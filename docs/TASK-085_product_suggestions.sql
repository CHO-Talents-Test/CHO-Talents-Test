-- ============================================================
-- TASK-085: 상품 추천 및 비밀 투표
-- - 모든 로그인 사용자의 상품 추천 등록
-- - 추천 등록 시점의 60등급 이상 투표 정원 스냅샷
-- - 비밀 투표 결과 노출 제어와 관리자 현황/종료 처리
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.product_suggestions (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  name text NOT NULL,
  product_url text,
  image_url text,
  description text,
  price_krw integer,
  category text NOT NULL DEFAULT 'gift',
  status text NOT NULL DEFAULT 'voting'
    CHECK (status IN ('voting', 'adopted', 'rejected')),
  suggested_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  electorate_count integer NOT NULL DEFAULT 0 CHECK (electorate_count >= 0),
  electorate_majority integer NOT NULL DEFAULT 1 CHECK (electorate_majority >= 1),
  adopted_product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  resolved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  resolution_basis text,
  current_electorate_at_resolution integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT product_suggestions_url_or_image_check
    CHECK (NULLIF(BTRIM(COALESCE(product_url, '')), '') IS NOT NULL
        OR NULLIF(BTRIM(COALESCE(image_url, '')), '') IS NOT NULL),
  CONSTRAINT product_suggestions_price_krw_check
    CHECK (price_krw IS NULL OR price_krw >= 0)
);

CREATE TABLE IF NOT EXISTS public.product_suggestion_eligible_voters (
  suggestion_id uuid NOT NULL REFERENCES public.product_suggestions(id) ON DELETE CASCADE,
  voter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (suggestion_id, voter_id)
);

