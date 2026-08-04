// Supabase Edge Function shared implementation: slack-notify
// 이 파일을 Supabase Dashboard > Edge Functions > Create new edge function에 붙여넣어 배포하세요.
// Function name: slack-notify
//
// 필수 Edge Function Secrets:
//   SLACK_WEBHOOK_PART1           - 1부 채널 (Type: HumanResources, Group: Part1)
//   SLACK_WEBHOOK_PART2           - 2부 채널 (Type: HumanResources, Group: Part2)
//   SLACK_WEBHOOK_PART3           - 3부 채널 (Type: HumanResources, Group: Part3)
//   SLACK_WEBHOOK_PART4           - 4부 채널 (Type: HumanResources, Group: Part4)
//   SLACK_WEBHOOK_PART5           - 5부 채널 (Type: HumanResources, Group: Part5)
//   SLACK_WEBHOOK_WORSHIP         - 예배부 채널 (Type: HumanResources, Group: Worship)
//   SLACK_WEBHOOK_PRODUCT_MANAGEMENT - 상품 관리 채널 (Type: Product, Group: Management)
//   SLACK_WEBHOOK_OPERATIONS      - 운영 로그 채널 (Type: Operations, Group: Management)
//   SLACK_WEBHOOK_ANSWER          - Q&A 채널 (Type: Answer, Group: Management)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// The exact same source runs in DEV and PROD. Slack remains fail-closed: each
// project must explicitly opt in through its own Edge Function environment.
const SLACK_ENABLED = (Deno.env.get("SLACK_ENABLED") || "false").trim().toLowerCase() === "true";

type SlackUsageContext = {
  reason?: "http_error" | "network_error" | "missing_webhook_config";
};

async function recordSlackUsage(
  metricKey: "notifications_sent" | "webhook_failures",
  type: string,
  status?: number,
  context: SlackUsageContext = {},
) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return;

  try {
    await fetch(`${supabaseUrl}/rest/v1/service_usage_events`, {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        service: "slack",
        metric_key: metricKey,
        quantity: 1,
        source: "edge-function",
        metadata: { type, status: status || null, ...context },
      }),
    });
  } catch (error) {
    console.warn("[slack-notify] usage telemetry failed:", error);
  }
}

const DEPT_WEBHOOK_MAP: Record<string, string> = {
  "1부": "SLACK_WEBHOOK_PART1",
  "2부": "SLACK_WEBHOOK_PART2",
  "3부": "SLACK_WEBHOOK_PART3",
  "4부": "SLACK_WEBHOOK_PART4",
  "5부": "SLACK_WEBHOOK_PART5",
  "예배부": "SLACK_WEBHOOK_WORSHIP",
};

const STATUS_LABELS: Record<string, string> = {
  requested: "📋 구매 신청",
  preparing: "📦 상품 준비",
  purchased: "💳 상품 구매",
  delivered: "✅ 상품 지급",
  cancelled: "❌ 구매 취소",
};

const PRODUCT_SUGGESTION_RESULT_LABELS: Record<string, string> = {
  adopted: "채택",
  rejected: "불채택",
  voting: "투표중",
};

const LOG_LEVEL_EMOJI: Record<string, string> = {
  WARN: "⚠️",
  ERROR: "🔴",
  FATAL: "💀",
  CRITICAL: "🚨",
};

const LOG_ACTION_LABELS: Record<string, string> = {
  AUTH_SESSION_MISSING: "인증 세션 없음",
  AUTH_REDIRECT: "인증/권한 리디렉트",
  AUTH_PROFILE_LOAD_FAIL: "인증 프로필 조회 실패",
  LOGIN_FAIL: "로그인 실패",
  LOGIN_PENDING_APPROVAL: "가입 승인 대기",
  APP_VERSION_STALE_SESSION: "구버전 세션 감지",
  TALENT_GIVE_ITEM_FAIL: "달란트 항목 지급 실패",
  TALENT_GIVE_ITEM_DENIED: "달란트 항목 지급 거부",
  TALENT_EXCEPTION_REQUEST_FAIL: "예외 지급 요청 실패",
  ORDER_CANCEL_REFUND_FAIL: "주문 취소 환불 실패",
  JS_ERROR: "JS 오류",
  RESOURCE_LOAD_FAIL: "리소스 로드 실패",
  SLACK_NOTIFY_FAIL: "Slack 알림 전송 실패",
  MY_TALENT_PENDING_QUERY: "대기 달란트 조회 오류",
};

