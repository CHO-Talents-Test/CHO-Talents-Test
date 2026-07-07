-- TASK-067: activity_logs 상세 데이터 한글 별칭 저장/백필
-- 목적:
--   1) 기존 activity_logs.details JSON에 한글 키 별칭을 추가해 로그 상세 조회 시 한글로 읽히게 보강
--   2) 코드 마스터에 누락된 실제 발생 액션 라벨을 추가
-- 주의:
--   - 원본 영문/기술 키는 호환성을 위해 삭제하지 않습니다.
--   - 신규 로그는 js/activity-log.js에서 같은 방식으로 한글 별칭을 함께 저장합니다.

BEGIN;

INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
VALUES
  ('activity_logs.action', 'APP_VERSION_STALE_SESSION', '구버전 세션 감지', 7018, '{"category":"AUTH","emoji":"🔄"}'),
  ('activity_logs.action', 'LOGIN_FAIL', '로그인 실패', 7011, '{"category":"AUTH","emoji":"🔒"}'),
  ('activity_logs.action', 'LOGIN_ERROR', '로그인 오류', 7012, '{"category":"AUTH","emoji":"⚠️"}'),
  ('activity_logs.action', 'AUTH_SESSION_MISSING', '인증 세션 없음', 7013, '{"category":"AUTH","emoji":"⏱️"}'),
  ('activity_logs.action', 'AUTH_PROFILE_LOAD_FAIL', '인증 프로필 조회 실패', 7014, '{"category":"AUTH","emoji":"⚠️"}'),
  ('activity_logs.action', 'AUTH_REDIRECT', '인증/권한 리디렉트', 7015, '{"category":"AUTH","emoji":"↪️"}'),
  ('activity_logs.action', 'AUTH_PAGE_ACCESS_CHECK_FAIL', '페이지 접근 권한 확인 실패', 7016, '{"category":"AUTH","emoji":"🛡️"}'),
  ('activity_logs.action', 'QR_LOCATION_PERMISSION_BLOCKED', 'QR 위치 권한 차단', 7017, '{"category":"AUTH","emoji":"📍"}'),
  ('activity_logs.action', 'USER_ID_CHECK_FAIL', '아이디 중복 확인 실패', 1060, '{"category":"USER","emoji":"🔎"}'),
  ('activity_logs.action', 'USER_ID_CHECK_DUPLICATE', '아이디 중복', 1070, '{"category":"USER","emoji":"🔎"}'),
  ('activity_logs.action', 'BULK_REGISTER', '학생 일괄 등록', 2040, '{"category":"REGISTER","emoji":"📥"}')
ON CONFLICT (group_key, code_key) DO UPDATE
SET code_value = EXCLUDED.code_value,
    sort_order = EXCLUDED.sort_order,
    meta = EXCLUDED.meta,
    is_active = true,
    updated_at = now();

