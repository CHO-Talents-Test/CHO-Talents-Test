/**
 * 버전 관리 모듈 - CHO-Talents
 */
const APP_VERSION = {
  current: '3.66.2',
  date: '2026-07-08',
  history: [
    {
      version: '3.66.2',
      date: '2026-07-08',
      title: '예외 지급/반환 관리 정렬 및 배지 기준 정리',
      changes: [
        '예외 지급 요청 네비게이션 배지는 실제 승인/거부 처리가 가능한 전도사님(90+) 이상에게만 표시',
        '예외 지급/반환 관리 요약 카드와 그리드의 순서를 예외 지급 요청, 예외 지급 내역, 달란트 반환 내역, 전체 처리 순으로 통일',
        '요약 카드 색상을 각 그리드 색상과 맞추고 전체 처리 통합 그리드를 추가'
      ]
    },
    {
      version: '3.66.1',
      date: '2026-07-07',
      title: '버전 캐시 참조 중앙화',
      changes: [
        '각 HTML 파일의 고정 버전 쿼리 문자열을 제거해 버전 변경 시 페이지별 수정이 필요 없도록 정리',
        '공통 version.js에서 최신 버전을 확인하고 로드된 CSS/JS 파일을 강제로 재검증하도록 보강',
        '구버전 자산 감지 시 한 번 새로고침한 뒤 최신 자산으로 재로그인 안내가 이어지도록 개선'
      ]
    },
    {
      version: '3.66.0',
      date: '2026-07-07',
      title: '로그 상세 한글화 및 기존 로그 백필',
      changes: [
        '신규 활동 로그 저장 시 원본 키와 함께 한글 상세 키 별칭을 저장하도록 보강',
        '로그 관리와 작업 이력 상세 모달에서 한글화된 로그 상세 데이터를 우선 표시',
        '기존 activity_logs 상세 데이터에 한글 별칭을 추가하는 SQL 문서 추가',
        '인증/버전/아이디 확인 관련 실제 발생 로그 액션의 한글 라벨 보강'
      ]
    },
    {
      version: '3.65.0',
      date: '2026-07-06',
      title: '가입 승인 안내 및 최신 버전 세션 갱신',
      changes: [
        '승인 대기 중인 가입 신청 계정은 로그인 인증 전에 승인 대기 안내와 담당 관리자 정보를 표시',
        '모든 페이지에서 세션의 앱 버전이 최신 버전이 아니면 현재 세션을 종료하고 로그인 페이지로 이동',
        '내 달란트, 부서 소속보기, 사용자 상세 내역에 페이지 처리를 추가하고 관련 그리드 표시를 정리',
        '상품 카테고리 신규 추가 후 코드 대신 명칭이 표시되도록 코드 마스터 로드를 보강',
        '로그 화면의 사용자 계정/이름 및 한글 액션 표시를 보강'
      ]
    },
    {
      version: '3.64.0',
      date: '2026-07-04',
      title: '버전 표시 인코딩 복구 + 예외 지급/반환 관리 요약 카드',
      changes: [
        '모든 페이지 하단 버전 표시의 깨진 한글 문구를 정상 한글로 복구',
        '버전 이력 페이지에서 누락된 버전 API를 복원하여 이력 목록이 다시 표시되도록 수정',
        '예외 지급/반환 관리의 처리 현황을 대시보드형 네모 카드로 이동',
        '예외 지급 내역 출처의 깨진 예외 배지를 정상 표시하도록 수정',
        'GitHub Pages 배포 워크플로를 명시적으로 추가'
      ]
    },
    {
      version: '3.63.0',
      date: '2026-07-03',
      title: '예외 지급 요청 일괄 승인 및 그리드별 페이지 크기',
      changes: [
        '예외 지급 요청 그리드에 전도사님 이상만 보이는 체크박스와 선택/전체 일괄 승인 버튼을 추가',
        '예외 지급, 예외 지급 내역, 달란트 반환 내역의 페이지당 항목 수를 그리드별로 분리하고 개별 저장하도록 변경',
        '요청 건수와 처리 건수 배지를 요청 그리드 상단으로 이동하고 요약 카드를 대체'
      ]
    },
    {
      version: '3.62.0',
      date: '2026-07-03',
      title: '사용자 등록 중복 확인, 예외 지급 요청 프로세스',
      changes: [
        '사용자 관리의 사용자 등록 모달에 아이디 중복확인 버튼을 추가하고 확인된 아이디만 등록 가능하도록 제한',
        '부서 담당 교사(60+) 이상이 전도사 승인 예외 지급을 요청할 수 있도록 지급 모달 권한 분리',
        '전도사님(90+) 이상은 예외 지급을 즉시 처리하고, 60~89 권한자는 talent_exception_requests 요청으로 누적',
        '예외 지급 반환 관리 섹션 상단에 예외 지급 요청 목록을 추가하고 90+ 승인/거부 처리 연결',
        '부서 교사 미만 요청 조회를 대상/소속 부서 기준으로 제한하고, 예외 지급 요청 테이블 RLS SQL 문서 추가'
      ]
    },
    {
      version: '3.61.0',
      date: '2026-07-03',
      title: '공지 사항 권한 조정, 이미지 업로드 공통화',
      changes: [
        '공지 사항 메뉴를 소개 > 공지 사항으로 이동하고 일반 교사(40+) 조회, 전도사님(90+) 관리 권한으로 분리',
        '공지 목록 상세 보기와 보기 전용/관리 전용 UI 분기를 추가',
        '상품/공지 이미지 업로드를 공통 함수로 통합하고 서버-S3 규칙을 적용',
        '모든 페이지 하단 버전 표시를 version-container + version.js 공통 렌더링 구조로 통합',
        '사용자 관리의 사용자 등록 모달에서 관리자 뿐만 아니라 권한자도 아이디를 입력할 수 있도록 보완'
      ]
    }
  ]
};

