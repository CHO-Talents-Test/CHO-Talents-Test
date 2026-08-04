/**
 * Slack Notification Module
 * Supabase Edge Function 'slack-notify'를 호출하여 Slack 채널에 알림을 전송하는 공통 유틸리티
 *
 * 채널 라우팅:
 *   purchase_new, user_register, dept_transfer → 부서별 채널 (data.부서/이동부서 기준)
 *   purchase_status (requested→preparing) → 상품 관리 채널
 *   log_alert (WARN+), product_suggestion_registered, product_suggestion_vote_completed → 운영관리 채널
 *   qna_new → Q&A 채널
 */

const _slackNotifyState = {
  lastSent: {},
  THROTTLE_MS: 5000
};

async function _getSlackNotifyFailure(error) {
  let status = null;
  let message = error && error.message ? String(error.message) : 'Slack 알림 요청에 실패했습니다.';
  const response = error && error.context;
  if (response) {
    status = Number(response.status) || null;
    try {
      const body = await (typeof response.clone === 'function' ? response.clone() : response).text();
      if (body) {
        try {
          const parsed = JSON.parse(body);
          message = String(parsed.error || parsed.message || body);
        } catch (e) {
          message = String(body);
        }
      }
    } catch (e) {}
  }
  return { status, message: message.slice(0, 500) };
}

function _recordSlackNotifyFailure(type, failure) {
  // log_alert 자체의 전송 실패를 다시 Slack 오류로 기록하면 재귀 알림이 생길 수 있습니다.
  if (type === 'log_alert' || typeof logError !== 'function') return;
  try {
    const result = logError('SLACK_NOTIFY_FAIL', {
      notificationType: type,
      notificationStatus: failure.status || null,
      error: failure.message || 'Slack 알림 요청에 실패했습니다.'
    });
    if (result && typeof result.catch === 'function') result.catch(() => {});
  } catch (e) {}
}

/**
 * Slack 알림 전송. 호출자는 await할 수 있으나, 기존 화면 흐름은 await하지 않아도 됩니다.
 * @param {string} type - 알림 유형: purchase_new, purchase_status, user_register, dept_transfer, log_alert, qna_new, product_suggestion_registered, product_suggestion_vote_completed, slack_test
 * @param {Object} data - 알림 데이터
 * @returns {Promise<{success:boolean, skipped?:boolean, data?:Object|null, error?:string, status?:number|null}>}
 */
async function sendSlackNotify(type, data) {
  if (window.CHO_TALENTS_CONFIG?.notifications?.slackEnabled !== true) {
    return { success: true, skipped: true, reason: 'Slack notifications are disabled for this environment.' };
  }
  if (!_sb || !type) return { success: false, error: 'Supabase 또는 알림 유형이 없습니다.' };

  const payloadData = Object.assign({}, data || {});
  const doesNotNeedUserContext = type === 'product_suggestion_registered'
    || type === 'product_suggestion_vote_completed';
  if (!doesNotNeedUserContext && type !== 'slack_test') {
    let session = null;
    try {
      session = (typeof getSession === 'function') ? getSession() : null;
    } catch (e) {}
    if (!payloadData['사용자계정']) {
      payloadData['사용자계정'] = session?.username || payloadData['아이디'] || payloadData['계정'] || '계정 없음';
    }
    if (!payloadData['사용자이름']) {
      payloadData['사용자이름'] = session?.displayName || payloadData['이름'] || payloadData['신청자'] || payloadData['등록자'] || '이름 없음';
    }
  }

  const key = type + '_' + JSON.stringify(payloadData);
  const now = Date.now();
  if (_slackNotifyState.lastSent[key] && now - _slackNotifyState.lastSent[key] < _slackNotifyState.THROTTLE_MS) {
    return { success: false, skipped: true, error: '동일 알림을 잠시 후 다시 시도하세요.' };
  }
  _slackNotifyState.lastSent[key] = now;

  const oldKeys = Object.keys(_slackNotifyState.lastSent);
  if (oldKeys.length > 50) {
    const cutoff = now - 60000;
    oldKeys.forEach(function(k) {
      if (_slackNotifyState.lastSent[k] < cutoff) delete _slackNotifyState.lastSent[k];
    });
  }

  try {
    const { data: responseData, error } = await _sb.functions.invoke('slack-notify', {
      body: { type: type, data: payloadData }
    });
    if (error || !responseData || responseData.success !== true) {
      const failure = error
        ? await _getSlackNotifyFailure(error)
        : { status: null, message: String((responseData && responseData.error) || 'Slack 알림 응답이 성공이 아닙니다.').slice(0, 500) };
      console.warn('[SlackNotify] Failed:', type, failure);
      _recordSlackNotifyFailure(type, failure);
      return { success: false, error: failure.message, status: failure.status };
    }
    return { success: true, data: responseData };
  } catch (err) {
    const failure = await _getSlackNotifyFailure(err);
    console.warn('[SlackNotify] Failed:', type, failure);
    _recordSlackNotifyFailure(type, failure);
    return { success: false, error: failure.message, status: failure.status };
  }
}
