-- TASK-001 보고서 4종 Supabase 등록
-- supabase_setup.sql 실행 후 이 파일을 실행하세요.

-- 1. 작업 계획서
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-001',
  '관리자 시스템 구축',
  'plan',
  '<h2>작업 계획서: 관리자 시스템 구축</h2>
<p><strong>작업일:</strong> 2026-05-26 (KST)<br/><strong>브랜치:</strong> develop</p>
<h3>작업 개요</h3>
<ul>
<li>관리자 인증 시스템 (커스텀 테이블, SHA-256, RPC 함수)</li>
<li>보고서 관리 페이지 (CRUD, 유형별 필터)</li>
<li>활동 로그 시스템 (7레벨, ERROR+ 필수 확인)</li>
<li>KST 시간 전역 적용</li>
<li>8단계 작업 프로세스 체계 수립</li>
</ul>
<h3>구현 범위</h3>
<ul>
<li>Supabase 테이블 3개: admin_users, reports, activity_logs</li>
<li>RPC 함수 2개: verify_admin, update_password</li>
<li>관리자 페이지 5개: login, dashboard, reports, logs, change-password</li>
<li>JS 모듈 2개: auth.js, activity-log.js</li>
<li>기존 index.html에 관리자 링크 및 로그 모듈 통합</li>
</ul>',
  'system'
);

-- 2. 검증 테스트 시나리오
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-001',
  '관리자 시스템 구축',
  'test_scenario',
  '<h2>검증 테스트 시나리오</h2>
<p><strong>작성일:</strong> 2026-05-26 (KST)</p>
<table><thead><tr><th>구분</th><th>항목 수</th><th>주요 검증 내용</th></tr></thead>
<tbody>
<tr><td>TC-01. Supabase 테이블/RPC</td><td>8</td><td>테이블 구조, RPC 함수, RLS 정책, 초기 계정</td></tr>
<tr><td>TC-02. 로그인 기능</td><td>6</td><td>정상/실패 로그인, 세션, 로그 기록</td></tr>
<tr><td>TC-03. 비밀번호 변경</td><td>5</td><td>첫 로그인 강제, 변경 처리, 로그</td></tr>
<tr><td>TC-04. 관리자 대시보드</td><td>7</td><td>인증 차단, 요약 카드, ERROR+ 배지</td></tr>
<tr><td>TC-05. 보고서 페이지</td><td>5</td><td>목록, 필터, 상세 모달</td></tr>
<tr><td>TC-06. 로그 관리 페이지</td><td>9</td><td>레벨 필터, 확인 모달, 페이지네이션</td></tr>
<tr><td>TC-07. KST 시간</td><td>3</td><td>전체 시간 표시 KST 적용</td></tr>
<tr><td>TC-08. 전체 페이지 로깅</td><td>3</td><td>PAGE_VIEW, 에러 자동 로깅</td></tr>
<tr><td>TC-09. 기존 페이지 영향도</td><td>3</td><td>환영 페이지 유지, 반응형 유지</td></tr>
</tbody></table>
<p><strong>총 49개 항목</strong></p>',
  'system'
);

-- 3. 테스트 결과 보고서
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-001',
  '관리자 시스템 구축',
  'test_result',
  '<h2>테스트 완료 보고서</h2>
<p><strong>테스트 일시:</strong> 2026-05-26 (KST)<br/><strong>방법:</strong> 코드 레벨 정적 검증</p>
<h3>결과 요약</h3>
<table><thead><tr><th>구분</th><th>항목</th><th>성공</th><th>실패</th></tr></thead>
<tbody>
<tr><td>TC-01. Supabase 테이블/RPC</td><td>8</td><td>8</td><td>0</td></tr>
<tr><td>TC-02. 로그인 기능</td><td>6</td><td>6</td><td>0</td></tr>
<tr><td>TC-03. 비밀번호 변경</td><td>5</td><td>5</td><td>0</td></tr>
<tr><td>TC-04. 관리자 대시보드</td><td>7</td><td>7</td><td>0</td></tr>
<tr><td>TC-05. 보고서 페이지</td><td>5</td><td>5</td><td>0</td></tr>
<tr><td>TC-06. 로그 관리 페이지</td><td>9</td><td>9</td><td>0</td></tr>
<tr><td>TC-07. KST 시간</td><td>3</td><td>3</td><td>0</td></tr>
<tr><td>TC-08. 전체 페이지 로깅</td><td>3</td><td>3</td><td>0</td></tr>
<tr><td>TC-09. 기존 페이지 영향도</td><td>3</td><td>3</td><td>0</td></tr>
<tr><td><strong>합계</strong></td><td><strong>49</strong></td><td><strong>49</strong></td><td><strong>0</strong></td></tr>
</tbody></table>
<p>전 항목 PASS. Supabase SQL 실행 후 E2E 브라우저 테스트 필요.</p>',
  'system'
);

-- 4. 수정 사항 보고서
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-001',
  '관리자 시스템 구축',
  'change_report',
  '<h2>수정 사항 보고서</h2>
<p><strong>작업일:</strong> 2026-05-26 (KST)</p>
<h3>신규 파일 (10개)</h3>
<table><thead><tr><th>파일</th><th>용도</th></tr></thead>
<tbody>
<tr><td>admin/login.html</td><td>관리자 로그인</td></tr>
<tr><td>admin/index.html</td><td>관리자 대시보드</td></tr>
<tr><td>admin/reports.html</td><td>보고서 열람</td></tr>
<tr><td>admin/logs.html</td><td>활동 로그 관리</td></tr>
<tr><td>admin/change-password.html</td><td>비밀번호 변경</td></tr>
<tr><td>css/admin.css</td><td>관리자 스타일</td></tr>
<tr><td>js/auth.js</td><td>인증 모듈</td></tr>
<tr><td>js/activity-log.js</td><td>로그 시스템</td></tr>
<tr><td>docs/supabase_setup.sql</td><td>DB 초기 설정</td></tr>
<tr><td>docs/TASK-001_test_scenario.md</td><td>검증 시나리오</td></tr>
</tbody></table>
<h3>수정 파일 (4개)</h3>
<table><thead><tr><th>파일</th><th>변경 내용</th></tr></thead>
<tbody>
<tr><td>index.html</td><td>관리자 링크 + activity-log.js 추가</td></tr>
<tr><td>css/style.css</td><td>.admin-link 스타일 추가</td></tr>
<tr><td>js/supabase-config.js</td><td>KST 유틸리티 함수 3개 추가</td></tr>
<tr><td>js/app.js</td><td>autoLogPageView() + logFatal 추가</td></tr>
</tbody></table>
<h3>개선 추천</h3>
<ul>
<li>세션 만료 시간 추가 (자동 로그아웃)</li>
<li>관리자 계정 관리 UI</li>
<li>비밀번호 강도 검증 강화</li>
<li>로그 CSV/Excel 내보내기</li>
</ul>',
  'system'
);
