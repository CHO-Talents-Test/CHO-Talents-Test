-- ============================================================
-- TASK-049: v3.37.0 스키마 변경
-- 1. profiles에 last_login_at 컬럼 추가
-- 2. page-access/features에 purchase_teacher 지원
-- ============================================================

-- 1. profiles.last_login_at 컬럼 추가
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_login_at timestamptz;

COMMENT ON COLUMN public.profiles.last_login_at IS '마지막 로그인 일시 (로그 삭제와 무관하게 유지)';

-- 2. 기존 last_sign_in_at 기반으로 초기값 설정 (auth.users에서)
UPDATE public.profiles p
  SET last_login_at = au.last_sign_in_at
  FROM auth.users au
  WHERE p.id = au.id AND p.last_login_at IS NULL AND au.last_sign_in_at IS NOT NULL;

-- 3. update_last_login RPC 생성 (로그인 시 호출)
CREATE OR REPLACE FUNCTION public.update_last_login()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
    SET last_login_at = now()
    WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_last_login() TO authenticated;
