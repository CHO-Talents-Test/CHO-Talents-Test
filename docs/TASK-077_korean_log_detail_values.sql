-- TASK-077: activity_logs 영문 상세 문구 한글화 및 action 코드 마스터 보강
-- 적용 대상: 운영 Supabase SQL Editor 또는 `npx supabase db query --linked --file docs/TASK-077_korean_log_detail_values.sql`
-- 목적:
--   1) activity_logs.action DB 코드 마스터 누락 라벨 저장
--   2) 기존 activity_logs.details의 대표 영어 오류/사유/처리 값을 한글 문구로 보정
--   3) 신규 코드는 js/activity-log.js에서 동일 매핑으로 저장 전 한글화함

BEGIN;

INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, is_active, meta)
VALUES
  ('activity_logs.action', 'MY_TALENT_PENDING_QUERY', '대기 달란트 조회 오류', 5095, true, '{"category":"ORDER","emoji":"⚠️"}'::jsonb),
  ('activity_logs.action', 'TALENT_GIVE_ITEM_DENIED', '달란트 항목 지급 거부', 4025, true, '{"category":"TALENT","emoji":"⚠️"}'::jsonb),
  ('activity_logs.action', 'TALENT_GIVE_ITEM_FAIL', '달란트 항목 지급 실패', 4026, true, '{"category":"TALENT","emoji":"⚠️"}'::jsonb),
  ('activity_logs.action', 'TALENT_EXCEPTION_REQUEST', '예외 지급 요청', 4180, true, '{"category":"TALENT","emoji":"📮"}'::jsonb),
  ('activity_logs.action', 'TALENT_EXCEPTION_REQUEST_FAIL', '예외 지급 요청 실패', 4181, true, '{"category":"TALENT","emoji":"⚠️"}'::jsonb),
  ('activity_logs.action', 'TALENT_EXCEPTION_APPROVE', '예외 지급 승인', 4182, true, '{"category":"TALENT","emoji":"✅"}'::jsonb),
  ('activity_logs.action', 'TALENT_EXCEPTION_REJECT', '예외 지급 거부', 4183, true, '{"category":"TALENT","emoji":"❌"}'::jsonb)
ON CONFLICT (group_key, code_key) DO UPDATE SET
  code_value = EXCLUDED.code_value,
  sort_order = EXCLUDED.sort_order,
  is_active = true,
  meta = EXCLUDED.meta,
  updated_at = now();

