# Configuration Guide

이 문서는 CHO-Talents 프로젝트의 공개 설정과 비밀 설정을 분리해 관리하는 기준을 설명한다.

## 1. 결론

| 항목 | 제공된 정보로 충분한가? | 설명 |
|---|---|---|
| GitHub 소스 형상관리 | 조건부 충분 | GitHub PAT에 해당 저장소의 `Contents: Read/Write` 권한 또는 classic `repo` 권한이 있으면 `develop` 브랜치 push가 가능하다. |
| Supabase 브라우저 CRUD | 기존 공개 키로 가능 | 현재 사이트는 `SUPABASE_URL` + publishable/anon key + 사용자 로그인 + RLS/RPC 기준으로 동작한다. |
| Supabase 관리 API/CLI | 조건부 충분 | `sbp_...` 형태의 Supabase access token은 Management API 또는 Supabase CLI 인증에 사용한다. 토큰이 해당 프로젝트 권한을 가지면 스키마 적용 자동화가 가능하다. |
| Supabase 무제한 DB CRUD/SQL | 추가 정보 필요 | 서비스 롤 키 또는 DB connection string/password가 필요하다. 이 값은 브라우저에 절대 노출하면 안 된다. |

## 2. 파일 구성

| 파일 | Git 추적 | 용도 |
|---|---|---|
| `config/public-config.js` | 추적 | 브라우저가 읽어도 되는 공개 런타임 설정 |
| `.env.example` | 추적 | 로컬 비밀 설정 템플릿 |
| `.env.local` | 미추적 | 실제 GitHub PAT, Supabase access token, service-role key 등 비밀값 |
| `js/supabase-config.js` | 추적 | `window.CHO_TALENTS_CONFIG`를 읽어 Supabase 클라이언트 초기화 |
| `scripts/load-env.ps1` | 추적 | `.env.local`을 읽어 현재 PowerShell 세션의 환경변수로 설정 |
| `scripts/install-supabase-database.ps1` | 추적 | 새 Supabase DB에 전체 설치 SQL을 적용하거나 설치 SQL을 생성 |
| `docs/INITIAL_DATABASE_SETUP.sql` | 추적 | 빈 Supabase DB에 현재 테이블/RPC/RLS/Storage/기본 데이터를 한 번에 설치 |
| `docs/INITIAL_DATABASE_SETUP.md` | 추적 | SQL Editor 실행 순서와 PowerShell 자동 설치 방법 |
| `docs/SUPABASE_NEW_PROJECT_SETUP.md` | 추적 | 다른 Supabase 프로젝트에서 새로 시작하는 설치 절차 |
| `docs/TASK-057_code_master.sql` | 추적 | `code_groups`/`code_items` 코드 마스터와 코드 컬럼 검증 트리거 |
| `docs/TASK-058_product_category_policy.sql` | 추적 | 구매 담당 교사(70+) 이상 상품 카테고리 관리자의 `products.category` 코드 항목 추가 RLS 정책 |
| `docs/TASK-068_product_category_page_and_sort_order.sql` | 추적 | 상품 정렬 순번 컬럼/인덱스와 상품 카테고리 관리 70+ 정책 |
| `docs/TASK-072_data_retention_180d.sql` | 추적 | 서비스 통계 스냅샷/수집 이력과 확인 완료 활동 로그 180일 보존 정책 |
| `docs/TASK-073_manual_retention_cleanup.sql` | 추적 | 관리자용 180일 초과 서비스 통계/확인 완료 활동 로그 수동 삭제 RPC와 로그 액션 |
| `docs/TASK-074_plan.md`, `docs/TASK-074_test_scenario.md`, `docs/TASK-074_test_result.md`, `docs/TASK-074_change_report.md` | 추적 | 활동 로그 영어 저장/한글 표시 분리 작업 계획, 검증, 변경 보고 |
| `docs/TASK-074_activity_logs_english_details.sql` | 추적 | 기존 활동 로그 details의 한글 별칭/중복/client 항목을 영어 key 중심으로 정리 |
| `docs/TASK-083_talent_item_emoji.sql` | 추적 | 기존 운영 DB의 `talent_items.emoji` 카드 이모지 컬럼과 기본 이모지 보정 |
| `docs/TASK-041_app_config.sql` | 추적 | Supabase `app_config` 테이블, RLS, 공개 설정 RPC, 초기 데이터 |
| `docs/edge-function-slack-notify.ts` | 추적 | Slack 알림 Edge Function 배포용 소스 |
| `docs/SLACK_NOTIFICATION_RULES.md` | 추적 | Slack 알림 type, 라우팅, Secret 기준 |

