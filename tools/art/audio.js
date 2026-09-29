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
  };
  for (const [name, samples] of Object.entries(files)) {
    fs.writeFileSync(path.join(dir, `${name}.wav`), wav(samples));
    L.written.push(`audio/${name}.wav`);
  }
}

module.exports = { generate };
