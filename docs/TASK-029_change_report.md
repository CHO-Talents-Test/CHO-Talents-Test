# TASK-029: v3.12.0 기능 수정 + 문서 정비 - 작업 완료 보고서

## 버전: v3.12.0
## 작성일: 2026-05-29
## 작성자: AI_Cursor

---

## 변경 사항 요약

### 1. 페이지 기능 관리 (admin/page-features.html)
- `role_page_features` 테이블 생성 (Supabase Management API)
- RLS 정책 추가 (SELECT: authenticated, INSERT/UPDATE/DELETE: rank >= 90)
- PostgREST 스키마 캐시 리로드
- PERM_LIST에 `userType`, `perm` 필드 추가
- 테이블 4열 → 6열 변경 (구분/유형/권한/등급/설명/관리)
- `renderPermTable()`: 유형(교사/학생), 권한(PERMISSION_LABELS) 컬럼 추가

### 2. 메인 페이지 (index.html)
- 비로그인: `🔐 로그인` 이모지
- 로그인: `🔓 로그아웃` 이모지
- `loadAuthSession()` try-catch 래핑

### 3. 네비게이션 통합
- Admin 15개 파일: "달란트 적립" nav 항목 추가
- Public 3개 파일(shop/earn-talents/my-talents): admin nav 전체 항목 동일 순서 구성
  - 순서: 대시보드 > 사용자관리(배지) > 부서관리 > 관리자관리 > 내달란트 > 달란트적립 > 달란트관리 > 상품구매 > 상품관리 > 구매관리(배지) > 보고서 > 로그(배지) > 페이지접근 > 페이지기능 > 작업이력 > 버전
- Public 페이지에 `updateNavOrderBadge()` 호출 추가
- 중복 `querySelectorAll('[data-min-perm]')` 코드 제거

### 4. 달란트 관리 (admin/talents.html)
- 제목 영역에 "📋 달란트 항목 관리" 버튼 추가 (`talent-items.html` 링크)

### 5. 구매 관리 (admin/purchases.html)
- 탭 순서: 전체 > 구매 신청 > 상품 준비 > 상품 구매 > 상품 지급
- 기본 선택: `currentPTab = 'all'`, `tabAll` active
- `TAB_IDS` 배열 순서 변경
- 초기 테이블 제목: "전체 목록"
- `statusFilterWrap` 초기 표시

### 6. 로그 (admin/logs.html)
- 제목: `활동 로그 (현재건수/전체건수)` 형식
- 별도 count 쿼리: `_sb.from('activity_logs').select('*', { count: 'exact', head: true })`
- 페이지네이션 개선: 번호 버튼 5개, 말줄임(...), 총 페이지 수 표시

### 7. 작업 이력 (admin/audit.html)
- `PERM_KEY_LABELS`: super_admin~student 7개 한글 매핑
- `DETAIL_KEY_LABELS`: 40+ 필드 한글 매핑
- `extractTarget()`: roleKey/permissionKey 한글 변환
- `localizeDetailJson()`: 상세 모달 JSON 키 한글 라벨 병기 + 값 변환

### 8. 문서 + 보고서
- docs/TASK-029_plan.md, test_scenario.md, test_result.md, change_report.md 생성
- REPORT_SEED_MAP + SEED에 TASK-029 4종 타입 추가
- 기존 누락 문서(TASK-001 plan/test_scenario/test_result, TASK-002 plan/test_scenario/test_result, TASK-007 security_report, TASK-010 security_report, TASK-011 test_scenario) 연결

## 수정 파일 목록
- `admin/page-features.html`
- `index.html`
- `shop.html`, `earn-talents.html`, `my-talents.html`
- Admin HTML 15개 파일
- `admin/talents.html`, `admin/purchases.html`
- `admin/logs.html`, `admin/audit.html`
- `admin/reports.html`
- `js/version.js`
- `docs/TASK-029_*.md` (4개)
