import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const APP_ENV = (Deno.env.get("APP_ENV") || "DEV").trim().toUpperCase();
const IS_PROD = APP_ENV === "PROD";
const GITHUB_TOKEN = Deno.env.get("GITHUB_TOKEN") || Deno.env.get("GITHUB_PAT") || "";
const GITHUB_OWNER = Deno.env.get("GITHUB_OWNER") || (IS_PROD ? "CHO-Talents" : "CHO-Talents-Test");
const GITHUB_REPO = Deno.env.get("GITHUB_REPO") || (IS_PROD ? "CHO-Talents" : "CHO-Talents-Test");
const GITHUB_ACCOUNT_TYPE = (Deno.env.get("GITHUB_ACCOUNT_TYPE") || "user").trim().toLowerCase();
const SB_MANAGEMENT_ACCESS_TOKEN = (Deno.env.get("SB_MANAGEMENT_ACCESS_TOKEN") || "").trim();
const SB_PROJECT_REF = (Deno.env.get("SB_PROJECT_REF") || "").trim();
const SLACK_WEBHOOK_OPERATIONS = Deno.env.get("SLACK_WEBHOOK_OPERATIONS") || "";
const SLACK_ENABLED = (Deno.env.get("SLACK_ENABLED") || "false").trim().toLowerCase() === "true";
const SERVICE_STATS_URL = Deno.env.get("SERVICE_STATS_URL") ||
  (IS_PROD
    ? "https://cho-talents.github.io/CHO-Talents/admin/service-stats.html"
    : "https://cho-talents-test.github.io/CHO-Talents-Test/admin/service-stats.html");

const GITHUB_API_VERSION = "2026-03-10";
const GB = 1024 ** 3;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const service = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

type Json = Record<string, unknown>;
type ErrorItem = { service: string; endpoint?: string; message: string };

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function numberValue(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function permissionRank(level: string | null, superAdmin: boolean): number {
  if (superAdmin) return 110;
  return ({ admin: 100, evangelist: 90, chief: 80 } as Record<string, number>)[level || ""] || 0;
}

function decodeJwtPayload(token: string): Json | null {
  const payload = token.split(".")[1];
  if (!payload) return null;
  const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
  try {
    return JSON.parse(atob(padded)) as Json;
  } catch {
    return null;
  }
}

function isServiceRoleJwt(token: string): boolean {
  const payload = decodeJwtPayload(token);
  return payload?.role === "service_role";
}

async function authorize(req: Request): Promise<{ ok: boolean; userId: string | null; trigger: "schedule" | "manual"; error?: string }> {
  const auth = req.headers.get("Authorization") || "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token) return { ok: false, userId: null, trigger: "manual", error: "authorization required" };
  if (token === SERVICE_ROLE_KEY || isServiceRoleJwt(token)) {
    return { ok: true, userId: null, trigger: "schedule" };
  }

  const { data: userData, error: userError } = await service.auth.getUser(token);
  if (userError || !userData.user) {
    return { ok: false, userId: null, trigger: "manual", error: "invalid session" };
  }

  const { data: profile, error: profileError } = await service
    .from("profiles")
    .select("permission_level,is_super_admin")
    .eq("id", userData.user.id)
    .single();
  if (profileError || permissionRank(profile?.permission_level, !!profile?.is_super_admin) < 100) {
    return { ok: false, userId: userData.user.id, trigger: "manual", error: "admin permission required" };
  }
  return { ok: true, userId: userData.user.id, trigger: "manual" };
}

async function recordEvent(metricKey: string, quantity = 1, metadata: Json = {}) {
  await service.from("service_usage_events").insert({
    service: metricKey.startsWith("notifications") || metricKey.startsWith("webhook") ? "slack" : "supabase",
    metric_key: metricKey,
    quantity,
    source: "edge-function",
    metadata,
  });
}

async function writeSnapshot(
  platform: string,
  metricKey: string,
  usage: number,
  source: string,
  estimated = false,
  details: Json = {},
  costValue = 0,
  costCurrency = "USD",
  quotaValue: number | null = null,
) {
  const { error } = await service.rpc("write_service_usage_snapshot", {
    p_service: platform,
    p_metric_key: metricKey,
    p_usage_value: Math.max(usage || 0, 0),
    p_source: source,
    p_is_estimated: estimated,
    p_details: details,
    p_cost_value: Math.max(costValue || 0, 0),
    p_cost_currency: costCurrency,
    p_quota_value: quotaValue,
  });
  if (error) throw new Error(`${platform}.${metricKey}: ${error.message}`);
}

async function githubFetch(path: string): Promise<Json> {
  const response = await fetch(`https://api.github.com${path}`, {
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      "X-GitHub-Api-Version": GITHUB_API_VERSION,
      "User-Agent": "CHO-Talents-service-usage",
    },
  });
  if (!response.ok) {
    const message = (await response.text()).slice(0, 300);
    throw new Error(`GitHub ${response.status}: ${message}`);
  }
  return await response.json() as Json;
}

