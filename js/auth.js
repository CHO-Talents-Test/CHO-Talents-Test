/**
 * Authentication Module
 * Supabase Auth 기반 인증 (유형 + 6단계 권한 체계)
 */

function fmtNum(n) { return n == null ? '0' : Number(n).toLocaleString(); }

const _PERMISSION_FALLBACK = {
  admin: { rank: 100, label: '관리자', emoji: '👑' },
  evangelist: { rank: 90, label: '전도사님', emoji: '✝️' },
  chief: { rank: 80, label: '부장 교사', emoji: '📋' },
  purchase_teacher: { rank: 70, label: '구매 담당 교사', emoji: '🛒' },
  dept_teacher: { rank: 60, label: '부서 담당 교사', emoji: '👩‍🏫' },
  teacher: { rank: 40, label: '일반 교사', emoji: '👨‍🏫' },
  student: { rank: 20, label: '학생', emoji: '🎒' },
  super_admin: { rank: 110, label: '최고 관리자', emoji: '⭐' }
};

const PERMISSION_RANK = Object.fromEntries(Object.entries(_PERMISSION_FALLBACK).map(([k, v]) => [
  k,
  (typeof getCodeRank === 'function') ? getCodeRank('profiles.permission_level', k, v.rank) : v.rank
]));

const PERMISSION_LABELS = Object.fromEntries(Object.entries(_PERMISSION_FALLBACK).map(([k, v]) => [
  k,
  (typeof getCodeLabel === 'function') ? getCodeLabel('profiles.permission_level', k, v.label) : v.label
]));

const PERMISSION_EMOJI = Object.fromEntries(Object.entries(_PERMISSION_FALLBACK).map(([k, v]) => [
  k,
  (typeof getCodeEmoji === 'function') ? getCodeEmoji('profiles.permission_level', k, v.emoji) : v.emoji
]));

const TYPE_LABELS = (typeof codeMap === 'function')
  ? codeMap('profiles.user_type', 'value')
  : { teacher: '교사', student: '학생' };

const PERMISSION_REDIRECT = {
  admin: 'index.html',
  evangelist: 'index.html',
  chief: 'index.html',
  purchase_teacher: 'index.html',
  dept_teacher: 'index.html',
  teacher: 'index.html',
  student: 'index.html'
};

const ROLE_REDIRECT = {
  admin: 'index.html',
  dept_manager: 'index.html',
  teacher: 'index.html',
  student: 'index.html'
};

function getPermRank(level, isSuperAdmin) {
  if (isSuperAdmin && level === 'admin') return 110;
  if (typeof getCodeRank === 'function') return getCodeRank('profiles.permission_level', level, PERMISSION_RANK[level] || 0);
  return PERMISSION_RANK[level] || 0;
}

function applyPermNav(rank) {
  document.querySelectorAll('[data-min-perm]').forEach(el => {
    const minPerm = parseInt(el.dataset.minPerm, 10);
    el.style.display = rank >= minPerm ? '' : 'none';
  });
  hideEmptyDropdowns();
}
const applyRoleNav = applyPermNav;

function hideEmptyDropdowns() {
  document.querySelectorAll('.nav-dropdown-menu').forEach(menu => {
    const items = menu.querySelectorAll('li');
    const hasVisible = Array.from(items).some(li => li.style.display !== 'none');
    const parentLi = menu.closest('.admin-nav-links > li, .top-nav-links > li');
    if (parentLi && !parentLi.hasAttribute('data-min-perm') && !parentLi.hasAttribute('data-auth-only')) {
      if (!hasVisible) parentLi.style.display = 'none';
      else parentLi.style.display = '';
    }
  });
  updateNavGroupBadges();
}

function updateNavGroupBadges() {
  document.querySelectorAll('.nav-dropdown-menu').forEach(menu => {
    const badges = menu.querySelectorAll('.badge:not(.hidden)');
    let sum = 0;
    badges.forEach(b => { const n = parseInt(b.textContent, 10); if (n > 0) sum += n; });
    const toggle = menu.parentElement ? menu.parentElement.querySelector('.nav-dropdown-toggle') : null;
    if (!toggle) return;
    let groupBadge = toggle.querySelector('.nav-group-badge');
    if (sum > 0) {
      if (!groupBadge) {
        groupBadge = document.createElement('span');
        groupBadge.className = 'nav-group-badge';
        groupBadge.style.cssText = 'display:inline-flex;align-items:center;justify-content:center;min-width:16px;height:16px;font-size:0.65rem;background:#e03131;color:#fff;border-radius:50%;margin-left:0.3rem;padding:0 3px;';
        toggle.appendChild(groupBadge);
      }
      groupBadge.textContent = sum;
      groupBadge.style.display = 'inline-flex';
    } else if (groupBadge) {
      groupBadge.style.display = 'none';
    }
  });
}

