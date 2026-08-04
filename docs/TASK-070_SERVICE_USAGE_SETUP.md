# TASK-070 서비스 통계 운영 설정

`운영 > 로그 > 서비스 통계` 페이지는 GitHub, Supabase, Kakao Developers, Slack의 무료 할당량과 현재 사용량을 표시합니다. 공식/관리 API로 수집 가능한 항목은 API로 수집하고, API가 없거나 프로젝트 내부 사용량만 필요한 항목은 브라우저·Edge Function 이벤트와 DB 직접 집계로 병행 수집합니다. 자동 수집은 매시간 정각(KST)에 실행되고, 사용률이 `70%`, `85%`, `95%`에 처음 도달할 때 운영관리 Slack 채널로 단계별 알림을 보냅니다.

## 1. Database 적용

Supabase SQL Editor에서 다음 파일을 실행합니다.

1. `docs/TASK-070_service_usage_monitoring.sql`
2. 기존 운영 DB는 `docs/TASK-080_service_usage_source_and_webhook_failures.sql`
3. Edge Function과 Secret 설정 완료 후 `docs/TASK-070_service_usage_cron.sql`
4. 보존 정책 적용 후 기존 운영 DB에는 `docs/TASK-073_manual_retention_cleanup.sql`

새 Database 설치 스크립트는 TASK-070과 TASK-080 스키마를 자동으로 포함합니다.

## 2. Edge Function 배포

```powershell
supabase functions deploy service-usage-collect --project-ref <PROJECT_REF>
supabase functions deploy slack-notify --project-ref <PROJECT_REF>
```

`slack-notify`를 다시 배포해야 기존 구매·가입·로그·Q&A 알림 성공/실패도 Slack 프로젝트 사용량에 포함됩니다.

## 3. 필요한 Edge Function Secrets

실제 값은 정적 HTML, 브라우저 JS, `app_config`에 넣지 않고 Supabase Edge Function Secret에만 저장합니다.

| Secret | 필수 | 용도 |
|---|---:|---|
| `GITHUB_TOKEN` | 예 | GitHub Billing, Actions 저장공간, 저장소 Traffic API 조회 |
| `GITHUB_ACCOUNT_TYPE` | 예 | GitHub 계정 유형. 현재 `CHO-Talents`는 개인 계정이므로 `user` |
| `GITHUB_OWNER` | 예 | `CHO-Talents` |
| `GITHUB_REPO` | 예 | `CHO-Talents` |
| `SB_MANAGEMENT_ACCESS_TOKEN` | 예 | Supabase Management API 공식 API 요청 통계 조회 |
| `SB_PROJECT_REF` | 예 | Supabase Dashboard URL의 프로젝트 ref. 캡쳐 화면 기준 `rabakjtjtkelpskptnvi` |
| `SLACK_WEBHOOK_OPERATIONS` | 예 | 70/85/95% 알림을 보낼 운영관리 채널 |
| `SERVICE_STATS_URL` | 선택 | Slack 알림의 상세 페이지 링크. 미설정 시 운영 GitHub Pages URL 사용 |

`SUPABASE_URL`과 `SUPABASE_SERVICE_ROLE_KEY`는 Supabase가 Edge Function에 기본 제공합니다. Kakao 사용량은 프로젝트의 실제 Map SDK 로드와 장소 검색 호출을 자체 계측하므로 별도 Kakao Admin Key가 필요하지 않습니다.

예시 명령의 값은 로컬 환경에서만 치환합니다.

```powershell
supabase secrets set --project-ref <PROJECT_REF> `
  GITHUB_TOKEN="<GITHUB_FINE_GRAINED_TOKEN>" `
  GITHUB_ACCOUNT_TYPE="user" `
  GITHUB_OWNER="CHO-Talents" `
  GITHUB_REPO="CHO-Talents" `
  SB_MANAGEMENT_ACCESS_TOKEN="<SUPABASE_MANAGEMENT_ACCESS_TOKEN>" `
  SB_PROJECT_REF="<PROJECT_REF>" `
  SLACK_WEBHOOK_OPERATIONS="<OPERATIONS_WEBHOOK_URL>" `
  SERVICE_STATS_URL="https://cho-talents.github.io/CHO-Talents/admin/service-stats.html"
```

