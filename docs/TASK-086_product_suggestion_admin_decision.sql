-- ============================================================
-- TASK-086: 관리자 상품 추천 예외 결정
-- - 관리자(100+)가 투표 완료 전에도 추천 상품을 채택/불채택 처리
-- - 기존 현재 유효 정원 기준 투표 종료 규칙은 변경하지 않음
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_resolve_product_suggestion(
  p_suggestion_id uuid,
  p_status text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_suggestion public.product_suggestions%ROWTYPE;
  v_current_electorate integer;
  v_product_id uuid;
BEGIN
  IF auth.uid() IS NULL OR COALESCE((
    SELECT public.get_permission_rank(p.permission_level)
    FROM public.profiles p
    WHERE p.id = auth.uid()
  ), 0) < 100 THEN
    RAISE EXCEPTION '관리자 권한이 필요합니다.';
  END IF;

  IF p_status NOT IN ('adopted', 'rejected') THEN
    RAISE EXCEPTION '채택 또는 불채택 상태만 처리할 수 있습니다.';
  END IF;

  SELECT * INTO v_suggestion
  FROM public.product_suggestions
  WHERE id = p_suggestion_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '상품 추천을 찾을 수 없습니다.';
  END IF;

  IF v_suggestion.status <> 'voting' THEN
    RETURN json_build_object(
      'success', true,
      'status', v_suggestion.status,
      'already_resolved', true,
      'adopted_product_id', v_suggestion.adopted_product_id
    );
  END IF;

  SELECT COUNT(*)::integer INTO v_current_electorate
  FROM public.product_suggestion_eligible_voters e
  INNER JOIN public.profiles p ON p.id = e.voter_id
  WHERE e.suggestion_id = p_suggestion_id
    AND public.get_permission_rank(p.permission_level) >= 60;

  v_product_id := public._resolve_product_suggestion(
    p_suggestion_id,
    p_status,
    auth.uid(),
    'admin_override',
    v_current_electorate
  );

  RETURN json_build_object(
    'success', true,
    'suggestion_id', p_suggestion_id,
    'status', p_status,
    'adopted_product_id', v_product_id,
    'current_electorate_count', v_current_electorate,
    'resolution_basis', 'admin_override'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_resolve_product_suggestion(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_product_suggestion(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
