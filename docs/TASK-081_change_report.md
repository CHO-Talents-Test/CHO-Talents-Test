# TASK-081 변경 보고 — 사용자 로그인 통계

## 결과

- 성공 로그인 이력을 `user_login_history`에 별도 저장하도록 추가했다.
- `관리 > 사용자 통계`를 관리 메뉴의 마지막 항목으로 추가했다. 관리자(100+)는 KST 기준 날짜·요일·시간·부서·사용자별 통계를 기간·부서 필터와 함께 조회할 수 있다.
- 로그인 원본 이력은 화면에서 직접 노출하지 않고, RLS 및 관리자 전용 집계 RPC로 보호한다.
- 작업 이력 및 구매 통계의 요청한 그리드 행 클릭 상세 모달과 메인 즐겨찾기 20개 제한을 반영했다.

## 주요 파일

| 영역 | 변경 파일 |
|---|---|
| DB | `docs/TASK-081_user_login_statistics.sql` |
| 로그인 기록 | `js/auth.js` |
| 통계 UI | `admin/user-stats.html`, `js/nav.js` |
| 권한/바로가기 | `admin/page-access.html`, `admin/page-features.html`, `index.html` |
| 상세 모달 | `admin/audit.html`, `admin/purchase-stats.html` |
| 설치 | `scripts/install-supabase-database.ps1`, `scripts/install-supabase-database.sh` |
| 문서 | README, 사용자 안내서, 아키텍처 문서, 역할별 가이드, 운영 룰, 설치/구성 문서 |

## 운영 주의사항

- 운영 적용 전 `docs/TASK-081_user_login_statistics.sql`을 반드시 실행한다.
- 이력 기록 실패는 정상 로그인 자체를 차단하지 않으며, 콘솔 경고로만 남긴다.
- 로그인 성공 이력·사용자 통계는 Slack 알림 이벤트가 아니다.
