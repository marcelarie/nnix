import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createLocalAdapter } from './src/backend/localAdapter.js';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const DIST = join(__dirname, 'dist');
const PORT = parseInt(process.env.PORT || '8910', 10);
const adapter = createLocalAdapter();

const MIME: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ico': 'image/x-icon',
  '.webmanifest': 'application/manifest+json',
};

createServer(async (req, res) => {
  const url = new URL(req.url || '', 'http://localhost');

  // API -> worker (youtubei.js)
  if (url.pathname.startsWith('/api/')) return adapter(req, res);

  // Static SPA + PWA
  const p = url.pathname === '/' ? '/index.html' : url.pathname;
  const file = join(DIST, p);

  if (!existsSync(file)) {
    // extensionless miss = client-side route (/s/:id, etc.) -> SPA fallback
    if (extname(p) === '') {
      try {
        const idx = await readFile(join(DIST, 'index.html'));
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        return res.end(idx);
      } catch {
        res.statusCode = 404;
        return res.end('Not Found');
      }
    }
    res.statusCode = 404;
    return res.end('Not Found');
  }

  const ext = extname(p);
  res.setHeader('Content-Type', MIME[ext] || 'application/octet-stream');
  if (ext !== '.html') res.setHeader('Cache-Control', 'public, max-age=86400');
  res.end(await readFile(file));
}).listen(PORT, '127.0.0.1', () => console.log(`ytify on 127.0.0.1:${PORT}`));
