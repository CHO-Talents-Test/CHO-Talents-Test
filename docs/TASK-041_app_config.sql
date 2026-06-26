-- ============================================================
-- TASK-041: app_config 기반 런타임 설정 관리
-- 목적:
--   1) 공개 설정은 Supabase RPC로 브라우저에 제공
--   2) 비밀 설정은 브라우저에서 직접 조회하지 않도록 차단
--   3) GitHub/Supabase 관리 토큰은 평문 DB 저장 대신 환경변수/Edge Function/Vault 참조만 기록
--
-- Supabase SQL Editor 또는 Management API에서 실행
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.app_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  env text NOT NULL DEFAULT 'PROD',
  key_name text NOT NULL,
  key_value text,
  is_secret boolean NOT NULL DEFAULT false,
  use_yn boolean NOT NULL DEFAULT true,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT app_config_env_key_unique UNIQUE (env, key_name),
  CONSTRAINT app_config_public_value_check CHECK (
    is_secret = true OR key_value IS NOT NULL
  )
);

COMMENT ON TABLE public.app_config IS 'CHO-Talents 런타임 설정 저장소. 공개 값은 RPC로 제공하고 비밀 값은 서버 환경변수/Vault 참조만 기록한다.';
COMMENT ON COLUMN public.app_config.env IS '설정 환경. config/public-config.js TARGET_ENV와 같은 값. 예: PROD, DEV';
COMMENT ON COLUMN public.app_config.key_name IS '설정 키 이름. 예: SUPABASE_URL, KAKAO_MAP_KEY';
COMMENT ON COLUMN public.app_config.key_value IS '공개 설정 값 또는 비밀 값 참조. 비밀 원문은 저장하지 않는다.';
COMMENT ON COLUMN public.app_config.is_secret IS 'true이면 브라우저 공개 RPC에서 제외된다.';
COMMENT ON COLUMN public.app_config.use_yn IS 'false이면 공개 RPC와 운영 로직에서 제외한다.';

CREATE INDEX IF NOT EXISTS idx_app_config_env_use
  ON public.app_config(env, use_yn);

CREATE INDEX IF NOT EXISTS idx_app_config_public
  ON public.app_config(env, key_name)
  WHERE is_secret = false AND use_yn = true;

CREATE OR REPLACE FUNCTION public.set_app_config_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_config_updated_at ON public.app_config;
CREATE TRIGGER trg_app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW
  EXECUTE FUNCTION public.set_app_config_updated_at();

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- 직접 테이블 조회는 기본 차단한다. 공개 값은 아래 SECURITY DEFINER RPC만 사용한다.
DROP POLICY IF EXISTS "app_config_select_public" ON public.app_config;
DROP POLICY IF EXISTS "app_config_no_direct_insert" ON public.app_config;
DROP POLICY IF EXISTS "app_config_no_direct_update" ON public.app_config;
DROP POLICY IF EXISTS "app_config_no_direct_delete" ON public.app_config;

CREATE OR REPLACE FUNCTION public.get_public_app_config(p_env text DEFAULT 'PROD')
RETURNS TABLE (
  key_name text,
  key_value text,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.key_name, c.key_value, c.updated_at
  FROM public.app_config c
  WHERE c.env = p_env
    AND c.use_yn = true
    AND c.is_secret = false
  ORDER BY c.key_name;
$$;

REVOKE ALL ON FUNCTION public.get_public_app_config(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_app_config(text) TO anon, authenticated;

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
  ('DEV', 'SUPABASE_DB_CONNECTION_STRING', 'env:SUPABASE_DB_CONNECTION_STRING', true, false, 'DB 관리/마이그레이션 전용. 로컬/CI 비밀 저장소에서만 사용')
ON CONFLICT (env, key_name) DO UPDATE
SET
  key_value = EXCLUDED.key_value,
  is_secret = EXCLUDED.is_secret,
  use_yn = EXCLUDED.use_yn,
  description = EXCLUDED.description,
  updated_at = now();

NOTIFY pgrst, 'reload schema';

COMMIT;
