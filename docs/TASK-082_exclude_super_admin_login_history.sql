-- ============================================================
-- TASK-082: 최고관리자 로그인 이력·사용자 통계 제외
-- public.profiles.is_super_admin=true 계정은 로그인 이력을 남기지 않고
-- 기존 이력도 삭제하며 사용자 통계 집계에서 방어적으로 제외합니다.
-- ============================================================

BEGIN;

DELETE FROM public.user_login_history h
USING public.profiles p
WHERE p.id = h.user_id
  AND COALESCE(p.is_super_admin, false) = true;

CREATE OR REPLACE FUNCTION public.record_user_login()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_department_name text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  SELECT *
  INTO v_profile
  FROM public.profiles
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile not found';
  END IF;

  IF COALESCE(v_profile.is_super_admin, false) THEN
    RETURN;
  END IF;

  SELECT d.name
  INTO v_department_name
  FROM public.departments d
  WHERE d.id = v_profile.department_id;

  INSERT INTO public.user_login_history (
    user_id, username, display_name, department_id, department_name, permission_level
  ) VALUES (
    v_profile.id,
    COALESCE(NULLIF(v_profile.username, ''), v_profile.id::text),
    v_profile.display_name,
    v_profile.department_id,
    v_department_name,
    v_profile.permission_level
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_login_statistics(
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_department_id uuid DEFAULT NULL
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

  RETURN QUERY
  WITH filtered AS (
    SELECT
      h.user_id,
      h.username,
      h.display_name,
      h.department_id,
      h.department_name,
      (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date AS login_date,
      EXTRACT(ISODOW FROM h.logged_in_at AT TIME ZONE 'Asia/Seoul')::integer AS weekday_number,
      EXTRACT(HOUR FROM h.logged_in_at AT TIME ZONE 'Asia/Seoul')::integer AS hour_number
    FROM public.user_login_history h
    INNER JOIN public.profiles p ON p.id = h.user_id
    WHERE COALESCE(p.is_super_admin, false) = false
      AND (p_start_date IS NULL OR (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date >= p_start_date)
      AND (p_end_date IS NULL OR (h.logged_in_at AT TIME ZONE 'Asia/Seoul')::date <= p_end_date)
      AND (p_department_id IS NULL OR h.department_id = p_department_id)
  )
  SELECT
    'date'::text,
    f.login_date::text,
    TO_CHAR(f.login_date, 'YYYY.MM.DD'),
    COUNT(*)::bigint,
    COUNT(DISTINCT f.user_id)::bigint,
    (f.login_date - DATE '2000-01-01')::integer
  FROM filtered f
  GROUP BY f.login_date

  UNION ALL

  SELECT
    'weekday'::text,
    f.weekday_number::text,
    CASE f.weekday_number
      WHEN 1 THEN '월요일' WHEN 2 THEN '화요일' WHEN 3 THEN '수요일'
      WHEN 4 THEN '목요일' WHEN 5 THEN '금요일' WHEN 6 THEN '토요일'
      WHEN 7 THEN '일요일'
    END,
    COUNT(*)::bigint,
    COUNT(DISTINCT f.user_id)::bigint,
    f.weekday_number
  FROM filtered f
  GROUP BY f.weekday_number

  UNION ALL

  SELECT
    'hour'::text,
    f.hour_number::text,
    LPAD(f.hour_number::text, 2, '0') || ':00',
    COUNT(*)::bigint,
    COUNT(DISTINCT f.user_id)::bigint,
    f.hour_number
  FROM filtered f
  GROUP BY f.hour_number

  UNION ALL

  SELECT
    'department'::text,
    COALESCE(f.department_id::text, 'unassigned'),
    COALESCE(NULLIF(f.department_name, ''), '미배정'),
    COUNT(*)::bigint,
    COUNT(DISTINCT f.user_id)::bigint,
    0
  FROM filtered f
  GROUP BY f.department_id, f.department_name

  UNION ALL

  SELECT
    'user'::text,
    f.user_id::text,
    CASE
      WHEN NULLIF(f.display_name, '') IS NOT NULL
        AND NULLIF(f.username, '') IS NOT NULL
        AND f.display_name <> f.username
        THEN f.display_name || ' (' || f.username || ')'
      ELSE COALESCE(NULLIF(f.display_name, ''), NULLIF(f.username, ''), '이름 없음')
    END,
    COUNT(*)::bigint,
    COUNT(DISTINCT f.user_id)::bigint,
    0
  FROM filtered f
  GROUP BY f.user_id, f.display_name, f.username;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_user_login() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_user_login_statistics(date, date, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_user_login() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_login_statistics(date, date, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
