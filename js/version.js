/**
 * 버전 관리 모듈 - CHO-Talents
 */
const APP_VERSION = {
  current: '3.63.0',
  date: '2026-07-03',
  history: [
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
    <footer class="version-footer" aria-label="踰꾩쟾 ?뺣낫">
      <span class="version-footer-brand">CHO Talents</span>
      <span class="version-badge" title="理쒖쥌 ?낅뜲?댄듃: ${APP_VERSION.date}">v${APP_VERSION.current}</span>
      <span>理쒖쥌 ?낅뜲?댄듃 ${APP_VERSION.date}</span>
      <span aria-hidden="true">쨌</span>
      <a href="${historyHref}">踰꾩쟾 ?대젰</a>
    </footer>
  `;
}

function renderVersionBadge() {
  renderVersionFooter();
  document.querySelectorAll('.version-badge').forEach(el => {
    el.textContent = `v${APP_VERSION.current}`;
    el.title = `理쒖쥌 ?낅뜲?댄듃: ${APP_VERSION.date}`;
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', renderVersionFooter);
} else {
  renderVersionFooter();
}