## 3. 공개 설정

`config/public-config.js`에는 사이트가 처음 Supabase에 접속하기 위해 필요한 최소 공개값만 둔다.

- Supabase Project URL
- Supabase publishable/anon key
- Auth 이메일 도메인
- Kakao JavaScript key
- GitHub 저장소 owner/repo/branch 같은 비밀이 아닌 메타데이터

`TARGET_ENV` 값으로 `PROD` 또는 `DEV` 설정을 선택한다. 이 값은 Supabase `app_config.env`와 같아야 한다. 현재 `PROD` 부트스트랩 설정은 `https://rabakjtjtkelpskptnvi.supabase.co` 프로젝트를 바라본다. Kakao Maps JavaScript 키도 같은 `TARGET_ENV` 기준으로 선택하며, DEV는 `f880c1746c4cd81e2fa54df45ebea41d`, PROD는 `0ef8925b28135eeac474bc411c456170`을 사용한다.

Supabase 접속 이후에는 `app_config` 테이블의 공개 설정을 `get_public_app_config()` RPC로 조회한다. 브라우저는 테이블을 직접 조회하지 않고 RPC 결과만 사용한다.
단, Kakao Maps JavaScript 키는 `config/public-config.js`에 환경별 값이 명시되어 있으면 해당 값을 우선 사용한다. 이는 `app_config`에 이전 환경 키가 남아 있는 경우 배포 페이지가 잘못된 Kakao 앱 키로 SDK를 로드하지 않도록 하기 위함이다.

현재 공개 RPC로 제공하는 값은 다음과 같다.

| key_name | 용도 |
|---|---|
| `SUPABASE_URL` | Supabase 프로젝트 URL |
| `SUPABASE_ANON_KEY` | 브라우저 공개 publishable/anon key |
| `SUPABASE_AUTH_EMAIL_DOMAIN` | 아이디 로그인용 내부 이메일 도메인 |
| `KAKAO_MAP_KEY` | 카카오 지도 JavaScript 공개 키 |
| `GITHUB_OWNER` | GitHub 저장소 owner |
| `GITHUB_REPO` | GitHub 저장소 이름 |
| `GITHUB_BRANCH` | 기본 브랜치 |

## 4. 비밀 설정

`.env.local`에는 아래 값을 넣을 수 있다. 이 파일은 `.gitignore`에 포함되어 있으므로 커밋하지 않는다.

```text
GITHUB_PAT=...
GITHUB_TOKEN=...
SB_MANAGEMENT_ACCESS_TOKEN=...
SUPABASE_SECRET_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
SUPABASE_DB_CONNECTION_STRING=...
```

반복적인 운영 로그 한글 번역 점검/보완은 [로그 번역 운영 런북](LOG_TRANSLATION_RUNBOOK.md)을 따른다. 이 작업에는 대상 환경과 프로젝트 ref, 그리고 로컬의 `SUPABASE_SECRET_KEY`(권장) 또는 `SUPABASE_SERVICE_ROLE_KEY`(레거시)가 필요하다. 두 키 모두 프로젝트 전체 데이터 권한을 가지므로 채팅, 정적 파일, `app_config`, Git에 입력하지 않는다.

로컬 PowerShell 자동화에서는 아래처럼 설정을 읽는다.

```powershell
. .\scripts\load-env.ps1
```

