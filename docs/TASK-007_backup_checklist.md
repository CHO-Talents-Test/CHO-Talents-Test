# TASK-007 사전 점검 및 백업 체크리스트

## 백업 일시
- 2026-05-26 15:00 KST

## 1. 테이블 데이터 백업

### admin_users (6건)
| username | role | department_id | managed_dept_id | talent_balance | is_first_login |
|----------|------|---------------|-----------------|----------------|----------------|
| admin_user | admin | 3부 (996b3f2f) | - | 0 | false |
| duswnd2 | admin | 3부 (996b3f2f) | - | 0 | false |
| test01 | admin | 예배부 (f45a977a) | - | 0 | false |
| test02 | dept_manager | 3부 (996b3f2f) | 예배부 (f45a977a) | 0 | false |
| test03 | teacher | 예배부 (f45a977a) | - | 0 | false |
| test04 | student | 3부 (996b3f2f) | - | 0 | false |

### departments (6건)
| name | id (prefix) | description |
|------|-------------|-------------|
| 1부 | 7ea2bb2e | 2026년 |
| 2부 | 5093d58d | 2026년 |
| 3부 | 996b3f2f | 2026년 |
| 4부 | d424c20e | 2026년 |
| 5부 | e4e68571 | 2026년 |
| 예배부 | f45a977a | 2026년 |

## 2. RLS 정책 백업

### 위험 정책 (제거 대상)
- `admin_users`: anon SELECT/INSERT/UPDATE/DELETE 전체 허용 → **즉시 차단 필요**
- `activity_logs`: anon INSERT/SELECT/UPDATE 전체 허용
- `registration_requests`: 전체 공개 CRUD → INSERT만 공개로 변경

### 유지/수정 대상 정책
- `departments`: 읽기 공개 유지, 쓰기는 admin 제한
- `products`: 읽기 공개 유지, 쓰기는 admin/manager 제한
- `talent_transactions`: 본인+관리자만 조회
- `reports`: admin만 조회

## 3. RPC 함수 백업

### verify_user(p_username, p_password_hash) → json
- SECURITY DEFINER, SQL
- admin_users에서 username + password_hash 매칭 후 사용자 정보 반환
- **제거 예정**: Supabase Auth로 대체

### give_talent(p_user_id, p_amount, p_description, p_created_by) → json
- SECURITY DEFINER, PL/pgSQL
- admin_users.talent_balance 증가 + talent_transactions 기록
- **수정 필요**: profiles 테이블로 변경

### use_talent(p_user_id, p_amount, p_description, p_created_by) → json
- SECURITY DEFINER, PL/pgSQL
- 잔액 확인 후 차감 + talent_transactions 기록
- **수정 필요**: profiles 테이블로 변경

### update_password(p_username, p_new_password_hash) → boolean
- SECURITY DEFINER, PL/pgSQL
- admin_users.password_hash 직접 업데이트
- **제거 예정**: Supabase Auth updateUser로 대체

## 4. 보안 위험 요약

| 위험 | 심각도 | 현황 |
|------|--------|------|
| anon key로 password_hash 조회 가능 | CRITICAL | admin_users SELECT 정책이 true |
| 프론트에서 password_hash 직접 생성 | HIGH | user-mgmt.js에서 SHA-256 후 INSERT |
| 클라이언트 SHA-256 기반 로그인 | HIGH | auth.js에서 해시 후 RPC 비교 |
| sessionStorage 조작으로 권한 상승 | HIGH | requireRole이 sessionStorage만 확인 |
| anon key로 사용자 CRUD 가능 | CRITICAL | INSERT/UPDATE/DELETE 정책이 true |
