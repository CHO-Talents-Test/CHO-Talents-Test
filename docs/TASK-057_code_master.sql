-- ============================================================
-- TASK-057: 공통 코드 마스터 도입
-- - 문자열 enum처럼 쓰던 권한/유형/상태/구분 컬럼을 code_groups/code_items로 관리
-- - 기존 컬럼값은 유지하되, 신규/수정 데이터는 코드 마스터에 등록된 code_key를 사용
-- - activity_logs.action은 로그 적재 안정성을 위해 강제 트리거 대신 라벨 마스터로 관리
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- ============================================================
-- 0. Prerequisite schema backfill
-- ============================================================

ALTER TABLE public.talent_transactions
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'admin';

UPDATE public.talent_transactions
SET source = 'admin'
WHERE source IS NULL OR btrim(source) = '';

COMMENT ON COLUMN public.talent_transactions.source
  IS 'admin = 관리자/RPC 지급, qr = QR 수령';

ALTER TABLE public.talent_qr_codes
  ADD COLUMN IF NOT EXISTS target_type text DEFAULT 'student',
  ADD COLUMN IF NOT EXISTS repeat_type text DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS repeat_days integer[] DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS repeat_weeks integer[] DEFAULT NULL;

UPDATE public.talent_qr_codes
SET target_type = 'student'
WHERE target_type IS NULL OR btrim(target_type) = '';

UPDATE public.talent_qr_codes
SET repeat_type = 'none'
WHERE repeat_type IS NULL OR btrim(repeat_type) = '';

COMMENT ON COLUMN public.talent_qr_codes.target_type
  IS '지급 대상: student 또는 teacher';
COMMENT ON COLUMN public.talent_qr_codes.repeat_type
  IS 'none=1회, daily=매일, weekday=요일반복, week_weekday=주차+요일반복';

