'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const { createPlayerServer, assetURL, HEADERS, ENTRY } = require('../tools/serve_web_player.cjs');
const listen = server => new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve('http://127.0.0.1:' + server.address().port)));
const close = server => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); });
async function fixture(t, handler, extra = {}) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'player-cache-test-'));
  const archive = path.join(dir, 'game.mkxpz');
  await fs.writeFile(archive, 'local game');
  const upstream = http.createServer(handler);
  const origin = await listen(upstream);
  const options = { archive, cacheDir: path.join(dir, 'cache'), upstreamOrigin: origin, testOnlyAllowLocalhost: true, ...extra };
  const player = createPlayerServer(options);
  const base = await listen(player.server);
  t.after(async () => { await close(player.server); await close(upstream); await fs.rm(dir, { recursive: true, force: true }); });
  return { dir, archive, upstream, options, player, base };
}
function isolation(response) {
  for (const [name, value] of Object.entries(HEADERS)) assert.equal(response.headers.get(name), value);
}

test('deduplicates, persists MIME and complete assets, handles HEAD and conditional GET', async t => {
  let hits = 0;
  const f = await fixture(t, (_req, res) => {
    hits++;
    setTimeout(() => { res.writeHead(200, { 'Content-Type': 'application/wasm' }); res.end('wasm bytes'); }, 30);
  });
  const route = ENTRY + 'engine.wasm?v=1';
  const responses = await Promise.all(Array.from({ length: 6 }, () => fetch(f.base + route)));
  assert.equal(hits, 1);
  for (const response of responses) {
    assert.equal(await response.text(), 'wasm bytes');
    assert.equal(response.headers.get('content-length'), '10');
    assert.equal(response.headers.get('content-type'), 'application/wasm');
    assert.equal(response.headers.get('cache-control'), 'no-cache');
    isolation(response);
  }
  const etag = responses[0].headers.get('etag');
  const conditional = await fetch(f.base + route, { headers: { 'If-None-Match': '"other", ' + etag } });
  assert.equal(conditional.status, 304);
  assert.equal(await conditional.text(), '');
  isolation(conditional);
  const head = await fetch(f.base + route, { method: 'HEAD' });
  assert.equal(head.headers.get('content-length'), '10');
  assert.equal(await head.text(), '');
  assert.equal(hits, 1);
  const paths = f.player.assetPaths(route);
  const metadata = JSON.parse(await fs.readFile(paths.metadata));
  assert.equal(metadata.contentType, 'application/wasm');
  assert.equal(metadata.size, 10);
  assert.equal((await fs.readFile(f.player.manifestPath, 'utf8')).trim().split('\n').length, 1);
  // A new instance can serve persisted assets with the upstream offline.
  await close(f.upstream);
  const restarted = createPlayerServer(f.options);
  const base = await listen(restarted.server);
  t.after(() => close(restarted.server));
  const persisted = await fetch(base + route);
  assert.equal(await persisted.text(), 'wasm bytes');
  assert.equal(persisted.headers.get('etag'), etag);
  // A truncated/replaced file must not masquerade as the complete cached asset.
  // Frontend changes use the transform hook, tested separately below.
  await fs.writeFile(paths.file, 'partial');
  const changed = await fetch(base + route, { headers: { 'If-None-Match': etag } });
  assert.equal(changed.status, 502);
  assert.match(await changed.text(), /unavailable/);
});

test('local game never fetches upstream and changed game invalidates its stat tag', async t => {
  let hits = 0;
  const f = await fixture(t, (_req, res) => { hits++; res.end('remote'); });
  const route = ENTRY + 'knight-blade-howling-of-kerberos.mkxpz';
  const first = await fetch(f.base + route);
  assert.equal(await first.text(), 'local game');
  const etag = first.headers.get('etag');
  const unchanged = await fetch(f.base + route + '?fresh=1', { headers: { 'If-None-Match': etag } });
  assert.equal(unchanged.status, 304);
  isolation(unchanged);
  await fs.writeFile(f.archive, 'replacement game');
  const changed = await fetch(f.base + route, { headers: { 'If-None-Match': etag } });
  assert.equal(changed.status, 200);
  assert.equal(await changed.text(), 'replacement game');
  assert.notEqual(changed.headers.get('etag'), etag);
  assert.equal(hits, 0);
});

test('rejects unsafe URLs and methods without network access or directory exposure', async t => {
  let hits = 0;
  const f = await fixture(t, (_req, res) => { hits++; res.end('remote'); });
  for (const input of ['/etc/passwd', '//evil.example/a', '/mkxp-z-libretro-emscripten/../secret', '/mkxp-z-libretro-emscripten/%2e%2e/secret', '/mkxp-z-libretro-emscripten/a%2fb', '/mkxp-z-libretro-emscripten/%252e%252e/a', '/mkxp-z-libretro-emscripten/a\\b']) assert.throws(() => assetURL(input));
  const denied = await fetch(f.base + '/manifest.jsonl');
  assert.equal(denied.status, 404);
  isolation(denied);
  const post = await fetch(f.base + ENTRY, { method: 'POST', body: 'do not upload' });
  assert.equal(post.status, 405);
  isolation(post);
  assert.equal(hits, 0);
  assert.throws(() => createPlayerServer({ upstreamOrigin: 'https://example.com' }));
  assert.throws(() => createPlayerServer({ upstreamOrigin: 'http://127.0.0.1:1' }));
});

test('does not cache truncated, oversized, failed or off-origin redirected responses', async t => {
  const f = await fixture(t, (req, res) => {
    if (req.url.endsWith('truncated')) { res.writeHead(200, { 'Content-Length': '100' }); res.write('short'); setTimeout(() => res.destroy(), 5); }
    else if (req.url.endsWith('oversized')) res.end('longer than limit');
    else if (req.url.endsWith('redirect')) { res.writeHead(302, { Location: 'http://127.0.0.1:1/secret' }); res.end(); }
    else { res.writeHead(404); res.end('not found'); }
  }, { maxAssetBytes: 10 });
  for (const suffix of ['truncated', 'oversized', 'redirect', 'missing']) {
    const response = await fetch(f.base + ENTRY + suffix);
    assert.equal(response.status, 502);
    isolation(response);
    await response.text();
  }
  assert.deepEqual(await fs.readdir(f.player.cacheDir), []);
});

test('transform hook leaves disk pristine and validators track transformed frontend', async t => {
  let replacement = 'patched frontend';
  const f = await fixture(t, (_req, res) => { res.writeHead(200, { 'Content-Type': 'text/javascript' }); res.end('upstream frontend'); }, {
    transformAsset: ({ body, file }) => { assert.equal(body.toString(), 'upstream frontend'); assert.ok(file.endsWith('.asset')); return replacement; },
  });
  const route = ENTRY + 'app.js';
  const first = await fetch(f.base + route);
  assert.equal(await first.text(), replacement);
  assert.equal(await fs.readFile(f.player.assetPaths(route).file, 'utf8'), 'upstream frontend');
  const etag = first.headers.get('etag');
  const unchanged = await fetch(f.base + route, { headers: { 'If-None-Match': etag } });
  assert.equal(unchanged.status, 304);
  isolation(unchanged);
  replacement = 'new frontend';
  const changed = await fetch(f.base + route, { headers: { 'If-None-Match': etag } });
  assert.equal(changed.status, 200);
  assert.equal(await changed.text(), replacement);
  assert.notEqual(changed.headers.get('etag'), etag);
});