Supabase `app_config` 테이블에는 비밀 원문을 넣지 않는다. 대신 아래처럼 참조값만 둔다.

| key_name | key_value 예시 | 실제 저장 위치 |
|---|---|---|
| `GITHUB_PAT` | `env:GITHUB_PAT` | 로컬 `.env.local`, CI secret, 서버/Edge Function 환경변수 |
| `GITHUB_TOKEN` | 미저장 | 서비스 통계용 GitHub fine-grained token. Edge Function Secret |
| `SB_MANAGEMENT_ACCESS_TOKEN` | `env:SB_MANAGEMENT_ACCESS_TOKEN` | 로컬 `.env.local`, CI secret |
| `SUPABASE_SECRET_KEY` | `env:SUPABASE_SECRET_KEY` | 서버/로컬 자동화용 권장 Secret key. 로컬 `.env.local`, CI secret |
| `SUPABASE_SERVICE_ROLE_KEY` | `env:SUPABASE_SERVICE_ROLE_KEY` | 서버/Edge Function 환경변수 또는 Supabase Vault |
| `SUPABASE_DB_CONNECTION_STRING` | `env:SUPABASE_DB_CONNECTION_STRING` | 로컬/CI 비밀 저장소 |
| `SLACK_WEBHOOK_PART1` ~ `SLACK_WEBHOOK_PART5` | `env:SLACK_WEBHOOK_PART1` 등 | Supabase Edge Function Secret |
| `SLACK_WEBHOOK_WORSHIP` | `env:SLACK_WEBHOOK_WORSHIP` | Supabase Edge Function Secret |
| `SLACK_WEBHOOK_PRODUCT_MANAGEMENT` | `env:SLACK_WEBHOOK_PRODUCT_MANAGEMENT` | Supabase Edge Function Secret |
| `SLACK_WEBHOOK_OPERATIONS` | `env:SLACK_WEBHOOK_OPERATIONS` | Supabase Edge Function Secret |
| `SB_PROJECT_REF` | 미저장 | 서비스 통계용 Supabase Management API 프로젝트 식별자 |
| `SERVICE_STATS_URL` | 미저장 | 서비스 할당량 Slack 알림의 상세 페이지 링크 |
| `SLACK_WEBHOOK_ANSWER` | `env:SLACK_WEBHOOK_ANSWER` | Supabase Edge Function Secret |

## 5. Supabase app_config 적용

> v3.89.0 사용자 통계의 학생/교사 필터를 사용하려면 `docs/TASK-091_user_stats_filters.sql`을 적용합니다. 이 SQL은 `get_user_login_statistics`와 `get_user_login_stat_detail` RPC에 동일한 `p_user_type` 조건을 추가하므로 집계와 상세 모달의 결과가 일치합니다.

> v3.88.0 상품 추천 투표 권한 정책을 사용하려면 `docs/TASK-090_product_suggestion_super_admin_vote_privileges.sql`을 `TASK-089` 다음에 적용합니다. 진행 중 익명 집계, 직접 채택/불채택 결정, 현재 유효 정원 기준 종료는 `profiles.is_super_admin=true`인 최고관리자만 허용됩니다. 기존 `SLACK_WEBHOOK_OPERATIONS` Secret과 Slack Edge Function 설정은 그대로 사용합니다.

