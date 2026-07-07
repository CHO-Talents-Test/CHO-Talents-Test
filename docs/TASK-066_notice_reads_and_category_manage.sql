-- TASK-066: Product category management and announcement read status
-- Purpose:
--   - Allow 60+ product managers to update/delete(soft-disable) product categories.
--   - Allow 90+ notice managers to view announcement dismissal rows for read-status reports.

BEGIN;

ALTER TABLE public.code_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_dismissals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS code_items_product_category_update ON public.code_items;
CREATE POLICY code_items_product_category_update ON public.code_items
  FOR UPDATE TO authenticated
  USING (
    group_key = 'products.category'
    AND public.get_permission_rank(public.get_my_role()) >= 60
  )
  WITH CHECK (
    group_key = 'products.category'
    AND public.get_permission_rank(public.get_my_role()) >= 60
  );

DROP POLICY IF EXISTS announcement_dismissals_select_manager ON public.announcement_dismissals;
CREATE POLICY announcement_dismissals_select_manager ON public.announcement_dismissals
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id
    OR public.get_permission_rank(auth.uid()) >= 90
  );

GRANT UPDATE ON public.code_items TO authenticated;
GRANT SELECT ON public.announcement_dismissals TO authenticated;

DO $$
BEGIN
  IF to_regclass('public.code_items') IS NOT NULL THEN
    INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
    VALUES
      ('activity_logs.action', 'PRODUCT_CATEGORY_UPDATE', '상품 카테고리 수정', 5016, '{"category":"ORDER","emoji":"🏷️"}'),
      ('activity_logs.action', 'PRODUCT_CATEGORY_DELETE', '상품 카테고리 삭제', 5017, '{"category":"ORDER","emoji":"🏷️"}'),
      ('activity_logs.action', 'ANNOUNCEMENT_READ_STATUS_VIEW', '공지 열람 현황 조회', 9085, '{"category":"PERM","emoji":"👁️"}')
    ON CONFLICT (group_key, code_key) DO UPDATE
    SET code_value = EXCLUDED.code_value,
        sort_order = EXCLUDED.sort_order,
        meta = EXCLUDED.meta,
        is_active = true;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
