-- =============================================================
-- TASK-039: user_preferences 테이블 생성 (즐겨찾기 DB 저장)
-- 실행 위치: Supabase SQL Editor
-- 실행 시점: v3.32.0 배포 전
-- =============================================================

-- 1. 테이블 생성
CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  favorite_shortcuts JSONB DEFAULT '["earn-talents","shop","my-talents"]'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. RLS 활성화
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- 3. RLS 정책
CREATE POLICY "Users can read own preferences"
  ON public.user_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
  ON public.user_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
  ON public.user_preferences FOR UPDATE
  USING (auth.uid() = user_id);

-- 4. 인덱스
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON public.user_preferences(user_id);