새 Supabase Database를 완전히 비어 있는 상태에서 구성할 때는 먼저 `docs/INITIAL_DATABASE_SETUP.sql`을 Supabase SQL Editor에서 실행한 뒤 `docs/TASK-057_code_master.sql`, `docs/TASK-058_product_category_policy.sql`, `docs/TASK-065_registration_approval_contact.sql`, `docs/TASK-066_notice_reads_and_category_manage.sql`, `docs/TASK-068_product_category_page_and_sort_order.sql`, `docs/TASK-072_data_retention_180d.sql`, `docs/TASK-073_manual_retention_cleanup.sql`, `docs/TASK-078_product_purchase_url.sql`, `docs/TASK-079_log_actor_identity.sql`, `docs/TASK-081_user_login_statistics.sql`, `docs/TASK-082_exclude_super_admin_login_history.sql`, `docs/TASK-083_talent_item_emoji.sql`, `docs/TASK-084_user_login_statistics_detail.sql`, `docs/TASK-085_product_suggestions.sql`, `docs/TASK-086_product_suggestion_admin_decision.sql`, `docs/TASK-087_product_suggestion_detail_image.sql`, `docs/TASK-088_product_suggestion_adoption_talent.sql`을 이어서 실행한다. 기본 설치 SQL은 테이블, 함수/RPC, RLS 정책, Storage 버킷, 기본 권한 데이터를 포함하고, `TASK-057`은 권한/유형/상태/카테고리/로그 액션 코드 마스터를 추가하며 `TASK-058`/`TASK-066`/`TASK-068`은 상품 카테고리 추가·수정·삭제 권한과 상품 정렬 순번, 공지 열람 현황 조회 권한을 보강한다. `TASK-065`는 승인 대기 로그인 안내 담당자 조회 RPC다. `TASK-072`는 서비스 통계 스냅샷/수집 이력과 확인 완료 활동 로그의 180일 보존 정책을 적용하고, `TASK-073`은 운영 화면의 180일 초과 수동 삭제 버튼이 호출하는 관리자용 RPC와 로그 액션을 보강한다. `TASK-078`은 상품별 구매 URL 컬럼을 추가하고, `TASK-079`는 활동 로그를 프로필의 표시 이름과 계정으로 정규화하며 기존 로그도 보정한다. `TASK-081`은 성공 로그인 이력 테이블과 관리자용 KST 통계 RPC를 추가하며, `TASK-082`는 최고관리자 이력 정리와 기록·통계 제외를 보강한다. `TASK-083`은 기존 운영 DB의 달란트 안내 카드 이모지를 보정한다. `TASK-085`는 상품 추천, 등록 시점 투표 정원, 비밀 투표 결과 노출 제어, 관리자 현재 유효 정원 종료 RPC와 추천 이미지 Storage 정책을 추가한다. `TASK-086`은 투표중 추천을 관리자(100+)가 채택/불채택으로 직접 결정하는 전용 RPC를 추가하고, `TASK-087`은 추천 상세 이미지·득표 비공개·종료 투표 잠금을, `TASK-088`은 채택 보상 항목·중복 방지 보상 원장·순번 999를 추가한다. 기존 운영 DB에 v3.66 한글 별칭 로그가 남아 있으면 `docs/TASK-074_activity_logs_english_details.sql`로 중복 details와 client 항목을 영어 key 중심으로 정리한다.

공개 설정만 기존 DB에 보강하거나 점검할 때는 Supabase SQL Editor 또는 Management API에서 `docs/TASK-041_app_config.sql`을 실행한다.

로컬에서 DB 접속 문자열을 사용할 수 있으면 `scripts/install-supabase-database.ps1` 또는 `scripts/install-supabase-database.sh`로 설치 SQL 생성 또는 실행을 자동화할 수 있다. 이 스크립트들은 기본으로 `docs/TASK-057_code_master.sql`, `docs/TASK-058_product_category_policy.sql`, `docs/TASK-068_product_category_page_and_sort_order.sql`, `docs/TASK-081_user_login_statistics.sql`, `docs/TASK-082_exclude_super_admin_login_history.sql`, `docs/TASK-084_user_login_statistics_detail.sql`, `docs/TASK-085_product_suggestions.sql`, `docs/TASK-086_product_suggestion_admin_decision.sql`, `docs/TASK-087_product_suggestion_detail_image.sql`, `docs/TASK-088_product_suggestion_adoption_talent.sql`, `docs/TASK-089_product_suggestion_slack_notifications.sql`을 합본에 포함하고, 적용 후 `scripts/verify-task-057-code-master.sql`로 검증한다. v3.65.0~v3.66.0 보강 SQL은 생성된 합본 뒤에 수동 적용하거나 스크립트의 추가 SQL 옵션으로 함께 넘긴다. 새 프로젝트 전체 설치 절차는 `docs/SUPABASE_NEW_PROJECT_SETUP.md`를 함께 확인한다.

