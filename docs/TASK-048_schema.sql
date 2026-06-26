-- ============================================================
-- TASK-048: v3.36.0 스키마 변경
-- 1. talent_items에 giving_rule, giving_description 컬럼 추가
-- 2. profiles.permission_level에 'purchase_teacher' 값 추가
-- 3. registration_requests.permission_level에 'purchase_teacher' 값 추가
-- ============================================================

-- 1. talent_items 컬럼 추가
ALTER TABLE public.talent_items
  ADD COLUMN IF NOT EXISTS giving_rule text,
  ADD COLUMN IF NOT EXISTS giving_description text;

-- 2. profiles.permission_level CHECK 제약 변경
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_permission_level_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_permission_level_check
  CHECK (permission_level IN ('admin','evangelist','chief','purchase_teacher','dept_teacher','teacher','student'));

-- 3. registration_requests.permission_level CHECK 제약 변경
ALTER TABLE public.registration_requests
  DROP CONSTRAINT IF EXISTS registration_requests_permission_level_check;
ALTER TABLE public.registration_requests
  ADD CONSTRAINT registration_requests_permission_level_check
  CHECK (permission_level IN ('admin','evangelist','chief','purchase_teacher','dept_teacher','teacher','student'));

-- 4. get_permission_rank 함수에 purchase_teacher(70) 추가
CREATE OR REPLACE FUNCTION public.get_permission_rank(p_level TEXT)
RETURNS INT AS $$
BEGIN
  RETURN CASE p_level
    WHEN 'admin' THEN 100 WHEN 'evangelist' THEN 90 WHEN 'chief' THEN 80
    WHEN 'purchase_teacher' THEN 70 WHEN 'dept_teacher' THEN 60 WHEN 'teacher' THEN 40 WHEN 'student' THEN 20
    ELSE 0 END;
END; $$ LANGUAGE plpgsql IMMUTABLE;
