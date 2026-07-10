# TASK-070 서비스 통계 운영 설정

`운영 > 로그 > 서비스 통계` 페이지는 GitHub, Supabase, Kakao Developers, Slack의 무료 할당량과 현재 사용량을 표시합니다. 자동 수집은 매일 `00:00`, `06:00`, `12:00`, `18:00` KST에 실행되고, 사용률이 `70%`, `85%`, `95%`에 처음 도달할 때 운영관리 Slack 채널로 단계별 알림을 보냅니다.

## 1. Database 적용

Supabase SQL Editor에서 다음 파일을 실행합니다.

1. `docs/TASK-070_service_usage_monitoring.sql`
2. Edge Function과 Secret 설정 완료 후 `docs/TASK-070_service_usage_cron.sql`

새 Database 설치 스크립트는 TASK-070 스키마를 자동으로 포함합니다.

## 2. Edge Function 배포

```powershell
supabase functions deploy service-usage-collect --project-ref blitrrcdkkkszvgylnus
supabase functions deploy slack-notify --project-ref blitrrcdkkkszvgylnus
```

`slack-notify`를 다시 배포해야 기존 구매·가입·로그·Q&A 알림 성공/실패도 Slack 프로젝트 사용량에 포함됩니다.

## 3. 필요한 Edge Function Secrets

실제 값은 정적 HTML, 브라우저 JS, `app_config`에 넣지 않고 Supabase Edge Function Secret에만 저장합니다.

| Secret | 필수 | 용도 |
|---|---:|---|
| `GITHUB_TOKEN` | 예 | GitHub Billing, Actions 저장공간, 저장소 Traffic API 조회 |
| `GITHUB_OWNER` | 예 | `CHO-Talents` |
| `GITHUB_REPO` | 예 | `CHO-Talents` |
| `SUPABASE_ACCESS_TOKEN` | 예 | Supabase Management API 공식 API 요청 통계 조회 |
| `SUPABASE_PROJECT_REF` | 예 | `blitrrcdkkkszvgylnus` |
| `SLACK_WEBHOOK_OPERATIONS` | 예 | 70/85/95% 알림을 보낼 운영관리 채널 |
| `SERVICE_STATS_URL` | 선택 | Slack 알림의 상세 페이지 링크. 미설정 시 운영 GitHub Pages URL 사용 |

`SUPABASE_URL`과 `SUPABASE_SERVICE_ROLE_KEY`는 Supabase가 Edge Function에 기본 제공합니다. Kakao 사용량은 프로젝트의 실제 Map SDK 로드와 장소 검색 호출을 자체 계측하므로 별도 Kakao Admin Key가 필요하지 않습니다.

예시 명령의 값은 로컬 환경에서만 치환합니다.

```powershell
supabase secrets set --project-ref blitrrcdkkkszvgylnus `
  GITHUB_TOKEN="<GITHUB_FINE_GRAINED_TOKEN>" `
  GITHUB_OWNER="CHO-Talents" `
  GITHUB_REPO="CHO-Talents" `
  SUPABASE_ACCESS_TOKEN="<SUPABASE_ACCESS_TOKEN>" `
  SUPABASE_PROJECT_REF="blitrrcdkkkszvgylnus" `
  SLACK_WEBHOOK_OPERATIONS="<OPERATIONS_WEBHOOK_URL>" `
  SERVICE_STATS_URL="https://cho-talents.github.io/CHO-Talents/admin/service-stats.html"
```

### GitHub Token 권한

Fine-grained personal access token의 접근 대상을 `CHO-Talents/CHO-Talents`로 제한하고 아래 읽기 권한만 부여합니다.

- Organization permissions: `Administration: Read`
- Repository permissions: `Actions: Read`, `Administration: Read`, `Metadata: Read`

Billing API는 조직 관리자 계정의 토큰이어야 합니다. 저장소 Traffic API는 Repository `Administration: Read`가 필요합니다.

### Supabase Access Token 권한

- Personal access token 또는 fine-grained token
- 대상 프로젝트 접근
- Fine-grained token 사용 시 `analytics_usage_read`

## 4. 6시간 예약 수집

`docs/TASK-070_service_usage_cron.sql`의 `<SUPABASE_SERVICE_ROLE_KEY>`를 현재 프로젝트 Service Role Key로 바꾼 뒤 SQL Editor에서 한 번 실행합니다.

- Vault에는 예약 호출용 Service Role Key만 저장됩니다.
- `pg_cron`은 UTC 기준이므로 `03,09,15,21 UTC`가 `12,18,00,06 KST`에 해당합니다.
- 동일한 작업명이 있으면 제거하고 다시 생성하므로 재설정할 수 있습니다.

## 5. 수집값 해석

| 표시 | 의미 |
|---|---|
| 공식 API | GitHub/Supabase 관리 API가 반환한 값 |
| DB 직접 | `pg_database_size`, `storage.objects`, `auth.users`에서 계산한 값 |
| 프로젝트 계측 | 이 프로젝트의 페이지, SDK, Edge Function, Webhook 호출 기록 |
| 추정 | 브라우저 Resource Timing 또는 Billing 단위 정규화 값 |
| Secret 필요 | 수집기는 배포됐지만 해당 API Secret이 없거나 권한이 부족함 |

Supabase Free 플랜은 초과 사용료가 자동 과금되는 대신 서비스 제한 또는 grace period가 적용될 수 있습니다. GitHub는 결제수단/예산 설정에 따라 초과 사용이 차단되거나 과금될 수 있습니다. Kakao 예상 비용은 유료 API를 활성화한 경우에만 실제 비용이 됩니다. Slack Free의 90일 내역과 앱 10개는 과금형 종량제가 아니라 기능 제한입니다.

## 6. 확인 순서

1. 부장 교사 이상 계정으로 `admin/service-stats.html`에 접속합니다.
2. `지금 수집`을 눌러 수동 수집을 확인합니다.
3. 플랫폼 카드가 `API 연결` 또는 `프로젝트 계측`으로 표시되는지 확인합니다.
4. `service_usage_collection_runs`의 최신 행이 `success` 또는 예상한 `partial`인지 확인합니다.
5. Cron 설정 후 `cron.job_run_details`에서 6시간 예약 실행을 확인합니다.

브라우저 계측은 개인정보, 입력값, URL 쿼리 문자열을 저장하지 않으며 페이지 경로와 서비스 호출 종류, 전송량만 기록합니다.
