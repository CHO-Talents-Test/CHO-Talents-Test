-- TASK-058: QR date range + weekday/time-window enforcement
-- Run target: Supabase SQL Editor or Management API

ALTER TABLE public.talent_qr_codes
  ADD COLUMN IF NOT EXISTS valid_start_time time,
  ADD COLUMN IF NOT EXISTS valid_end_time time;

COMMENT ON COLUMN public.talent_qr_codes.valid_start_time IS 'Daily QR receive start time in Asia/Seoul, separated from valid_from date range';
COMMENT ON COLUMN public.talent_qr_codes.valid_end_time IS 'Daily QR receive end time in Asia/Seoul, separated from valid_until date range';

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
  v_now_kst timestamp;
  v_time_kst time;
  v_day_kst integer;
  v_week_kst integer;
  v_today_start_utc timestamptz;
  v_tomorrow_start_utc timestamptz;
BEGIN
  v_now_kst := timezone('Asia/Seoul', now());
  v_time_kst := v_now_kst::time;
  v_day_kst := extract(dow from v_now_kst)::integer;
  v_week_kst := ceil((
    extract(day from v_now_kst)::numeric
    + extract(dow from date_trunc('month', v_now_kst)::date)::numeric
  ) / 7)::integer;
  v_today_start_utc := date_trunc('day', v_now_kst) AT TIME ZONE 'Asia/Seoul';
  v_tomorrow_start_utc := (date_trunc('day', v_now_kst) + interval '1 day') AT TIME ZONE 'Asia/Seoul';

  SELECT * INTO v_qr
  FROM public.talent_qr_codes
  WHERE id = p_qr_code_id
    AND is_active = true;

  IF v_qr IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Invalid QR code');
  END IF;

  IF v_qr.valid_from IS NOT NULL AND now() < v_qr.valid_from THEN
    RETURN json_build_object('success', false, 'error', 'Not yet valid');
  END IF;

  IF v_qr.valid_until IS NOT NULL AND now() > v_qr.valid_until THEN
    RETURN json_build_object('success', false, 'error', 'Expired QR code');
  END IF;

  IF v_qr.expires_at IS NOT NULL AND now() > v_qr.expires_at THEN
    RETURN json_build_object('success', false, 'error', 'Expired QR code');
  END IF;

  IF v_qr.valid_start_time IS NOT NULL AND v_time_kst < v_qr.valid_start_time THEN
    RETURN json_build_object('success', false, 'error', 'Invalid time window');
  END IF;

  IF v_qr.valid_end_time IS NOT NULL AND v_time_kst > v_qr.valid_end_time THEN
    RETURN json_build_object('success', false, 'error', 'Invalid time window');
  END IF;

  IF COALESCE(v_qr.repeat_type, 'none') = 'weekday' THEN
    IF v_qr.repeat_days IS NULL OR NOT (v_day_kst = ANY(v_qr.repeat_days)) THEN
      RETURN json_build_object('success', false, 'error', 'Invalid weekday');
    END IF;
  END IF;

  IF COALESCE(v_qr.repeat_type, 'none') = 'week_weekday' THEN
    IF v_qr.repeat_weeks IS NULL OR NOT (v_week_kst = ANY(v_qr.repeat_weeks)) THEN
      RETURN json_build_object('success', false, 'error', 'Invalid week of month');
    END IF;

    IF v_qr.repeat_days IS NULL OR NOT (v_day_kst = ANY(v_qr.repeat_days)) THEN
      RETURN json_build_object('success', false, 'error', 'Invalid weekday');
    END IF;
  END IF;

  IF COALESCE(v_qr.max_uses, 0) > 0 AND COALESCE(v_qr.used_count, 0) >= v_qr.max_uses THEN
    RETURN json_build_object('success', false, 'error', 'Max uses exceeded');
  END IF;

  IF COALESCE(v_qr.repeat_type, 'none') = 'none' THEN
    SELECT id INTO v_existing_scan
    FROM public.talent_qr_scans
    WHERE qr_code_id = p_qr_code_id
      AND user_id = p_user_id
    ORDER BY scanned_at DESC
    LIMIT 1;
  ELSE
    SELECT id INTO v_existing_scan
    FROM public.talent_qr_scans
    WHERE qr_code_id = p_qr_code_id
      AND user_id = p_user_id
      AND scanned_at >= v_today_start_utc
      AND scanned_at < v_tomorrow_start_utc
    ORDER BY scanned_at DESC
    LIMIT 1;
  END IF;

  IF v_existing_scan IS NOT NULL THEN
    SELECT id INTO v_existing_txn
    FROM public.talent_transactions
    WHERE user_id = p_user_id
      AND type = 'earn'
      AND created_at BETWEEN
        (SELECT scanned_at FROM public.talent_qr_scans WHERE id = v_existing_scan) - interval '2 minutes'
        AND
        (SELECT scanned_at FROM public.talent_qr_scans WHERE id = v_existing_scan) + interval '2 minutes'
      AND (
        source = 'qr'
        OR v_qr.talent_item_id IS NULL
        OR talent_item_id = v_qr.talent_item_id
      )
    LIMIT 1;

    IF v_existing_txn IS NOT NULL THEN
      RETURN json_build_object('success', false, 'error', 'Already received');
    END IF;

    UPDATE public.talent_qr_scans
    SET scanned_at = now()
    WHERE id = v_existing_scan;

    v_scan_id := v_existing_scan;
  ELSE
    INSERT INTO public.talent_qr_scans (qr_code_id, user_id, scanned_at)
    VALUES (p_qr_code_id, p_user_id, now())
    RETURNING id INTO v_scan_id;

    UPDATE public.talent_qr_codes
    SET used_count = COALESCE(used_count, 0) + 1
    WHERE id = p_qr_code_id;
  END IF;

  UPDATE public.profiles
  SET talent_balance = COALESCE(talent_balance, 0) + v_qr.amount
  WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

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

GRANT EXECUTE ON FUNCTION public.scan_qr_talent(uuid, uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';

-- Optional targeted backfill for existing repeating QR rows that were saved
-- with time-of-day embedded in valid_from/valid_until before this fix.
-- Review rows first, then narrow the WHERE clause by id/code if needed.
--
-- SELECT id, code, description, repeat_type, valid_from, valid_until,
--        valid_start_time, valid_end_time
-- FROM public.talent_qr_codes
-- WHERE COALESCE(repeat_type, 'none') <> 'none'
--   AND valid_from IS NOT NULL
--   AND valid_until IS NOT NULL
--   AND (valid_start_time IS NULL OR valid_end_time IS NULL);
--
-- UPDATE public.talent_qr_codes
-- SET valid_start_time = (valid_from AT TIME ZONE 'Asia/Seoul')::time,
--     valid_end_time = (valid_until AT TIME ZONE 'Asia/Seoul')::time,
--     valid_from = date_trunc('day', valid_from AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul',
--     valid_until = (
--       date_trunc('day', valid_until AT TIME ZONE 'Asia/Seoul') + interval '1 day' - interval '1 second'
--     ) AT TIME ZONE 'Asia/Seoul'
-- WHERE COALESCE(repeat_type, 'none') <> 'none'
--   AND valid_from IS NOT NULL
--   AND valid_until IS NOT NULL
--   AND (valid_start_time IS NULL OR valid_end_time IS NULL)
--   AND (
--     (valid_from AT TIME ZONE 'Asia/Seoul')::time <> time '00:00:00'
--     OR (valid_until AT TIME ZONE 'Asia/Seoul')::time < time '23:59:00'
--   );
