// Static file server for the wasm build, no dependencies: `npm start` (PORT, default 8080).
const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = __dirname;
const PORT = process.env.PORT || 8080;
const PUBLIC = new Set(['index.html', 'wasm', 'assets']); // all the browser may read
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.wgsl': 'text/plain; charset=utf-8',
  '.ron': 'text/plain; charset=utf-8',
};
// gzip these; images are compressed already
const GZIP = new Set(['.html', '.js', '.json', '.wasm', '.wgsl', '.ron', '.data', '.map', '.txt']);
const gzipCache = new Map(); // file path -> { etag, buf }, built on first request

function send(res, status, headers, body) {
  res.writeHead(status, headers);
  res.end(body);
}

async function gzipped(file, stat) {
  const etag = `"${stat.size}-${stat.mtimeMs}"`;
  const hit = gzipCache.get(file);
  if (hit && hit.etag === etag) return hit.buf;
  const buf = await new Promise((ok, fail) =>
    zlib.gzip(fs.readFileSync(file), { level: 6 }, (e, b) => (e ? fail(e) : ok(b))));
  gzipCache.set(file, { etag, buf });
  return buf;
}

http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    const file = path.join(ROOT, path.normalize(rel));
    const top = path.relative(ROOT, file).split(path.sep)[0];
    if (!file.startsWith(ROOT + path.sep) || !PUBLIC.has(top)) return send(res, 403, {}, 'forbidden');
    const stat = fs.statSync(file, { throwIfNoEntry: false });
    if (!stat || !stat.isFile()) return send(res, 404, { 'Content-Type': 'text/plain' }, 'not found');

    const ext = path.extname(file).toLowerCase();
    const etag = `"${stat.size}-${stat.mtimeMs}"`;
    const headers = {
      'Content-Type': TYPES[ext] || 'application/octet-stream',
      ETag: etag,
      'Cache-Control': 'no-cache',
      // the page reads this for the progress bar: Content-Length is the gzipped size
      'X-Uncompressed-Length': String(stat.size),
      'Access-Control-Expose-Headers': 'X-Uncompressed-Length',
    };
    if (req.headers['if-none-match'] === etag) return send(res, 304, headers);

    const gzip = GZIP.has(ext) && /\bgzip\b/.test(req.headers['accept-encoding'] || '');
    if (gzip) {
      const buf = await gzipped(file, stat);
      headers['Content-Encoding'] = 'gzip';
      headers['Content-Length'] = buf.length;
      headers.Vary = 'Accept-Encoding';
      return send(res, 200, headers, req.method === 'HEAD' ? undefined : buf);
    }
    headers['Content-Length'] = stat.size;
    res.writeHead(200, headers);
    if (req.method === 'HEAD') return res.end();
    fs.createReadStream(file).pipe(res);
  } catch (e) {
    send(res, 500, { 'Content-Type': 'text/plain' }, String(e));
  }
}).listen(PORT, () => console.log(`Castle Sim on http://localhost:${PORT}`));
