-- ============================================================
-- TASK-057 롤백: 공통 코드 마스터 도입 전체 되돌리기
-- 대상: TASK-057_code_master.sql 의 모든 변경을 역순으로 복원
-- 주의: 반드시 [사전 검증]을 먼저 실행하여 안전 여부를 확인한 후 롤백을 진행하세요.
-- ============================================================


-- ████████████████████████████████████████████████████████████
-- [사전 검증] — 롤백 실행 전 반드시 아래 쿼리를 개별 실행하세요
-- 결과가 0건이어야 롤백이 안전합니다.
-- ████████████████████████████████████████████████████████████

-- ① profiles.permission_level에 'super_admin'이 있으면 롤백 후 CHECK 충돌
-- → 결과가 있으면 해당 행의 permission_level을 'admin'으로 변경 후 롤백
SELECT id, username, permission_level
FROM public.profiles
WHERE permission_level NOT IN (
  'admin','evangelist','chief','purchase_teacher','dept_teacher','teacher','student'
);

-- ② registration_requests.permission_level 점검
SELECT id, username, permission_level
FROM public.registration_requests
WHERE permission_level NOT IN (
  'admin','evangelist','chief','purchase_teacher','dept_teacher','teacher','student'
);

-- ③ registration_requests.status 점검
SELECT id, status FROM public.registration_requests
WHERE status NOT IN ('pending','approved','rejected');

-- ④ department_transfer_requests.status 점검
SELECT id, status FROM public.department_transfer_requests
WHERE status NOT IN ('pending','approved','rejected');

-- ⑤ talent_items.target_type 점검
SELECT id, target_type FROM public.talent_items
WHERE target_type NOT IN ('teacher','student');

-- ⑥ talent_transactions.type 점검
SELECT id, type FROM public.talent_transactions
WHERE type NOT IN ('earn','use');

-- ⑦ products.target_role 점검
SELECT id, target_role FROM public.products
WHERE target_role NOT IN ('teacher','student');

-- ⑧ product_orders.status 점검
SELECT id, status FROM public.product_orders
WHERE status NOT IN ('requested','preparing','purchased','delivered','cancelled');

-- ⑨ qna.status 점검
SELECT id, status FROM public.qna
WHERE status NOT IN ('pending','answered','faq');

-- ⑩ reports.report_type 점검
SELECT id, report_type FROM public.reports
WHERE report_type NOT IN ('plan','test_scenario','test_result','change_report','security_report');

-- ⑪ report_events.event_type 점검
SELECT id, event_type FROM public.report_events
WHERE event_type NOT IN ('created','updated','confirmed','reconfirmed','status_changed');

-- ⑫ user_preferences.theme 점검
SELECT user_id, theme FROM public.user_preferences
WHERE theme NOT IN ('default','dark','spring','summer','autumn','winter');

-- ⑬ activity_logs.level 점검 (원본 CHECK가 유지되어 있으므로 보통 안전)
SELECT id, level FROM public.activity_logs
WHERE level NOT IN ('TRACE','DEBUG','INFO','WARN','ERROR','FATAL','CRITICAL');


-- ████████████████████████████████████████████████████████████
-- [롤백 본문] — 사전 검증 통과 후 아래 트랜잭션을 실행하세요
-- ████████████████████████████████████████████████████████████

BEGIN;

-- ============================================================
-- 1. 코드 마스터 검증 트리거 제거 (13개 테이블)
-- ============================================================

