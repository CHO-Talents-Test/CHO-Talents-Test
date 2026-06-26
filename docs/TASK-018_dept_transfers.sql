-- ============================================================
-- TASK-018: 부서 이동 관리 시스템
-- Supabase SQL Editor에서 실행해주세요
-- ============================================================

-- 1. 부서 이동 요청 테이블 생성
CREATE TABLE IF NOT EXISTS department_transfer_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  username TEXT NOT NULL,
  display_name TEXT,
  from_department_id UUID REFERENCES departments(id),
  to_department_id UUID NOT NULL REFERENCES departments(id),
  requested_by TEXT NOT NULL,
  request_reason TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by TEXT,
  review_note TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. RLS 활성화
ALTER TABLE department_transfer_requests ENABLE ROW LEVEL SECURITY;

-- 3. RLS 정책: SELECT - 인증된 사용자 조회 가능
CREATE POLICY "dept_transfer_select" ON department_transfer_requests
  FOR SELECT TO authenticated USING (true);

-- 4. RLS 정책: INSERT - rank >= 60 (부서 담당 교사 이상)
CREATE POLICY "dept_transfer_insert" ON department_transfer_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT get_permission_rank(permission_level) FROM profiles WHERE id = auth.uid()) >= 60
  );

-- 5. RLS 정책: UPDATE - rank >= 80 (부장 이상, 승인/거부용)
CREATE POLICY "dept_transfer_update" ON department_transfer_requests
  FOR UPDATE TO authenticated
  USING (
    (SELECT get_permission_rank(permission_level) FROM profiles WHERE id = auth.uid()) >= 80
  );

-- 6. RLS 정책: DELETE - rank >= 90 (전도사님 이상)
CREATE POLICY "dept_transfer_delete" ON department_transfer_requests
  FOR DELETE TO authenticated
  USING (
    (SELECT get_permission_rank(permission_level) FROM profiles WHERE id = auth.uid()) >= 90
  );
