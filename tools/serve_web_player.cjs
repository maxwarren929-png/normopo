#!/usr/bin/env node
// Loopback-only experimental player. Never uploads the local game archive.
'use strict';
const fs = require('node:fs');
const fsp = fs.promises;
const http = require('node:http');
const path = require('node:path');
const crypto = require('node:crypto');
const { Readable, Transform } = require('node:stream');
const { pipeline } = require('node:stream/promises');
const ENTRY = '/mkxp-z-libretro-emscripten/nostalgist-knight-blade-howling-of-kerberos/';
const PREFIX = '/mkxp-z-libretro-emscripten/';
const HEADERS = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Resource-Policy': 'cross-origin',
  'Access-Control-Allow-Origin': '*',
};

function assetURL(input, origin = 'https://white-axe.github.io') {
  if (typeof input !== 'string' || !input.startsWith('/') || input.startsWith('//') || /[\\#\s\x00-\x1f]/.test(input)) throw new Error('Invalid asset URL');
  const pathname = input.split('?')[0];
  const decoded = decodeURIComponent(pathname);
  if (!decoded.startsWith(PREFIX) || /[\\\x00-\x1f]/.test(decoded) || decoded.split('/').some(s => s === '.' || s === '..') || /%2f|%5c|%25/i.test(pathname)) throw new Error('Invalid asset path');
  const url = new URL(input, origin);
  if (url.origin !== origin || !url.pathname.startsWith(PREFIX)) throw new Error('Invalid asset origin');
  return url;
}

function createPlayerServer(options = {}) {
  const archive = path.resolve(options.archive || process.env.WEB_ARCHIVE || 'normanhurst/build/web-player-review/pokemon-normanhurst-buffered-deferred-no-cache.mkxpz');
  const cacheDir = path.resolve(options.cacheDir || process.env.WEB_ASSET_CACHE || 'normanhurst/build/web-player-review/player-assets');
  const origin = new URL(options.upstreamOrigin || 'https://white-axe.github.io').origin;
  if (origin !== 'https://white-axe.github.io' && !(options.testOnlyAllowLocalhost === true && /^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(origin))) throw new Error('Upstream must be white-axe.github.io');
  const maxAssetBytes = options.maxAssetBytes || 256 * 1024 * 1024;
  const inFlight = new Map();
  const logged = new Set();
  const manifestPath = path.join(cacheDir, 'manifest.jsonl');
  const assetPaths = input => {
    const url = assetURL(input, origin).href;
    const key = crypto.createHash('sha256').update(url).digest('hex');
    return { url, file: path.join(cacheDir, key + '.asset'), metadata: path.join(cacheDir, key + '.json') };
  };
  async function atomicJSON(file, value) {
    const temporary = file + '.' + crypto.randomUUID() + '.tmp';
    try {
      await fsp.writeFile(temporary, JSON.stringify(value) + '\n', { flag: 'wx' });
      await fsp.rename(temporary, file);
    } finally { await fsp.rm(temporary, { force: true }); }
  }
  async function getCached(paths) {
    try {
      const metadata = JSON.parse(await fsp.readFile(paths.metadata, 'utf8'));
      const stat = await fsp.stat(paths.file);
      if (metadata.url === paths.url && typeof metadata.contentType === 'string' && !/[\r\n]/.test(metadata.contentType) && stat.isFile() && stat.size === metadata.size) return { ...paths, ...metadata };
    } catch (e) { if (!['ENOENT', 'SyntaxError'].includes(e.code || e.name)) throw e; }
    return null;
  }
  async function download(paths) {
    await fsp.mkdir(cacheDir, { recursive: true });
    const existing = await getCached(paths);
    if (existing) return existing;
    let url = new URL(paths.url), response;
    for (let redirects = 0; redirects <= 5; redirects++) {
      response = await fetch(url, { redirect: 'manual', signal: AbortSignal.timeout(120000) });
      if (![301, 302, 303, 307, 308].includes(response.status)) break;
      await response.body?.cancel();
      const next = new URL(response.headers.get('location'), url);
      if (next.origin !== origin) throw new Error('Unsafe upstream redirect');
      url = assetURL(next.pathname + next.search, origin);
      if (redirects === 5) throw new Error('Too many upstream redirects');
    }
    if (response.status !== 200 || !response.body) {
      await response.body?.cancel();
      throw new Error('Upstream asset returned ' + response.status);
    }
    const temporary = paths.file + '.' + crypto.randomUUID() + '.tmp';
    let size = 0;
    const hash = crypto.createHash('sha256');
    const meter = new Transform({ transform(chunk, encoding, done) {
      size += chunk.length;
      if (size > maxAssetBytes) return done(new Error('Upstream asset exceeds size limit'));
      hash.update(chunk);
      done(null, chunk);
    } });
    try {
      await pipeline(Readable.fromWeb(response.body), meter, fs.createWriteStream(temporary, { flags: 'wx' }));
      const expected = response.headers.get('content-length');
      if (!response.headers.get('content-encoding') && expected !== null && Number(expected) !== size) throw new Error('Incomplete upstream asset');
      const metadata = { url: paths.url, contentType: response.headers.get('content-type') || 'application/octet-stream', size, sha256: hash.digest('hex'), fetchedAt: new Date().toISOString() };
      await fsp.rename(temporary, paths.file);
      await atomicJSON(paths.metadata, metadata);
      return { ...paths, ...metadata };
    } finally { await fsp.rm(temporary, { force: true }); }
  }
  async function cacheAsset(input) {
    const paths = assetPaths(input);
    if (!inFlight.has(paths.url)) inFlight.set(paths.url, download(paths).finally(() => inFlight.delete(paths.url)));
    const asset = await inFlight.get(paths.url);
    if (!logged.has(paths.url)) {
      logged.add(paths.url);
      try { await fsp.appendFile(manifestPath, JSON.stringify({ url: paths.url, file: paths.file, contentType: asset.contentType }) + '\n'); }
      catch (e) { logged.delete(paths.url); throw e; }
    }
    return asset;
  }
  function notModified(req, etag) {
    return req.headers['if-none-match']?.split(',').some(tag => tag.trim() === '*' || tag.trim().replace(/^W\//, '') === etag.replace(/^W\//, ''));
  }
  async function serveFile(req, res, file, contentType, asset) {
    const handle = await fsp.open(file, 'r');
    try {
      const stat = await handle.stat({ bigint: true });
      let body;
      let etag = `W/"${stat.ino}-${stat.size}-${stat.mtimeNs}-${stat.ctimeNs}"`;
      // Transform only frontend text, never engine binaries or the local archive.
      // The disk cache stays pristine; the transformed response gets its own ETag.
      if (asset && options.transformAsset && /(?:javascript|text\/html|text\/css)/i.test(contentType)) {
        body = await handle.readFile();
        const transformed = await options.transformAsset({ url: asset.url, file: asset.file, body, contentType });
        if (transformed != null) body = Buffer.isBuffer(transformed) ? transformed : Buffer.from(transformed);
        etag = '"' + crypto.createHash('sha256').update(body).digest('hex') + '"';
      }
      const headers = { ...HEADERS, 'Content-Type': contentType, 'Cache-Control': 'no-cache', ETag: etag, 'Last-Modified': new Date(Number(stat.mtimeMs)).toUTCString() };
      if (notModified(req, etag)) { res.writeHead(304, headers); res.end(); return; }
      res.writeHead(200, { ...headers, 'Content-Length': body ? body.length : stat.size.toString() });
      if (req.method === 'HEAD') { res.end(); return; }
      if (body) { res.end(body); return; }
      await pipeline(handle.createReadStream({ autoClose: false }), res);
    } finally { await handle.close(); }
  }
  const server = http.createServer(async (req, res) => {
    try {
      if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405, { ...HEADERS, Allow: 'GET, HEAD', 'Cache-Control': 'no-store' }); res.end(); return; }
      if (req.url === '/' || req.url === '/?') { res.writeHead(302, { ...HEADERS, Location: ENTRY, 'Cache-Control': 'no-cache' }); res.end(); return; }
      let url;
      try { url = assetURL(req.url, origin); }
      catch { res.writeHead(404, { ...HEADERS, 'Cache-Control': 'no-store' }); res.end(); return; }
      if (decodeURIComponent(url.pathname).endsWith('/knight-blade-howling-of-kerberos.mkxpz')) {
        await serveFile(req, res, archive, 'application/octet-stream');
      } else {
        const asset = await cacheAsset(url.pathname + url.search);
        await serveFile(req, res, asset.file, asset.contentType, asset);
      }
    } catch (e) {
      console.error(req.url, e.message);
      if (res.headersSent) { res.destroy(e); return; }
      res.writeHead(502, { ...HEADERS, 'Cache-Control': 'no-store' });
      res.end('Player asset unavailable. Try reloading.');
    }
  });
  return { server, cacheAsset, assetPaths, cacheDir, manifestPath, archive };
}

async function main() {
  const archive = path.resolve(process.env.WEB_ARCHIVE || 'normanhurst/build/web-player-review/pokemon-normanhurst-buffered-deferred-no-cache.mkxpz');
  const { createFrontendTransform } = require('./web_player_frontend.cjs');
  const player = createPlayerServer({ archive, transformAsset: createFrontendTransform(archive) });
  if (process.argv[2] === '--prefetch') {
    for (const input of process.argv.slice(3)) {
      const asset = await player.cacheAsset(input);
      console.log(asset.url + ' -> ' + asset.file);
    }
    return;
  }
  if (!fs.existsSync(player.archive)) throw new Error('Missing game archive: ' + player.archive);
  const port = Number(process.env.WEB_PORT || 8123);
  player.server.on('error', e => { console.error(e.message); process.exitCode = 1; });
  player.server.listen(port, '127.0.0.1', () => {
    console.log('Player ready: http://localhost:' + port + '/');
    console.log('Local archive: ' + player.archive);
    console.log('Controls: Enter confirm, X/Escape cancel, Z menu, arrows move.');
    console.log('Runtime asset cache: ' + player.cacheDir + '. Game files stay on this machine.');
  });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => { player.server.closeAllConnections(); player.server.close(() => process.exit(0)); });
}
module.exports = { createPlayerServer, assetURL, ENTRY, HEADERS };
if (require.main === module) main().catch(e => { console.error(e.message); process.exitCode = 1; });
