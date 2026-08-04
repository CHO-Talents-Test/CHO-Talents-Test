-- Run this first in DEV project blitrrcdkkkszvgylnus.
-- It revokes every refreshable Supabase Auth session before the reset begins.
-- Existing access JWTs expire according to the project's JWT lifetime.

BEGIN;

DO $$
BEGIN
  IF to_regclass('auth.refresh_tokens') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.refresh_tokens';
  END IF;
  IF to_regclass('auth.sessions') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.sessions';
  END IF;
END;
$$;

COMMIT;

SELECT count(*) AS remaining_sessions FROM auth.sessions;
