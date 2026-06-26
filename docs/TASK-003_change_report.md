# TASK-003 변경 보고서: 상품 이미지 및 메인 화면 개선

## 작업 개요
- **작업 ID**: TASK-003
- **버전**: v1.2.0
- **작업일**: 2026-05-26
- **작업자**: AI

## 변경 사항

### 1. 상품 이미지 URL 지원
- `products` 테이블에 `image_url` (text) 컬럼 추가
- 학생 상점 (`student/shop.html`): 이미지 URL 있으면 이미지 표시, 없으면 이모지
- 교사 상점 (`teacher/shop.html`): 동일 처리
- `css/common.css`에 `.product-img` 스타일 추가

### 2. Supabase Storage 파일 업로드
- `Talents_Items` 버킷 생성 및 public 설정
- Storage RLS 정책 구성 (읽기: 공개, 업로드/수정/삭제: 허용)
- `js/product.js`에 `uploadProductImage()`, `deleteProductImage()` 함수 추가
- `manager/products.html` 파일 업로드 UI:
  - 드래그 앤 드롭 지원
  - 클릭으로 파일 선택
  - 이미지 미리보기 + 삭제
  - URL 직접 입력 병행 지원
  - 5MB 파일 크기 제한

### 3. 메인 화면 카드 링크 연결
- `index.html` feature-cards를 `<div>` → `<a>` 태그로 변경
- 달란트 적립 → `earn-talents.html` 연결
- 상품 구매 → `student/shop.html` 연결
- 랭킹 보기 → "내 달란트"로 변경, 역할별 달란트 페이지 연결
- `css/style.css` 카드 스타일 업데이트 (`cursor: pointer`, `text-decoration: none`)

### 4. 달란트 적립 안내 페이지
- `earn-talents.html` 신규 생성
- 6가지 적립 방법 안내 (성경읽기, 말씀암송, 출석, 친구초대, 특별활동, 선행)
- 적립 TIP 안내 박스

### 5. 관리자 상점 조회 페이지
- `admin/shop.html` 신규 생성
- 학생/교사/전체 탭 전환 조회
- 카테고리별 그룹핑, 활성/비활성 구분 표시
- 상품 수 요약 정보
- admin 네비게이션 전체에 상점 조회 링크 추가

## 변경 파일 목록

| 파일 | 상태 | 설명 |
|------|------|------|
| `js/product.js` | 수정 | 이미지 업로드/삭제 함수 추가 |
| `css/common.css` | 수정 | .product-img 스타일 추가 |
| `css/style.css` | 수정 | 카드 링크 스타일 |
| `index.html` | 수정 | 카드 링크화, 내 달란트 변경 |
| `student/shop.html` | 수정 | 이미지 표시 |
| `teacher/shop.html` | 수정 | 이미지 표시 |
| `manager/products.html` | 수정 | 파일 업로드 UI |
| `earn-talents.html` | 신규 | 적립 방법 안내 |
| `admin/shop.html` | 신규 | 관리자 상점 조회 |
| `admin/index.html` | 수정 | 네비/퀵링크 추가 |
| `admin/reports.html` | 수정 | 네비 추가 |
| `admin/logs.html` | 수정 | 네비 추가 |
| `admin/departments.html` | 수정 | 네비 추가 |
| `admin/managers.html` | 수정 | 네비 추가 |

## DB 변경
- `products` 테이블: `image_url` (text) 컬럼 추가
- Supabase Storage: `Talents_Items` 버킷 (public, RLS 정책 4개)
