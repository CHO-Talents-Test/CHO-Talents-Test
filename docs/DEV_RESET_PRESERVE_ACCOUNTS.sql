-- CHO-Talents DEV reset
--
-- Scope
--   * Preserves: auth account IDs, usernames, names, departments, roles,
--     managed departments, and class numbers.
--   * Resets: every account password to 1234, all app sessions, balances,
--     UI preferences, and all business/operational data.
--   * Does not delete: profiles, departments, or system schema/config tables.
--
-- Preconditions
--   1. Run only in project blitrrcdkkkszvgylnus.
--   2. Take a project backup first.
--   3. The profile username admin_user must already exist.
--   4. Run the DEV schema/config migration bundle immediately afterwards.

BEGIN;

-- Prevent concurrent application writes while the reset is committed.
LOCK TABLE public.profiles IN SHARE ROW EXCLUSIVE MODE;

DO $$
DECLARE
  v_admin_user_id uuid;
  v_table_name text;
  v_tables text[] := ARRAY[
    -- Child tables must be removed before their parents.
    'product_suggestion_adoption_rewards',
    'product_suggestion_votes',
    'product_suggestion_eligible_voters',
    'product_suggestions',
    'product_orders',
    'qna_comments',
    'qna',
    'report_confirmations',
    'report_events',
    'reports',
    'announcement_dismissals',
    'announcements',
    'talent_qr_scans',
    'talent_qr_codes',
    'talent_exception_requests',
    'talent_transactions',
    'talent_items',
    'registration_requests',
    'department_transfer_requests',
    'user_login_history',
    'user_preferences',
    'activity_logs',
    'service_usage_alerts',
    'service_usage_collection_runs',
    'service_usage_events',
    'service_usage_snapshots',
    'service_usage_metrics',
    'usage_size_daily_snapshots',
    'system_logs',
    'products'
  ];
BEGIN
  SELECT id
  INTO v_admin_user_id
  FROM public.profiles
  WHERE username = 'admin_user';

  IF v_admin_user_id IS NULL THEN
    RAISE EXCEPTION 'admin_user profile is required; aborting without changes';
  END IF;

  -- Terminate every refreshable Auth session before deleting application data.
  -- Existing access JWTs expire according to the project's configured JWT lifetime.
  IF to_regclass('auth.refresh_tokens') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.refresh_tokens';
  END IF;
  IF to_regclass('auth.sessions') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.sessions';
  END IF;

  -- Every retained account starts again with the temporary password and must
  -- change it on the first successful login.
  UPDATE auth.users
  SET encrypted_password = extensions.crypt('1234', extensions.gen_salt('bf')),
      recovery_token = '',
      updated_at = now()
  WHERE id IN (SELECT id FROM public.profiles);

  UPDATE public.profiles
  SET talent_balance = 0,
      pending_talent = 0,
      is_first_login = true,
      is_super_admin = (id = v_admin_user_id),
      permission_level = CASE WHEN id = v_admin_user_id THEN 'admin' ELSE permission_level END,
      user_type = CASE WHEN id = v_admin_user_id THEN 'teacher' ELSE user_type END,
      updated_at = now();

  -- This is a retired authentication table, kept only for backwards
  -- compatibility. Reset its password state too, so no legacy login route can
  -- retain an older password. The active account authority remains auth.users
  -- plus public.profiles.
  IF to_regclass('public.admin_users') IS NOT NULL THEN
    UPDATE public.admin_users
    SET password_hash = encode(extensions.digest('1234', 'sha256'), 'hex'),
        is_first_login = true,
        updated_at = now();
  END IF;

  FOREACH v_table_name IN ARRAY v_tables LOOP
    IF to_regclass(format('public.%s', v_table_name)) IS NOT NULL THEN
      EXECUTE format('DELETE FROM public.%I', v_table_name);
    END IF;
  END LOOP;
END;
$$;

-- Reset the baseline talent menu. No talent transaction or QR history remains.
INSERT INTO public.talent_items
  (name, target_type, talent_amount, is_active, sort_order, is_quick_button)