### GitHub Token 권한

`CHO-Talents`는 GitHub 개인 계정(`type: User`)입니다. Billing Summary API는 개인 계정 endpoint를 사용하므로 fine-grained personal access token에 아래 읽기 권한을 부여합니다.

- Account permissions: `Plan: Read`
- Repository permissions: `Actions: Read`, `Administration: Read`, `Metadata: Read`

저장소 Traffic API는 Repository `Administration: Read`가 필요합니다. 나중에 GitHub Organization으로 이전하면 `GITHUB_ACCOUNT_TYPE=organization`으로 바꾸고 조직 관리자 토큰에 Organization `Administration: Read` 권한을 부여합니다.

### Supabase Access Token 권한

- Personal access token 또는 fine-grained token
- 대상 프로젝트 접근
- Fine-grained token 사용 시 `analytics_usage_read`

## 4. 1시간 예약 수집

`docs/TASK-070_service_usage_cron.sql`의 `<SUPABASE_SERVICE_ROLE_KEY>`를 현재 프로젝트 Service Role Key로 바꾼 뒤 SQL Editor에서 한 번 실행합니다.

- Vault에는 예약 호출용 Service Role Key만 저장됩니다.
- `<SUPABASE_SERVICE_ROLE_KEY>`를 그대로 두거나 JWT 형식이 아닌 값을 넣으면 SQL이 중단됩니다. Supabase Dashboard의 JWT 형태 `service_role` key 전체 값을 사용합니다. `anon` key나 `sb_secret_*` 형식의 새 Secret API key가 아니라, 점(`.`)이 2개 들어간 `eyJ...` 형태의 JWT여야 합니다. 붙여넣기 중 들어간 줄바꿈/공백은 SQL에서 제거합니다.
- `pg_cron`은 UTC 기준이며 `0 * * * *`로 매시간 정각에 실행합니다.
- 기존 6시간 작업(`cho-service-usage-collect-6h`)과 새 1시간 작업(`cho-service-usage-collect-1h`)이 있으면 제거하고 다시 생성하므로 재설정할 수 있습니다.
- 매시간 수집으로 누적되는 `service_usage_snapshots`와 `service_usage_collection_runs`는 `docs/TASK-072_data_retention_180d.sql`의 180일 보존 정책으로 정리합니다.
- 기존 DB에 `서비스 통계` 화면의 `180일 초과 정리` 버튼을 활성화하려면 `docs/TASK-073_manual_retention_cleanup.sql`을 추가 적용합니다.

운영 DB가 아래 상태라면 아직 새 SQL이 적용되지 않은 것입니다.

```sql
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname LIKE 'cho-service-usage-collect%';
```

정상 상태는 `cho-service-usage-collect-1h` 하나만 남고 schedule이 `0 * * * *`로 표시되는 것입니다. `net._http_response.content`에 `UNAUTHORIZED_INVALID_JWT_FORMAT`이 보이면 Vault에 저장된 `service_usage_service_role_key`가 실제 service role JWT가 아니거나, placeholder/공백이 들어간 상태입니다. `<SUPABASE_SERVICE_ROLE_KEY>`를 실제 값으로 바꾼 최신 Cron SQL을 다시 실행합니다.

`net._http_response.status_code=403`이고 content가 `{"error":"invalid session"}`이면 cron은 Edge Function까지 도달했지만 배포된 `service-usage-collect` 함수가 service_role JWT를 schedule 호출로 인정하지 않는 구버전일 수 있습니다. 최신 `supabase/functions/service-usage-collect/index.ts`는 JWT payload의 `role=service_role`을 schedule 호출로 처리하므로 Edge Function을 다시 배포합니다.

