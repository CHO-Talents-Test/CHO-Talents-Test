/**
 * Product Module - 달란트 상품 조회/관리 모듈
 */

async function fetchProducts(targetRole, options = {}) {
  if (!_sb) return { data: [], error: 'Supabase not initialized' };

  let query = _sb.from('products').select('*');

  if (targetRole) query = query.eq('target_role', targetRole);
  if (options.activeOnly !== false) query = query.eq('is_active', true);
  if (options.category) query = query.eq('category', options.category);

  query = query.order('category').order('created_at', { ascending: false });
  return await query;
}

function getProductTargetLabel(targetRole) {
  return (typeof getCodeLabel === 'function')
    ? getCodeLabel('products.target_role', targetRole, targetRole)
    : (targetRole === 'teacher' ? '교사' : targetRole === 'student' ? '학생' : targetRole);
}

function getProductCategoryLabel(category) {
  if (!category) return '기타';
  return (typeof getCodeLabel === 'function')
    ? getCodeLabel('products.category', category, category)
    : category;
}

function renderProductCategoryOptions(selectedValue) {
  const selected = selectedValue || 'etc';
  if (typeof renderCodeOptions === 'function') {
    const base = renderCodeOptions('products.category', { selected });
    if (selected && typeof getCodeItem === 'function' && !getCodeItem('products.category', selected)) {
      return `<option value="${selected}" selected>${selected}</option>` + base;
    }
    return base;
  }
  const fallback = [
    ['stationery', '학용품'],
    ['snack', '간식'],
    ['toy', '장난감'],
    ['book', '도서'],
    ['gift', '선물'],
    ['etc', '기타']
  ];
  const base = fallback.map(([value, label]) => `<option value="${value}" ${value === selected ? 'selected' : ''}>${label}</option>`).join('');
  return fallback.some(([value]) => value === selected) ? base : `<option value="${selected}" selected>${selected}</option>` + base;
}

function normalizeProductCategoryLabel(label) {
  return String(label || '').trim().replace(/\s+/g, ' ');
}

function getProductCategoryItems(options = {}) {
  if (typeof getCodeItems === 'function') {
    return getCodeItems('products.category', options);
  }
  return [
    { key: 'stationery', value: '학용품', emoji: '✏️', order: 10 },
    { key: 'snack', value: '간식', emoji: '🍬', order: 20 },
    { key: 'toy', value: '장난감', emoji: '🧸', order: 30 },
    { key: 'book', value: '도서', emoji: '📚', order: 40 },
    { key: 'gift', value: '선물', emoji: '🎁', order: 50 },
    { key: 'etc', value: '기타', emoji: '📦', order: 999 }
  ];
}

function getProductCategoryByLabel(label) {
  const normalized = normalizeProductCategoryLabel(label).toLocaleLowerCase('ko-KR');
  if (!normalized) return null;
  return getProductCategoryItems({ includeInactive: true }).find(item =>
    normalizeProductCategoryLabel(item.value || item.code_value || item.key).toLocaleLowerCase('ko-KR') === normalized
  ) || null;
}

function makeProductCategoryKey(label) {
  const asciiKey = normalizeProductCategoryLabel(label)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
  const base = asciiKey.length >= 2
    ? asciiKey
    : `custom_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 5)}`;
  const existing = new Set(getProductCategoryItems({ includeInactive: true }).map(item => item.key));
  let key = base;
  let seq = 2;
  while (existing.has(key)) {
    key = `${base}_${seq}`;
    seq += 1;
  }
  return key;
}

function getNextProductCategoryOrder() {
  const orders = getProductCategoryItems({ includeInactive: true })
    .map(item => Number(item.order ?? item.sort_order))
    .filter(order => Number.isFinite(order) && order > 0 && order < 900);
  return orders.length ? Math.max(...orders) + 10 : 60;
}

function upsertLocalProductCategory(item) {
  if (!window.CODE_ITEMS) window.CODE_ITEMS = {};
  if (!window.CODE_ITEMS['products.category']) window.CODE_ITEMS['products.category'] = [];
  const items = window.CODE_ITEMS['products.category'];
  const idx = items.findIndex(x => x.key === item.key || x.code_key === item.key);
  if (idx >= 0) items[idx] = Object.assign({}, items[idx], item);
  else items.push(item);
}

function productCategoryRowToItem(row) {
  const meta = row.meta || {};
  return Object.assign({}, meta, {
    key: row.code_key,
    value: row.code_value,
    order: row.sort_order,
    is_active: row.is_active
  });
}

