-- TASK-058: 상품 등록 모달에서 상품 카테고리 추가 허용
-- - 상품 관리는 60등급 이상이 사용하므로 products.category 코드만 60등급 이상 INSERT 가능하게 확장
-- - 전체 코드 마스터 관리(code_groups/code_items 전체 수정)는 기존 100등급 정책을 유지

BEGIN;

ALTER TABLE public.code_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS code_items_product_category_insert ON public.code_items;
CREATE POLICY code_items_product_category_insert ON public.code_items
  FOR INSERT TO authenticated
  WITH CHECK (
    group_key = 'products.category'
    AND public.get_permission_rank(public.get_my_role()) >= 60
  );

GRANT INSERT ON public.code_items TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
