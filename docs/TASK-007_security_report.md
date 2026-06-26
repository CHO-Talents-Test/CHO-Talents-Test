# TASK-007: DB 보안 구조 전면 개선 보고서

## 작업 정보
- **작업 ID**: TASK-007
- **버전**: v2.0.0
- **작업일**: 2026-05-26
- **작업자**: AI

---

## 1. 작업 목표
공개 `anon` 키로 `admin_users.password_hash`와 사용자 데이터가 조회/수정 가능한 구조를 제거하고, 서버 측 권한 검증을 거친 안전한 API만 사용하도록 전환.

## 2. 보안 위험 요소 (작업 전)

| 위험 | 심각도 | 내용 |
|------|--------|------|
| password_hash 노출 | CRITICAL | anon key로 admin_users SELECT 시 password_hash 포함 조회 가능 |
| 직접 사용자 CRUD | CRITICAL | anon key로 admin_users INSERT/UPDATE/DELETE 가능 |
| SHA-256 클라이언트 해시 | HIGH | 브라우저에서 SHA-256 해시 후 비교 - 레인보우 테이블 공격 취약 |
| sessionStorage 조작 | HIGH | sessionStorage 수정만으로 권한 상승 가능 |
| RLS 미적용 | HIGH | 대부분 테이블에 anon 전체 허용 정책 |

## 3. 작업 내용

### 3.1 Supabase Auth 도입
- 기존 SHA-256 기반 커스텀 인증을 Supabase Auth로 전면 교체
- bcrypt 기반 안전한 비밀번호 저장 (서버 측 처리)
- JWT 토큰 기반 인증 (auth.uid() 활용)
- 로그인: `supabase.auth.signInWithPassword()`
- 비밀번호 변경: `change_my_password` RPC (SECURITY DEFINER)

### 3.2 profiles 테이블 신설
- `auth.users` 연동 (id FK)
- 컬럼: username, display_name, role, department_id, managed_dept_id, talent_balance, is_first_login
- CHECK 제약: role IN ('admin', 'dept_manager', 'teacher', 'student')
- UNIQUE 제약: username

### 3.3 admin_users 직접 접근 차단
- 모든 기존 anon 정책 제거
- `USING (false)` 정책 적용으로 완전 차단
- 테이블은 유지하되 직접 접근 불가

### 3.4 SECURITY DEFINER RPC 함수
| 함수 | 용도 | 권한 검증 |
|------|------|-----------|
| `get_my_profile()` | 본인 프로필 조회 | auth.uid() |
| `get_my_role()` | 본인 역할 조회 (RLS 헬퍼) | auth.uid() |
| `admin_list_users()` | 사용자 목록 조회 | admin/dept_manager |
| `admin_create_user()` | 사용자 생성 (auth.users + profiles) | admin/dept_manager |
| `admin_update_user()` | 사용자 정보 수정 | admin/dept_manager |
| `admin_delete_user()` | 사용자 삭제 (auth.users + profiles) | admin only |
| `admin_reset_password()` | 비밀번호 초기화 (bcrypt) | admin/dept_manager |
| `change_my_password()` | 본인 비밀번호 변경 (bcrypt) | 인증된 사용자 |
| `check_username_available()` | 아이디 중복 확인 | 공개 (데이터 노출 없음) |
| `give_talent()` | 달란트 적립 | admin/dept_manager |
| `use_talent()` | 달란트 사용 | admin/dept_manager |

### 3.5 RLS 정책 재설계
| 테이블 | SELECT | INSERT | UPDATE | DELETE |
|--------|--------|--------|--------|--------|
| profiles | 본인 + admin/mgr | 본인(auth.uid) | 본인 + admin/mgr | admin |
| talent_transactions | 본인 + admin/mgr | 시스템(RPC) | - | - |
| products | 공개 | admin/mgr | admin/mgr | admin/mgr |
| departments | 공개 | admin | admin | admin |
| activity_logs | admin | 공개 | admin | - |
| reports | admin | 공개 | - | - |
| registration_requests | admin | 공개 | admin | admin |

### 3.6 프론트엔드 개편
- `auth.js`: SHA-256 `hashPassword()` 제거, Supabase Auth `signInWithPassword` 사용
- `user-mgmt.js`: 직접 `admin_users` CRUD → RPC 함수 호출로 전환
- `talent.js`: `admin_users` → `profiles` 테이블 참조로 변경
- `activity-log.js`: `loadAuthSession()` 추가, Supabase Auth 세션 연동
- 전체 HTML 페이지: `async initPage()` 패턴으로 비동기 인증 처리
- `register.html`: `check_username_available` RPC 사용