function itemQuantity(item: Json): number {
  return numberValue(item.grossQuantity ?? item.netQuantity ?? item.quantity);
}

function normalizedBytes(item: Json): number {
  const quantity = itemQuantity(item);
  const unit = String(item.unitType || item.unit || "").toLowerCase().replace(/[ _-]/g, "");
  const monthStart = new Date();
  monthStart.setUTCDate(1);
  monthStart.setUTCHours(0, 0, 0, 0);
  const elapsedHours = Math.max((Date.now() - monthStart.getTime()) / 3600000, 1);
  const normalizedQuantity = unit.includes("hour") ? quantity / elapsedHours : quantity;
  if (unit.includes("byte") && !unit.includes("gigabyte") && !unit.includes("megabyte")) return normalizedQuantity;
  if (unit.includes("megabyte")) return normalizedQuantity * 1024 ** 2;
  if (unit.includes("gigabyte") || unit === "gb" || unit.includes("gbmonth")) return normalizedQuantity * GB;
  if (unit.includes("gibibyte")) return normalizedQuantity * GB;
  return normalizedQuantity * GB;
}

function sumItems(items: Json[], predicate: (item: Json) => boolean, convert: (item: Json) => number = itemQuantity): number {
  return items.filter(predicate).reduce((sum, item) => sum + convert(item), 0);
}

