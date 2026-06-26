-- TASK-021: 페이지 접근 관리 + 페이지 기능 관리 테이블 생성
-- Supabase SQL Editor에서 실행해주세요

-- 1. 페이지 접근 관리 테이블
CREATE TABLE IF NOT EXISTS user_page_access (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  page_id TEXT NOT NULL,
  can_access BOOLEAN DEFAULT true,
  hidden_elements TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, page_id)
);

ALTER TABLE user_page_access ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_page_access_select" ON user_page_access;
CREATE POLICY "user_page_access_select" ON user_page_access
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "user_page_access_insert" ON user_page_access;
CREATE POLICY "user_page_access_insert" ON user_page_access
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );

DROP POLICY IF EXISTS "user_page_access_update" ON user_page_access;
CREATE POLICY "user_page_access_update" ON user_page_access
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );

DROP POLICY IF EXISTS "user_page_access_delete" ON user_page_access;
CREATE POLICY "user_page_access_delete" ON user_page_access
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );

-- 2. 페이지 기능 관리 테이블 (권한별 관리)
CREATE TABLE IF NOT EXISTS role_page_features (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  permission_key TEXT NOT NULL,
  page_id TEXT NOT NULL,
  features JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(permission_key, page_id)
);

ALTER TABLE role_page_features ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "role_page_features_select" ON role_page_features;
CREATE POLICY "role_page_features_select" ON role_page_features
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "role_page_features_insert" ON role_page_features;
CREATE POLICY "role_page_features_insert" ON role_page_features
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );

DROP POLICY IF EXISTS "role_page_features_update" ON role_page_features;
CREATE POLICY "role_page_features_update" ON role_page_features
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );

DROP POLICY IF EXISTS "role_page_features_delete" ON role_page_features;
CREATE POLICY "role_page_features_delete" ON role_page_features
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );
