'use strict';
// Run: node --test tv/test
const test = require('node:test');
const assert = require('node:assert/strict');
const L = require('../js/lib.js');

test('normalizeBaseUrl accepts what users type on a TV', () => {
  assert.equal(L.normalizeBaseUrl('192.168.1.50'), 'http://192.168.1.50:8080');
  assert.equal(L.normalizeBaseUrl(' 192.168.1.50:9000 '), 'http://192.168.1.50:9000');
  assert.equal(L.normalizeBaseUrl('http://192.168.1.50:8080/'), 'http://192.168.1.50:8080');
  assert.equal(L.normalizeBaseUrl('HTTP://NAS.local/photos/lib//'), 'http://nas.local/photos/lib');
  assert.equal(L.normalizeBaseUrl('https://cdn.example.com/lib'), 'https://cdn.example.com/lib');
  assert.equal(L.normalizeBaseUrl('192.168.1. 50'), 'http://192.168.1.50:8080');
});

test('normalizeBaseUrl rejects invalid input', () => {
  for (const bad of ['', '   ', null, undefined, 42, 'ftp://x', 'javascript:alert(1)', 'http://',
    'http://host:0', 'http://host:70000', 'http://user@host', 'http://host/a?b=1', 'http://host/#x',
    'http://host/../x', 'http://.host', 'http://host./', 'http://ho_st']) {
    assert.equal(L.normalizeBaseUrl(bad), null, String(bad));
  }
});

test('isSafeRelativePath only allows plain relative paths', () => {
  assert.ok(L.isSafeRelativePath('thumbs/abc.jpg'));
  assert.ok(L.isSafeRelativePath('full/a%20b.jpg'));
  for (const bad of ['', null, '/abs.jpg', '../x.jpg', 'a/../b.jpg', './a.jpg', 'a//b.jpg', 'http://evil/x.jpg',
    'javascript:alert(1)', 'data:image/png;base64,xx', '//evil/x.jpg', 'a\\b.jpg', '.hidden.jpg', 'a/%2e%2e/b.jpg',
    'a%2fb.jpg', 'a.jpg?x=1', 'a.jpg#f', '%E0%A4%A.jpg']) {
    assert.equal(L.isSafeRelativePath(bad), false, String(bad));
  }
});

test('resolveUrl joins base and path and appends token', () => {
  assert.equal(L.resolveUrl('http://h:8080', 'thumbs/a.jpg', ''), 'http://h:8080/thumbs/a.jpg');
  assert.equal(L.resolveUrl('http://h:8080/lib', 'thumbs/a.jpg', 't k&'), 'http://h:8080/lib/thumbs/a.jpg?token=t%20k%26');
  assert.equal(L.resolveUrl('http://h', '../etc/passwd', ''), null);
  assert.equal(L.withToken('http://h/x?a=1', 'z'), 'http://h/x?a=1&token=z');
  assert.equal(L.withToken('http://h/x', ''), 'http://h/x');
});

const photo = (id, extra) => Object.assign({
  id, title: id + '.jpg', takenAt: '2024-06-01T15:22:00Z', thumb: 'thumbs/' + id + '.jpg', full: 'full/' + id + '.jpg', width: 400, height: 300
}, extra);

test('validateIndex parses a SIV index', () => {
  const lib = L.validateIndex({
    version: 1, generatedAt: '2026-08-11T20:00:00Z', albumName: 'Holiday',
    photos: [photo('a'), photo('b', { takenAt: null, title: 5 })]
  });
  assert.equal(lib.albumName, 'Holiday');
  assert.equal(lib.photos.length, 2);
  assert.equal(lib.skipped, 0);
  assert.equal(lib.photos[0].takenAt.toISOString(), '2024-06-01T15:22:00.000Z');
  assert.equal(lib.photos[1].takenAt, null);
  assert.equal(lib.photos[1].title, '');
  assert.equal(lib.generatedAt.toISOString(), '2026-08-11T20:00:00.000Z');
});

