-- TASK-074: activity_logs.details 영어 key 정규화 및 중복 필드 제거
-- 목적
--   1) 기존 로그 details에 섞여 있는 한글 별칭/기술 key를 영어 key 중심으로 정리
--   2) action/user/level/page/timestamp/client처럼 activity_logs 기본 컬럼 또는 수집 금지 항목과 중복되는 details 제거
--   3) 신규 로그는 js/activity-log.js에서 같은 기준으로 저장되므로, 이 SQL은 기존 데이터 정리용

CREATE OR REPLACE FUNCTION public.normalize_activity_log_details_en(p_details jsonb, p_username text DEFAULT NULL, p_user_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  entry record;
  normalized_key text;
  entry_text text;
  result jsonb := '{}'::jsonb;
  suffix int;
  next_key text;
BEGIN
  IF p_details IS NULL OR jsonb_typeof(p_details) <> 'object' THEN
    RETURN '{}'::jsonb;
  END IF;

  FOR entry IN SELECT * FROM jsonb_each(p_details)
  LOOP
    normalized_key := CASE entry.key
      WHEN '오류' THEN 'error'
      WHEN '에러' THEN 'error'
      WHEN '사유' THEN 'reason'
      WHEN '대상' THEN 'targetName'
      WHEN '아이디' THEN 'targetAccount'
      WHEN '이름' THEN 'targetName'
      WHEN '요청ID' THEN 'requestId'
      WHEN '사용자ID' THEN 'userId'
      WHEN '항목ID' THEN 'itemId'
      WHEN '상품ID' THEN 'productId'
      WHEN '주문ID' THEN 'orderId'
      WHEN '거래ID' THEN 'txnId'
      WHEN '작업ID' THEN 'taskId'
      WHEN '보고서ID' THEN 'reportId'
      WHEN '제목' THEN 'title'
      WHEN '질문ID' THEN 'questionId'
      WHEN '답변자' THEN 'answererName'
      WHEN 'FAQ여부' THEN 'isFaq'
      WHEN '상품명' THEN 'productName'
      WHEN '금액' THEN 'amount'
      WHEN '수량' THEN 'amount'
      WHEN '건수' THEN 'count'
      WHEN '총건수' THEN 'totalCount'
      WHEN '성공' THEN 'successCount'
      WHEN '실패' THEN 'failCount'
      WHEN '실패건수' THEN 'failedCount'
      WHEN '지급건수' THEN 'givenCount'
      WHEN '요청건수' THEN 'requestCount'
      WHEN '구분' THEN 'type'
      WHEN '코드' THEN 'code'
      WHEN '카테고리' THEN 'categoryName'
      WHEN '필드' THEN 'field'
      WHEN '이미지' THEN 'hasImage'
      WHEN '설명' THEN 'description'
      WHEN '유형' THEN 'type'
      WHEN '공지ID' THEN 'noticeId'
      WHEN '활성' THEN 'isActive'
      WHEN '활성여부' THEN 'isActive'
      WHEN '변경상태' THEN 'newStatus'
      WHEN '이전상태' THEN 'oldStatus'
      WHEN '이전값' THEN 'oldValue'
      WHEN '변경값' THEN 'newValue'
      WHEN '변경내역' THEN 'changeSummary'
      WHEN '권한' THEN 'permissionLabel'
      WHEN '부서' THEN 'departmentName'
      WHEN '부서명' THEN 'departmentName'
      WHEN '이전부서' THEN 'fromDeptName'
      WHEN '이동부서' THEN 'toDeptName'
      WHEN '반' THEN 'classNumber'
      WHEN '항목명' THEN 'itemName'
      WHEN '주문번호' THEN 'orderNo'
      WHEN '요청페이지' THEN 'requestedPage'
      WHEN '이동대상' THEN 'redirectTarget'
      WHEN '현재페이지버전' THEN 'currentPageVersion'
      WHEN '최신버전' THEN 'latestVersion'
      WHEN '세션버전' THEN 'sessionVersion'
      ELSE entry.key
    END;

    IF entry.key IN (
      '_actionKey', '_actionEn', '_actionLabel', '_actionKo',
      '_userAccount', '_username', '_userName', '_displayName',
      '_client', 'client', '클라이언트',
      'actorAccount', 'actorName', 'actorId',
      'username', 'displayName', 'userName', 'cachedUsername', 'authUserId',
      'actionCode', 'actionLabel',
      'level', 'logLevel', 'page', 'logPage',
      'createdAt', 'created_at', 'timestamp', 'time', 'loggedAt',
      '작업', '작업코드', '작업명', '작업자', '작업자 아이디',
      '레벨', '페이지', '시간', '일시', '작성일시',
      '로그 작성 일시', '로그 발생 페이지', '로그 레벨'
    ) OR left(entry.key, 1) = '_' THEN
      CONTINUE;
    END IF;

	    IF normalized_key IN (
	      'client', 'actorAccount', 'actorName', 'actorId',
	      'username', 'displayName', 'userName', 'cachedUsername', 'authUserId',
	      'actionCode', 'actionLabel', 'logLevel', 'logPage', 'loggedAt'
	    ) THEN
	      CONTINUE;
	    END IF;

    entry_text := NULLIF(entry.value #>> '{}', '');
    IF normalized_key IN ('targetAccount', 'targetName', 'targetUser', 'userId', 'targetUserId')
       AND entry_text IS NOT NULL
       AND entry_text IN (p_username, p_user_name) THEN
      CONTINUE;
    END IF;

    IF NOT result ? normalized_key THEN
      result := result || jsonb_build_object(normalized_key, entry.value);
    ELSIF result->normalized_key = entry.value THEN
      CONTINUE;
    ELSE
      suffix := 2;
      LOOP
        next_key := normalized_key || suffix::text;
        EXIT WHEN NOT result ? next_key;
        IF result->next_key = entry.value THEN
          next_key := NULL;
          EXIT;
        END IF;
        suffix := suffix + 1;
      END LOOP;
      IF next_key IS NOT NULL THEN
        result := result || jsonb_build_object(next_key, entry.value);
      END IF;
    END IF;
  END LOOP;

  RETURN result;
END;
$$;

UPDATE public.activity_logs
   SET details = public.normalize_activity_log_details_en(details, username, user_name)
 WHERE details IS NOT NULL;

DROP FUNCTION IF EXISTS public.normalize_activity_log_details_en(jsonb, text, text);
DROP FUNCTION IF EXISTS public.normalize_activity_log_details_en(jsonb);
