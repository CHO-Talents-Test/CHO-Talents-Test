# TASK-056 테스트 시나리오

- 작성일: 2026-06-18
- 대상 버전: v3.47.0

## 1. 정적 검증

| 번호 | 검증 항목 | 방법 | 기대 결과 |
|---:|---|---|---|
| 1 | JS 문법 | `node --check js/version.js`, `js/auth.js`, `js/nav.js` | 문법 오류 없음 |
| 2 | 캐시 버전 | `rg "\?v=3\.46\.0"` | 결과 없음 |
| 3 | 충돌 마커 | `rg "^(<<<<<<<|=======|>>>>>>>)"` | 결과 없음 |
| 4 | 패치 기본 오류 | `git diff --check` | 오류 없음 |

## 2. 권한/메뉴 검증

| 번호 | 검증 항목 | 방법 | 기대 결과 |
|---:|---|---|---|
| 1 | 소개 메뉴 순서 | `js/nav.js` 확인 | 신규 역할 가이드가 관리자 가이드 위에 순서대로 위치 |
| 2 | 새 가이드 접근 | 각 HTML 하단 접근 로직 확인 | 부서 담당 60+, 구매 담당 70+, 부장 80+, 전도사님 90+ |
| 3 | Slack 룰 접근 | `admin/slack-rules.html` 확인 | `initPage(80, '../login.html')` 사용 |
| 4 | DB 기반 페이지 접근 | `js/auth.js`, `admin/page-access.html` 확인 | 신규 page_id가 탐지/관리 목록에 포함 |

## 3. 신규 Supabase 설치 검증

| 번호 | 검증 항목 | 방법 | 기대 결과 |
|---:|---|---|---|
| 1 | 최신 RPC 포함 | `docs/INITIAL_DATABASE_SETUP.sql` 검색 | `cancel_product_order`, `scan_qr_talent` 포함 |
| 2 | Slack Secret 포함 | SQL/스크립트/.env 검색 | 9개 Slack Webhook Secret 참조 포함 |
| 3 | 최신 설정 포함 | SQL 검색 | `user_preferences.page_sizes`, `talent_transactions.source` 포함 |
