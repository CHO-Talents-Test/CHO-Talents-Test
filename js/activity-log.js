/**
 * Activity Log Module
 * 모든 페이지에서 사용하는 공통 로그 기록/조회 모듈
 */

const LOG_LEVELS = ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL', 'CRITICAL'];
const ERROR_LEVELS = ['ERROR', 'FATAL', 'CRITICAL'];
const SLACK_ALERT_LEVELS = ['WARN', 'ERROR', 'FATAL', 'CRITICAL'];
const LOG_NO_ACCOUNT = '계정 없음';

let _logAlertLastSent = {};
const _LOG_ALERT_THROTTLE_MS = 5000;
let _logWriteLastSeen = {};
const _LOG_WRITE_DEDUPE_MS = 5000;
const _logUserLookupCache = {};
const _logDepartmentLookupCache = {};

function closeOpenActionMenus() {
  if (typeof document === 'undefined') return;
  document.querySelectorAll('.mgmt-menu.show, .notice-mgmt-menu.show').forEach(menu => {
    menu.classList.remove('show');
  });
}

if (typeof document !== 'undefined' && !window.__choActionMenuCloserInstalled) {
  window.__choActionMenuCloserInstalled = true;
  document.addEventListener('click', function(event) {
    const action = event.target && event.target.closest
      ? event.target.closest('.mgmt-menu a, .mgmt-menu button, .notice-mgmt-menu a, .notice-mgmt-menu button')
      : null;
    if (action) closeOpenActionMenus();
  }, true);
}

function _stableStringifyForLog(value) {
  if (value == null || typeof value !== 'object') return String(value);
  if (Array.isArray(value)) return '[' + value.map(_stableStringifyForLog).join(',') + ']';
  return '{' + Object.keys(value).sort().map(key => key + ':' + _stableStringifyForLog(value[key])).join(',') + '}';
}

function _shouldSkipDuplicateLog(level, action, page, details) {
  if (!SLACK_ALERT_LEVELS.includes(level)) return false;
  const key = [level, action, page || '', _stableStringifyForLog(details || {})].join('|');
  const now = Date.now();
  if (_logWriteLastSeen[key] && now - _logWriteLastSeen[key] < _LOG_WRITE_DEDUPE_MS) return true;
  _logWriteLastSeen[key] = now;
  return false;
}

function _sendLogAlertDirect(level, action, page, details) {
  if (window.CHO_TALENTS_CONFIG?.notifications?.slackEnabled !== true) return;
  if (!_sb) return;
  var key = 'log_alert_' + level + '_' + action;
  var now = Date.now();
  if (_logAlertLastSent[key] && now - _logAlertLastSent[key] < _LOG_ALERT_THROTTLE_MS) return;
  _logAlertLastSent[key] = now;
  var actorAccount = (details && (details.logUserAccount || details.actorAccount || details._userAccount || details._username)) || LOG_NO_ACCOUNT;
  var actorName = (details && (details.logUserName || details.actorName || details._userName || details._displayName)) || actorAccount || LOG_NO_ACCOUNT;
  var safeDetails = (typeof getDisplayLogDetails === 'function') ? getDisplayLogDetails(details || {}) : (details || {});
  _sb.functions.invoke('slack-notify', {
    body: {
      type: 'log_alert',
      data: {
        '레벨': level,
        '액션': getActionLabel(action),
        '액션코드': action,
        '페이지': page || window.location.pathname,
        '사용자계정': actorAccount,
        '사용자이름': actorName,
        '상세': safeDetails
      }
    }
  }).catch(function(err) {
    console.warn('[LogAlert] Slack notify failed:', err);
  });
}

