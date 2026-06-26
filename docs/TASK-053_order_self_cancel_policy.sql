-- TASK-053: 사용자 본인 주문 취소 RLS 정책 추가
-- 문제: 학생/일반 교사(rank < 60)가 자신의 '구매 신청' 상태 주문을 취소할 수 없음
-- 원인: product_orders UPDATE 정책이 rank >= 60만 허용
-- 해결: 본인 주문 + 현재 상태 'requested' 조건으로 자기 취소 정책 추가
-- 실행 위치: Supabase Dashboard > SQL Editor

-- 1. 사용자 본인 주문 취소 정책
DROP POLICY IF EXISTS "Users can cancel own requested orders" ON public.product_orders;
CREATE POLICY "Users can cancel own requested orders" ON public.product_orders
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND status = 'requested')
  WITH CHECK (user_id = auth.uid() AND status = 'cancelled');

-- 2. cancel_product_order RPC (SECURITY DEFINER로 RLS 우회)
-- 이 RPC가 있으면 프론트엔드에서 우선 사용하며, 없을 때 위 정책으로 직접 UPDATE 폴백
CREATE OR REPLACE FUNCTION public.cancel_product_order(
  p_order_id uuid,
  p_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_current_pending integer;
BEGIN
  -- 주문 조회 및 검증
  SELECT * INTO v_order
  FROM public.product_orders
  WHERE id = p_order_id AND user_id = p_user_id AND status = 'requested';

  IF v_order IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'No cancellable order found');
  END IF;

  -- 주문 상태를 cancelled로 변경
  UPDATE public.product_orders
  SET status = 'cancelled'
  WHERE id = p_order_id;

  -- pending_talent 차감 (구매 신청 시 증가했던 값 복원)
  SELECT COALESCE(pending_talent, 0) INTO v_current_pending
  FROM public.profiles WHERE id = p_user_id;

  UPDATE public.profiles
  SET pending_talent = GREATEST(0, v_current_pending - v_order.price)
  WHERE id = p_user_id;

  RETURN json_build_object('success', true, 'refunded', v_order.price);
END;
$$;

-- 3. RPC 실행 권한 부여
GRANT EXECUTE ON FUNCTION public.cancel_product_order(uuid, uuid) TO authenticated;
