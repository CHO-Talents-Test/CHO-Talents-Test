-- TASK-102: 사용자 계정 조회 범위 조정
-- 실행 위치: Supabase SQL Editor
--
-- 권한 기준
--   * 부장 교사(80): 담당 부서의 일반 교사·학생 계정만 조회
--   * 전도사님(90), 관리자(100), 최고관리자: 전체 계정 조회
--
-- admin/users.html의 화면 필터를 우회해 RPC 또는 profiles 테이블을
-- 직접 호출해도 같은 범위가 적용되도록 합니다.

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
  v_managed_dept_id uuid;
  v_caller_dept_id uuid;
  v_caller_class_number integer;
  v_target_perm text;
  v_target_dept_id uuid;
  v_target_type text;
  v_target_class_number integer;
BEGIN
  IF p_target_id IS NULL OR auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  IF auth.uid() = p_target_id THEN
    RETURN true;
  END IF;

  SELECT permission_level,
         public.get_permission_rank(permission_level),
         COALESCE(managed_dept_id, department_id),
         department_id,
         class_number
  INTO v_caller_perm, v_caller_rank, v_managed_dept_id,
       v_caller_dept_id, v_caller_class_number
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_perm IS NULL THEN
    RETURN false;
  END IF;

  -- 전도사님 이상은 관리자와 같이 전체 계정을 조회한다.
  IF v_caller_rank >= 90 THEN
    RETURN true;
  END IF;

  -- 부장 교사는 담당 부서의 일반 교사·학생 계정만 조회한다.
  IF v_caller_rank = 80 THEN
    IF v_managed_dept_id IS NULL THEN
      RETURN false;
    END IF;

    SELECT permission_level, department_id
    INTO v_target_perm, v_target_dept_id
    FROM public.profiles
    WHERE id = p_target_id;

    RETURN v_target_dept_id = v_managed_dept_id
      AND v_target_perm IN ('teacher', 'student');
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

  -- 기존 부서 담당/구매 담당 교사의 프로필 조회 범위는 유지한다.
  RETURN v_caller_rank >= 60;
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
  v_managed_dept_id uuid;
BEGIN
  SELECT permission_level,
         public.get_permission_rank(permission_level),
         COALESCE(managed_dept_id, department_id)
  INTO v_caller_perm, v_caller_rank, v_managed_dept_id
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_perm IS NULL OR v_caller_rank < 40 THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 전도사님 이상은 관리자와 동일하게 전체 계정을 조회한다.
  IF v_caller_rank >= 90 THEN
    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
      ORDER BY created_at DESC;
    RETURN;
  END IF;

  -- 부장 교사는 호출 파라미터와 관계없이 담당 부서의 일반 교사·학생만 조회한다.
  IF v_caller_rank = 80 THEN
    IF v_managed_dept_id IS NULL THEN
      RETURN;
    END IF;

    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE department_id = v_managed_dept_id
        AND permission_level IN ('teacher', 'student')
        AND (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
      ORDER BY created_at DESC;
    RETURN;
  END IF;

  -- 기존 40~70 권한의 운영 화면 동작은 변경하지 않는다.
  RETURN QUERY
    SELECT *
    FROM public.profiles
    WHERE (p_user_type IS NULL OR user_type = p_user_type)
      AND (p_department_id IS NULL OR department_id = p_department_id)
    ORDER BY created_at DESC;
END;
$$;

-- 기존의 60+ 전체 조회 정책을 부장 교사에게는 담당 부서 범위로 제한한다.
DROP POLICY IF EXISTS profiles_select_perm ON public.profiles;
CREATE POLICY profiles_select_perm
  ON public.profiles
  FOR SELECT
  USING (
    public.get_permission_rank(public.get_my_role()) >= 90
    OR (
      public.get_permission_rank(public.get_my_role()) >= 60
      AND public.get_permission_rank(public.get_my_role()) < 80
    )
  );

DROP POLICY IF EXISTS profiles_select_teacher_scope ON public.profiles;
CREATE POLICY profiles_select_teacher_scope
  ON public.profiles
  FOR SELECT TO authenticated
  USING (public.can_view_scoped_profile(id));

GRANT EXECUTE ON FUNCTION public.can_view_scoped_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users(text, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