function renderRoleBadge(elementId, session, basePath) {
  const el = document.getElementById(elementId);
  if (!el || !session) return;
  const perm = session.permissionLevel;
  const emoji = PERMISSION_EMOJI[perm] || '👤';
  const label = PERMISSION_LABELS[perm] || perm;
  const name = session.displayName || session.username;
  const uid = session.username || '';
  const redirect = PERMISSION_REDIRECT[perm] || '#';
  const href = (basePath || '') + redirect;
  el.innerHTML = `<a href="${href}" style="text-decoration:none;color:inherit;display:inline-flex;align-items:center;gap:0.3rem;" title="${label} 페이지로 이동">
    <span style="font-size:1.1rem;">${emoji}</span>
    <span>${name} <span style="font-size:0.75rem;color:#222;">(${uid})</span></span>
    <span style="font-size:0.7rem;background:rgba(255,255,255,0.2);padding:0.1rem 0.4rem;border-radius:50px;">${label}</span>
  </a>`;
}

async function login(username, password) {
  if (!_sb) return { success: false, error: 'Supabase 연결 실패' };
  if (!username || !password) return { success: false, error: '아이디와 비밀번호를 입력해주세요.' };

  try {
    const email = username + AUTH_EMAIL_DOMAIN;
    const { data: authData, error: authError } = await _sb.auth.signInWithPassword({ email, password });

    if (authError) {
      await logWarn('LOGIN_FAIL', { 대상: username, 사유: authError.message });
      return { success: false, error: '아이디 또는 비밀번호가 일치하지 않습니다.' };
    }

    const { data: profile } = await _sb.rpc('get_my_profile');
    if (!profile) {
      await _sb.auth.signOut();
      return { success: false, error: '프로필 정보를 불러올 수 없습니다.' };
    }

    const perm = profile.permission_level;
    const _isSA = profile.is_super_admin || false;
    setSession({
      id: profile.id,
      username: profile.username,
      displayName: profile.display_name,
      userType: profile.user_type || 'teacher',
      permissionLevel: perm,
      permissionRank: getPermRank(perm, _isSA),
      isSuperAdmin: _isSA,
      isFirstLogin: profile.is_first_login,
      departmentId: profile.department_id,
      managedDeptId: profile.managed_dept_id,
      talentBalance: profile.talent_balance || 0,
      departmentName: profile.department_name,
      classNumber: profile.class_number
    });

    await logInfo('LOGIN_SUCCESS', { 대상: username, permissionLevel: perm });
    try { await _sb.rpc('update_last_login'); } catch(e) {}
    _touchActivity();
    return { success: true, data: profile };
  } catch (err) {
    await logError('LOGIN_ERROR', { 대상: username, 오류: String(err) });
    return { success: false, error: '로그인 처리 중 오류가 발생했습니다.' };
  }
}

function getRedirectUrl(session, basePath) {
  const base = basePath || '';
  const perm = session.permissionLevel;
  const path = PERMISSION_REDIRECT[perm] || 'login.html';
  return base + path;
}

function getRoleRedirectUrl(role, basePath) {
  const base = basePath || '';
  const path = PERMISSION_REDIRECT[role] || ROLE_REDIRECT[role] || 'login.html';
  return base + path;
}

function resolveAppUrl(url, baseUrl) {
  try {
    return new URL(url || '', baseUrl || window.location.href).href;
  } catch (e) {
    return url || '';
  }
}

function buildUrlWithRedirect(url, redirectUrl) {
  const resolved = resolveAppUrl(url);
  if (!redirectUrl) return resolved;
  try {
    const target = new URL(resolved);
    target.searchParams.set('redirect', redirectUrl);
    return target.href;
  } catch (e) {
    const sep = resolved.includes('?') ? '&' : '?';
    return resolved + sep + 'redirect=' + encodeURIComponent(redirectUrl);
  }
}

