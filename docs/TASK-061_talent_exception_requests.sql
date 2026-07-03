-- TASK-061: Talent exception request approval flow
-- Purpose:
--   60~89 rank users can request weekly-limit exception talent grants.
--   90+ rank users approve/reject requests. Actual talent is granted by the
--   existing give_talent RPC during approval.

CREATE TABLE IF NOT EXISTS public.talent_exception_requests (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_display_name text,
  department_id uuid REFERENCES public.departments(id),
  talent_item_id uuid NOT NULL REFERENCES public.talent_items(id),
  talent_item_name text,
  amount integer NOT NULL CHECK (amount > 0),
  description text,
  override_reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  requested_by uuid REFERENCES public.profiles(id),
  requested_by_name text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  reviewed_by uuid REFERENCES public.profiles(id),
  reviewed_by_name text,
  reviewed_at timestamptz,
  review_note text,
  approved_transaction_id uuid REFERENCES public.talent_transactions(id)
);

CREATE INDEX IF NOT EXISTS idx_talent_exception_requests_status
  ON public.talent_exception_requests(status, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_talent_exception_requests_user
  ON public.talent_exception_requests(user_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_talent_exception_requests_dept
  ON public.talent_exception_requests(department_id, requested_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_talent_exception_requests_pending_item
  ON public.talent_exception_requests(user_id, talent_item_id)
  WHERE status = 'pending';

ALTER TABLE public.talent_exception_requests ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.talent_exception_requests TO authenticated;

DROP POLICY IF EXISTS talent_exception_requests_select ON public.talent_exception_requests;
CREATE POLICY talent_exception_requests_select
  ON public.talent_exception_requests
  FOR SELECT TO authenticated
  USING (
    public.get_permission_rank(auth.uid()) >= 80
    OR (
      public.get_permission_rank(auth.uid()) >= 60
      AND (
        requested_by = auth.uid()
        OR department_id = (
          SELECT COALESCE(p.managed_dept_id, p.department_id)
          FROM public.profiles p
          WHERE p.id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS talent_exception_requests_insert ON public.talent_exception_requests;
CREATE POLICY talent_exception_requests_insert
  ON public.talent_exception_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    public.get_permission_rank(auth.uid()) >= 60
    AND status = 'pending'
    AND requested_by = auth.uid()
    AND (
      public.get_permission_rank(auth.uid()) >= 80
      OR department_id = (
        SELECT COALESCE(p.managed_dept_id, p.department_id)
        FROM public.profiles p
        WHERE p.id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS talent_exception_requests_update ON public.talent_exception_requests;
CREATE POLICY talent_exception_requests_update
  ON public.talent_exception_requests
  FOR UPDATE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 90)
  WITH CHECK (public.get_permission_rank(auth.uid()) >= 90);