CREATE OR REPLACE FUNCTION public.koreanize_activity_log_details(p_action text, p_details jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v jsonb := COALESCE(p_details, '{}'::jsonb);
  action_label text;
  entry record;
  key_label text;
  text_value text;
  localized_value jsonb;
BEGIN
  SELECT code_value
    INTO action_label
    FROM public.code_items
   WHERE group_key = 'activity_logs.action'
     AND code_key = p_action
     AND is_active = true
   LIMIT 1;

  action_label := COALESCE(NULLIF(v->>'_actionKo', ''), NULLIF(v->>'_actionLabel', ''), action_label, p_action);

  IF action_label IS NOT NULL THEN
    v := v || jsonb_build_object('_actionLabel', action_label, '_actionKo', action_label, '작업', action_label);
  END IF;

  IF p_action IS NOT NULL THEN
    v := v || jsonb_build_object('_actionKey', p_action, '_actionEn', p_action, '작업코드', p_action);
  END IF;

  IF v ? '_userName' AND NOT (v ? '작업자') THEN
    v := v || jsonb_build_object('작업자', v->>'_userName');
  END IF;

  IF v ? '_username' AND NOT (v ? '작업자 아이디') THEN
    v := v || jsonb_build_object('작업자 아이디', v->>'_username');
  END IF;

  IF v ? '_client' AND NOT (v ? '클라이언트') THEN
    v := v || jsonb_build_object('클라이언트', v->'_client');
  END IF;

  FOR entry IN SELECT * FROM jsonb_each(v) LOOP
    key_label := CASE entry.key
      WHEN 'message' THEN '메시지'
      WHEN 'details' THEN '상세'
      WHEN 'detail' THEN '상세'
      WHEN 'error' THEN '오류'
      WHEN 'reason' THEN '사유'
      WHEN 'target' THEN '대상'
      WHEN 'targetName' THEN '대상'
      WHEN 'displayName' THEN '표시 이름'
      WHEN 'name' THEN '이름'
      WHEN 'username' THEN '아이디'
      WHEN 'userName' THEN '사용자 이름'
      WHEN 'userId' THEN '사용자 ID'
      WHEN 'authUserId' THEN '인증 사용자 ID'
      WHEN 'user_type' THEN '사용자 유형'
      WHEN 'userType' THEN '사용자 유형'
      WHEN 'class_number' THEN '반'
      WHEN 'classNumber' THEN '반'
      WHEN 'roleKey' THEN '역할'
      WHEN 'permissionKey' THEN '권한'
      WHEN 'permissionLevel' THEN '권한 등급'
      WHEN 'permissionRank' THEN '권한 순위'
      WHEN 'cachedUsername' THEN '캐시된 아이디'
      WHEN 'cachedPermissionLevel' THEN '캐시된 권한 등급'
      WHEN 'cachedPermissionRank' THEN '캐시된 권한 순위'
      WHEN 'hasCachedSession' THEN '캐시 세션 여부'
      WHEN 'lastActivityAt' THEN '마지막 활동 일시'
      WHEN 'idleExpired' THEN '유휴 만료 여부'
      WHEN 'page' THEN '페이지'
      WHEN 'pageId' THEN '페이지 ID'
      WHEN 'pageName' THEN '페이지명'
      WHEN 'filename' THEN '파일명'
      WHEN 'lineno' THEN '줄 번호'
      WHEN 'colno' THEN '열 번호'
      WHEN 'url' THEN 'URL'
      WHEN 'imageUrl' THEN '이미지 URL'
      WHEN 'filePath' THEN '파일 경로'
      WHEN 'currentVersion' THEN '현재 버전'
      WHEN 'latestVersion' THEN '최신 버전'
      WHEN 'sessionVersion' THEN '세션 버전'
      WHEN '현재페이지버전' THEN '현재 페이지 버전'
      WHEN '최신버전' THEN '최신 버전'
      WHEN '세션버전' THEN '세션 버전'
      WHEN '요청페이지' THEN '요청 페이지'
      WHEN '이동대상' THEN '이동 대상'
      WHEN 'dateFrom' THEN '시작일'
      WHEN 'dateTo' THEN '종료일'
      WHEN 'level' THEN '레벨'
      WHEN 'logId' THEN '로그 ID'
      WHEN 'count' THEN '건수'
      WHEN 'total' THEN '전체'
      WHEN 'totalCount' THEN '전체 건수'
      WHEN 'itemId' THEN '항목 ID'
      WHEN 'itemName' THEN '항목명'
      WHEN 'taskId' THEN '작업 ID'
      WHEN 'taskTitle' THEN '작업 제목'
      WHEN 'product_id' THEN '상품 ID'
      WHEN 'productId' THEN '상품 ID'
      WHEN 'product_name' THEN '상품명'
      WHEN 'productName' THEN '상품명'
      WHEN 'category' THEN '카테고리'
      WHEN 'categoryCode' THEN '카테고리 코드'
      WHEN 'categoryName' THEN '카테고리명'
      WHEN 'emoji' THEN '이모지'
      WHEN 'sort_order' THEN '표시 순번'
      WHEN 'sortOrder' THEN '표시 순번'
      WHEN 'displayOrder' THEN '표시 순번'
      WHEN 'orderId' THEN '주문 ID'
      WHEN 'orderNo' THEN '주문번호'
      WHEN 'status' THEN '상태'
      WHEN 'state' THEN '상태'
      WHEN 'oldStatus' THEN '이전 상태'
      WHEN 'newStatus' THEN '변경 상태'
      WHEN 'amount' THEN '수량'
      WHEN 'balance' THEN '잔액'
      WHEN 'price' THEN '가격'
      WHEN 'pending' THEN '대기 달란트'
      WHEN 'available' THEN '사용 가능 달란트'
      WHEN 'talentBalance' THEN '달란트 잔액'
      WHEN 'talent_balance' THEN '달란트 잔액'
      WHEN 'pendingTalent' THEN '보류 달란트'
      WHEN 'pending_talent' THEN '보류 달란트'
      WHEN 'department' THEN '부서'
      WHEN 'departmentId' THEN '부서 ID'
      WHEN 'departmentName' THEN '부서명'
      WHEN 'fromDept' THEN '이전 부서'
      WHEN 'toDept' THEN '이동 부서'
      WHEN 'fromDeptName' THEN '이전 부서명'
      WHEN 'toDeptName' THEN '이동 부서명'
      WHEN 'success' THEN '성공'
      WHEN 'fail' THEN '실패'
      WHEN 'failed' THEN '실패'
      WHEN 'old' THEN '이전 값'
      WHEN 'new' THEN '변경 값'
      WHEN 'oldValue' THEN '이전 값'
      WHEN 'newValue' THEN '변경 값'
      WHEN 'before' THEN '이전 값'
      WHEN 'after' THEN '변경 값'
      WHEN 'is_active' THEN '활성 상태'
      WHEN 'isActive' THEN '활성 상태'
      WHEN 'is_deleted' THEN '삭제 상태'
      WHEN 'isDeleted' THEN '삭제 상태'
      ELSE NULL
    END;

    IF key_label IS NOT NULL AND key_label <> entry.key AND NOT (v ? key_label) THEN
      localized_value := entry.value;

      IF jsonb_typeof(entry.value) = 'boolean' THEN
        localized_value := to_jsonb(CASE WHEN entry.value = 'true'::jsonb THEN '예' ELSE '아니오' END);
      ELSIF jsonb_typeof(entry.value) = 'string' THEN
        text_value := trim(both '"' from entry.value::text);
        localized_value := to_jsonb(CASE text_value
          WHEN 'teacher' THEN '교사'
          WHEN 'student' THEN '학생'
          WHEN 'admin' THEN '관리자'
          WHEN 'super_admin' THEN '최고 관리자'
          WHEN 'evangelist' THEN '전도사님'
          WHEN 'chief' THEN '부장 교사'
          WHEN 'purchase_teacher' THEN '구매 담당 교사'
          WHEN 'dept_teacher' THEN '부서 담당 교사'
          WHEN 'pending' THEN '대기'
          WHEN 'approved' THEN '승인'
          WHEN 'rejected' THEN '거부'
          WHEN 'requested' THEN '요청됨'
          WHEN 'preparing' THEN '준비 중'
          WHEN 'purchased' THEN '구매 완료'
          WHEN 'delivered' THEN '지급 완료'
          WHEN 'cancelled' THEN '취소됨'
          WHEN 'active' THEN '활성'
          WHEN 'inactive' THEN '비활성'
          WHEN 'ALL' THEN '전체'
          WHEN 'desktop' THEN '데스크톱'
          WHEN 'mobile' THEN '모바일'
          WHEN 'tablet' THEN '태블릿'
          WHEN 'Unknown' THEN '알 수 없음'
          WHEN 'unknown' THEN '알 수 없음'
          WHEN 'Supabase client not initialized' THEN 'Supabase 클라이언트 초기화 안 됨'
          WHEN 'Supabase auth session error' THEN 'Supabase 인증 세션 오류'
          WHEN 'Supabase auth session exception' THEN 'Supabase 인증 세션 예외'
          WHEN 'Supabase auth session missing' THEN 'Supabase 인증 세션 없음'
          WHEN 'Profile RPC returned no profile' THEN '프로필 RPC 결과 없음'
          ELSE text_value
        END);
      END IF;

      v := v || jsonb_build_object(key_label, localized_value);
    END IF;
  END LOOP;

  RETURN v;
END;
$$;

UPDATE public.activity_logs
   SET details = public.koreanize_activity_log_details(action, details)
 WHERE details IS NOT NULL;

DROP FUNCTION IF EXISTS public.koreanize_activity_log_details(text, jsonb);

COMMIT;
