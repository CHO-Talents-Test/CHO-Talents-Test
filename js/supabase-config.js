/**
 * Supabase Configuration & Global Utilities
 */
const DEFAULT_PUBLIC_CONFIG = Object.freeze({
  supabase: {
    url: 'https://blitrrcdkkkszvgylnus.supabase.co',
    anonKey: 'sb_publishable_TgsQePzjxca9Hr3Lh_dHvA_O1JqRAQ6',
    authEmailDomain: '@cho-talents.app'
  },
  kakao: {
    mapKey: '0ef8925b28135eeac474bc411c456170'
  },
  github: {
    owner: 'CHO-Talents',
    repo: 'CHO-Talents',
    defaultBranch: 'develop'
  }
});

const CHO_TALENTS_CONFIG = window.CHO_TALENTS_CONFIG || {};
const APP_CONFIG_ENV = CHO_TALENTS_CONFIG.env || 'PROD';

function getNestedConfigValue(source, path, fallback) {
  let value = source;
  for (const key of path) {
    if (!value || typeof value !== 'object') return fallback;
    value = value[key];
  }
  return value ?? fallback;
}

let SUPABASE_URL = getNestedConfigValue(CHO_TALENTS_CONFIG, ['supabase', 'url'], DEFAULT_PUBLIC_CONFIG.supabase.url);
let SUPABASE_ANON_KEY = getNestedConfigValue(CHO_TALENTS_CONFIG, ['supabase', 'anonKey'], DEFAULT_PUBLIC_CONFIG.supabase.anonKey);
let AUTH_EMAIL_DOMAIN = getNestedConfigValue(CHO_TALENTS_CONFIG, ['supabase', 'authEmailDomain'], DEFAULT_PUBLIC_CONFIG.supabase.authEmailDomain);
const BOOTSTRAP_KAKAO_MAP_KEY = getNestedConfigValue(CHO_TALENTS_CONFIG, ['kakao', 'mapKey'], null);
let KAKAO_MAP_KEY = BOOTSTRAP_KAKAO_MAP_KEY || DEFAULT_PUBLIC_CONFIG.kakao.mapKey;

var _sb = null;
var _remotePublicConfigPromise = null;

/* ===== Service Usage Telemetry =====
 * 브라우저가 실제로 사용한 GitHub Pages/Supabase/Kakao 호출을 작은 배치로 적재합니다.
 * 쿼리 문자열, 입력값, 사용자명 등 개인정보는 저장하지 않습니다.
 */
const SERVICE_USAGE_QUEUE_KEY = 'cho_service_usage_queue_v1';
const SERVICE_USAGE_SESSION_KEY = 'cho_service_usage_session_v1';
const _serviceUsageNativeFetch = window.fetch.bind(window);
let _serviceUsageStarted = false;
let _serviceUsageFlushing = false;
let _serviceUsageQueue = [];

function _serviceUsageSessionId() {
  try {
    let id = sessionStorage.getItem(SERVICE_USAGE_SESSION_KEY);
    if (!id) {
      id = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      sessionStorage.setItem(SERVICE_USAGE_SESSION_KEY, id);
    }
    return id;
  } catch (e) {
    return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  }
}

function _loadServiceUsageQueue() {
  try {
    const saved = JSON.parse(localStorage.getItem(SERVICE_USAGE_QUEUE_KEY) || '[]');
    _serviceUsageQueue = Array.isArray(saved) ? saved.slice(0, 100) : [];
  } catch (e) {
    _serviceUsageQueue = [];
  }
}

function _saveServiceUsageQueue() {
  try { localStorage.setItem(SERVICE_USAGE_QUEUE_KEY, JSON.stringify(_serviceUsageQueue.slice(-100))); } catch (e) {}
}

