# TASK-091 변경 보고 — 운영 조회·상품 검증·가이드 권한 정비

**버전:** v3.89.0  
**변경일:** 2026-07-16

## 변경 내용

- 미확인 ERROR+ 로그의 행 전체 클릭으로 상세 모달을 열도록 개선했다.
- 서비스 통계에 수집 실행 이력의 오류 배열을 해석한 최근 수집 실패 목록을 추가했다.
- 사용자 통계에 학생/교사 필터와 조건별 세로 막대 그래프를 추가했고, 집계와 상세 RPC에 동일한 `p_user_type` 필터를 적용했다.
- 상품 등록에서 상품명, 대상, 카테고리, 썸네일 이미지, 구매 URL을 필수로 검증하고, 교사/학생 목록별 활성 상태 필터를 추가했다.
- 상점 상품 카드는 이미지를 자르지 않고 전체가 보이도록 변경했으며 상세 모달의 표시 방식은 유지했다.
- 역할별 가이드 전환기를 공통 최소 등급 맵으로 제어해 누적 표시 규칙을 통일하고, 관리자 가이드를 관리자(100+) 전용으로 변경했다.

## DB 적용 사항

`docs/TASK-091_user_stats_filters.sql`은 기존 3/5 인자 통계 RPC를 교체해 다음 두 RPC에 `p_user_type`을 추가한다.

- `get_user_login_statistics(p_start_date, p_end_date, p_dept_id, p_user_type)`
- `get_user_login_stat_detail(p_view_type, p_view_key, p_start_date, p_end_date, p_dept_id, p_user_type)`

두 RPC는 `student`, `teacher`, `NULL(전체)`만 허용하며, 관리자(100+) 권한 검증을 유지한다.

## 유의 사항

- SQL 파일은 외부 DB에 자동 실행하지 않았다. 운영 배포 시 TASK-081/TASK-084 다음에 적용한다.
- 서비스 수집 실패 목록은 Slack 발송 이력이 아니라 수집 실행 이력의 진단 정보다.

