-- TASK-039: talent_items 테이블에 is_quick_button 컬럼 추가
-- 출석 퀵버튼 기능을 위해 유형별(학생/교사) 1개 항목만 퀵버튼으로 지정 가능

ALTER TABLE talent_items
  ADD COLUMN IF NOT EXISTS is_quick_button boolean DEFAULT false;

COMMENT ON COLUMN talent_items.is_quick_button IS '출석 퀵버튼 지정 여부 (유형별 1개만 가능)';
