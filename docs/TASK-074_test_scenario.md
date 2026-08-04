# TASK-074 테스트 시나리오

- 버전: v3.74.0
- 작성일: 2026-07-11

## TC-01 신규 로그 details 정규화

1. `writeLog()`에 한글 key, 영어 key, `_client`, `클라이언트`, 사용자/레벨/페이지 중복 값을 섞어 전달한다.
2. 저장용 details에 영어 key만 남는지 확인한다.
3. actor와 동일한 `대상`/`아이디`, `_actionLabel`, `_actionKo`, `_client`, `클라이언트`, `레벨`, `페이지`가 제거되는지 확인한다.

## TC-02 로그인 중복 로그 제거

1. 로그인 성공/실패 흐름에서 `login()` 내부 로그와 화면 로그가 중복 호출되지 않는지 확인한다.
2. 성공/실패 각각 한 번만 `LOGIN_SUCCESS`/`LOGIN_FAIL`로 기록되는지 확인한다.

## TC-03 로그 화면 표시

1. `admin/logs.html`에서 사용자 컬럼이 `profiles.display_name(username)`을 우선 표시하는지 확인한다.
2. 승인 대기/미승인 계정은 `registration_requests.display_name(username)` 기준으로 표시되는지 확인한다.
3. 상세 모달에서 시간, 레벨, 액션, 페이지, 사용자 기본 영역과 처리 상세 영역이 분리되는지 확인한다.

## TC-04 작업 이력 표시

1. `admin/audit.html`에서 작업자와 대상이 profiles/registration_requests 기준으로 해석되는지 확인한다.
2. 영어 저장 details가 한글 상세로 변환되는지 확인한다.
3. 상세 JSON 표시가 HTML escape 처리되는지 확인한다.

## TC-05 Slack WARN+ 로그 알림

1. WARN 이상 로그 발생 시 `log_alert` body가 한글 액션명과 한글 상세를 포함하는지 확인한다.
2. Slack Edge Function에서 `_`, client, actor, level/page/time 중복 detail을 제외하는지 확인한다.

## TC-06 기존 데이터 정리 SQL

1. `docs/TASK-074_activity_logs_english_details.sql`을 검토한다.
2. 한글 별칭을 영어 key로 바꾸고 중복 값은 한 번만 남기는지 확인한다.
3. client 및 기본 컬럼 중복 값이 제거되는지 확인한다.
