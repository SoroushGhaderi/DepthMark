/* DepthMark warehouse reference — shared behaviour (no dependencies) */
(() => {
  const root = document.documentElement;

  /* ---------- Theme: remembered per viewer, falls back to system ---------- */
  const themeBtn = document.getElementById('theme');
  const readTheme = () => { try { return localStorage.getItem('dm-theme'); } catch (e) { return null; } };
  const saveTheme = (t) => { try { localStorage.setItem('dm-theme', t); } catch (e) { /* storage blocked */ } };
  const setTheme = (t) => {
    root.dataset.theme = t;
    if (themeBtn) {
      themeBtn.textContent = t === 'dark' ? 'Light mode' : 'Dark mode';
      themeBtn.setAttribute('aria-pressed', String(t === 'dark'));
    }
  };
  setTheme(readTheme() || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'));
  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      const next = root.dataset.theme === 'dark' ? 'light' : 'dark';
      setTheme(next);
      saveTheme(next);
    });
  }

  /* ---------- Global search across all pages ---------- */
  const gInput = document.getElementById('global-search');
  const gResults = document.getElementById('global-results');
  const index = Array.isArray(window.DM_SEARCH) ? window.DM_SEARCH : [];

  const renderResults = () => {
    const q = gInput.value.trim().toLowerCase();
    gResults.innerHTML = '';
    if (!q) { gResults.hidden = true; return; }
    const hits = index.filter((e) => (e.t + ' ' + e.p + ' ' + (e.k || '')).toLowerCase().includes(q)).slice(0, 12);
    gResults.hidden = false;
    if (!hits.length) {
      const empty = document.createElement('div');
      empty.className = 'empty';
      empty.textContent = 'No matches. Try a table name, a command, or a concept.';
      gResults.appendChild(empty);
      return;
    }
    hits.forEach((e) => {
      const a = document.createElement('a');
      a.href = '#' + e.id;
      const t = document.createElement('div');
      t.className = 'r-title';
      t.textContent = e.t;
      const p = document.createElement('div');
      p.className = 'r-page';
      p.textContent = e.p;
      a.append(t, p);
      gResults.appendChild(a);
    });
  };
  if (gInput) {
    gInput.addEventListener('input', renderResults);
    gInput.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { gInput.value = ''; renderResults(); gInput.blur(); }
      if (e.key === 'Enter') { const first = gResults.querySelector('a'); if (first) first.click(); }
    });
    gInput.addEventListener('blur', () => setTimeout(() => { gResults.hidden = true; }, 150));
    gInput.addEventListener('focus', renderResults);
  }
  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && gInput && !/input|textarea|select/i.test(document.activeElement.tagName)) {
      e.preventDefault();
      gInput.focus();
    }
  });

  /* ---------- Scoped filters (text box, source chips, expand/collapse) ---------- */
  const states = new Map();
  const stateOf = (scope) => {
    if (!states.has(scope)) states.set(scope, { text: '', source: 'all' });
    return states.get(scope);
  };
  const applyScope = (scope) => {
    const st = stateOf(scope);
    const items = [...scope.querySelectorAll('[data-search]')];
    let visible = 0;
    items.forEach((el) => {
      const textOk = !st.text || (el.dataset.search || '').includes(st.text) || el.textContent.toLowerCase().includes(st.text);
      const sourceOk = st.source === 'all' || el.dataset.source === st.source;
      el.hidden = !(textOk && sourceOk);
      if (!el.hidden) visible++;
    });
    const scopeId = '#' + scope.id;
    document.querySelectorAll(`[data-count-for="${scopeId}"]`).forEach((c) => {
      c.textContent = `${visible} of ${items.length} ${c.dataset.countLabel || 'items'}`;
    });
  };

  document.querySelectorAll('[data-filter-input]').forEach((input) => {
    const scope = document.querySelector(input.dataset.scope);
    if (!scope) return;
    input.addEventListener('input', () => {
      stateOf(scope).text = input.value.trim().toLowerCase();
      applyScope(scope);
    });
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { input.value = ''; stateOf(scope).text = ''; applyScope(scope); input.blur(); }
    });
    applyScope(scope);
  });

  document.querySelectorAll('[data-filter-group] [data-value]').forEach((chip) => {
    const group = chip.closest('[data-filter-group]');
    const scope = document.querySelector(group.dataset.scope);
    if (!scope) return;
    chip.addEventListener('click', () => {
      stateOf(scope).source = chip.dataset.value;
      group.querySelectorAll('[data-value]').forEach((c) => c.setAttribute('aria-pressed', String(c === chip)));
      applyScope(scope);
    });
  });

  document.querySelectorAll('[data-expand]').forEach((btn) => {
    const scope = document.querySelector(btn.dataset.scope);
    if (!scope) return;
    btn.addEventListener('click', () => {
      const open = btn.dataset.expand === 'open';
      scope.querySelectorAll('details').forEach((d) => { if (!d.hidden) d.open = open; });
    });
  });

  /* ---------- Deep links: reset filters that hide the target, open its card, scroll ---------- */
  const resetScopesAround = (target) => {
    document.querySelectorAll('[data-scope-root]').forEach((scope) => {
      if (!scope.contains(target)) return;
      stateOf(scope).text = '';
      stateOf(scope).source = 'all';
      document.querySelectorAll(`[data-filter-input][data-scope="#${scope.id}"]`).forEach((i) => { i.value = ''; });
      document.querySelectorAll(`[data-filter-group][data-scope="#${scope.id}"] [data-value]`).forEach((c) => {
        c.setAttribute('aria-pressed', String(c.dataset.value === 'all'));
      });
      applyScope(scope);
    });
  };
  const revealId = (id) => {
    const target = id && document.getElementById(id);
    if (!target) return false;
    if (target.closest('[hidden]')) resetScopesAround(target);
    let d = target.closest('details');
    while (d) { d.open = true; d = d.parentElement && d.parentElement.closest('details'); }
    if (target.tagName === 'DETAILS') target.open = true;
    requestAnimationFrame(() => target.scrollIntoView({ block: 'start' }));
    return true;
  };
  const revealHash = () => {
    const id = decodeURIComponent(location.hash.slice(1));
    if (id) revealId(id);
  };
  window.addEventListener('hashchange', revealHash);
  // Embedded previews (srcdoc, blob:, data:, sandboxed frames) resolve "#id" against the wrong
  // URL or block fragment navigation, so there we switch pages ourselves and never leave the document.
  const nativeHash = /^(file|https?):$/.test(location.protocol) && location.href !== 'about:srcdoc';
  const manualNav = (id) => {
    const target = document.getElementById(id);
    if (!target) return;
    const page = target.classList.contains('page') ? target : target.closest('.page');
    document.body.classList.add('js-nav');
    document.querySelectorAll('.page').forEach((p) => p.classList.toggle('is-active', p === page));
    document.querySelectorAll('.sidebar a[data-page]').forEach((a) => {
      if (page && a.dataset.page === page.id) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    });
    revealId(id);
  };
  document.addEventListener('click', (e) => {
    const a = e.target.closest('a[href^="#"]');
    if (!a) return;
    const id = decodeURIComponent(a.getAttribute('href').slice(1));
    if (!nativeHash) {
      e.preventDefault();
      manualNav(id);
    } else {
      // A link to the current hash does not fire hashchange, so reveal the target here too.
      setTimeout(() => revealId(id), 0);
    }
  });
  revealHash();

  /* ---------- Copy buttons (Clipboard API, with a fallback) ---------- */
  const copyText = async (text) => {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (e) {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      let ok = false;
      try { ok = document.execCommand('copy'); } catch (err) { ok = false; }
      ta.remove();
      return ok;
    }
  };
  document.querySelectorAll('pre').forEach((pre) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'copy';
    btn.textContent = 'Copy';
    btn.setAttribute('aria-label', 'Copy this code');
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const code = pre.querySelector('code');
      const ok = await copyText(code ? code.textContent : pre.textContent);
      btn.textContent = ok ? 'Copied' : 'Copy failed';
      setTimeout(() => { btn.textContent = 'Copy'; }, 1500);
    });
    pre.appendChild(btn);
  });

  /* ---------- Print: open every card, restore afterwards ---------- */
  let before = null;
  window.addEventListener('beforeprint', () => {
    before = [...document.querySelectorAll('details')].map((d) => d.open);
    document.querySelectorAll('details').forEach((d) => { d.open = true; });
  });
  window.addEventListener('afterprint', () => {
    if (before) document.querySelectorAll('details').forEach((d, i) => { d.open = before[i]; });
    before = null;
  });
})();
