# TASK-013B/C/D 변경 보고서: 페이지 통합, 달란트 개편, 권한 관리

## 작업 개요
- **작업 ID**: TASK-013B, TASK-013C, TASK-013D (TASK-013의 2~4단계)
- **버전**: v3.1.0 ~ v3.3.0
- **작업일**: 2026-05-27
- **작업자**: AI

---

## TASK-013B: 페이지 구조 통합 + 네비게이션 개선 (v3.1.0)

### 변경 내용

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 학생 내 달란트 | student/my-talents.html | my-talents.html (루트) |
| 학생 상점 | student/shop.html | shop.html (루트) |
| 교사 내 달란트 | teacher/my-talents.html | 통합 → my-talents.html |
| 교사 상점 | teacher/shop.html | 통합 → shop.html |
| 물품 관리 (admin) | admin/products.html + admin/shop.html 분리 | admin/shop.html로 CRUD 통합 |
| 네비게이션 | data-role 기반 + applyRoleNav | data-min-perm 기반 + applyPermNav |

### 삭제된 파일
- `student/my-talents.html`, `student/shop.html`
- `teacher/my-talents.html`, `teacher/shop.html`
- `admin/products.html`

### 네비게이션 표준화
- 모든 admin 페이지: 통일된 `data-min-perm` nav 템플릿 적용
- 루트 레벨 페이지: 로그인 상태에 따라 admin 메뉴 동적 표시
- `earn-talents.html`: 구버전 경로(student/shop.html 등) 제거

---

## TASK-013C: 달란트 지급 방식 개편 (v3.2.0)

### DB 변경

| 항목 | 내용 |
|------|------|
| 신규 테이블 | `talent_items` (id, name, target_type, talent_amount, is_active, sort_order, created_by, created_at) |
| 테이블 확장 | `talent_transactions`에 `talent_item_id` 컬럼 추가 |
| RLS 정책 | talent_items: SELECT(전체), INSERT/UPDATE(rank>=90), DELETE(rank>=100) |

### 초기 데이터

| 대상 | 항목명 | 달란트 |
|------|--------|--------|
| 학생 | 출석 | +3 |
| 학생 | 성경 읽기 | +5 |
| 학생 | 말씀 암송 | +10 |
| 학생 | 찬양 | +2 |
| 학생 | 봉사 | +10 |
| 학생 | 친구 초대 | +20 |
| 학생 | 선행 | +5 |
| 학생 | 특별 활동 | +5 |
| 교사 | 예배 참석 | +5 |
| 교사 | 교사 회의 참석 | +3 |
| 교사 | 봉사 활동 | +10 |
| 교사 | 특별 활동 참여 | +5 |
| 교사 | 연수 참석 | +8 |

### RPC 변경: give_talent
- 새 파라미터: `p_talent_item_id UUID DEFAULT NULL`
- 항목 지정 시: talent_items에서 금액/이름 자동 조회
- 학생 주 1회 규칙: 동일 항목 주간 중복 지급 차단 (KST 기준 월~일)
- 교사: 제한 없음 (상시 지급 가능)
- 수동 지급: 항목 없이 금액+사유 직접 입력도 유지

### 프론트엔드 변경

| 파일 | 변경 |
|------|------|
| admin/talent-items.html | 신규 - 달란트 항목 CRUD 관리 (rank>=90) |
| admin/talents.html | 달란트 모달: 항목 버튼 기반 적립 + 수동 입력(details) + 사용 분리 |
| js/talent.js | giveTalentByItem(), fetchTalentItems(), fetchAllTalentItems() 추가 |

---

## TASK-013D: 페이지 권한 관리 + 세부 권한 적용 (v3.3.0)

### DB 변경

| 항목 | 내용 |
|------|------|
| 신규 테이블 | `page_permissions` (page_key, permission_level, can_view, can_manage) |
| 컬럼 드롭 | `profiles.role`, `registration_requests.role` |
| RPC 업데이트 | admin_list_users: p_role→p_user_type, admin_create_user/update_user: p_role 제거 |
| RPC 업데이트 | get_my_profile: role 필드 제거 |

### page_permissions 초기 데이터

| 페이지 | admin | evangelist | chief | dept_teacher | teacher | student |
|--------|:-----:|:----------:|:-----:|:------------:|:-------:|:-------:|
| dashboard | V/M | V/M | V/M | - | - | - |
| users | V/M | V/M | V/M | V/M | - | - |
| departments | V/M | V/M | V | - | - | - |
| managers | V/M | V/M | V | - | - | - |
| talents | V/M | V/M | V/M | V/M | - | - |
| talent_items | V/M | V/M | - | - | - | - |
| shop | V/M | V/M | V/M | V/M | - | - |
| reports | V/M | V/M | V | - | - | - |
| logs | V/M | V/M | V | - | - | - |
| versions | V/M | V | V | - | - | - |
| page_permissions | V/M | - | - | - | - | - |

### 프론트엔드 role 제거

| 파일 | 변경 |
|------|------|
| js/auth.js | session.role 제거, permissionLevel만 사용 |
| js/activity-log.js | loadAuthSession에서 role 제거 |
| js/user-mgmt.js | p_role→p_user_type/p_permission_level 전환 |
| admin/users.html | 통계/필터/렌더링 permission_level 기반 전환 |
| admin/managers.html | fetchUsers role→userType 전환 |
| admin/departments.html | 사용자 그룹핑 user_type/permission_level 기반 |
| admin/page-permissions.html | 신규 - 권한 매트릭스 관리 UI (admin 전용) |

---

## 전체 영향 범위 (TASK-013A~D 합산)

| 영역 | 변경 수 |
|------|---------|
| DB 테이블 변경 | 5 (profiles, talent_transactions, registration_requests, talent_items, page_permissions) |
| RPC 함수 | 13 (기존 12 + get_permission_rank) |
| RLS 정책 | 8 테이블 |
| JS 모듈 | 4 (auth.js, user-mgmt.js, talent.js, activity-log.js) |
| HTML 페이지 수정 | 15+ |
| 신규 페이지 | 4 (shop.html, my-talents.html, admin/talent-items.html, admin/page-permissions.html) |
| 삭제 페이지 | 5 (student/*, teacher/*, admin/products.html) |
| 최종 버전 | v3.3.0 |
