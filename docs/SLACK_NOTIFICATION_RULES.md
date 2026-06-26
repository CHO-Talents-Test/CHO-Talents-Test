# Slack 알림 룰

Slack 알림은 브라우저 이벤트가 `sendSlackNotify(type, data)`를 호출하고, Supabase Edge Function `slack-notify`가 알림 유형과 부서명에 맞는 Webhook Secret을 선택해 전송하는 구조다.

## 호출 구조

```text
화면 이벤트
-> js/slack-notify.js sendSlackNotify(type, data)
-> _sb.functions.invoke('slack-notify')
-> docs/edge-function-slack-notify.ts
-> Slack Incoming Webhook
```

## 알림 유형

| type | 발생 위치 | 라우팅 기준 | 대상 채널 |
|---|---|---|---|
| `purchase_new` | `shop.html` 일반 구매, 대리 구매 | `data.부서` | 해당 부서 채널 |
| `purchase_status` | `admin/purchases.html` 구매 신청 -> 상품 준비 | 상태 전환 | 상품 관리 채널 |
| `user_register` | `register.html` 계정 등록 신청 | `data.부서` | 해당 부서 채널 |
| `dept_transfer` | `admin/users.html` 부서 이동 요청 | `data.이동부서` | 이동 대상 부서 채널 |
| `log_alert` | `js/activity-log.js` WARN 이상 로그 | 로그 레벨 | 운영 채널 |
| `qna_new` | `qna.html` 새 질문 등록 | 고정 | Q&A 채널 |

## Edge Function Secrets

| Secret | 용도 |
|---|---|
| `SLACK_WEBHOOK_PART1` ~ `SLACK_WEBHOOK_PART5` | 1부~5부 채널 |
| `SLACK_WEBHOOK_WORSHIP` | 예배부 채널 |
| `SLACK_WEBHOOK_PRODUCT_MANAGEMENT` | 상품 관리 채널 |
| `SLACK_WEBHOOK_OPERATIONS` | 운영 로그 채널 |
| `SLACK_WEBHOOK_ANSWER` | Q&A 채널 |

Webhook 원문은 정적 HTML/JS나 `app_config`에 저장하지 않는다. Supabase Edge Function Secret 또는 서버 환경변수에만 저장한다.

