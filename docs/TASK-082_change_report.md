# TASK-082 변경 보고 — 최고관리자 로그인 이력 제외

- `public.profiles.is_super_admin=true`인 계정은 향후 `user_login_history`에 기록하지 않는다.
- 기존 최고관리자 로그인 이력은 TASK-082 적용 시 삭제한다.
- 통계 RPC는 현재 프로필 기준으로 최고관리자를 다시 제외하므로, 비정상 잔존 데이터도 통계에 표시되지 않는다.
- 새 DB와 기존 DB 모두 적용할 수 있도록 PowerShell/Bash 설치 스크립트 및 설치 문서를 갱신했다.

운영 DB에는 [TASK-082_exclude_super_admin_login_history.sql](TASK-082_exclude_super_admin_login_history.sql)을 적용해야 기존 이력 정리와 함수 교체가 완료된다.
