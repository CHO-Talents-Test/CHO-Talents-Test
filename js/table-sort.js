/* table-sort.js – 공통 헤더 클릭 정렬 유틸리티
 * initSortableHeaders(tableId, getDataFn, renderFn)
 *   tableId  : <table> 요소의 id
 *   getDataFn: 현재 표시 중인 데이터 배열을 반환하는 함수
 *   renderFn : 정렬된 배열을 받아 테이블을 다시 그리는 함수
 *
 * <th data-sort-key="fieldName"> 속성이 있는 헤더만 정렬 대상
 * data-sort-type="number" | "date" 을 지정하면 해당 타입으로 비교
 */
(function () {
  'use strict';

  function _compare(a, b, key, type) {
    var va = a[key], vb = b[key];
    if (va == null && vb == null) return 0;
    if (va == null) return 1;
    if (vb == null) return -1;

    if (type === 'number') {
      return (parseFloat(va) || 0) - (parseFloat(vb) || 0);
    }
    if (type === 'date') {
      return new Date(va) - new Date(vb);
    }
    return String(va).localeCompare(String(vb), 'ko');
  }

  function _clearArrows(ths, except) {
    ths.forEach(function (th) {
      if (th !== except) {
        th.classList.remove('sort-asc', 'sort-desc');
        th.removeAttribute('data-sort-dir');
      }
    });
  }

  /**
   * @param {string} tableId
   * @param {function(): Array} getDataFn
   * @param {function(Array): void} renderFn
   */
  function initSortableHeaders(tableId, getDataFn, renderFn) {
    var table = document.getElementById(tableId);
    if (!table) return;

    var ths = Array.from(table.querySelectorAll('th[data-sort-key]'));
    if (!ths.length) return;

    ths.forEach(function (th) {
      th.style.cursor = 'pointer';
      th.style.userSelect = 'none';

      th.addEventListener('click', function () {
        var key = th.getAttribute('data-sort-key');
        var type = th.getAttribute('data-sort-type') || 'string';
        var curDir = th.getAttribute('data-sort-dir');
        var newDir = curDir === 'asc' ? 'desc' : 'asc';

        _clearArrows(ths, th);
        th.classList.remove('sort-asc', 'sort-desc');
        th.classList.add(newDir === 'asc' ? 'sort-asc' : 'sort-desc');
        th.setAttribute('data-sort-dir', newDir);

        var data = getDataFn();
        if (!data || !data.length) return;

        data.sort(function (a, b) {
          var result = _compare(a, b, key, type);
          return newDir === 'desc' ? -result : result;
        });

        renderFn(data);
      });
    });
  }

  window.initSortableHeaders = initSortableHeaders;
})();