const LOG_VALUE_LABELS: Record<string, string> = {
  "Supabase auth session missing": "Supabase 인증 세션 없음",
  "Invalid login credentials": "로그인 정보가 일치하지 않습니다",
  "TypeError: Load failed": "로드 실패",
  "Load failed": "로드 실패",
  "TypeError: Failed to fetch": "네트워크 요청에 실패했습니다",
  "Failed to fetch": "네트워크 요청에 실패했습니다",
  "Failed to send a request to the Edge Function": "Edge Function 요청 전송 실패",
  "Edge Function returned a non-2xx status code": "Edge Function이 오류 상태를 반환했습니다",
  profiles: "사용자 프로필",
  registration_requests: "가입 신청",
  talent_transactions: "달란트 거래",
  product_orders: "상품 주문",
  activity_logs: "작업 로그",
  purchase_new: "새 구매 신청",
  "Script error.": "스크립트 오류",
  "User denied Geolocation": "사용자가 위치 권한을 거부했습니다",
  "Profile RPC returned no profile": "프로필 RPC 결과 없음",
  "Cannot coerce the result to a single JSON object": "단일 결과로 변환할 수 없습니다",
  "permission denied for table profiles": "profiles 테이블 권한이 없습니다",
  Unauthorized: "권한이 없습니다",
  last_activity: "마지막 활동 기준",
  idle_timer: "유휴 타이머 기준",
  visibilitychange: "탭 재활성화 기준",
  weekly_duplicate: "주간 중복 지급",
  duplicate_pending: "이미 대기 중인 요청",
  cached_session: "캐시 세션으로 복구",
  profiles_fallback: "프로필 직접 조회로 복구",
  cancel_aborted_before_partial_update: "부분 취소 방지를 위해 중단",
  teacher: "교사",
  student: "학생",
  admin: "관리자",
  evangelist: "전도사님",
  chief: "부장 교사",
  purchase_teacher: "구매 담당 교사",
  dept_teacher: "부서 담당 교사",
  requested: "요청됨",
  preparing: "준비 중",
  purchased: "구매 완료",
  delivered: "지급 완료",
  cancelled: "취소됨",
  false: "아니오",
  true: "예",
};

interface SlackBlock {
  type: string;
  text?: { type: string; text: string; emoji?: boolean };
  elements?: Array<{ type: string; text: string }>;
  fields?: Array<{ type: string; text: string }>;
}

function stringValue(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "string") return value.trim();
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return "";
}

function getObjectValue(source: unknown, keys: string[]): string {
  if (!source || typeof source !== "object") return "";
  const obj = source as Record<string, unknown>;
  for (const key of keys) {
    const value = stringValue(obj[key]);
    if (value) return value;
  }
  return "";
}

function translateLogText(value: unknown): string {
  const raw = stringValue(value);
  if (!raw) return "";
  if (LOG_VALUE_LABELS[raw]) return LOG_VALUE_LABELS[raw];
  const weekly = raw.match(/^Already given this item this week:\s*(.+)$/i);
  if (weekly) return `이번 주에 이미 지급된 항목입니다: ${weekly[1]}`;
  const permission = raw.match(/^permission denied for table ([\w.]+)$/i);
  if (permission) return `${permission[1]} 테이블 권한이 없습니다`;
  return LOG_ACTION_LABELS[raw] || raw;
}

function localizeLogDetailValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(localizeLogDetailValue);
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    Object.entries(value as Record<string, unknown>).forEach(([key, item]) => {
      out[key] = localizeLogDetailValue(item);
    });
    return out;
  }
  if (typeof value === "boolean") return value ? "예" : "아니오";
  if (typeof value === "string" || typeof value === "number") return translateLogText(value);
  return value;
}

function formatLogDetailValue(value: unknown): string {
  const localized = localizeLogDetailValue(value);
  if (localized && typeof localized === "object") return JSON.stringify(localized);
  return stringValue(localized);
}

