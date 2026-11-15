// End-to-end test of the TV app in headless Chrome at 1920×1080, driven with remote-control keys.
//
//   node tv/test/e2e.mjs --app http://127.0.0.1:8000 --server http://192.168.1.50:8080 [--token T] [--shots DIR]
//
// Needs: the TV app served at --app (make tv-preview) and a published library at --server
// (SIV → Publish to TV, or `SIV tv-serve`) with at least 13 photos.

import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, a) => {
  if (v.startsWith('--')) acc.push([v.slice(2), a[i + 1]]);
  return acc;
}, []));
const APP = args.app || 'http://127.0.0.1:8000';
const SERVER = args.server;
const TOKEN = args.token || '';
const SHOTS = args.shots || '';
const CHROME = args.chrome || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PORT = 9300 + Math.floor(Math.random() * 500);
if (!SERVER) {
  console.error('usage: node tv/test/e2e.mjs --app URL --server URL [--token T] [--shots DIR]');
  process.exit(2);
}

const KEYS = {
  Left: [37, 'ArrowLeft'], Right: [39, 'ArrowRight'], Up: [38, 'ArrowUp'], Down: [40, 'ArrowDown'],
  Enter: [13, 'Enter'], Back: [10009, 'XF86Back'], Esc: [27, 'Escape'], PlayPause: [10252, 'MediaPlayPause']
};

const sleep = ms => new Promise(r => setTimeout(r, ms));
const profile = mkdtempSync(join(tmpdir(), 'sivtv-chrome-'));
const chrome = spawn(CHROME, [
  '--headless=new', `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`,
  '--window-size=1920,1080', '--no-first-run', '--no-default-browser-check', 'about:blank'
], { stdio: 'ignore' });

let ws;
let nextId = 1;
const pending = new Map();
const exceptions = [];

function cdp(method, params = {}) {
  const id = nextId++;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject, method }));
}

async function connect() {
  for (let i = 0; i < 50; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
      const page = list.find(t => t.type === 'page');
      if (page) {
        ws = new WebSocket(page.webSocketDebuggerUrl);
        await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
        ws.onmessage = ev => {
          const msg = JSON.parse(ev.data);
          if (msg.id && pending.has(msg.id)) {
            const p = pending.get(msg.id);
            pending.delete(msg.id);
            msg.error ? p.reject(new Error(p.method + ': ' + msg.error.message)) : p.resolve(msg.result);
          } else if (msg.method === 'Runtime.exceptionThrown') {
            exceptions.push(msg.params.exceptionDetails.exception?.description || msg.params.exceptionDetails.text);
          }
        };
        return;
      }
    } catch { /* not up yet */ }
    await sleep(200);
  }
  throw new Error('Chrome DevTools did not start');
}

async function evaluate(expr) {
  const r = await cdp('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error('eval failed: ' + expr + ' → ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text));
  return r.result.value;
}

async function waitFor(expr, label, timeout = 10000) {
  const start = Date.now();
  let last;
  while (Date.now() - start < timeout) {
    last = await evaluate(expr).catch(e => e.message);
    if (last === true) return;
    await sleep(100);
  }
  throw new Error(`timeout waiting for ${label} (last: ${JSON.stringify(last)})`);
}

