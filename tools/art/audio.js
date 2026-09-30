// Efectos de sonido mínimos generados por síntesis (sin dependencias):
// clic de botón, compra/confirmación y error. WAV mono 16 bit.

const L = require('./lib');
const fs = require('fs');
const path = require('path');

const RATE = 44100;

function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((v, i) => data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(v * 32767))), i * 2));
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

/** Tono con barrido de frecuencia y caída exponencial. */
function tone(dur, f0, f1, decay, gain = 1, seed = 1) {
  const n = Math.floor(dur * RATE);
  const out = new Array(n).fill(0);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const f = f0 + (f1 - f0) * Math.min(1, t / dur);
    phase += (2 * Math.PI * f) / RATE;
    const attack = Math.min(1, i / (RATE * 0.002));
    out[i] = Math.sin(phase) * Math.exp(-t * decay) * gain * attack;
  }
  return out;
}

function noiseClick(dur, gain, seed = 7) {
  const r = L.rng(seed);
  const n = Math.floor(dur * RATE);
  const out = new Array(n).fill(0);
  for (let i = 0; i < n; i++) out[i] = (r() * 2 - 1) * Math.exp(-(i / n) * 7) * gain;
  return out;
}

/** Ruido con envolvente rápida (soplido de espada). */
function sweptNoise(dur, gain, seed = 11) {
  const r = L.rng(seed);
  const n = Math.floor(dur * RATE);
  const out = new Array(n).fill(0);
  let lp = 0;
  for (let i = 0; i < n; i++) {
    const t = i / n;
    const k = 0.15 + 0.7 * t; // el filtro se abre: suena "ssshh" ascendente
    lp += ((r() * 2 - 1) - lp) * k;
    out[i] = lp * Math.sin(Math.PI * Math.pow(t, 0.6)) * gain;
  }
  return out;
}

/** Ruido grave (filtro paso bajo fuerte) con caída: retumbar de trueno, golpe de castillo. */
function rumble(dur, gain, k = 0.04, decay = 5, seed = 21) {
  const r = L.rng(seed);
  const n = Math.floor(dur * RATE);
  const out = new Array(n).fill(0);
  let lp = 0;
  for (let i = 0; i < n; i++) {
    lp += ((r() * 2 - 1) - lp) * k;
    out[i] = lp * Math.exp(-(i / RATE) * decay) * gain * 6;
  }
  return out;
}

/** Nota con armónicos (timbre de metal/trompeta) y ataque suave. */
function brass(dur, f, gain = 1, decay = 5) {
  const n = Math.floor(dur * RATE);
  const out = new Array(n).fill(0);
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const env = Math.min(1, t / 0.03) * Math.exp(-t * decay);
    const v = Math.sin(2 * Math.PI * f * t) + 0.5 * Math.sin(4 * Math.PI * f * t) + 0.3 * Math.sin(6 * Math.PI * f * t) + 0.15 * Math.sin(8 * Math.PI * f * t);
    out[i] = v * env * gain * 0.5;
  }
  return out;
}

/** "Boing" de muelle: tono con vibrato que se apaga. */
function boing(dur, f, gain = 1) {
  const n = Math.floor(dur * RATE);
  const out = new Array(n).fill(0);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const freq = f * (1 + 0.55 * Math.exp(-t * 9) * Math.sin(2 * Math.PI * 11 * t));
    phase += (2 * Math.PI * freq) / RATE;
    out[i] = Math.sin(phase) * Math.exp(-t * 11) * gain * Math.min(1, i / (RATE * 0.003));
  }
  return out;
}

function mix(...tracks) {
  const n = Math.max(...tracks.map((t) => t.length));
  const out = new Array(n).fill(0);
  for (const t of tracks) for (let i = 0; i < t.length; i++) out[i] += t[i];
  const peak = Math.max(1, ...out.map(Math.abs));
  return out.map((v) => (v / peak) * 0.8);
}

function delayed(track, seconds) {
  return new Array(Math.floor(seconds * RATE)).fill(0).concat(track);
}

