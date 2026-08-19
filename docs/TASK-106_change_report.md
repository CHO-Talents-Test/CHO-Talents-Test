# TASK-106 변경 보고 — 즐겨찾기 전체 메뉴 동기화 및 운영 문서 최신화

**버전:** v4.2.9  
**작업일:** 2026-08-19

## 변경 요약

1. 메인 즐겨찾기와 상단 네비게이션의 메뉴 구성을 동기화했습니다.
   - 추가: 공지 사항(40+), 월별 달란트 관리(40+), 구매 통계(60+), Slack 알림 룰(80+), 서비스 통계(80+)
   - 정정: 사용자 관리(80+), 관리자 관리(90+), 버전(100+)의 즐겨찾기 메타 권한
2. 중앙 버전을 `v4.2.9`로 갱신하고 변경 이력을 추가했습니다.
3. README, 사용자 안내서, 아키텍처 문서와 역할별 7개/운영 룰 4개 가이드를 현재 메뉴·권한·달란트 지급 대상일 기준으로 갱신했습니다.
4. 지급일 문서 기준을 통일했습니다.
   - 일요일 발생 지급: 당일
   - 월~토요일 발생 지급: 다음 일요일
   - QR 수령: 실제 발생 시각과 지급 대상일 분리 표시

## 수정 파일

- 기능/버전: `index.html`, `js/version.js`
- 핵심 문서: `README.md`, `docs/SITE_USER_GUIDE.md`, `docs/PROJECT_ARCHITECTURE_FLOW.md`
- 역할별 가이드: `guide.html`, `teacher-guide.html`, `dept-teacher-guide.html`, `purchase-teacher-guide.html`, `chief-teacher-guide.html`, `evangelist-guide.html`, `admin-guide.html`
- 운영 룰: `docs/page-permission-rules.html`, `admin/log-rules.html`, `admin/slack-rules.html`, `admin/audit-rules.html`
- 작업 산출물: `docs/TASK-106_plan.md`, `docs/TASK-106_test_scenario.md`, `docs/TASK-106_test_result.md`, `docs/TASK-106_change_report.md`

## 운영 적용 메모

- 이번 TASK는 프런트엔드 즐겨찾기와 문서 동기화만 변경하며, 새 DB 스키마/RPC는 추가하지 않습니다.
- 지급 대상일 동작을 운영 DB에 반영하려면 선행 변경의 `docs/TASK-104_qr_grant_date.sql`, `docs/TASK-105_sunday_grant_dates.sql`이 적용되어 있어야 합니다.
- 기존 미커밋 지급 기능 파일과 SQL 파일은 보존했으며, 이 보고서 작업에서 직접 수정하지 않았습니다.
