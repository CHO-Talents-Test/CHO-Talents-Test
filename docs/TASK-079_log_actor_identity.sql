-- TASK-079: 활동 로그의 표시 이름(display_name)과 계정(username) 정규화
-- 로그인 실패처럼 브라우저에서 표시 이름을 알 수 없는 경우에도 DB가 profiles를 기준으로 보정한다.

CREATE OR REPLACE FUNCTION public.normalize_activity_log_actor_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account text;
  v_username text;
  v_display_name text;
BEGIN
  v_account := NULLIF(BTRIM(COALESCE(
    NEW.username,
    NEW.details ->> 'logUserAccount',
    NEW.details ->> 'targetAccount'
  )), '');

  IF v_account IS NULL OR v_account IN ('계정 없음', '<계정 없음>') THEN
    RETURN NEW;
  END IF;

  SELECT p.username, COALESCE(NULLIF(BTRIM(p.display_name), ''), p.username)
    INTO v_username, v_display_name
  FROM public.profiles p
  WHERE LOWER(p.username) = LOWER(v_account)
  LIMIT 1;

  IF v_username IS NULL THEN
    SELECT r.username, COALESCE(NULLIF(BTRIM(r.display_name), ''), r.username)
      INTO v_username, v_display_name
    FROM public.registration_requests r
    WHERE LOWER(r.username) = LOWER(v_account)
    ORDER BY r.created_at DESC
    LIMIT 1;
  END IF;

  IF v_username IS NOT NULL THEN
    NEW.username := v_username;
    NEW.user_name := v_display_name;
    NEW.details := COALESCE(NEW.details, '{}'::jsonb) || jsonb_build_object(
      'logUserAccount', v_username,
      'logUserName', v_display_name
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_normalize_activity_log_actor_identity ON public.activity_logs;
CREATE TRIGGER trg_normalize_activity_log_actor_identity
  BEFORE INSERT OR UPDATE OF username, user_name, details ON public.activity_logs
  FOR EACH ROW EXECUTE FUNCTION public.normalize_activity_log_actor_identity();

-- 기존 로그도 현재 프로필 정보를 기준으로 보정한다.
UPDATE public.activity_logs l
SET username = p.username,
    user_name = COALESCE(NULLIF(BTRIM(p.display_name), ''), p.username),
    details = COALESCE(l.details, '{}'::jsonb) || jsonb_build_object(
      'logUserAccount', p.username,
      'logUserName', COALESCE(NULLIF(BTRIM(p.display_name), ''), p.username)
    )
FROM public.profiles p
WHERE LOWER(l.username) = LOWER(p.username)
  AND l.username NOT IN ('계정 없음', '<계정 없음>');

WITH latest_registration_requests AS (
  SELECT DISTINCT ON (LOWER(username))
    username,
    display_name
  FROM public.registration_requests
  WHERE username IS NOT NULL
  ORDER BY LOWER(username), created_at DESC
)
UPDATE public.activity_logs l
SET username = r.username,
    user_name = COALESCE(NULLIF(BTRIM(r.display_name), ''), r.username),
    details = COALESCE(l.details, '{}'::jsonb) || jsonb_build_object(
      'logUserAccount', r.username,
      'logUserName', COALESCE(NULLIF(BTRIM(r.display_name), ''), r.username)
    )
FROM latest_registration_requests r
WHERE LOWER(l.username) = LOWER(r.username)
  AND NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE LOWER(p.username) = LOWER(l.username)
  )
  AND l.username NOT IN ('계정 없음', '<계정 없음>');

NOTIFY pgrst, 'reload schema';
