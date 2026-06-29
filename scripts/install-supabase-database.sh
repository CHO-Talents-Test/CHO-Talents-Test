#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONNECTION_STRING=""
SQL_PATH="$ROOT_DIR/docs/INITIAL_DATABASE_SETUP.sql"
APP_CONFIG_ENV_VALUE=""
SUPABASE_URL_VALUE=""
SUPABASE_ANON_KEY_VALUE=""
AUTH_EMAIL_DOMAIN_VALUE=""
KAKAO_MAP_KEY_VALUE=""
GITHUB_OWNER_VALUE=""
GITHUB_REPO_VALUE=""
GITHUB_BRANCH_VALUE=""
PSQL_PATH="psql"
OUTPUT_SQL_PATH=""
VERIFY_SQL_PATH="$SCRIPT_DIR/verify-task-057-code-master.sql"
ENV_FILE="$ROOT_DIR/.env.local"
GENERATE_ONLY=0
SKIP_VERIFY=0
EXTRA_SQL_PATHS=()

usage() {
  cat <<'USAGE'
Apply the CHO-Talents Supabase schema and seed data to a new database.

Usage:
  scripts/install-supabase-database.sh [options]

Options:
  --connection-string VALUE  PostgreSQL connection string.
  --sql-path PATH            Base SQL path. Defaults to docs/INITIAL_DATABASE_SETUP.sql.
  --app-config-env VALUE     app_config.env value. Defaults to config/public-config.js TARGET_ENV.
  --supabase-url VALUE       Supabase project URL.
  --supabase-anon-key VALUE  Supabase publishable/anon key.
  --auth-email-domain VALUE  Auth email domain. Defaults to @cho-talents.app.
  --kakao-map-key VALUE      Kakao JavaScript key.
  --github-owner VALUE       GitHub owner. Defaults to CHO-Talents.
  --github-repo VALUE        GitHub repo. Defaults to CHO-Talents.
  --github-branch VALUE      GitHub branch. Defaults to develop.
  --extra-sql-path PATH      Extra SQL to append. Can be repeated.
  --output-sql-path PATH     Write combined SQL to this path.
  --verify-sql-path PATH     Verification SQL path.
  --psql-path PATH           psql executable path. Defaults to psql.
  --env-file PATH            Env file to load. Defaults to .env.local when present.
  --generate-only            Only generate combined SQL.
  --skip-verify              Skip post-apply TASK-057 verification.
  -h, --help                 Show this help.

The script automatically appends docs/TASK-057_code_master.sql and
docs/TASK-058_product_category_policy.sql when no --extra-sql-path is provided.
USAGE
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

load_env_file() {
  local path="$1"
  local line key value

  [ -f "$path" ] || return 0

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    case "$line" in
      ""|\#*) continue ;;
    esac

    key="${line%%=*}"
    value="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi

    export "$key=$value"
  done < "$path"
}

detect_public_config_env() {
  local config_path="$ROOT_DIR/config/public-config.js"

  [ -f "$config_path" ] || return 0
  sed -n "s/.*const TARGET_ENV = ['\"]\([^'\"]*\)['\"].*/\1/p" "$config_path" | head -n 1
}

sql_literal() {
  local value="$1"
  local escaped
  escaped="$(printf '%s' "$value" | sed "s/'/''/g")"
  printf "'%s'" "$escaped"
}

emit_config_patch() {
  local env_sql row_count
  env_sql="$(sql_literal "$APP_CONFIG_ENV_VALUE")"
  row_count=0

  emit_config_row() {
    local key="$1"
    local value="$2"
    local is_secret="$3"
    local use_yn="$4"
    local description="$5"

    [ -n "$value" ] || return 0

    if [ "$row_count" -gt 0 ]; then
      printf ',\n'
    fi

    row_count=$((row_count + 1))
    printf '  (%s, %s, %s, %s, %s, %s)' \
      "$env_sql" \
      "$(sql_literal "$key")" \
      "$(sql_literal "$value")" \
      "$is_secret" \
      "$use_yn" \
      "$(sql_literal "$description")"
  }

  cat <<'SQL'

-- ============================================================
-- Runtime config override for the target Supabase project
-- ============================================================

INSERT INTO public.app_config (env, key_name, key_value, is_secret, use_yn, description)
VALUES
SQL

  emit_config_row 'SUPABASE_URL' "$SUPABASE_URL_VALUE" false true 'Browser Supabase client bootstrap URL'
  emit_config_row 'SUPABASE_ANON_KEY' "$SUPABASE_ANON_KEY_VALUE" false true 'Browser publishable/anon key. Access is restricted by RLS/RPC.'
  emit_config_row 'SUPABASE_AUTH_EMAIL_DOMAIN' "$AUTH_EMAIL_DOMAIN_VALUE" false true 'Internal email domain for username-based login'
  emit_config_row 'KAKAO_MAP_KEY' "$KAKAO_MAP_KEY_VALUE" false true 'Browser-safe Kakao Maps JavaScript key'
  emit_config_row 'GITHUB_OWNER' "$GITHUB_OWNER_VALUE" false true 'GitHub repository owner metadata'
  emit_config_row 'GITHUB_REPO' "$GITHUB_REPO_VALUE" false true 'GitHub repository name metadata'
  emit_config_row 'GITHUB_BRANCH' "$GITHUB_BRANCH_VALUE" false true 'Default deployment/source branch metadata'
  emit_config_row 'GITHUB_PAT' 'env:GITHUB_PAT' true false 'Secret reference only. Store the real value in local, CI, server, or Edge Function environment variables.'
  emit_config_row 'SUPABASE_ACCESS_TOKEN' 'env:SUPABASE_ACCESS_TOKEN' true false 'Secret reference only. Used by Supabase CLI or Management API automation.'
  emit_config_row 'SUPABASE_SERVICE_ROLE_KEY' 'env:SUPABASE_SERVICE_ROLE_KEY' true false 'Server-only key. Never expose this value to browser code.'
  emit_config_row 'SUPABASE_DB_CONNECTION_STRING' 'env:SUPABASE_DB_CONNECTION_STRING' true false 'Database migration/admin connection string reference.'
  emit_config_row 'SLACK_WEBHOOK_PART1' 'env:SLACK_WEBHOOK_PART1' true false 'Slack Part 1 channel webhook. Store the real value as an Edge Function secret.'
  emit_config_row 'SLACK_WEBHOOK_PART2' 'env:SLACK_WEBHOOK_PART2' true false 'Slack Part 2 channel webhook. Store the real value as an Edge Function secret.'
  emit_config_row 'SLACK_WEBHOOK_PART3' 'env:SLACK_WEBHOOK_PART3' true false 'Slack Part 3 channel webhook. Store the real value as an Edge Function secret.'
  emit_config_row 'SLACK_WEBHOOK_PART4' 'env:SLACK_WEBHOOK_PART4' true false 'Slack Part 4 channel webhook. Store the real value as an Edge Function secret.'
  emit_config_row 'SLACK_WEBHOOK_PART5' 'env:SLACK_WEBHOOK_PART5' true false 'Slack Part 5 channel webhook. Store the real value as an Edge Function secret.'
  emit_config_row 'SLACK_WEBHOOK_WORSHIP' 'env:SLACK_WEBHOOK_WORSHIP' true false 'Slack worship department channel webhook. Store the real value as an Edge Function secret.'
  emit_config_row 'SLACK_WEBHOOK_PRODUCT_MANAGEMENT' 'env:SLACK_WEBHOOK_PRODUCT_MANAGEMENT' true false 'Slack product management channel webhook. Store the real value as an Edge Function secret.'
  emit_config_row 'SLACK_WEBHOOK_OPERATIONS' 'env:SLACK_WEBHOOK_OPERATIONS' true false 'Slack operations log channel webhook. Store the real value as an Edge Function secret.'
  emit_config_row 'SLACK_WEBHOOK_ANSWER' 'env:SLACK_WEBHOOK_ANSWER' true false 'Slack Q&A channel webhook. Store the real value as an Edge Function secret.'

  if [ "$row_count" -eq 0 ]; then
    fail 'No app_config rows were generated.'
  fi

  cat <<'SQL'

ON CONFLICT (env, key_name) DO UPDATE
SET key_value = EXCLUDED.key_value,
    is_secret = EXCLUDED.is_secret,
    use_yn = EXCLUDED.use_yn,
    description = EXCLUDED.description,
    updated_at = now();

NOTIFY pgrst, 'reload schema';
SQL
}

write_combined_sql() {
  local output_path="$1"
  local output_dir extra_path

  output_dir="$(dirname "$output_path")"
  [ -d "$output_dir" ] || mkdir -p "$output_dir"
  : > "$output_path"

  [ -f "$SQL_PATH" ] || fail "SQL file not found: $SQL_PATH"
  cat "$SQL_PATH" >> "$output_path"
  printf '\n\n' >> "$output_path"

  for extra_path in "${EXTRA_SQL_PATHS[@]}"; do
    [ -f "$extra_path" ] || fail "Extra SQL file not found: $extra_path"
    cat "$extra_path" >> "$output_path"
    printf '\n\n' >> "$output_path"
  done

  emit_config_patch >> "$output_path"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --connection-string) CONNECTION_STRING="${2:-}"; shift 2 ;;
    --sql-path) SQL_PATH="${2:-}"; shift 2 ;;
    --app-config-env) APP_CONFIG_ENV_VALUE="${2:-}"; shift 2 ;;
    --supabase-url) SUPABASE_URL_VALUE="${2:-}"; shift 2 ;;
    --supabase-anon-key) SUPABASE_ANON_KEY_VALUE="${2:-}"; shift 2 ;;
    --auth-email-domain) AUTH_EMAIL_DOMAIN_VALUE="${2:-}"; shift 2 ;;
    --kakao-map-key) KAKAO_MAP_KEY_VALUE="${2:-}"; shift 2 ;;
    --github-owner) GITHUB_OWNER_VALUE="${2:-}"; shift 2 ;;
    --github-repo) GITHUB_REPO_VALUE="${2:-}"; shift 2 ;;
    --github-branch) GITHUB_BRANCH_VALUE="${2:-}"; shift 2 ;;
    --extra-sql-path) EXTRA_SQL_PATHS+=("${2:-}"); shift 2 ;;
    --output-sql-path) OUTPUT_SQL_PATH="${2:-}"; shift 2 ;;
    --verify-sql-path) VERIFY_SQL_PATH="${2:-}"; shift 2 ;;
    --psql-path) PSQL_PATH="${2:-}"; shift 2 ;;
    --env-file) ENV_FILE="${2:-}"; shift 2 ;;
    --generate-only) GENERATE_ONLY=1; shift ;;
    --skip-verify) SKIP_VERIFY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

