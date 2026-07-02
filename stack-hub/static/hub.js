const TABS = ['downloads', 'status', 'agents', 'terminal'];

function showToast(msg) {
  const el = document.getElementById('toast');
  if (!el) return;
  el.textContent = msg;
  el.classList.add('show');
  setTimeout(() => el.classList.remove('show'), 3000);
}

function getTab() {
  const p = new URLSearchParams(location.search);
  const t = p.get('tab') || 'downloads';
  return TABS.includes(t) ? t : 'downloads';
}

function setTab(tab, push = true) {
  document.querySelectorAll('.tab').forEach((el) => {
    el.classList.toggle('active', el.dataset.tab === tab);
  });
  document.querySelectorAll('.panel').forEach((el) => {
    el.classList.toggle('active', el.id === tab);
  });
  if (push) {
    const url = new URL(location.href);
    url.searchParams.set('tab', tab);
    history.pushState({ tab }, '', url.pathname + url.search);
  }
}

function initTabs() {
  setTab(getTab(), false);
  document.querySelectorAll('.tab[data-tab]').forEach((el) => {
    el.addEventListener('click', (e) => {
      if (el.tagName === 'A') e.preventDefault();
      setTab(el.dataset.tab);
    });
  });
  window.addEventListener('popstate', () => setTab(getTab(), false));
}

async function resume(id) {
  showToast('Download queued — starting...');
  try {
    const r = await fetch('/hub/api/downloads/resume', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    const j = await r.json();
    if (!j.queued) showToast('Failed to queue download');
    else showToast(`Queued: ${id}`);
  } catch (e) {
    showToast('Error: ' + e.message);
  }
  pollDownloads();
}

function renderDownloads(d) {
  const grid = document.getElementById('dl-grid');
  const logEl = document.getElementById('dl-log');
  if (!grid) return;

  const warn = document.getElementById('watcher-warn');
  if (warn) {
    warn.style.display = d.watcher_up === false ? 'block' : 'none';
  }

  grid.innerHTML = (d.jobs || []).map((j) => `
    <div class="dl-card ${j.status}">
      <h3>${j.name}</h3>
      <span class="badge ${j.status}">${j.status}</span>
      <div>${j.size_gb} / ${j.expected_gb} GB (${j.progress_pct}%)</div>
      <div class="bar"><div class="bar-fill" style="width:${j.progress_pct}%"></div></div>
      ${j.status !== 'complete'
        ? `<button type="button" class="btn" data-resume="${j.id}">Resume</button>`
        : '<span class="ok">Ready</span>'}
    </div>`).join('');

  if (logEl) {
    logEl.textContent = '';
    (d.log_tail || []).forEach((line) => {
      const span = document.createElement('span');
      span.className = 'line';
      span.textContent = line;
      logEl.appendChild(span);
    });
    if (!(d.log_tail || []).length) logEl.textContent = 'No log yet';
  }
}

async function pollDownloads() {
  try {
    const r = await fetch('/hub/api/downloads');
    if (!r.ok) return;
    renderDownloads(await r.json());
  } catch (_) { /* ignore */ }
}

async function pollStatus() {
  try {
    const s = await fetch('/hub/api/status').then((r) => r.json());
    const dot = (ok) => (ok ? '<span class="ok">●</span>' : '<span class="bad">○</span>');
    const sg = document.getElementById('status-grid');
    if (sg) {
      sg.innerHTML = `
        <div class="card"><h2>Services</h2><ul>
          <li>${dot(s.omlx.up)} oMLX <a href="${s.omlx.admin}">admin</a></li>
          <li>${dot(s.ollama.up)} Ollama</li>
          <li>${dot(s.open_webui.up)} <a href="${s.open_webui.url}">Open WebUI</a></li>
          <li>MLX loaded: ${s.omlx.health?.engine_pool?.loaded_count ?? 0}</li>
        </ul></div>
        <div class="card"><h2>Ollama</h2><ul>
          ${s.ollama.models.map((m) => `<li><code>${m}</code></li>`).join('') || '<li class="warn">none</li>'}
        </ul></div>
        <div class="card"><h2>Cursor</h2><ul>
          <li><code>${s.cursor.base_url}</code></li>
          <li>Model: <code>${s.cursor.primary_model}</code></li>
        </ul></div>`;
    }
    const ag = document.getElementById('agents-grid');
    if (ag) {
      ag.innerHTML = Object.entries(s.agents)
        .filter(([k]) => k !== 'terminal')
        .map(([k, a]) => `
          <div class="card"><h2>${a.name || k}</h2>
            ${a.chat ? `<li><a href="${a.chat}">Open chat</a></li>` : ''}
            <li><code>${a.cmd}</code></li></div>`).join('');
    }
  } catch (_) { /* ignore */ }
}

function copyCmd(k) {
  const cmds = window.HUB_CMDS || {};
  navigator.clipboard.writeText(cmds[k] || '');
  showToast('Copied: ' + (cmds[k] || k));
}

document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  const grid = document.getElementById('dl-grid');
  if (grid) {
    grid.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-resume]');
      if (btn) resume(btn.dataset.resume);
    });
  }
  document.querySelectorAll('[data-copy]').forEach((el) => {
    el.addEventListener('click', () => copyCmd(el.dataset.copy));
  });
  pollDownloads();
  pollStatus();
  setInterval(pollDownloads, 3000);
  setInterval(pollStatus, 10000);
});
