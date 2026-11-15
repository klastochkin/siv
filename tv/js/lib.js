/*
 * Pure helpers for SIV TV (no DOM). ES5 so it runs on older Tizen WebKit/Chromium.
 * Loaded as a browser global (window.SIVLib) and as a CommonJS module for tests.
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SIVLib = factory();
  }
})(this, function () {
  'use strict';

  var SCHEMA_VERSION = 1;
  var DEFAULT_PORT = 8080;
  var INTERVALS = [3, 5, 8, 12, 20, 30];

  /**
   * Accepts what a user types with a TV keyboard ("192.168.1.50", "192.168.1.50:8080",
   * "http://host/lib/") and returns a canonical base URL without trailing slash, or null.
   * Without an explicit scheme or port, SIV's default port is assumed.
   */
  function normalizeBaseUrl(input) {
    if (typeof input !== 'string') return null;
    var s = input.replace(/\s+/g, '');
    if (!s) return null;
    var hasScheme = /^[a-z][a-z0-9+.-]*:\/\//i.test(s);
    if (!hasScheme) s = 'http://' + s;
    var m = /^(https?):\/\/([^\/?#@:]+|\[[0-9a-f:]+\])(?::(\d{1,5}))?(\/[^?#]*)?$/i.exec(s);
    if (!m) return null;
    var scheme = m[1].toLowerCase();
    var host = m[2].toLowerCase();
    var port = m[3];
    var path = (m[4] || '').replace(/\/+$/, '');
    if (!/^[a-z0-9.\-\[\]:]+$/.test(host) || host.charAt(0) === '.' || host.charAt(host.length - 1) === '.') return null;
    if (port !== undefined) {
      var n = parseInt(port, 10);
      if (n < 1 || n > 65535) return null;
    } else if (!hasScheme) {
      port = String(DEFAULT_PORT);
    }
    if (/(^|\/)\.\.?(\/|$)/.test(path)) return null;
    return scheme + '://' + host + (port !== undefined ? ':' + port : '') + path;
  }

  /** True for index paths like "thumbs/abc.jpg": relative, no scheme, no dot segments. */
  function isSafeRelativePath(p) {
    if (typeof p !== 'string' || !p) return false;
    if (/^[a-z][a-z0-9+.-]*:/i.test(p) || p.charAt(0) === '/' || p.indexOf('\\') !== -1) return false;
    if (p.indexOf('?') !== -1 || p.indexOf('#') !== -1) return false;
    var segs = p.split('/');
    for (var i = 0; i < segs.length; i++) {
      var seg = segs[i];
      var decoded;
      try { decoded = decodeURIComponent(seg); } catch (e) { return false; }
      if (!seg || decoded.charAt(0) === '.' || decoded.indexOf('/') !== -1) return false;
    }
    return true;
  }

  /** Joins a base URL and a safe relative path, appending the token when set. Returns null for unsafe paths. */
  function resolveUrl(base, relPath, token) {
    if (!isSafeRelativePath(relPath)) return null;
    return withToken(base + '/' + relPath, token);
  }

  function withToken(url, token) {
    if (!token) return url;
    return url + (url.indexOf('?') === -1 ? '?' : '&') + 'token=' + encodeURIComponent(token);
  }

  function isPositiveInt(v) {
    return typeof v === 'number' && isFinite(v) && v > 0 && Math.floor(v) === v;
  }

  function parseDate(value) {
    if (typeof value !== 'string') return null;
    var t = Date.parse(value);
    return isNaN(t) ? null : new Date(t);
  }

  /**
   * Validates parsed index.json. Throws on unusable documents; drops individual bad
   * photos (reported in `skipped`) so one broken entry never blanks the whole grid.
   */
  function validateIndex(doc) {
    if (!doc || typeof doc !== 'object' || Object.prototype.toString.call(doc) === '[object Array]') {
      throw new Error('index.json is not an object');
    }
    if (doc.version !== SCHEMA_VERSION) {
      throw new Error('Unsupported library version ' + doc.version + ' (expected ' + SCHEMA_VERSION + ')');
    }
    if (Object.prototype.toString.call(doc.photos) !== '[object Array]') {
      throw new Error('index.json has no photos list');
    }
    var photos = [];
    var skipped = 0;
    var seen = {};
    for (var i = 0; i < doc.photos.length; i++) {
      var p = doc.photos[i];
      if (!p || typeof p !== 'object' || typeof p.id !== 'string' || !p.id || seen.hasOwnProperty(p.id) ||
          !isSafeRelativePath(p.thumb) || !isSafeRelativePath(p.full) ||
          !isPositiveInt(p.width) || !isPositiveInt(p.height)) {
        skipped++;
        continue;
      }
      seen[p.id] = true;
      photos.push({
        id: p.id,
        title: typeof p.title === 'string' ? p.title : '',
        takenAt: parseDate(p.takenAt),
        thumb: p.thumb,
        full: p.full,
        width: p.width,
        height: p.height
      });
    }
    return {
      albumName: typeof doc.albumName === 'string' && doc.albumName ? doc.albumName : 'Photos',
      generatedAt: parseDate(doc.generatedAt),
      photos: photos,
      skipped: skipped
    };
  }

  /**
   * Grid focus movement. Returns the new index, or -1 when moving up from the first row
   * (the caller moves focus to the toolbar).
   */
  function gridMove(index, direction, count, cols) {
    if (count <= 0) return -1;
    cols = Math.max(1, cols);
    index = Math.min(Math.max(index, 0), count - 1);
    switch (direction) {
      case 'left': return Math.max(0, index - 1);
      case 'right': return Math.min(count - 1, index + 1);
      case 'up': return index - cols < 0 ? -1 : index - cols;
      case 'down':
        if (index + cols < count) return index + cols;
        // From the second-to-last row, a partial last row still accepts "down".
        return Math.floor(index / cols) < Math.floor((count - 1) / cols) ? count - 1 : index;
      default: return index;
    }
  }

  /** Rows [first, last] that should have thumbnails loaded around the visible window. */
  function rowsToLoad(scrollTop, viewportHeight, rowHeight, totalRows, margin) {
    if (totalRows <= 0 || !(rowHeight > 0)) return { first: 0, last: -1 };
    var first = Math.floor(scrollTop / rowHeight) - margin;
    var last = Math.ceil((scrollTop + viewportHeight) / rowHeight) + margin;
    return { first: Math.max(0, first), last: Math.min(totalRows - 1, last) };
  }

  /** scrollTop that keeps `row` fully visible, moving as little as possible. */
  function scrollForRow(row, currentScroll, viewportHeight, rowHeight, padding) {
    var top = row * rowHeight;
    var bottom = top + rowHeight;
    if (top - padding < currentScroll) return Math.max(0, top - padding);
    if (bottom + padding > currentScroll + viewportHeight) return bottom + padding - viewportHeight;
    return currentScroll;
  }

  function wrapIndex(i, n) {
    if (n <= 0) return 0;
    return ((i % n) + n) % n;
  }

  function nextInterval(current, step) {
    var i = INTERVALS.indexOf(current);
    if (i === -1) i = 1;
    return INTERVALS[Math.min(INTERVALS.length - 1, Math.max(0, i + step))];
  }

  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  function formatDate(date) {
    if (!(date instanceof Date) || isNaN(date.getTime())) return '';
    return date.getDate() + ' ' + MONTHS[date.getMonth()] + ' ' + date.getFullYear();
  }

  /** Maps Tizen remote and desktop keyboard codes to logical actions. */
  var KEYS = {
    37: 'left', 38: 'up', 39: 'right', 40: 'down',
    13: 'enter', 32: 'enter',
    10009: 'back', 27: 'back', 8: 'back', 461: 'back',
    10252: 'playpause', 415: 'play', 19: 'pause', 413: 'stop',
    417: 'next', 412: 'prev', 10233: 'next', 10232: 'prev',
    403: 'red', 404: 'green', 405: 'yellow', 406: 'blue',
    65376: 'imedone', 65385: 'imecancel'
  };

  function keyAction(keyCode) {
    return KEYS[keyCode] || null;
  }

  /** Tizen keys that must be registered to reach the app (arrows/enter/back always do). */
  var TIZEN_REGISTERED_KEYS = [
    'MediaPlayPause', 'MediaPlay', 'MediaPause', 'MediaStop',
    'MediaFastForward', 'MediaRewind', 'MediaTrackNext', 'MediaTrackPrevious',
    'ColorF0Red', 'ColorF1Green', 'ColorF2Yellow', 'ColorF3Blue'
  ];

  return {
    SCHEMA_VERSION: SCHEMA_VERSION,
    DEFAULT_PORT: DEFAULT_PORT,
    INTERVALS: INTERVALS,
    TIZEN_REGISTERED_KEYS: TIZEN_REGISTERED_KEYS,
    normalizeBaseUrl: normalizeBaseUrl,
    isSafeRelativePath: isSafeRelativePath,
    resolveUrl: resolveUrl,
    withToken: withToken,
    validateIndex: validateIndex,
    gridMove: gridMove,
    rowsToLoad: rowsToLoad,
    scrollForRow: scrollForRow,
    wrapIndex: wrapIndex,
    nextInterval: nextInterval,
    formatDate: formatDate,
    keyAction: keyAction
  };
});
