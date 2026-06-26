-- TASK-022: 로그 삭제 RLS 정책 + 권한별 페이지 기능 테이블

-- 1. activity_logs 테이블 DELETE 정책 추가 (관리자만)
DROP POLICY IF EXISTS "activity_logs_delete" ON activity_logs;
CREATE POLICY "activity_logs_delete" ON activity_logs
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND get_permission_rank(permission_level) >= 100
    )
  );

-- 2. reports 테이블 DELETE 정책 (관리자만)
DROP POLICY IF EXISTS "reports_delete" ON reports;
CREATE POLICY "reports_delete" ON reports
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND get_permission_rank(permission_level) >= 80
    )
  );

-- 3. reports 테이블 INSERT 정책
DROP POLICY IF EXISTS "reports_insert" ON reports;
CREATE POLICY "reports_insert" ON reports
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND get_permission_rank(permission_level) >= 80
    )
  );

-- 4. reports 테이블 UPDATE 정책
DROP POLICY IF EXISTS "reports_update" ON reports;
CREATE POLICY "reports_update" ON reports
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND get_permission_rank(permission_level) >= 80
    )
  );

-- 5. 권한별 페이지 기능 관리 테이블 (user_page_features -> role_page_features)
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
