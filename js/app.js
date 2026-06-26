document.addEventListener('DOMContentLoaded', () => {
  createFallingStars();
  checkSupabaseConnection();
  autoLogPageView();
});

/* ===== Falling Stars Effect ===== */
function createFallingStars() {
  const container = document.getElementById('fallingStars');
  const emojis = ['⭐', '✨', '🌟', '💫', '🌈'];
  const count = 20;

  for (let i = 0; i < count; i++) {
    const star = document.createElement('span');
    star.className = 'star';
    star.textContent = emojis[Math.floor(Math.random() * emojis.length)];
    star.style.left = `${Math.random() * 100}%`;
    star.style.fontSize = `${0.6 + Math.random() * 1}rem`;
    star.style.animationDuration = `${6 + Math.random() * 10}s`;
    star.style.animationDelay = `${Math.random() * 12}s`;
    container.appendChild(star);
  }
}

/* ===== Supabase Connection Check ===== */
async function checkSupabaseConnection() {
  const box = document.getElementById('statusBox');
  const value = document.getElementById('statusValue');

  const client = initSupabase();

  if (!client) {
    value.textContent = 'API 키 미설정';
    box.classList.add('error');
    return;
  }

  try {
    const { data, error } = await client.from('departments').select('id', { count: 'exact', head: true });

    if (!error) {
      value.textContent = '연결 성공 ✓';
      box.classList.remove('error');
      box.classList.add('connected');
    } else {
      value.textContent = '연결 실패';
      box.classList.add('error');
      logFatal('CONNECTION_FAIL', { error: error.message });
    }
  } catch (err) {
    value.textContent = '연결 실패';
    box.classList.add('error');
    logFatal('CONNECTION_FAIL', { error: String(err) });
  }
}
