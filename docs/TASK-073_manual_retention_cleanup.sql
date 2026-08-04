-- ============================================================
-- TASK-073: 180일 보존 데이터 수동 삭제 RPC
-- 서비스 통계 페이지: service_usage_snapshots, service_usage_collection_runs
-- 로그 페이지: activity_logs 확인 완료 로그
-- ============================================================

BEGIN;

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

REVOKE EXECUTE ON FUNCTION public.cleanup_service_usage_retention_180d() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.cleanup_activity_logs_retention_180d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_service_usage_retention_180d() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_activity_logs_retention_180d() TO authenticated, service_role;

INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
VALUES
  ('activity_logs.action', 'LOG_RETENTION_CLEANUP', '180일 초과 로그 실제 삭제', 8060, '{"category":"LOG_MGMT","emoji":"🧹"}'),
  ('activity_logs.action', 'LOG_RETENTION_CLEANUP_FAIL', '180일 초과 로그 실제 삭제 실패', 8061, '{"category":"LOG_MGMT","emoji":"⚠️"}'),
  ('activity_logs.action', 'SERVICE_USAGE_RETENTION_CLEANUP', '서비스 통계 180일 초과 정리', 8062, '{"category":"LOG_MGMT","emoji":"🧹"}'),
  ('activity_logs.action', 'SERVICE_USAGE_RETENTION_CLEANUP_FAIL', '서비스 통계 180일 초과 정리 실패', 8063, '{"category":"LOG_MGMT","emoji":"⚠️"}')
ON CONFLICT (group_key, code_key) DO UPDATE
SET code_value = EXCLUDED.code_value,
    sort_order = EXCLUDED.sort_order,
    meta = EXCLUDED.meta,
    updated_at = now();

NOTIFY pgrst, 'reload schema';

COMMIT;
