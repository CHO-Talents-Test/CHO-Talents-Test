/**
 * Centralized Navigation Module
 * Generates and manages navigation for all pages
 */

const NAV_MENU = [
  {
    id: 'intro',
    label: '소개',
    items: [
      { href: 'guide.html', label: '가이드', guide: true },
      { href: 'earn-talents.html', label: '달란트 적립' },
      { href: 'qna.html', label: 'Q & A', badgeId: 'navQnaBadge' }
    ]
  },
  {
    id: 'talent',
    label: '달란트',
    authOnly: true,
    items: [
      { href: 'my-talents.html', label: '내 달란트', id: 'navMyTalent', authOnly: true },
      { href: 'talent-receive.html', label: '달란트 수령', authOnly: true },
      { href: 'admin/talents.html', label: '달란트 관리', minPerm: 40 },
      { href: 'admin/talent-items.html', label: '달란트 항목 관리', minPerm: 60 },
      { href: 'admin/talent-stats.html', label: '달란트 통계', minPerm: 60 },
      { href: 'admin/talent-qr.html', label: '달란트 QR 관리', minPerm: 90 }
    ]
  },
  {
    id: 'shop',
    label: '상품',
    items: [
      { href: 'shop.html', label: '상품 구매' },
      { href: 'my-orders.html', label: '내 구매 상품', id: 'navMyOrders', authOnly: true },
      { href: 'admin/shop.html', label: '상품 관리', minPerm: 60 },
      { href: 'admin/purchases.html', label: '구매 관리', minPerm: 60, badgeId: 'navOrderBadge' },
      { href: 'admin/purchase-stats.html', label: '구매 통계', minPerm: 60 }
    ]
  },
  {
    id: 'manage',
    label: '관리',
    minPerm: 60,
    items: [
      { href: 'admin/index.html', label: '대시보드', minPerm: 60 },
      { href: 'admin/users.html', label: '사용자 관리', minPerm: 60, id: 'navUsers', badgeId: 'navUserBadge' },
      { href: 'admin/bulk-register.html', label: '학생 일괄 등록', minPerm: 80 },
      { href: 'admin/managers.html', label: '관리자 관리', minPerm: 80 },
      { href: 'admin/departments.html', label: '부서 관리', minPerm: 60 }
    ]
  },
  {
    id: 'operation',
    label: '운영',
    minPerm: 80,
    items: [
      { href: 'admin/page-access.html', label: '페이지 접근', minPerm: 100 },
      { href: 'admin/page-features.html', label: '페이지 기능', minPerm: 100 },
      { href: 'docs/page-permission-rules.html', label: '페이지 권한 룰', minPerm: 80 },
      { href: 'admin/log-rules.html', label: '로그 작성 룰', minPerm: 80 },
      { href: 'admin/slack-rules.html', label: 'Slack 알림 룰', minPerm: 80 },
      { href: 'admin/audit-rules.html', label: '작업 이력 작성 룰', minPerm: 80 },
      { href: 'admin/notices.html', label: '공지 관리', minPerm: 90 },
      { href: 'admin/versions.html', label: '버전', minPerm: 80 },
      { href: 'admin/reports.html', label: '보고서', minPerm: 80 },
      { href: 'admin/audit.html', label: '작업 이력', minPerm: 100 },
      { href: 'admin/logs.html', label: '로그', minPerm: 100, id: 'navLogs', badgeId: 'navLogBadge' }
    ]
  }
];

const GUIDE_HREFS = [
  'guide.html',
  'teacher-guide.html',
  'dept-teacher-guide.html',
  'purchase-teacher-guide.html',
  'chief-teacher-guide.html',
  'evangelist-guide.html',
  'admin-guide.html'
];

function _navBasePath() {
  const path = window.location.pathname;
  if (path.includes('/admin/') || path.endsWith('/admin') ||
      path.includes('/docs/') || path.endsWith('/docs')) return '../';
  return '';
}

function _navResolveHref(href) {
  const base = _navBasePath();
  return base + href;
}

function _navCurrentPath() {
  const pathname = window.location.pathname;
  const trimmed = pathname.replace(/\/+$/, '');
  const parts = trimmed.split('/').filter(Boolean);

  if (!trimmed || pathname.endsWith('/')) {
    if (parts[parts.length - 1] === 'admin') return 'admin/index.html';
    return 'index.html';
  }

  const adminIdx = parts.indexOf('admin');
  if (adminIdx >= 0) return parts.slice(adminIdx).join('/');

  const docsIdx = parts.indexOf('docs');
  if (docsIdx >= 0) return parts.slice(docsIdx).join('/');

  return parts[parts.length - 1] || 'index.html';
}

