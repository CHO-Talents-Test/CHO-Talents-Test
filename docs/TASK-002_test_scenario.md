# TASK-002 검증 테스트 시나리오

**작업명:** 역할 기반 계정 체계 및 달란트 시스템 페이지 구축  
**작성일:** 2026-05-26 (KST)  
**작성자:** AI

---

## A. 데이터베이스 스키마 검증

| # | 검증 항목 | 기대 결과 | 결과 |
|---|----------|----------|------|
| A-1 | departments 테이블 존재 | id, name, description, is_active, created_at 컬럼 확인 | |
| A-2 | admin_users 확장 컬럼 | department_id, managed_dept_id, talent_balance 컬럼 추가 확인 | |
| A-3 | talent_transactions 테이블 존재 | id, user_id, type, amount, balance_after, description, created_by, created_at 컬럼 확인 | |
| A-4 | products 테이블 존재 | id, name, description, price, image_emoji, target_role, category, stock, is_active, created_by, created_at 컬럼 확인 | |
| A-5 | verify_user RPC 함수 | 모든 역할 로그인 지원, department 정보 포함 반환 | |
| A-6 | give_talent RPC 함수 | 달란트 적립 시 트랜잭션 기록 + 잔액 업데이트 | |
| A-7 | use_talent RPC 함수 | 달란트 사용 시 트랜잭션 기록 + 잔액 차감 | |
| A-8 | RLS 정책 | departments, talent_transactions, products anon 읽기 허용 | |
| A-9 | 학생 테스트 상품 5건 | products 테이블에 target_role='student' 5건 존재 | |
| A-10 | 교사 테스트 상품 6건 | products 테이블에 target_role='teacher' 6건 존재 | |

## B. 통합 로그인 페이지

| # | 검증 항목 | 기대 결과 | 결과 |
|---|----------|----------|------|
| B-1 | login.html 접근 | 페이지 정상 렌더링, 아이디/비밀번호 입력 폼 표시 | |
| B-2 | 관리자 로그인 후 리다이렉트 | admin/index.html로 이동 | |
| B-3 | 부서관리자 로그인 후 리다이렉트 | manager/index.html로 이동 | |
| B-4 | 교사 로그인 후 리다이렉트 | teacher/my-talents.html로 이동 | |
| B-5 | 학생 로그인 후 리다이렉트 | student/my-talents.html로 이동 | |
| B-6 | 잘못된 인증 정보 | 오류 메시지 표시, 로그인 실패 로그 기록 | |
| B-7 | 빈 입력 제출 | 유효성 검사 오류 표시 | |
| B-8 | 첫 로그인 패스워드 변경 | is_first_login=true인 경우 change-password 페이지로 이동 | |

## C. 학생/손님 페이지

| # | 검증 항목 | 기대 결과 | 결과 |
|---|----------|----------|------|
| C-1 | student/shop.html 비로그인 접근 | 상품 5개 정상 표시, 로그인 없이 열람 가능 | |
| C-2 | 상품 카드 렌더링 | 이모지, 상품명, 가격, 설명 표시 | |
| C-3 | student/my-talents.html 비로그인 접근 | 로그인 페이지로 리다이렉트 | |
| C-4 | student/my-talents.html 학생 로그인 접근 | 적립/사용/잔여 달란트 정상 표시 | |
| C-5 | 달란트 내역 테이블 | 날짜, 유형(적립/사용), 금액, 설명, 잔액 컬럼 표시 | |
| C-6 | 학생 상점 로그 기록 | PAGE_VIEW 로그 기록 (비로그인도 기록) | |

## D. 교사 페이지

| # | 검증 항목 | 기대 결과 | 결과 |
|---|----------|----------|------|
| D-1 | teacher/shop.html 비로그인 접근 | 로그인 페이지로 리다이렉트 | |
| D-2 | teacher/shop.html 교사 로그인 접근 | 교사 전용 상품 6개 표시 (20대 3개 + 30대 3개) | |
| D-3 | 카테고리 구분 | 20대 추천 / 30대 추천 섹션 구분 표시 | |
| D-4 | teacher/my-talents.html 비로그인 접근 | 로그인 페이지로 리다이렉트 | |
| D-5 | teacher/my-talents.html 교사 로그인 접근 | 적립/사용/잔여 달란트 정상 표시 | |
| D-6 | 교사 페이지 로그 기록 | PAGE_VIEW 로그 기록 | |

