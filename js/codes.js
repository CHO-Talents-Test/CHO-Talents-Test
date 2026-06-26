/**
 * Common codebook module
 *
 * DB code columns keep compact code keys (for example: permission_level=teacher)
 * while labels, order, rank, colors and audit metadata are managed here and,
 * when available, overridden by public.code_items.
 */

const CODE_GROUPS = {
  'profiles.permission_level': { name: '권한 등급', description: 'profiles.permission_level, registration_requests.permission_level' },
  'profiles.user_type': { name: '사용자 유형', description: 'profiles.user_type, registration_requests.user_type' },
  'product_orders.status': { name: '구매 상태', description: 'product_orders.status' },
  'products.target_role': { name: '상품 대상', description: 'products.target_role' },
  'products.category': { name: '상품 카테고리', description: 'products.category' },
  'activity_logs.level': { name: '로그 레벨', description: 'activity_logs.level' },
  'activity_logs.action': { name: '로그 액션', description: 'activity_logs.action' },
  'talent_items.target_type': { name: '달란트 항목 대상', description: 'talent_items.target_type, talent_qr_codes.target_type' },
  'talent_transactions.type': { name: '달란트 거래 유형', description: 'talent_transactions.type' },
  'talent_transactions.source': { name: '달란트 지급 출처', description: 'talent_transactions.source' },
  'qna.status': { name: 'Q&A 상태', description: 'qna.status' },
  'request.status': { name: '신청 상태', description: 'registration_requests.status, department_transfer_requests.status' },
  'talent_qr_codes.repeat_type': { name: 'QR 반복 유형', description: 'talent_qr_codes.repeat_type' },
  'reports.report_type': { name: '보고서 유형', description: 'reports.report_type' },
  'report_events.event_type': { name: '보고서 이벤트 유형', description: 'report_events.event_type' },
  'user_preferences.theme': { name: '테마', description: 'user_preferences.theme' }
};

