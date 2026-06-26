# TASK-030: v3.13.0 작업 완료 보고서

## 작업 개요
- **버전:** v3.13.0
- **작업명:** QR 달란트 시스템 + 관리 개선 + 통계 개편
- **완료일:** 2026-06-01
- **작업자:** AI_Cursor

---

## 변경 사항 요약

### 1. QR 달란트 수령 시스템 (신규)

#### 1-1. talent-receive.html (신규)
- 교사 전용 QR 코드 스캔 페이지
- html5-qrcode 라이브러리로 카메라 QR 스캔
- 다단계 유효성 검증: 키 확인 → 유효기간 → GPS 위치 → 중복 체크
- Haversine 공식 기반 GPS 거리 계산
- 스캔 결과 실시간 표시 + 오늘 수령 내역

#### 1-2. admin/talent-qr.html (신규)
- 전도사님 이상(rank 90+) QR 코드 관리 페이지
- 달란트 항목별 QR 코드 생성/재생성
- 유효기간 설정 (상시 또는 시작~종료)
- 위치 제한 (Kakao Maps API 주소→좌표 변환 + 반경 설정)
- QR 이미지 보기/다운로드/인쇄
- QR 비활성화 + 스캔 이력 조회

### 2. DB 변경

| 테이블 | 작업 | 비고 |
|--------|------|------|
| `talent_qr_codes` | CREATE | 11개 컬럼, RLS (SELECT: auth, CUD: rank 90+) |
| `talent_qr_scans` | CREATE | 9개 컬럼, RLS (SELECT: auth, INSERT: auth) |

### 3. 달란트 관리 개선 (admin/talents.html)

#### 3-1. 달란트 취소 기능
- 전도사님 이상 권한자에게 "취소" 버튼 표시
- use_talent RPC로 금액 차감, "취소:" 접두사 설명
- TALENT_CANCEL 감사 로그 기록

#### 3-2. 출석 명칭 통일 + 중복 방지
- 퀵 버튼과 모달 모두 같은 talent_item_id 참조
- _attendanceGivenToday Set으로 중복 지급 차단

#### 3-3. 지급일 지정 (rank 90+)
- 달란트 지급 모달에 날짜 선택 필드 추가
- 과거 날짜 선택 시 created_at 업데이트

### 4. 구매 취소 (my-orders.html)
- requested 상태 주문에 "취소" 버튼 추가
- 취소 시 status를 'cancelled'로 변경
- pending_talent 차감으로 보류 달란트 복원
- cancelled 상태 표시 (빨간색 ❌)

### 5. 통계 페이지 개편 (admin/talent-stats.html)
- 컨테이너 max-width 제거 → 전폭 레이아웃
- 날짜 범위 필터: 직접 입력 + 프리셋(이번 주/달/학기/전체)
- 요약 카드: 모든 뷰(전체/부서별/개인별)에 동일 표시
- 학생/교사 유형 구분 통계 (건수 + 금액 분리)
- 개인별 뷰에 유형 배지 표시

### 6. 네비게이션 업데이트
- "달란트 수령" 메뉴 추가 (교사 이상)
- "달란트 QR 관리" 메뉴 추가 (rank 90+)
- 전체 22+ HTML 파일 네비게이션 통일

### 7. 감사 로그 (admin/audit.html)
- QR_CREATE, QR_DEACTIVATE, TALENT_CANCEL, ORDER_CANCEL 액션 추가

### 8. 기타
- `js/auth.js`: detectCurrentPageId에 5개 신규 페이지 ID 추가
- 캐시 버스팅: ?v=3.13.0

---

## 외부 라이브러리
| 라이브러리 | 버전 | 용도 |
|-----------|------|------|
| html5-qrcode | 2.3.8 | QR 코드 스캔 |
| qrcode.js | 1.5.4 | QR 코드 이미지 생성 |
| Kakao Maps SDK | - | 주소→좌표 변환 |

## 주의 사항
- Kakao Maps API 키를 admin/talent-qr.html의 script src에서 `KAKAO_API_KEY`를 실제 키로 교체 필요
- GPS/카메라 기능은 HTTPS(GitHub Pages) 환경에서만 동작
- GPS 실내 정확도 제한 → 반경 최소 0.2km 권장
