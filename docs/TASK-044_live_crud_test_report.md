# TASK-044 실데이터 CRUD 기능 검증 보고서

- 검증일: 2026-06-08
- 검증 계정: `****`
- 검증자: AI_Codex
- 테스트 표식: `AI_Codex_CRUD_20260608_151856`
- 검증 방식: 실제 사이트 로그인 화면 확인 + 마스킹된 관리자 인증 세션 기반 Supabase CRUD 호출
- 검증 결과: PASS 54건, FAIL 0건

## 1. 요약

실제 서비스 전 운영 데이터에서 테스트 전용 표식을 붙인 임시 데이터를 생성하고, 등록/수정/삭제 또는 비활성화/소프트 삭제 흐름을 검증했다.

부서, 사용자, 관리자 권한, 가입 신청, 달란트 항목, 달란트 지급/반환, 상품, 구매 신청/상태 변경/취소, QR, Q&A, 페이지 권한, 페이지 접근/기능, 로그, 보고서 CRUD는 정상 처리되었다.

이전 점검에서 실패했던 `department_transfer_requests` REST 엔드포인트 404는 테이블/RLS/권한 정책 재적용과 PostgREST 스키마 캐시 재적재 후 재검증에서 해소되었다.

## 2. 화면 확인

| 페이지 | 확인 내용 | 결과 | 비고 |
|---|---|---|---|
| `index.html` | 로그인 유지, 메인 화면 로딩 | PASS | 서버 연결 상태 정상 |
| `admin/departments.html` | 부서 목록, 등록/수정/삭제 메뉴 표시 및 실제 부서 CRUD | PASS | 브라우저 UI로 직접 등록/수정/비활성화 확인 |
| `admin/users.html` | 사용자 목록, 등록 모달, 부서 필수 검증 | PASS | 화면 자동화에서 select 변경은 제한됨. REST 권한으로 실제 사용자 CRUD 검증 |
| `admin/managers.html` | 관리자 관리 화면 로딩 | PASS | 교사 생성, 권한 등록/수정/해제/삭제 검증 |
| `admin/talents.html` | 달란트 관리 화면 로딩 | PASS | 임시 사용자 대상 지급/반환 RPC 검증 |
| `admin/talent-items.html` | 달란트 항목 화면 로딩 | PASS | 항목 등록/수정/비활성화 검증 |
| `admin/shop.html` | 상품 관리 화면 로딩 | PASS | 상품 등록/수정/비활성화 검증 |
| `shop.html` | 상품 구매 화면 로딩 | PASS | 임시 상품 구매 신청 RPC 검증 |
| `my-orders.html` | 내 구매 상품 화면 로딩 | PASS | 임시 주문 취소 상태 전환 검증 |
| `admin/purchases.html` | 구매 관리 화면 로딩 | PASS | 주문 준비/되돌리기 검증 |
| `admin/talent-qr.html` | QR 관리 화면 로딩 | PASS | QR 등록/수정/비활성화 검증 |
| `qna.html` | Q&A 화면 로딩 | PASS | 질문/답변/소프트 삭제 검증 |
| `admin/page-permissions.html` | 페이지 권한 데이터 CRUD | PASS | 앱 미사용 임시 page_key로 검증 후 삭제 |
| `admin/page-access.html` | 페이지 접근 화면 로딩 및 데이터 CRUD | PASS | 앱 미사용 임시 page_id로 검증 후 삭제 |
| `admin/page-features.html` | 페이지 기능 화면 로딩 및 데이터 CRUD | PASS | 앱 미사용 임시 page_id로 검증 후 삭제 |
| `admin/logs.html` | 로그 화면 로딩, 확인/삭제 대기 처리 | PASS | 테스트 ERROR 로그 생성 후 확인/소프트 삭제 |
| `admin/audit.html` | 작업 이력 화면 로딩 | PASS | 작업 로그 기반 이력 화면 접근 정상 |
| `admin/reports.html` | 보고서 DB 등록 및 목록 노출 | PASS | TASK-044 등록, 누락 시드 보강 후 재조회, 최신 row 노출 흐름 확인 |

## 3. CRUD 검증 상세

