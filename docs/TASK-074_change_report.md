# TASK-074 변경 보고서

- 버전: v3.74.0
- 작성일: 2026-07-11
- 작업명: 활동 로그 영어 저장과 한글 표시 분리

## 변경 요약

| 영역 | 변경 전 | 변경 후 |
|---|---|---|
| 로그 저장 | 한글/영문 key와 `_actionLabel`, `_actionKo`, client 항목이 함께 저장될 수 있음 | `details`를 영어 key로 정규화하고 중복/기본 표시/client 항목 제거 |
| 사용자 표시 | 저장된 username 또는 details 보조 값 중심 | `profiles.display_name(username)`, 미승인 계정은 `registration_requests.display_name(username)` 기준 표시 |
| 로그 화면 | 액션 영문 key 병기, client 컬럼 표시 | 한글 액션명만 표시, client 컬럼 제거, 상세는 처리 내용만 표시 |
| 작업 이력 | 별도 상세 포맷터 중심 | 공통 한글 details 변환을 사용하고 대상/작업자 조회 보강 |
| Slack 로그 알림 | 저장 details 일부가 그대로 전달될 수 있음 | WARN+ 알림에 한글 액션명과 한글 처리 상세만 전달 |
| 로그인 로그 | 화면과 `login()` 내부가 성공/실패 로그를 중복 기록 | `login()` 내부 기록만 남겨 중복 제거 |
| 기존 데이터 | 과거 한글 별칭/client details가 남을 수 있음 | `docs/TASK-074_activity_logs_english_details.sql` 제공 |

## 주요 수정 파일

- `js/activity-log.js`
- `admin/logs.html`
- `admin/audit.html`
- `login.html`
- `supabase/functions/_shared/slack-notify.ts`
- `docs/TASK-074_activity_logs_english_details.sql`
- `js/version.js`
- README 및 운영/역할별 가이드 문서

## 운영 참고

- 신규 로그는 브라우저/기기/IP 정보를 저장하지 않는다.
- 과거 운영 DB의 기존 로그를 정리하려면 Supabase SQL Editor에서 `docs/TASK-074_activity_logs_english_details.sql`을 실행한다.
- Slack `log_alert`는 저장값이 아니라 한글 치환 결과를 사용자에게 보여주는 기준으로 유지한다.
