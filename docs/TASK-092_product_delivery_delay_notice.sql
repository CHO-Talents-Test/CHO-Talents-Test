-- TASK-092: 상품 배송 지연 안내 표시 여부
-- 상품 관리에서 선택한 안내 문구를 상품 구매 카드와 상세 모달에 표시합니다.

BEGIN;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS show_delivery_delay_notice boolean NOT NULL DEFAULT false;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS actual_purchase_price integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.products.show_delivery_delay_notice IS
  '상품 구매 화면에 배송 지연 안내를 표시할지 여부';

COMMENT ON COLUMN public.products.actual_purchase_price IS
  '관리용 실제 상품 구매 가격(원). 사용자 상품 구매 화면에는 노출하지 않음';

COMMIT;
