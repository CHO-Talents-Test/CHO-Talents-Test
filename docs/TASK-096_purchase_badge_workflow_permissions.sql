-- TASK-096: 구매 관리 배지 및 처리 권한 정렬
-- 실행 위치: Supabase Dashboard > SQL Editor
--
-- 역할별 처리 범위
--   부서 담당 교사, 부장 교사: 관리 부서의 구매 신청 -> 상품 준비
--   구매 담당 교사: 전체 계정의 상품 준비 -> 상품 구매, 상품 구매 -> 상품 지급
--   전도사님, 관리자: 전체 계정의 각 단계 처리 (상품 준비는 구매 신청으로 되돌리기 가능)
--
-- 상품 구매 이후의 되돌리기는 달란트 원장/잔액 정합성을 위해 허용하지 않습니다.

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
    RETURN json_build_object('success', false, 'error', '주문을 찾을 수 없습니다.');
  END IF;

  SELECT permission_level, managed_dept_id
  INTO v_caller_permission, v_caller_managed_dept_id
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_permission IS NULL THEN
    RETURN json_build_object('success', false, 'error', '구매 처리 권한이 없습니다.');
  END IF;

  SELECT department_id
  INTO v_order_department_id
  FROM public.profiles
  WHERE id = v_order.user_id;

  v_caller_rank := public.get_permission_rank(v_caller_permission);

  IF v_caller_rank >= 90 THEN
    v_allowed := (v_order.status = 'requested' AND p_new_status = 'preparing')
      OR (v_order.status = 'preparing' AND p_new_status IN ('purchased', 'requested'))
      OR (v_order.status = 'purchased' AND p_new_status = 'delivered');
  ELSIF v_caller_permission = 'purchase_teacher' THEN
    v_allowed := (v_order.status = 'preparing' AND p_new_status = 'purchased')
      OR (v_order.status = 'purchased' AND p_new_status = 'delivered');
  ELSIF v_caller_permission IN ('dept_teacher', 'chief')
    AND v_caller_managed_dept_id IS NOT NULL
    AND v_caller_managed_dept_id = v_order_department_id THEN
    v_allowed := v_order.status = 'requested' AND p_new_status = 'preparing';
  END IF;

  IF NOT v_allowed THEN
    RETURN json_build_object('success', false, 'error', '현재 권한으로는 이 주문 상태를 변경할 수 없습니다.');
  END IF;

  IF p_new_status = 'preparing' THEN
    UPDATE public.product_orders
    SET status = 'preparing', prepared_at = now(), prepared_by = auth.uid()
    WHERE id = v_order.id;
  ELSIF p_new_status = 'purchased' THEN
    SELECT public.use_talent(
      v_order.user_id,
      v_order.price,
      '상품 구매: ' || v_order.product_name,
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
  END IF;

  RETURN json_build_object(
    'success', true,
    'previous_status', v_order.status,
    'status', p_new_status
  );
END;
$$;

-- 기존 호출부와의 호환성을 유지하되, 전달받은 처리자 ID는 신뢰하지 않습니다.
CREATE OR REPLACE FUNCTION public.confirm_product_purchase(
  p_order_id uuid,
  p_admin_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_admin_id IS DISTINCT FROM auth.uid() THEN
    RETURN json_build_object('success', false, 'error', '처리자 정보가 현재 로그인 계정과 일치하지 않습니다.');
  END IF;

  RETURN public.process_product_order(p_order_id, 'purchased');
END;
$$;

-- 직원의 직접 UPDATE는 차단하고, 위 RPC가 역할·부서·상태 전이를 검증하도록 합니다.
DROP POLICY IF EXISTS "Staff can update orders" ON public.product_orders;

REVOKE ALL ON FUNCTION public.process_product_order(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.process_product_order(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.process_product_order(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.confirm_product_purchase(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.confirm_product_purchase(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.confirm_product_purchase(uuid, uuid) TO authenticated;

-- PostgREST가 새 RPC 시그니처를 즉시 인식하도록 스키마 캐시를 갱신한다.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- 적용 확인
-- SELECT proname, proargnames
-- FROM pg_proc
-- WHERE pronamespace = 'public'::regnamespace
--   AND proname IN ('process_product_order', 'confirm_product_purchase');
--
-- SELECT policyname, cmd
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'product_orders'
-- ORDER BY policyname;
