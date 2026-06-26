-- ============================================================
-- TASK-033: talent_qr_codes 위치 제한 + 지급 대상 컬럼 추가
-- Supabase SQL Editor에서 실행
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='target_type') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN target_type text DEFAULT 'student';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='location_lat') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN location_lat double precision;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='location_lng') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN location_lng double precision;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='location_name') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN location_name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='location_radius') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN location_radius integer DEFAULT 1000;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='valid_from') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN valid_from timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='valid_until') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN valid_until timestamptz;
  END IF;
END $$;

COMMENT ON COLUMN public.talent_qr_codes.target_type IS '지급 대상: student 또는 teacher';
COMMENT ON COLUMN public.talent_qr_codes.location_lat IS '위치 제한 위도';
COMMENT ON COLUMN public.talent_qr_codes.location_lng IS '위치 제한 경도';
COMMENT ON COLUMN public.talent_qr_codes.location_name IS '위치 제한 장소명';
COMMENT ON COLUMN public.talent_qr_codes.location_radius IS '위치 제한 반경 (미터)';

NOTIFY pgrst, 'reload schema';
