#!/usr/bin/env node

/**
 * 현재 activity_logs.action과 activity_logs.action 코드북을 대조해
 * 한글 라벨이 누락된 실제 로그 액션만 보완한다.
 *
 * 기본값은 조회 전용이다. DB 반영은 --apply를 명시했을 때만 수행한다.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const envPath = path.join(rootDir, '.env.local');
const sourcePath = path.join(rootDir, 'js', 'activity-log.js');
const publicConfigPath = path.join(rootDir, 'config', 'public-config.js');
const args = new Set(process.argv.slice(2));
const apply = args.has('--apply');

function fail(message) {
  console.error(`로그 번역 동기화 중단: ${message}`);
  process.exit(1);
}

function printHelp() {
  console.log(`사용법:
  node scripts/sync-log-translations.mjs --check
  node scripts/sync-log-translations.mjs --apply

필수 .env.local 값:
  LOG_TRANSLATION_TARGET_ENV=PROD 또는 DEV
  LOG_TRANSLATION_PROJECT_REF=<Supabase project ref>
  SUPABASE_URL=https://<project ref>.supabase.co
  SUPABASE_SECRET_KEY=<권장: sb_secret_...>
  # 또는 레거시 SUPABASE_SERVICE_ROLE_KEY=<service role secret>

--check는 조회만 수행하며, --apply만 code_items를 변경합니다.`);
}

if (args.has('--help') || args.has('-h')) {
  printHelp();
  process.exit(0);
}

if (args.size > 1 || (!args.has('--check') && !args.has('--apply'))) {
  printHelp();
  process.exit(1);
}

function parseEnvFile(source) {
  const values = {};
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const match = line.match(/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) continue;
    let [, key, value] = match;
    value = value.trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }
  return values;
}

function readLocalEnv() {
  if (!fs.existsSync(envPath)) fail('.env.local 파일이 없습니다. docs/LOG_TRANSLATION_RUNBOOK.md를 따라 설정하세요.');
  return { ...parseEnvFile(fs.readFileSync(envPath, 'utf8')), ...process.env };
}

function getActionLabels() {
  const source = fs.readFileSync(sourcePath, 'utf8');
  const block = source.match(/const ACTION_LABELS = \{([\s\S]*?)\n\};/);
  if (!block) fail('js/activity-log.js에서 ACTION_LABELS를 찾지 못했습니다.');

  const labels = new Map();
  for (const match of block[1].matchAll(/^\s*([A-Za-z][A-Za-z0-9_]*):\s*'([^']*)',/gm)) {
    labels.set(match[1], match[2]);
  }
  if (!labels.size) fail('ACTION_LABELS에서 한글 액션 라벨을 읽지 못했습니다.');
  return labels;
}

function configuredProjectUrl(targetEnv) {
  const source = fs.readFileSync(publicConfigPath, 'utf8');
  const configuredEnv = source.match(/const TARGET_ENV\s*=\s*'([^']+)'/);
  if (!configuredEnv) fail('config/public-config.js의 TARGET_ENV를 확인할 수 없습니다.');
  if (configuredEnv[1] !== targetEnv) {
    fail(`LOG_TRANSLATION_TARGET_ENV(${targetEnv})와 현재 TARGET_ENV(${configuredEnv[1]})가 다릅니다.`);
  }

  const escapedEnv = targetEnv.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`case '${escapedEnv}':[\\s\\S]*?url:\\s*'([^']+)'`);
  const configuredUrl = source.match(pattern);
  if (!configuredUrl) fail(`${targetEnv} 환경의 Supabase URL을 찾지 못했습니다.`);
  return configuredUrl[1];
}

function projectRefFromUrl(value) {
  try {
    const hostname = new URL(value).hostname;
    const [projectRef] = hostname.split('.');
    return projectRef || '';
  } catch {
    return '';
  }
}

function hasKoreanLabel(item) {
  const value = String(item?.code_value || '').trim();
  return Boolean(value) && value !== item?.code_key && /[가-힣]/.test(value) && item?.is_active !== false;
}

async function main() {
  const env = readLocalEnv();
  const targetEnv = String(env.LOG_TRANSLATION_TARGET_ENV || '').trim().toUpperCase();
  const projectRef = String(env.LOG_TRANSLATION_PROJECT_REF || '').trim();
  const supabaseUrl = String(env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
  const secretKey = String(env.SUPABASE_SECRET_KEY || '').trim();
  const serviceRoleKey = String(env.SUPABASE_SERVICE_ROLE_KEY || '').trim();
  const adminKey = secretKey || serviceRoleKey;

  if (!targetEnv || !projectRef || !supabaseUrl || !adminKey) {
    fail('LOG_TRANSLATION_TARGET_ENV, LOG_TRANSLATION_PROJECT_REF, SUPABASE_URL, SUPABASE_SECRET_KEY(권장) 또는 SUPABASE_SERVICE_ROLE_KEY를 설정하세요.');
  }

  const configuredUrl = configuredProjectUrl(targetEnv).replace(/\/+$/, '');
  const urlProjectRef = projectRefFromUrl(supabaseUrl);
  const configuredProjectRef = projectRefFromUrl(configuredUrl);
  if (urlProjectRef !== projectRef || configuredProjectRef !== projectRef || configuredUrl !== supabaseUrl) {
    fail('환경, project ref, SUPABASE_URL, config/public-config.js의 대상 프로젝트가 일치하지 않습니다.');
  }

  async function request(resource, options = {}) {
    const response = await fetch(`${supabaseUrl}/rest/v1/${resource}`, {
      ...options,
      headers: {
        apikey: adminKey,
        ...(secretKey ? {} : { Authorization: `Bearer ${serviceRoleKey}` }),
        'Content-Type': 'application/json',
        ...(options.headers || {})
      }
    });
    const body = await response.text();
    if (!response.ok) throw new Error(`${response.status} ${body || response.statusText}`);
    return body ? JSON.parse(body) : null;
  }

  async function fetchAll(resource) {
    const rows = [];
    const pageSize = 1000;
    for (let offset = 0; ; offset += pageSize) {
      const separator = resource.includes('?') ? '&' : '?';
      const page = await request(`${resource}${separator}limit=${pageSize}&offset=${offset}`);
      rows.push(...page);
      if (page.length < pageSize) return rows;
    }
  }

  const actionLabels = getActionLabels();
  const [logs, codeItems] = await Promise.all([
    fetchAll('activity_logs?select=action&action=not.is.null&is_deleted=eq.false&order=action.asc'),
    fetchAll('code_items?group_key=eq.activity_logs.action&select=code_key,code_value,is_active&order=code_key.asc')
  ]);

  const logActions = [...new Set(logs
    .map(row => String(row.action || '').trim())
    .filter(Boolean))].sort();
  const existingItems = new Map(codeItems.map(item => [item.code_key, item]));
  const unknownActions = logActions.filter(code => !actionLabels.has(code));
  const candidates = logActions
    .filter(code => actionLabels.has(code))
    .map(code => ({ code_key: code, code_value: actionLabels.get(code), existing: existingItems.get(code) }))
    .filter(item => !hasKoreanLabel(item.existing));
  const inserts = candidates.filter(item => !item.existing);
  const updates = candidates.filter(item => item.existing);

  const result = {
    mode: apply ? 'apply' : 'check',
    target_env: targetEnv,
    project_ref: projectRef,
    distinct_log_actions: logActions.length,
    known_actions: logActions.length - unknownActions.length,
    unknown_actions: unknownActions,
    labels_to_insert: inserts.map(item => item.code_key),
    labels_to_update: updates.map(item => item.code_key)
  };

  if (apply && inserts.length) {
    await request('code_items?on_conflict=group_key,code_key', {
      method: 'POST',
      headers: { Prefer: 'resolution=ignore-duplicates,return=minimal' },
      body: JSON.stringify(inserts.map(item => ({
        group_key: 'activity_logs.action',
        code_key: item.code_key,
        code_value: item.code_value,
        sort_order: 990000,
        is_active: true,
        meta: { source: 'sync-log-translations' }
      })))
    });
  }

  if (apply && updates.length) {
    for (const item of updates) {
      const params = new URLSearchParams({
        group_key: 'eq.activity_logs.action',
        code_key: `eq.${item.code_key}`
      });
      await request(`code_items?${params.toString()}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({ code_value: item.code_value, is_active: true })
      });
    }
  }

  if (apply && (inserts.length || updates.length)) {
    const verifiedItems = await fetchAll('code_items?group_key=eq.activity_logs.action&select=code_key,code_value,is_active&order=code_key.asc');
    const verifiedByCode = new Map(verifiedItems.map(item => [item.code_key, item]));
    result.remaining_untranslated_known_actions = logActions.filter(code =>
      actionLabels.has(code) && !hasKoreanLabel(verifiedByCode.get(code))
    );
  }

  console.log(JSON.stringify(result, null, 2));
  if (unknownActions.length || result.remaining_untranslated_known_actions?.length) process.exitCode = 2;
}

main().catch(error => {
  console.error(`로그 번역 동기화 실패: ${error.message || error}`);
  process.exit(1);
});
