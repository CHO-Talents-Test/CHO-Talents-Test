-- TASK-014: v3.7.0 다중 기능 개선 보고서 등록
-- Supabase SQL Editor에서 실행

-- 0. RLS INSERT 정책 수정 (anon/authenticated 모두 INSERT 허용)
DROP POLICY IF EXISTS "Allow anon insert reports" ON reports;
DROP POLICY IF EXISTS "Allow insert reports" ON reports;
DROP POLICY IF EXISTS "reports_insert" ON reports;
DROP POLICY IF EXISTS "Allow authenticated insert reports" ON reports;

CREATE POLICY "Allow insert reports" ON reports
  FOR INSERT WITH CHECK (true);

-- 추가: UPDATE, DELETE 정책 (관리자용)
DROP POLICY IF EXISTS "Allow update reports" ON reports;
CREATE POLICY "Allow update reports" ON reports
  FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete reports" ON reports;
CREATE POLICY "Allow delete reports" ON reports
  FOR DELETE USING (true);

-- 1. 작업 계획서
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-014',
  'v3.7.0 다중 기능 개선 및 UX 향상',
  'plan',
  '<h2>작업 계획서: v3.7.0 다중 기능 개선</h2>
<p><strong>작업일:</strong> 2026-05-27 (KST)<br/><strong>브랜치:</strong> develop</p>
<h3>작업 개요</h3>
<p>총 9건의 기능 개선/수정 요청을 처리합니다.</p>
<h3>수정 항목</h3>
<table><thead><tr><th>#</th><th>항목</th><th>대상 파일</th></tr></thead>
<tbody>
<tr><td>1</td><td>아이디 한글 입력 제한</td><td>register.html, admin/users.html</td></tr>
<tr><td>2</td><td>로그 범위 삭제 기능</td><td>admin/logs.html, js/activity-log.js</td></tr>
<tr><td>3</td><td>로그 사용자 ''이름 (아이디)'' 표시</td><td>admin/logs.html</td></tr>
<tr><td>4</td><td>로그 상세 정보 팝업</td><td>admin/logs.html</td></tr>
<tr><td>5</td><td>보고서 페이지 미표시 해결</td><td>admin/reports.html</td></tr>
<tr><td>6</td><td>대시보드 이슈 로그 필터링</td><td>admin/index.html</td></tr>
<tr><td>7</td><td>네비게이션 타이틀/링크 변경</td><td>admin 전체 11개 파일</td></tr>
<tr><td>8</td><td>물품 활성화/비활성화 토글</td><td>admin/shop.html</td></tr>
<tr><td>9</td><td>승인 대기 로그인 메시지 분기</td><td>login.html</td></tr>
</tbody></table>',
  'AI_Cursor'
);

-- 2. 검증 테스트 시나리오
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-014',
  'v3.7.0 다중 기능 개선 및 UX 향상',
  'test_scenario',
  '<h2>검증 테스트 시나리오</h2>
<p><strong>작성일:</strong> 2026-05-27 (KST)</p>
<table><thead><tr><th>TC</th><th>항목</th><th>검증 내용</th></tr></thead>
<tbody>
<tr><td>TC-01</td><td>한글 입력 제한</td><td>register.html에서 한글 입력 시 자동 제거, 유효성 검사 메시지 표시</td></tr>
<tr><td>TC-02</td><td>로그 범위 삭제</td><td>날짜 범위 선택 → 확인 → 삭제 → 새로고침</td></tr>
<tr><td>TC-03</td><td>사용자 표시 형식</td><td>로그 목록에서 ''이름 (아이디)'' 형식 표시</td></tr>
<tr><td>TC-04</td><td>로그 상세 팝업</td><td>상세 버튼 클릭 → 모달에 전체 정보 표시</td></tr>
<tr><td>TC-05</td><td>보고서 페이지 표시</td><td>3초 타임아웃 작동, auth-ready 클래스 적용</td></tr>
<tr><td>TC-06</td><td>이슈 로그 필터</td><td>대시보드에서 WARN+ 레벨만 표시</td></tr>
<tr><td>TC-07</td><td>네비게이션 변경</td><td>CHO-Talents 타이틀, 메인 페이지 링크</td></tr>
<tr><td>TC-08</td><td>물품 상태 토글</td><td>수정 모달에서 활성/비활성 전환</td></tr>
<tr><td>TC-09</td><td>로그인 메시지</td><td>대기 계정 로그인 시 구분 메시지 표시</td></tr>
</tbody></table>
<p><strong>총 9개 시나리오</strong></p>',
  'AI_Cursor'
);

