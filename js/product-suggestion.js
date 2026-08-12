/**
 * Product suggestion module.
 * Product recommendation and voting data is exposed through RPC only so
 * recommender and voter identities do not reach the voting screen.
 */

function psEscapeHtml(value) {
  return String(value == null ? '' : value).replace(/[&<>"']/g, ch => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[ch]));
}

function psIsHttpUrl(value) {
  if (!value) return false;
  try {
    const url = new URL(String(value).trim());
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch (e) {
    return false;
  }
}

function psCreateId() {
  if (window.crypto && typeof window.crypto.randomUUID === 'function') return window.crypto.randomUUID();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.floor(Math.random() * 16);
    const v = c === 'x' ? r : ((r & 0x3) | 0x8);
    return v.toString(16);
  });
}

function psStatusLabel(status) {
  if (status === 'adopted') return '채택';
  if (status === 'rejected') return '불채택';
  return '투표중';
}

function psStatusClass(status) {
  if (status === 'adopted') return 'ps-status-adopted';
  if (status === 'rejected') return 'ps-status-rejected';
  return 'ps-status-voting';
}

function psStatusBadge(status) {
  return `<span class="ps-status ${psStatusClass(status)}">${psStatusLabel(status)}</span>`;
}

function psFormatKrw(value) {
  if (value == null || value === '') return '-';
  return `${fmtNum(value)}원`;
}

function psFormatDate(value) {
  if (!value) return '-';
  return typeof formatKSTShort === 'function' ? formatKSTShort(value) : new Date(value).toLocaleString('ko-KR');
}

// 진행률은 찬성/반대 방향과 관계없이 전체 투표 수를 등록 시점 과반 기준으로 계산한다.
// 서버가 계산한 값을 우선 사용해 방향별 집계나 정원 수를 화면에 노출하지 않는다.
function psGetVoteProgress(item) {
  const supplied = item && item.vote_progress != null && item.vote_progress !== ''
    ? Number(item.vote_progress)
    : NaN;
  if (Number.isFinite(supplied)) return Math.max(0, Math.min(100, Math.round(supplied)));

  const voteCount = Number(item && item.vote_count);
  const majority = Number(item && item.electorate_majority);
  if (!Number.isFinite(voteCount) || !Number.isFinite(majority) || majority <= 0) return null;
  return Math.max(0, Math.min(100, Math.round((voteCount / majority) * 100)));
}

function psRenderVoteProgress(item, extraClass = '') {
  const progress = psGetVoteProgress(item);
  if (progress == null) return '<span class="ps-vote-progress-empty">-</span>';
  return `<div class="ps-vote-progress ${extraClass}" role="progressbar" aria-label="투표 진행률" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${progress}">
    <div class="ps-vote-progress-label"><span>투표 진행률</span><strong>${progress}%</strong></div>
    <div class="ps-vote-progress-track"><span style="width:${progress}%"></span></div>
  </div>`;
}

function psNotifySuggestionRegistered(payload, data) {
  if (typeof sendSlackNotify !== 'function') return;
  sendSlackNotify('product_suggestion_registered', {
    상품명: payload.name || '-',
    등록완료시각: new Date().toISOString(),
    처리상태: psStatusLabel(data.status)
  });
}

function psNotifySuggestionVoteCompleted(item, data, resolutionMethod) {
  if (typeof sendSlackNotify !== 'function' || !data || data.already_resolved || data.status === 'voting') return;
  const approveCount = Number(data.approve_count == null ? (item && item.approve_count || 0) : data.approve_count);
  const rejectCount = Number(data.reject_count == null ? (item && item.reject_count || 0) : data.reject_count);
  const itemVoteCount = item && item.vote_count != null ? Number(item.vote_count) : approveCount + rejectCount;
  sendSlackNotify('product_suggestion_vote_completed', {
    상품명: item && item.name ? item.name : '-',
    결과: psStatusLabel(data.status),
    찬성: approveCount,
    반대: rejectCount,
    투표수: Number(data.vote_count == null ? itemVoteCount : data.vote_count),
    종료방식: resolutionMethod,
    완료시각: new Date().toISOString()
  });
}

async function submitProductSuggestion(payload) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('submit_product_suggestion', {
      p_id: payload.id || null,
      p_name: payload.name || '',
      p_product_url: payload.productUrl || null,
      p_image_url: payload.imageUrl || null,
      p_detail_image_url: payload.detailImageUrl || null,
      p_description: payload.description || null,
      p_price_krw: payload.priceKrw == null || payload.priceKrw === '' ? null : Number(payload.priceKrw),
      p_category: payload.category || null
    });
    if (error) {
      if (typeof logError === 'function') await logError('PRODUCT_SUGGESTION_CREATE_FAIL', { 상품명: payload.name || '', 오류: error.message });
      return { data: null, error: error.message };
    }
    if (!data || data.success !== true) {
      const message = data && data.error ? data.error : '상품 추천 등록에 실패했습니다.';
      if (typeof logError === 'function') await logError('PRODUCT_SUGGESTION_CREATE_FAIL', { 상품명: payload.name || '', 오류: message });
      return { data: null, error: message };
    }
    psNotifySuggestionRegistered(payload, data);
    if (typeof logInfo === 'function') {
      await logInfo('PRODUCT_SUGGESTION_CREATE', buildChangeLogDetails({
        targetName: payload.name || '',
        targetType: '상품 추천',
        targetId: data.suggestion_id,
        changes: buildChangeSet({}, {
          name: payload.name || '',
          product_url: payload.productUrl || null,
          image_url: payload.imageUrl || null,
          detail_image_url: payload.detailImageUrl || null,
          description: payload.description || null,
          price_krw: payload.priceKrw == null ? null : payload.priceKrw,
          category: payload.category || 'gift'
        }),
        extra: {
          처리상태: psStatusLabel(data.status),
          등록시점투표정원: data.electorate_count,
          등록시점과반: data.electorate_majority
        }
      }));
      if (data.status === 'adopted') {
        await logInfo('PRODUCT_SUGGESTION_ADOPT', { 추천상품ID: data.suggestion_id, 처리유형: '관리자 즉시 등록' });
      }
    }
    return { data, error: null };
  } catch (err) {
    const message = String(err);
    if (typeof logError === 'function') await logError('PRODUCT_SUGGESTION_CREATE_FAIL', { 상품명: payload.name || '', 오류: message });
    return { data: null, error: message };
  }
}

