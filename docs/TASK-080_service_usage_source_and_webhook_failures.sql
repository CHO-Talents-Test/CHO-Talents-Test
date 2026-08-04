-- ============================================================
-- TASK-080: 서비스 통계 계측 기준 구분 및 Slack Webhook 실패 상세
-- 적용 전 TASK-070_service_usage_monitoring.sql이 완료되어 있어야 합니다.
-- ============================================================

BEGIN;

UPDATE public.service_usage_metrics
SET label = 'Webhook 실패·설정 오류(이번 달)',
    source_label = 'Slack Webhook 실패·설정 오류 계측',
    notes = 'HTTP 오류, 네트워크 오류, Webhook Secret 미설정 건을 프로젝트 내부에서 기록합니다. Slack 외부의 실제 전달 보장은 아닙니다.',
    updated_at = now()
WHERE service = 'slack'
  AND metric_key = 'webhook_failures_month';

CREATE OR REPLACE FUNCTION public.get_service_usage_recent_webhook_failures(
  p_limit integer DEFAULT 20
)
RETURNS TABLE (
  occurred_at timestamptz,
  notification_type text,
  failure_reason text,
  http_status integer,
  source text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND public.get_permission_rank(auth.uid()) < 80 THEN
    RAISE EXCEPTION 'insufficient permission';
  END IF;

  RETURN QUERY
  SELECT
    e.occurred_at,
    COALESCE(NULLIF(e.metadata->>'type', ''), 'unknown') AS notification_type,
    COALESCE(
      NULLIF(e.metadata->>'reason', ''),
      CASE WHEN e.metadata->>'status' IS NOT NULL THEN 'http_error' ELSE 'unknown' END
    ) AS failure_reason,
    CASE
      WHEN COALESCE(e.metadata->>'status', '') ~ '^[0-9]+$'
        THEN (e.metadata->>'status')::integer
      ELSE NULL
    END AS http_status,
    e.source
  FROM public.service_usage_events e
  WHERE e.service = 'slack'
    AND e.metric_key = 'webhook_failures'
  ORDER BY e.occurred_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_service_usage_recent_webhook_failures(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_service_usage_recent_webhook_failures(integer) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
