-- TASK-040: v3.26.1 DB 수정사항

-- 1. product_orders 테이블의 status CHECK 제약조건에 'cancelled' 추가
ALTER TABLE product_orders DROP CONSTRAINT IF EXISTS product_orders_status_check;
ALTER TABLE product_orders ADD CONSTRAINT product_orders_status_check
  CHECK (status IN ('requested', 'preparing', 'purchased', 'delivered', 'cancelled'));

-- 2. talent_qr_codes 테이블의 talent_item_id UNIQUE 제약조건 제거 (중복 항목 QR 허용)
DO $$
DECLARE
  cname text;
BEGIN
  FOR cname IN
    SELECT constraint_name FROM information_schema.table_constraints
    WHERE table_name = 'talent_qr_codes'
      AND constraint_type = 'UNIQUE'
      AND constraint_name LIKE '%talent_item%'
  LOOP
    EXECUTE 'ALTER TABLE talent_qr_codes DROP CONSTRAINT ' || cname;
  END LOOP;
END $$;

-- 3. talent_items 테이블에 is_quick_button 컬럼 추가 (퀵버튼 기능)
ALTER TABLE talent_items ADD COLUMN IF NOT EXISTS is_quick_button boolean DEFAULT false;
