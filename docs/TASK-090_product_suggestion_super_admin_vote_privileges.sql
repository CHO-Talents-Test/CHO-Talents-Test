-- ============================================================
-- TASK-090: 상품 추천 투표 최고관리자 특례 권한
-- - 진행 중 익명 득표/정원 열람은 profiles.is_super_admin=true만 가능
-- - 채택·불채택 직접 결정과 현재 유효 정원 기준 종료도 최고관리자만 가능
-- - 일반 관리자(100)는 일반 투표자와 동일하게 종료 전 집계를 보지 못한다.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.vote_product_suggestion(
  p_suggestion_id uuid,
  p_vote text
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
  v_is_super_admin boolean := COALESCE((
    SELECT p.is_super_admin
    FROM public.profiles p
    WHERE p.id = auth.uid()
  ), false);
BEGIN
  IF auth.uid() IS NULL OR COALESCE((
    SELECT public.get_permission_rank(p.permission_level)
    FROM public.profiles p WHERE p.id = auth.uid()
  ), 0) < 60 THEN
    RAISE EXCEPTION '부서 담당 교사 이상의 권한이 필요합니다.';
  END IF;
  IF p_vote NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION '찬성 또는 반대 투표만 가능합니다.';
  END IF;

  SELECT * INTO v_suggestion
  FROM public.product_suggestions
  WHERE id = p_suggestion_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION '상품 추천을 찾을 수 없습니다.';
  END IF;
  IF v_suggestion.status <> 'voting' THEN
    RAISE EXCEPTION '종료된 투표에는 새로 투표하거나 기존 투표를 변경할 수 없습니다.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.product_suggestion_eligible_voters e
    WHERE e.suggestion_id = p_suggestion_id AND e.voter_id = auth.uid()
  ) THEN
    RAISE EXCEPTION '추천 등록 시점의 투표 정원에 포함되지 않아 투표할 수 없습니다.';
  END IF;

  INSERT INTO public.product_suggestion_votes (suggestion_id, voter_id, vote, updated_at)
  VALUES (p_suggestion_id, auth.uid(), p_vote, now())
  ON CONFLICT (suggestion_id, voter_id) DO UPDATE
  SET vote = EXCLUDED.vote, updated_at = now();

  SELECT COUNT(*)::integer INTO v_current_electorate
  FROM public.product_suggestion_eligible_voters e
  INNER JOIN public.profiles p ON p.id = e.voter_id
  WHERE e.suggestion_id = p_suggestion_id
    AND public.get_permission_rank(p.permission_level) >= 60;

  SELECT COUNT(*)::integer,
         COUNT(*) FILTER (WHERE v.vote = 'approve')::integer,
         COUNT(*) FILTER (WHERE v.vote = 'reject')::integer
  INTO v_vote_count, v_approve_count, v_reject_count
  FROM public.product_suggestion_votes v
  INNER JOIN public.product_suggestion_eligible_voters e
    ON e.suggestion_id = v.suggestion_id AND e.voter_id = v.voter_id
  INNER JOIN public.profiles p ON p.id = v.voter_id
  WHERE v.suggestion_id = p_suggestion_id
    AND public.get_permission_rank(p.permission_level) >= 60;

  IF v_current_electorate >= v_suggestion.electorate_majority THEN
    IF v_approve_count >= v_suggestion.electorate_majority THEN
      v_product_id := public._resolve_product_suggestion(
        p_suggestion_id, 'adopted', auth.uid(), 'snapshot_majority', v_current_electorate
      );
      v_suggestion.status := 'adopted';
    ELSIF v_reject_count >= v_suggestion.electorate_majority THEN
      PERFORM public._resolve_product_suggestion(
        p_suggestion_id, 'rejected', auth.uid(), 'snapshot_majority', v_current_electorate
      );
      v_suggestion.status := 'rejected';
    END IF;
  END IF;

  RETURN json_build_object(
    'success', true, 'suggestion_id', p_suggestion_id, 'status', v_suggestion.status,
    'adopted_product_id', v_product_id,
    'electorate_count', CASE WHEN v_is_super_admin OR v_suggestion.status <> 'voting' THEN v_suggestion.electorate_count ELSE NULL END,
    'electorate_majority', CASE WHEN v_is_super_admin OR v_suggestion.status <> 'voting' THEN v_suggestion.electorate_majority ELSE NULL END,
    'current_electorate_count', CASE WHEN v_is_super_admin OR v_suggestion.status <> 'voting' THEN v_current_electorate ELSE NULL END,
    'current_majority', CASE WHEN v_is_super_admin OR v_suggestion.status <> 'voting' THEN (v_current_electorate / 2) + 1 ELSE NULL END,
    'vote_count', CASE WHEN v_is_super_admin OR v_suggestion.status <> 'voting' THEN v_vote_count ELSE NULL END,
    'approve_count', CASE WHEN v_is_super_admin OR v_suggestion.status <> 'voting' THEN v_approve_count ELSE NULL END,
    'reject_count', CASE WHEN v_is_super_admin OR v_suggestion.status <> 'voting' THEN v_reject_count ELSE NULL END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.close_product_suggestion_vote(
  p_suggestion_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_suggestion public.product_suggestions%ROWTYPE;
  v_current_electorate integer;
  v_current_majority integer;
  v_vote_count integer;
  v_approve_count integer;
  v_reject_count integer;
  v_status text;
  v_product_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT COALESCE((
    SELECT p.is_super_admin
    FROM public.profiles p
    WHERE p.id = auth.uid()
  ), false) THEN
    RAISE EXCEPTION '최고관리자 권한이 필요합니다.';
  END IF;

  SELECT * INTO v_suggestion
  FROM public.product_suggestions
  WHERE id = p_suggestion_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION '상품 추천을 찾을 수 없습니다.';
  END IF;
  IF v_suggestion.status <> 'voting' THEN
    RETURN json_build_object('success', true, 'status', v_suggestion.status, 'already_resolved', true);
  END IF;

  SELECT COUNT(*)::integer INTO v_current_electorate
  FROM public.product_suggestion_eligible_voters e
  INNER JOIN public.profiles p ON p.id = e.voter_id
  WHERE e.suggestion_id = p_suggestion_id
    AND public.get_permission_rank(p.permission_level) >= 60;

  IF v_current_electorate >= v_suggestion.electorate_majority THEN
    RAISE EXCEPTION '등록 시점 과반 달성이 가능한 현재 투표 정원이므로 일반 투표로 완료해 주세요.';
  END IF;
  IF v_current_electorate = 0 THEN
    RAISE EXCEPTION '현재 유효한 투표자가 없어 현재 투표 기준으로 종료할 수 없습니다.';
  END IF;

  v_current_majority := (v_current_electorate / 2) + 1;
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

  IF v_approve_count >= v_current_majority THEN
    v_product_id := public._resolve_product_suggestion(
      p_suggestion_id, 'adopted', auth.uid(), 'current_eligible_majority', v_current_electorate
    );
    v_status := 'adopted';
  ELSIF v_reject_count >= v_current_majority THEN
    PERFORM public._resolve_product_suggestion(
      p_suggestion_id, 'rejected', auth.uid(), 'current_eligible_majority', v_current_electorate
    );
    v_status := 'rejected';
  ELSE
    RAISE EXCEPTION '현재 유효 투표 정원의 과반 결과가 없어 종료할 수 없습니다.';
  END IF;

  RETURN json_build_object(
    'success', true,
    'suggestion_id', p_suggestion_id,
    'status', v_status,
    'adopted_product_id', v_product_id,
    'current_electorate_count', v_current_electorate,
    'current_majority', v_current_majority,
    'vote_count', v_vote_count,
    'approve_count', v_approve_count,
    'reject_count', v_reject_count
  );
END;
$$;

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
  IF auth.uid() IS NULL OR NOT COALESCE((
    SELECT p.is_super_admin
    FROM public.profiles p
    WHERE p.id = auth.uid()
  ), false) THEN
    RAISE EXCEPTION '최고관리자 권한이 필요합니다.';
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

CREATE OR REPLACE FUNCTION public.get_product_suggestion_vote_items(
  p_filter text DEFAULT 'all'
)
RETURNS TABLE (
  suggestion_id uuid, name text, product_url text, image_url text, detail_image_url text,
  description text, price_krw integer, category text, actual_status text, display_status text,
  viewer_has_voted boolean, viewer_vote text, vote_count integer, approve_count integer,
  reject_count integer, electorate_count integer, electorate_majority integer,
  current_electorate_count integer, current_majority integer, needs_admin_close boolean,
  can_admin_close boolean, created_at timestamptz, resolved_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_super_admin boolean := COALESCE((
    SELECT p.is_super_admin
    FROM public.profiles p
    WHERE p.id = auth.uid()
  ), false);
BEGIN
  IF auth.uid() IS NULL OR COALESCE((
    SELECT public.get_permission_rank(p.permission_level) FROM public.profiles p WHERE p.id = auth.uid()
  ), 0) < 60 THEN
    RAISE EXCEPTION '부서 담당 교사 이상의 권한이 필요합니다.';
  END IF;
  IF COALESCE(p_filter, 'all') NOT IN ('all', 'completed', 'incomplete') THEN
    RAISE EXCEPTION 'invalid filter';
  END IF;

  RETURN QUERY
  WITH active_electorate AS (
    SELECT e.suggestion_id, COUNT(*)::integer AS current_electorate_count
    FROM public.product_suggestion_eligible_voters e
    INNER JOIN public.profiles p ON p.id = e.voter_id
    WHERE public.get_permission_rank(p.permission_level) >= 60
    GROUP BY e.suggestion_id
  ), vote_counts AS (
    SELECT v.suggestion_id, COUNT(*)::integer AS vote_count,
           COUNT(*) FILTER (WHERE v.vote = 'approve')::integer AS approve_count,
           COUNT(*) FILTER (WHERE v.vote = 'reject')::integer AS reject_count
    FROM public.product_suggestion_votes v
    INNER JOIN public.product_suggestion_eligible_voters e ON e.suggestion_id = v.suggestion_id AND e.voter_id = v.voter_id
    INNER JOIN public.profiles p ON p.id = v.voter_id
    WHERE public.get_permission_rank(p.permission_level) >= 60
    GROUP BY v.suggestion_id
  ), source AS (
    SELECT s.*, (viewer.vote IS NOT NULL) AS viewer_has_voted, viewer.vote AS viewer_vote,
           COALESCE(vc.vote_count, 0)::integer AS current_vote_count,
           COALESCE(vc.approve_count, 0)::integer AS current_approve_count,
           COALESCE(vc.reject_count, 0)::integer AS current_reject_count,
           COALESCE(ae.current_electorate_count, 0)::integer AS current_electorate_count
    FROM public.product_suggestions s
    LEFT JOIN public.product_suggestion_votes viewer ON viewer.suggestion_id = s.id AND viewer.voter_id = auth.uid()
    LEFT JOIN vote_counts vc ON vc.suggestion_id = s.id
    LEFT JOIN active_electorate ae ON ae.suggestion_id = s.id
    WHERE s.resolution_basis IS DISTINCT FROM 'admin_immediate'
      AND (v_is_super_admin OR EXISTS (
        SELECT 1 FROM public.product_suggestion_eligible_voters viewer_electorate
        WHERE viewer_electorate.suggestion_id = s.id AND viewer_electorate.voter_id = auth.uid()
      ))
  ), shaped AS (
    SELECT src.*, (src.current_electorate_count / 2) + 1 AS current_majority,
      CASE WHEN v_is_super_admin THEN src.status WHEN NOT src.viewer_has_voted THEN 'voting' ELSE src.status END AS visible_status,
      (src.viewer_has_voted AND src.status <> 'voting') AS viewer_completed
    FROM source src
  )
  SELECT q.id, q.name, q.product_url, q.image_url, q.detail_image_url, q.description, q.price_krw,
         q.category, q.status, q.visible_status, q.viewer_has_voted, q.viewer_vote,
         CASE WHEN v_is_super_admin OR q.status <> 'voting' THEN q.current_vote_count ELSE NULL END,
         CASE WHEN v_is_super_admin OR q.status <> 'voting' THEN q.current_approve_count ELSE NULL END,
         CASE WHEN v_is_super_admin OR q.status <> 'voting' THEN q.current_reject_count ELSE NULL END,
         CASE WHEN v_is_super_admin OR q.status <> 'voting' THEN q.electorate_count ELSE NULL END,
         CASE WHEN v_is_super_admin OR q.status <> 'voting' THEN q.electorate_majority ELSE NULL END,
         CASE WHEN v_is_super_admin OR q.status <> 'voting' THEN q.current_electorate_count ELSE NULL END,
         CASE WHEN v_is_super_admin OR q.status <> 'voting' THEN q.current_majority ELSE NULL END,
         (v_is_super_admin AND q.status = 'voting' AND q.current_electorate_count < q.electorate_majority),
         (v_is_super_admin AND q.status = 'voting' AND q.current_electorate_count > 0
          AND q.current_electorate_count < q.electorate_majority
          AND (q.current_approve_count >= q.current_majority OR q.current_reject_count >= q.current_majority)),
         q.created_at, q.resolved_at
  FROM shaped q
  WHERE COALESCE(p_filter, 'all') = 'all'
     OR (p_filter = 'completed' AND q.viewer_completed)
     OR (p_filter = 'incomplete' AND NOT q.viewer_completed)
  ORDER BY CASE WHEN q.visible_status = 'voting' THEN 0 ELSE 1 END, q.created_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.vote_product_suggestion(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_product_suggestion_vote(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_resolve_product_suggestion(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_product_suggestion_vote_items(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vote_product_suggestion(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_product_suggestion_vote(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_product_suggestion(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_product_suggestion_vote_items(text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
