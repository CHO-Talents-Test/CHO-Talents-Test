-- TASK-041: 페이지당 표시 항목 수 사용자별 설정 (v3.40.0)
-- user_preferences 테이블에 page_sizes 컬럼 추가

ALTER TABLE public.user_preferences
ADD COLUMN IF NOT EXISTS page_sizes JSONB DEFAULT '{}'::jsonb;

-- page_sizes 구조 예시:
-- {
--   "logs": 50,
--   "users_teacher": 10,
--   "users_student": 10,
--   "talents": 10,
--   "shop_teacher": 10,
--   "shop_student": 10,
--   "talent_stats_teacher": 20,
--   "talent_stats_student": 20,
--   "purchases": 20,
--   "talent_receive_student": 5,
--   "talent_receive_teacher": 5
-- }