load_env_file "$ENV_FILE"

CONNECTION_STRING="${CONNECTION_STRING:-${SUPABASE_DB_CONNECTION_STRING:-}}"
APP_CONFIG_ENV_VALUE="${APP_CONFIG_ENV_VALUE:-${APP_CONFIG_ENV:-}}"
APP_CONFIG_ENV_VALUE="${APP_CONFIG_ENV_VALUE:-$(detect_public_config_env)}"
APP_CONFIG_ENV_VALUE="${APP_CONFIG_ENV_VALUE:-PROD}"
SUPABASE_URL_VALUE="${SUPABASE_URL_VALUE:-${SUPABASE_URL:-}}"
SUPABASE_ANON_KEY_VALUE="${SUPABASE_ANON_KEY_VALUE:-${SUPABASE_ANON_KEY:-}}"
AUTH_EMAIL_DOMAIN_VALUE="${AUTH_EMAIL_DOMAIN_VALUE:-${SUPABASE_AUTH_EMAIL_DOMAIN:-@cho-talents.app}}"
KAKAO_MAP_KEY_VALUE="${KAKAO_MAP_KEY_VALUE:-${KAKAO_MAP_KEY:-}}"
GITHUB_OWNER_VALUE="${GITHUB_OWNER_VALUE:-${GITHUB_OWNER:-CHO-Talents}}"
GITHUB_REPO_VALUE="${GITHUB_REPO_VALUE:-${GITHUB_REPO:-CHO-Talents}}"
GITHUB_BRANCH_VALUE="${GITHUB_BRANCH_VALUE:-${GITHUB_BRANCH:-develop}}"