function _navTargetPath(href) {
  return href.replace(/^\.\//, '').replace(/^\.\.\//, '');
}

function _navIsActive(href) {
  return _navCurrentPath() === _navTargetPath(href);
}

function _navGroupIsActive(items) {
  return items.some(item => item.guide ? GUIDE_HREFS.some(_navIsActive) : _navIsActive(item.href));
}

function _navItemAttrs(item) {
  const attrs = [];
  if (item.minPerm) attrs.push(`data-min-perm="${item.minPerm}"`);
  if (item.id) attrs.push(`id="${item.id}"`);
  if (item.authOnly) attrs.push('data-auth-only="true"');
  if (item.guide) attrs.push('data-guide-link="true"');
  if (item.minPerm || item.authOnly) attrs.push('style="display:none;"');
  return attrs.length ? ' ' + attrs.join(' ') : '';
}

function _navGuideHrefForSession(session) {
  if (!session) return 'guide.html';
  if (session.isSuperAdmin || session.permissionLevel === 'admin') return 'admin-guide.html';
  if (session.permissionLevel === 'evangelist') return 'evangelist-guide.html';
  if (session.permissionLevel === 'chief') return 'chief-teacher-guide.html';
  if (session.permissionLevel === 'purchase_teacher') return 'purchase-teacher-guide.html';
  if (session.permissionLevel === 'dept_teacher') return 'dept-teacher-guide.html';
  if (session.permissionLevel === 'teacher') return 'teacher-guide.html';
  return 'guide.html';
}

function _navBrandLabel() {
  const env = (window.CHO_TALENTS_CONFIG && window.CHO_TALENTS_CONFIG.env) || 'DEV';
  return env === 'DEV' ? '달란트 마을 (DEV)' : '달란트 마을';
}

function _navUpdateGuideHref(session) {
  const guideItem = document.querySelector('[data-guide-link="true"]');
  const link = guideItem ? guideItem.querySelector('a') : null;
  if (!link) return;
  const href = _navGuideHrefForSession(session);
  link.href = _navResolveHref(href);
  link.classList.toggle('active', _navIsActive(href));
}

function renderNav(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;

  let html = `<nav class="admin-nav" id="mainNavBar">`;
  html += `<a href="${_navResolveHref('index.html')}" class="admin-nav-brand"><span class="brand-icon">⭐</span> ${_navBrandLabel()}</a>`;

  html += `<div class="nav-header-actions" id="navHeaderActions">`;
  html += `<div id="navThemePicker"></div>`;
  html += `<button class="nav-hamburger" id="navHamburger" aria-label="메뉴 열기">&#9776;</button>`;
  html += `<button class="nav-header-logout" id="navLogoutBtn" style="display:none;">로그아웃</button>`;
  html += `<span id="navLoginArea"><a href="${_navResolveHref('login.html')}" class="nav-header-login">로그인</a></span>`;
  html += `<span id="navAuthArea" style="display:none;"><span class="nav-user" id="navUser"></span></span>`;
  html += `</div>`;
  html += `<ul class="admin-nav-links" id="navLinks">`;

  NAV_MENU.forEach(group => {
    const groupActive = _navGroupIsActive(group.items);
    const hideGroup = group.minPerm || group.authOnly;
    const permAttr = group.minPerm ? ` data-min-perm="${group.minPerm}"` : '';
    const authAttr = group.authOnly ? ' data-auth-only="true"' : '';
    const styleAttr = hideGroup ? ' style="display:none;"' : '';
    html += `<li${permAttr}${authAttr}${styleAttr}>`;
    html += `<button class="nav-dropdown-toggle${groupActive ? ' active' : ''}">${group.label}</button>`;
    html += `<ul class="nav-dropdown-menu">`;
    group.items.forEach(item => {
      const active = _navIsActive(item.href);
      html += `<li${_navItemAttrs(item)}>`;
      html += `<a href="${_navResolveHref(item.href)}"${active ? ' class="active"' : ''}>`;
      html += item.label;
      if (item.badgeId) html += ` <span class="badge hidden" id="${item.badgeId}">0</span>`;
      html += `</a></li>`;
    });
    html += `</ul></li>`;
  });

  html += `</ul></nav>`;

  container.innerHTML = html;
  _navBindEvents();
  _navInitThemePicker();
}

function _navBindEvents() {
  const hamburger = document.getElementById('navHamburger');
  const navLinks = document.getElementById('navLinks');
  if (hamburger && navLinks) {
    hamburger.addEventListener('click', () => {
      navLinks.classList.toggle('nav-open');
    });
  }

  document.querySelectorAll('.nav-dropdown-toggle').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const li = btn.parentElement;
      const wasOpen = li.classList.contains('dropdown-open');
      document.querySelectorAll('.dropdown-open, .mobile-open').forEach(el => {
        el.classList.remove('dropdown-open', 'mobile-open');
      });
      if (!wasOpen) {
        li.classList.add('dropdown-open', 'mobile-open');
        _navPositionDropdown(li);
      }
    });
  });

  document.addEventListener('click', () => {
    document.querySelectorAll('.dropdown-open, .mobile-open').forEach(el => {
      el.classList.remove('dropdown-open', 'mobile-open');
    });
  });

  const logoutBtn = document.getElementById('navLogoutBtn');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', () => {
      if (typeof logout === 'function') {
        logout(_navResolveHref('login.html'));
      }
    });
  }
}

