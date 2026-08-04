# TASK-073 변경 보고서: 180일 초과 데이터 수동 삭제 버튼

- 작업일: 2026-07-11
- 버전: v3.73.0
- 작업자: AI_Codex

## 1. 작업 계획 및 영향 범위

| 항목 | 현재 상태 | 수정 방향 | 영향 파일 |
|---|---|---|---|
| 서비스 통계 수동 삭제 | 180일 보존 정리는 SQL/cron 중심 | `서비스 통계` 페이지에 관리자 전용 수동 정리 버튼 추가 | `admin/service-stats.html`, `docs/TASK-073_manual_retention_cleanup.sql` |
| 활동 로그 수동 삭제 | 선택/범위 삭제는 삭제 대기 처리, 실제 180일 정리는 SQL 중심 | `로그` 페이지에 확인 완료 로그 180일 초과 실제 삭제 버튼 추가 | `admin/logs.html`, `docs/TASK-073_manual_retention_cleanup.sql` |
| 수동 삭제 권한 | 버튼 호출용 RPC 없음 | 관리자(100+) 이상만 실행 가능한 RPC 추가 | `docs/TASK-073_manual_retention_cleanup.sql` |
| 로그/작업 이력 라벨 | 신규 수동 정리 액션 없음 | 코드 마스터와 JS 액션 라벨 추가 | `js/activity-log.js`, `docs/TASK-073_manual_retention_cleanup.sql` |
| 버전/문서 | v3.72.0 보존 정책 기준 | v3.73.0 수동 삭제 버튼 기준으로 동기화 | README, 안내서, 아키텍처/운영 룰/설정 문서 |

## 2. 변경 내역

- `cleanup_service_usage_retention_180d()` RPC를 추가했습니다.
  - `service_usage_snapshots.collected_at < now() - interval '180 days'` 삭제
  - `service_usage_collection_runs.started_at < now() - interval '180 days'` 삭제
  - 관리자(100+) 또는 service_role만 실행 가능
- `cleanup_activity_logs_retention_180d()` RPC를 추가했습니다.
  - `activity_logs.created_at < now() - interval '180 days'`
  - `is_acknowledged=true`인 확인 완료 로그만 삭제
  - 미확인 로그는 삭제하지 않음
- `admin/service-stats.html`에 `180일 초과 정리` 버튼을 추가했습니다.
- `admin/logs.html`에 `180일 초과 실제 삭제` 버튼을 추가했습니다.
- 로그 전체 선택/선택 삭제가 비활성 미확인 로그 체크박스를 포함하지 않도록 보정했습니다.
- 성공/실패 시 활동 로그를 남기도록 `LOG_RETENTION_CLEANUP`, `SERVICE_USAGE_RETENTION_CLEANUP` 액션 라벨을 추가했습니다.

## 3. 운영 적용 방법

1. Supabase SQL Editor에서 `docs/TASK-073_manual_retention_cleanup.sql`을 실행합니다.
2. 관리자(100+) 계정으로 `admin/service-stats.html`에 접속해 `180일 초과 정리` 버튼이 보이는지 확인합니다.
3. 관리자(100+) 계정으로 `admin/logs.html`에 접속해 `180일 초과 실제 삭제` 버튼이 보이는지 확인합니다.
4. 버튼 실행 후 안내되는 삭제 건수와 `activity_logs`에 남는 수동 정리 로그를 확인합니다.

## 4. 주의 사항

- 버튼은 실제 DELETE를 수행합니다.
- `activity_logs` 미확인 로그는 180일이 지나도 삭제하지 않습니다.
- 180일 이내 데이터는 버튼 실행 대상이 아닙니다.