-- ============================================================
-- 1. Code master tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.code_groups (
  group_key text PRIMARY KEY,
  group_name text NOT NULL,
  description text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.code_items (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  group_key text NOT NULL REFERENCES public.code_groups(group_key) ON DELETE CASCADE,
  code_key text NOT NULL,
  code_value text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT code_items_group_key_unique UNIQUE (group_key, code_key)
);

CREATE INDEX IF NOT EXISTS idx_code_items_group_sort
  ON public.code_items(group_key, is_active, sort_order, code_key);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_code_groups_updated_at ON public.code_groups;
CREATE TRIGGER trg_code_groups_updated_at
  BEFORE UPDATE ON public.code_groups
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_code_items_updated_at ON public.code_items;
CREATE TRIGGER trg_code_items_updated_at
  BEFORE UPDATE ON public.code_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 2. Seed groups/items
-- ============================================================

INSERT INTO public.code_groups (group_key, group_name, description, sort_order)
VALUES
  ('profiles.permission_level', '권한 등급', 'profiles.permission_level, registration_requests.permission_level', 10),
  ('profiles.user_type', '사용자 유형', 'profiles.user_type, registration_requests.user_type', 20),
  ('request.status', '신청 상태', 'registration_requests.status, department_transfer_requests.status', 30),
  ('product_orders.status', '구매 상태', 'product_orders.status', 40),
  ('products.target_role', '상품 대상', 'products.target_role', 50),
  ('products.category', '상품 카테고리', 'products.category', 60),
  ('talent_items.target_type', '달란트 대상', 'talent_items.target_type, talent_qr_codes.target_type', 70),
  ('talent_transactions.type', '달란트 거래 유형', 'talent_transactions.type', 80),
  ('talent_transactions.source', '달란트 지급 출처', 'talent_transactions.source', 90),
  ('talent_qr_codes.repeat_type', 'QR 반복 유형', 'talent_qr_codes.repeat_type', 100),
  ('qna.status', 'Q&A 상태', 'qna.status', 110),
  ('reports.report_type', '보고서 유형', 'reports.report_type', 120),
  ('report_events.event_type', '보고서 이벤트 유형', 'report_events.event_type', 130),
  ('user_preferences.theme', '테마', 'user_preferences.theme', 140),
  ('activity_logs.level', '로그 레벨', 'activity_logs.level', 150),
  ('activity_logs.action', '로그 액션', 'activity_logs.action label/category master', 160)
ON CONFLICT (group_key) DO UPDATE
SET group_name = EXCLUDED.group_name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();

INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
VALUES
  ('profiles.permission_level', 'super_admin', '최고 관리자', 1, '{"rank":110,"emoji":"⭐","color":"#c92a2a","badgeClass":"CRITICAL"}'),
  ('profiles.permission_level', 'admin', '관리자', 10, '{"rank":100,"emoji":"👑","color":"#e03131","badgeClass":"ERROR"}'),
  ('profiles.permission_level', 'evangelist', '전도사님', 20, '{"rank":90,"emoji":"✝️","color":"#9c36b5","badgeClass":"WARN"}'),
  ('profiles.permission_level', 'chief', '부장 교사', 30, '{"rank":80,"emoji":"📋","color":"#f08c00","badgeClass":"WARN"}'),
  ('profiles.permission_level', 'purchase_teacher', '구매 담당 교사', 40, '{"rank":70,"emoji":"🛒","color":"#1971c2","badgeClass":"INFO"}'),
  ('profiles.permission_level', 'dept_teacher', '부서 담당 교사', 50, '{"rank":60,"emoji":"👩‍🏫","color":"#1971c2","badgeClass":"INFO"}'),
  ('profiles.permission_level', 'teacher', '일반 교사', 60, '{"rank":40,"emoji":"👨‍🏫","color":"#4dabf7","badgeClass":"INFO"}'),
  ('profiles.permission_level', 'student', '학생', 70, '{"rank":20,"emoji":"🎒","color":"#2b8a3e","badgeClass":"SUCCESS"}'),

  ('profiles.user_type', 'teacher', '교사', 10, '{"emoji":"👩‍🏫"}'),
  ('profiles.user_type', 'student', '학생', 20, '{"emoji":"🎒"}'),

  ('request.status', 'pending', '대기', 10, '{"emoji":"⏳"}'),
  ('request.status', 'approved', '승인', 20, '{"emoji":"✅"}'),
  ('request.status', 'rejected', '거부', 30, '{"emoji":"❌"}'),

  ('product_orders.status', 'requested', '구매 신청', 10, '{"emoji":"🛒","color":"#868e96"}'),
  ('product_orders.status', 'preparing', '상품 준비', 20, '{"emoji":"📦","color":"#e67700"}'),
  ('product_orders.status', 'purchased', '상품 구매', 30, '{"emoji":"💳","color":"#1971c2"}'),
  ('product_orders.status', 'delivered', '상품 지급', 40, '{"emoji":"✅","color":"#2b8a3e"}'),
  ('product_orders.status', 'cancelled', '구매 취소', 50, '{"emoji":"❌","color":"#e03131"}'),

  ('products.target_role', 'teacher', '교사', 10, '{"emoji":"👩‍🏫"}'),
  ('products.target_role', 'student', '학생', 20, '{"emoji":"🎒"}'),
  ('products.category', 'stationery', '학용품', 10, '{"emoji":"✏️"}'),
  ('products.category', 'snack', '간식', 20, '{"emoji":"🍬"}'),
  ('products.category', 'toy', '장난감', 30, '{"emoji":"🧸"}'),
  ('products.category', 'book', '도서', 40, '{"emoji":"📚"}'),
  ('products.category', 'gift', '선물', 50, '{"emoji":"🎁"}'),
  ('products.category', 'etc', '기타', 999, '{"emoji":"📦"}'),

  ('talent_items.target_type', 'teacher', '교사', 10, '{"emoji":"👩‍🏫"}'),
  ('talent_items.target_type', 'student', '학생', 20, '{"emoji":"🎒"}'),
  ('talent_transactions.type', 'earn', '적립', 10, '{"emoji":"➕","color":"#2b8a3e"}'),
  ('talent_transactions.type', 'use', '사용', 20, '{"emoji":"➖","color":"#e03131"}'),
  ('talent_transactions.source', 'admin', '관리자 지급', 10, '{"emoji":"🧑‍💻"}'),
  ('talent_transactions.source', 'qr', 'QR 수령', 20, '{"emoji":"📱"}'),

  ('talent_qr_codes.repeat_type', 'none', '1회', 10, '{}'),
  ('talent_qr_codes.repeat_type', 'daily', '매일', 20, '{}'),
  ('talent_qr_codes.repeat_type', 'weekday', '요일 반복', 30, '{}'),
  ('talent_qr_codes.repeat_type', 'week_weekday', '주차+요일 반복', 40, '{}'),

  ('qna.status', 'pending', '답변 대기', 10, '{"emoji":"❓"}'),
  ('qna.status', 'answered', '답변 완료', 20, '{"emoji":"💬"}'),
  ('qna.status', 'faq', 'FAQ', 30, '{"emoji":"📌"}'),

  ('reports.report_type', 'plan', '계획서', 10, '{}'),
  ('reports.report_type', 'test_scenario', '테스트 시나리오', 20, '{}'),
  ('reports.report_type', 'test_result', '테스트 결과', 30, '{}'),
  ('reports.report_type', 'change_report', '변경 보고서', 40, '{}'),
  ('reports.report_type', 'security_report', '보안 보고서', 50, '{}'),

  ('report_events.event_type', 'created', '생성', 10, '{}'),
  ('report_events.event_type', 'updated', '수정', 20, '{}'),
  ('report_events.event_type', 'confirmed', '확인', 30, '{}'),
  ('report_events.event_type', 'reconfirmed', '재확인', 40, '{}'),
  ('report_events.event_type', 'status_changed', '상태 변경', 50, '{}'),

  ('user_preferences.theme', 'default', '일반', 10, '{}'),
  ('user_preferences.theme', 'dark', '다크', 20, '{}'),
  ('user_preferences.theme', 'spring', '봄', 30, '{}'),
  ('user_preferences.theme', 'summer', '여름', 40, '{}'),
  ('user_preferences.theme', 'autumn', '가을', 50, '{}'),
  ('user_preferences.theme', 'winter', '겨울', 60, '{}'),

  ('activity_logs.level', 'TRACE', '추적', 10, '{}'),
  ('activity_logs.level', 'DEBUG', '디버그', 20, '{}'),
  ('activity_logs.level', 'INFO', '정보', 30, '{}'),
  ('activity_logs.level', 'WARN', '경고', 40, '{}'),
  ('activity_logs.level', 'ERROR', '오류', 50, '{}'),
  ('activity_logs.level', 'FATAL', '치명 오류', 60, '{}'),
  ('activity_logs.level', 'CRITICAL', '긴급 오류', 70, '{}')
ON CONFLICT (group_key, code_key) DO UPDATE
SET code_value = EXCLUDED.code_value,
    sort_order = EXCLUDED.sort_order,
    meta = EXCLUDED.meta,
    is_active = true,
    updated_at = now();

-- 작업 이력/로그 액션 라벨. 감사 화면 필터에 쓰는 category/emoji는 meta로 관리한다.
INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
VALUES
  ('activity_logs.action', 'USER_CREATE', '사용자 등록', 1010, '{"category":"USER","emoji":"➕"}'),
  ('activity_logs.action', 'USER_UPDATE', '사용자 수정', 1020, '{"category":"USER","emoji":"✏️"}'),
  ('activity_logs.action', 'USER_DELETE', '사용자 삭제', 1030, '{"category":"USER","emoji":"🗑️"}'),
  ('activity_logs.action', 'USER_PW_RESET', '비밀번호 초기화', 1040, '{"category":"USER","emoji":"🔑"}'),
  ('activity_logs.action', 'PASSWORD_RESET', '비밀번호 초기화', 1050, '{"category":"USER","emoji":"🔑"}'),
  ('activity_logs.action', 'REGISTER_REQUEST', '가입 신청', 2010, '{"category":"REGISTER","emoji":"📝"}'),
  ('activity_logs.action', 'REGISTER_APPROVE', '가입 승인', 2020, '{"category":"REGISTER","emoji":"✅"}'),
  ('activity_logs.action', 'REGISTER_REJECT', '가입 거부', 2030, '{"category":"REGISTER","emoji":"❌"}'),
  ('activity_logs.action', 'DEPT_CREATE', '부서 등록', 3010, '{"category":"DEPT","emoji":"🏢"}'),
  ('activity_logs.action', 'DEPT_UPDATE', '부서 수정', 3020, '{"category":"DEPT","emoji":"✏️"}'),
  ('activity_logs.action', 'DEPT_DELETE', '부서 삭제', 3030, '{"category":"DEPT","emoji":"🗑️"}'),
  ('activity_logs.action', 'DEPT_DEACTIVATE', '부서 비활성화', 3040, '{"category":"DEPT","emoji":"🚫"}'),
  ('activity_logs.action', 'DEPT_TRANSFER_IMMEDIATE', '부서 즉시 이동', 3050, '{"category":"DEPT","emoji":"🔄"}'),
  ('activity_logs.action', 'DEPT_TRANSFER_REQUEST', '부서 이동 요청', 3060, '{"category":"DEPT","emoji":"📮"}'),
  ('activity_logs.action', 'DEPT_TRANSFER_APPROVE', '부서 이동 승인', 3070, '{"category":"DEPT","emoji":"✅"}'),
  ('activity_logs.action', 'DEPT_TRANSFER_REJECT', '부서 이동 거부', 3080, '{"category":"DEPT","emoji":"❌"}'),
  ('activity_logs.action', 'MANAGER_UPDATE', '관리자 수정', 3090, '{"category":"DEPT","emoji":"👤"}'),
  ('activity_logs.action', 'MANAGER_PROMOTE', '관리자 승격', 3100, '{"category":"DEPT","emoji":"⬆️"}'),
  ('activity_logs.action', 'TALENT_GIVE', '달란트 지급', 4010, '{"category":"TALENT","emoji":"💰"}'),
  ('activity_logs.action', 'TALENT_GIVE_ITEM', '달란트 항목 지급', 4020, '{"category":"TALENT","emoji":"💰"}'),
  ('activity_logs.action', 'TALENT_GIVE_ITEMS', '달란트 일괄 지급', 4030, '{"category":"TALENT","emoji":"💰"}'),
  ('activity_logs.action', 'TALENT_MANUAL_GIVE', '달란트 수동 지급', 4040, '{"category":"TALENT","emoji":"✍️"}'),
  ('activity_logs.action', 'TALENT_USE', '달란트 사용', 4050, '{"category":"TALENT","emoji":"💸"}'),
  ('activity_logs.action', 'TALENT_RETURN', '달란트 반환', 4060, '{"category":"TALENT","emoji":"↩️"}'),
  ('activity_logs.action', 'ATTENDANCE_GIVE', '출석 달란트 지급', 4070, '{"category":"TALENT","emoji":"⛪"}'),
  ('activity_logs.action', 'ATTENDANCE_CANCEL', '출석 달란트 취소', 4080, '{"category":"TALENT","emoji":"🔙"}'),
  ('activity_logs.action', 'TALENT_ITEM_CANCEL', '달란트 항목 취소', 4090, '{"category":"TALENT","emoji":"🔙"}'),
  ('activity_logs.action', 'TALENT_ITEM_CREATE', '달란트 항목 등록', 4100, '{"category":"TALENT","emoji":"📋"}'),
  ('activity_logs.action', 'TALENT_ITEM_UPDATE', '달란트 항목 수정', 4110, '{"category":"TALENT","emoji":"📋"}'),
  ('activity_logs.action', 'TALENT_ITEM_TOGGLE', '달란트 항목 활성 토글', 4120, '{"category":"TALENT","emoji":"🔘"}'),
  ('activity_logs.action', 'TALENT_ITEM_QUICKBTN', '달란트 퀵버튼 설정', 4130, '{"category":"TALENT","emoji":"⚡"}'),
  ('activity_logs.action', 'qr_create', 'QR 코드 생성', 4140, '{"category":"TALENT","emoji":"📷"}'),
  ('activity_logs.action', 'qr_edit', 'QR 코드 수정', 4150, '{"category":"TALENT","emoji":"✏️"}'),
  ('activity_logs.action', 'qr_toggle', 'QR 코드 토글', 4160, '{"category":"TALENT","emoji":"🔘"}'),
  ('activity_logs.action', 'qr_scan', 'QR 달란트 수령', 4170, '{"category":"TALENT","emoji":"📱"}'),
  ('activity_logs.action', 'PRODUCT_CREATE', '상품 등록', 5010, '{"category":"ORDER","emoji":"🛍️"}'),
  ('activity_logs.action', 'PRODUCT_CATEGORY_CREATE', '상품 카테고리 등록', 5015, '{"category":"ORDER","emoji":"🏷️"}'),
  ('activity_logs.action', 'PRODUCT_UPDATE', '상품 수정', 5020, '{"category":"ORDER","emoji":"✏️"}'),
  ('activity_logs.action', 'PRODUCT_DELETE', '상품 삭제', 5030, '{"category":"ORDER","emoji":"🗑️"}'),
  ('activity_logs.action', 'PRODUCT_DEACTIVATE', '상품 비활성화', 5040, '{"category":"ORDER","emoji":"🚫"}'),
  ('activity_logs.action', 'PRODUCT_SOFT_DELETE', '상품 비활성화', 5050, '{"category":"ORDER","emoji":"🚫"}'),
  ('activity_logs.action', 'ORDER_REQUEST_SUCCESS', '상품 구매 신청', 5060, '{"category":"ORDER","emoji":"🛒"}'),
  ('activity_logs.action', 'PROXY_ORDER_SUCCESS', '대리 구매 신청', 5070, '{"category":"ORDER","emoji":"🛒"}'),
  ('activity_logs.action', 'order_cancel', '주문 취소', 5080, '{"category":"ORDER","emoji":"❌"}'),
  ('activity_logs.action', 'ORDER_CANCEL', '주문 취소', 5081, '{"category":"ORDER","emoji":"❌"}'),
  ('activity_logs.action', 'ORDER_STATUS_CHANGE', '주문 상태 변경', 5090, '{"category":"ORDER","emoji":"🔄"}'),
  ('activity_logs.action', 'ORDER_REVERT', '주문 상태 되돌리기', 5100, '{"category":"ORDER","emoji":"↩️"}'),
  ('activity_logs.action', 'ORDER_PURCHASE_CONFIRM', '구매 확정', 5110, '{"category":"ORDER","emoji":"✅"}'),
  ('activity_logs.action', 'ORDER_BULK_PREPARE', '일괄 상품 준비', 5120, '{"category":"ORDER","emoji":"📦"}'),
  ('activity_logs.action', 'ORDER_BULK_PURCHASE', '일괄 구매 확정', 5130, '{"category":"ORDER","emoji":"📦"}'),
  ('activity_logs.action', 'ORDER_BULK_DELIVER', '일괄 상품 지급', 5140, '{"category":"ORDER","emoji":"📦"}'),
  ('activity_logs.action', 'QNA_CREATE', '질문 등록', 6010, '{"category":"QNA","emoji":"❓"}'),
  ('activity_logs.action', 'QNA_ANSWER', '답변 등록', 6020, '{"category":"QNA","emoji":"💬"}'),
  ('activity_logs.action', 'QNA_COMMENT', '댓글 등록', 6030, '{"category":"QNA","emoji":"💬"}'),
  ('activity_logs.action', 'QNA_DELETE', 'Q&A 삭제', 6040, '{"category":"QNA","emoji":"🗑️"}'),
  ('activity_logs.action', 'QNA_FAQ_SET', 'FAQ 설정', 6050, '{"category":"QNA","emoji":"📌"}'),
  ('activity_logs.action', 'LOGIN_SUCCESS', '로그인 성공', 7010, '{"category":"AUTH","emoji":"🔓"}'),
  ('activity_logs.action', 'LOGOUT', '로그아웃', 7020, '{"category":"AUTH","emoji":"🔒"}'),
  ('activity_logs.action', 'PASSWORD_CHANGE', '비밀번호 변경', 7030, '{"category":"AUTH","emoji":"🔑"}'),
  ('activity_logs.action', 'LOG_ACKNOWLEDGED', '로그 확인', 8010, '{"category":"LOG_MGMT","emoji":"✅"}'),
  ('activity_logs.action', 'LOG_BULK_ACK', '로그 일괄 확인', 8020, '{"category":"LOG_MGMT","emoji":"✅"}'),
  ('activity_logs.action', 'LOG_RANGE_DELETE', '로그 범위 삭제', 8030, '{"category":"LOG_MGMT","emoji":"🗑️"}'),
  ('activity_logs.action', 'LOG_SELECT_DELETE', '로그 선택 삭제', 8040, '{"category":"LOG_MGMT","emoji":"🗑️"}'),
  ('activity_logs.action', 'LOG_RESTORE', '로그 복원', 8050, '{"category":"LOG_MGMT","emoji":"♻️"}'),
  ('activity_logs.action', 'ROLE_ACCESS_UPDATE', '페이지 접근 권한 변경', 9010, '{"category":"PERM","emoji":"🔐"}'),
  ('activity_logs.action', 'ROLE_FEATURE_UPDATE', '페이지 기능 권한 변경', 9020, '{"category":"PERM","emoji":"🔧"}'),
  ('activity_logs.action', 'PAGE_PERM_UPDATE', '페이지 권한 설정 변경', 9030, '{"category":"PERM","emoji":"🛡️"}'),
  ('activity_logs.action', 'REPORT_SAVE', '보고서 저장', 9040, '{"category":"PERM","emoji":"📄"}'),
  ('activity_logs.action', 'REPORT_DELETE', '보고서 삭제', 9050, '{"category":"PERM","emoji":"🗑️"}'),
  ('activity_logs.action', 'REPORT_SEED', '보고서 시드 등록', 9060, '{"category":"PERM","emoji":"🌱"}')
ON CONFLICT (group_key, code_key) DO UPDATE
SET code_value = EXCLUDED.code_value,
    sort_order = EXCLUDED.sort_order,
    meta = EXCLUDED.meta,
    is_active = true,
    updated_at = now();

-- 기존 운영 데이터의 자유 입력 카테고리/액션도 코드 마스터에 보존한다.
INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
SELECT 'products.category', p.category, p.category, 9000, '{"source":"legacy"}'::jsonb
FROM (SELECT DISTINCT category FROM public.products WHERE category IS NOT NULL AND btrim(category) <> '') p
ON CONFLICT (group_key, code_key) DO NOTHING;

INSERT INTO public.code_items (group_key, code_key, code_value, sort_order, meta)
SELECT 'activity_logs.action',
       l.action,
       COALESCE(NULLIF(MAX(l.details->>'_actionLabel'), ''), l.action),
       990000,
       '{"source":"legacy"}'::jsonb
FROM public.activity_logs l
WHERE l.action IS NOT NULL AND btrim(l.action) <> ''
GROUP BY l.action
ON CONFLICT (group_key, code_key) DO NOTHING;

-- ============================================================
-- 3. Permission rank reads the master table first
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_permission_rank(p_level text)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rank integer;
BEGIN
  SELECT NULLIF(meta->>'rank', '')::integer
  INTO v_rank
  FROM public.code_items
  WHERE group_key = 'profiles.permission_level'
    AND code_key = p_level
    AND is_active = true
  LIMIT 1;

  IF v_rank IS NOT NULL THEN
    RETURN v_rank;
  END IF;

  RETURN CASE p_level
    WHEN 'super_admin' THEN 110
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

CREATE OR REPLACE FUNCTION public.get_code_value(p_group_key text, p_code_key text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT code_value
  FROM public.code_items
  WHERE group_key = p_group_key
    AND code_key = p_code_key
    AND is_active = true
  LIMIT 1;
$$;

-- ============================================================
-- 4. Replace static CHECKs with code master validation triggers
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_code_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  i integer := 0;
  v_column text;
  v_group text;
  v_value text;
BEGIN
  WHILE i < TG_NARGS LOOP
    v_column := TG_ARGV[i];
    v_group := TG_ARGV[i + 1];
    v_value := to_jsonb(NEW)->>v_column;

    IF v_value IS NOT NULL AND btrim(v_value) <> '' THEN
      IF NOT EXISTS (
        SELECT 1
        FROM public.code_items
        WHERE group_key = v_group
          AND code_key = v_value
          AND is_active = true
      ) THEN
        RAISE EXCEPTION 'Invalid code for %.%: %', v_group, v_column, v_value
          USING ERRCODE = '23514';
      END IF;
    END IF;

    i := i + 2;
  END LOOP;

  RETURN NEW;
END;
$$;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_permission_level_check;
ALTER TABLE public.registration_requests DROP CONSTRAINT IF EXISTS registration_requests_status_check;
ALTER TABLE public.registration_requests DROP CONSTRAINT IF EXISTS registration_requests_user_type_check;
ALTER TABLE public.registration_requests DROP CONSTRAINT IF EXISTS registration_requests_permission_level_check;
ALTER TABLE public.department_transfer_requests DROP CONSTRAINT IF EXISTS department_transfer_requests_status_check;
ALTER TABLE public.talent_items DROP CONSTRAINT IF EXISTS talent_items_target_type_check;
ALTER TABLE public.talent_transactions DROP CONSTRAINT IF EXISTS talent_transactions_type_check;
ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_target_role_check;
ALTER TABLE public.product_orders DROP CONSTRAINT IF EXISTS product_orders_status_check;
ALTER TABLE public.qna DROP CONSTRAINT IF EXISTS qna_status_check;
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_report_type_check;
ALTER TABLE public.report_events DROP CONSTRAINT IF EXISTS report_events_event_type_check;
ALTER TABLE public.user_preferences DROP CONSTRAINT IF EXISTS user_preferences_theme_check;

DROP TRIGGER IF EXISTS trg_code_profiles ON public.profiles;
CREATE TRIGGER trg_code_profiles
  BEFORE INSERT OR UPDATE OF user_type, permission_level ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns(
    'user_type', 'profiles.user_type',
    'permission_level', 'profiles.permission_level'
  );

DROP TRIGGER IF EXISTS trg_code_registration_requests ON public.registration_requests;
CREATE TRIGGER trg_code_registration_requests
  BEFORE INSERT OR UPDATE OF status, user_type, permission_level ON public.registration_requests
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns(
    'status', 'request.status',
    'user_type', 'profiles.user_type',
    'permission_level', 'profiles.permission_level'
  );

DROP TRIGGER IF EXISTS trg_code_department_transfer_requests ON public.department_transfer_requests;
CREATE TRIGGER trg_code_department_transfer_requests
  BEFORE INSERT OR UPDATE OF status ON public.department_transfer_requests
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('status', 'request.status');

DROP TRIGGER IF EXISTS trg_code_talent_items ON public.talent_items;
CREATE TRIGGER trg_code_talent_items
  BEFORE INSERT OR UPDATE OF target_type ON public.talent_items
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('target_type', 'talent_items.target_type');

DROP TRIGGER IF EXISTS trg_code_talent_transactions ON public.talent_transactions;
CREATE TRIGGER trg_code_talent_transactions
  BEFORE INSERT OR UPDATE OF type, source ON public.talent_transactions
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns(
    'type', 'talent_transactions.type',
    'source', 'talent_transactions.source'
  );

DROP TRIGGER IF EXISTS trg_code_products ON public.products;
CREATE TRIGGER trg_code_products
  BEFORE INSERT OR UPDATE OF target_role, category ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns(
    'target_role', 'products.target_role',
    'category', 'products.category'
  );

DROP TRIGGER IF EXISTS trg_code_product_orders ON public.product_orders;
CREATE TRIGGER trg_code_product_orders
  BEFORE INSERT OR UPDATE OF status ON public.product_orders
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('status', 'product_orders.status');

DROP TRIGGER IF EXISTS trg_code_qna ON public.qna;
CREATE TRIGGER trg_code_qna
  BEFORE INSERT OR UPDATE OF status ON public.qna
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('status', 'qna.status');

DROP TRIGGER IF EXISTS trg_code_reports ON public.reports;
CREATE TRIGGER trg_code_reports
  BEFORE INSERT OR UPDATE OF report_type ON public.reports
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('report_type', 'reports.report_type');

DROP TRIGGER IF EXISTS trg_code_report_events ON public.report_events;
CREATE TRIGGER trg_code_report_events
  BEFORE INSERT OR UPDATE OF event_type ON public.report_events
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('event_type', 'report_events.event_type');

DROP TRIGGER IF EXISTS trg_code_user_preferences ON public.user_preferences;
CREATE TRIGGER trg_code_user_preferences
  BEFORE INSERT OR UPDATE OF theme ON public.user_preferences
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('theme', 'user_preferences.theme');

DROP TRIGGER IF EXISTS trg_code_talent_qr_codes ON public.talent_qr_codes;
CREATE TRIGGER trg_code_talent_qr_codes
  BEFORE INSERT OR UPDATE OF target_type, repeat_type ON public.talent_qr_codes
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns(
    'target_type', 'talent_items.target_type',
    'repeat_type', 'talent_qr_codes.repeat_type'
  );

DROP TRIGGER IF EXISTS trg_code_activity_logs_level ON public.activity_logs;
CREATE TRIGGER trg_code_activity_logs_level
  BEFORE INSERT OR UPDATE OF level ON public.activity_logs
  FOR EACH ROW EXECUTE FUNCTION public.validate_code_columns('level', 'activity_logs.level');

-- ============================================================
-- 5. RLS / grants
-- ============================================================

ALTER TABLE public.code_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.code_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS code_groups_select ON public.code_groups;
CREATE POLICY code_groups_select ON public.code_groups
  FOR SELECT TO anon, authenticated
  USING (is_active = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS code_items_select ON public.code_items;
CREATE POLICY code_items_select ON public.code_items
  FOR SELECT TO anon, authenticated
  USING (is_active = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS code_groups_manage ON public.code_groups;
CREATE POLICY code_groups_manage ON public.code_groups
  FOR ALL TO authenticated
  USING (public.get_permission_rank(public.get_my_role()) >= 100)
  WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 100);

DROP POLICY IF EXISTS code_items_manage ON public.code_items;
CREATE POLICY code_items_manage ON public.code_items
  FOR ALL TO authenticated
  USING (public.get_permission_rank(public.get_my_role()) >= 100)
  WITH CHECK (public.get_permission_rank(public.get_my_role()) >= 100);

DROP POLICY IF EXISTS code_items_product_category_insert ON public.code_items;
CREATE POLICY code_items_product_category_insert ON public.code_items
  FOR INSERT TO authenticated
  WITH CHECK (
    group_key = 'products.category'
    AND public.get_permission_rank(public.get_my_role()) >= 60
  );

GRANT SELECT ON public.code_groups, public.code_items TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.code_groups, public.code_items TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_code_value(text, text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