## 5. 수집값 해석

| 표시 | 의미 |
|---|---|
| 공식 API | GitHub/Supabase 관리 API가 반환한 값 |
| DB 직접 | `pg_database_size`, `storage.objects`, `auth.users`에서 계산한 값 |
| 프로젝트 계측 | 이 프로젝트의 페이지, SDK, Edge Function, Webhook 호출 기록 |
| 추정 | 브라우저 Resource Timing 또는 Billing 단위 정규화 값 |
| Secret 필요 | 수집기는 배포됐지만 해당 API Secret이 없거나 권한이 부족함 |

화면의 `계측 기준` 필터에서 `공식/API 계측`과 `프로젝트 자체 계측`을 분리해서 볼 수 있습니다. DB 직접값과 브라우저·Edge Function 이벤트, 추정값은 후자에 포함됩니다. `최근 Slack Webhook 실패`에는 HTTP 오류, 네트워크 오류, Webhook Secret 미설정이 유형·상태와 함께 표시됩니다.

Supabase Free 플랜은 초과 사용료가 자동 과금되는 대신 서비스 제한 또는 grace period가 적용될 수 있습니다. GitHub는 결제수단/예산 설정에 따라 초과 사용이 차단되거나 과금될 수 있습니다. Kakao 예상 비용은 유료 API를 활성화한 경우에만 실제 비용이 됩니다. Slack Free의 90일 내역과 앱 10개는 과금형 종량제가 아니라 기능 제한입니다.

## 5-1. 데이터 보존 정책

`docs/TASK-072_data_retention_180d.sql`을 적용하면 `cho-data-retention-180d` pg_cron 작업이 매일 03:30(KST)에 실행됩니다.

- `service_usage_snapshots`: `collected_at` 기준 180일 초과 행 삭제
- `service_usage_collection_runs`: `started_at` 기준 180일 초과 행 삭제
- `activity_logs`: `created_at` 기준 180일 초과이면서 확인 완료(`is_acknowledged=true`)된 행만 삭제
- 미확인 `activity_logs`는 확인 완료 처리 전까지 삭제하지 않음

`docs/TASK-073_manual_retention_cleanup.sql`을 적용하면 관리자(100+)가 화면에서 같은 기준의 수동 정리를 실행할 수 있습니다.

- `운영 > 서비스 통계`: `180일 초과 정리` 버튼으로 `service_usage_snapshots`, `service_usage_collection_runs`를 즉시 정리
- `운영 > 로그`: `180일 초과 실제 삭제` 버튼으로 확인 완료된 `activity_logs`만 즉시 삭제
- 수동 정리 RPC는 관리자(100+) 또는 `service_role`만 실행 가능
- 미확인 `activity_logs`는 자동 정리, 선택 삭제, 수동 실제 삭제 모두에서 보존

## 6. 확인 순서

1. 부장 교사 이상 계정으로 `admin/service-stats.html`에 접속합니다.
2. `지금 수집`을 눌러 수동 수집을 확인합니다.
3. 플랫폼 카드가 `API 연결` 또는 `프로젝트 계측`으로 표시되는지 확인합니다.
4. `service_usage_collection_runs`의 최신 행이 `success` 또는 예상한 `partial`인지 확인합니다.
5. Cron 설정 후 `cron.job`와 `cron.job_run_details`에서 1시간 예약 실행을 확인합니다.
6. 관리자 계정에서 `180일 초과 정리` 버튼이 보이고, RPC 미적용 오류가 없으면 `TASK-073` 적용이 완료된 상태입니다.

브라우저 계측은 개인정보, 입력값, URL 쿼리 문자열을 저장하지 않으며 페이지 경로와 서비스 호출 종류, 전송량만 기록합니다.
