# TASK-085 상품 추천과 비밀 투표 테스트 결과

## 정적 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| `node --check` | 통과 | `js/product-suggestion.js`, `nav.js`, `auth.js`, `codes.js`, `activity-log.js`, `version.js` |
| 신규 HTML 인라인 스크립트 컴파일 | 통과 | `product-suggestions.html`, `admin/product-suggestion-votes.html` |
| 추천 상세/상품 노출 화면 컴파일 | 통과 | `product-suggestions.html`, `admin/product-suggestion-votes.html`, `shop.html`, `admin/shop.html` |
| 상품 추천 투표 배지 연결 | 통과 | `navProductSuggestionVoteBadge`, `get_unvoted_product_suggestion_count`, 상품 상위 배지 합산 호출 확인 |
| 보호 페이지 초기화 순서 | 통과 | `initSupabase` → `navInit` → `initPage` → `autoLogPageView` 확인 |
| 메뉴/페이지 ID/RPC 연결 | 통과 | 내비게이션, `detectCurrentPageId`, 페이지 접근/기능 목록, RPC 이름 교차 확인 |
| Bash 설치 스크립트 문법 | 통과 | `bash -n scripts/install-supabase-database.sh` |
| TASK-085 합본 SQL 생성 | 통과 | `bash scripts/install-supabase-database.sh --generate-only`로 상품 추천 RPC 포함 확인 |
| 미투표 배지 RPC 합본 포함 | 통과 | 생성 SQL에서 함수 생성과 `authenticated` 실행 권한 확인 |
| UUID/text 호환성 점검 | 통과 | 권한 계산은 `profiles.permission_level` 텍스트를 사용하고 Storage `owner_id`는 텍스트 비교 |
| 병합 충돌 마커 | 통과 | 작업 대상 파일에서 충돌 마커 없음 |

DB RPC/Storage 정책은 실제 Supabase 프로젝트에 `TASK-085_product_suggestions.sql`을 적용한 뒤 TS-01~TS-16을 수행해야 한다.

## 수동 검증 필요 항목

- 실제 로그인 계정별 비밀 결과 노출과 관리자 전용 익명 집계
- 추천 등록 시점 정원 스냅샷 및 권한 변경 후 현재 유효 정원 종료 조건
- 일반 사용자 추천 이미지 업로드 Storage 정책
- 상품 구매의 비활성 채택 상품 비노출과 상품 관리의 상태 표시
- 모바일 5열 투표 그리드와 상세 모달 투표

실제 운영 DB 변경이나 브라우저 로그인 세션을 사용하지 않은 코드 작업 환경에서는 위 항목을 자동 실행하지 않는다.