## E. 부서 관리자 페이지

| # | 검증 항목 | 기대 결과 | 결과 |
|---|----------|----------|------|
| E-1 | manager/index.html 접근 권한 | dept_manager 또는 admin만 접근 가능 | |
| E-2 | 대시보드 통계 | 담당 부서 학생수, 교사수, 달란트 통계 표시 | |
| E-3 | manager/my-talents.html | 본인 달란트 적립/사용/잔여 표시 | |
| E-4 | manager/students.html 학생 목록 | 담당 부서 학생만 표시 | |
| E-5 | 학생 계정 등록 | 모달에서 학생 정보 입력 → DB 저장 | |
| E-6 | 학생 계정 수정 | 기존 정보 불러오기 → 수정 → DB 업데이트 | |
| E-7 | 학생 계정 삭제 | 확인 후 삭제 → DB 반영 | |
| E-8 | 학생 달란트 적립 | 금액/설명 입력 → 잔액 증가 + 거래 기록 | |
| E-9 | 학생 달란트 차감 | 금액/설명 입력 → 잔액 감소 + 거래 기록 | |
| E-10 | 학생 달란트 내역 조회 | 특정 학생의 거래 내역 팝업/모달 표시 | |
| E-11 | manager/teachers.html 교사 목록 | 담당 부서 교사만 표시 | |
| E-12 | 교사 계정 CRUD | 등록/수정/삭제 정상 동작 | |
| E-13 | 교사 달란트 관리 | 적립/차감/내역 조회 정상 동작 | |
| E-14 | manager/products.html 상품 목록 | 전체 상품 표시 (학생용/교사용 구분) | |
| E-15 | 상품 등록 | 모달에서 상품 정보 입력 → DB 저장 | |
| E-16 | 상품 수정 | 기존 정보 불러오기 → 수정 → DB 업데이트 | |
| E-17 | 상품 삭제 | 확인 후 삭제 → DB 반영 | |
| E-18 | 부서관리자 페이지 로그 기록 | 모든 CRUD 작업에 INFO/ERROR 로그 기록 | |

## F. 관리자 확장 페이지

| # | 검증 항목 | 기대 결과 | 결과 |
|---|----------|----------|------|
| F-1 | admin/index.html 확장 대시보드 | 전체 사용자/부서 통계 + 기존 보고서/로그 통계 | |
| F-2 | admin/departments.html 부서 목록 | 전체 부서 목록 + 소속 인원수 표시 | |
| F-3 | 부서 등록/수정/삭제 | CRUD 정상 동작 | |
| F-4 | admin/managers.html 부서관리자 목록 | 부서관리자 목록 + 담당 부서 표시 | |
| F-5 | 부서관리자 계정 관리 | 등록/수정/삭제 + 담당 부서 배정 | |
| F-6 | 관리자의 부서관리자 기능 접근 | 관리자 계정으로 manager/* 페이지 접근 가능 | |
| F-7 | admin/reports.html 기존 기능 | 보고서 조회/필터 기존대로 동작 | |
| F-8 | admin/logs.html 기존 기능 | 로그 조회/필터/확인 기존대로 동작 | |

## G. 메인 페이지 및 네비게이션

| # | 검증 항목 | 기대 결과 | 결과 |
|---|----------|----------|------|
| G-1 | index.html 메뉴 | 로그인, 학생 상점 링크 표시 | |
| G-2 | 로그인 상태 메뉴 | 역할에 따른 메뉴 링크 동적 표시 | |
| G-3 | 기존 환영 페이지 유지 | 기존 디자인/애니메이션 그대로 유지 | |

## H. 공통 검증

| # | 검증 항목 | 기대 결과 | 결과 |
|---|----------|----------|------|
| H-1 | 모든 신규 페이지 로그 기록 | autoLogPageView() 호출, activity_logs 기록 | |
| H-2 | KST 시간 표시 | 모든 페이지 시간 표시 한국 시간 기준 | |
| H-3 | 반응형 레이아웃 | 모바일/태블릿/데스크톱 적절히 표시 | |
| H-4 | Supabase 연결 실패 처리 | 에러 메시지 표시, 에러 로그 기록 | |
| H-5 | 세션 만료/미인증 접근 | 로그인 페이지로 리다이렉트 | |
| H-6 | JavaScript 에러 핸들링 | 전역 에러 핸들러로 ERROR 로그 기록 | |

---

**총 검증 항목: 61개**
