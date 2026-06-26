-- TASK-054: talent_qr_codes 테이블 권한 + RLS 정책 수정
-- 문제 1: authenticated 역할에 talent_qr_codes 테이블 INSERT 권한 없음
--          -> "permission denied for table talent_qr_codes" 에러
-- 문제 2: TASK-030에서 생성한 RLS 정책이 get_permission_rank() 호출 시 public. 스키마 누락
--          -> "new row violates row-level security policy" 에러
-- 실행 위치: Supabase Dashboard > SQL Editor

-- ============================================================
-- 1. 테이블 권한 부여 (핵심 수정)
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.talent_qr_codes TO authenticated;
GRANT SELECT, INSERT ON public.talent_qr_scans TO authenticated;

-- ============================================================
-- 2. RLS 정책 재생성 (public. 스키마 명시)
-- ============================================================
DROP POLICY IF EXISTS "qr_codes_select" ON public.talent_qr_codes;
DROP POLICY IF EXISTS "qr_codes_insert" ON public.talent_qr_codes;
DROP POLICY IF EXISTS "qr_codes_update" ON public.talent_qr_codes;
DROP POLICY IF EXISTS "qr_codes_delete" ON public.talent_qr_codes;

ALTER TABLE public.talent_qr_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "qr_codes_select" ON public.talent_qr_codes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "qr_codes_insert" ON public.talent_qr_codes
  FOR INSERT TO authenticated
  WITH CHECK (public.get_permission_rank(auth.uid()) >= 90);

CREATE POLICY "qr_codes_update" ON public.talent_qr_codes
  FOR UPDATE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 90);

CREATE POLICY "qr_codes_delete" ON public.talent_qr_codes
  FOR DELETE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 90);

-- ============================================================
-- 3. talent_qr_scans RLS 확인
-- ============================================================
DROP POLICY IF EXISTS "qr_scans_select" ON public.talent_qr_scans;
DROP POLICY IF EXISTS "qr_scans_insert" ON public.talent_qr_scans;

ALTER TABLE public.talent_qr_scans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "qr_scans_select" ON public.talent_qr_scans
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "qr_scans_insert" ON public.talent_qr_scans
  FOR INSERT TO authenticated WITH CHECK (true);

-- 스키마 캐시 리로드
NOTIFY pgrst, 'reload schema';
