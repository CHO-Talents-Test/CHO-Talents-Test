-- ============================================================
-- 전체 작업 보고서 등록 (한글 깨짐 데이터 교체 포함)
-- Supabase SQL Editor에서 실행해주세요
-- ============================================================

-- 기존 보고서 전체 삭제 (깨진 데이터 포함)
DELETE FROM reports;

-- TASK-001: v1.0.0 초기 구축
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-001', 'v1.0.0 초기 구축', 'change_report',
  '<h2>수정 보고서: TASK-001</h2>
<p><strong>버전:</strong> v1.0.0 | <strong>작업일:</strong> 2026-05-25</p>
<h3>주요 변경 사항</h3>
<ul>
<li>환영 메인 페이지 구현</li>
<li>관리자 로그인/패스워드 변경 시스템</li>
<li>관리자 대시보드 (보고서, 로그 조회)</li>
<li>Supabase 연동 및 CRUD 환경 구성</li>
<li>활동 로그 시스템 (레벨별, KST 시간, 미확인 ERROR 알림)</li>
<li>GitHub Pages 배포 환경 구성</li>
</ul>', 'AI_Cursor');

-- TASK-002: v1.1.0 역할별 계정 시스템
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-002', 'v1.1.0 역할별 계정 시스템 및 페이지 구현', 'change_report',
  '<h2>수정 보고서: TASK-002</h2>
<p><strong>버전:</strong> v1.1.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>4단계 역할 구분 (관리자, 부서관리자, 교사, 학생)</li>
<li>역할별 페이지 구현 (학생/교사/부서관리자 전용)</li>
<li>달란트 상점 (학생용/교사용 분리)</li>
<li>달란트 내역 조회 페이지</li>
<li>부서 관리자 기능 (학생/교사 계정 관리, 달란트 관리, 물품 관리)</li>
<li>관리자 기능 확장 (부서 관리, 관리자 계정 관리)</li>
<li>RPC 함수 (verify_user, give_talent, use_talent)</li>
<li>통합 로그인 페이지</li>
</ul>', 'AI_Cursor');

-- TASK-003: v1.2.0 상품 이미지 및 메인 화면 개선
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-003', 'v1.2.0 상품 이미지 및 메인 화면 개선', 'change_report',
  '<h2>수정 보고서: TASK-003</h2>
<p><strong>버전:</strong> v1.2.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>상품 이미지 URL 지원 (products 테이블 image_url 컬럼)</li>
<li>Supabase Storage 파일 업로드 (Talents_Items 버킷)</li>
<li>물품 관리 페이지 드래그앤드롭 이미지 업로드 UI</li>
<li>학생/교사 상점 이미지 표시</li>
<li>메인 화면 카드 링크 연결 (달란트적립, 상품구매, 내달란트)</li>
<li>달란트 적립 방법 안내 페이지 (earn-talents.html)</li>
<li>관리자 상점 조회 페이지 (학생/교사/전체 탭 전환)</li>
</ul>', 'AI_Cursor');

-- TASK-004: v1.3.0 버전 관리 시스템
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-004', 'v1.3.0 버전 관리 시스템', 'change_report',
  '<h2>수정 보고서: TASK-004</h2>
<p><strong>버전:</strong> v1.3.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>버전 관리 시스템 도입 (version.js)</li>
<li>모든 페이지 하단에 버전 표시</li>
<li>관리자 버전 이력 조회 페이지</li>
<li>보고서 체계 정비</li>
</ul>', 'AI_Cursor');

-- TASK-005: v1.4.0 사용자 관리 및 역할 배지
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-005', 'v1.4.0 사용자 관리 및 역할 배지', 'change_report',
  '<h2>수정 보고서: TASK-005</h2>
<p><strong>버전:</strong> v1.4.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>관리자 사용자 관리 페이지 (등록/수정/삭제/권한변경/비밀번호초기화)</li>
<li>역할별 통계 대시보드 (전체/관리자/부서관리자/교사/학생)</li>
<li>역할별 필터링 조회</li>
<li>모든 페이지 역할 배지 (이모지+텍스트+클릭 링크)</li>
</ul>', 'AI_Cursor');