async function collectGitHub(errors: ErrorItem[]): Promise<Json> {
  if (!GITHUB_TOKEN) return { status: "needs_secret", message: "GITHUB_TOKEN 미설정" };

  const now = new Date();
  const query = new URLSearchParams({
    year: String(now.getUTCFullYear()),
    month: String(now.getUTCMonth() + 1),
    repository: `${GITHUB_OWNER}/${GITHUB_REPO}`,
  });
  let summary: Json | null = null;
  let items: Json[] = [];

  try {
    const billingSummaryPath = GITHUB_ACCOUNT_TYPE === "organization"
      ? `/organizations/${encodeURIComponent(GITHUB_OWNER)}/settings/billing/usage/summary?${query}`
      : `/users/${encodeURIComponent(GITHUB_OWNER)}/settings/billing/usage/summary?${query}`;
    summary = await githubFetch(billingSummaryPath);
    items = Array.isArray(summary.usageItems) ? summary.usageItems as Json[] : [];
  } catch (error) {
    errors.push({ service: "github", endpoint: "billing/usage/summary", message: String(error) });
  }

  if (summary) {
    const product = (item: Json) => String(item.product || "").toLowerCase();
    const sku = (item: Json) => String(item.sku || "").toLowerCase();
    const unit = (item: Json) => String(item.unitType || "").toLowerCase();

    const actionsMinutes = sumItems(items, (i) => product(i) === "actions" && unit(i).includes("minute"));
    const packagesStorage = sumItems(items, (i) => product(i) === "packages" && sku(i).includes("storage"), normalizedBytes);
    const packagesTransfer = sumItems(items, (i) => product(i) === "packages" && /(transfer|bandwidth)/.test(sku(i)), normalizedBytes);
    const lfsStorage = sumItems(items, (i) => /(git large file|lfs)/.test(product(i) + " " + sku(i)) && sku(i).includes("storage"), normalizedBytes);
    const lfsBandwidth = sumItems(items, (i) => /(git large file|lfs)/.test(product(i) + " " + sku(i)) && /(bandwidth|transfer)/.test(sku(i)), normalizedBytes);
    const codespacesCompute = sumItems(items, (i) => product(i) === "codespaces" && !sku(i).includes("storage"));
    const codespacesStorage = sumItems(items, (i) => product(i) === "codespaces" && sku(i).includes("storage"));
    const netCost = items.reduce((sum, item) => sum + numberValue(item.netAmount), 0);

    await Promise.all([
      writeSnapshot("github", "actions_minutes", actionsMinutes, "GitHub Billing API", false, { items: items.length }),
      writeSnapshot("github", "packages_storage_bytes", packagesStorage, "GitHub Billing API", true, { normalized_from_billing_units: true }),
      writeSnapshot("github", "packages_transfer_bytes", packagesTransfer, "GitHub Billing API", true, { normalized_from_billing_units: true }),
      writeSnapshot("github", "lfs_storage_bytes", lfsStorage, "GitHub Billing API", true, { normalized_from_billing_units: true }),
      writeSnapshot("github", "lfs_bandwidth_bytes", lfsBandwidth, "GitHub Billing API", true, { normalized_from_billing_units: true }),
      writeSnapshot("github", "codespaces_compute_hours", codespacesCompute, "GitHub Billing API", false, { organization_free_quota: 0 }),
      writeSnapshot("github", "codespaces_storage_gb_month", codespacesStorage, "GitHub Billing API", false, { organization_free_quota: 0 }),
      writeSnapshot("github", "estimated_cost_usd", netCost, "GitHub Billing API", false, { net_amount: true }, netCost, "USD"),
    ]);
  }

  try {
    const [artifacts, cacheUsage] = await Promise.all([
      githubFetch(`/repos/${encodeURIComponent(GITHUB_OWNER)}/${encodeURIComponent(GITHUB_REPO)}/actions/artifacts?per_page=100`),
      githubFetch(`/repos/${encodeURIComponent(GITHUB_OWNER)}/${encodeURIComponent(GITHUB_REPO)}/actions/cache/usage`),
    ]);
    const artifactRows = Array.isArray(artifacts.artifacts) ? artifacts.artifacts as Json[] : [];
    const activeArtifactRows = artifactRows.filter((row) => row.expired === false);
    const expiredArtifactRows = artifactRows.filter((row) => row.expired === true);
    const artifactBytes = activeArtifactRows.reduce((sum, row) => sum + numberValue(row.size_in_bytes), 0);
    const expiredArtifactBytes = expiredArtifactRows.reduce((sum, row) => sum + numberValue(row.size_in_bytes), 0);
    const cacheBytes = numberValue(cacheUsage.active_caches_size_in_bytes);
    await writeSnapshot("github", "actions_storage_bytes", artifactBytes + cacheBytes, "GitHub Actions API", true, {
      artifacts_bytes: artifactBytes,
      active_artifact_count: activeArtifactRows.length,
      expired_artifacts_bytes: expiredArtifactBytes,
      expired_artifact_count: expiredArtifactRows.length,
      cache_bytes: cacheBytes,
      artifact_count: artifactRows.length,
    });
  } catch (error) {
    errors.push({ service: "github", endpoint: "actions storage", message: String(error) });
  }

  try {
    const repo = await githubFetch(`/repos/${encodeURIComponent(GITHUB_OWNER)}/${encodeURIComponent(GITHUB_REPO)}`);
    await writeSnapshot("github", "pages_site_size_bytes", numberValue(repo.size) * 1024, "GitHub Repository API", true, {
      repository_size_kb: numberValue(repo.size),
    });
  } catch (error) {
    errors.push({ service: "github", endpoint: "repository", message: String(error) });
  }

  try {
    const [views, clones] = await Promise.all([
      githubFetch(`/repos/${encodeURIComponent(GITHUB_OWNER)}/${encodeURIComponent(GITHUB_REPO)}/traffic/views`),
      githubFetch(`/repos/${encodeURIComponent(GITHUB_OWNER)}/${encodeURIComponent(GITHUB_REPO)}/traffic/clones`),
    ]);
    await Promise.all([
      writeSnapshot("github", "repo_views_14d", numberValue(views.count), "GitHub Traffic API", false, { uniques: numberValue(views.uniques) }),
      writeSnapshot("github", "repo_clones_14d", numberValue(clones.count), "GitHub Traffic API", false, { uniques: numberValue(clones.uniques) }),
    ]);
  } catch (error) {
    errors.push({ service: "github", endpoint: "traffic", message: String(error) });
  }

  return {
    status: errors.some((item) => item.service === "github") ? "partial" : "connected",
    owner: GITHUB_OWNER,
    repository: GITHUB_REPO,
    account_type: GITHUB_ACCOUNT_TYPE === "organization" ? "organization" : "user",
    billing_items: items.length,
  };
}