const CODE_ITEMS = {
  'profiles.permission_level': [
    { key: 'admin', value: '관리자', emoji: '👑', rank: 100, order: 10, color: '#e03131', badgeClass: 'ERROR' },
    { key: 'evangelist', value: '전도사님', emoji: '✝️', rank: 90, order: 20, color: '#9c36b5', badgeClass: 'WARN' },
    { key: 'chief', value: '부장 교사', emoji: '📋', rank: 80, order: 30, color: '#f08c00', badgeClass: 'WARN' },
    { key: 'purchase_teacher', value: '구매 담당 교사', emoji: '🛒', rank: 70, order: 40, color: '#1971c2', badgeClass: 'INFO' },
    { key: 'dept_teacher', value: '부서 담당 교사', emoji: '👩‍🏫', rank: 60, order: 50, color: '#1971c2', badgeClass: 'INFO' },
    { key: 'teacher', value: '일반 교사', emoji: '👨‍🏫', rank: 40, order: 60, color: '#4dabf7', badgeClass: 'INFO' },
    { key: 'student', value: '학생', emoji: '🎒', rank: 20, order: 70, color: '#2b8a3e', badgeClass: 'SUCCESS' },
    { key: 'super_admin', value: '최고 관리자', emoji: '⭐', rank: 110, order: 1, color: '#c92a2a', badgeClass: 'CRITICAL' }
  ],
  'profiles.user_type': [
    { key: 'teacher', value: '교사', emoji: '👩‍🏫', order: 10 },
    { key: 'student', value: '학생', emoji: '🎒', order: 20 }
  ],
  'product_orders.status': [
    { key: 'requested', value: '구매 신청', emoji: '🛒', order: 10, color: '#868e96' },
    { key: 'preparing', value: '상품 준비', emoji: '📦', order: 20, color: '#e67700' },
    { key: 'purchased', value: '상품 구매', emoji: '💳', order: 30, color: '#1971c2' },
    { key: 'delivered', value: '상품 지급', emoji: '✅', order: 40, color: '#2b8a3e' },
    { key: 'cancelled', value: '구매 취소', emoji: '❌', order: 50, color: '#e03131' }
  ],
  'products.target_role': [
    { key: 'teacher', value: '교사', emoji: '👩‍🏫', order: 10 },
    { key: 'student', value: '학생', emoji: '🎒', order: 20 }
  ],
  'products.category': [
    { key: 'stationery', value: '학용품', emoji: '✏️', order: 10 },
    { key: 'snack', value: '간식', emoji: '🍬', order: 20 },
    { key: 'toy', value: '장난감', emoji: '🧸', order: 30 },
    { key: 'book', value: '도서', emoji: '📚', order: 40 },
    { key: 'gift', value: '선물', emoji: '🎁', order: 50 },
    { key: 'etc', value: '기타', emoji: '📦', order: 999 }
  ],
  'activity_logs.level': [
    { key: 'TRACE', value: '추적', order: 10 },
    { key: 'DEBUG', value: '디버그', order: 20 },
    { key: 'INFO', value: '정보', order: 30 },
    { key: 'WARN', value: '경고', order: 40 },
    { key: 'ERROR', value: '오류', order: 50 },
    { key: 'FATAL', value: '치명 오류', order: 60 },
    { key: 'CRITICAL', value: '긴급 오류', order: 70 }
  ],
  'talent_items.target_type': [
    { key: 'teacher', value: '교사', emoji: '👩‍🏫', order: 10 },
    { key: 'student', value: '학생', emoji: '🎒', order: 20 }
  ],
  'talent_transactions.type': [
    { key: 'earn', value: '적립', emoji: '➕', order: 10, color: '#2b8a3e' },
    { key: 'use', value: '사용', emoji: '➖', order: 20, color: '#e03131' }
  ],
  'talent_transactions.source': [
    { key: 'admin', value: '관리자 지급', emoji: '🧑‍💻', order: 10 },
    { key: 'qr', value: 'QR 수령', emoji: '📱', order: 20 }
  ],
  'qna.status': [
    { key: 'pending', value: '답변 대기', emoji: '❓', order: 10 },
    { key: 'answered', value: '답변 완료', emoji: '💬', order: 20 },
    { key: 'faq', value: 'FAQ', emoji: '📌', order: 30 }
  ],
  'request.status': [
    { key: 'pending', value: '대기', emoji: '⏳', order: 10 },
    { key: 'approved', value: '승인', emoji: '✅', order: 20 },
    { key: 'rejected', value: '거부', emoji: '❌', order: 30 }
  ],
  'talent_qr_codes.repeat_type': [
    { key: 'none', value: '1회', order: 10 },
    { key: 'daily', value: '매일', order: 20 },
    { key: 'weekday', value: '요일 반복', order: 30 },
    { key: 'week_weekday', value: '주차+요일 반복', order: 40 }
  ],
  'reports.report_type': [
    { key: 'plan', value: '계획서', order: 10 },
    { key: 'test_scenario', value: '테스트 시나리오', order: 20 },
    { key: 'test_result', value: '테스트 결과', order: 30 },
    { key: 'change_report', value: '변경 보고서', order: 40 },
    { key: 'security_report', value: '보안 보고서', order: 50 }
  ],
  'report_events.event_type': [
    { key: 'created', value: '생성', order: 10 },
    { key: 'updated', value: '수정', order: 20 },
    { key: 'confirmed', value: '확인', order: 30 },
    { key: 'reconfirmed', value: '재확인', order: 40 },
    { key: 'status_changed', value: '상태 변경', order: 50 }
  ],
  'user_preferences.theme': [
    { key: 'default', value: '일반', order: 10 },
    { key: 'dark', value: '다크', order: 20 },
    { key: 'spring', value: '봄', order: 30 },
    { key: 'summer', value: '여름', order: 40 },
    { key: 'autumn', value: '가을', order: 50 },
    { key: 'winter', value: '겨울', order: 60 }
  ],
  'activity_logs.action': [
    { key: 'USER_CREATE', value: '사용자 등록', category: 'USER', emoji: '➕', order: 1010 },
    { key: 'USER_UPDATE', value: '사용자 수정', category: 'USER', emoji: '✏️', order: 1020 },
    { key: 'USER_DELETE', value: '사용자 삭제', category: 'USER', emoji: '🗑️', order: 1030 },
    { key: 'USER_PW_RESET', value: '비밀번호 초기화', category: 'USER', emoji: '🔑', order: 1040 },
    { key: 'PASSWORD_RESET', value: '비밀번호 초기화', category: 'USER', emoji: '🔑', order: 1050 },
    { key: 'REGISTER_REQUEST', value: '가입 신청', category: 'REGISTER', emoji: '📝', order: 2010 },
    { key: 'REGISTER_APPROVE', value: '가입 승인', category: 'REGISTER', emoji: '✅', order: 2020 },
    { key: 'REGISTER_REJECT', value: '가입 거부', category: 'REGISTER', emoji: '❌', order: 2030 },
    { key: 'DEPT_CREATE', value: '부서 등록', category: 'DEPT', emoji: '🏢', order: 3010 },
    { key: 'DEPT_UPDATE', value: '부서 수정', category: 'DEPT', emoji: '✏️', order: 3020 },
    { key: 'DEPT_DELETE', value: '부서 삭제', category: 'DEPT', emoji: '🗑️', order: 3030 },
    { key: 'DEPT_DEACTIVATE', value: '부서 비활성화', category: 'DEPT', emoji: '🚫', order: 3040 },
    { key: 'DEPT_TRANSFER_IMMEDIATE', value: '부서 즉시 이동', category: 'DEPT', emoji: '🔄', order: 3050 },
    { key: 'DEPT_TRANSFER_REQUEST', value: '부서 이동 요청', category: 'DEPT', emoji: '📮', order: 3060 },
    { key: 'DEPT_TRANSFER_APPROVE', value: '부서 이동 승인', category: 'DEPT', emoji: '✅', order: 3070 },
    { key: 'DEPT_TRANSFER_REJECT', value: '부서 이동 거부', category: 'DEPT', emoji: '❌', order: 3080 },
    { key: 'MANAGER_UPDATE', value: '관리자 수정', category: 'DEPT', emoji: '👤', order: 3090 },
    { key: 'MANAGER_PROMOTE', value: '관리자 승격', category: 'DEPT', emoji: '⬆️', order: 3100 },
    { key: 'TALENT_GIVE', value: '달란트 지급', category: 'TALENT', emoji: '💰', order: 4010 },
    { key: 'TALENT_GIVE_ITEM', value: '달란트 항목 지급', category: 'TALENT', emoji: '💰', order: 4020 },
    { key: 'TALENT_GIVE_ITEMS', value: '달란트 일괄 지급', category: 'TALENT', emoji: '💰', order: 4030 },
    { key: 'TALENT_MANUAL_GIVE', value: '달란트 수동 지급', category: 'TALENT', emoji: '✍️', order: 4040 },
    { key: 'TALENT_USE', value: '달란트 사용', category: 'TALENT', emoji: '💸', order: 4050 },
    { key: 'TALENT_RETURN', value: '달란트 반환', category: 'TALENT', emoji: '↩️', order: 4060 },
    { key: 'ATTENDANCE_GIVE', value: '출석 달란트 지급', category: 'TALENT', emoji: '⛪', order: 4070 },
    { key: 'ATTENDANCE_CANCEL', value: '출석 달란트 취소', category: 'TALENT', emoji: '🔙', order: 4080 },
    { key: 'TALENT_ITEM_CANCEL', value: '달란트 항목 취소', category: 'TALENT', emoji: '🔙', order: 4090 },
    { key: 'TALENT_ITEM_CREATE', value: '달란트 항목 등록', category: 'TALENT', emoji: '📋', order: 4100 },
    { key: 'TALENT_ITEM_UPDATE', value: '달란트 항목 수정', category: 'TALENT', emoji: '📋', order: 4110 },
    { key: 'TALENT_ITEM_TOGGLE', value: '달란트 항목 활성 토글', category: 'TALENT', emoji: '🔘', order: 4120 },
    { key: 'TALENT_ITEM_QUICKBTN', value: '달란트 퀵버튼 설정', category: 'TALENT', emoji: '⚡', order: 4130 },
    { key: 'qr_create', value: 'QR 코드 생성', category: 'TALENT', emoji: '📷', order: 4140 },
    { key: 'qr_edit', value: 'QR 코드 수정', category: 'TALENT', emoji: '✏️', order: 4150 },
    { key: 'qr_toggle', value: 'QR 코드 토글', category: 'TALENT', emoji: '🔘', order: 4160 },
    { key: 'qr_scan', value: 'QR 달란트 수령', category: 'TALENT', emoji: '📱', order: 4170 },
    { key: 'PRODUCT_CREATE', value: '상품 등록', category: 'ORDER', emoji: '🛍️', order: 5010 },
    { key: 'PRODUCT_UPDATE', value: '상품 수정', category: 'ORDER', emoji: '✏️', order: 5020 },
    { key: 'PRODUCT_DELETE', value: '상품 삭제', category: 'ORDER', emoji: '🗑️', order: 5030 },
    { key: 'PRODUCT_DEACTIVATE', value: '상품 비활성화', category: 'ORDER', emoji: '🚫', order: 5040 },
    { key: 'PRODUCT_SOFT_DELETE', value: '상품 비활성화', category: 'ORDER', emoji: '🚫', order: 5050 },
    { key: 'ORDER_REQUEST_SUCCESS', value: '상품 구매 신청', category: 'ORDER', emoji: '🛒', order: 5060 },
    { key: 'PROXY_ORDER_SUCCESS', value: '대리 구매 신청', category: 'ORDER', emoji: '🛒', order: 5070 },
    { key: 'order_cancel', value: '주문 취소', category: 'ORDER', emoji: '❌', order: 5080 },
    { key: 'ORDER_CANCEL', value: '주문 취소', category: 'ORDER', emoji: '❌', order: 5081 },
    { key: 'ORDER_STATUS_CHANGE', value: '주문 상태 변경', category: 'ORDER', emoji: '🔄', order: 5090 },
    { key: 'ORDER_REVERT', value: '주문 상태 되돌리기', category: 'ORDER', emoji: '↩️', order: 5100 },
    { key: 'ORDER_PURCHASE_CONFIRM', value: '구매 확정', category: 'ORDER', emoji: '✅', order: 5110 },
    { key: 'ORDER_BULK_PREPARE', value: '일괄 상품 준비', category: 'ORDER', emoji: '📦', order: 5120 },
    { key: 'ORDER_BULK_PURCHASE', value: '일괄 구매 확정', category: 'ORDER', emoji: '📦', order: 5130 },
    { key: 'ORDER_BULK_DELIVER', value: '일괄 상품 지급', category: 'ORDER', emoji: '📦', order: 5140 },
    { key: 'QNA_CREATE', value: '질문 등록', category: 'QNA', emoji: '❓', order: 6010 },
    { key: 'QNA_ANSWER', value: '답변 등록', category: 'QNA', emoji: '💬', order: 6020 },
    { key: 'QNA_COMMENT', value: '댓글 등록', category: 'QNA', emoji: '💬', order: 6030 },
    { key: 'QNA_DELETE', value: 'Q&A 삭제', category: 'QNA', emoji: '🗑️', order: 6040 },
    { key: 'QNA_FAQ_SET', value: 'FAQ 설정', category: 'QNA', emoji: '📌', order: 6050 },
    { key: 'LOGIN_SUCCESS', value: '로그인 성공', category: 'AUTH', emoji: '🔓', order: 7010 },
    { key: 'LOGOUT', value: '로그아웃', category: 'AUTH', emoji: '🔒', order: 7020 },
    { key: 'PASSWORD_CHANGE', value: '비밀번호 변경', category: 'AUTH', emoji: '🔑', order: 7030 },
    { key: 'LOG_ACKNOWLEDGED', value: '로그 확인', category: 'LOG_MGMT', emoji: '✅', order: 8010 },
    { key: 'LOG_BULK_ACK', value: '로그 일괄 확인', category: 'LOG_MGMT', emoji: '✅', order: 8020 },
    { key: 'LOG_RANGE_DELETE', value: '로그 범위 삭제', category: 'LOG_MGMT', emoji: '🗑️', order: 8030 },
    { key: 'LOG_SELECT_DELETE', value: '로그 선택 삭제', category: 'LOG_MGMT', emoji: '🗑️', order: 8040 },
    { key: 'LOG_RESTORE', value: '로그 복원', category: 'LOG_MGMT', emoji: '♻️', order: 8050 },
    { key: 'ROLE_ACCESS_UPDATE', value: '페이지 접근 권한 변경', category: 'PERM', emoji: '🔐', order: 9010 },
    { key: 'ROLE_FEATURE_UPDATE', value: '페이지 기능 권한 변경', category: 'PERM', emoji: '🔧', order: 9020 },
    { key: 'PAGE_PERM_UPDATE', value: '페이지 권한 설정 변경', category: 'PERM', emoji: '🛡️', order: 9030 },
    { key: 'REPORT_SAVE', value: '보고서 저장', category: 'PERM', emoji: '📄', order: 9040 },
    { key: 'REPORT_DELETE', value: '보고서 삭제', category: 'PERM', emoji: '🗑️', order: 9050 },
    { key: 'REPORT_SEED', value: '보고서 시드 등록', category: 'PERM', emoji: '🌱', order: 9060 }
  ]
};