CREATE TABLE IF NOT EXISTS public.product_suggestion_votes (
  suggestion_id uuid NOT NULL REFERENCES public.product_suggestions(id) ON DELETE CASCADE,
  voter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vote text NOT NULL CHECK (vote IN ('approve', 'reject')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (suggestion_id, voter_id)
);

CREATE INDEX IF NOT EXISTS idx_product_suggestions_status_created
  ON public.product_suggestions(status, created_at);
CREATE INDEX IF NOT EXISTS idx_product_suggestions_suggested_by_created
  ON public.product_suggestions(suggested_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_suggestion_votes_suggestion
  ON public.product_suggestion_votes(suggestion_id, vote);

CREATE OR REPLACE FUNCTION public._resolve_product_suggestion(
  p_suggestion_id uuid,
  p_status text,
  p_actor_id uuid,
  p_resolution_basis text,
  p_current_electorate integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_suggestion public.product_suggestions%ROWTYPE;
  v_product_id uuid;
BEGIN
  IF p_status NOT IN ('adopted', 'rejected') THEN
    RAISE EXCEPTION 'invalid resolution status';
  END IF;

  SELECT * INTO v_suggestion
  FROM public.product_suggestions
  WHERE id = p_suggestion_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'product suggestion not found';
  END IF;

  IF v_suggestion.status <> 'voting' THEN
    RETURN v_suggestion.adopted_product_id;
  END IF;

  IF p_status = 'adopted' THEN
    INSERT INTO public.products (
      name,
      description,
      price,
      image_emoji,
      image_url,
      purchase_url,
      target_role,
      category,
      sort_order,
      stock,
      is_active,
      created_by
    ) VALUES (
      v_suggestion.name,
      v_suggestion.description,
      0,
      '🎁',
      v_suggestion.image_url,
      v_suggestion.product_url,
      'student',
      COALESCE(NULLIF(BTRIM(v_suggestion.category), ''), 'gift'),
      0,
      0,
      false,
      v_suggestion.suggested_by
    )
    RETURNING id INTO v_product_id;
  END IF;

  UPDATE public.product_suggestions
  SET status = p_status,
      adopted_product_id = CASE WHEN p_status = 'adopted' THEN v_product_id ELSE NULL END,
      resolved_by = p_actor_id,
      resolved_at = now(),
      resolution_basis = p_resolution_basis,
      current_electorate_at_resolution = p_current_electorate,
      updated_at = now()
  WHERE id = p_suggestion_id;

  RETURN v_product_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_product_suggestion(
  p_id uuid,
  p_name text,
  p_product_url text,
  p_image_url text,
  p_description text,
  p_price_krw integer,
  p_category text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid := COALESCE(p_id, extensions.gen_random_uuid());
  v_name text := NULLIF(BTRIM(p_name), '');
  v_product_url text := NULLIF(BTRIM(p_product_url), '');
  v_image_url text := NULLIF(BTRIM(p_image_url), '');
  v_description text := NULLIF(BTRIM(p_description), '');
  v_category text := COALESCE(NULLIF(BTRIM(p_category), ''), 'gift');
  v_electorate_count integer;
  v_majority integer;
  v_rank integer;
  v_product_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication is required';
  END IF;
  IF v_name IS NULL THEN
    RAISE EXCEPTION '상품명을 입력해주세요.';
  END IF;
  IF v_product_url IS NULL AND v_image_url IS NULL THEN
    RAISE EXCEPTION '상품 URL 또는 이미지를 하나 이상 입력해주세요.';
  END IF;
  IF v_product_url IS NOT NULL AND v_product_url !~* '^https?://' THEN
    RAISE EXCEPTION '상품 URL은 http 또는 https 주소로 입력해주세요.';
  END IF;
  IF v_image_url IS NOT NULL AND v_image_url !~* '^https?://' THEN
    RAISE EXCEPTION '이미지 URL은 http 또는 https 주소로 입력해주세요.';
  END IF;
  IF p_price_krw IS NOT NULL AND p_price_krw < 0 THEN
    RAISE EXCEPTION '금액은 0원 이상으로 입력해주세요.';
  END IF;

  SELECT COUNT(*)::integer INTO v_electorate_count
  FROM public.profiles p
  WHERE public.get_permission_rank(p.permission_level) >= 60;
  v_majority := (v_electorate_count / 2) + 1;

  INSERT INTO public.product_suggestions (
    id, name, product_url, image_url, description, price_krw, category,
    suggested_by, electorate_count, electorate_majority
  ) VALUES (
    v_id, v_name, v_product_url, v_image_url, v_description, p_price_krw, v_category,
    auth.uid(), v_electorate_count, v_majority
  );

  INSERT INTO public.product_suggestion_eligible_voters (suggestion_id, voter_id)
  SELECT v_id, p.id
  FROM public.profiles p
  WHERE public.get_permission_rank(p.permission_level) >= 60;

  SELECT COALESCE(public.get_permission_rank(p.permission_level), 0)
  INTO v_rank
  FROM public.profiles p
  WHERE p.id = auth.uid();
  IF v_rank >= 100 THEN
    v_product_id := public._resolve_product_suggestion(
      v_id, 'adopted', auth.uid(), 'admin_immediate', v_electorate_count
    );
    RETURN json_build_object(
      'success', true,
      'suggestion_id', v_id,
      'status', 'adopted',
      'adopted_product_id', v_product_id,
      'electorate_count', v_electorate_count,
      'electorate_majority', v_majority
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'suggestion_id', v_id,
    'status', 'voting',
    'electorate_count', v_electorate_count,
    'electorate_majority', v_majority
  );
END;
$$;

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
BEGIN
  IF auth.uid() IS NULL OR COALESCE((
    SELECT public.get_permission_rank(p.permission_level)
    FROM public.profiles p
    WHERE p.id = auth.uid()
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.product_suggestion_eligible_voters e
    WHERE e.suggestion_id = p_suggestion_id
      AND e.voter_id = auth.uid()
  ) THEN
    RAISE EXCEPTION '추천 등록 시점의 투표 정원에 포함되지 않아 투표할 수 없습니다.';
  END IF;

  IF v_suggestion.status <> 'voting' AND EXISTS (
    SELECT 1
    FROM public.product_suggestion_votes v
    WHERE v.suggestion_id = p_suggestion_id
      AND v.voter_id = auth.uid()
  ) THEN
    RAISE EXCEPTION '완료된 투표는 변경할 수 없습니다.';
  END IF;

  INSERT INTO public.product_suggestion_votes (suggestion_id, voter_id, vote, updated_at)
  VALUES (p_suggestion_id, auth.uid(), p_vote, now())
  ON CONFLICT (suggestion_id, voter_id) DO UPDATE
  SET vote = EXCLUDED.vote,
      updated_at = now();

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

  IF v_suggestion.status = 'voting'
     AND v_current_electorate >= v_suggestion.electorate_majority THEN
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
    'success', true,
    'suggestion_id', p_suggestion_id,
    'status', v_suggestion.status,
    'adopted_product_id', v_product_id,
    'electorate_count', v_suggestion.electorate_count,
    'electorate_majority', v_suggestion.electorate_majority,
    'current_electorate_count', v_current_electorate,
    'current_majority', (v_current_electorate / 2) + 1,
    'vote_count', v_vote_count,
    'approve_count', v_approve_count,
    'reject_count', v_reject_count
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
  IF auth.uid() IS NULL OR COALESCE((
    SELECT public.get_permission_rank(p.permission_level)
    FROM public.profiles p
    WHERE p.id = auth.uid()
  ), 0) < 100 THEN
    RAISE EXCEPTION '관리자 권한이 필요합니다.';
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
    RAISE EXCEPTION '등록 시점 과반을 달성할 수 있는 현재 투표 정원이므로 일반 투표로 완료해주세요.';
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

CREATE OR REPLACE FUNCTION public.get_my_product_suggestions()
RETURNS TABLE (
  suggestion_id uuid,
  name text,
  product_url text,
  image_url text,
  description text,
  price_krw integer,
  category text,
  status text,
  adopted_product_id uuid,
  electorate_count integer,
  electorate_majority integer,
  created_at timestamptz,
  resolved_at timestamptz
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
  SELECT
    s.id,
    s.name,
    s.product_url,
    s.image_url,
    s.description,
    s.price_krw,
    s.category,
    s.status,
    s.adopted_product_id,
    s.electorate_count,
    s.electorate_majority,
    s.created_at,
    s.resolved_at
  FROM public.product_suggestions s
  WHERE s.suggested_by = auth.uid()
  ORDER BY s.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_product_suggestion_vote_items(
  p_filter text DEFAULT 'all'
)
RETURNS TABLE (
  suggestion_id uuid,
  name text,
  product_url text,
  image_url text,
  description text,
  price_krw integer,
  category text,
  actual_status text,
  display_status text,
  viewer_has_voted boolean,
  viewer_vote text,
  vote_count integer,
  approve_count integer,
  reject_count integer,
  electorate_count integer,
  electorate_majority integer,
  current_electorate_count integer,
  current_majority integer,
  needs_admin_close boolean,
  can_admin_close boolean,
  created_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_admin boolean := COALESCE((
    SELECT public.get_permission_rank(p.permission_level)
    FROM public.profiles p
    WHERE p.id = auth.uid()
  ), 0) >= 100;
BEGIN
  IF auth.uid() IS NULL OR COALESCE((
    SELECT public.get_permission_rank(p.permission_level)
    FROM public.profiles p
    WHERE p.id = auth.uid()
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
  ),
  vote_counts AS (
    SELECT
      v.suggestion_id,
      COUNT(*)::integer AS vote_count,
      COUNT(*) FILTER (WHERE v.vote = 'approve')::integer AS approve_count,
      COUNT(*) FILTER (WHERE v.vote = 'reject')::integer AS reject_count
    FROM public.product_suggestion_votes v
    INNER JOIN public.product_suggestion_eligible_voters e
      ON e.suggestion_id = v.suggestion_id AND e.voter_id = v.voter_id
    INNER JOIN public.profiles p ON p.id = v.voter_id
    WHERE public.get_permission_rank(p.permission_level) >= 60
    GROUP BY v.suggestion_id
  ),
  source AS (
    SELECT
      s.*,
      (viewer.vote IS NOT NULL) AS viewer_has_voted,
      viewer.vote AS viewer_vote,
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
      AND (
        v_is_admin
        OR EXISTS (
          SELECT 1
          FROM public.product_suggestion_eligible_voters viewer_electorate
          WHERE viewer_electorate.suggestion_id = s.id
            AND viewer_electorate.voter_id = auth.uid()
        )
      )
  ),
  shaped AS (
    SELECT
      src.*,
      (src.current_electorate_count / 2) + 1 AS current_majority,
      CASE
        WHEN v_is_admin THEN src.status
        WHEN NOT src.viewer_has_voted THEN 'voting'
        ELSE src.status
      END AS visible_status,
      (src.viewer_has_voted AND src.status <> 'voting') AS viewer_completed
    FROM source src
  )
  SELECT
    q.id,
    q.name,
    q.product_url,
    q.image_url,
    q.description,
    q.price_krw,
    q.category,
    q.status,
    q.visible_status,
    q.viewer_has_voted,
    q.viewer_vote,
    CASE WHEN v_is_admin OR q.viewer_has_voted THEN q.current_vote_count ELSE NULL END,
    CASE WHEN v_is_admin OR q.viewer_has_voted THEN q.current_approve_count ELSE NULL END,
    CASE WHEN v_is_admin OR q.viewer_has_voted THEN q.current_reject_count ELSE NULL END,
    q.electorate_count,
    q.electorate_majority,
    q.current_electorate_count,
    q.current_majority,
    (q.status = 'voting' AND q.current_electorate_count < q.electorate_majority),
    (
      v_is_admin
      AND q.status = 'voting'
      AND q.current_electorate_count > 0
      AND q.current_electorate_count < q.electorate_majority
      AND (q.current_approve_count >= q.current_majority OR q.current_reject_count >= q.current_majority)
    ),
    q.created_at,
    q.resolved_at
  FROM shaped q
  WHERE COALESCE(p_filter, 'all') = 'all'
     OR (p_filter = 'completed' AND q.viewer_completed)
     OR (p_filter = 'incomplete' AND NOT q.viewer_completed)
  ORDER BY
    CASE WHEN q.visible_status = 'voting' THEN 0 ELSE 1 END,
    q.created_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_unvoted_product_suggestion_count()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count integer;
BEGIN
  IF auth.uid() IS NULL OR COALESCE((
    SELECT public.get_permission_rank(p.permission_level)
    FROM public.profiles p
    WHERE p.id = auth.uid()
  ), 0) < 60 THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*)::integer INTO v_count
  FROM public.product_suggestions s
  INNER JOIN public.product_suggestion_eligible_voters e
    ON e.suggestion_id = s.id AND e.voter_id = auth.uid()
  LEFT JOIN public.product_suggestion_votes v
    ON v.suggestion_id = s.id AND v.voter_id = auth.uid()
  WHERE v.suggestion_id IS NULL
    AND s.resolution_basis IS DISTINCT FROM 'admin_immediate';

  RETURN COALESCE(v_count, 0);
END;
$$;

ALTER TABLE public.product_suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_suggestion_eligible_voters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_suggestion_votes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.product_suggestions FROM anon, authenticated;
REVOKE ALL ON public.product_suggestion_eligible_voters FROM anon, authenticated;
REVOKE ALL ON public.product_suggestion_votes FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public._resolve_product_suggestion(uuid, text, uuid, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.submit_product_suggestion(uuid, text, text, text, text, integer, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.vote_product_suggestion(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_product_suggestion_vote(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_my_product_suggestions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_product_suggestion_vote_items(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_unvoted_product_suggestion_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_product_suggestion(uuid, text, text, text, text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vote_product_suggestion(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_product_suggestion_vote(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_product_suggestions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_product_suggestion_vote_items(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_unvoted_product_suggestion_count() TO authenticated;

DROP POLICY IF EXISTS "Suggestion image upload" ON storage.objects;
CREATE POLICY "Suggestion image upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'Talents_Items'
    AND name LIKE 'product-suggestions/%'
    AND owner_id::text = auth.uid()::text
  );

DROP POLICY IF EXISTS "Suggestion image update" ON storage.objects;
CREATE POLICY "Suggestion image update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'Talents_Items'
    AND name LIKE 'product-suggestions/%'
    AND owner_id::text = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'Talents_Items'
    AND name LIKE 'product-suggestions/%'
    AND owner_id::text = auth.uid()::text
  );

DROP POLICY IF EXISTS "Suggestion image delete" ON storage.objects;
CREATE POLICY "Suggestion image delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'Talents_Items'
    AND name LIKE 'product-suggestions/%'
    AND owner_id::text = auth.uid()::text
  );

INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
VALUES
  ('activity_logs.action', 'PRODUCT_SUGGESTION_CREATE', '상품 추천 등록', 5150, '{"category":"ORDER","emoji":"💡"}'),
  ('activity_logs.action', 'PRODUCT_SUGGESTION_CREATE_FAIL', '상품 추천 등록 실패', 5151, '{"category":"ORDER","emoji":"⚠️"}'),
  ('activity_logs.action', 'PRODUCT_SUGGESTION_ADOPT', '추천 상품 채택', 5153, '{"category":"ORDER","emoji":"✅"}'),
  ('activity_logs.action', 'PRODUCT_SUGGESTION_REJECT', '추천 상품 불채택', 5154, '{"category":"ORDER","emoji":"❌"}'),
  ('activity_logs.action', 'PRODUCT_SUGGESTION_CLOSE', '추천 상품 투표 종료', 5155, '{"category":"ORDER","emoji":"⏹️"}')
ON CONFLICT (group_key, code_key) DO UPDATE
SET code_value = EXCLUDED.code_value,
    sort_order = EXCLUDED.sort_order,
    meta = EXCLUDED.meta,
    is_active = true,
    updated_at = now();

NOTIFY pgrst, 'reload schema';

COMMIT;
