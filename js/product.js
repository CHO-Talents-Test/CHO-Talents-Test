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

function getProductCategoryOrder(category) {
  const key = category || 'etc';
  const item = typeof getCodeItem === 'function' ? getCodeItem('products.category', key) : null;
  const order = Number(item && (item.order ?? item.sort_order));
  return Number.isFinite(order) ? order : (key === 'etc' ? 999 : 9000);
}

function getProductSortOrder(product) {
  const order = Number(product && product.sort_order);
  return Number.isFinite(order) ? order : 0;
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

async function fetchProductCategories(options = {}) {
  if (!_sb) return { data: getProductCategoryItems(options), error: null, fallback: true };
  try {
    let query = _sb
      .from('code_items')
      .select('group_key, code_key, code_value, sort_order, is_active, meta')
      .eq('group_key', 'products.category')
      .order('sort_order', { ascending: true })
      .order('code_value', { ascending: true });
    if (!options.includeInactive) query = query.eq('is_active', true);
    const { data, error } = await query;
    if (error) return { data: getProductCategoryItems(options), error: error.message, fallback: true };
    const items = (data || []).map(productCategoryRowToItem);
    items.forEach(upsertLocalProductCategory);
    return { data: items, error: null, fallback: false };
  } catch (err) {
    return { data: getProductCategoryItems(options), error: String(err), fallback: true };
  }
}

async function createProductCategory(categoryData) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  const label = normalizeProductCategoryLabel(categoryData && categoryData.label);
  if (!label) return { data: null, error: '카테고리명을 입력해주세요.' };

  const existing = getProductCategoryByLabel(label);
  if (existing && existing.is_active === false) {
    const revived = await updateProductCategory(existing.key, {
      label,
      emoji: (categoryData && categoryData.emoji) || existing.emoji,
      sortOrder: (categoryData && categoryData.sortOrder) || existing.order || existing.sort_order
    });
    return Object.assign({}, revived, { existing: true, revived: !revived.error });
  }
  if (existing) return { data: existing, error: null, existing: true };

  const emoji = normalizeProductCategoryLabel(categoryData && categoryData.emoji) || '🏷️';
  const key = makeProductCategoryKey(label);
  const row = {
    group_key: 'products.category',
    code_key: key,
    code_value: label,
    sort_order: Number(categoryData && categoryData.sortOrder) || getNextProductCategoryOrder(),
    is_active: true,
    meta: { emoji, source: 'product_category_management' }
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
    await logInfo('PRODUCT_CATEGORY_CREATE', buildChangeLogDetails({
      targetName: label,
      targetType: '상품 카테고리',
      targetId: key,
      changes: buildChangeSet({}, item)
    }));
    return { data: item, error: null, existing: false };
  } catch (err) {
    await logError('PRODUCT_CATEGORY_CREATE_ERROR', { 카테고리: label, 오류: String(err) });
    return { data: null, error: String(err) };
  }
}

async function updateProductCategory(codeKey, categoryData) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  const key = String(codeKey || '').trim();
  const label = normalizeProductCategoryLabel(categoryData && categoryData.label);
  if (!key) return { data: null, error: '카테고리 코드를 확인할 수 없습니다.' };
  if (!label) return { data: null, error: '카테고리명을 입력해주세요.' };

  const duplicate = getProductCategoryItems({ includeInactive: true }).find(item =>
    item.key !== key &&
    normalizeProductCategoryLabel(item.value || item.code_value || item.key).toLocaleLowerCase('ko-KR') === label.toLocaleLowerCase('ko-KR')
  );
  if (duplicate) return { data: null, error: '같은 이름의 카테고리가 이미 있습니다.' };

  const current = getCodeItem('products.category', key) || {};
  const emoji = normalizeProductCategoryLabel(categoryData && categoryData.emoji) || current.emoji || '🏷️';
  const sortOrder = Number(categoryData && categoryData.sortOrder);
  const row = {
    code_value: label,
    sort_order: Number.isFinite(sortOrder) ? sortOrder : Number(current.order || current.sort_order || getNextProductCategoryOrder()),
    is_active: true,
    meta: Object.assign({}, current.meta || {}, { emoji, source: current.source || 'product_category_management' })
  };

  try {
    const { data, error } = await _sb
      .from('code_items')
      .update(row)
      .eq('group_key', 'products.category')
      .eq('code_key', key)
      .select('group_key, code_key, code_value, sort_order, is_active, meta')
      .single();
    if (error) {
      await logError('PRODUCT_CATEGORY_UPDATE_FAIL', { 카테고리: label, 코드: key, 오류: error.message });
      return { data: null, error: error.message };
    }
    const item = productCategoryRowToItem(data || Object.assign({ group_key: 'products.category', code_key: key }, row));
    upsertLocalProductCategory(item);
    await logInfo('PRODUCT_CATEGORY_UPDATE', buildChangeLogDetails({
      targetName: label,
      targetType: '상품 카테고리',
      targetId: key,
      changes: buildChangeSet(current, item)
    }));
    return { data: item, error: null };
  } catch (err) {
    await logError('PRODUCT_CATEGORY_UPDATE_ERROR', { 카테고리: label, 코드: key, 오류: String(err) });
    return { data: null, error: String(err) };
  }
}