function resolveNotificationUser(data: Record<string, unknown>): { account: string; name: string } {
  const details = data["상세"];
  const account = getObjectValue(data, ["사용자계정", "사용자 계정", "계정", "아이디", "logUserAccount", "actorAccount"])
    || getObjectValue(details, ["사용자 계정", "작업자 아이디", "아이디", "logUserAccount", "actorAccount"]);
  const name = getObjectValue(data, ["사용자이름", "사용자 이름", "표시이름", "표시 이름", "이름", "신청자", "등록자", "처리자", "logUserName", "actorName"])
    || getObjectValue(details, ["사용자 이름", "작업자", "이름", "표시 이름", "logUserName", "actorName"]);

  return {
    account: account || "계정 없음",
    name: name || "이름 없음",
  };
}

function addUserContext(payload: { text: string; blocks: SlackBlock[] }, data: Record<string, unknown>) {
  const user = resolveNotificationUser(data);
  payload.blocks.push({
    type: "context",
    elements: [{ type: "mrkdwn", text: `👤 사용자 계정: ${user.account} / 표시이름: ${user.name}` }],
  });
  return payload;
}

function resolveWebhookUrl(type: string, data: Record<string, unknown>): string | null {
  switch (type) {
    case "user_register": {
      const dept = String(data["부서"] || "");
      const secretName = DEPT_WEBHOOK_MAP[dept];
      return secretName ? (Deno.env.get(secretName) || null) : null;
    }
    case "dept_transfer": {
      const dept = String(data["이동부서"] || "");
      const secretName = DEPT_WEBHOOK_MAP[dept];
      return secretName ? (Deno.env.get(secretName) || null) : null;
    }
    case "purchase_new": {
      const dept = String(data["부서"] || "");
      const secretName = DEPT_WEBHOOK_MAP[dept];
      return secretName ? (Deno.env.get(secretName) || null) : null;
    }
    case "purchase_status": {
      return Deno.env.get("SLACK_WEBHOOK_PRODUCT_MANAGEMENT") || null;
    }
    case "log_alert": {
      return Deno.env.get("SLACK_WEBHOOK_OPERATIONS") || null;
    }
    case "product_suggestion_registered":
    case "product_suggestion_vote_completed":
    case "slack_test": {
      return Deno.env.get("SLACK_WEBHOOK_OPERATIONS") || null;
    }
    case "qna_new": {
      return Deno.env.get("SLACK_WEBHOOK_ANSWER") || null;
    }
    default:
      return null;
  }
}

