// Tiny static server for a Flutter web build: node serve.js <dir> <port>
const http = require('http'), fs = require('fs'), path = require('path');
const root = path.resolve(process.argv[2] || 'build/web_dev');
const port = +(process.argv[3] || 8765);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.wav': 'audio/wav', '.css': 'text/css' };
http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(root, p);
  if (!f.startsWith(root) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
}).listen(port, () => console.log('serving', root, 'on', port));
