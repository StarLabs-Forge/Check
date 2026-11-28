// Conduce un navegador real (Edge/Chrome sin interfaz) por el protocolo DevTools.
// Sin dependencias: Node >= 22 (WebSocket nativo).
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { extname, join, normalize } from 'node:path';

const BROWSERS = [
  process.env.BROWSER_PATH,
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
].filter(Boolean);

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf', '.ico': 'image/x-icon',
};

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function serve(root) {
  const server = createServer((req, res) => {
    let path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    if (path.endsWith('/')) path += 'index.html';
    const file = join(root, normalize(path).replace(/^([/\\]|\.\.)+/, ''));
    if (!existsSync(file)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' });
    res.end(readFileSync(file));
  });
  return new Promise((r) => server.listen(0, '127.0.0.1', () => r({ server, url: `http://127.0.0.1:${server.address().port}` })));
}

export async function launch() {
  const exe = BROWSERS.find((p) => existsSync(p));
  if (!exe) throw new Error('No se encontró Edge/Chrome (usa BROWSER_PATH).');
  const profile = mkdtempSync(join(tmpdir(), 'check-browser-'));
  const proc = spawn(exe, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
    '--no-first-run', '--no-default-browser-check', '--disable-extensions', 'about:blank'], { stdio: 'ignore' });
  const portFile = join(profile, 'DevToolsActivePort');
  for (let i = 0; i < 600 && !existsSync(portFile); i++) await sleep(100);
  if (!existsSync(portFile)) { proc.kill(); throw new Error('El navegador no arrancó en 60 s.'); }
  await sleep(200);
  const port = readFileSync(portFile, 'utf8').split('\n')[0];
  let target;
  for (let i = 0; i < 50 && !target; i++) {
    target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find((t) => t.type === 'page');
    if (!target) await sleep(100);
  }
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((ok, ko) => { ws.onopen = ok; ws.onerror = ko; });
  let id = 0;
  const pending = new Map();
  const errors = [];
  ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id) { pending.get(msg.id)?.(msg); pending.delete(msg.id); }
    if (msg.method === 'Runtime.exceptionThrown') {
      errors.push(msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text);
    }
  };
  const send = (method, params = {}) => new Promise((ok, ko) => {
    const n = ++id;
    const timer = setTimeout(() => { pending.delete(n); ko(new Error(`${method}: sin respuesta en 90 s`)); }, 90000);
    pending.set(n, (msg) => {
      clearTimeout(timer);
      if (msg.error) ko(new Error(`${method}: ${msg.error.message}`)); else ok(msg.result);
    });
    ws.send(JSON.stringify({ id: n, method, params }));
  });
  await send('Page.enable');
  await send('Runtime.enable');

  const page = {
    errors,
    send,
    async eval(expression) {
      const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
      if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description ?? r.exceptionDetails.text);
      return r.result.value;
    },
    async goto(url, wait = 1500) {
      await send('Page.navigate', { url: 'about:blank' });
      const nav = await send('Page.navigate', { url });
      if (nav.errorText) throw new Error(`No se pudo abrir ${url}: ${nav.errorText}`);
      for (let i = 0; i < 100; i++) {
        await sleep(100);
        if (await page.eval('location.href !== "about:blank" && document.readyState === "complete"')) break;
      }
      await sleep(wait);
    },
    async viewport(width, height, mobile = false) {
      await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile });
      await send('Emulation.setTouchEmulationEnabled', { enabled: mobile });
    },
    async history(delta, wait = 1500) {
      const h = await send('Page.getNavigationHistory');
      const entry = h.entries[h.currentIndex + delta];
      if (!entry) return false; // no hay entrada en esa dirección
      await send('Page.navigateToHistoryEntry', { entryId: entry.id });
      await sleep(wait);
      return true;
    },
    async screenshot(file) {
      const r = await send('Page.captureScreenshot', { format: 'png' });
      writeFileSync(file, Buffer.from(r.data, 'base64'));
    },
    async click(x, y, wait = 1000) {
      for (const type of ['mousePressed', 'mouseReleased']) {
        await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
      }
      await sleep(wait);
    },
    close() { ws.close(); proc.kill(); },
  };
  return page;
}

export function reporter() {
  let fails = 0;
  return {
    check(name, ok, detail = '') {
      if (!ok) fails++;
      console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail === '' ? '' : `  [${detail}]`}`);
    },
    done() { console.log(`\n${fails ? 'FALLÓ' : 'OK'}: ${fails} fallo(s)`); return fails; },
  };
}
