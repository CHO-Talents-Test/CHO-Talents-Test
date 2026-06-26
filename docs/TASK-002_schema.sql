-- ============================================================
-- TASK-002 Schema Changes
-- 역할 기반 계정 체계 및 달란트 시스템
-- Management API로 실행 완료 (2026-05-26)
-- ============================================================

-- 1. departments 테이블
CREATE TABLE IF NOT EXISTS departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- 2. admin_users 확장 컬럼
ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS department_id uuid REFERENCES departments(id);
ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS managed_dept_id uuid REFERENCES departments(id);
ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS talent_balance integer DEFAULT 0;

-- 3. talent_transactions 테이블
CREATE TABLE IF NOT EXISTS talent_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('earn', 'use')),
  amount integer NOT NULL,
  balance_after integer NOT NULL,
  description text,
  created_by uuid REFERENCES admin_users(id),
  created_at timestamptz DEFAULT now()
);

-- 4. products 테이블
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price integer NOT NULL,
  image_emoji text DEFAULT '',
  target_role text NOT NULL CHECK (target_role IN ('teacher', 'student')),
  category text,
  stock integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_by uuid,
  created_at timestamptz DEFAULT now()
);

-- 5. RLS Policies
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE talent_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- departments: full access
CREATE POLICY "Allow anon read departments" ON departments FOR SELECT USING (true);
CREATE POLICY "Allow anon insert departments" ON departments FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon update departments" ON departments FOR UPDATE USING (true);
CREATE POLICY "Allow anon delete departments" ON departments FOR DELETE USING (true);

-- talent_transactions: read/insert
CREATE POLICY "Allow anon read talent_transactions" ON talent_transactions FOR SELECT USING (true);
CREATE POLICY "Allow anon insert talent_transactions" ON talent_transactions FOR INSERT WITH CHECK (true);

-- products: full access
CREATE POLICY "Allow anon read products" ON products FOR SELECT USING (true);
CREATE POLICY "Allow anon insert products" ON products FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon update products" ON products FOR UPDATE USING (true);
CREATE POLICY "Allow anon delete products" ON products FOR DELETE USING (true);

-- admin_users: extended policies
CREATE POLICY "Allow anon insert admin_users" ON admin_users FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon update admin_users" ON admin_users FOR UPDATE USING (true);
CREATE POLICY "Allow anon delete admin_users" ON admin_users FOR DELETE USING (true);
CREATE POLICY "Allow anon select admin_users_limited" ON admin_users FOR SELECT USING (true);

-- 6. verify_user RPC (extends verify_admin)
CREATE OR REPLACE FUNCTION verify_user(p_username text, p_password_hash text)
RETURNS json LANGUAGE sql SECURITY DEFINER AS $$
  SELECT json_build_object(
    'id', u.id, 'username', u.username, 'display_name', u.display_name,
    'role', u.role, 'is_first_login', u.is_first_login,
    'department_id', u.department_id, 'managed_dept_id', u.managed_dept_id,
    'talent_balance', COALESCE(u.talent_balance, 0),
    'department_name', d.name
  )
  FROM admin_users u LEFT JOIN departments d ON d.id = u.department_id
  WHERE u.username = p_username AND u.password_hash = p_password_hash LIMIT 1;
$$;

-- 7. give_talent RPC
CREATE OR REPLACE FUNCTION give_talent(p_user_id uuid, p_amount integer, p_description text, p_created_by uuid)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_new_balance integer; v_txn_id uuid;
BEGIN
  UPDATE admin_users SET talent_balance = COALESCE(talent_balance,0) + p_amount WHERE id = p_user_id RETURNING talent_balance INTO v_new_balance;
  IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'User not found'); END IF;
  INSERT INTO talent_transactions (user_id, type, amount, balance_after, description, created_by)
  VALUES (p_user_id, 'earn', p_amount, v_new_balance, p_description, p_created_by) RETURNING id INTO v_txn_id;
  RETURN json_build_object('success', true, 'balance', v_new_balance, 'txn_id', v_txn_id);
END; $$;

-- 8. use_talent RPC
CREATE OR REPLACE FUNCTION use_talent(p_user_id uuid, p_amount integer, p_description text, p_created_by uuid)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_current integer; v_new_balance integer; v_txn_id uuid;
BEGIN
  SELECT COALESCE(talent_balance,0) INTO v_current FROM admin_users WHERE id = p_user_id;
  IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'User not found'); END IF;
  IF v_current < p_amount THEN RETURN json_build_object('success', false, 'error', 'Insufficient balance', 'balance', v_current); END IF;
  v_new_balance := v_current - p_amount;
  UPDATE admin_users SET talent_balance = v_new_balance WHERE id = p_user_id;
  INSERT INTO talent_transactions (user_id, type, amount, balance_after, description, created_by)
  VALUES (p_user_id, 'use', p_amount, v_new_balance, p_description, p_created_by) RETURNING id INTO v_txn_id;
  RETURN json_build_object('success', true, 'balance', v_new_balance, 'txn_id', v_txn_id);
END; $$;

-- 9. Sample Products (11 items)
INSERT INTO products (name, description, price, image_emoji, target_role, category, stock, is_active) VALUES
('캐릭터 연필세트', '귀여운 캐릭터가 그려진 연필 6자루 세트', 5, '✏️', 'student', '학용품', 50, true),
('귀여운 지우개 컬렉션', '동물 모양 지우개 3개 세트', 3, '🧹', 'student', '학용품', 100, true),
('미니 인형 키링', '가방에 달 수 있는 귀여운 미니 인형', 10, '🧸', 'student', '액세서리', 30, true),
('반짝이 스티커북', '다양한 반짝이 스티커 100장 모음', 7, '⭐', 'student', '문구', 40, true),
('간식 쿠폰 (과자+음료)', '매점에서 사용 가능한 간식 쿠폰', 15, '🍪', 'student', '쿠폰', 20, true),
('스타벅스 아메리카노 쿠폰', '스타벅스 톨사이즈 아메리카노 교환권', 10, '☕', 'teacher', '20대 추천', 15, true),
('무선 이어폰 파우치', '감성 디자인 이어폰 파우치', 20, '🎧', 'teacher', '20대 추천', 10, true),
('감성 다이어리', '2026년 감성 위클리 다이어리', 15, '📔', 'teacher', '20대 추천', 20, true),
('프리미엄 핸드크림 세트', '고급 시어버터 핸드크림 3종 세트', 12, '🧴', 'teacher', '30대 추천', 15, true),
('미니 가습기', 'USB 충전 미니 가습기', 25, '💧', 'teacher', '30대 추천', 8, true),
('편의점 상품권 5천원', 'CU/GS25 편의점 상품권', 18, '🏪', 'teacher', '30대 추천', 25, true)
ON CONFLICT DO NOTHING;
