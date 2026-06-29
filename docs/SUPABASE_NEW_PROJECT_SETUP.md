# 새 Supabase 프로젝트 설치 가이드

이 문서는 운영 중인 CHO-Talents 소스를 다른 Supabase 프로젝트에서 새로 시작할 때 필요한 실행 순서를 정리한다.

## 준비물

| 값 | 용도 |
|---|---|
| `SUPABASE_URL` | 새 Supabase 프로젝트 URL |
| `SUPABASE_ANON_KEY` | 브라우저 공개 publishable/anon key |
| `SUPABASE_DB_CONNECTION_STRING` | SQL 설치 자동 실행용 DB 접속 문자열 |
| `APP_CONFIG_ENV` | `config/public-config.js`의 `TARGET_ENV`와 같은 값 (`PROD` 또는 `DEV`) |
| `KAKAO_MAP_KEY` | QR 위치 제한 주소 검색 |
| Slack Webhook URLs | Edge Function Secret으로만 등록 |

## 설치 방법

### SQL Editor

1. Supabase Dashboard에서 새 프로젝트를 만든다.
2. `docs/INITIAL_DATABASE_SETUP.sql` 하단의 `공개 런타임 설정과 비밀 참조값` 값을 새 프로젝트 기준으로 바꾼다.
   - `env` 값은 `config/public-config.js`의 `TARGET_ENV`와 맞춘다. DEV 검증이면 `DEV`를 사용한다.
3. SQL Editor에서 전체 실행한다.
4. `docs/TASK-057_code_master.sql`을 SQL Editor에서 이어서 실행한다.
5. `docs/TASK-058_product_category_policy.sql`을 SQL Editor에서 이어서 실행한다.
6. `admin_user / 1234`로 로그인하고 비밀번호를 바꾼다.

### PowerShell/psql

```powershell
. .\scripts\load-env.ps1
.\scripts\install-supabase-database.ps1
```

PowerShell 설치 스크립트는 기본으로 `docs/TASK-057_code_master.sql`과 `docs/TASK-058_product_category_policy.sql`을 함께 적용한다.

### macOS/Linux bash/psql

```bash
scripts/install-supabase-database.sh --app-config-env DEV
```

셸 스크립트도 `.env.local`을 자동으로 읽고, 기본으로 `docs/TASK-057_code_master.sql`과 `docs/TASK-058_product_category_policy.sql`을 함께 적용한다.

SQL 파일만 생성할 수도 있다.

```powershell
.\scripts\install-supabase-database.ps1 `
  -GenerateOnly `
  -OutputSqlPath .\docs\INITIAL_DATABASE_SETUP.generated.sql `
  -AppConfigEnv DEV `
  -SupabaseUrl "https://YOUR_PROJECT_REF.supabase.co" `
  -SupabaseAnonKey "YOUR_PUBLISHABLE_OR_ANON_KEY"
```

```bash
scripts/install-supabase-database.sh \
  --generate-only \
  --output-sql-path docs/INITIAL_DATABASE_SETUP.generated.sql \
  --app-config-env DEV \
  --supabase-url "https://YOUR_PROJECT_REF.supabase.co" \
  --supabase-anon-key "YOUR_PUBLISHABLE_OR_ANON_KEY"
```

생성된 합본 SQL에도 코드 마스터(`code_groups`, `code_items`)와 상품 카테고리 추가 정책이 포함된다.

## 부분 설치 복구

초기 SQL 실행 중 일부만 적용된 DB에서는 전체 초기 SQL을 반복 실행하지 않는다.

1. `docs/FIX_INITIAL_APP_CONFIG_DEV.sql`
2. `docs/FIX_TASK057_PREREQUISITES.sql`
3. `docs/TASK-057_code_master.sql`
4. `docs/TASK-058_product_category_policy.sql`
5. `scripts/verify-task-057-code-master.sql`

## Slack Edge Function

1. `docs/edge-function-slack-notify.ts`를 Supabase Edge Function `slack-notify`로 배포한다.
2. 아래 Secret을 새 프로젝트에 등록한다.
   - `SLACK_WEBHOOK_PART1` ~ `SLACK_WEBHOOK_PART5`
   - `SLACK_WEBHOOK_WORSHIP`
   - `SLACK_WEBHOOK_PRODUCT_MANAGEMENT`
   - `SLACK_WEBHOOK_OPERATIONS`
   - `SLACK_WEBHOOK_ANSWER`
3. `admin/slack-rules.html`에서 라우팅 기준을 확인한다.

## 새 DB에 포함되는 최신 기능

- 권한 레벨: 학생 20, 일반 교사 40, 부서 담당 교사 60, 구매 담당 교사 70, 부장 교사 80, 전도사님 90, 관리자 100, 최고관리자 110
- `user_preferences.page_sizes`
- 구매 취소 RPC `cancel_product_order`
- 상품 등록 모달의 `products.category` 코드 추가 정책
- QR 수령 RPC `scan_qr_talent`
- `talent_transactions.source`
- `role_page_access`, `role_page_features`, `page_permissions`
- Slack Secret 참조값
