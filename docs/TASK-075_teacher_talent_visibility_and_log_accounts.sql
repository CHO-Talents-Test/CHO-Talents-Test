-- TASK-075: 일반 교사 달란트 지급 후 화면 갱신/RLS 보강 + 로그 계정 표시 보조
-- 실행 위치: Supabase SQL Editor
--
-- 원인:
-- 1) give_talent RPC는 일반 교사(40)의 같은 부서/반 학생 지급을 허용한다.
-- 2) 하지만 화면 갱신에 필요한 profiles/talent_transactions 직접 SELECT 정책은
--    본인 또는 60등급 이상만 허용해, 일반 교사 화면에서 지급 완료/최근 내역이 비어 보일 수 있다.
--
-- 조치:
-- - 지급 가능 범위와 조회 가능 범위를 맞추는 SECURITY DEFINER 헬퍼를 추가한다.
-- - profiles와 talent_transactions SELECT 정책에서 같은 부서/반 학생 조회를 허용한다.

BEGIN;

CREATE OR REPLACE FUNCTION public.can_view_managed_profile(p_target_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_perm text;
  v_caller_dept uuid;
  v_caller_class integer;
  v_target_type text;
  v_target_dept uuid;
  v_target_class integer;
  v_caller_rank integer;
BEGIN
  IF p_target_id IS NULL OR auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT permission_level, department_id, class_number
  INTO v_caller_perm, v_caller_dept, v_caller_class
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_perm IS NULL THEN
    RETURN false;
  END IF;

  v_caller_rank := public.get_permission_rank(v_caller_perm);

  IF auth.uid() = p_target_id OR v_caller_rank >= 60 THEN
    RETURN true;
  END IF;

  IF v_caller_rank <> 40 OR v_caller_dept IS NULL OR v_caller_class IS NULL THEN
    RETURN false;
  END IF;

  SELECT user_type, department_id, class_number
  INTO v_target_type, v_target_dept, v_target_class
  FROM public.profiles
  WHERE id = p_target_id;

  RETURN v_target_type = 'student'
    AND v_target_dept = v_caller_dept
    AND v_target_class IS NOT DISTINCT FROM v_caller_class;
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_view_managed_profile(uuid) TO authenticated;

DROP POLICY IF EXISTS profiles_select_teacher_scope ON public.profiles;
CREATE POLICY profiles_select_teacher_scope
  ON public.profiles
  FOR SELECT TO authenticated
  USING (public.can_view_managed_profile(id));

DROP POLICY IF EXISTS tt_select_perm ON public.talent_transactions;
CREATE POLICY tt_select_perm
  ON public.talent_transactions
  FOR SELECT TO authenticated
  USING (public.can_view_managed_profile(user_id));

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activity_logs' AND column_name = 'username'
  ) THEN
    ALTER TABLE public.activity_logs ALTER COLUMN username SET DEFAULT '<계정 없음>';
    UPDATE public.activity_logs
    SET username = '<계정 없음>'
    WHERE username IS NULL OR btrim(username) = '';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activity_logs' AND column_name = 'user_name'
  ) THEN
    ALTER TABLE public.activity_logs ALTER COLUMN user_name SET DEFAULT '<계정 없음>';
    UPDATE public.activity_logs
    SET user_name = '<계정 없음>'
    WHERE user_name IS NULL OR btrim(user_name) = '';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
