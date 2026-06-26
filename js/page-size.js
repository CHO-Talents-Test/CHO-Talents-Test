(function () {
  let _pageSizes = null;
  let _saveTimer = null;

  async function _loadPageSizes() {
    if (_pageSizes !== null) return _pageSizes;
    try {
      const session = getSession();
      if (!session || !session.id || !_sb) { _pageSizes = {}; return _pageSizes; }
      const { data } = await _sb.from('user_preferences')
        .select('page_sizes')
        .eq('user_id', session.id)
        .single();
      _pageSizes = (data && data.page_sizes) ? data.page_sizes : {};
    } catch (e) {
      _pageSizes = {};
    }
    return _pageSizes;
  }

  async function loadPageSize(key, defaultSize) {
    const sizes = await _loadPageSizes();
    return sizes[key] || defaultSize;
  }

  async function savePageSize(key, size) {
    if (!_pageSizes) _pageSizes = {};
    _pageSizes[key] = size;
    clearTimeout(_saveTimer);
    _saveTimer = setTimeout(async () => {
      try {
        const session = getSession();
        if (!session || !session.id || !_sb) return;
        await _sb.from('user_preferences').upsert({
          user_id: session.id,
          page_sizes: _pageSizes,
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id' });
      } catch (e) { }
    }, 500);
  }

  function renderPageSizeSelector(key, currentSize, onChange) {
    const options = [3, 5, 10, 15, 20, 25, 30];
    return '<select class="page-size-select" onchange="' + onChange + '" style="padding:0.25rem 0.4rem;border:1px solid var(--t-border, #dee2e6);border-radius:6px;font-size:0.75rem;background:var(--t-input-bg, #fff);color:var(--t-text, #333);cursor:pointer;">'
      + options.map(n => '<option value="' + n + '"' + (n === currentSize ? ' selected' : '') + '>' + n + '개</option>').join('')
      + '</select>';
  }

  /**
   * Build pagination buttons with max 7 page numbers + ellipsis.
   * @param {number} cur  1-based current page
   * @param {number} tot  total pages
   * @param {string} goExpr  onclick template — use __PAGE__ for the 1-based page number
   * @returns {string} HTML string
   */
  function buildPagingButtons(cur, tot, goExpr) {
    if (tot <= 1) return '';
    var pages;
    if (tot <= 7) {
      pages = [];
      for (var i = 1; i <= tot; i++) pages.push(i);
    } else if (tot === 8 && cur === 4) {
      pages = [1, '…', 3, 4, 5, 6, 7, 8];
    } else {
      var s = cur - 2, e = cur + 2;
      if (s < 2) { e += (2 - s); s = 2; }
      if (e > tot - 1) { s -= (e - (tot - 1)); e = tot - 1; }
      if (s < 2) s = 2;
      pages = [1];
      if (s > 2) pages.push('…');
      for (var j = s; j <= e; j++) pages.push(j);
      if (e < tot - 1) pages.push('…');
      pages.push(tot);
    }
    var _b = function (p, label, dis) {
      return '<button class="filter-btn' + (p === cur ? ' active' : '') + '"' + (dis ? ' disabled' : '') +
        ' onclick="' + goExpr.replace(/__PAGE__/g, p) + '" style="padding:0.3rem 0.6rem;font-size:0.8rem;">' + label + '</button>';
    };
    var html = _b(cur - 1, '◀', cur <= 1);
    pages.forEach(function (p) {
      if (typeof p === 'string') {
        html += '<span style="padding:0.2rem 0.3rem;font-size:0.8rem;color:var(--t-text-muted, #adb5bd);">' + p + '</span>';
      } else {
        html += _b(p, p, false);
      }
    });
    html += _b(cur + 1, '▶', cur >= tot);
    html += '<span style="font-size:0.78rem;color:var(--t-text-muted, #adb5bd);margin-left:0.5rem;">' + cur + '/' + tot + '</span>';
    return html;
  }

  window.loadPageSize = loadPageSize;
  window.savePageSize = savePageSize;
  window.renderPageSizeSelector = renderPageSizeSelector;
  window.buildPagingButtons = buildPagingButtons;
})();