const ACTION_LABELS = {
  PAGE_VIEW: '페이지 조회',
  JS_ERROR: 'JS 오류',
  RESOURCE_LOAD_FAIL: '리소스 로드 실패',
  PROMISE_REJECTION: '비동기 오류',
  CONNECTION_FAIL: '연결 실패',
  APP_VERSION_STALE_SESSION: '구버전 세션 감지',
  // 사용자
  USER_CREATE: '사용자 등록',
  USER_CREATE_FAIL: '사용자 등록 실패',
  USER_CREATE_DENIED: '사용자 등록 거부',
  USER_CREATE_ERROR: '사용자 등록 오류',
  USER_UPDATE: '사용자 수정',
  USER_UPDATE_FAIL: '사용자 수정 실패',
  USER_UPDATE_DENIED: '사용자 수정 거부',
  USER_UPDATE_ERROR: '사용자 수정 오류',
  SLACK_NOTIFY_FAIL: 'Slack 알림 전송 실패',
  USER_DELETE: '사용자 삭제',
  USER_DELETE_FAIL: '사용자 삭제 실패',
  USER_DELETE_DENIED: '사용자 삭제 거부',
  USER_DELETE_ERROR: '사용자 삭제 오류',
  USER_PW_RESET: '비밀번호 초기화',
  USER_PW_RESET_FAIL: '비밀번호 초기화 실패',
  USER_ID_CHECK_FAIL: '아이디 중복 확인 실패',
  USER_ID_CHECK_DUPLICATE: '아이디 중복',
  PASSWORD_RESET: '비밀번호 초기화',
  PASSWORD_RESET_FAIL: '비밀번호 초기화 실패',
  PASSWORD_RESET_DENIED: '비밀번호 초기화 거부',
  PASSWORD_RESET_ERROR: '비밀번호 초기화 오류',
  // 등록
  REGISTER_REQUEST: '가입 신청',
  REGISTER_REQUEST_FAIL: '가입 신청 실패',
  REGISTER_APPROVE: '가입 승인',
  REGISTER_APPROVE_FAIL: '가입 승인 실패',
  REGISTER_REJECT: '가입 거부',
  BULK_REGISTER: '학생 일괄 등록',
  // 인증
  LOGIN_SUCCESS: '로그인 성공',
  LOGIN_FAIL: '로그인 실패',
  LOGIN_ERROR: '로그인 오류',
  LOGIN_PENDING_APPROVAL: '가입 승인 대기',
  AUTH_SESSION_MISSING: '인증 세션 없음',
  AUTH_PROFILE_LOAD_FAIL: '인증 프로필 조회 실패',
  AUTH_REDIRECT: '인증/권한 리디렉트',
  AUTH_PAGE_ACCESS_CHECK_FAIL: '페이지 접근 권한 확인 실패',
  QR_LOCATION_PERMISSION_BLOCKED: 'QR 위치 권한 차단',
  LOGOUT: '로그아웃',
  PASSWORD_CHANGE: '비밀번호 변경',
  PASSWORD_CHANGE_FAIL: '비밀번호 변경 실패',
  PASSWORD_CHANGE_ERROR: '비밀번호 변경 오류',
  // 부서
  DEPT_CREATE: '부서 등록',
  DEPT_CREATE_FAIL: '부서 등록 실패',
  DEPT_CREATE_ERROR: '부서 등록 오류',
  DEPT_UPDATE: '부서 수정',
  DEPT_UPDATE_FAIL: '부서 수정 실패',
  DEPT_UPDATE_ERROR: '부서 수정 오류',
  DEPT_DELETE: '부서 삭제',
  DEPT_DELETE_FAIL: '부서 삭제 실패',
  DEPT_DELETE_ERROR: '부서 삭제 오류',
  DEPT_DEACTIVATE: '부서 비활성화',
  DEPT_TRANSFER_IMMEDIATE: '부서 즉시 이동',
  DEPT_TRANSFER_IMMEDIATE_FAIL: '부서 즉시 이동 실패',
  DEPT_TRANSFER_REQUEST: '부서 이동 요청',
  DEPT_TRANSFER_REQUEST_FAIL: '부서 이동 요청 실패',
  DEPT_TRANSFER_APPROVE: '부서 이동 승인',
  DEPT_TRANSFER_REJECT: '부서 이동 거부',
  MANAGER_UPDATE: '관리자 수정',
  MANAGER_UPDATE_FAIL: '관리자 수정 실패',
  MANAGER_PROMOTE: '관리자 승격',
  MANAGER_PROMOTE_FAIL: '관리자 승격 실패',
  // 달란트
  TALENT_GIVE: '달란트 지급',
  TALENT_GIVE_FAIL: '달란트 지급 실패',
  TALENT_GIVE_DENIED: '달란트 지급 거부',
  TALENT_GIVE_ERROR: '달란트 지급 오류',
  TALENT_GIVE_ITEM: '달란트 항목 지급',
  TALENT_GIVE_ITEM_FAIL: '달란트 항목 지급 실패',
  TALENT_GIVE_ITEM_DENIED: '달란트 항목 지급 거부',
  TALENT_GIVE_ITEM_ERROR: '달란트 항목 지급 오류',
  TALENT_GIVE_ITEMS: '달란트 일괄 지급',
  TALENT_EXCEPTION_REQUEST: '예외 지급 요청',
  TALENT_EXCEPTION_REQUEST_FAIL: '예외 지급 요청 실패',
  TALENT_EXCEPTION_REQUEST_ERROR: '예외 지급 요청 오류',
  TALENT_EXCEPTION_APPROVE: '예외 지급 승인',
  TALENT_EXCEPTION_APPROVE_FAIL: '예외 지급 승인 실패',
  TALENT_EXCEPTION_REJECT: '예외 지급 거부',
  TALENT_EXCEPTION_REQUEST_UPDATE_FAIL: '예외 지급 요청 수정 실패',
  TALENT_EXCEPTION_REQUEST_UPDATE_ERROR: '예외 지급 요청 수정 오류',
  TALENT_MANUAL_GIVE: '달란트 수동 지급',
  TALENT_MANUAL_GIVE_FAIL: '달란트 수동 지급 실패',
  TALENT_MANUAL_GIVE_ERROR: '달란트 수동 지급 오류',
  TALENT_USE: '달란트 사용',
  TALENT_USE_FAIL: '달란트 사용 실패',
  TALENT_USE_DENIED: '달란트 사용 거부',
  TALENT_USE_ERROR: '달란트 사용 오류',
  TALENT_RETURN: '달란트 반환',
  TALENT_RETURN_FAIL: '달란트 반환 실패',
  TALENT_RETURN_DENIED: '달란트 반환 거부',
  TALENT_RETURN_ERROR: '달란트 반환 오류',
  ATTENDANCE_GIVE: '출석 달란트 지급',
  ATTENDANCE_CANCEL: '출석 달란트 취소',
  TALENT_ITEM_CANCEL: '달란트 항목 취소',
  TALENT_ITEM_CREATE: '달란트 항목 등록',
  TALENT_ITEM_CREATE_FAIL: '달란트 항목 등록 실패',
  TALENT_ITEM_UPDATE: '달란트 항목 수정',
  TALENT_ITEM_UPDATE_FAIL: '달란트 항목 수정 실패',
  TALENT_ITEM_TOGGLE: '달란트 항목 활성 토글',
  TALENT_ITEM_QUICKBTN: '달란트 퀵버튼 설정',
  qr_create: 'QR 코드 생성',
  QR_CREATE_FAIL: 'QR 코드 생성 실패',
  QR_CREATE_NO_RESULT: 'QR 코드 생성 결과 없음',
  QR_CREATE_ERROR: 'QR 코드 생성 오류',
  qr_edit: 'QR 코드 수정',
  qr_toggle: 'QR 코드 토글',
  qr_scan: 'QR 달란트 수령',
  // 상품/주문
  PRODUCT_CREATE: '상품 등록',
  PRODUCT_BULK_CREATE: '상품 일괄 등록',
  PRODUCT_CREATE_FAIL: '상품 등록 실패',
  PRODUCT_CREATE_ERROR: '상품 등록 오류',
  PRODUCT_CATEGORY_CREATE: '상품 카테고리 등록',
  PRODUCT_CATEGORY_CREATE_FAIL: '상품 카테고리 등록 실패',
  PRODUCT_CATEGORY_CREATE_ERROR: '상품 카테고리 등록 오류',
  PRODUCT_CATEGORY_UPDATE: '상품 카테고리 수정',
  PRODUCT_CATEGORY_UPDATE_FAIL: '상품 카테고리 수정 실패',
  PRODUCT_CATEGORY_UPDATE_ERROR: '상품 카테고리 수정 오류',
  PRODUCT_CATEGORY_DELETE: '상품 카테고리 삭제',
  PRODUCT_CATEGORY_DELETE_FAIL: '상품 카테고리 삭제 실패',
  PRODUCT_CATEGORY_DELETE_ERROR: '상품 카테고리 삭제 오류',
  PRODUCT_UPDATE: '상품 수정',
  PRODUCT_UPDATE_FAIL: '상품 수정 실패',
  PRODUCT_UPDATE_ERROR: '상품 수정 오류',
  PRODUCT_IMAGE_UPDATE: '상품 이미지 연결',
  PRODUCT_IMAGE_UPDATE_FAIL: '상품 이미지 연결 실패',
  PRODUCT_IMAGE_UPDATE_ERROR: '상품 이미지 연결 오류',
  PRODUCT_DELETE: '상품 삭제',
  PRODUCT_DELETE_FAIL: '상품 삭제 실패',
  PRODUCT_DELETE_ERROR: '상품 삭제 오류',
  PRODUCT_DEACTIVATE: '상품 비활성화',
  PRODUCT_DEACTIVATE_FAIL: '상품 비활성화 실패',
  PRODUCT_DEACTIVATE_ERROR: '상품 비활성화 오류',
  PRODUCT_SOFT_DELETE: '상품 비활성화',
  PRODUCT_SUGGESTION_CREATE: '상품 추천 등록',
  PRODUCT_SUGGESTION_CREATE_FAIL: '상품 추천 등록 실패',
  PRODUCT_SUGGESTION_ADOPT: '추천 상품 채택',
  PRODUCT_SUGGESTION_REJECT: '추천 상품 불채택',
  PRODUCT_SUGGESTION_CLOSE: '추천 상품 투표 종료',
  PRODUCT_SUGGESTION_ADOPTION_TALENT: '상품 추천 채택 달란트 지급',
  IMAGE_UPLOAD: '이미지 업로드',
  IMAGE_COMPRESS_FAIL: '이미지 압축 실패',
  IMAGE_UPLOAD_FAIL: '이미지 업로드 실패',
  IMAGE_UPLOAD_ERROR: '이미지 업로드 오류',
  IMAGE_DELETE_FAIL: '이미지 삭제 실패',
  ORDER_REQUEST_SUCCESS: '상품 구매 신청',
  ORDER_REQUEST_FAIL: '상품 구매 신청 실패',
  ORDER_REQUEST_DENIED: '상품 구매 신청 거부',
  ORDER_REQUEST_ERROR: '상품 구매 신청 오류',
  ORDER_INSUFFICIENT_BALANCE: '달란트 부족으로 구매 불가',
  PROXY_ORDER_SUCCESS: '대리 구매 신청',
  PROXY_ORDER_FAIL: '대리 구매 신청 실패',
  PROXY_ORDER_DENIED: '대리 구매 신청 거부',
  PROXY_ORDER_ERROR: '대리 구매 신청 오류',
  PROXY_USER_LOAD_FAIL: '대리 구매 사용자 조회 실패',
  PROXY_USER_LOAD_ERROR: '대리 구매 사용자 조회 오류',
  order_cancel: '주문 취소',
  ORDER_STATUS_CHANGE: '주문 상태 변경',
  ORDER_STATUS_CHANGE_FAIL: '주문 상태 변경 실패',
  ORDER_STATUS_CHANGE_ERROR: '주문 상태 변경 오류',
  ORDER_REVERT: '주문 상태 되돌리기',
  ORDER_REVERT_FAIL: '주문 상태 되돌리기 실패',
  ORDER_REVERT_ERROR: '주문 상태 되돌리기 오류',
  ORDER_PURCHASE_CANCEL: '구매 취소 처리',
  ORDER_PURCHASE_CANCEL_FAIL: '구매 취소 처리 실패',
  ORDER_PURCHASE_CANCEL_ERROR: '구매 취소 처리 오류',
  ORDER_PURCHASE_CONFIRM: '구매 확정',
  ORDER_PURCHASE_CONFIRM_FAIL: '구매 확정 실패',
  ORDER_PURCHASE_CONFIRM_DENIED: '구매 확정 거부',
  ORDER_PURCHASE_CONFIRM_ERROR: '구매 확정 오류',
  ORDER_BULK_PREPARE: '일괄 상품 준비',
  ORDER_BULK_PREPARE_ITEM_FAIL: '일괄 상품 준비 항목 실패',
  ORDER_BULK_PURCHASE: '일괄 구매 확정',
  ORDER_BULK_PURCHASE_ITEM_FAIL: '일괄 구매 확정 항목 실패',
  ORDER_BULK_PURCHASE_DENIED: '일괄 구매 확정 거부',
  ORDER_BULK_DELIVER: '일괄 상품 지급',
  ORDER_BULK_DELIVER_ITEM_FAIL: '일괄 상품 지급 항목 실패',
  PURCHASE_LOAD_FAIL: '구매 데이터 조회 실패',
  PURCHASE_SCOPE_USERS_FAIL: '구매 범위 사용자 조회 실패',
  SHOP_PROFILE_FALLBACK: '상점 프로필 폴백',
  MY_ORDERS_FETCH: '내 주문 조회 실패',
  MY_TALENT_PENDING_QUERY: '대기 달란트 조회 오류',
  MY_TALENT_ORDERS_QUERY: '주문 조회 오류',
  ORDER_CANCEL: '주문 취소',
  ORDER_CANCEL_REFUND_FAIL: '주문 취소 환불 실패',
  // Q&A
  QNA_CREATE: '질문 등록',
  QNA_ANSWER: '답변 등록',
  QNA_COMMENT: '댓글 등록',
  QNA_DELETE: 'Q&A 삭제',
  QNA_FAQ_SET: 'FAQ 설정',
  // 공지
  ANNOUNCEMENT_VIEW: '공지 조회',
  ANNOUNCEMENT_READ_STATUS_VIEW: '공지 열람 현황 조회',
  ANNOUNCEMENT_CREATE: '공지 등록',
  ANNOUNCEMENT_CREATE_FAIL: '공지 등록 실패',
  ANNOUNCEMENT_UPDATE: '공지 수정',
  ANNOUNCEMENT_UPDATE_FAIL: '공지 수정 실패',
  ANNOUNCEMENT_TOGGLE: '공지 활성 토글',
  ANNOUNCEMENT_TOGGLE_FAIL: '공지 활성 토글 실패',
  ANNOUNCEMENT_DELETE: '공지 삭제',
  ANNOUNCEMENT_DELETE_FAIL: '공지 삭제 실패',
  ANNOUNCEMENT_LOAD_FAIL: '공지 조회 실패',
  ANNOUNCEMENT_DISMISS: '공지 다시 열지 않음',
  ANNOUNCEMENT_DISMISS_FAIL: '공지 다시 열지 않음 실패',
  ANNOUNCEMENT_SAVE_ERROR: '공지 저장 오류',
  // 로그 관리
  LOG_ACKNOWLEDGED: '로그 확인',
  LOG_BULK_ACK: '로그 일괄 확인',
  LOG_RANGE_DELETE: '로그 범위 삭제',
  LOG_RANGE_DELETE_FAIL: '로그 범위 삭제 실패',
  LOG_RANGE_DELETE_ERROR: '로그 범위 삭제 오류',
  LOG_SELECT_DELETE: '로그 선택 삭제',
  LOG_SELECT_DELETE_FAIL: '로그 선택 삭제 실패',
  LOG_SELECT_DELETE_ERROR: '로그 선택 삭제 오류',
  LOG_RESTORE: '로그 복원',
  LOG_RESTORE_FAIL: '로그 복원 실패',
  LOG_RETENTION_CLEANUP: '180일 초과 로그 실제 삭제',
  LOG_RETENTION_CLEANUP_FAIL: '180일 초과 로그 실제 삭제 실패',
  // 권한/설정
  ROLE_ACCESS_UPDATE: '페이지 접근 권한 변경',
  ROLE_ACCESS_UPDATE_FAIL: '페이지 접근 권한 변경 실패',
  ROLE_FEATURE_UPDATE: '페이지 기능 권한 변경',
  ROLE_FEATURE_UPDATE_FAIL: '페이지 기능 권한 변경 실패',
  PAGE_PERM_UPDATE: '페이지 권한 설정 변경',
  REPORT_VIEW: '보고서 조회',
  REPORT_SAVE: '보고서 저장',
  REPORT_SAVE_FAIL: '보고서 저장 실패',
  REPORT_SAVE_ERROR: '보고서 저장 오류',
  REPORT_DELETE: '보고서 삭제',
  REPORT_DELETE_FAIL: '보고서 삭제 실패',
  REPORT_DELETE_ERROR: '보고서 삭제 오류',
  REPORT_SEED: '보고서 시드 등록',
  REPORT_SEED_FAIL: '보고서 시드 등록 실패',
  REPORT_SEED_ERROR: '보고서 시드 등록 오류',
  SERVICE_USAGE_COLLECT_FAIL: '서비스 사용량 수집 실패',
  SERVICE_USAGE_RETENTION_CLEANUP: '서비스 통계 180일 초과 정리',
  SERVICE_USAGE_RETENTION_CLEANUP_FAIL: '서비스 통계 180일 초과 정리 실패',
};

function getActionLabel(action) {
  const fallback = ACTION_LABELS[action] || action;
  if (typeof getCodeLabel !== 'function') return fallback;
  const codeLabel = getCodeLabel('activity_logs.action', action, fallback);
  // 코드북 반영 전의 영문/코드값이 화면에 그대로 노출되지 않도록,
  // 이미 정의된 한글 기본 라벨을 우선 사용한다.
  if (fallback !== action && (!codeLabel || codeLabel === action || !/[가-힣]/.test(codeLabel))) {
    return fallback;
  }
  return codeLabel;
}

