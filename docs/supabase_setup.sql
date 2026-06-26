-- ============================================================
-- CHO-Talents Supabase Setup SQL
-- 실행 방법: Supabase Dashboard > SQL Editor > New Query 에 붙여넣고 실행
-- ============================================================

-- 1. admin_users 테이블
CREATE TABLE IF NOT EXISTS admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  display_name text,
  role text DEFAULT 'admin',
  is_first_login boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. reports 테이블
CREATE TABLE IF NOT EXISTS reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id text NOT NULL,
  task_title text NOT NULL,
  report_type text NOT NULL CHECK (report_type IN ('plan', 'test_scenario', 'test_result', 'change_report')),
  content text NOT NULL,
  created_by text,
  created_at timestamptz DEFAULT now()
);

-- 3. activity_logs 테이블
CREATE TABLE IF NOT EXISTS activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  level text NOT NULL DEFAULT 'INFO' CHECK (level IN ('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL', 'CRITICAL')),
  action text NOT NULL,
  page text,
  details jsonb,
  username text,
  is_acknowledged boolean DEFAULT false,
  acknowledged_by text,
  acknowledged_at timestamptz,
  resolution_note text,
  created_at timestamptz DEFAULT now()
);

-- 4. RLS 활성화
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- 5. RLS 정책 - admin_users: 직접 조회 차단 (RPC 함수로만 접근)
DROP POLICY IF EXISTS "Block direct access to admin_users" ON admin_users;
CREATE POLICY "Block direct access to admin_users" ON admin_users
  FOR SELECT USING (false);

-- 6. RLS 정책 - reports: anon 읽기 허용 (관리자 인증은 클라이언트에서 처리)
DROP POLICY IF EXISTS "Allow anon read reports" ON reports;
CREATE POLICY "Allow anon read reports" ON reports
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow anon insert reports" ON reports;
CREATE POLICY "Allow anon insert reports" ON reports
  FOR INSERT WITH CHECK (true);

-- 7. RLS 정책 - activity_logs: anon 읽기/쓰기 허용
DROP POLICY IF EXISTS "Allow anon read logs" ON activity_logs;
CREATE POLICY "Allow anon read logs" ON activity_logs
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow anon insert logs" ON activity_logs;
CREATE POLICY "Allow anon insert logs" ON activity_logs
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon update logs" ON activity_logs;
CREATE POLICY "Allow anon update logs" ON activity_logs
  FOR UPDATE USING (true);

-- 8. verify_admin RPC 함수 (SECURITY DEFINER로 RLS 우회)
CREATE OR REPLACE FUNCTION verify_admin(p_username text, p_password_hash text)
RETURNS json
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT json_build_object(
    'id', id,
    'username', username,
    'display_name', display_name,
    'role', role,
    'is_first_login', is_first_login
  )
  FROM admin_users
  WHERE username = p_username AND password_hash = p_password_hash
  LIMIT 1;
$$;

-- 9. update_password RPC 함수
CREATE OR REPLACE FUNCTION update_password(p_username text, p_new_password_hash text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE admin_users
  SET password_hash = p_new_password_hash,
      is_first_login = false,
      updated_at = now()
  WHERE username = p_username;
  RETURN FOUND;
END;
$$;

-- 10. 초기 관리자 계정 (admin_user / 1234)
-- SHA-256('1234') = 03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4
INSERT INTO admin_users (username, password_hash, display_name, role, is_first_login)
VALUES ('admin_user', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', '관리자', 'admin', true)
ON CONFLICT (username) DO NOTHING;
