# TASK-106 작업 계획 — 메인 즐겨찾기 전체 메뉴 동기화 및 운영 문서 최신화

**작성일:** 2026-08-19  
**기준 버전:** 현재 작업 트리의 `v4.2.8` (미커밋 지급 대상일 변경 포함)

## 1. 현재 상태와 문제점

1. `index.html`의 `ALL_SHORTCUTS`는 `js/nav.js`의 실제 메뉴보다 항목이 적습니다. 현재 즐겨찾기 설정에서 다음 메뉴를 선택할 수 없습니다.
   - `admin/notices.html` — 공지 사항 (40+)
   - `admin/monthly-talents.html` — 월별 달란트 관리 (40+)
   - `admin/purchase-stats.html` — 구매 통계 (60+)
   - `admin/slack-rules.html` — Slack 알림 룰 (80+)
   - `admin/service-stats.html` — 서비스 통계 (80+)
2. `README.md`, `docs/SITE_USER_GUIDE.md`, `docs/PROJECT_ARCHITECTURE_FLOW.md`와 11개 역할/운영 가이드는 작성 기준이 주로 `v3.79.0~v3.89.0`입니다. 실제 코드의 현재 버전과 최근 기능(월별 달란트 관리, 지급 대상일 일요일 기준, QR 수령 발생 시각/지급일 분리, 최신 권한/메뉴)을 충분히 반영하지 못합니다.
3. 특히 권한 룰 문서에는 현재 `js/nav.js`와 다른 사용자 관리·관리자 관리의 최소 권한과, 즐겨찾기 후보 전체 목록이 명확히 정리되어 있지 않습니다.

## 2. 수정 방안

1. `index.html`
   - `ALL_SHORTCUTS`에 위 5개 누락 메뉴를 `js/nav.js`의 `href`, `minPerm`, `authOnly` 규칙과 동일하게 추가합니다.
   - 각 항목에 짧은 제목, 설명, 식별 가능한 아이콘과 기존 카드 팔레트 범위의 색상을 부여합니다.
   - `NAV_MENU`의 즐겨찾기 대상 메뉴와 `ALL_SHORTCUTS`를 대조해 이번 누락 목록이 모두 해소됐음을 정적 검사합니다.
2. 버전과 변경 이력
   - 현재 미커밋 `v4.2.8` 변경은 보존하고, 즐겨찾기 목록 동기화와 문서 갱신을 별도 `v4.2.9` 변경 이력으로 추가합니다.
   - 이 프로젝트의 중앙 버전 검증 구조상 별도 `?v=` 문자열을 추가하지 않고 `js/version.js`의 버전 이력을 기준으로 최신 자산 검증을 유지합니다.
3. 사용자·아키텍처 문서 (3개)
   - 현재 버전·작성 기준·최근 변경 요약을 `v4.2.9` 기준으로 갱신합니다.
   - 즐겨찾기는 네비게이션 권한 규칙과 동일하게 후보를 표시하고, 새로 추가한 5개 메뉴도 해당 권한에서 선택할 수 있음을 설명합니다.
   - 달란트 지급은 한국 시간 기준 발생일이 일요일이면 당일, 월~토요일이면 다음 일요일을 `grant_date`로 기록하고, QR 수령의 발생 시각과 지급 대상일을 구분해 표시하는 현재 동작을 반영합니다.
   - `TASK-104`, `TASK-105` 운영 DB 적용 필요성을 실제 코드 기준으로 명시합니다.
4. 역할별 가이드 (7개)
   - 학생/교사/부서 담당/구매 담당/부장/전도사/관리자 가이드에 권한별로 필요한 최신 달란트 지급 대상일, QR 수령 내역, 월별 관리 또는 즐겨찾기 정보를 반영합니다.
   - 안내 내의 오래된 "현재 기준 v3.79.0" 표기를 현재 기준으로 통일하고, 기존 역할별 권한 제한은 유지합니다.
5. 운영 룰 가이드 (4개)
   - `docs/page-permission-rules.html`의 실제 메뉴 권한표·작성 기준·즐겨찾기 연동 규칙을 `js/nav.js`/`index.html`과 일치시킵니다.
   - 로그·Slack·작업 이력 룰에는 지급 대상일/QR 수령에 대한 최신 기록 원칙을 필요한 범위에서만 추가하고, 기존 개인정보 및 익명 투표 보호 원칙은 바꾸지 않습니다.
6. 작업 보고·검증 문서
   - 코드 수정 후 `docs/TASK-106_test_scenario.md`, `docs/TASK-106_test_result.md`, `docs/TASK-106_change_report.md`를 작성합니다.

## 3. 영향 범위

| 구분 | 파일 |
|---|---|
| 화면/기능 | `index.html`, `js/version.js` |
| 사용자 문서 | `README.md`, `docs/SITE_USER_GUIDE.md`, `docs/PROJECT_ARCHITECTURE_FLOW.md` |
| 역할별 가이드 | `guide.html`, `teacher-guide.html`, `dept-teacher-guide.html`, `purchase-teacher-guide.html`, `chief-teacher-guide.html`, `evangelist-guide.html`, `admin-guide.html` |
| 운영 룰 페이지 | `docs/page-permission-rules.html`, `admin/log-rules.html`, `admin/slack-rules.html`, `admin/audit-rules.html` |
| 작업 산출물 | `docs/TASK-106_test_scenario.md`, `docs/TASK-106_test_result.md`, `docs/TASK-106_change_report.md` |

현재 사용자가 수정 중인 `admin/talent-qr.html`, `admin/talents.html`, `js/talent.js`, `talent-receive.html` 및 기존 SQL 파일은 직접 수정하지 않습니다. 다만 그 변경에 포함된 현재 동작을 문서에 정확히 반영합니다. `js/version.js`는 기존 미커밋 `v4.2.8` 항목을 보존한 채 새 항목만 추가합니다.

## 4. 예정 검증 시나리오

| ID | 확인 내용 | 기대 결과 | 확인 방법 |
|---|---|---|---|
| T1 | 네비게이션과 즐겨찾기 경로 대조 | 즐겨찾기 대상 `NAV_MENU` 경로가 모두 `ALL_SHORTCUTS`에 존재 | 정적 경로 비교 스크립트 |
| T2 | 권한 규칙 | 추가 5개 항목의 최소 권한이 네비게이션과 동일 | `minPerm`/`minRank` 값 코드 리뷰 |
| T3 | 문서 최신성 | 세 문서와 11개 가이드에 오래된 현재 기준(`v3.79.0`, `v3.89.0`)이 남지 않음 | 텍스트 검색 및 문맥 검토 |
| T4 | 지급 대상일 설명 | 월~토요일 다음 일요일·일요일 당일, QR 발생 시각과 지급일 분리가 일관됨 | 관련 문서/가이드 상호 검토 |
| T5 | HTML/JavaScript 문법 | 수정 HTML과 `js/version.js`가 파싱 가능 | `node --check` 및 HTML 구조 정적 검토 |
| T6 | 인코딩/작업 트리 보호 | 한글 UTF-8(BOM 없음) 유지, 기존 사용자 수정이 보존됨 | 바이트 확인 및 `git diff` 범위 검토 |

## 5. 배포 및 Git 기준

- DB 스키마/RPC를 새로 변경하지 않습니다. 운영 DB에는 선행 작업의 `TASK-104`, `TASK-105` 적용 여부만 문서에서 안내합니다.
- 커밋·push는 별도 승인 범위로 보고, 현재 단계에서는 수행하지 않습니다. 진행 시에는 `develop` 브랜치와 `AI_Cursor <ai@cursor>` author 규칙을 적용합니다.
