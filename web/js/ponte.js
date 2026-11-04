// Ponte tra la TV (Godot, versione web) e il resto: stanza su Firebase, telefoni, voce, suoni, QR code.
// Godot lo usa con JavaScriptBridge.get_interface("FR"). Tutto passa come testo JSON.
import { creaRete, nuovoCodice, RADICE } from './rete.js';
import { parla, setVoce, suona, impostaVoce } from './suoni.js';

const coda = [];
const q = new URLSearchParams(location.search);
const parlati = {};
let pid = 0;
let rete = null;
let codice = '';
let stacca = [];
let sigla = null;   // per smettere di ascoltare la stanza precedente

function base() {
  return location.href.split('?')[0].split('#')[0].replace(/index\.html$/, '');
}

window.FR = {
  codice() { return codice; },
  parametri() { return JSON.stringify(Object.fromEntries(q)); },
  preleva() {
    if (!coda.length) return '[]';
    const s = JSON.stringify(coda);
    coda.length = 0;
    return s;
  },
  async avvia(riprendi) {
    try {
      if (!rete) { rete = creaRete(); await rete.init(); }
      for (const f of stacca) { try { f(); } catch (e) { /* ok */ } }
      stacca = [];
      let c = '';
      if (riprendi) {
        const h = await rete.get(`${RADICE}/${riprendi}/host`);
        if (h === rete.uid) c = riprendi;
      }
      if (!c) {
        for (let i = 0; i < 30 && !c; i++) {
          const k = nuovoCodice();
          const h = await rete.get(`${RADICE}/${k}/host`);
          if (!h) c = k;
        }
        await rete.set(`${RADICE}/${c}/host`, rete.uid);
        await rete.set(`${RADICE}/${c}/created`, Date.now());
      }
      codice = c;
      const url = base() + 'telefono.html?s=' + c + (q.get('rete') === 'locale' ? '&rete=locale' : '');
      coda.push({ e: 'stanza', codice: c, url });
      stacca.push(rete.onFigli(`${RADICE}/${c}/giocatori`, {
        aggiunto: (k, v) => coda.push({ e: 'entra', uid: k, nome: v?.nome || '', ritratto: v?.ritratto || '' }),
        cambiato: (k, v) => coda.push({ e: 'entra', uid: k, nome: v?.nome || '', ritratto: v?.ritratto || '' }),
        tolto: (k) => coda.push({ e: 'esce', uid: k }),
      }));
      stacca.push(rete.onFigli(`${RADICE}/${c}/azioni`, {
        aggiunto: (k, v) => {
          if (v && v.da) coda.push({ e: 'azione', uid: v.da, p: v.p, k: v.k });
          if (c === codice) rete.remove(`${RADICE}/${c}/azioni/${k}`);
        },
      }));
    } catch (e) {
      console.error(e);
      coda.push({ e: 'errore', msg: String(e?.message || e) });
    }
  },
  stato(j) { if (rete && codice) rete.set(`${RADICE}/${codice}/stato`, j).catch((e) => console.warn(e)); },
  segreto(uid, j) { if (rete && codice) rete.set(`${RADICE}/${codice}/segreti/${uid}`, j).catch((e) => console.warn(e)); },
  parla(t) {
    const id = ++pid;
    parlati[id] = false;
    if (sigla) sigla.volume = 0.12;
    parla(t, { interrompi: true }).then(() => { parlati[id] = true; if (sigla && Object.values(parlati).every((x) => x)) sigla.volume = 0.35; });
    return id;
  },
  parlato(id) { return !!parlati[id]; },
  suono(n) { suona(n); },
  voce(v) { setVoce(!!v); },
  // colonna sonora in loop (si abbassa quando parla il cronista)
  musica(v) {
    try {
      if (!sigla) { sigla = new Audio('audio/sigla.mp3'); sigla.loop = true; sigla.volume = 0.35; }
      if (v) sigla.play().catch(() => {}); else sigla.pause();
    } catch (e) { /* ok */ }
  },
  velocitaVoce(x) { impostaVoce({ vel: Number(x) || 1 }); },
  schermoIntero() {
    const d = document.documentElement;
    try {
      if (document.fullscreenElement || document.webkitFullscreenElement) (document.exitFullscreen || document.webkitExitFullscreen).call(document);
      else (d.requestFullscreen || d.webkitRequestFullscreen).call(d);
    } catch (e) { /* ok */ }
  },
  qr(testo) {
    /* global qrcode */
    try {
      const qq = qrcode(0, 'M');
      qq.addData(testo);
      qq.make();
      const n = qq.getModuleCount();
      let s = '';
      for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) s += qq.isDark(y, x) ? '1' : '0';
      return s;
    } catch (e) { return ''; }
  },
  salva(k, v) { try { if (v) localStorage.setItem(k, v); else localStorage.removeItem(k); } catch (e) { /* ok */ } },
  carica(k) { try { return localStorage.getItem(k) || ''; } catch (e) { return ''; } },
};
