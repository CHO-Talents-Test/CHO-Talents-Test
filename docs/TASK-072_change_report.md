# TASK-072 변경 보고서: 180일 데이터 보존 정책

- 작업일: 2026-07-11
- 버전: v3.72.0
- 작업자: AI_Codex

## 1. 작업 계획 및 영향 범위

| 항목 | 현재 상태 | 수정 방향 | 영향 파일 |
|---|---|---|---|
| 서비스 통계 스냅샷 | 매시간 수집으로 장기 누적 가능 | `collected_at` 기준 180일 초과 삭제 | `docs/TASK-072_data_retention_180d.sql` |
| 서비스 통계 수집 이력 | 매시간 수집 성공/실패 이력 장기 누적 가능 | `started_at` 기준 180일 초과 삭제 | `docs/TASK-072_data_retention_180d.sql` |
| 활동 로그 | 오류 확인 전 로그가 보존 정책으로 삭제될 위험 | `is_acknowledged=true`인 180일 초과 로그만 삭제 | `docs/TASK-072_data_retention_180d.sql` |
| 로그 선택 삭제 | 미확인 로그를 체크박스로 삭제 대기 처리할 수 있음 | 미확인 로그 체크박스 비활성화 및 삭제 함수 확인 완료 조건 추가 | `admin/logs.html`, `js/activity-log.js` |
| 운영 안내/버전 | v3.71.0 기준 안내 | v3.72.0 및 180일 보존 정책 반영 | README, 사용자 안내서, 아키텍처/설정/초기 세팅 문서, 운영 룰/가이드 |

## 2. 변경 내역

- `public.cleanup_data_retention_180d()` 함수를 추가해 보존 정리를 한 곳에서 실행하도록 했습니다.
- `service_usage_snapshots`는 `collected_at < now() - interval '180 days'` 기준으로 삭제합니다.
- `service_usage_collection_runs`는 `started_at < now() - interval '180 days'` 기준으로 삭제합니다.
- `activity_logs`는 `created_at < now() - interval '180 days'`이면서 `is_acknowledged=true`인 로그만 삭제합니다.
- 미확인 활동 로그는 180일이 지나도 확인 완료 전까지 자동 삭제하지 않습니다.
- 로그 화면의 선택 삭제도 미확인 로그는 선택할 수 없도록 하고, 공통 삭제 함수가 `is_acknowledged=true`인 로그만 삭제 대기 처리하도록 보강했습니다.
- `cho-data-retention-180d` pg_cron 작업을 매일 `18:30 UTC`(`03:30 KST`)에 실행하도록 구성했습니다.

## 3. 운영 적용 방법

1. Supabase SQL Editor에서 `docs/TASK-072_data_retention_180d.sql`을 실행합니다.
2. `cron.job`에서 `cho-data-retention-180d`, `30 18 * * *`, `active=true`를 확인합니다.
3. 즉시 정리 결과를 확인해야 하면 `SELECT * FROM public.cleanup_data_retention_180d();`를 수동 실행합니다.
4. `activity_logs`의 `is_acknowledged=false` 로그가 삭제되지 않는지 확인합니다.
