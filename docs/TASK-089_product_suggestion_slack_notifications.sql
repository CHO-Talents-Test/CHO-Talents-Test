-- ============================================================
-- TASK-089: 상품 추천 투표 종료 Slack 알림용 집계 반환
-- - 관리자 직접 결정 RPC도 종료 시점의 익명 찬성/반대/총 투표 수를 반환한다.
-- - 브라우저는 이 결과로 운영관리 Slack 채널에 상품명·결과·득표만 알린다.
-- - 추천자와 개별 투표자 식별 정보는 반환하거나 Slack으로 전송하지 않는다.
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
  v_vote_count integer;
  v_approve_count integer;
  v_reject_count integer;
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

  SELECT
    COUNT(*)::integer,
    COUNT(*) FILTER (WHERE v.vote = 'approve')::integer,
    COUNT(*) FILTER (WHERE v.vote = 'reject')::integer
  INTO v_vote_count, v_approve_count, v_reject_count
  FROM public.product_suggestion_votes v
  INNER JOIN public.product_suggestion_eligible_voters e
    ON e.suggestion_id = v.suggestion_id AND e.voter_id = v.voter_id
  INNER JOIN public.profiles p ON p.id = v.voter_id
  WHERE v.suggestion_id = p_suggestion_id
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
    'vote_count', v_vote_count,
    'approve_count', v_approve_count,
    'reject_count', v_reject_count,
    'resolution_basis', 'admin_override'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_resolve_product_suggestion(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_product_suggestion(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
