# TASK-082 테스트 결과 — 최고관리자 로그인 이력 제외

검증일: 2026-07-14 (KST)

| 항목 | 결과 | 근거 |
|---|---|---|
| 기록 함수 제외 조건 | 통과 | `record_user_login()`이 `COALESCE(v_profile.is_super_admin, false)`일 때 반환하도록 확인 |
| 기존 이력 정리 | 통과 | TASK-082의 `DELETE ... USING profiles` 조건으로 최고관리자 행만 대상 지정 확인 |
| 집계 방어 제외 | 통과 | 통계 RPC의 `profiles` 조인 및 `is_super_admin=false` 조건 확인 |
| 설치 스크립트 반영 | 통과 | PowerShell/Bash 기본 합본 경로에 TASK-082 포함 확인 |
| 실제 DB 실행 | 배포 전 필요 | 이 작업에서는 운영 DB SQL을 실행하지 않았으므로 적용 후 TS-01~TS-04를 확인해야 함 |
