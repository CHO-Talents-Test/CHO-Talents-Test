-- TASK-107: 사용자 관리 계정 조회 범위를 담당 부서 기준으로 통일
-- 실행 위치: Supabase SQL Editor
--
-- 권한 기준
--   * 관리자(100), 전도사님(90), 최고관리자: 모든 사용자 계정 조회
--   * 부장 교사(80): 모든 부서의 교사·학생 계정을 목록에서 조회
--   * 구매 담당 교사(70), 부서 담당 교사(60): 담당 부서의 교사·학생 계정만 조회
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

  -- 관리자·전도사님은 모든 사용자 계정을 조회한다.
  IF v_caller_rank >= 90 THEN
    RETURN true;
  END IF;

  -- 부장 교사는 모든 부서의 교사·학생 계정을 목록에서 조회한다.
  IF v_caller_perm = 'chief' THEN
    SELECT user_type
    INTO v_target_type
    FROM public.profiles
    WHERE id = p_target_id;

    RETURN v_target_type IN ('teacher', 'student');
  END IF;

  -- 구매 담당·부서 담당 교사는 담당 부서의 교사·학생만 조회한다.
  IF v_caller_perm IN ('purchase_teacher', 'dept_teacher') THEN
    IF v_managed_dept_id IS NULL THEN
      RETURN false;
    END IF;

    SELECT user_type, department_id
    INTO v_target_type, v_target_dept_id
    FROM public.profiles
    WHERE id = p_target_id;

    RETURN v_target_dept_id = v_managed_dept_id
      AND v_target_type IN ('teacher', 'student');
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
  v_managed_dept_id uuid;
  v_caller_dept_id uuid;
  v_caller_class_number integer;
BEGIN
  SELECT permission_level,
         public.get_permission_rank(permission_level),
         COALESCE(managed_dept_id, department_id),
         department_id,
         class_number
  INTO v_caller_perm, v_caller_rank, v_managed_dept_id,
       v_caller_dept_id, v_caller_class_number
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_perm IS NULL OR v_caller_rank < 40 THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 관리자·전도사님은 모든 사용자 계정을 조회한다.
  IF v_caller_rank >= 90 THEN
    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
      ORDER BY created_at DESC;
    RETURN;
  END IF;

  -- 부장 교사는 모든 부서의 교사·학생 계정을 목록에서 조회한다.
  IF v_caller_perm = 'chief' THEN
    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE user_type IN ('teacher', 'student')
        AND (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
      ORDER BY created_at DESC;
    RETURN;
  END IF;

  -- 구매 담당·부서 담당 교사는 담당 부서의 교사·학생만 조회한다.
  IF v_caller_perm IN ('purchase_teacher', 'dept_teacher') THEN
    IF v_managed_dept_id IS NULL THEN
      RETURN;
    END IF;

    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE department_id = v_managed_dept_id
        AND user_type IN ('teacher', 'student')
        AND (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
      ORDER BY created_at DESC;
    RETURN;
  END IF;

  -- 일반 교사는 자기 부서·반의 학생만 조회한다.
  IF v_caller_rank = 40
     AND v_caller_dept_id IS NOT NULL
     AND v_caller_class_number IS NOT NULL THEN
    RETURN QUERY
      SELECT *
      FROM public.profiles
      WHERE user_type = 'student'
        AND department_id = v_caller_dept_id
        AND class_number IS NOT DISTINCT FROM v_caller_class_number
        AND (p_user_type IS NULL OR user_type = p_user_type)
        AND (p_department_id IS NULL OR department_id = p_department_id)
      ORDER BY created_at DESC;
  END IF;

  RETURN QUERY
    SELECT * FROM public.profiles WHERE false;
END;
$$;

-- 직접 profiles 조회도 같은 범위로 제한한다.
DROP POLICY IF EXISTS profiles_select_perm ON public.profiles;
CREATE POLICY profiles_select_perm
  ON public.profiles
  FOR SELECT
  USING (public.get_permission_rank(public.get_my_role()) >= 90);

DROP POLICY IF EXISTS profiles_select_teacher_scope ON public.profiles;
CREATE POLICY profiles_select_teacher_scope
  ON public.profiles
  FOR SELECT TO authenticated
  USING (public.can_view_scoped_profile(id));

GRANT EXECUTE ON FUNCTION public.can_view_scoped_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users(text, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
