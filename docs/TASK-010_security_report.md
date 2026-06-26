# TASK-010 완료 보고서: 초기 비밀번호 변경 강제 + 학생 상점 인증 보호

**작성일**: 2026-05-26  
**버전**: v2.3.0  
**작성자**: AI_Cursor

---

## 1. 수정 파일 목록

| 파일 | 수정 내용 |
|------|-----------|
| `js/auth.js` | `initPage()` 함수에 isFirstLogin 강제 리디렉트 로직 추가 |
| `student/shop.html` | `loadAuthSession()` → `initPage()` 전환, autoLogPageView 위치 변경 |
| `login.html` | 기존 세션 isFirstLogin 처리 로직 보완 |
| `js/version.js` | v2.3.0 업데이트 및 변경 이력 추가 |

---

## 2. 변경 내용 요약

### 2-1. initPage() 초기 비밀번호 변경 강제 (js/auth.js)

**변경 전**: `initPage()`는 세션 확인 → 권한 확인 순서만 처리  
**변경 후**: 세션 확인 → **isFirstLogin 강제** → 권한 확인 순서로 처리

```javascript
// 추가된 로직 (권한 체크보다 선행)
if (session.isFirstLogin && !window.location.pathname.includes('change-password')) {
  const basePath = loginPath ? loginPath.replace(/[^/]*$/, '') : '../';
  window.location.href = basePath + 'admin/change-password.html';
  return null;
}
```

**핵심 설계**:
- `session.isFirstLogin === true`이면 역할과 무관하게 비밀번호 변경 페이지로 강제 이동
- 현재 페이지가 `change-password.html`인 경우 리디렉트 루프 방지
- 권한 체크보다 먼저 실행되므로 어떤 URL 직접 접근도 우회 불가

### 2-2. login.html isFirstLogin 처리 보완

**변경 전**: 기존 세션이 있고 `isFirstLogin=true`이면 로그인 폼을 다시 표시  
**변경 후**: 기존 세션이 있고 `isFirstLogin=true`이면 즉시 change-password.html로 리디렉트

### 2-3. student/shop.html 보호 페이지 전환 (권장안 A 적용)

**변경 전**: `loadAuthSession()`으로 선택적 인증, 비로그인도 접근 가능  
**변경 후**: `initPage(['student', 'admin', 'dept_manager'], '../login.html')` 적용

- 비로그인 접근 시 `login.html`로 이동
- isFirstLogin 사용자는 `change-password.html`로 이동
- `autoLogPageView()`는 인증 완료 후 실행 (익명 로그 방지)

---

## 3. 권한별 테스트 결과표

### 3-1. isFirstLogin=true 상태 (비밀번호 미변경)

| 테스트 ID | 계정 | 역할 | 접근 페이지 | 예상 결과 | 결과 |
|-----------|------|------|-------------|-----------|------|
| T-01 | test01 | admin | admin/reports.html | change-password.html 이동 | PASS |
| T-02 | test01 | admin | admin/logs.html | change-password.html 이동 | PASS |
| T-03 | test01 | admin | admin/users.html | change-password.html 이동 | PASS |
| T-04 | test02 | dept_manager | manager/index.html | change-password.html 이동 | PASS |
| T-05 | test02 | dept_manager | manager/products.html | change-password.html 이동 | PASS |
| T-06 | test03 | teacher | teacher/my-talents.html | change-password.html 이동 | PASS |
| T-07 | test03 | teacher | teacher/shop.html | change-password.html 이동 | PASS |
| T-08 | test04 | student | student/my-talents.html | change-password.html 이동 | PASS |
| T-09 | test04 | student | student/shop.html | change-password.html 이동 | PASS |

### 3-2. isFirstLogin=false 상태 (비밀번호 변경 완료)

| 테스트 ID | 계정 | 역할 | 접근 페이지 | 예상 결과 | 결과 |
|-----------|------|------|-------------|-----------|------|
| T-10 | test01 | admin | admin/reports.html | 정상 접근 | PASS |
| T-11 | test02 | dept_manager | admin/reports.html | manager/index.html 이동 | PASS |
| T-12 | test03 | teacher | admin/reports.html | teacher/my-talents.html 이동 | PASS |
| T-13 | test04 | student | admin/reports.html | student/my-talents.html 이동 | PASS |
| T-14 | test04 | student | student/shop.html | 정상 접근 | PASS |

### 3-3. 비로그인 상태

| 테스트 ID | 접근 페이지 | 예상 결과 | 결과 |
|-----------|-------------|-----------|------|
| T-15 | admin/reports.html | login.html 이동 | PASS |
| T-16 | admin/logs.html | login.html 이동 | PASS |
| T-17 | student/shop.html | login.html 이동 | PASS |
| T-18 | manager/index.html | login.html 이동 | PASS |

### 3-4. 기존 세션 상태에서 login.html 접근

| 테스트 ID | 세션 상태 | 예상 결과 | 결과 |
|-----------|-----------|-----------|------|
| T-19 | isFirstLogin=true | change-password.html 이동 | PASS |
| T-20 | isFirstLogin=false, admin | admin/index.html 이동 | PASS |
| T-21 | isFirstLogin=false, student | student/my-talents.html 이동 | PASS |

---

## 4. 최초 비밀번호 변경 강제 검증 결과

| 항목 | 상태 |
|------|------|
| 모든 역할에서 isFirstLogin 시 리디렉트 | 확인 완료 |
| change-password.html 자체 리디렉트 루프 없음 | 확인 완료 |
| login.html에서 isFirstLogin 세션 처리 | 확인 완료 |
| 권한 체크보다 isFirstLogin 우선 실행 | 확인 완료 |
| URL 직접 입력으로 우회 불가 | 확인 완료 |

---

## 5. 정책 확정 사항

### student/shop.html 접근 정책: **보호 페이지 (권장안 A 적용)**

- 비로그인 사용자는 상품 조회 불가, 로그인 페이지로 이동
- 허용 역할: student, admin, dept_manager
- teacher는 별도 `teacher/shop.html` 사용

### 적용 근거
- 보안 일관성 유지
- 사용자 요청에 따른 권장안 A 선택
- 메인 페이지에서 "상품 구매" 버튼 클릭 시 로그인 필요

---

## 6. 추가 발견 이슈

- 없음. 전체 `initPage()` 호출 18개 모두 동일한 패턴(`loginPath = '../login.html'`) 사용으로 경로 계산 일관성 확인 완료.

---

## 7. 리디렉트 흐름도

```
[사용자 페이지 접근]
    │
    ▼
initPage() 실행
    │
    ├─ 세션 없음? ──────────────── → login.html
    │
    ├─ isFirstLogin=true? ──────── → admin/change-password.html
    │   (change-password 제외)
    │
    ├─ 역할 미허용? ────────────── → 역할별 기본 페이지
    │   (admin→admin/index.html)
    │   (dept_mgr→manager/index.html)
    │   (teacher→teacher/my-talents.html)
    │   (student→student/my-talents.html)
    │
    └─ 통과 ────────────────────── → auth-ready → 페이지 정상 표시
```
