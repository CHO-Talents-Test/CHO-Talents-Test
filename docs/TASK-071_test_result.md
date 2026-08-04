# TASK-071 테스트 결과: 서비스 사용량 수집 주기 1시간 전환

- 테스트일: 2026-07-11
- 대상 버전: v3.71.0
- 테스트 방식: 정적 검증 및 문법 검사

## 1. 테스트 시나리오

| 번호 | 시나리오 | 기대 결과 | 확인 방법 |
|---:|---|---|---|
| 1 | Cron SQL 작업명/주기 확인 | `cho-service-usage-collect-1h`, `0 * * * *` 기준으로 예약 생성 | `rg`로 SQL 문자열 확인 |
| 2 | 기존 6시간 예약 중복 방지 | 기존 `cho-service-usage-collect-6h` 작업이 재설정 시 제거 대상에 포함 | SQL의 `cron.unschedule` 조건 확인 |
| 3 | 화면/문서 수집 주기 안내 확인 | 사용자/운영 문서는 매시간 또는 1시간 수집 기준으로 표시 | `rg "6시간|1시간|매시간"` 검색 |
| 4 | 버전 표시 확인 | `APP_VERSION.current`가 `3.71.0`이고 이력 최상단이 v3.71.0 | `rg "3.71.0" js/version.js` 확인 |
| 5 | Cron Secret 입력 검증 | placeholder 또는 JWT 형식이 아닌 값은 SQL 실행 시점에 중단 | SQL 정적 확인 |
| 6 | Edge Function 예약 인증 로직 | service_role JWT payload를 schedule 호출로 승인 | 코드 정적 확인 |
| 7 | JS 문법 확인 | 수정된 버전 모듈에 문법 오류 없음 | `node --check js/version.js` |
| 8 | Edge Function 타입 체크 | 로컬 Deno/TypeScript 체크 가능 여부 확인 | `deno check`, `npx --no-install tsc --version` |
| 9 | 운영 수동 호출 확인 | 배포된 Edge Function이 service_role JWT 예약 호출을 성공 처리 | Supabase `net._http_response` 확인 |

## 2. 테스트 결과

| 번호 | 결과 | 상세 |
|---:|---|---|
| 1 | 성공 | Cron SQL이 `cho-service-usage-collect-1h`와 `0 * * * *`를 사용합니다. |
| 2 | 성공 | `cron.unschedule` 대상에 기존 `cho-service-usage-collect-6h`와 새 `cho-service-usage-collect-1h`가 모두 포함됩니다. |
| 3 | 성공 | 현재 운영 문구는 1시간/매시간 수집 기준으로 갱신했습니다. 변경 이력 문맥의 "6시간에서 1시간" 표현은 의도적으로 유지했습니다. |
| 4 | 성공 | `js/version.js`의 현재 버전과 최상단 이력이 v3.71.0입니다. |
| 5 | 성공 | Cron SQL에 service role key placeholder/JWT 형식 검증, 붙여넣기 공백 제거, Authorization 헤더 `trim()` 처리를 추가했습니다. |
| 6 | 성공 | `service-usage-collect`가 JWT payload의 `role=service_role`을 schedule 호출로 승인하도록 보강했습니다. |
| 7 | 성공 | `node --check js/version.js` 통과. |
| 8 | 제한 | 로컬에 `deno`가 없고 `npx --no-install tsc --version`이 출력 없이 대기해 타입 체크는 실행하지 못했습니다. 수정 범위는 독립 헬퍼 함수와 인증 분기입니다. |
| 9 | 성공 | `2026-07-11 11:07:50+09` 수동 `net.http_post` 응답이 `status_code=200`, `success=true`, `status=success`, `errors=[]`로 확인되었습니다. |

## 3. 잔여 운영 확인

- Supabase 운영 DB에서 `cho-service-usage-collect-1h`, `0 * * * *`, `active=true` 상태를 확인했습니다.
- `2026-07-11 11:00:00+09` 예약 실행은 Edge Function 재배포 전 구버전 코드로 인해 `403 {"error":"invalid session"}`을 반환했습니다.
- 최신 `service-usage-collect` 배포 후 `2026-07-11 11:07:50+09` 수동 호출이 `200`으로 성공했습니다.
- 다음 정기 검증 지점은 `2026-07-11 12:00:00+09` 자동 cron 실행입니다.