function getRedirectTargetFromQuery(defaultUrl) {
  try {
    const raw = new URLSearchParams(window.location.search).get('redirect');
    if (!raw) return defaultUrl || null;
    const resolved = resolveAppUrl(raw);
    if (!resolved) return defaultUrl || null;
    try {
      const parsed = new URL(resolved);
      if (parsed.protocol !== window.location.protocol && parsed.origin !== window.location.origin) {
        return defaultUrl || null;
      }
      if (parsed.pathname.endsWith('/login.html') || parsed.pathname.endsWith('login.html')) {
        return defaultUrl || null;
      }
    } catch (e) {}
    return resolved;
  } catch (e) {
    return defaultUrl || null;
  }
}

function buildLoginRedirectUrl(loginPath, redirectUrl) {
  return buildUrlWithRedirect(loginPath || '../login.html', redirectUrl);
}

function getTalentReceiveUrl(code) {
  const base = window.location.pathname.includes('/admin/') ? '../talent-receive.html' : 'talent-receive.html';
  const resolved = resolveAppUrl(base);
  return code ? resolved + '?code=' + encodeURIComponent(code) : resolved;
}

async function logout(loginPath) {
  const session = getSession();
  if (session) {
    await logInfo('LOGOUT', { 대상: session.username });
  }
  if (_sb) {
    await _sb.auth.signOut();
  }
  clearSession();
  if (_sessionTimer) { clearTimeout(_sessionTimer); _sessionTimer = null; }
  try { localStorage.removeItem(SESSION_ACTIVITY_KEY); } catch (e) {}
  if (typeof applyTheme === 'function') applyTheme('default');
  window.location.href = resolveAppUrl(loginPath || '../login.html');
}

function requirePermission(minRank, loginPath) {
  const session = getSession();
  if (!session) {
    window.location.href = resolveAppUrl(loginPath || '../login.html');
    return null;
  }
  const rank = session.permissionRank || getPermRank(session.permissionLevel);
  if (rank < minRank) {
    window.location.href = resolveAppUrl(loginPath || '../login.html');
    return null;
  }
  return session;
}

function requireRole(allowedRoles, loginPath) {
  const session = getSession();
  if (!session) {
    window.location.href = resolveAppUrl(loginPath || '../login.html');
    return null;
  }
  const perm = session.permissionLevel;
  if (!allowedRoles.includes(perm)) {
    window.location.href = resolveAppUrl(loginPath || '../login.html');
    return null;
  }
  return session;
}

async function validateAuthSession(loginPath) {
  if (!_sb) return null;
  const { data: { session: authSession } } = await _sb.auth.getSession();
  if (!authSession) {
    clearSession();
    window.location.href = buildLoginRedirectUrl(loginPath || '../login.html', window.location.href);
    return null;
  }
  return getSession();
}

function _getAuthRedirectBase(loginPath) {
  return loginPath ? loginPath.replace(/[^/]*$/, '') : '../';
}

async function _logAuthRedirect(reason, session, target, extra) {
  if (typeof logWarn !== 'function') return;
  const details = Object.assign({
    사유: reason,
    요청페이지: window.location.pathname,
    pageId: typeof detectCurrentPageId === 'function' ? detectCurrentPageId() : null,
    이동대상: target,
    사용자: session ? session.username : null,
    권한: session ? session.permissionLevel : null,
    권한등급: session ? session.permissionRank : null,
    최고관리자: session ? !!session.isSuperAdmin : false
  }, extra || {});
  await logWarn('AUTH_REDIRECT', details);
}

