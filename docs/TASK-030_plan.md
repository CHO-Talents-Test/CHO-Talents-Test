# TASK-030: v3.13.0 작업 계획서

## 작업 개요
- **버전:** v3.13.0
- **작업명:** QR 달란트 시스템 + 관리 개선 + 통계 개편
- **작성일:** 2026-06-01
- **작성자:** AI_Cursor

## 작업 목적
1. QR 코드 기반 달란트 수령 시스템 신규 구축
2. 달란트 관리 기능 개선 (취소, 지급일 지정)
3. 구매 취소 기능 추가
4. 통계 페이지 전면 개편

## 변경 범위

### 신규 파일
| 파일 | 설명 |
|------|------|
| `talent-receive.html` | QR 스캔 달란트 수령 (교사용) |
| `admin/talent-qr.html` | QR 코드 관리 (전도사님+) |

### 수정 파일
| 파일 | 변경 내용 |
|------|----------|
| `admin/talents.html` | 달란트 취소, 출석 통일, 지급일 지정 |
| `my-orders.html` | 구매 취소 기능 |
| `admin/talent-stats.html` | 전폭 레이아웃, 날짜 필터, 요약 카드, 유형 구분 |
| `js/auth.js` | detectCurrentPageId 확장 |
| `admin/audit.html` | 새 액션 라벨 추가 |
| 전체 HTML (22+) | 네비게이션 메뉴 업데이트 |

### DB 변경
| 테이블 | 작업 |
|--------|------|
| `talent_qr_codes` | 신규 생성 + RLS |
| `talent_qr_scans` | 신규 생성 + RLS |

## 외부 의존성
- html5-qrcode v2.3.8 (CDN)
- qrcode v1.5.4 (CDN)
- Kakao Maps SDK (주소→좌표 변환)

## 작업 순서
1. DB 테이블 생성 + RLS + 스키마 캐시 리로드
2. talent-receive.html 신규 생성
3. admin/talent-qr.html 신규 생성
4. admin/talents.html 취소 기능 + 출석 통일
5. admin/talents.html 지급일 지정
6. my-orders.html 구매 취소
7. admin/talent-stats.html 전면 개편
8. 전체 네비게이션 업데이트
9. 문서/버전/캐시 버스팅/커밋
