-- TASK-098: Purchase-request cancellation authority
-- Run this script in Supabase Dashboard > SQL Editor after TASK-096.
--
-- Cancellation is limited to orders in the requested state. It releases the
-- buyer's pending_talent reservation because no purchase has been confirmed.
--
-- Authorized scopes
--   * evangelist and above: every department
--   * dept_teacher and chief: users in their managed department only
--   * purchase_teacher: no independent cancellation authority. This role has
--     no requested -> preparing authority in the current workflow, so it must
--     not receive requested -> cancelled authority either.

BEGIN;

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

  SELECT department_id
  INTO v_order_department_id
  FROM public.profiles
  WHERE id = v_order.user_id;

  v_caller_rank := public.get_permission_rank(v_caller_permission);

  IF v_caller_rank >= 90 THEN
    v_allowed := (v_order.status = 'requested' AND p_new_status IN ('preparing', 'cancelled'))
      OR (v_order.status = 'preparing' AND p_new_status IN ('purchased', 'requested'))
      OR (v_order.status = 'purchased' AND p_new_status = 'delivered');
  ELSIF v_caller_permission = 'purchase_teacher' THEN
    v_allowed := (v_order.status = 'preparing' AND p_new_status = 'purchased')
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

INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, is_active, meta)
VALUES
  ('activity_logs.action', 'ORDER_PURCHASE_CANCEL', '구매 취소 처리', 5115, true, '{"category":"ORDER","emoji":"❌","source":"TASK-098"}'::jsonb),
  ('activity_logs.action', 'ORDER_PURCHASE_CANCEL_FAIL', '구매 취소 처리 실패', 5116, true, '{"category":"ORDER","emoji":"⚠️","source":"TASK-098"}'::jsonb),
  ('activity_logs.action', 'ORDER_PURCHASE_CANCEL_ERROR', '구매 취소 처리 오류', 5117, true, '{"category":"ORDER","emoji":"⚠️","source":"TASK-098"}'::jsonb)
ON CONFLICT (group_key, code_key) DO UPDATE
SET code_value = EXCLUDED.code_value,
    sort_order = EXCLUDED.sort_order,
    is_active = true,
    meta = EXCLUDED.meta,
    updated_at = now();

REVOKE ALL ON FUNCTION public.process_product_order(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.process_product_order(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.process_product_order(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verification
-- 1. A requested order in the caller's managed department can be changed to cancelled.
-- 2. An order in another department and every non-requested order are rejected.
-- 3. The matching profile.pending_talent is reduced by the order price.