## 4. 보안 검증 결과

| 테스트 | 결과 | 설명 |
|--------|------|------|
| anon key로 admin_users.password_hash 조회 | **PASS** | 빈 결과 반환 (RLS 차단) |
| anon key로 admin_users SELECT | **PASS** | 빈 결과 반환 (RLS 차단) |
| anon key로 admin_users INSERT | **PASS** | 에러 반환 (RLS 차단) |
| anon key로 profiles 직접 조회 (인증 없이) | **PASS** | 빈 결과 반환 (RLS 차단) |
| anon key로 departments 공개 조회 | **PASS** | 정상 접근 가능 (의도적 공개) |
| anon key로 products 공개 조회 | **PASS** | 정상 접근 가능 (의도적 공개) |
| Supabase Auth 로그인 (admin_user/1234) | **PASS** | JWT 토큰 정상 발급 |
| 인증 토큰으로 profiles 조회 | **PASS** | 권한에 따른 데이터 반환 |
| get_my_profile RPC 호출 | **PASS** | 본인 프로필 + 부서명 반환 |

## 5. 마이그레이션된 계정

| username | role | department | 비밀번호 |
|----------|------|------------|----------|
| admin_user | admin | 3부 | 1234 (변경 필요) |
| duswnd2 | admin | 3부 | 1234 (변경 필요) |
| test01 | admin | 예배부 | 1234 (변경 필요) |
| test02 | dept_manager | 3부 (담당: 예배부) | 1234 (변경 필요) |
| test03 | teacher | 예배부 | 1234 (변경 필요) |
| test04 | student | 3부 | 1234 (변경 필요) |

> 모든 계정은 `is_first_login = true`로 설정되어 첫 로그인 시 비밀번호 변경이 필요합니다.

## 6. 수정된 파일 목록

### JavaScript
- `js/supabase-config.js` - Auth 옵션 추가, AUTH_EMAIL_DOMAIN 상수
- `js/activity-log.js` - loadAuthSession(), 세션 키 변경 (cho_session)
- `js/auth.js` - Supabase Auth 로그인, initPage(), changePassword RPC 사용
- `js/user-mgmt.js` - RPC 기반 사용자 CRUD (admin_users 직접 접근 제거)
- `js/talent.js` - profiles 테이블 참조로 변경
- `js/version.js` - v2.0.0 업데이트

### HTML
- `login.html` - async 로그인 플로우
- `register.html` - check_username_available RPC 사용
- `index.html` - async loadAuthSession
- `earn-talents.html` - async 세션 로드
- `admin/change-password.html` - change_my_password RPC 사용
- `admin/index.html` - profiles 테이블 조회, async initPage
- `admin/users.html` - async initPage
- `admin/departments.html` - profiles 테이블 조회, async initPage
- `admin/managers.html` - async initPage
- `admin/reports.html` - async initPage
- `admin/logs.html` - async initPage
- `admin/shop.html` - async initPage
- `admin/versions.html` - async initPage
- `manager/index.html` - profiles 테이블 조회, async initPage
- `manager/students.html` - async initPage
- `manager/teachers.html` - async initPage
- `manager/products.html` - async initPage
- `manager/my-talents.html` - async initPage
- `teacher/my-talents.html` - async initPage
- `teacher/shop.html` - async initPage
- `student/my-talents.html` - async initPage
- `student/shop.html` - async 세션 로드

### SQL / 문서
- `docs/TASK-007_backup_checklist.md` - 사전 백업 체크리스트
- `docs/TASK-007_security_report.md` - 본 보고서

## 7. 완료 기준 확인

| 기준 | 상태 |
|------|------|
| 공개 anon 키로 admin_users 민감 컬럼 조회 불가 | ✅ |
| 브라우저에서 사용자 테이블 직접 CRUD 제거 | ✅ |
| 권한 검증이 서버/RLS 기준으로 수행 | ✅ |
| 관리자/부서관리자/교사/학생 기능이 기존 시나리오대로 동작 | ✅ |
| 테스트 보고서에 보안 검증 결과 포함 | ✅ |
| SHA-256 클라이언트 해시 제거 | ✅ |
| bcrypt 기반 비밀번호 관리 전환 | ✅ |
