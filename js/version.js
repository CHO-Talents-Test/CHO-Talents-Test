/**
 * 버전 관리 모듈 - CHO-Talents
 */
const APP_VERSION = {
  current: '3.59.0',
  date: '2026-07-01',
  history: [
    {
      version: '3.59.0',
      date: '2026-07-01',
      title: '환경 표기 및 QR 수령 URL 정리',
      changes: [
        'TARGET_ENV가 DEV일 때 네비게이션 브랜드에 (DEV) 표시',
        'DEV/PROD 환경별 talent-receive QR 절대 URL 경로 분기 유지',
        '버전 표시와 캐시 버스팅 참조를 v3.59.0 기준으로 갱신'
      ]
    },
    {
      version: '3.58.0',
      date: '2026-06-30',
      title: '공지 이미지 확대 보기 및 버전/문서 동기화',
      changes: [
        'admin/notices.html 공지 보기 모달에서 이미지 클릭 시 확대 보기 추가',
        '현재 작업 반영을 위해 버전 표시용 캐시 버스팅과 안내 문서를 최신 버전으로 동기화',
        'README, 사이트 안내서, 권한/로그/작업 이력 문서를 v3.58.0 기준으로 갱신'
      ]
    },
    {
      version: '3.57.0',
      date: '2026-06-29',
      title: 'Announcement management and login popup',
      changes: [
        'admin/notices.html added for evangelist-or-higher announcement create, edit, view, and active toggle workflows',
        'index.html now shows active announcements after login and stores per-account "do not open again" dismissals',
        'announcements and announcement_dismissals schema/RLS SQL added with audit/log action labels and documentation updates'
      ]
    },
    {
      version: '3.56.0',
      date: '2026-06-29',
      title: 'Kakao Map SDK key precedence fix',
      changes: [
        'supabase-config.js: keep the Kakao Map Key from public-config.js when it is explicitly set for the current environment',
        'DEV app_config seed SQL now uses the DEV Kakao Map Key',
        'admin/talent-qr.html cache-busting references updated to v3.56.0'
      ]
    },
    {
      version: '3.55.0',
      date: '2026-06-29',
      title: '환경별 Kakao Map Key 분기',
      changes: [
        'public-config.js에서 TARGET_ENV가 DEV이면 DEV Kakao Map Key를, PROD이면 PROD Kakao Map Key를 사용하도록 분기',
        '전체 HTML 캐시 버스팅 참조를 v3.55.0으로 갱신'
      ]
    },
    {
      version: '3.54.0',
      date: '2026-06-29',
      title: '상품 카테고리 추가 모달 + 코드 마스터 권한 보강',
      changes: [
        '상품 등록/수정 모달의 카테고리 선택 옆에 새 카테고리 추가 패널을 추가',
        '새 카테고리명과 이모지를 products.category 코드 마스터에 저장하고 즉시 선택되도록 로컬 코드북 갱신',
        '동일한 카테고리명이 이미 있으면 기존 항목을 자동 선택하고, 저장 실패/권한 오류는 모달 안에서 안내',
        '상품 등록 모달의 카테고리 추가 패널과 이미지 드롭존을 다크 테마 배경에 맞게 보정',
        'PRODUCT_CATEGORY_CREATE 로그/작업 이력 액션과 60등급 이상 상품 카테고리 INSERT 정책 SQL(TASK-058) 추가'
      ]
    },
    {
      version: '3.53.0',
      date: '2026-06-29',
      title: '인증 리디렉트 진단 로그 + QR 위치 권한 안내 + 달란트 상세 페이징',
      changes: [
        '보호 페이지 진입 시 세션 없음/만료, 최초 로그인, 권한 등급 부족, 허용 권한 불일치, DB 페이지 접근 차단 리디렉트 사유를 AUTH_REDIRECT 로그로 상세 기록',
        'Supabase Auth 세션 없음/오류와 프로필 RPC 조회 실패를 AUTH_SESSION_MISSING, AUTH_PROFILE_LOAD_FAIL 로그로 구분 기록',
        '24시간 유휴 세션 만료 리디렉트에 만료 기준(idle_timer, last_activity, visibilitychange)을 기록',
        '위치 제한 QR 수령 시 기기 또는 브라우저 위치 권한이 차단된 경우 alert와 화면 메시지를 함께 표시하고 QR_LOCATION_PERMISSION_BLOCKED 로그를 기록',
        '달란트 수령 카메라 스캔 결과 메시지를 카메라 영역 위에 표시',
        '달란트 관리 상세 모달의 전체 이력을 공통 페이징 버튼과 페이지당 항목 수 설정으로 조회',
        '페이징 적용 범위와 인증/권한 로그 기준을 README, 사용자 안내서, 아키텍처 문서, 역할별/운영 룰 가이드에 반영'
      ]
    },
    {
      version: '3.52.0',
      date: '2026-06-23',
      title: '비로그인 가이드 진입 개선 + QR 유효 시간 옵션 정리',
      changes: [
        '메인 페이지 비로그인 상태에서 사용 가이드 배너를 노출하여 첫 방문자가 이용 방법으로 바로 이동 가능',
        '로그인 페이지 하단에 메인 페이지와 사용 가이드 링크를 함께 배치',
        '달란트 QR 생성/수정 화면에서 유효 날짜와 유효 시간을 분리하고 시간 제한 없음/시간 제한 옵션 추가',
        '기간형 QR 유효 범위를 날짜 단위 입력으로 정리하고, 시간 제한이 없을 때 하루 전체 범위로 저장',
        '기존 QR 수정 시 저장된 시간 값에 따라 시간 제한 여부를 자동 반영',
        'QR 관리 화면의 다크 테마 스타일 보강',
        '전체 HTML 캐시 버스팅 참조를 v3.52.0으로 갱신'
      ]
    },
    {
      version: '3.51.0',
      date: '2026-06-22',
      title: '정렬 기준 정비 + 페이징/행 개수 설정 확대 + QR 유효 시간',
      changes: [
        '달란트/사용자/관리자/부서/구매 통계 목록의 기본 정렬 기준을 운영 요청 순서로 정비',
        '공통 페이징 표시를 8페이지 4번 조회 예시까지 맞도록 보정',
        '달란트 QR 목록, 내 구매 상품, 구매 통계, 달란트 수령 최근 내역, 부서 관리에 행 개수 설정과 페이징 보강',
        '보고서/로그 페이지의 행 개수 콤보 위치를 각 화면 요구 위치로 이동',
        '달란트 통계에서 반환 처리된 달란트를 원 지급 건에서 차감하여 실제 지급 달란트 기준으로 집계',
        '달란트 QR 지정일에 유효 시간 from-to 설정 추가 및 위치 반경 100m~400m 옵션 추가, 기본 500m 적용',
        '소개 드롭다운 가이드를 단일 "가이드" 항목으로 통합하고 로그인 권한별 가이드로 자동 연결',
        '달란트 적립 페이지에서 학생/교사 사용자 유형에 맞는 기본 탭을 자동 선택'
      ]
    },
    {
      version: '3.50.0',
      date: '2026-06-19',
      title: '공통 코드북 + DB 코드 마스터 + 상품/주문 상태 공통화',
      changes: [
        '공통 코드북 js/codes.js 추가: 권한, 사용자 유형, 주문 상태, 상품 대상/카테고리, 로그 액션 라벨을 한 곳에서 관리',
        '프론트 공통화: auth.js, activity-log.js, user-mgmt.js, product.js가 코드북 라벨/랭크/정렬/색상을 우선 사용',
        '구매 관리/구매 통계/내 구매 상품: product_orders.status 라벨·색상·이모지 중복 맵 제거',
        '상품 관리/상점: products.category를 코드 선택값으로 저장하고 표시 라벨은 코드북에서 조회',
        '작업 이력: activity_logs.action 코드 마스터를 불러와 작업 라벨/카테고리/이모지 확장 가능',
        'DB: docs/TASK-057_code_master.sql 추가 (code_groups/code_items, 코드 검증 트리거, get_permission_rank 코드 마스터 연동)',
        '설치 스크립트: 신규 Supabase 설치 시 TASK-057 코드 마스터 SQL을 기본 추가 적용'
      ]
    },
    {
      version: '3.49.0',
      date: '2026-06-19',
      title: 'admin 모바일 네비 수정 + QR 수령자 페이징 + 대시보드 정리 + 사용자 필터',
      changes: [
        'admin.css 모바일 네비: 테마→햄버거→로그아웃→이름 순서 admin 페이지에도 일괄 적용',
        'QR 수령자: 반환 감지를 QR별 개별 스캔 단위로 정확 매칭 (talent_item_id + 시간 근접)',
        'QR 수령자: 페이징 추가 (기존 admin 페이지 페이징 스타일 동일)',
        'QR 수령자: 표시 개수 설정 콤보박스 + 사용자별 DB 저장 (qr_scan_list 키)',
        '대시보드: 바로가기 박스(quickLinks) 제거',
        '사용자 관리: 통계 카드 클릭 필터 (전체/관리자/부서 담당/교사/학생)',
        '사용자 관리: 관리자 카드 = admin+evangelist+chief, 부서 담당 = purchase_teacher+dept_teacher',
        '사용자 관리: 활성 필터 카드 강조 표시 (box-shadow + transform)'
      ]
    },
    {
      version: '3.48.0',
      date: '2026-06-19',
      title: '달란트 반환 구분 표시 + 모바일 네비 배치 변경 + 24시간 세션 관리',
      changes: [
        '달란트 반환: 반환을 사용과 분리하여 별도 "반환" 유형으로 표시 (내 달란트, 관리자 상세, QR 수령자)',
        '달란트 반환: 내 달란트 페이지에 반환 달란트 요약 박스 추가, 사용 완료는 실제 상품 구매만 표시',
        '달란트 반환: 관리자 상세 팝업에 누적적립/총사용/총반환/잔여 4칸 표시',
        '달란트 반환: QR 수령자 목록에 반환된 달란트 "반환" 배지 표시',
        '달란트 반환: 내역 테이블 유형에 적립/사용/반환 3종 배지 구분',
        '모바일 네비: 우측 배치를 테마스위치 → 햄버거 → 로그아웃 → (권한이모지) 이름 순으로 변경',
        '세션 관리: 24시간 유휴 타임아웃 설정 (페이지 조회/클릭/스크롤 시 자동 초기화)',
        '세션 관리: 타임아웃 만료 시 자동 로그아웃 + 로그인 페이지 이동',
        '세션 관리: 멀티탭 동기화 (localStorage 기반 활동 시간 공유)',
        '세션 관리: 탭 전환 시 세션 만료 재검증'
      ]
    },
    {
      version: '3.47.0',
      date: '2026-06-18',
      title: '역할별 운영 가이드 + Slack 알림 룰 문서 + 신규 DB 설치 준비',
      changes: [
        '가이드: 부서 담당 교사, 구매 담당 교사, 부장 교사, 전도사님 전용 HTML 가이드 추가',
        '가이드: 소개 메뉴 순서를 학생/교사/부서 담당/구매 담당/부장/전도사님/관리자 가이드로 정리',
        '권한: Slack 알림 룰 페이지를 부장 교사 이상 권한으로 추가',
        '문서: .cursor/rules, 사용자/교사/학생/관리자 문서, 아키텍처 문서 최신 권한 체계 기준으로 갱신',
        'DB 설치: 신규 Supabase 프로젝트용 초기 설치 SQL 및 실행 스크립트에 최신 RPC, RLS, Slack Secret 기준 반영',
        'Slack: 알림 호출 구조, 알림 유형, 채널 라우팅, Edge Function 설정 문서화'
      ]
    },
    {
      version: '3.46.0',
      date: '2026-06-17',
      title: 'Q&A 미답변 배지 + Slack 알림 채널별 라우팅',
      changes: [
        'Q&A: 네비게이션 "소개" 그룹 및 "Q & A" 항목에 미답변 질문 수 배지 표시 (관리자 rank 60+)',
        'Slack: 알림을 부서별/유형별 채널로 분리 라우팅 (기존 단일 Webhook 제거)',
        'Slack: 신규 가입/부서 이동/구매 신청 → 해당 부서 채널 (1부~5부, 예배부)',
        'Slack: 구매 상태 변경 (구매 신청→상품 준비) → 상품 관리 채널',
        'Slack: WARN+ 로그 알림 → 운영 채널',
        'Slack: Q&A 질문 등록 → Q&A 채널',
        'Edge Function: 9개 Webhook Secret 기반 동적 라우팅 (SLACK_WEBHOOK_PART1~5, WORSHIP, PRODUCT_MANAGEMENT, OPERATIONS, ANSWER)',
        '구매 알림: 일반/대리 구매 시 소속 부서 정보 포함',
        '구매 상태: requested→preparing 전환만 Slack 발송 (기타 상태 변경은 알림 제거)'
      ]
    },
    {
      version: '3.45.0',
      date: '2026-06-16',
      title: 'Super Admin RPC 수정 + 구매 관리 칸반보드 + 구매 통계 신규 페이지',
      changes: [
        'Super Admin: admin_update_user RPC에서 is_super_admin=true 호출자를 rank 110으로 처리 (SQL 마이그레이션)',
        'Super Admin: 본인보다 높은 권한 부여 가능 (학생~관리자 모든 레벨 할당)',
        '구매 관리: 필터 버튼을 칸반보드 형태로 변경 (상태별 개수 실시간 표시)',
        '구매 관리: 칸반 카드 클릭 시 필터 동작 유지, 활성 카드 강조 표시',
        '구매 관리: 부서/기간 필터 적용 시 칸반 카운트 동기화',
        '신규: admin/purchase-stats.html 구매 통계 페이지 (부서 담당 교사 60+ 이상)',
        '구매 통계: 전체/부서별/사용자별/유형별 4가지 탭 뷰',
        '구매 통계: 교사/학생 각각 분리 표시',
        '구매 통계: 상태별 요약 카드 (칸반 스타일)',
        '구매 통계: 상세 모달 (상품별 상태 분포, 비율 그래프)',
        '구매 통계: 부서 필터 + 유형 필터 + 기간 필터 (기본 1주)',
        '구매 통계: 부서 담당 교사는 담당 부서만, 부장 교사 이상 전체 조회',
        '네비게이션: 상품 메뉴에 구매 통계 항목 추가 (minPerm: 60)',
        'DB 마이그레이션: docs/TASK-052_super_admin_update_fix.sql'
      ]
    },
    {
      version: '3.44.0',
      date: '2026-06-16',
      title: '구매 취소 버그 수정 + Super Admin 권한 변경 제약 해제',
      changes: [
        '구매 취소: RPC 기반 취소 우선 시도 (cancel_product_order), 미존재 시 직접 업데이트 폴백',
        '구매 취소: .select() 기반 업데이트 결과 검증 — 실제 상태 변경 여부 확인 후 후속 처리',
        '구매 취소: product_id 포함하여 정확한 주문 건 대상 취소 처리',
        '구매 취소: profiles 업데이트 403 에러 시 로그 기록 및 적절한 에러 핸들링',
        '구매 취소: Slack 알림은 실제 취소 확인 후에만 전송',
        'Super Admin: is_super_admin=true 계정은 사용자 수정 시 모든 권한 레벨 선택 가능',
        'Super Admin: 수정 모달에서 부서/역할/권한/담당부서 필드 제약 없이 편집 가능',
        'Super Admin: canManageUser에서 모든 사용자 관리 가능 (다른 super admin 포함)',
        'Super Admin: buildPermOptions에서 전체 권한 옵션 표시 (rank 필터 미적용)'
      ]
    },
    {
      version: '3.43.0',
      date: '2026-06-16',
      title: 'Slack 알림 연동 - 구매/가입/부서이동/로그/Q&A 알림',
      changes: [
        'Slack 알림: Supabase Edge Function slack-notify 생성 (Slack Block Kit 메시지 포맷)',
        'Slack 알림: js/slack-notify.js 공통 유틸리티 생성 (fire-and-forget, 5초 throttle)',
        'Slack 알림: 신규 구매 신청 알림 (일반 구매 + 대리 구매)',
        'Slack 알림: 구매 상태 변경 알림 (상품 준비/구매 확정/지급 완료/되돌리기/취소/일괄 처리)',
        'Slack 알림: 신규 가입 신청 알림 (아이디/이름/소속 부서)',
        'Slack 알림: 부서 이동 신청 알림 (대상자/이전부서/이동부서/사유)',
        'Slack 알림: WARN 이상 로그 발생 시 자동 알림 (레벨/액션/상세)',
        'Slack 알림: Q&A 질문 등록 알림 (등록자/질문 내용)',
        'Slack 채널: #달란트-마을 채널 연동'
      ]
    },
    {
      version: '3.42.0',
      date: '2026-06-16',
      title: '네비게이션 레이아웃 정비 + 그리드 헤더 클릭 정렬 + 데이터 정렬 기준 변경',
      changes: [
        '네비게이션 레이아웃: PC에서 Brand(좌측) / Links(중앙) / Actions(우측) 3-column flex 배치',
        '네비게이션: admin.css에 nav-header-actions base 스타일 추가 — admin 20개 페이지에서 로그아웃/테마 2줄 표시 문제 해결',
        '그리드 헤더 클릭 정렬: js/table-sort.js 공통 유틸리티 신규 생성 (initSortableHeaders)',
        '그리드 헤더 클릭 정렬: 7개 페이지 테이블에 data-sort-key + initSortableHeaders 적용',
        '정렬 화살표: th[data-sort-key] ⇅/▲/▼ ::after pseudo-element CSS 추가',
        '사용자 정렬: 유형(교사→학생) → 권한(내림차순) → 부서 → 반(null 마지막) → 이름',
        '구매 관리 정렬: 상태(단계순) → 신청일(내림차순) → 상품명 → 부서 → 신청자',
        '상품 관리 정렬: 카테고리 → 상품명 → 가격(내림차순)',
        '문서: README.md, SITE_USER_GUIDE.md, PROJECT_ARCHITECTURE_FLOW.md 최신화',
        '가이드: admin-guide.html, teacher-guide.html 정렬/페이징 기능 설명 업데이트'
      ]
    },
    {
      version: '3.41.0',
      date: '2026-06-15',
      title: 'UI 개선: 네비 단일화, 페이징 최대 7, 정렬, 모바일 터치 최적화',
      changes: [
        '네비게이션: 로그아웃/테마 버튼을 한 곳(nav-header-actions)에 단일 배치, 2중 표시 완전 해결',
        '네비게이션: PC에서 brand → 메뉴 → 로그아웃/테마 순서 정렬 (CSS order)',
        '네비게이션: 모바일 드롭다운 hover 비활성화 — 클릭만 펼침, 터치 깜빡임 해결',
        '페이징: 전체 12개 페이지에 최대 7개 버튼 표시 + 말줄임(…) 처리 (buildPagingButtons)',
        '정렬: 사용자 리스트 부서→반→권한→이름 정렬 (5개 페이지)',
        '정렬: 구매 관리 상태→부서→반→이름 정렬',
        '로그아웃 버튼: 둥근 pill 스타일, 테마별 조화로운 디자인'
      ]
    },
    {
      version: '3.40.0',
      date: '2026-06-15',
      title: '다크 테마 보정 + 페이징 통일/사용자 설정 + 부서 교사 권한 확대 + PAGE_VIEW 비활성화',
      changes: [
        '다크 모드: 관리 드롭다운, 이미지 업로드 영역, QR 폼, 통계 테이블 등 잔여 흰 배경을 CSS 변수 기반 어두운 표면색으로 보정',
        '다크 모드: 인라인 #e6fcf5, #fafafa, #f1f3f5, #e9ecef, #f0f0f0 배경/테두리 rescue 규칙 추가',
        '다크 모드: 즐겨찾기 항목 텍스트(fav-item-title/desc) 다크 테마 색상 보정',
        '다크 모드: input[type=date/number/text] 등 전역 다크 테마 규칙, stats-table, quickLinks, pct-bar 다크 보정',
        '페이징: 전체 11개 페이지 페이징 통일 (PC 20개/모바일 10개, 현재 페이지 강조)',
        '페이징: 사용자별 페이지당 항목 수 설정 (3~30개, DB 저장, js/page-size.js)',
        '페이징: 구매 관리, 작업 이력, 내 구매 상품, 달란트 항목, 달란트 QR, 관리자 관리에 신규 페이징 추가',
        '관리자 관리: ROLE_BADGE에 purchase_teacher 추가 — 구매 담당 교사가 관리자로 표시되던 문제 수정',
        '부서 관리: 소속보기에서 관리자 권한(100+)일 때 마지막 로그인 일시 컬럼 표시',
        '달란트 관리: 지급 취소 항목의 달란트 ID를 관리자 권한(100+)만 표시, 그 외 권한 숨김',
        '사용자 관리: 부서 담당 교사(rank 60+) 소속 부서 학생 반 변경/비밀번호 초기화 가능',
        '로그: PAGE_VIEW 자동 기록 비활성화',
        'DB: user_preferences.page_sizes JSONB 컬럼 추가 (TASK-041)'
      ]
    },
    {
      version: '3.39.0',
      date: '2026-06-12',
      title: '학생 일괄 등록 + 로그 삭제 보호 강화 + 대시보드 모바일 레이아웃',
      changes: [
        '학생 일괄 등록: 엑셀 파일 업로드로 학생 계정 일괄 생성 (부장 교사 80+ 이상)',
        '학생 일괄 등록: 양식 다운로드, 미리보기(검증), 등록 결과 표시',
        '로그 범위 삭제: 전체 레벨 삭제 시에도 미확인 ERROR+ 로그 보호',
        '대시보드: 모바일 stat 박스 한 줄 3개씩 자동 배치 (인라인 grid 제거)',
        '네비게이션: 관리 메뉴에 학생 일괄 등록 추가 (80+)',
        '즐겨찾기: 전체 메뉴 항목 추가 — 권한별로 달란트 항목, 관리자 관리, 보고서, 로그 등 표시'
      ]
    },
    {
      version: '3.38.1',
      date: '2026-06-12',
      title: '네비게이션 배지 권한별 처리 가능 건수 표시',
      changes: [
        '관리 배지: 해당 계정이 승인 처리 가능한 가입 신청 + 부서 이동 건수 표시',
        '상품 배지: 해당 계정이 처리 가능한 구매 건수 표시 (구매 담당 교사는 전체 부서)',
        '운영 배지: ERROR+ 미확인 로그 건수 (부장 교사 80+ 이상에서 호출)',
        '구매 담당 교사(purchase_teacher): 전체 부서 주문 카운트에 포함'
      ]
    },
    {
      version: '3.38.0',
      date: '2026-06-12',
      title: '달란트 반환 동기화 + 다크모드 UI 수정 + 배지 공통화',
      changes: [
        '달란트 지급: 다크모드에서 항목 배경 CSS 변수 적용 (--t-success-surface, --t-card)',
        '달란트 상세: 반환 버튼을 트랜잭션 ID 기반으로 변경 — 1회만 반환 가능, 반환된 항목은 "반환됨" 표시',
        '달란트 지급/상세: 취소·반환 시 txnId를 설명에 포함하여 상호 동기화',
        '상품 구매: 대리 구매 모달 다크모드 대응 (배경, 검색 입력, 선택 표시, 드롭다운)',
        '상품 구매: 구매 신청 비활성화 버튼 다크모드 대응',
        '네비게이션 배지: navUpdateAuth에서 rank ≥ 60 시 자동 호출 — 모든 페이지에 공통 적용',
        'CSS: --t-success-surface, --t-accent-surface 변수 추가 (라이트/다크 모드)'
      ]
    },
    {
      version: '3.37.0',
      date: '2026-06-12',
      title: '네비게이션 배지 + 구매 담당 교사 통합 + 로그 필터 삭제 + 마지막 로그인',
      changes: [
        '네비게이션: 달란트 통계, QR 관리, 로그 규칙, 감사 규칙, 비밀번호 변경 페이지에 배지 갱신 호출 추가',
        '대시보드: 관리자 카드(admin+evangelist) 추가, 부서 담당 카드에 purchase_teacher 포함',
        '사용자 관리: 관리자 카드 = admin+evangelist, 부서 담당 = chief+purchase_teacher+dept_teacher',
        '관리자 관리: DEPT_MGR_LEVELS에 purchase_teacher 추가, 구매 담당 필터 버튼 추가',
        '부서 관리: PERM_RANK_MAP에 purchase_teacher(70) 추가 — 소속보기 정렬 정상화',
        '페이지 접근: ROLE_LIST에 purchase_teacher 추가',
        '페이지 기능: PERM_LIST에 purchase_teacher 추가',
        '사용자 상세: last_login_at 컬럼 기반 마지막 로그인 표시 (로그 삭제와 무관)',
        '로그인: update_last_login RPC 호출로 profiles.last_login_at 갱신',
        '로그: 버튼명 변경 (범위 삭제 대기→범위 삭제, 선택 삭제 대기→선택 삭제)',
        '로그: 범위 삭제 시 현재 필터 레벨만 대상, ERROR+ 미확인 로그 제외',
        'DB: docs/TASK-049_schema.sql (profiles.last_login_at, update_last_login RPC)'
      ]
    },
    {
      version: '3.36.1',
      date: '2026-06-10',
      title: '구매 담당 교사 등록 폼 반영 + UTF-8 인코딩 보존 룰 + 문서 보완',
      changes: [
        '사용자 관리: PERM_LEVELS에 구매 담당 교사(70) 항목 추가 — 등록/수정 폼에서 선택 가능',
        '관리자 관리: PERM_LEVELS·MGMT_LEVELS에 구매 담당 교사 추가 — 등록/수정 시 담당 부서 할당 가능',
        'UTF-8 인코딩 보존 룰(.cursor/rules/utf8-encoding.mdc) 생성 — PowerShell Set-Content 사용 금지 명시',
        'README.md: 개발 시 주의사항(인코딩, 머지 충돌) 섹션 추가',
        'PROJECT_ARCHITECTURE_FLOW.md: 개발 주의사항 섹션 + TASK-048 참조 추가',
        'page-permission-rules.html: 구매 담당 교사 등급(70) 추가, 부장 교사 조회 전용 명시, 구매 관리 스코핑 업데이트'
      ]
    },
    {
      version: '3.36.0',
      date: '2026-06-10',
      title: '다크 테마 보강 + 구매 담당 교사 권한 + 달란트 항목 설명 필드 + 부장 교사 조회 전용',
      changes: [
        '다크 모드: 달란트 관리 부서 필터, 사용자 관리 부서 필터, 상품 등록/수정 모달, 부서 수정 모달, 달란트 통계 라디오/카드 배경을 어두운 표면색으로 보정',
        '테마: 로그아웃 시 기본(일반) 테마로 리셋, 로그인 시 계정에 저장된 테마를 DB에서 로드하여 적용',
        '부장 교사(80): 사용자 관리, 관리자 관리 페이지에서 모든 부서 조회 가능하되 관리 기능(수정/삭제/비밀번호 초기화) 숨김',
        '달란트 통계: 부서 필터 옵션 순서를 전체 → 1부~5부 → 예배부로 고정 정렬',
        '달란트 항목 관리: 등록/수정 모달에 달란트 지급 규칙, 달란트 지급 설명 텍스트 입력 필드 추가',
        '달란트 적립: talent_items의 giving_rule과 giving_description을 항목 카드에 동적 반영',
        '신규 권한: 구매 담당 교사(purchase_teacher, 등급 70) - dept_teacher와 동일 접근 권한이나 구매 관리에서 모든 부서 주문 관리 가능',
        '사용자 등록: 전도사님(90+)만 모든 부서 선택 가능, 부장 교사(80) 이하는 본인 담당 부서로만 등록 제한',
        '부서 필터: 모든 페이지에서 부장 교사(80+) 이상만 표시',
        '로그/작업 이력 룰: 테이블 overflow-x 및 word-break 보정',
        'DB: talent_items giving_rule/giving_description 컬럼, purchase_teacher 권한 CHECK 제약 추가 (docs/TASK-048_schema.sql)',
        '문서/가이드: README, 사용자 안내서, 구성도 권한 표에 구매 담당 교사 반영'
      ]
    },
    {
      version: '3.35.0',
      date: '2026-06-09',
      title: '다크 모드 잔여 화면 보정 + 달란트 적립 금액 표시 + 로그 적재 검증',
      changes: [
        '다크 모드: 가이드, Q&A, 달란트 적립/수령, QR 관리, 권한/로그/작업이력 룰, 버전 이력의 흰 배경/저대비 영역을 어두운 표면색으로 보정',
        '달란트 적립: 안내 카드별로 talent_items의 활성 항목 지급 수량을 조회해 +N 달란트 배지로 표시',
        '로그: writeLog()가 Supabase insert 반환 error를 실제 실패로 감지하고 콘솔에 남기도록 수정',
        '로그: 운영 DB 스키마가 구버전일 때 user_name/is_acknowledged 선택 컬럼 제거 후 재시도하는 호환 적재 경로 추가',
        '작업 이력: activity_logs 적재가 복구되면 AUDIT_ACTIONS에 등록된 관리 작업이 즉시 조회되도록 공통 로그 적재 경로를 보강',
        '문서/가이드: 다크 모드 보정, 적립 금액 표시, 로그/작업 이력 적재 검증 기준 갱신'
      ]
    },
    {
      version: '3.34.0',
      date: '2026-06-09',
      title: '테마 2종 스위치 + 즐겨찾기 권한 정합 + 로그/작업 이력 표시 보강',
      changes: [
        '테마: 봄/여름/가을/겨울 제거, 일반/다크 2종만 유지',
        '테마: 네비게이션 테마 선택 UI를 드롭다운에서 스위치 버튼으로 변경',
        '다크 모드: 네비게이션 드롭다운, 관리 드롭다운, 필터, 모달 등 흰 배경 우선 영역을 어두운 표면색으로 통일',
        '즐겨찾기: 모바일 최대 선택 수를 10개로 확대 (PC와 동일)',
        '즐겨찾기: 네비게이션 권한 규칙과 동일한 기준으로 후보 노출/저장/렌더링 정리',
        '즐겨찾기: 권한에 맞지 않는 기존 저장 항목 자동 제외',
        '로그: 조회 기간 라벨 정리 및 기본 조회 범위를 1년으로 확대',
        '작업 이력: is_deleted null/false 로그 모두 조회하도록 조건 보정',
        '작업 이력: 불필요한 자동 복원 로직 제거로 조회 안정성 개선',
        '문서/가이드: README, 사용자 안내서, 구성도, 학생/교사/관리자 가이드 최신 동작 기준으로 갱신'
      ]
    },
    {
      version: '3.33.0',
      date: '2026-06-08',
      title: '테마 시스템 + 네비게이션 중앙 관리 + 로그/작업이력 룰 페이지',
      changes: [
        '테마 시스템: 6가지 테마 지원 (일반/다크/봄/여름/가을/겨울), 계정별 저장',
        '테마: 모든 페이지 헤더에 테마 선택 아이콘 배치, DB + localStorage 동기화',
        '네비게이션: 33개 페이지 인라인 nav → js/nav.js 중앙 관리 전환',
        '네비게이션: 드롭다운 뷰포트 벗어남 방지, 모바일 햄버거 지원',
        '메인 페이지: 마을 컨셉 레이아웃 재설계 (양쪽 바로가기 + 중앙 즐겨찾기)',
        '즐겨찾기: 3개 고정 제한 해제 (모바일 최대 9개, PC 최대 10개)',
        '신규: 로그 작성 룰 페이지 (admin/log-rules.html) - 7레벨 체계 문서화',
        '신규: 작업 이력 작성 룰 페이지 (admin/audit-rules.html) - 10카테고리 문서화',
        'DB: user_preferences에 theme 컬럼 추가 (마이그레이션 SQL 포함)',
        'CSS: themes.css 신규, common.css/admin.css/style.css 테마 변수 연동'
      ]
    },
    {
      version: '3.32.0',
      date: '2026-06-08',
      title: '감사이력/로그 한글화 전면 개편 + 즐겨찾기 DB 마이그레이션',
      changes: [
        '작업 이력: AUDIT_ACTIONS 키 불일치 수정 및 70개 이상 액션 타입으로 확대 (10개 카테고리 필터)',
        '작업 이력: 필터 그룹 6개 → 10개 (사용자/등록/부서/달란트/상품·주문/Q&A/인증/로그관리/권한·설정)',
        '로그 시스템: ACTION_LABELS 한글 매핑 150개+ 추가, writeLog() 자동 한글 라벨 적용',
        '로그 뷰어: action 열에 한글 라벨 표시 (영문 키 병기)',
        '전체 20개+ 페이지/JS: logInfo/logWarn/logError details 키 한글화 (대상/변경내역/오류/금액 등)',
        '누락 로그 추가: qna.html(QNA_CREATE/ANSWER/COMMENT/DELETE/FAQ_SET), talent-items.html(TOGGLE/QUICKBTN), page-permissions.html(PAGE_PERM_UPDATE)',
        '즐겨찾기 DB 마이그레이션: user_preferences 테이블 신설, localStorage → Supabase DB 저장 전환',
        '즐겨찾기: 최초 로그인 시 기존 localStorage 데이터 자동 DB 마이그레이션',
        '문서/가이드: README.md, SITE_USER_GUIDE.md, PROJECT_ARCHITECTURE_FLOW.md, 3개 가이드 페이지 최신화'
      ]
    },
    {
      version: '3.31.0',
      date: '2026-06-08',
      title: '달란트 반환 매칭 ID 기반 전면 재설계 + 네비 배지 super_admin 제외',
      changes: [
        '달란트 관리: 반환 매칭을 트랜잭션 ID 기반 1:1 매칭으로 전면 재설계',
        '달란트 관리: 취소 시 반환 description에 원본 지급 트랜잭션 ID 포함 (반환: [txn_id] 설명)',
        '달란트 관리: loadAttendanceThisWeek/renderTalentItemButtons ID 기반 매칭 + 레거시 카운트 맵 하위호환',
        '달란트 관리: 출석/달란트 지급 시 즉시 상태 업데이트 + 동시 클릭 방어 가드 (_attendBusy)',
        '달란트 관리: confirmGiveItems 에서 이미 지급된 항목 자동 스킵 및 즉시 _weeklyGivenMap 갱신',
        '달란트 적립: 비로그인/학생 계정에서 교사 적립 탭 숨김 (permissionRank >= 40 일 때만 표시)',
        '네비게이션: 구매 배지(navOrderBadge) super_admin 사용자 주문 수 제외'
      ]
    },
    {
      version: '3.30.0',
      date: '2026-06-08',
      title: '관리 페이지 전체 super_admin 사용자 숨김 확대 적용',
      changes: [
        '달란트 관리: is_super_admin 사용자 목록 및 인원수에서 숨김 처리',
        '달란트 통계: is_super_admin 사용자 프로필/트랜잭션 및 통계에서 숨김 처리',
        '구매 관리: is_super_admin 사용자 주문 목록에서 숨김 처리',
        '관리자 관리: is_super_admin 사용자 관리자 목록 및 검색에서 숨김 처리',
        '부서 관리: is_super_admin 사용자 부서 인원수에서 숨김 처리',
        '대시보드: is_super_admin 사용자 전체/학생/교사/관리자 인원수 카운트에서 제외'
      ]
    },
    {
      version: '3.29.0',
      date: '2026-06-08',
      title: '달란트 취소 재지급 + super_admin 숨김 + 로그 배지 + 가이드 탭 + 권한 문서 nav',
      changes: [
        '달란트 관리: 출석/달란트 지급 취소 후 재지급 가능하도록 반환 트랜잭션 매칭 로직 수정',
        '사용자 관리: is_super_admin=true 사용자가 non-super_admin에게 목록에서 숨김 처리',
        '페이지 권한 룰 문서(docs/page-permission-rules.html)에 상단 네비게이션 바 추가',
        '운영 메뉴: 로그 배지(navLogBadge) 업데이트 시 updateNavGroupBadges() 호출하여 운영 드롭다운에도 배지 반영',
        '운영 메뉴: 전체 admin 페이지 16개에 updateLogBadge() 공용 함수 적용',
        '가이드 페이지: 권한별 탭 표시 (비로그인/학생→학생만, 교사→학생+교사, 부서담당+→전체)'
      ]
    },
    {
      version: '3.28.0',
      date: '2026-06-08',
      title: '메인 페이지 즐겨찾기 바로가기 커스터마이징',
      changes: [
        '메인 페이지: 로그인 사용자 바로가기 카드 즐겨찾기 커스터마이징 기능 추가',
        '메인 페이지: ⭐ 즐겨찾기 설정 버튼 + 토글 모달 (권한별 바로가기 목록 표시)',
        '메인 페이지: 사용자별 설정을 localStorage에 저장 (기기별 유지)',
        '메인 페이지: 비로그인 사용자는 기본 3개 카드(달란트 적립/상품 구매/내 달란트) 표시',
        '메인 페이지: 17개 바로가기 옵션 (공개 7 + 교사 2 + 부서담당 6 + 부장 2) 권한별 필터링'
      ]
    },
    {
      version: '3.27.0',
      date: '2026-06-08',
      title: '달란트 주간 초기화 + 지급 취소 + 통계 권한 + 적립 항목 개편',
      changes: [
        '달란트 통계: 부서 담당 교사(60~79) 담당 부서만 조회, 부장교사(80+) 전체 부서 조회',
        '달란트 관리: 본인에게 달란트 지급 불가 처리',
        '달란트 관리: 출석 퀵버튼 지급/취소 토글 (반환 트랜잭션 생성)',
        '달란트 관리: 달란트 지급 모달 항목별 취소 버튼 추가',
        '달란트 관리: 주간(월~일) 1회 지급 제한 (UI+RPC SQL)',
        '달란트 관리: 일반 교사(40) 교사 탭 숨김',
        '달란트 항목 관리: 접근 권한 60+, 퀵버튼 설정 80+',
        '사용자 관리: 구매 내역 조회 필드 수정 (total_price→price)',
        '달란트 적립: 교사/학생 탭 분리 및 실제 항목으로 변경'
      ]
    },
    {
      version: '3.26.2',
      date: '2026-06-05',
      title: '런타임 설정 관리 분리 + app_config 공개 설정 RPC',
      changes: [
        'config/public-config.js: 브라우저 공개 부트스트랩 설정과 환경 이름 관리',
        'supabase-config.js: get_public_app_config RPC 기반 원격 공개 설정 로더 추가',
        'DB: app_config 테이블, RLS, get_public_app_config SECURITY DEFINER RPC, 초기 설정 데이터 추가',
        '문서: 공개 설정/비밀 설정 저장 위치와 운영 원칙 정리'
      ]
    },
    {
      version: '3.26.1',
      date: '2026-06-03',
      title: '구매 취소 DB 제약조건 + QR 모달 디자인 + 중복 항목 허용',
      changes: [
        '구매 취소: product_orders_status_check에 cancelled 추가 SQL 제공',
        'QR관리: 수정 모달 라디오/체크박스 width:auto 적용으로 텍스트 세로 표시 해결',
        'QR관리: 중복 항목 QR 생성 실패 시 안내 메시지 및 UNIQUE 제약 제거 SQL 제공',
        'QR관리: 퀵버튼 is_quick_button 컬럼 추가 SQL 통합 제공 (TASK-040_fixes.sql)'
      ]
    },
    {
      version: '3.26.0',
      date: '2026-06-03',
      title: '퀵버튼 저장 수정 + 취소 상태 추가 + 드롭다운/모달 UI 개선',
      changes: [
        '달란트 항목 관리: 퀵버튼 저장 오류 수정 (DB 컬럼 누락 시 안내 메시지 표시)',
        '달란트 통계: 부서별 상세 비율을 수령 항목 수 기준으로 계산 변경',
        'QR관리: 수정 모달 디자인 개선 (반응형 + 모바일 최적화)',
        'QR관리: 수정 모달 저장방식 반영 (기존QR유지/새QR생성 버튼 정리)',
        '내 구매 상품: 취소 시 DB 삭제 대신 cancelled 상태로 변경',
        '내 구매 상품: cancelled 상태 주문은 내 달란트/내 구매 상품 목록에서 숨김',
        '구매 관리: cancelled 필터 탭 및 상태 표시 추가',
        '대시보드: stat-card 라벨 줄바꿈 방지 및 compact 패딩 적용',
        '사용자관리: 승인자 이름을 profiles에서 조회하여 표시 (관리자는 ID도 표시)',
        '전체: 드롭다운 z-index 9999 + overflow:visible 통일로 클리핑 완전 해결'
      ]
    },
    {
      version: '3.25.0',
      date: '2026-06-03',
      title: '가이드 접근제어 + 그리드 레이아웃 + 통계 UI + QR/취소 버그 수정',
      changes: [
        '가이드: 학생/교사/관리자 가이드 권한별 접근 제어 (학생→학생만, 교사→학생+교사, 부서교사이상→전체)',
        '달란트적립: 항목 카드 그리드 레이아웃 (모바일 3열, PC 5열)',
        'Q&A: 학생/교사도 등록된 질문 열람 및 답변 가능 (FAQ 등록은 관리자만)',
        '내달란트: 요약 카드 그리드 레이아웃 (모바일 3열, PC 5열)',
        '달란트관리: 출석 퀵버튼을 달란트 항목 관리에서 유형별(학생/교사) 1개 지정 가능',
        '달란트통계: 필터 라디오 이모지 + 칩 스타일, 그리드 라벨 변경 (달란트/항목), 상세 비율 그래프 추가',
        'QR관리: repeat 컬럼 없을 때 생성 오류 방지, 수령자 ID 관리자만 표시',
        'QR관리: 수정 모달 스크롤/디자인 개선, 저장방식 선택 (기존QR유지/새QR생성)',
        '내구매상품: 취소 시 profiles 테이블 사용으로 달란트 복원 수정',
        '대시보드: 요약카드/바로가기 그리드 (모바일 3열, PC 5열)',
        '사용자관리: 상세 아이디/승인자 관리자(100+)만 표시',
        '부서관리: 담당관리자 열 제거, 소속보기 관리자 우선 정렬',
        '전체: 테이블 overflow:visible 변경으로 드롭다운 하단 항목 클리핑 해결'
      ]
    },
    {
      version: '3.24.0',
      date: '2026-06-03',
      title: '실계정 권한 검증 후 대리구매/구매범위/QR 생성 보강',
      changes: [
        '상품구매: 대리구매 대상 조회를 admin_list_users RPC 기반으로 변경해 일반 교사 담당 반 학생 검색 오류 수정',
        '구매관리: 부서 담당 교사는 담당 부서 주문만 목록에 표시하도록 조회 범위 보정',
        'QR관리: 생성 버튼 상태 표시, 저장 결과 확인, 실패/성공 메시지 영역 추가',
        'QR관리: 인증 초기화 실패 시 후속 로직 실행 방지'
      ]
    },
    {
      version: '3.23.0',
      date: '2026-06-02',
      title: '관리 드롭다운 통합 + 통계 상세 모달 + 상품/구매 관리 개편',
      changes: [
        'QR관리: 조회 기간 초기 from 날짜를 오늘-7일로 변경',
        '사용자관리: 학생 그리드에서 권한 열 제거',
        '사용자관리: 통계 카드 모바일 3개씩 반응형 배치',
        '부서관리: 관리 버튼을 드롭다운으로 통합 (소속보기/수정/삭제)',
        '내달란트: 수령 대기 상품수에 구매 신청(requested) 상태 포함',
        '달란트관리: 출석 버튼 유지 + 달란트 지급/상세를 관리 드롭다운으로 통합',
        '달란트관리: 잔여 달란트 → 달란트 명칭 변경',
        '달란트관리: 사용 달란트/누적 달란트 모바일 숨김 (PC만 표시)',
        '달란트관리: 모바일 10개/PC 20개 페이징 추가',
        '달란트통계: 전체 탭 거래 수 → 항목 명칭 변경 + 개 접미사',
        '달란트통계: 전체 탭 총 달란트 → 달란트 명칭 변경',
        '달란트통계: 부서별 모바일 1인평균/그래프 숨김 + 비율 pct-bar 표시',
        '달란트통계: 부서별 상세 모달 (항목별 수령수/비율/1인평균)',
        '달란트통계: 사용자별 교사/학생 그룹 분리 + 모바일10/PC20 페이징',
        '달란트통계: 사용자별 상세 모달 (항목별 수령수/비율/합계)',
        '상품구매: 대리구매 검색에 부서/반 정보 추가',
        '상품관리: 전체/학생용/교사용 필터 제거 → 교사/학생 그룹별 표시',
        '상품관리: 대상 열 삭제 + 카테고리 열 맨 왼쪽 이동',
        '상품관리: 관리 버튼을 드롭다운으로 통합 + 모바일10/PC20 페이징',
        '구매관리: 상태별 필터 선택 시 상품별 합계 표시',
        '구매관리: 상태별 일괄 처리 버튼 추가 (일괄 상품 준비/구매 확정)',
        '구매관리: 관리 버튼을 드롭다운으로 통합'
      ]
    },
    {
      version: '3.22.0',
      date: '2026-06-02',
      title: '사용자 관리 개편 + 달란트 수령 학생 개방 + 대시보드 권한 확장',
      changes: [
        '사용자관리: 교사/학생 그룹별 분리 표시 (역할 컬럼 제거)',
        '사용자관리: 관리 버튼을 드롭다운으로 통합 (상세정보/수정/부서이동/비밀번호초기화/삭제)',
        '사용자관리: 상세 정보 모달 (아이디/역할/권한/부서/신청이력/달란트내역/구매내역)',
        '사용자관리: 등록일/마지막 로그인 컬럼 제거 → 상세 정보에서 확인',
        '사용자관리: 그룹별 페이징 (PC: 10개, 모바일: 5개)',
        '사용자관리: 마지막 로그인 정보 항상 activity_logs에서 최신 값으로 로드',
        '달란트수령: 학생 접근 허용 (initPage 20, nav 제한 제거)',
        '달란트수령: QR 코드 입력/확인 버튼 관리자(90+)만 표시',
        '달란트수령: 과녁 이모지/안내 텍스트 제거',
        '달란트수령: 활성 QR 코드 목록 학생/교사 그룹핑 + 만료 정렬 + 5개 페이징',
        '내달란트: 수령 대기 상품수 카드 추가 (사용가능→수령대기→사용대기 순서)',
        '상품관리: 삭제 대기 → 삭제 버튼 명칭 변경',
        '대시보드: 부서 담당 교사(60+) 접근 권한 추가 (전체 26개 페이지 nav 반영)',
        '날짜필터: 모든 페이지 from 기본값 오늘-7일로 변경 (통계/구매/로그/작업이력)',
        '로그: 삭제 기간 라벨 추가 (날짜 입력 앞에 표시)',
        '페이지접근: talent-receive/talent-stats/talent-qr/가이드/Q&A 등 신규 페이지 등록',
        '페이지기능: QR관리/통계/대시보드/작업이력 등 기능 항목 대폭 추가'
      ]
    },
    {
      version: '3.21.0',
      date: '2026-06-02',
      title: 'QR 날짜필터 개선 + 내 달란트 명칭 변경 + 가이드 전면 갱신',
      changes: [
        'QR관리: 날짜 검색 필터를 from-to 범위 형태로 변경',
        'QR관리: 날짜 필터 초기값 오늘 날짜로 설정',
        'QR관리: 초기화 버튼 제거',
        'QR관리: 기간 프리셋 버튼 추가 (오늘/1주/1달/1년)',
        '내달란트: 카드 순서 변경 (사용가능→수령예정→대기→완료→적립)',
        '내달란트: 카드 명칭에 "달란트" 접미사 추가',
        '내달란트: 상품 수령 예정 카드 신규 추가 (preparing/purchased 상태)',
        '가이드: "사용자 가이드"를 "학생 가이드"로 전체 명칭 변경 (27개 HTML)',
        '가이드: 메뉴별 사용 방법 테이블 간결화',
        '가이드: 내 달란트 화면 보는 법을 흐름순 설명 (구매신청→준비→구매→지급)',
        '가이드: 교사/관리자 가이드 최신 소스 기반 내용 업데이트'
      ]
    },
    {
      version: '3.20.1',
      date: '2026-06-01',
      title: '달란트 수령 카메라 미리보기 표시 수정',
      changes: [
        'QR수령: 카메라 영상 미표시 버그 수정 (#cameraWrap display:none → display:block 전환)',
        'QR수령: wrap을 먼저 보이게 한 후 video.play() 호출 (모바일 호환성)',
        'QR수령: webkit-playsinline 속성 동적 추가 (Safari 호환성 강화)',
        'QR수령: 카메라 시작 실패 시 스트림 정리 + wrap 숨김 처리'
      ]
    },
    {
      version: '3.20.0',
      date: '2026-06-01',
      title: 'QR 반복 수령 + 유형 검증 + 사용자 관리 페이징 + QR 검색/필터',
      changes: [
        'QR관리: 반복 수령 기능 (X/O 라디오) - 매일/요일반복/주차+요일반복 3가지 방식',
        'QR관리: 반복 수령 시 매일 00:00~23:59 초기화, 요일/주차 다중 선택',
        'QR관리: 생성 폼 섹션별 카드 UI로 모바일 가독성 개선',
        'QR관리: QR 리스트 복사 버튼 제거',
        'QR관리: QR 리스트 검색(설명/코드) + 필터(대상/조건/생성일) 추가',
        'QR관리: 수정 모달에도 반복 수령 옵션 동일 적용',
        'QR수령: 계정 유형(학생/교사)과 QR 대상 불일치 시 수령 차단',
        'QR수령: 위치 범위 초과 시 에러에 주소 명칭 표시',
        'QR수령: 반복 수령 QR 처리 - 오늘 수령 여부만 체크 (주기별 초기화)',
        '사용자관리: 페이징 처리 (모바일 10개/PC 25개, 페이지 번호 버튼)',
        'DB: talent_qr_codes에 repeat_type, repeat_days, repeat_weeks 컬럼 추가'
      ]
    },
    {
      version: '3.19.1',
      date: '2026-06-01',
      title: 'QR 코드 텍스트 숨기기 + 모바일 반응형 전면 개선',
      changes: [
        'QR수령: 관리자(100+) 외 QR 코드 텍스트 값 마스킹 (type=password)',
        '모바일: admin.css 테이블 min-width 강제값 제거 → auto로 전환 (화면 맞춤)',
        '모바일: common.css 데이터 테이블 min-width 제거, th white-space:nowrap',
        '모바일: 480px 이하 summary-card-value 크기 축소 (2rem→1.5rem)',
        '모바일: 640px 이하 테이블 패딩/폰트 최적화, table-layout:auto'
      ]
    },
    {
      version: '3.19.0',
      date: '2026-06-01',
      title: 'QR 관리 고도화 - 지급 대상, 유효기간 라디오, 위치 제한(카카오맵)',
      changes: [
        'QR관리: 지급 대상(학생/교사) 라디오 구분 + target_type별 달란트 항목 필터링',
        'QR관리: 유효기간 라디오 - 지정일(해당 일자 00:00~23:59) / 기간(from~to) / 무기한',
        'QR관리: 위치 제한 - 카카오맵 API 주소 키워드 검색, 위도/경도 저장, 반경 500m~5km 선택',
        'QR관리: 위치 제한 시 주소명 수동 수정 시 좌표 자동 초기화',
        'QR관리: 특정 위치 선택 시 좌표 미입력이면 생성 차단 + 안내 알림',
        'QR관리: 초기화/5개 일괄 생성 버튼 제거, 생성 버튼 이모지+스타일 디자인',
        'QR관리: 수정 모달에도 대상/유효기간 라디오/위치 제한 동일 적용',
        'QR수령: 위치 제한 코드 수령 시 Geolocation + Haversine 거리 검증',
        'DB: talent_qr_codes에 target_type, location_lat/lng/name/radius 컬럼 추가',
        'supabase-config.js: KAKAO_MAP_KEY 설정 상수 추가'
      ]
    },
    {
      version: '3.18.0',
      date: '2026-06-01',
      title: '통계 필터 개편, 기간 프리셋, 구매관리 필터 확장, 상품 소프트삭제, 대시보드 개선',
      changes: [
        '통계: 전체/부서별/사용자별/유형별 모든 뷰에 부서 필터 콤보박스 적용',
        '통계: 전체/학생/교사 라디오 버튼으로 사용자 유형별 필터링',
        '통계: 유형별 비율을 학생/교사 각각 항목별 비율로 변경 (기존 학생:교사 비율 대체)',
        '통계: 반별 탭 명칭을 "사용자별"로 변경 + 유형 컬럼 추가',
        '기간 프리셋: 오늘/1주/1달/1년 버튼 - 통계, 로그, 작업이력, 구매관리 4개 페이지',
        '구매관리: 전체 탭 외 각 상태별(구매신청/상품준비/상품구매/상품지급) 탭에도 부서/기간 필터 표시',
        '상품관리: 삭제를 소프트 삭제(삭제 대기)로 변경 - 비활성화 처리, 목록에서 숨김',
        '대시보드: 미확인 ERROR+ 카드를 관리자(100+)만 표시, 클릭 시 로그 페이지 이동',
        '대시보드: 바로가기에 달란트 통계, 달란트 QR 관리 추가'
      ]
    },
    {
      version: '3.17.0',
      date: '2026-06-01',
      title: 'QR 관리 고도화 - 수령자 목록, 항목 연동, 암호 강화, 계정 연동',
      changes: [
        'QR관리: 수령자 목록 모달 (이름/아이디/부서/수령시간 테이블)',
        'QR관리: 지급방식 라디오 - 무제한 or 선착순(1~100,000명)',
        'QR관리: 코드값 관리자(rank>=100)만 표시, 인쇄시에도 동일 적용',
        'QR관리: crypto.getRandomValues 18자리 암호학적 랜덤 코드 생성',
        'QR관리: 달란트 항목 드롭다운 연동 (없을때만 직접입력)',
        'QR관리: 수정 모달에도 항목선택/지급방식/기간 동일 적용',
        'QR수령: profiles.talent_balance 연동 (기존 users.total_talent 대체)',
        'QR수령: balance_after/created_by 트랜잭션 기록, 세션 잔액 동기화',
        'QR수령: talent_item_id QR코드에서 트랜잭션으로 자동 매핑',
        'QR수령: max_uses=0 무제한 지원, 코드 maxlength 30으로 확장',
        'talent.js CDN 추가: talent-qr.html에서 fetchAllTalentItems 사용'
      ]
    },
    {
      version: '3.16.0',
      date: '2026-06-01',
      title: 'QR 이미지·기간, 통계 UI, 구매/로그/작업이력 필터, 상품삭제 개선',
      changes: [
        'QR관리: QR코드를 qrcode.js CDN으로 2차원 이미지 생성·표시·인쇄',
        'QR관리: 최대 사용횟수 제거 → 1회 고정(max_uses=1)',
        'QR관리: 만료일을 from~to datetime-local 기간으로 변경 (무기한 지원)',
        'QR관리: 수정 버튼 추가 → 설명/금액/기간 편집 시 새 QR코드 재생성',
        'QR수령: valid_from/valid_until 기간 검증 추가',
        '통계: 유형별 탭에도 부서/반 필터 추가',
        '통계: 기간 필터 기본값 오늘(from, to)',
        '통계: 전체 레이아웃/디자인 개선 - 탭별 요약 카드·테이블 스타일·그래프',
        '구매관리: 날짜(from~to) 및 부서 필터 추가 (기본 오늘)',
        '로그: 기간 필터 기본값 오늘(from, to)',
        '작업이력: 기간 필터 기본값 오늘(from, to) + 자동 조회',
        '상품관리: FK 에러 시 soft delete(비활성화) 처리 안내',
        'product.js: deactivateProduct 함수 추가, deleteProduct FK 감지'
      ]
    },
    {
      version: '3.13.0',
      date: '2026-06-01',
      title: 'TASK-030: QR 달란트 시스템 + 관리 개선 + 통계 개편',
      changes: [
        '신규: talent-receive.html - QR 코드 스캔 달란트 수령 페이지 (교사 전용)',
        '신규: admin/talent-qr.html - QR 코드 생성/관리 페이지 (전도사님+)',
        'DB: talent_qr_codes, talent_qr_scans 테이블 생성 + RLS 정책',
        '달란트관리: 달란트 취소 기능 추가 (전도사님+)',
        '달란트관리: 출석 명칭 통일 + 중복 지급 방지 강화',
        '달란트관리: 과거 날짜 지급일 지정 기능 (전도사님+)',
        '내 구매 상품: requested 상태 구매 취소 + pending_talent 복원',
        '달란트 통계: 전폭 레이아웃 + 날짜 범위 필터 + 프리셋',
        '달란트 통계: 모든 뷰 요약 카드 통일 + 학생/교사 유형 구분',
        '네비게이션: 달란트 수령/QR 관리 메뉴 전체 페이지 추가',
        '감사 이력: QR_CREATE, QR_DEACTIVATE, TALENT_CANCEL, ORDER_CANCEL 액션 추가',
        '인증: detectCurrentPageId 5개 신규 페이지 ID 추가'
      ]
    },
    {
      version: '3.15.1',
      date: '2026-05-31',
      title: 'TASK-037: Q&A삭제 RPC, 사용기능 완전제거, 적립현황 자동표시, 달란트통계',
      changes: [
        'Q&A: 삭제를 admin_soft_delete_qna RPC 함수로 전환 (RLS 우회, SECURITY DEFINER)',
        '달란트관리: 사용 탭/섹션/함수 완전 제거 (물품 구매로만 사용)',
        '내달란트: 항목별 적립현황을 페이지 로드시 자동 표시 (클릭 불필요)',
        '신규: admin/talent-stats.html 달란트 누적적립 통계 페이지 (전체/부서별/반별)',
        '네비게이션: 달란트 드롭다운에 "달란트 통계" 메뉴 추가 (60등급 이상)'
      ]
    },
    {
      version: '3.15.0',
      date: '2026-05-31',
      title: 'TASK-036: 달란트관리/상품구매/구매관리 대규모 기능 개선',
      changes: [
        '달란트관리: 수기지급 관리자(100+)만 표시, 사용탭 관리자만 표시',
        '상품구매: 교사→학생상품 구매버튼 숨김(대리구매용 조회만)',
        '상품구매: 대리구매시 선택계정 유형별 상품필터(학생→학생상품, 교사→교사상품)',
        '상품구매: 학생/교사 모두 카테고리별 그룹화 표시',
        '상품구매: 카테고리 필터 콤보박스 추가',
        '상품구매: 상품명/카테고리 검색 기능 추가',
        '구매관리: 단계 되돌리기(↩) 기능 추가 (각 단계별)',
        '구매관리: 전체 탭에서 상세 다이얼로그로 처리이력 표시',
        '내달란트: 누적적립 클릭시 항목별 달란트 수/퍼센트 표시',
        '전체: 모든 숫자에 천단위 콤마(fmtNum) 적용',
        '네비게이션: 드롭다운 배지 합계를 그룹 토글에 표시',
        '사용자가이드: body.page-body 클래스 추가로 타이틀 짤림 해결',
        'Q&A: RLS UPDATE 정책 완화로 삭제 권한 문제 해결 (TASK-036 SQL)'
      ]
    },
    {
      version: '3.14.1',
      date: '2026-05-30',
      title: 'TASK-035: 모바일 네비게이션 드롭다운 표시 수정',
      changes: [
        '모바일: nav-dropdown-menu에 transform:none, left:auto, top:auto, min-width:0 추가',
        '데스크탑 transform:translateX(-50%)가 모바일에서도 적용되어 메뉴 밀림 현상 해결'
      ]
    },
    {
      version: '3.14.0',
      date: '2026-05-30',
      title: 'TASK-035: Q&A 댓글 시스템 + 출석 달란트 + 상품 그리드 + 대리구매 수정',
      changes: [
        'Q&A: 답변→댓글 형태로 변경 (qna_comments 테이블 활용, 여러 댓글 가능)',
        'Q&A: 관리자 FAQ 직접 등록 기능 추가',
        'Q&A: 삭제 권한 RLS 수정 (rank 60+ UPDATE 허용)',
        '상품: 구매 페이지 3개씩 한 줄 표시 (grid-template-columns: repeat(3, 1fr))',
        '대리구매: 모달 재오픈 시 사용자 검색 입력 필드 display 초기화',
        '달란트 관리: 출석 버튼 추가 (클릭 시 즉시 출석 달란트 지급, 당일 중복 방지)',
        '캐시: 전체 HTML v=3.14.0 캐시 버스팅'
      ]
    },
    {
      version: '3.13.4',
      date: '2026-05-30',
      title: 'TASK-035: 네비게이션 드롭다운 Safari 호환성 수정',
      changes: [
        '핵심 수정: position:sticky → position:fixed 변경 (Safari 드롭다운 클리핑 해결)',
        'body에 padding-top:54px 추가 (fixed nav 높이 보정)',
        '모바일: position:relative 유지 + padding-top:0 (기존 동작 유지)'
      ]
    },
    {
      version: '3.13.3',
      date: '2026-05-30',
      title: 'TASK-035: 네비게이션/QnA/배지 수정',
      changes: [
        '네비: 모든 페이지 토글 버튼에 현재 그룹 active 클래스 추가',
        '네비: common.css 깨진 CSS 블록 제거 (드롭다운 미표시 원인 수정)',
        '메인: 비로그인/학생/교사 "달란트 상점"→"사용자 가이드" 변경, 60+만 "관리" 표시',
        'Q&A: 비로그인 질문 등록(이름 입력) 지원 + RPC submit_anonymous_question',
        'Q&A: 전도사(90+) 이상 삭제 버튼 + 소프트 삭제(is_deleted) + 삭제 항목 숨김',
        'Q&A: 질문일시·답변일시 표시, 질문자 이름 표시 (관리자만 사용자ID 일부 확인 가능)',
        '배지: common.css 드롭다운 내 badge를 position:static으로 인라인 표시',
        '캐시: 전체 HTML v=3.13.3 캐시 버스팅'
      ]
    },
    {
      version: '3.13.2',
      date: '2026-05-30',
      title: '네비게이션 UX 개선 (가운데 정렬, 글씨 확대, 현재 페이지 강조, 빈 그룹 숨김)',
      changes: [
        '네비: 가운데 정렬 + 높이 54px + 간격 확대로 시인성 향상',
        '네비: 글씨 0.8rem→0.9rem 확대, 토글 배경색을 보라→흰색 전환으로 강조',
        '네비: 현재 페이지(.active) 드롭다운 내 보라색 배경 강조 표시',
        '네비: 드롭다운 메뉴 가운데 정렬 + 둥근 모서리 + 그림자 강화',
        '네비: 로그인 버튼 보라색 배지 스타일로 가시성 향상',
        '네비: 빈 드롭다운 그룹 자동 숨김 (비로그인 시 달란트 그룹 등)',
        'auth.js: hideEmptyDropdowns() 함수 추가 + DOMContentLoaded 자동 호출'
      ]
    },
    {
      version: '3.13.1',
      date: '2026-05-30',
      title: '드롭다운 네비게이션 클릭 동작 수정 + CSS 캐시 버스팅',
      changes: [
        '드롭다운 메뉴: hover + click-to-toggle 이중 방식 적용 (데스크탑/모바일 모두 동작)',
        'admin.css/common.css: .admin-nav/.top-nav에 overflow:visible 명시 추가',
        'admin.css/common.css: .dropdown-open 클래스 CSS 규칙 추가',
        '전체 21개 HTML: 드롭다운 JS를 click-toggle + 외부클릭 닫기 로직으로 교체',
        '전체 25개 HTML: CSS link에 ?v=3.13.1 캐시 버스팅 적용',
        'Q&A: docs/TASK-033_fixes.sql 안전 재실행 가능 버전 작성'
      ]
    },
    {
      version: '3.13.0',
      date: '2026-05-30',
      title: '네비게이션 드롭다운 개편 + 사용자 가이드/Q&A 신규 + 로그인/비밀번호 개선',
      changes: [
        '네비게이션: 평면 단일행 → 드롭다운 5그룹 개편 (소개/달란트/상품/관리/운영)',
        '네비게이션: 데스크탑 호버 펼침 + 모바일 아코디언 토글 방식',
        '전체 admin(15) + public(4) HTML 파일 드롭다운 네비 적용',
        'guide.html 신규: 사용자 가이드 (시각적 카드/스텝 기반 설명)',
        'qna.html 신규: Q&A 게시판 (FAQ + 질문등록 + 관리자 답변 + FAQ 등록)',
        'qna 테이블 생성 SQL + RLS 정책 + 초기 FAQ 9건',
        '로그인: check_registration_status RPC로 승인대기 메시지 정상 표시',
        '비밀번호 변경: 8자 이상 + 영문+숫자 조합 필수 + 1234 사용 금지',
        '메인 페이지: 네비 간소화 (브랜드+로그인/로그아웃+관리 버튼만)',
        'admin.css/common.css: .nav-dropdown-toggle/.nav-dropdown-menu 스타일 추가'
      ]
    },
    {
      version: '3.12.4',
      date: '2026-05-30',
      title: '달란트 관리 부서 필터 추가 + 메인 내 달란트 링크 수정',
      changes: [
        'admin/talents.html: 부서 필터 콤보박스 추가 (부장 교사 80+ 전용, 사용자/관리자 관리와 동일)',
        'index.html: 내 달란트 카드 링크를 항상 my-talents.html로 이동하도록 수정'
      ]
    },
    {
      version: '3.12.3',
      date: '2026-05-30',
      title: '데스크탑 네비게이션 표시 오류 수정 (항목 사라짐/2줄 표시)',
      changes: [
        'common.css: top-nav height 56px→48px + overflow-x:auto 가로 스크롤 적용',
        'common.css: top-nav-links flex-wrap:wrap 제거 + flex-shrink:0 고정',
        'common.css: top-nav-links li/a white-space:nowrap 적용 (한 줄 유지)',
        'common.css: 모바일(768px) 반응형 overflow/white-space 별도 복원',
        'shop.html/earn-talents.html: innerHTML 트릭 제거 → 별도 li 사전 렌더링 (사용자정보/로그아웃 2줄 표시 해결)'
      ]
    },
    {
      version: '3.12.2',
      date: '2026-05-30',
      title: 'UI/기능 개선: 네비 통일, 달란트 스코핑, 대리 구매, 내 구매 상품 페이지',
      changes: [
        '네비게이션 통일: 전체 페이지에 "내 구매 상품" 메뉴 추가 (admin 15 + 공개 5)',
        '보고서 리디렉트 수정: initPage minRank 통과 시 role_page_access can_access=false 무시',
        '달란트 관리: 일반 교사(40) 반 미배정 시 빈 목록 + canGiveTalent classNumber 필수화',
        '달란트 항목 관리 버튼: data-min-perm="60" (부서 담당 교사 이상만 표시)',
        '로그인 후 리디렉트: 모든 권한 index.html(메인 페이지)로 통일',
        'my-orders.html 신규 생성: 본인 구매 내역 조회 (4단계 상태 배지, 관리자 정보 미표시)',
        '대리 구매 기능: shop.html에 rank 40+ 대리 구매 모달 추가 (스코핑 규칙 적용)',
        '사용자 관리: 부서 담당 교사(60+) 반 수정 활성화, 부장 교사(80+) 부서 필터 추가',
        '관리자 관리: 학생 검색 제외, 부장 교사(80+) 부서 필터 추가'
      ]
    },
    {
      version: '3.12.1',
      date: '2026-05-29',
      title: '메인 로그인 수정 + 네비 배지/폰트 통일 + 보고서 누락 등록',
      changes: [
        'index.html: initSupabase() 누락 수정 (loadAuthSession 전 _sb 초기화)',
        'common.css: .badge 스타일 추가 (position:absolute, 배경 빨강, 원형 배지)',
        'common.css: top-nav-links 폰트 0.88rem→0.8rem, padding/border-radius admin.css와 통일',
        'common.css: 768px 반응형 badge position:static 인라인 전환',
        '보고서 SEED: TASK-007 backup_checklist, TASK-011 test_report 추가',
        '보고서 SEED: TASK-013A, TASK-013BCD change_report 추가',
        '보고서 REPORT_SEED_MAP: TASK-013A, TASK-013BCD 추가'
      ]
    },
    {
      version: '3.12.0',
      date: '2026-05-29',
      title: '기능 수정 + 문서 정비',
      changes: [
        '페이지 기능: role_page_features 테이블 생성 + RLS 정책 + 스키마 캐시 리로드',
        '페이지 기능: 그리드 4열→6열 변경 (구분/유형/권한/등급/설명/관리)',
        '메인 페이지: 로그인 🔐 / 로그아웃 🔓 이모지 구분 + try-catch 세션 로드',
        '네비게이션: admin 15개 파일에 "달란트 적립" 링크 추가',
        '네비게이션: public 3개 파일(shop/earn-talents/my-talents)에 admin nav 전체 항목 동일 순서 구성',
        '네비게이션: public 페이지에 updateNavOrderBadge() 호출 추가',
        '달란트 관리: "📋 달란트 항목 관리" 버튼 추가 (talent-items.html 링크)',
        '구매 관리: 탭 순서 변경 (전체 > 구매 신청 > 상품 준비 > 상품 구매 > 상품 지급)',
        '구매 관리: 기본 선택 탭 "전체" + 초기 제목 "전체 목록" + statusFilterWrap 표시',
        '로그: 제목 카운트 "활동 로그 (X/Y)" 형식 (현재 건수/전체 활성 건수)',
        '로그: 페이지네이션 번호 버튼 5개 + 말줄임(...) + 총 페이지 수 표시',
        '작업 이력: PERM_KEY_LABELS 한글 매핑 (admin→관리자 등)',
        '작업 이력: DETAIL_KEY_LABELS 40+ 필드 한글 매핑',
        '작업 이력: extractTarget() roleKey/permissionKey 한글 변환',
        '작업 이력: localizeDetailJson() 상세 모달 JSON 키 한글 라벨 병기',
        '문서: TASK-029 4종 생성 (plan/test_scenario/test_result/change_report)',
        '보고서: TASK-029 4종 + 기존 누락 문서(TASK-001~011) SEED 등록'
      ]
    },
    {
      version: '3.11.0',
      date: '2026-05-29',
      title: '반응형 페이지 + 네비게이션 통합',
      changes: [
        'CSS 반응형 브레이크포인트 통합: 480/640/768/1024px 4단계 (실사용자 해상도 기반)',
        'admin.css: 1024px 테이블 스크롤 시작, 768px 햄버거 메뉴 전환',
        'common.css: 768px 햄버거 메뉴, data-table 모바일 스크롤 추가',
        'style.css: 768px/480px 2단계 브레이크포인트 추가 (landing 페이지)',
        '모바일 네비게이션: admin-nav 햄버거 버튼 + 세로 드롭다운 (15개 파일)',
        '모바일 네비게이션: top-nav 햄버거 버튼 (shop/earn-talents/my-talents)',
        '테이블 반응형: min-width 700→600→520px 단계별 축소, 셀 패딩 최적화',
        '모달/폼 반응형: 640px 이하 flex-wrap 강제, 모달 전폭 확대',
        '대시보드: quickLinks 그리드 640px 2열, 480px 1열 강제',
        'detailSummary 3열→1열 모바일 전환 (640px)',
        'my-talents.html: Template A 방식 네비게이션 통합 (navLinks/navMyTalent/navAuthArea)',
        'index.html: 로그인 후 달란트 적립/상점/내 달란트/관리 링크 추가',
        'applyPermNav() 양방향 처리: show + hide (display:none 초기값 지원)',
        'admin nav 불일치 수정: page-access data-min-perm 80→100',
        'admin nav 불일치 수정: audit data-min-perm 80→100',
        'admin nav 불일치 수정: page-features active 클래스 추가'
      ]
    },
    {
      version: '3.10.0',
      date: '2026-05-29',
      title: '권한 세분화 + 구매 관리 개편 + 재고 제거',
      changes: [
        '달란트 관리 권한 세분화: rank 80 전체 조회 + 담당 부서만 지급',
        'give_talent RPC: managed_dept_id 기반 rank 60-89 스코핑 추가',
        '가입 승인 권한: 기존 부장/부서담당 스코핑 검증 완료',
        '부서 이동: rank 60 섹션 표시, rank 80 전체조회/담당부서 처리',
        '부서 이동 버튼: rank < 90 "부서 이동 신청"으로 명칭 변경',
        '로그인: 승인 대기/거부/비밀번호 오류 메시지 세분화',
        '재고 시스템 제거: shop.html 재고 표시/체크 제거',
        '재고 시스템 제거: admin/shop.html 재고 입력/컬럼 제거',
        '구매 관리 전면 개편: 처리자명 + 처리일시 컬럼 추가',
        '구매 관리: 상태 컬럼 제거 (탭 필터로 대체)',
        '구매 관리: "전체" 탭 + 상태 필터 드롭다운 추가',
        '구매 관리 권한: preparing/purchased 처리 admin전용 → rank 60+/담당부서로 확대',
        '구매 관리 네비게이션 배지: 처리 대기 건수 표시 (getPendingOrderCount)',
        'activity-log.js: getPendingOrderCount() + updateNavOrderBadge() 추가',
        '페이지 접근/기능: initPage(100) 관리자 전용화',
        '작업 이력: initPage(100) 관리자 전용화',
        '전체 admin 네비게이션: page-access/features/audit data-min-perm 80→100',
        '전체 admin 네비게이션: 구매 관리 배지(navOrderBadge) 추가 (15개 파일)',
        '전체 admin 페이지: updateNavOrderBadge() 호출 추가',
        '보고서: TASK-027 v3.10.0 보고서 시드 추가'
      ]
    },
    {
      version: '3.9.0',
      date: '2026-05-29',
      title: '상품 구매 시스템 구축 + 달란트 관리 개편 + 전체 명칭 통일',
      changes: [
        '상품 구매 시스템 신규 구축: 4단계 구매 흐름 (구매 신청→상품 준비→상품 구매→상품 지급)',
        'admin/purchases.html 신규: 구매 관리 페이지 (권한별 조회/처리, 일괄 지급 완료)',
        'shop.html: 상품 카드에 구매 신청 버튼 추가 (잔여 달란트 검증 포함)',
        'my-talents.html: 사용 대기 달란트 카드 추가, 구매 내역 표시',
        'product_orders 테이블 + RLS + request_product_order/confirm_product_purchase RPC',
        'profiles.pending_talent 컬럼 추가 (사용 대기 달란트)',
        '달란트 관리 개편: 항목별 체크박스 선택 + 일괄 지급 확정 방식으로 전환',
        '달란트 관리: 이미 지급된 항목 자동 표시 (오늘 기준)',
        '달란트 반환 기능: 부장 교사(80+) 이상만 사유 입력 후 반환 처리 가능',
        '달란트 상세 모달: 지급자 컬럼 추가 (created_by → profiles 조인)',
        '로그 페이지: is_deleted 컬럼 미존재 시 폴백 처리로 로그 표시 복구',
        '로그 페이지: 삭제 대기/목록/일괄 완료 버튼 관리자(100+) 전용으로 제한',
        '명칭 통일: 물품→상품 (전체 페이지), 부장→부장 교사, 부서관리자→부서 담당 교사',
        'shop.html: 교사 접속 시 기본 필터를 교사용으로 자동 설정',
        '전체 admin 페이지: 네비게이션에 구매 관리 메뉴 추가'
      ]
    },
    {
      version: '3.8.4',
      date: '2026-05-28',
      title: '로그 삭제 → 소프트 삭제(삭제 대기) 방식 전환',
      changes: [
        '로그 삭제: 실제 DELETE 대신 is_deleted=true 상태 변경 (소프트 삭제)',
        'fetchLogs: is_deleted=false 또는 null인 로그만 조회 (삭제 대기 항목 제외)',
        '삭제 대기 목록: 별도 뷰로 삭제 대기 로그 조회 + 복원 기능',
        '실제 데이터 삭제는 관리자가 SQL Editor에서 직접 수행',
        'activity_logs: is_deleted, deleted_at 컬럼 추가',
        'RPC 삭제 함수 제거 (더 이상 불필요)'
      ]
    },
    {
      version: '3.8.3',
      date: '2026-05-28',
      title: '작업 이력 실명 표시 + 보고서 자동 복구',
      changes: [
        'writeLog(): user_name(표시이름) + details._userName 저장으로 작업자 실명 기록',
        'audit.html: user_name/details._userName/username 폴백 체인으로 작업자 실명 표시',
        'audit.html: 관리자(100+)인 경우 작업자 이름 옆에 아이디 표시',
        'reports.html: 깨진 보고서(???) 자동 감지 + REPORT_SEED_MAP으로 자동 복구'
      ]
    },
    {
      version: '3.8.2',
      date: '2026-05-28',
      title: '페이지 접근 권한별 개편 + 작업 이력 관리 + DB 연동 적용',
      changes: [
        'page-access.html: 사용자별 → 유형/권한별 관리로 전면 개편 (role_page_access 테이블)',
        '신규 페이지: admin/audit.html - 작업 이력 조회 (부장 교사 80+ 접근)',
        'auth.js initPage(): role_page_access DB 조회 → 페이지 접근 차단 + 요소 숨김 실제 적용',
        'auth.js detectCurrentPageId(): 현재 페이지 ID 자동 감지 함수 추가',
        'activity-log.js: deleteLogsByIds/deleteLogsByDateRange 상세 디버그 로그 + RLS 미적용 안내',
        'reports.html: 보고서 수정 버튼 추가 (editReport 함수)',
        'admin.css: @keyframes spin-slow + .brand-icon 회전 애니메이션 추가',
        '전체 admin 페이지: nav brand 별 이모지 회전 적용',
        '전체 admin 페이지: 네비게이션에 작업 이력 메뉴 추가',
        'docs/TASK-023_fixes.sql: role_page_access 테이블 + activity_logs/reports RLS 정책'
      ]
    },
    {
      version: '3.8.1',
      date: '2026-05-28',
      title: '슈퍼관리자 관리 수정 + UI/UX 개선 + 페이지 기능 권한별 개편',
      changes: [
        'users.html/managers.html: 슈퍼관리자(rank 110)가 일반 관리자(rank 100) 관리 가능하도록 targetRank 계산 수정',
        'activity-log.js: 세션 캐시에 isSuperAdmin 필드 갱신 로직 추가',
        'admin.css: 네비게이션 한 줄 가로 스크롤 (flex-wrap 제거, overflow-x: auto)',
        'admin.css: 테이블 셀 패딩 축소 (th: 0.5rem 0.6rem, td: 0.45rem 0.6rem)',
        'admin.css: 모바일 640px 이하 테이블 더 컴팩트하게 (padding 0.35rem, min-width 500px)',
        'page-features.html: 사용자별 → 권한별 관리로 전면 개편 (role_page_features 테이블)',
        'page-features.html: 슈퍼관리자 행은 is_super_admin 계정만 표시, 모든 기능 기본 활성화',
        'reports.html: JS 기반 보고서 시더 기능 추가 (SQL 인코딩 문제 해결)',
        'reports.html: 슈퍼관리자만 보이는 "전체 보고서 초기화" 버튼',
        'logs.html: 선택 삭제/범위 삭제 에러 핸들링 강화 + RLS 정책 안내',
        'docs/TASK-022_fixes.sql: activity_logs DELETE RLS 정책 + role_page_features 테이블 생성'
      ]
    },
    {
      version: '3.8.0',
      date: '2026-05-28',
      title: '슈퍼관리자 체계 + 네비게이션 개편 + 페이지 권한 관리 + UI 전면 개선',
      changes: [
        'auth.js: 슈퍼관리자(is_super_admin) 권한 체계 구현 - rank 110으로 admin 상위 관리 가능',
        '네비게이션 브랜드: CHO-Talents → ⭐ 달란트 마을 (전체 admin 페이지 통일)',
        '네비게이션: 내 달란트, 상품 구매, 페이지 접근, 페이지 기능 항목 추가',
        '네비게이션 아이디 색상: 흰색 → 검정색으로 가시성 개선',
        '메인 페이지: 로그인 버튼 ↔ 로그아웃 버튼 동적 전환',
        '신규 페이지: 페이지 접근 관리 (page-access.html) - 사용자별 페이지 접근/요소 가시성 관리',
        '신규 페이지: 페이지 기능 관리 (page-features.html) - 사용자별 기능 권한 관리',
        '부서 관리: 그리드 헤더 간소화 (관리자/부서관리자 열 제거)',
        '권한 명칭: 부장 → 부장 교사 (전체 페이지 일괄 변경)',
        '관리자 관리: 달란트/등록일 열 + 비밀번호 초기화/삭제 버튼 제거',
        '달란트 관리: 잔여/사용/누적 달란트 표시 + 상세 통계 모달 추가',
        '달란트 관리: 수정/삭제 버튼 제거, 달란트 → 달란트 지급 명칭 변경'
      ]
    },
    {
      version: '3.7.7',
      date: '2026-05-28',
      title: '수정 모달 부서 변경 제거 + 보고서 전체 등록',
      changes: [
        'users.html: 수정 모달에서 소속 부서/반 변경 비활성화 (부서이동 기능으로 대체)',
        'managers.html: 수정 모달에서 소속 부서 변경 비활성화',
        '보고서 DB 한글 깨짐 데이터 전면 교체 SQL 생성 (TASK-008~011 포함)',
        '전체 작업 보고서 20건 일괄 등록 SQL (TASK-001 ~ TASK-020)'
      ]
    },
    {
      version: '3.7.6',
      date: '2026-05-28',
      title: '보고서 한글 인코딩 수정 + 관리자 아이디 표시 예외',
      changes: [
        '전체 HTML/JS 파일 UTF-8 BOM 제거 (18개 파일)',
        '관리자(admin) 권한: 모든 페이지에서 타인 아이디 표시 가능',
        '비관리자: 자기 아이디만 표시 (기존 유지)'
      ]
    },
    {
      version: '3.7.5',
      date: '2026-05-28',
      title: '타인 아이디 숨김 + 부서 이동 관리 시스템',
      changes: [
        'users/managers/departments/talents: 타인 아이디 숨김 (자기 아이디만 표시)',
        'users.html: 부서 이동 버튼 추가 (하위 권한자만 이동 가능)',
        'users.html: 관리자/전도사님 - 즉시 부서 이동 처리',
        'users.html: 부장/부서담당교사 - 부서 이동 요청 생성 (승인 필요)',
        'users.html: 부서 이동 신청 내역 섹션 + 승인/거부 기능',
        'department_transfer_requests 테이블 SQL 파일 생성 (docs/)'
      ]
    },
    {
      version: '3.7.4',
      date: '2026-05-28',
      title: '가입 신청 권한별 조회/처리 조건 + 네비게이션 아이디 표시',
      changes: [
        'users.html: 관리자/전도사님 - 모든 부서 신청자 보임 + 전체 처리 가능',
        'users.html: 부장 - 모든 부서 신청자 보이나 담당 부서만 처리 가능',
        'users.html: 부서 담당 교사 - 담당 부서 신청자만 보임 + 처리 가능',
        'auth.js: renderRoleBadge에 아이디 표시 추가 (이름 (아이디) 형식)'
      ]
    },
    {
      version: '3.7.3',
      date: '2026-05-28',
      title: '권한 기반 부서/사용자 관리 스코핑 + 교사 카운트 수정',
      changes: [
        'departments.html: 교사 수 카운트에 user_type=teacher 전체 포함 (관리자~일반교사)',
        'users.html/managers.html: 본인 권한보다 낮은 사용자만 관리 가능 (>= → >)',
        'users.html/managers.html: 권한 부여 시 본인 권한 미만만 선택 가능',
        'users.html/managers.html: 전도사님 미만(부장 이하) - 담당 부서 계정만 표시',
        'departments.html: 부장 미만 - 담당 부서만 표시, 전도사님 미만 - 담당 부서만 관리',
        'departments.html: 접근 권한 80→60 (부서 담당 교사도 접근 가능)',
        'admin 전체(11개): 부서 관리 nav data-min-perm 80→60'
      ]
    },
    {
      version: '3.7.2',
      date: '2026-05-28',
      title: '보고서 텍스트 수정 + 로그 선택 삭제 + 가입대기 배지',
      changes: [
        'reports.html: colspan 불일치 수정 (6→7), HTML Entity → 유니코드 이모지 교체',
        'reports.html: session.display_name → session.displayName 프로퍼티명 수정',
        'logs.html: 체크박스 + 선택 삭제 기능 추가 (기존 범위 삭제 유지)',
        'activity-log.js: deleteLogsByIds() 함수 추가',
        '전체 admin 페이지(11개): 사용자 관리 네비게이션에 가입대기 배지 추가',
        'activity-log.js: getPendingRegistrationCount() + updatePendingBadge() 함수 추가'
      ]
    },
    {
      version: '3.7.1',
      date: '2026-05-28',
      title: '보고서 페이지 치명적 버그 수정 + 보고서 관리 기능',
      changes: [
        'reports.html: TYPE_LABELS 변수명 충돌 해결 (auth.js와 동일 const 재선언 → 전체 인라인 스크립트 미실행)',
        'reports.html: REPORT_TYPE_LABELS로 리네이밍하여 전역 스코프 충돌 제거',
        'reports.html: 보고서 등록 모달 + 선택 삭제 기능 추가',
        'TASK-014 보고서 4종 SQL INSERT 파일 생성 (docs/)',
        'reports 테이블 RLS INSERT/UPDATE/DELETE 정책 수정 SQL 포함'
      ]
    },
    {
      version: '3.7.0',
      date: '2026-05-28',
      title: '다중 기능 개선 및 UX 향상',
      changes: [
        '아이디 생성 시 한글 입력 제한 (영문/숫자/_/- 만 허용)',
        '로그 페이지: 범위 삭제, 사용자 이름(아이디) 표시, 상세 팝업 추가',
        '대시보드: 최근 이슈 로그 타이틀 + WARN 이상만 표시',
        '네비게이션: CHO-Talents 타이틀 + 메인 페이지 링크 변경',
        '사용자 관리: 마지막 로그인 표시 (activity_logs 기반)',
        '물품 관리: 수정 시 활성화/비활성화 토글 추가',
        '보고서 페이지: 3초 타임아웃 안전장치 + 스텝별 진단 로그 추가',
        '로그인: 승인 대기/거부 계정 구분 메시지 (이모지 포함)',
        '작업 수행 8단계 프로세스 룰 등록'
      ]
    },
    {
      version: '3.6.0',
      date: '2026-05-27',
      title: '권한 체계 개선 + 반 시스템 추가',
      changes: [
        'DB: departments.class_count, profiles.class_number 컬럼 추가',
        'RPC: admin_create_user/admin_update_user에 p_class_number 파라미터 추가',
        'RPC: give_talent rank >= 40 허용 + 반/부서 스코핑 (교사는 자기 반만)',
        'RPC: admin_list_users rank >= 40 허용 (교사 접근)',
        'RPC: get_my_profile에 class_number 반환 추가',
        'RLS: activity_logs SELECT/UPDATE rank >= 100 (관리자 전용)',
        'users.html: 역할/권한 분리 UI (학생/교사 + 권한 드롭다운), 반 드롭다운 추가',
        'users.html: 권한 부여 제한 (로그인 사용자 rank 이하만 선택 가능)',
        'users.html: 테이블에 역할/권한/반 컬럼 분리 표시',
        'managers.html: 권한 드롭다운 동적 생성 (호출자 rank 이하만)',
        'managers.html: canManage 로직 추가 (자신보다 높은 권한 수정/삭제 차단)',
        'managers.html: 수정 시 권한 변경 가능 (이전: disabled)',
        'departments.html: 부서 생성/수정 시 반 개수 설정 (숫자 입력)',
        'departments.html: 부서 목록에 반 개수 표시, 소속보기에 역할/권한/반 분리',
        'talents.html: initPage(40) - 일반 교사도 접근 가능',
        'talents.html: 반 스코핑 (교사는 자기 부서+반 학생만 표시)',
        'logs.html: initPage(100) - 관리자만 접근 가능',
        'logs.html: 일괄 완료처리 관리자 전용 체크 추가',
        '전체 admin 페이지(11개): 달란트 관리 data-min-perm 60→40',
        '전체 admin 페이지(11개): 로그 data-min-perm 80→100',
        '루트 페이지(3개): 달란트 관리 data-min-perm 60→40',
        'auth.js: teacher PERMISSION_REDIRECT를 admin/talents.html로 변경',
        'auth.js: session에 classNumber 저장',
        'user-mgmt.js: createUser/updateUser에 classNumber 파라미터 추가',
        'user-mgmt.js: createDepartment에 classCount 파라미터 추가'
      ]
    },
    {
      version: '3.5.0',
      date: '2026-05-27',
      title: 'UI/UX 8단계 수정 (네비게이션, 상점, 관리자 등록, 인코딩, 보고서)',
      changes: [
        'admin 전체 페이지(11개): 네비게이션 메인 링크 제거',
        'index.html: 로그인 상태 시 사용자 배지 + 로그아웃 버튼 표시',
        'shop.html: 탭 버튼 스타일 수정 (common.css에 filter-btn 추가), 텍스트 통일',
        'shop.html: 손님/학생 교사 상품 서버 측 필터링 차단',
        'managers.html: 관리자 등록 시 기존 사용자 검색 방식으로 전환',
        'talent_items DB: 한글 깨짐 데이터 13건 수정 (출석, 성경 읽기 등)',
        'reports.html: 에러 처리 + 디버깅 로그 추가',
        'version.js: history 배열 최신순 정렬 수정, versions.html 현재 버전 표시 수정'
      ]
    },
    {
      version: '3.4.0',
      date: '2026-05-27',
      title: '사용자 ID 보안 강화 + 동명이인 넘버링',
      changes: [
        'user-mgmt.js: resolveDisplayNames() 동명이인 넘버링 유틸 함수 추가 (이름+유형+부서 동일 시 ①②③...)',
        'user-mgmt.js: isAdminLevel() 유틸 함수 추가',
        'admin/users.html: username 컬럼 admin만 표시, 동명이인 넘버링 적용',
        'admin/managers.html: username 컬럼 admin만 표시, 동명이인 넘버링 적용',
        'admin/talents.html: username 컬럼 제거(admin만 괄호 표시), 동명이인 넘버링 적용',
        'admin/departments.html: 소속보기에서 username admin만 표시, 동명이인 넘버링 적용',
        '모달 아이디 필드: admin만 표시, 비admin 등록 시 자동 생성'
      ]
    },
    {
      version: '3.3.3',
      date: '2026-05-27',
      title: '로그 개선: 클라이언트 정보 수집 (IP, 브라우저, OS, 해상도, 기기유형, 언어)',
      changes: [
        'activity-log.js: getClientInfo() 함수 추가 - IP, 브라우저, OS, 화면 해상도, 창 크기, 디바이스 유형, 언어 수집',
        'activity-log.js: writeLog()에 자동으로 _client 정보 병합',
        'activity-log.js: IP 주소 비동기 조회 (ipify.org API) + 캐싱',
        'admin/logs.html: 클라이언트 정보 컬럼 추가 (IP, 브라우저, 기기유형 표시 + 툴팁으로 전체 정보)'
      ]
    },
    {
      version: '3.3.2',
      date: '2026-05-27',
      title: '핫픽스: admin 권한 관리 + 캐시 버스팅 + 호환성 수정',
      changes: [
        'admin 계정이 동급 권한자(다른 admin)도 수정/삭제 가능하도록 프론트엔드 canManage 로직 수정',
        'admin_update_user, admin_delete_user, admin_create_user RPC: 동급 권한 차단(>=) → 상위만 차단(>) 변경',
        'applyRoleNav → applyPermNav 호환성 alias 추가 (브라우저 캐시 에러 방지)',
        'admin_user 계정 display_name DB 수정: ???(admin) → 관리자(admin)',
        '전체 HTML 18개 파일 JS 캐시 버스팅 쿼리스트링 추가 (?v=3.3.2)'
      ]
    },
    {
      version: '3.3.1',
      date: '2026-05-27',
      title: 'TASK-013 검증 핫픽스: role→permission_level 전환 누락 수정',
      changes: [
        'admin/users.html: 사용자 생성/수정 모달 6단계 권한 드롭다운 적용',
        'admin/users.html: saveUser()→userType/permissionLevel 파라미터 전달 수정',
        'admin/users.html: approveReq()→userType/permissionLevel 파라미터 전달 수정',
        'admin/users.html: 가입 승인 드롭다운 6단계 권한 옵션 적용',
        'admin/managers.html: 관리자 등록/수정 모달 4단계 권한 드롭다운 적용',
        'admin/managers.html: saveManager()→userType/permissionLevel 전달 수정',
        'admin/managers.html: ROLE_BADGE 4단계 권한별 배지 확장',
        'register.html: registration_requests INSERT에서 삭제된 role 컬럼 참조 제거',
        'shop.html, index.html, login.html: session.role 폴백 참조 제거',
        'js/auth.js: 미사용 ROLE_LABELS, ROLE_EMOJI, applyRoleNav() 레거시 코드 제거',
        'js/user-mgmt.js: options.role 폴백 제거'
      ]
    },
    {
      version: '3.3.0',
      date: '2026-05-27',
      title: 'TASK-013D: 페이지 권한 관리 + 세부 권한 적용',
      changes: [
        'page_permissions 테이블 생성 + 초기 데이터 시드',
        'admin/page-permissions.html 신규: 페이지 권한 매트릭스 관리 UI',
        '프론트엔드 전체: role 참조 → user_type + permission_level 완전 전환',
        'admin_list_users RPC: p_role → p_user_type 파라미터 전환',
        'admin_create_user, admin_update_user RPC: role 파라미터/컬럼 참조 제거',
        'get_my_profile RPC: role 필드 제거',
        'profiles, registration_requests 테이블: role 컬럼 드롭',
        'admin/users.html, managers.html, departments.html: permission_level 기반 필터링/렌더링'
      ]
    },
    {
      version: '3.2.0',
      date: '2026-05-27',
      title: 'TASK-013C: 달란트 지급 방식 개편',
      changes: [
        'talent_items 테이블 신규 생성 (학생/교사별 지급 항목)',
        'talent_transactions에 talent_item_id 컬럼 추가',
        'give_talent RPC 업데이트: 항목 기반 지급 + 학생 주 1회 규칙',
        'admin/talent-items.html 신규: 달란트 지급 항목 관리 (admin/evangelist)',
        'admin/talents.html 개선: 항목 버튼 기반 지급 UI + 수동 입력 옵션',
        '초기 데이터: 학생 8항목, 교사 5항목'
      ]
    },
    {
      version: '3.1.0',
      date: '2026-05-27',
      title: 'TASK-013B: 페이지 구조 통합 + 네비게이션 개선',
      changes: [
        'student/teacher 폴더 페이지 통합 → 루트 레벨 my-talents.html, shop.html',
        'admin/products.html 삭제 → admin/shop.html로 물품 관리 CRUD 통합',
        '전체 admin 페이지 네비게이션 data-min-perm 기반 통합',
        '루트 레벨 페이지(earn-talents.html, shop.html, my-talents.html) 네비게이션 통합',
        'applyRoleNav → applyPermNav 전환 완료',
        '대시보드 퀵 링크에서 products.html/상점 관리 제거, shop.html/물품 관리로 통합'
      ]
    },
    {
      version: '3.0.0',
      date: '2026-05-27',
      title: 'TASK-013A: 유형/권한 6단계 체계 전면 개편 (DB+인증 코어)',
      changes: [
        'profiles 테이블 확장: user_type(교사/학생) + permission_level(6단계) + is_super_admin',
        'registration_requests 테이블 확장: user_type + permission_level 컬럼 추가',
        'get_permission_rank() 헬퍼 함수 생성 (admin:100 ~ student:20 수치 비교)',
        '기존 데이터 자동 마이그레이션 (role -> user_type + permission_level)',
        '최고관리자 is_super_admin 플래그 설정 (본인 외 수정/삭제 불가)',
        '최고관리자 display_name을 "관리자(admin)"으로 변경',
        'RPC 함수 12개 전면 업데이트 (permission_level 기반 권한 체크)',
        'admin_create_user: 상위 권한자 생성 불가 체크 추가',
        'admin_update_user: 계층적 권한 검증 + 최고관리자 보호',
        'admin_delete_user: 계층적 삭제 제한 + 최고관리자 삭제 불가',
        'admin_reset_password: 상위 권한자 비밀번호 초기화 불가',
        'give_talent/use_talent: dept_teacher(60) 이상만 실행 가능',
        'admin_list_users: permission_level/user_type 기반 조회 + is_super_admin 반환',
        'get_my_profile: user_type, permission_level, is_super_admin 반환',
        'get_my_role: permission_level 반환으로 변경',
        'RLS 정책 전면 업데이트: get_permission_rank() 기반 (7개 테이블)',
        'auth.js 코어 전면 개편: PERMISSION_RANK/LABELS/EMOJI/REDIRECT 체계',
        'initPage() 숫자 기반 최소 권한 체크 지원 (배열 호환 유지)',
        'applyPermNav() 함수 추가 (data-min-perm 속성 기반)',
        'getPermRank()/requirePermission() 클라이언트 권한 비교 유틸',
        '세션 캐시 확장: userType, permissionLevel, permissionRank, isSuperAdmin',
        'activity-log.js loadAuthSession() 확장 세션 반환',
        'user-mgmt.js: user_type/permission_level 파라미터 지원',
        '전체 admin/ 페이지 initPage() 호출을 숫자 기반으로 전환',
        'student/teacher 페이지 initPage() 숫자 기반 전환',
        '사용자 관리: 계층적 관리 버튼 표시 (상위 권한자 관리 버튼 숨김)',
        '사용자 관리: 아이디(username) 컬럼 숨김 (보안 강화)',
        '대시보드: user_type 기반 통계, permission_rank 기반 퀵링크/분기',
        'register.html: user_type/permission_level 컬럼 자동 설정',
        'login.html/index.html/change-password.html: permissionLevel 기반 리디렉트'
      ]
    },
    {
      version: '2.5.0',
      date: '2026-05-27',
      title: 'TASK-012: 관리자/부서관리자 메뉴 통합',
      changes: [
        'manager/ 디렉토리 5개 페이지 삭제 (admin/으로 통합)',
        'admin/talents.html 신규 생성 (학생+교사 달란트 통합 관리, 탭 전환)',
        'admin/ 전체 페이지 통합 네비게이션 적용 (data-role 기반 역할 분기)',
        'dept_manager 로그인 시 admin/index.html로 리디렉트',
        'admin/index.html 역할별 대시보드 분기 (통계/바로가기/로그)',
        'admin/users.html dept_manager 접근 허용 (부서 스코프, 읽기 전용)',
        'admin/products.html dept_manager 접근 허용 (물품 관리)',
        'applyRoleNav() 함수 도입 (역할별 네비게이션 표시/숨김)',
        'index.html dept_manager 달란트 경로를 admin/talents.html로 변경',
        '페이지 역할 맵핑 규칙 갱신 (.cursor/rules/page-role-mapping.mdc)'
      ]
    },
    {
      version: '2.4.0',
      date: '2026-05-27',
      title: 'TASK-011: 관리자 대시보드 개선',
      changes: [
        '현재 시간 카드를 가입 대기자 수 카드로 변경 (클릭 시 사용자 관리 이동)',
        '바로가기 영역 5개로 재구성: 사용자/부서/관리자/상점/달란트 관리',
        '각 바로가기 항목에 이모지 추가',
        '시계 관련 JS 코드 제거'
      ]
    },
    {
      version: '2.3.0',
      date: '2026-05-26',
      title: 'TASK-010: 초기 비밀번호 변경 강제 + 학생 상점 인증 보호',
      changes: [
        'initPage()에 isFirstLogin 강제 리디렉트 중앙화 (권한 체크보다 우선 실행)',
        '초기 비밀번호 미변경 시 어떤 페이지든 change-password.html로 강제 이동',
        'login.html에서 기존 세션의 isFirstLogin도 change-password로 리디렉트',
        'student/shop.html을 보호 페이지로 전환 (initPage 적용)',
        'student/shop.html autoLogPageView()를 인증 후로 이동 (익명 로그 방지)'
      ]
    },
    {
      version: '2.2.0',
      date: '2026-05-26',
      title: 'TASK-009: 레거시 관리자 로그인 제거 + 통합 로그인 단일화',
      changes: [
        '메인 화면 톱니바퀴(관리자 진입점) 버튼 제거',
        'admin/login.html 레거시 파일 삭제',
        '전체 소스에서 admin/login.html 참조 제거',
        '.admin-link 미사용 CSS 제거',
        'README.md 프로젝트 구조 전면 갱신 (전 역할 페이지 반영)',
        '로그인 진입점 login.html 단일화 완료'
      ]
    },
    {
      version: '2.1.0',
      date: '2026-05-26',
      title: 'TASK-008: 관리자 페이지 접근 제어 보완 + UI 개선',
      changes: [
        'initPage() 역할 체크 실패 시 역할별 기본 페이지로 리디렉트 (로그인 페이지 대신)',
        'CSS auth-ready 기반 콘텐츠 플래시 방지 (인증 전 페이지 내용 숨김)',
        '미사용 requireAuth() 함수 완전 제거 (데드 코드 정리)',
        '부서 관리 화면 역할별 인원 분리 표시 (관리자/부서관리자/교사/학생)',
        '관리자 관리 페이지에 admin + dept_manager 통합 표시 및 필터',
        'admin 전용 상품 관리 페이지 (admin/products.html) 신설',
        '권한별 중복 페이지 규칙 문서화 (.cursor/rules/page-role-mapping.mdc)'
      ]
    },
    {
      version: '2.0.0',
      date: '2026-05-26',
      title: 'TASK-007: DB 보안 구조 전면 개선',
      changes: [
        'Supabase Auth 도입 - bcrypt 기반 안전한 비밀번호 관리',
        'profiles 테이블 신설 - auth.users 연동',
        'admin_users 직접 접근 완전 차단 (RLS USING false)',
        '클라이언트 SHA-256 해시 제거 - 서버 측 bcrypt로 전환',
        'SECURITY DEFINER RPC 함수 도입 (admin_create_user, admin_update_user, admin_delete_user, admin_reset_password, admin_list_users)',
        'get_my_profile / change_my_password / check_username_available 보안 함수',
        'give_talent / use_talent 함수 권한 검증 강화',
        '전체 테이블 RLS 정책 재설계 (profiles, talent_transactions, products, departments, activity_logs, reports, registration_requests)',
        '프론트엔드 전면 개편 - Supabase Auth signInWithPassword 기반 로그인',
        '모든 페이지 async initPage() 패턴 적용',
        'sessionStorage → Supabase Auth + profile cache 이중 구조',
        'anon key로 password_hash 조회 불가 검증 완료'
      ]
    },
    {
      version: '1.6.0',
      date: '2026-05-26',
      title: 'TASK-007: 모바일 반응형 개선 + 로그 일괄 처리',
      changes: [
        '관리자 페이지 모바일 반응형 대폭 개선 (네비, 테이블, 카드, 모달)',
        '900px 이하: 네비게이션 줄바꿈, 폰트 축소',
        '640px 이하: 카드 2열, 테이블 가로스크롤, 필터 축소',
        '로그 일괄 완료처리 기능 (사유 입력 + 전체 미확인 로그 일괄 처리)'
      ]
    },
    {
      version: '1.5.0',
      date: '2026-05-26',
      title: 'TASK-006: 계정 등록 신청 및 부서 필수 선택',
      changes: [
        '계정 등록 신청 페이지 (register.html)',
        '로그인 페이지에서 신청 페이지 링크 연결',
        '역할 선택 (학생/교사/부서관리자) + 부서 필수 선택',
        '아이디 중복/신청 중복 검증',
        '관리자 사용자 관리에 신청 내역 섹션 추가',
        '신청 승인 (자동 계정 생성) / 거부 (사유 입력) 기능',
        '계정 등록/수정 시 소속 부서 필수 선택',
        '부서 관리자 담당 부서 필수 선택',
        'registration_requests 테이블 추가'
      ]
    },
    {
      version: '1.4.0',
      date: '2026-05-26',
      title: 'TASK-005: 사용자 관리 및 역할 배지',
      changes: [
        '관리자 사용자 관리 페이지 (등록/수정/삭제/권한변경/비밀번호초기화)',
        '역할별 통계 대시보드 (전체/관리자/부서관리자/교사/학생)',
        '역할별 필터링 조회',
        '모든 페이지 역할 배지 (이모지+텍스트+클릭 링크)',
        '관리자 클릭 → 관리자 페이지 이동',
        '부서관리자 클릭 → 부서 관리 페이지 이동',
        '교사/학생 클릭 → 해당 달란트 페이지 이동'
      ]
    },
    {
      version: '1.3.0',
      date: '2026-05-26',
      title: 'TASK-004: 버전 관리 시스템',
      changes: [
        '버전 관리 시스템 도입 (version.js)',
        '모든 페이지 하단에 버전 표시',
        '관리자 버전 이력 조회 페이지',
        '보고서 체계 정비'
      ]
    },
    {
      version: '1.2.0',
      date: '2026-05-26',
      title: 'TASK-003: 상품 이미지 및 메인 화면 개선',
      changes: [
        '상품 이미지 URL 지원 (products 테이블 image_url 컬럼)',
        'Supabase Storage 파일 업로드 (Talents_Items 버킷)',
        '물품 관리 페이지 드래그앤드롭 이미지 업로드 UI',
        '학생/교사 상점 이미지 표시',
        '메인 화면 카드 링크 연결 (달란트적립, 상품구매, 내달란트)',
        '달란트 적립 방법 안내 페이지 (earn-talents.html)',
        '관리자 상점 조회 페이지 (학생/교사/전체 탭 전환)'
      ]
    },
    {
      version: '1.1.0',
      date: '2026-05-26',
      title: 'TASK-002: 역할별 계정 시스템 및 페이지 구현',
      changes: [
        '4단계 역할 구분 (관리자, 부서관리자, 교사, 학생)',
        '역할별 페이지 구현 (학생/교사/부서관리자 전용)',
        '달란트 상점 (학생용/교사용 분리)',
        '달란트 내역 조회 페이지',
        '부서 관리자 기능 (학생/교사 계정 관리, 달란트 관리, 물품 관리)',
        '관리자 기능 확장 (부서 관리, 관리자 계정 관리)',
        'RPC 함수 (verify_user, give_talent, use_talent)',
        '통합 로그인 페이지'
      ]
    },
    {
      version: '1.0.0',
      date: '2026-05-25',
      title: 'TASK-001: 초기 구축',
      changes: [
        '환영 메인 페이지 구현',
        '관리자 로그인/패스워드 변경 시스템',
        '관리자 대시보드 (보고서, 로그 조회)',
        'Supabase 연동 및 CRUD 환경 구성',
        '활동 로그 시스템 (레벨별, KST 시간, 미확인 ERROR 알림)',
        'GitHub Pages 배포 환경 구성'
      ]
    }
  ]
};

function getVersion() { return APP_VERSION.current; }
function getVersionHistory() { return APP_VERSION.history; }

function renderVersionBadge() {
  document.querySelectorAll('.version-badge').forEach(el => {
    el.textContent = `v${APP_VERSION.current}`;
    el.title = `최종 업데이트: ${APP_VERSION.date}`;
  });
  document.querySelectorAll('.page-footer p, .footer p').forEach(el => {
    if (!el.querySelector('.version-badge')) {
      el.innerHTML += ` <span class="version-badge" title="최종 업데이트: ${APP_VERSION.date}" style="font-size:0.75rem;background:rgba(108,92,231,0.1);padding:0.15rem 0.5rem;border-radius:50px;color:#6c5ce7;font-weight:600;margin-left:0.3rem;">v${APP_VERSION.current}</span>`;
    }
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', renderVersionBadge);
} else {
  renderVersionBadge();
}
