-- ============================================================
-- TASK-091: 사용자 통계 사용자 유형 필터
-- 관리자(100+)가 학생/교사로 로그인 이력을 분리해 집계·상세 조회합니다.
-- 기존 TASK-081, TASK-084 RPC를 이 파일로 교체 적용합니다.
-- ============================================================

BEGIN;

DROP FUNCTION IF EXISTS public.get_user_login_statistics(date, date, uuid);
DROP FUNCTION IF EXISTS public.get_user_login_stat_detail(text, text, date, date, uuid);

CREATE OR REPLACE FUNCTION public.get_user_login_statistics(
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_department_id uuid DEFAULT NULL,
  p_user_type text DEFAULT NULL
)
RETURNS TABLE (
  group_type text,
  group_key text,
  group_label text,
  login_count bigint,
  user_count bigint,
  sort_order integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR COALESCE(public.get_permission_rank(auth.uid()), 0) < 100 THEN
    RAISE EXCEPTION 'insufficient permission';
  END IF;
  IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_start_date > p_end_date THEN
    RAISE EXCEPTION 'invalid date range';
  END IF;
  IF p_user_type IS NOT NULL AND p_user_type NOT IN ('student', 'teacher') THEN
    RAISE EXCEPTION 'invalid user type';
  END IF;

  RETURN QUERY
  WITH filtered AS (
    SELECT
      h.user_id, h.username, h.display_name, h.department_id, h.department_name,
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
  )
  SELECT 'date'::text, f.login_date::text, TO_CHAR(f.login_date, 'YYYY.MM.DD'),
    COUNT(*)::bigint, COUNT(DISTINCT f.user_id)::bigint, (f.login_date - DATE '2000-01-01')::integer
  FROM filtered f GROUP BY f.login_date
  UNION ALL
  SELECT 'weekday'::text, f.weekday_number::text,
    CASE f.weekday_number WHEN 1 THEN '월요일' WHEN 2 THEN '화요일' WHEN 3 THEN '수요일'
      WHEN 4 THEN '목요일' WHEN 5 THEN '금요일' WHEN 6 THEN '토요일' WHEN 7 THEN '일요일' END,
    COUNT(*)::bigint, COUNT(DISTINCT f.user_id)::bigint, f.weekday_number
  FROM filtered f GROUP BY f.weekday_number
  UNION ALL
  SELECT 'hour'::text, f.hour_number::text, LPAD(f.hour_number::text, 2, '0') || ':00',
    COUNT(*)::bigint, COUNT(DISTINCT f.user_id)::bigint, f.hour_number
  FROM filtered f GROUP BY f.hour_number
  UNION ALL
  SELECT 'department'::text, COALESCE(f.department_id::text, 'unassigned'),
    COALESCE(NULLIF(f.department_name, ''), '미배정'), COUNT(*)::bigint,
    COUNT(DISTINCT f.user_id)::bigint, 0
  FROM filtered f GROUP BY f.department_id, f.department_name
  UNION ALL
  SELECT 'user'::text, f.user_id::text,
    CASE WHEN NULLIF(f.display_name, '') IS NOT NULL AND NULLIF(f.username, '') IS NOT NULL
        AND f.display_name <> f.username THEN f.display_name || ' (' || f.username || ')'
      ELSE COALESCE(NULLIF(f.display_name, ''), NULLIF(f.username, ''), '이름 없음') END,
    COUNT(*)::bigint, COUNT(DISTINCT f.user_id)::bigint, 0
  FROM filtered f GROUP BY f.user_id, f.display_name, f.username;
END;
$$;

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
    SELECT h.user_id, h.username, h.display_name, h.department_name, h.permission_level,
      1::bigint, h.logged_in_at
    FROM public.user_login_history h
    INNER JOIN public.profiles p ON p.id = h.user_id
    WHERE COALESCE(p.is_super_admin, false) = false
      AND h.user_id::text = p_group_key
      AND (p_start_date IS NULL OR (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date >= p_start_date)
      AND (p_end_date IS NULL OR (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date <= p_end_date)
      AND (p_department_id IS NULL OR h.department_id = p_department_id)
      AND (p_user_type IS NULL OR p.user_type = p_user_type)
    ORDER BY h.logged_in_at DESC;
    RETURN;
  END IF;

  RETURN QUERY
  WITH filtered AS (
    SELECT h.user_id, h.username, h.display_name, h.department_id, h.department_name,
      h.permission_level, h.logged_in_at,
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
  ), matched AS (
    SELECT * FROM filtered f
    WHERE (p_group_type = 'date' AND f.login_date::text = p_group_key)
       OR (p_group_type = 'weekday' AND f.weekday_number::text = p_group_key)
       OR (p_group_type = 'hour' AND f.hour_number::text = p_group_key)
       OR (p_group_type = 'department' AND COALESCE(f.department_id::text, 'unassigned') = p_group_key)
  ), user_counts AS (
    SELECT m.user_id, COUNT(*)::bigint AS login_count, MAX(m.logged_in_at) AS last_logged_in_at
    FROM matched m GROUP BY m.user_id
  ), latest_user_snapshot AS (
    SELECT DISTINCT ON (m.user_id) m.user_id, m.username, m.display_name, m.department_name, m.permission_level
    FROM matched m ORDER BY m.user_id, m.logged_in_at DESC
  )
  SELECT s.user_id, s.username, s.display_name, s.department_name, s.permission_level,
    c.login_count, c.last_logged_in_at
  FROM user_counts c
  INNER JOIN latest_user_snapshot s ON s.user_id = c.user_id
  ORDER BY c.login_count DESC, c.last_logged_in_at DESC, COALESCE(s.display_name, s.username, '');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_login_statistics(date, date, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_user_login_stat_detail(text, text, date, date, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_login_statistics(date, date, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_login_stat_detail(text, text, date, date, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
