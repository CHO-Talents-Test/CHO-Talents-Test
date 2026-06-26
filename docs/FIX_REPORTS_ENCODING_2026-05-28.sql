-- ============================================================
-- reports 테이블 한글 깨짐 복구 SQL
-- 대상: TASK-008, TASK-009, TASK-010, TASK-011
-- 실행 위치: Supabase Dashboard > SQL Editor
--
-- 목적:
-- 1. 현재 reports 테이블을 백업한다.
-- 2. 스크린샷처럼 task_title/content가 ???로 저장된 행만 정상 한글로 갱신한다.
-- 3. security_report 유형이 있는 기존 TASK-010 행도 함께 복구한다.
-- ============================================================

BEGIN;

-- 복구 전 원본 백업. 같은 날 여러 번 실행해도 최초 백업은 유지됩니다.
CREATE TABLE IF NOT EXISTS reports_backup_20260528_encoding AS
SELECT *
FROM reports;

-- TASK-008
UPDATE reports
SET
  task_title = '관리자 페이지 접근 제어 보완 + UI 개선',
  content = $task008$
<h2>수정 보고서: TASK-008</h2>
<p><strong>버전:</strong> v2.1.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>initPage() 역할 체크 실패 시 역할별 기본 페이지로 리디렉트</li>
<li>CSS auth-ready 기반 콘텐츠 플래시 방지</li>
<li>미사용 requireAuth() 함수 제거</li>
<li>부서 관리 화면 역할별 인원 분리 표시</li>
<li>관리자 관리 페이지에 admin + dept_manager 통합 표시 및 필터</li>
<li>admin 전용 상품 관리 페이지 신설</li>
<li>권한별 중복 페이지 규칙 문서화</li>
</ul>
$task008$
WHERE task_id = 'TASK-008'
  AND report_type = 'change_report';

-- TASK-009
UPDATE reports
SET
  task_title = '레거시 관리자 로그인 제거 + 통합 로그인 단일화',
  content = $task009$
<h2>수정 보고서: TASK-009</h2>
<p><strong>버전:</strong> v2.2.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>메인 화면 톱니바퀴 관리자 진입점 버튼 제거</li>
<li>admin/login.html 레거시 파일 삭제</li>
<li>전체 소스에서 admin/login.html 참조 제거</li>
<li>.admin-link 미사용 CSS 제거</li>
<li>README.md 프로젝트 구조 갱신</li>
<li>로그인 진입점 login.html 단일화</li>
</ul>
$task009$
WHERE task_id = 'TASK-009'
  AND report_type = 'change_report';

-- TASK-010
UPDATE reports
SET
  task_title = '초기 비밀번호 변경 강제 + 학생 상점 인증 보호',
  content = $task010$
<h2>보안 보고서: TASK-010</h2>
<p><strong>버전:</strong> v2.3.0 | <strong>작업일:</strong> 2026-05-26</p>
<h3>주요 변경 사항</h3>
<ul>
<li>initPage()에 최초 로그인 비밀번호 변경 강제 리디렉트 로직 추가</li>
<li>초기 비밀번호 미변경 시 change-password.html로 강제 이동</li>
<li>login.html에서 기존 세션의 isFirstLogin 상태 처리 보완</li>
<li>student/shop.html 보호 페이지 전환</li>
<li>autoLogPageView()를 인증 완료 이후 실행하도록 조정</li>
</ul>
<h3>검증 결과</h3>
<ul>
<li>모든 역할에서 isFirstLogin 상태일 때 비밀번호 변경 화면으로 이동</li>
<li>change-password.html 리디렉트 루프 없음</li>
<li>권한 체크보다 최초 로그인 강제 로직이 먼저 실행됨</li>
<li>URL 직접 입력으로 최초 비밀번호 변경 절차 우회 불가</li>
</ul>
$task010$
WHERE task_id = 'TASK-010'
  AND report_type IN ('security_report', 'change_report');

-- TASK-011
UPDATE reports
SET
  task_title = '관리자 대시보드 개선',
  content = $task011$
<h2>수정 보고서: TASK-011</h2>
<p><strong>버전:</strong> v2.4.0 | <strong>작업일:</strong> 2026-05-27</p>
<h3>주요 변경 사항</h3>
<ul>
<li>현재 시간 카드를 가입 대기자 수 카드로 변경</li>
<li>가입 대기자 카드 클릭 시 사용자 관리 페이지로 이동</li>
<li>바로가기 영역을 사용자, 부서, 관리자, 상점, 달란트 관리로 재구성</li>
<li>registration_requests pending 건수 조회 추가</li>
<li>시계 관련 JS 코드 제거</li>
</ul>
$task011$
WHERE task_id = 'TASK-011'
  AND report_type = 'change_report';

COMMIT;

-- 실행 후 점검용: 결과가 0건이면 task_title/content의 ??? 데이터가 제거된 상태입니다.
SELECT id, task_id, report_type, task_title
FROM reports
WHERE task_title LIKE '%???%'
   OR content LIKE '%???%'
ORDER BY task_id, report_type;
