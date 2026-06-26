# TASK-005 변경 보고서: 사용자 관리 및 역할 배지

## 작업 개요
- **작업 ID**: TASK-005
- **버전**: v1.4.0
- **작업일**: 2026-05-26
- **작업자**: AI

## 변경 사항

### 1. 관리자 사용자 관리 페이지 (`admin/users.html`)
- 전체 사용자 CRUD (등록, 수정, 삭제)
- 역할 변경 (관리자, 부서관리자, 교사, 학생)
- 소속 부서 / 담당 관리 부서 설정
- 비밀번호 초기화 (1234)
- 역할별 필터링 조회 (전체/관리자/부서관리자/교사/학생)
- 역할별 통계 카드 (전체, 관리자, 부서관리자, 교사, 학생 수)
- admin 네비게이션 전체에 "사용자 관리" 링크 추가

### 2. 역할 배지 시스템
- `auth.js`에 `ROLE_EMOJI` 매핑 추가 (👑관리자, 📋부서관리자, 👩‍🏫교사, 🎒학생)
- `renderRoleBadge()` 함수: 이모지 + 이름 + 역할 라벨 표시
- 클릭 시 역할별 대시보드/페이지로 이동:
  - 👑 관리자 → `admin/index.html`
  - 📋 부서 관리자 → `manager/index.html`
  - 👩‍🏫 교사 → `teacher/my-talents.html`
  - 🎒 학생 → `student/my-talents.html`
- 전체 15개 페이지에서 기존 텍스트 표시를 역할 배지로 교체

## 변경 파일 목록

| 파일 | 상태 | 설명 |
|------|------|------|
| `admin/users.html` | 신규 | 사용자 관리 페이지 |
| `js/auth.js` | 수정 | ROLE_EMOJI + renderRoleBadge() 추가 |
| `js/version.js` | 수정 | v1.4.0 이력 추가 |
| admin 7개 HTML | 수정 | 네비에 사용자관리 추가 + 역할 배지 |
| manager 5개 HTML | 수정 | 역할 배지 |
| teacher 2개 HTML | 수정 | 역할 배지 |
| student 1개 HTML | 수정 | 역할 배지 |
| `docs/TASK-005_change_report.md` | 신규 | 변경 보고서 |
