-- TASK-052: Super Admin 권한 수정 시 제약 해제
-- is_super_admin = true인 호출자는 모든 권한 레벨 할당 가능
-- 실행 위치: Supabase Dashboard > SQL Editor

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
  FROM public.profiles WHERE id = auth.uid();

  IF v_caller_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_caller_rank := public.get_permission_rank(v_caller_perm);
  -- Super Admin은 rank 110으로 처리
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
      class_number = p_class_number
  WHERE id = p_user_id;

  RETURN json_build_object('success', true);
END;
$$;
