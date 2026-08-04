-- ============================================================
-- TASK-070: Reset collected service usage data
-- Keeps metric definitions, RLS policies, and helper functions.
-- Clears only accumulated telemetry, snapshots, collection runs,
-- and alert delivery history so the next collection starts clean.
-- ============================================================

BEGIN;

-- Optional: check current row counts before reset.
SELECT 'service_usage_events' AS table_name, count(*) AS rows FROM public.service_usage_events
UNION ALL
SELECT 'service_usage_snapshots', count(*) FROM public.service_usage_snapshots
UNION ALL
SELECT 'service_usage_collection_runs', count(*) FROM public.service_usage_collection_runs
UNION ALL
SELECT 'service_usage_alerts', count(*) FROM public.service_usage_alerts
ORDER BY table_name;

TRUNCATE TABLE
  public.service_usage_alerts,
  public.service_usage_snapshots,
  public.service_usage_collection_runs,
  public.service_usage_events
RESTART IDENTITY;

-- Optional: verify reset result.
SELECT 'service_usage_events' AS table_name, count(*) AS rows FROM public.service_usage_events
UNION ALL
SELECT 'service_usage_snapshots', count(*) FROM public.service_usage_snapshots
UNION ALL
SELECT 'service_usage_collection_runs', count(*) FROM public.service_usage_collection_runs
UNION ALL
SELECT 'service_usage_alerts', count(*) FROM public.service_usage_alerts
ORDER BY table_name;

COMMIT;
