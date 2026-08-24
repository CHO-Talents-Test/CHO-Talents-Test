-- TASK-110: 최고관리자의 상위 권한 할당 허용
-- 실행 위치: Supabase Dashboard > SQL Editor
--
-- profiles.is_super_admin = true인 호출자는 현재 permission_level보다 높은
-- 권한도 사용자 관리 화면에서 할당할 수 있습니다. super admin 플래그 자체는
-- 이 RPC에서 변경하지 않습니다.

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_update_user(
  p_user_id uuid,
  p_display_name text DEFAULT NULL,
  p_department_id uuid DEFAULT NULL,
  p_managed_dept_id uuid DEFAULT NULL,
  p_user_type text DEFAULT NULL,
  p_permission_level text DEFAULT NULL,
  p_class_number integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_perm text;
  v_caller_rank integer;
  v_caller_super boolean;
  v_target_perm text;
  v_target_rank integer;
  v_target_super boolean;
  v_new_rank integer;
BEGIN
  SELECT permission_level, COALESCE(is_super_admin, false)
  INTO v_caller_perm, v_caller_super
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- 최고관리자 플래그는 permission_level과 독립된 최상위 권한이다.
  v_caller_rank := public.get_permission_rank(v_caller_perm);
  IF v_caller_super THEN
    v_caller_rank := 110;
  END IF;

  IF v_caller_rank < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT permission_level, COALESCE(is_super_admin, false)
  INTO v_target_perm, v_target_super
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_target_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  -- 다른 최고관리자 계정은 기존 보호 규칙대로 본인만 수정할 수 있다.
  IF v_target_super AND auth.uid() != p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Super admin can only be modified by themselves');
  END IF;

  v_target_rank := public.get_permission_rank(v_target_perm);
  IF v_target_rank > v_caller_rank AND auth.uid() != p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot modify user with higher permission');
  END IF;

  IF p_permission_level IS NOT NULL THEN
    v_new_rank := public.get_permission_rank(p_permission_level);
    IF v_new_rank > v_caller_rank THEN
      RETURN json_build_object('success', false, 'error', 'Cannot assign permission higher than your own');
    END IF;
  END IF;

  UPDATE public.profiles
  SET display_name = COALESCE(p_display_name, display_name),
      user_type = COALESCE(p_user_type, user_type),
      permission_level = COALESCE(p_permission_level, permission_level),
      department_id = COALESCE(p_department_id, department_id),
      managed_dept_id = p_managed_dept_id,
      class_number = p_class_number,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN json_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_user(uuid, text, uuid, uuid, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_user(uuid, text, uuid, uuid, text, text, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user(uuid, text, uuid, uuid, text, text, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verification
-- 1. is_super_admin=true and permission_level='teacher' caller can assign 'admin'.
-- 2. Non-super-admin caller cannot assign a permission above its own rank.
-- 3. A super-admin target remains editable only by itself.
