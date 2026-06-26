/**
 * Talent Module - 달란트 조회/적립/사용 공통 모듈
 * profiles 테이블 기반 (admin_users 사용 안 함)
 */

async function fetchTalentBalance(userId) {
  if (!_sb) return 0;
  const { data, error } = await _sb
    .from('profiles')
    .select('talent_balance')
    .eq('id', userId)
    .single();
  if (error || !data) return 0;
  return data.talent_balance || 0;
}

async function fetchTalentHistory(userId, options = {}) {
  if (!_sb) return { data: [], error: 'Supabase not initialized' };

  let query = _sb.from('talent_transactions').select('*').eq('user_id', userId);

  if (options.type) query = query.eq('type', options.type);
  if (options.dateFrom) query = query.gte('created_at', options.dateFrom);
  if (options.dateTo) query = query.lte('created_at', options.dateTo);

  query = query.order('created_at', { ascending: false });

  if (options.limit) query = query.limit(options.limit);
  if (options.offset) query = query.range(options.offset, options.offset + (options.limit || 50) - 1);

  return await query;
}

async function fetchTalentSummary(userId) {
  if (!_sb) return { earned: 0, used: 0, returned: 0, balance: 0 };

  const [balanceRes, earnRes, useRes] = await Promise.all([
    fetchTalentBalance(userId),
    _sb.from('talent_transactions').select('amount').eq('user_id', userId).eq('type', 'earn'),
    _sb.from('talent_transactions').select('amount, description').eq('user_id', userId).eq('type', 'use')
  ]);

  const earned = (earnRes.data || []).reduce((s, r) => s + r.amount, 0);
  let used = 0, returned = 0;
  (useRes.data || []).forEach(r => {
    if (r.description && r.description.startsWith('반환:')) {
      returned += r.amount;
    } else {
      used += r.amount;
    }
  });

  return { earned, used, returned, balance: balanceRes };
}

async function giveTalent(userId, amount, description, createdBy) {
  if (!_sb) return { success: false, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('give_talent', {
      p_user_id: userId,
      p_amount: amount,
      p_description: description,
      p_created_by: createdBy,
      p_talent_item_id: null
    });
    if (error) {
      await logError('TALENT_GIVE_FAIL', { userId, 금액: amount, description, 오류: error.message });
      return { success: false, error: error.message };
    }
    if (data && data.success === false) {
      await logWarn('TALENT_GIVE_DENIED', { userId, 금액: amount, description, 사유: data.error });
      return data;
    }
    await logInfo('TALENT_GIVE', { userId, 금액: amount, description });
    return data;
  } catch (err) {
    await logError('TALENT_GIVE_ERROR', { userId, 금액: amount, 오류: String(err) });
    return { success: false, error: String(err) };
  }
}

async function giveTalentByItem(userId, talentItemId, createdBy) {
  if (!_sb) return { success: false, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('give_talent', {
      p_user_id: userId,
      p_amount: 0,
      p_description: '',
      p_created_by: createdBy,
      p_talent_item_id: talentItemId,
    });
    if (error) {
      await logError('TALENT_GIVE_ITEM_FAIL', { userId, talentItemId, 오류: error.message });
      return { success: false, error: error.message };
    }
    if (data && data.success === false) {
      await logWarn('TALENT_GIVE_ITEM_DENIED', { userId, talentItemId, 사유: data.error });
      return data;
    }
    await logInfo('TALENT_GIVE_ITEM', { userId, talentItemId, 금액: data?.amount });
    return data;
  } catch (err) {
    await logError('TALENT_GIVE_ITEM_ERROR', { userId, talentItemId, 오류: String(err) });
    return { success: false, error: String(err) };
  }
}

async function fetchTalentItems(targetType) {
  if (!_sb) return { data: [], error: 'Supabase not initialized' };
  let query = _sb.from('talent_items').select('*').eq('is_active', true).order('sort_order');
  if (targetType) query = query.eq('target_type', targetType);
  return await query;
}

async function fetchAllTalentItems() {
  if (!_sb) return { data: [], error: 'Supabase not initialized' };
  return await _sb.from('talent_items').select('*').order('target_type').order('sort_order');
}

async function returnTalent(userId, amount, description, createdBy) {
  if (!_sb) return { success: false, error: 'Supabase not initialized' };
  try {
    const bal = await fetchTalentBalance(userId);
    if (bal < amount) {
      await logWarn('TALENT_RETURN_DENIED', { userId, 금액: amount, balance: bal, 사유: '잔여 달란트 부족' });
      return { success: false, error: `잔여 달란트(${bal})가 부족합니다. 반환 불가` };
    }
    const { data, error } = await _sb.rpc('use_talent', {
      p_user_id: userId,
      p_amount: amount,
      p_description: '반환: ' + description,
      p_created_by: createdBy
    });
    if (error) {
      await logError('TALENT_RETURN_FAIL', { userId, 금액: amount, 오류: error.message });
      return { success: false, error: error.message };
    }
    if (data && data.success === false) {
      await logWarn('TALENT_RETURN_DENIED', { userId, 금액: amount, 사유: data.error });
      return data;
    }
    await logInfo('TALENT_RETURN', { userId, 금액: amount, description });
    return data;
  } catch (err) {
    await logError('TALENT_RETURN_ERROR', { userId, 금액: amount, 오류: String(err) });
    return { success: false, error: String(err) };
  }
}

async function useTalent(userId, amount, description, createdBy) {
  if (!_sb) return { success: false, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('use_talent', {
      p_user_id: userId,
      p_amount: amount,
      p_description: description,
      p_created_by: createdBy
    });
    if (error) {
      await logError('TALENT_USE_FAIL', { userId, 금액: amount, description, 오류: error.message });
      return { success: false, error: error.message };
    }
    if (data && data.success === false) {
      await logWarn('TALENT_USE_DENIED', { userId, 금액: amount, description, 사유: data.error });
      return data;
    }
    await logInfo('TALENT_USE', { userId, 금액: amount, description });
    return data;
  } catch (err) {
    await logError('TALENT_USE_ERROR', { userId, 금액: amount, 오류: String(err) });
    return { success: false, error: String(err) };
  }
}