window.APP_VERSION = APP_VERSION;

function getVersion() { return APP_VERSION.current; }
function getVersionHistory() { return APP_VERSION.history; }

function _versionBasePath() {
  const path = window.location.pathname;
  if (path.includes('/admin/') || path.endsWith('/admin') ||
      path.includes('/docs/') || path.endsWith('/docs')) return '../';
  return '';
}

function _versionEnsureStyles() {
  if (document.getElementById('versionFooterStyle')) return;
  const style = document.createElement('style');
  style.id = 'versionFooterStyle';
  style.textContent = `
    .version-footer {
      margin: 2.5rem auto 1.2rem;
      padding: 0.75rem 1rem;
      max-width: 1180px;
      color: var(--admin-text-muted, var(--t-text-muted, #868e96));
      font-size: 0.78rem;
      text-align: center;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.45rem 0.6rem;
      flex-wrap: wrap;
    }
    .version-footer a {
      color: var(--admin-primary, #6c5ce7);
      text-decoration: none;
      font-weight: 700;
    }
    .version-footer a:hover { text-decoration: underline; }
    .version-footer-brand { font-weight: 800; color: var(--t-text, #495057); }
    .version-badge {
      display: inline-flex;
      align-items: center;
      border-radius: 999px;
      padding: 0.15rem 0.5rem;
      color: var(--admin-primary, #6c5ce7);
      background: rgba(108,92,231,0.1);
      font-weight: 800;
      line-height: 1.3;
    }
    [data-theme="dark"] .version-badge {
      background: rgba(132, 94, 247, 0.18);
      color: #b197fc;
    }
  `;
  document.head.appendChild(style);
}

function renderVersionFooter(containerId = 'version-container') {
  if (!document.body) return;
  _versionEnsureStyles();
  let container = document.getElementById(containerId);
  if (!container) {
    container = document.createElement('div');
    container.id = containerId;
    document.body.appendChild(container);
  }
  const historyHref = _versionBasePath() + 'admin/versions.html';
  container.innerHTML = `
    <footer class="version-footer" aria-label="버전 정보">
      <span class="version-footer-brand">CHO Talents</span>
      <span class="version-badge" title="최종 업데이트: ${APP_VERSION.date}">v${APP_VERSION.current}</span>
      <span>최종 업데이트 ${APP_VERSION.date}</span>
      <span aria-hidden="true">·</span>
      <a href="${historyHref}">버전 이력</a>
    </footer>
  `;
}

function renderVersionBadge() {
  renderVersionFooter();
  document.querySelectorAll('.version-badge').forEach(el => {
    el.textContent = `v${APP_VERSION.current}`;
    el.title = `최종 업데이트: ${APP_VERSION.date}`;
  });
}

const VERSION_SESSION_KEY = 'cho_session_app_version';
const VERSION_ASSET_REFRESH_KEY = 'cho_last_asset_refresh_version';

function markCurrentAppVersion() {
  try {
    localStorage.setItem(VERSION_SESSION_KEY, APP_VERSION.current);
    if (typeof getSession === 'function' && typeof setSession === 'function') {
      const session = getSession();
      if (session) {
        session.appVersion = APP_VERSION.current;
        setSession(session);
      }
    }
  } catch (e) {}
}

