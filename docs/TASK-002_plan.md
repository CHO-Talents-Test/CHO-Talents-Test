# TASK-002 작업 계획서

**작업명:** 역할 기반 계정 체계 및 달란트 시스템 페이지 구축  
**작성일:** 2026-05-26 (KST)  
**작성자:** AI  
**상태:** 검토 대기

---

## 1. 작업 개요

기존 관리자 전용 시스템을 확장하여 4가지 역할(관리자, 부서 관리자, 교사, 학생)의 계정 체계를 구축하고, 각 역할별 달란트(적립/사용/잔여) 조회 및 물품 상점 페이지를 구현한다. 미 로그인 사용자(손님)도 학생 상점을 열람할 수 있도록 한다.

---

## 2. 역할 정의

| 역할 | 코드 | 설명 |
|------|------|------|
| 관리자 | `admin` | 전체 시스템 관리, 부서 관리자의 모든 기능 + 부서/계정/보고서/로그 관리 |
| 부서 관리자 | `dept_manager` | 담당 부서의 학생·교사 계정 관리, 달란트 관리, 물품 관리 |
| 교사 | `teacher` | 본인 달란트 내역 조회, 교사 전용 상점 이용 |
| 학생 | `student` | 본인 달란트 내역 조회(로그인 필수), 학생 전용 상점 이용 |
| 손님(미 로그인) | - | 학생 상점 열람만 가능 |

---

## 3. 데이터베이스 스키마 변경

### 3-1. departments (신규 테이블)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid PK | 부서 ID |
| name | text UNIQUE | 부서명 |
| description | text | 부서 설명 |
| is_active | boolean | 활성 여부 (기본: true) |
| created_at | timestamptz | 생성일시 |

### 3-2. admin_users 테이블 확장

기존 `admin_users` 테이블에 컬럼 추가:

| 추가 컬럼 | 타입 | 설명 |
|-----------|------|------|
| department_id | uuid FK → departments | 소속 부서 |
| managed_dept_id | uuid FK → departments | 관리 담당 부서 (부서 관리자용) |
| talent_balance | integer DEFAULT 0 | 달란트 잔액 |

`role` 컬럼 값 확장: `'admin'`, `'dept_manager'`, `'teacher'`, `'student'`

### 3-3. talent_transactions (신규 테이블)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid PK | 거래 ID |
| user_id | uuid FK → admin_users | 대상 사용자 |
| type | text ('earn' / 'use') | 적립 / 사용 |
| amount | integer | 금액 |
| balance_after | integer | 거래 후 잔액 |
| description | text | 내역 설명 |
| created_by | uuid FK → admin_users | 처리자 |
| created_at | timestamptz | 거래일시 |

### 3-4. products (신규 테이블)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid PK | 상품 ID |
| name | text | 상품명 |
| description | text | 상품 설명 |
| price | integer | 달란트 가격 |
| image_emoji | text | 상품 이모지 (이미지 대체) |
| target_role | text ('teacher' / 'student') | 대상 역할 |
| category | text | 카테고리 |
| stock | integer DEFAULT 0 | 재고 |
| is_active | boolean DEFAULT true | 판매 활성 여부 |
| created_by | uuid | 등록자 |
| created_at | timestamptz | 등록일시 |

### 3-5. RPC 함수 변경

- `verify_admin` → `verify_user`로 확장: 모든 역할 로그인 지원, department 정보 포함 반환
- `update_password`: 기존 유지
- `give_talent`: 달란트 적립 (트랜잭션 + 잔액 업데이트)
- `use_talent`: 달란트 사용 (트랜잭션 + 잔액 차감)

### 3-6. RLS 정책

- `departments`: anon 읽기 허용
- `talent_transactions`: anon 읽기/쓰기 허용
- `products`: anon 읽기 허용, 쓰기는 허용 (클라이언트 인증으로 관리)

---

## 4. 페이지 구조

### 4-0. 공통 수정

| 파일 | 변경 내용 |
|------|----------|
| `index.html` | 역할별 메뉴 링크 추가 (로그인, 상점, 내 달란트) |
| `login.html` | 통합 로그인 페이지 (모든 역할, 루트 레벨) |
| `js/auth.js` | 역할 기반 로그인/리다이렉트 확장 |
| `js/activity-log.js` | 세션에 부서/역할 정보 확장 |
| `css/common.css` | 공통 페이지 스타일 (역할별 페이지 공유) |