const LOG_DETAIL_KEY_LABELS = {
  _actionKey: '작업코드',
  _actionEn: '작업코드',
  _actionLabel: '작업명',
  _actionKo: '작업명',
  _userAccount: '작업자 아이디',
  _username: '작업자 아이디',
  _userName: '작업자',
  _displayName: '작업자',
  logUserAccount: '사용자 계정',
  logUserName: '사용자 이름',
  _client: '클라이언트',
  client: '클라이언트',
  sourceTable: '조회 테이블',
  targetAccount: '대상 아이디',
  targetName: '대상',
  targetDisplayName: '대상 이름',
  targetUser: '대상 사용자',
  targetUserId: '대상 사용자 ID',
  targetDepartmentId: '대상 부서 ID',
  targetDepartmentName: '대상 부서',
  actorAccount: '작업자 아이디',
  actorName: '작업자',
  actorId: '작업자 ID',
  action: '작업',
  id: 'ID',
  actionKey: '작업코드',
  actionLabel: '작업명',
  actionCode: '작업코드',
  operation: '처리',
  type: '구분',
  message: '메시지',
  stack: '오류 스택',
  details: '상세',
  detail: '상세',
  error: '오류',
  errorKind: '오류 유형',
  errorName: '오류 이름',
  errorFingerprint: '오류 식별값',
  notificationType: '알림 유형',
  notificationStatus: '알림 응답 상태',
  requestedChanges: '수정 요청 항목',
  reason: '사유',
  target: '대상',
  targetName: '대상',
  displayName: '표시 이름',
  name: '이름',
  username: '아이디',
  userName: '사용자 이름',
  userId: '사용자 ID',
  authUserId: '인증 사용자 ID',
  authSessionUserId: '인증 세션 사용자 ID',
  authSessionAccount: '인증 세션 계정',
  authSessionRole: '인증 세션 역할',
  authSessionIsAnonymous: '익명 인증 세션 여부',
  authSessionExpiresAt: '인증 세션 만료 시각',
  requestId: '요청 ID',
  user_type: '사용자 유형',
  userType: '사용자 유형',
  class_number: '반',
  classNumber: '반',
  roleKey: '역할',
  permissionKey: '권한',
  permissionLevel: '권한 등급',
  permissionRank: '권한 순위',
  cachedUsername: '캐시된 아이디',
  cachedDisplayName: '캐시된 표시 이름',
  cachedPermissionLevel: '캐시된 권한 등급',
  cachedPermissionRank: '캐시된 권한 순위',
  hasCachedSession: '캐시 세션 여부',
  cachedSessionIdMatchesAuthUser: '캐시와 인증 사용자 ID 일치',
  cachedAccountMatchesAuthUser: '캐시와 인증 계정 일치',
  browserOnline: '브라우저 온라인 상태',
  networkEffectiveType: '네트워크 유형',
  networkRttMs: '네트워크 RTT(ms)',
  networkDownlinkMbps: '네트워크 다운링크(Mbps)',
  networkSaveData: '데이터 절약 모드',
  profileRpcName: '프로필 RPC',
  profileRpcOutcome: '프로필 RPC 결과',
  profileRpcDurationMs: '프로필 RPC 소요 시간(ms)',
  profileRpcErrorName: '프로필 RPC 오류 유형',
  profileRpcErrorMessage: '프로필 RPC 오류 메시지',
  profileRpcErrorCode: '프로필 RPC 오류 코드',
  profileRpcErrorStatus: '프로필 RPC HTTP 상태',
  profileRpcErrorDetails: '프로필 RPC 오류 상세',
  profileRpcErrorHint: '프로필 RPC 오류 힌트',
  profileFallbackAttempted: '프로필 직접 조회 시도',
  profileFallbackQuery: '프로필 직접 조회 방식',
  profileFallbackRequestedUserId: '프로필 직접 조회 사용자 ID',
  profileFallbackOutcome: '프로필 직접 조회 결과',
  profileFallbackDurationMs: '프로필 직접 조회 소요 시간(ms)',
  profileFallbackErrorName: '프로필 직접 조회 오류 유형',
  profileFallbackErrorMessage: '프로필 직접 조회 오류 메시지',
  profileFallbackErrorCode: '프로필 직접 조회 오류 코드',
  profileFallbackErrorStatus: '프로필 직접 조회 HTTP 상태',
  profileFallbackErrorDetails: '프로필 직접 조회 오류 상세',
  profileFallbackErrorHint: '프로필 직접 조회 오류 힌트',
  lastActivityAt: '마지막 활동 일시',
  idleExpired: '유휴 만료 여부',
  page: '페이지',
  pageId: '페이지 ID',
  pageName: '페이지명',
  logLevel: '로그 레벨',
  logPage: '로그 발생 페이지',
  loggedAt: '로그 작성 일시',
  filename: '파일명',
  lineno: '줄 번호',
  colno: '열 번호',
  url: 'URL',
  resourceUrl: '리소스 URL',
  resourceType: '리소스 유형',
  resourceHasQuery: '리소스 URL 쿼리 포함 여부',
  resourceId: '리소스 요소 ID',
  resourceRel: '리소스 rel',
  resourceLoading: '리소스 로딩 방식',
  resourceCrossOrigin: '리소스 CORS 설정',
  imageUrl: '이미지 URL',
  imageMimeType: '이미지 MIME',
  imageExtension: '이미지 확장자',
  imageSizeBytes: '이미지 크기(Byte)',
  imageSizeLabel: '이미지 크기',
  filePath: '파일 경로',
  currentVersion: '현재 버전',
  latestVersion: '최신 버전',
  sessionVersion: '세션 버전',
  currentPageVersion: '현재 페이지 버전',
  redirectTarget: '이동 대상',
  requestedPage: '요청 페이지',
  dateFrom: '시작일',
  dateTo: '종료일',
  level: '레벨',
  logId: '로그 ID',
  count: '건수',
  total: '전체',
  totalCount: '전체 건수',
  successCount: '성공 건수',
  failCount: '실패 건수',
  failedCount: '실패 건수',
  givenCount: '지급 건수',
  requestCount: '요청 건수',
  items: '항목 목록',
  itemId: '항목 ID',
  itemName: '항목명',
  managers: '담당자',
  description: '설명',
  taskId: '작업 ID',
  taskTitle: '작업 제목',
  reportId: '보고서 ID',
  product_id: '상품 ID',
  productId: '상품 ID',
  product_name: '상품명',
  productName: '상품명',
  title: '제목',
  questionId: '질문 ID',
  answererName: '답변자',
  isFaq: 'FAQ 여부',
  noticeId: '공지 ID',
  code: '코드',
  field: '필드',
  hasImage: '이미지 여부',
  targetType: '대상 유형',
  changeSummary: '변경 내역',
  changes: '변경 항목',
  targetId: '대상 ID',
  fieldLabel: '항목',
  permissionLabel: '권한',
  category: '카테고리',
  categoryCode: '카테고리 코드',
  categoryName: '카테고리명',
  emoji: '이모지',
  sort_order: '표시 순번',
  sortOrder: '표시 순번',
  displayOrder: '표시 순번',
  max_uses: '최대 사용 횟수',
  mode: '모드',
  new_state: '변경 상태',
  qr_id: 'QR ID',
  qrCodeId: 'QR 코드 ID',
  qrId: 'QR ID',
  orderId: '주문 ID',
  orderNo: '주문번호',
  cutoffAt: '기준 일시',
  oldState: '이전 상태',
  status: '상태',
  state: '상태',
  oldStatus: '이전 상태',
  newStatus: '변경 상태',
  amount: '수량',
  balance: '잔액',
  price: '가격',
  pending: '대기 달란트',
  available: '사용 가능 달란트',
  talentBalance: '달란트 잔액',
  talent_balance: '달란트 잔액',
  pendingTalent: '보류 달란트',
  pending_talent: '보류 달란트',
  requestId: '요청 ID',
  talentItemId: '달란트 항목 ID',
  targetUser: '대상 사용자',
  txnId: '거래 ID',
  department: '부서',
  departmentId: '부서 ID',
  departmentName: '부서명',
  fromDept: '이전 부서',
  toDept: '이동 부서',
  fromDeptName: '이전 부서명',
  toDeptName: '이동 부서명',
  success: '성공',
  fail: '실패',
  failed: '실패',
  old: '이전 값',
  new: '변경 값',
  oldValue: '이전 값',
  newValue: '변경 값',
  before: '이전 값',
  after: '변경 값',
  is_active: '활성 상태',
  isActive: '활성 상태',
  is_deleted: '삭제 상태',
  isDeleted: '삭제 상태',
  acknowledgedBy: '확인자',
  acknowledgedAt: '확인 일시',
  resolutionNote: '해결 사항',
  ip: 'IP',
  browser: '브라우저',
  os: 'OS',
  screenRes: '화면 해상도',
  windowSize: '창 크기',
  deviceType: '기기 유형',
  language: '언어',
  userAgent: '사용자 에이전트',
  현재페이지버전: '현재 페이지 버전',
  최신버전: '최신 버전',
  세션버전: '세션 버전',
  요청페이지: '요청 페이지',
  이동대상: '이동 대상'
};

const LOG_DETAIL_VALUE_LABELS = {
  true: '예',
  false: '아니오',
  teacher: '교사',
  student: '학생',
  admin: '관리자',
  super_admin: '최고 관리자',
  evangelist: '전도사님',
  chief: '부장 교사',
  purchase_teacher: '구매 담당 교사',
  dept_teacher: '부서 담당 교사',
  pending: '대기',
  approved: '승인',
  rejected: '거부',
  requested: '요청됨',
  preparing: '준비 중',
  purchased: '구매 완료',
  delivered: '지급 완료',
  cancelled: '취소됨',
  active: '활성',
  inactive: '비활성',
  ALL: '전체',
  desktop: '데스크톱',
  mobile: '모바일',
  tablet: '태블릿',
  Unknown: '알 수 없음',
  unknown: '알 수 없음',
  'Supabase client not initialized': 'Supabase 클라이언트 초기화 안 됨',
  'Supabase auth session error': 'Supabase 인증 세션 오류',
  'Supabase auth session exception': 'Supabase 인증 세션 예외',
  'Supabase auth session missing': 'Supabase 인증 세션 없음',
  'Profile RPC returned no profile': '프로필 RPC 결과 없음',
  'Invalid login credentials': '로그인 정보가 일치하지 않습니다',
  'TypeError: Load failed': '로드 실패',
  'Load failed': '로드 실패',
  'TypeError: Failed to fetch': '네트워크 요청에 실패했습니다',
  'Failed to fetch': '네트워크 요청에 실패했습니다',
  'Failed to send a request to the Edge Function': 'Edge Function 요청 전송 실패',
  'Edge Function returned a non-2xx status code': 'Edge Function이 오류 상태를 반환했습니다',
  TypeError: '유형 오류',
  'Script error.': '스크립트 오류',
  'User denied Geolocation': '사용자가 위치 권한을 거부했습니다',
  'Cannot coerce the result to a single JSON object': '단일 결과로 변환할 수 없습니다',
  'permission denied for table profiles': 'profiles 테이블 권한이 없습니다',
  profiles: '사용자 프로필',
  registration_requests: '가입 신청',
  talent_transactions: '달란트 거래',
  product_orders: '상품 주문',
  activity_logs: '작업 로그',
  purchase_new: '새 구매 신청',
  'Could not embed because more than one relationship was found for \'profiles\' and \'departments\'': 'profiles와 departments 사이의 관계가 둘 이상이라 자동으로 연결할 수 없습니다',
  "Try changing 'departments' to one of the following: 'departments!profiles_department_id_fkey', 'departments!profiles_managed_dept_id_fkey'. Find the desired relationship in the 'details' key.": 'profiles와 departments의 관계를 명시적으로 선택해야 합니다',
  '[object Object],[object Object]': '관계 후보 상세 정보',
  'null is not an object (evaluating \'_currentAnnouncement.id\')': '현재 공지 정보가 없어 처리할 수 없습니다',
  Unauthorized: '권한이 없습니다',
  'resource-load': '리소스 로드',
  runtime: '실행 중 오류',
  'unhandled-rejection': '처리되지 않은 비동기 오류',
  error: '오류',
  profile: '프로필 조회 완료',
  empty_result: '조회 결과 없음',
  last_activity: '마지막 활동 기준',
  idle_timer: '유휴 타이머 기준',
  visibilitychange: '탭 재활성화 기준',
  weekly_duplicate: '주간 중복 지급',
  duplicate_pending: '이미 대기 중인 요청',
  cached_session: '캐시 세션으로 복구',
  profiles_fallback: '프로필 직접 조회로 복구',
  cancel_aborted_before_partial_update: '부분 취소 방지를 위해 중단',
  'admin-dashboard': '관리자 대시보드',
  'admin-users': '사용자 관리',
  'admin-talents': '달란트 관리',
  'admin-service-stats': '서비스 통계',
  'my-talents': '내 달란트',
  'talent-receive': 'QR 달란트 수령',
  login: '로그인'
};

