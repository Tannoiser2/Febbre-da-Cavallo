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

function mieQuote() {
  const val = {};
  if (mio?.talloncini) for (const t of mio.talloncini) val[t.c] = (val[t.c] || 0) + t.q;
  return val;
}

// I talloncini stanno in un box chiuso: si apre e si chiude toccandolo
function talloncini(vincitore = -1) {
  if (!mio || mio.pila < 0) return '';
  const gruppi = {};
  for (const x of mio.talloncini) {
    if (!gruppi[x.c]) gruppi[x.c] = { c: x.c, nome: x.nome, col: x.col, q: [] };
    gruppi[x.c].q.push(x.q);
  }
  const ord = Object.values(gruppi).sort((a, b) => b.q.reduce((s, v) => s + v, 0) - a.q.reduce((s, v) => s + v, 0));
  const aperto = mostraTal || vincitore >= 0;
  const t = ord.map((g) => `<div class="tal ${g.c === vincitore ? 'vince' : ''}" style="background:${esc(g.col)}">
    <b>${g.q.reduce((s, v) => s + v, 0)}</b>${esc(g.nome)}${g.q.length > 1 ? `<small>${g.q.join(' + ')}</small>` : ''}</div>`).join('');
  return `<div class="box tallbox" id="mostra"><h2>I tuoi talloncini (pila ${esc(mio.lettera)}) <span class="freccia">${aperto ? 'chiudi' : 'apri'}</span></h2>
    ${aperto ? `<div class="talloncini">${t}</div>` : '<p class="piccolo">Tocca per guardarli di nascosto.</p>'}</div>`;
}

// I cavalli sono sempre visibili: si possono toccare solo quando si deve scegliere un cavallo.
// Per muovere: il primo tocco mostra dove può andare (e la TV lo inquadra), poi si conferma con MUOVI
let anteprima = -1;
let anteprimaPer = -1;
function guarda(k) {
  anteprima = k;
  const d = S?.domanda;
  if (d) rete.push(`${RADICE}/${codice}/azioni`, { da: uid, p: d.id, k: String(k), g: 1, t: Date.now() }).catch(() => {});
}
function cavalli(d) {
  if (!S?.cavalli) return '';
  const val = mieQuote();
  const attiva = d && d.tipo === 'cavallo' && inviato !== d.id;
  const scelta = attiva ? Object.fromEntries(d.opzioni.map((o) => [o.k, o.ok])) : null;
  const conAnteprima = attiva && d.anteprime;
  if (!attiva || anteprimaPer !== d.id) {
    anteprima = -1;
    anteprimaPer = attiva ? d.id : -1;
    // si parte già guardando il primo cavallo che si può muovere
    if (conAnteprima) { const primo = d.opzioni.find((o) => o.ok); if (primo) guarda(Number(primo.k)); }
  }
  const bottone = (c, compatto) => {
    const ok = scelta ? !!scelta[c.id] : false;
    const k = conAnteprima ? `data-a="${c.id}"` : `data-k="${c.id}"`;
    return `<button class="cavallo ${compatto ? 'compatto' : ''} ${c.attivo ? '' : 'riposa'} ${scelta && ok ? 'valido' : ''} ${anteprima === c.id ? 'scelto' : ''}" ${ok ? k : 'disabled'}
      style="border-color:${esc(c.col)}"><span class="col" style="background:${esc(c.col)}"></span>
      <span>${esc(c.nome)}<small>${esc(c.stato)}</small></span>${val[c.id] ? `<span class="quote">${val[c.id]}</span>` : ''}</button>`;
  };
  if (conAnteprima && anteprima >= 0) {
    // a sinistra i cavalli uno sopra l'altro, a destra la pista: si tocca la casella e si muove
    return `<div class="scegli"><div class="colonna">${S.cavalli.map((c) => bottone(c, true)).join('')}</div>
      <div class="pistina">${mappa(d.anteprime[String(anteprima)], true, anteprima)}</div></div>`;
  }
  return `<div class="cavalli fissi">${S.cavalli.map((c) => bottone(c, false)).join('')}</div>`;
}

