-- TASK-041: Fix give_talent RPC weekly item limit without creating overloads.
-- Root cause:
--   A previous migration created public.give_talent(uuid, uuid, uuid).
--   The app also uses public.give_talent(uuid, integer, text, uuid, uuid).
--   PostgREST can become ambiguous when both signatures exist.

BEGIN;

DROP FUNCTION IF EXISTS public.give_talent(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.give_talent(uuid, integer, text, uuid);

CREATE OR REPLACE FUNCTION public.give_talent(
  p_user_id uuid,
  p_amount integer DEFAULT 0,
  p_description text DEFAULT '',
  p_created_by uuid DEFAULT NULL,
  p_talent_item_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance integer;
  v_txn_id uuid;
  v_caller_perm text;
  v_caller_rank integer;
  v_caller_dept uuid;
  v_caller_class integer;
  v_caller_managed_dept uuid;
  v_target_type text;
  v_target_dept uuid;
  v_target_class integer;
  v_item record;
  v_actual_amount integer;
  v_actual_desc text;
  v_week_count integer;
BEGIN
  SELECT permission_level, department_id, class_number, managed_dept_id
  INTO v_caller_perm, v_caller_dept, v_caller_class, v_caller_managed_dept
  FROM public.profiles
  WHERE id = auth.uid();

  v_caller_rank := public.get_permission_rank(v_caller_perm);
  IF v_caller_perm IS NULL OR v_caller_rank < 40 THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT user_type, department_id, class_number
  INTO v_target_type, v_target_dept, v_target_class
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_target_type IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_caller_rank = 40 THEN
    IF v_caller_dept IS NULL
       OR v_caller_dept != v_target_dept
       OR v_caller_class IS DISTINCT FROM v_target_class THEN
      RETURN json_build_object('success', false, 'error', 'You can only give talents to students in your class');
    END IF;
  ELSIF v_caller_rank >= 60 AND v_caller_rank < 90 THEN
    IF v_caller_managed_dept IS NULL OR v_caller_managed_dept != v_target_dept THEN
      RETURN json_build_object('success', false, 'error', 'You can only give talents to users in your managed department');
    END IF;
  END IF;

  IF p_talent_item_id IS NOT NULL THEN
    SELECT * INTO v_item
    FROM public.talent_items
    WHERE id = p_talent_item_id AND is_active = true;

    IF v_item IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Invalid or inactive talent item');
    END IF;

    IF v_item.target_type IS NOT NULL AND v_item.target_type <> v_target_type THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Item target type mismatch: ' || v_item.target_type || ' vs ' || v_target_type
      );
    END IF;

    v_actual_amount := v_item.talent_amount;
    v_actual_desc := v_item.name;

    SELECT count(*) INTO v_week_count
    FROM public.talent_transactions
    WHERE user_id = p_user_id
      AND talent_item_id = p_talent_item_id
      AND type = 'earn'
      AND created_at >= date_trunc('week', now() AT TIME ZONE 'Asia/Seoul')
      AND created_at < date_trunc('week', now() AT TIME ZONE 'Asia/Seoul') + interval '7 days';

    IF v_week_count > 0 THEN
      RETURN json_build_object('success', false, 'error', 'Already given this item this week: ' || v_item.name);
    END IF;
  ELSE
    IF p_amount <= 0 THEN
      RETURN json_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    v_actual_amount := p_amount;
    v_actual_desc := COALESCE(NULLIF(p_description, ''), 'Manual');
  END IF;

  UPDATE public.profiles
  SET talent_balance = COALESCE(talent_balance, 0) + v_actual_amount
  WHERE id = p_user_id
  RETURNING talent_balance INTO v_new_balance;

  INSERT INTO public.talent_transactions (
    user_id, type, amount, balance_after, description, created_by, talent_item_id
  ) VALUES (
    p_user_id, 'earn', v_actual_amount, v_new_balance, v_actual_desc,
    COALESCE(p_created_by, auth.uid()), p_talent_item_id
  )
  RETURNING id INTO v_txn_id;

  RETURN json_build_object('success', true, 'balance', v_new_balance, 'txn_id', v_txn_id, 'amount', v_actual_amount);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.give_talent(uuid, integer, text, uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
