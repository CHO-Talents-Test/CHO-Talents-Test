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
4. 이어서 `docs/TASK-057_code_master.sql`부터 최신 보강 SQL을 순서대로 실행한다. 상품 추천과 비밀 투표 기능을 사용하려면 마지막에 `docs/TASK-085_product_suggestions.sql`, `docs/TASK-086_product_suggestion_admin_decision.sql`, `docs/TASK-087_product_suggestion_detail_image.sql`, `docs/TASK-088_product_suggestion_adoption_talent.sql`, `docs/TASK-089_product_suggestion_slack_notifications.sql`, `docs/TASK-090_product_suggestion_super_admin_vote_privileges.sql`을 순서대로 반드시 적용하고 최신 `slack-notify` Edge Function을 배포한다. `TASK-087`은 추천 상세 이미지, 종료 전 일반 투표자 득표 비공개와 종료 투표 잠금을, `TASK-088`은 채택 추천 등록자의 건별 1달란트 자동 지급과 채택 상품 순번 999를, `TASK-089`는 직접 결정의 익명 득표 반환을, `TASK-090`은 진행 중 집계·직접 결정·현재 유효 정원 종료를 최고관리자로 제한한다.
4. `docs/TASK-057_code_master.sql`을 SQL Editor에서 이어서 실행한다.
5. `docs/TASK-058_product_category_policy.sql`을 SQL Editor에서 이어서 실행한다.
6. `docs/TASK-068_product_category_page_and_sort_order.sql`을 SQL Editor에서 이어서 실행한다.
7. `docs/TASK-069_product_detail_image.sql`을 SQL Editor에서 이어서 실행한다.
8. `docs/TASK-072_data_retention_180d.sql`을 SQL Editor에서 이어서 실행해 운영 데이터 180일 보존 정책을 적용한다.
9. `docs/TASK-073_manual_retention_cleanup.sql`을 SQL Editor에서 이어서 실행해 운영 화면의 180일 초과 수동 삭제 RPC를 적용한다. 기존 운영 DB에서 v3.66 한글 별칭 로그가 남아 있으면 `docs/TASK-074_activity_logs_english_details.sql`도 실행해 `activity_logs.details` 중복/client 항목을 정리한다.
10. `admin / 1234`로 로그인하고 비밀번호를 바꾼다.

### PowerShell/psql

```powershell
. .\scripts\load-env.ps1
.\scripts\install-supabase-database.ps1
```

PowerShell 설치 스크립트는 기본으로 `docs/TASK-057_code_master.sql`, `docs/TASK-058_product_category_policy.sql`, `docs/TASK-068_product_category_page_and_sort_order.sql`, `docs/TASK-069_product_detail_image.sql`을 함께 적용한다.

### macOS/Linux bash/psql

```bash
scripts/install-supabase-database.sh --app-config-env DEV
```

셸 스크립트도 `.env.local`을 자동으로 읽고, 기본으로 `docs/TASK-057_code_master.sql`, `docs/TASK-058_product_category_policy.sql`, `docs/TASK-068_product_category_page_and_sort_order.sql`, `docs/TASK-069_product_detail_image.sql`을 함께 적용한다.

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

생성된 합본 SQL에는 코드 마스터(`code_groups`, `code_items`), 상품 카테고리 추가 정책, 상품 정렬 순번 보강, 상품 상세 설명 이미지 컬럼이 포함된다. v3.65.0~v3.74.0 보강 기능까지 새 DB에 바로 적용하려면 합본 실행 후 `docs/TASK-065_registration_approval_contact.sql`, `docs/TASK-066_notice_reads_and_category_manage.sql`, `docs/TASK-068_product_category_page_and_sort_order.sql`, `docs/TASK-072_data_retention_180d.sql`, `docs/TASK-073_manual_retention_cleanup.sql`을 추가로 실행한다. `docs/TASK-067_korean_activity_logs.sql`은 과거 한글 별칭 백필용이므로 신규 DB 기본 설치에는 실행하지 않고, 기존 운영 DB의 중복 details 정리는 `docs/TASK-074_activity_logs_english_details.sql`로 처리한다.

## 부분 설치 복구

초기 SQL 실행 중 일부만 적용된 DB에서는 전체 초기 SQL을 반복 실행하지 않는다.

1. `docs/FIX_INITIAL_APP_CONFIG_DEV.sql`
2. `docs/FIX_TASK057_PREREQUISITES.sql`
3. `docs/TASK-057_code_master.sql`
4. `docs/TASK-058_product_category_policy.sql`
5. `docs/TASK-068_product_category_page_and_sort_order.sql`
6. `docs/TASK-069_product_detail_image.sql`
7. `scripts/verify-task-057-code-master.sql`

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
- 상품 카테고리 관리 페이지의 `products.category` 등록/수정/삭제 정책(구매 담당 교사 70+)
- 상품 `products.sort_order` 정렬 순번
- 상품 `products.detail_image_url` 상세 설명 이미지
- QR 수령 RPC `scan_qr_talent`
- `talent_transactions.source`
- `role_page_access`, `role_page_features`, `page_permissions`
- Slack Secret 참조값
- 운영 데이터 180일 보존 정책과 관리자용 수동 삭제 RPC
