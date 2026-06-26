-- 기존 reports 테이블 삭제 후 재생성
-- 기존 테이블의 컬럼 구조가 프로젝트와 불일치하여 재생성 필요

DROP TABLE IF EXISTS reports CASCADE;

CREATE TABLE reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id text NOT NULL,
  task_title text NOT NULL,
  report_type text NOT NULL CHECK (report_type IN ('plan', 'test_scenario', 'test_result', 'change_report')),
  content text NOT NULL,
  created_by text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read reports" ON reports
  FOR SELECT USING (true);

CREATE POLICY "Allow anon insert reports" ON reports
  FOR INSERT WITH CHECK (true);