function queueServiceUsage(service, metricKey, quantity = 1, metadata = {}, eventKey = null) {
  const amount = Number(quantity);
  if (!service || !metricKey || !Number.isFinite(amount) || amount <= 0) return;
  const safeMetadata = metadata && typeof metadata === 'object' ? metadata : {};

  if (!eventKey) {
    const aggregate = _serviceUsageQueue.find(item =>
      !item.event_key && item.service === service && item.metric_key === metricKey
    );
    if (aggregate) {
      aggregate.quantity = Number(aggregate.quantity || 0) + amount;
      _saveServiceUsageQueue();
      return;
    }
  }

  _serviceUsageQueue.push({
    service,
    metric_key: metricKey,
    quantity: amount,
    metadata: safeMetadata,
    event_key: eventKey || null
  });
  if (_serviceUsageQueue.length > 100) _serviceUsageQueue = _serviceUsageQueue.slice(-100);
  _saveServiceUsageQueue();
}

async function flushServiceUsageTelemetry() {
  if (_serviceUsageFlushing || _serviceUsageQueue.length === 0 || !SUPABASE_URL || !SUPABASE_ANON_KEY) return;
  _serviceUsageFlushing = true;
  const batch = _serviceUsageQueue.slice(0, 30).map((item, index) => ({
    ...item,
    event_key: item.event_key || `batch:${_serviceUsageSessionId()}:${Date.now()}:${index}:${item.service}:${item.metric_key}`
  }));

  try {
    const response = await _serviceUsageNativeFetch(`${SUPABASE_URL}/rest/v1/rpc/record_service_usage_batch`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ p_events: batch }),
      keepalive: true
    });
    if (response.ok) {
      _serviceUsageQueue.splice(0, batch.length);
      _saveServiceUsageQueue();
    }
  } catch (e) {
    // 네트워크 복구 후 다음 주기에 재시도합니다.
  } finally {
    _serviceUsageFlushing = false;
  }
}

async function _trackedSupabaseFetch(input, init) {
  const url = typeof input === 'string' ? input : (input && input.url) || '';
  const isSupabase = typeof url === 'string' && url.startsWith(SUPABASE_URL);
  const isTelemetry = isSupabase && url.includes('/rpc/record_service_usage_batch');
  const response = await _serviceUsageNativeFetch(input, init);

  if (isSupabase && !isTelemetry) {
    let pathType = 'other';
    try {
      const path = new URL(url).pathname;
      if (path.startsWith('/rest/')) pathType = 'rest';
      else if (path.startsWith('/auth/')) pathType = 'auth';
      else if (path.startsWith('/storage/')) pathType = 'storage';
      else if (path.startsWith('/functions/')) pathType = 'functions';
    } catch (e) {}
    queueServiceUsage('supabase', 'api_requests', 1, { type: pathType });

    try {
      response.clone().arrayBuffer().then(buffer => {
        if (buffer.byteLength > 0) queueServiceUsage('supabase', 'egress_bytes', buffer.byteLength, { type: pathType });
      }).catch(() => {});
    } catch (e) {}
  }
  return response;
}

function recordKakaoUsage(metricKey, metadata = {}) {
  const key = `kakao:${_serviceUsageSessionId()}:${Date.now()}:${metricKey}:${Math.random().toString(36).slice(2, 8)}`;
  queueServiceUsage('kakao', 'monthly_api_calls', 1, metadata, `${key}:total`);
  queueServiceUsage('kakao', metricKey, 1, metadata, `${key}:detail`);
  setTimeout(flushServiceUsageTelemetry, 200);
}

function recordRealtimeUsage(messageCount, peakConnections) {
  if (Number(messageCount) > 0) queueServiceUsage('supabase', 'realtime_messages', Number(messageCount));
  if (Number(peakConnections) > 0) queueServiceUsage('supabase', 'realtime_peak_connections', Number(peakConnections));
}

