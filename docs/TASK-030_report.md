# TASK-030: v3.12.2 작업 완료 보고서

## 작업 개요
- **버전**: v3.12.1 → v3.12.2
- **작업 유형**: UI/기능 개선
- **작업일**: 2026-05-29

## 수정 내역

### 1. 네비게이션 통일
- **index.html**: 로그인 시 '내 구매 상품' 메뉴 추가, 사용자 프로필 링크를 index.html로 통일
- **보고서 리디렉트 수정**: `auth.js`의 `initPage()` 내 `role_page_access` 체크 로직 수정. `initPage(minRank)` 기본 등급 검사를 통과한 사용자는 DB의 `can_access=false` 설정에 의해 차단되지 않도록 변경. 부장 교사(80)/전도사님(90)이 보고서 페이지에 정상 접근 가능
- **모든 페이지 nav에 '내 구매 상품' 메뉴 추가**: admin 15개 + 공개 4개 + 신규 1개 = 총 20개 페이지

### 2. 달란트 관리
- **교사 반 스코핑 강화**: 일반 교사(rank 40)는 반드시 부서 + 반이 모두 배정되어 있어야 사용자 조회/달란트 지급 가능. 반 미배정 시 빈 목록 표시
- **`canGiveTalent()` 강화**: `classNumber`가 null이면 무조건 false 반환
- **`loadUsers()` 강화**: rank 40 + classNumber 없으면 `data = []`
- **달란트 항목 관리 버튼**: `data-min-perm="60"` 추가하여 부서 담당 교사(60) 이상만 표시

### 3. 로그인 후 메인 페이지 이동
- `PERMISSION_REDIRECT`: 모든 권한을 `index.html`로 통일
- `ROLE_REDIRECT`: 모든 역할을 `index.html`로 통일
- `login.html`: 로그인 성공 시 `index.html`로 이동 (최초 로그인은 기존대로 `change-password.html`)
- 이미 로그인 상태로 `login.html` 접근 시에도 `index.html`로 이동

### 4. 내 구매 상품 페이지 (my-orders.html)
- **신규 페이지 생성**: `my-orders.html`
- **접근 권한**: `initPage(20)` - 로그인 사용자 전용
- **기능**: 본인 구매 내역 조회 (날짜, 상품명, 가격, 4단계 상태 배지)
- **관리자 정보 미표시**: 처리자, 상태 변경 버튼 등 관리용 정보 제외
- **nav 통합**: 공개 페이지(top-nav)와 admin 페이지(admin-nav) 모두에 추가

### 5. 대리 구매 기능 (shop.html)
- **대리 구매 버튼**: rank 40 이상에게 '🤝 대리 구매' 버튼 표시
- **대상 사용자 검색 모달**: 이름/아이디 검색, 스코핑 규칙 적용
  - 일반 교사(40): 같은 부서 + 같은 반 학생만
  - 부서 담당 교사(60)/부장 교사(80): 담당 부서 교사 + 학생
  - 전도사님(90+): 모든 부서 교사 + 학생
- **구매 흐름**: 대상 선택 → 상품 선택 → 잔액 확인 → 구매 신청
- **로깅**: PROXY_ORDER_SUCCESS/FAIL/DENIED/ERROR 로그 기록

### 6. 사용자 관리 개선
- **반(class_number) 수정 활성화**: 부서 담당 교사(60) 이상이 수정 모달에서 반 변경 가능. 부서(mDept)는 기존대로 잠금
- **부서 필터 드롭다운**: 부장 교사(80) 이상에게 부서 필터 콤보 박스 추가 (전체 부서 / 각 부서). 선택 시 해당 부서 사용자만 표시

### 7. 관리자 관리 개선
- **학생 검색 제외**: 관리자 등록 시 사용자 검색에서 `user_type === 'student'` 제외
- **부서 필터 드롭다운**: 부장 교사(80) 이상에게 부서 필터 콤보 박스 추가. 소속 부서 또는 담당 부서 기준 필터링

## 수정 파일 목록

| 파일 | 수정 유형 |
|------|----------|
| `js/auth.js` | PERMISSION_REDIRECT/ROLE_REDIRECT 통일, initPage role_page_access 로직 수정 |
| `login.html` | 로그인 후 index.html 리디렉트 |
| `index.html` | nav에 '내 구매 상품' 추가, 프로필 링크 통일 |
| `my-orders.html` | 신규 생성 |
| `shop.html` | 대리 구매 기능 추가, nav에 '내 구매 상품' 추가 |
| `my-talents.html` | nav에 '내 구매 상품' 추가, navMyOrders 표시 |
| `earn-talents.html` | nav에 '내 구매 상품' 추가, navMyOrders 표시 |
| `admin/talents.html` | 교사 반 스코핑 강화, 항목관리 버튼 data-min-perm="60" |
| `admin/users.html` | 반 수정 활성화, 부서 필터 추가 |
| `admin/managers.html` | 학생 검색 제외, 부서 필터 추가 |
| `admin/*.html` (15개) | nav에 '내 구매 상품' 메뉴 추가 |