const LOG_DETAIL_VALUE_PATTERNS = [
  [/^Already given this item this week:\s*(.+)$/i, '이번 주에 이미 지급된 항목입니다: $1'],
  [/^permission denied for table ([\w.]+)$/i, '$1 테이블 권한이 없습니다'],
  [/^(?:Could not find the function|DB 함수를 찾을 수 없습니다)\s*:?\s*(.+?)\s+in the schema cache$/i, 'DB 함수 $1을(를) 스키마 캐시에서 찾을 수 없습니다'],
  [/^Cannot coerce the result to a single JSON object$/i, '단일 결과로 변환할 수 없습니다'],
  [/^TypeError:\s*Load failed$/i, '로드 실패'],
  [/^TypeError:\s*Failed to fetch$/i, '네트워크 요청에 실패했습니다'],
  [/^IMG 리소스 로드 실패$/i, '이미지 리소스 로드 실패'],
  [/^Script error\.$/i, '스크립트 오류']
];

const LOG_DETAIL_KEY_ALIASES = {
  오류: 'error',
  에러: 'error',
  사유: 'reason',
  대상: 'targetName',
  아이디: 'targetAccount',
  이름: 'targetName',
  요청ID: 'requestId',
  사용자: 'targetAccount',
  사용자계정: 'targetAccount',
  '사용자 계정': 'targetAccount',
  사용자아이디: 'targetAccount',
  '사용자 아이디': 'targetAccount',
  사용자이름: 'targetName',
  '사용자 이름': 'targetName',
  '대상 사용자': 'targetUser',
  대상사용자: 'targetUser',
  '대상 사용자 ID': 'targetUserId',
  대상사용자ID: 'targetUserId',
  '대상 부서 ID': 'targetDepartmentId',
  대상부서ID: 'targetDepartmentId',
  '대상 부서': 'targetDepartmentName',
  대상부서: 'targetDepartmentName',
  사용자ID: 'userId',
  항목ID: 'itemId',
  상품ID: 'productId',
  주문ID: 'orderId',
  거래ID: 'txnId',
  작업ID: 'taskId',
  보고서ID: 'reportId',
  제목: 'title',
  질문ID: 'questionId',
  답변자: 'answererName',
  FAQ여부: 'isFaq',
  상품명: 'productName',
  금액: 'amount',
  수량: 'amount',
  건수: 'count',
  총건수: 'totalCount',
  성공: 'successCount',
  실패: 'failCount',
  실패건수: 'failedCount',
  지급건수: 'givenCount',
  요청건수: 'requestCount',
  구분: 'type',
  코드: 'code',
  카테고리: 'categoryName',
  필드: 'field',
  이미지: 'hasImage',
  설명: 'description',
  유형: 'type',
  공지ID: 'noticeId',
  활성: 'isActive',
  활성여부: 'isActive',
  변경상태: 'newStatus',
  이전상태: 'oldStatus',
  이전값: 'oldValue',
  변경값: 'newValue',
  변경내역: 'changeSummary',
  권한: 'permissionLabel',
  부서: 'departmentName',
  부서명: 'departmentName',
  이전부서: 'fromDeptName',
  이동부서: 'toDeptName',
  반: 'classNumber',
  항목명: 'itemName',
  주문번호: 'orderNo',
  요청페이지: 'requestedPage',
  이동대상: 'redirectTarget',
  현재페이지버전: 'currentPageVersion',
  최신버전: 'latestVersion',
  세션버전: 'sessionVersion',
  작업: 'operation',
  작업코드: 'actionCode',
  작업명: 'actionLabel',
  작업자: 'actorName',
  '수정 요청 항목': 'requestedChanges',
  '알림 유형': 'notificationType',
  '알림 응답 상태': 'notificationStatus',
  '오류 유형': 'errorKind',
  '오류 이름': 'errorName',
  '오류 식별값': 'errorFingerprint',
  '작업자 아이디': 'actorAccount',
  페이지: 'logPage',
  레벨: 'logLevel',
  시간: 'loggedAt',
  일시: 'loggedAt',
  작성일시: 'loggedAt',
  '로그 작성 일시': 'loggedAt',
  '로그 발생 페이지': 'logPage',
  '로그 레벨': 'logLevel',
  클라이언트: 'client'
};

const LOG_TECHNICAL_DETAIL_KEYS = new Set([
  '_actionKey',
  '_actionEn',
  '_actionLabel',
  '_actionKo',
  '_userAccount',
  '_username',
  '_userName',
  '_displayName',
  '_client',
  'client',
  '클라이언트',
  'actorAccount',
  'actorName',
  'actorId',
  'username',
  'displayName',
  'userName',
  'cachedUsername',
  'authUserId',
  'actionCode',
  'actionLabel',
  'logLevel',
  'logPage',
  'loggedAt'
]);

const LOG_COMMON_DETAIL_KEYS = new Set([
  '_actionKey',
  '_actionEn',
  '_actionLabel',
  '_actionKo',
  '_userAccount',
  '_username',
  '_userName',
  '_displayName',
  '_client',
  'client',
  '클라이언트',
  'actorAccount',
  'actorName',
  'actorId',
  'username',
  'displayName',
  'userName',
  'cachedUsername',
  'authUserId',
  'actionCode',
  'actionLabel',
  'logLevel',
  'logPage',
  'loggedAt',
  'level',
  'page',
  'createdAt',
  'created_at',
  'timestamp',
  'time',
  '로그 작성 일시',
  '로그 발생 페이지',
  '로그 레벨',
  '작업',
  '작업코드',
  '작업명',
  '작업자',
  '작업자 아이디',
  '레벨',
  '페이지',
  '시간',
  '일시',
  '작성일시'
]);

function getLogDetailKeyLabel(key) {
  return LOG_DETAIL_KEY_LABELS[key] || key;
}

function _safeLogJson(value) {
  try { return JSON.stringify(value); }
  catch (e) { return String(value); }
}

function _sameLogDetailValue(a, b) {
  return _safeLogJson(a) === _safeLogJson(b);
}

function _isEmptyLogDetailValue(value) {
  if (value === undefined || value === null) return true;
  if (typeof value === 'string') return value.trim() === '';
  if (Array.isArray(value)) return value.length === 0;
  if (typeof value === 'object') return Object.keys(value).length === 0;
  return false;
}

function translateLogDetailValue(key, value) {
  if (value === null || value === undefined) return value;
  if (typeof value === 'boolean') return value ? '예' : '아니오';
  if (typeof value !== 'string') return value;

  const direct = LOG_DETAIL_VALUE_LABELS[value];
  if (direct) return direct;

  const lowerKey = String(key || '').toLowerCase();
  if ((lowerKey.includes('permission') || lowerKey === 'rolekey' || lowerKey === '권한' || lowerKey === '실제권한') && typeof getCodeLabel === 'function') {
    const label = getCodeLabel('profiles.permission_level', value, LOG_DETAIL_VALUE_LABELS[value] || value);
    if (label !== value) return label;
  }
  if ((lowerKey.includes('status') || lowerKey === '상태' || lowerKey === '변경상태') && typeof getCodeLabel === 'function') {
    const label = getCodeLabel('product_orders.status', value, LOG_DETAIL_VALUE_LABELS[value] || value);
    if (label !== value) return label;
  }
  if ((lowerKey === 'action' || lowerKey === 'actionkey') && value) {
    return getActionLabel(value);
  }

  for (const [pattern, replacement] of LOG_DETAIL_VALUE_PATTERNS) {
    if (pattern.test(value)) return value.replace(pattern, replacement);
  }
  return value;
}

function _setNormalizedLogDetail(target, key, value) {
  if (!key || _isEmptyLogDetailValue(value)) return;
  if (!Object.prototype.hasOwnProperty.call(target, key)) {
    target[key] = value;
    return;
  }
  if (_sameLogDetailValue(target[key], value)) return;
  let idx = 2;
  let nextKey = key + idx;
  while (Object.prototype.hasOwnProperty.call(target, nextKey)) {
    if (_sameLogDetailValue(target[nextKey], value)) return;
    idx += 1;
    nextKey = key + idx;
  }
  target[nextKey] = value;
}

function _normalizeLogDetailKey(key, value, context = {}) {
  const rawKey = String(key || '');
  const aliasKey = LOG_DETAIL_KEY_ALIASES[rawKey] || rawKey;

  if (LOG_COMMON_DETAIL_KEYS.has(rawKey) || LOG_COMMON_DETAIL_KEYS.has(aliasKey)) return null;
  if (rawKey.startsWith('_')) return null;

  if (aliasKey === 'action' || aliasKey === 'actionKey') {
    return value === context.action ? null : 'operation';
  }

  if ((aliasKey === 'username' || aliasKey === 'displayName' || aliasKey === 'userName') &&
      (value === context.actorAccount || value === context.actorName)) {
    return null;
  }

  if ((aliasKey === 'targetAccount' || aliasKey === 'targetName' || aliasKey === 'targetUser' || aliasKey === 'userId' || aliasKey === 'targetUserId') &&
      (value === context.actorAccount || value === context.actorName)) {
    return null;
  }

  if (aliasKey === 'authUserId' && value === context.actorAccount) return null;
  return aliasKey;
}

function normalizeLogDetailsForStorage(details, context = {}, depth = 0) {
  if (!details || typeof details !== 'object') return {};
  if (Array.isArray(details)) {
    return details
      .map(item => (item && typeof item === 'object') ? normalizeLogDetailsForStorage(item, context, depth + 1) : item)
      .filter(item => !_isEmptyLogDetailValue(item));
  }
  if (depth > 5) return details;

  const result = {};
  Object.entries(details).forEach(([key, value]) => {
    const normalizedKey = _normalizeLogDetailKey(key, value, context);
    if (!normalizedKey) return;
    let normalizedValue = value;
    if (Array.isArray(value)) {
      normalizedValue = value
        .map(item => (item && typeof item === 'object') ? normalizeLogDetailsForStorage(item, context, depth + 1) : translateLogDetailValue(normalizedKey, item))
        .filter(item => !_isEmptyLogDetailValue(item));
    } else if (value && typeof value === 'object') {
      normalizedValue = normalizeLogDetailsForStorage(value, context, depth + 1);
    } else {
      normalizedValue = translateLogDetailValue(normalizedKey, value);
    }
    _setNormalizedLogDetail(result, normalizedKey, normalizedValue);
  });
  return result;
}

function inferLogActor(session, details = {}, action = '') {
  const source = (details && typeof details === 'object' && !Array.isArray(details)) ? details : {};
  const authFailure = (source.sessionFailure && typeof source.sessionFailure === 'object')
    ? source.sessionFailure
    : ((source.세션실패 && typeof source.세션실패 === 'object') ? source.세션실패 : {});
  const targetLikeAccount = source['대상'] && typeof source['대상'] === 'string' && /^(LOGIN|LOGOUT|PASSWORD|REGISTER|AUTH_)/.test(String(action || ''))
    ? source['대상']
    : null;
  const targetAccount = source.targetAccount || source['사용자'] || source['아이디'] || targetLikeAccount || source.authSessionAccount || null;
  const targetName = source.targetName || source['사용자 이름'] || source['이름'] || source['대상'] || null;
  const isLoginAttempt = /^(LOGIN_FAIL|LOGIN_ERROR|LOGIN_PENDING_APPROVAL)$/.test(String(action || ''));
  const account = (isLoginAttempt && targetAccount) ? targetAccount : (session ? (session.username || null) : (
    source._userAccount ||
    source._username ||
    source.cachedUsername ||
    authFailure.cachedUsername ||
    source.authSessionAccount ||
    source.username ||
    targetAccount ||
    source.authUserId ||
    source.userId ||
    null
  ));
  const name = (isLoginAttempt && targetName) ? targetName : (session ? (session.displayName || session.username || null) : (
    source._userName ||
    source._displayName ||
    source.displayName ||
    source.userName ||
    source.cachedDisplayName ||
    authFailure.cachedDisplayName ||
    targetName ||
    source.name ||
    null
  ));
  return {
    account: account || LOG_NO_ACCOUNT,
    name: name || account || LOG_NO_ACCOUNT
  };
}

