// Prova completa nel browser: TV (Godot web) + telefoni, collegati con la rete "locale" (BroadcastChannel).
// node tests/browser.mjs [cartella build] [cartella foto] [telefoni] [secondi]
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PW || 'playwright');
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = path.resolve(process.argv[2] || 'build/web');
const out = path.resolve(process.argv[3] || '/tmp/prova_web');
const NT = Number(process.argv[4] || 3);
const DURATA = Number(process.argv[5] || 300) * 1000;
fs.mkdirSync(out, { recursive: true });
const tipi = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.css': 'text/css', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.webp': 'image/webp', '.png': 'image/png' };
const srv = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(dir, p);
  if (!fs.existsSync(f)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': tipi[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
}).listen(8765);

const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
const ctx = await browser.newContext();
const errori = [];
const tv = await ctx.newPage({ viewport: { width: Number(process.env.LARG || 960), height: Number(process.env.ALT || 540) } });
tv.setDefaultTimeout(180000);
async function foto_tv(f) { try { await tv.screenshot({ path: f, timeout: 180000 }); } catch (e) { console.log('foto TV non riuscita', f); } }
tv.on('console', (m) => { if (m.type() === 'error') errori.push('TV: ' + m.text()); });
tv.on('pageerror', (e) => errori.push('TV pageerror: ' + e.message));
await tv.goto(`http://localhost:8765/index.html?rete=locale&auto=1&veloce=4&noschermo&parti=${NT}&pista=${process.env.PISTA || 4}`);
let codice = '';
for (let i = 0; i < 240 && !codice; i++) {
  await tv.waitForTimeout(1000);
  codice = await tv.evaluate(() => window.FR?.codice?.() || '');
}
console.log('codice stanza', codice);
await tv.waitForTimeout(3000);
await foto_tv(out + '/tv_sala_vuota.png');
const nomi = ['Stefano', 'Nonna Lina', 'Zio Gigi', 'Chiara', 'Marco'];
const tel = [];
for (let i = 0; i < NT; i++) {
  const p = await ctx.newPage();
  await p.setViewportSize({ width: 390, height: 844 });
  p.on('pageerror', (e) => errori.push(`tel${i} pageerror: ` + e.message));
  p.on('console', (m) => { if (m.type() === 'error') errori.push(`tel${i}: ` + m.text()); });
  await p.goto(`http://localhost:8765/telefono.html?s=${codice}&rete=locale`);
  try { await p.waitForSelector('#nome', { timeout: 60000 }); } catch (e) { await p.screenshot({ path: `${out}/tel${i}_errore.png` }); throw e; }
  await p.fill('#nome', nomi[i]);
  await p.click('#entra');
  tel.push(p);
  await tv.waitForTimeout(800);
}
await tv.waitForTimeout(2500);
await foto_tv(out + '/tv_sala.png');
await tel[0].screenshot({ path: out + '/tel_sala.png' });
const t0 = Date.now();
let foto = 0;
const tipiVisti = {};
let fineVista = false;
while (Date.now() - t0 < DURATA) {
  for (let i = 0; i < tel.length; i++) {
    const p = tel[i];
    const bs = await p.$$('.domanda [data-k]:not([disabled])');
    if (bs.length) {
      const tipo = await p.evaluate(() => document.querySelector('.domanda h2')?.textContent || '');
      const chiave = tipo.split(' ')[0];
      if (!tipiVisti[chiave]) {
        tipiVisti[chiave] = 1;
        await p.screenshot({ path: `${out}/tel${i}_${Object.keys(tipiVisti).length}_${chiave.replace(/[^A-Za-z]/g, '')}.png` });
        if (!process.env.POCHE) await foto_tv(`${out}/tv_domanda_${Object.keys(tipiVisti).length}.png`);
      }
      await new Promise((r) => setTimeout(r, 300 + Math.random() * 500));
      try { await bs[Math.floor(Math.random() * bs.length)].click({ timeout: 2000 }); } catch (e) { /* cambiata */ }
    }
  }
  if (Date.now() - t0 > (foto + 1) * (process.env.POCHE ? 200000 : 40000)) {
    foto++;
    await foto_tv(`${out}/tv_corsa_${foto}.png`);
  }
  const fine = await tel[0].$('.vittoria, .peccato');
  if (fine && !fineVista) {
    fineVista = true;
    await tv.waitForTimeout(4000);
    await foto_tv(out + '/tv_fine.png');
    for (let i = 0; i < tel.length; i++) await tel[i].screenshot({ path: `${out}/tel${i}_fine.png`, fullPage: true });
    break;
  }
  await new Promise((r) => setTimeout(r, 400));
}
console.log('domande viste:', Object.keys(tipiVisti).join(', '));
console.log('fine corsa vista:', fineVista);
console.log('errori:', errori.length ? errori.slice(0, 15).join('\n') : 'nessuno');
await browser.close();
srv.close();
