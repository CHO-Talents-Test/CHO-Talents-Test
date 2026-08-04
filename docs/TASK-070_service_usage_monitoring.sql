-- ============================================================
-- TASK-070: 서비스 사용량/무료 할당량 모니터링
-- GitHub, Supabase, Kakao Developers, Slack
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.service_usage_metrics (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  service text NOT NULL CHECK (service IN ('github', 'supabase', 'kakao', 'slack')),
  metric_key text NOT NULL,
  label text NOT NULL,
  category text NOT NULL DEFAULT 'usage',
  unit text NOT NULL DEFAULT 'count',
  quota_value numeric,
  reset_cycle text NOT NULL DEFAULT 'monthly'
    CHECK (reset_cycle IN ('hourly', 'daily', 'monthly', 'rolling_14d', 'rolling_90d', 'cumulative', 'policy')),
  source_type text NOT NULL DEFAULT 'event'
    CHECK (source_type IN ('api', 'database', 'event', 'estimate', 'policy')),
  source_label text NOT NULL,
  is_estimated boolean NOT NULL DEFAULT false,
  alert_enabled boolean NOT NULL DEFAULT true,
  caution_threshold numeric NOT NULL DEFAULT 70 CHECK (caution_threshold BETWEEN 0 AND 100),
  warning_threshold numeric NOT NULL DEFAULT 85 CHECK (warning_threshold BETWEEN 0 AND 100),
  danger_threshold numeric NOT NULL DEFAULT 95 CHECK (danger_threshold BETWEEN 0 AND 100),
  official_url text,
  notes text,
  sort_order integer NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(service, metric_key),
  CHECK (caution_threshold < warning_threshold AND warning_threshold < danger_threshold)
);

CREATE TABLE IF NOT EXISTS public.service_usage_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  service text NOT NULL,
  metric_key text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0),
  source text NOT NULL DEFAULT 'browser',
  event_key text UNIQUE,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL DEFAULT auth.uid(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (service, metric_key)
    REFERENCES public.service_usage_metrics(service, metric_key)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.service_usage_snapshots (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  service text NOT NULL,
  metric_key text NOT NULL,
  usage_value numeric NOT NULL DEFAULT 0,
  quota_value numeric,
  period_start timestamptz,
  period_end timestamptz,
  source text NOT NULL,
  is_estimated boolean NOT NULL DEFAULT false,
  cost_value numeric NOT NULL DEFAULT 0,
  cost_currency text NOT NULL DEFAULT 'USD',
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  collected_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (service, metric_key)
    REFERENCES public.service_usage_metrics(service, metric_key)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.service_usage_collection_runs (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  trigger_type text NOT NULL DEFAULT 'schedule'
    CHECK (trigger_type IN ('schedule', 'manual', 'setup')),
  triggered_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'running'
    CHECK (status IN ('running', 'success', 'partial', 'failed')),
  service_status jsonb NOT NULL DEFAULT '{}'::jsonb,
  errors jsonb NOT NULL DEFAULT '[]'::jsonb,
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.service_usage_alerts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  service text NOT NULL,
  metric_key text NOT NULL,
  threshold numeric NOT NULL CHECK (threshold IN (70, 85, 95)),
  usage_value numeric NOT NULL,
  quota_value numeric NOT NULL,
  usage_percent numeric NOT NULL,
  period_start timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'failed')),
  slack_response text,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (service, metric_key)
    REFERENCES public.service_usage_metrics(service, metric_key)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  UNIQUE(service, metric_key, threshold, period_start)
);

