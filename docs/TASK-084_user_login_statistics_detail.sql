-- ============================================================
-- TASK-084: 사용자 통계 상세 조회
-- 관리자(100+)가 사용자 통계의 각 행에서 안전하게 상세 목록을
-- 조회할 수 있도록 전용 RPC를 추가합니다.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_user_login_stat_detail(
  p_group_type text,
  p_group_key text,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_department_id uuid DEFAULT NULL,
  p_user_type text DEFAULT NULL
)
RETURNS TABLE (
  user_id uuid,
  username text,
  display_name text,
  department_name text,
  permission_level text,
  login_count bigint,
  last_logged_in_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR COALESCE(public.get_permission_rank(auth.uid()), 0) < 100 THEN
    RAISE EXCEPTION 'insufficient permission';
  END IF;

  IF p_group_type IS NULL OR p_group_type NOT IN ('date', 'weekday', 'hour', 'department', 'user') THEN
    RAISE EXCEPTION 'invalid group type';
  END IF;

  IF NULLIF(BTRIM(p_group_key), '') IS NULL THEN
    RAISE EXCEPTION 'group key is required';
  END IF;

  IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_start_date > p_end_date THEN
    RAISE EXCEPTION 'invalid date range';
  END IF;

  IF p_user_type IS NOT NULL AND p_user_type NOT IN ('student', 'teacher') THEN
    RAISE EXCEPTION 'invalid user type';
  END IF;

  IF p_group_type = 'user' THEN
    RETURN QUERY
    WITH filtered AS (
      SELECT
        h.user_id,
        h.username,
        h.display_name,
        h.department_name,
        h.permission_level,
        h.logged_in_at
      FROM public.user_login_history h
      INNER JOIN public.profiles p ON p.id = h.user_id
      WHERE COALESCE(p.is_super_admin, false) = false
        AND (p_start_date IS NULL OR (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date >= p_start_date)
        AND (p_end_date IS NULL OR (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date <= p_end_date)
        AND (p_department_id IS NULL OR h.department_id = p_department_id)
        AND (p_user_type IS NULL OR p.user_type = p_user_type)
    )
    SELECT
      f.user_id,
      f.username,
      f.display_name,
      f.department_name,
      f.permission_level,
      1::bigint AS login_count,
      f.logged_in_at AS last_logged_in_at
    FROM filtered f
    WHERE f.user_id::text = p_group_key
    ORDER BY f.logged_in_at DESC;
    RETURN;
  END IF;

  RETURN QUERY
  WITH filtered AS (
    SELECT
      h.user_id,
      h.username,
      h.display_name,
      h.department_id,
      h.department_name,
      h.permission_level,
      h.logged_in_at,
      (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date AS login_date,
      EXTRACT(ISODOW FROM h.logged_in_at AT TIME ZONE 'Asia/Seoul')::integer AS weekday_number,
      EXTRACT(HOUR FROM h.logged_in_at AT TIME ZONE 'Asia/Seoul')::integer AS hour_number
    FROM public.user_login_history h
    INNER JOIN public.profiles p ON p.id = h.user_id
    WHERE COALESCE(p.is_super_admin, false) = false
      AND (p_start_date IS NULL OR (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date >= p_start_date)
      AND (p_end_date IS NULL OR (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date <= p_end_date)
      AND (p_department_id IS NULL OR h.department_id = p_department_id)
      AND (p_user_type IS NULL OR p.user_type = p_user_type)
  ),
  matched AS (
    SELECT *
    FROM filtered f
    WHERE (p_group_type = 'date' AND f.login_date::text = p_group_key)
       OR (p_group_type = 'weekday' AND f.weekday_number::text = p_group_key)
       OR (p_group_type = 'hour' AND f.hour_number::text = p_group_key)
       OR (p_group_type = 'department' AND COALESCE(f.department_id::text, 'unassigned') = p_group_key)
  ),
  user_counts AS (
    SELECT
      m.user_id,
      COUNT(*)::bigint AS login_count,
      MAX(m.logged_in_at) AS last_logged_in_at
    FROM matched m
    GROUP BY m.user_id
  ),
  latest_user_snapshot AS (
    SELECT DISTINCT ON (m.user_id)
      m.user_id,
      m.username,
      m.display_name,
      m.department_name,
      m.permission_level
    FROM matched m
    ORDER BY m.user_id, m.logged_in_at DESC
  )
  SELECT
    s.user_id,
    s.username,
    s.display_name,
    s.department_name,
    s.permission_level,
    c.login_count,
    c.last_logged_in_at
  FROM user_counts c
  INNER JOIN latest_user_snapshot s ON s.user_id = c.user_id
  ORDER BY c.login_count DESC, c.last_logged_in_at DESC, COALESCE(s.display_name, s.username, '');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_login_stat_detail(text, text, date, date, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_login_stat_detail(text, text, date, date, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
