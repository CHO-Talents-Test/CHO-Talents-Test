-- TASK-033: v3.13.1 DB 변경사항
-- 실행 위치: Supabase SQL Editor (https://supabase.com/dashboard → SQL Editor)
-- 실행 순서: 위에서 아래로 순서대로 실행
-- 반복 실행 안전: 이 SQL은 여러 번 실행해도 안전합니다

-- ============================================================
-- 0. get_permission_rank UUID 오버로드 (기존 TEXT 버전 보완)
--    auth.uid()를 직접 전달할 수 있도록 UUID→profiles 조회→TEXT 버전 호출
-- ============================================================
CREATE OR REPLACE FUNCTION get_permission_rank(p_user_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT get_permission_rank(
    COALESCE(
      (SELECT permission_level FROM profiles WHERE id = p_user_id),
      'student'
    )
  );
$$;

-- ============================================================
-- 1. Q&A 테이블 생성 (이미 존재하면 건너뜀)
-- ============================================================
CREATE TABLE IF NOT EXISTS qna (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  question text NOT NULL,
  answer text,
  asked_by uuid REFERENCES auth.users(id),
  asked_by_name text,
  answered_by uuid REFERENCES auth.users(id),
  answered_by_name text,
  is_faq boolean DEFAULT false,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'answered', 'faq')),
  created_at timestamptz DEFAULT now(),
  answered_at timestamptz
);

ALTER TABLE qna ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. RLS 정책 (이미 존재하면 건너뜀)
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'qna' AND policyname = 'qna_select_all') THEN
    CREATE POLICY "qna_select_all" ON qna FOR SELECT TO authenticated
      USING (is_faq = true OR asked_by = auth.uid() OR get_permission_rank(auth.uid()) >= 60);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'qna' AND policyname = 'qna_select_anon') THEN
    CREATE POLICY "qna_select_anon" ON qna FOR SELECT TO anon
      USING (is_faq = true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'qna' AND policyname = 'qna_insert') THEN
    CREATE POLICY "qna_insert" ON qna FOR INSERT TO authenticated
      WITH CHECK (asked_by = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'qna' AND policyname = 'qna_update') THEN
    CREATE POLICY "qna_update" ON qna FOR UPDATE TO authenticated
      USING (get_permission_rank(auth.uid()) >= 60);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'qna' AND policyname = 'qna_delete') THEN
    CREATE POLICY "qna_delete" ON qna FOR DELETE TO authenticated
      USING (get_permission_rank(auth.uid()) >= 100);
  END IF;
END $$;

-- ============================================================
-- 3. 초기 FAQ 데이터 삽입 (SITE_USER_GUIDE.md 10번 항목)
--    기존 시스템 FAQ(asked_by IS NULL)를 제거 후 재삽입 → 반복 실행 안전
-- ============================================================
DELETE FROM qna WHERE is_faq = true AND asked_by IS NULL;

INSERT INTO qna (question, answer, is_faq, status) VALUES
('로그인이 안 돼요.', '아이디와 비밀번호를 다시 확인하세요. 승인 전 계정은 로그인할 수 없으며, "승인 대기 중" 안내가 표시됩니다.', true, 'faq'),
('계정 신청 후 바로 사용할 수 있나요?', '아니요. 관리자가 승인한 뒤 사용할 수 있습니다.', true, 'faq'),
('상품은 어떻게 구매하나요?', '로그인 후 상품 구매 페이지에서 구매 신청 버튼을 누르세요. 이후 선생님이 처리합니다.', true, 'faq'),
('구매 신청했는데 달란트가 안 줄었어요.', '정상입니다. 구매 신청 시에는 사용 대기로 표시되고, 선생님이 상품 구매를 확정하면 실제로 차감됩니다.', true, 'faq'),
('내 달란트가 맞지 않는 것 같아요.', '담당 선생님에게 문의해 최근 적립/사용 내역을 확인하세요.', true, 'faq'),
('교사용 상품이 안 보여요.', '교사 계정으로 로그인해야 교사용 상품 탭을 볼 수 있습니다.', true, 'faq'),
('메뉴가 사람마다 달라요.', '사이트 권한에 따라 사용할 수 있는 메뉴만 보입니다.', true, 'faq'),
('오류 메시지가 표시돼요.', '에러는 한글로 안내됩니다. 같은 오류가 반복되면 관리자에게 문의하세요.', true, 'faq'),
('비밀번호를 잊어버렸어요.', '담당 선생님이나 관리자에게 비밀번호 초기화를 요청하세요. 초기화 후 1234로 로그인하고 새 비밀번호로 변경하면 됩니다.', true, 'faq');

-- ============================================================
-- 4. qna 테이블 is_deleted 컬럼 추가 (소프트 삭제)
-- ============================================================
ALTER TABLE qna ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;

-- 기존 SELECT 정책에 is_deleted 필터 추가 (기존 정책 교체)
DROP POLICY IF EXISTS "qna_select_all" ON qna;
CREATE POLICY "qna_select_all" ON qna FOR SELECT TO authenticated
  USING ((is_faq = true OR asked_by = auth.uid() OR get_permission_rank(auth.uid()) >= 60) AND is_deleted = false);

DROP POLICY IF EXISTS "qna_select_anon" ON qna;
CREATE POLICY "qna_select_anon" ON qna FOR SELECT TO anon
  USING (is_faq = true AND is_deleted = false);

-- 비로그인 사용자 질문 등록 RPC
CREATE OR REPLACE FUNCTION submit_anonymous_question(p_question text, p_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_question IS NULL OR length(trim(p_question)) = 0 THEN
    RAISE EXCEPTION 'question is required';
  END IF;
  INSERT INTO qna (question, asked_by_name, status)
  VALUES (trim(p_question), COALESCE(NULLIF(trim(p_name), ''), '익명'), 'pending')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION submit_anonymous_question(text, text) TO anon;
GRANT EXECUTE ON FUNCTION submit_anonymous_question(text, text) TO authenticated;