function _codeSort(a, b) {
  const ao = a.order ?? a.sort_order ?? 9999;
  const bo = b.order ?? b.sort_order ?? 9999;
  if (ao !== bo) return ao - bo;
  return String(a.value || a.key).localeCompare(String(b.value || b.key), 'ko');
}

function getCodeItems(groupKey, options = {}) {
  const items = (CODE_ITEMS[groupKey] || []).filter(item => options.includeInactive || item.is_active !== false);
  return items.slice().sort(_codeSort);
}

function getCodeItem(groupKey, codeKey) {
  return (CODE_ITEMS[groupKey] || []).find(item => item.key === codeKey || item.code_key === codeKey) || null;
}

function getCodeLabel(groupKey, codeKey, fallback) {
  const item = getCodeItem(groupKey, codeKey);
  return item ? (item.value || item.code_value || item.label || codeKey) : (fallback ?? codeKey ?? '');
}

function getCodeEmoji(groupKey, codeKey, fallback) {
  const item = getCodeItem(groupKey, codeKey);
  return item ? (item.emoji || fallback || '') : (fallback || '');
}

function getCodeColor(groupKey, codeKey, fallback) {
  const item = getCodeItem(groupKey, codeKey);
  return item ? (item.color || fallback || '#868e96') : (fallback || '#868e96');
}

