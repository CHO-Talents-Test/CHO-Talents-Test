# TASK-056 변경 보고서

- 작성일: 2026-06-18
- 작업자: AI_Codex
- 대상 버전: v3.47.0

## 1. 요약

최신 소스의 권한 체계와 운영 기능을 기준으로 관리 문서, 역할별 가이드, Slack 알림 룰 문서, 신규 Supabase 설치 자료를 갱신했다. 소개 메뉴에는 부서 담당 교사, 구매 담당 교사, 부장 교사, 전도사님 가이드를 추가했고, Slack 알림 룰 페이지는 부장 교사 이상 권한으로 추가했다.

## 2. 주요 변경

- `.cursor/rules`의 페이지 권한 매핑, 신규 admin 페이지 가이드, 작업 프로세스 문서 목록 갱신
- `guide.html`, `teacher-guide.html`, `admin-guide.html`의 가이드 전환 메뉴 최신화
- 역할별 신규 HTML/Markdown 가이드 추가
- `admin/slack-rules.html`과 `docs/SLACK_NOTIFICATION_RULES.md` 추가
- `docs/INITIAL_DATABASE_SETUP.sql`에 최신 RPC, RLS, `page_sizes`, `source`, Slack Secret 참조 반영
- `scripts/install-supabase-database.ps1`와 `.env.example`에 새 Supabase 프로젝트 설정값 보강
- `docs/SUPABASE_NEW_PROJECT_SETUP.md` 신규 작성
- `js/version.js`를 v3.47.0으로 갱신하고 캐시 버스팅 참조를 `?v=3.47.0`으로 변경

## 3. 검증

- JS 문법 검사 PASS
- 구버전 캐시 참조 검색 PASS
- 충돌 마커 검색 PASS
- `git diff --check` PASS