async function initPage(allowedRolesOrMinRank, loginPath) {
  const session = await loadAuthSession();
  if (!session) {
    const target = buildLoginRedirectUrl(loginPath || '../login.html', window.location.href);
    await _logAuthRedirect('세션 없음 또는 만료', null, target, {
      필요조건: allowedRolesOrMinRank,
      세션실패: window.__lastAuthSessionFailure || null
    });
    window.location.href = target;
    return null;
  }

  if (session.isFirstLogin && !window.location.pathname.includes('change-password')) {
    const target = buildUrlWithRedirect(_getAuthRedirectBase(loginPath) + 'admin/change-password.html', window.location.href);
    await _logAuthRedirect('첫 로그인 비밀번호 변경 필요', session, target, {
      필요조건: allowedRolesOrMinRank
    });
    window.location.href = target;
    return null;
  }

  const rank = session.permissionRank || getPermRank(session.permissionLevel);

  if (typeof allowedRolesOrMinRank === 'number') {
    if (rank < allowedRolesOrMinRank) {
      const basePath = _getAuthRedirectBase(loginPath);
      const target = getRedirectUrl(session, basePath);
      await _logAuthRedirect('권한 등급 부족', session, target, {
        필요권한등급: allowedRolesOrMinRank,
        실제권한등급: rank
      });
      window.location.href = target;
      return null;
    }
  } else if (Array.isArray(allowedRolesOrMinRank) && allowedRolesOrMinRank.length) {
    const perm = session.permissionLevel;
    if (!allowedRolesOrMinRank.includes(perm)) {
      const basePath = _getAuthRedirectBase(loginPath);
      const target = getRedirectUrl(session, basePath);
      await _logAuthRedirect('허용 권한 목록 불일치', session, target, {
        허용권한: allowedRolesOrMinRank,
        실제권한: perm
      });
      window.location.href = target;
      return null;
    }
  }

  document.body.classList.add('auth-ready');
  if (typeof startSessionTimer === 'function') startSessionTimer();

  if (typeof _sb !== 'undefined' && _sb) {
    try {
      const roleKey = session.isSuperAdmin ? 'super_admin' : session.permissionLevel;
      const { data: accessData } = await _sb.from('role_page_access').select('*').eq('role_key', roleKey);
      if (accessData && accessData.length > 0) {
        const pageId = detectCurrentPageId();
        const pageAccess = accessData.find(a => a.page_id === pageId);
        if (pageAccess && pageAccess.can_access === false) {
          const minRank = typeof allowedRolesOrMinRank === 'number' ? allowedRolesOrMinRank : 0;
          if (rank < minRank || minRank === 0) {
            const basePath = _getAuthRedirectBase(loginPath);
            const target = getRedirectUrl(session, basePath);
            await _logAuthRedirect('DB 페이지 접근 권한 차단', session, target, {
              pageId,
              roleKey,
              필요권한등급: minRank,
              실제권한등급: rank,
              rolePageAccessId: pageAccess.id || null
            });
            window.location.href = target;
            return null;
          }
        }
        if (pageAccess && pageAccess.hidden_elements && pageAccess.hidden_elements.length > 0) {
          pageAccess.hidden_elements.forEach(elId => {
            const el = document.getElementById(elId);
            if (el) el.style.display = 'none';
          });
        }
      }
    } catch (e) {
      console.warn('[AUTH] role_page_access check skipped:', e.message);
      if (typeof logError === 'function') {
        await logError('AUTH_PAGE_ACCESS_CHECK_FAIL', {
          요청페이지: window.location.pathname,
          pageId: typeof detectCurrentPageId === 'function' ? detectCurrentPageId() : null,
          권한: session.permissionLevel,
          권한등급: rank,
          오류: e.message || String(e)
        });
      }
    }
  }

  return session;
}

function detectCurrentPageId() {
  const path = window.location.pathname;
  if (path.includes('admin/index.html') || path.endsWith('admin/')) return 'admin-dashboard';
  if (path.includes('admin/users.html')) return 'admin-users';
  if (path.includes('admin/bulk-register.html')) return 'admin-bulk-register';
  if (path.includes('admin/departments.html')) return 'admin-departments';
  if (path.includes('admin/managers.html')) return 'admin-managers';
  if (path.includes('admin/talents.html')) return 'admin-talents';
  if (path.includes('admin/talent-adjustments.html')) return 'admin-talent-adjustments';
  if (path.includes('admin/talent-stats.html')) return 'admin-talent-stats';
  if (path.includes('admin/talent-qr.html')) return 'admin-talent-qr';
  if (path.includes('admin/shop.html')) return 'admin-shop';
  if (path.includes('admin/purchases.html')) return 'admin-purchases';
  if (path.includes('admin/purchase-stats.html')) return 'admin-purchase-stats';
  if (path.includes('admin/reports.html')) return 'admin-reports';
  if (path.includes('admin/logs.html')) return 'admin-logs';
  if (path.includes('admin/log-rules.html')) return 'admin-log-rules';
  if (path.includes('admin/slack-rules.html')) return 'admin-slack-rules';
  if (path.includes('admin/notices.html')) return 'admin-notices';
  if (path.includes('admin/versions.html')) return 'admin-versions';
  if (path.includes('admin/talent-items.html')) return 'admin-talent-items';
  if (path.includes('admin/page-access.html')) return 'admin-page-access';
  if (path.includes('admin/page-features.html')) return 'admin-page-features';
  if (path.includes('admin/page-permissions.html')) return 'admin-page-perms';
  if (path.includes('docs/page-permission-rules.html')) return 'docs-page-permission-rules';
  if (path.includes('admin/audit-rules.html')) return 'admin-audit-rules';
  if (path.includes('admin/audit.html')) return 'admin-audit';
  if (path.includes('talent-receive.html')) return 'talent-receive';
  if (path.includes('my-talents.html')) return 'my-talents';
  if (path.includes('my-orders.html')) return 'my-orders';
  if (path.includes('dept-teacher-guide.html')) return 'dept-teacher-guide';
  if (path.includes('purchase-teacher-guide.html')) return 'purchase-teacher-guide';
  if (path.includes('chief-teacher-guide.html')) return 'chief-teacher-guide';
  if (path.includes('evangelist-guide.html')) return 'evangelist-guide';
  if (path.includes('earn-talents.html')) return 'earn-talents';
  if (path.includes('shop.html')) return 'shop';
  if (path.includes('login.html')) return 'login';
  if (path.includes('register.html')) return 'register';
  return 'index';
}