적용 후 브라우저에서는 아래 흐름으로 설정을 읽는다.

1. `config/public-config.js`에서 Supabase 접속용 최소 공개값을 읽는다.
2. `initSupabase()`가 Supabase 클라이언트를 만든다.
3. `loadRemotePublicConfig()`가 `get_public_app_config(TARGET_ENV)` RPC를 호출한다. 예: `DEV`, `PROD`.
4. 공개 설정만 `window.CHO_TALENTS_REMOTE_CONFIG`에 저장한다.
5. 코드에서는 `getPublicConfigValue(keyName, fallback)`로 공개 설정을 조회할 수 있다.

`app_config` 테이블은 RLS가 켜져 있고 직접 SELECT 정책을 만들지 않는다. 공개값은 `SECURITY DEFINER` RPC가 `is_secret = false`이고 `use_yn = true`인 행만 반환한다.

주의: publishable/anon key는 브라우저에 공개 가능한 키이지만 비밀키가 아니다. 서비스 롤 키, DB connection string, Supabase access token은 `.env.local`, CI secret, 서버/Edge Function 환경변수, Vault 같은 비공개 위치에서만 사용한다.

## 6. Slack Edge Function 설정

Slack 알림은 브라우저에서 Webhook URL을 직접 호출하지 않는다. 화면은 `sendSlackNotify(type, data)`로 Supabase Edge Function `slack-notify`를 호출하고, Edge Function이 Secret으로 저장된 Webhook URL을 선택해 Slack으로 전송한다.

필수 Secret:

| Secret | 채널 |
|---|---|
| `SLACK_WEBHOOK_PART1` ~ `SLACK_WEBHOOK_PART5` | 1부~5부 |
| `SLACK_WEBHOOK_WORSHIP` | 예배부 |
| `SLACK_WEBHOOK_PRODUCT_MANAGEMENT` | 상품 관리 |
| `SLACK_WEBHOOK_OPERATIONS` | 운영 로그 |
| `SLACK_WEBHOOK_ANSWER` | Q&A |

정적 파일, `config/public-config.js`, `app_config`에는 Webhook 원문을 넣지 않는다. `app_config`에는 `env:SLACK_WEBHOOK_...` 참조값만 기록할 수 있다.

## 7. 추가로 필요한 Supabase 정보

제공된 Supabase access token만으로는 브라우저 앱에서 DB CRUD를 직접 수행하는 용도로 쓰지 않는다. DB 관리 자동화 목적이라면 다음 중 하나가 추가로 필요하다.

| 목적 | 필요한 값 |
|---|---|
| RLS를 무시하는 서버/로컬 CRUD | `SUPABASE_SECRET_KEY`(권장) 또는 `SUPABASE_SERVICE_ROLE_KEY`(레거시) |
| SQL 실행, 마이그레이션, 백업 | `SUPABASE_DB_CONNECTION_STRING` 또는 DB password |
| 서비스 통계 Supabase Management API 연결 | `SB_MANAGEMENT_ACCESS_TOKEN` + `SB_PROJECT_REF` |

## 8. 보안 원칙

- GitHub PAT와 Supabase access token은 정적 HTML/JS에 넣지 않는다.
- `app_config`에 비밀값 원문을 평문 저장하지 않는다.
- 서비스 롤 키는 브라우저에서 사용하지 않는다.
- Slack Webhook URL은 브라우저에서 사용하지 않고 Supabase Edge Function Secret으로만 관리한다.
- 브라우저 앱은 publishable/anon key와 RLS/RPC로 제한된 작업만 수행한다.
- 로컬 자동화나 배포 스크립트는 `.env.local`을 읽어 실행한다.
