-- ============================================================
-- TASK-095: 활동 로그 오류 집계 보고서 (읽기 전용)
--
-- 오류 식별값(errorFingerprint)이 있으면 같은 오류로 묶고,
-- 없으면 action + page + UUID를 제거한 대표 오류 문구로 중복을 제거합니다.
-- 이 파일은 activity_logs 데이터를 변경하지 않습니다.
-- ============================================================

WITH error_source AS (
  SELECT
    l.id,
    l.created_at,
    l.level,
    l.action,
    l.page,
    l.details,
    COALESCE(l.is_acknowledged, false) AS is_acknowledged,
    COALESCE(l.details->>'errorFingerprint', '') AS error_fingerprint,
    COALESCE(
      NULLIF(l.details->>'message', ''),
      NULLIF(l.details->>'error', ''),
      NULLIF(l.details->>'reason', ''),
      NULLIF(l.details->>'hint', ''),
      '(상세 문구 없음)'
    ) AS raw_message
  FROM public.activity_logs l
  WHERE l.level IN ('ERROR', 'FATAL', 'CRITICAL')
    AND COALESCE(l.is_deleted, false) = false
),
normalized AS (
  SELECT
    e.*,
    regexp_replace(
      e.raw_message,
      '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      '{uuid}',
      'gi'
    ) AS normalized_message
  FROM error_source e
),
classified AS (
  SELECT
    n.*,
    CASE
      WHEN n.level IN ('FATAL', 'CRITICAL')
        OR n.action IN ('JS_ERROR', 'PROMISE_REJECTION', 'CONNECTION_FAIL', 'SLACK_NOTIFY_FAIL', 'SERVICE_USAGE_COLLECT_FAIL', 'ORDER_CANCEL_REFUND_FAIL')
        THEN '높음'
      WHEN n.action LIKE '%_FAIL' OR n.action LIKE '%_ERROR' THEN '보통'
      ELSE '검토'
    END AS priority,
    CASE
      WHEN n.action IN ('JS_ERROR', 'PROMISE_REJECTION') THEN '클라이언트 오류'
      WHEN n.action IN ('CONNECTION_FAIL', 'SLACK_NOTIFY_FAIL', 'SERVICE_USAGE_COLLECT_FAIL') THEN '외부 연동/네트워크'
      WHEN n.action LIKE 'AUTH_%' OR n.action LIKE 'LOGIN_%' THEN '인증/권한'
      WHEN n.action LIKE 'ORDER_%' OR n.action LIKE 'PROXY_%' THEN '주문/결제 흐름'
      WHEN n.action LIKE 'TALENT_%' OR n.action LIKE 'ATTENDANCE_%' THEN '달란트 흐름'
      ELSE '기타 기능 오류'
    END AS issue_category,
    COALESCE(
      NULLIF(n.error_fingerprint, ''),
      n.action || '|' || COALESCE(n.page, '-') || '|' || n.normalized_message
    ) AS issue_signature
  FROM normalized n
),
ranked AS (
  SELECT
    c.*,
    row_number() OVER (PARTITION BY c.issue_signature ORDER BY c.created_at DESC) AS sample_rank
  FROM classified c
  WHERE c.action NOT IN (
    'LOGIN_FAIL', 'LOGIN_PENDING_APPROVAL', 'USER_ID_CHECK_DUPLICATE',
    'QR_LOCATION_PERMISSION_BLOCKED', 'TALENT_GIVE_ITEM_DENIED',
    'TALENT_USE_DENIED', 'ORDER_REQUEST_DENIED', 'PROXY_ORDER_DENIED',
    'ORDER_PURCHASE_CONFIRM_DENIED'
  )
)
SELECT
  r.priority AS 우선순위,
  r.issue_category AS 분류,
  r.action AS 액션코드,
  COALESCE(ci.code_value, r.action) AS 액션명,
  COUNT(*)::int AS 발생건수,
  COUNT(*) FILTER (WHERE NOT r.is_acknowledged)::int AS 미확인건수,
  MIN(r.created_at) AS 최초발생,
  MAX(r.created_at) AS 최종발생,
  r.normalized_message AS 대표오류,
  jsonb_agg(
    jsonb_build_object('id', r.id, '발생시각', r.created_at, '페이지', r.page, '상세', r.details)
    ORDER BY r.created_at DESC
  ) FILTER (WHERE r.sample_rank <= 3) AS 최근예시
FROM ranked r
LEFT JOIN public.code_items ci
  ON ci.group_key = 'activity_logs.action'
 AND ci.code_key = r.action
 AND ci.is_active = true
GROUP BY r.priority, r.issue_category, r.action, ci.code_value, r.normalized_message
ORDER BY
  CASE r.priority WHEN '높음' THEN 1 WHEN '보통' THEN 2 ELSE 3 END,
  MAX(r.created_at) DESC,
  COUNT(*) DESC;