### 4-1. 학생/손님 페이지

| 페이지 | 파일 경로 | 설명 |
|--------|----------|------|
| 학생 상점 | `student/shop.html` | 달란트 물품 조회 (로그인 없이 열람 가능, 초등 3-4학년 대상 물품 5개) |
| 내 달란트 | `student/my-talents.html` | 달란트 내역 조회 - 적립/사용/잔여 (로그인 필수) |

**테스트 상품 (학생용 5개):**
| # | 상품명 | 가격 | 이모지 |
|---|--------|------|--------|
| 1 | 캐릭터 연필세트 | 5 달란트 | ✏️ |
| 2 | 귀여운 지우개 컬렉션 | 3 달란트 | 🧹 |
| 3 | 미니 인형 키링 | 10 달란트 | 🧸 |
| 4 | 반짝이 스티커북 | 7 달란트 | ⭐ |
| 5 | 간식 쿠폰 (과자+음료) | 15 달란트 | 🍪 |

### 4-2. 교사 페이지

| 페이지 | 파일 경로 | 설명 |
|--------|----------|------|
| 교사 상점 | `teacher/shop.html` | 달란트 물품 조회 (교사 전용, 20대·30대 물품 각 3개) |
| 내 달란트 | `teacher/my-talents.html` | 달란트 내역 조회 - 적립/사용/잔여 |

**테스트 상품 (교사용 6개):**
| # | 카테고리 | 상품명 | 가격 | 이모지 |
|---|---------|--------|------|--------|
| 1 | 20대 추천 | 스타벅스 아메리카노 쿠폰 | 10 달란트 | ☕ |
| 2 | 20대 추천 | 무선 이어폰 파우치 | 20 달란트 | 🎧 |
| 3 | 20대 추천 | 감성 다이어리 | 15 달란트 | 📔 |
| 4 | 30대 추천 | 프리미엄 핸드크림 세트 | 12 달란트 | 🧴 |
| 5 | 30대 추천 | 미니 가습기 | 25 달란트 | 💧 |
| 6 | 30대 추천 | 편의점 상품권 5천원 | 18 달란트 | 🏪 |

### 4-3. 부서 관리자 페이지

| 페이지 | 파일 경로 | 설명 |
|--------|----------|------|
| 관리 대시보드 | `manager/index.html` | 담당 부서 현황 요약 (학생수, 교사수, 달란트 통계) |
| 내 달란트 | `manager/my-talents.html` | 본인 달란트 내역 조회 |
| 학생 관리 | `manager/students.html` | 담당 부서 학생 계정 CRUD + 달란트 적립/차감/내역 조회 |
| 교사 관리 | `manager/teachers.html` | 담당 부서 교사 계정 CRUD + 달란트 적립/차감/내역 조회 |
| 물품 관리 | `manager/products.html` | 달란트 물품 등록/수정/삭제 |

### 4-4. 관리자 페이지 (확장)

| 페이지 | 파일 경로 | 설명 |
|--------|----------|------|
| 대시보드 | `admin/index.html` | 기존 대시보드에 전체 통계 추가 (수정) |
| 부서 관리 | `admin/departments.html` | 부서 등록/수정/삭제, 학생·교사 부서 편성 |
| 부서관리자 관리 | `admin/managers.html` | 부서 관리자 계정 관리, 담당 부서 배정 |
| 보고서 | `admin/reports.html` | 기존 유지 |
| 로그 | `admin/logs.html` | 기존 유지 |

---

## 5. 신규/수정 파일 목록

### 신규 파일 (16개)

