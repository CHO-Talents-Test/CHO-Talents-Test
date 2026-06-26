-- ============================================================
-- TASK-045: department_transfer_requests API/RLS repair
-- Purpose: expose the department transfer request table through
--          Supabase REST and refresh the PostgREST schema cache.
-- Run in Supabase SQL Editor or through the Management API.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.department_transfer_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  username TEXT NOT NULL,
  display_name TEXT,
  from_department_id UUID REFERENCES public.departments(id),
  to_department_id UUID NOT NULL REFERENCES public.departments(id),
  requested_by TEXT NOT NULL,
  request_reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  reviewed_by TEXT,
  review_note TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.department_transfer_requests
  ADD COLUMN IF NOT EXISTS user_id UUID,
  ADD COLUMN IF NOT EXISTS username TEXT,
  ADD COLUMN IF NOT EXISTS display_name TEXT,
  ADD COLUMN IF NOT EXISTS from_department_id UUID,
  ADD COLUMN IF NOT EXISTS to_department_id UUID,
  ADD COLUMN IF NOT EXISTS requested_by TEXT,
  ADD COLUMN IF NOT EXISTS request_reason TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS reviewed_by TEXT,
  ADD COLUMN IF NOT EXISTS review_note TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'department_transfer_requests_status_check'
      AND conrelid = 'public.department_transfer_requests'::regclass
  ) THEN
    ALTER TABLE public.department_transfer_requests
      ADD CONSTRAINT department_transfer_requests_status_check
      CHECK (status IN ('pending', 'approved', 'rejected'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_department_transfer_requests_status
  ON public.department_transfer_requests(status);

CREATE INDEX IF NOT EXISTS idx_department_transfer_requests_created_at
  ON public.department_transfer_requests(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_department_transfer_requests_user_id
  ON public.department_transfer_requests(user_id);

ALTER TABLE public.department_transfer_requests ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.department_transfer_requests TO authenticated;

DROP POLICY IF EXISTS dept_transfer_select ON public.department_transfer_requests;
CREATE POLICY dept_transfer_select
  ON public.department_transfer_requests
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS dept_transfer_insert ON public.department_transfer_requests;
CREATE POLICY dept_transfer_insert
  ON public.department_transfer_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    COALESCE((
      SELECT public.get_permission_rank(p.permission_level)
      FROM public.profiles p
      WHERE p.id = auth.uid()
    ), 0) >= 60
  );

DROP POLICY IF EXISTS dept_transfer_update ON public.department_transfer_requests;
CREATE POLICY dept_transfer_update
  ON public.department_transfer_requests
  FOR UPDATE
  TO authenticated
  USING (
    COALESCE((
      SELECT public.get_permission_rank(p.permission_level)
      FROM public.profiles p
      WHERE p.id = auth.uid()
    ), 0) >= 80
  )
  WITH CHECK (
    COALESCE((
      SELECT public.get_permission_rank(p.permission_level)
      FROM public.profiles p
      WHERE p.id = auth.uid()
    ), 0) >= 80
  );

DROP POLICY IF EXISTS dept_transfer_delete ON public.department_transfer_requests;
CREATE POLICY dept_transfer_delete
  ON public.department_transfer_requests
  FOR DELETE
  TO authenticated
  USING (
    COALESCE((
      SELECT public.get_permission_rank(p.permission_level)
      FROM public.profiles p
      WHERE p.id = auth.uid()
    ), 0) >= 90
  );

NOTIFY pgrst, 'reload schema';