-- TASK-006: v1.5.0 계정 등록 신청
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-006', 'v1.5.0 계정 등록 신청 및 부서 필수 선택', 'change_report',
  '<h2>수정 보고서: TASK-006</h2>
<p><strong>버전:</strong> v1.5.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>계정 등록 신청 페이지 (register.html)</li>
<li>역할 선택 (학생/교사/부서관리자) + 부서 필수 선택</li>
<li>아이디 중복/신청 중복 검증</li>
<li>관리자 사용자 관리에 신청 내역 섹션 추가</li>
<li>신청 승인 (자동 계정 생성) / 거부 (사유 입력) 기능</li>
<li>registration_requests 테이블 추가</li>
</ul>', 'AI_Cursor');

-- TASK-007: v1.6.0~v2.0.0 DB 보안 구조 전면 개선
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-007', 'v1.6.0~v2.0.0 DB 보안 구조 전면 개선 + 모바일 반응형', 'change_report',
  '<h2>수정 보고서: TASK-007</h2>
<p><strong>버전:</strong> v1.6.0 ~ v2.0.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>Supabase Auth 도입 - bcrypt 기반 안전한 비밀번호 관리</li>
<li>profiles 테이블 신설 - auth.users 연동</li>
<li>admin_users 직접 접근 완전 차단 (RLS USING false)</li>
<li>SECURITY DEFINER RPC 함수 도입</li>
<li>전체 테이블 RLS 정책 재설계</li>
<li>프론트엔드 전면 개편 - Supabase Auth signInWithPassword 기반 로그인</li>
<li>관리자 페이지 모바일 반응형 대폭 개선</li>
<li>로그 일괄 완료처리 기능</li>
</ul>', 'AI_Cursor');

-- TASK-008: v2.1.0 관리자 페이지 접근 제어
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-008', 'v2.1.0 관리자 페이지 접근 제어 보완 + UI 개선', 'change_report',
  '<h2>수정 보고서: TASK-008</h2>
<p><strong>버전:</strong> v2.1.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>initPage() 역할 체크 실패 시 역할별 기본 페이지로 리디렉트</li>
<li>CSS auth-ready 기반 콘텐츠 플래시 방지 (인증 전 페이지 내용 숨김)</li>
<li>미사용 requireAuth() 함수 완전 제거</li>
<li>부서 관리 화면 역할별 인원 분리 표시</li>
<li>관리자 관리 페이지에 admin + dept_manager 통합 표시 및 필터</li>
<li>admin 전용 상품 관리 페이지 신설</li>
<li>권한별 중복 페이지 규칙 문서화</li>
</ul>', 'AI_Cursor');

-- TASK-009: v2.2.0 레거시 관리자 로그인 제거
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-009', 'v2.2.0 레거시 관리자 로그인 제거 + 통합 로그인 단일화', 'change_report',
  '<h2>수정 보고서: TASK-009</h2>
<p><strong>버전:</strong> v2.2.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>메인 화면 톱니바퀴(관리자 진입점) 버튼 제거</li>
<li>admin/login.html 레거시 파일 삭제</li>
<li>전체 소스에서 admin/login.html 참조 제거</li>
<li>.admin-link 미사용 CSS 제거</li>
<li>README.md 프로젝트 구조 전면 갱신</li>
<li>로그인 진입점 login.html 단일화 완료</li>
</ul>', 'AI_Cursor');

-- TASK-010: v2.3.0 초기 비밀번호 변경 강제
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-010', 'v2.3.0 초기 비밀번호 변경 강제 + 학생 상점 인증 보호', 'change_report',
  '<h2>수정 보고서: TASK-010</h2>
<p><strong>버전:</strong> v2.3.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>initPage()에 isFirstLogin 강제 리디렉트 중앙화</li>
<li>초기 비밀번호 미변경 시 change-password.html로 강제 이동</li>
<li>login.html에서 기존 세션의 isFirstLogin도 change-password로 리디렉트</li>
<li>student/shop.html을 보호 페이지로 전환 (initPage 적용)</li>
<li>autoLogPageView()를 인증 후로 이동 (익명 로그 방지)</li>
</ul>', 'AI_Cursor');

