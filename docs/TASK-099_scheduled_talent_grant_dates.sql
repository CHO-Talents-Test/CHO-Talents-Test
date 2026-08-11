-- TASK-099: 일요일 지정일 기반 달란트 지급
-- 실행 위치: Supabase Dashboard > SQL Editor
--
-- 기존 "이번 주" 중복 제한을 실제 지급 대상일(grant_date) 기준으로 바꿉니다.
-- 관리자 지급 화면에서는 일요일만 지급일로 선택할 수 있으며, 같은 대상·항목·지급일의
-- 중복만 차단합니다. 기존 거래는 생성 시각의 KST 날짜를 지급일로 보정합니다.

BEGIN;

ALTER TABLE public.talent_transactions
  ADD COLUMN IF NOT EXISTS grant_date date;

UPDATE public.talent_transactions
SET grant_date = (created_at AT TIME ZONE 'Asia/Seoul')::date
WHERE grant_date IS NULL;

ALTER TABLE public.talent_transactions
  ALTER COLUMN grant_date SET DEFAULT ((now() AT TIME ZONE 'Asia/Seoul')::date),
  ALTER COLUMN grant_date SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_talent_transactions_grant_schedule
  ON public.talent_transactions(user_id, grant_date, talent_item_id)
  WHERE type = 'earn' AND talent_item_id IS NOT NULL;

