# TASK-002 수정 사항 보고서

**작업명:** 역할 기반 계정 체계 및 달란트 시스템 페이지 구축  
**작업일:** 2026-05-26 (KST)  
**작성자:** AI

---

## 1. 변경 요약

기존 관리자 전용 시스템을 4가지 역할(관리자, 부서 관리자, 교사, 학생) 기반 체계로 확장.  
달란트 적립/사용/잔여 조회 시스템과 역할별 물품 상점 페이지를 구현.

---

## 2. 데이터베이스 변경사항

### 2-1. 신규 테이블 (3개)
| 테이블 | 설명 | 컬럼수 |
|--------|------|--------|
| `departments` | 부서 관리 | 5 |
| `talent_transactions` | 달란트 거래 이력 | 8 |
| `products` | 달란트 물품 | 11 |

### 2-2. 기존 테이블 변경
| 테이블 | 변경 | 내용 |
|--------|------|------|
| `admin_users` | 컬럼 추가 | `department_id`, `managed_dept_id`, `talent_balance` |
| `admin_users` | RLS 확장 | INSERT/UPDATE/DELETE/SELECT 정책 추가 |

### 2-3. 신규 RPC 함수 (2개)
| 함수 | 설명 |
|------|------|
| `verify_user` | 전 역할 로그인 (verify_admin 확장) |
| `give_talent` | 달란트 적립 (트랜잭션 + 잔액 업데이트) |
| `use_talent` | 달란트 사용 (잔액 검증 + 차감) |

### 2-4. 샘플 데이터
- 학생용 상품 5건 (캐릭터 연필세트, 지우개, 인형 키링, 스티커북, 간식 쿠폰)
- 교사용 상품 6건 (스타벅스 쿠폰, 이어폰 파우치, 다이어리, 핸드크림, 가습기, 편의점 상품권)

---

## 3. 신규 파일 목록 (19개)

### 3-1. JavaScript 모듈 (3개)
| 파일 | 설명 |
|------|------|
| `js/talent.js` | 달란트 조회/적립/사용 공통 모듈 |
| `js/product.js` | 상품 CRUD 모듈 |
| `js/user-mgmt.js` | 사용자/부서 관리 모듈 |

### 3-2. CSS (1개)
| 파일 | 설명 |
|------|------|
| `css/common.css` | 학생/교사 페이지 공통 스타일 |

### 3-3. HTML 페이지 (14개)
| 파일 | 설명 |
|------|------|
| `login.html` | 통합 로그인 페이지 (전 역할) |
| `student/shop.html` | 학생 달란트 상점 (비로그인 열람 가능) |
| `student/my-talents.html` | 학생 달란트 내역 조회 |
| `teacher/shop.html` | 교사 달란트 상점 (20대/30대 카테고리) |
| `teacher/my-talents.html` | 교사 달란트 내역 조회 |
| `manager/index.html` | 부서 관리자 대시보드 |
| `manager/my-talents.html` | 부서 관리자 달란트 내역 |
| `manager/students.html` | 학생 계정/달란트 관리 (CRUD) |
| `manager/teachers.html` | 교사 계정/달란트 관리 (CRUD) |
| `manager/products.html` | 물품 관리 (CRUD) |
| `admin/departments.html` | 부서 관리 (CRUD) |
| `admin/managers.html` | 부서 관리자 계정 관리 |

### 3-4. SQL/문서 (3개)
| 파일 | 설명 |
|------|------|
| `docs/TASK-002_schema.sql` | DB 스키마 변경 SQL 기록 |
| `docs/TASK-002_plan.md` | 작업 계획서 |
| `docs/TASK-002_test_scenario.md` | 검증 테스트 시나리오 |

---

## 4. 수정 파일 목록 (6개)

| 파일 | 변경 내용 |
|------|----------|
| `js/auth.js` | verify_user RPC 사용, ROLE_LABELS/ROLE_REDIRECT 추가, requireRole/getRoleRedirectUrl 함수 추가 |
| `index.html` | 메인 네비게이션 추가 (달란트 상점, 로그인 버튼), 로그인 상태 동적 메뉴 |
| `css/style.css` | .main-nav, .nav-btn 스타일 추가 |
| `admin/index.html` | 대시보드 확장 (전체 사용자/부서/역할별 통계), 부서관리/관리자관리 네비게이션 추가 |
| `admin/reports.html` | 네비게이션에 부서관리/관리자관리 링크 추가 |
| `admin/logs.html` | 네비게이션에 부서관리/관리자관리 링크 추가 |

---

## 5. 접근 권한 매트릭스

| 페이지 | 손님 | 학생 | 교사 | 부서관리자 | 관리자 |
|--------|------|------|------|----------|--------|
| index.html | ✅ | ✅ | ✅ | ✅ | ✅ |
| student/shop.html | ✅ | ✅ | ✅ | ✅ | ✅ |
| student/my-talents.html | ❌ | ✅ | ❌ | ✅ | ✅ |
| teacher/shop.html | ❌ | ❌ | ✅ | ✅ | ✅ |
| teacher/my-talents.html | ❌ | ❌ | ✅ | ✅ | ✅ |
| manager/* | ❌ | ❌ | ❌ | ✅ | ✅ |
| admin/* | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 6. 아키텍처 변화

### Before (TASK-001)
```
index.html (공개)
admin/ (관리자 전용)
  ├── login.html
  ├── index.html
  ├── reports.html
  └── logs.html
```

### After (TASK-002)
```
index.html (공개, 메뉴 추가)
login.html (통합 로그인)
student/ (학생/손님)
  ├── shop.html (공개)
  └── my-talents.html (로그인 필수)
teacher/ (교사)
  ├── shop.html
  └── my-talents.html
manager/ (부서 관리자)
  ├── index.html
  ├── my-talents.html
  ├── students.html
  ├── teachers.html
  └── products.html
admin/ (관리자, 확장)
  ├── index.html (확장)
  ├── departments.html (신규)
  ├── managers.html (신규)
  ├── reports.html (네비 수정)
  └── logs.html (네비 수정)
```

---

## 7. 향후 개선 사항

1. **실제 계정 등록** - 현재 구조만 준비, 실제 학생/교사/관리자 계정 등록 필요
2. **상품 구매 기능** - 현재는 상점 열람만, 실제 구매(달란트 차감) 프로세스 구현 필요
3. **프로필 사진 업로드** - 사용자 프로필 이미지 지원
4. **달란트 랭킹** - 메인 페이지의 "랭킹 보기" 기능 구현
5. **비밀번호 정책 강화** - 최소 길이, 복잡도 규칙 추가
6. **부서별 대시보드** - 부서 관리자용 상세 통계/차트
