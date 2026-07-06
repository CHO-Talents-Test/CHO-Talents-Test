-- TASK-065: 가입 승인 대기 로그인 안내 담당자 조회 RPC
-- 실행 위치: Supabase SQL Editor
-- 목적:
--   로그인 전 사용자에게 가입 신청 상태와 신청 부서의 부서 담당 교사 이상 담당자명을 안내합니다.
--   기존 check_registration_status(text)는 그대로 유지하고, 새 JSON RPC만 추가합니다.

CREATE OR REPLACE FUNCTION public.get_registration_approval_contact(p_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req record;
  v_managers jsonb;
BEGIN
  SELECT rr.status, rr.department_id, d.name AS department_name
  INTO v_req
  FROM public.registration_requests rr
  LEFT JOIN public.departments d ON d.id = rr.department_id
  WHERE rr.username = p_username
  ORDER BY rr.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'not_found',
      'departmentName', null,
      'managers', jsonb_build_array()
    );
  END IF;

  SELECT COALESCE(jsonb_agg(name ORDER BY name), jsonb_build_array())
  INTO v_managers
  FROM (
    SELECT DISTINCT COALESCE(NULLIF(trim(p.display_name), ''), p.username) AS name
    FROM public.profiles p
    WHERE v_req.department_id IS NOT NULL
      AND p.user_type = 'teacher'
      AND public.get_permission_rank(p.permission_level) >= 60
      AND (
        p.department_id = v_req.department_id
        OR p.managed_dept_id = v_req.department_id
      )
  ) manager_rows
  WHERE name IS NOT NULL;

  RETURN jsonb_build_object(
    'status', COALESCE(v_req.status, 'not_found'),
    'departmentName', v_req.department_name,
    'managers', COALESCE(v_managers, jsonb_build_array())
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_registration_approval_contact(text) TO anon, authenticated;
