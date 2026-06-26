-- TASK-013C: talent_items 테이블
CREATE TABLE talent_items (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('teacher', 'student')),
  talent_amount INT NOT NULL CHECK (talent_amount > 0),
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE talent_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY talent_items_select ON talent_items FOR SELECT USING (true);
CREATE POLICY talent_items_insert ON talent_items FOR INSERT WITH CHECK (get_permission_rank(get_my_role()) >= 90);
CREATE POLICY talent_items_update ON talent_items FOR UPDATE USING (get_permission_rank(get_my_role()) >= 90);
CREATE POLICY talent_items_delete ON talent_items FOR DELETE USING (get_permission_rank(get_my_role()) >= 100);

-- TASK-013C: talent_transactions 확장
ALTER TABLE talent_transactions ADD COLUMN talent_item_id UUID REFERENCES talent_items(id);

-- TASK-013C: give_talent RPC (항목 기반 + 학생 주 1회 규칙)
CREATE OR REPLACE FUNCTION give_talent(
  p_user_id UUID,
  p_amount INTEGER DEFAULT 0,
  p_description TEXT DEFAULT '',
  p_created_by UUID DEFAULT NULL,
  p_talent_item_id UUID DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_balance INTEGER; v_txn_id UUID; v_caller_perm TEXT;
  v_target_type TEXT; v_item RECORD; v_actual_amount INTEGER;
  v_actual_desc TEXT; v_week_count INTEGER;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL OR get_permission_rank(v_caller_perm) < 60 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT user_type INTO v_target_type FROM profiles WHERE id = p_user_id;
  IF v_target_type IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF p_talent_item_id IS NOT NULL THEN
    SELECT * INTO v_item FROM talent_items WHERE id = p_talent_item_id AND is_active = true;
    IF v_item IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Invalid or inactive talent item');
    END IF;
    v_actual_amount := v_item.talent_amount;
    v_actual_desc := v_item.name;

    IF v_target_type = 'student' THEN
      SELECT COUNT(*) INTO v_week_count FROM talent_transactions
      WHERE user_id = p_user_id AND talent_item_id = p_talent_item_id AND type = 'earn'
        AND created_at >= date_trunc('week', now() AT TIME ZONE 'Asia/Seoul')
        AND created_at < date_trunc('week', now() AT TIME ZONE 'Asia/Seoul') + interval '7 days';
      IF v_week_count > 0 THEN
        RETURN json_build_object('success', false, 'error',
          'Already given this item this week for student: ' || v_item.name);
      END IF;
    END IF;
  ELSE
    IF p_amount <= 0 THEN
      RETURN json_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    v_actual_amount := p_amount;
    v_actual_desc := COALESCE(NULLIF(p_description, ''), 'Manual');
  END IF;

  UPDATE profiles SET talent_balance = COALESCE(talent_balance, 0) + v_actual_amount WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

  INSERT INTO talent_transactions (user_id, type, amount, balance_after, description, created_by, talent_item_id)
  VALUES (p_user_id, 'earn', v_actual_amount, v_new_balance, v_actual_desc, COALESCE(p_created_by, auth.uid()), p_talent_item_id)
  RETURNING id INTO v_txn_id;

  RETURN json_build_object('success', true, 'balance', v_new_balance, 'txn_id', v_txn_id, 'amount', v_actual_amount);
END;
$$;

-- TASK-013D: page_permissions 테이블
CREATE TABLE page_permissions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  page_key TEXT NOT NULL,
  permission_level TEXT NOT NULL,
  can_view BOOLEAN DEFAULT false,
  can_manage BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(page_key, permission_level)
);

ALTER TABLE page_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY pp_select ON page_permissions FOR SELECT USING (true);
CREATE POLICY pp_manage ON page_permissions FOR ALL USING (get_permission_rank(get_my_role()) >= 100);

-- TASK-013D: admin_list_users (p_role -> p_user_type)
CREATE OR REPLACE FUNCTION admin_list_users(
  p_user_type TEXT DEFAULT NULL,
  p_department_id UUID DEFAULT NULL
) RETURNS SETOF profiles LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_caller_perm TEXT;
BEGIN
  SELECT permission_level INTO v_caller_perm FROM profiles WHERE id = auth.uid();
  IF v_caller_perm IS NULL OR get_permission_rank(v_caller_perm) < 60 THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
    SELECT * FROM profiles
    WHERE (p_user_type IS NULL OR user_type = p_user_type)
      AND (p_department_id IS NULL OR department_id = p_department_id)
    ORDER BY created_at DESC;
END;
$$;

-- TASK-013D: admin_create_user (role 제거)
CREATE OR REPLACE FUNCTION admin_create_user(
  p_username TEXT, p_password TEXT, p_display_name TEXT,
  p_department_id UUID DEFAULT NULL, p_managed_dept_id UUID DEFAULT NULL,
  p_user_type TEXT DEFAULT 'student', p_permission_level TEXT DEFAULT 'student'
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
-- (전체 함수 본문은 DB에서 확인)
$$;

-- TASK-013D: admin_update_user (role 제거)
CREATE OR REPLACE FUNCTION admin_update_user(
  p_user_id UUID, p_display_name TEXT DEFAULT NULL,
  p_department_id UUID DEFAULT NULL, p_managed_dept_id UUID DEFAULT NULL,
  p_user_type TEXT DEFAULT NULL, p_permission_level TEXT DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
-- (전체 함수 본문은 DB에서 확인)
$$;

-- TASK-013D: role 컬럼 최종 제거
ALTER TABLE profiles DROP COLUMN role;
ALTER TABLE registration_requests DROP COLUMN role;