DROP TRIGGER IF EXISTS trg_code_profiles ON public.profiles;
DROP TRIGGER IF EXISTS trg_code_registration_requests ON public.registration_requests;
DROP TRIGGER IF EXISTS trg_code_department_transfer_requests ON public.department_transfer_requests;
DROP TRIGGER IF EXISTS trg_code_talent_items ON public.talent_items;
DROP TRIGGER IF EXISTS trg_code_talent_transactions ON public.talent_transactions;
DROP TRIGGER IF EXISTS trg_code_products ON public.products;
DROP TRIGGER IF EXISTS trg_code_product_orders ON public.product_orders;
DROP TRIGGER IF EXISTS trg_code_qna ON public.qna;
DROP TRIGGER IF EXISTS trg_code_reports ON public.reports;
DROP TRIGGER IF EXISTS trg_code_report_events ON public.report_events;
DROP TRIGGER IF EXISTS trg_code_user_preferences ON public.user_preferences;
DROP TRIGGER IF EXISTS trg_code_talent_qr_codes ON public.talent_qr_codes;
DROP TRIGGER IF EXISTS trg_code_activity_logs_level ON public.activity_logs;

-- ============================================================
-- 2. 원본 CHECK 제약조건 복원 (14개)
--    INITIAL_DATABASE_SETUP.sql + TASK-040 + TASK-048 기준
-- ============================================================

-- profiles
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_user_type_check
  CHECK (user_type IN ('teacher','student'));

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_permission_level_check
  CHECK (permission_level IN ('admin','evangelist','chief','purchase_teacher','dept_teacher','teacher','student'));

-- registration_requests
ALTER TABLE public.registration_requests
  ADD CONSTRAINT registration_requests_status_check
  CHECK (status IN ('pending','approved','rejected'));

ALTER TABLE public.registration_requests
  ADD CONSTRAINT registration_requests_user_type_check
  CHECK (user_type IN ('teacher','student'));

ALTER TABLE public.registration_requests
  ADD CONSTRAINT registration_requests_permission_level_check
  CHECK (permission_level IN ('admin','evangelist','chief','purchase_teacher','dept_teacher','teacher','student'));

-- department_transfer_requests
ALTER TABLE public.department_transfer_requests
  ADD CONSTRAINT department_transfer_requests_status_check
  CHECK (status IN ('pending','approved','rejected'));

-- talent_items
ALTER TABLE public.talent_items
  ADD CONSTRAINT talent_items_target_type_check
  CHECK (target_type IN ('teacher','student'));

-- talent_transactions
ALTER TABLE public.talent_transactions
  ADD CONSTRAINT talent_transactions_type_check
  CHECK (type IN ('earn','use'));

-- products
ALTER TABLE public.products
  ADD CONSTRAINT products_target_role_check
  CHECK (target_role IN ('teacher','student'));

-- product_orders
ALTER TABLE public.product_orders
  ADD CONSTRAINT product_orders_status_check
  CHECK (status IN ('requested','preparing','purchased','delivered','cancelled'));

-- qna
ALTER TABLE public.qna
  ADD CONSTRAINT qna_status_check
  CHECK (status IN ('pending','answered','faq'));

-- reports
ALTER TABLE public.reports
  ADD CONSTRAINT reports_report_type_check
  CHECK (report_type IN ('plan','test_scenario','test_result','change_report','security_report'));

-- report_events
ALTER TABLE public.report_events
  ADD CONSTRAINT report_events_event_type_check
  CHECK (event_type IN ('created','updated','confirmed','reconfirmed','status_changed'));

-- user_preferences
ALTER TABLE public.user_preferences
  ADD CONSTRAINT user_preferences_theme_check
  CHECK (theme IN ('default','dark','spring','summer','autumn','winter'));

-- ============================================================
-- 3. 코드 마스터 전용 함수 제거
-- ============================================================

DROP FUNCTION IF EXISTS public.validate_code_columns() CASCADE;
DROP FUNCTION IF EXISTS public.get_code_value(text, text);

