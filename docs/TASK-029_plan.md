# TASK-029: v3.12.0 기능 수정 + 문서 정비 - 작업 계획서

## 버전: v3.12.0
## 작성일: 2026-05-29
## 작성자: AI_Cursor

---

## 1. 작업 개요
v3.12.0에서는 기존 기능의 버그 수정, UI/UX 개선, 문서 정비를 수행합니다.

## 2. 수정 대상

### 2-1. 페이지 기능 (admin/page-features.html)
- `role_page_features` 테이블 생성 + RLS 정책 추가 + PostgREST 스키마 캐시 리로드
- 그리드 구조 변경: 4열 → 6열 (구분/유형/권한/등급/설명/관리)

### 2-2. 메인 페이지 (index.html)
- 로그인 상태에서 "로그아웃" 버튼 표시, 이모지 변경

### 2-3. 네비게이션 통합
- admin nav 기준으로 public/admin 모든 페이지 항목/순서 일치화
- admin 15개 파일에 "달란트 적립" 링크 추가
- public 3개 파일에 전체 admin nav 항목 추가 + 배지 호출

### 2-4. 달란트 관리 (admin/talents.html)
- "달란트 항목 관리" 페이지 이동 버튼 추가

### 2-5. 구매 관리 (admin/purchases.html)
- 탭 순서 변경: 전체 > 구매 신청 > 상품 준비 > 상품 구매 > 상품 지급
- 기본 선택 탭: 전체

### 2-6. 로그 (admin/logs.html)
- 카운트 형식: `활동 로그 (50/74)` (현재 페이지 건수 / 전체 활성 로그 수)
- 페이지네이션: 번호 5개 + 말줄임(...) + 총 페이지 표시

### 2-7. 작업 이력 (admin/audit.html)
- roleKey/permissionKey 등 대상 명칭 한글화
- 상세 모달 JSON 키 한글 라벨 추가

### 2-8. 문서 작성 + 보고서 등록
- TASK-029 문서 4종 생성 (계획서/테스트 시나리오/결과/완료 보고서)
- 보고서 페이지에 4종 타입별 등록
- 기존 누락 문서 연결

## 3. 수정 대상 파일
- `admin/page-features.html`, `index.html`
- `shop.html`, `earn-talents.html`, `my-talents.html`
- Admin 15개 HTML 파일
- `admin/talents.html`, `admin/purchases.html`
- `admin/logs.html`, `admin/audit.html`
- `admin/reports.html`, `js/version.js`
- `docs/` 폴더 (4종 문서)
- Supabase: `role_page_features` 테이블/RLS