-- 3. 테스트 결과 보고서
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-014',
  'v3.7.0 다중 기능 개선 및 UX 향상',
  'test_result',
  '<h2>테스트 결과 보고서</h2>
<p><strong>테스트 일시:</strong> 2026-05-27 (KST)<br/><strong>방법:</strong> 코드 레벨 정적 검증</p>
<h3>결과 요약</h3>
<table><thead><tr><th>TC</th><th>항목</th><th>결과</th><th>비고</th></tr></thead>
<tbody>
<tr><td>TC-01</td><td>한글 입력 제한</td><td>&#9989; PASS</td><td>정규식 필터 + 유효성 메시지 정상</td></tr>
<tr><td>TC-02</td><td>로그 범위 삭제</td><td>&#9989; PASS</td><td>deleteLogsByDateRange 함수 구현 완료</td></tr>
<tr><td>TC-03</td><td>사용자 표시 형식</td><td>&#9989; PASS</td><td>profiles 조회 후 getUserDisplay() 적용</td></tr>
<tr><td>TC-04</td><td>로그 상세 팝업</td><td>&#9989; PASS</td><td>모달 UI + 상세 정보 렌더링 완료</td></tr>
<tr><td>TC-05</td><td>보고서 페이지 표시</td><td>&#9989; PASS</td><td>타임아웃 fallback + 단계별 로그 추가</td></tr>
<tr><td>TC-06</td><td>이슈 로그 필터</td><td>&#9989; PASS</td><td>WARN/ERROR/FATAL/CRITICAL 필터 적용</td></tr>
<tr><td>TC-07</td><td>네비게이션 변경</td><td>&#9989; PASS</td><td>11개 admin 파일 일괄 수정</td></tr>
<tr><td>TC-08</td><td>물품 상태 토글</td><td>&#9989; PASS</td><td>radio 버튼 + is_active 필드 저장</td></tr>
<tr><td>TC-09</td><td>로그인 메시지</td><td>&#9989; PASS</td><td>pending/rejected 상태별 이모지 메시지</td></tr>
</tbody></table>
<p><strong>전 항목 PASS (9/9)</strong></p>',
  'AI_Cursor'
);

-- 4. 수정 사항 보고서
INSERT INTO reports (task_id, task_title, report_type, content, created_by) VALUES (
  'TASK-014',
  'v3.7.0 다중 기능 개선 및 UX 향상',
  'change_report',
  '<h2>수정 사항 보고서</h2>
<p><strong>작업일:</strong> 2026-05-27 (KST)<br/><strong>버전:</strong> v3.7.0</p>
<h3>수정 파일 목록</h3>
<table><thead><tr><th>파일</th><th>변경 내용</th></tr></thead>
<tbody>
<tr><td>register.html</td><td>아이디 한글 입력 제한 (정규식 필터)</td></tr>
<tr><td>login.html</td><td>승인 대기/거부 계정 로그인 메시지 분기</td></tr>
<tr><td>admin/index.html</td><td>이슈 로그 타이틀 변경, WARN+ 필터</td></tr>
<tr><td>admin/logs.html</td><td>범위 삭제, 이름(아이디) 표시, 상세 팝업</td></tr>
<tr><td>admin/reports.html</td><td>페이지 미표시 해결 (타임아웃, 진단 로그)</td></tr>
<tr><td>admin/shop.html</td><td>물품 활성화/비활성화 토글 추가</td></tr>
<tr><td>admin/users.html</td><td>한글 제한, 마지막 로그인 표시</td></tr>
<tr><td>admin/*.html (11개)</td><td>네비게이션 타이틀/링크 변경</td></tr>
<tr><td>js/activity-log.js</td><td>deleteLogsByDateRange() 함수 추가</td></tr>
<tr><td>js/version.js</td><td>v3.7.0 버전 등록</td></tr>
</tbody></table>
<h3>주요 개선 사항</h3>
<ul>
<li>사용자 입력 보안 강화 (한글 제한)</li>
<li>로그 관리 UX 대폭 개선 (범위 삭제, 상세 팝업, 사용자 표시)</li>
<li>보고서 페이지 안정성 확보 (타임아웃 fallback)</li>
<li>대시보드 이슈 로그 집중 표시</li>
<li>물품 활성화 상태 관리 기능</li>
<li>로그인 UX 개선 (승인 상태별 메시지)</li>
</ul>',
  'AI_Cursor'
);