function _isUuidLike(value) {
  return typeof value === 'string'
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

function _isDisplayOnlyUuidIdentifier(key, value) {
  if (!_isUuidLike(value)) return false;
  const normalizedKey = LOG_DETAIL_KEY_ALIASES[String(key || '')] || key;
  return [
    'id', 'userId', 'authUserId', 'targetId', 'targetUserId', 'targetDepartmentId',
    'departmentId', 'managedDeptId', 'fromDept', 'toDept', 'itemId', 'productId',
    'orderId', 'txnId', 'taskId', 'reportId', 'requestId', 'noticeId', 'logId', 'qrId'
  ].includes(normalizedKey);
}

function _extractLogUsername(value) {
  if (value === undefined || value === null) return '';
  const raw = String(value).trim();
  if (!raw || raw === LOG_NO_ACCOUNT || raw === '계정 없음' || raw === '이름 없음') return '';
  const paren = raw.match(/\(([^()]+)\)\s*$/);
  if (paren && /^[a-zA-Z0-9_-]+$/.test(paren[1])) return paren[1];
  return /^[a-zA-Z0-9_-]+$/.test(raw) ? raw : '';
}

function _normalizeResolvedLogUser(row, sourceTable) {
  if (!row || !row.username) return null;
  return {
    id: row.id || null,
    username: row.username || null,
    display_name: row.display_name || row.username || null,
    department_id: row.department_id || null,
    sourceTable
  };
}

async function _resolveLogUserById(userId) {
  if (!_sb || !_isUuidLike(userId)) return null;
  const cacheKey = 'id:' + userId;
  if (Object.prototype.hasOwnProperty.call(_logUserLookupCache, cacheKey)) {
    return _logUserLookupCache[cacheKey];
  }
  let resolved = null;
  try {
    const { data } = await _sb
      .from('profiles')
      .select('id,username,display_name,department_id')
      .eq('id', userId)
      .maybeSingle();
    resolved = _normalizeResolvedLogUser(data, 'profiles');
  } catch (e) {}
  _logUserLookupCache[cacheKey] = resolved;
  return resolved;
}

async function _resolveLogUserByUsername(value) {
  if (!_sb) return null;
  const username = _extractLogUsername(value);
  if (!username) return null;
  const cacheKey = 'username:' + username;
  if (Object.prototype.hasOwnProperty.call(_logUserLookupCache, cacheKey)) {
    return _logUserLookupCache[cacheKey];
  }

  let resolved = null;
  try {
    const { data } = await _sb
      .from('profiles')
      .select('id,username,display_name,department_id')
      .eq('username', username)
      .maybeSingle();
    resolved = _normalizeResolvedLogUser(data, 'profiles');
  } catch (e) {}

  if (!resolved) {
    try {
      const { data } = await _sb
        .from('registration_requests')
        .select('id,username,display_name,department_id,status,created_at')
        .eq('username', username)
        .order('created_at', { ascending: false })
        .limit(1);
      resolved = _normalizeResolvedLogUser(data && data[0], 'registration_requests');
    } catch (e) {}
  }

  _logUserLookupCache[cacheKey] = resolved;
  return resolved;
}

async function _resolveLogDepartmentById(departmentId) {
  if (!_sb || !_isUuidLike(departmentId)) return null;
  const cacheKey = 'id:' + departmentId;
  if (Object.prototype.hasOwnProperty.call(_logDepartmentLookupCache, cacheKey)) {
    return _logDepartmentLookupCache[cacheKey];
  }

  let name = null;
  try {
    const { data } = await _sb
      .from('departments')
      .select('name')
      .eq('id', departmentId)
      .maybeSingle();
    name = data && data.name ? data.name : null;
  } catch (e) {}
  _logDepartmentLookupCache[cacheKey] = name;
  return name;
}

function _applyResolvedLogUser(enriched, resolved, options = {}) {
  if (!resolved) return;
  const displayName = resolved.display_name || resolved.username || null;
  const account = resolved.username || null;
  if (options.asActorFallback) {
    if (!enriched.username) enriched.username = account;
    if (!enriched.displayName && !enriched.userName && !enriched.name && !enriched['이름']) {
      enriched.displayName = displayName;
    }
  }
  if (Object.prototype.hasOwnProperty.call(enriched, 'targetUser') &&
      (_isUuidLike(enriched.targetUser) || enriched.targetUser === resolved.id)) {
    enriched.targetUser = displayName;
  }
  if (Object.prototype.hasOwnProperty.call(enriched, 'targetUserId') &&
      (_isUuidLike(enriched.targetUserId) || enriched.targetUserId === resolved.id)) {
    enriched.targetUserId = account;
  }
  if (!enriched.targetAccount) enriched.targetAccount = account;
  if (!enriched.targetName) enriched.targetName = displayName;
  if (!enriched.targetDepartmentId && resolved.department_id) enriched.targetDepartmentId = resolved.department_id;
  if (!enriched.sourceTable) enriched.sourceTable = resolved.sourceTable;
}

async function enrichLogDetailsWithUserContext(details) {
  if (!_sb || !details || typeof details !== 'object' || Array.isArray(details)) return details || {};
  const enriched = Object.assign({}, details);
  const authFailure = (enriched.sessionFailure && typeof enriched.sessionFailure === 'object')
    ? enriched.sessionFailure
    : ((enriched.세션실패 && typeof enriched.세션실패 === 'object') ? enriched.세션실패 : {});
  const targetId = enriched.targetUserId || enriched.targetUser || enriched.userId || null;
  const targetAccount = enriched.targetAccount || enriched.username || enriched['아이디'] || enriched['사용자'] || _extractLogUsername(enriched['대상']) || enriched.authSessionAccount || enriched.cachedUsername || authFailure.cachedUsername || null;
  const actorCandidate = enriched.username || enriched['사용자'] || enriched['아이디'] || enriched._username || enriched._userAccount || enriched.authSessionAccount || enriched.cachedUsername || authFailure.cachedUsername || null;

  try {
    let profile = null;
    if (_isUuidLike(targetId)) {
      profile = await _resolveLogUserById(targetId);
    } else if (targetAccount && targetAccount !== LOG_NO_ACCOUNT) {
      profile = await _resolveLogUserByUsername(targetAccount);
    }

    if (profile) {
      _applyResolvedLogUser(enriched, profile, { asActorFallback: false });
    }

    const departmentId = enriched.targetDepartmentId || enriched.departmentId || (profile && profile.department_id) || null;
    const departmentName = await _resolveLogDepartmentById(departmentId);
    if (departmentName && !enriched.targetDepartmentName) {
      enriched.targetDepartmentName = departmentName;
    }

    const actorResolved = await _resolveLogUserByUsername(actorCandidate);
    if (actorResolved) {
      _applyResolvedLogUser(enriched, actorResolved, { asActorFallback: true });
    }
  } catch (e) {}

  return enriched;
}

function _addLogDetailValue(target, key, value) {
  if (!key) return;
  if (!Object.prototype.hasOwnProperty.call(target, key)) {
    target[key] = value;
    return;
  }
  if (JSON.stringify(target[key]) !== JSON.stringify(value)) {
    let idx = 2;
    let nextKey = key + ' ' + idx;
    while (Object.prototype.hasOwnProperty.call(target, nextKey)) {
      idx += 1;
      nextKey = key + ' ' + idx;
    }
    target[nextKey] = value;
  }
}

function _localizeLogDetailValue(key, value, depth = 0) {
  if (depth > 5) return value;
  if (value === null || value === undefined) return value;
  if (typeof value === 'boolean') return value ? '예' : '아니오';
  if (Array.isArray(value)) return value.map(item => _localizeLogDetailValue(key, item, depth + 1));
  if (typeof value === 'object') {
    return buildKoreanLogDetails(value, {
      includeOriginalKeys: false,
      includeTechnicalKeys: false,
      addContext: false,
      depth: depth + 1
    });
  }
  if (typeof value !== 'string') return value;

  const lowerKey = String(key || '').toLowerCase();
  if ((lowerKey.includes('permission') || lowerKey === 'rolekey') && typeof getCodeLabel === 'function') {
    return getCodeLabel('profiles.permission_level', value, LOG_DETAIL_VALUE_LABELS[value] || value);
  }
  if ((lowerKey === 'action' || lowerKey === 'actionkey') && value) {
    return getActionLabel(value);
  }
  return translateLogDetailValue(key, value);
}

function buildKoreanLogDetails(details, options = {}) {
  const source = (details && typeof details === 'object' && !Array.isArray(details)) ? details : {};
  const includeOriginalKeys = options.includeOriginalKeys !== false;
  const includeTechnicalKeys = options.includeTechnicalKeys !== false;
  const hideUuidIdentifiers = options.hideUuidIdentifiers !== false;
  const addContext = options.addContext !== false;
  const result = {};

  if (addContext) {
    const actionKey = options.action || source._actionKey || source._actionEn || source.action || null;
    const actionLabel = options.actionLabel || source._actionKo || source._actionLabel || (actionKey ? getActionLabel(actionKey) : null);
    const userName = options.userName || source._userName || source._displayName || null;
    const userAccount = options.userAccount || source._userAccount || source._username || null;

    if (actionLabel) _addLogDetailValue(result, '작업', actionLabel);
    if (actionKey) _addLogDetailValue(result, '작업코드', actionKey);
    if (userName) _addLogDetailValue(result, '작업자', userName);
    if (userAccount) _addLogDetailValue(result, '작업자 아이디', userAccount);
  }

  Object.entries(source).forEach(([key, value]) => {
    const isTechnical = key.startsWith('_') || LOG_TECHNICAL_DETAIL_KEYS.has(key);
    if (hideUuidIdentifiers && _isDisplayOnlyUuidIdentifier(key, value)) return;
    let displayValue = value;
    if ((key === 'targetUser' || key === '대상 사용자') && _isUuidLike(value)) {
      displayValue = source.targetName || source.targetDisplayName || source['대상'] || source['대상 이름'] || value;
    }
    if ((key === 'targetUserId' || key === '대상 사용자 ID') && _isUuidLike(value)) {
      displayValue = source.targetAccount || source['대상 아이디'] || source['사용자 계정'] || value;
    }

    if (includeOriginalKeys && (includeTechnicalKeys || !isTechnical)) {
      _addLogDetailValue(result, key, displayValue);
    }

    const label = getLogDetailKeyLabel(key);
    const localizedValue = _localizeLogDetailValue(key, displayValue, options.depth || 0);
    if (label && label !== key) {
      _addLogDetailValue(result, label, localizedValue);
    } else if (!includeOriginalKeys && !isTechnical) {
      _addLogDetailValue(result, key, localizedValue);
    }
  });

  return result;
}

function getLocalizedLogDetails(details, options = {}) {
  const normalized = normalizeLogDetailsForStorage(details || {}, options);
  return buildKoreanLogDetails(normalized, Object.assign({
    includeOriginalKeys: true,
    includeTechnicalKeys: true,
    addContext: false
  }, options));
}

function getDisplayLogDetails(details, options = {}) {
  const normalized = normalizeLogDetailsForStorage(details || {}, options);
  return buildKoreanLogDetails(normalized, Object.assign({
    includeOriginalKeys: false,
    includeTechnicalKeys: false,
    addContext: false
  }, options));
}

function stringifyKoreanLogDetails(details) {
  const localized = getDisplayLogDetails(details || {});
  return Object.keys(localized).length ? JSON.stringify(localized, null, 2) : '-';
}

const CHANGE_LOG_FIELD_LABELS = {
  name: '명칭',
  display_name: '표시 이름',
  displayName: '표시 이름',
  username: '계정',
  department_id: '소속 부서',
  departmentId: '소속 부서',
  managed_dept_id: '관리 부서',
  managedDeptId: '관리 부서',
  user_type: '사용자 유형',
  userType: '사용자 유형',
  permission_level: '권한',
  permissionLevel: '권한',
  class_number: '반',
  classNumber: '반',
  description: '설명',
  category: '카테고리',
  target_role: '대상',
  price: '달란트 가격',
  sort_order: '표시 순번',
  image_emoji: '아이콘',
  image_url: '썸네일 이미지',
  detail_image_url: '상세 설명 이미지',
  purchase_url: '구매 URL',
  actual_purchase_price: '실제 상품 가격',
  show_delivery_delay_notice: '배송 지연 안내',
  stock: '재고',
  is_active: '활성 상태',
  code_value: '명칭',
  code_key: '코드',
  meta: '추가 설정'
};

function _changeLogComparable(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value === 'object') return JSON.stringify(value);
  return value;
}

