/**
 * Activity Log Module
 * 모든 페이지에서 사용하는 공통 로그 기록/조회 모듈
 */

const LOG_LEVELS = ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL', 'CRITICAL'];
const ERROR_LEVELS = ['ERROR', 'FATAL', 'CRITICAL'];
const SLACK_ALERT_LEVELS = ['WARN', 'ERROR', 'FATAL', 'CRITICAL'];

let _clientInfo = null;
let _clientIp = null;
let _logAlertLastSent = {};
const _LOG_ALERT_THROTTLE_MS = 5000;

function _sendLogAlertDirect(level, action, page, details) {
  if (!_sb) return;
  var key = 'log_alert_' + level + '_' + action;
  var now = Date.now();
  if (_logAlertLastSent[key] && now - _logAlertLastSent[key] < _LOG_ALERT_THROTTLE_MS) return;
  _logAlertLastSent[key] = now;
  var safeDetails = {};
  if (details) {
    Object.keys(details).forEach(function(k) { if (!k.startsWith('_')) safeDetails[k] = details[k]; });
  }
  _sb.functions.invoke('slack-notify', {
    body: { type: 'log_alert', data: { '레벨': level, '액션': action, '페이지': page || window.location.pathname, '상세': safeDetails } }
  }).catch(function(err) {
    console.warn('[LogAlert] Slack notify failed:', err);
  });
}

