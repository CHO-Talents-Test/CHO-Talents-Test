# TASK-089 작업 계획 — 상품 추천 운영관리 Slack 알림

## 목적

상품 추천 등록 완료와 투표 종료를 운영관리 Slack 채널에 알린다. 등록 알림에는 상품명과 등록 시각을, 종료 알림에는 상품명·결과·익명 득표 수를 제공한다.

## 현재 상태와 문제

- 기존 Slack Edge Function은 구매, 가입, 부서 이동, WARN 이상 로그, Q&A만 라우팅한다.
- 상품 추천 등록·투표 종료는 운영관리자가 별도로 화면이나 로그를 확인해야 한다.
- 비밀 투표 정책상 추천자와 개별 투표자 정보는 Slack에 포함하면 안 된다.

## 구현 방안

1. `product_suggestion_registered`, `product_suggestion_vote_completed` 유형을 `SLACK_WEBHOOK_OPERATIONS`로 라우팅한다.
2. 추천 등록, 기본 과반 종료, 관리자 현재 유효 정원 종료, 관리자 직접 결정의 성공 직후 알림을 보낸다.
3. 관리자 직접 결정 RPC가 종료 당시의 익명 찬성·반대·총 투표 수를 반환하도록 TASK-089 SQL을 추가한다.
4. 두 상품 추천 알림은 Edge Function의 사용자 계정/표시 이름 컨텍스트를 생략한다.

## 영향 파일

- `js/product-suggestion.js`, `product-suggestions.html`, `admin/product-suggestion-votes.html`
- `js/slack-notify.js`, `supabase/functions/_shared/slack-notify.ts`
- `docs/TASK-089_product_suggestion_slack_notifications.sql`
- 설치 스크립트, 운영 문서, 역할별 가이드, 버전 이력