-- ============================================================
-- 4. get_permission_rank(text) 를 원본(IMMUTABLE)으로 복원
--    TASK-048 기준: purchase_teacher(70) 포함, super_admin 미포함
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_permission_rank(p_level text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_level
    WHEN 'admin' THEN 100
    WHEN 'evangelist' THEN 90
    WHEN 'chief' THEN 80
    WHEN 'purchase_teacher' THEN 70
    WHEN 'dept_teacher' THEN 60
    WHEN 'teacher' THEN 40
    WHEN 'student' THEN 20
    ELSE 0
  END;
END;
$$;

-- ============================================================
-- 5. code_groups / code_items RLS 정책 및 권한 제거
-- ============================================================

DROP POLICY IF EXISTS code_groups_select ON public.code_groups;
DROP POLICY IF EXISTS code_items_select ON public.code_items;
DROP POLICY IF EXISTS code_groups_manage ON public.code_groups;
DROP POLICY IF EXISTS code_items_manage ON public.code_items;

REVOKE ALL ON public.code_groups FROM anon, authenticated;
REVOKE ALL ON public.code_items FROM anon, authenticated;

-- ============================================================
-- 6. code_groups / code_items updated_at 트리거 제거
-- ============================================================

DROP TRIGGER IF EXISTS trg_code_groups_updated_at ON public.code_groups;
DROP TRIGGER IF EXISTS trg_code_items_updated_at ON public.code_items;

-- ============================================================
-- 7. 인덱스 및 테이블 제거 (code_items → code_groups 순서)
-- ============================================================

DROP INDEX IF EXISTS public.idx_code_items_group_sort;
DROP TABLE IF EXISTS public.code_items;
DROP TABLE IF EXISTS public.code_groups;

-- set_updated_at() 함수는 기존에도 동일하게 존재하므로 유지
-- extensions 스키마 / pgcrypto 확장도 기존에 존재하므로 유지

NOTIFY pgrst, 'reload schema';

COMMIT;


-- ████████████████████████████████████████████████████████████
-- [사후 검증] — 롤백 완료 후 아래 쿼리로 정상 복원을 확인하세요
-- ████████████████████████████████████████████████████████████

-- ① 코드 마스터 테이블이 제거되었는지 확인 (0건이어야 정상)
SELECT tablename FROM pg_tables
WHERE schemaname = 'public' AND tablename IN ('code_groups','code_items');

-- ② 검증 트리거가 모두 제거되었는지 확인 (0건이어야 정상)
SELECT tgname, relname
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE tgname LIKE 'trg_code_%'
  AND NOT tgisinternal;

-- ③ CHECK 제약조건이 복원되었는지 확인 (14건이어야 정상)
SELECT conname, conrelid::regclass AS table_name
FROM pg_constraint
WHERE conname IN (
  'profiles_user_type_check',
  'profiles_permission_level_check',
  'registration_requests_status_check',
  'registration_requests_user_type_check',
  'registration_requests_permission_level_check',
  'department_transfer_requests_status_check',
  'talent_items_target_type_check',
  'talent_transactions_type_check',
  'products_target_role_check',
  'product_orders_status_check',
  'qna_status_check',
  'reports_report_type_check',
  'report_events_event_type_check',
  'user_preferences_theme_check'
)
ORDER BY conrelid::regclass::text;

-- ④ get_permission_rank(text) 함수가 IMMUTABLE로 복원되었는지 확인
SELECT proname, provolatile, prosecdef
FROM pg_proc
WHERE proname = 'get_permission_rank'
  AND proargtypes::text = (SELECT oid::text FROM pg_type WHERE typname = 'text');
-- provolatile = 'i' (IMMUTABLE), prosecdef = false 이어야 정상

-- ⑤ validate_code_columns, get_code_value 함수가 제거되었는지 확인 (0건이어야 정상)
SELECT proname FROM pg_proc
WHERE proname IN ('validate_code_columns','get_code_value')
  AND pronamespace = 'public'::regnamespace;

-- ⑥ 기존 기능 동작 검증: permission_rank 함수 호출 테스트
SELECT public.get_permission_rank('admin') AS admin_rank,       -- 100
       public.get_permission_rank('evangelist') AS evang_rank,  -- 90
       public.get_permission_rank('chief') AS chief_rank,       -- 80
       public.get_permission_rank('teacher') AS teacher_rank,   -- 40
       public.get_permission_rank('student') AS student_rank;   -- 20