// Pezzo di pista in verticale (si va verso l'alto, corsia interna a sinistra), con i cavalli,
// le caselle dove si può arrivare (numerate) e accanto i token o le carte della colonna
function mappa(m, tocca = true, cav = null) {
  const chiave = (k) => (cav == null ? String(k) : `${cav}:${k}`);
  if (!m) return '';
  const LANE = 62, PAD = 10, SIDE = 112, W = PAD * 2 + LANE * 3 + SIDE;
  const span = Math.max(1, m.hi - m.lo);
  const sc = Math.min(30, Math.max(14, 560 / span));
  const H = Math.round(span * sc + 2 * PAD);
  const Y = (v) => PAD + (m.hi - v) * sc;
  let svg = `<svg class="mappa" viewBox="0 0 ${W} ${H + (m.arrivo ? 40 : 0)}" xmlns="http://www.w3.org/2000/svg" style="max-height:62vh">
    <rect x="0" y="0" width="${W}" height="${H + (m.arrivo ? 40 : 0)}" rx="12" fill="#2f8f3f"/>
    <rect x="${PAD - 5}" y="0" width="${LANE * 3 + 10}" height="${H + (m.arrivo ? 40 : 0)}" fill="#1d7a4a"/>`;
  if (m.arrivo) svg += `<rect x="${PAD}" y="4" width="${LANE * 3}" height="30" fill="#fff" stroke="#ff2d55" stroke-width="4" ${tocca ? `data-k="${chiave(-2)}"` : ''}/><text x="${PAD + LANE * 1.5}" y="28" text-anchor="middle" font-family="Bangers" font-size="26" fill="#b8202a" pointer-events="none">ARRIVO</text>`;
  const off = m.arrivo ? 40 : 0;
  const toks = {};
  for (const c of m.celle) {
    const x = PAD + c.l * LANE, y = Y(c.b) + off, h = (c.b - c.a) * sc;
    const scelta = c.n != null;
    svg += `<rect x="${x + 2}" y="${y + 2}" width="${LANE - 4}" height="${Math.max(2, h - 4)}" rx="5"
      fill="${scelta ? '#ffe36b' : (c.c ? '#f6d978' : '#ebc248')}" stroke="${scelta ? '#ff2d55' : '#1d7a4a'}" stroke-width="${scelta ? 5 : 1.5}"
      ${scelta && tocca ? `data-k="${chiave(c.k)}"` : ''}/>`;
    if (c.tok != null && c.tok !== false) toks[Math.round((c.a + c.b) * 5)] = { tok: c.tok, y: y + h / 2 };
    if (c.cav) svg += `<circle cx="${x + LANE / 2}" cy="${y + h / 2}" r="17" fill="${c.cav}" stroke="${c.io ? '#fff' : '#000'}" stroke-width="${c.io ? 5 : 2}" pointer-events="none"/>`;
    if (scelta) svg += `<text x="${x + LANE / 2}" y="${y + h / 2 + 12}" text-anchor="middle" font-family="Bangers" font-size="34" fill="#b0002a" pointer-events="none">${c.n}</text>`;
  }
  // un token o una carta per colonna, sul prato a destra della pista
  const visti = [];
  for (const t of Object.values(toks)) {
    if (visti.some((v) => Math.abs(v - t.y) < 52)) continue;
    visti.push(t.y);
    const xs = PAD * 2 + LANE * 3 + 4;
    if (typeof t.tok === 'number') {
      // della carta si vede la parte di sotto, come sulla pista
      svg += `<image href="img/carte/s${String(t.tok + 1).padStart(2, '0')}.webp" x="${xs}" y="${t.y - 26}" width="${SIDE - 8}" height="${(SIDE - 8) * 0.48}" preserveAspectRatio="xMidYMid meet" pointer-events="none"/>`;
    } else {
      svg += `<image href="img/token/${esc(t.tok)}.webp" x="${xs + 12}" y="${t.y - 40}" width="80" height="80" pointer-events="none"/>`;
    }
  }
  svg += `</svg>`;
  return svg;
}

// Corsa al dado: a tutto schermo, finché non sono stati presi tutti i dadi
function corsaDado(d) {
  const dc = S?.dadi_corsa || [];
  if (!S?.in_corsa_dado || !dc.length || dc.every((x) => x.chi)) return '';
  const mia = d && d.tipo === 'prendi' && inviato !== d.id;
  const preso = dc.find((x) => x.chi === S.giocatori.find((g) => g.uid === uid)?.nome);
  return `<div class="corsadado"><h1>CORSA AL DADO!</h1><p>${mia ? 'Tocca un dado, presto!' : (preso ? 'Hai preso il tuo dado!' : 'Aspetta...')}</p>
    <div class="dadi grandi">${dc.map((x, i) => {
      const libero = !x.chi && mia;
      return `<div class="dadobox"><button class="dado ${x.e ? 'doppio' : ''}" ${libero ? `data-k="${i}"` : 'disabled'}>${x.e ? `+${x.n}<br>-${x.n}` : '+' + esc(x.n)}${x.v ? '<span class="pv"></span>' : ''}</button>
        <div class="chi">${esc(x.chi || '')}</div></div>`;
    }).join('')}</div><p class="piccolo">Il pallino verde fa pescare; con +N -N puoi anche tornare indietro. Chi prende per primo gioca per ultimo.</p></div>`;
}