CREATE OR REPLACE FUNCTION pg_temp.cho_translate_log_detail_string(p_key text, p_value text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v text := p_value;
  suffix text;
BEGIN
  IF v IS NULL THEN
    RETURN v;
  END IF;

  CASE v
    WHEN 'Supabase auth session missing' THEN RETURN 'Supabase 인증 세션 없음';
    WHEN 'Supabase auth session error' THEN RETURN 'Supabase 인증 세션 오류';
    WHEN 'Supabase auth session exception' THEN RETURN 'Supabase 인증 세션 예외';
    WHEN 'Profile RPC returned no profile' THEN RETURN '프로필 RPC 결과 없음';
    WHEN 'Invalid login credentials' THEN RETURN '로그인 정보가 일치하지 않습니다';
    WHEN 'TypeError: Load failed' THEN RETURN '로드 실패';
    WHEN 'Load failed' THEN RETURN '로드 실패';
    WHEN 'Failed to fetch' THEN RETURN '네트워크 요청 실패';
    WHEN 'fetch failed' THEN RETURN '네트워크 요청 실패';
    WHEN 'Network request failed' THEN RETURN '네트워크 요청 실패';
    WHEN 'NetworkError when attempting to fetch resource.' THEN RETURN '네트워크 리소스 요청 실패';
    WHEN 'The network connection was lost.' THEN RETURN '네트워크 연결이 끊어졌습니다';
    WHEN 'Script error.' THEN RETURN '스크립트 오류';
    WHEN 'User denied Geolocation' THEN RETURN '사용자가 위치 권한을 거부했습니다';
    WHEN 'Cannot coerce the result to a single JSON object' THEN RETURN '단일 결과로 변환할 수 없습니다';
    WHEN 'permission denied for table profiles' THEN RETURN 'profiles 테이블 권한이 없습니다';
    WHEN 'Unauthorized' THEN RETURN '권한이 없습니다';
    WHEN 'JWT expired' THEN RETURN '인증 토큰이 만료되었습니다';
    WHEN 'Invalid JWT' THEN RETURN '유효하지 않은 인증 토큰입니다';
    WHEN 'refresh_token_not_found' THEN RETURN '세션 갱신 토큰을 찾을 수 없습니다';
    WHEN 'Email not confirmed' THEN RETURN '이메일 인증이 완료되지 않았습니다';
    WHEN 'User already registered' THEN RETURN '이미 등록된 사용자입니다';
    WHEN 'Failed to send a request to the Edge Function' THEN RETURN 'Edge Function 요청 전송 실패';
    WHEN 'Edge Function returned a non-2xx status code' THEN RETURN 'Edge Function이 오류 상태를 반환했습니다';
    WHEN 'last_activity' THEN RETURN '마지막 활동 기준';
    WHEN 'idle_timer' THEN RETURN '유휴 타이머 기준';
    WHEN 'visibilitychange' THEN RETURN '탭 재활성화 기준';
    WHEN 'weekly_duplicate' THEN RETURN '주간 중복 지급';
    WHEN 'duplicate_pending' THEN RETURN '이미 대기 중인 요청';
    WHEN 'cached_session' THEN RETURN '캐시 세션으로 복구';
    WHEN 'profiles_fallback' THEN RETURN '프로필 직접 조회로 복구';
    WHEN 'cancel_aborted_before_partial_update' THEN RETURN '부분 취소 방지를 위해 중단';
    WHEN 'teacher' THEN
      IF p_key ILIKE '%permission%' OR p_key IN ('permissionLabel','permissionLevel','cachedPermissionLevel','권한','실제권한','userType','user_type') THEN RETURN '교사'; END IF;
    WHEN 'student' THEN
      IF p_key ILIKE '%permission%' OR p_key IN ('permissionLabel','permissionLevel','cachedPermissionLevel','권한','실제권한','userType','user_type') THEN RETURN '학생'; END IF;
    WHEN 'admin' THEN
      IF p_key ILIKE '%permission%' OR p_key IN ('permissionLabel','permissionLevel','cachedPermissionLevel','권한','실제권한') THEN RETURN '관리자'; END IF;
    WHEN 'evangelist' THEN
      IF p_key ILIKE '%permission%' OR p_key IN ('permissionLabel','permissionLevel','cachedPermissionLevel','권한','실제권한') THEN RETURN '전도사님'; END IF;
    WHEN 'chief' THEN
      IF p_key ILIKE '%permission%' OR p_key IN ('permissionLabel','permissionLevel','cachedPermissionLevel','권한','실제권한') THEN RETURN '부장 교사'; END IF;
    WHEN 'purchase_teacher' THEN
      IF p_key ILIKE '%permission%' OR p_key IN ('permissionLabel','permissionLevel','cachedPermissionLevel','권한','실제권한') THEN RETURN '구매 담당 교사'; END IF;
    WHEN 'dept_teacher' THEN
      IF p_key ILIKE '%permission%' OR p_key IN ('permissionLabel','permissionLevel','cachedPermissionLevel','권한','실제권한') THEN RETURN '부서 담당 교사'; END IF;
    WHEN 'requested' THEN
      IF p_key ILIKE '%status%' OR p_key IN ('상태','변경상태') THEN RETURN '요청됨'; END IF;
    WHEN 'preparing' THEN
      IF p_key ILIKE '%status%' OR p_key IN ('상태','변경상태') THEN RETURN '준비 중'; END IF;
    WHEN 'purchased' THEN
      IF p_key ILIKE '%status%' OR p_key IN ('상태','변경상태') THEN RETURN '구매 완료'; END IF;
    WHEN 'delivered' THEN
      IF p_key ILIKE '%status%' OR p_key IN ('상태','변경상태') THEN RETURN '지급 완료'; END IF;
    WHEN 'cancelled' THEN
      IF p_key ILIKE '%status%' OR p_key IN ('상태','변경상태') THEN RETURN '취소됨'; END IF;
    WHEN 'admin-dashboard' THEN RETURN '관리자 대시보드';
    WHEN 'admin-users' THEN RETURN '사용자 관리';
    WHEN 'admin-talents' THEN RETURN '달란트 관리';
    WHEN 'admin-service-stats' THEN RETURN '서비스 통계';
    WHEN 'my-talents' THEN RETURN '내 달란트';
    WHEN 'talent-receive' THEN RETURN 'QR 달란트 수령';
    ELSE NULL;
  END CASE;

  suffix := substring(v from '^Already given this item this week:\s*(.+)$');
  IF suffix IS NOT NULL THEN
    RETURN '이번 주에 이미 지급된 항목입니다: ' || suffix;
  END IF;

  suffix := substring(v from '^permission denied for table ([A-Za-z0-9_.]+)$');
  IF suffix IS NOT NULL THEN
    RETURN suffix || ' 테이블 권한이 없습니다';
  END IF;

  IF v ~* '^relation ".+" does not exist$' THEN
    RETURN '필요한 테이블 또는 뷰를 찾을 수 없습니다';
  END IF;

  IF v ~* '^function .+ does not exist$' OR v ~* '^Could not find the function' THEN
    RETURN '필요한 DB 함수를 찾을 수 없습니다';
  END IF;

  IF v ~* 'row-level security policy' THEN
    RETURN '행 수준 보안(RLS) 정책에 의해 요청이 거부되었습니다';
  END IF;

  IF v ~* '^duplicate key value violates unique constraint' THEN
    RETURN '중복된 데이터로 저장할 수 없습니다';
  END IF;

  RETURN v;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.cho_translate_log_detail_json(p_json jsonb, p_key text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  item record;
  out_json jsonb := '{}'::jsonb;
  out_arr jsonb := '[]'::jsonb;
BEGIN
  IF p_json IS NULL THEN
    RETURN p_json;
  END IF;

  CASE jsonb_typeof(p_json)
    WHEN 'object' THEN
      FOR item IN SELECT key, value FROM jsonb_each(p_json)
      LOOP
        out_json := out_json || jsonb_build_object(item.key, pg_temp.cho_translate_log_detail_json(item.value, item.key));
      END LOOP;
      RETURN out_json;
    WHEN 'array' THEN
      FOR item IN SELECT value FROM jsonb_array_elements(p_json)
      LOOP
        out_arr := out_arr || jsonb_build_array(pg_temp.cho_translate_log_detail_json(item.value, p_key));
      END LOOP;
      RETURN out_arr;
    WHEN 'string' THEN
      RETURN to_jsonb(pg_temp.cho_translate_log_detail_string(p_key, p_json #>> '{}'));
    ELSE
      RETURN p_json;
  END CASE;
END;
$$;

WITH candidates AS (
  SELECT
    id,
    details,
    pg_temp.cho_translate_log_detail_json(details) AS translated_details
  FROM public.activity_logs
  WHERE details IS NOT NULL
),
updated AS (
  UPDATE public.activity_logs l
  SET details = c.translated_details
  FROM candidates c
  WHERE l.id = c.id
    AND c.translated_details IS DISTINCT FROM c.details
  RETURNING l.id, l.action
)
SELECT action, count(*)::int AS updated_count
FROM updated
GROUP BY action
ORDER BY action;

COMMIT;
