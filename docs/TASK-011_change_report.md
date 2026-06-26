# TASK-011 수정 사항 보고서: 관리자 대시보드 개선

**작성일**: 2026-05-27
**버전**: v2.4.0
**작성자**: AI_Cursor

---

## 1. 수정 파일

| 파일 | 변경 유형 |
|------|-----------|
| `admin/index.html` | 수정 (HTML + JS) |
| `js/version.js` | 수정 (버전 업데이트) |
| `docs/TASK-011_test_scenario.md` | 신규 |
| `docs/TASK-011_test_report.md` | 신규 |
| `docs/TASK-011_change_report.md` | 신규 (현재 문서) |

---

## 2. 변경 내용

### 2-1. 통계 카드: "현재 시간" -> "가입 대기자"

**변경 전:**
- 4번째 카드: "현재 시간 (KST)" - 1초 간격 시계 표시
- JS: `updateClock()` 함수 + `setInterval(updateClock, 1000)`

**변경 후:**
- 4번째 카드: "📝 가입 대기자" - registration_requests pending 건수 표시
- `<a href="users.html">` 태그로 클릭 시 사용자 관리 페이지 이동
- JS: `registration_requests` 테이블 pending count 조회 추가
- 시계 관련 코드 완전 제거

### 2-2. 바로가기 영역: 4개 -> 5개 재구성

**변경 전 (4개):**
1. 🏢 부서 관리 -> departments.html
2. 👤 관리자 관리 -> managers.html
3. 📦 상품 관리 -> products.html
4. 📊 보고서 -> reports.html

**변경 후 (5개):**
1. 👥 사용자 관리 -> users.html
2. 🏢 부서 관리 -> departments.html
3. 👑 관리자 관리 -> managers.html
4. 🛒 상점 관리 -> shop.html
5. 💰 달란트 관리 -> ../manager/students.html

### 2-3. JS loadDashboard() 변경

- `Promise.all`에 `registration_requests` pending count 조회 추가
- `pendingCount` element에 건수 표시 추가
- 시계 관련 코드(`updateClock`, `setInterval`) 제거

---

## 3. 영향 범위

- `admin/index.html` 단일 파일 수정
- 다른 페이지 영향 없음
- DB 스키마 변경 없음
- RPC/RLS 변경 없음

---

## 4. 개선 추천 사항

- 가입 대기자가 있을 때 카드에 강조 스타일(애니메이션 또는 색상 변경) 추가 검토
- 달란트 관리 링크의 관리자 전용 통합 페이지 신규 생성 검토 (현재는 부서관리자 페이지 공유)
