-- TASK-026: 상품 구매 시스템 DB 스키마
-- v3.9.0

-- ============================================
-- 1. product_orders 테이블 (상품 구매 주문)
-- ============================================
CREATE TABLE IF NOT EXISTS product_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  product_id UUID NOT NULL REFERENCES products(id),
  product_name TEXT NOT NULL,
  price INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested', 'preparing', 'purchased', 'delivered')),
  requested_at TIMESTAMPTZ DEFAULT now(),
  prepared_at TIMESTAMPTZ,
  purchased_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  prepared_by UUID REFERENCES profiles(id),
  purchased_by UUID REFERENCES profiles(id),
  delivered_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 2. profiles 테이블 수정 (사용 대기 달란트)
-- ============================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pending_talent INTEGER DEFAULT 0;

-- ============================================
-- 3. RLS 정책
-- ============================================
ALTER TABLE product_orders ENABLE ROW LEVEL SECURITY;

-- 기존 정책 제거 후 재생성
DROP POLICY IF EXISTS "Users can view own orders" ON product_orders;
DROP POLICY IF EXISTS "Staff can view all orders" ON product_orders;
DROP POLICY IF EXISTS "Users can create orders" ON product_orders;
DROP POLICY IF EXISTS "Staff can update orders" ON product_orders;

-- 인증 사용자: 자기 주문 조회
CREATE POLICY "Users can view own orders"
  ON product_orders FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- 관리 권한(60+): 모든 주문 조회
CREATE POLICY "Staff can view all orders"
  ON product_orders FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND get_permission_rank(permission_level) >= 60
    )
  );

-- 인증 사용자: 구매 신청 생성
CREATE POLICY "Users can create orders"
  ON product_orders FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- 관리 권한(60+): 주문 상태 업데이트
CREATE POLICY "Staff can update orders"
  ON product_orders FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND get_permission_rank(permission_level) >= 60
    )
  );

-- ============================================
-- 4. pending_talent 증감 RPC
-- ============================================
CREATE OR REPLACE FUNCTION request_product_order(
  p_user_id UUID,
  p_product_id UUID,
  p_product_name TEXT,
  p_price INTEGER
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_balance INTEGER;
  v_pending INTEGER;
  v_order_id UUID;
BEGIN
  SELECT talent_balance, COALESCE(pending_talent, 0)
  INTO v_balance, v_pending
  FROM profiles WHERE id = p_user_id FOR UPDATE;

  IF (v_balance - v_pending) < p_price THEN
    RETURN json_build_object('success', false, 'error', '사용 가능한 달란트가 부족합니다.');
  END IF;

  INSERT INTO product_orders (user_id, product_id, product_name, price, status, requested_at)
  VALUES (p_user_id, p_product_id, p_product_name, p_price, 'requested', now())
  RETURNING id INTO v_order_id;

  UPDATE profiles SET pending_talent = COALESCE(pending_talent, 0) + p_price WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'order_id', v_order_id,
    'pending_talent', v_pending + p_price
  );
END;
$$;

-- 상품 구매 확정 시 실제 달란트 차감
CREATE OR REPLACE FUNCTION confirm_product_purchase(
  p_order_id UUID,
  p_admin_id UUID
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_order product_orders%ROWTYPE;
  v_result JSON;
BEGIN
  SELECT * INTO v_order FROM product_orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN json_build_object('success', false, 'error', '주문을 찾을 수 없습니다.');
  END IF;
  IF v_order.status != 'preparing' THEN
    RETURN json_build_object('success', false, 'error', '상품 준비 상태의 주문만 구매 확정할 수 있습니다.');
  END IF;

  SELECT use_talent(v_order.user_id, v_order.price, '상품 구매: ' || v_order.product_name, p_admin_id) INTO v_result;

  IF (v_result->>'success')::boolean = false THEN
    RETURN v_result;
  END IF;

  UPDATE product_orders
  SET status = 'purchased', purchased_at = now(), purchased_by = p_admin_id
  WHERE id = p_order_id;

  UPDATE profiles
  SET pending_talent = GREATEST(COALESCE(pending_talent, 0) - v_order.price, 0)
  WHERE id = v_order.user_id;

  RETURN json_build_object('success', true, 'balance', (v_result->>'balance')::integer);
END;
$$;