async function getProductCategoryUsageCount(codeKey) {
  if (!_sb || !codeKey) return 0;
  try {
    const { count, error } = await _sb
      .from('products')
      .select('id', { count: 'exact', head: true })
      .eq('category', codeKey);
    if (error) return 0;
    return count || 0;
  } catch (err) {
    return 0;
  }
}

async function deactivateProductCategory(codeKey) {
  if (!_sb) return { error: 'Supabase not initialized' };
  const key = String(codeKey || '').trim();
  if (!key) return { error: '카테고리 코드를 확인할 수 없습니다.' };
  if (key === 'etc') return { error: '기타 카테고리는 기본값이라 삭제할 수 없습니다.' };
  const usageCount = await getProductCategoryUsageCount(key);
  if (usageCount > 0) {
    return { error: `이 카테고리를 사용하는 상품이 ${usageCount}건 있어 삭제할 수 없습니다.` };
  }

  try {
    const { error } = await _sb
      .from('code_items')
      .update({ is_active: false })
      .eq('group_key', 'products.category')
      .eq('code_key', key);
    if (error) {
      await logError('PRODUCT_CATEGORY_DELETE_FAIL', { 코드: key, 오류: error.message });
      return { error: error.message };
    }
    upsertLocalProductCategory({ key, is_active: false });
    await logInfo('PRODUCT_CATEGORY_DELETE', buildChangeLogDetails({
      targetName: (getCodeItem('products.category', key) || {}).value || key,
      targetType: '상품 카테고리',
      targetId: key,
      changes: buildChangeSet({ is_active:true }, { is_active:false }, { fields:['is_active'] })
    }));
    return { error: null };
  } catch (err) {
    await logError('PRODUCT_CATEGORY_DELETE_ERROR', { 코드: key, 오류: String(err) });
    return { error: String(err) };
  }
}

async function createProduct(productData, logContext = {}) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.from('products').insert(productData).select();
    if (error) {
      await logError('PRODUCT_CREATE_FAIL', { 오류: error.message });
      return { data: null, error: error.message };
    }
    const created = data && data[0] ? data[0] : null;
    await logInfo('PRODUCT_CREATE', buildChangeLogDetails({
      targetName: (created && created.name) || productData.name,
      targetType: '상품',
      targetId: created && created.id,
      changes: buildChangeSet({}, created || productData),
      extra: logContext
    }));
    return { data: created, error: null };
  } catch (err) {
    await logError('PRODUCT_CREATE_ERROR', { 오류: String(err) });
    return { data: null, error: String(err) };
  }
}

async function updateProduct(id, updates) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  try {
    const { data: before } = await _sb.from('products').select('*').eq('id', id).maybeSingle();
    const { data, error } = await _sb.from('products').update(updates).eq('id', id).select();
    if (error) {
      await logError('PRODUCT_UPDATE_FAIL', { id, 오류: error.message });
      return { data: null, error: error.message };
    }
    const updated = data && data[0] ? data[0] : null;
    await logInfo('PRODUCT_UPDATE', buildChangeLogDetails({
      targetName: (updated && updated.name) || (before && before.name) || updates.name,
      targetType: '상품',
      targetId: id,
      changes: buildChangeSet(before || {}, updated || updates)
    }));
    return { data: updated, error: null };
  } catch (err) {
    await logError('PRODUCT_UPDATE_ERROR', { id, 오류: String(err) });
    return { data: null, error: String(err) };
  }
}