-- 기존 7개 인자 RPC를 제거한 뒤 지급일 인자가 추가된 단일 RPC만 남깁니다.
DROP FUNCTION IF EXISTS public.give_talent(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.give_talent(uuid, integer, text, uuid);
DROP FUNCTION IF EXISTS public.give_talent(uuid, integer, text, uuid, uuid);
DROP FUNCTION IF EXISTS public.give_talent(uuid, integer, text, uuid, uuid, boolean, text);
DROP FUNCTION IF EXISTS public.give_talent(uuid, integer, text, uuid, uuid, boolean, text, date);

CREATE FUNCTION public.give_talent(
  p_user_id uuid,
  p_amount integer DEFAULT 0,
  p_description text DEFAULT '',
  p_created_by uuid DEFAULT NULL,
  p_talent_item_id uuid DEFAULT NULL,
  p_override_week_limit boolean DEFAULT false,
  p_override_reason text DEFAULT NULL,
  p_grant_date date DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance integer;
  v_txn_id uuid;
  v_caller_perm text;
  v_caller_rank integer;
  v_caller_dept uuid;
  v_caller_class integer;
  v_caller_managed_dept uuid;
  v_target_type text;
  v_target_dept uuid;
  v_target_class integer;
  v_item record;
  v_actual_amount integer;
  v_actual_desc text;
  v_grant_date date;
  v_grant_count integer;
  v_override_week_limit boolean;
BEGIN
  SELECT permission_level, department_id, class_number, managed_dept_id
  INTO v_caller_perm, v_caller_dept, v_caller_class, v_caller_managed_dept
  FROM public.profiles
  WHERE id = auth.uid();

  v_caller_rank := public.get_permission_rank(v_caller_perm);
  IF v_caller_perm IS NULL OR v_caller_rank < 40 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_override_week_limit := COALESCE(p_override_week_limit, false);
  IF v_override_week_limit AND v_caller_rank < 90 THEN
    RETURN json_build_object('success', false, 'error', '예외 지급은 전도사님 이상만 가능합니다');
  END IF;

  -- 대상 프로필 잠금은 같은 대상에 대한 동시 지급 요청이 중복 검사를 우회하지 않게 합니다.
  SELECT user_type, department_id, class_number
  INTO v_target_type, v_target_dept, v_target_class
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_target_type IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_caller_rank = 40 THEN
    IF v_caller_dept IS NULL
       OR v_caller_dept != v_target_dept
       OR v_caller_class IS DISTINCT FROM v_target_class THEN
      RETURN json_build_object('success', false, 'error', 'You can only give talents to students in your class');
    END IF;
  ELSIF v_caller_rank >= 60 AND v_caller_rank < 90 THEN
    IF v_caller_managed_dept IS NULL OR v_caller_managed_dept != v_target_dept THEN
      RETURN json_build_object('success', false, 'error', 'You can only give talents to users in your managed department');
    END IF;
  END IF;

  v_grant_date := COALESCE(p_grant_date, (now() AT TIME ZONE 'Asia/Seoul')::date);

  IF p_talent_item_id IS NOT NULL THEN
    -- 일정 화면에서 전달하는 지정일은 일요일만 허용합니다. 지정하지 않은 다른 지급 경로는
    -- 실제 처리일을 기본 지급일로 기록해 기존 QR/자동 지급을 유지합니다.
    IF p_grant_date IS NOT NULL AND EXTRACT(DOW FROM p_grant_date) <> 0 THEN
      RETURN json_build_object('success', false, 'error', '지급일은 일요일만 선택할 수 있습니다');
    END IF;

    SELECT * INTO v_item
    FROM public.talent_items
    WHERE id = p_talent_item_id AND is_active = true;

    IF v_item IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Invalid or inactive talent item');
    END IF;

    IF v_item.target_type IS NOT NULL AND v_item.target_type <> v_target_type THEN
      RETURN json_build_object('success', false, 'error', 'Item target type mismatch: ' || v_item.target_type || ' vs ' || v_target_type);
    END IF;

    v_actual_amount := v_item.talent_amount;
    v_actual_desc := v_item.name;

    SELECT count(*) INTO v_grant_count
    FROM public.talent_transactions AS earned
    WHERE earned.user_id = p_user_id
      AND earned.talent_item_id = p_talent_item_id
      AND earned.type = 'earn'
      AND COALESCE(earned.grant_date, (earned.created_at AT TIME ZONE 'Asia/Seoul')::date) = v_grant_date
      AND NOT EXISTS (
        SELECT 1
        FROM public.talent_transactions AS returned
        WHERE returned.user_id = earned.user_id
          AND returned.type = 'use'
          AND (
            returned.description LIKE ('반환: [' || earned.id::text || ']%')
            OR (
              returned.amount = earned.amount
              AND returned.description = '반환: [] ' || COALESCE(earned.description, '')
            )
          )
      );

    IF v_grant_count > 0 AND NOT v_override_week_limit THEN
      RETURN json_build_object('success', false, 'error', 'Already given this item on this payment date: ' || v_item.name);
    END IF;
  ELSE
    IF p_amount <= 0 THEN
      RETURN json_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    v_actual_amount := p_amount;
    v_actual_desc := COALESCE(NULLIF(p_description, ''), 'Manual');
  END IF;

  IF v_override_week_limit AND (p_override_reason IS NULL OR btrim(p_override_reason) = '') THEN
    RETURN json_build_object('success', false, 'error', '예외 지급 사유를 입력해주세요');
  END IF;
  IF v_actual_amount > 100 THEN
    RETURN json_build_object('success', false, 'error', 'Amount cannot exceed 100');
  END IF;

  UPDATE public.profiles
  SET talent_balance = COALESCE(talent_balance, 0) + v_actual_amount
  WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

  INSERT INTO public.talent_transactions (
    user_id, type, amount, balance_after, description, created_by, talent_item_id,
    override_week_limit, override_reason, grant_date
  ) VALUES (
    p_user_id, 'earn', v_actual_amount, v_new_balance, v_actual_desc,
    COALESCE(p_created_by, auth.uid()), p_talent_item_id,
    v_override_week_limit, p_override_reason, v_grant_date
  )
  RETURNING id INTO v_txn_id;

  RETURN json_build_object(
    'success', true,
    'balance', v_new_balance,
    'txn_id', v_txn_id,
    'amount', v_actual_amount,
    'grant_date', v_grant_date
  );
END;
$$;

REVOKE ALL ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid, boolean, text, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid, boolean, text, date) FROM anon;
GRANT EXECUTE ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid, boolean, text, date) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- 적용 확인
-- SELECT column_name, column_default, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'talent_transactions' AND column_name = 'grant_date';
--
-- SELECT proname, proargnames
-- FROM pg_proc
-- WHERE pronamespace = 'public'::regnamespace AND proname = 'give_talent';
