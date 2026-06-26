# TASK-013A 변경 보고서: 유형/권한 6단계 체계 전면 개편 (DB + 인증 코어)

## 작업 개요
- **작업 ID**: TASK-013A (TASK-013의 1단계)
- **버전**: v3.0.0
- **작업일**: 2026-05-27
- **작업자**: AI

## 변경 배경

기존 4역할 체계(admin/dept_manager/teacher/student)를 유형(교사/학생) + 6단계 권한(관리자/전도사님/부장/부서담당교사/일반교사/학생)으로 전면 개편. 계층적 권한 관리, 최고관리자 보호, 사용자 ID 숨김 등 보안 강화.

## 주요 변경사항

### 1. DB 스키마 변경

| 테이블 | 변경 내용 |
|--------|----------|
| profiles | `user_type`, `permission_level`, `is_super_admin` 컬럼 추가 |
| registration_requests | `user_type`, `permission_level` 컬럼 추가 |
| (신규 함수) | `get_permission_rank()` 헬퍼 함수 생성 |

**권한 레벨 체계:**

| permission_level | 수치 (rank) | 설명 |
|-----------------|-------------|------|
| admin | 100 | 관리자 |
| evangelist | 90 | 전도사님 |
| chief | 80 | 부장 |
| dept_teacher | 60 | 부서 담당 교사 |
| teacher | 40 | 일반 교사 |
| student | 20 | 학생 |

### 2. RPC 함수 업데이트 (12개)

| 함수 | 변경 내용 |
|------|----------|
| get_my_profile | user_type, permission_level, is_super_admin 반환 추가 |
| get_my_role | permission_level 반환으로 변경 |
| admin_list_users | permission_level 기반 조회 + is_super_admin 반환 |
| admin_create_user | user_type/permission_level 파라미터 + 상위 권한자 생성 불가 |
| admin_update_user | 계층적 권한 검증 + 최고관리자 보호 |
| admin_delete_user | 계층적 삭제 제한 + 최고관리자 삭제 불가 |
| admin_reset_password | 상위 권한자 비밀번호 초기화 불가 + 최고관리자 보호 |
| give_talent | dept_teacher(60) 이상만 실행 가능 |
| use_talent | dept_teacher(60) 이상만 실행 가능 |
| change_my_password | 변경 없음 (본인 전용) |
| check_username_available | 변경 없음 |
| get_my_managed_dept_id | 변경 없음 |

### 3. RLS 정책 업데이트 (7개 테이블)

| 테이블 | SELECT | INSERT | UPDATE | DELETE |
|--------|--------|--------|--------|--------|
| activity_logs | rank >= 80 | public | rank >= 80 | - |
| departments | public | rank >= 80 | rank >= 80 | rank >= 90 |
| products | public | rank >= 60 | rank >= 60 | rank >= 90 |
| profiles | 본인 OR rank >= 60 | 본인 | 본인 OR rank >= 60 | rank >= 60 |
| registration_requests | rank >= 80 | public | rank >= 80 | rank >= 80 |
| talent_transactions | 본인 OR rank >= 60 | public (RPC 제어) | - | - |
| reports | rank >= 80 | public | - | - |

### 4. 프론트엔드 변경

| 모듈/파일 | 변경 내용 |
|----------|----------|
| js/auth.js | PERMISSION_RANK/LABELS/EMOJI/REDIRECT 체계, initPage(minRank), applyPermNav() |
| js/activity-log.js | loadAuthSession()에 userType, permissionLevel, permissionRank, isSuperAdmin 추가 |
| js/user-mgmt.js | createUser/updateUser에 userType/permissionLevel 파라미터 지원 |
| admin/*.html (11개) | initPage()를 숫자 기반으로 전환, applyPermNav() 추가 |
| student/teacher/*.html (3개) | initPage()를 숫자 기반으로 전환 |
| login.html | permissionLevel 기반 리디렉트 |
| index.html | permissionLevel 기반 리디렉트 + 퀵링크 분기 |
| register.html | user_type/permission_level 자동 설정 |

### 5. 보안 강화

- 사용자 ID(username) 컬럼을 사용자 관리 목록에서 숨김
- 최고관리자(is_super_admin) 계정 본인 외 수정/삭제/비밀번호 초기화 불가
- 계층적 권한 관리: 상위 권한자 수정/삭제 불가 (서버+클라이언트 이중 체크)
- 최고관리자 display_name을 "관리자(admin)"으로 변경

## 호환성

- `session.role` 필드 유지 (TASK-013D에서 최종 제거 예정)
- `data-role="admin"` 속성 유지 (TASK-013B에서 `data-min-perm`으로 전환 예정)
- `initPage()` 배열 방식 여전히 지원 (숫자 + 배열 모두 가능)

## 변경 파일 목록 (22개)

| 파일 | 상태 | 설명 |
|------|------|------|
| js/auth.js | 전면 재작성 | 6단계 권한 체계 코어 |
| js/activity-log.js | 수정 | 확장 세션 캐시 |
| js/user-mgmt.js | 수정 | user_type/permission_level 파라미터 |
| js/version.js | 수정 | v3.0.0 이력 추가 |
| admin/index.html | 수정 | initPage(80), permissionRank 기반 분기 |
| admin/users.html | 수정 | initPage(60), 계층적 관리 버튼, ID 숨김 |
| admin/talents.html | 수정 | initPage(60), permissionRank 기반 스코프 |
| admin/products.html | 수정 | initPage(60), permissionRank 기반 배지 |
| admin/departments.html | 수정 | initPage(80) |
| admin/managers.html | 수정 | initPage(80) |
| admin/shop.html | 수정 | initPage(80) |
| admin/reports.html | 수정 | initPage(80) |
| admin/logs.html | 수정 | initPage(80) |
| admin/versions.html | 수정 | initPage(80) |
| admin/change-password.html | 수정 | permissionLevel 기반 리디렉트 |
| login.html | 수정 | permissionLevel 기반 리디렉트 |
| index.html | 수정 | permissionLevel 기반 리디렉트 + 퀵링크 |
| register.html | 수정 | user_type/permission_level 설정 |
| student/my-talents.html | 수정 | initPage(20) |
| teacher/my-talents.html | 수정 | initPage(20) |
| teacher/shop.html | 수정 | initPage(20) |
| docs/TASK-013A_schema.sql | 신규 | SQL 변경 문서 |

## 다음 단계

- **TASK-013B**: 페이지 구조 통합 + 네비게이션 개선 (data-min-perm 기반 통합 nav)
- **TASK-013C**: 달란트 지급 방식 개편 (talent_items 테이블, 항목별 지급)
- **TASK-013D**: 페이지 권한 관리 + 세부 권한 적용 + role 컬럼 최종 제거
