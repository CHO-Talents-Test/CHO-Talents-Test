# TASK-089 변경 보고 — 상품 추천 운영관리 Slack 알림

## 변경 내용

- 상품 추천 등록 완료와 투표 종료용 Slack 이벤트를 추가했다.
- 운영관리 Webhook(`SLACK_WEBHOOK_OPERATIONS`)을 재사용하며 새 Secret은 필요하지 않다.
- 종료 알림은 기본 과반, 관리자 현재 유효 정원 종료, 관리자 직접 결정을 모두 지원한다.
- 관리자 직접 결정 RPC가 종료 시점의 익명 투표 집계를 반환하도록 보강했다.
- 비밀 투표를 보호하기 위해 추천자와 개별 투표자 정보는 Slack 메시지와 context에서 제외했다.

## 배포 순서

1. `docs/TASK-089_product_suggestion_slack_notifications.sql` 실행
2. `supabase/functions/slack-notify` Edge Function 최신 소스 배포
3. 운영관리 Slack 채널에서 등록·종료 시나리오 점검
