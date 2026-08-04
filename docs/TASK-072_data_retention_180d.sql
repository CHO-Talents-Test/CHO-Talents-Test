-- ============================================================
-- TASK-072: 180일 데이터 보존 정책
-- service_usage_snapshots, service_usage_collection_runs, activity_logs
-- activity_logs 미확인 로그는 확인 완료 전까지 자동 삭제하지 않습니다.
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE INDEX IF NOT EXISTS idx_service_usage_snapshots_collected
  ON public.service_usage_snapshots(collected_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_logs_ack_created
  ON public.activity_logs(is_acknowledged, created_at DESC);

CREATE OR REPLACE FUNCTION public.cleanup_data_retention_180d()
RETURNS TABLE (
  service_usage_snapshots_deleted bigint,
  service_usage_collection_runs_deleted bigint,
  activity_logs_deleted bigint,
  cutoff_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cutoff timestamptz := now() - interval '180 days';
BEGIN
  cutoff_at := v_cutoff;

  DELETE FROM public.service_usage_snapshots
  WHERE collected_at < v_cutoff;
  GET DIAGNOSTICS service_usage_snapshots_deleted = ROW_COUNT;

  DELETE FROM public.service_usage_collection_runs
  WHERE started_at < v_cutoff;
  GET DIAGNOSTICS service_usage_collection_runs_deleted = ROW_COUNT;

  DELETE FROM public.activity_logs
  WHERE created_at < v_cutoff
    AND COALESCE(is_acknowledged, false) = true;
  GET DIAGNOSTICS activity_logs_deleted = ROW_COUNT;

  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION public.cleanup_data_retention_180d()
  IS '180일 초과 서비스 통계 스냅샷/수집 이력/확인 완료 활동 로그를 삭제합니다. activity_logs 미확인 로그는 보존합니다.';

CREATE OR REPLACE FUNCTION public.cleanup_service_usage_retention_180d()
RETURNS TABLE (
  service_usage_snapshots_deleted bigint,
  service_usage_collection_runs_deleted bigint,
  cutoff_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cutoff timestamptz := now() - interval '180 days';
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND COALESCE(public.get_permission_rank(auth.uid()), 0) < 100 THEN
    RAISE EXCEPTION 'admin permission required';
  END IF;

  cutoff_at := v_cutoff;

  DELETE FROM public.service_usage_snapshots
  WHERE collected_at < v_cutoff;
  GET DIAGNOSTICS service_usage_snapshots_deleted = ROW_COUNT;

  DELETE FROM public.service_usage_collection_runs
  WHERE started_at < v_cutoff;
  GET DIAGNOSTICS service_usage_collection_runs_deleted = ROW_COUNT;

  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION public.cleanup_service_usage_retention_180d()
  IS '관리자용 수동 정리: 180일 초과 service_usage_snapshots, service_usage_collection_runs를 삭제합니다.';

CREATE OR REPLACE FUNCTION public.cleanup_activity_logs_retention_180d()
RETURNS TABLE (
  activity_logs_deleted bigint,
  cutoff_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cutoff timestamptz := now() - interval '180 days';
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND COALESCE(public.get_permission_rank(auth.uid()), 0) < 100 THEN
    RAISE EXCEPTION 'admin permission required';
  END IF;

  cutoff_at := v_cutoff;

  DELETE FROM public.activity_logs
  WHERE created_at < v_cutoff
    AND COALESCE(is_acknowledged, false) = true;
  GET DIAGNOSTICS activity_logs_deleted = ROW_COUNT;

  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION public.cleanup_activity_logs_retention_180d()
  IS '관리자용 수동 정리: 180일 초과 확인 완료 activity_logs를 삭제합니다. 미확인 로그는 보존합니다.';

REVOKE EXECUTE ON FUNCTION public.cleanup_data_retention_180d() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_data_retention_180d() TO service_role;
REVOKE EXECUTE ON FUNCTION public.cleanup_service_usage_retention_180d() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.cleanup_activity_logs_retention_180d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_service_usage_retention_180d() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_activity_logs_retention_180d() TO authenticated, service_role;

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'cho-data-retention-180d';

SELECT cron.schedule(
  'cho-data-retention-180d',
  '30 18 * * *',
  $cron$
    SELECT * FROM public.cleanup_data_retention_180d();
  $cron$
);

-- 수동 검증용: 필요 시 아래 SELECT만 별도로 실행해 삭제 건수를 확인할 수 있습니다.
-- SELECT * FROM public.cleanup_data_retention_180d();

-- 확인
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'cho-data-retention-180d';

NOTIFY pgrst, 'reload schema';

COMMIT;
