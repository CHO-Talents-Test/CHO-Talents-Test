-- TASK-109: 구매 담당 교사의 전체 구매 이력 조회 및 관리 권한
-- 실행 위치: Supabase Dashboard > SQL Editor
--
-- 구매 담당 교사(purchase_teacher)는 구매 관리 화면에서 모든 부서, 모든 사용자
-- 유형 및 권한의 주문을 조회하고 전체 구매 흐름을 관리합니다. 일반 profiles RLS는
-- 그대로 유지하며, 주문 화면에 필요한 최소 프로필 정보만 전용 RPC로 반환합니다.

BEGIN;

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
  v_caller_is_super_admin boolean;
BEGIN
  IF auth.uid() IS NULL OR COALESCE(array_length(p_user_ids, 1), 0) = 0 THEN
    RETURN;
  END IF;

  SELECT permission_level,
         public.get_permission_rank(permission_level),
         COALESCE(managed_dept_id, department_id),
         COALESCE(is_super_admin, false)
  INTO v_caller_permission,
       v_caller_rank,
       v_caller_managed_dept_id,
       v_caller_is_super_admin
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_permission IS NULL OR (v_caller_rank < 60 AND NOT v_caller_is_super_admin) THEN
    RAISE EXCEPTION 'Unauthorized purchase profile access';
  END IF;

  IF v_caller_is_super_admin THEN
    v_caller_rank := 110;
  END IF;

  -- 전도사님 이상과 구매 담당 교사는 전체 주문자의 최소 식별 정보를 조회한다.
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
          SELECT 1
          FROM public.product_orders o
          WHERE o.user_id = p.id
             OR o.prepared_by = p.id
             OR o.purchased_by = p.id
             OR o.delivered_by = p.id
        );
    RETURN;
  END IF;

  -- 부장/부서 담당 교사는 기존 구매 관리 범위인 담당 부서 계정만 반환한다.
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
          SELECT 1
          FROM public.product_orders o
          WHERE o.user_id = p.id
             OR o.prepared_by = p.id
             OR o.purchased_by = p.id
             OR o.delivered_by = p.id
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
  v_caller_is_super_admin boolean;
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

  SELECT permission_level,
         managed_dept_id,
         COALESCE(is_super_admin, false)
  INTO v_caller_permission,
       v_caller_managed_dept_id,
       v_caller_is_super_admin
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_permission IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized purchase workflow');
  END IF;

  SELECT department_id
  INTO v_order_department_id
  FROM public.profiles
  WHERE id = v_order.user_id;

  v_caller_rank := public.get_permission_rank(v_caller_permission);
  IF v_caller_is_super_admin THEN
    v_caller_rank := 110;
  END IF;

  -- 구매 담당 교사는 전도사님 이상과 동일하게 전체 부서의 모든 구매 단계를 처리한다.
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
      v_order.user_id,
      v_order.price,
      'Product purchase: ' || v_order.product_name,
      auth.uid()
    )
    INTO v_purchase_result;

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

REVOKE ALL ON FUNCTION public.get_purchase_order_profiles(uuid[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_purchase_order_profiles(uuid[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_purchase_order_profiles(uuid[]) TO authenticated;

REVOKE ALL ON FUNCTION public.process_product_order(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.process_product_order(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.process_product_order(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verification
-- 1. purchase_teacher: all-department order buyer names/departments are shown.
-- 2. purchase_teacher: requested -> preparing/cancelled, preparing -> purchased/requested,
--    purchased -> delivered transitions work for every department.
-- 3. dept_teacher/chief: existing managed-department order and profile scope remains unchanged.
