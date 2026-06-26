-- TASK-032: v3.13.0 DB 변경사항
-- 실행 위치: Supabase SQL Editor
-- 실행 순서: 위에서 아래로 순서대로 실행

-- ============================================================
-- 1. 가입 신청 상태 조회 RPC (anonymous 호출 가능)
-- ============================================================
CREATE OR REPLACE FUNCTION check_registration_status(p_username text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT status INTO v_status
  FROM registration_requests
  WHERE username = p_username
  ORDER BY created_at DESC
  LIMIT 1;

  RETURN COALESCE(v_status, 'not_found');
END;
$$;

GRANT EXECUTE ON FUNCTION check_registration_status(text) TO anon;
GRANT EXECUTE ON FUNCTION check_registration_status(text) TO authenticated;

-- ============================================================
-- 2. Q&A 테이블 생성
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

-- 모든 인증 사용자: FAQ 및 자신의 질문 조회 가능
CREATE POLICY "qna_select_all" ON qna FOR SELECT TO authenticated
  USING (is_faq = true OR asked_by = auth.uid() OR get_permission_rank(auth.uid()) >= 60);

-- 비인증(anon): FAQ만 조회 가능
CREATE POLICY "qna_select_anon" ON qna FOR SELECT TO anon
  USING (is_faq = true);

-- 인증 사용자: 질문 등록 가능
CREATE POLICY "qna_insert" ON qna FOR INSERT TO authenticated
  WITH CHECK (asked_by = auth.uid());

-- 부서 담당 교사(60+): 답변 및 FAQ 등록 처리
CREATE POLICY "qna_update" ON qna FOR UPDATE TO authenticated
  USING (get_permission_rank(auth.uid()) >= 60);

-- 관리자(100+): 삭제 가능
CREATE POLICY "qna_delete" ON qna FOR DELETE TO authenticated
  USING (get_permission_rank(auth.uid()) >= 100);

-- ============================================================
-- 3. 초기 FAQ 데이터 삽입
-- ============================================================
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