async function press(name, times = 1) {
  const [code, key] = KEYS[name];
  for (let i = 0; i < times; i++) {
    await cdp('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key, code: key });
    await cdp('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, key, code: key });
    await sleep(60);
  }
}

async function typeText(text) {
  await cdp('Input.insertText', { text });
}

async function shot(name) {
  if (!SHOTS) return;
  mkdirSync(SHOTS, { recursive: true });
  const { data } = await cdp('Page.captureScreenshot', { format: 'png' });
  writeFileSync(join(SHOTS, name + '.png'), Buffer.from(data, 'base64'));
}

const screen = () => evaluate('window.SIVApp && window.SIVApp.state.screen');
const st = path => evaluate('window.SIVApp.state.' + path);

async function openFresh() {
  await cdp('Page.navigate', { url: APP + '/index.html' });
  await waitFor('document.readyState === "complete" && !!window.SIVApp', 'app loaded');
}

async function fillSettings(url, token, intervalSteps) {
  await waitFor('SIVApp.state.screen === "settings"', 'settings screen');
  await evaluate('document.getElementById("set-url").value = ""; document.getElementById("set-token").value = ""; true');
  // focus starts on the address field
  await press('Enter');
  assert.equal(await st('form.editing'), 'url');
  await typeText(url);
  await press('Enter');
  assert.equal(await st('form.editing'), null);
  await press('Down');
  if (token) {
    await press('Enter');
    await typeText(token);
    await press('Enter');
  }
  await press('Down');
  if (intervalSteps < 0) await press('Left', -intervalSteps);
  if (intervalSteps > 0) await press('Right', intervalSteps);
  await press('Down');
  assert.equal(await st('form.focus'), 3, 'focus on Save');
  await press('Enter');
}

const results = [];
async function step(name, fn) {
  try {
    await fn();
    results.push(['ok', name]);
    console.log('  ok    ' + name);
  } catch (e) {
    results.push(['FAIL', name]);
    console.log('  FAIL  ' + name + '\n        ' + e.message);
    await shot('FAIL-' + name.replace(/\W+/g, '-'));
  }
}

const serverHostPort = SERVER.replace(/^https?:\/\//, '').replace(/\/$/, '');

try {
  await connect();
  await cdp('Page.enable');
  await cdp('Runtime.enable');
  await cdp('Emulation.setDeviceMetricsOverride', { width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false });
  await openFresh();
  await evaluate('localStorage.clear(); true');
  await openFresh();
  console.log(`SIV TV e2e: app=${APP} server=${SERVER}`);

  await step('first launch opens Settings', async () => {
    assert.equal(await screen(), 'settings');
    assert.equal(await evaluate('getComputedStyle(document.getElementById("field-cancel")).display'), 'none');
    await shot('01-settings');
  });

  await step('invalid address is rejected in Settings', async () => {
    await fillSettings('http://bad host:99999', '', 0);
    assert.equal(await screen(), 'settings');
    assert.match(await evaluate('document.getElementById("settings-error").textContent'), /Not a valid address/);
  });

  await step('wrong token shows Access denied with Retry/Settings', async () => {
    await press('Up', 5);
    await fillSettings(serverHostPort, TOKEN ? 'wrong-token' : '', -1);
    if (!TOKEN) return;
    await waitFor('SIVApp.state.screen === "message" && SIVApp.state.message.buttons.length === 2', 'error message');
    assert.equal(await evaluate('document.getElementById("message-text").textContent'), 'Access denied');
    await shot('02-access-denied');
    await press('Right');
    await press('Enter');
  });

  await step('valid settings connect and show the grid', async () => {
    if (TOKEN || (await screen()) !== 'grid') {
      await fillSettings(serverHostPort, TOKEN, -1);
    }
    await waitFor('SIVApp.state.screen === "grid"', 'grid', 15000);
    const n = await evaluate('document.querySelectorAll("#grid .tile").length');
    assert.ok(n >= 13, 'need at least 13 photos, got ' + n);
    assert.match(await evaluate('document.getElementById("photo-count").textContent'), new RegExp('^' + n + ' photos'));
    assert.equal(await evaluate('localStorage.getItem("siv.interval")'), '3');
    assert.equal(await evaluate('localStorage.getItem("siv.serverUrl")'), 'http://' + (serverHostPort.includes(':') ? serverHostPort : serverHostPort + ':8080'));
  });

  await step('thumbnails load lazily for visible rows only', async () => {
    await waitFor('Array.prototype.every.call(document.querySelectorAll("#grid img[src]"), i => i.complete)', 'thumbs complete', 15000);
    const loaded = await evaluate('Array.prototype.filter.call(document.querySelectorAll("#grid img[src]"), i => i.naturalWidth > 0).length');
    const withSrc = await evaluate('document.querySelectorAll("#grid img[src]").length');
    const total = await evaluate('document.querySelectorAll("#grid .tile").length');
    const cols = await st('grid.cols');
    assert.equal(loaded, withSrc, 'every requested thumbnail decoded');
    assert.ok(cols >= 4, 'expected ≥4 columns at 1920px, got ' + cols);
    if (total > cols * 7) assert.ok(withSrc < total, `lazy loading: ${withSrc} of ${total} requested`);
    await shot('03-grid');
  });

  await step('arrow keys move focus through the grid and scroll', async () => {
    const cols = await st('grid.cols');
    const total = await evaluate('document.querySelectorAll("#grid .tile").length');
    assert.equal(await st('grid.index'), 0);
    await press('Right', 2);
    assert.equal(await st('grid.index'), 2);
    await press('Down');
    assert.equal(await st('grid.index'), 2 + cols);
    await press('Left');
    assert.equal(await st('grid.index'), 1 + cols);
    assert.equal(await evaluate('document.querySelectorAll("#grid .tile.focused").length'), 1);
    await press('Down', Math.ceil(total / cols) + 2);
    const last = await st('grid.index');
    assert.ok(last >= total - cols, 'reached last row, index ' + last);
    assert.ok(await evaluate('document.getElementById("grid-viewport").scrollTop') > 0, 'viewport scrolled');
    const focusedVisible = await evaluate(`(() => {
      const t = document.querySelector('#grid .tile.focused').getBoundingClientRect();
      const v = document.getElementById('grid-viewport').getBoundingClientRect();
      return t.top >= v.top - 20 && t.bottom <= v.bottom + 20;
    })()`);
    assert.ok(focusedVisible, 'focused tile is on screen');
    assert.equal(await evaluate('document.querySelector("#grid .tile.focused img").getAttribute("src") !== null'), true);
    await shot('04-grid-scrolled');
  });

  await step('Up from the first row reaches the toolbar and Down returns', async () => {
    await press('Up', 30);
    assert.equal(await st('grid.toolbarIndex'), 0);
    assert.equal(await evaluate('document.querySelectorAll("#toolbar .button.focused").length'), 1);
    assert.equal(await evaluate('document.querySelectorAll("#grid .tile.focused").length'), 0);
    await press('Right', 5);
    assert.equal(await st('grid.toolbarIndex'), 2);
    await shot('05-toolbar');
    await press('Down');
    assert.equal(await st('grid.toolbarIndex'), -1);
    assert.equal(await evaluate('document.querySelectorAll("#grid .tile.focused").length'), 1);
  });

  await step('OK opens the focused photo full screen (paused)', async () => {
    await press('Right', 3);
    const idx = await st('grid.index');
    await press('Enter');
    assert.equal(await screen(), 'slideshow');
    await waitFor('document.querySelector(".slide.visible") && document.querySelector(".slide.visible").naturalWidth > 0', 'slide visible', 15000);
    const id = await evaluate(`SIVApp.state.library.photos[${idx}].id`);
    assert.ok((await evaluate('document.querySelector(".slide.visible").getAttribute("src")')).includes('full/' + id + '.jpg'));
    assert.equal(await st('slide.playing'), false);
    assert.match(await evaluate('document.getElementById("slide-pos").textContent'), new RegExp('^' + (idx + 1) + ' / '));
    const fit = await evaluate('getComputedStyle(document.querySelector(".slide.visible")).objectFit');
    assert.equal(fit, 'contain');
    await shot('06-photo');
  });

  await step('Left/Right step photos with wraparound', async () => {
    const start = await st('slide.index');
    const n = await evaluate('SIVApp.state.library.photos.length');
    await press('Right');
    assert.equal(await st('slide.index'), (start + 1) % n);
    await press('Left', 2);
    assert.equal(await st('slide.index'), (start - 1 + n) % n);
    await press('Right');
    await waitFor('document.querySelector(".slide.visible") && document.querySelector(".slide.visible").naturalWidth > 0', 'slide', 15000);
    await evaluate('SIVApp.state.slide.index = 0; true');
    await press('Left');
    assert.equal(await st('slide.index'), n - 1, 'wraps from first to last');
  });

  await step('OK starts the slideshow and it auto-advances', async () => {
    await waitFor('document.querySelector(".slide.visible").naturalWidth > 0', 'slide', 15000);
    await press('Enter');
    assert.equal(await st('slide.playing'), true);
    assert.match(await evaluate('document.getElementById("slide-state").textContent'), /3s/);
    const before = await st('slide.index');
    await waitFor(`SIVApp.state.slide.index !== ${before}`, 'auto-advance', 8000);
    await shot('07-slideshow-overlay');
    await press('PlayPause');
    assert.equal(await st('slide.playing'), false);
    const paused = await st('slide.index');
    await sleep(3800);
    assert.equal(await st('slide.index'), paused, 'paused slideshow stays put');
  });

  await step('Back returns to the grid focused on the current photo', async () => {
    const idx = await st('slide.index');
    await press('Back');
    assert.equal(await screen(), 'grid');
    assert.equal(await st('grid.index'), idx);
    assert.equal(await evaluate(`document.querySelectorAll("#grid .tile")[${idx}].className.indexOf("focused") !== -1`), true);
    const timerIdx = await st('slide.index');
    await sleep(3500);
    assert.equal(await st('slide.index'), timerIdx, 'slideshow timer stopped after leaving');
  });

  await step('Play on the grid starts slideshow from focused photo', async () => {
    const idx = await st('grid.index');
    await press('PlayPause');
    assert.equal(await screen(), 'slideshow');
    assert.equal(await st('slide.playing'), true);
    assert.equal(await st('slide.index'), idx);
    await press('Esc');
    assert.equal(await screen(), 'grid');
  });

  await step('toolbar Settings opens with Cancel and Back returns', async () => {
    await press('Up', 30);
    await press('Right', 5);
    await press('Enter');
    assert.equal(await screen(), 'settings');
    assert.notEqual(await evaluate('getComputedStyle(document.getElementById("field-cancel")).display'), 'none');
    assert.equal(await evaluate('document.getElementById("set-url").value'), await evaluate('localStorage.getItem("siv.serverUrl")'));
    await press('Back');
    assert.equal(await screen(), 'grid');
  });

  await step('settings persist across app restarts', async () => {
    await openFresh();
    await waitFor('SIVApp.state.screen === "grid"', 'grid after restart', 15000);
  });

  await step('unreachable server shows a helpful error', async () => {
    await evaluate('localStorage.setItem("siv.serverUrl", "http://127.0.0.1:1"); true');
    await openFresh();
    await waitFor('SIVApp.state.screen === "message" && SIVApp.state.message.buttons.length === 2', 'error', 20000);
    assert.equal(await evaluate('document.getElementById("message-text").textContent'), 'Cannot reach the photo server');
    await shot('08-unreachable');
    await press('Right');
    await press('Enter');
    assert.equal(await screen(), 'settings');
  });

  await step('no uncaught JavaScript exceptions', async () => {
    assert.deepEqual(exceptions, []);
  });
} catch (e) {
  results.push(['FAIL', 'harness']);
  console.log('  FAIL  harness: ' + e.stack);
} finally {
  try { ws && ws.close(); } catch { /* closed */ }
  chrome.kill('SIGKILL');
  await sleep(300);
  rmSync(profile, { recursive: true, force: true });
}

const failed = results.filter(r => r[0] === 'FAIL').length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
