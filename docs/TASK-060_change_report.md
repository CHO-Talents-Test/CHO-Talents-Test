# TASK-060 변경 보고서: 달란트 예외 지급 및 반환 이력 관리

- 버전: v3.60.0
- 작성일: 2026-07-02
- 기준 브랜치: develop 작업본

## 1. 변경분 분석

현재 작업본의 핵심 변경은 달란트 항목의 주간 1회 지급 제한을 유지하면서, 전도사님(90+) 이상에게만 사유 기반 예외 재지급 경로를 추가한 것이다.

주요 변경 범위:

| 영역 | 내용 |
|---|---|
| DB/RPC | `talent_transactions.override_week_limit`, `override_reason` 컬럼 추가. `give_talent` RPC에 `p_override_week_limit`, `p_override_reason` 파라미터와 권한/사유 검증 추가 |
| 달란트 관리 | `admin/talents.html`에 예외 지급 체크박스와 사유 입력 추가. 이미 이번 주 지급된 항목도 예외 모드에서 재선택 가능 |
| 이력 조회 | `admin/talent-adjustments.html` 신규 추가. 예외 지급과 반환 이력을 분리 조회 |
| 사용자 표시 | `my-talents.html`과 관리자 상세 이력에서 예외 지급을 별도 배지와 요약으로 표시 |
| 항목 관리 | `admin/talent-items.html`에 총 지급, 이번 주 지급, 예외 지급 통계 표시 |
| 권한/네비 | `js/nav.js`, `js/auth.js`, `admin/page-access.html`, `admin/page-features.html`, `index.html`에 신규 페이지 연결 |
| 문서 | README, 사용자 안내서, 아키텍처 문서, 권한/로그/작업 이력 룰, 역할별 가이드, 작업 가드레일 동기화 |

## 2. 권한 기준

| 기능 | 권한 |
|---|---:|
| 일반 항목 지급 | 40+ |
| 예외 지급 실행 | 90+ |
| 예외 지급/반환 이력 조회 | 60+ |
| 반환 처리 | 80+ |
| 수동 적립 입력 | 100+ |

부서 담당 교사는 `admin/talent-adjustments.html`에서 담당 부서 이력만 조회하고, 부장 교사 이상은 전체 부서 이력을 조회한다.

## 3. 테스트 시나리오

| 항목 | 기대 결과 |
|---|---|
| 90등급 미만 사용자가 달란트 지급 모달을 열기 | 예외 지급 영역이 보이지 않는다 |
| 90등급 이상 사용자가 예외 지급 체크 후 사유 없이 확정 | 사유 입력 안내가 표시되고 지급되지 않는다 |
| 90등급 이상 사용자가 이미 지급된 항목을 사유와 함께 예외 지급 | `override_week_limit=true`, `override_reason` 포함 이력이 생성된다 |
| 내 달란트 조회 | 예외 지급은 노란색 예외 배지와 예외 달란트 요약에 표시된다 |
| 예외 지급/반환 관리 조회 | 예외 지급과 반환이 분리 표시되고 권한별 부서 스코핑이 적용된다 |
| 구버전 DB 스키마 | `override_week_limit` 선택 실패 시 기존 컬럼 조회로 폴백한다 |

## 4. 검증 결과

정적 검증 기준:

- HTML/JS 문법 검증 대상: `admin/talents.html`, `admin/talent-items.html`, `admin/talent-adjustments.html`, `my-talents.html`, 공통 JS
- 문서 동기화 대상: `README.md`, `docs/SITE_USER_GUIDE.md`, `docs/PROJECT_ARCHITECTURE_FLOW.md`, `docs/page-permission-rules.html`, 운영 룰/역할별 가이드
- 버전 기준: `js/version.js` v3.60.0, HTML 캐시 버스팅 `?v=3.60.0`

실 DB 적용과 브라우저 실사용 테스트는 별도 운영 환경에서 `docs/INITIAL_DATABASE_SETUP.sql` 또는 보강 SQL 적용 후 확인한다.
