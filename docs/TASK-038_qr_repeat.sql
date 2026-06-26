-- TASK-038: QR 반복 수령 기능 컬럼 추가
-- 실행 대상: Supabase SQL Editor
-- 멱등성: IF NOT EXISTS / DO $$ 블록 사용

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='talent_qr_codes' AND column_name='repeat_type') THEN
    ALTER TABLE talent_qr_codes ADD COLUMN repeat_type TEXT DEFAULT 'none';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='talent_qr_codes' AND column_name='repeat_days') THEN
    ALTER TABLE talent_qr_codes ADD COLUMN repeat_days INTEGER[] DEFAULT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='talent_qr_codes' AND column_name='repeat_weeks') THEN
    ALTER TABLE talent_qr_codes ADD COLUMN repeat_weeks INTEGER[] DEFAULT NULL;
  END IF;
END $$;

COMMENT ON COLUMN talent_qr_codes.repeat_type IS 'none=1회, daily=매일, weekday=요일반복, week_weekday=주차+요일반복';
COMMENT ON COLUMN talent_qr_codes.repeat_days IS '요일 배열 (0=일,1=월,...,6=토)';
COMMENT ON COLUMN talent_qr_codes.repeat_weeks IS '주차 배열 (1~5)';