| 구분 | 페이지 | 작업 | 결과 | 비고 |
|---|---|---|---|---|
| 로그인 | `login.html` | 계정 인증 토큰 발급 | PASS | 마스킹된 관리자 계정 인증 성공 |
| 로그인 | `index.html` | 프로필 조회 | PASS | `permission_level=admin`, `is_super_admin=true` |
| 부서 관리 | `admin/departments.html` | 부서 등록 | PASS | 임시 부서 생성 |
| 부서 관리 | `admin/departments.html` | 부서 수정 | PASS | 이름/설명/반 수 수정 |
| 부서 관리 | `admin/departments.html` | 부서 삭제(비활성화) | PASS | `is_active=false` |
| 사용자 관리 | `admin/users.html` | 학생 사용자 등록 | PASS | `admin_create_user` RPC |
| 사용자 관리 | `admin/users.html` | 학생 사용자 수정 | PASS | `admin_update_user` RPC |
| 사용자 관리 | `admin/users.html` | 임시 학생 계정 삭제 | PASS | `admin_delete_user` RPC |
| 관리자 관리 | `admin/managers.html` | 교사 계정 등록 | PASS | `admin_create_user` RPC |
| 관리자 관리 | `admin/managers.html` | 관리자 권한 등록 | PASS | `dept_teacher` 권한 부여 |
| 관리자 관리 | `admin/managers.html` | 관리자 권한 수정 | PASS | `chief` 권한 변경 |
| 관리자 관리 | `admin/managers.html` | 관리자 권한 해제 | PASS | 일반 교사로 복구 |
| 관리자 관리 | `admin/managers.html` | 임시 관리자 계정 삭제 | PASS | `admin_delete_user` RPC |
| 가입 신청 | `admin/users.html` | 가입 신청 등록 | PASS | 임시 신청 row 생성 |
| 가입 신청 | `admin/users.html` | 가입 신청 수정/반려 | PASS | `status=rejected` |
| 가입 신청 | `admin/users.html` | 가입 신청 삭제 | PASS | 임시 신청 row 삭제 |
| 부서 이동 신청 | `admin/users.html` | 이동 신청 등록 | PASS | 테이블/RLS/스키마 캐시 재적용 후 REST insert 검증 |
| 부서 이동 신청 | `admin/users.html` | 이동 신청 수정 | PASS | REST update로 `status=rejected` 검증 |
| 부서 이동 신청 | `admin/users.html` | 이동 신청 삭제 | PASS | 임시 이동 신청 row 삭제 |
| 달란트 항목 | `admin/talent-items.html` | 항목 등록 | PASS | 임시 항목 생성 |
| 달란트 항목 | `admin/talent-items.html` | 항목 수정 | PASS | 이름/금액/정렬 수정 |
| 달란트 항목 | `admin/talent-items.html` | 항목 삭제(비활성화) | PASS | `is_active=false` |
| 달란트 관리 | `admin/talents.html` | 달란트 지급 | PASS | `give_talent` RPC 오버로드 문제 없음 |
| 달란트 관리 | `admin/talents.html` | 달란트 반환 | PASS | `use_talent` RPC |
| 상품 관리 | `admin/shop.html` | 상품 등록 | PASS | 임시 상품 생성 |
| 상품 관리 | `admin/shop.html` | 상품 수정 | PASS | 이름/설명/카테고리 수정 |
| 상품 관리 | `admin/shop.html` | 상품 삭제(비활성화) | PASS | `is_active=false` |
| 상품 구매 | `shop.html` | 구매 신청 등록 | PASS | `request_product_order` RPC |
| 구매 관리 | `admin/purchases.html` | 주문 상태 수정 | PASS | `requested -> preparing` |
| 구매 관리 | `admin/purchases.html` | 주문 상태 되돌리기 | PASS | `preparing -> requested` |
| 내 구매 상품 | `my-orders.html` | 구매 신청 삭제(취소) | PASS | `status=cancelled` |
| QR 관리 | `admin/talent-qr.html` | QR 등록 | PASS | 임시 QR 생성 |
| QR 관리 | `admin/talent-qr.html` | QR 수정 | PASS | 설명/수량 수정 |
| QR 관리 | `admin/talent-qr.html` | QR 삭제(비활성화) | PASS | `is_active=false` |
| Q&A | `qna.html` | 질문 등록 | PASS | 임시 질문 생성 |
| Q&A | `qna.html` | 답변 댓글 등록 | PASS | `qna_comments` insert |
| Q&A | `qna.html` | 질문 답변 상태 수정 | PASS | `status=answered` |
| Q&A | `qna.html` | 질문 삭제(소프트 삭제) | PASS | `admin_soft_delete_qna` RPC |
| 페이지 권한 | `admin/page-permissions.html` | 권한 등록 | PASS | 임시 page_key |
| 페이지 권한 | `admin/page-permissions.html` | 권한 수정 | PASS | `can_manage=true` |
| 페이지 권한 | `admin/page-permissions.html` | 권한 삭제 | PASS | 임시 row 삭제 |
| 페이지 접근 | `admin/page-access.html` | 접근 등록 | PASS | 임시 page_id |
| 페이지 접근 | `admin/page-access.html` | 접근 수정 | PASS | `can_access=false` |
| 페이지 접근 | `admin/page-access.html` | 접근 삭제 | PASS | 임시 row 삭제 |
| 페이지 기능 | `admin/page-features.html` | 기능 등록 | PASS | 임시 page_id |
| 페이지 기능 | `admin/page-features.html` | 기능 수정 | PASS | JSON features 수정 |
| 페이지 기능 | `admin/page-features.html` | 기능 삭제 | PASS | 임시 row 삭제 |
| 로그 | `admin/logs.html` | ERROR 로그 등록 | PASS | 테스트 로그 생성 |
| 로그 | `admin/logs.html` | 로그 확인 처리 | PASS | `is_acknowledged=true` |
| 로그 | `admin/logs.html` | 로그 삭제 대기 처리 | PASS | `is_deleted=true` |
| 보고서 | `admin/reports.html` | 임시 보고서 등록 | PASS | 임시 보고서 생성 |
| 보고서 | `admin/reports.html` | 임시 보고서 수정 | PASS | 제목/내용 수정 |
| 보고서 | `admin/reports.html` | 임시 보고서 삭제 | PASS | 임시 보고서 삭제 |
| 보고서 | `admin/reports.html` | 최종 보고서 등록 | PASS | `TASK-044` DB row 등록 |

