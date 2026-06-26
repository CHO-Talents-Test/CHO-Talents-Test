-- TASK-055 Final Fix: QR 스캔 전용 RPC + 권한 수정
-- 실행 위치: Supabase Dashboard > SQL Editor
-- 이 파일이 최종 수정본이며 이전 hotfix SQL 실행 여부 무관

-- ============================================================
-- 1. 권한 추가
-- ============================================================
GRANT DELETE ON public.talent_qr_scans TO authenticated;
GRANT UPDATE ON public.talent_qr_scans TO authenticated;
GRANT UPDATE ON public.talent_transactions TO authenticated;

-- ============================================================
-- 2. source 컬럼 확인 (이미 있으면 무시)
-- ============================================================
ALTER TABLE public.talent_transactions
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'admin';

-- ============================================================
-- 3. QR 스캔 전용 RPC 함수 (SECURITY DEFINER - RLS 우회)
-- ============================================================
CREATE OR REPLACE FUNCTION public.scan_qr_talent(
  p_qr_code_id uuid,
  p_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qr record;
  v_new_balance integer;
  v_txn_id uuid;
  v_scan_id uuid;
  v_existing_scan uuid;
  v_existing_txn uuid;
BEGIN
  -- QR 코드 조회
  SELECT * INTO v_qr FROM public.talent_qr_codes WHERE id = p_qr_code_id AND is_active = true;
  IF v_qr IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid QR code');
  END IF;

  -- 기존 스캔 확인
  SELECT id INTO v_existing_scan
  FROM public.talent_qr_scans
  WHERE qr_code_id = p_qr_code_id AND user_id = p_user_id
  LIMIT 1;

  IF v_existing_scan IS NOT NULL THEN
    -- 스캔 기록 존재 → 실제 지급 여부 확인
    SELECT id INTO v_existing_txn
    FROM public.talent_transactions
    WHERE user_id = p_user_id
      AND type = 'earn'
      AND (
        (talent_item_id = v_qr.talent_item_id AND v_qr.talent_item_id IS NOT NULL)
        OR (created_at BETWEEN (SELECT scanned_at FROM talent_qr_scans WHERE id = v_existing_scan) - interval '2 minutes'
                            AND (SELECT scanned_at FROM talent_qr_scans WHERE id = v_existing_scan) + interval '2 minutes')
      )
    LIMIT 1;

    IF v_existing_txn IS NOT NULL THEN
      RETURN json_build_object('success', false, 'error', 'Already received');
    END IF;

    -- 고아 레코드: 스캔은 있으나 지급 안됨 → 기존 스캔 재사용
    UPDATE public.talent_qr_scans SET scanned_at = now() WHERE id = v_existing_scan;
    v_scan_id := v_existing_scan;
  ELSE
    -- 새 스캔 삽입
    INSERT INTO public.talent_qr_scans (qr_code_id, user_id, scanned_at)
    VALUES (p_qr_code_id, p_user_id, now())
    RETURNING id INTO v_scan_id;
  END IF;

  -- used_count 업데이트 (기존 고아 재사용이면 증가하지 않음)
  IF v_existing_scan IS NULL THEN
    UPDATE public.talent_qr_codes
    SET used_count = COALESCE(used_count, 0) + 1
    WHERE id = p_qr_code_id;
  END IF;

  -- 잔액 업데이트
  UPDATE public.profiles
  SET talent_balance = COALESCE(talent_balance, 0) + v_qr.amount
  WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

  -- 트랜잭션 기록
  INSERT INTO public.talent_transactions (
    user_id, type, amount, balance_after, description,
    created_by, talent_item_id, source
  ) VALUES (
    p_user_id, 'earn', v_qr.amount, v_new_balance,
    COALESCE(v_qr.description, 'QR 달란트'),
    p_user_id, v_qr.talent_item_id, 'qr'
  )
  RETURNING id INTO v_txn_id;

  RETURN json_build_object(
    'success', true,
    'balance', v_new_balance,
    'amount', v_qr.amount,
    'txn_id', v_txn_id,
    'scan_id', v_scan_id
  );
END;
$$;

-- ============================================================
-- 4. 기존 고아 레코드 정리
-- ============================================================
DELETE FROM public.talent_qr_scans qs
WHERE NOT EXISTS (
  SELECT 1 FROM public.talent_transactions tt
  WHERE tt.user_id = qs.user_id
    AND tt.type = 'earn'
    AND tt.created_at BETWEEN qs.scanned_at - interval '5 minutes'
                          AND qs.scanned_at + interval '5 minutes'
)
AND NOT EXISTS (
  SELECT 1 FROM public.talent_transactions tt
  WHERE tt.user_id = qs.user_id
    AND tt.type = 'earn'
    AND tt.source = 'qr'
    AND tt.talent_item_id IS NOT NULL
    AND tt.talent_item_id = (
      SELECT qc.talent_item_id FROM public.talent_qr_codes qc WHERE qc.id = qs.qr_code_id
    )
);

-- used_count 재계산
UPDATE public.talent_qr_codes qc
SET used_count = (
  SELECT COUNT(*) FROM public.talent_qr_scans qs WHERE qs.qr_code_id = qc.id
);

-- ============================================================
-- 5. 스키마 캐시 리로드
-- ============================================================
NOTIFY pgrst, 'reload schema';