function generate() {
  const dir = path.join(L.ASSETS, 'audio');
  fs.mkdirSync(dir, { recursive: true });
  const files = {
    // "toc" de madera: golpe grave corto + chasquido
    click: mix(tone(0.11, 520, 210, 34, 0.9), noiseClick(0.012, 0.5)),
    // tajo: soplido de ruido que sube de tono + chasquido
    slash: mix(sweptNoise(0.13, 0.9), tone(0.09, 900, 260, 40, 0.5), noiseClick(0.008, 0.6, 3)),
    // confirmación: dos notas ascendentes
    confirm: mix(tone(0.16, 660, 660, 16, 0.7), delayed(tone(0.2, 990, 990, 14, 0.7), 0.07), noiseClick(0.01, 0.3)),
    // error: dos golpes graves descendentes
    error: mix(tone(0.14, 200, 150, 18, 0.9), delayed(tone(0.18, 160, 110, 16, 0.9), 0.09)),
    // --- Combate ---
    // flecha: cuerda de arco + soplido
    arrow: mix(tone(0.14, 340, 110, 26, 0.7), sweptNoise(0.09, 0.5, 5), noiseClick(0.006, 0.4, 9)),
    // impacto: golpe sordo
    hit: mix(tone(0.1, 190, 70, 38, 0.9), noiseClick(0.02, 0.5, 4)),
    // unidad que cae
    death: mix(tone(0.24, 240, 55, 13, 0.8), sweptNoise(0.12, 0.35, 13)),
    // golpe al castillo: piedra pesada
    castle: mix(tone(0.4, 95, 38, 8, 1), rumble(0.5, 0.7, 0.06, 7), noiseClick(0.03, 0.6, 6)),
    // --- Edificios ---
    // rebote al producir: muelle
    boing: mix(boing(0.32, 250, 0.9), noiseClick(0.008, 0.3, 2)),
    // --- Habilidades ---
    // lluvia de flechas: varias andanadas seguidas
    rain: mix(sweptNoise(0.18, 0.6, 31), delayed(sweptNoise(0.16, 0.55, 32), 0.14), delayed(sweptNoise(0.16, 0.5, 33), 0.3), delayed(sweptNoise(0.2, 0.55, 34), 0.46), delayed(tone(0.1, 300, 120, 28, 0.35), 0.5)),
    // rayo: chasquido + trueno
    thunder: mix(noiseClick(0.09, 1, 41), tone(0.16, 1400, 300, 30, 0.35), delayed(rumble(0.8, 0.9, 0.035, 4, 42), 0.02)),
    // milicias: cuerno de llamada
    horn: mix(brass(0.28, 262, 0.9, 6), delayed(brass(0.5, 392, 0.9, 4.5), 0.2), delayed(sweptNoise(0.1, 0.12, 3), 0.02)),
    // --- Cuenta atrás 3 · 2 · 1: golpe de tambor de guerra, igual en los tres números ---
    drum: mix(tone(0.34, 125, 46, 12, 1), tone(0.07, 270, 95, 48, 0.55), tone(0.42, 62, 44, 7, 0.55), noiseClick(0.012, 0.32, 21)),
    // --- Interfaz ---
    // globito de emote
    pop: mix(tone(0.09, 480, 980, 28, 0.9), noiseClick(0.008, 0.25, 8)),
    // risa de goblin: cuatro "je" cada vez más agudos y cortos
    laugh: mix(tone(0.09, 420, 330, 22, 0.8), delayed(tone(0.09, 470, 360, 22, 0.8), 0.12), delayed(tone(0.09, 520, 400, 22, 0.8), 0.24), delayed(tone(0.13, 560, 380, 16, 0.8), 0.36), noiseClick(0.02, 0.15, 12)),
    // unidad desbloqueada: arpegio ascendente
    unlock: mix(tone(0.14, 523, 523, 12, 0.7), delayed(tone(0.14, 659, 659, 12, 0.7), 0.08), delayed(tone(0.14, 784, 784, 12, 0.7), 0.16), delayed(tone(0.3, 1047, 1047, 8, 0.8), 0.24)),
    // victoria: fanfarria
    win: mix(brass(0.2, 392, 0.9, 5), delayed(brass(0.2, 523, 0.9, 5), 0.18), delayed(brass(0.2, 659, 0.9, 5), 0.36), delayed(brass(0.7, 784, 1, 3), 0.54)),
    // derrota: notas que caen
    lose: mix(brass(0.3, 330, 0.8, 5), delayed(brass(0.3, 294, 0.8, 5), 0.3), delayed(brass(0.3, 262, 0.8, 5), 0.6), delayed(brass(0.8, 196, 0.9, 3), 0.9)),
  };
  for (const [name, samples] of Object.entries(files)) {
    fs.writeFileSync(path.join(dir, `${name}.wav`), wav(samples));
    L.written.push(`audio/${name}.wav`);
  }
}

module.exports = { generate };
