-- TASK-101: 추천 상품 진행률 과반 기준 보정
-- 적용 전제: TASK-100 적용 완료
-- 총 투표 수가 아니라 찬성/반대 중 더 많은 한쪽 표가 등록 시점 과반에 도달해야 100%입니다.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_my_product_suggestions()
RETURNS TABLE (
  suggestion_id uuid, name text, product_url text, image_url text, detail_image_url text,
  description text, price_krw integer, category text, status text, adopted_product_id uuid,
  electorate_count integer, electorate_majority integer, vote_progress integer,
  created_at timestamptz, resolved_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication is required';
  END IF;

  RETURN QUERY
  SELECT s.id, s.name, s.product_url, s.image_url, s.detail_image_url, s.description,
         s.price_krw, s.category, s.status, s.adopted_product_id, s.electorate_count,
         s.electorate_majority,
         CASE
           WHEN s.resolution_basis = 'admin_immediate' OR COALESCE(s.electorate_majority, 0) <= 0 THEN NULL::integer
           ELSE LEAST(100, ROUND((GREATEST(COALESCE(vc.approve_count, 0), COALESCE(vc.reject_count, 0))::numeric / s.electorate_majority) * 100)::integer)
         END AS vote_progress,
         s.created_at, s.resolved_at
  FROM public.product_suggestions s
  LEFT JOIN LATERAL (
    SELECT COUNT(*) FILTER (WHERE v.vote = 'approve')::integer AS approve_count,
           COUNT(*) FILTER (WHERE v.vote = 'reject')::integer AS reject_count
    FROM public.product_suggestion_votes v
    INNER JOIN public.product_suggestion_eligible_voters e
      ON e.suggestion_id = v.suggestion_id AND e.voter_id = v.voter_id
    INNER JOIN public.profiles p ON p.id = v.voter_id
    WHERE v.suggestion_id = s.id
      AND public.get_permission_rank(p.permission_level) >= 60
  ) vc ON true
  WHERE s.suggested_by = auth.uid()
  ORDER BY s.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_product_suggestion_vote_items(
  p_filter text DEFAULT 'all'
)
RETURNS TABLE (
  suggestion_id uuid, name text, product_url text, image_url text, detail_image_url text,
  description text, price_krw integer, category text, actual_status text, display_status text,
  viewer_has_voted boolean, viewer_vote text, vote_count integer, vote_progress integer,
  approve_count integer, reject_count integer, electorate_count integer, electorate_majority integer,
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
    INNER JOIN public.product_suggestion_eligible_voters e
      ON e.suggestion_id = v.suggestion_id AND e.voter_id = v.voter_id
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
    LEFT JOIN public.product_suggestion_votes viewer
      ON viewer.suggestion_id = s.id AND viewer.voter_id = auth.uid()
    LEFT JOIN vote_counts vc ON vc.suggestion_id = s.id
    LEFT JOIN active_electorate ae ON ae.suggestion_id = s.id
    WHERE s.resolution_basis IS DISTINCT FROM 'admin_immediate'
      AND (v_is_super_admin OR EXISTS (
        SELECT 1
        FROM public.product_suggestion_eligible_voters viewer_electorate
        WHERE viewer_electorate.suggestion_id = s.id
          AND viewer_electorate.voter_id = auth.uid()
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
         CASE
           WHEN COALESCE(q.electorate_majority, 0) <= 0 THEN NULL::integer
           ELSE LEAST(100, ROUND((GREATEST(q.current_approve_count, q.current_reject_count)::numeric / q.electorate_majority) * 100)::integer)
         END,
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

NOTIFY pgrst, 'reload schema';

COMMIT;