[ -n "$SUPABASE_URL_VALUE" ] || fail 'Supabase URL is required. Pass --supabase-url or set SUPABASE_URL.'
[ -n "$SUPABASE_ANON_KEY_VALUE" ] || fail 'Supabase anon key is required. Pass --supabase-anon-key or set SUPABASE_ANON_KEY.'

if [ "${#EXTRA_SQL_PATHS[@]}" -eq 0 ]; then
  DEFAULT_CODE_MASTER_SQL="$ROOT_DIR/docs/TASK-057_code_master.sql"
  if [ -f "$DEFAULT_CODE_MASTER_SQL" ]; then
    EXTRA_SQL_PATHS+=("$DEFAULT_CODE_MASTER_SQL")
  fi
  DEFAULT_PRODUCT_CATEGORY_POLICY_SQL="$ROOT_DIR/docs/TASK-058_product_category_policy.sql"
  if [ -f "$DEFAULT_PRODUCT_CATEGORY_POLICY_SQL" ]; then
    EXTRA_SQL_PATHS+=("$DEFAULT_PRODUCT_CATEGORY_POLICY_SQL")
  fi
fi

if [ "$GENERATE_ONLY" -eq 1 ] && [ -z "$OUTPUT_SQL_PATH" ]; then
  fail 'Output SQL path is required when using --generate-only.'
