-- ============================================================
-- TASK-035: Q&A 댓글 시스템 + 삭제 권한 RLS 수정
-- 실행 대상: Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. qna_comments 테이블 생성
-- ============================================================
CREATE TABLE IF NOT EXISTS qna_comments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  qna_id UUID NOT NULL REFERENCES qna(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  commented_by UUID REFERENCES auth.users(id),
  commented_by_name TEXT DEFAULT '관리자',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE qna_comments ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. qna_comments RLS 정책
-- ============================================================
DROP POLICY IF EXISTS "qna_comments_select" ON qna_comments;
CREATE POLICY "qna_comments_select" ON qna_comments FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "qna_comments_insert" ON qna_comments;
CREATE POLICY "qna_comments_insert" ON qna_comments FOR INSERT TO authenticated
  WITH CHECK (get_permission_rank(auth.uid()) >= 60);

DROP POLICY IF EXISTS "qna_comments_update" ON qna_comments;
CREATE POLICY "qna_comments_update" ON qna_comments FOR UPDATE TO authenticated
  USING (get_permission_rank(auth.uid()) >= 60);

DROP POLICY IF EXISTS "qna_comments_delete" ON qna_comments;
CREATE POLICY "qna_comments_delete" ON qna_comments FOR DELETE TO authenticated
  USING (get_permission_rank(auth.uid()) >= 90);

-- ============================================================
-- 3. qna 테이블 RLS 수정 (UPDATE: 모든 인증 사용자, 실제 권한 체크는 클라이언트에서)
-- ============================================================
DROP POLICY IF EXISTS "qna_update" ON qna;
CREATE POLICY "qna_update" ON qna FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "qna_insert" ON qna;
CREATE POLICY "qna_insert" ON qna FOR INSERT TO authenticated
  WITH CHECK (true);

-- ============================================================
-- 4. qna SELECT 정책 재생성 (is_deleted 필터 + anon/authenticated 분리)
-- ============================================================
DROP POLICY IF EXISTS "qna_select_all" ON qna;
CREATE POLICY "qna_select_all" ON qna FOR SELECT TO authenticated
  USING (
    (is_faq = true OR asked_by = auth.uid() OR get_permission_rank(auth.uid()) >= 60)
    AND is_deleted = false
  );

DROP POLICY IF EXISTS "qna_select_anon" ON qna;
CREATE POLICY "qna_select_anon" ON qna FOR SELECT TO anon
  USING (is_faq = true AND is_deleted = false);

-- ============================================================
-- 5. 인덱스 추가 (성능)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_qna_comments_qna_id ON qna_comments(qna_id);
CREATE INDEX IF NOT EXISTS idx_qna_comments_created_at ON qna_comments(created_at);