| # | 파일 | 설명 |
|---|------|------|
| 1 | `docs/TASK-002_schema.sql` | DB 스키마 변경 SQL (Management API로 실행) |
| 2 | `login.html` | 통합 로그인 페이지 |
| 3 | `css/common.css` | 역할별 페이지 공통 스타일 |
| 4 | `js/talent.js` | 달란트 조회/적립/사용 공통 모듈 |
| 5 | `js/product.js` | 상품 조회/관리 공통 모듈 |
| 6 | `js/user-mgmt.js` | 사용자 관리 공통 모듈 |
| 7 | `student/shop.html` | 학생 달란트 상점 |
| 8 | `student/my-talents.html` | 학생 달란트 내역 조회 |
| 9 | `teacher/shop.html` | 교사 달란트 상점 |
| 10 | `teacher/my-talents.html` | 교사 달란트 내역 조회 |
| 11 | `manager/index.html` | 부서 관리자 대시보드 |
| 12 | `manager/my-talents.html` | 부서 관리자 달란트 내역 |
| 13 | `manager/students.html` | 학생 계정/달란트 관리 |
| 14 | `manager/teachers.html` | 교사 계정/달란트 관리 |
| 15 | `manager/products.html` | 물품 관리 |
| 16 | `admin/departments.html` | 부서 관리 |
| 17 | `admin/managers.html` | 부서 관리자 계정 관리 |

### 수정 파일 (6개)

| # | 파일 | 변경 내용 |
|---|------|----------|
| 1 | `index.html` | 역할별 네비게이션 메뉴 추가 |
| 2 | `js/auth.js` | 역할 기반 로그인/리다이렉트 확장, verify_user RPC 연동 |
| 3 | `js/activity-log.js` | 세션 정보에 부서/역할 필드 확장 |
| 4 | `js/supabase-config.js` | 필요 시 유틸리티 함수 추가 |
| 5 | `admin/index.html` | 대시보드에 전체 사용자/부서 통계 추가, 관리 메뉴 확장 |
| 6 | `css/admin.css` | 관리자/부서관리자 공통 스타일 추가 |

---

## 6. 인증 및 접근 제어 흐름

```
[메인 페이지 (index.html)]
  ├─ 로그인 → login.html
  │    ├─ 학생 로그인 → student/my-talents.html
  │    ├─ 교사 로그인 → teacher/my-talents.html
  │    ├─ 부서관리자 로그인 → manager/index.html
  │    └─ 관리자 로그인 → admin/index.html
  ├─ 학생 상점 (비로그인 가능) → student/shop.html
  └─ 교사 상점 (로그인 필요) → teacher/shop.html

[접근 권한 매트릭스]
  student/shop.html     : 전체 공개
  student/my-talents    : student, dept_manager, admin
  teacher/shop.html     : teacher, dept_manager, admin
  teacher/my-talents    : teacher, dept_manager, admin
  manager/*             : dept_manager, admin
  admin/*               : admin
```

---

## 7. 작업 순서

| 단계 | 작업 | 산출물 |
|------|------|--------|
| A | DB 스키마 변경 (Management API) | departments, talent_transactions, products 테이블 생성, admin_users 확장, RPC 함수 |
| B | 공통 모듈 개발 | auth.js 확장, talent.js, product.js, user-mgmt.js, common.css |
| C | 통합 로그인 페이지 | login.html |
| D | 학생/손님 페이지 | student/shop.html, student/my-talents.html |
| E | 교사 페이지 | teacher/shop.html, teacher/my-talents.html |
| F | 부서 관리자 페이지 | manager/*.html (5개) |
| G | 관리자 페이지 확장 | admin/departments.html, admin/managers.html, admin/index.html 수정 |
| H | 메인 페이지 수정 | index.html 네비게이션 추가 |
| I | 테스트 데이터 삽입 | 샘플 상품 데이터 (Management API) |

---

## 8. 특이사항 / 제약조건

1. **계정 추가는 하지 않음** - 구조만 준비, 실제 계정 등록은 추후
2. **테스트 상품 데이터** - 하드코딩이 아닌 DB 기반, Management API로 삽입
3. **기존 admin 시스템 호환** - 기존 admin 로그인/대시보드/보고서/로그 기능 유지
4. **모든 페이지에 로그 기록** - TASK-001 로그 체계 일관 적용
5. **KST 시간** - 모든 시간 표시는 한국 시간 기준
6. **Management API 키** 활용으로 DB 스키마 변경 직접 처리 가능

---

## 9. 예상 소요

- DB 스키마 + RPC 함수: 높은 복잡도
- 페이지 17개 (신규) + 6개 (수정) = 23개 파일 작업
- JS 모듈 3개 신규 + 3개 수정

---

*검토 후 승인해주시면 3단계(테스트 시나리오 작성)로 진행하겠습니다.*