const ACTION_LABELS = {
  PAGE_VIEW: '페이지 조회',
  JS_ERROR: 'JS 오류',
  PROMISE_REJECTION: '비동기 오류',
  CONNECTION_FAIL: '연결 실패',
  // 사용자
  USER_CREATE: '사용자 등록',
  USER_CREATE_FAIL: '사용자 등록 실패',
  USER_CREATE_DENIED: '사용자 등록 거부',
  USER_CREATE_ERROR: '사용자 등록 오류',
  USER_UPDATE: '사용자 수정',
  USER_UPDATE_FAIL: '사용자 수정 실패',
  USER_UPDATE_DENIED: '사용자 수정 거부',
  USER_UPDATE_ERROR: '사용자 수정 오류',
  USER_DELETE: '사용자 삭제',
  USER_DELETE_FAIL: '사용자 삭제 실패',
  USER_DELETE_DENIED: '사용자 삭제 거부',
  USER_DELETE_ERROR: '사용자 삭제 오류',
  USER_PW_RESET: '비밀번호 초기화',
  USER_PW_RESET_FAIL: '비밀번호 초기화 실패',
  PASSWORD_RESET: '비밀번호 초기화',
  PASSWORD_RESET_FAIL: '비밀번호 초기화 실패',
  PASSWORD_RESET_DENIED: '비밀번호 초기화 거부',
  PASSWORD_RESET_ERROR: '비밀번호 초기화 오류',
  // 등록
  REGISTER_REQUEST: '가입 신청',
  REGISTER_REQUEST_FAIL: '가입 신청 실패',
  REGISTER_APPROVE: '가입 승인',
  REGISTER_APPROVE_FAIL: '가입 승인 실패',
  REGISTER_REJECT: '가입 거부',
  // 인증
  LOGIN_SUCCESS: '로그인 성공',
  LOGIN_FAIL: '로그인 실패',
  LOGIN_ERROR: '로그인 오류',
  AUTH_SESSION_MISSING: '인증 세션 없음',
  AUTH_PROFILE_LOAD_FAIL: '인증 프로필 조회 실패',
  AUTH_REDIRECT: '인증/권한 리디렉트',
  AUTH_PAGE_ACCESS_CHECK_FAIL: '페이지 접근 권한 확인 실패',
  QR_LOCATION_PERMISSION_BLOCKED: 'QR 위치 권한 차단',
  LOGOUT: '로그아웃',
  PASSWORD_CHANGE: '비밀번호 변경',
  PASSWORD_CHANGE_FAIL: '비밀번호 변경 실패',
  PASSWORD_CHANGE_ERROR: '비밀번호 변경 오류',
  // 부서
  DEPT_CREATE: '부서 등록',
  DEPT_CREATE_FAIL: '부서 등록 실패',
  DEPT_CREATE_ERROR: '부서 등록 오류',
  DEPT_UPDATE: '부서 수정',
  DEPT_UPDATE_FAIL: '부서 수정 실패',
  DEPT_UPDATE_ERROR: '부서 수정 오류',
  DEPT_DELETE: '부서 삭제',
  DEPT_DELETE_FAIL: '부서 삭제 실패',
  DEPT_DELETE_ERROR: '부서 삭제 오류',
  DEPT_DEACTIVATE: '부서 비활성화',
  DEPT_TRANSFER_IMMEDIATE: '부서 즉시 이동',
  DEPT_TRANSFER_IMMEDIATE_FAIL: '부서 즉시 이동 실패',
  DEPT_TRANSFER_REQUEST: '부서 이동 요청',
  DEPT_TRANSFER_REQUEST_FAIL: '부서 이동 요청 실패',
  DEPT_TRANSFER_APPROVE: '부서 이동 승인',
  DEPT_TRANSFER_REJECT: '부서 이동 거부',
  MANAGER_UPDATE: '관리자 수정',
  MANAGER_UPDATE_FAIL: '관리자 수정 실패',
  MANAGER_PROMOTE: '관리자 승격',
  MANAGER_PROMOTE_FAIL: '관리자 승격 실패',
  // 달란트
  TALENT_GIVE: '달란트 지급',
  TALENT_GIVE_FAIL: '달란트 지급 실패',
  TALENT_GIVE_DENIED: '달란트 지급 거부',
  TALENT_GIVE_ERROR: '달란트 지급 오류',
  TALENT_GIVE_ITEM: '달란트 항목 지급',
  TALENT_GIVE_ITEM_FAIL: '달란트 항목 지급 실패',
  TALENT_GIVE_ITEM_DENIED: '달란트 항목 지급 거부',
  TALENT_GIVE_ITEM_ERROR: '달란트 항목 지급 오류',
  TALENT_GIVE_ITEMS: '달란트 일괄 지급',
  TALENT_MANUAL_GIVE: '달란트 수동 지급',
  TALENT_MANUAL_GIVE_FAIL: '달란트 수동 지급 실패',
  TALENT_MANUAL_GIVE_ERROR: '달란트 수동 지급 오류',
  TALENT_USE: '달란트 사용',
  TALENT_USE_FAIL: '달란트 사용 실패',
  TALENT_USE_DENIED: '달란트 사용 거부',
  TALENT_USE_ERROR: '달란트 사용 오류',
  TALENT_RETURN: '달란트 반환',
  TALENT_RETURN_FAIL: '달란트 반환 실패',
  TALENT_RETURN_DENIED: '달란트 반환 거부',
  TALENT_RETURN_ERROR: '달란트 반환 오류',
  ATTENDANCE_GIVE: '출석 달란트 지급',
  ATTENDANCE_CANCEL: '출석 달란트 취소',
  TALENT_ITEM_CANCEL: '달란트 항목 취소',
  TALENT_ITEM_CREATE: '달란트 항목 등록',
  TALENT_ITEM_CREATE_FAIL: '달란트 항목 등록 실패',
  TALENT_ITEM_UPDATE: '달란트 항목 수정',
  TALENT_ITEM_UPDATE_FAIL: '달란트 항목 수정 실패',
  TALENT_ITEM_TOGGLE: '달란트 항목 활성 토글',
  TALENT_ITEM_QUICKBTN: '달란트 퀵버튼 설정',
  qr_create: 'QR 코드 생성',
  QR_CREATE_FAIL: 'QR 코드 생성 실패',
  QR_CREATE_NO_RESULT: 'QR 코드 생성 결과 없음',
  QR_CREATE_ERROR: 'QR 코드 생성 오류',
  qr_edit: 'QR 코드 수정',
  qr_toggle: 'QR 코드 토글',
  qr_scan: 'QR 달란트 수령',
  // 상품/주문
  PRODUCT_CREATE: '상품 등록',
  PRODUCT_CREATE_FAIL: '상품 등록 실패',
  PRODUCT_CREATE_ERROR: '상품 등록 오류',
  PRODUCT_UPDATE: '상품 수정',
  PRODUCT_UPDATE_FAIL: '상품 수정 실패',
  PRODUCT_UPDATE_ERROR: '상품 수정 오류',
  PRODUCT_DELETE: '상품 삭제',
  PRODUCT_DELETE_FAIL: '상품 삭제 실패',
  PRODUCT_DELETE_ERROR: '상품 삭제 오류',
  PRODUCT_DEACTIVATE: '상품 비활성화',
  PRODUCT_DEACTIVATE_FAIL: '상품 비활성화 실패',
  PRODUCT_DEACTIVATE_ERROR: '상품 비활성화 오류',
  PRODUCT_SOFT_DELETE: '상품 비활성화',
  IMAGE_UPLOAD: '이미지 업로드',
  IMAGE_UPLOAD_FAIL: '이미지 업로드 실패',
  IMAGE_UPLOAD_ERROR: '이미지 업로드 오류',
  IMAGE_DELETE_FAIL: '이미지 삭제 실패',
  ORDER_REQUEST_SUCCESS: '상품 구매 신청',
  ORDER_REQUEST_FAIL: '상품 구매 신청 실패',
  ORDER_REQUEST_DENIED: '상품 구매 신청 거부',
  ORDER_REQUEST_ERROR: '상품 구매 신청 오류',
  ORDER_INSUFFICIENT_BALANCE: '달란트 부족으로 구매 불가',
  PROXY_ORDER_SUCCESS: '대리 구매 신청',
  PROXY_ORDER_FAIL: '대리 구매 신청 실패',
  PROXY_ORDER_DENIED: '대리 구매 신청 거부',
  PROXY_ORDER_ERROR: '대리 구매 신청 오류',
  PROXY_USER_LOAD_FAIL: '대리 구매 사용자 조회 실패',
  PROXY_USER_LOAD_ERROR: '대리 구매 사용자 조회 오류',
  order_cancel: '주문 취소',
  ORDER_STATUS_CHANGE: '주문 상태 변경',
  ORDER_STATUS_CHANGE_FAIL: '주문 상태 변경 실패',
  ORDER_STATUS_CHANGE_ERROR: '주문 상태 변경 오류',
  ORDER_REVERT: '주문 상태 되돌리기',
  ORDER_REVERT_FAIL: '주문 상태 되돌리기 실패',
  ORDER_REVERT_ERROR: '주문 상태 되돌리기 오류',
  ORDER_PURCHASE_CONFIRM: '구매 확정',
  ORDER_PURCHASE_CONFIRM_FAIL: '구매 확정 실패',
  ORDER_PURCHASE_CONFIRM_DENIED: '구매 확정 거부',
  ORDER_PURCHASE_CONFIRM_ERROR: '구매 확정 오류',
  ORDER_BULK_PREPARE: '일괄 상품 준비',
  ORDER_BULK_PREPARE_ITEM_FAIL: '일괄 상품 준비 항목 실패',
  ORDER_BULK_PURCHASE: '일괄 구매 확정',
  ORDER_BULK_PURCHASE_ITEM_FAIL: '일괄 구매 확정 항목 실패',
  ORDER_BULK_PURCHASE_DENIED: '일괄 구매 확정 거부',
  ORDER_BULK_DELIVER: '일괄 상품 지급',
  ORDER_BULK_DELIVER_ITEM_FAIL: '일괄 상품 지급 항목 실패',
  PURCHASE_LOAD_FAIL: '구매 데이터 조회 실패',
  PURCHASE_SCOPE_USERS_FAIL: '구매 범위 사용자 조회 실패',
  SHOP_PROFILE_FALLBACK: '상점 프로필 폴백',
  MY_ORDERS_FETCH: '내 주문 조회 실패',
  MY_TALENT_PENDING_QUERY: '대기 달란트 조회 오류',
  MY_TALENT_ORDERS_QUERY: '주문 조회 오류',
  // Q&A
  QNA_CREATE: '질문 등록',
  QNA_ANSWER: '답변 등록',
  QNA_COMMENT: '댓글 등록',
  QNA_DELETE: 'Q&A 삭제',
  QNA_FAQ_SET: 'FAQ 설정',
  // 로그 관리
  LOG_ACKNOWLEDGED: '로그 확인',
  LOG_BULK_ACK: '로그 일괄 확인',
  LOG_RANGE_DELETE: '로그 범위 삭제',
  LOG_RANGE_DELETE_FAIL: '로그 범위 삭제 실패',
  LOG_RANGE_DELETE_ERROR: '로그 범위 삭제 오류',
  LOG_SELECT_DELETE: '로그 선택 삭제',
  LOG_SELECT_DELETE_FAIL: '로그 선택 삭제 실패',
  LOG_SELECT_DELETE_ERROR: '로그 선택 삭제 오류',
  LOG_RESTORE: '로그 복원',
  LOG_RESTORE_FAIL: '로그 복원 실패',
  // 권한/설정
  ROLE_ACCESS_UPDATE: '페이지 접근 권한 변경',
  ROLE_ACCESS_UPDATE_FAIL: '페이지 접근 권한 변경 실패',
  ROLE_FEATURE_UPDATE: '페이지 기능 권한 변경',
  ROLE_FEATURE_UPDATE_FAIL: '페이지 기능 권한 변경 실패',
  PAGE_PERM_UPDATE: '페이지 권한 설정 변경',
  REPORT_VIEW: '보고서 조회',
  REPORT_SAVE: '보고서 저장',
  REPORT_SAVE_FAIL: '보고서 저장 실패',
  REPORT_SAVE_ERROR: '보고서 저장 오류',
  REPORT_DELETE: '보고서 삭제',
  REPORT_DELETE_FAIL: '보고서 삭제 실패',
  REPORT_DELETE_ERROR: '보고서 삭제 오류',
  REPORT_SEED: '보고서 시드 등록',
  REPORT_SEED_FAIL: '보고서 시드 등록 실패',
  REPORT_SEED_ERROR: '보고서 시드 등록 오류',
};

