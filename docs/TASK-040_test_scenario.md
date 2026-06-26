# 테스트 시나리오 - v3.33.0

## 작업 1: 테마 시스템

### TC-01: 테마 선택 UI 표시
- **입력:** 모든 페이지 접속
- **기대결과:** 네비게이션 바 우측에 테마 아이콘(🎨) 버튼 표시
- **확인방법:** 버튼 클릭 시 6가지 테마 옵션 드롭다운 표시
- **결과:** ✅ (정적 검증 완료 - nav.js에서 renderThemePicker 호출, themes.css에 UI 스타일 정의)

### TC-02: 테마 변경 즉시 적용
- **입력:** 테마 드롭다운에서 '다크 모드' 선택
- **기대결과:** 페이지 배경/텍스트/카드 색상이 즉시 다크 테마로 변경
- **확인방법:** HTML 요소에 `data-theme="dark"` 속성 변경 확인
- **결과:** ✅ (정적 검증 - applyTheme()이 documentElement에 data-theme 설정, localStorage 저장)

### TC-03: 테마 설정 DB 저장 (로그인 상태)
- **입력:** 로그인 후 테마 변경
- **기대결과:** user_preferences 테이블에 theme 컬럼 업데이트
- **확인방법:** Supabase에서 해당 사용자의 theme 값 확인
- **결과:** ✅ (정적 검증 - saveThemeToDB()가 upsert 호출)

### TC-04: 다른 환경에서 테마 복원
- **입력:** 다른 브라우저에서 동일 계정 로그인
- **기대결과:** DB에 저장된 테마가 자동 적용
- **확인방법:** initTheme()이 loadThemeFromDB() 호출 후 적용
- **결과:** ✅ (정적 검증 - initTheme에서 dbTheme 우선 적용 로직)

### TC-05: 비로그인 시 localStorage 유지
- **입력:** 비로그인 상태에서 테마 변경
- **기대결과:** localStorage에 저장, 새로고침 시 유지
- **확인방법:** loadThemeFromLocal() 확인
- **결과:** ✅ (정적 검증 완료)

### TC-06: 계절 테마 배경 효과
- **입력:** 봄/여름/가을/겨울 테마 각각 선택
- **기대결과:** 해당 계절 CSS 장식 효과 (body::before) 표시
- **확인방법:** themes.css의 [data-theme="spring"] body::before 등
- **결과:** ✅ (정적 검증 - CSS 파일에 계절별 radial-gradient 패턴 정의)

## 작업 2: 메인 페이지 재설계

### TC-07: 마을 레이아웃 표시
- **입력:** index.html 접속
- **기대결과:** 양쪽에 "달란트 적립"/"상품 구매" 고정 바로가기, 중앙에 즐겨찾기
- **확인방법:** .village-layout, .village-side-btn 요소 확인
- **결과:** ✅ (정적 검증 - index.html에 구조 구현, style.css에 스타일 정의)

### TC-08: 즐겨찾기 제한 (모바일 9, PC 10)
- **입력:** 즐겨찾기 설정에서 제한 초과 선택
- **기대결과:** 최대 개수 초과 시 경고 메시지
- **확인방법:** saveFavorites()에서 maxFav 체크
- **결과:** ✅ (정적 검증 - MAX_FAV_MOBILE=9, MAX_FAV_PC=10, _getMaxFav() 분기)

## 작업 3: 네비게이션 중앙 관리

### TC-09: nav.js 단일 소스
- **입력:** 모든 HTML 파일 검사
- **기대결과:** 인라인 nav HTML 없음, nav-container + nav.js 사용
- **확인방법:** grep으로 확인
- **결과:** ✅ (검증 완료 - `<nav class="top-nav"` / `admin-nav` 0건, nav-container 29건)

### TC-10: 권한별 메뉴 표시
- **입력:** 다양한 권한 레벨로 로그인
- **기대결과:** data-min-perm에 따라 메뉴 항목 표시/숨김
- **확인방법:** navUpdateAuth() → applyPermNav() 호출 체인
- **결과:** ✅ (정적 검증 - nav.js에서 data-min-perm 속성 출력, auth.js의 applyPermNav 동작)

### TC-11: 드롭다운 뷰포트 벗어남 방지
- **입력:** 우측 끝 메뉴 드롭다운 열기
- **기대결과:** 드롭다운이 화면 밖으로 벗어나지 않음
- **확인방법:** _navPositionDropdown() 함수 로직
- **결과:** ✅ (정적 검증 - rect.right > viewportWidth 시 right:0 적용)

### TC-12: 모바일 햄버거 메뉴
- **입력:** 768px 이하 화면에서 햄버거 버튼 클릭
- **기대결과:** 네비게이션 링크 목록 토글
- **확인방법:** nav-open 클래스 토글
- **결과:** ✅ (정적 검증 - navHamburger click → navLinks.classList.toggle)

## 작업 4: 로그/작업이력 룰 페이지

### TC-13: 로그 작성 룰 페이지 접근
- **입력:** 운영 > 로그 작성 룰 메뉴 클릭
- **기대결과:** admin/log-rules.html 페이지 표시 (rank 80 이상)
- **확인방법:** initPage(80) 호출
- **결과:** ✅ (정적 검증 - nav.js에 minPerm:80으로 등록, 페이지에 initPage(80) 호출)

### TC-14: 작업 이력 룰 페이지 접근
- **입력:** 운영 > 작업 이력 작성 룰 메뉴 클릭
- **기대결과:** admin/audit-rules.html 페이지 표시 (rank 80 이상)
- **확인방법:** initPage(80) 호출
- **결과:** ✅ (정적 검증 완료)

### TC-15: 네비게이션 연결 확인
- **입력:** nav.js NAV_MENU 데이터 확인
- **기대결과:** operation 그룹에 log-rules.html, audit-rules.html 포함
- **확인방법:** NAV_MENU 검색
- **결과:** ✅ (정적 검증 - admin/log-rules.html, admin/audit-rules.html 확인됨)

## 전체 결과: 15/15 항목 통과 (정적 검증 기반)
