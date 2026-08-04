# TASK-071 변경 보고서: 서비스 사용량 수집 주기 1시간 전환

- 작업일: 2026-07-11
- 버전: v3.71.0
- 작업자: AI_Codex

## 1. 작업 계획 및 영향 범위

| 항목 | 현재 상태 | 수정 방향 | 영향 파일 |
|---|---|---|---|
| 서비스 사용량 예약 수집 | `service-usage-collect` pg_cron 작업이 6시간 간격으로 실행 | 매시간 정각 실행으로 변경하고 기존 6시간 작업을 재설정 시 제거 | `docs/TASK-070_service_usage_cron.sql` |
| 서비스 통계 운영 안내 | 화면/문서 일부가 6시간 또는 00/06/12/18 KST 기준 | 1시간/매시간 정각 기준으로 갱신 | `admin/service-stats.html`, `docs/TASK-070_SERVICE_USAGE_SETUP.md`, `README.md`, `docs/SITE_USER_GUIDE.md`, `docs/PROJECT_ARCHITECTURE_FLOW.md` |
| 버전 관리 | 최신 버전 v3.70.0 | v3.71.0 이력 추가 | `js/version.js` |
| 가이드/룰 페이지 | 일부 페이지가 v3.69.0~v3.70.0 기준 문구 | v3.71.0 현재 기준과 서비스 통계 1시간 수집 기준 반영 | 역할별 가이드 7종, 운영 룰 4종 |

## 2. 변경 내역

- `docs/TASK-070_service_usage_cron.sql`
  - 기존 `cho-service-usage-collect-6h` 작업과 새 `cho-service-usage-collect-1h` 작업을 함께 제거 후 재생성하도록 변경
  - Cron expression을 `0 * * * *`로 변경
  - 확인 쿼리 작업명을 `cho-service-usage-collect-1h`로 변경
  - Service Role Key placeholder 또는 JWT 형식 오류를 SQL 실행 시점에 차단하고, Vault 값을 Authorization 헤더에 넣을 때 공백을 제거하도록 보강

- `js/version.js`
  - `APP_VERSION.current`를 `3.71.0`으로 변경
  - 서비스 사용량 매시간 수집 전환 이력 추가

- `supabase/functions/service-usage-collect/index.ts`
  - 예약 호출 Authorization 토큰이 Edge Function 환경변수 문자열과 정확히 같지 않아도 JWT payload의 `role=service_role`이면 schedule 호출로 승인하도록 보강
  - 1시간 cron 실행 후 `net._http_response`에 `403 {"error":"invalid session"}`이 남는 경우를 해소

- 문서/가이드
  - README, 사이트 안내서, 아키텍처 문서, 서비스 통계 운영 설정 문서를 v3.71.0 및 매시간 수집 기준으로 갱신
  - 학생/교사/부서 담당/구매 담당/부장/전도사/관리자 가이드의 최신 기준 문구 갱신
  - 페이지 권한 룰, 로그 작성 룰, Slack 알림 룰, 작업 이력 룰에 서비스 통계 1시간 수집 및 할당량 알림 기준 반영

## 3. 운영 적용 방법

1. `docs/TASK-070_service_usage_cron.sql`의 `<SUPABASE_SERVICE_ROLE_KEY>`를 현재 프로젝트 Service Role Key 전체 JWT 값으로 치환합니다.
2. Supabase SQL Editor에서 해당 SQL을 실행합니다.
3. `cron.job`에서 `cho-service-usage-collect-1h` 작업의 schedule이 `0 * * * *`인지 확인합니다.
4. 최신 `service-usage-collect` Edge Function을 배포합니다.
5. `net._http_response`에 `UNAUTHORIZED_INVALID_JWT_FORMAT` 또는 `{"error":"invalid session"}`이 다시 남지 않는지 확인합니다.
6. `admin/service-stats.html`에서 `지금 수집`과 최근 수집 이력을 확인합니다.

## 4. 운영 확인 결과

- `cron.job` 기준 `cho-service-usage-collect-1h` 작업이 `0 * * * *`, `active=true`로 생성되었습니다.
- `2026-07-11 11:00:00+09` 자동 실행은 Edge Function 재배포 전 코드로 인해 `403 {"error":"invalid session"}`을 반환했습니다.
- 최신 `service-usage-collect` 배포 후 `2026-07-11 11:07:50+09` 수동 호출에서 `status_code=200`, `success=true`, `status=success`, `errors=[]`를 확인했습니다.
- 이전 `403` 응답은 배포 전 이력으로 남아 있으며, 현재 인증 및 수집 호출은 정상입니다.