async function fetchMyProductSuggestions() {
  if (!_sb) return { data: [], error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('get_my_product_suggestions');
    return { data: data || [], error: error ? error.message : null };
  } catch (err) {
    return { data: [], error: String(err) };
  }
}

async function fetchProductSuggestionVoteItems(filter = 'all') {
  if (!_sb) return { data: [], error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('get_product_suggestion_vote_items', { p_filter: filter });
    return { data: data || [], error: error ? error.message : null };
  } catch (err) {
    return { data: [], error: String(err) };
  }
}

async function voteProductSuggestion(suggestionId, vote, item) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('vote_product_suggestion', {
      p_suggestion_id: suggestionId,
      p_vote: vote
    });
    if (!error && data && data.success === true) {
      psNotifySuggestionVoteCompleted(item, data, '등록 시점 과반 투표 완료');
    }
    return { data: data || null, error: error ? error.message : null };
  } catch (err) {
    return { data: null, error: String(err) };
  }
}

async function closeProductSuggestionVote(suggestionId, item) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('close_product_suggestion_vote', { p_suggestion_id: suggestionId });
    if (error) return { data: null, error: error.message };
    if (!data || data.success !== true) return { data: null, error: (data && data.error) || '투표 종료 처리에 실패했습니다.' };
    if (typeof logInfo === 'function') {
      await logInfo('PRODUCT_SUGGESTION_CLOSE', {
        추천상품ID: suggestionId,
        상품명: item && item.name ? item.name : '',
        처리상태: psStatusLabel(data.status),
        현재유효투표정원: data.current_electorate_count,
        현재과반: data.current_majority,
        찬성: data.approve_count,
        반대: data.reject_count
      });
      await logInfo(data.status === 'adopted' ? 'PRODUCT_SUGGESTION_ADOPT' : 'PRODUCT_SUGGESTION_REJECT', {
        추천상품ID: suggestionId,
        처리유형: '최고관리자 현재 유효 정원 종료'
      });
    }
    psNotifySuggestionVoteCompleted(item, data, '최고관리자 현재 유효 정원 종료');
    return { data, error: null };
  } catch (err) {
    return { data: null, error: String(err) };
  }
}

async function adminResolveProductSuggestion(suggestionId, status, item) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  try {
    const { data, error } = await _sb.rpc('admin_resolve_product_suggestion', {
      p_suggestion_id: suggestionId,
      p_status: status
    });
    if (error) return { data: null, error: error.message };
    if (!data || data.success !== true) return { data: null, error: (data && data.error) || '관리자 결정 처리에 실패했습니다.' };
    if (!data.already_resolved && typeof logInfo === 'function') {
      await logInfo(status === 'adopted' ? 'PRODUCT_SUGGESTION_ADOPT' : 'PRODUCT_SUGGESTION_REJECT', {
        추천상품ID: suggestionId,
        상품명: item && item.name ? item.name : '',
        처리유형: '최고관리자 예외 결정'
      });
    }
    psNotifySuggestionVoteCompleted(item, data, '최고관리자 직접 결정');
    return { data, error: null };
  } catch (err) {
    return { data: null, error: String(err) };
  }
}