CREATE INDEX IF NOT EXISTS idx_service_usage_events_metric_time
  ON public.service_usage_events(service, metric_key, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_usage_events_occurred
  ON public.service_usage_events(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_usage_snapshots_metric_time
  ON public.service_usage_snapshots(service, metric_key, collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_usage_runs_started
  ON public.service_usage_collection_runs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_usage_alerts_created
  ON public.service_usage_alerts(created_at DESC);

DROP TRIGGER IF EXISTS trg_service_usage_metrics_updated_at ON public.service_usage_metrics;
CREATE TRIGGER trg_service_usage_metrics_updated_at
  BEFORE UPDATE ON public.service_usage_metrics
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- KST 기준 할당량 기간. 월/일 할당량이 자정(Asia/Seoul)에 정확히 초기화되도록 합니다.
CREATE OR REPLACE FUNCTION public.service_usage_period_start(
  p_cycle text,
  p_reference timestamptz DEFAULT now()
)
RETURNS timestamptz
LANGUAGE sql
STABLE
AS $$
  SELECT CASE p_cycle
    WHEN 'hourly' THEN date_trunc('hour', p_reference AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul'
    WHEN 'daily' THEN date_trunc('day', p_reference AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul'
    WHEN 'monthly' THEN date_trunc('month', p_reference AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul'
    WHEN 'rolling_14d' THEN p_reference - interval '14 days'
    WHEN 'rolling_90d' THEN p_reference - interval '90 days'
    WHEN 'cumulative' THEN timestamptz '2000-01-01 00:00:00+00'
    WHEN 'policy' THEN timestamptz '2000-01-01 00:00:00+00'
    ELSE date_trunc('month', p_reference AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul'
  END;
$$;

CREATE OR REPLACE FUNCTION public.service_usage_period_end(
  p_cycle text,
  p_reference timestamptz DEFAULT now()
)
RETURNS timestamptz
LANGUAGE sql
STABLE
AS $$
  SELECT CASE p_cycle
    WHEN 'hourly' THEN public.service_usage_period_start(p_cycle, p_reference) + interval '1 hour'
    WHEN 'daily' THEN public.service_usage_period_start(p_cycle, p_reference) + interval '1 day'
    WHEN 'monthly' THEN public.service_usage_period_start(p_cycle, p_reference) + interval '1 month'
    WHEN 'rolling_14d' THEN p_reference
    WHEN 'rolling_90d' THEN p_reference
    ELSE NULL
  END;
$$;

-- 공개 화면을 포함한 브라우저 계측 전용 RPC입니다. 등록된 클라이언트 허용 항목만 적재합니다.
CREATE OR REPLACE FUNCTION public.record_service_usage_batch(p_events jsonb)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_event jsonb;
  v_service text;
  v_metric text;
  v_event_key text;
  v_quantity numeric;
  v_metadata jsonb;
  v_inserted integer := 0;
BEGIN
  IF jsonb_typeof(p_events) <> 'array' OR jsonb_array_length(p_events) > 30 THEN
    RAISE EXCEPTION 'invalid telemetry batch';
  END IF;

  FOR v_event IN SELECT value FROM jsonb_array_elements(p_events)
  LOOP
    v_service := lower(left(COALESCE(v_event->>'service', ''), 30));
    v_metric := left(COALESCE(v_event->>'metric_key', ''), 80);
    v_event_key := NULLIF(left(COALESCE(v_event->>'event_key', ''), 180), '');

    BEGIN
      v_quantity := (v_event->>'quantity')::numeric;
    EXCEPTION WHEN OTHERS THEN
      CONTINUE;
    END;

    IF v_quantity <= 0 OR v_quantity > 10000000000 THEN CONTINUE; END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM public.service_usage_metrics m
      WHERE m.service = v_service
        AND m.metric_key = v_metric
        AND m.is_active = true
        AND COALESCE((m.metadata->>'accepts_client_events')::boolean, false) = true
    ) THEN
      CONTINUE;
    END IF;

    v_metadata := COALESCE(v_event->'metadata', '{}'::jsonb);
    IF jsonb_typeof(v_metadata) <> 'object' OR length(v_metadata::text) > 2000 THEN
      v_metadata := '{}'::jsonb;
    END IF;

    INSERT INTO public.service_usage_events(
      service, metric_key, quantity, source, event_key, user_id, metadata
    ) VALUES (
      v_service, v_metric, v_quantity, 'browser', v_event_key, auth.uid(), v_metadata
    )
    ON CONFLICT (event_key) DO NOTHING;

    IF FOUND THEN v_inserted := v_inserted + 1; END IF;
  END LOOP;

  RETURN v_inserted;
END;
$$;

CREATE OR REPLACE FUNCTION public.write_service_usage_snapshot(
  p_service text,
  p_metric_key text,
  p_usage_value numeric,
  p_source text,
  p_is_estimated boolean DEFAULT false,
  p_details jsonb DEFAULT '{}'::jsonb,
  p_cost_value numeric DEFAULT 0,
  p_cost_currency text DEFAULT 'USD',
  p_quota_value numeric DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_metric public.service_usage_metrics%ROWTYPE;
  v_id bigint;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service role required';
  END IF;

  SELECT * INTO STRICT v_metric
  FROM public.service_usage_metrics
  WHERE service = p_service AND metric_key = p_metric_key AND is_active = true;

  INSERT INTO public.service_usage_snapshots(
    service, metric_key, usage_value, quota_value, period_start, period_end,
    source, is_estimated, cost_value, cost_currency, details
  ) VALUES (
    p_service,
    p_metric_key,
    GREATEST(COALESCE(p_usage_value, 0), 0),
    COALESCE(p_quota_value, v_metric.quota_value),
    public.service_usage_period_start(v_metric.reset_cycle, now()),
    public.service_usage_period_end(v_metric.reset_cycle, now()),
    p_source,
    p_is_estimated,
    GREATEST(COALESCE(p_cost_value, 0), 0),
    COALESCE(NULLIF(p_cost_currency, ''), 'USD'),
    COALESCE(p_details, '{}'::jsonb)
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_local_service_usage_snapshots()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage, auth, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_month_start timestamptz := public.service_usage_period_start('monthly', v_now);
  v_month_end timestamptz := public.service_usage_period_end('monthly', v_now);
  v_day_start timestamptz := public.service_usage_period_start('daily', v_now);
  v_day_end timestamptz := public.service_usage_period_end('daily', v_now);
  v_value numeric;
  v_map_calls numeric;
  v_local_calls numeric;
  v_count integer := 0;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service role required';
  END IF;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'github' AND metric_key = 'pages_views' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('github', 'pages_views', v_value, '프로젝트 페이지 계측', true); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'github' AND metric_key = 'pages_bandwidth_bytes' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('github', 'pages_bandwidth_bytes', v_value, '브라우저 Resource Timing 추정', true); v_count := v_count + 1;

  PERFORM public.write_service_usage_snapshot('supabase', 'database_size_bytes', pg_database_size(current_database()), 'PostgreSQL pg_database_size', false); v_count := v_count + 1;

  BEGIN
    SELECT COALESCE(sum(NULLIF(metadata->>'size', '')::numeric), 0) INTO v_value FROM storage.objects;
  EXCEPTION WHEN OTHERS THEN
    v_value := 0;
  END;
  PERFORM public.write_service_usage_snapshot('supabase', 'storage_size_bytes', v_value, 'storage.objects 합계', false); v_count := v_count + 1;

  SELECT count(*) INTO v_value FROM auth.users
   WHERE last_sign_in_at >= v_month_start AND last_sign_in_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('supabase', 'monthly_active_users', v_value, 'auth.users.last_sign_in_at', false); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'supabase' AND metric_key = 'api_requests' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('supabase', 'api_requests', v_value, '프로젝트 Supabase fetch 계측', true); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'supabase' AND metric_key = 'egress_bytes' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('supabase', 'egress_bytes', v_value, '브라우저 응답 전송량 추정', true); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'supabase' AND metric_key = 'cached_egress_bytes' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('supabase', 'cached_egress_bytes', v_value, 'Storage CDN Resource Timing 추정', true); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'supabase' AND metric_key = 'edge_function_invocations' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('supabase', 'edge_function_invocations', v_value, '프로젝트 Edge Function 계측', true); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'supabase' AND metric_key = 'realtime_messages' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('supabase', 'realtime_messages', v_value, '프로젝트 Realtime 계측', true); v_count := v_count + 1;

  SELECT COALESCE(max(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'supabase' AND metric_key = 'realtime_peak_connections' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('supabase', 'realtime_peak_connections', v_value, '프로젝트 Realtime 계측', true); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'kakao' AND metric_key = 'monthly_api_calls' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('kakao', 'monthly_api_calls', v_value, '프로젝트 Kakao 호출 계측', true); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_map_calls FROM public.service_usage_events
   WHERE service = 'kakao' AND metric_key = 'map_sdk_daily' AND occurred_at >= v_day_start AND occurred_at < v_day_end;
  PERFORM public.write_service_usage_snapshot('kakao', 'map_sdk_daily', v_map_calls, 'Kakao Map SDK 로드 계측', true); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_local_calls FROM public.service_usage_events
   WHERE service = 'kakao' AND metric_key = 'local_keyword_daily' AND occurred_at >= v_day_start AND occurred_at < v_day_end;
  PERFORM public.write_service_usage_snapshot('kakao', 'local_keyword_daily', v_local_calls, 'Kakao Places keywordSearch 계측', true); v_count := v_count + 1;

  v_value := GREATEST(v_map_calls - 300000, 0) * 0.1 + GREATEST(v_local_calls - 100000, 0) * 2;
  PERFORM public.write_service_usage_snapshot(
    'kakao', 'estimated_overage_cost_krw_today', v_value, '공식 단가 기반 예상', true,
    jsonb_build_object('paid_api_must_be_enabled', true), 0, 'KRW'
  ); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'slack' AND metric_key = 'notifications_sent' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('slack', 'notifications_month', v_value, 'Slack Webhook 성공 계측', false); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'slack' AND metric_key = 'notifications_sent' AND occurred_at >= v_now - interval '90 days';
  PERFORM public.write_service_usage_snapshot('slack', 'notifications_90d', v_value, 'Slack Webhook 성공 계측', false); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'slack' AND metric_key = 'notifications_sent';
  PERFORM public.write_service_usage_snapshot('slack', 'notifications_total', v_value, 'Slack Webhook 성공 누적', false); v_count := v_count + 1;

  SELECT COALESCE(sum(quantity), 0) INTO v_value FROM public.service_usage_events
   WHERE service = 'slack' AND metric_key = 'webhook_failures' AND occurred_at >= v_month_start AND occurred_at < v_month_end;
  PERFORM public.write_service_usage_snapshot('slack', 'webhook_failures_month', v_value, 'Slack Webhook 실패 계측', false); v_count := v_count + 1;

  PERFORM public.write_service_usage_snapshot('slack', 'installed_apps', 1, '프로젝트에서 사용하는 Slack 앱', true); v_count := v_count + 1;
  PERFORM public.write_service_usage_snapshot('slack', 'message_retention_days', 90, 'Slack Free 정책', false); v_count := v_count + 1;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_service_usage_dashboard()
RETURNS TABLE (
  service text,
  metric_key text,
  label text,
  category text,
  unit text,
  reset_cycle text,
  source_type text,
  source_label text,
  is_estimated boolean,
  alert_enabled boolean,
  caution_threshold numeric,
  warning_threshold numeric,
  danger_threshold numeric,
  official_url text,
  notes text,
  sort_order integer,
  usage_value numeric,
  quota_value numeric,
  remaining_value numeric,
  usage_percent numeric,
  remaining_percent numeric,
  status text,
  period_start timestamptz,
  period_end timestamptz,
  collected_at timestamptz,
  cost_value numeric,
  cost_currency text,
  details jsonb
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
    m.service,
    m.metric_key,
    m.label,
    m.category,
    m.unit,
    m.reset_cycle,
    m.source_type,
    m.source_label,
    COALESCE(s.is_estimated, m.is_estimated),
    m.alert_enabled,
    m.caution_threshold,
    m.warning_threshold,
    m.danger_threshold,
    m.official_url,
    m.notes,
    m.sort_order,
    COALESCE(s.usage_value, 0),
    COALESCE(s.quota_value, m.quota_value),
    CASE WHEN COALESCE(s.quota_value, m.quota_value) IS NULL THEN NULL
      ELSE GREATEST(COALESCE(s.quota_value, m.quota_value) - COALESCE(s.usage_value, 0), 0) END,
    CASE WHEN COALESCE(s.quota_value, m.quota_value) > 0
      THEN round(COALESCE(s.usage_value, 0) / COALESCE(s.quota_value, m.quota_value) * 100, 2) ELSE NULL END,
    CASE WHEN COALESCE(s.quota_value, m.quota_value) > 0
      THEN GREATEST(round(100 - COALESCE(s.usage_value, 0) / COALESCE(s.quota_value, m.quota_value) * 100, 2), 0) ELSE NULL END,
    CASE
      WHEN s.id IS NULL THEN 'not_collected'
      WHEN m.reset_cycle = 'policy' THEN 'policy'
      WHEN COALESCE(s.quota_value, m.quota_value) IS NULL THEN 'unlimited'
      WHEN COALESCE(s.quota_value, m.quota_value) <= 0 THEN 'unlimited'
      WHEN s.usage_value / COALESCE(s.quota_value, m.quota_value) * 100 >= m.danger_threshold THEN 'danger'
      WHEN s.usage_value / COALESCE(s.quota_value, m.quota_value) * 100 >= m.warning_threshold THEN 'warning'
      WHEN s.usage_value / COALESCE(s.quota_value, m.quota_value) * 100 >= m.caution_threshold THEN 'caution'
      ELSE 'normal'
    END,
    s.period_start,
    s.period_end,
    s.collected_at,
    COALESCE(s.cost_value, 0),
    COALESCE(s.cost_currency, 'USD'),
    COALESCE(s.details, '{}'::jsonb)
  FROM public.service_usage_metrics m
  LEFT JOIN LATERAL (
    SELECT ss.*
    FROM public.service_usage_snapshots ss
    WHERE ss.service = m.service AND ss.metric_key = m.metric_key
    ORDER BY ss.collected_at DESC
    LIMIT 1
  ) s ON true
  WHERE m.is_active = true
    AND COALESCE((m.metadata->>'hidden')::boolean, false) = false
  ORDER BY CASE m.service WHEN 'github' THEN 1 WHEN 'supabase' THEN 2 WHEN 'kakao' THEN 3 ELSE 4 END,
           m.sort_order, m.label;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_service_usage_history(
  p_service text,
  p_metric_key text,
  p_days integer DEFAULT 30
)
RETURNS TABLE (
  usage_value numeric,
  quota_value numeric,
  collected_at timestamptz,
  is_estimated boolean,
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
  SELECT s.usage_value, s.quota_value, s.collected_at, s.is_estimated, s.source
  FROM public.service_usage_snapshots s
  WHERE s.service = p_service
    AND s.metric_key = p_metric_key
    AND s.collected_at >= now() - make_interval(days => LEAST(GREATEST(p_days, 1), 365))
  ORDER BY s.collected_at ASC
  LIMIT 500;
END;
$$;

ALTER TABLE public.service_usage_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_usage_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_usage_collection_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_usage_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS service_usage_metrics_chief_select ON public.service_usage_metrics;
CREATE POLICY service_usage_metrics_chief_select ON public.service_usage_metrics FOR SELECT TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 80);
DROP POLICY IF EXISTS service_usage_snapshots_chief_select ON public.service_usage_snapshots;
CREATE POLICY service_usage_snapshots_chief_select ON public.service_usage_snapshots FOR SELECT TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 80);
DROP POLICY IF EXISTS service_usage_runs_chief_select ON public.service_usage_collection_runs;
CREATE POLICY service_usage_runs_chief_select ON public.service_usage_collection_runs FOR SELECT TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 80);
DROP POLICY IF EXISTS service_usage_alerts_chief_select ON public.service_usage_alerts;
CREATE POLICY service_usage_alerts_chief_select ON public.service_usage_alerts FOR SELECT TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 80);

REVOKE ALL ON public.service_usage_events FROM anon, authenticated;
REVOKE ALL ON public.service_usage_metrics FROM anon, authenticated;
REVOKE ALL ON public.service_usage_snapshots FROM anon, authenticated;
REVOKE ALL ON public.service_usage_collection_runs FROM anon, authenticated;
REVOKE ALL ON public.service_usage_alerts FROM anon, authenticated;
GRANT SELECT ON public.service_usage_metrics TO authenticated;
GRANT SELECT ON public.service_usage_snapshots TO authenticated;
GRANT SELECT ON public.service_usage_collection_runs TO authenticated;
GRANT SELECT ON public.service_usage_alerts TO authenticated;
GRANT ALL ON public.service_usage_metrics TO service_role;
GRANT ALL ON public.service_usage_events TO service_role;
GRANT ALL ON public.service_usage_snapshots TO service_role;
GRANT ALL ON public.service_usage_collection_runs TO service_role;
GRANT ALL ON public.service_usage_alerts TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;

REVOKE EXECUTE ON FUNCTION public.record_service_usage_batch(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_service_usage_batch(jsonb) TO anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.write_service_usage_snapshot(text,text,numeric,text,boolean,jsonb,numeric,text,numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.write_service_usage_snapshot(text,text,numeric,text,boolean,jsonb,numeric,text,numeric) TO service_role;
REVOKE EXECUTE ON FUNCTION public.refresh_local_service_usage_snapshots() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_local_service_usage_snapshots() TO service_role;
REVOKE EXECUTE ON FUNCTION public.get_service_usage_dashboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_service_usage_dashboard() TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.get_service_usage_history(text,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_service_usage_history(text,text,integer) TO authenticated, service_role;

-- 2026-07-10 공식 무료 기준. 운영 화면에서 공식 링크와 수집 출처를 함께 표시합니다.
INSERT INTO public.service_usage_metrics
  (service, metric_key, label, category, unit, quota_value, reset_cycle, source_type, source_label, is_estimated, alert_enabled, official_url, notes, sort_order, metadata)
VALUES
  ('github','actions_minutes','Actions 실행 시간','빌링','minutes',2000,'monthly','api','GitHub Billing API',false,true,'https://docs.github.com/en/billing/reference/product-usage-included','GitHub Free for organizations 월 제공량',10,'{}'),
  ('github','actions_storage_bytes','Actions 아티팩트·캐시 저장공간','저장공간','bytes',524288000,'monthly','api','GitHub Actions API',true,true,'https://docs.github.com/en/billing/reference/product-usage-included','만료되지 않은 활성 아티팩트와 active cache 크기 합계로 추정',20,'{}'),
  ('github','packages_storage_bytes','Packages 저장공간','저장공간','bytes',524288000,'monthly','api','GitHub Billing API',true,true,'https://docs.github.com/en/billing/reference/product-usage-included','Billing API 단위를 현재 월 기준으로 정규화',30,'{}'),
  ('github','packages_transfer_bytes','Packages 데이터 전송','트래픽','bytes',1073741824,'monthly','api','GitHub Billing API',true,true,'https://docs.github.com/en/billing/reference/product-usage-included','GitHub Free organization 월 제공량',40,'{}'),
  ('github','lfs_storage_bytes','Git LFS 저장공간','저장공간','bytes',10737418240,'monthly','api','GitHub Billing API',true,true,'https://docs.github.com/en/billing/reference/product-usage-included','Git LFS 월 저장공간 기준',50,'{}'),
  ('github','lfs_bandwidth_bytes','Git LFS 대역폭','트래픽','bytes',10737418240,'monthly','api','GitHub Billing API',true,true,'https://docs.github.com/en/billing/reference/product-usage-included','Git LFS 월 대역폭 기준',60,'{}'),
  ('github','codespaces_compute_hours','Codespaces 컴퓨트','빌링','hours',NULL,'monthly','api','GitHub Billing API',false,false,'https://docs.github.com/en/billing/reference/product-usage-included','Free organization에는 무료 Codespaces 할당량이 없어 사용 발생 시 과금 사용량으로 표시',70,'{}'),
  ('github','codespaces_storage_gb_month','Codespaces 저장공간','저장공간','gb_month',NULL,'monthly','api','GitHub Billing API',false,false,'https://docs.github.com/en/billing/reference/product-usage-included','개인 계정 무료 할당량과 조직 사용량을 혼합하지 않음',80,'{}'),
  ('github','pages_bandwidth_bytes','GitHub Pages 대역폭','트래픽','bytes',107374182400,'monthly','estimate','페이지 Resource Timing',true,true,'https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits','월 100GB soft limit. 브라우저에서 관측한 프로젝트 트래픽만 합산',90,'{"accepts_client_events":true}'),
  ('github','pages_site_size_bytes','게시 사이트 크기','저장공간','bytes',1073741824,'monthly','api','GitHub Repository API',true,true,'https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits','저장소 크기를 게시 사이트 크기의 보수적 근사치로 사용',100,'{}'),
  ('github','pages_views','페이지 조회','트래픽','count',NULL,'monthly','event','프로젝트 페이지 계측',true,false,'https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits','공개·로그인 페이지 로드 횟수',110,'{"accepts_client_events":true}'),
  ('github','repo_views_14d','저장소 조회(최근 14일)','트래픽','count',NULL,'rolling_14d','api','GitHub Traffic API',false,false,'https://docs.github.com/en/rest/metrics/traffic','GitHub 저장소 자체 조회 수',120,'{}'),
  ('github','repo_clones_14d','저장소 clone(최근 14일)','트래픽','count',NULL,'rolling_14d','api','GitHub Traffic API',false,false,'https://docs.github.com/en/rest/metrics/traffic','GitHub 저장소 clone 수',130,'{}'),
  ('github','estimated_cost_usd','이번 달 확인된 과금액','비용','usd',NULL,'monthly','api','GitHub Billing API',false,false,'https://docs.github.com/en/rest/billing/usage','Billing API netAmount 합계',140,'{}'),

  ('supabase','api_requests','API 요청','API','count',NULL,'monthly','event','프로젝트 Supabase fetch 계측',true,false,'https://supabase.com/pricing','Free 플랜은 API 요청 수 무제한',10,'{"accepts_client_events":true}'),
  ('supabase','database_size_bytes','Database 크기','저장공간','bytes',524288000,'monthly','database','pg_database_size',false,true,'https://supabase.com/pricing','500MB 초과 시 Free 프로젝트 제한 위험',20,'{}'),
  ('supabase','monthly_active_users','월간 활성 사용자(MAU)','사용자','count',50000,'monthly','database','auth.users.last_sign_in_at',false,true,'https://supabase.com/pricing','현재 월 로그인 사용자 기준',30,'{}'),
  ('supabase','egress_bytes','Egress','트래픽','bytes',5368709120,'monthly','estimate','프로젝트 응답 계측',true,true,'https://supabase.com/docs/guides/platform/manage-your-usage/egress','모든 Supabase 서비스의 비캐시 전송량 공식값보다 작을 수 있음',40,'{"accepts_client_events":true}'),
  ('supabase','cached_egress_bytes','Cached Egress','트래픽','bytes',5368709120,'monthly','estimate','Storage CDN Resource Timing',true,true,'https://supabase.com/docs/guides/platform/manage-your-usage/egress','프로젝트 화면에서 관측된 Storage CDN 전송량',50,'{"accepts_client_events":true}'),
  ('supabase','storage_size_bytes','File Storage','저장공간','bytes',1073741824,'monthly','database','storage.objects',false,true,'https://supabase.com/docs/guides/platform/manage-your-usage/storage-size','현재 파일 원본 크기 합계',60,'{}'),
  ('supabase','edge_function_invocations','Edge Function 호출','함수','count',500000,'monthly','event','Edge Function 내부 계측',true,true,'https://supabase.com/docs/guides/platform/manage-your-usage/edge-function-invocations','프로젝트가 관리하는 Edge Function 호출을 기록',70,'{"accepts_client_events":false}'),
  ('supabase','realtime_messages','Realtime 메시지','Realtime','count',2000000,'monthly','event','프로젝트 Realtime 계측',true,true,'https://supabase.com/docs/guides/platform/manage-your-usage/realtime-messages','현재 프로젝트 코드에서 Realtime 사용 시 계측 함수 호출 필요',80,'{"accepts_client_events":true}'),
  ('supabase','realtime_peak_connections','Realtime 최대 동시 연결','Realtime','count',200,'monthly','event','프로젝트 Realtime 계측',true,true,'https://supabase.com/docs/guides/realtime/pricing','현재 월 관측 최대 연결 수',90,'{"accepts_client_events":true}'),
  ('supabase','official_api_requests_24h','공식 API 요청(최근 수집 구간)','API','count',NULL,'daily','api','Supabase Management API',false,false,'https://supabase.com/docs/reference/api/start','Management API analytics_usage_read 값',100,'{}'),

  ('kakao','monthly_api_calls','무료 API 전체','API','count',3000000,'monthly','event','프로젝트 Kakao 호출 계측',true,true,'https://developers.kakao.com/docs/ko/getting-started/quota','앱당 월간 기본 쿼터',10,'{"accepts_client_events":true}'),
  ('kakao','map_sdk_daily','Map JavaScript SDK','지도','count',300000,'daily','event','Kakao Map SDK 로드 계측',true,true,'https://developers.kakao.com/docs/ko/getting-started/quota','일간 무료 쿼터',20,'{"accepts_client_events":true}'),
  ('kakao','local_keyword_daily','Local 키워드 장소 검색','지도','count',100000,'daily','event','Kakao Places keywordSearch 계측',true,true,'https://developers.kakao.com/docs/ko/getting-started/quota','일간 무료 쿼터',30,'{"accepts_client_events":true}'),
  ('kakao','estimated_overage_cost_krw_today','오늘 추가 쿼터 예상 비용','비용','krw',NULL,'daily','estimate','공식 API 단가 계산',true,false,'https://developers.kakao.com/docs/ko/getting-started/quota','유료 API 활성화 시에만 실제 비용 발생. Map JS 0.1원, Local 키워드 검색 2원 기준',40,'{}'),

  ('slack','notifications_month','프로젝트 알림(이번 달)','메시지','count',NULL,'monthly','event','Slack Webhook 성공 계측',false,false,'https://slack.com/help/articles/115002422943-Usage-limits-for-free-workspaces','해당 프로젝트에서 보낸 Slack 알림',10,'{}'),
  ('slack','notifications_90d','최근 90일 프로젝트 알림','메시지','count',NULL,'rolling_90d','event','Slack Webhook 성공 계측',false,false,'https://slack.com/help/articles/115002422943-Usage-limits-for-free-workspaces','무료 플랜에서 검색 가능한 기간의 프로젝트 알림 수',20,'{}'),
  ('slack','notifications_total','프로젝트 알림 누적','메시지','count',NULL,'cumulative','event','Slack Webhook 성공 누적',false,false,'https://slack.com/help/articles/115002422943-Usage-limits-for-free-workspaces','모니터링 적용 이후 누적',30,'{}'),
  ('slack','webhook_failures_month','Webhook 실패·설정 오류(이번 달)','오류','count',NULL,'monthly','event','Slack Webhook 실패·설정 오류 계측',false,false,'https://api.slack.com/messaging/webhooks','HTTP 오류, 네트워크 오류, Webhook Secret 미설정 건을 프로젝트 내부에서 기록합니다.',40,'{}'),
  ('slack','installed_apps','프로젝트 사용 앱','앱','count',10,'monthly','estimate','프로젝트 설정',true,false,'https://slack.com/help/articles/115002422943-Usage-limits-for-free-workspaces','워크스페이스 전체가 아니라 이 프로젝트가 사용하는 앱 1개만 표시',50,'{}'),
  ('slack','message_retention_days','메시지 내역 보존','정책','days',90,'policy','policy','Slack Free 정책',false,false,'https://slack.com/help/articles/115002422943-Usage-limits-for-free-workspaces','90일 초과 메시지와 파일은 숨겨지고 1년 초과 데이터는 삭제될 수 있음',60,'{}'),
  ('slack','notifications_sent','내부: Slack 성공 이벤트','내부','count',NULL,'cumulative','event','Edge Function 내부',false,false,NULL,'집계 원본 이벤트',900,'{"accepts_client_events":false,"hidden":true}'),
  ('slack','webhook_failures','내부: Slack 실패 이벤트','내부','count',NULL,'cumulative','event','Edge Function 내부',false,false,NULL,'집계 원본 이벤트',910,'{"accepts_client_events":false,"hidden":true}')
ON CONFLICT (service, metric_key) DO UPDATE SET
  label = EXCLUDED.label,
  category = EXCLUDED.category,
  unit = EXCLUDED.unit,
  quota_value = EXCLUDED.quota_value,
  reset_cycle = EXCLUDED.reset_cycle,
  source_type = EXCLUDED.source_type,
  source_label = EXCLUDED.source_label,
  is_estimated = EXCLUDED.is_estimated,
  alert_enabled = EXCLUDED.alert_enabled,
  official_url = EXCLUDED.official_url,
  notes = EXCLUDED.notes,
  sort_order = EXCLUDED.sort_order,
  metadata = EXCLUDED.metadata,
  is_active = true,
  updated_at = now();

NOTIFY pgrst, 'reload schema';

COMMIT;