async function updateProductImageUrl(id, imageUrl, fieldName = 'image_url') {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  const safeField = fieldName === 'detail_image_url' ? 'detail_image_url' : 'image_url';
  try {
    const { data: before } = await _sb.from('products').select('id,name,image_url,detail_image_url').eq('id', id).maybeSingle();
    const { data, error } = await _sb.from('products').update({ [safeField]: imageUrl }).eq('id', id).select();
    if (error) {
      await logError('PRODUCT_IMAGE_UPDATE_FAIL', { id, 필드: safeField, 오류: error.message });
      return { data: null, error: error.message };
    }
    const updated = data && data[0] ? data[0] : null;
    await logInfo('PRODUCT_IMAGE_UPDATE', buildChangeLogDetails({
      targetName: (updated && updated.name) || (before && before.name),
      targetType: '상품',
      targetId: id,
      changes: buildChangeSet(before || {}, updated || { [safeField]: imageUrl }, { fields:[safeField] })
    }));
    return { data: updated, error: null };
  } catch (err) {
    await logError('PRODUCT_IMAGE_UPDATE_ERROR', { id, 필드: safeField, 오류: String(err) });
    return { data: null, error: String(err) };
  }
}

async function uploadProductImage(file, options = {}) {
  if (typeof uploadManagedImage !== 'function') {
    const message = '이미지 업로드 모듈을 불러오지 못했습니다.';
    if (typeof logError === 'function') await logError('IMAGE_UPLOAD_ERROR', { 구분: '상품', 오류: message });
    return { url: null, error: message };
  }
  const opts = (options && typeof options === 'object') ? options : { entityId: options };
  const entityId = opts.entityId || opts.productId || opts.itemId;
  if (!entityId) {
    const message = '상품 ID를 확인한 뒤 이미지를 업로드해주세요.';
    if (typeof logError === 'function') await logError('IMAGE_UPLOAD_ERROR', { 구분: '상품', 오류: message });
    return { url: null, error: message };
  }
  return uploadManagedImage(file, Object.assign({}, opts, {
    folder: opts.folder || 'talent-items',
    prefix: opts.prefix || 'talent_item',
    entityId,
    context: opts.context || '상품'
  }));
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
    const { data: before } = await _sb.from('products').select('*').eq('id', id).maybeSingle();
    const { error } = await _sb.from('products').delete().eq('id', id);
    if (error) {
      if (/foreign key|violates|referenced/i.test(error.message)) {
        return { error: error.message, fkConflict: true };
      }
      await logError('PRODUCT_DELETE_FAIL', { id, 오류: error.message });
      return { error: error.message };
    }
    await logInfo('PRODUCT_DELETE', buildChangeLogDetails({
      targetName: before && before.name,
      targetType: '상품',
      targetId: id,
      changes: buildChangeSet(before || {}, {}, { fields:['name', 'target_role', 'category', 'price', 'actual_purchase_price', 'image_url', 'detail_image_url', 'purchase_url', 'show_delivery_delay_notice', 'description', 'is_active'] })
    }));
    return { error: null };
  } catch (err) {
    await logError('PRODUCT_DELETE_ERROR', { id, 오류: String(err) });
    return { error: String(err) };
  }
}

async function deactivateProduct(id) {
  if (!_sb) return { error: 'Supabase not initialized' };
  try {
    const { data: before } = await _sb.from('products').select('*').eq('id', id).maybeSingle();
    const { data, error } = await _sb.from('products').update({ is_active: false }).eq('id', id).select();
    if (error) {
      await logError('PRODUCT_DEACTIVATE_FAIL', { id, 오류: error.message });
      return { error: error.message };
    }
    const updated = data && data[0] ? data[0] : null;
    await logInfo('PRODUCT_DEACTIVATE', buildChangeLogDetails({
      targetName: (updated && updated.name) || (before && before.name),
      targetType: '상품',
      targetId: id,
      changes: buildChangeSet(before || {}, updated || { is_active:false }, { fields:['is_active'] })
    }));
    return { error: null };
  } catch (err) {
    await logError('PRODUCT_DEACTIVATE_ERROR', { id, 오류: String(err) });
    return { error: String(err) };
  }
}
