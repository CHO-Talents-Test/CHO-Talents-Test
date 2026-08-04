-- ============================================================
-- TASK-088: 상품 추천 채택 보상 및 채택 상품 순번 정책
-- - 채택된 상품 추천의 등록자에게 건별 1달란트를 자동 지급한다.
-- - 학생/교사 등록자 모두를 지원하기 위해 대상별 '상품 추천 채택' 항목을 유지한다.
-- - 추천 건 단위 보상 원장을 둬 재시도·동시 요청에도 중복 지급하지 않는다.
-- - 채택으로 생성되는 상품은 관리자가 검토하기 전까지 순번 999, 가격 0, 비활성 상태로 둔다.
-- ============================================================

BEGIN;

INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
VALUES
  ('talent_transactions.source', 'product_suggestion_adoption', '상품 추천 채택 보상', 40, '{"emoji":"💡"}'),
  ('activity_logs.action', 'PRODUCT_SUGGESTION_ADOPTION_TALENT', '상품 추천 채택 달란트 지급', 5156, '{"category":"ORDER","emoji":"💰"}')
ON CONFLICT (group_key, code_key) DO UPDATE
SET code_value = EXCLUDED.code_value,
    sort_order = EXCLUDED.sort_order,
    meta = EXCLUDED.meta,
    is_active = true,
    updated_at = now();

INSERT INTO public.talent_items (
  name, emoji, target_type, talent_amount, is_active, sort_order,
  is_quick_button, giving_rule, giving_description
)
VALUES
  ('상품 추천 채택', '💡', 'student', 1, true, 999, false, '채택 건별 자동 지급', '등록한 상품 추천이 채택될 때마다 1달란트가 자동 지급됩니다.'),
  ('상품 추천 채택', '💡', 'teacher', 1, true, 999, false, '채택 건별 자동 지급', '등록한 상품 추천이 채택될 때마다 1달란트가 자동 지급됩니다.')
ON CONFLICT (target_type, name) DO UPDATE
SET emoji = EXCLUDED.emoji,
    talent_amount = EXCLUDED.talent_amount,
    is_active = true,
    sort_order = EXCLUDED.sort_order,
    is_quick_button = EXCLUDED.is_quick_button,
    giving_rule = EXCLUDED.giving_rule,
    giving_description = EXCLUDED.giving_description;

