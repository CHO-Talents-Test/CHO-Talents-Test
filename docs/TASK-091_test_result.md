# TASK-091 정적 검증 결과

**버전:** v3.89.0  
**검증일:** 2026-07-16

| 항목 | 결과 | 근거 |
|---|---|---|
| JavaScript 구문 | 통과 | `js/nav.js`, `js/version.js`, 수정한 11개 HTML의 인라인 스크립트를 Node `vm.Script`로 파싱했다. |
| HTML 연결 | 통과 | 로그 행 이벤트, 수집 실패 목록, 사용자 통계 필터·차트, 상품 필수값·상태 필터 선택자를 정적 점검했다. |
| SQL 조건 일치 | 통과 | 집계·상세 RPC가 모두 `p_user_type`과 `profiles.user_type` 조건을 사용하도록 확인했다. |
| 설치 경로 | 통과 | PowerShell/Bash 설치 스크립트가 `TASK-091_user_stats_filters.sql`을 기본 합본에 추가하는지 확인했고, PowerShell 스크립트 구문도 파싱했다. |
| 가이드 권한 | 통과 | `GUIDE_MIN_RANK` 기준으로 학생 20부터 관리자 100까지의 누적 노출 규칙을 점검했다. |
| 운영 DB 실행 | 미실행 | 외부 Supabase DB 변경은 별도 운영 배포 권한이 필요하므로 `TASK-091_user_stats_filters.sql`만 준비했다. |

## 배포 후 확인

실제 데이터가 있는 운영 환경에서 `TASK-091_test_scenario.md`의 TS-01~TS-07을 수행한다. 특히 학생/교사 필터는 SQL 적용 전에는 RPC 인자 오류가 날 수 있으므로 SQL 적용 후 확인한다.