fi

RUN_SQL_PATH="$OUTPUT_SQL_PATH"
TEMP_SQL_PATH=""
if [ -z "$RUN_SQL_PATH" ]; then
  TEMP_SQL_PATH="$(mktemp "${TMPDIR:-/tmp}/cho-talents-supabase-setup.XXXXXX.sql")"
  RUN_SQL_PATH="$TEMP_SQL_PATH"
  trap 'rm -f "$TEMP_SQL_PATH"' EXIT
fi

write_combined_sql "$RUN_SQL_PATH"

if [ -n "$OUTPUT_SQL_PATH" ]; then
  printf 'Generated SQL: %s\n' "$OUTPUT_SQL_PATH"
fi

if [ "$GENERATE_ONLY" -eq 1 ]; then
  exit 0
fi

[ -n "$CONNECTION_STRING" ] || fail 'Connection string is required. Pass --connection-string or set SUPABASE_DB_CONNECTION_STRING.'
command -v "$PSQL_PATH" >/dev/null 2>&1 || fail "psql was not found: $PSQL_PATH"

printf 'Applying SQL to Supabase database...\n'
"$PSQL_PATH" "$CONNECTION_STRING" -v ON_ERROR_STOP=1 -f "$RUN_SQL_PATH"

if [ "$SKIP_VERIFY" -eq 0 ]; then
  if [ -f "$VERIFY_SQL_PATH" ]; then
    printf 'Verifying TASK-057 code master...\n'
    "$PSQL_PATH" "$CONNECTION_STRING" -v ON_ERROR_STOP=1 -f "$VERIFY_SQL_PATH"
  else
    printf 'Warning: verification SQL not found: %s\n' "$VERIFY_SQL_PATH" >&2
  fi
fi

printf 'Supabase database setup completed.\n'