-- TASK-011: v2.4.0 관리자 대시보드 개선
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-011', 'v2.4.0 관리자 대시보드 개선', 'change_report',
  '<h2>수정 보고서: TASK-011</h2>
<p><strong>버전:</strong> v2.4.0 | <strong>작업일:</strong> 2026-05-27</p>
<h3>주요 변경 사항</h3>
<ul>
<li>현재 시간 카드를 가입 대기자 수 카드로 변경 (클릭 시 사용자 관리 이동)</li>
<li>바로가기 영역 5개로 재구성: 사용자/부서/관리자/상점/달란트 관리</li>
<li>각 바로가기 항목에 이모지 추가</li>
<li>시계 관련 JS 코드 제거</li>
</ul>', 'AI_Cursor');

-- TASK-012: v2.5.0 관리자/부서관리자 메뉴 통합
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-012', 'v2.5.0 관리자/부서관리자 메뉴 통합', 'change_report',
  '<h2>수정 보고서: TASK-012</h2>
<p><strong>버전:</strong> v2.5.0 | <strong>작업일:</strong> 2026-05-27</p>
<h3>주요 변경 사항</h3>
<ul>
<li>manager/ 디렉토리 5개 페이지 삭제 (admin/으로 통합)</li>
<li>admin/talents.html 신규 생성 (학생+교사 달란트 통합 관리)</li>
<li>admin/ 전체 페이지 통합 네비게이션 적용 (data-role 기반)</li>
<li>dept_manager 로그인 시 admin/index.html로 리디렉트</li>
<li>admin/index.html 역할별 대시보드 분기</li>
<li>applyRoleNav() 함수 도입</li>
</ul>', 'AI_Cursor');

-- TASK-013: v3.0.0~v3.6.0 유형/권한 6단계 체계 전면 개편
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-013', 'v3.0.0~v3.6.0 유형/권한 6단계 체계 전면 개편', 'change_report',
  '<h2>수정 보고서: TASK-013</h2>
<p><strong>버전:</strong> v3.0.0 ~ v3.6.0 | <strong>작업일:</strong> 2026-05-27</p>
<h3>주요 변경 사항</h3>
<ul>
<li>profiles 테이블 확장: user_type(교사/학생) + permission_level(6단계) + is_super_admin</li>
<li>get_permission_rank() 헬퍼 함수 생성 (admin:100 ~ student:20)</li>
<li>RPC 함수 12개 전면 업데이트 (permission_level 기반 권한 체크)</li>
<li>전체 테이블 RLS 정책 업데이트</li>
<li>auth.js 코어 전면 개편: PERMISSION_RANK/LABELS/EMOJI/REDIRECT 체계</li>
<li>페이지 권한 관리 (admin/page-permissions.html)</li>
<li>달란트 지급 방식 개편 (talent_items 테이블, 항목 기반 지급)</li>
<li>페이지 구조 통합 + 네비게이션 개선</li>
<li>반 시스템 추가 (departments.class_count, profiles.class_number)</li>
</ul>', 'AI_Cursor');

-- TASK-014: v3.7.0 다중 기능 개선
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-014', 'v3.7.0 다중 기능 개선 및 UX 향상', 'change_report',
  '<h2>수정 보고서: TASK-014</h2>
<p><strong>버전:</strong> v3.7.0 | <strong>작업일:</strong> 2026-05-27</p>
<h3>주요 변경 사항</h3>
<ul>
<li>아이디 생성 시 한글 입력 제한</li>
<li>로그 페이지: 범위 삭제, 사용자 이름(아이디) 표시, 상세 팝업 추가</li>
<li>대시보드: 최근 이슈 로그 타이틀 + WARN 이상만 표시</li>
<li>네비게이션: CHO-Talents 타이틀 + 메인 페이지 링크 변경</li>
<li>사용자 관리: 마지막 로그인 표시</li>
<li>물품 관리: 수정 시 활성화/비활성화 토글 추가</li>
<li>보고서 페이지: 3초 타임아웃 안전장치 + 스텝별 진단 로그</li>
<li>로그인: 승인 대기/거부 계정 구분 메시지 (이모지 포함)</li>
</ul>', 'AI_Cursor');