function getActionLabel(action) {
  const fallback = ACTION_LABELS[action] || action;
  return (typeof getCodeLabel === 'function')
    ? getCodeLabel('activity_logs.action', action, fallback)
    : fallback;
}

function _getLogErrorMessage(error) {
  if (!error) return '';
  return [
    error.message,
    error.details,
    error.hint,
    error.code,
    typeof error === 'string' ? error : ''
  ].filter(Boolean).join(' ');
}

function _getMissingOptionalLogColumn(error, row) {
  const msg = _getLogErrorMessage(error).toLowerCase();
  if (!msg || !/could not find|column|schema cache|does not exist/i.test(msg)) return null;
  return ['user_name', 'is_acknowledged'].find(col =>
    Object.prototype.hasOwnProperty.call(row, col) && msg.includes(col.toLowerCase())
  ) || null;
}

async function _insertActivityLogRow(row) {
  let currentRow = { ...row };
  const removedColumns = [];

  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const result = await _sb.from('activity_logs').insert(currentRow);
      if (!result.error) {
        if (removedColumns.length) {
          console.warn('[Log] Inserted with compatibility fallback. Removed columns:', removedColumns.join(', '));
        }
        return result;
      }

      const missingColumn = _getMissingOptionalLogColumn(result.error, currentRow);
      if (missingColumn) {
        delete currentRow[missingColumn];
        removedColumns.push(missingColumn);
        continue;
      }

      console.error('[Log] Failed to write log:', result.error);
      return result;
    } catch (err) {
      const missingColumn = _getMissingOptionalLogColumn(err, currentRow);
      if (missingColumn) {
        delete currentRow[missingColumn];
        removedColumns.push(missingColumn);
        continue;
      }
      console.error('[Log] Failed to write log:', err);
      return { data: null, error: err };
    }
  }

  const error = new Error('activity_logs insert failed after compatibility fallbacks');
  console.error('[Log] Failed to write log:', error);
  return { data: null, error };
}

