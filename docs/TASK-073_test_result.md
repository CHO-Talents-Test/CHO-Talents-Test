# TASK-073 테스트 결과: 180일 초과 데이터 수동 삭제 버튼

- 테스트일: 2026-07-11
- 대상 버전: v3.73.0
- 테스트 방식: 정적 검증 및 JS 문법 검사

## 1. 테스트 시나리오

| 번호 | 시나리오 | 기대 결과 | 확인 방법 |
|---:|---|---|---|
| 1 | 서비스 통계 수동 정리 버튼 | 관리자에게 `180일 초과 정리` 버튼 표시, RPC 호출 | HTML/JS 정적 확인 |
| 2 | 활동 로그 수동 정리 버튼 | 로그 페이지에 `180일 초과 실제 삭제` 버튼 표시, RPC 호출 | HTML/JS 정적 확인 |
| 3 | 서비스 통계 삭제 조건 | 스냅샷은 `collected_at`, 수집 이력은 `started_at` 기준 180일 초과만 삭제 | SQL 정적 확인 |
| 4 | 활동 로그 삭제 조건 | `is_acknowledged=true`인 180일 초과 로그만 삭제 | SQL 정적 확인 |
| 5 | 권한 제한 | 관리자(100+) 또는 service_role만 RPC 실행 가능 | SQL `COALESCE(get_permission_rank(...), 0) < 100` 확인 |
| 6 | 선택 삭제 UI | 전체 선택/선택 삭제가 비활성 미확인 로그 체크박스를 제외 | JS 정적 확인 |
| 7 | 액션 라벨 | 수동 정리 성공/실패 액션이 한글 라벨로 기록 | `js/activity-log.js`, SQL 코드 마스터 확인 |
| 8 | JS 문법 | 수정 JS 파일과 버튼 추가 HTML 인라인 스크립트 문법 오류 없음 | `node --check`, HTML script parse |
| 9 | 충돌 마커 | 수정 파일에 병합 충돌 마커 없음 | `rg` 검색 |

## 2. 테스트 결과

| 번호 | 결과 | 상세 |
|---:|---|---|
| 1 | 성공 | `admin/service-stats.html`에 `cleanupServiceUsage()`와 버튼을 추가했습니다. |
| 2 | 성공 | `admin/logs.html`에 `cleanupOldActivityLogs()`와 버튼을 추가했습니다. |
| 3 | 성공 | `cleanup_service_usage_retention_180d()`가 두 서비스 통계 테이블의 180일 초과 행만 삭제합니다. |
| 4 | 성공 | `cleanup_activity_logs_retention_180d()`가 확인 완료된 180일 초과 활동 로그만 삭제합니다. |
| 5 | 성공 | 두 RPC 모두 관리자(100+) 미만 또는 비로그인 사용자를 차단합니다. |
| 6 | 성공 | 로그 전체 선택/선택 삭제가 비활성 미확인 로그 체크박스를 제외합니다. |
| 7 | 성공 | `LOG_RETENTION_CLEANUP`, `SERVICE_USAGE_RETENTION_CLEANUP` 성공/실패 라벨을 추가했습니다. |
| 8 | 성공 | `node --check js/version.js`, `node --check js/activity-log.js`, `admin/service-stats.html`/`admin/logs.html` 인라인 스크립트 파싱 통과. |
| 9 | 성공 | 수정 대상 파일에서 충돌 마커가 발견되지 않았습니다. |

## 3. 잔여 운영 확인

- 운영 DB에는 `docs/TASK-073_manual_retention_cleanup.sql`을 적용해야 페이지 버튼이 RPC를 호출할 수 있습니다.
- 로컬 `git status --short`는 macOS Command Line Tools 경로 문제(`xcrun: invalid active developer path`)로 실패했습니다.
