-- TASK-093: 사용자별 로그인 통계에 권한 및 마지막 로그인 일시 제공
-- 적용 후 관리자 사용자 통계의 사용자별 표에서 권한과 마지막 로그인 일시를 표시합니다.

BEGIN;

DROP FUNCTION IF EXISTS public.get_user_login_statistics(date, date, uuid, text);

CREATE FUNCTION public.get_user_login_statistics(
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
  sort_order integer,
  permission_level text,
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
  )
  SELECT 'date'::text, f.login_date::text, TO_CHAR(f.login_date, 'YYYY.MM.DD'),
    COUNT(*)::bigint, COUNT(DISTINCT f.user_id)::bigint, (f.login_date - DATE '2000-01-01')::integer,
    NULL::text, NULL::timestamptz
  FROM filtered f GROUP BY f.login_date
  UNION ALL
  SELECT 'weekday'::text, f.weekday_number::text,
    CASE f.weekday_number WHEN 1 THEN '월요일' WHEN 2 THEN '화요일' WHEN 3 THEN '수요일'
      WHEN 4 THEN '목요일' WHEN 5 THEN '금요일' WHEN 6 THEN '토요일' WHEN 7 THEN '일요일' END,
    COUNT(*)::bigint, COUNT(DISTINCT f.user_id)::bigint, f.weekday_number,
    NULL::text, NULL::timestamptz
  FROM filtered f GROUP BY f.weekday_number
  UNION ALL
  SELECT 'hour'::text, f.hour_number::text, LPAD(f.hour_number::text, 2, '0') || ':00',
    COUNT(*)::bigint, COUNT(DISTINCT f.user_id)::bigint, f.hour_number,
    NULL::text, NULL::timestamptz
  FROM filtered f GROUP BY f.hour_number
  UNION ALL
  SELECT 'department'::text, COALESCE(f.department_id::text, 'unassigned'),
    COALESCE(NULLIF(f.department_name, ''), '미배정'), COUNT(*)::bigint,
    COUNT(DISTINCT f.user_id)::bigint, 0, NULL::text, NULL::timestamptz
  FROM filtered f GROUP BY f.department_id, f.department_name
  UNION ALL
  SELECT 'user'::text, f.user_id::text,
    CASE WHEN NULLIF(f.display_name, '') IS NOT NULL AND NULLIF(f.username, '') IS NOT NULL
        AND f.display_name <> f.username THEN f.display_name || ' (' || f.username || ')'
      ELSE COALESCE(NULLIF(f.display_name, ''), NULLIF(f.username, ''), '이름 없음') END,
    COUNT(*)::bigint, COUNT(DISTINCT f.user_id)::bigint, 0,
    (ARRAY_AGG(f.permission_level ORDER BY f.logged_in_at DESC))[1]::text,
    MAX(f.logged_in_at)
  FROM filtered f GROUP BY f.user_id, f.display_name, f.username;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_login_statistics(date, date, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_login_statistics(date, date, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
