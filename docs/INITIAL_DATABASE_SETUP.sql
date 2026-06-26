-- ============================================================
-- CHO-Talents 초기 Database 구성 SQL
-- 대상: 새 Supabase 프로젝트 / 비어 있는 Database
--
-- 실행 위치:
--   Supabase Dashboard > SQL Editor > New query
--
-- 실행 후 기본 로그인:
--   ID: admin_user
--   PW: 1234
--   최초 로그인 후 비밀번호 변경 화면으로 이동됩니다.
--
-- 주의:
--   이 파일은 기존 운영 데이터를 복사하지 않습니다.
--   운영 데이터(사용자, 상품, 주문, QR, 로그)는 새로 시작하는 기준으로 비워둡니다.
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- ============================================================
-- 0. Target Project Runtime Config
-- ============================================================
-- 새 Supabase 프로젝트에 실행하기 전에 파일 하단의
-- "공개 런타임 설정과 비밀 참조값" VALUES 블록을 새 프로젝트 기준으로 수정하세요.
-- 비밀 토큰 원문은 넣지 말고 env:... 참조값만 유지합니다.

-- ============================================================
-- 1. Core Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.departments (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  is_active boolean DEFAULT true,
  class_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  display_name text,
  username text,
  department_id uuid REFERENCES public.departments(id),
  managed_dept_id uuid REFERENCES public.departments(id),
  talent_balance integer DEFAULT 0,
  pending_talent integer DEFAULT 0,
  is_first_login boolean DEFAULT true,
  user_type text NOT NULL DEFAULT 'student' CHECK (user_type IN ('teacher', 'student')),
  permission_level text NOT NULL DEFAULT 'student'
    CHECK (permission_level IN ('admin','evangelist','chief','purchase_teacher','dept_teacher','teacher','student')),
  is_super_admin boolean DEFAULT false,
  class_number integer,
  last_login_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profiles_username_unique UNIQUE (username)
);

