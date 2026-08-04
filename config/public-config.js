/*
 * Public runtime configuration for the browser app.
 *
 * Keep only browser-safe values in this file. Do not put GitHub tokens,
 * Supabase access tokens, service-role keys, or database passwords here.
 */
(() => {
  // The same source is deployed to both repositories. Pick the environment
  // from the deployed origin so copying verified DEV source to PROD cannot
  // accidentally point production browsers at the DEV database.
  const ENV_BY_HOST = Object.freeze({
    'cho-talents.github.io': 'PROD',
    'cho-talents-test.github.io': 'DEV',
    'localhost': 'DEV',
    '127.0.0.1': 'DEV'
  });
  const TARGET_ENV = ENV_BY_HOST[window.location.hostname];

  let supabaseConfig;
  let kakaoConfig;

  switch (TARGET_ENV) {
    case 'PROD':
      supabaseConfig = {
        url: 'https://rabakjtjtkelpskptnvi.supabase.co',
        anonKey: 'sb_publishable_X_5jRmNvnhIbwrkC2Dv0uQ_VoO3RtKo'
      };
      kakaoConfig = {
        mapKey: '0ef8925b28135eeac474bc411c456170'
      };
      break;

    case 'DEV':
      supabaseConfig = {
        url: 'https://blitrrcdkkkszvgylnus.supabase.co',
        anonKey: 'sb_publishable_TgsQePzjxca9Hr3Lh_dHvA_O1JqRAQ6'
      };
      kakaoConfig = {
        mapKey: 'f880c1746c4cd81e2fa54df45ebea41d'
      };
      break;

    default:
      throw new Error(`Invalid TARGET_ENV: ${TARGET_ENV}`);
  }

  window.CHO_TALENTS_CONFIG = Object.freeze({
    env: TARGET_ENV,

    appUrls: {
      dev: 'https://cho-talents-test.github.io/CHO-Talents-Test/',
      prod: 'https://cho-talents.github.io/CHO-Talents/'
    },

    supabase: {
      ...supabaseConfig,
      authEmailDomain: '@cho-talents.app'
    },

    kakao: kakaoConfig,

    github: TARGET_ENV === 'DEV'
      ? {
          owner: 'CHO-Talents-Test',
          repo: 'CHO-Talents-Test',
          defaultBranch: 'develop'
        }
      : {
          owner: 'CHO-Talents',
          repo: 'CHO-Talents',
          defaultBranch: 'develop'
        },

    // DEV에서는 외부 알림을 호출하지 않습니다. 이 플래그는 UI와 로그 알림의
    // Edge Function 호출을 모두 차단하므로 Slack 미설정 오류 로그도 남기지 않습니다.
    notifications: {
      slackEnabled: TARGET_ENV === 'PROD'
    },

    ui: {
      preferenceResetVersion: TARGET_ENV === 'DEV' ? '2026-08-04' : '1'
    }
  });
})();
