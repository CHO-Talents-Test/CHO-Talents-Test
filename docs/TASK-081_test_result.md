# TASK-081 테스트 결과 — 사용자 로그인 통계

검증일: 2026-07-14 (KST)

| 항목 | 결과 | 근거 |
|---|---|---|
| 변경 HTML 인라인 JavaScript 파싱 | 통과 | `index.html`, 상점/통계/작업 이력, 신규 사용자 통계, 11개 안내·룰 페이지 포함 16개 HTML의 인라인 스크립트 파싱 완료 |
| PowerShell 설치 스크립트 구문 | 통과 | `scripts/install-supabase-database.ps1` AST 파싱 오류 없음 |
| TASK-081 SQL 필수 요소 | 통과 | 테이블, RLS, 기록 RPC, 통계 RPC, authenticated 실행 권한 구문 확인 |
| 변경 공백/충돌 검사 | 통과 | `git diff --check` 통과 |
| Bash 설치 스크립트 구문 | 보류 | 현재 Windows 환경에 실행 가능한 Linux 배포판이 없어 `bash -n`을 실행할 수 없음. 스크립트에는 TASK-081 합본 경로가 포함된 것을 정적 확인함. |
| 실제 Supabase SQL 실행 및 브라우저 E2E | 배포 전 필요 | 이 작업에서는 운영 DB에 SQL을 적용하지 않았으므로, 적용 후 TS-01~TS-08을 실제 계정으로 확인해야 함. |

## 배포 확인 순서

1. `docs/TASK-081_user_login_statistics.sql`을 Supabase SQL Editor에서 적용한다.
2. 관리자 계정으로 로그인해 `관리 > 사용자 통계`의 다섯 탭과 기간·부서 필터를 확인한다.
3. 100 미만 계정으로 직접 URL 접근과 RPC 호출이 거부되는지 확인한다.
4. 작업 이력과 구매 통계의 행 클릭 상세 모달, 즐겨찾기 20개 선택을 확인한다.