CREATE TABLE IF NOT EXISTS public.registration_requests (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  username text NOT NULL,
  display_name text NOT NULL,
  department_id uuid REFERENCES public.departments(id),
  reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_by text,
  review_note text,
  reviewed_at timestamptz,
  user_type text NOT NULL DEFAULT 'student' CHECK (user_type IN ('teacher', 'student')),
  permission_level text NOT NULL DEFAULT 'student'
    CHECK (permission_level IN ('admin','evangelist','chief','purchase_teacher','dept_teacher','teacher','student')),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.department_transfer_requests (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  username text NOT NULL,
  display_name text,
  from_department_id uuid REFERENCES public.departments(id),
  to_department_id uuid NOT NULL REFERENCES public.departments(id),
  requested_by text NOT NULL,
  request_reason text,
  status text DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_by text,
  review_note text,
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.talent_items (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  name text NOT NULL,
  target_type text NOT NULL CHECK (target_type IN ('teacher', 'student')),
  talent_amount integer NOT NULL CHECK (talent_amount > 0),
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_by uuid REFERENCES public.profiles(id),
  is_quick_button boolean DEFAULT false,
  giving_rule text,
  giving_description text,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT talent_items_amount_max100 CHECK (talent_amount <= 100)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_talent_items_target_name
  ON public.talent_items(target_type, name);

CREATE TABLE IF NOT EXISTS public.talent_transactions (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('earn','use')),
  amount integer NOT NULL,
  balance_after integer NOT NULL,
  description text,
  created_by uuid REFERENCES public.profiles(id),
  talent_item_id uuid REFERENCES public.talent_items(id),
  source text DEFAULT 'admin',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  name text NOT NULL,
  description text,
  price integer NOT NULL,
  image_emoji text DEFAULT '',
  image_url text,
  target_role text NOT NULL CHECK (target_role IN ('teacher','student')),
  category text,
  stock integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.product_orders (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id),
  product_id uuid NOT NULL REFERENCES public.products(id),
  product_name text NOT NULL,
  price integer NOT NULL,
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','preparing','purchased','delivered','cancelled')),
  requested_at timestamptz DEFAULT now(),
  prepared_at timestamptz,
  purchased_at timestamptz,
  delivered_at timestamptz,
  prepared_by uuid REFERENCES public.profiles(id),
  purchased_by uuid REFERENCES public.profiles(id),
  delivered_by uuid REFERENCES public.profiles(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.qna (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  question text NOT NULL,
  answer text,
  asked_by uuid REFERENCES auth.users(id),
  asked_by_name text,
  answered_by uuid REFERENCES auth.users(id),
  answered_by_name text,
  is_faq boolean DEFAULT false,
  status text DEFAULT 'pending' CHECK (status IN ('pending','answered','faq')),
  created_at timestamptz DEFAULT now(),
  answered_at timestamptz,
  is_deleted boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.qna_comments (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  qna_id uuid NOT NULL REFERENCES public.qna(id) ON DELETE CASCADE,
  content text NOT NULL,
  commented_by uuid REFERENCES auth.users(id),
  commented_by_name text DEFAULT '관리자',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reports (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  task_id text NOT NULL,
  task_title text NOT NULL,
  report_type text NOT NULL
    CHECK (report_type IN ('plan','test_scenario','test_result','change_report','security_report')),
  content text NOT NULL,
  created_by text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.report_events (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type text NOT NULL
    CHECK (event_type IN ('created','updated','confirmed','reconfirmed','status_changed')),
  event_at timestamptz NOT NULL DEFAULT now(),
  event_note text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.activity_logs (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  level text NOT NULL DEFAULT 'INFO'
    CHECK (level IN ('TRACE','DEBUG','INFO','WARN','ERROR','FATAL','CRITICAL')),
  action text NOT NULL,
  page text,
  details jsonb,
  username text,
  user_name text,
  is_acknowledged boolean DEFAULT false,
  acknowledged_by text,
  acknowledged_at timestamptz,
  resolution_note text,
  is_deleted boolean DEFAULT false,
  deleted_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.page_permissions (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  page_key text NOT NULL,
  permission_level text NOT NULL,
  can_view boolean DEFAULT false,
  can_manage boolean DEFAULT false,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(page_key, permission_level)
);

CREATE TABLE IF NOT EXISTS public.role_page_access (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  role_key text NOT NULL,
  page_id text NOT NULL,
  can_access boolean DEFAULT true,
  hidden_elements text[] DEFAULT '{}'::text[],
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(role_key, page_id)
);

CREATE TABLE IF NOT EXISTS public.role_page_features (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  permission_key text NOT NULL,
  page_id text NOT NULL,
  features jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(permission_key, page_id)
);

CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  favorite_shortcuts jsonb DEFAULT '["earn-talents","shop","my-talents"]'::jsonb,
  theme text DEFAULT 'default' CHECK (theme IN ('default', 'dark', 'spring', 'summer', 'autumn', 'winter')),
  page_sizes jsonb DEFAULT '{}'::jsonb,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.talent_qr_codes (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  talent_item_id uuid REFERENCES public.talent_items(id) ON DELETE CASCADE,
  qr_key text UNIQUE,
  code text NOT NULL UNIQUE,
  description text,
  amount integer NOT NULL DEFAULT 1,
  target_type text DEFAULT 'student',
  max_uses integer,
  used_count integer NOT NULL DEFAULT 0,
  valid_from timestamptz,
  valid_until timestamptz,
  valid_start_time time,
  valid_end_time time,
  expires_at timestamptz,
  location_address text,
  location_name text,
  location_lat double precision,
  location_lng double precision,
  location_radius integer DEFAULT 1000,
  location_radius_km numeric,
  repeat_type text DEFAULT 'none',
  repeat_days integer[] DEFAULT NULL,
  repeat_weeks integer[] DEFAULT NULL,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz DEFAULT now(),
  CONSTRAINT talent_qr_codes_amount_max100 CHECK (amount <= 100)
);

CREATE TABLE IF NOT EXISTS public.talent_qr_scans (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  qr_code_id uuid NOT NULL REFERENCES public.talent_qr_codes(id) ON DELETE CASCADE,
  talent_item_id uuid REFERENCES public.talent_items(id),
  user_id uuid NOT NULL REFERENCES public.profiles(id),
  scan_result text NOT NULL DEFAULT 'success',
  failure_reason text,
  scan_lat double precision,
  scan_lng double precision,
  scanned_at timestamptz NOT NULL DEFAULT now(),
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_config (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  env text NOT NULL DEFAULT 'PROD',
  key_name text NOT NULL,
  key_value text,
  is_secret boolean NOT NULL DEFAULT false,
  use_yn boolean NOT NULL DEFAULT true,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT app_config_env_key_unique UNIQUE (env, key_name),
  CONSTRAINT app_config_public_value_check CHECK (is_secret = true OR key_value IS NOT NULL)
);

-- ============================================================
-- 2. Indexes
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_department ON public.profiles(department_id);
CREATE INDEX IF NOT EXISTS idx_profiles_permission ON public.profiles(permission_level);
CREATE INDEX IF NOT EXISTS idx_registration_status ON public.registration_requests(status, created_at);
CREATE INDEX IF NOT EXISTS idx_department_transfer_requests_status
  ON public.department_transfer_requests(status);
CREATE INDEX IF NOT EXISTS idx_department_transfer_requests_created_at
  ON public.department_transfer_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_department_transfer_requests_user_id
  ON public.department_transfer_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_talent_transactions_user ON public.talent_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_talent_transactions_item ON public.talent_transactions(talent_item_id);
CREATE INDEX IF NOT EXISTS idx_products_active_target ON public.products(is_active, target_role);
CREATE INDEX IF NOT EXISTS idx_product_orders_user_status ON public.product_orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_product_orders_status ON public.product_orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_qna_status ON public.qna(status, is_faq, is_deleted);
CREATE INDEX IF NOT EXISTS idx_qna_comments_qna_id ON public.qna_comments(qna_id);
CREATE INDEX IF NOT EXISTS idx_qna_comments_created_at ON public.qna_comments(created_at);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created ON public.activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_level_ack ON public.activity_logs(level, is_acknowledged);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action_created ON public.activity_logs(action, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_codes_code_unique
  ON public.talent_qr_codes(code)
  WHERE code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_qr_scans_qr_code ON public.talent_qr_scans(qr_code_id);
CREATE INDEX IF NOT EXISTS idx_qr_scans_user ON public.talent_qr_scans(user_id);
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON public.user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_app_config_env_use ON public.app_config(env, use_yn);
CREATE INDEX IF NOT EXISTS idx_app_config_public ON public.app_config(env, key_name)
  WHERE is_secret = false AND use_yn = true;

-- ============================================================
-- 3. Helper Functions
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_permission_rank(p_level text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_level
    WHEN 'admin' THEN 100
    WHEN 'evangelist' THEN 90
    WHEN 'chief' THEN 80
    WHEN 'purchase_teacher' THEN 70
    WHEN 'dept_teacher' THEN 60
    WHEN 'teacher' THEN 40
    WHEN 'student' THEN 20
    ELSE 0
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_permission_rank(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.get_permission_rank(
    COALESCE((SELECT permission_level FROM public.profiles WHERE id = p_user_id), 'student')
  );
$$;

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT permission_level FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_app_config_updated_at ON public.app_config;
CREATE TRIGGER trg_app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 4. RPC Functions
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT json_build_object(
    'id', p.id,
    'username', p.username,
    'display_name', p.display_name,
    'user_type', p.user_type,
    'permission_level', p.permission_level,
    'is_super_admin', COALESCE(p.is_super_admin, false),
    'is_first_login', p.is_first_login,
    'department_id', p.department_id,
    'managed_dept_id', p.managed_dept_id,
    'talent_balance', COALESCE(p.talent_balance, 0),
    'department_name', d.name,
    'class_number', p.class_number
  )
  FROM public.profiles p
  LEFT JOIN public.departments d ON d.id = p.department_id
  WHERE p.id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.change_my_password(p_new_password text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
  IF length(p_new_password) < 4 THEN
    RETURN json_build_object('success', false, 'error', 'Password too short');
  END IF;

  UPDATE auth.users
  SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
      updated_at = now()
  WHERE id = auth.uid();

  UPDATE public.profiles
  SET is_first_login = false, updated_at = now()
  WHERE id = auth.uid();

  RETURN json_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_last_login()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET last_login_at = now(),
      updated_at = now()
  WHERE id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.check_username_available(p_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles WHERE username = p_username) THEN
    RETURN false;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.registration_requests
    WHERE username = p_username AND status = 'pending'
  ) THEN
    RETURN false;
  END IF;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_registration_status(p_username text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT status INTO v_status
  FROM public.registration_requests
  WHERE username = p_username
  ORDER BY created_at DESC
  LIMIT 1;

  RETURN COALESCE(v_status, 'not_found');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_users(
  p_user_type text DEFAULT NULL,
  p_department_id uuid DEFAULT NULL
)
RETURNS SETOF public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_perm text;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM public.profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL OR public.get_permission_rank(v_caller_perm) < 40 THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
    SELECT *
    FROM public.profiles
    WHERE (p_user_type IS NULL OR user_type = p_user_type)
      AND (p_department_id IS NULL OR department_id = p_department_id)
    ORDER BY created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_user(
  p_username text,
  p_password text,
  p_display_name text,
  p_department_id uuid DEFAULT NULL,
  p_managed_dept_id uuid DEFAULT NULL,
  p_user_type text DEFAULT 'student',
  p_permission_level text DEFAULT 'student',
  p_class_number integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_caller_perm text;
  v_caller_rank integer;
  v_new_rank integer;
  v_new_id uuid;
  v_email text;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM public.profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_caller_rank := public.get_permission_rank(v_caller_perm);
  IF v_caller_rank < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_new_rank := public.get_permission_rank(p_permission_level);
  IF v_new_rank > v_caller_rank THEN
    RETURN json_build_object('success', false, 'error', 'Cannot create user with higher permission');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE username = p_username) THEN
    RETURN json_build_object('success', false, 'error', 'Username already exists');
  END IF;

  v_new_id := extensions.gen_random_uuid();
  v_email := p_username || '@cho-talents.app';

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, email_change, email_change_token_new, recovery_token,
    is_sso_user, is_anonymous
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_new_id, 'authenticated', 'authenticated',
    v_email, extensions.crypt(p_password, extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('username', p_username, 'display_name', p_display_name),
    '', '', '', '', false, false
  );

  INSERT INTO auth.identities (
    id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_new_id, v_new_id::text, v_new_id,
    jsonb_build_object('sub', v_new_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now()
  );

  INSERT INTO public.profiles (
    id, username, email, display_name, user_type, permission_level,
    department_id, managed_dept_id, class_number, talent_balance, pending_talent,
    is_first_login, created_at, updated_at
  ) VALUES (
    v_new_id, p_username, v_email, p_display_name, p_user_type, p_permission_level,
    p_department_id, p_managed_dept_id, p_class_number, 0, 0,
    true, now(), now()
  );

  RETURN json_build_object('success', true, 'user_id', v_new_id, 'username', p_username);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_user(
  p_user_id uuid,
  p_display_name text DEFAULT NULL,
  p_department_id uuid DEFAULT NULL,
  p_managed_dept_id uuid DEFAULT NULL,
  p_user_type text DEFAULT NULL,
  p_permission_level text DEFAULT NULL,
  p_class_number integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_perm text;
  v_caller_rank integer;
  v_target_perm text;
  v_target_rank integer;
  v_target_super boolean;
  v_new_rank integer;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM public.profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_caller_rank := public.get_permission_rank(v_caller_perm);
  IF v_caller_rank < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT permission_level, COALESCE(is_super_admin, false)
  INTO v_target_perm, v_target_super
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_target_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;
  IF v_target_super AND auth.uid() != p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Super admin can only be modified by themselves');
  END IF;

  v_target_rank := public.get_permission_rank(v_target_perm);
  IF v_target_rank > v_caller_rank AND auth.uid() != p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot modify user with higher permission');
  END IF;

  IF p_permission_level IS NOT NULL THEN
    v_new_rank := public.get_permission_rank(p_permission_level);
    IF v_new_rank > v_caller_rank THEN
      RETURN json_build_object('success', false, 'error', 'Cannot assign permission higher than your own');
    END IF;
  END IF;

  UPDATE public.profiles
  SET display_name = COALESCE(p_display_name, display_name),
      user_type = COALESCE(p_user_type, user_type),
      permission_level = COALESCE(p_permission_level, permission_level),
      department_id = COALESCE(p_department_id, department_id),
      managed_dept_id = p_managed_dept_id,
      class_number = p_class_number,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN json_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_user(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller_perm text;
  v_caller_rank integer;
  v_target_perm text;
  v_target_rank integer;
  v_target_super boolean;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM public.profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL OR public.get_permission_rank(v_caller_perm) < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_caller_rank := public.get_permission_rank(v_caller_perm);
  IF p_user_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete yourself');
  END IF;

  SELECT permission_level, COALESCE(is_super_admin, false)
  INTO v_target_perm, v_target_super
  FROM public.profiles WHERE id = p_user_id;

  IF v_target_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;
  IF v_target_super THEN
    RETURN json_build_object('success', false, 'error', 'Super admin cannot be deleted');
  END IF;

  v_target_rank := public.get_permission_rank(v_target_perm);
  IF v_target_rank > v_caller_rank THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete user with higher permission');
  END IF;

  DELETE FROM public.profiles WHERE id = p_user_id;
  DELETE FROM auth.identities WHERE user_id = p_user_id;
  DELETE FROM auth.users WHERE id = p_user_id;

  RETURN json_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reset_password(p_user_id uuid, p_new_password text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_caller_perm text;
  v_caller_rank integer;
  v_target_perm text;
  v_target_rank integer;
  v_target_super boolean;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM public.profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL OR public.get_permission_rank(v_caller_perm) < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  v_caller_rank := public.get_permission_rank(v_caller_perm);
  SELECT permission_level, COALESCE(is_super_admin, false)
  INTO v_target_perm, v_target_super
  FROM public.profiles WHERE id = p_user_id;

  IF v_target_perm IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;
  IF v_target_super AND auth.uid() != p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Super admin password can only be changed by themselves');
  END IF;

  v_target_rank := public.get_permission_rank(v_target_perm);
  IF v_target_rank >= v_caller_rank AND auth.uid() != p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot reset password of user with equal or higher permission');
  END IF;

  UPDATE auth.users
  SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
      updated_at = now()
  WHERE id = p_user_id;

  UPDATE public.profiles
  SET is_first_login = true, updated_at = now()
  WHERE id = p_user_id;

  RETURN json_build_object('success', true);
END;
$$;

DROP FUNCTION IF EXISTS public.give_talent(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.give_talent(uuid, integer, text, uuid);

CREATE OR REPLACE FUNCTION public.give_talent(
  p_user_id uuid,
  p_amount integer DEFAULT 0,
  p_description text DEFAULT '',
  p_created_by uuid DEFAULT NULL,
  p_talent_item_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance integer;
  v_txn_id uuid;
  v_caller_perm text;
  v_caller_rank integer;
  v_caller_dept uuid;
  v_caller_class integer;
  v_caller_managed_dept uuid;
  v_target_type text;
  v_target_dept uuid;
  v_target_class integer;
  v_item record;
  v_actual_amount integer;
  v_actual_desc text;
  v_week_count integer;
BEGIN
  SELECT permission_level, department_id, class_number, managed_dept_id
  INTO v_caller_perm, v_caller_dept, v_caller_class, v_caller_managed_dept
  FROM public.profiles
  WHERE id = auth.uid();

  v_caller_rank := public.get_permission_rank(v_caller_perm);
  IF v_caller_perm IS NULL OR v_caller_rank < 40 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT user_type, department_id, class_number
  INTO v_target_type, v_target_dept, v_target_class
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_target_type IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_caller_rank = 40 THEN
    IF v_caller_dept IS NULL
       OR v_caller_dept != v_target_dept
       OR v_caller_class IS DISTINCT FROM v_target_class THEN
      RETURN json_build_object('success', false, 'error', 'You can only give talents to students in your class');
    END IF;
  ELSIF v_caller_rank >= 60 AND v_caller_rank < 90 THEN
    IF v_caller_managed_dept IS NULL OR v_caller_managed_dept != v_target_dept THEN
      RETURN json_build_object('success', false, 'error', 'You can only give talents to users in your managed department');
    END IF;
  END IF;

  IF p_talent_item_id IS NOT NULL THEN
    SELECT * INTO v_item
    FROM public.talent_items
    WHERE id = p_talent_item_id AND is_active = true;

    IF v_item IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Invalid or inactive talent item');
    END IF;

    IF v_item.target_type IS NOT NULL AND v_item.target_type <> v_target_type THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Item target type mismatch: ' || v_item.target_type || ' vs ' || v_target_type
      );
    END IF;

    v_actual_amount := v_item.talent_amount;
    v_actual_desc := v_item.name;

    SELECT count(*) INTO v_week_count
    FROM public.talent_transactions
    WHERE user_id = p_user_id
      AND talent_item_id = p_talent_item_id
      AND type = 'earn'
      AND created_at >= date_trunc('week', now() AT TIME ZONE 'Asia/Seoul')
      AND created_at < date_trunc('week', now() AT TIME ZONE 'Asia/Seoul') + interval '7 days';

    IF v_week_count > 0 THEN
      RETURN json_build_object('success', false, 'error', 'Already given this item this week: ' || v_item.name);
    END IF;
  ELSE
    IF p_amount <= 0 THEN
      RETURN json_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    v_actual_amount := p_amount;
    v_actual_desc := COALESCE(NULLIF(p_description, ''), 'Manual');
  END IF;

  IF v_actual_amount > 100 THEN
    RETURN json_build_object('success', false, 'error', 'Amount cannot exceed 100');
  END IF;

  UPDATE public.profiles
  SET talent_balance = COALESCE(talent_balance, 0) + v_actual_amount
  WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

  INSERT INTO public.talent_transactions (
    user_id, type, amount, balance_after, description, created_by, talent_item_id
  ) VALUES (
    p_user_id, 'earn', v_actual_amount, v_new_balance, v_actual_desc,
    COALESCE(p_created_by, auth.uid()), p_talent_item_id
  )
  RETURNING id INTO v_txn_id;

  RETURN json_build_object('success', true, 'balance', v_new_balance, 'txn_id', v_txn_id, 'amount', v_actual_amount);
END;
$$;

CREATE OR REPLACE FUNCTION public.use_talent(
  p_user_id uuid,
  p_amount integer,
  p_description text,
  p_created_by uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current integer;
  v_new_balance integer;
  v_txn_id uuid;
  v_caller_perm text;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM public.profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL OR public.get_permission_rank(v_caller_perm) < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT COALESCE(talent_balance, 0) INTO v_current
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;
  IF v_current < p_amount THEN
    RETURN json_build_object('success', false, 'error', 'Insufficient balance', 'balance', v_current);
  END IF;

  v_new_balance := v_current - p_amount;

  UPDATE public.profiles
  SET talent_balance = v_new_balance
  WHERE id = p_user_id;

  INSERT INTO public.talent_transactions (user_id, type, amount, balance_after, description, created_by)
  VALUES (p_user_id, 'use', p_amount, v_new_balance, p_description, p_created_by)
  RETURNING id INTO v_txn_id;

  RETURN json_build_object('success', true, 'balance', v_new_balance, 'txn_id', v_txn_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.request_product_order(
  p_user_id uuid,
  p_product_id uuid,
  p_product_name text,
  p_price integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance integer;
  v_pending integer;
  v_order_id uuid;
  v_caller_rank integer;
BEGIN
  v_caller_rank := public.get_permission_rank(auth.uid());
  IF p_user_id <> auth.uid() AND v_caller_rank < 40 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized proxy order');
  END IF;

  SELECT talent_balance, COALESCE(pending_talent, 0)
  INTO v_balance, v_pending
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF (v_balance - v_pending) < p_price THEN
    RETURN json_build_object('success', false, 'error', '사용 가능한 달란트가 부족합니다.');
  END IF;

  INSERT INTO public.product_orders (user_id, product_id, product_name, price, status, requested_at)
  VALUES (p_user_id, p_product_id, p_product_name, p_price, 'requested', now())
  RETURNING id INTO v_order_id;

  UPDATE public.profiles
  SET pending_talent = COALESCE(pending_talent, 0) + p_price
  WHERE id = p_user_id;

  RETURN json_build_object('success', true, 'order_id', v_order_id, 'pending_talent', v_pending + p_price);
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_product_order(
  p_order_id uuid,
  p_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_current_pending integer;
BEGIN
  SELECT * INTO v_order
  FROM public.product_orders
  WHERE id = p_order_id
    AND user_id = p_user_id
    AND status = 'requested'
  FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'No cancellable order found');
  END IF;

  UPDATE public.product_orders
  SET status = 'cancelled'
  WHERE id = p_order_id;

  SELECT COALESCE(pending_talent, 0) INTO v_current_pending
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  UPDATE public.profiles
  SET pending_talent = GREATEST(0, v_current_pending - v_order.price)
  WHERE id = p_user_id;

  RETURN json_build_object('success', true, 'refunded', v_order.price);
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_product_purchase(
  p_order_id uuid,
  p_admin_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.product_orders%ROWTYPE;
  v_result json;
BEGIN
  IF public.get_permission_rank(auth.uid()) < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_order
  FROM public.product_orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN json_build_object('success', false, 'error', '주문을 찾을 수 없습니다.');
  END IF;
  IF v_order.status != 'preparing' THEN
    RETURN json_build_object('success', false, 'error', '상품 준비 상태의 주문만 구매 확정할 수 있습니다.');
  END IF;

  SELECT public.use_talent(v_order.user_id, v_order.price, '상품 구매: ' || v_order.product_name, p_admin_id)
  INTO v_result;

  IF (v_result->>'success')::boolean = false THEN
    RETURN v_result;
  END IF;

  UPDATE public.product_orders
  SET status = 'purchased', purchased_at = now(), purchased_by = p_admin_id
  WHERE id = p_order_id;

  UPDATE public.profiles
  SET pending_talent = GREATEST(COALESCE(pending_talent, 0) - v_order.price, 0)
  WHERE id = v_order.user_id;

  RETURN json_build_object('success', true, 'balance', (v_result->>'balance')::integer);
END;
$$;

CREATE OR REPLACE FUNCTION public.scan_qr_talent(
  p_qr_code_id uuid,
  p_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qr record;
  v_new_balance integer;
  v_txn_id uuid;
  v_scan_id uuid;
  v_existing_scan uuid;
  v_existing_txn uuid;
BEGIN
  SELECT * INTO v_qr
  FROM public.talent_qr_codes
  WHERE id = p_qr_code_id
    AND is_active = true;

  IF v_qr IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid QR code');
  END IF;

  SELECT id INTO v_existing_scan
  FROM public.talent_qr_scans
  WHERE qr_code_id = p_qr_code_id
    AND user_id = p_user_id
  LIMIT 1;

  IF v_existing_scan IS NOT NULL THEN
    SELECT id INTO v_existing_txn
    FROM public.talent_transactions
    WHERE user_id = p_user_id
      AND type = 'earn'
      AND (
        (talent_item_id = v_qr.talent_item_id AND v_qr.talent_item_id IS NOT NULL)
        OR (
          created_at BETWEEN
            (SELECT scanned_at FROM public.talent_qr_scans WHERE id = v_existing_scan) - interval '2 minutes'
            AND
            (SELECT scanned_at FROM public.talent_qr_scans WHERE id = v_existing_scan) + interval '2 minutes'
        )
      )
    LIMIT 1;

    IF v_existing_txn IS NOT NULL THEN
      RETURN json_build_object('success', false, 'error', 'Already received');
    END IF;

    UPDATE public.talent_qr_scans
    SET scanned_at = now()
    WHERE id = v_existing_scan;

    v_scan_id := v_existing_scan;
  ELSE
    INSERT INTO public.talent_qr_scans (qr_code_id, user_id, scanned_at)
    VALUES (p_qr_code_id, p_user_id, now())
    RETURNING id INTO v_scan_id;

    UPDATE public.talent_qr_codes
    SET used_count = COALESCE(used_count, 0) + 1
    WHERE id = p_qr_code_id;
  END IF;

  UPDATE public.profiles
  SET talent_balance = COALESCE(talent_balance, 0) + v_qr.amount
  WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

  INSERT INTO public.talent_transactions (
    user_id, type, amount, balance_after, description,
    created_by, talent_item_id, source
  ) VALUES (
    p_user_id, 'earn', v_qr.amount, v_new_balance,
    COALESCE(v_qr.description, 'QR 달란트'),
    p_user_id, v_qr.talent_item_id, 'qr'
  )
  RETURNING id INTO v_txn_id;

  RETURN json_build_object(
    'success', true,
    'balance', v_new_balance,
    'amount', v_qr.amount,
    'txn_id', v_txn_id,
    'scan_id', v_scan_id
  );
END;
$$;

-- TASK-058: QR validity date range and daily time-window enforcement.
CREATE OR REPLACE FUNCTION public.scan_qr_talent(
  p_qr_code_id uuid,
  p_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qr record;
  v_new_balance integer;
  v_txn_id uuid;
  v_scan_id uuid;
  v_existing_scan uuid;
  v_existing_txn uuid;
  v_now_kst timestamp;
  v_time_kst time;
  v_day_kst integer;
  v_week_kst integer;
  v_today_start_utc timestamptz;
  v_tomorrow_start_utc timestamptz;
BEGIN
  v_now_kst := timezone('Asia/Seoul', now());
  v_time_kst := v_now_kst::time;
  v_day_kst := extract(dow from v_now_kst)::integer;
  v_week_kst := ceil((
    extract(day from v_now_kst)::numeric
    + extract(dow from date_trunc('month', v_now_kst)::date)::numeric
  ) / 7)::integer;
  v_today_start_utc := date_trunc('day', v_now_kst) AT TIME ZONE 'Asia/Seoul';
  v_tomorrow_start_utc := (date_trunc('day', v_now_kst) + interval '1 day') AT TIME ZONE 'Asia/Seoul';

  SELECT * INTO v_qr
  FROM public.talent_qr_codes
  WHERE id = p_qr_code_id
    AND is_active = true;

  IF v_qr IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid QR code');
  END IF;

  IF v_qr.valid_from IS NOT NULL AND now() < v_qr.valid_from THEN
    RETURN json_build_object('success', false, 'error', 'Not yet valid');
  END IF;

  IF v_qr.valid_until IS NOT NULL AND now() > v_qr.valid_until THEN
    RETURN json_build_object('success', false, 'error', 'Expired QR code');
  END IF;

  IF v_qr.expires_at IS NOT NULL AND now() > v_qr.expires_at THEN
    RETURN json_build_object('success', false, 'error', 'Expired QR code');
  END IF;

  IF v_qr.valid_start_time IS NOT NULL AND v_time_kst < v_qr.valid_start_time THEN
    RETURN json_build_object('success', false, 'error', 'Invalid time window');
  END IF;

  IF v_qr.valid_end_time IS NOT NULL AND v_time_kst > v_qr.valid_end_time THEN
    RETURN json_build_object('success', false, 'error', 'Invalid time window');
  END IF;

  IF COALESCE(v_qr.repeat_type, 'none') = 'weekday' THEN
    IF v_qr.repeat_days IS NULL OR NOT (v_day_kst = ANY(v_qr.repeat_days)) THEN
      RETURN json_build_object('success', false, 'error', 'Invalid weekday');
    END IF;
  END IF;

  IF COALESCE(v_qr.repeat_type, 'none') = 'week_weekday' THEN
    IF v_qr.repeat_weeks IS NULL OR NOT (v_week_kst = ANY(v_qr.repeat_weeks)) THEN
      RETURN json_build_object('success', false, 'error', 'Invalid week of month');
    END IF;

    IF v_qr.repeat_days IS NULL OR NOT (v_day_kst = ANY(v_qr.repeat_days)) THEN
      RETURN json_build_object('success', false, 'error', 'Invalid weekday');
    END IF;
  END IF;

  IF COALESCE(v_qr.max_uses, 0) > 0 AND COALESCE(v_qr.used_count, 0) >= v_qr.max_uses THEN
    RETURN json_build_object('success', false, 'error', 'Max uses exceeded');
  END IF;

  IF COALESCE(v_qr.repeat_type, 'none') = 'none' THEN
    SELECT id INTO v_existing_scan
    FROM public.talent_qr_scans
    WHERE qr_code_id = p_qr_code_id
      AND user_id = p_user_id
    ORDER BY scanned_at DESC
    LIMIT 1;
  ELSE
    SELECT id INTO v_existing_scan
    FROM public.talent_qr_scans
    WHERE qr_code_id = p_qr_code_id
      AND user_id = p_user_id
      AND scanned_at >= v_today_start_utc
      AND scanned_at < v_tomorrow_start_utc
    ORDER BY scanned_at DESC
    LIMIT 1;
  END IF;

  IF v_existing_scan IS NOT NULL THEN
    SELECT id INTO v_existing_txn
    FROM public.talent_transactions
    WHERE user_id = p_user_id
      AND type = 'earn'
      AND created_at BETWEEN
        (SELECT scanned_at FROM public.talent_qr_scans WHERE id = v_existing_scan) - interval '2 minutes'
        AND
        (SELECT scanned_at FROM public.talent_qr_scans WHERE id = v_existing_scan) + interval '2 minutes'
      AND (
        source = 'qr'
        OR v_qr.talent_item_id IS NULL
        OR talent_item_id = v_qr.talent_item_id
      )
    LIMIT 1;

    IF v_existing_txn IS NOT NULL THEN
      RETURN json_build_object('success', false, 'error', 'Already received');
    END IF;

    UPDATE public.talent_qr_scans
    SET scanned_at = now()
    WHERE id = v_existing_scan;

    v_scan_id := v_existing_scan;
  ELSE
    INSERT INTO public.talent_qr_scans (qr_code_id, user_id, scanned_at)
    VALUES (p_qr_code_id, p_user_id, now())
    RETURNING id INTO v_scan_id;

    UPDATE public.talent_qr_codes
    SET used_count = COALESCE(used_count, 0) + 1
    WHERE id = p_qr_code_id;
  END IF;

  UPDATE public.profiles
  SET talent_balance = COALESCE(talent_balance, 0) + v_qr.amount
  WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

  INSERT INTO public.talent_transactions (
    user_id, type, amount, balance_after, description,
    created_by, talent_item_id, source
  ) VALUES (
    p_user_id, 'earn', v_qr.amount, v_new_balance,
    COALESCE(v_qr.description, 'QR 달란트'),
    p_user_id, v_qr.talent_item_id, 'qr'
  )
  RETURNING id INTO v_txn_id;

  RETURN json_build_object(
    'success', true,
    'balance', v_new_balance,
    'amount', v_qr.amount,
    'txn_id', v_txn_id,
    'scan_id', v_scan_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_anonymous_question(p_question text, p_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_question IS NULL OR length(trim(p_question)) = 0 THEN
    RAISE EXCEPTION 'question is required';
  END IF;

  INSERT INTO public.qna (question, asked_by_name, status)
  VALUES (trim(p_question), COALESCE(NULLIF(trim(p_name), ''), '익명'), 'pending')
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_soft_delete_qna(p_qna_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.get_permission_rank(auth.uid()) < 90 THEN
    RETURN jsonb_build_object('success', false, 'error', '삭제 권한이 없습니다. 전도사님 이상 권한이 필요합니다.');
  END IF;

  UPDATE public.qna SET is_deleted = true WHERE id = p_qna_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

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

-- ============================================================
-- 5. RLS Policies
-- ============================================================

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registration_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.department_transfer_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.talent_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.talent_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qna ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qna_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.page_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_page_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_page_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.talent_qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.talent_qr_scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- departments
DROP POLICY IF EXISTS dept_select_public ON public.departments;
CREATE POLICY dept_select_public ON public.departments FOR SELECT USING (true);
DROP POLICY IF EXISTS dept_insert_perm ON public.departments;
CREATE POLICY dept_insert_perm ON public.departments FOR INSERT WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 80);
DROP POLICY IF EXISTS dept_update_perm ON public.departments;
CREATE POLICY dept_update_perm ON public.departments FOR UPDATE USING (public.get_permission_rank(public.get_my_role()) >= 80);
DROP POLICY IF EXISTS dept_delete_perm ON public.departments;
CREATE POLICY dept_delete_perm ON public.departments FOR DELETE USING (public.get_permission_rank(public.get_my_role()) >= 90);

-- profiles
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
CREATE POLICY profiles_select_own ON public.profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS profiles_select_perm ON public.profiles;
CREATE POLICY profiles_select_perm ON public.profiles FOR SELECT USING (public.get_permission_rank(public.get_my_role()) >= 60);
DROP POLICY IF EXISTS profiles_insert_system ON public.profiles;
CREATE POLICY profiles_insert_system ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS profiles_update_perm ON public.profiles;
CREATE POLICY profiles_update_perm ON public.profiles FOR UPDATE USING (public.get_permission_rank(public.get_my_role()) >= 60);
DROP POLICY IF EXISTS profiles_delete_perm ON public.profiles;
CREATE POLICY profiles_delete_perm ON public.profiles FOR DELETE USING (public.get_permission_rank(public.get_my_role()) >= 60);

-- registration_requests
DROP POLICY IF EXISTS rr_insert_public ON public.registration_requests;
CREATE POLICY rr_insert_public ON public.registration_requests FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS rr_select_perm ON public.registration_requests;
CREATE POLICY rr_select_perm ON public.registration_requests FOR SELECT USING (public.get_permission_rank(public.get_my_role()) >= 60);
DROP POLICY IF EXISTS rr_update_perm ON public.registration_requests;
CREATE POLICY rr_update_perm ON public.registration_requests FOR UPDATE USING (public.get_permission_rank(public.get_my_role()) >= 60);
DROP POLICY IF EXISTS rr_delete_perm ON public.registration_requests;
CREATE POLICY rr_delete_perm ON public.registration_requests FOR DELETE USING (public.get_permission_rank(public.get_my_role()) >= 80);

-- department_transfer_requests
DROP POLICY IF EXISTS dept_transfer_select ON public.department_transfer_requests;
CREATE POLICY dept_transfer_select ON public.department_transfer_requests FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS dept_transfer_insert ON public.department_transfer_requests;
CREATE POLICY dept_transfer_insert ON public.department_transfer_requests FOR INSERT TO authenticated
  WITH CHECK (public.get_permission_rank(auth.uid()) >= 60);
DROP POLICY IF EXISTS dept_transfer_update ON public.department_transfer_requests;
CREATE POLICY dept_transfer_update ON public.department_transfer_requests FOR UPDATE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 60);
DROP POLICY IF EXISTS dept_transfer_delete ON public.department_transfer_requests;
CREATE POLICY dept_transfer_delete ON public.department_transfer_requests FOR DELETE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 90);

-- talent_items / transactions
DROP POLICY IF EXISTS talent_items_select ON public.talent_items;
CREATE POLICY talent_items_select ON public.talent_items FOR SELECT USING (true);
DROP POLICY IF EXISTS talent_items_insert ON public.talent_items;
CREATE POLICY talent_items_insert ON public.talent_items FOR INSERT WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 90);
DROP POLICY IF EXISTS talent_items_update ON public.talent_items;
CREATE POLICY talent_items_update ON public.talent_items FOR UPDATE USING (public.get_permission_rank(public.get_my_role()) >= 90);
DROP POLICY IF EXISTS talent_items_delete ON public.talent_items;
CREATE POLICY talent_items_delete ON public.talent_items FOR DELETE USING (public.get_permission_rank(public.get_my_role()) >= 100);

DROP POLICY IF EXISTS tt_select_perm ON public.talent_transactions;
CREATE POLICY tt_select_perm ON public.talent_transactions FOR SELECT
  USING (auth.uid() = user_id OR public.get_permission_rank(public.get_my_role()) >= 60);
DROP POLICY IF EXISTS tt_insert_system ON public.talent_transactions;
CREATE POLICY tt_insert_system ON public.talent_transactions FOR INSERT WITH CHECK (true);

-- products / orders
DROP POLICY IF EXISTS products_select_public ON public.products;
CREATE POLICY products_select_public ON public.products FOR SELECT USING (true);
DROP POLICY IF EXISTS products_insert_perm ON public.products;
CREATE POLICY products_insert_perm ON public.products FOR INSERT WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 60);
DROP POLICY IF EXISTS products_update_perm ON public.products;
CREATE POLICY products_update_perm ON public.products FOR UPDATE USING (public.get_permission_rank(public.get_my_role()) >= 60);
DROP POLICY IF EXISTS products_delete_perm ON public.products;
CREATE POLICY products_delete_perm ON public.products FOR DELETE USING (public.get_permission_rank(public.get_my_role()) >= 90);

DROP POLICY IF EXISTS "Users can view own orders" ON public.product_orders;
CREATE POLICY "Users can view own orders" ON public.product_orders FOR SELECT TO authenticated USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Staff can view all orders" ON public.product_orders;
CREATE POLICY "Staff can view all orders" ON public.product_orders FOR SELECT TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 60);
DROP POLICY IF EXISTS "Users can create orders" ON public.product_orders;
CREATE POLICY "Users can create orders" ON public.product_orders FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Staff can update orders" ON public.product_orders;
CREATE POLICY "Staff can update orders" ON public.product_orders FOR UPDATE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 60);
DROP POLICY IF EXISTS "Users can cancel own requested orders" ON public.product_orders;
CREATE POLICY "Users can cancel own requested orders" ON public.product_orders FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND status = 'requested')
  WITH CHECK (user_id = auth.uid() AND status = 'cancelled');

-- Q&A
DROP POLICY IF EXISTS qna_select_all ON public.qna;
CREATE POLICY qna_select_all ON public.qna FOR SELECT TO authenticated
  USING (((is_faq = true) OR (asked_by = auth.uid()) OR (public.get_permission_rank(auth.uid()) >= 60)) AND is_deleted = false);
DROP POLICY IF EXISTS qna_select_anon ON public.qna;
CREATE POLICY qna_select_anon ON public.qna FOR SELECT TO anon
  USING (is_faq = true AND is_deleted = false);
DROP POLICY IF EXISTS qna_insert ON public.qna;
CREATE POLICY qna_insert ON public.qna FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS qna_update ON public.qna;
CREATE POLICY qna_update ON public.qna FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS qna_delete ON public.qna;
CREATE POLICY qna_delete ON public.qna FOR DELETE TO authenticated USING (public.get_permission_rank(auth.uid()) >= 100);

DROP POLICY IF EXISTS qna_comments_select ON public.qna_comments;
CREATE POLICY qna_comments_select ON public.qna_comments FOR SELECT USING (true);
DROP POLICY IF EXISTS qna_comments_insert ON public.qna_comments;
CREATE POLICY qna_comments_insert ON public.qna_comments FOR INSERT TO authenticated
  WITH CHECK (public.get_permission_rank(auth.uid()) >= 60);
DROP POLICY IF EXISTS qna_comments_update ON public.qna_comments;
CREATE POLICY qna_comments_update ON public.qna_comments FOR UPDATE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 60);
DROP POLICY IF EXISTS qna_comments_delete ON public.qna_comments;
CREATE POLICY qna_comments_delete ON public.qna_comments FOR DELETE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 90);

-- reports
DROP POLICY IF EXISTS reports_select_perm ON public.reports;
CREATE POLICY reports_select_perm ON public.reports FOR SELECT USING (public.get_permission_rank(public.get_my_role()) >= 80);
DROP POLICY IF EXISTS reports_insert ON public.reports;
CREATE POLICY reports_insert ON public.reports FOR INSERT WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 80);
DROP POLICY IF EXISTS reports_update ON public.reports;
CREATE POLICY reports_update ON public.reports FOR UPDATE USING (public.get_permission_rank(public.get_my_role()) >= 80);
DROP POLICY IF EXISTS reports_delete ON public.reports;
CREATE POLICY reports_delete ON public.reports FOR DELETE USING (public.get_permission_rank(public.get_my_role()) >= 80);

DROP POLICY IF EXISTS report_events_select_perm ON public.report_events;
CREATE POLICY report_events_select_perm ON public.report_events FOR SELECT
  USING (auth.uid() = user_id OR public.get_permission_rank(public.get_my_role()) >= 80);
DROP POLICY IF EXISTS report_events_insert_perm ON public.report_events;
CREATE POLICY report_events_insert_perm ON public.report_events FOR INSERT
  WITH CHECK (auth.uid() = user_id OR public.get_permission_rank(public.get_my_role()) >= 80);

-- logs
GRANT INSERT ON public.activity_logs TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.activity_logs TO authenticated;
DROP POLICY IF EXISTS logs_insert_public ON public.activity_logs;
CREATE POLICY logs_insert_public ON public.activity_logs FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS logs_select_perm ON public.activity_logs;
CREATE POLICY logs_select_perm ON public.activity_logs FOR SELECT TO authenticated USING (public.get_permission_rank(public.get_my_role()) >= 100);
DROP POLICY IF EXISTS logs_update_perm ON public.activity_logs;
CREATE POLICY logs_update_perm ON public.activity_logs FOR UPDATE TO authenticated USING (public.get_permission_rank(public.get_my_role()) >= 100) WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 100);
DROP POLICY IF EXISTS activity_logs_delete ON public.activity_logs;
CREATE POLICY activity_logs_delete ON public.activity_logs FOR DELETE TO authenticated USING (public.get_permission_rank(public.get_my_role()) >= 100);

-- page permission management
DROP POLICY IF EXISTS pp_select ON public.page_permissions;
CREATE POLICY pp_select ON public.page_permissions FOR SELECT USING (true);
DROP POLICY IF EXISTS pp_manage ON public.page_permissions;
CREATE POLICY pp_manage ON public.page_permissions FOR ALL USING (public.get_permission_rank(public.get_my_role()) >= 100);

DROP POLICY IF EXISTS role_page_access_select ON public.role_page_access;
CREATE POLICY role_page_access_select ON public.role_page_access FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS role_page_access_insert ON public.role_page_access;
CREATE POLICY role_page_access_insert ON public.role_page_access FOR INSERT
  WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 90);
DROP POLICY IF EXISTS role_page_access_update ON public.role_page_access;
CREATE POLICY role_page_access_update ON public.role_page_access FOR UPDATE
  USING (public.get_permission_rank(public.get_my_role()) >= 90);
DROP POLICY IF EXISTS role_page_access_delete ON public.role_page_access;
CREATE POLICY role_page_access_delete ON public.role_page_access FOR DELETE
  USING (public.get_permission_rank(public.get_my_role()) >= 90);

DROP POLICY IF EXISTS role_page_features_select ON public.role_page_features;
CREATE POLICY role_page_features_select ON public.role_page_features FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS role_page_features_insert ON public.role_page_features;
CREATE POLICY role_page_features_insert ON public.role_page_features FOR INSERT
  WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 90);
DROP POLICY IF EXISTS role_page_features_update ON public.role_page_features;
CREATE POLICY role_page_features_update ON public.role_page_features FOR UPDATE
  USING (public.get_permission_rank(public.get_my_role()) >= 90);
DROP POLICY IF EXISTS role_page_features_delete ON public.role_page_features;
CREATE POLICY role_page_features_delete ON public.role_page_features FOR DELETE
  USING (public.get_permission_rank(public.get_my_role()) >= 90);

-- user preferences
DROP POLICY IF EXISTS user_preferences_select_own ON public.user_preferences;
CREATE POLICY user_preferences_select_own ON public.user_preferences FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_preferences_insert_own ON public.user_preferences;
CREATE POLICY user_preferences_insert_own ON public.user_preferences FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_preferences_update_own ON public.user_preferences;
CREATE POLICY user_preferences_update_own ON public.user_preferences FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_preferences_delete_own ON public.user_preferences;
CREATE POLICY user_preferences_delete_own ON public.user_preferences FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- QR
DROP POLICY IF EXISTS qr_codes_select ON public.talent_qr_codes;
CREATE POLICY qr_codes_select ON public.talent_qr_codes FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS qr_codes_insert ON public.talent_qr_codes;
CREATE POLICY qr_codes_insert ON public.talent_qr_codes FOR INSERT TO authenticated
  WITH CHECK (public.get_permission_rank(auth.uid()) >= 90);
DROP POLICY IF EXISTS qr_codes_update ON public.talent_qr_codes;
CREATE POLICY qr_codes_update ON public.talent_qr_codes FOR UPDATE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 90);
DROP POLICY IF EXISTS qr_codes_delete ON public.talent_qr_codes;
CREATE POLICY qr_codes_delete ON public.talent_qr_codes FOR DELETE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 90);

DROP POLICY IF EXISTS qr_scans_select ON public.talent_qr_scans;
CREATE POLICY qr_scans_select ON public.talent_qr_scans FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS qr_scans_insert ON public.talent_qr_scans;
CREATE POLICY qr_scans_insert ON public.talent_qr_scans FOR INSERT TO authenticated WITH CHECK (true);

-- app_config: direct table access is intentionally blocked by having no SELECT policy.
-- Public browser-safe values are exposed only through get_public_app_config().

-- ============================================================
-- 6. Grants
-- ============================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.change_my_password(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_last_login() TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_registration_status(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_user(text, text, text, uuid, uuid, text, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user(uuid, text, uuid, uuid, text, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_password(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.use_talent(uuid, integer, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_product_order(uuid, uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_product_order(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_product_purchase(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.scan_qr_talent(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_anonymous_question(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_soft_delete_qna(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_app_config(text) TO anon, authenticated;

-- ============================================================
-- 7. Storage Bucket
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('Talents_Items', 'Talents_Items', true)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = EXCLUDED.public;

DROP POLICY IF EXISTS "Public read Talents_Items" ON storage.objects;
CREATE POLICY "Public read Talents_Items" ON storage.objects
  FOR SELECT USING (bucket_id = 'Talents_Items');

DROP POLICY IF EXISTS "Staff upload Talents_Items" ON storage.objects;
CREATE POLICY "Staff upload Talents_Items" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'Talents_Items' AND public.get_permission_rank(auth.uid()) >= 60);

DROP POLICY IF EXISTS "Staff update Talents_Items" ON storage.objects;
CREATE POLICY "Staff update Talents_Items" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'Talents_Items' AND public.get_permission_rank(auth.uid()) >= 60);

DROP POLICY IF EXISTS "Staff delete Talents_Items" ON storage.objects;
CREATE POLICY "Staff delete Talents_Items" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'Talents_Items' AND public.get_permission_rank(auth.uid()) >= 60);

-- ============================================================
-- 8. Required Seed Data
-- ============================================================

-- 기본 부서: 가입 신청 화면에서 부서 선택이 필수이므로 최소 1개가 필요합니다.
INSERT INTO public.departments (name, description, is_active, class_count)
VALUES ('기본 부서', '초기 설정용 기본 부서입니다. 실제 부서명으로 수정해서 사용하세요.', true, 0)
ON CONFLICT (name) DO UPDATE
SET description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    class_count = EXCLUDED.class_count;

-- 첫 관리자 계정: admin_user / 1234
DO $$
DECLARE
  v_admin_id uuid;
  v_email text := 'admin_user@cho-talents.app';
BEGIN
  SELECT id INTO v_admin_id FROM auth.users WHERE email = v_email LIMIT 1;

  IF v_admin_id IS NULL THEN
    v_admin_id := extensions.gen_random_uuid();

    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, email_change, email_change_token_new, recovery_token,
      is_sso_user, is_anonymous
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_admin_id, 'authenticated', 'authenticated',
      v_email, extensions.crypt('1234', extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('username', 'admin_user', 'display_name', '관리자'),
      '', '', '', '', false, false
    );

    INSERT INTO auth.identities (
      id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) VALUES (
      v_admin_id, v_admin_id::text, v_admin_id,
      jsonb_build_object('sub', v_admin_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
      'email', now(), now(), now()
    );
  END IF;

  INSERT INTO public.profiles (
    id, email, username, display_name, user_type, permission_level,
    is_super_admin, is_first_login, talent_balance, pending_talent
  ) VALUES (
    v_admin_id, v_email, 'admin_user', '관리자', 'teacher', 'admin',
    true, true, 0, 0
  )
  ON CONFLICT (id) DO UPDATE
  SET username = EXCLUDED.username,
      display_name = EXCLUDED.display_name,
      user_type = EXCLUDED.user_type,
      permission_level = EXCLUDED.permission_level,
      is_super_admin = EXCLUDED.is_super_admin,
      updated_at = now();
END $$;

-- 달란트 지급 기본 항목
INSERT INTO public.talent_items (name, target_type, talent_amount, is_active, sort_order, is_quick_button)
VALUES
  ('출석', 'student', 3, true, 1, true),
  ('성경 읽기', 'student', 5, true, 2, false),
  ('말씀 암송', 'student', 10, true, 3, false),
  ('찬양', 'student', 2, true, 4, false),
  ('봉사', 'student', 10, true, 5, false),
  ('친구 초대', 'student', 20, true, 6, false),
  ('선행', 'student', 5, true, 7, false),
  ('특별 활동', 'student', 5, true, 8, false),
  ('예배 참석', 'teacher', 5, true, 1, true),
  ('교사 회의 참석', 'teacher', 3, true, 2, false),
  ('봉사 활동', 'teacher', 10, true, 3, false),
  ('특별 활동 참여', 'teacher', 5, true, 4, false),
  ('연수 참석', 'teacher', 8, true, 5, false)
ON CONFLICT (target_type, name) DO UPDATE
SET talent_amount = EXCLUDED.talent_amount,
    is_active = EXCLUDED.is_active,
    sort_order = EXCLUDED.sort_order,
    is_quick_button = EXCLUDED.is_quick_button;

-- Q&A 기본 FAQ
INSERT INTO public.qna (question, answer, is_faq, status)
SELECT v.question, v.answer, true, 'faq'
FROM (VALUES
  ('로그인이 안 돼요.', '아이디와 비밀번호를 다시 확인하세요. 승인 전 계정은 로그인할 수 없으며, 승인 대기 중 안내가 표시됩니다.'),
  ('계정 신청 후 바로 사용할 수 있나요?', '아니요. 관리자가 승인한 뒤 사용할 수 있습니다.'),
  ('상품은 어떻게 구매하나요?', '로그인 후 상품 구매 페이지에서 구매 신청 버튼을 누르세요. 이후 선생님이 처리합니다.'),
  ('구매 신청했는데 달란트가 안 줄었어요.', '정상입니다. 구매 신청 시에는 사용 대기로 표시되고, 선생님이 상품 구매를 확정하면 실제로 차감됩니다.'),
  ('내 달란트가 맞지 않는 것 같아요.', '담당 선생님에게 문의해 최근 적립/사용 내역을 확인하세요.'),
  ('교사용 상품이 안 보여요.', '교사 계정으로 로그인해야 교사용 상품 탭을 볼 수 있습니다.'),
  ('메뉴가 사람마다 달라요.', '사이트 권한에 따라 사용할 수 있는 메뉴만 보입니다.'),
  ('오류 메시지가 표시돼요.', '에러는 한글로 안내됩니다. 같은 오류가 반복되면 관리자에게 문의하세요.'),
  ('비밀번호를 잊어버렸어요.', '담당 선생님이나 관리자에게 비밀번호 초기화를 요청하세요. 초기화 후 1234로 로그인하고 새 비밀번호로 변경하면 됩니다.')
) AS v(question, answer)
WHERE NOT EXISTS (
  SELECT 1 FROM public.qna q
  WHERE q.question = v.question AND q.is_faq = true
);

-- 페이지 권한 매트릭스 기본값
WITH levels(permission_level, rank) AS (
  VALUES
    ('admin', 100),
    ('evangelist', 90),
    ('chief', 80),
    ('purchase_teacher', 70),
    ('dept_teacher', 60),
    ('teacher', 40),
    ('student', 20)
),
pages(page_key, min_view_rank, min_manage_rank) AS (
  VALUES
    ('dashboard', 60, 60),
    ('users', 60, 60),
    ('departments', 60, 80),
    ('managers', 80, 80),
    ('talents', 40, 40),
    ('talent_stats', 60, 60),
    ('talent_qr', 90, 90),
    ('talent_items', 90, 90),
    ('shop', 60, 60),
    ('purchases', 60, 60),
    ('purchase_stats', 60, 60),
    ('reports', 80, 80),
    ('logs', 100, 100),
    ('audit', 100, 100),
    ('slack_rules', 80, 80),
    ('versions', 80, 80),
    ('page_permissions', 100, 100)
)
INSERT INTO public.page_permissions (page_key, permission_level, can_view, can_manage)
SELECT p.page_key,
       l.permission_level,
       l.rank >= p.min_view_rank,
       l.rank >= p.min_manage_rank
FROM pages p
CROSS JOIN levels l
WHERE l.rank >= p.min_view_rank OR l.rank >= p.min_manage_rank
ON CONFLICT (page_key, permission_level) DO UPDATE
SET can_view = EXCLUDED.can_view,
    can_manage = EXCLUDED.can_manage,
    updated_at = now();

-- 공개 런타임 설정과 비밀 참조값
-- env 값은 config/public-config.js의 TARGET_ENV와 같아야 합니다. DEV 검증이면 'DEV'를 사용하세요.
INSERT INTO public.app_config (env, key_name, key_value, is_secret, use_yn, description)
VALUES
  ('PROD', 'SUPABASE_URL', 'https://YOUR_PROJECT_REF.supabase.co', false, true, '브라우저 Supabase 클라이언트 부트스트랩 URL'),
  ('PROD', 'SUPABASE_ANON_KEY', 'YOUR_PUBLISHABLE_OR_ANON_KEY', false, true, '브라우저 공개 publishable/anon key. RLS/RPC로 권한 제한'),
  ('PROD', 'SUPABASE_AUTH_EMAIL_DOMAIN', '@cho-talents.app', false, true, '아이디 로그인용 내부 이메일 도메인'),
  ('PROD', 'KAKAO_MAP_KEY', 'YOUR_KAKAO_MAP_JAVASCRIPT_KEY', false, true, '카카오 지도 JavaScript 공개 키'),
  ('PROD', 'GITHUB_OWNER', 'CHO-Talents', false, true, 'GitHub 저장소 owner 메타데이터'),
  ('PROD', 'GITHUB_REPO', 'CHO-Talents', false, true, 'GitHub 저장소 이름 메타데이터'),
  ('PROD', 'GITHUB_BRANCH', 'develop', false, true, '기본 배포/형상관리 브랜치 메타데이터'),
  ('PROD', 'GITHUB_PAT', 'env:GITHUB_PAT', true, false, '비밀 원문 저장 금지. 로컬 .env.local 또는 Edge Function 환경변수에 저장'),
  ('PROD', 'SUPABASE_ACCESS_TOKEN', 'env:SUPABASE_ACCESS_TOKEN', true, false, '비밀 원문 저장 금지. Supabase CLI/Management API 실행 환경변수에 저장'),
  ('PROD', 'SUPABASE_SERVICE_ROLE_KEY', 'env:SUPABASE_SERVICE_ROLE_KEY', true, false, '서버 전용 키. Edge Function/서버 환경변수 또는 Supabase Vault에 저장'),
  ('PROD', 'SUPABASE_DB_CONNECTION_STRING', 'env:SUPABASE_DB_CONNECTION_STRING', true, false, 'DB 관리/마이그레이션 전용. 로컬/CI 비밀 저장소에서만 사용'),
  ('PROD', 'SLACK_WEBHOOK_PART1', 'env:SLACK_WEBHOOK_PART1', true, false, 'Slack 1부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('PROD', 'SLACK_WEBHOOK_PART2', 'env:SLACK_WEBHOOK_PART2', true, false, 'Slack 2부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('PROD', 'SLACK_WEBHOOK_PART3', 'env:SLACK_WEBHOOK_PART3', true, false, 'Slack 3부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('PROD', 'SLACK_WEBHOOK_PART4', 'env:SLACK_WEBHOOK_PART4', true, false, 'Slack 4부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('PROD', 'SLACK_WEBHOOK_PART5', 'env:SLACK_WEBHOOK_PART5', true, false, 'Slack 5부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('PROD', 'SLACK_WEBHOOK_WORSHIP', 'env:SLACK_WEBHOOK_WORSHIP', true, false, 'Slack 예배부 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('PROD', 'SLACK_WEBHOOK_PRODUCT_MANAGEMENT', 'env:SLACK_WEBHOOK_PRODUCT_MANAGEMENT', true, false, 'Slack 상품 관리 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('PROD', 'SLACK_WEBHOOK_OPERATIONS', 'env:SLACK_WEBHOOK_OPERATIONS', true, false, 'Slack 운영 로그 채널 Webhook. Edge Function Secret에 원문 저장'),
  ('PROD', 'SLACK_WEBHOOK_ANSWER', 'env:SLACK_WEBHOOK_ANSWER', true, false, 'Slack Q&A 채널 Webhook. Edge Function Secret에 원문 저장')
ON CONFLICT (env, key_name) DO UPDATE
SET key_value = EXCLUDED.key_value,
    is_secret = EXCLUDED.is_secret,
    use_yn = EXCLUDED.use_yn,
    description = EXCLUDED.description,
    updated_at = now();

NOTIFY pgrst, 'reload schema';

COMMIT;
