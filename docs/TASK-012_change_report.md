# TASK-012 변경 보고서: 관리자/부서관리자 메뉴 통합

## 1. 작업 개요

- **작업명:** manager/ + admin/ 메뉴 통합 (admin/ 기반)
- **버전:** v2.4.0 → v2.5.0
- **작업일:** 2026-05-27
- **작업자:** AI_Cursor

## 2. 변경 요약

manager/ 디렉토리를 삭제하고 모든 관리 기능을 admin/ 디렉토리로 통합했습니다.
관리자(admin)와 부서관리자(dept_manager)가 동일한 admin/ 구조를 사용하되,
`data-role` 속성과 `applyRoleNav()` 함수로 역할별 메뉴를 분기합니다.

## 3. 역할별 메뉴 구성

### 관리자 (admin) - 전체 메뉴
대시보드, 사용자 관리, 부서 관리, 관리자 관리, 달란트 관리, 물품 관리, 상점 관리, 보고서, 로그, 버전

### 부서관리자 (dept_manager) - 제한 메뉴
대시보드, 사용자 관리, 달란트 관리, 물품 관리

## 4. 파일 변경 내역

### 4-1. 신규 생성 (1개)
| 파일 | 설명 |
|------|------|
| `admin/talents.html` | 학생+교사 달란트 통합 관리 (탭 전환, 역할별 스코프) |

### 4-2. 수정 파일 (13개)
| 파일 | 변경 내용 |
|------|----------|
| `js/auth.js` | ROLE_REDIRECT.dept_manager → admin/index.html, applyRoleNav() 함수 추가 |
| `admin/index.html` | initPage 역할 확장, 역할별 대시보드(통계/바로가기/로그), 통합 네비게이션 |
| `admin/users.html` | initPage 역할 확장, dept_manager 읽기 전용(가입승인/등록/삭제 숨김), 통합 네비게이션 |
| `admin/products.html` | initPage 역할 확장, 통합 네비게이션 |
| `admin/departments.html` | 통합 네비게이션 (data-role 적용) |
| `admin/managers.html` | 통합 네비게이션 |
| `admin/shop.html` | 통합 네비게이션 |
| `admin/reports.html` | 통합 네비게이션 |
| `admin/logs.html` | 통합 네비게이션 |
| `admin/versions.html` | 통합 네비게이션 |
| `index.html` | dept_manager 달란트 경로를 admin/talents.html로 변경 |
| `js/version.js` | v2.5.0 업데이트 + TASK-012 변경 이력 추가 |
| `README.md` | manager/ 폴더 제거, admin/talents.html 추가 |

### 4-3. 삭제 파일 (5개)
| 파일 | 통합 대상 |
|------|----------|
| `manager/index.html` | → `admin/index.html` (통합 대시보드) |
| `manager/students.html` | → `admin/talents.html` (학생 탭) |
| `manager/teachers.html` | → `admin/talents.html` (교사 탭) |
| `manager/products.html` | → `admin/products.html` |
| `manager/my-talents.html` | 삭제 (필요시 추후 추가) |

### 4-4. 규칙 파일 수정
| 파일 | 변경 내용 |
|------|----------|
| `.cursor/rules/page-role-mapping.mdc` | admin/dept_manager 통합 구조 반영 |

## 5. 구현 방식

### 역할 분기 (data-role 속성)
```html
<li data-role="admin"><a href="departments.html">부서 관리</a></li>
```
`initPage()` 후 `applyRoleNav(session.role)` 호출로 현재 역할에 맞지 않는 항목 숨김.

### 대시보드 역할별 스코프
- **admin**: 전체 통계, 전체 바로가기 6개, 최근 활동 로그
- **dept_manager**: 담당 부서 통계(학생/교사), 바로가기 3개(사용자/달란트/물품), 로그 미표시

### 사용자 관리 접근 제한
- dept_manager: 담당 부서 사용자만 조회 (RPC 서버측 스코프)
- 가입 신청 승인, 사용자 등록, 수정/삭제/비밀번호초기화 숨김

## 6. 영향 범위

- dept_manager 로그인 시 `admin/index.html`로 리디렉트 (기존: `manager/index.html`)
- 기존 `manager/*` URL 북마크는 404 발생 (불가피)
- DB/RPC 변경 없음 - 기존 RLS와 RPC 함수의 역할 체크가 그대로 유효