function _parseUA() {
  const ua = navigator.userAgent || '';
  let browser = 'Unknown', os = 'Unknown', deviceType = 'desktop';

  if (/Edg\//i.test(ua)) browser = 'Edge ' + (ua.match(/Edg\/([\d.]+)/)||[])[1];
  else if (/OPR\//i.test(ua)) browser = 'Opera ' + (ua.match(/OPR\/([\d.]+)/)||[])[1];
  else if (/Chrome\//i.test(ua)) browser = 'Chrome ' + (ua.match(/Chrome\/([\d.]+)/)||[])[1];
  else if (/Safari\//i.test(ua) && !/Chrome/i.test(ua)) browser = 'Safari ' + (ua.match(/Version\/([\d.]+)/)||[])[1];
  else if (/Firefox\//i.test(ua)) browser = 'Firefox ' + (ua.match(/Firefox\/([\d.]+)/)||[])[1];

  if (/Windows NT 10/i.test(ua)) os = 'Windows 10/11';
  else if (/Windows NT/i.test(ua)) os = 'Windows';
  else if (/Mac OS X/i.test(ua)) os = 'macOS ' + ((ua.match(/Mac OS X ([\d_]+)/)||[])[1]||'').replace(/_/g,'.');
  else if (/Android/i.test(ua)) os = 'Android ' + (ua.match(/Android ([\d.]+)/)||[])[1];
  else if (/iPhone|iPad/i.test(ua)) os = 'iOS ' + ((ua.match(/OS ([\d_]+)/)||[])[1]||'').replace(/_/g,'.');
  else if (/Linux/i.test(ua)) os = 'Linux';
  else if (/CrOS/i.test(ua)) os = 'Chrome OS';

  if (/Mobi|Android.*Mobile|iPhone/i.test(ua)) deviceType = 'mobile';
  else if (/iPad|Android(?!.*Mobile)|Tablet/i.test(ua)) deviceType = 'tablet';

  return { browser, os, deviceType, userAgent: ua };
}

function getClientInfo() {
  if (_clientInfo) return _clientInfo;
  const { browser, os, deviceType, userAgent } = _parseUA();
  _clientInfo = {
    ip: _clientIp || null,
    browser,
    os,
    screenRes: screen.width + 'x' + screen.height,
    windowSize: window.innerWidth + 'x' + window.innerHeight,
    deviceType,
    language: navigator.language || navigator.userLanguage || 'unknown'
  };
  return _clientInfo;
}

function _fetchIp() {
  fetch('https://api.ipify.org?format=json')
    .then(r => r.json())
    .then(d => {
      _clientIp = d.ip;
      if (_clientInfo) _clientInfo.ip = d.ip;
    })
    .catch(() => {});
}
_fetchIp();

async function writeLog(level, action, page, details) {
  if (!_sb) {
    console.warn('[Log] Supabase not initialized, log skipped:', level, action);
    return { data: null, error: 'Supabase not initialized' };
  }
  const session = getSession();
  const ci = getClientInfo();
  const userName = session ? (session.displayName || session.username || null) : null;
  const actionLabel = getActionLabel(action);
  if (actionLabel && actionLabel !== action) {
    if (!details) details = {};
    details._actionLabel = actionLabel;
  }
  const merged = details ? Object.assign({}, details, { _client: ci, _userName: userName }) : { _client: ci, _userName: userName };
  const row = {
    level,
    action,
    page: page || window.location.pathname,
    details: merged,
    username: session ? session.username : null,
    user_name: userName,
    is_acknowledged: !ERROR_LEVELS.includes(level)
  };
  var result = await _insertActivityLogRow(row);
  if (SLACK_ALERT_LEVELS.includes(level)) {
    _sendLogAlertDirect(level, action, page || window.location.pathname, details);
  }
  return result;
}

function logTrace(action, details) { return writeLog('TRACE', action, null, details); }
function logDebug(action, details) { return writeLog('DEBUG', action, null, details); }
function logInfo(action, details)  { return writeLog('INFO', action, null, details); }
function logWarn(action, details)  { return writeLog('WARN', action, null, details); }
function logError(action, details) { return writeLog('ERROR', action, null, details); }
function logFatal(action, details) { return writeLog('FATAL', action, null, details); }
function logCritical(action, details) { return writeLog('CRITICAL', action, null, details); }

async function fetchLogs(options = {}) {
  if (!_sb) return { data: [], error: 'Supabase not initialized' };

  let query = _sb.from('activity_logs').select('*');

  if (!options.includeDeleted) {
    try {
      const testQ = _sb.from('activity_logs').select('id', { count: 'exact', head: true }).eq('is_deleted', false).limit(1);
      const { error: colErr } = await testQ;
      if (!colErr) {
        query = query.or('is_deleted.is.null,is_deleted.eq.false');
      }
    } catch (e) { /* is_deleted column may not exist yet */ }
  }

  if (options.levels && options.levels.length > 0) {
    query = query.in('level', options.levels);
  }
  if (options.action) {
    query = query.eq('action', options.action);
  }
  if (options.dateFrom) {
    query = query.gte('created_at', options.dateFrom);
  }
  if (options.dateTo) {
    query = query.lte('created_at', options.dateTo);
  }
  if (options.unacknowledgedOnly) {
    query = query.eq('is_acknowledged', false).in('level', ERROR_LEVELS);
  }

  query = query.order('created_at', { ascending: false });

  if (options.limit) query = query.limit(options.limit);
  if (options.offset) query = query.range(options.offset, options.offset + (options.limit || 50) - 1);

  return await query;
}

async function getUnacknowledgedCount() {
  if (!_sb) return 0;
  let query = _sb
    .from('activity_logs')
    .select('*', { count: 'exact', head: true })
    .eq('is_acknowledged', false)
    .in('level', ERROR_LEVELS);
  try {
    const { error: deletedColError } = await _sb.from('activity_logs')
      .select('id', { count: 'exact', head: true })
      .or('is_deleted.is.null,is_deleted.eq.false')
      .limit(1);
    if (!deletedColError) {
      query = query.or('is_deleted.is.null,is_deleted.eq.false');
    }
  } catch (e) {}
  const { count, error } = await query;
  return error ? 0 : (count || 0);
}

async function acknowledgeLog(logId, username, note) {
  if (!_sb) return { error: 'Supabase not initialized' };
  return await _sb.from('activity_logs').update({
    is_acknowledged: true,
    acknowledged_by: username,
    acknowledged_at: new Date().toISOString(),
    resolution_note: note
  }).eq('id', logId).select();
}

/* ===== Pending Registration Count ===== */

async function getPendingRegistrationCount() {
  if (!_sb) return 0;
  try {
    const session = getSession();
    if (!session || (session.permissionRank || 0) < 60) return 0;
    const myRank = session.permissionRank || 0;

    if (myRank >= 90) {
      const { count, error } = await _sb
        .from('registration_requests')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending');
      if (error) return 0;
      return count || 0;
    }

    const myDepts = new Set([session.managedDeptId, session.departmentId].filter(Boolean));
    if (myDepts.size === 0) return 0;

    const [regRes, trfRes] = await Promise.all([
      _sb.from('registration_requests').select('id,department_id').eq('status', 'pending'),
      _sb.from('department_transfer_requests').select('id,to_department_id').eq('status', 'pending')
    ]);

    const regs = (regRes.data || []).filter(r => myDepts.has(r.department_id));
    const trfs = (trfRes.data || []).filter(t => myDepts.has(t.to_department_id));
    return regs.length + trfs.length;
  } catch { return 0; }
}

async function getProcessableRequestCount() {
  if (!_sb) return 0;
  try {
    const session = getSession();
    if (!session || (session.permissionRank || 0) < 60) return 0;
    const myRank = session.permissionRank || 0;

    const [regRes, trfRes] = await Promise.all([
      _sb.from('registration_requests').select('id,department_id').eq('status', 'pending'),
      _sb.from('department_transfer_requests').select('id,to_department_id').eq('status', 'pending')
    ]);

    let regs = regRes.data || [];
    let trfs = trfRes.data || [];

    if (myRank >= 90) {
      return regs.length + trfs.length;
    }

    const myDepts = new Set([session.managedDeptId, session.departmentId].filter(Boolean));
    if (myDepts.size === 0) return 0;

    const processableRegs = regs.filter(r => myDepts.has(r.department_id));
    const processableTrfs = trfs.filter(t => myDepts.has(t.to_department_id));
    return processableRegs.length + processableTrfs.length;
  } catch { return 0; }
}

async function updatePendingBadge() {
  const badge = document.getElementById('navUserBadge');
  if (!badge) return;
  const count = await getProcessableRequestCount();
  if (count > 0) {
    badge.textContent = count;
    badge.classList.remove('hidden');
  } else {
    badge.classList.add('hidden');
  }
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

/* ===== Log Badge (nav "운영" group) ===== */

async function updateLogBadge() {
  const badge = document.getElementById('navLogBadge');
  if (!badge) return;
  try {
    const cnt = await getUnacknowledgedCount();
    if (cnt > 0) { badge.textContent = cnt; badge.classList.remove('hidden'); }
    else { badge.classList.add('hidden'); }
  } catch (e) {}
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

/* ===== Session Helpers (Supabase Auth 연동) ===== */

function getSession() {
  try {
    const raw = sessionStorage.getItem('cho_session');
    if (raw) return JSON.parse(raw);
    const old = sessionStorage.getItem('cho_admin_session');
    return old ? JSON.parse(old) : null;
  } catch { return null; }
}

function setSession(data) {
  sessionStorage.setItem('cho_session', JSON.stringify(data));
  sessionStorage.removeItem('cho_admin_session');
}

function clearSession() {
  sessionStorage.removeItem('cho_session');
  sessionStorage.removeItem('cho_admin_session');
}

async function loadAuthSession() {
  if (!_sb) {
    window.__lastAuthSessionFailure = {
      reason: 'Supabase client not initialized',
      page: window.location.pathname
    };
    return null;
  }

  const cached = getSession();
  let authSession = null;
  try {
    const { data: authData, error: authError } = await _sb.auth.getSession();
    if (authError) {
      window.__lastAuthSessionFailure = {
        reason: 'Supabase auth session error',
        message: authError.message,
        page: window.location.pathname,
        cachedUsername: cached ? cached.username : null,
        cachedPermissionLevel: cached ? cached.permissionLevel : null
      };
      await logWarn('AUTH_SESSION_MISSING', window.__lastAuthSessionFailure);
      clearSession();
      return null;
    }
    authSession = authData.session;
  } catch (err) {
    window.__lastAuthSessionFailure = {
      reason: 'Supabase auth session exception',
      message: err.message || String(err),
      page: window.location.pathname,
      cachedUsername: cached ? cached.username : null,
      cachedPermissionLevel: cached ? cached.permissionLevel : null
    };
    await logWarn('AUTH_SESSION_MISSING', window.__lastAuthSessionFailure);
    clearSession();
    return null;
  }

  if (!authSession) {
    let lastActivityAt = null;
    let idleExpired = false;
    try {
      const last = parseInt(localStorage.getItem('cho_last_activity') || '0', 10);
      if (last > 0) {
        lastActivityAt = new Date(last).toISOString();
        idleExpired = Date.now() - last > 24 * 60 * 60 * 1000;
      }
    } catch (e) {}
    window.__lastAuthSessionFailure = {
      reason: 'Supabase auth session missing',
      page: window.location.pathname,
      cachedUsername: cached ? cached.username : null,
      cachedPermissionLevel: cached ? cached.permissionLevel : null,
      cachedPermissionRank: cached ? cached.permissionRank : null,
      hasCachedSession: !!cached,
      lastActivityAt,
      idleExpired
    };
    await logInfo('AUTH_SESSION_MISSING', window.__lastAuthSessionFailure);
    clearSession();
    return null;
  }

  if (cached && cached.id === authSession.user.id && cached.isSuperAdmin !== undefined) return cached;

  const { data, error: profileError } = await _sb.rpc('get_my_profile');
  if (profileError || !data) {
    window.__lastAuthSessionFailure = {
      reason: 'Profile RPC returned no profile',
      message: profileError ? profileError.message : null,
      page: window.location.pathname,
      authUserId: authSession.user.id,
      cachedUsername: cached ? cached.username : null
    };
    await logError('AUTH_PROFILE_LOAD_FAIL', window.__lastAuthSessionFailure);
    clearSession();
    return null;
  }

  const perm = data.permission_level;
  const _isSA = data.is_super_admin || false;
  const profile = {
    id: data.id,
    username: data.username,
    displayName: data.display_name,
    userType: data.user_type || 'teacher',
    permissionLevel: perm,
    permissionRank: (typeof getPermRank === 'function') ? getPermRank(perm, _isSA) : ((_isSA && perm === 'admin') ? 110 : ({ admin: 100, evangelist: 90, chief: 80, purchase_teacher: 70, dept_teacher: 60, teacher: 40, student: 20 }[perm] || 0)),
    isSuperAdmin: _isSA,
    isFirstLogin: data.is_first_login,
    departmentId: data.department_id,
    managedDeptId: data.managed_dept_id,
    talentBalance: data.talent_balance || 0,
    departmentName: data.department_name,
    classNumber: data.class_number
  };
  setSession(profile);
  return profile;
}

/* ===== Global Error Handler ===== */

window.addEventListener('error', (e) => {
  logError('JS_ERROR', {
    message: e.message,
    filename: e.filename,
    lineno: e.lineno,
    colno: e.colno
  });
});

window.addEventListener('unhandledrejection', (e) => {
  logError('PROMISE_REJECTION', {
    reason: e.reason ? String(e.reason) : 'Unknown'
  });
});

/* ===== Auto Page View Log ===== */

function autoLogPageView() {
}

const _SOFT_DEL_COL_ERR = 'DB에 삭제 관리 컬럼이 없습니다.\nSupabase SQL Editor에서 아래 SQL을 실행해주세요:\n\nALTER TABLE activity_logs ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;\nALTER TABLE activity_logs ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;';

function _isMissingColErr(msg) {
  return /could not find.*column|column.*does not exist|schema cache/i.test(msg || '');
}

async function deleteLogsByIds(ids) {
  if (!_sb) return { error: 'Supabase not initialized', count: 0 };
  if (!ids || ids.length === 0) return { error: null, count: 0 };
  try {
    const { data, error } = await _sb
      .from('activity_logs')
      .update({ is_deleted: true, deleted_at: new Date().toISOString() })
      .in('id', ids)
      .select('id');
    if (error) {
      if (_isMissingColErr(error.message)) return { error: _SOFT_DEL_COL_ERR, count: 0 };
      return { error: error.message, count: 0 };
    }
    return { error: null, count: data ? data.length : 0 };
  } catch (err) {
    return { error: String(err), count: 0 };
  }
}

async function getPendingOrderCount() {
  if (!_sb) return 0;
  try {
    const session = getSession();
    if (!session || (session.permissionRank || 0) < 60) return 0;
    const myRank = session.permissionRank || 0;
    const isPurchaseTeacher = session.permissionLevel === 'purchase_teacher';
    const { data, error } = await _sb.from('product_orders').select('user_id').neq('status', 'delivered').neq('status', 'cancelled');
    if (error || !data) return 0;
    let orders = data;
    if (!session.isSuperAdmin) {
      const { data: saRows } = await _sb.from('profiles').select('id').eq('is_super_admin', true);
      if (saRows && saRows.length) {
        const saIds = new Set(saRows.map(r => r.id));
        orders = orders.filter(o => !saIds.has(o.user_id));
      }
    }
    if (myRank >= 90 || isPurchaseTeacher) return orders.length;
    const myDepts = new Set([session.managedDeptId, session.departmentId].filter(Boolean));
    if (myDepts.size === 0) return 0;
    const userIds = [...new Set(orders.map(o => o.user_id))];
    if (userIds.length === 0) return 0;
    const { data: profiles } = await _sb.from('profiles').select('id,department_id').in('id', userIds);
    if (!profiles) return 0;
    const deptUsers = new Set(profiles.filter(p => myDepts.has(p.department_id)).map(p => p.id));
    return orders.filter(o => deptUsers.has(o.user_id)).length;
  } catch (e) { return 0; }
}

async function updateNavOrderBadge() {
  const badge = document.getElementById('navOrderBadge');
  if (!badge) return;
  try {
    const cnt = await getPendingOrderCount();
    if (cnt > 0) { badge.textContent = cnt; badge.classList.remove('hidden'); }
    else { badge.classList.add('hidden'); }
  } catch (e) {}
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

/* ===== Q&A Badge (nav "소개" group) ===== */

async function getUnansweredQnaCount() {
  if (!_sb) return 0;
  try {
    const { count, error } = await _sb
      .from('qna')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending')
      .eq('is_deleted', false);
    if (error) return 0;
    return count || 0;
  } catch { return 0; }
}

async function updateQnaBadge() {
  const badge = document.getElementById('navQnaBadge');
  if (!badge) return;
  try {
    const cnt = await getUnansweredQnaCount();
    if (cnt > 0) { badge.textContent = cnt; badge.classList.remove('hidden'); }
    else { badge.classList.add('hidden'); }
  } catch (e) {}
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

async function deleteLogsByDateRange(dateFrom, dateTo, options = {}) {
  if (!_sb) return { error: 'Supabase not initialized', count: 0 };
  try {
    let query = _sb
      .from('activity_logs')
      .update({ is_deleted: true, deleted_at: new Date().toISOString() })
      .gte('created_at', dateFrom)
      .lte('created_at', dateTo)
      .eq('is_deleted', false);
    if (options.level) {
      query = query.eq('level', options.level);
      if (options.excludeUnacknowledged) {
        const ERROR_PLUS = ['ERROR', 'FATAL', 'CRITICAL'];
        if (ERROR_PLUS.includes(options.level)) {
          query = query.eq('is_acknowledged', true);
        }
      }
    } else if (options.excludeUnacknowledged) {
      query = query.or('level.not.in.(ERROR,FATAL,CRITICAL),is_acknowledged.eq.true');
    }
    const { data, error } = await query.select('id');
    if (error) return { error: error.message, count: 0 };
    return { error: null, count: data ? data.length : 0 };
  } catch (err) {
    return { error: String(err), count: 0 };
  }
}