function buildChangeSet(before = {}, after = {}, options = {}) {
  const fields = options.fields || Array.from(new Set([...Object.keys(before || {}), ...Object.keys(after || {})]));
  const ignore = new Set(options.ignore || ['id', 'created_at', 'updated_at', 'created_by', 'password', 'password_hash']);
  return fields.filter(field => !ignore.has(field)).map(field => {
    const oldValue = before ? before[field] : undefined;
    const newValue = after ? after[field] : undefined;
    return {
      field,
      label: CHANGE_LOG_FIELD_LABELS[field] || getLogDetailKeyLabel(field) || field,
      before: oldValue == null || oldValue === '' ? null : oldValue,
      after: newValue == null || newValue === '' ? null : newValue
    };
  }).filter(change => _changeLogComparable(change.before) !== _changeLogComparable(change.after));
}

function _changeLogText(value) {
  if (value === undefined || value === null || value === '') return '없음';
  if (typeof value === 'boolean') return value ? '사용' : '사용 안 함';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(_localizeLogDetailValue('', value));
}

function buildChangeLogDetails(options = {}) {
  const changes = Array.isArray(options.changes) ? options.changes : [];
  const changeSummary = changes.map(change => `${change.label || CHANGE_LOG_FIELD_LABELS[change.field] || change.field}: ${_changeLogText(change.before)} → ${_changeLogText(change.after)}`).join(' / ');
  return Object.assign({
    targetName: options.targetName || null,
    targetType: options.targetType || null,
    targetId: options.targetId || null,
    changes,
    changeSummary: changeSummary || null
  }, options.extra || {});
}

if (typeof window !== 'undefined') {
  window.buildChangeSet = buildChangeSet;
  window.buildChangeLogDetails = buildChangeLogDetails;
}

if (typeof window !== 'undefined') {
  window.closeOpenActionMenus = closeOpenActionMenus;
  window.getLogDetailKeyLabel = getLogDetailKeyLabel;
  window.getLocalizedLogDetails = getLocalizedLogDetails;
  window.getDisplayLogDetails = getDisplayLogDetails;
  window.stringifyKoreanLogDetails = stringifyKoreanLogDetails;
}

function _getLogErrorMessage(error) {
  if (!error) return '';
  return [
    error.message,
    error.details,
    error.hint,
    error.code,
    typeof error === 'string' ? error : ''
  ].filter(Boolean).join(' ');
}

function _getMissingOptionalLogColumn(error, row) {
  const msg = _getLogErrorMessage(error).toLowerCase();
  if (!msg || !/could not find|column|schema cache|does not exist/i.test(msg)) return null;
  return ['user_name', 'is_acknowledged'].find(col =>
    Object.prototype.hasOwnProperty.call(row, col) && msg.includes(col.toLowerCase())
  ) || null;
}

async function _insertActivityLogRow(row) {
  let currentRow = { ...row };
  const removedColumns = [];

  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const result = await _sb.from('activity_logs').insert(currentRow);
      if (!result.error) {
        if (removedColumns.length) {
          console.warn('[Log] Inserted with compatibility fallback. Removed columns:', removedColumns.join(', '));
        }
        return result;
      }

      const missingColumn = _getMissingOptionalLogColumn(result.error, currentRow);
      if (missingColumn) {
        delete currentRow[missingColumn];
        removedColumns.push(missingColumn);
        continue;
      }

      console.error('[Log] Failed to write log:', result.error);
      return result;
    } catch (err) {
      const missingColumn = _getMissingOptionalLogColumn(err, currentRow);
      if (missingColumn) {
        delete currentRow[missingColumn];
        removedColumns.push(missingColumn);
        continue;
      }
      console.error('[Log] Failed to write log:', err);
      return { data: null, error: err };
    }
  }

  const error = new Error('activity_logs insert failed after compatibility fallbacks');
  console.error('[Log] Failed to write log:', error);
  return { data: null, error };
}