VALUES
  ('출석', 'student', 3, true, 1, true),
  ('성경 읽기', 'student', 5, true, 2, false),
  ('말씀 암송', 'student', 10, true, 3, false),
  ('찬양', 'student', 2, true, 4, false),
  ('행사', 'student', 10, true, 5, false),
  ('친구 초대', 'student', 20, true, 6, false),
  ('전도', 'student', 5, true, 7, false),
  ('새친구 섬김', 'student', 5, true, 8, false),
  ('예배 참석', 'teacher', 5, true, 1, true),
  ('교사 회의 참석', 'teacher', 3, true, 2, false),
  ('행사 섬김', 'teacher', 10, true, 3, false),
  ('새친구 섬김 참여', 'teacher', 5, true, 4, false),
  ('연수 참석', 'teacher', 8, true, 5, false)
ON CONFLICT (target_type, name) DO UPDATE
SET talent_amount = EXCLUDED.talent_amount,
    is_active = EXCLUDED.is_active,
    sort_order = EXCLUDED.sort_order,
    is_quick_button = EXCLUDED.is_quick_button;

-- Restore the initial FAQ set.
INSERT INTO public.qna (question, answer, is_faq, status)
VALUES
  ('로그인이 안 돼요.', '아이디와 비밀번호를 다시 확인하세요. 승인 전 계정은 로그인할 수 없습니다.', true, 'faq'),
  ('계정 신청 후 바로 사용할 수 있나요?', '아니요. 관리자 승인 후 사용할 수 있습니다.', true, 'faq'),
  ('상품은 어떻게 구매하나요?', '로그인 후 상품 구매 페이지에서 구매 신청 버튼을 누르세요.', true, 'faq'),
  ('구매 신청했는데 달란트가 줄었어요.', '구매 신청 시 사용 대기 달란트로 표시되고, 구매 확정 시 실제 차감됩니다.', true, 'faq'),
  ('내 달란트가 맞지 않는 것 같아요.', '담당 교사에게 문의하고 최근 적립/사용 내역을 확인하세요.', true, 'faq'),
  ('교사용 상품도 보이나요?', '교사 계정으로 로그인하면 교사용 상품을 볼 수 있습니다.', true, 'faq'),
  ('메뉴가 사람마다 달라요.', '사이트 권한에 따라 사용할 수 있는 메뉴만 표시됩니다.', true, 'faq'),
  ('오류 메시지가 표시돼요.', '메시지 안내에 따라 다시 시도하고 반복되면 관리자에게 문의하세요.', true, 'faq'),
  ('비밀번호를 잊어버렸어요.', '초기 비밀번호 1234로 로그인한 뒤 반드시 비밀번호를 변경하세요.', true, 'faq');

-- DEV runtime configuration only. Slack secrets stay disabled and are never
-- copied from production.
INSERT INTO public.app_config (env, key_name, key_value, is_secret, use_yn, description)
VALUES
  ('DEV', 'SUPABASE_URL', 'https://blitrrcdkkkszvgylnus.supabase.co', false, true, 'DEV browser client URL'),
  ('DEV', 'SUPABASE_ANON_KEY', 'sb_publishable_TgsQePzjxca9Hr3Lh_dHvA_O1JqRAQ6', false, true, 'DEV browser publishable key'),
  ('DEV', 'SUPABASE_AUTH_EMAIL_DOMAIN', '@cho-talents.app', false, true, 'Internal auth email domain'),
  ('DEV', 'KAKAO_MAP_KEY', 'f880c1746c4cd81e2fa54df45ebea41d', false, true, 'DEV Kakao Maps key'),
  ('DEV', 'GITHUB_OWNER', 'CHO-Talents-Test', false, true, 'DEV GitHub owner'),
  ('DEV', 'GITHUB_REPO', 'CHO-Talents-Test', false, true, 'DEV GitHub repository'),
  ('DEV', 'GITHUB_BRANCH', 'develop', false, true, 'DEV source branch')
ON CONFLICT (env, key_name) DO UPDATE
SET key_value = EXCLUDED.key_value,
    is_secret = EXCLUDED.is_secret,
    use_yn = EXCLUDED.use_yn,
    description = EXCLUDED.description,
    updated_at = now();

UPDATE public.app_config
SET use_yn = false,
    updated_at = now()
WHERE env = 'DEV'
  AND key_name LIKE 'SLACK_WEBHOOK_%';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Postconditions to verify before deploying the DEV site:
--   SELECT username, permission_level, is_super_admin, talent_balance,
--          pending_talent, is_first_login
--   FROM public.profiles ORDER BY username;
--   SELECT count(*) FROM auth.sessions; -- expected 0
--   SELECT count(*) FROM public.talent_transactions; -- expected 0
--   SELECT count(*) FROM public.user_preferences; -- expected 0
