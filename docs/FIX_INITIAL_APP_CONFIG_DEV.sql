-- ============================================================
-- Initial setup recovery: DEV app_config upsert
-- Use this when INITIAL_DATABASE_SETUP.sql failed with:
--   ERROR: 42P01: relation "cho_install_runtime_config" does not exist
--
-- Run order for a partially configured DEV database:
--   1. docs/FIX_INITIAL_APP_CONFIG_DEV.sql
--   2. docs/TASK-057_code_master.sql
--   3. scripts/verify-task-057-code-master.sql
-- ============================================================

BEGIN;

INSERT INTO public.app_config (env, key_name, key_value, is_secret, use_yn, description)
VALUES
  ('DEV', 'SUPABASE_URL', 'https://blitrrcdkkkszvgylnus.supabase.co', false, true, '브라우저 Supabase 클라이언트 부트스트랩 URL'),
  ('DEV', 'SUPABASE_ANON_KEY', 'sb_publishable_TgsQePzjxca9Hr3Lh_dHvA_O1JqRAQ6', false, true, '브라우저 공개 publishable/anon key. RLS/RPC로 권한 제한'),
  ('DEV', 'SUPABASE_AUTH_EMAIL_DOMAIN', '@cho-talents.app', false, true, '아이디 로그인용 내부 이메일 도메인'),
  ('DEV', 'KAKAO_MAP_KEY', '0ef8925b28135eeac474bc411c456170', false, true, '카카오 지도 JavaScript 공개 키'),
  ('DEV', 'GITHUB_OWNER', 'CHO-Talents', false, true, 'GitHub 저장소 owner 메타데이터'),
  ('DEV', 'GITHUB_REPO', 'CHO-Talents', false, true, 'GitHub 저장소 이름 메타데이터'),
  ('DEV', 'GITHUB_BRANCH', 'develop', false, true, '기본 배포/형상관리 브랜치 메타데이터'),
  ('DEV', 'GITHUB_PAT', 'env:GITHUB_PAT', true, false, '비밀 원문 저장 금지. 로컬 .env.local 또는 Edge Function 환경변수에 저장'),
  ('DEV', 'SUPABASE_ACCESS_TOKEN', 'env:SUPABASE_ACCESS_TOKEN', true, false, '비밀 원문 저장 금지. Supabase CLI/Management API 실행 환경변수에 저장'),
  ('DEV', 'SUPABASE_SERVICE_ROLE_KEY', 'env:SUPABASE_SERVICE_ROLE_KEY', true, false, '서버 전용 키. Edge Function/서버 환경변수 또는 Supabase Vault에 저장'),
  ('DEV', 'SUPABASE_DB_CONNECTION_STRING', 'env:SUPABASE_DB_CONNECTION_STRING', true, false, 'DB 관리/마이그레이션 전용. 로컬/CI 비밀 저장소에서만 사용'),
  ('DEV', 'SLACK_WEBHOOK_PART1', 'env:SLACK_WEBHOOK_PART1', true, false, 'Slack 1부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('DEV', 'SLACK_WEBHOOK_PART2', 'env:SLACK_WEBHOOK_PART2', true, false, 'Slack 2부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('DEV', 'SLACK_WEBHOOK_PART3', 'env:SLACK_WEBHOOK_PART3', true, false, 'Slack 3부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('DEV', 'SLACK_WEBHOOK_PART4', 'env:SLACK_WEBHOOK_PART4', true, false, 'Slack 4부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('DEV', 'SLACK_WEBHOOK_PART5', 'env:SLACK_WEBHOOK_PART5', true, false, 'Slack 5부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('DEV', 'SLACK_WEBHOOK_WORSHIP', 'env:SLACK_WEBHOOK_WORSHIP', true, false, 'Slack 예배부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('DEV', 'SLACK_WEBHOOK_PRODUCT_MANAGEMENT', 'env:SLACK_WEBHOOK_PRODUCT_MANAGEMENT', true, false, 'Slack 상품 관리 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('DEV', 'SLACK_WEBHOOK_OPERATIONS', 'env:SLACK_WEBHOOK_OPERATIONS', true, false, 'Slack 운영 로그 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('DEV', 'SLACK_WEBHOOK_ANSWER', 'env:SLACK_WEBHOOK_ANSWER', true, false, 'Slack Q&A 채널 Webhook. Edge Function Secret에 원문 저장')
ON CONFLICT (env, key_name) DO UPDATE
SET key_value = EXCLUDED.key_value,
    is_secret = EXCLUDED.is_secret,
    use_yn = EXCLUDED.use_yn,
    description = EXCLUDED.description,
    updated_at = now();

NOTIFY pgrst, 'reload schema';

COMMIT;