function _parseUA() {
  const ua = navigator.userAgent || '';
  let browser = 'Unknown', os = 'Unknown', deviceType = 'desktop';

  if (/Edg\//i.test(ua)) browser = 'Edge ' + (ua.match(/Edg\/([\d.]+)/)||[])[1];
  else if (/OPR\//i.test(ua)) browser = 'Opera ' + (ua.match(/OPR\/([\d.]+)/)||[])[1];
  else if (/Chrome\//i.test(ua)) browser = 'Chrome ' + (ua.match(/Chrome\/([\d.]+)/)||[])[1];
  else if (/Safari\//i.test(ua) && !/Chrome/i.test(ua)) browser = 'Safari ' + (ua.match(/Version\/([\d.]+)/)||[])[1];
  else if (/Firefox\//i.test(ua)) browser = 'Firefox ' + (ua.match(/Firefox\/([\d.]+)/)||[])[1];

  if (/Windows NT 10/i.test(ua)) os = 'Windows 10/11';
  else if (/Windows NT/i.test(ua)) os = 'Windows';
  else if (/Mac OS X/i.test(ua)) os = 'macOS ' + ((ua.match(/Mac OS X ([\d_]+)/)||[])[1]||'').replace(/_/g,'.');
  else if (/Android/i.test(ua)) os = 'Android ' + (ua.match(/Android ([\d.]+)/)||[])[1];
  else if (/iPhone|iPad/i.test(ua)) os = 'iOS ' + ((ua.match(/OS ([\d_]+)/)||[])[1]||'').replace(/_/g,'.');
  else if (/Linux/i.test(ua)) os = 'Linux';
  else if (/CrOS/i.test(ua)) os = 'Chrome OS';

  if (/Mobi|Android.*Mobile|iPhone/i.test(ua)) deviceType = 'mobile';
  else if (/iPad|Android(?!.*Mobile)|Tablet/i.test(ua)) deviceType = 'tablet';

  return { browser, os, deviceType, userAgent: ua };
}

function getClientInfo() {
  return null;
}

function _fetchIp() {
  return null;
}

async function writeLog(level, action, page, details) {
  if (!_sb) {
    console.warn('[Log] Supabase not initialized, log skipped:', level, action);
    return { data: null, error: 'Supabase not initialized' };
  }
  const session = getSession();
  const baseDetails = (details && typeof details === 'object' && !Array.isArray(details))
    ? Object.assign({}, details)
    : {};
  if (details && (typeof details !== 'object' || Array.isArray(details))) {
    baseDetails.message = String(details);
  }
  const enrichedDetails = await enrichLogDetailsWithUserContext(baseDetails);
  const actor = inferLogActor(session, enrichedDetails, action);
  const resolvedActor = await _resolveLogUserByUsername(actor.account);
  if (resolvedActor) {
    actor.account = resolvedActor.username || actor.account;
    actor.name = resolvedActor.display_name || resolvedActor.username || actor.name;
  }
  const normalizedDetails = normalizeLogDetailsForStorage(enrichedDetails, {
    action,
    actorAccount: actor.account,
    actorName: actor.name
  });
  normalizedDetails.logUserAccount = actor.account || LOG_NO_ACCOUNT;
  normalizedDetails.logUserName = actor.name || LOG_NO_ACCOUNT;
  const row = {
    level,
    action,
    page: page || window.location.pathname,
    details: normalizedDetails,
    username: actor.account || LOG_NO_ACCOUNT,
    user_name: actor.name || LOG_NO_ACCOUNT,
    is_acknowledged: !ERROR_LEVELS.includes(level)
  };
  if (_shouldSkipDuplicateLog(level, action, row.page, normalizedDetails)) {
    return { data: null, error: null, skipped: true };
  }
  var result = await _insertActivityLogRow(row);
  if (SLACK_ALERT_LEVELS.includes(level)) {
    _sendLogAlertDirect(level, action, page || window.location.pathname, normalizedDetails);
  }
  return result;
}

function logTrace(action, details) { return writeLog('TRACE', action, null, details); }
function logDebug(action, details) { return writeLog('DEBUG', action, null, details); }
function logInfo(action, details)  { return writeLog('INFO', action, null, details); }
function logWarn(action, details)  { return writeLog('WARN', action, null, details); }
function logError(action, details) { return writeLog('ERROR', action, null, details); }
function logFatal(action, details) { return writeLog('FATAL', action, null, details); }
function logCritical(action, details) { return writeLog('CRITICAL', action, null, details); }

async function fetchLogs(options = {}) {
  if (!_sb) return { data: [], error: 'Supabase not initialized' };

  let query = _sb.from('activity_logs').select('*');

  if (!options.includeDeleted) {
    try {
      const testQ = _sb.from('activity_logs').select('id', { count: 'exact', head: true }).eq('is_deleted', false).limit(1);
      const { error: colErr } = await testQ;
      if (!colErr) {
        query = query.or('is_deleted.is.null,is_deleted.eq.false');
      }
    } catch (e) { /* is_deleted column may not exist yet */ }
  }

  if (options.levels && options.levels.length > 0) {
    query = query.in('level', options.levels);
  }
  if (options.action) {
    query = query.eq('action', options.action);
  }
  if (options.dateFrom) {
    query = query.gte('created_at', options.dateFrom);
  }
  if (options.dateTo) {
    query = query.lte('created_at', options.dateTo);
  }
  if (options.unacknowledgedOnly) {
    query = query.eq('is_acknowledged', false).in('level', ERROR_LEVELS);
  }

  query = query.order('created_at', { ascending: false });

  if (options.limit) query = query.limit(options.limit);
  if (options.offset) query = query.range(options.offset, options.offset + (options.limit || 50) - 1);

  return await query;
}

async function getUnacknowledgedCount() {
  if (!_sb) return 0;
  let query = _sb
    .from('activity_logs')
    .select('*', { count: 'exact', head: true })
    .eq('is_acknowledged', false)
    .in('level', ERROR_LEVELS);
  try {
    const { error: deletedColError } = await _sb.from('activity_logs')
      .select('id', { count: 'exact', head: true })
      .or('is_deleted.is.null,is_deleted.eq.false')
      .limit(1);
    if (!deletedColError) {
      query = query.or('is_deleted.is.null,is_deleted.eq.false');
    }
  } catch (e) {}
  const { count, error } = await query;
  return error ? 0 : (count || 0);
}

async function acknowledgeLog(logId, username, note) {
  if (!_sb) return { error: 'Supabase not initialized' };
  return await _sb.from('activity_logs').update({
    is_acknowledged: true,
    acknowledged_by: username,
    acknowledged_at: new Date().toISOString(),
    resolution_note: note
  }).eq('id', logId).select();
}

/* ===== Pending Registration Count ===== */

async function getPendingRegistrationCount() {
  if (!_sb) return 0;
  try {
    const session = getSession();
    if (!session || (session.permissionRank || 0) < 60) return 0;
    const myRank = session.permissionRank || 0;

    if (myRank >= 90) {
      const { count, error } = await _sb
        .from('registration_requests')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending');
      if (error) return 0;
      return count || 0;
    }

    const myDepts = new Set([session.managedDeptId, session.departmentId].filter(Boolean));
    if (myDepts.size === 0) return 0;

    const [regRes, trfRes] = await Promise.all([
      _sb.from('registration_requests').select('id,department_id').eq('status', 'pending'),
      _sb.from('department_transfer_requests').select('id,to_department_id').eq('status', 'pending')
    ]);

    const regs = (regRes.data || []).filter(r => myDepts.has(r.department_id));
    const trfs = (trfRes.data || []).filter(t => myDepts.has(t.to_department_id));
    return regs.length + trfs.length;
  } catch { return 0; }
}

async function getProcessableRequestCount() {
  if (!_sb) return 0;
  try {
    const session = getSession();
    if (!session || (session.permissionRank || 0) < 60) return 0;
    const myRank = session.permissionRank || 0;

    const [regRes, trfRes] = await Promise.all([
      _sb.from('registration_requests').select('id,department_id').eq('status', 'pending'),
      _sb.from('department_transfer_requests').select('id,to_department_id').eq('status', 'pending')
    ]);

    let regs = regRes.data || [];
    let trfs = trfRes.data || [];

    if (myRank >= 90) {
      return regs.length + trfs.length;
    }

    const myDepts = new Set([session.managedDeptId, session.departmentId].filter(Boolean));
    if (myDepts.size === 0) return 0;

    const processableRegs = regs.filter(r => myDepts.has(r.department_id));
    const processableTrfs = trfs.filter(t => myDepts.has(t.to_department_id));
    return processableRegs.length + processableTrfs.length;
  } catch { return 0; }
}

async function updatePendingBadge() {
  const badge = document.getElementById('navUserBadge');
  if (!badge) return;
  const count = await getProcessableRequestCount();
  if (count > 0) {
    badge.textContent = count;
    badge.classList.remove('hidden');
  } else {
    badge.classList.add('hidden');
  }
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

/* ===== Talent Exception Request Badge (nav "달란트" group) ===== */

async function getPendingTalentExceptionRequestCount() {
  if (!_sb) return 0;
  try {
    const session = getSession();
    if (!session || (session.permissionRank || 0) < 90) return 0;
    const { count, error } = await _sb
      .from('talent_exception_requests')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending');
    if (error) return 0;
    return count || 0;
  } catch { return 0; }
}

async function updateTalentExceptionBadge() {
  const badge = document.getElementById('navTalentExceptionBadge');
  if (!badge) return;
  try {
    const cnt = await getPendingTalentExceptionRequestCount();
    if (cnt > 0) { badge.textContent = cnt; badge.classList.remove('hidden'); }
    else { badge.classList.add('hidden'); }
  } catch (e) {}
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

/* ===== Log Badge (nav "운영" group) ===== */

async function updateLogBadge() {
  const badge = document.getElementById('navLogBadge');
  if (!badge) return;
  try {
    const cnt = await getUnacknowledgedCount();
    if (cnt > 0) { badge.textContent = cnt; badge.classList.remove('hidden'); }
    else { badge.classList.add('hidden'); }
  } catch (e) {}
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

/* ===== Session Helpers (Supabase Auth 연동) ===== */

function getSession() {
  try {
    const raw = sessionStorage.getItem('cho_session');
    if (raw) return JSON.parse(raw);
    const old = sessionStorage.getItem('cho_admin_session');
    return old ? JSON.parse(old) : null;
  } catch { return null; }
}

function setSession(data) {
  sessionStorage.setItem('cho_session', JSON.stringify(data));
  sessionStorage.removeItem('cho_admin_session');
}

function clearSession() {
  sessionStorage.removeItem('cho_session');
  sessionStorage.removeItem('cho_admin_session');
}

function _getRequestErrorDetails(prefix, error) {
  if (!error) return {};
  const value = (error && typeof error === 'object') ? error : {};
  const details = {};
  details[`${prefix}ErrorName`] = value.name ? String(value.name) : null;
  details[`${prefix}ErrorMessage`] = value.message ? String(value.message) : String(error);
  details[`${prefix}ErrorCode`] = value.code ? String(value.code) : null;
  details[`${prefix}ErrorStatus`] = value.status ?? value.statusCode ?? null;
  details[`${prefix}ErrorDetails`] = value.details ? String(value.details) : null;
  details[`${prefix}ErrorHint`] = value.hint ? String(value.hint) : null;
  return details;
}

function _getProfileRequestNetworkDetails() {
  const details = {};
  try {
    details.browserOnline = typeof navigator.onLine === 'boolean' ? navigator.onLine : null;
    const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    if (connection) {
      details.networkEffectiveType = connection.effectiveType || null;
      details.networkRttMs = Number.isFinite(connection.rtt) ? connection.rtt : null;
      details.networkDownlinkMbps = Number.isFinite(connection.downlink) ? connection.downlink : null;
      details.networkSaveData = typeof connection.saveData === 'boolean' ? connection.saveData : null;
    }
  } catch (e) {}
  return details;
}

function _getProfileRequestAuthDetails(authSession, cached) {
  const authUser = authSession && authSession.user ? authSession.user : {};
  const authEmail = String(authUser.email || '');
  const atIndex = authEmail.indexOf('@');
  const authAccount = atIndex > 0 ? authEmail.slice(0, atIndex) : null;
  const expiresAt = Number(authSession && authSession.expires_at);
  return {
    authSessionUserId: authUser.id || null,
    authSessionAccount: authAccount,
    authSessionRole: authUser.role || null,
    authSessionIsAnonymous: authUser.is_anonymous === true,
    authSessionExpiresAt: Number.isFinite(expiresAt) && expiresAt > 0 ? new Date(expiresAt * 1000).toISOString() : null,
    hasCachedSession: !!cached,
    cachedSessionIdMatchesAuthUser: cached && cached.id ? cached.id === authUser.id : null,
    cachedAccountMatchesAuthUser: cached && cached.username && authAccount ? cached.username === authAccount : null,
    cachedUsername: cached ? cached.username : null,
    cachedDisplayName: cached ? (cached.displayName || cached.username) : null
  };
}

async function _loadProfileDirectForSession(authUserId) {
  const startedAt = Date.now();
  const diagnostics = {
    profileFallbackAttempted: !!(_sb && authUserId),
    profileFallbackQuery: 'profiles.select(..., departments!profiles_department_id_fkey(name)).eq(id, auth user).maybeSingle()',
    profileFallbackRequestedUserId: authUserId || null
  };
  if (!_sb || !authUserId) {
    return {
      data: null,
      error: null,
      diagnostics: Object.assign(diagnostics, {
        profileFallbackOutcome: 'skipped',
        profileFallbackDurationMs: Date.now() - startedAt
      })
    };
  }
  try {
    const { data, error } = await _sb
      .from('profiles')
      .select('id, username, display_name, user_type, permission_level, is_super_admin, is_first_login, department_id, managed_dept_id, talent_balance, class_number, departments!profiles_department_id_fkey(name)')
      .eq('id', authUserId)
      .maybeSingle();
    Object.assign(diagnostics, {
      profileFallbackDurationMs: Date.now() - startedAt,
      profileFallbackOutcome: error ? 'error' : (data ? 'profile' : 'empty_result')
    }, _getRequestErrorDetails('profileFallback', error));
    if (error || !data) return { data: null, error, diagnostics };
    return {
      data: {
        id: data.id,
        username: data.username,
        display_name: data.display_name,
        user_type: data.user_type,
        permission_level: data.permission_level,
        is_super_admin: data.is_super_admin,
        is_first_login: data.is_first_login,
        department_id: data.department_id,
        managed_dept_id: data.managed_dept_id,
        talent_balance: data.talent_balance,
        department_name: data.departments ? data.departments.name : null,
        class_number: data.class_number
      },
      error: null,
      diagnostics
    };
  } catch (err) {
    return {
      data: null,
      error: err,
      diagnostics: Object.assign(diagnostics, {
        profileFallbackDurationMs: Date.now() - startedAt,
        profileFallbackOutcome: 'exception'
      }, _getRequestErrorDetails('profileFallback', err))
    };
  }
}

async function loadAuthSession() {
  if (!_sb) {
    window.__lastAuthSessionFailure = {
      reason: 'Supabase client not initialized',
      page: window.location.pathname
    };
    return null;
  }

  const cached = getSession();
  let authSession = null;
  try {
    const { data: authData, error: authError } = await _sb.auth.getSession();
    if (authError) {
      window.__lastAuthSessionFailure = {
        reason: 'Supabase auth session error',
        message: authError.message,
        page: window.location.pathname,
        cachedUsername: cached ? cached.username : null,
        cachedDisplayName: cached ? (cached.displayName || cached.username) : null,
        cachedPermissionLevel: cached ? cached.permissionLevel : null
      };
      await logWarn('AUTH_SESSION_MISSING', window.__lastAuthSessionFailure);
      clearSession();
      return null;
    }
    authSession = authData.session;
  } catch (err) {
      window.__lastAuthSessionFailure = {
        reason: 'Supabase auth session exception',
        message: err.message || String(err),
        page: window.location.pathname,
        cachedUsername: cached ? cached.username : null,
        cachedDisplayName: cached ? (cached.displayName || cached.username) : null,
        cachedPermissionLevel: cached ? cached.permissionLevel : null
    };
    await logWarn('AUTH_SESSION_MISSING', window.__lastAuthSessionFailure);
    clearSession();
    return null;
  }

  if (!authSession) {
    let lastActivityAt = null;
    let idleExpired = false;
    try {
      const last = parseInt(localStorage.getItem('cho_last_activity') || '0', 10);
      if (last > 0) {
        lastActivityAt = new Date(last).toISOString();
        idleExpired = Date.now() - last > 24 * 60 * 60 * 1000;
      }
    } catch (e) {}
    window.__lastAuthSessionFailure = {
      reason: 'Supabase auth session missing',
      page: window.location.pathname,
      cachedUsername: cached ? cached.username : null,
      cachedDisplayName: cached ? (cached.displayName || cached.username) : null,
      cachedPermissionLevel: cached ? cached.permissionLevel : null,
      cachedPermissionRank: cached ? cached.permissionRank : null,
      hasCachedSession: !!cached,
      lastActivityAt,
      idleExpired
    };
    if (cached || idleExpired) {
      await logInfo('AUTH_SESSION_MISSING', window.__lastAuthSessionFailure);
    }
    clearSession();
    return null;
  }

  if (cached && cached.id === authSession.user.id && cached.isSuperAdmin !== undefined) return cached;

  const profileRequestAuth = _getProfileRequestAuthDetails(authSession, cached);
  const profileRequestNetwork = _getProfileRequestNetworkDetails();
  const profileRpcStartedAt = Date.now();
  let data = null;
  let profileError = null;
  try {
    const profileRpc = await _sb.rpc('get_my_profile');
    data = profileRpc.data;
    profileError = profileRpc.error;
  } catch (err) {
    profileError = err;
  }
  const profileRpcDiagnostics = Object.assign({
    profileRpcName: 'get_my_profile',
    profileRpcDurationMs: Date.now() - profileRpcStartedAt,
    profileRpcOutcome: profileError ? 'error' : (data ? 'profile' : 'empty_result')
  }, _getRequestErrorDetails('profileRpc', profileError));
  if (profileError || !data) {
    window.__lastAuthSessionFailure = {
      reason: 'Profile RPC returned no profile',
      message: profileError ? (profileError.message || String(profileError)) : null,
      page: window.location.pathname,
      authUserId: authSession.user.id,
      profileFallbackAttempted: false,
      ...profileRequestAuth,
      ...profileRequestNetwork,
      ...profileRpcDiagnostics
    };
    if (cached && cached.id === authSession.user.id && cached.username && cached.permissionLevel) {
      await logInfo('AUTH_PROFILE_LOAD_FAIL', Object.assign({}, window.__lastAuthSessionFailure, { recoveredBy: 'cached_session' }));
      return cached;
    }
    const directProfile = await _loadProfileDirectForSession(authSession.user.id);
    Object.assign(window.__lastAuthSessionFailure, directProfile.diagnostics || {});
    if (directProfile.data) {
      await logInfo('AUTH_PROFILE_LOAD_FAIL', Object.assign({}, window.__lastAuthSessionFailure, { recoveredBy: 'profiles_fallback' }));
      data = directProfile.data;
      profileError = null;
    } else {
      window.__lastAuthSessionFailure.fallbackMessage = directProfile.error ? (directProfile.error.message || String(directProfile.error)) : null;
    }
  }

  if (profileError || !data) {
    await logError('AUTH_PROFILE_LOAD_FAIL', window.__lastAuthSessionFailure);
    clearSession();
    return null;
  }

  const perm = data.permission_level;
  const _isSA = data.is_super_admin || false;
  const profile = {
    id: data.id,
    username: data.username,
    displayName: data.display_name,
    userType: data.user_type || 'teacher',
    permissionLevel: perm,
    permissionRank: (typeof getPermRank === 'function') ? getPermRank(perm, _isSA) : ((_isSA && perm === 'admin') ? 110 : ({ admin: 100, evangelist: 90, chief: 80, purchase_teacher: 70, dept_teacher: 60, teacher: 40, student: 20 }[perm] || 0)),
    isSuperAdmin: _isSA,
    isFirstLogin: data.is_first_login,
    departmentId: data.department_id,
    managedDeptId: data.managed_dept_id,
    talentBalance: data.talent_balance || 0,
    departmentName: data.department_name,
    classNumber: data.class_number,
    appVersion: (() => {
      try { return localStorage.getItem('cho_session_app_version') || null; }
      catch (e) { return null; }
    })()
  };
  setSession(profile);
  return profile;
}

/* ===== Global Error Handler ===== */

function _clientErrorText(value, fallback = '브라우저가 오류 세부정보를 제공하지 않았습니다.') {
  if (value && typeof value === 'object' && value.message) return String(value.message);
  if (typeof value === 'string' && value.trim()) return value.trim();
  if (value !== null && value !== undefined) {
    try {
      const serialized = JSON.stringify(value);
      if (serialized && serialized !== '{}') return serialized;
    } catch (e) {}
  }
  return fallback;
}

function _clientErrorFingerprint(parts) {
  const source = parts.map(value => String(value || '')
    .replace(/[?#].*$/, '')
    .replace(/\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/ig, '{uuid}')
    .trim()).join('|');
  let hash = 2166136261;
  for (let i = 0; i < source.length; i += 1) {
    hash ^= source.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return 'js-' + (hash >>> 0).toString(36);
}

function _getResourceLoadDetails(resource, resourceTag) {
  const rawUrl = resource.currentSrc || resource.src || resource.href || null;
  const details = {
    resourceType: resourceTag,
    resourceUrl: null,
    resourceHasQuery: false,
    resourceId: resource.id || null,
    resourceRel: resource.rel || null,
    resourceLoading: resource.loading || null,
    resourceCrossOrigin: resource.crossOrigin || null
  };
  if (!rawUrl) return details;

  try {
    const parsed = new URL(rawUrl, window.location.href);
    details.resourceUrl = parsed.protocol === 'blob:' || parsed.protocol === 'data:'
      ? parsed.protocol
      : `${parsed.origin}${parsed.pathname}`;
    details.resourceHasQuery = !!parsed.search;
  } catch (e) {
    details.resourceUrl = String(rawUrl).replace(/[?#].*$/, '').slice(0, 1000);
  }
  return details;
}

window.addEventListener('error', (e) => {
  const resource = e.target;
  const resourceTag = resource && resource !== window ? String(resource.tagName || '').toUpperCase() : '';
  if (resourceTag) {
    const resourceDetails = _getResourceLoadDetails(resource, resourceTag);
    logError('RESOURCE_LOAD_FAIL', Object.assign({
      message: `${resourceTag} 리소스 로드 실패`,
      errorKind: 'resource-load',
      errorFingerprint: _clientErrorFingerprint(['resource-load', resourceTag, resourceDetails.resourceUrl])
    }, resourceDetails));
    return;
  }
  const message = _clientErrorText(e.message || (e.error && e.error.message));
  const filename = e.filename || (e.error && e.error.fileName) || null;
  const lineno = e.lineno || (e.error && e.error.lineNumber) || null;
  const colno = e.colno || (e.error && e.error.columnNumber) || null;
  const details = {
    message,
    errorKind: 'runtime',
    errorName: e.error && e.error.name ? String(e.error.name) : null,
    errorFingerprint: _clientErrorFingerprint(['runtime', message, filename, lineno, colno]),
    filename,
    lineno,
    colno
  };
  if (e.error && e.error.stack) details.stack = String(e.error.stack).slice(0, 2000);
  if (message === 'Script error.' && !filename && !lineno && !colno) {
    details.hint = '외부 스크립트 오류 세부정보가 브라우저 CORS 정책으로 숨겨졌습니다.';
  }
  logError('JS_ERROR', details);
}, true);

window.addEventListener('unhandledrejection', (e) => {
  const reason = e.reason;
  const message = _clientErrorText(reason, '처리되지 않은 Promise 거부');
  logError('PROMISE_REJECTION', {
    reason: message,
    errorKind: 'unhandled-rejection',
    errorName: reason && reason.name ? String(reason.name) : null,
    errorFingerprint: _clientErrorFingerprint(['unhandled-rejection', message, reason && reason.stack]),
    stack: reason && reason.stack ? String(reason.stack).slice(0, 2000) : null
  });
});

/* ===== Auto Page View Log ===== */

function autoLogPageView() {
}

const _SOFT_DEL_COL_ERR = 'DB에 삭제 관리 컬럼이 없습니다.\nSupabase SQL Editor에서 아래 SQL을 실행해주세요:\n\nALTER TABLE activity_logs ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;\nALTER TABLE activity_logs ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;';

function _isMissingColErr(msg) {
  return /could not find.*column|column.*does not exist|schema cache/i.test(msg || '');
}

async function deleteLogsByIds(ids) {
  if (!_sb) return { error: 'Supabase not initialized', count: 0 };
  if (!ids || ids.length === 0) return { error: null, count: 0 };
  try {
    const { data, error } = await _sb
      .from('activity_logs')
      .update({ is_deleted: true, deleted_at: new Date().toISOString() })
      .in('id', ids)
      .eq('is_acknowledged', true)
      .select('id');
    if (error) {
      if (_isMissingColErr(error.message)) return { error: _SOFT_DEL_COL_ERR, count: 0 };
      return { error: error.message, count: 0 };
    }
    return { error: null, count: data ? data.length : 0 };
  } catch (err) {
    return { error: String(err), count: 0 };
  }
}

async function getPendingOrderCount() {
  if (!_sb) return 0;
  try {
    const session = getSession();
    if (!session || (session.permissionRank || 0) < 60) return 0;
    const permissionLevel = session.permissionLevel;
    const isGlobalManager = (session.permissionRank || 0) >= 90;
    const isPurchaseTeacher = permissionLevel === 'purchase_teacher';
    const isManagedDepartmentTeacher = permissionLevel === 'dept_teacher' || permissionLevel === 'chief';
    const badgeStatuses = isGlobalManager
      ? ['requested', 'preparing', 'purchased']
      : isPurchaseTeacher
        ? ['preparing', 'purchased']
        : isManagedDepartmentTeacher
          ? ['requested']
          : [];
    if (badgeStatuses.length === 0) return 0;
    const { data, error } = await _sb
      .from('product_orders')
      .select('user_id')
      .in('status', badgeStatuses);
    if (error || !data) return 0;
    if (isGlobalManager || isPurchaseTeacher) return data.length;
    if (!session.managedDeptId) return 0;
    const userIds = [...new Set(data.map(o => o.user_id))];
    if (userIds.length === 0) return 0;
    const { data: profiles } = await _sb.from('profiles').select('id,department_id').in('id', userIds);
    if (!profiles) return 0;
    const departmentUsers = new Set(profiles
      .filter(profile => profile.department_id === session.managedDeptId)
      .map(profile => profile.id));
    return data.filter(order => departmentUsers.has(order.user_id)).length;
  } catch (e) { return 0; }
}

async function updateNavOrderBadge() {
  const badge = document.getElementById('navOrderBadge');
  if (!badge) return;
  try {
    const cnt = await getPendingOrderCount();
    if (cnt > 0) { badge.textContent = cnt; badge.classList.remove('hidden'); }
    else { badge.classList.add('hidden'); }
  } catch (e) {}
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

/* ===== Product Suggestion Vote Badge (nav "상품" group) ===== */

async function getUnvotedProductSuggestionCount() {
  if (!_sb) return 0;
  try {
    const session = getSession();
    if (!session || (session.permissionRank || 0) < 60) return 0;
    const { data, error } = await _sb.rpc('get_unvoted_product_suggestion_count');
    if (error) return 0;
    return Number(data) || 0;
  } catch (e) { return 0; }
}

async function updateNavProductSuggestionVoteBadge() {
  const badge = document.getElementById('navProductSuggestionVoteBadge');
  if (!badge) return;
  try {
    const count = await getUnvotedProductSuggestionCount();
    if (count > 0) {
      badge.textContent = count;
      badge.classList.remove('hidden');
    } else {
      badge.classList.add('hidden');
    }
  } catch (e) {}
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

/* ===== Q&A Badge (nav "소개" group) ===== */

async function getUnansweredQnaCount() {
  if (!_sb) return 0;
  try {
    const { count, error } = await _sb
      .from('qna')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending')
      .eq('is_deleted', false);
    if (error) return 0;
    return count || 0;
  } catch { return 0; }
}

async function updateQnaBadge() {
  const badge = document.getElementById('navQnaBadge');
  if (!badge) return;
  try {
    const cnt = await getUnansweredQnaCount();
    if (cnt > 0) { badge.textContent = cnt; badge.classList.remove('hidden'); }
    else { badge.classList.add('hidden'); }
  } catch (e) {}
  if (typeof updateNavGroupBadges === 'function') updateNavGroupBadges();
}

async function deleteLogsByDateRange(dateFrom, dateTo, options = {}) {
  if (!_sb) return { error: 'Supabase not initialized', count: 0 };
  try {
    let query = _sb
      .from('activity_logs')
      .update({ is_deleted: true, deleted_at: new Date().toISOString() })
      .gte('created_at', dateFrom)
      .lte('created_at', dateTo)
      .eq('is_deleted', false);
    if (options.level) {
      query = query.eq('level', options.level);
      if (options.excludeUnacknowledged) {
        const ERROR_PLUS = ['ERROR', 'FATAL', 'CRITICAL'];
        if (ERROR_PLUS.includes(options.level)) {
          query = query.eq('is_acknowledged', true);
        }
      }
    } else if (options.excludeUnacknowledged) {
      query = query.or('level.not.in.(ERROR,FATAL,CRITICAL),is_acknowledged.eq.true');
    }
    const { data, error } = await query.select('id');
    if (error) return { error: error.message, count: 0 };
    return { error: null, count: data ? data.length : 0 };
  } catch (err) {
    return { error: String(err), count: 0 };
  }
}
