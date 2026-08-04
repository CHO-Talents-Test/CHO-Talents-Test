#!/usr/bin/env node

/**
 * 과거 사용자 수정 실패 로그를 사람이 읽을 수 있는 대상·부서·오류 정보로 보완한다.
 * UUID는 화면에 노출하지 않도록 details에서 제거하며, 원본 로그 행 외의 데이터는 변경하지 않는다.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const envPath = path.join(rootDir, '.env.local');
const publicConfigPath = path.join(rootDir, 'config', 'public-config.js');
const args = new Set(process.argv.slice(2));
const apply = args.has('--apply');
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function fail(message) {
  console.error(`사용자 수정 실패 로그 보정 중단: ${message}`);
  process.exit(1);
}

if (args.size !== 1 || (!args.has('--check') && !args.has('--apply'))) {
  fail('사용법: node scripts/backfill-user-update-log-context.mjs --check | --apply');
}

function parseEnvFile(source) {
  const values = {};
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const index = line.indexOf('=');
    if (index > 0) values[line.slice(0, index)] = line.slice(index + 1).trim();
  }
  return values;
}

function getConfiguredProjectUrl(targetEnv) {
  const source = fs.readFileSync(publicConfigPath, 'utf8');
  const active = source.match(/const TARGET_ENV\s*=\s*'([^']+)'/);
  if (!active || active[1] !== targetEnv) fail('LOG_TRANSLATION_TARGET_ENV와 config/public-config.js의 대상 환경이 일치하지 않습니다.');
  const pattern = new RegExp(`case '${targetEnv}':[\\s\\S]*?url:\\s*'([^']+)'`);
  const configured = source.match(pattern);
  if (!configured) fail('대상 환경의 Supabase URL을 찾을 수 없습니다.');
  return configured[1].replace(/\/+$/, '');
}

function isUuid(value) {
  return typeof value === 'string' && UUID_RE.test(value);
}

function translatedError(value) {
  return String(value || '').trim() === 'Unauthorized' ? '권한이 없습니다' : value;
}

async function main() {
  if (!fs.existsSync(envPath)) fail('.env.local 파일이 없습니다.');
  const env = { ...parseEnvFile(fs.readFileSync(envPath, 'utf8')), ...process.env };
  const targetEnv = String(env.LOG_TRANSLATION_TARGET_ENV || '').trim().toUpperCase();
  const supabaseUrl = String(env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
  const key = String(env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY || '').trim();
  if (!targetEnv || !supabaseUrl || !key) fail('대상 환경, SUPABASE_URL, 서버 전용 키가 필요합니다.');
  if (getConfiguredProjectUrl(targetEnv) !== supabaseUrl) fail('Supabase URL이 현재 사이트 대상 환경과 다릅니다.');

  async function request(resource, options = {}) {
    const response = await fetch(`${supabaseUrl}/rest/v1/${resource}`, {
      ...options,
      headers: { apikey: key, 'Content-Type': 'application/json', ...(options.headers || {}) }
    });
    const body = await response.text();
    if (!response.ok) throw new Error(`${response.status} ${body || response.statusText}`);
    return body ? JSON.parse(body) : null;
  }

  const logs = await request('activity_logs?select=id,details&action=in.(USER_UPDATE_FAIL,USER_UPDATE_ERROR)&is_deleted=eq.false&order=created_at.asc');
  const profileCache = new Map();
  const departmentCache = new Map();

  async function findProfile(details) {
    const id = [details.targetUserId, details.userId, details.id].find(isUuid);
    const account = details.targetAccount || details.username || details['대상 아이디'] || null;
    const cacheKey = id ? `id:${id}` : `account:${account || ''}`;
    if (profileCache.has(cacheKey)) return profileCache.get(cacheKey);
    let rows = [];
    if (id) rows = await request(`profiles?select=id,username,display_name,department_id&id=eq.${encodeURIComponent(id)}&limit=1`);
    else if (account) rows = await request(`profiles?select=id,username,display_name,department_id&username=eq.${encodeURIComponent(account)}&limit=1`);
    const profile = rows[0] || null;
    profileCache.set(cacheKey, profile);
    return profile;
  }

  async function findDepartmentName(id) {
    if (!isUuid(id)) return null;
    if (departmentCache.has(id)) return departmentCache.get(id);
    const rows = await request(`departments?select=name&id=eq.${encodeURIComponent(id)}&limit=1`);
    const name = rows[0]?.name || null;
    departmentCache.set(id, name);
    return name;
  }

  const patches = [];
  let unresolvedTargets = 0;
  for (const row of logs) {
    const before = row.details && typeof row.details === 'object' && !Array.isArray(row.details) ? row.details : {};
    const details = { ...before };
    const profile = await findProfile(details);
    const departmentId = profile?.department_id || details.targetDepartmentId || details['대상 부서 ID'];
    const departmentName = await findDepartmentName(departmentId);

    if (profile) {
      details.targetName = profile.display_name || profile.username;
      details.targetAccount = profile.username;
      details.sourceTable = details.sourceTable || 'profiles';
    } else {
      unresolvedTargets += 1;
    }
    if (departmentName) details.targetDepartmentName = departmentName;
    if (details.error || details['오류']) details.error = translatedError(details.error || details['오류']);
    delete details['오류'];
    delete details.id;
    delete details.userId;
    delete details.targetUserId;
    delete details.targetDepartmentId;
    delete details['대상 부서 ID'];
    details.operation = details.operation || '사용자 정보 수정';
    details.requestedChanges = details.requestedChanges || '기존 로그에는 수정 요청 항목이 기록되지 않아 확인할 수 없습니다.';

    if (JSON.stringify(before) !== JSON.stringify(details)) patches.push({ id: row.id, details });
  }

  if (apply) {
    for (const patch of patches) {
      await request(`activity_logs?id=eq.${encodeURIComponent(patch.id)}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({ details: patch.details })
      });
    }
  }

  console.log(JSON.stringify({
    mode: apply ? 'apply' : 'check',
    matching_logs: logs.length,
    logs_to_update: patches.length,
    updated_logs: apply ? patches.length : 0,
    unresolved_targets: unresolvedTargets
  }, null, 2));
}

main().catch(error => fail(error.message || String(error)));
