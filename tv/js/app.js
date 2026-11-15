/* SIV TV — grid + slideshow client for a SIV-published photo library. ES5 for older Tizen. */
(function () {
  'use strict';

  var L = window.SIVLib;
  var CONFIG = window.SIV_CONFIG || {};
  var STORAGE = { url: 'siv.serverUrl', token: 'siv.token', interval: 'siv.interval' };
  var REQUEST_TIMEOUT_MS = 15000;
  var OVERLAY_MS = 3500;
  var LOAD_MARGIN_ROWS = 2;

  var state = {
    screen: null,
    settings: loadSettings(),
    library: null,
    grid: { index: 0, cols: 1, rowHeight: 1, toolbarIndex: -1 },
    slide: { index: 0, playing: true, timer: null, overlayTimer: null, front: null, back: null, token: 0 },
    form: { focus: 0, editing: null, interval: 5, returnTo: null },
    message: { focus: 0, buttons: [] }
  };

  function $(id) { return document.getElementById(id); }

  // ---------------------------------------------------------------- settings

  function storageGet(key) {
    try { return window.localStorage.getItem(key); } catch (e) { return null; }
  }

  function storageSet(key, value) {
    try { window.localStorage.setItem(key, value); } catch (e) { /* storage unavailable */ }
  }

  function loadSettings() {
    var interval = parseInt(storageGet(STORAGE.interval), 10);
    var url = storageGet(STORAGE.url);
    var token = storageGet(STORAGE.token);
    return {
      url: L.normalizeBaseUrl(url !== null ? url : (CONFIG.serverUrl || '')),
      token: token !== null ? token : (CONFIG.token || ''),
      interval: L.INTERVALS.indexOf(interval) !== -1 ? interval : 5
    };
  }

  function saveSettings(s) {
    storageSet(STORAGE.url, s.url || '');
    storageSet(STORAGE.token, s.token || '');
    storageSet(STORAGE.interval, String(s.interval));
    state.settings = s;
  }

  function url(relPath) {
    return L.resolveUrl(state.settings.url, relPath, state.settings.token);
  }

  // ---------------------------------------------------------------- screens

  function show(name) {
    var screens = document.querySelectorAll('.screen');
    for (var i = 0; i < screens.length; i++) {
      screens[i].className = 'screen' + (screens[i].id === 'screen-' + name ? ' active' : '');
    }
    if (state.screen === 'slideshow' && name !== 'slideshow') stopSlideshow();
    state.screen = name;
    setScreenSaver(name !== 'slideshow');
  }

  function showMessage(text, detail, buttons) {
    $('message-text').textContent = text;
    $('message-detail').textContent = detail || '';
    $('message-spinner').style.display = buttons && buttons.length ? 'none' : '';
    var box = $('message-buttons');
    box.innerHTML = '';
    state.message.buttons = buttons || [];
    state.message.focus = 0;
    for (var i = 0; i < state.message.buttons.length; i++) {
      var b = document.createElement('div');
      b.className = 'button';
      b.textContent = state.message.buttons[i].label;
      box.appendChild(b);
    }
    renderMessageFocus();
    show('message');
  }

  function renderMessageFocus() {
    var nodes = $('message-buttons').childNodes;
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].className = 'button' + (i === state.message.focus ? ' focused' : '');
    }
  }

  // ---------------------------------------------------------------- loading

  function loadLibrary() {
    if (!state.settings.url) {
      openSettings(null);
      return;
    }
    showMessage('Connecting…', state.settings.url);
    var xhr = new XMLHttpRequest();
    var done = false;
    function fail(title, detail) {
      if (done) return;
      done = true;
      showMessage(title, detail, [
        { label: 'Retry', run: loadLibrary },
        { label: 'Settings', run: function () { openSettings(null); } }
      ]);
    }
    xhr.open('GET', L.withToken(state.settings.url + '/index.json', state.settings.token) +
      (state.settings.token ? '&' : '?') + '_=' + Date.now(), true);
    xhr.timeout = REQUEST_TIMEOUT_MS;
    xhr.ontimeout = function () { fail('Server did not respond', state.settings.url + ' timed out.'); };
    xhr.onerror = function () {
      fail('Cannot reach the photo server',
        'Check that SIV’s TV server is running on ' + state.settings.url + ' and the TV is on the same network.');
    };
    xhr.onload = function () {
      if (done) return;
      if (xhr.status === 401) return fail('Access denied', 'The server needs an access token. Enter it in Settings.');
      if (xhr.status === 404) return fail('No photo library found', 'Publish an album from SIV on your Mac (Album → Publish to TV).');
      if (xhr.status !== 200) return fail('Server error ' + xhr.status, state.settings.url);
      var lib;
      try {
        lib = L.validateIndex(JSON.parse(xhr.responseText));
      } catch (e) {
        return fail('Library is unreadable', e.message);
      }
      done = true;
      state.library = lib;
      if (!lib.photos.length) {
        showMessage('The album is empty', 'Add photos in SIV and publish again.', [
          { label: 'Reload', run: loadLibrary },
          { label: 'Settings', run: function () { openSettings(null); } }
        ]);
        return;
      }
      openGrid(Math.min(state.grid.index, lib.photos.length - 1));
    };
    xhr.send();
  }

  // ---------------------------------------------------------------- grid

  function openGrid(focusIndex) {
    var lib = state.library;
    $('album-name').textContent = lib.albumName;
    $('photo-count').textContent = lib.photos.length + (lib.photos.length === 1 ? ' photo' : ' photos') +
      (lib.skipped ? ' · ' + lib.skipped + ' skipped' : '');
    var grid = $('grid');
    if (grid.getAttribute('data-library') !== String(lib.generatedAt && lib.generatedAt.getTime()) ||
        grid.childNodes.length !== lib.photos.length) {
      buildGrid(lib.photos);
      grid.setAttribute('data-library', String(lib.generatedAt && lib.generatedAt.getTime()));
    }
    show('grid');
    measureGrid();
    state.grid.toolbarIndex = -1;
    focusTile(focusIndex || 0);
  }

  function buildGrid(photos) {
    var grid = $('grid');
    grid.innerHTML = '';
    var frag = document.createDocumentFragment();
    for (var i = 0; i < photos.length; i++) {
      var tile = document.createElement('div');
      tile.className = 'tile';
      var img = document.createElement('img');
      img.setAttribute('alt', '');
      img.onerror = markBroken;
      tile.appendChild(img);
      frag.appendChild(tile);
    }
    grid.appendChild(frag);
    $('grid-viewport').scrollTop = 0;
  }

  function markBroken() {
    this.parentNode.className += ' broken';
  }

  function measureGrid() {
    var tiles = $('grid').childNodes;
    if (!tiles.length) return;
    var top = tiles[0].offsetTop;
    var cols = 0;
    while (cols < tiles.length && tiles[cols].offsetTop === top) cols++;
    state.grid.cols = Math.max(1, cols);
    state.grid.rowHeight = tiles.length > cols
      ? tiles[cols].offsetTop - top
      : tiles[0].offsetHeight + 24;
  }

  function focusTile(index) {
    var tiles = $('grid').childNodes;
    var g = state.grid;
    if (tiles[g.index]) tiles[g.index].className = tiles[g.index].className.replace(' focused', '');
    g.index = index;
    if (g.toolbarIndex === -1 && tiles[index]) tiles[index].className += ' focused';
    renderToolbarFocus();

    var viewport = $('grid-viewport');
    var row = Math.floor(index / g.cols);
    viewport.scrollTop = L.scrollForRow(row, viewport.scrollTop, viewport.clientHeight, g.rowHeight, 24);
    loadVisibleThumbs();
  }

  function loadVisibleThumbs() {
    var tiles = $('grid').childNodes;
    var g = state.grid;
    var viewport = $('grid-viewport');
    var range = L.rowsToLoad(viewport.scrollTop, viewport.clientHeight, g.rowHeight,
      Math.ceil(tiles.length / g.cols), LOAD_MARGIN_ROWS);
    var photos = state.library.photos;
    for (var i = range.first * g.cols; i < Math.min(tiles.length, (range.last + 1) * g.cols); i++) {
      var img = tiles[i].firstChild;
      if (!img.getAttribute('src')) img.setAttribute('src', url(photos[i].thumb));
    }
  }

  function renderToolbarFocus() {
    var buttons = document.querySelectorAll('#toolbar .button');
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].className = 'button' + (i === state.grid.toolbarIndex ? ' focused' : '');
    }
    var tile = $('grid').childNodes[state.grid.index];
    if (tile) {
      var focused = state.grid.toolbarIndex === -1;
      var has = tile.className.indexOf(' focused') !== -1;
      if (focused && !has) tile.className += ' focused';
      if (!focused && has) tile.className = tile.className.replace(' focused', '');
    }
  }

  function toolbarAction(i) {
    var action = document.querySelectorAll('#toolbar .button')[i].getAttribute('data-action');
    if (action === 'slideshow') openSlideshow(state.grid.index, true);
    else if (action === 'reload') loadLibrary();
    else if (action === 'settings') openSettings('grid');
  }

  function gridKey(action) {
    var g = state.grid;
    var count = state.library.photos.length;
    var buttons = document.querySelectorAll('#toolbar .button').length;
    if (g.toolbarIndex !== -1) {
      if (action === 'left') g.toolbarIndex = Math.max(0, g.toolbarIndex - 1);
      else if (action === 'right') g.toolbarIndex = Math.min(buttons - 1, g.toolbarIndex + 1);
      else if (action === 'down') g.toolbarIndex = -1;
      else if (action === 'enter') return toolbarAction(g.toolbarIndex);
      else if (action === 'back') g.toolbarIndex = -1;
      renderToolbarFocus();
      return;
    }
    switch (action) {
      case 'left': case 'right': case 'down':
        focusTile(L.gridMove(g.index, action, count, g.cols));
        return;
      case 'up':
        var next = L.gridMove(g.index, 'up', count, g.cols);
        if (next === -1) {
          g.toolbarIndex = 0;
          renderToolbarFocus();
        } else {
          focusTile(next);
        }
        return;
      case 'enter': return openSlideshow(g.index, false);
      case 'play': case 'playpause': return openSlideshow(g.index, true);
      case 'blue': return openSettings('grid');
      case 'green': return loadLibrary();
      case 'back': return exitApp();
    }
  }

  // ---------------------------------------------------------------- slideshow

  function openSlideshow(index, playing) {
    var s = state.slide;
    s.playing = playing;
    s.front = $('slide-a');
    s.back = $('slide-b');
    s.front.className = 'slide';
    s.back.className = 'slide';
    s.front.removeAttribute('src');
    s.back.removeAttribute('src');
    show('slideshow');
    showSlide(index);
  }

  function showSlide(index) {
    var s = state.slide;
    var photos = state.library.photos;
    s.index = L.wrapIndex(index, photos.length);
    clearTimeout(s.timer);
    var token = ++s.token;
    var photo = photos[s.index];
    var img = s.back;
    $('slide-error').style.display = 'none';

    img.onload = function () {
      if (token !== s.token) return;
      img.className = 'slide visible';
      s.front.className = 'slide';
      s.back = s.front;
      s.front = img;
      schedule();
      preload(s.index + 1);
      preload(s.index - 1);
    };
    img.onerror = function () {
      if (token !== s.token) return;
      $('slide-error').textContent = 'Cannot load ' + (photo.title || 'photo');
      $('slide-error').style.display = '';
      schedule();
    };
    img.setAttribute('src', url(photo.full));
    renderSlideInfo(true);
  }

  function preload(i) {
    var photos = state.library.photos;
    if (photos.length < 2) return;
    var im = new Image();
    im.src = url(photos[L.wrapIndex(i, photos.length)].full);
  }

  function schedule() {
    var s = state.slide;
    clearTimeout(s.timer);
    if (s.playing && state.library.photos.length > 1) {
      s.timer = setTimeout(function () { showSlide(s.index + 1); }, state.settings.interval * 1000);
    }
  }

  function renderSlideInfo(flash) {
    var s = state.slide;
    var photo = state.library.photos[s.index];
    $('slide-title').textContent = photo.title;
    $('slide-date').textContent = L.formatDate(photo.takenAt);
    $('slide-pos').textContent = (s.index + 1) + ' / ' + state.library.photos.length;
    $('slide-state').textContent = s.playing ? '▶ ' + state.settings.interval + 's' : '❚❚ Paused';
    if (flash) {
      $('slide-info').className = 'overlay visible';
      clearTimeout(s.overlayTimer);
      s.overlayTimer = setTimeout(function () {
        if (state.slide.playing) $('slide-info').className = 'overlay';
      }, OVERLAY_MS);
    }
  }

  function togglePlay(force) {
    var s = state.slide;
    s.playing = force === undefined ? !s.playing : force;
    renderSlideInfo(true);
    if (s.playing) schedule(); else clearTimeout(s.timer);
  }

  function stopSlideshow() {
    var s = state.slide;
    clearTimeout(s.timer);
    clearTimeout(s.overlayTimer);
    s.token++;
  }

  function slideshowKey(action) {
    var s = state.slide;
    switch (action) {
      case 'left': case 'prev': return showSlide(s.index - 1);
      case 'right': case 'next': return showSlide(s.index + 1);
      case 'enter': case 'playpause': return togglePlay();
      case 'play': return togglePlay(true);
      case 'pause': return togglePlay(false);
      case 'up': case 'down': return renderSlideInfo(true);
      case 'back': case 'stop': return openGrid(s.index);
    }
  }

  // ---------------------------------------------------------------- settings form

  var FIELDS = ['url', 'token', 'interval', 'save', 'cancel'];

  function openSettings(returnTo) {
    var f = state.form;
    f.returnTo = returnTo;
    f.editing = null;
    f.focus = 0;
    f.interval = state.settings.interval;
    $('set-url').value = state.settings.url || '';
    $('set-token').value = state.settings.token || '';
    $('settings-error').textContent = '';
    $('field-cancel').style.display = returnTo && state.library ? '' : 'none';
    renderForm();
    show('settings');
  }

  function renderForm() {
    var f = state.form;
    for (var i = 0; i < FIELDS.length; i++) {
      var el = $('field-' + FIELDS[i]);
      var cls = el.className.replace(/ ?(focused|editing)/g, '');
      if (i === f.focus) cls += f.editing ? ' editing' : ' focused';
      el.className = cls;
    }
    $('set-interval').textContent = f.interval + ' seconds';
  }

  function visibleFields() {
    return $('field-cancel').style.display === 'none' ? FIELDS.length - 1 : FIELDS.length;
  }

  function beginEdit(name) {
    var input = $('set-' + name);
    state.form.editing = name;
    renderForm();
    input.focus();
    try { input.setSelectionRange(input.value.length, input.value.length); } catch (e) { /* unsupported */ }
  }

  function endEdit() {
    var name = state.form.editing;
    if (!name) return;
    state.form.editing = null;
    $('set-' + name).blur();
    renderForm();
  }

  function submitSettings() {
    var raw = $('set-url').value;
    var normalized = L.normalizeBaseUrl(raw);
    if (!normalized) {
      $('settings-error').textContent = raw ? 'Not a valid address: ' + raw : 'Enter the server address shown in SIV.';
      state.form.focus = 0;
      renderForm();
      return;
    }
    saveSettings({ url: normalized, token: $('set-token').value.replace(/\s+/g, ''), interval: state.form.interval });
    state.grid.index = 0;
    loadLibrary();
  }

  function settingsKey(action, event) {
    var f = state.form;
    if (f.editing) {
      if (action === 'enter' && event.keyCode === 32) return false;
      if (action === 'enter' || action === 'imedone' || action === 'imecancel' ||
          (action === 'back' && event.keyCode !== 8) ||
          action === 'up' || action === 'down') {
        endEdit();
        if (action === 'down') { f.focus = Math.min(visibleFields() - 1, f.focus + 1); renderForm(); }
        if (action === 'up') { f.focus = Math.max(0, f.focus - 1); renderForm(); }
        return true;
      }
      return false;
    }
    var name = FIELDS[f.focus];
    switch (action) {
      case 'up': f.focus = Math.max(0, f.focus - 1); break;
      case 'down': f.focus = Math.min(visibleFields() - 1, f.focus + 1); break;
      case 'left': case 'right':
        if (name === 'interval') f.interval = L.nextInterval(f.interval, action === 'left' ? -1 : 1);
        else if (name === 'cancel' && action === 'left') f.focus = 3;
        else if (name === 'save' && action === 'right' && visibleFields() === FIELDS.length) f.focus = 4;
        break;
      case 'enter':
        if (name === 'url' || name === 'token') { beginEdit(name); return true; }
        if (name === 'save') { submitSettings(); return true; }
        if (name === 'cancel') { openGrid(state.grid.index); return true; }
        if (name === 'interval') f.interval = L.nextInterval(f.interval, 1);
        break;
      case 'back':
        if (f.returnTo && state.library) { openGrid(state.grid.index); return true; }
        exitApp();
        return true;
      default:
        return true;
    }
    renderForm();
    return true;
  }

  // ---------------------------------------------------------------- message screen

  function messageKey(action) {
    var m = state.message;
    if (!m.buttons.length) {
      if (action === 'back') exitApp();
      return;
    }
    if (action === 'left') m.focus = Math.max(0, m.focus - 1);
    else if (action === 'right') m.focus = Math.min(m.buttons.length - 1, m.focus + 1);
    else if (action === 'enter') return m.buttons[m.focus].run();
    else if (action === 'back') return exitApp();
    renderMessageFocus();
  }

  // ---------------------------------------------------------------- platform

  function registerKeys() {
    try {
      if (window.tizen && tizen.tvinputdevice) {
        for (var i = 0; i < L.TIZEN_REGISTERED_KEYS.length; i++) {
          try { tizen.tvinputdevice.registerKey(L.TIZEN_REGISTERED_KEYS[i]); } catch (e) { /* key absent on this model */ }
        }
      }
    } catch (e) { /* not on Tizen */ }
  }

  function setScreenSaver(enabled) {
    try {
      if (window.webapis && webapis.appcommon) {
        var S = webapis.appcommon.AppCommonScreenSaverState;
        webapis.appcommon.setScreenSaver(enabled ? S.SCREEN_SAVER_ON : S.SCREEN_SAVER_OFF);
      }
    } catch (e) { /* not on Tizen */ }
  }

  function exitApp() {
    try {
      if (window.tizen && tizen.application) {
        tizen.application.getCurrentApplication().exit();
      }
    } catch (e) { /* not on Tizen */ }
  }

  function onKeyDown(event) {
    var action = L.keyAction(event.keyCode);
    if (!action) return;
    var handled = true;
    switch (state.screen) {
      case 'grid': gridKey(action); break;
      case 'slideshow': slideshowKey(action); break;
      case 'settings': handled = settingsKey(action, event); break;
      case 'message': messageKey(action); break;
    }
    if (handled !== false) event.preventDefault();
  }

  function onResize() {
    if (state.screen === 'grid') {
      measureGrid();
      focusTile(state.grid.index);
    }
  }

  function onVisibility() {
    if (state.screen !== 'slideshow') return;
    if (document.hidden) clearTimeout(state.slide.timer);
    else schedule();
  }

  function init() {
    registerKeys();
    document.addEventListener('keydown', onKeyDown);
    window.addEventListener('resize', onResize);
    document.addEventListener('visibilitychange', onVisibility);
    $('grid-viewport').addEventListener('scroll', function () {
      if (state.screen === 'grid') loadVisibleThumbs();
    });
    loadLibrary();
  }

  window.SIVApp = { state: state, loadLibrary: loadLibrary };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
