# TASK-082 작업 계획 — 최고관리자 로그인 이력 제외

`profiles.is_super_admin=true`인 계정은 사용자 로그인 이력에 새로 저장하지 않고, 기존 이력을 정리하며 사용자 통계에서도 제외한다.

적용 범위는 `record_user_login()` 기록 함수, `get_user_login_statistics()` 집계 함수, 기존 이력 정리 SQL, 기본 설치 스크립트와 관련 문서다.