test('validateIndex drops bad photos but keeps the rest', () => {
  const lib = L.validateIndex({
    version: 1,
    photos: [
      photo('ok'),
      photo('ok'),
      null,
      'str',
      photo('', {}),
      photo('abs', { full: '/etc/passwd' }),
      photo('remote', { thumb: 'http://evil/x.jpg' }),
      photo('trav', { thumb: '../x.jpg' }),
      photo('w0', { width: 0 }),
      photo('hf', { height: 1.5 }),
      photo('hs', { height: '300' }),
      photo('ok2')
    ]
  });
  assert.deepEqual(lib.photos.map(p => p.id), ['ok', 'ok2']);
  assert.equal(lib.skipped, 10);
  assert.equal(lib.albumName, 'Photos');
});

test('validateIndex rejects unusable documents', () => {
  assert.throws(() => L.validateIndex(null), /not an object/);
  assert.throws(() => L.validateIndex([]), /not an object/);
  assert.throws(() => L.validateIndex({ version: 2, photos: [] }), /Unsupported library version 2/);
  assert.throws(() => L.validateIndex({ version: 1 }), /no photos list/);
  assert.throws(() => L.validateIndex({ version: 1, photos: {} }), /no photos list/);
});

test('gridMove in a 5-column grid of 12', () => {
  const n = 12, c = 5;
  assert.equal(L.gridMove(0, 'left', n, c), 0);
  assert.equal(L.gridMove(4, 'right', n, c), 5);
  assert.equal(L.gridMove(11, 'right', n, c), 11);
  assert.equal(L.gridMove(2, 'up', n, c), -1);
  assert.equal(L.gridMove(7, 'up', n, c), 2);
  assert.equal(L.gridMove(2, 'down', n, c), 7);
  assert.equal(L.gridMove(8, 'down', n, c), 11, 'partial last row');
  assert.equal(L.gridMove(11, 'down', n, c), 11, 'already on last row');
  assert.equal(L.gridMove(10, 'down', n, c), 10);
  assert.equal(L.gridMove(99, 'left', n, c), 10, 'clamps out-of-range index');
  assert.equal(L.gridMove(3, 'enter', n, c), 3);
  assert.equal(L.gridMove(0, 'down', 0, c), -1);
  assert.equal(L.gridMove(0, 'down', 1, 0), 0);
});

test('rowsToLoad and scrollForRow', () => {
  assert.deepEqual(L.rowsToLoad(0, 850, 264, 10, 2), { first: 0, last: 6 });
  assert.deepEqual(L.rowsToLoad(1056, 850, 264, 10, 2), { first: 2, last: 9 });
  assert.deepEqual(L.rowsToLoad(0, 850, 264, 0, 2), { first: 0, last: -1 });
  assert.equal(L.scrollForRow(0, 0, 850, 264, 24), 0);
  assert.equal(L.scrollForRow(3, 0, 850, 264, 24), 4 * 264 + 24 - 850);
  assert.equal(L.scrollForRow(1, 0, 850, 264, 24), 0, 'already visible');
  assert.equal(L.scrollForRow(1, 600, 850, 264, 24), 240);
});

test('wrapIndex and nextInterval', () => {
  assert.equal(L.wrapIndex(-1, 5), 4);
  assert.equal(L.wrapIndex(5, 5), 0);
  assert.equal(L.wrapIndex(12, 5), 2);
  assert.equal(L.wrapIndex(3, 0), 0);
  assert.equal(L.nextInterval(5, 1), 8);
  assert.equal(L.nextInterval(3, -1), 3);
  assert.equal(L.nextInterval(30, 1), 30);
  assert.equal(L.nextInterval(7, 1), 8, 'unknown value restarts from default');
});

test('formatDate', () => {
  assert.equal(L.formatDate(new Date(2024, 5, 1)), '1 Jun 2024');
  assert.equal(L.formatDate(null), '');
  assert.equal(L.formatDate(new Date('bad')), '');
});

test('keyAction maps Tizen remote keys', () => {
  assert.equal(L.keyAction(37), 'left');
  assert.equal(L.keyAction(13), 'enter');
  assert.equal(L.keyAction(10009), 'back');
  assert.equal(L.keyAction(10252), 'playpause');
  assert.equal(L.keyAction(406), 'blue');
  assert.equal(L.keyAction(65376), 'imedone');
  assert.equal(L.keyAction(65), null);
});