## 4. 개선 완료 항목

| 항목 | 문제점 | 영향 | 개선 방법 |
|---|---|---|---|
| 부서 이동 신청 등록 | `department_transfer_requests` REST 엔드포인트가 404를 반환 | 부서 이동 신청 기능이 실제 API에서 동작하지 않을 수 있음 | `docs/TASK-045_department_transfer_reports_fix.sql`을 작성하고 운영 DB에 적용했다. 테이블/RLS/권한/스키마 캐시 재적재 후 insert/update/delete 재검증 PASS |
| 보고서 화면 목록 | `reports` 테이블에는 `TASK-044`가 정상 등록됐지만 화면 첫 목록에서 즉시 노출되지 않음 | 운영자가 새 보고서 등록 직후 화면에서 확인하기 어려움 | `reports.html`에서 조회 count/최신 row 로그를 추가하고, 누락 시드 보강 및 자동복구 후 DB 재조회가 강제되도록 수정 |
| 사용자 등록 화면 자동화 | 브라우저 자동화에서 HTML select 값 변경이 제한되어 첫 UI 저장 시 부서 필수 검증에 걸림 | 실제 사용자 조작 결함은 아니며, 자동화 한계 | 사용자 등록/수정 및 부서 이동 폼에 안정적인 `data-testid`를 추가했다. E2E에서는 Playwright `selectOption` 대상으로 사용 가능 |

## 5. 데이터 정리 상태

| 데이터 | 정리 방식 | 결과 |
|---|---|---|
| 임시 부서 | `is_active=false` | PASS |
| 임시 학생/교사 | `admin_delete_user` RPC | PASS |
| 임시 가입 신청 | DELETE | PASS |
| 임시 부서 이동 신청 | DELETE | PASS |
| 임시 달란트 항목 | `is_active=false` | PASS |
| 임시 달란트 지급 | 반환 트랜잭션 생성 | PASS |
| 임시 상품 | `is_active=false` | PASS |
| 임시 주문 | `status=cancelled` | PASS |
| 임시 QR | `is_active=false` | PASS |
| 임시 Q&A | `is_deleted=true` | PASS |
| 임시 페이지 권한/접근/기능 | DELETE | PASS |
| 임시 로그 | 확인 처리 후 `is_deleted=true` | PASS |
| 임시 보고서 | DELETE | PASS |
| 최종 보고서 | `TASK-044` 유지 | PASS |

## 6. 결론

현재 마스킹된 최고관리자 계정으로 수행 가능한 등록/수정/삭제 또는 상태 전환 작업은 정상 처리된다. 달란트 지급 RPC 후보 함수 충돌 문제도 이번 지급 검증에서 재발하지 않았다.

부서 이동 신청 API 404와 보고서 화면의 최신 보고서 노출 문제는 이번 조치에서 개선 완료했다. 이후 같은 문제가 반복될 때는 `docs/TASK-045_department_transfer_reports_fix.sql`을 재실행하고 보고서 화면의 `loadStatus` 단계 로그를 확인하면 된다.
