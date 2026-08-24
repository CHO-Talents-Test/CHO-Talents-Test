-- TASK-111: 최고관리자 권한 테스트 콤보 및 기존 권한 범위 복구
-- 실행 위치: Supabase Dashboard > SQL Editor
--
-- is_super_admin 플래그는 본인 권한 변경 콤보 표시와 RPC 호출 인증에만 사용합니다.
-- 실제 화면 및 서버 기능 권한은 변경된 permission_level 기준으로 다시 동작합니다.

BEGIN;

CREATE OR REPLACE FUNCTION public.super_admin_change_own_permission(
  p_permission_level text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_super_admin boolean;
BEGIN
  SELECT COALESCE(is_super_admin, false)
  INTO v_is_super_admin
  FROM public.profiles
  WHERE id = auth.uid();

  IF NOT COALESCE(v_is_super_admin, false) THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_permission_level NOT IN (
    'student', 'teacher', 'dept_teacher', 'purchase_teacher',
    'chief', 'evangelist', 'admin'
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Invalid permission level');
  END IF;

  UPDATE public.profiles
  SET permission_level = p_permission_level,
      updated_at = now()
  WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'permission_level', p_permission_level);
END;
$$;

-- 기존 사용자 수정 RPC의 권한 검증을 permission_level 기준으로 되돌린다.
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
  v_target_perm text;
  v_target_rank integer;
  v_target_super boolean;
  v_new_rank integer;
BEGIN
  SELECT permission_level INTO v_caller_perm
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_caller_rank := public.get_permission_rank(v_caller_perm);
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
      class_number = p_class_number,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN json_build_object('success', true);
END;
$$;

-- TASK-109에서 추가한 구매 담당 교사의 전체 주문 권한은 유지하되,
-- is_super_admin 플래그만으로 구매 범위를 넓히지는 않는다.
CREATE OR REPLACE FUNCTION public.get_purchase_order_profiles(
  p_user_ids uuid[]
)
RETURNS TABLE (
  id uuid,
  display_name text,
  username text,
  user_type text,
  department_id uuid,
  class_number integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_permission text;
  v_caller_rank integer;
  v_caller_managed_dept_id uuid;
BEGIN
  IF auth.uid() IS NULL OR COALESCE(array_length(p_user_ids, 1), 0) = 0 THEN
    RETURN;
  END IF;

  SELECT permission_level,
         public.get_permission_rank(permission_level),
         COALESCE(managed_dept_id, department_id)
  INTO v_caller_permission,
       v_caller_rank,
       v_caller_managed_dept_id
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_permission IS NULL OR v_caller_rank < 60 THEN
    RAISE EXCEPTION 'Unauthorized purchase profile access';
  END IF;

  IF v_caller_rank >= 90 OR v_caller_permission = 'purchase_teacher' THEN
    RETURN QUERY
      SELECT p.id,
             p.display_name,
             CASE WHEN v_caller_rank >= 100 THEN p.username ELSE NULL END,
             p.user_type,
             p.department_id,
             p.class_number
      FROM public.profiles p
      WHERE p.id = ANY(p_user_ids)
        AND EXISTS (
          SELECT 1 FROM public.product_orders o
          WHERE o.user_id = p.id OR o.prepared_by = p.id
             OR o.purchased_by = p.id OR o.delivered_by = p.id
        );
    RETURN;
  END IF;

  IF v_caller_permission IN ('chief', 'dept_teacher')
    AND v_caller_managed_dept_id IS NOT NULL THEN
    RETURN QUERY
      SELECT p.id,
             p.display_name,
             CASE WHEN v_caller_rank >= 100 THEN p.username ELSE NULL END,
             p.user_type,
             p.department_id,
             p.class_number
      FROM public.profiles p
      WHERE p.id = ANY(p_user_ids)
        AND p.department_id = v_caller_managed_dept_id
        AND EXISTS (
          SELECT 1 FROM public.product_orders o
          WHERE o.user_id = p.id OR o.prepared_by = p.id
             OR o.purchased_by = p.id OR o.delivered_by = p.id
        );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.process_product_order(
  p_order_id uuid,
  p_new_status text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.product_orders%ROWTYPE;
  v_caller_permission text;
  v_caller_managed_dept_id uuid;
  v_caller_rank integer;
  v_order_department_id uuid;
  v_purchase_result json;
  v_allowed boolean := false;
BEGIN
  SELECT * INTO v_order
  FROM public.product_orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Order not found');
  END IF;

  SELECT permission_level, managed_dept_id
  INTO v_caller_permission, v_caller_managed_dept_id
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_permission IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized purchase workflow');
  END IF;

  SELECT department_id INTO v_order_department_id
  FROM public.profiles
  WHERE id = v_order.user_id;

  v_caller_rank := public.get_permission_rank(v_caller_permission);
  IF v_caller_rank >= 90 OR v_caller_permission = 'purchase_teacher' THEN
    v_allowed := (v_order.status = 'requested' AND p_new_status IN ('preparing', 'cancelled'))
      OR (v_order.status = 'preparing' AND p_new_status IN ('purchased', 'requested'))
      OR (v_order.status = 'purchased' AND p_new_status = 'delivered');
  ELSIF v_caller_permission IN ('dept_teacher', 'chief')
    AND v_caller_managed_dept_id IS NOT NULL
    AND v_caller_managed_dept_id = v_order_department_id THEN
    v_allowed := v_order.status = 'requested' AND p_new_status IN ('preparing', 'cancelled');
  END IF;

  IF NOT v_allowed THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized order status transition');
  END IF;

  IF p_new_status = 'preparing' THEN
    UPDATE public.product_orders
    SET status = 'preparing', prepared_at = now(), prepared_by = auth.uid()
    WHERE id = v_order.id;
  ELSIF p_new_status = 'purchased' THEN
    SELECT public.use_talent(
      v_order.user_id, v_order.price,
      'Product purchase: ' || v_order.product_name, auth.uid()
    ) INTO v_purchase_result;

    IF COALESCE((v_purchase_result->>'success')::boolean, false) = false THEN
      RETURN v_purchase_result;
    END IF;

    UPDATE public.product_orders
    SET status = 'purchased', purchased_at = now(), purchased_by = auth.uid()
    WHERE id = v_order.id;
    UPDATE public.profiles
    SET pending_talent = GREATEST(COALESCE(pending_talent, 0) - v_order.price, 0)
    WHERE id = v_order.user_id;
  ELSIF p_new_status = 'delivered' THEN
    UPDATE public.product_orders
    SET status = 'delivered', delivered_at = now(), delivered_by = auth.uid()
    WHERE id = v_order.id;
  ELSIF p_new_status = 'requested' THEN
    UPDATE public.product_orders
    SET status = 'requested', prepared_at = null, prepared_by = null
    WHERE id = v_order.id;
  ELSIF p_new_status = 'cancelled' THEN
    UPDATE public.product_orders
    SET status = 'cancelled'
    WHERE id = v_order.id;
    UPDATE public.profiles
    SET pending_talent = GREATEST(COALESCE(pending_talent, 0) - v_order.price, 0)
    WHERE id = v_order.user_id;
  END IF;

  RETURN json_build_object(
    'success', true,
    'previous_status', v_order.status,
    'status', p_new_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.super_admin_change_own_permission(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.super_admin_change_own_permission(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.super_admin_change_own_permission(text) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_update_user(uuid, text, uuid, uuid, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_user(uuid, text, uuid, uuid, text, text, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user(uuid, text, uuid, uuid, text, text, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.get_purchase_order_profiles(uuid[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_purchase_order_profiles(uuid[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_purchase_order_profiles(uuid[]) TO authenticated;
REVOKE ALL ON FUNCTION public.process_product_order(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.process_product_order(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.process_product_order(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verification
-- 1. is_super_admin=true account can only change its own permission_level via the new RPC.
-- 2. A selected teacher/chief/etc. permission follows its normal authorization rules.
-- 3. Non-super-admin calls to super_admin_change_own_permission are rejected.