function domanda() {
  const d = S?.domanda;
  if (!d || !d.per || !d.per.includes(uid)) return '';
  if (d.tipo === 'prendi') return '';
  if (inviato === d.id) return `<div class="box"><div class="inviato">Fatto! Guarda la TV...</div></div>`;
  let corpo = '';
  const op = d.opzioni || [];
  if (d.tipo === 'tira') {
    corpo = `<button class="verde grande" data-k="tira">TIRA IL DADO!</button>`;
  } else if (d.tipo === 'cavallo') {
    corpo = d.anteprime ? `<p class="piccolo">Scegli il cavallo a sinistra, poi tocca sulla pista la casella dove va.</p>` : `<p class="piccolo">Tocca uno dei cavalli illuminati qui sotto.</p>`;
  } else if (d.tipo === 'casella') {
    corpo = d.mappa ? `<p class="piccolo">Si va verso l'alto; a sinistra la corsia interna. Tocca la casella.</p>${mappa(d.mappa)}` : `<div class="scelte">${op.map((o) => `<button class="casella" data-k="${esc(o.k)}">
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
    h += `<div class="box"><h2>Corsa già partita</h2><p>Questa corsa è già cominciata: potrai entrare alla prossima.</p></div>${cronista()}${cavalli(null)}`;
  } else if (S.fase === 'attesa') {
    h += `<div class="box"><h2>Sei dentro, ${esc(nome)}!</h2><p>Siete in ${S.giocatori.length}. Quando ci sono tutti, si parte dalla TV.</p>
      <p class="piccolo">Tieni il telefono acceso e il volume alto: quando tocca a te suona e lampeggia (e vibra, sui telefoni Android).</p></div>${cronista()}`;
  } else {
    const dd = S.domanda && S.domanda.per && S.domanda.per.includes(uid) ? S.domanda : null;
    const d = domanda();
    const ris = risultato();
    const cd = corsaDado(dd);
    if (cd) {
      h += cd;
    } else {
      if (S.di_turno && S.di_turno !== uid && !d) h += `<div class="tocca">Tocca a ${esc(S.nome_turno)}</div>`;
      if (S.di_turno === uid && !d) h += `<div class="tocca">Tocca a te!</div>`;
      h += ris;
      const tira = dd && dd.tipo === 'tira';
      const conCavalli = (S.fase === 'corsa' || S.fase === 'svela') && !ris;
      if (!tira) h += d;
      h += cronista();
      if (S.fase === 'pile' && !d) h += `<div class="box"><p>Gli altri stanno scegliendo la pila...</p></div>`;
      if (conCavalli) h += cavalli(dd);
      if (tira) h += d;
      h += talloncini(ris ? S.vincitore : -1);
    }
    if (dd && S.domanda.id !== ultimaDomanda) {
      ultimaDomanda = S.domanda.id;
      richiamo(S.domanda.tipo);
    }
  }
  app.innerHTML = h;
  app.querySelectorAll('[data-k]').forEach((b) => {
    b.onclick = () => rispondi(b.getAttribute('data-k'));
  });
  app.querySelectorAll('[data-a]').forEach((b) => {
    b.onclick = () => { guarda(Number(b.getAttribute('data-a'))); suona('click'); disegna(); };
  });
  // i titoli stanno su una riga: se non ci stanno si rimpiccioliscono
  app.querySelectorAll('.domanda h2, .tocca').forEach((el) => {
    el.style.whiteSpace = 'nowrap';
    let fs = parseFloat(getComputedStyle(el).fontSize);
    while (el.scrollWidth > el.clientWidth + 1 && fs > 15) { fs -= 1; el.style.fontSize = fs + 'px'; }
  });
  const m = app.querySelector('#mostra');
  if (m) m.onclick = () => { mostraTal = !mostraTal; disegna(); };
}

// Quando tocca a te: vibrazione (Android), suono e lampo dello schermo (anche su iPhone, dove le pagine web non possono vibrare)
function richiamo(tipo) {
  try { navigator.vibrate?.(tipo === 'prendi' ? [80, 40, 80, 40, 80] : [200, 80, 200]); } catch (e) { /* ok */ }
  suona(tipo === 'prendi' ? 'preso' : 'ding');
  document.body.classList.remove('lampo');
  void document.body.offsetWidth;
  document.body.classList.add('lampo');
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
