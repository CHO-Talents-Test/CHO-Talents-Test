-- ============================================================
-- TASK-059: Announcements
-- Adds operator-managed announcements and per-user dismissals.
-- Run in Supabase SQL Editor or through the Management API.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.announcements (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  title text NOT NULL CHECK (char_length(trim(title)) > 0 AND char_length(title) <= 200),
  content text NOT NULL CHECK (char_length(trim(content)) > 0),
  is_active boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_by_name text,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.announcement_dismissals (
  announcement_id uuid NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  dismissed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (announcement_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_announcements_active_created
  ON public.announcements(is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcement_dismissals_user
  ON public.announcement_dismissals(user_id, announcement_id);

DROP TRIGGER IF EXISTS trg_announcements_updated_at ON public.announcements;
CREATE TRIGGER trg_announcements_updated_at
  BEFORE UPDATE ON public.announcements
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_dismissals ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.announcements TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.announcement_dismissals TO authenticated;

DO $$
BEGIN
  IF to_regclass('public.code_items') IS NOT NULL THEN
    INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
    VALUES
      ('activity_logs.action', 'ANNOUNCEMENT_CREATE', '공지 등록', 9040, '{"category":"PERM","emoji":"📢"}'),
      ('activity_logs.action', 'ANNOUNCEMENT_UPDATE', '공지 수정', 9050, '{"category":"PERM","emoji":"📢"}'),
      ('activity_logs.action', 'ANNOUNCEMENT_TOGGLE', '공지 활성 토글', 9060, '{"category":"PERM","emoji":"🔘"}'),
      ('activity_logs.action', 'ANNOUNCEMENT_DISMISS', '공지 다시 열지 않음', 9070, '{"category":"PERM","emoji":"🚫"}')
    ON CONFLICT (group_key, code_key) DO UPDATE
    SET code_value = EXCLUDED.code_value,
        sort_order = EXCLUDED.sort_order,
        meta = EXCLUDED.meta,
        is_active = true;
  END IF;
END $$;

DROP POLICY IF EXISTS announcements_select ON public.announcements;
CREATE POLICY announcements_select ON public.announcements
  FOR SELECT TO authenticated
  USING (
    is_active = true
    OR public.get_permission_rank(auth.uid()) >= 90
  );

DROP POLICY IF EXISTS announcements_insert ON public.announcements;
CREATE POLICY announcements_insert ON public.announcements
  FOR INSERT TO authenticated
  WITH CHECK (public.get_permission_rank(auth.uid()) >= 90);

DROP POLICY IF EXISTS announcements_update ON public.announcements;
CREATE POLICY announcements_update ON public.announcements
  FOR UPDATE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 90)
  WITH CHECK (public.get_permission_rank(auth.uid()) >= 90);

DROP POLICY IF EXISTS announcements_delete ON public.announcements;
CREATE POLICY announcements_delete ON public.announcements
  FOR DELETE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 100);

DROP POLICY IF EXISTS announcement_dismissals_select_own ON public.announcement_dismissals;
CREATE POLICY announcement_dismissals_select_own ON public.announcement_dismissals
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS announcement_dismissals_insert_own ON public.announcement_dismissals;
CREATE POLICY announcement_dismissals_insert_own ON public.announcement_dismissals
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS announcement_dismissals_delete_own ON public.announcement_dismissals;
CREATE POLICY announcement_dismissals_delete_own ON public.announcement_dismissals
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

COMMIT;