-- TASK-015: v3.7.1~v3.7.2 보고서 버그 수정 + 로그/배지
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-015', 'v3.7.1~v3.7.2 보고서 버그 수정 + 로그 선택 삭제 + 가입대기 배지', 'change_report',
  '<h2>수정 보고서: TASK-015</h2>
<p><strong>버전:</strong> v3.7.1 ~ v3.7.2 | <strong>작업일:</strong> 2026-05-28</p>
<h3>주요 변경 사항</h3>
<ul>
<li>reports.html: TYPE_LABELS 변수명 충돌 해결 (전역 스코프 충돌 제거)</li>
<li>reports.html: colspan 불일치 수정, HTML Entity를 유니코드 이모지로 교체</li>
<li>reports.html: 보고서 등록 모달 + 선택 삭제 기능 추가</li>
<li>logs.html: 체크박스 + 선택 삭제 기능 추가</li>
<li>전체 admin 페이지(11개): 사용자 관리 네비게이션에 가입대기 배지 추가</li>
<li>activity-log.js: deleteLogsByIds(), getPendingRegistrationCount(), updatePendingBadge() 함수 추가</li>
</ul>', 'AI_Cursor');

-- TASK-016: v3.7.3 권한 기반 부서/사용자 관리 스코핑
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-016', 'v3.7.3 권한 기반 부서/사용자 관리 스코핑 + 교사 카운트 수정', 'change_report',
  '<h2>수정 보고서: TASK-016</h2>
<p><strong>버전:</strong> v3.7.3 | <strong>작업일:</strong> 2026-05-28</p>
<h3>주요 변경 사항</h3>
<ul>
<li>departments.html: 교사 수 카운트에 user_type=teacher 전체 포함</li>
<li>users.html/managers.html: 본인 권한보다 낮은 사용자만 관리 가능</li>
<li>users.html/managers.html: 전도사님 미만(부장 이하) 담당 부서 계정만 표시</li>
<li>departments.html: 부장 미만 담당 부서만 표시, 전도사님 미만 담당 부서만 관리</li>
<li>departments.html: 접근 권한 80에서 60으로 변경 (부서 담당 교사도 접근 가능)</li>
<li>admin 전체(11개): 부서 관리 nav data-min-perm 80에서 60으로 변경</li>
</ul>', 'AI_Cursor');

-- TASK-017: v3.7.4 가입 신청 권한별 조회/처리 조건
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-017', 'v3.7.4 가입 신청 권한별 조회/처리 조건 + 네비게이션 아이디 표시', 'change_report',
  '<h2>수정 보고서: TASK-017</h2>
<p><strong>버전:</strong> v3.7.4 | <strong>작업일:</strong> 2026-05-28</p>
<h3>주요 변경 사항</h3>
<ul>
<li>users.html: 관리자/전도사님 - 모든 부서 신청자 조회 + 전체 처리 가능</li>
<li>users.html: 부장 - 모든 부서 신청자 조회, 담당 부서만 처리 가능</li>
<li>users.html: 부서 담당 교사 - 담당 부서 신청자만 조회 + 처리 가능</li>
<li>auth.js: renderRoleBadge에 이름 (아이디) 형식으로 아이디 표시 추가</li>
</ul>', 'AI_Cursor');

-- TASK-018: v3.7.5 타인 아이디 숨김 + 부서 이동 관리 시스템
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-018', 'v3.7.5 타인 아이디 숨김 + 부서 이동 관리 시스템', 'change_report',
  '<h2>수정 보고서: TASK-018</h2>
