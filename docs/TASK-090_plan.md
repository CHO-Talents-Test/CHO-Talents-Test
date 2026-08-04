# TASK-090 작업 계획 — 상품 추천 투표 최고관리자 특례 권한

## 목적

상품 추천 투표에서 진행 중 익명 득표 수 열람, 투표 중 채택·불채택 직접 결정, 현재 유효 유권자 수가 등록 시점 과반보다 적을 때의 종료 처리를 일반 관리자 권한과 분리한다. 이 특례는 `profiles.is_super_admin = true`인 계정만 사용할 수 있다.

## 현재 상태와 문제

- 화면과 일부 RPC가 `permission_level`의 관리자 등급(100+)을 기준으로 진행 중 집계와 결정 기능을 제공한다.
- 일반 관리자도 RPC를 직접 호출하면 특례 기능 또는 진행 중 집계에 접근할 여지가 있다.

## 구현 방안

1. 투표 화면은 세션의 `isSuperAdmin` 값이 `true`일 때만 진행률·득표 수·조기 종료·직접 결정 UI를 렌더링한다.
2. `vote_product_suggestion`, `get_product_suggestion_vote_items`, `close_product_suggestion_vote`, `admin_resolve_product_suggestion`을 TASK-090 SQL에서 재정의한다.
3. 진행 중 집계와 현재 유효 정원은 최고관리자에게만 반환하고, 일반 관리자 직접 RPC 호출은 종료·결정 시 서버에서 거부한다.
4. 기존 투표 참여 권한(부서 담당 교사 60+), 종료 후 득표 공개, 추천 등록 시 관리자 즉시 채택 규칙은 변경하지 않는다.

## 영향 파일

- `admin/product-suggestion-votes.html`
- `docs/TASK-090_product_suggestion_super_admin_vote_privileges.sql`
- 설치 스크립트, 중앙 운영 문서, 역할별 가이드, 버전 이력
