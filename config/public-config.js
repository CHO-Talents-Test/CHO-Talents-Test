/*
 * Public runtime configuration for the browser app.
 *
 * Keep only browser-safe values in this file. Do not put GitHub tokens,
 * Supabase access tokens, service-role keys, or database passwords here.
 */
(() => {
  const TARGET_ENV = 'DEV'; // 'PROD' 또는 'DEV'

  let supabaseConfig;

  switch (TARGET_ENV) {
    case 'PROD':
      supabaseConfig = {
        url: 'https://rabakjtjtkelpskptnvi.supabase.co',
        anonKey: 'sb_publishable_X_5jRmNvnhIbwrkC2Dv0uQ_VoO3RtKo'
      };
      break;

    case 'DEV':
      supabaseConfig = {
        url: 'https://blitrrcdkkkszvgylnus.supabase.co',
        anonKey: 'sb_publishable_TgsQePzjxca9Hr3Lh_dHvA_O1JqRAQ6'
      };
      break;

    default:
      throw new Error(`Invalid TARGET_ENV: ${TARGET_ENV}`);
  }

  window.CHO_TALENTS_CONFIG = Object.freeze({
    env: TARGET_ENV,

    supabase: {
      ...supabaseConfig,
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
})();