<p><strong>버전:</strong> v3.7.5 | <strong>작업일:</strong> 2026-05-28</p>
<h3>주요 변경 사항</h3>
<ul>
<li>users/managers/departments/talents: 타인 아이디 숨김 (자기 아이디만 표시)</li>
<li>users.html: 부서 이동 버튼 추가 (하위 권한자만 이동 가능)</li>
<li>users.html: 관리자/전도사님 - 즉시 부서 이동 처리</li>
<li>users.html: 부장/부서담당교사 - 부서 이동 요청 생성 (승인 필요)</li>
<li>users.html: 부서 이동 신청 내역 섹션 + 승인/거부 기능</li>
<li>department_transfer_requests 테이블 SQL 파일 생성</li>
</ul>', 'AI_Cursor');

-- TASK-019: v3.7.6 보고서 한글 인코딩 수정
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-019', 'v3.7.6 보고서 한글 인코딩 수정 + 관리자 아이디 표시 예외', 'change_report',
  '<h2>수정 보고서: TASK-019</h2>
<p><strong>버전:</strong> v3.7.6 | <strong>작업일:</strong> 2026-05-28</p>
<h3>주요 변경 사항</h3>
<ul>
<li>전체 HTML 18개 파일 UTF-8 BOM 제거 (인코딩 깨짐 방지)</li>
<li>관리자(admin) 권한: 모든 페이지에서 타인 아이디 표시 가능</li>
<li>비관리자: 본인 아이디만 표시 유지</li>
</ul>', 'AI_Cursor');

-- TASK-020: v3.7.7 수정 모달 부서 변경 제거 + 보고서 데이터 수정
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-020', 'v3.7.7 수정 모달 부서 변경 제거 + 보고서 전체 등록', 'change_report',
  '<h2>수정 보고서: TASK-020</h2>
<p><strong>버전:</strong> v3.7.7 | <strong>작업일:</strong> 2026-05-28</p>
<h3>주요 변경 사항</h3>
<ul>
<li>users.html: 수정 모달에서 소속 부서/반 변경 비활성화 (부서 이동 기능으로 대체)</li>
<li>managers.html: 수정 모달에서 소속 부서 변경 비활성화</li>
<li>보고서 DB 한글 깨짐 데이터 전면 교체 (TASK-008~011 포함)</li>
<li>전체 작업 보고서 20건 일괄 등록 (TASK-001 ~ TASK-020)</li>
</ul>', 'AI_Cursor');

-- TASK-021: v3.8.0 슈퍼관리자 체계 + 네비게이션 개편 + 페이지 권한 관리
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-021', 'v3.8.0 슈퍼관리자 체계 + 네비게이션 개편 + 페이지 권한 관리 + UI 전면 개선', 'change_report',
  '<h2>수정 보고서: TASK-021</h2>
<p><strong>버전:</strong> v3.8.0 | <strong>작업일:</strong> 2026-05-28</p>
<h3>주요 변경 사항</h3>
<ul>
<li>슈퍼관리자(is_super_admin) 권한 체계 구현 - rank 110으로 관리자 상위 관리 가능</li>
<li>네비게이션 브랜드: CHO-Talents를 ⭐ 달란트 마을로 전체 통일</li>
<li>네비게이션: 내 달란트, 상품 구매, 페이지 접근, 페이지 기능 항목 추가</li>
<li>네비게이션 아이디 색상 가시성 개선 (흰색 → 검정색)</li>
<li>메인 페이지: 로그인/로그아웃 버튼 동적 전환</li>
<li>신규 페이지: 페이지 접근 관리 (page-access.html)</li>
<li>신규 페이지: 페이지 기능 관리 (page-features.html)</li>
<li>부서 관리: 관리자/부서관리자 열 제거, 헤더 간소화</li>
<li>권한 명칭: 부장 → 부장 교사 (전체 일괄 변경)</li>
<li>관리자 관리: 달란트/등록일 열, 비밀번호 초기화/삭제 버튼 제거</li>
<li>달란트 관리: 잔여/사용/누적 달란트 3열 + 상세 통계 모달 추가</li>
<li>달란트 관리: 수정/삭제 버튼 제거, 달란트 → 달란트 지급 명칭 변경</li>
</ul>', 'AI_Cursor');
