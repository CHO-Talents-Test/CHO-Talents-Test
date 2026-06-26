-- TASK-055: QR 수령 / 관리자 지급 동기화
-- talent_transactions에 source 컬럼을 추가하여 지급 출처(admin/qr)를 구분
-- 실행 위치: Supabase Dashboard > SQL Editor

-- ============================================================
-- 1. source 컬럼 추가
-- ============================================================
ALTER TABLE public.talent_transactions
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'admin';

COMMENT ON COLUMN public.talent_transactions.source
  IS 'admin = 관리자/RPC 지급, qr = QR 수령';

-- ============================================================
-- 2. 기존 QR 수령 데이터 소급 적용
-- ============================================================
UPDATE public.talent_transactions tt
SET source = 'qr'
FROM public.talent_qr_scans qs
JOIN public.talent_qr_codes qc ON qs.qr_code_id = qc.id
WHERE tt.user_id = qs.user_id
  AND tt.talent_item_id = qc.talent_item_id
  AND tt.talent_item_id IS NOT NULL
  AND tt.type = 'earn'
  AND tt.created_at BETWEEN qs.scanned_at - interval '5 seconds'
                        AND qs.scanned_at + interval '5 seconds';

-- talent_item_id가 null인 직접 입력 QR도 매칭 (timestamp + user 기반)
UPDATE public.talent_transactions tt
SET source = 'qr'
FROM public.talent_qr_scans qs
JOIN public.talent_qr_codes qc ON qs.qr_code_id = qc.id
WHERE tt.user_id = qs.user_id
  AND tt.talent_item_id IS NULL
  AND qc.talent_item_id IS NULL
  AND tt.type = 'earn'
  AND tt.source = 'admin'
  AND tt.description = COALESCE(qc.description, 'QR 달란트')
  AND tt.created_at BETWEEN qs.scanned_at - interval '5 seconds'
                        AND qs.scanned_at + interval '5 seconds';

-- ============================================================
-- 3. 고아 레코드 정리: talent_qr_scans에는 있지만 talent_transactions에 없는 경우
--    (source 컬럼 추가 전 코드 배포로 인해 INSERT 실패한 스캔 기록)
-- ============================================================
DELETE FROM public.talent_qr_scans qs
WHERE NOT EXISTS (
  SELECT 1 FROM public.talent_transactions tt
  WHERE tt.user_id = qs.user_id
    AND tt.type = 'earn'
    AND tt.created_at BETWEEN qs.scanned_at - interval '10 seconds'
                          AND qs.scanned_at + interval '10 seconds'
);

-- 고아 삭제 후 used_count 재계산
UPDATE public.talent_qr_codes qc
SET used_count = (
  SELECT COUNT(*) FROM public.talent_qr_scans qs
  WHERE qs.qr_code_id = qc.id
);

-- ============================================================
-- 4. 스키마 캐시 리로드
-- ============================================================
NOTIFY pgrst, 'reload schema';