async function createProductCategory(categoryData) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  const label = normalizeProductCategoryLabel(categoryData && categoryData.label);
  if (!label) return { data: null, error: '카테고리명을 입력해주세요.' };

  const existing = getProductCategoryByLabel(label);
  if (existing) return { data: existing, error: null, existing: true };

  const emoji = normalizeProductCategoryLabel(categoryData && categoryData.emoji) || '🏷️';
  const key = makeProductCategoryKey(label);
  const row = {
    group_key: 'products.category',
    code_key: key,
    code_value: label,
    sort_order: getNextProductCategoryOrder(),
    is_active: true,
    meta: { emoji, source: 'admin_shop_modal' }
  };

  try {
    const { data, error } = await _sb
      .from('code_items')
      .insert(row)
      .select('group_key, code_key, code_value, sort_order, is_active, meta')
      .single();
    if (error) {
      await logError('PRODUCT_CATEGORY_CREATE_FAIL', { 카테고리: label, 코드: key, 오류: error.message });
      return { data: null, error: error.message };
    }
    const item = productCategoryRowToItem(data || row);
    upsertLocalProductCategory(item);
    await logInfo('PRODUCT_CATEGORY_CREATE', { 카테고리: label, 코드: key });
    return { data: item, error: null, existing: false };
  } catch (err) {
    await logError('PRODUCT_CATEGORY_CREATE_ERROR', { 카테고리: label, 오류: String(err) });
    return { data: null, error: String(err) };
  }
}

async function createProduct(productData) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.from('products').insert(productData).select();
    if (error) {
      await logError('PRODUCT_CREATE_FAIL', { 오류: error.message });
      return { data: null, error: error.message };
    }
    await logInfo('PRODUCT_CREATE', { 상품명: productData.name });
    return { data: data[0], error: null };
  } catch (err) {
    await logError('PRODUCT_CREATE_ERROR', { 오류: String(err) });
    return { data: null, error: String(err) };
  }
}

async function updateProduct(id, updates) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.from('products').update(updates).eq('id', id).select();
    if (error) {
      await logError('PRODUCT_UPDATE_FAIL', { id, 오류: error.message });
      return { data: null, error: error.message };
    }
    await logInfo('PRODUCT_UPDATE', { id, 상품명: updates.name });
    return { data: data[0], error: null };
  } catch (err) {
    await logError('PRODUCT_UPDATE_ERROR', { id, 오류: String(err) });
    return { data: null, error: String(err) };
  }
}

async function uploadProductImage(file) {
  if (!_sb) return { url: null, error: 'Supabase not initialized' };
  try {
    const ext = file.name.split('.').pop().toLowerCase();
    const fileName = `product_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`;
    const { data, error } = await _sb.storage.from('Talents_Items').upload(fileName, file, {
      cacheControl: '3600',
      upsert: false
    });
    if (error) {
      await logError('IMAGE_UPLOAD_FAIL', { 오류: error.message });
      return { url: null, error: error.message };
    }
    const { data: urlData } = _sb.storage.from('Talents_Items').getPublicUrl(data.path);
    await logInfo('IMAGE_UPLOAD', { path: data.path });
    return { url: urlData.publicUrl, error: null };
  } catch (err) {
    await logError('IMAGE_UPLOAD_ERROR', { 오류: String(err) });
    return { url: null, error: String(err) };
  }
}

async function deleteProductImage(imageUrl) {
  if (!_sb || !imageUrl) return;
  try {
    const path = imageUrl.split('/Talents_Items/').pop();
    if (path) await _sb.storage.from('Talents_Items').remove([path]);
  } catch (err) {
    logWarn('IMAGE_DELETE_FAIL', { imageUrl, 오류: String(err) });
  }
}

async function deleteProduct(id) {
  if (!_sb) return { error: 'Supabase not initialized' };
  try {
    const { error } = await _sb.from('products').delete().eq('id', id);
    if (error) {
      if (/foreign key|violates|referenced/i.test(error.message)) {
        return { error: error.message, fkConflict: true };
      }
      await logError('PRODUCT_DELETE_FAIL', { id, 오류: error.message });
      return { error: error.message };
    }
    await logInfo('PRODUCT_DELETE', { id });
    return { error: null };
  } catch (err) {
    await logError('PRODUCT_DELETE_ERROR', { id, 오류: String(err) });
    return { error: String(err) };
  }
}

async function deactivateProduct(id) {
  if (!_sb) return { error: 'Supabase not initialized' };
  try {
    const { error } = await _sb.from('products').update({ is_active: false }).eq('id', id);
    if (error) {
      await logError('PRODUCT_DEACTIVATE_FAIL', { id, 오류: error.message });
      return { error: error.message };
    }
    await logInfo('PRODUCT_DEACTIVATE', { id });
    return { error: null };
  } catch (err) {
    await logError('PRODUCT_DEACTIVATE_ERROR', { id, 오류: String(err) });
    return { error: String(err) };
  }
}
