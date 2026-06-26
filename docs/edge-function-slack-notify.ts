// Supabase Edge Function: slack-notify
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

const LOG_LEVEL_EMOJI: Record<string, string> = {
  WARN: "⚠️",
  ERROR: "🔴",
  FATAL: "💀",
  CRITICAL: "🚨",
};

interface SlackBlock {
  type: string;
  text?: { type: string; text: string; emoji?: boolean };
  elements?: Array<{ type: string; text: string }>;
  fields?: Array<{ type: string; text: string }>;
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
      const action = data["액션"] as string || "";
      const details = data["상세"] || {};
      let detailStr = "";
      if (typeof details === "object" && details !== null) {
        const d = details as Record<string, unknown>;
        const filtered = Object.entries(d)
          .filter(([k]) => !k.startsWith("_"))
          .slice(0, 5);
        detailStr = filtered.map(([k, v]) => `${k}: ${v}`).join("\n");
      } else {
        detailStr = String(details);
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

  try {
    const { type, data } = await req.json();
    if (!type) {
      return new Response(JSON.stringify({ error: "type is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    const webhookUrl = resolveWebhookUrl(type, data || {});
    if (!webhookUrl) {
      return new Response(JSON.stringify({ error: "No webhook configured for this notification type/department", type, data }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    const payload = formatMessage(type, data || {});

    const slackRes = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!slackRes.ok) {
      const errText = await slackRes.text();
      console.error("[slack-notify] Slack API error:", slackRes.status, errText);
      return new Response(JSON.stringify({ error: "Slack API error", status: slackRes.status }), {
        status: 502,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (err) {
    console.error("[slack-notify] Error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
