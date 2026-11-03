// Prova della schermata finale del telefono: una finta TV scrive lo stato di fine corsa.
// node tests/telefono_fine.mjs build/web /tmp/prova_fine
import { createRequire } from 'module';
import http from 'http';
import fs from 'fs';
import path from 'path';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PW || 'playwright');
const dir = path.resolve(process.argv[2] || 'build/web');
const out = path.resolve(process.argv[3] || '/tmp/prova_fine');
fs.mkdirSync(out, { recursive: true });
const tipi = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.webp': 'image/webp', '.png': 'image/png' };
const srv = http.createServer((req, res) => {
  const p = decodeURIComponent(req.url.split('?')[0]);
  const f = path.join(dir, p);
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(200, { 'Content-Type': 'text/html' }); res.end('<html><body></body></html>'); return; }
  res.writeHead(200, { 'Content-Type': tipi[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
}).listen(8766);

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
const tv = await ctx.newPage();
await tv.goto('http://localhost:8766/vuota.html?rete=locale');
await tv.addScriptTag({ type: 'module', content: `
  import { creaRete, RADICE } from '/js/rete.js';
  const r = creaRete(); await r.init(); await r.set(RADICE + '/PROV/host', r.uid);
  window.RADICE = RADICE; window.R = r;` });
await tv.waitForFunction(() => window.R, null, { timeout: 20000 });
const tel = [];
for (const n of ['Stefano', 'Chiara']) {
  const p = await ctx.newPage();
  await p.goto('http://localhost:8766/telefono.html?s=PROV&rete=locale');
  await p.waitForSelector('#nome', { timeout: 20000 });
  await p.fill('#nome', n);
  await p.click('#entra');
  tel.push(p);
  await p.waitForTimeout(800);
}
await tv.waitForTimeout(1000);
await tv.evaluate(async () => {
  const R = window.R, RAD = window.RADICE;
  const g = await R.get(RAD + '/PROV/giocatori');
  const uids = Object.keys(g);
  const nomiC = ['King', 'Soldatino', 'Dartagnan', 'Apocalisse', 'Can Can', 'Piripicchio', "'O Sole Mio", 'Uragano'];
  const colori = ['#d62828', '#f2c200', '#1f5fd6', '#2a9d3f', '#8e44ad', '#f77f00', '#ff5fa2', '#2b2b2b'];
  const cav = nomiC.map((n, i) => ({ id: i, nome: n, col: colori[i], attivo: true, zoppo: false, p: i / 8, stato: 'pronto' }));
  const ris = [
    { uid: uids[0], nome: g[uids[0]].nome, quote: 4, premio: 8, talloncini: [] },
    { uid: uids[1], nome: g[uids[1]].nome, quote: 0, premio: 0, talloncini: [] },
  ];
  const S = { fase: 'fine', corsa: 1, giocatori: uids.map((u, i) => ({ uid: u, nome: g[u].nome, saldo: i ? -15 : -7 })),
    cavalli: cav, vincitore: 2, risultati: ris, cfg: { posta: 15 }, frase: 'Ha vinto Dartagnan! Che corsa, signori!', domanda: {} };
  const tal = [{ c: 2, nome: 'Dartagnan', col: colori[2], q: 3 }, { c: 2, nome: 'Dartagnan', col: colori[2], q: 1 },
    { c: 5, nome: 'Piripicchio', col: colori[5], q: 2 }, { c: 0, nome: 'King', col: colori[0], q: 4 }, { c: 7, nome: 'Uragano', col: colori[7], q: 5 }];
  for (const u of uids) await R.set(RAD + '/PROV/segreti/' + u, JSON.stringify({ pila: 0, lettera: 'A', talloncini: tal }));
  await R.set(RAD + '/PROV/stato', JSON.stringify(S));
});
await tv.waitForTimeout(2500);
for (let i = 0; i < tel.length; i++) await tel[i].screenshot({ path: `${out}/fine_${i}.png`, fullPage: true });
console.log('ok');
await browser.close();
srv.close();
