-- ============================================================
-- TASK: user_preferences에 theme 컬럼 추가
-- Date: 2026-06-08
-- Version: 3.33.0
-- Description: 사용자별 테마 설정을 저장하기 위한 컬럼 추가
-- ============================================================

-- 1. theme 컬럼 추가
ALTER TABLE public.user_preferences
ADD COLUMN IF NOT EXISTS theme text DEFAULT 'default'
CHECK (theme IN ('default', 'dark', 'spring', 'summer', 'autumn', 'winter'));

-- 2. 기존 RLS 정책은 user_preferences 전체에 적용되므로
--    추가 RLS 변경 불필요 (user_id 기반 자기 자신만 접근 가능)

-- 확인용 쿼리
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'user_preferences' AND table_schema = 'public';