function _navPositionDropdown(li) {
  const menu = li.querySelector('.nav-dropdown-menu');
  if (!menu || window.innerWidth <= 768) return;
  menu.style.left = '';
  menu.style.right = '';
  menu.style.transform = '';

  const rect = menu.getBoundingClientRect();
  const viewportWidth = window.innerWidth;

  if (rect.right > viewportWidth - 10) {
    menu.style.left = 'auto';
    menu.style.right = '0';
    menu.style.transform = 'none';
  } else if (rect.left < 10) {
    menu.style.left = '0';
    menu.style.right = 'auto';
    menu.style.transform = 'none';
  }
}

function _navInitThemePicker() {
  if (typeof renderThemePicker === 'function') {
    renderThemePicker('navThemePicker');
  }
}

function navUpdateAuth(session) {
  const loginArea = document.getElementById('navLoginArea');
  const authArea = document.getElementById('navAuthArea');
  const logoutBtn = document.getElementById('navLogoutBtn');
  const navUser = document.getElementById('navUser');
  const navMyTalent = document.getElementById('navMyTalent');
  const navMyOrders = document.getElementById('navMyOrders');

  if (session) {
    _navUpdateGuideHref(session);
    if (loginArea) loginArea.style.display = 'none';
    if (authArea) authArea.style.display = '';
    if (logoutBtn) logoutBtn.style.display = '';
    if (navUser) {
      const perm = session.permissionLevel;
      const emoji = (typeof PERMISSION_EMOJI !== 'undefined') ? (PERMISSION_EMOJI[perm] || '👤') : '👤';
      const name = session.displayName || session.username;
      navUser.innerHTML = `${emoji} ${name}`;
    }
    if (navMyTalent) navMyTalent.style.display = '';
    if (navMyOrders) navMyOrders.style.display = '';

    document.querySelectorAll('[data-auth-only]').forEach(el => {
      el.style.display = '';
    });

    const rank = session.permissionRank || 0;
    if (typeof applyPermNav === 'function') applyPermNav(rank);

    if (rank >= 60) {
      if (typeof updatePendingBadge === 'function') updatePendingBadge();
      if (typeof updateNavOrderBadge === 'function') updateNavOrderBadge();
      if (typeof updateQnaBadge === 'function') updateQnaBadge();
    }
    if (rank >= 80) {
      if (typeof updateLogBadge === 'function') updateLogBadge();
    }
  } else {
    _navUpdateGuideHref(null);
    if (loginArea) loginArea.style.display = '';
    if (authArea) authArea.style.display = 'none';
    if (logoutBtn) logoutBtn.style.display = 'none';
    document.querySelectorAll('[data-auth-only]').forEach(el => {
      el.style.display = 'none';
    });
  }
}

async function navInit() {
  renderNav('nav-container');
  if (typeof initTheme === 'function') {
    await initTheme();
  }
  const session = typeof getSession === 'function' ? getSession() : null;
  _navUpdateGuideHref(session);
  if (session) {
    navUpdateAuth(session);
  }
}
