-- ============================================================
-- TASK-070: 서비스 사용량 수집 예약 실행
-- 실행 전 <SUPABASE_SERVICE_ROLE_KEY>를 현재 프로젝트 값으로 바꾸세요.
-- pg_cron은 UTC 기준이므로 03/09/15/21 UTC = 12/18/00/06 KST입니다.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;

DO $$
DECLARE
  v_secret_id uuid;
BEGIN
  SELECT id INTO v_secret_id
  FROM vault.secrets
  WHERE name = 'service_usage_service_role_key'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_secret_id IS NULL THEN
    PERFORM vault.create_secret(
      '<SUPABASE_SERVICE_ROLE_KEY>',
      'service_usage_service_role_key',
      'service-usage-collect 예약 호출 전용'
    );
  ELSE
    PERFORM vault.update_secret(
      v_secret_id,
      '<SUPABASE_SERVICE_ROLE_KEY>',
      'service_usage_service_role_key',
      'service-usage-collect 예약 호출 전용'
    );
  END IF;
END;
$$;

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'cho-service-usage-collect-6h';

SELECT cron.schedule(
  'cho-service-usage-collect-6h',
  '0 3,9,15,21 * * *',
  $cron$
    SELECT net.http_post(
      url := (
        SELECT key_value
        FROM public.app_config
        WHERE key_name = 'SUPABASE_URL' AND use_yn = true
        ORDER BY updated_at DESC
        LIMIT 1
      ) || '/functions/v1/service-usage-collect',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'service_usage_service_role_key'
          ORDER BY created_at DESC
          LIMIT 1
        )
      ),
      body := jsonb_build_object('trigger', 'schedule'),
      timeout_milliseconds := 120000
    );
  $cron$
);

-- 확인
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'cho-service-usage-collect-6h';
