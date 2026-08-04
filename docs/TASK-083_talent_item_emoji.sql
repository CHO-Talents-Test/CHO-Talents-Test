-- ============================================================
-- TASK-083: 달란트 항목 안내 카드 이모지
-- 적용 대상: 기존 운영 Supabase Database
-- ============================================================

-- 1. 달란트 항목별 카드 이모지 저장 컬럼 추가
ALTER TABLE public.talent_items
  ADD COLUMN IF NOT EXISTS emoji text;

-- 2. 기존 안내 카드와 같은 이모지로 보정하고, 그 외 항목은 기본 이모지를 설정
UPDATE public.talent_items
SET emoji = CASE
  WHEN name = '주일 어린이예배' THEN '⛪'
  WHEN name IN ('토요일 센터(SGS기간)', '토요일 센터 (SGS기간)') THEN '📚'
  WHEN name = '매주 말씀암송' THEN '✍️'
  WHEN name = '미션북 시상' THEN '🏆'
  WHEN name = '예배 태도' THEN '🙏'
  WHEN name = '전도/새신자' THEN '🤝'
  WHEN name = '주일 아침기도회' THEN '🌅'
  WHEN name IN ('WAY MAKER 기도회', '웨이메이커 기도회') THEN '🔥'
  WHEN name = '초등부 기도회' THEN '🙏'
  WHEN name IN ('교회행사', '교회 행사') THEN '🎉'
  WHEN name = '월례회' THEN '📋'
  ELSE '✨'
END
WHERE emoji IS NULL OR btrim(emoji) = '';

-- 3. 이후 등록 항목에도 기본값을 제공하고 빈 값이 저장되지 않도록 설정
ALTER TABLE public.talent_items
  ALTER COLUMN emoji SET DEFAULT '✨';

ALTER TABLE public.talent_items
  ALTER COLUMN emoji SET NOT NULL;

COMMENT ON COLUMN public.talent_items.emoji IS '달란트 적립 안내 카드에 표시할 이모지';
