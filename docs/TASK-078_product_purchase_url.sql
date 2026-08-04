-- TASK-078: 상품별 외부 구매 URL
-- 상품 구매 화면에는 노출하지 않고, 구매 관리의 상품별 상세에서만 사용한다.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS purchase_url text;

COMMENT ON COLUMN public.products.purchase_url IS '구매 관리 담당자가 상품별 외부 구매처를 확인하기 위한 URL';
