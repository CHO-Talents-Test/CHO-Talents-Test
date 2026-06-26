-- ============================================================
-- TASK-030: talent_qr_codes + talent_qr_scans 테이블 보정
-- 테이블이 이미 존재하면 누락 컬럼만 추가, 정책은 재생성
-- Supabase SQL Editor에서 실행
-- ============================================================

-- 1. talent_qr_codes 테이블 (없으면 생성)
CREATE TABLE IF NOT EXISTS public.talent_qr_codes (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  code          text NOT NULL UNIQUE,
  description   text,
  amount        integer NOT NULL DEFAULT 1,
  max_uses      integer,
  used_count    integer NOT NULL DEFAULT 0,
  expires_at    timestamptz,
  is_active     boolean NOT NULL DEFAULT true,
  talent_item_id uuid,
  created_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- 이미 테이블이 있지만 컬럼이 누락된 경우 개별 추가
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='amount') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN amount integer NOT NULL DEFAULT 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='description') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN description text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='max_uses') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN max_uses integer;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='used_count') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN used_count integer NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='expires_at') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN expires_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='is_active') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN is_active boolean NOT NULL DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='talent_item_id') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN talent_item_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='created_by') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN created_by uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='talent_qr_codes' AND column_name='created_at') THEN
    ALTER TABLE public.talent_qr_codes ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
  END IF;
END $$;

COMMENT ON TABLE public.talent_qr_codes IS 'QR 코드 기반 달란트 지급 코드';

-- 2. talent_qr_scans 테이블 (없으면 생성)
CREATE TABLE IF NOT EXISTS public.talent_qr_scans (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  qr_code_id    uuid NOT NULL REFERENCES public.talent_qr_codes(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL,
  scanned_at    timestamptz NOT NULL DEFAULT now(),
  ip_address    text,
  user_agent    text,
  latitude      double precision,
  longitude     double precision,
  created_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.talent_qr_scans IS 'QR 코드 스캔 이력';

CREATE INDEX IF NOT EXISTS idx_qr_scans_qr_code ON public.talent_qr_scans(qr_code_id);
CREATE INDEX IF NOT EXISTS idx_qr_scans_user    ON public.talent_qr_scans(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_scans_unique ON public.talent_qr_scans(qr_code_id, user_id);

-- 3. RLS 정책 (기존 정책 삭제 후 재생성)
ALTER TABLE public.talent_qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.talent_qr_scans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "qr_codes_select" ON public.talent_qr_codes;
DROP POLICY IF EXISTS "qr_codes_insert" ON public.talent_qr_codes;
DROP POLICY IF EXISTS "qr_codes_update" ON public.talent_qr_codes;
DROP POLICY IF EXISTS "qr_codes_delete" ON public.talent_qr_codes;

CREATE POLICY "qr_codes_select" ON public.talent_qr_codes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "qr_codes_insert" ON public.talent_qr_codes
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );

CREATE POLICY "qr_codes_update" ON public.talent_qr_codes
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );

CREATE POLICY "qr_codes_delete" ON public.talent_qr_codes
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND get_permission_rank(permission_level) >= 90)
  );

DROP POLICY IF EXISTS "qr_scans_select" ON public.talent_qr_scans;
DROP POLICY IF EXISTS "qr_scans_insert" ON public.talent_qr_scans;

CREATE POLICY "qr_scans_select" ON public.talent_qr_scans
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "qr_scans_insert" ON public.talent_qr_scans
  FOR INSERT TO authenticated WITH CHECK (true);

-- 4. 스키마 캐시 리로드
NOTIFY pgrst, 'reload schema';