function getCodeRank(groupKey, codeKey, fallback = 0) {
  const item = getCodeItem(groupKey, codeKey);
  const rank = item ? Number(item.rank ?? item.meta?.rank) : NaN;
  return Number.isFinite(rank) ? rank : fallback;
}

function getCodeOrder(groupKey, codeKey, fallback = 9999) {
  const item = getCodeItem(groupKey, codeKey);
  const order = item ? Number(item.order ?? item.sort_order) : NaN;
  return Number.isFinite(order) ? order : fallback;
}

function renderCodeOptions(groupKey, options = {}) {
  const selected = options.selected ?? '';
  return getCodeItems(groupKey)
    .filter(item => !options.include || options.include.includes(item.key))
    .filter(item => !options.exclude || !options.exclude.includes(item.key))
    .filter(item => options.maxRank == null || getCodeRank(groupKey, item.key, 0) <= options.maxRank || item.key === selected)
    .map(item => {
      const label = (options.showEmoji === false ? '' : ((item.emoji || '') + ' ')) + (item.value || item.key);
      return `<option value="${item.key}" ${item.key === selected ? 'selected' : ''}>${label.trim()}</option>`;
    })
    .join('');
}

function codeMap(groupKey, prop, fallbackProp) {
  const result = {};
  getCodeItems(groupKey, { includeInactive: true }).forEach(item => {
    result[item.key] = item[prop] ?? (fallbackProp ? item[fallbackProp] : undefined);
  });
  return result;
}

