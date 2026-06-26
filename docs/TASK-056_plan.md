# TASK-056 관리 문서/역할 가이드/Slack 룰/신규 DB 설치 계획

- 작성일: 2026-06-18
- 작업자: AI_Codex
- 대상 버전: v3.47.0

## 1. 작업 범위

1. `.cursor/rules`의 권한/작업/신규 admin 페이지 규칙을 최신 권한 체계에 맞게 갱신한다.
2. 사용자/학생/교사/관리자/아키텍처/설정/초기 DB 문서를 최신 소스 기준으로 갱신한다.
3. 부서 담당 교사, 구매 담당 교사, 부장 교사, 전도사님 전용 Markdown 문서와 HTML 가이드 페이지를 추가한다.
4. 소개 메뉴 순서를 학생 가이드, 교사 가이드, 부서 담당 교사 가이드, 구매 담당 교사 가이드, 부장 교사 가이드, 전도사님 가이드, 관리자 가이드 순서로 정리한다.
5. Slack 알림 룰 HTML/Markdown 문서를 추가하고 부장 교사 이상 권한으로 노출한다.
6. 다른 Supabase 프로젝트에서 새로 시작할 수 있도록 초기 설치 SQL과 PowerShell 설치 스크립트를 최신 스키마/RPC/Slack Secret 기준으로 갱신한다.

## 2. 영향 범위

- 메뉴/권한: `js/nav.js`, `js/auth.js`, `admin/page-access.html`, `admin/page-features.html`, `admin/page-permissions.html`
- 신규 페이지: `dept-teacher-guide.html`, `purchase-teacher-guide.html`, `chief-teacher-guide.html`, `evangelist-guide.html`, `admin/slack-rules.html`
- 신규 문서: `docs/DEPT_TEACHER_GUIDE.md`, `docs/PURCHASE_TEACHER_GUIDE.md`, `docs/CHIEF_TEACHER_GUIDE.md`, `docs/EVANGELIST_GUIDE.md`, `docs/SLACK_NOTIFICATION_RULES.md`, `docs/SUPABASE_NEW_PROJECT_SETUP.md`
- 설치: `docs/INITIAL_DATABASE_SETUP.sql`, `scripts/install-supabase-database.ps1`, `.env.example`
- 버전/캐시: `js/version.js`, HTML/CSS/JS 참조 쿼리 `?v=3.47.0`

## 3. 검증 계획

- 새 페이지의 메뉴 노출 권한과 직접 접근 제한을 소스 기준으로 확인한다.
- `node --check`로 수정된 JS 문법을 확인한다.
- `rg`로 구버전 캐시 참조와 충돌 마커 잔존 여부를 확인한다.
- `git diff --check`로 패치 기본 오류를 확인한다.