CREATE TABLE IF NOT EXISTS public.product_suggestion_adoption_rewards (
  suggestion_id uuid PRIMARY KEY REFERENCES public.product_suggestions(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  talent_item_id uuid NOT NULL REFERENCES public.talent_items(id) ON DELETE RESTRICT,
  transaction_id uuid UNIQUE REFERENCES public.talent_transactions(id) ON DELETE RESTRICT,
  granted_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.product_suggestion_adoption_rewards ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.product_suggestion_adoption_rewards FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public._grant_product_suggestion_adoption_talent(
  p_suggestion_id uuid,
  p_actor_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_suggestion public.product_suggestions%ROWTYPE;
  v_recipient_type text;
  v_current_balance integer;
  v_new_balance integer;
  v_talent_item_id uuid;
  v_amount integer;
  v_reward_suggestion_id uuid;
  v_transaction_id uuid;
  v_actor_username text;
  v_actor_name text;
BEGIN
  SELECT * INTO v_suggestion
  FROM public.product_suggestions
  WHERE id = p_suggestion_id;

  IF NOT FOUND OR v_suggestion.suggested_by IS NULL THEN
    RAISE EXCEPTION '상품 추천 등록자를 찾을 수 없습니다.';
  END IF;

  SELECT user_type, COALESCE(talent_balance, 0)
  INTO v_recipient_type, v_current_balance
  FROM public.profiles
  WHERE id = v_suggestion.suggested_by
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '상품 추천 등록자 프로필을 찾을 수 없습니다.';
  END IF;

  SELECT id, talent_amount
  INTO v_talent_item_id, v_amount
  FROM public.talent_items
  WHERE name = '상품 추천 채택'
    AND target_type = v_recipient_type
    AND is_active = true
  ORDER BY sort_order, id
  LIMIT 1;

  IF v_talent_item_id IS NULL THEN
    RAISE EXCEPTION '상품 추천 채택 달란트 항목이 활성화되어 있지 않습니다.';
  END IF;

  -- suggestion_id의 PK가 지급 단위이다. 이미 보상된 추천은 잔액이나 거래를 다시 만들지 않는다.
  INSERT INTO public.product_suggestion_adoption_rewards (
    suggestion_id, recipient_id, talent_item_id, granted_by
  ) VALUES (
    p_suggestion_id, v_suggestion.suggested_by, v_talent_item_id, p_actor_id
  )
  ON CONFLICT (suggestion_id) DO NOTHING
  RETURNING suggestion_id INTO v_reward_suggestion_id;

  IF v_reward_suggestion_id IS NULL THEN
    RETURN json_build_object('rewarded', false, 'reason', 'already_rewarded');
  END IF;

  v_new_balance := v_current_balance + v_amount;
  UPDATE public.profiles
  SET talent_balance = v_new_balance,
      updated_at = now()
  WHERE id = v_suggestion.suggested_by;

  INSERT INTO public.talent_transactions (
    user_id, type, amount, balance_after, description, created_by,
    talent_item_id, source, override_week_limit, override_reason
  ) VALUES (
    v_suggestion.suggested_by, 'earn', v_amount, v_new_balance, '상품 추천 채택', p_actor_id,
    v_talent_item_id, 'product_suggestion_adoption', false, NULL
  )
  RETURNING id INTO v_transaction_id;

  UPDATE public.product_suggestion_adoption_rewards
  SET transaction_id = v_transaction_id
  WHERE suggestion_id = p_suggestion_id;

  SELECT COALESCE(username, '시스템'), COALESCE(display_name, username, '시스템')
  INTO v_actor_username, v_actor_name
  FROM public.profiles
  WHERE id = p_actor_id;

  INSERT INTO public.activity_logs (level, action, page, details, username, user_name)
  VALUES (
    'INFO',
    'PRODUCT_SUGGESTION_ADOPTION_TALENT',
    'product_suggestion_votes',
    jsonb_build_object(
      'targetType', '상품 추천',
      'targetId', p_suggestion_id,
      'targetName', v_suggestion.name,
      'talentItem', '상품 추천 채택',
      'amount', v_amount,
      'source', 'product_suggestion_adoption',
      'changeSummary', '추천 등록자에게 상품 추천 채택 ' || v_amount || '달란트 자동 지급'
    ),
    COALESCE(v_actor_username, '시스템'),
    COALESCE(v_actor_name, '시스템')
  );

  RETURN json_build_object(
    'rewarded', true,
    'amount', v_amount,
    'talent_item_name', '상품 추천 채택',
    'transaction_id', v_transaction_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._resolve_product_suggestion(
  p_suggestion_id uuid,
  p_status text,
  p_actor_id uuid,
  p_resolution_basis text,
  p_current_electorate integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_suggestion public.product_suggestions%ROWTYPE;
  v_product_id uuid;
BEGIN
  IF p_status NOT IN ('adopted', 'rejected') THEN
    RAISE EXCEPTION 'invalid resolution status';
  END IF;

  SELECT * INTO v_suggestion
  FROM public.product_suggestions
  WHERE id = p_suggestion_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'product suggestion not found';
  END IF;

  IF v_suggestion.status <> 'voting' THEN
    RETURN v_suggestion.adopted_product_id;
  END IF;

  IF p_status = 'adopted' THEN
    INSERT INTO public.products (
      name, description, price, image_emoji, image_url, detail_image_url,
      purchase_url, target_role, category, sort_order, stock, is_active, created_by
    ) VALUES (
      v_suggestion.name, v_suggestion.description, 0, '🎁', v_suggestion.image_url,
      v_suggestion.detail_image_url, v_suggestion.product_url, 'student',
      COALESCE(NULLIF(BTRIM(v_suggestion.category), ''), 'gift'), 999, 0, false,
      v_suggestion.suggested_by
    )
    RETURNING id INTO v_product_id;

    PERFORM public._grant_product_suggestion_adoption_talent(p_suggestion_id, p_actor_id);
  END IF;

  UPDATE public.product_suggestions
  SET status = p_status,
      adopted_product_id = CASE WHEN p_status = 'adopted' THEN v_product_id ELSE NULL END,
      resolved_by = p_actor_id,
      resolved_at = now(),
      resolution_basis = p_resolution_basis,
      current_electorate_at_resolution = p_current_electorate,
      updated_at = now()
  WHERE id = p_suggestion_id;

  RETURN v_product_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public._grant_product_suggestion_adoption_talent(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._resolve_product_suggestion(uuid, text, uuid, text, integer)
  FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
