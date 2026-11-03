const ACCEL = Math.max(1, Number(new URLSearchParams(location.search).get('veloce') || 1));

// Suoni sintetizzati (nessun file audio da scaricare) e voce del banditore (sintesi vocale del browser).

let ctx = null;
export let audioAttivo = true;
export function sbloccaAudio() {
  try {
    if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
    if (ctx.state === 'suspended') ctx.resume();
  } catch (e) { /* niente audio */ }
}
export function setAudio(v) { audioAttivo = v; }

function nota(f, t0, dur, tipo = 'sine', vol = 0.2, f2 = null) {
  if (!ctx || !audioAttivo) return;
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = tipo;
  o.frequency.setValueAtTime(f, ctx.currentTime + t0);
  if (f2) o.frequency.exponentialRampToValueAtTime(f2, ctx.currentTime + t0 + dur);
  g.gain.setValueAtTime(0.0001, ctx.currentTime + t0);
  g.gain.exponentialRampToValueAtTime(vol, ctx.currentTime + t0 + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + t0 + dur);
  o.connect(g).connect(ctx.destination);
  o.start(ctx.currentTime + t0);
  o.stop(ctx.currentTime + t0 + dur + 0.05);
}
function rumore(t0, dur, vol = 0.3, filtro = 1200) {
  if (!ctx || !audioAttivo) return;
  const n = ctx.sampleRate * dur, b = ctx.createBuffer(1, n, ctx.sampleRate), d = b.getChannelData(0);
  for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
  const s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
  s.buffer = b; f.type = 'lowpass'; f.frequency.value = filtro; g.gain.value = vol;
  s.connect(f).connect(g).connect(ctx.destination);
  s.start(ctx.currentTime + t0);
}

let galoppoInt = null;
function zoccolo(t0, vol = 0.22) { rumore(t0, 0.05, vol, 1800); nota(180, t0, 0.06, 'triangle', vol * 0.9, 90); }
export const SUONI = {
  martello() { rumore(0, 0.12, 0.6, 900); nota(140, 0, 0.15, 'triangle', 0.4, 60); },
  moneta() { nota(1320, 0, 0.08, 'square', 0.06); nota(1760, 0.07, 0.18, 'square', 0.06); },
  tick() { nota(1000, 0, 0.04, 'square', 0.04); },
  ding() { nota(1175, 0, 0.25, 'sine', 0.18); nota(1568, 0.1, 0.35, 'sine', 0.14); },
  click() { nota(700, 0, 0.05, 'triangle', 0.1); },
  dado() { rumore(0, 0.05, 0.25, 3500); nota(300 + Math.random() * 300, 0, 0.04, 'square', 0.03); },
  verde() { [660, 880, 1320].forEach((f, i) => nota(f, i * 0.08, 0.18, 'triangle', 0.12)); },
  preso() { nota(523, 0, 0.08, 'square', 0.08); nota(1046, 0.06, 0.15, 'square', 0.08); },
  token() { nota(400, 0, 0.3, 'sine', 0.12, 1200); nota(1500, 0.25, 0.2, 'triangle', 0.1); },
  gira() { rumore(0, 0.08, 0.2, 4000); },
  ahi() { nota(500, 0, 0.5, 'sawtooth', 0.08, 150); },
  sparo() { rumore(0, 0.35, 0.8, 2500); nota(90, 0, 0.3, 'triangle', 0.4, 40); },
  tromba() {
    // la chiamata al canapo: ta-ta-ta-taaa
    const s = [[392, 0.16], [523, 0.16], [659, 0.16], [784, 0.4], [659, 0.16], [784, 0.7]];
    let t = 0;
    for (const [f, d] of s) { nota(f, t, d, 'sawtooth', 0.06); nota(f * 2, t, d, 'square', 0.02); t += d + 0.03; }
  },
  vittoria() {
    const s = [523, 659, 784, 1047, 784, 1047];
    s.forEach((f, i) => nota(f, i * 0.13, i === 5 ? 0.6 : 0.16, 'square', 0.07));
    rumore(0.8, 1.6, 0.12, 1500);
  },
  peccato() { nota(392, 0, 0.25, 'sawtooth', 0.07); nota(370, 0.25, 0.25, 'sawtooth', 0.07); nota(349, 0.5, 0.25, 'sawtooth', 0.07); nota(330, 0.75, 0.6, 'sawtooth', 0.07, 300); },
  galoppo_via() {
    clearInterval(galoppoInt);
    const passo = () => { zoccolo(0); zoccolo(0.09, 0.16); zoccolo(0.17, 0.2); };
    passo();
    galoppoInt = setInterval(passo, 360);
  },
  galoppo_stop() { clearInterval(galoppoInt); galoppoInt = null; },
};
export function suona(n) { try { SUONI[n]?.(); } catch (e) { /* ok */ } }

