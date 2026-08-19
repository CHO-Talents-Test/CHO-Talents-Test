-- TASK-103: 달란트 대상자 조회·지급 권한 범위 정렬
-- 실행 위치: Supabase SQL Editor
--
-- 권한 규칙
--   * 관리자/전도사님(90+): 전체 부서·전체 계정 조회 및 지급
--   * 부장 교사(chief): 전체 부서·전체 계정 조회, 관리 부서만 지급
--   * 구매 담당/부서 담당 교사: 관리 부서의 전체 계정 조회 및 지급
--   * 일반 교사(40): 자기 부서·자기 반 학생만 조회 및 지급
--   * 학생: 달란트 관리 화면 및 목록 RPC 접근 불가
--   * 최고관리자 계정: 최고관리자 본인 외에는 조회·지급 불가

BEGIN;

CREATE OR REPLACE FUNCTION public.can_view_scoped_profile(p_target_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_perm text;
  v_caller_rank integer;
  v_caller_is_super_admin boolean;
  v_managed_dept_id uuid;
  v_caller_dept_id uuid;
  v_caller_class_number integer;
  v_target_dept_id uuid;
  v_target_type text;
  v_target_class_number integer;
  v_target_is_super_admin boolean;
BEGIN
  IF p_target_id IS NULL OR auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  IF auth.uid() = p_target_id THEN
    RETURN true;
  END IF;

  SELECT permission_level,
         public.get_permission_rank(permission_level),
         COALESCE(is_super_admin, false),
         COALESCE(managed_dept_id, department_id),
         department_id,
         class_number
  INTO v_caller_perm, v_caller_rank, v_caller_is_super_admin, v_managed_dept_id,
       v_caller_dept_id, v_caller_class_number
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_perm IS NULL THEN
    RETURN false;
  END IF;

  SELECT COALESCE(is_super_admin, false)
  INTO v_target_is_super_admin
  FROM public.profiles
  WHERE id = p_target_id;

  IF v_target_is_super_admin AND NOT v_caller_is_super_admin THEN
    RETURN false;
  END IF;

  IF v_caller_rank >= 90 OR v_caller_perm = 'chief' THEN
    RETURN true;
  END IF;

  -- 구매 담당/부서 담당 교사는 관리 부서의 모든 계정을 조회한다.
  IF v_caller_perm IN ('purchase_teacher', 'dept_teacher') THEN
    IF v_managed_dept_id IS NULL THEN
      RETURN false;
    END IF;

    SELECT department_id
    INTO v_target_dept_id
    FROM public.profiles
    WHERE id = p_target_id;

    RETURN v_target_dept_id = v_managed_dept_id;
  END IF;

  -- 일반 교사의 기존 같은 부서·같은 반 학생 조회 범위는 유지한다.
  IF v_caller_rank = 40 THEN
    IF v_caller_dept_id IS NULL OR v_caller_class_number IS NULL THEN
      RETURN false;
    END IF;

    SELECT user_type, department_id, class_number
    INTO v_target_type, v_target_dept_id, v_target_class_number
    FROM public.profiles
    WHERE id = p_target_id;

    RETURN v_target_type = 'student'
      AND v_target_dept_id = v_caller_dept_id
      AND v_target_class_number IS NOT DISTINCT FROM v_caller_class_number;
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_users(
  p_user_type text DEFAULT NULL,
  p_department_id uuid DEFAULT NULL
)
RETURNS SETOF public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_perm text;
  v_caller_rank integer;
  v_caller_is_super_admin boolean;
  v_caller_dept_id uuid;
  v_managed_dept_id uuid;
BEGIN
  SELECT permission_level,
         public.get_permission_rank(permission_level),
         COALESCE(is_super_admin, false),
         department_id,
         COALESCE(managed_dept_id, department_id)
  INTO v_caller_perm, v_caller_rank, v_caller_is_super_admin, v_caller_dept_id, v_managed_dept_id
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_perm IS NULL OR v_caller_rank < 40 THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 관리자·전도사님과 부장 교사는 전체 부서의 모든 계정을 조회한다.
  IF v_caller_rank >= 90 OR v_caller_perm = 'chief' THEN
    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
        AND (v_caller_is_super_admin OR COALESCE(is_super_admin, false) = false)
      ORDER BY created_at DESC;
    RETURN;
  END IF;

  -- 구매 담당/부서 담당 교사는 관리 부서의 모든 계정을 조회한다.
  IF v_caller_perm IN ('purchase_teacher', 'dept_teacher') THEN
    IF v_managed_dept_id IS NULL THEN
      RETURN;
    END IF;

    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE department_id = v_managed_dept_id
        AND (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
        AND (v_caller_is_super_admin OR COALESCE(is_super_admin, false) = false)
      ORDER BY created_at DESC;
    RETURN;
  END IF;

  -- 일반 교사는 자기 부서·자기 반 학생만 조회한다.
  IF v_caller_rank = 40 THEN
    IF v_caller_dept_id IS NULL THEN
      RETURN;
    END IF;

    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE user_type = 'student'
        AND department_id = v_caller_dept_id
        AND class_number IS NOT DISTINCT FROM (
          SELECT class_number FROM public.profiles WHERE id = auth.uid()
        )
        AND (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
        AND (v_caller_is_super_admin OR COALESCE(is_super_admin, false) = false)
      ORDER BY created_at DESC;
    RETURN;
  END IF;

  RAISE EXCEPTION 'Unauthorized';
END;
$$;

-- 실제 지급 RPC도 목록에 표시된 지급 가능 범위와 동일하게 강제한다.
-- TASK-099(지정 지급일 지원)가 적용된 운영 DB를 기준으로 한다.
CREATE OR REPLACE FUNCTION public.give_talent(
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
  v_caller_is_super_admin boolean;
  v_caller_dept uuid;
  v_caller_class integer;
  v_caller_managed_dept uuid;
  v_target_type text;
  v_target_dept uuid;
  v_target_class integer;
  v_target_is_super_admin boolean;
  v_item record;
  v_actual_amount integer;
  v_actual_desc text;
  v_grant_date date;
  v_grant_count integer;
  v_override_week_limit boolean;
BEGIN
  SELECT permission_level,
         COALESCE(is_super_admin, false),
         department_id,
         class_number,
         COALESCE(managed_dept_id, department_id)
  INTO v_caller_perm, v_caller_is_super_admin, v_caller_dept, v_caller_class, v_caller_managed_dept
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

  -- 동시 지급 시 중복 검사를 우회하지 않도록 대상 프로필을 잠근다.
  SELECT user_type, department_id, class_number, COALESCE(is_super_admin, false)
  INTO v_target_type, v_target_dept, v_target_class, v_target_is_super_admin
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_target_type IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_target_is_super_admin AND NOT v_caller_is_super_admin THEN
    RETURN json_build_object('success', false, 'error', 'Super administrator accounts cannot be granted talents');
  END IF;

  -- 관리자·전도사님은 전체 대상 지급, 부장/담당 교사는 관리 부서만 지급한다.
  IF v_caller_rank >= 90 THEN
    NULL;
  ELSIF v_caller_perm IN ('chief', 'purchase_teacher', 'dept_teacher') THEN
    IF v_caller_managed_dept IS NULL OR v_caller_managed_dept != v_target_dept THEN
      RETURN json_build_object('success', false, 'error', 'You can only give talents to users in your managed department');
    END IF;
  ELSIF v_caller_rank = 40 THEN
    IF v_target_type <> 'student'
       OR v_caller_dept IS NULL
       OR v_caller_dept != v_target_dept
       OR v_caller_class IS DISTINCT FROM v_target_class THEN
      RETURN json_build_object('success', false, 'error', 'You can only give talents to students in your class');
    END IF;
  ELSE
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_grant_date := COALESCE(p_grant_date, (now() AT TIME ZONE 'Asia/Seoul')::date);

  IF p_talent_item_id IS NOT NULL THEN
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

-- profiles와 달란트 이력의 직접 조회도 위 범위를 우회하지 못하게 맞춘다.
DROP POLICY IF EXISTS profiles_select_perm ON public.profiles;

DROP POLICY IF EXISTS profiles_select_teacher_scope ON public.profiles;
CREATE POLICY profiles_select_teacher_scope
  ON public.profiles
  FOR SELECT TO authenticated
  USING (public.can_view_scoped_profile(id));

DROP POLICY IF EXISTS tt_select_perm ON public.talent_transactions;
CREATE POLICY tt_select_perm
  ON public.talent_transactions
  FOR SELECT TO authenticated
  USING (public.can_view_scoped_profile(user_id));

GRANT EXECUTE ON FUNCTION public.can_view_scoped_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users(text, uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid, boolean, text, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid, boolean, text, date) FROM anon;
GRANT EXECUTE ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid, boolean, text, date) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
