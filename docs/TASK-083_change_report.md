# TASK-083 변경 보고서: 달란트 적립 카드 동적 생성과 이모지 관리

## 변경 요약

| 구분 | 변경 전 | 변경 후 |
|---|---|---|
| 적립 안내 카드 | HTML에 고정된 카드만 존재하고 이름/별칭 매칭 항목만 갱신 | 활성 `talent_items`의 각 행을 학생/교사별 카드로 직접 생성 |
| 새 항목 표시 | 새 이름에 대응하는 고정 카드가 없으면 미표시 | 저장 후 활성 상태이면 다음 적립 안내 로드부터 자동 표시 |
| 이모지 | HTML에만 고정 | `talent_items.emoji`에 저장하고 관리 목록·안내 카드에 공통 표시 |
| 기존 운영 DB | 이모지 컬럼 없음 | `TASK-083_talent_item_emoji.sql`로 컬럼, 기본값, 기존 항목 보정 제공 |

## 수정 파일

- `earn-talents.html`
- `admin/talent-items.html`
- `docs/INITIAL_DATABASE_SETUP.sql`
- `docs/TASK-083_talent_item_emoji.sql`
- `js/version.js`
- `README.md`, `docs/SITE_USER_GUIDE.md`, `docs/PROJECT_ARCHITECTURE_FLOW.md`, `docs/CONFIGURATION.md`, `docs/INITIAL_DATABASE_SETUP.md`
- `guide.html`, `admin-guide.html`

## 운영 적용 순서

1. Supabase SQL Editor에서 `docs/TASK-083_talent_item_emoji.sql`을 실행한다.
2. 수정된 정적 파일을 배포한다.
3. `관리 > 달란트 항목 관리`에서 항목의 이모지, 규칙, 설명, 활성 상태를 확인한다.
4. `달란트 적립` 페이지를 새로고침해 학생/교사 탭별 카드가 정렬 순서대로 표시되는지 확인한다.
