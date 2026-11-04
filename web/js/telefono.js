// Il telefono del giocatore: entra nella stanza, sceglie la pila, tira il dado, sceglie cavalli e caselle.
// Sono attivi solo i pulsanti delle scelte valide (li decide la TV).
import { creaRete, RADICE } from './rete.js';
import { sbloccaAudio, suona } from './suoni.js';

const q = new URLSearchParams(location.search);
const app = document.getElementById('app');
let rete = null;
let codice = (q.get('s') || '').toUpperCase().replace(/[^A-Z]/g, '');
let uid = '';
let nome = localStorage.getItem('fdc_nome') || '';
let S = null;          // stato pubblico mandato dalla TV
let mio = null;        // i miei talloncini
let inviato = -1;      // id della domanda a cui ho già risposto
let mostraTal = false;
let ultimaDomanda = -1;
let festeggiato = -1;

function esc(s) { return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function euro(x) {
  if (!x || x <= 0) return '0 euro';
  const c = Math.round(x * 100);
  return c % 100 === 0 ? `${c / 100} euro` : `${Math.floor(c / 100)},${String(c % 100).padStart(2, '0')} euro`;
}
function testata() {
  const io = S?.giocatori?.find((g) => g.uid === uid);
  const r = io?.ritratto ? `<img class="mio-ritratto" src="img/ritratti/${esc(io.ritratto)}.webp" alt="">` : '';
  return `<div class="testata"><img src="img/titolo.webp" alt="Febbre da Cavallo">
    <div class="chi">${io ? `<b>${esc(io.nome)}</b>` : (nome ? `<b>${esc(nome)}</b>` : '')}${codice ? 'stanza ' + esc(codice) : ''}</div>${r}</div>`;
}

// ------------------------------------------------------------------ ingresso
function schermataCodice(msg = '') {
  app.innerHTML = `${testata()}<div class="box"><h2>Entra all'ippodromo</h2>
    <p>Scrivi il codice di 4 lettere che vedi sulla TV.</p>
    <input id="cod" maxlength="4" placeholder="CODICE" autocapitalize="characters" autocomplete="off">
    <button class="verde" id="vai">ENTRA</button>${msg ? `<p class="piccolo">${esc(msg)}</p>` : ''}</div>
    <div class="box"><h2>Sei la TV?</h2><p>Apri l'ippodromo sull'iPad o sul computer collegato al televisore.</p>
    <a class="bottone" href="./${q.get('rete') ? '?rete=' + esc(q.get('rete')) : ''}">APRI LA TV</a></div>`;
  const i = app.querySelector('#cod');
  const vai = () => {
    const c = i.value.toUpperCase().replace(/[^A-Z]/g, '');
    if (c.length === 4) location.search = '?s=' + c + (q.get('rete') ? '&rete=' + q.get('rete') : '');
  };
  app.querySelector('#vai').onclick = vai;
  i.onkeydown = (e) => { if (e.key === 'Enter') vai(); };
}

const RITRATTI = [['mandrake', 'Mandrake'], ['pomata', 'Pomata'], ['felice', 'Felice'], ['gabriella', 'Gabriella'],
  ['giuliana', 'Giuliana'], ['mafalda', 'Mafalda'], ['avvocato', 'Avvocato De Marchis'], ['giudice', 'Giudice'],
  ['manzotin', 'Manzotin'], ['ventresca', 'Ventresca']];
let ritratto = localStorage.getItem('fdc_ritratto') || '';
let presiRitratti = {};

function schermataNome() {
  app.innerHTML = `${testata()}<div class="box"><h2>Come ti chiami?</h2>
    <p>Il nome comparirà sulla TV.</p>
    <input id="nome" maxlength="14" placeholder="Il tuo nome" value="${esc(nome)}" autocomplete="off">
    <h2>Chi sei nel film?</h2><div class="ritratti" id="ritratti"></div>
    <button class="verde grande" id="entra">ENTRA</button></div>`;
  const i = app.querySelector('#nome');
  const griglia = app.querySelector('#ritratti');
  const disegnaRitratti = () => {
    if (!ritratto || presiRitratti[ritratto]) ritratto = (RITRATTI.find(([id]) => !presiRitratti[id]) || [''])[0];
    griglia.innerHTML = RITRATTI.map(([id, n]) => `<button class="ritratto ${id === ritratto ? 'scelto' : ''}" data-r="${id}" ${presiRitratti[id] ? 'disabled' : ''}>
      <img src="img/ritratti/${id}.webp" alt=""><span>${esc(n)}</span></button>`).join('');
    griglia.querySelectorAll('[data-r]').forEach((b) => { b.onclick = () => { ritratto = b.dataset.r; disegnaRitratti(); }; });
  };
  disegnaRitratti();
  const stacca = rete.on(`${RADICE}/${codice}/stato`, (v) => {
    let st = null;
    try { st = v ? JSON.parse(v) : null; } catch (e) { st = null; }
    presiRitratti = {};
    for (const g of st?.giocatori || []) if (g.uid !== uid && g.ritratto) presiRitratti[g.ritratto] = true;
    disegnaRitratti();
  });
  const entra = async () => {
    const n = i.value.trim().slice(0, 14);
    if (!n) { i.focus(); return; }
    sbloccaAudio();
    nome = n;
    localStorage.setItem('fdc_nome', n);
    localStorage.setItem('fdc_ritratto', ritratto);
    try { stacca?.(); } catch (e) { /* ok */ }
    await rete.set(`${RADICE}/${codice}/giocatori/${uid}`, { nome: n, ritratto, t: Date.now() });
    localStorage.setItem('fdc_stanza_' + codice, '1');
    ascolta();
  };
  app.querySelector('#entra').onclick = entra;
  i.onkeydown = (e) => { if (e.key === 'Enter') entra(); };
}

let inAscolto = false;
function ascolta() {
  if (inAscolto) return;
  inAscolto = true;
  try { navigator.wakeLock?.request('screen'); } catch (e) { /* ok */ }
  rete.on(`${RADICE}/${codice}/stato`, (v) => {
    try { S = v ? JSON.parse(v) : null; } catch (e) { S = null; }
    disegna();
  });
  rete.on(`${RADICE}/${codice}/segreti/${uid}`, (v) => {
    try { mio = v ? JSON.parse(v) : null; } catch (e) { mio = null; }
    disegna();
  });
  disegna();
}

// ------------------------------------------------------------------ disegno
function cronista() {
  if (!S?.frase) return '';
  return `<div class="cronista"><img src="img/avatar/saluta.webp" alt=""><div class="fumetto">${esc(S.frase)}</div></div>`;
}

function talloncini(vincitore = -1) {
  if (!mio || mio.pila < 0) return '';
  // raggruppati per cavallo: con pochi giocatori le pile sono grandi
  const gruppi = {};
  for (const x of mio.talloncini) {
    if (!gruppi[x.c]) gruppi[x.c] = { c: x.c, nome: x.nome, col: x.col, q: [] };
    gruppi[x.c].q.push(x.q);
  }
  const ord = Object.values(gruppi).sort((a, b) => b.q.reduce((s, v) => s + v, 0) - a.q.reduce((s, v) => s + v, 0));
  const t = ord.map((g) => `<div class="tal ${g.c === vincitore ? 'vince' : ''}" style="background:${esc(g.col)}">
    <b>${g.q.reduce((s, v) => s + v, 0)}</b>${esc(g.nome)}${g.q.length > 1 ? `<small>${g.q.join(' + ')}</small>` : ''}</div>`).join('');
  const coperti = !mostraTal && vincitore < 0;
  return `<div class="box"><h2>I tuoi talloncini (pila ${esc(mio.lettera)})</h2>
    <div class="talloncini ${coperti ? 'coperti' : ''}">${t}</div>
    ${vincitore < 0 ? `<button class="grigio" id="mostra">${mostraTal ? 'NASCONDI' : 'GUARDA DI NASCOSTO'}</button>` : ''}</div>`;
}

function classifica() {
  if (!S?.cavalli) return '';
  const val = {};
  if (mio?.talloncini) for (const t of mio.talloncini) val[t.c] = (val[t.c] || 0) + t.q;
  const ord = [...S.cavalli].sort((a, b) => b.p - a.p);
  const righe = ord.map((c) => `<div class="r ${c.attivo ? '' : 'riposa'}"><span class="col" style="background:${esc(c.col)}"></span>
    <span style="width:104px">${esc(c.nome)}</span><span class="barra"><i style="width:${Math.max(2, Math.min(100, (c.p + 0.02) * 100))}%;background:${esc(c.col)}"></i></span>
    <span class="st">${esc(c.stato)}</span>${mostraTal && val[c.id] ? `<span class="mio">${val[c.id]}</span>` : '<span class="mio"></span>'}</div>`).join('');
  return `<div class="box classifica"><h2>La corsa</h2>${righe}</div>`;
}

function domanda() {
  const d = S?.domanda;
  if (!d || !d.per || !d.per.includes(uid)) return '';
  if (inviato === d.id) return `<div class="box"><div class="inviato">Fatto! Guarda la TV...</div></div>`;
  let corpo = '';
  const op = d.opzioni || [];
  if (d.tipo === 'tira') {
    corpo = `<button class="verde grande" data-k="tira">TIRA IL DADO!</button>`;
  } else if (d.tipo === 'cavallo') {
    corpo = `<div class="cavalli">${op.map((o) => `<button class="cavallo" data-k="${esc(o.k)}" ${o.ok ? '' : 'disabled'}
      style="border-color:${esc(o.c)}"><span class="col" style="background:${esc(o.c)}"></span><span>${esc(o.t)}<small>${esc(o.s || '')}</small></span></button>`).join('')}</div>`;
  } else if (d.tipo === 'casella') {
    corpo = `<p class="piccolo">I numeri sono segnati sulla pista, sulla TV.</p><div class="scelte">${op.map((o) => `<button class="casella" data-k="${esc(o.k)}" ${o.ok ? '' : 'disabled'}>
      <span class="num">${esc(o.t)}</span><small>${esc(o.s || '')}</small></button>`).join('')}</div>`;
  } else if (d.tipo === 'prendi') {
    corpo = `<div class="dadi">${op.map((o) => `<button class="dado ${o.e ? 'doppio' : ''}" data-k="${esc(o.k)}" ${o.ok ? '' : 'disabled'}>${o.e ? `+${o.n}<br>-${o.n}` : '+' + esc(o.n)}${o.v ? '<span class="pv"></span>' : ''}</button>`).join('')}</div>
      <p class="piccolo">Il pallino verde fa pescare un token; con +N -N puoi anche tornare indietro.</p>`;
  } else if (d.tipo === 'pila') {
    corpo = `<div class="scelte quattro">${op.map((o) => `<button data-k="${esc(o.k)}" ${o.ok ? '' : 'disabled'}>${esc(o.t.replace('Pila ', ''))}</button>`).join('')}</div>`;
  } else {
    corpo = `<div class="scelte ${op.length === 2 ? 'due' : ''}">${op.map((o) => `<button data-k="${esc(o.k)}" ${o.ok ? '' : 'disabled'}>${esc(o.t)}</button>`).join('')}</div>`;
  }
  return `<div class="box domanda"><h2>${esc(d.titolo)}</h2>${d.sotto ? `<p>${esc(d.sotto)}</p>` : ''}${corpo}</div>`;
}

function risultato() {
  if (!S || (S.fase !== 'svela' && S.fase !== 'fine') || !S.risultati?.length) return '';
  const r = S.risultati.find((x) => x.uid === uid);
  const vinc = S.cavalli?.[S.vincitore];
  const titolo = vinc ? `<p>Ha vinto <b style="color:${esc(vinc.col)}">${esc(vinc.nome)}</b></p>` : '';
  if (!r) return '';
  const g = S.giocatori.find((x) => x.uid === uid);
  const saldo = g ? g.saldo : 0;
  const saldoTxt = S.cfg?.posta > 0 ? `<p class="piccolo">Saldo della serata: ${saldo >= 0 ? '+' : '-'}${euro(Math.abs(saldo))}</p>` : '';
  if (r.quote > 0) {
    if (festeggiato !== S.corsa) { festeggiato = S.corsa; suona('vittoria'); try { navigator.vibrate?.([200, 100, 200, 100, 400]); } catch (e) { /* ok */ } coriandoli(); }
    return `<div class="box vittoria"><img src="img/avatar/festeggia.webp" alt=""><h1>HAI VINTO!</h1>${titolo}
      <div class="premio">${S.cfg?.posta > 0 ? euro(r.premio) : r.quote + ' quote'}</div>
      <p>${r.quote} ${r.quote === 1 ? 'quota' : 'quote'} sul cavallo vincente</p>${saldoTxt}</div>`;
  }
  return `<div class="box peccato"><img src="img/avatar/triste.webp" alt=""><h1>Peccato...</h1>${titolo}
    <p>Nessun talloncino sul cavallo vincente. Sarà per la prossima!</p>${saldoTxt}</div>`;
}

function disegna() {
  if (!S) {
    app.innerHTML = `${testata()}<div class="box"><h2>Collegamento...</h2><p>Aspetto la TV dell'ippodromo.</p></div>`;
    return;
  }
  const io = S.giocatori?.find((g) => g.uid === uid);
  let h = testata();
  if (!io && S.fase === 'attesa') {
    h += `<div class="box"><h2>Un attimo...</h2><p>Sto entrando nella stanza ${esc(codice)}.</p></div>`;
  } else if (!io) {
    h += `<div class="box"><h2>Corsa già partita</h2><p>Questa corsa è già cominciata: potrai entrare alla prossima.</p></div>${cronista()}${classifica()}`;
  } else if (S.fase === 'attesa') {
    h += `<div class="box"><h2>Sei dentro, ${esc(nome)}!</h2><p>Siete in ${S.giocatori.length}. Quando ci sono tutti, si parte dalla TV.</p>
      <p class="piccolo">Tieni il telefono acceso: quando tocca a te vibra.</p></div>${cronista()}`;
  } else {
    const d = domanda();
    const ris = risultato();
    if (S.di_turno && S.di_turno !== uid && !d) h += `<div class="tocca">Tocca a ${esc(S.nome_turno)}</div>`;
    h += ris + d + cronista();
    if (S.fase === 'pile' && !d) h += `<div class="box"><p>Gli altri stanno scegliendo la pila...</p></div>`;
    h += talloncini(ris ? S.vincitore : -1);
    if (S.fase === 'corsa' || S.fase === 'svela') h += classifica();
    if (d && S.domanda.id !== ultimaDomanda) {
      ultimaDomanda = S.domanda.id;
      try { navigator.vibrate?.(S.domanda.tipo === 'prendi' ? [80, 40, 80] : 150); } catch (e) { /* ok */ }
      suona('ding');
    }
  }
  app.innerHTML = h;
  app.querySelectorAll('[data-k]').forEach((b) => {
    b.onclick = () => rispondi(b.dataset.k);
  });
  const m = app.querySelector('#mostra');
  if (m) m.onclick = () => { mostraTal = !mostraTal; disegna(); };
}

async function rispondi(k) {
  const d = S?.domanda;
  if (!d || inviato === d.id) return;
  inviato = d.id;
  suona('click');
  disegna();
  try {
    await rete.push(`${RADICE}/${codice}/azioni`, { da: uid, p: d.id, k: String(k), t: Date.now() });
  } catch (e) {
    inviato = -1;
    avviso('Non sono riuscito a mandarlo, riprova');
    disegna();
  }
}

function avviso(t) {
  const a = document.createElement('div');
  a.className = 'avviso';
  a.textContent = t;
  document.body.appendChild(a);
  setTimeout(() => a.remove(), 2500);
}

function coriandoli() {
  const cv = document.createElement('canvas');
  cv.className = 'coriandoli';
  document.body.appendChild(cv);
  const W = (cv.width = innerWidth * devicePixelRatio), H = (cv.height = innerHeight * devicePixelRatio);
  const g = cv.getContext('2d');
  const col = ['#e63946', '#ffd166', '#06d6a0', '#118ab2', '#f15bb5', '#ffffff'];
  const p = Array.from({ length: 140 }, () => ({ x: Math.random() * W, y: -Math.random() * H * 0.6, vx: (Math.random() - 0.5) * 6,
    vy: 3 + Math.random() * 6, r: (4 + Math.random() * 7) * devicePixelRatio, a: Math.random() * 6, c: col[Math.floor(Math.random() * col.length)] }));
  const t0 = performance.now();
  (function passo(t) {
    g.clearRect(0, 0, W, H);
    for (const c of p) {
      c.x += c.vx; c.y += c.vy * devicePixelRatio; c.a += 0.1;
      g.save(); g.translate(c.x, c.y); g.rotate(c.a); g.fillStyle = c.c; g.fillRect(-c.r, -c.r / 2, c.r * 2, c.r); g.restore();
    }
    if (t - t0 < 4500) requestAnimationFrame(passo); else cv.remove();
  })(t0);
}

// ------------------------------------------------------------------ avvio
(async () => {
  if (codice.length !== 4) { schermataCodice(); return; }
  app.innerHTML = `${testata()}<div class="box"><h2>Collegamento...</h2></div>`;
  try {
    rete = creaRete();
    uid = await rete.init();
    const host = await rete.get(`${RADICE}/${codice}/host`);
    if (!host) { schermataCodice('La stanza ' + codice + ' non esiste: controlla il codice sulla TV.'); return; }
    const gia = await rete.get(`${RADICE}/${codice}/giocatori/${uid}`);
    if (gia && gia.nome) { nome = gia.nome; ascolta(); } else schermataNome();
  } catch (e) {
    console.error(e);
    app.innerHTML = `${testata()}<div class="box"><h2>Niente collegamento</h2><p>Controlla la connessione e riprova.</p>
      <p class="piccolo">${esc(e?.message || e)}</p><a class="bottone" href="${esc(location.href)}">RIPROVA</a></div>`;
  }
})();
