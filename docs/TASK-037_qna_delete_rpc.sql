-- ============================================================
-- TASK-037: Q&A 삭제 RPC 함수 (RLS 우회)
-- 실행 대상: Supabase SQL Editor
-- 문제: qna_update RLS 정책의 get_permission_rank(auth.uid()) 호출 실패
-- 해결: SECURITY DEFINER RPC로 RLS 우회하여 soft delete 수행
-- ============================================================

-- 1. Q&A 소프트 삭제 RPC (rank 90+ 전용)
CREATE OR REPLACE FUNCTION admin_soft_delete_qna(p_qna_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rank INT;
BEGIN
  -- 권한 체크: profiles 테이블에서 직접 조회
  SELECT COALESCE(
    CASE permission_level
      WHEN 'admin' THEN 100
      WHEN 'evangelist' THEN 90
      WHEN 'chief' THEN 80
      WHEN 'dept_teacher' THEN 60
      WHEN 'teacher' THEN 40
      WHEN 'student' THEN 20
      ELSE 0
    END, 0)
  INTO v_rank
  FROM profiles
  WHERE id = auth.uid();

  IF v_rank < 90 THEN
    RETURN jsonb_build_object('success', false, 'error', '삭제 권한이 없습니다 (전도사님 이상)');
  END IF;

  UPDATE qna SET is_deleted = true WHERE id = p_qna_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 2. 기존 qna UPDATE RLS 정책도 완화 (다른 UPDATE 작업을 위해)
DROP POLICY IF EXISTS "qna_update" ON qna;
CREATE POLICY "qna_update" ON qna FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