async function collectSupabaseManagement(errors: ErrorItem[]): Promise<Json> {
  if (!SB_MANAGEMENT_ACCESS_TOKEN || !SB_PROJECT_REF) {
    return { status: "needs_secret", message: "SB_MANAGEMENT_ACCESS_TOKEN or SB_PROJECT_REF is not set" };
  }

  try {
    const response = await fetch(
      `https://api.supabase.com/v1/projects/${encodeURIComponent(SB_PROJECT_REF)}/analytics/endpoints/usage.api-counts?interval=1day`,
      {
        headers: {
          Authorization: `Bearer ${SB_MANAGEMENT_ACCESS_TOKEN}`,
          Accept: "application/json",
        },
      },
    );
    if (!response.ok) throw new Error(`Supabase ${response.status}: ${(await response.text()).slice(0, 300)}`);
    const payload = await response.json() as Json;
    const rows = Array.isArray(payload.result) ? payload.result as Json[] : [];
    const total = rows.reduce((sum, row) => sum +
      numberValue(row.total_auth_requests) + numberValue(row.total_realtime_requests) +
      numberValue(row.total_rest_requests) + numberValue(row.total_storage_requests), 0);
    await writeSnapshot("supabase", "official_api_requests_24h", total, "Supabase Management API", false, {
      points: rows.length,
      interval: "1day",
    });
    return { status: "connected", analytics_points: rows.length };
  } catch (error) {
    errors.push({ service: "supabase", endpoint: "usage.api-counts", message: String(error) });
    return { status: "partial", message: String(error) };
  }
}

async function collectLocalSnapshots(errors: ErrorItem[]): Promise<Json> {
  const { data, error } = await service.rpc("refresh_local_service_usage_snapshots");
  if (error) {
    errors.push({ service: "project", endpoint: "local snapshots", message: error.message });
    return { status: "partial", source: "project telemetry", message: error.message, snapshots: 0 };
  }

  return { status: "tracking", source: "project telemetry", snapshots: numberValue(data) };
}

