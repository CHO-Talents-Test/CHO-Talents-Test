-- ============================================================
-- TASK-013A Schema Changes
-- 유형/권한 6단계 체계 전면 개편 (DB + 인증 코어)
-- Management API로 실행 완료 (2026-05-27)
-- ============================================================

-- 1. profiles 테이블 확장
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_type TEXT NOT NULL DEFAULT 'student'
  CHECK (user_type IN ('teacher', 'student'));
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS permission_level TEXT NOT NULL DEFAULT 'student'
  CHECK (permission_level IN ('admin','evangelist','chief','dept_teacher','teacher','student'));
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_super_admin BOOLEAN DEFAULT false;

-- 2. 기존 데이터 마이그레이션
UPDATE profiles SET user_type = 'teacher', permission_level = 'admin'        WHERE role = 'admin';
UPDATE profiles SET user_type = 'teacher', permission_level = 'dept_teacher' WHERE role = 'dept_manager';
UPDATE profiles SET user_type = 'teacher', permission_level = 'teacher'      WHERE role = 'teacher';
UPDATE profiles SET user_type = 'student', permission_level = 'student'      WHERE role = 'student';

-- 3. 최고관리자 설정
UPDATE profiles SET is_super_admin = true, display_name = '관리자(admin)' WHERE username = 'admin_user';

-- 4. registration_requests 테이블 확장
ALTER TABLE registration_requests ADD COLUMN IF NOT EXISTS user_type TEXT NOT NULL DEFAULT 'student'
  CHECK (user_type IN ('teacher', 'student'));
ALTER TABLE registration_requests ADD COLUMN IF NOT EXISTS permission_level TEXT NOT NULL DEFAULT 'student'
  CHECK (permission_level IN ('admin','evangelist','chief','dept_teacher','teacher','student'));

-- 5. 권한 레벨 숫자 변환 헬퍼 함수
CREATE OR REPLACE FUNCTION get_permission_rank(p_level TEXT)
RETURNS INT AS $$
BEGIN
  RETURN CASE p_level
    WHEN 'admin' THEN 100 WHEN 'evangelist' THEN 90 WHEN 'chief' THEN 80
    WHEN 'dept_teacher' THEN 60 WHEN 'teacher' THEN 40 WHEN 'student' THEN 20
    ELSE 0 END;
END; $$ LANGUAGE plpgsql IMMUTABLE;

-- 6. RPC 함수 12개 업데이트 (get_my_profile, get_my_role, admin_list_users,
--    admin_create_user, admin_update_user, admin_delete_user, admin_reset_password,
--    give_talent, use_talent, change_my_password, check_username_available, get_my_managed_dept_id)
-- 모든 함수가 permission_level 기반 권한 체크로 전환됨
-- 계층적 권한 검증: 상위 권한자 수정/삭제 불가
-- 최고관리자(is_super_admin) 보호 적용

-- 7. RLS 정책 업데이트 (7개 테이블)
-- activity_logs: chief(80)+ 조회/수정
-- departments: chief(80)+ 생성/수정, evangelist(90)+ 삭제
-- products: dept_teacher(60)+ 생성/수정, evangelist(90)+ 삭제
-- profiles: dept_teacher(60)+ 관리, 본인 조회/수정 유지
-- registration_requests: chief(80)+ 관리
-- talent_transactions: 본인 OR dept_teacher(60)+ 조회
-- reports: chief(80)+ 조회
-- report_events: 본인 OR chief(80)+ 조회/삽입
