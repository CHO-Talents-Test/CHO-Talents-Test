-- ============================================================
-- TASK-097: 로그 진단 보완 및 표시용 한글 라벨 추가
--
-- 목적
--   - 실제 운영 로그에서 누락이 확인된 activity_logs.action 코드의
--     표시용 한글 라벨을 추가한다.
--   - 기존 라벨·정렬 순서·메타데이터는 변경하지 않는다.
--
-- 참고
--   구매 상태 변경 실패의 근본 원인은 이 SQL이 아니라
--   TASK-096_purchase_badge_workflow_permissions.sql의
--   process_product_order(uuid, text) RPC 미적용이다.
-- ============================================================

BEGIN;

INSERT INTO public.code_items (
  group_key,
  code_key,
  code_value,
  sort_order,
  is_active,
  meta
)
VALUES
  ('activity_logs.action', 'PROMISE_REJECTION', '비동기 오류', 12, true, '{"category":"SYSTEM","emoji":"⚠️","source":"TASK-097"}'::jsonb),
  ('activity_logs.action', 'IMAGE_COMPRESS_FAIL', '이미지 압축 실패', 5023, true, '{"category":"ORDER","emoji":"🖼️","source":"TASK-097"}'::jsonb),
  ('activity_logs.action', 'ORDER_STATUS_CHANGE_FAIL', '주문 상태 변경 실패', 5091, true, '{"category":"ORDER","emoji":"⚠️","source":"TASK-097"}'::jsonb),
  ('activity_logs.action', 'ORDER_BULK_DELIVER_ITEM_FAIL', '일괄 상품 지급 항목 실패', 5141, true, '{"category":"ORDER","emoji":"⚠️","source":"TASK-097"}'::jsonb)
ON CONFLICT (group_key, code_key) DO NOTHING;

COMMIT;

-- 적용 후 확인: 아래 네 항목이 모두 한글 라벨로 반환되어야 한다.
-- SELECT code_key, code_value, is_active
-- FROM public.code_items
-- WHERE group_key = 'activity_logs.action'
--   AND code_key IN (
--     'PROMISE_REJECTION',
--     'IMAGE_COMPRESS_FAIL',
--     'ORDER_STATUS_CHANGE_FAIL',
--     'ORDER_BULK_DELIVER_ITEM_FAIL'
--   )
-- ORDER BY code_key;
