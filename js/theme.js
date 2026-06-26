/**
 * Theme Module - 테마 로드/저장/적용
 * Supported themes: default, dark
 */

const THEMES = [
  { id: 'default', icon: '☀️', label: '일반' },
  { id: 'dark', icon: '🌙', label: '다크' }
];

const THEME_STORAGE_KEY = 'cho_theme';

function getCurrentTheme() {
  return document.documentElement.getAttribute('data-theme') || 'default';
}

function normalizeThemeId(themeId) {
  return THEMES.find(t => t.id === themeId) ? themeId : 'default';
}

function applyTheme(themeId) {
  themeId = normalizeThemeId(themeId);
  document.documentElement.setAttribute('data-theme', themeId);
  localStorage.setItem(THEME_STORAGE_KEY, themeId);
  updateThemePickerUI(themeId);
}

function loadThemeFromLocal() {
  const saved = normalizeThemeId(localStorage.getItem(THEME_STORAGE_KEY));
  document.documentElement.setAttribute('data-theme', saved);
  return saved;
}

async function loadThemeFromDB() {
  if (typeof _sb === 'undefined' || !_sb) return null;
  const session = typeof getSession === 'function' ? getSession() : null;
  if (!session) return null;
  try {
    const { data } = await _sb.from('user_preferences')
      .select('theme')
      .eq('user_id', session.id)
      .single();
    if (data && data.theme) {
      return normalizeThemeId(data.theme);
    }
  } catch(e) {}
  return null;
}

async function saveThemeToDB(themeId) {
  if (typeof _sb === 'undefined' || !_sb) return;
  const session = typeof getSession === 'function' ? getSession() : null;
  if (!session) return;
  themeId = normalizeThemeId(themeId);
  try {
    await _sb.from('user_preferences').upsert({
      user_id: session.id,
      theme: themeId,
      updated_at: new Date().toISOString()
    }, { onConflict: 'user_id' });
  } catch(e) { console.warn('[THEME] DB save failed:', e.message); }
}

async function initTheme() {
  let theme = loadThemeFromLocal();
  const dbTheme = await loadThemeFromDB();
  if (dbTheme) {
    theme = dbTheme;
    applyTheme(theme);
  } else if (theme !== getCurrentTheme()) {
    applyTheme(theme);
  }
  return theme;
}

async function setTheme(themeId) {
  applyTheme(themeId);
  await saveThemeToDB(themeId);
}

function positionThemeDropdown(dropdown, btn) {
  if (!dropdown || !btn || !dropdown.classList.contains('open')) return;

  const margin = 8;
  const btnRect = btn.getBoundingClientRect();
  const viewportWidth = window.innerWidth || document.documentElement.clientWidth;
  const viewportHeight = window.innerHeight || document.documentElement.clientHeight;
  const maxWidth = Math.max(160, viewportWidth - margin * 2);
  const maxHeight = Math.max(160, viewportHeight - margin * 2);

  dropdown.style.position = 'fixed';
  dropdown.style.right = 'auto';
  dropdown.style.left = '0px';
  dropdown.style.top = '0px';
  dropdown.style.maxWidth = `${maxWidth}px`;
  dropdown.style.maxHeight = `${maxHeight}px`;
  dropdown.style.overflowY = 'auto';

  const width = Math.min(Math.max(dropdown.offsetWidth || 180, 180), maxWidth);
  dropdown.style.width = `${width}px`;

  const height = Math.min(dropdown.offsetHeight || 0, maxHeight);
  const left = Math.min(
    Math.max(btnRect.right - width, margin),
    Math.max(margin, viewportWidth - width - margin)
  );
  let top = btnRect.bottom + margin;
  if (top + height > viewportHeight - margin) {
    top = btnRect.top - height - margin;
  }
  top = Math.min(Math.max(top, margin), Math.max(margin, viewportHeight - height - margin));

  dropdown.style.left = `${left}px`;
  dropdown.style.top = `${top}px`;
}

function renderThemePicker(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;
  const current = getCurrentTheme();
  const isDark = current === 'dark';

  container.innerHTML = `
    <div class="theme-switch-wrap">
      <span class="theme-switch-text">일반</span>
      <button
        class="theme-switch${isDark ? ' dark' : ''}"
        data-theme-btn
        title="다크 모드 전환"
        aria-label="다크 모드 전환"
        aria-pressed="${isDark ? 'true' : 'false'}"
      >
        <span class="theme-switch-track">
          <span class="theme-switch-thumb">${isDark ? '🌙' : '☀️'}</span>
        </span>
      </button>
      <span class="theme-switch-text">다크</span>
    </div>
  `;

  const btn = container.querySelector('[data-theme-btn]');
  btn.addEventListener('click', () => {
    const nextTheme = getCurrentTheme() === 'dark' ? 'default' : 'dark';
    setTheme(nextTheme);
  });
}

function updateThemePickerUI(themeId) {
  const isDark = normalizeThemeId(themeId) === 'dark';
  document.querySelectorAll('[data-theme-btn]').forEach(btn => {
    btn.classList.toggle('dark', isDark);
    btn.setAttribute('aria-pressed', isDark ? 'true' : 'false');
    const thumb = btn.querySelector('.theme-switch-thumb');
    if (thumb) thumb.textContent = isDark ? '🌙' : '☀️';
  });
}

// Apply theme immediately on script load (prevents flash)
(function() {
  loadThemeFromLocal();
})();