// ------------------------------------------------------------- voce
// Le voci sono quelle del dispositivo: su iPad conviene scaricare una voce "Premium" o "Avanzata"
// (Impostazioni > Accessibilità > Contenuti letti ad alta voce > Voci > Italiano), su Windows/Edge le
// voci "Online (Natural)" di Microsoft, su Chrome "Google italiano".
let voce = null;
let sceltaNome = '';
let velVoce = 1.0, tonoVoce = 1.0;
export let voceAttiva = true;
export function setVoce(v) { voceAttiva = v; if (!v) try { speechSynthesis.cancel(); } catch (e) { /* ok */ } }

// punteggio: più alto = voce più naturale
function qualita(v) {
  const n = v.name.toLowerCase();
  let q = 0;
  if (/premium/.test(n)) q += 50;
  if (/natural|neural|online/.test(n)) q += 45;
  if (/enhanced|avanzat|migliorat|ottimizzat/.test(n)) q += 35;
  if (/google/.test(n)) q += 20;
  if (/compact|eloquence|espeak|bad|grandpa|grandma|nonn|rocko|reed|sandy|shelley|flo|eddy/.test(n)) q -= 40;
  if (/luca|diego|giuseppe|cosimo|paolo/.test(n)) q += 6; // voci maschili, come il cronista
  if (v.localService === false) q += 4;
  if ((v.lang || '').toLowerCase() === 'it-it') q += 2;
  return q;
}
export function elencoVoci() {
  try {
    return speechSynthesis.getVoices()
      .filter((v) => v.lang && v.lang.toLowerCase().startsWith('it'))
      .sort((a, b) => qualita(b) - qualita(a) || a.name.localeCompare(b.name));
  } catch (e) { return []; }
}
function scegliVoce() {
  const vs = elencoVoci();
  voce = vs.find((v) => v.name === sceltaNome) || vs[0] || null;
  dispatchEvent(new Event('voci-cambiate'));
}
export function impostaVoce({ nome, vel, tono } = {}) {
  if (nome !== undefined) sceltaNome = nome;
  if (vel) velVoce = vel;
  if (tono) tonoVoce = tono;
  scegliVoce();
}
export function voceInUso() { return voce ? voce.name : ''; }
if (typeof speechSynthesis !== 'undefined') {
  scegliVoce();
  speechSynthesis.onvoiceschanged = scegliVoce;
}
export function sbloccaVoce() {
  try { const u = new SpeechSynthesisUtterance(' '); u.volume = 0; speechSynthesis.speak(u); } catch (e) { /* ok */ }
}
// Parla e risolve quando ha finito (o dopo una stima, se il browser non avvisa)
export function parla(testo, { interrompi = false } = {}) {
  return new Promise((ok) => {
    const stima = 600 + testo.length * 62;
    if (!voceAttiva || typeof speechSynthesis === 'undefined' || ACCEL > 1) { setTimeout(ok, Math.min(stima, 2600) / ACCEL); return; }
    try {
      if (interrompi) speechSynthesis.cancel();
      const u = new SpeechSynthesisUtterance(testo);
      u.lang = voce?.lang || 'it-IT';
      if (voce) u.voice = voce;
      u.rate = velVoce; u.pitch = tonoVoce;
      let fatto = false;
      const fine = () => { if (!fatto) { fatto = true; ok(); } };
      u.onend = fine; u.onerror = fine;
      setTimeout(fine, stima / velVoce + 2500);
      speechSynthesis.speak(u);
    } catch (e) { setTimeout(ok, stima); }
  });
}
export function zitto() { try { speechSynthesis.cancel(); } catch (e) { /* ok */ } }
