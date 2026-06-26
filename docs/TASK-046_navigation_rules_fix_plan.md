# TASK-046 네비게이션/룰 페이지 연결 수정 계획서

작성일: 2026-06-08
작업자: AI_Codex
대상 브랜치: develop

## 1. 원인 분석

### 1.1 상단 네비게이션이 페이지마다 다르게 보이는 원인

- `js/nav.js`가 관리자 페이지에서는 `admin-nav`, 일반/문서 페이지에서는 `top-nav`를 생성하고 있어 같은 메뉴라도 페이지 유형별 CSS 체계가 갈라져 있었다.
- `index.html`은 `js/nav.js`를 사용하지만 `top-nav` 스타일이 들어 있는 `css/common.css`를 로드하지 않고 `css/style.css`만 로드한다. 이 때문에 메인 페이지에서 네비게이션이 스타일 없는 일반 링크처럼 노출될 수 있었다.
- `docs/page-permission-rules.html`은 공용 `nav.js`를 사용하지 않고 인라인 `<nav>`를 직접 갖고 있어 대시보드 네비게이션과 구조, 권한 표시, 링크 계산이 모두 분리되어 있었다.

### 1.2 로그 작성 룰/작업 이력 작성 룰 페이지 연결 문제 원인

- `admin/log-rules.html`, `admin/audit-rules.html`은 `initPage()`를 호출하지만 `initSupabase()`를 먼저 호출하지 않는다.
- `initPage()` 내부의 `loadAuthSession()`은 `_sb`가 초기화되어 있어야 세션을 확인할 수 있으므로, 이미 로그인한 사용자도 세션을 못 읽고 로그인 페이지로 이동할 수 있었다.
- `detectCurrentPageId()`에도 두 룰 페이지와 페이지 권한 룰 문서의 page id가 등록되어 있지 않아, 권한 접근 설정과 실제 페이지가 어긋날 가능성이 있었다.

### 1.3 모바일 테마 드롭다운 화면 이탈 원인

- 테마 드롭다운은 `.theme-picker-wrap` 기준 `position:absolute; right:0`으로만 배치된다.
- 모바일 메뉴가 세로로 열리거나 낮은 해상도에서 테마 버튼이 오른쪽/좁은 영역에 위치하면 드롭다운 폭이 뷰포트 밖으로 밀릴 수 있다.
- 열린 뒤 뷰포트 기준 보정 로직이 없어 화면 밖으로 나간 상태가 그대로 유지된다.

### 1.4 재발 방지 포인트

- `nav.js`는 한 종류의 네비게이션 마크업만 생성한다.
- 문서 페이지도 직접 인라인 네비를 갖지 않고 공용 `nav.js`를 사용한다.
- 인증이 필요한 페이지는 `initSupabase()` 후 `initPage()` 순서를 지킨다.
- 활성 메뉴 판정은 `includes()`가 아니라 현재 경로와 대상 경로의 정확한 비교로 처리한다.
- 드롭다운은 열린 직후 뷰포트 안쪽으로 보정한다.

## 2. 작업 계획

1. `js/nav.js`를 대시보드형 `admin-nav` 마크업으로 통일한다.
2. `css/common.css`와 `css/admin.css`에서 통일된 네비 클래스가 동일하게 동작하도록 보완한다.
3. `index.html`에 공용 네비 CSS를 추가해 메인 페이지도 같은 네비 스타일을 받도록 한다.
4. `docs/page-permission-rules.html`의 인라인 네비를 제거하고 공용 네비/인증/테마/로그 스크립트를 연결한다.
5. `admin/log-rules.html`, `admin/audit-rules.html`에 `initSupabase()` 호출을 추가한다.
6. `js/auth.js`의 현재 페이지 식별 목록에 룰 문서 페이지들을 추가한다.
7. `js/theme.js`에 모바일/저해상도 뷰포트 보정 로직을 추가한다.
8. 정적 링크/문법 검증 후 로컬 서버와 브라우저로 메인, 대시보드, 페이지 권한 룰, 로그 작성 룰, 작업 이력 작성 룰, 모바일 테마 드롭다운을 확인한다.
9. 문제가 없으면 `develop` 브랜치에 커밋하고 원격에 푸시한다.

## 3. 검증 기준

- 메인 페이지, 관리자 대시보드, 페이지 권한 룰 문서의 상단 네비게이션이 같은 대시보드형 구조로 렌더링된다.
- `운영 > 로그 작성 룰`, `운영 > 작업 이력 작성 룰` 링크가 정상 URL로 이동한다.
- 모바일 폭에서 햄버거 메뉴와 테마 드롭다운이 화면 밖으로 넘치지 않는다.
- 콘솔에 네비게이션/초기화 관련 JavaScript 오류가 없어야 한다.

## 4. 검증 결과

- `node --check js/nav.js`, `node --check js/theme.js`, `node --check js/auth.js` 통과.
- `git diff --check` 통과.
- 주요 변경 페이지 내부 정적 참조 검사 통과.
- 공용 네비 렌더링 단위 검사 통과.
  - 메인: `admin-nav` 마크업 생성 및 루트 기준 링크 확인.
  - 관리자: `../admin/log-rules.html`, `../admin/audit-rules.html` 링크 확인.
  - 문서: `../docs/page-permission-rules.html` 활성 메뉴 및 운영 룰 링크 확인.
- 모바일 테마 드롭다운 위치 계산 단위 검사 통과.
- 로컬 정적 서버 HTTP 응답 확인 통과.
  - `index.html`: 200
  - `docs/page-permission-rules.html`: 200
  - `admin/log-rules.html`: 200
  - `admin/audit-rules.html`: 200
  - `admin/index.html`: 200
- Codex in-app Browser는 로컬 HTTP 및 `file://` URL 접근이 정책상 차단되어 실제 화면 스크린샷 검증은 수행하지 못했다. 대신 로컬 HTTP 응답, 정적 참조, 네비 렌더링, 모바일 드롭다운 계산 검증으로 대체했다.
