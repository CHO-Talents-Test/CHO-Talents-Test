-- ============================================================
-- TASK-057 prerequisite schema backfill
-- Use this when TASK-057_code_master.sql failed with:
--   ERROR: 42703: column "source" of relation "talent_transactions" does not exist
--
-- Run order for a partially configured DEV database:
--   1. docs/FIX_INITIAL_APP_CONFIG_DEV.sql
--   2. docs/FIX_TASK057_PREREQUISITES.sql
--   3. docs/TASK-057_code_master.sql
--   4. scripts/verify-task-057-code-master.sql
--
-- The current TASK-057_code_master.sql already includes this backfill.
-- This file is for recovering a database before re-running TASK-057.
-- ============================================================

BEGIN;

ALTER TABLE public.talent_transactions
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'admin';

UPDATE public.talent_transactions
SET source = 'admin'
WHERE source IS NULL OR btrim(source) = '';

COMMENT ON COLUMN public.talent_transactions.source
  IS 'admin = 관리자/RPC 지급, qr = QR 수령';

ALTER TABLE public.talent_qr_codes
  ADD COLUMN IF NOT EXISTS target_type text DEFAULT 'student',
  ADD COLUMN IF NOT EXISTS repeat_type text DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS repeat_days integer[] DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS repeat_weeks integer[] DEFAULT NULL;

UPDATE public.talent_qr_codes
SET target_type = 'student'
WHERE target_type IS NULL OR btrim(target_type) = '';

UPDATE public.talent_qr_codes
SET repeat_type = 'none'
WHERE repeat_type IS NULL OR btrim(repeat_type) = '';

COMMENT ON COLUMN public.talent_qr_codes.target_type
  IS '지급 대상: student 또는 teacher';
COMMENT ON COLUMN public.talent_qr_codes.repeat_type
  IS 'none=1회, daily=매일, weekday=요일반복, week_weekday=주차+요일반복';

NOTIFY pgrst, 'reload schema';

COMMIT;
