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
      }
    });
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