function getAuditActions() {
  const result = {};
  getCodeItems('activity_logs.action', { includeInactive: true }).forEach(item => {
    if (!item.category) return;
    result[item.key] = {
      label: item.value || item.key,
      category: item.category,
      emoji: item.emoji || '📋'
    };
  });
  return result;
}

async function loadCodeItems(groupKeys) {
  if (typeof _sb === 'undefined' || !_sb) return false;
  const groups = Array.isArray(groupKeys) && groupKeys.length ? groupKeys : Object.keys(CODE_GROUPS);
  try {
    let query = _sb
      .from('code_items')
      .select('group_key, code_key, code_value, sort_order, is_active, meta')
      .in('group_key', groups)
      .eq('is_active', true)
      .order('sort_order', { ascending: true });
    const { data, error } = await query;
    if (error || !data) return false;

    data.forEach(row => {
      const meta = row.meta || {};
      const item = Object.assign({}, meta, {
        key: row.code_key,
        value: row.code_value,
        order: row.sort_order,
        is_active: row.is_active
      });
      if (!CODE_ITEMS[row.group_key]) CODE_ITEMS[row.group_key] = [];
      const idx = CODE_ITEMS[row.group_key].findIndex(x => x.key === item.key);
      if (idx >= 0) CODE_ITEMS[row.group_key][idx] = Object.assign({}, CODE_ITEMS[row.group_key][idx], item);
      else CODE_ITEMS[row.group_key].push(item);
    });
    return true;
  } catch (e) {
    console.warn('[Codes] code_items fallback in use:', e.message || e);
    return false;
  }
}

const CodeBook = {
  groups: CODE_GROUPS,
  items: CODE_ITEMS,
  list: getCodeItems,
  item: getCodeItem,
  label: getCodeLabel,
  emoji: getCodeEmoji,
  color: getCodeColor,
  rank: getCodeRank,
  order: getCodeOrder,
  options: renderCodeOptions,
  map: codeMap,
  auditActions: getAuditActions,
  load: loadCodeItems
};

window.CodeBook = CodeBook;
window.CODE_GROUPS = CODE_GROUPS;
window.CODE_ITEMS = CODE_ITEMS;
window.getCodeItems = getCodeItems;
window.getCodeItem = getCodeItem;
window.getCodeLabel = getCodeLabel;
window.getCodeEmoji = getCodeEmoji;
window.getCodeColor = getCodeColor;
window.getCodeRank = getCodeRank;
window.getCodeOrder = getCodeOrder;
window.codeMap = codeMap;
window.renderCodeOptions = renderCodeOptions;
window.getAuditActions = getAuditActions;
window.loadCodeItems = loadCodeItems;
