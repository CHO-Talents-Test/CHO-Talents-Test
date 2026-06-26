-- ============================================
-- TASK-051: registration_requests RLS를 rank 60 이상 조회/수정 허용
-- 실행 위치: Supabase SQL Editor
-- 목적: 부서 담당 교사(60), 구매 담당 교사(70)도 가입 신청 조회/처리 가능
-- ============================================

-- SELECT: rank 60 이상 조회 가능
DROP POLICY IF EXISTS rr_select_perm ON public.registration_requests;
CREATE POLICY rr_select_perm ON public.registration_requests
  FOR SELECT USING (public.get_permission_rank(public.get_my_role()) >= 60);

-- UPDATE: rank 60 이상 수정(승인/거부) 가능
DROP POLICY IF EXISTS rr_update_perm ON public.registration_requests;
CREATE POLICY rr_update_perm ON public.registration_requests
  FOR UPDATE USING (public.get_permission_rank(public.get_my_role()) >= 60);

-- DELETE: rank 80 이상만 삭제 (기존 유지)
-- (삭제는 관리 목적이므로 80 이상만 허용)

-- department_transfer_requests UPDATE도 rank 60 이상으로 변경
DROP POLICY IF EXISTS dept_transfer_update ON public.department_transfer_requests;
CREATE POLICY dept_transfer_update ON public.department_transfer_requests
  FOR UPDATE TO authenticated
  USING (public.get_permission_rank(auth.uid()) >= 60);

-- 확인
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename IN ('registration_requests', 'department_transfer_requests');
