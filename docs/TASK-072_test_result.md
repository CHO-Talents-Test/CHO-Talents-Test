# TASK-072 테스트 결과: 180일 데이터 보존 정책

- 테스트일: 2026-07-11
- 대상 버전: v3.72.0
- 테스트 방식: 정적 검증

## 1. 테스트 시나리오

| 번호 | 시나리오 | 기대 결과 | 확인 방법 |
|---:|---|---|---|
| 1 | 서비스 사용량 스냅샷 보존 기준 | `collected_at` 180일 초과 행만 삭제 | SQL 정적 확인 |
| 2 | 서비스 사용량 수집 이력 보존 기준 | `started_at` 180일 초과 행만 삭제 | SQL 정적 확인 |
| 3 | 활동 로그 미확인 보호 | `is_acknowledged=false` 로그는 180일 초과여도 삭제하지 않음 | SQL `WHERE` 조건 확인 |
| 4 | 예약 실행 | `cho-data-retention-180d`가 매일 03:30 KST 실행 | cron expression 확인 |
| 5 | 권한 제한 | 정리 함수는 `PUBLIC`, `anon`, `authenticated` 실행 권한 제거 | SQL GRANT/REVOKE 확인 |
| 6 | 선택 삭제 미확인 보호 | 미확인 로그는 체크박스 선택/삭제 대기 처리 불가 | `admin/logs.html`, `js/activity-log.js` 정적 확인 |
| 7 | JS 문법 | `js/version.js`, `js/activity-log.js` 문법 오류 없음 | `node --check` |
| 8 | 충돌 마커 확인 | 수정 파일에 병합 충돌 마커 없음 | `rg "^(<<<<<<<|=======|>>>>>>>)"` |

## 2. 테스트 결과

| 번호 | 결과 | 상세 |
|---:|---|---|
| 1 | 성공 | `DELETE FROM public.service_usage_snapshots WHERE collected_at < v_cutoff`로 제한했습니다. |
| 2 | 성공 | `DELETE FROM public.service_usage_collection_runs WHERE started_at < v_cutoff`로 제한했습니다. |
| 3 | 성공 | `activity_logs` 삭제 조건에 `COALESCE(is_acknowledged, false) = true`를 포함해 미확인 로그를 보호했습니다. |
| 4 | 성공 | `cho-data-retention-180d` cron schedule은 `30 18 * * *`이며 KST 기준 매일 03:30입니다. |
| 5 | 성공 | 함수 실행 권한을 service_role로 제한하고 cron/postgres 운영 실행을 기준으로 구성했습니다. |
| 6 | 성공 | 미확인 로그 체크박스는 비활성화되고, `deleteLogsByIds()`는 `is_acknowledged=true` 조건을 포함합니다. |
| 7 | 성공 | `node --check js/version.js`, `node --check js/activity-log.js` 통과. |
| 8 | 성공 | 수정 대상 문서/HTML/JS/SQL 파일에서 충돌 마커가 발견되지 않았습니다. |

## 3. 잔여 운영 확인

- 운영 DB에는 Supabase SQL Editor에서 `docs/TASK-072_data_retention_180d.sql`을 적용해야 합니다.
- 적용 직후 `cron.job`과 수동 `SELECT * FROM public.cleanup_data_retention_180d();` 결과로 삭제 건수를 확인합니다.
- 로컬 `git status`는 macOS Command Line Tools 경로 문제(`xcrun: invalid active developer path`)로 확인하지 못했습니다.