function _recordPageUsage() {
  const pageKey = `page:${_serviceUsageSessionId()}:${Math.round(performance.timeOrigin || Date.now())}`;
  queueServiceUsage('github', 'pages_views', 1, { path: window.location.pathname }, `${pageKey}:view`);

  let githubBytes = 0;
  let cachedSupabaseBytes = 0;
  try {
    const entries = [...performance.getEntriesByType('navigation'), ...performance.getEntriesByType('resource')];
    entries.forEach(entry => {
      let parsed;
      try { parsed = new URL(entry.name, window.location.href); } catch (e) { return; }
      const bytes = Number(entry.transferSize || entry.encodedBodySize || 0);
      if (bytes <= 0) return;
      if (parsed.origin === window.location.origin) githubBytes += bytes;
      if (parsed.href.startsWith(SUPABASE_URL) && parsed.pathname.includes('/storage/v1/object/')) cachedSupabaseBytes += bytes;
    });
  } catch (e) {}

  if (githubBytes > 0) {
    queueServiceUsage('github', 'pages_bandwidth_bytes', githubBytes, { path: window.location.pathname }, `${pageKey}:bytes`);
  }
  if (cachedSupabaseBytes > 0) {
    queueServiceUsage('supabase', 'cached_egress_bytes', cachedSupabaseBytes, { type: 'storage_cdn' }, `${pageKey}:cached`);
  }
  flushServiceUsageTelemetry();
}

function startServiceUsageTelemetry() {
  if (_serviceUsageStarted) return;
  _serviceUsageStarted = true;
  _loadServiceUsageQueue();
  window.addEventListener('load', () => setTimeout(_recordPageUsage, 500), { once: true });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') flushServiceUsageTelemetry();
  });
  window.addEventListener('pagehide', flushServiceUsageTelemetry);
  setInterval(flushServiceUsageTelemetry, 30000);
}

window.queueServiceUsage = queueServiceUsage;
window.flushServiceUsageTelemetry = flushServiceUsageTelemetry;
window.recordKakaoUsage = recordKakaoUsage;
window.recordRealtimeUsage = recordRealtimeUsage;

function initSupabase() {
  if (_sb) return _sb;

  if (SUPABASE_URL === 'YOUR_SUPABASE_URL' || SUPABASE_ANON_KEY === 'YOUR_SUPABASE_ANON_KEY') {
    console.warn('[Supabase] API 키가 설정되지 않았습니다.');
    return null;
  }
  try {
    _sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: false
      },
      global: { fetch: _trackedSupabaseFetch }
    });
    startServiceUsageTelemetry();
    loadRemotePublicConfig().catch(() => {});
    return _sb;
  } catch (err) {
    console.error('[Supabase] 초기화 실패:', err);
    return null;
  }
}

function normalizePublicAppConfig(rows) {
  const config = {};
  for (const row of rows || []) {
    if (!row || !row.key_name) continue;
    config[row.key_name] = row.key_value;
  }
  return config;
}

function applyRemotePublicConfig(rows) {
  const remoteConfig = normalizePublicAppConfig(rows);
  window.CHO_TALENTS_REMOTE_CONFIG = Object.freeze(remoteConfig);

  if (remoteConfig.SUPABASE_AUTH_EMAIL_DOMAIN) {
    AUTH_EMAIL_DOMAIN = remoteConfig.SUPABASE_AUTH_EMAIL_DOMAIN;
  }
  if (remoteConfig.KAKAO_MAP_KEY && !BOOTSTRAP_KAKAO_MAP_KEY) {
    KAKAO_MAP_KEY = remoteConfig.KAKAO_MAP_KEY;
  } else if (remoteConfig.KAKAO_MAP_KEY && remoteConfig.KAKAO_MAP_KEY !== BOOTSTRAP_KAKAO_MAP_KEY) {
    console.warn('[Config] Ignoring remote KAKAO_MAP_KEY because public-config.js provides the environment key.');
  }

  return remoteConfig;
}

async function loadRemotePublicConfig(env = APP_CONFIG_ENV) {
  if (_remotePublicConfigPromise) return _remotePublicConfigPromise;

  const client = _sb || initSupabase();
  if (_remotePublicConfigPromise) return _remotePublicConfigPromise;
  if (!client) return {};

  _remotePublicConfigPromise = client
    .rpc('get_public_app_config', { p_env: env })
    .then(({ data, error }) => {
      if (error) throw error;
      return applyRemotePublicConfig(data);
    })
    .catch(err => {
      console.warn('[Config] 원격 공개 설정 로드 실패:', err?.message || err);
      return {};
    });

  return _remotePublicConfigPromise;
}