function _versionLoginPath() {
  return _versionBasePath() + 'login.html';
}

function _versionRedirectTarget(loginPath) {
  const isAuthPage = /\/?(login|register)\.html$/i.test(window.location.pathname);
  if (isAuthPage) return loginPath;
  if (typeof buildLoginRedirectUrl === 'function') return buildLoginRedirectUrl(loginPath, window.location.href);
  return loginPath + '?redirect=' + encodeURIComponent(window.location.href);
}

async function _fetchLatestVersion() {
  try {
    const url = _versionBasePath() + 'js/version.js?_=' + Date.now();
    const res = await fetch(url, { cache: 'no-store' });
    if (!res.ok) return APP_VERSION.current;
    const text = await res.text();
    const match = text.match(/current:\s*['"]([^'"]+)['"]/);
    return match ? match[1] : APP_VERSION.current;
  } catch (e) {
    return APP_VERSION.current;
  }
}

function _versionNormalizeAssetUrl(rawUrl) {
  try {
    const url = new URL(rawUrl, window.location.href);
    if (url.origin !== window.location.origin) return null;
    if (!/\.(css|js)$/i.test(url.pathname)) return null;
    url.searchParams.delete('v');
    url.searchParams.delete('_');
    return url.href;
  } catch (e) {
    return null;
  }
}

function _versionLoadedAssetUrls() {
  const nodes = Array.from(document.querySelectorAll('script[src], link[rel="stylesheet"][href]'));
  const urls = nodes
    .map(node => _versionNormalizeAssetUrl(node.getAttribute('src') || node.getAttribute('href')))
    .filter(Boolean);
  return Array.from(new Set(urls));
}

async function refreshAppAssetsForVersion(latestVersion) {
  if (typeof fetch !== 'function') return false;
  const urls = _versionLoadedAssetUrls();
  if (urls.length === 0) return false;
  await Promise.all(urls.map(url => fetch(url, { cache: 'reload' }).catch(() => null)));
  try {
    localStorage.setItem(VERSION_ASSET_REFRESH_KEY, latestVersion || APP_VERSION.current);
  } catch (e) {}
  return true;
}

async function _refreshAssetsOnceForVersion(latestVersion) {
  try {
    if (!latestVersion || localStorage.getItem(VERSION_ASSET_REFRESH_KEY) === latestVersion) return false;
  } catch (e) {}
  return refreshAppAssetsForVersion(latestVersion);
}

async function _forceLogoutForVersion(latestVersion, sessionVersion) {
  const loginPath = _versionLoginPath();
  const target = _versionRedirectTarget(loginPath);
  await refreshAppAssetsForVersion(latestVersion);
  try {
    if (typeof logWarn === 'function') {
      await logWarn('APP_VERSION_STALE_SESSION', {
        현재페이지버전: APP_VERSION.current,
        최신버전: latestVersion,
        세션버전: sessionVersion || null,
        요청페이지: window.location.pathname,
        이동대상: target
      });
    }
  } catch (e) {}

  try {
    if (typeof _sb !== 'undefined' && _sb && _sb.auth) await _sb.auth.signOut();
  } catch (e) {}
  try {
    if (typeof clearSession === 'function') clearSession();
    else {
      sessionStorage.removeItem('cho_session');
      sessionStorage.removeItem('cho_admin_session');
    }
    localStorage.removeItem(VERSION_SESSION_KEY);
    localStorage.removeItem('cho_last_activity');
  } catch (e) {}

  alert('새 버전이 배포되어 다시 로그인해주세요.');
  window.location.href = target;
}

async function enforceLatestAppVersion() {
  const latestVersion = await _fetchLatestVersion();
  if (APP_VERSION.current !== latestVersion) {
    const refreshed = await _refreshAssetsOnceForVersion(latestVersion);
    if (refreshed) {
      window.location.reload();
      return;
    }
  }

  if (typeof getSession !== 'function') return;
  const session = getSession();
  if (!session) return;
  const sessionVersion = session.appVersion || localStorage.getItem(VERSION_SESSION_KEY) || '';
  if (APP_VERSION.current !== latestVersion || sessionVersion !== latestVersion) {
    await _forceLogoutForVersion(latestVersion, sessionVersion);
    return;
  }
  if (session.appVersion !== latestVersion && typeof setSession === 'function') {
    session.appVersion = latestVersion;
    setSession(session);
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    renderVersionFooter();
    enforceLatestAppVersion();
  });
} else {
  renderVersionFooter();
  enforceLatestAppVersion();
}

window.refreshAppAssetsForVersion = refreshAppAssetsForVersion;


