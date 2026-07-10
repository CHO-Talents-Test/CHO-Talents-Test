-- TASK-069: 상품 썸네일/상세 설명 이미지 분리
-- image_url은 상품 구매 카드 썸네일로 유지하고, 상세 모달 설명 아래 이미지는 detail_image_url을 사용한다.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS detail_image_url text;

COMMENT ON COLUMN public.products.image_url IS '상품 구매 카드에 표시되는 썸네일 이미지 URL';
COMMENT ON COLUMN public.products.detail_image_url IS '상품 상세 모달의 설명 아래에 표시되는 상세 설명 이미지 URL';
