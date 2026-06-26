-- TASK-057 code master post-install verification.
-- Run with:
--   psql "$SUPABASE_DB_CONNECTION_STRING" -v ON_ERROR_STOP=1 -f scripts/verify-task-057-code-master.sql

BEGIN;

DO $$
DECLARE
  v_count integer;
  v_missing text;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.code_groups;

  IF v_count < 16 THEN
    RAISE EXCEPTION 'Expected at least 16 code groups, found %', v_count;
  END IF;

  SELECT string_agg(expected.group_key, ', ' ORDER BY expected.group_key)
  INTO v_missing
  FROM (
    VALUES
      ('profiles.permission_level'),
      ('profiles.user_type'),
      ('request.status'),
      ('product_orders.status'),
      ('products.target_role'),
      ('products.category'),
      ('talent_items.target_type'),
      ('talent_transactions.type'),
      ('talent_transactions.source'),
      ('talent_qr_codes.repeat_type'),
      ('qna.status'),
      ('reports.report_type'),
      ('report_events.event_type'),
      ('user_preferences.theme'),
      ('activity_logs.level'),
      ('activity_logs.action')
  ) AS expected(group_key)
  LEFT JOIN public.code_groups actual ON actual.group_key = expected.group_key
  WHERE actual.group_key IS NULL;

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing code groups: %', v_missing;
  END IF;

  SELECT string_agg(expected.group_key || ':' || expected.code_key, ', ' ORDER BY expected.group_key, expected.code_key)
  INTO v_missing
  FROM (
    VALUES
      ('profiles.permission_level', 'super_admin'),
      ('profiles.permission_level', 'admin'),
      ('profiles.permission_level', 'student'),
      ('profiles.user_type', 'teacher'),
      ('profiles.user_type', 'student'),
      ('request.status', 'pending'),
      ('product_orders.status', 'requested'),
      ('product_orders.status', 'cancelled'),
      ('products.target_role', 'teacher'),
      ('products.target_role', 'student'),
      ('products.category', 'etc'),
      ('talent_items.target_type', 'teacher'),
      ('talent_transactions.type', 'earn'),
      ('talent_transactions.source', 'admin'),
      ('talent_transactions.source', 'qr'),
      ('talent_qr_codes.repeat_type', 'none'),
      ('qna.status', 'answered'),
      ('reports.report_type', 'test_result'),
      ('report_events.event_type', 'confirmed'),
      ('user_preferences.theme', 'default'),
      ('activity_logs.level', 'INFO'),
      ('activity_logs.action', 'PRODUCT_CREATE'),
      ('activity_logs.action', 'qr_scan')
  ) AS expected(group_key, code_key)
  LEFT JOIN public.code_items actual
    ON actual.group_key = expected.group_key
   AND actual.code_key = expected.code_key
   AND actual.is_active = true
  WHERE actual.code_key IS NULL;

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing active code items: %', v_missing;
  END IF;

  SELECT string_agg(expected.trigger_name, ', ' ORDER BY expected.trigger_name)
  INTO v_missing
  FROM (
    VALUES
      ('trg_code_profiles'),
      ('trg_code_registration_requests'),
      ('trg_code_department_transfer_requests'),
      ('trg_code_talent_items'),
      ('trg_code_talent_transactions'),
      ('trg_code_products'),
      ('trg_code_product_orders'),
      ('trg_code_qna'),
      ('trg_code_reports'),
      ('trg_code_report_events'),
      ('trg_code_user_preferences'),
      ('trg_code_talent_qr_codes'),
      ('trg_code_activity_logs_level')
  ) AS expected(trigger_name)
  LEFT JOIN pg_trigger actual
    ON actual.tgname = expected.trigger_name
   AND NOT actual.tgisinternal
  WHERE actual.tgname IS NULL;

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing validation triggers: %', v_missing;
  END IF;

  SELECT string_agg(conname, ', ' ORDER BY conname)
  INTO v_missing
  FROM pg_constraint
  WHERE conname IN (
    'profiles_user_type_check',
    'profiles_permission_level_check',
    'registration_requests_status_check',
    'registration_requests_user_type_check',
    'registration_requests_permission_level_check',
    'department_transfer_requests_status_check',
    'talent_items_target_type_check',
    'talent_transactions_type_check',
    'products_target_role_check',
    'product_orders_status_check',
    'qna_status_check',
    'reports_report_type_check',
    'report_events_event_type_check',
    'user_preferences_theme_check'
  );

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Static CHECK constraints still exist: %', v_missing;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE oid = 'public.get_permission_rank(text)'::regprocedure
      AND provolatile = 's'
      AND prosecdef = true
  ) THEN
    RAISE EXCEPTION 'get_permission_rank(text) is not STABLE SECURITY DEFINER';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE oid = 'public.get_code_value(text, text)'::regprocedure
      AND prosecdef = true
  ) THEN
    RAISE EXCEPTION 'get_code_value(text, text) is missing or not SECURITY DEFINER';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE oid = 'public.validate_code_columns()'::regprocedure
  ) THEN
    RAISE EXCEPTION 'validate_code_columns() is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_class
    WHERE oid = 'public.code_groups'::regclass
      AND relrowsecurity = true
  ) OR NOT EXISTS (
    SELECT 1
    FROM pg_class
    WHERE oid = 'public.code_items'::regclass
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'RLS is not enabled on code master tables';
  END IF;

  IF NOT has_table_privilege('anon', 'public.code_items', 'SELECT') THEN
    RAISE EXCEPTION 'anon does not have SELECT on public.code_items';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.app_config
    WHERE env IN ('PROD', 'DEV')
      AND key_name = 'SUPABASE_URL'
      AND is_secret = false
      AND use_yn = true
  ) THEN
    RAISE EXCEPTION 'app_config has no public SUPABASE_URL for PROD or DEV. app_config.env must match config/public-config.js TARGET_ENV.';
  END IF;

  CREATE TEMP TABLE task057_validation_smoke (
    status text
  ) ON COMMIT DROP;

  CREATE TRIGGER task057_validation_smoke_trigger
    BEFORE INSERT OR UPDATE OF status ON task057_validation_smoke
    FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('status', 'product_orders.status');

  INSERT INTO task057_validation_smoke (status) VALUES ('requested');

  BEGIN
    INSERT INTO task057_validation_smoke (status) VALUES ('not_a_real_status');
    RAISE EXCEPTION 'Invalid code was accepted by validate_code_columns()';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END;
$$;

ROLLBACK;

SELECT 'TASK-057 code master verification passed' AS result;