async function changePassword(username, newPassword) {
  if (!_sb) return { success: false, error: 'Supabase 연결 실패' };
  if (!newPassword || newPassword.length < 4) {
    return { success: false, error: '비밀번호는 4자 이상이어야 합니다.' };
  }

  try {
    const { data, error } = await _sb.rpc('change_my_password', { p_new_password: newPassword });

    if (error) {
      await logError('PASSWORD_CHANGE_FAIL', { 대상: username, 사유: error.message });
      return { success: false, error: '비밀번호 변경 중 오류가 발생했습니다.' };
    }
    if (data && !data.success) {
      return { success: false, error: data.error || '비밀번호 변경 실패' };
    }

    const session = getSession();
    if (session) {
      session.isFirstLogin = false;
      setSession(session);
    }

    await logInfo('PASSWORD_CHANGE', { 대상: username });
    return { success: true };
  } catch (err) {
    await logError('PASSWORD_CHANGE_ERROR', { 대상: username, 오류: String(err) });
    return { success: false, error: '비밀번호 변경 중 오류가 발생했습니다.' };
  }
}

const _ERR_MAP = [
  [/Already given this item this week/i, '이번 주에 이미 지급된 항목입니다'],
  [/Already given this item today/i, '오늘 이미 지급된 항목입니다'],
  [/Already given/i, '이미 지급된 항목입니다'],
  [/Invalid login credentials/i, '아이디 또는 비밀번호가 올바르지 않습니다'],
  [/User not found/i, '사용자를 찾을 수 없습니다'],
  [/User already registered/i, '이미 등록된 사용자입니다'],
  [/Email not confirmed/i, '이메일 인증이 완료되지 않았습니다'],
  [/Password should be at least/i, '비밀번호는 최소 6자 이상이어야 합니다'],
  [/duplicate key.*username/i, '이미 사용 중인 아이디입니다'],
  [/duplicate key/i, '이미 존재하는 데이터입니다'],
  [/violates check constraint/i, '입력값이 허용 범위를 벗어났습니다'],
  [/violates foreign key/i, '참조하는 데이터가 존재하지 않습니다'],
  [/violates row-level security/i, '해당 작업에 대한 권한이 없습니다'],
  [/new row violates/i, '데이터 저장 권한이 없습니다'],
  [/Super admin can only be modified by themselves/i, '최고관리자 계정은 본인만 수정할 수 있습니다'],
  [/Super admin cannot be deleted/i, '최고관리자 계정은 삭제할 수 없습니다'],
  [/Cannot modify user with higher permission/i, '본인보다 높은 권한의 사용자는 수정할 수 없습니다'],
  [/Cannot assign permission higher than your own/i, '본인보다 높은 권한은 부여할 수 없습니다'],
  [/permission denied/i, '권한이 없습니다'],
  [/column .* does not exist/i, 'DB 스키마 업데이트가 필요합니다. 관리자에게 문의하세요'],
  [/Could not find.*column.*schema cache/i, 'DB 스키마 업데이트가 필요합니다. 관리자에게 문의하세요'],
  [/relation .* does not exist/i, 'DB 테이블이 존재하지 않습니다. 관리자에게 문의하세요'],
  [/function .* does not exist/i, 'DB 함수가 존재하지 않습니다. 관리자에게 문의하세요'],
  [/Could not find the function/i, 'DB 함수를 찾을 수 없습니다. 관리자에게 문의하세요'],
  [/JWT expired/i, '인증이 만료되었습니다. 다시 로그인해주세요'],
  [/JWT issued at future/i, '기기 시간이 서버보다 앞서 있습니다. 자동 날짜/시간을 켠 뒤 다시 로그인해주세요'],
  [/JWT/i, '인증 오류가 발생했습니다. 다시 로그인해주세요'],
  [/network/i, '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요'],
  [/timeout/i, '요청 시간이 초과되었습니다. 다시 시도해주세요'],
  [/fetch failed/i, '서버 연결에 실패했습니다. 잠시 후 다시 시도해주세요'],
  [/Insufficient talent/i, '달란트가 부족합니다'],
  [/not enough/i, '잔액이 부족합니다'],
];