function getPublicConfigValue(keyName, fallback = null) {
  const bootstrapConfig = {
    SUPABASE_URL,
    SUPABASE_ANON_KEY,
    SUPABASE_AUTH_EMAIL_DOMAIN: AUTH_EMAIL_DOMAIN,
    KAKAO_MAP_KEY,
    GITHUB_OWNER: getNestedConfigValue(CHO_TALENTS_CONFIG, ['github', 'owner'], DEFAULT_PUBLIC_CONFIG.github.owner),
    GITHUB_REPO: getNestedConfigValue(CHO_TALENTS_CONFIG, ['github', 'repo'], DEFAULT_PUBLIC_CONFIG.github.repo),
    GITHUB_BRANCH: getNestedConfigValue(CHO_TALENTS_CONFIG, ['github', 'defaultBranch'], DEFAULT_PUBLIC_CONFIG.github.defaultBranch)
  };

  if (keyName === 'KAKAO_MAP_KEY' && BOOTSTRAP_KAKAO_MAP_KEY) {
    return bootstrapConfig.KAKAO_MAP_KEY;
  }

  const remoteConfig = window.CHO_TALENTS_REMOTE_CONFIG || {};
  if (Object.prototype.hasOwnProperty.call(remoteConfig, keyName)) {
    return remoteConfig[keyName];
  }

  return Object.prototype.hasOwnProperty.call(bootstrapConfig, keyName) ? bootstrapConfig[keyName] : fallback;
}

/* ===== KST Time Utilities ===== */

function toKST(date) {
  return new Date((date || new Date()).toLocaleString('en-US', { timeZone: 'Asia/Seoul' }));
}

function formatKST(date, opts) {
  const d = date ? new Date(date) : new Date();
  const defaults = {
    timeZone: 'Asia/Seoul', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false
  };
  return d.toLocaleString('ko-KR', { ...defaults, ...opts });
}

function formatKSTShort(date) {
  const d = date ? new Date(date) : new Date();
  return d.toLocaleString('ko-KR', {
    timeZone: 'Asia/Seoul', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hour12: false
  });
}

function formatKSTDateInput(date) {
  const d = date ? new Date(date) : new Date();
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(d).reduce((acc, part) => {
    if (part.type !== 'literal') acc[part.type] = part.value;
    return acc;
  }, {});
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function addDateInputDays(dateStr, days) {
  const [year, month, day] = String(dateStr || '').split('-').map(Number);
  if (!year || !month || !day || !Number.isFinite(Number(days))) {
    return formatKSTDateInput();
  }
  const d = new Date(Date.UTC(year, month - 1, day + Number(days)));
  return d.toISOString().slice(0, 10);
}

/* ===== CRUD Helper Functions ===== */

async function dbSelect(table, options = {}) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };

  let query = _sb.from(table).select(options.columns || '*');

  if (options.filter) {
    for (const [col, val] of Object.entries(options.filter)) {
      query = query.eq(col, val);
    }
  }
  if (options.order) {
    query = query.order(options.order.column, { ascending: options.order.ascending ?? true });
  }
  if (options.limit) {
    query = query.limit(options.limit);
  }

  return await query;
}

async function dbInsert(table, rows) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };
  return await _sb.from(table).insert(rows).select();
}

async function dbUpdate(table, updates, filter) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };

  let query = _sb.from(table).update(updates);
  for (const [col, val] of Object.entries(filter)) {
    query = query.eq(col, val);
  }
  return await query.select();
}

async function dbDelete(table, filter) {
  if (!_sb) return { data: null, error: 'Supabase not initialized' };

  let query = _sb.from(table).delete();
  for (const [col, val] of Object.entries(filter)) {
    query = query.eq(col, val);
  }
  return await query;
}
