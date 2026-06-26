-- TASK-055 Hotfix: QR 스캔 고아 레코드 문제 긴급 수정
-- 실행 위치: Supabase Dashboard > SQL Editor

-- ============================================================
-- 1. talent_qr_scans에 DELETE 권한 추가 (rollback 지원)
-- ============================================================
GRANT DELETE ON public.talent_qr_scans TO authenticated;

-- ============================================================
-- 2. 고아 레코드 삭제: talent_qr_scans에는 있지만
--    대응하는 talent_transactions가 없는 레코드
-- ============================================================
DELETE FROM public.talent_qr_scans qs
WHERE NOT EXISTS (
  SELECT 1 FROM public.talent_transactions tt
  WHERE tt.user_id = qs.user_id
    AND tt.type = 'earn'
    AND tt.created_at BETWEEN qs.scanned_at - interval '2 minutes'
                          AND qs.scanned_at + interval '2 minutes'
)
AND NOT EXISTS (
  SELECT 1 FROM public.talent_transactions tt
  WHERE tt.user_id = qs.user_id
    AND tt.type = 'earn'
    AND tt.source = 'qr'
    AND tt.talent_item_id = (
      SELECT qc.talent_item_id FROM public.talent_qr_codes qc
      WHERE qc.id = qs.qr_code_id
    )
);

-- ============================================================
-- 3. used_count 재계산
-- ============================================================
UPDATE public.talent_qr_codes qc
SET used_count = (
  SELECT COUNT(*) FROM public.talent_qr_scans qs
  WHERE qs.qr_code_id = qc.id
);

-- ============================================================
-- 4. 스키마 캐시 리로드
-- ============================================================
NOTIFY pgrst, 'reload schema';
