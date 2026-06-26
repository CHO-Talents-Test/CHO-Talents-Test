-- TASK-031: 달란트 지급 금액 최대 100 제한
-- Supabase SQL Editor에서 실행하세요.

-- 1. give_talent RPC에 최대 100 제한 추가
CREATE OR REPLACE FUNCTION give_talent(
  p_user_id UUID,
  p_amount INTEGER DEFAULT 0,
  p_description TEXT DEFAULT '',
  p_created_by UUID DEFAULT NULL,
  p_talent_item_id UUID DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_balance INTEGER; v_txn_id UUID; v_caller_perm TEXT;
  v_target_type TEXT; v_item RECORD; v_actual_amount INTEGER;
  v_actual_desc TEXT; v_week_count INTEGER;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL OR get_permission_rank(v_caller_perm) < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT user_type INTO v_target_type FROM profiles WHERE id = p_user_id;
  IF v_target_type IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF p_talent_item_id IS NOT NULL THEN
    SELECT * INTO v_item FROM talent_items WHERE id = p_talent_item_id AND is_active = true;
    IF v_item IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Invalid or inactive talent item');
    END IF;
    v_actual_amount := v_item.talent_amount;
    v_actual_desc := v_item.name;

    IF v_target_type = 'student' THEN
      SELECT COUNT(*) INTO v_week_count FROM talent_transactions
      WHERE user_id = p_user_id AND talent_item_id = p_talent_item_id AND type = 'earn'
        AND created_at >= date_trunc('week', now() AT TIME ZONE 'Asia/Seoul')
        AND created_at < date_trunc('week', now() AT TIME ZONE 'Asia/Seoul') + interval '7 days';
      IF v_week_count > 0 THEN
        RETURN json_build_object('success', false, 'error',
          'Already given this item this week for student: ' || v_item.name);
      END IF;
    END IF;
  ELSE
    IF p_amount <= 0 THEN
      RETURN json_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    v_actual_amount := p_amount;
    v_actual_desc := COALESCE(NULLIF(p_description, ''), 'Manual');
  END IF;

  -- 최대 100 제한 (항목/수동 모두 적용)
  IF v_actual_amount > 100 THEN
    RETURN json_build_object('success', false, 'error', 'Amount cannot exceed 100');
  END IF;

  UPDATE profiles SET talent_balance = COALESCE(talent_balance, 0) + v_actual_amount WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

  INSERT INTO talent_transactions (user_id, type, amount, balance_after, description, created_by, talent_item_id)
  VALUES (p_user_id, 'earn', v_actual_amount, v_new_balance, v_actual_desc, COALESCE(p_created_by, auth.uid()), p_talent_item_id)
  RETURNING id INTO v_txn_id;

  RETURN json_build_object('success', true, 'balance', v_new_balance, 'txn_id', v_txn_id, 'amount', v_actual_amount);
END;
$$;

-- 2. talent_items 테이블에 CHECK 제약조건 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'talent_items_amount_max100'
  ) THEN
    ALTER TABLE talent_items ADD CONSTRAINT talent_items_amount_max100 CHECK (talent_amount <= 100);
  END IF;
END $$;

-- 3. talent_qr_codes 테이블에 CHECK 제약조건 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'talent_qr_codes_amount_max100'
  ) THEN
    ALTER TABLE talent_qr_codes ADD CONSTRAINT talent_qr_codes_amount_max100 CHECK (amount <= 100);
  END IF;
END $$;

-- 4. 스키마 캐시 리로드
NOTIFY pgrst, 'reload schema';
