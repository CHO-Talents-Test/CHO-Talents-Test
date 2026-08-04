# Slack 알림 룰

Slack 알림은 브라우저 이벤트가 `sendSlackNotify(type, data)`를 호출하고, Supabase Edge Function `slack-notify`가 알림 유형과 부서명에 맞는 Webhook Secret을 선택해 전송하는 구조다. v3.74.0부터 WARN+ 로그 알림은 영어로 저장된 `action`/`details`를 한글 라벨로 변환해서 전송한다.

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
| `log_alert` | `js/activity-log.js` WARN 이상 로그 | 로그 레벨. 액션/상세는 한글 치환 후 전송 | 운영 채널 |
| `product_suggestion_registered` | `product-suggestions.html` 추천 등록 완료 | 상품명, 등록 완료 시각, 처리 상태 | 운영관리 채널 |
| `product_suggestion_vote_completed` | `admin/product-suggestion-votes.html` 채택/불채택 종료 | 상품명, 결과, 찬성/반대/총 득표 수, 종료 방식 | 운영관리 채널 |

## 로그 알림 상세 기준

- `activity_logs.action`과 `activity_logs.details`는 영어 key 기준으로 저장한다.
- Slack `log_alert`에는 작업명, 레벨, 발생 페이지, 처리 상세를 한글 라벨로 표시한다.
- 사용자 계정, 일시, 레벨, 발생 페이지처럼 기본 컬럼으로 표현되는 값은 `details` 중복 항목으로 보내지 않는다.
- `_client`, `client`, `클라이언트` 같은 브라우저/기기 정보는 신규 로그 알림 상세에 포함하지 않는다.
- 상품 추천 Slack 알림은 추천자와 개별 투표자 정보를 포함하지 않으며, Edge Function도 사용자 계정/표시 이름 컨텍스트를 추가하지 않는다.
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