function formatMessage(type: string, data: Record<string, unknown>): { text: string; blocks: SlackBlock[] } {
  const now = new Date().toLocaleString("ko-KR", { timeZone: "Asia/Seoul" });

  switch (type) {
    case "purchase_new": {
      const fallback = `🛒 신규 구매 신청: ${data["신청자"] || "알 수 없음"} - ${data["상품명"] || ""} (${data["금액"] || 0} 달란트)`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: "🛒 신규 구매 신청", emoji: true } },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*신청자:*\n${data["신청자"] || "알 수 없음"}` },
              { type: "mrkdwn", text: `*상품명:*\n${data["상품명"] || "-"}` },
              { type: "mrkdwn", text: `*금액:*\n${Number(data["금액"] || 0).toLocaleString()} 달란트` },
              { type: "mrkdwn", text: `*유형:*\n${data["유형"] || "일반 구매"}` },
            ],
          },
          ...(data["부서"] ? [{
            type: "context" as const,
            elements: [{ type: "mrkdwn" as const, text: `🏢 소속: ${data["부서"]}` }],
          }] : []),
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 ${now}` }] },
        ],
      };
    }

    case "purchase_status": {
      const prev = data["이전상태"] as string || "";
      const next = data["변경상태"] as string || "";
      const prevLabel = STATUS_LABELS[prev] || prev;
      const nextLabel = STATUS_LABELS[next] || next;
      const fallback = `📦 구매 상태 변경: ${data["상품명"] || ""} (${prevLabel} → ${nextLabel})`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: "📦 구매 상태 변경", emoji: true } },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*상품명:*\n${data["상품명"] || "-"}` },
              { type: "mrkdwn", text: `*신청자:*\n${data["신청자"] || "-"}` },
              { type: "mrkdwn", text: `*상태 변경:*\n${prevLabel} → ${nextLabel}` },
              { type: "mrkdwn", text: `*처리자:*\n${data["처리자"] || "-"}` },
            ],
          },
          ...(data["건수"] ? [{
            type: "context" as const,
            elements: [{ type: "mrkdwn" as const, text: `📊 일괄 처리: ${data["건수"]}건${data["실패건수"] ? ` (실패 ${data["실패건수"]}건)` : ""}` }],
          }] : []),
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 ${now}` }] },
        ],
      };
    }

    case "user_register": {
      const deptName = data["부서"] || "-";
      const fallback = `📝 신규 가입 신청: ${data["이름"] || ""} (${data["아이디"] || ""})`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: "📝 신규 가입 신청", emoji: true } },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*구분:*\n🆕 가입 신청` },
              { type: "mrkdwn", text: `*아이디:*\n${data["아이디"] || "-"}` },
              { type: "mrkdwn", text: `*이름:*\n${data["이름"] || "-"}` },
              { type: "mrkdwn", text: `*소속 부서:*\n${deptName}` },
            ],
          },
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 ${now}` }] },
        ],
      };
    }

    case "dept_transfer": {
      const fallback = `🔄 부서 이동 신청: ${data["대상"] || ""} (${data["이전부서"] || ""} → ${data["이동부서"] || ""})`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: "🔄 부서 이동 신청", emoji: true } },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*구분:*\n🔄 부서 이동 신청` },
              { type: "mrkdwn", text: `*대상자:*\n${data["대상"] || "-"}` },
              { type: "mrkdwn", text: `*이동 경로:*\n${data["이전부서"] || "-"} → ${data["이동부서"] || "-"}` },
              { type: "mrkdwn", text: `*신청 사유:*\n${data["사유"] || "없음"}` },
            ],
          },
          ...(data["신청자"] ? [{
            type: "context" as const,
            elements: [{ type: "mrkdwn" as const, text: `👤 신청자: ${data["신청자"]}` }],
          }] : []),
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 ${now}` }] },
        ],
      };
    }

    case "log_alert": {
      const level = (data["레벨"] as string) || "WARN";
      const emoji = LOG_LEVEL_EMOJI[level] || "⚠️";
      const action = translateLogText(data["액션"] || data["actionLabel"] || data["action"] || "");
      const details = data["상세"] || {};
      let detailStr = "";
      if (typeof details === "object" && details !== null) {
        const d = details as Record<string, unknown>;
        const filtered = Object.entries(d)
          .filter(([k]) => !k.startsWith("_") && !["client", "클라이언트", "logLevel", "logPage", "loggedAt", "actionCode", "actionLabel", "actorAccount", "actorName"].includes(k))
          .slice(0, 5);
        detailStr = filtered.map(([k, v]) => `${k}: ${formatLogDetailValue(v)}`).join("\n");
      } else {
        detailStr = formatLogDetailValue(details);
      }
      if (detailStr.length > 300) detailStr = detailStr.substring(0, 300) + "...";

      const fallback = `${emoji} [${level}] ${action}`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: `${emoji} 로그 알림 [${level}]`, emoji: true } },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*레벨:*\n${emoji} ${level}` },
              { type: "mrkdwn", text: `*액션:*\n${action}` },
              { type: "mrkdwn", text: `*페이지:*\n${data["페이지"] || "-"}` },
            ],
          },
          ...(detailStr ? [{
            type: "section" as const,
            text: { type: "mrkdwn" as const, text: `*상세:*\n\`\`\`${detailStr}\`\`\`` },
          }] : []),
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 ${now}` }] },
        ],
      };
    }

    case "product_suggestion_registered": {
      const registeredAt = data["등록완료시각"]
        ? new Date(String(data["등록완료시각"])).toLocaleString("ko-KR", { timeZone: "Asia/Seoul" })
        : now;
      const status = String(data["처리상태"] || "투표중");
      const fallback = `💡 상품 추천 등록: ${data["상품명"] || "-"}`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: "💡 상품 추천 등록 완료", emoji: true } },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*상품명:*\n${data["상품명"] || "-"}` },
              { type: "mrkdwn", text: `*등록 완료 시각:*\n${registeredAt}` },
              { type: "mrkdwn", text: `*처리 상태:*\n${status}` },
            ],
          },
          { type: "context", elements: [{ type: "mrkdwn", text: "🔒 추천자 정보는 비밀 투표 정책에 따라 포함하지 않습니다." }] },
        ],
      };
    }

    case "product_suggestion_vote_completed": {
      const resultCode = String(data["결과"] || "");
      const result = PRODUCT_SUGGESTION_RESULT_LABELS[resultCode] || resultCode || "-";
      const completedAt = data["완료시각"]
        ? new Date(String(data["완료시각"])).toLocaleString("ko-KR", { timeZone: "Asia/Seoul" })
        : now;
      const approve = Number(data["찬성"] || 0).toLocaleString();
      const reject = Number(data["반대"] || 0).toLocaleString();
      const voteCount = Number(data["투표수"] || 0).toLocaleString();
      const fallback = `🗳️ 상품 추천 투표 완료: ${data["상품명"] || "-"} (${result}, 찬성 ${approve}표 / 반대 ${reject}표)`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: "🗳️ 상품 추천 투표 완료", emoji: true } },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*상품명:*\n${data["상품명"] || "-"}` },
              { type: "mrkdwn", text: `*투표 결과:*\n${result}` },
              { type: "mrkdwn", text: `*찬성:*\n${approve}표` },
              { type: "mrkdwn", text: `*반대:*\n${reject}표` },
              { type: "mrkdwn", text: `*총 투표:*\n${voteCount}표` },
              { type: "mrkdwn", text: `*종료 방식:*\n${data["종료방식"] || "-"}` },
            ],
          },
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 투표 완료 시각: ${completedAt}` }] },
          { type: "context", elements: [{ type: "mrkdwn", text: "🔒 추천자와 개별 투표자 정보는 포함하지 않습니다." }] },
        ],
      };
    }

    case "slack_test": {
      return {
        text: "✅ Slack 연결 테스트",
        blocks: [
          { type: "header", text: { type: "plain_text", text: "✅ Slack 연결 테스트", emoji: true } },
          {
            type: "section",
            text: { type: "mrkdwn", text: "운영관리 Slack 알림 경로가 정상적으로 연결되었습니다." },
          },
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 ${now}` }] },
        ],
      };
    }

    case "qna_new": {
      const questionText = String(data["질문"] || "");
      const truncated = questionText.length > 200 ? questionText.substring(0, 200) + "..." : questionText;
      const fallback = `❓ Q&A 질문 등록: ${data["등록자"] || "익명"} - ${truncated}`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: "❓ Q&A 새 질문 등록", emoji: true } },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*등록자:*\n${data["등록자"] || "익명"}` },
            ],
          },
          {
            type: "section",
            text: { type: "mrkdwn", text: `*질문 내용:*\n>${truncated.replace(/\n/g, "\n>")}` },
          },
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 ${now}` }] },
        ],
      };
    }

    default: {
      const fallback = `📢 [${type}] 알림`;
      return {
        text: fallback,
        blocks: [
          { type: "header", text: { type: "plain_text", text: `📢 ${type}`, emoji: true } },
          {
            type: "section",
            text: { type: "mrkdwn", text: `\`\`\`${JSON.stringify(data, null, 2).substring(0, 500)}\`\`\`` },
          },
          { type: "context", elements: [{ type: "mrkdwn", text: `📅 ${now}` }] },
        ],
      };
    }
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (!SLACK_ENABLED) {
    return new Response(JSON.stringify({ success: true, skipped: true, reason: "Slack notifications are disabled" }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }

  let notificationType = "unknown";
  let webhookRequestStarted = false;

  try {
    const { type, data } = await req.json();
    if (!type) {
      return new Response(JSON.stringify({ error: "type is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }
    notificationType = String(type);

    const webhookUrl = resolveWebhookUrl(type, data || {});
    if (!webhookUrl) {
      await recordSlackUsage("webhook_failures", notificationType, undefined, { reason: "missing_webhook_config" });
      return new Response(JSON.stringify({ error: "No webhook configured for this notification type/department", type }), {
        status: 503,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    const payload = formatMessage(type, data || {});
    if (type !== "product_suggestion_registered" && type !== "product_suggestion_vote_completed" && type !== "slack_test") {
      addUserContext(payload, data || {});
    }
    webhookRequestStarted = true;

    const slackRes = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!slackRes.ok) {
      const errText = await slackRes.text();
      console.error("[slack-notify] Slack API error:", slackRes.status, errText);
      await recordSlackUsage("webhook_failures", notificationType, slackRes.status, { reason: "http_error" });
      return new Response(JSON.stringify({ error: "Slack API error", status: slackRes.status }), {
        status: 502,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    await recordSlackUsage("notifications_sent", notificationType, slackRes.status);
    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (err) {
    console.error("[slack-notify] Error:", err);
    if (webhookRequestStarted) {
      await recordSlackUsage("webhook_failures", notificationType, undefined, { reason: "network_error" });
    }
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
