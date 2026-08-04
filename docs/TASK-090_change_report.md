# TASK-090 변경 보고 — 상품 추천 투표 최고관리자 특례 권한

## 변경 내용

- 상품 추천 투표 화면의 진행 중 집계·조기 종료·직접 결정 UI를 세션의 `isSuperAdmin` 값으로 제한했습니다.
- TASK-090 SQL에서 `vote_product_suggestion`, `get_product_suggestion_vote_items`, `close_product_suggestion_vote`, `admin_resolve_product_suggestion`을 재정의했습니다.
- 일반 관리자(100)는 종료 전 익명 득표·정원 정보를 받을 수 없고, 직접 결정·정원 감소 종료 RPC 호출도 서버에서 거부됩니다.
- `profiles.is_super_admin=true`인 최고관리자만 위 특례를 사용할 수 있습니다. 종료 후 득표 공개와 부서 담당 교사 이상의 일반 투표 권한은 유지합니다.
- 조기 종료·직접 결정의 작업 이력과 Slack 종료 방식 표기를 최고관리자로 변경했습니다.
- 기본 DB 설치 스크립트, 중앙 문서, 역할별 가이드와 버전 이력을 v3.88.0 기준으로 갱신했습니다.

## 적용 순서

1. `docs/TASK-089_product_suggestion_slack_notifications.sql` 적용 여부를 확인합니다.
2. `docs/TASK-090_product_suggestion_super_admin_vote_privileges.sql`을 실행합니다.
3. 일반 관리자와 최고관리자 계정으로 `docs/TASK-090_test_scenario.md`를 확인합니다.
