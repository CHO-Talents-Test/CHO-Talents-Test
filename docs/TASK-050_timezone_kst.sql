-- ============================================
-- TASK-050: DB 타임존을 Asia/Seoul(KST)로 변경
-- 실행 위치: Supabase SQL Editor (관리자 권한 필요)
-- 목적: now() 및 모든 timestamptz 기본값이 KST 기준으로 동작하도록 설정
-- ============================================

-- 1. 데이터베이스 전체 타임존을 Asia/Seoul로 변경
ALTER DATABASE postgres SET timezone TO 'Asia/Seoul';

-- 2. 현재 세션에도 즉시 적용
SET timezone = 'Asia/Seoul';

-- 3. 변경 확인 (KST = UTC+9, 현재 시간이 한국 시간으로 표시되어야 함)
SELECT now() AS current_kst_time, current_setting('TIMEZONE') AS timezone_setting;

-- ============================================
-- 참고사항:
-- - timestamptz 컬럼은 내부적으로 항상 UTC로 저장됩니다.
-- - timezone 설정은 표시/비교 시 변환 기준을 결정합니다.
-- - now() 함수의 반환값이 KST 기준으로 표시됩니다.
-- - 기존 데이터는 변경 없이 정상 동작합니다 (UTC 저장, KST 표시).
-- - Supabase JS 클라이언트는 항상 UTC ISO 문자열을 반환하므로
--   프론트엔드의 formatKSTShort() 변환 로직은 그대로 유지합니다.
-- - 이 설정 후 새 연결(새 세션)부터 적용됩니다.
--   즉시 적용을 위해 SET timezone도 포함했습니다.
-- ============================================