function formatMetricValue(value: number, unit: string): string {
  if (unit === "bytes") {
    if (value >= GB) return `${(value / GB).toFixed(2)} GB`;
    if (value >= 1024 ** 2) return `${(value / 1024 ** 2).toFixed(1)} MB`;
    return `${Math.round(value / 1024)} KB`;
  }
  if (unit === "usd") return `$${value.toFixed(2)}`;
  if (unit === "krw") return `${Math.round(value).toLocaleString("ko-KR")}원`;
  return value.toLocaleString("ko-KR", { maximumFractionDigits: 2 });
}

async function sendQuotaAlerts(errors: ErrorItem[]): Promise<number> {
  if (!SLACK_ENABLED) return 0;
  const { data: rows, error } = await service.rpc("get_service_usage_dashboard");
  if (error) throw new Error(`dashboard for alerts: ${error.message}`);
  const metrics = (rows || []) as Json[];
  let sent = 0;

  for (const metric of metrics) {
    if (!metric.alert_enabled || !metric.collected_at || numberValue(metric.quota_value) <= 0) continue;
    const percent = numberValue(metric.usage_percent);
    const thresholds = [70, 85, 95].filter((threshold) => percent >= threshold);
    for (const threshold of thresholds) {
      const periodStart = String(metric.period_start || new Date(0).toISOString());
      const { data: existing } = await service
        .from("service_usage_alerts")
        .select("id,status")
        .eq("service", metric.service)
        .eq("metric_key", metric.metric_key)
        .eq("threshold", threshold)
        .eq("period_start", periodStart)
        .maybeSingle();
      if (existing?.status === "sent") continue;

      let alertId = existing?.id as number | undefined;
      if (!alertId) {
        const { data: inserted, error: insertError } = await service
          .from("service_usage_alerts")
          .insert({
            service: metric.service,
            metric_key: metric.metric_key,
            threshold,
            usage_value: metric.usage_value,
            quota_value: metric.quota_value,
            usage_percent: percent,
            period_start: periodStart,
          })
          .select("id")
          .single();
        if (insertError) continue;
        alertId = inserted.id;
      }

      if (!SLACK_WEBHOOK_OPERATIONS) {
        await service.from("service_usage_alerts").update({ status: "failed", slack_response: "SLACK_WEBHOOK_OPERATIONS 미설정" }).eq("id", alertId);
        await recordEvent("webhook_failures", 1, {
          type: "service_quota_alert",
          threshold,
          reason: "missing_webhook_config",
        });
        continue;
      }

      const icon = threshold >= 95 ? "🚨" : threshold >= 85 ? "⚠️" : "🔔";
      const level = threshold >= 95 ? "위험" : threshold >= 85 ? "경고" : "주의";
      const usage = numberValue(metric.usage_value);
      const quota = numberValue(metric.quota_value);
      const remaining = Math.max(quota - usage, 0);
      const payload = {
        text: `${icon} [${level}] ${metric.service} ${metric.label} ${percent.toFixed(1)}%`,
        blocks: [
          { type: "header", text: { type: "plain_text", text: `${icon} 서비스 할당량 ${level} (${threshold}%)`, emoji: true } },
          { type: "section", fields: [
            { type: "mrkdwn", text: `*플랫폼*\n${String(metric.service).toUpperCase()}` },
            { type: "mrkdwn", text: `*항목*\n${metric.label}` },
            { type: "mrkdwn", text: `*현재 사용량*\n${formatMetricValue(usage, String(metric.unit))} (${percent.toFixed(1)}%)` },
            { type: "mrkdwn", text: `*남은 사용량*\n${formatMetricValue(remaining, String(metric.unit))} (${Math.max(100 - percent, 0).toFixed(1)}%)` },
          ] },
          { type: "section", text: { type: "mrkdwn", text: `<${SERVICE_STATS_URL}|서비스 통계에서 상세 확인>` } },
          { type: "context", elements: [{ type: "mrkdwn", text: "👤 사용자 계정: 계정 없음 / 표시이름: 시스템 자동 수집" }] },
        ],
      };

      let slackStatus: number | null = null;
      try {
        const response = await fetch(SLACK_WEBHOOK_OPERATIONS, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        slackStatus = response.status;
        const responseText = (await response.text()).slice(0, 300);
        if (!response.ok) throw new Error(`Slack ${response.status}: ${responseText}`);
        await service.from("service_usage_alerts").update({
          status: "sent", sent_at: new Date().toISOString(), slack_response: responseText || "ok",
        }).eq("id", alertId);
        await recordEvent("notifications_sent", 1, { type: "service_quota_alert", threshold });
        sent += 1;
      } catch (sendError) {
        const message = String(sendError);
        errors.push({ service: "slack", endpoint: "quota alert", message });
        await service.from("service_usage_alerts").update({ status: "failed", slack_response: message.slice(0, 500) }).eq("id", alertId);
        await recordEvent("webhook_failures", 1, {
          type: "service_quota_alert",
          threshold,
          status: slackStatus,
          reason: slackStatus ? "http_error" : "network_error",
        });
      }
    }
  }
  return sent;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "POST required" }, 405);

  const auth = await authorize(req);
  if (!auth.ok) return jsonResponse({ error: auth.error }, 403);

  const errors: ErrorItem[] = [];
  const { data: run, error: runError } = await service
    .from("service_usage_collection_runs")
    .insert({ trigger_type: auth.trigger, triggered_by: auth.userId })
    .select("id")
    .single();
  if (runError) return jsonResponse({ error: runError.message }, 500);

  try {
    await recordEvent("edge_function_invocations", 1, { function: "service-usage-collect", trigger: auth.trigger });

    const localErrors: ErrorItem[] = [];
    const githubErrors: ErrorItem[] = [];
    const supabaseErrors: ErrorItem[] = [];

    const [localStatus, githubStatus, supabaseStatus] = await Promise.all([
      collectLocalSnapshots(localErrors),
      collectGitHub(githubErrors),
      collectSupabaseManagement(supabaseErrors),
    ]);
    errors.push(...localErrors, ...githubErrors, ...supabaseErrors);

    const alertCount = await sendQuotaAlerts(errors);
    const slackStatus = !SLACK_ENABLED
      ? { status: "disabled", source: "environment configuration", message: "Slack notifications are disabled for this environment" }
      : SLACK_WEBHOOK_OPERATIONS
      ? { status: "connected", source: "project webhook events" }
      : { status: "needs_secret", source: "project webhook events", message: "SLACK_WEBHOOK_OPERATIONS is not set" };
    const serviceStatus = {
      github: { ...githubStatus, channels: { api: githubStatus, project: localStatus } },
      supabase: { ...supabaseStatus, channels: { api: supabaseStatus, project: localStatus } },
      kakao: {
        status: "tracking",
        source: "project events",
        channels: {
          api: { status: "not_supported", source: "official API", message: "Kakao 사용량은 프로젝트 계측으로 수집" },
          project: localStatus,
        },
      },
      slack: {
        ...slackStatus,
        channels: {
          api: { status: "not_supported", source: "official API", message: "Slack 사용량은 Webhook 이벤트 계측으로 수집" },
          project: slackStatus,
        },
      },
      local_snapshots: numberValue(localStatus["snapshots"]),
      alerts_sent: alertCount,
    };
    const status = errors.length === 0 ? "success" : "partial";
    await service.from("service_usage_collection_runs").update({
      status,
      service_status: serviceStatus,
      errors,
      finished_at: new Date().toISOString(),
    }).eq("id", run.id);
    return jsonResponse({ success: true, status, run_id: run.id, service_status: serviceStatus, errors });
  } catch (error) {
    errors.push({ service: "collector", message: String(error) });
    await service.from("service_usage_collection_runs").update({
      status: "failed",
      errors,
      finished_at: new Date().toISOString(),
    }).eq("id", run.id);
    return jsonResponse({ success: false, run_id: run.id, errors }, 500);
  }
});
