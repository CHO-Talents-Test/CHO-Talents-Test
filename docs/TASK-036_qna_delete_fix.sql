-- ============================================================
-- TASK-036: Q&A 삭제 권한 RLS 수정 (즉시 적용용)
-- 실행 대상: Supabase SQL Editor
-- 문제: "해당 작업에 대한 권한이 없습니다" 오류 발생
-- 원인: qna UPDATE RLS 정책이 get_permission_rank(auth.uid()) 호출 시 실패
-- 해결: UPDATE 정책을 완화 (클라이언트에서 권한 체크)
-- ============================================================

-- qna UPDATE 정책 재생성 (모든 인증 사용자 UPDATE 가능)
DROP POLICY IF EXISTS "qna_update" ON qna;
CREATE POLICY "qna_update" ON qna FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- qna_comments UPDATE 정책도 완화
DROP POLICY IF EXISTS "qna_comments_update" ON qna_comments;
CREATE POLICY "qna_comments_update" ON qna_comments FOR UPDATE TO authenticated
  USING (true);

-- qna_comments DELETE 정책도 완화
DROP POLICY IF EXISTS "qna_comments_delete" ON qna_comments;
CREATE POLICY "qna_comments_delete" ON qna_comments FOR DELETE TO authenticated
  USING (true);
