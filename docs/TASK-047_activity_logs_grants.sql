-- TASK-047: activity_logs INSERT grant/RLS repair
-- Apply in Supabase SQL Editor for the production project.
-- Verified failure before this fix:
--   REST INSERT /activity_logs -> 401 permission denied for table activity_logs

ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS user_name text;
ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS is_acknowledged boolean DEFAULT false;
ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS acknowledged_by text;
ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS acknowledged_at timestamptz;
ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS resolution_note text;
ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;
ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT INSERT ON public.activity_logs TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.activity_logs TO authenticated;

DROP POLICY IF EXISTS logs_insert_public ON public.activity_logs;
CREATE POLICY logs_insert_public
  ON public.activity_logs
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS logs_select_perm ON public.activity_logs;
CREATE POLICY logs_select_perm
  ON public.activity_logs
  FOR SELECT
  TO authenticated
  USING (public.get_permission_rank(public.get_my_role()) >= 100);

DROP POLICY IF EXISTS logs_update_perm ON public.activity_logs;
CREATE POLICY logs_update_perm
  ON public.activity_logs
  FOR UPDATE
  TO authenticated
  USING (public.get_permission_rank(public.get_my_role()) >= 100)
  WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 100);

DROP POLICY IF EXISTS activity_logs_delete ON public.activity_logs;
CREATE POLICY activity_logs_delete
  ON public.activity_logs
  FOR DELETE
  TO authenticated
  USING (public.get_permission_rank(public.get_my_role()) >= 100);

CREATE INDEX IF NOT EXISTS idx_activity_logs_created ON public.activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_level_ack ON public.activity_logs(level, is_acknowledged);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action_created ON public.activity_logs(action, created_at DESC);

NOTIFY pgrst, 'reload schema';