function tErr(msg) {
  if (!msg) return '알 수 없는 오류가 발생했습니다';
  const s = typeof msg === 'object' ? (msg.message || JSON.stringify(msg)) : String(msg);
  if (/^[가-힣\s.,!?:;()\d\-_/]+$/.test(s)) return s;
  for (const [re, ko] of _ERR_MAP) {
    if (re.test(s)) return ko;
  }
  return '오류가 발생했습니다 (' + s.substring(0, 80) + ')';
}

document.addEventListener('DOMContentLoaded', () => { if (typeof hideEmptyDropdowns === 'function') hideEmptyDropdowns(); });

/* ===== Session Timeout (24h idle timer) ===== */
const SESSION_TIMEOUT_MS = 24 * 60 * 60 * 1000;
const SESSION_ACTIVITY_KEY = 'cho_last_activity';
let _sessionTimer = null;
let _activityDebounce = null;

function _touchActivity() {
  try { localStorage.setItem(SESSION_ACTIVITY_KEY, String(Date.now())); } catch (e) {}
}

function _checkSessionExpiry() {
  const last = parseInt(localStorage.getItem(SESSION_ACTIVITY_KEY) || '0', 10);
  if (last > 0 && Date.now() - last > SESSION_TIMEOUT_MS) {
    return true;
  }
  return false;
}

function _onUserActivity() {
  if (_activityDebounce) return;
  _activityDebounce = setTimeout(() => { _activityDebounce = null; }, 60000);
  _touchActivity();
  _resetSessionTimer();
}

function _resetSessionTimer() {
  if (_sessionTimer) clearTimeout(_sessionTimer);
  _sessionTimer = setTimeout(async () => {
    const s = typeof getSession === 'function' ? getSession() : null;
    if (!s) return;
    alert('세션이 만료되었습니다. 다시 로그인해주세요.');
    if (typeof logout === 'function') {
      const loginPath = window.location.pathname.includes('/admin/') || window.location.pathname.includes('/docs/') ? '../login.html' : 'login.html';
      const target = buildLoginRedirectUrl(loginPath, window.location.href);
      await _logAuthRedirect('24시간 비활성 세션 만료', s, target, { 만료기준: 'idle_timer' });
      await logout(target);
    }
  }, SESSION_TIMEOUT_MS);
}

async function startSessionTimer() {
  if (_checkSessionExpiry()) {
    const s = typeof getSession === 'function' ? getSession() : null;
    clearSession();
    const loginPath = window.location.pathname.includes('/admin/') || window.location.pathname.includes('/docs/') ? '../login.html' : 'login.html';
    if (!window.location.pathname.includes('login.html') && !window.location.pathname.includes('register.html')) {
      const target = buildLoginRedirectUrl(loginPath, window.location.href);
      await _logAuthRedirect('24시간 비활성 세션 만료', s, target, { 만료기준: 'last_activity' });
      window.location.href = target;
    }
    return;
  }
  _touchActivity();
  _resetSessionTimer();
  ['click', 'keydown', 'scroll', 'mousemove', 'touchstart'].forEach(evt => {
    document.addEventListener(evt, _onUserActivity, { passive: true });
  });
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
      if (_checkSessionExpiry()) {
        const s = typeof getSession === 'function' ? getSession() : null;
        if (s) {
          alert('세션이 만료되었습니다. 다시 로그인해주세요.');
          const loginPath = window.location.pathname.includes('/admin/') || window.location.pathname.includes('/docs/') ? '../login.html' : 'login.html';
          if (typeof logout === 'function') {
            const target = buildLoginRedirectUrl(loginPath, window.location.href);
            _logAuthRedirect('24시간 비활성 세션 만료', s, target, { 만료기준: 'visibilitychange' })
              .finally(() => logout(target));
          }
        }
      } else {
        _onUserActivity();
      }
    }
  });
  window.addEventListener('storage', (e) => {
    if (e.key === SESSION_ACTIVITY_KEY && e.newValue) {
      _resetSessionTimer();
    }
  });
}
