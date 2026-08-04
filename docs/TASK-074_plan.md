# TASK-074 작업 계획

- 버전: v3.74.0
- 작성일: 2026-07-11
- 작업명: 활동 로그 영어 저장, 중복 제거, 한글 표시/Slack 치환 통일

## 목표

1. 활동 로그 `details`는 영어 key 기반 처리 상세만 저장한다.
2. 작업명, 사용자 계정, 로그 일시, 로그 레벨, 발생 페이지는 기본 컬럼과 화면 기본 영역에서 처리하고 `details` 중복 저장을 제거한다.
3. 신규 로그에 `_client`, `client`, `클라이언트` 및 IP/브라우저/OS/화면/기기 정보를 저장하지 않는다.
4. 로그 화면, 작업 이력 화면, WARN+ Slack 알림에서는 저장된 영어 action/details를 한글로 치환해 보여준다.
5. 기존 `activity_logs.details`의 한글 별칭/중복/client 항목을 정리하는 운영 SQL을 제공한다.

## 범위

- 공통 로그 모듈: `js/activity-log.js`
- 로그/작업 이력 화면: `admin/logs.html`, `admin/audit.html`
- Slack 로그 알림: `supabase/functions/_shared/slack-notify.ts`
- 문서/가이드: README, 사이트 안내서, 아키텍처 문서, 역할별 가이드, 권한/로그/Slack/작업 이력 룰

## 구현 순서

1. `.cursor/rules` 작업 룰과 기존 로그 구조를 확인한다.
2. `writeLog()` 공통 경로에서 details 정규화, 중복 제거, client 정보 미저장을 적용한다.
3. 사용자 표시명은 `profiles`와 `registration_requests`의 `display_name(username)` 기준으로 조회한다.
4. 로그/작업 이력 화면과 Slack 알림의 한글 치환 표시를 통일한다.
5. 기존 로그 정리 SQL과 운영 문서를 추가한다.
6. 문법 검사, 인라인 스크립트 파싱, 샘플 정규화 테스트를 수행한다.
