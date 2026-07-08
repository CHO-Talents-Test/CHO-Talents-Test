-- TASK-068: Product category page and product sort order
-- Purpose:
--   - Add product sort order used by admin/shop.html.
--   - Align product category insert/update/delete permission with the new
--     product category management page: purchase teacher rank 70+.

BEGIN;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0;

UPDATE public.products
SET sort_order = 0
WHERE sort_order IS NULL;

CREATE INDEX IF NOT EXISTS idx_products_category_sort
  ON public.products(category, sort_order, name);

ALTER TABLE public.code_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS code_items_product_category_insert ON public.code_items;
CREATE POLICY code_items_product_category_insert ON public.code_items
  FOR INSERT TO authenticated
  WITH CHECK (
    group_key = 'products.category'
    AND public.get_permission_rank(public.get_my_role()) >= 70
  );

DROP POLICY IF EXISTS code_items_product_category_update ON public.code_items;
CREATE POLICY code_items_product_category_update ON public.code_items
  FOR UPDATE TO authenticated
  USING (
    group_key = 'products.category'
    AND public.get_permission_rank(public.get_my_role()) >= 70
  )
  WITH CHECK (
    group_key = 'products.category'
    AND public.get_permission_rank(public.get_my_role()) >= 70
  );

GRANT INSERT, UPDATE ON public.code_items TO authenticated;

DO $$
BEGIN
  IF to_regclass('public.code_items') IS NOT NULL THEN
    INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
    VALUES
      ('activity_logs.action', 'PRODUCT_CATEGORY_CREATE', '상품 카테고리 등록', 5015, '{"category":"ORDER","emoji":"🏷️"}'),
      ('activity_logs.action', 'PRODUCT_CATEGORY_UPDATE', '상품 카테고리 수정', 5016, '{"category":"ORDER","emoji":"🏷️"}'),
      ('activity_logs.action', 'PRODUCT_CATEGORY_DELETE', '상품 카테고리 삭제', 5017, '{"category":"ORDER","emoji":"🏷️"}'),
      ('activity_logs.action', 'PRODUCT_UPDATE', '상품 수정', 5020, '{"category":"ORDER","emoji":"✏️"}')
    ON CONFLICT (group_key, code_key) DO UPDATE
    SET code_value = EXCLUDED.code_value,
        sort_order = EXCLUDED.sort_order,
        meta = EXCLUDED.meta,
        is_active = true;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
