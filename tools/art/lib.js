// Helpers para generar arte SVG. Todo el arte del juego sale de tools/art/*.js
// (node tools/art/generate.js). Coordenadas en píxeles de mundo con el origen
// en el centro del lienzo; el SVG se rasteriza a RENDER_SCALE veces ese tamaño
// (nítido en pantallas densas) y en Godot se escala 1/RENDER_SCALE.

const fs = require('fs');
const path = require('path');

const RENDER_SCALE = 2;
const OUT = '#17121f'; // contorno oscuro común (mismo tono que el panel de la tienda)

const C = {
  steel: '#a9b4c0', steelLight: '#e1e9f0', steelDark: '#6d7885', steelDeep: '#48505c',
  gold: '#f2c14e', goldLight: '#ffe58f', goldDark: '#b5841f',
  wood: '#8a5a34', woodLight: '#b98250', woodDark: '#5a3620', woodDeep: '#3d2414',
  leather: '#84502b', leatherDark: '#5e381d',
  skin: '#f1c39b', skinDark: '#c98f68',
  green: '#5b9a45', greenLight: '#86c465', greenDark: '#356a2d', greenDeep: '#244a20',
  cream: '#f6efdc', creamDark: '#d3c7a6',
  stone: '#bdb7aa', stoneLight: '#dcd7cb', stoneDark: '#8f897e', stoneDeep: '#6a655c',
  slate: '#66707f', slateLight: '#8794a6', slateDark: '#454d5b',
  terracotta: '#c8683a', terracottaLight: '#e58a55', terracottaDark: '#8f4526',
  thatch: '#dcaa48', thatchLight: '#f3ce76', thatchDark: '#a8782a',
  white: '#ffffff',
};

function strokeAttrs(o) {
  if (o.noStroke) return '';
  const sw = o.sw === undefined ? 3 : o.sw;
  return ` stroke="${o.stroke || OUT}" stroke-width="${sw}" stroke-linejoin="round" stroke-linecap="round"`;
}
function extra(o) {
  let s = '';
  if (o.opacity !== undefined) s += ` opacity="${o.opacity}"`;
  if (o.transform) s += ` transform="${o.transform}"`;
  return s;
}
const n = (v) => Math.round(v * 100) / 100;

const path_ = (d, fill, o = {}) => `<path d="${d}" fill="${fill}"${strokeAttrs(o)}${extra(o)}/>`;
const circle = (cx, cy, r, fill, o = {}) => `<circle cx="${n(cx)}" cy="${n(cy)}" r="${n(r)}" fill="${fill}"${strokeAttrs(o)}${extra(o)}/>`;
const ellipse = (cx, cy, rx, ry, fill, o = {}) => `<ellipse cx="${n(cx)}" cy="${n(cy)}" rx="${n(rx)}" ry="${n(ry)}" fill="${fill}"${strokeAttrs(o)}${extra(o)}/>`;
const rect = (x, y, w, h, fill, o = {}) => `<rect x="${n(x)}" y="${n(y)}" width="${n(w)}" height="${n(h)}"${o.r ? ` rx="${o.r}"` : ''} fill="${fill}"${strokeAttrs(o)}${extra(o)}/>`;
const poly = (pts, fill, o = {}) => `<polygon points="${pts.map((p) => `${n(p[0])},${n(p[1])}`).join(' ')}" fill="${fill}"${strokeAttrs(o)}${extra(o)}/>`;
const line = (x1, y1, x2, y2, color, sw = 3, o = {}) => `<line x1="${n(x1)}" y1="${n(y1)}" x2="${n(x2)}" y2="${n(y2)}" stroke="${color}" stroke-width="${sw}" stroke-linecap="${o.cap || 'round'}"${extra(o)}/>`;
const g = (children, o = {}) => `<g${extra(o)}>${Array.isArray(children) ? children.join('') : children}</g>`;
const rot = (deg, cx = 0, cy = 0) => `rotate(${n(deg)} ${n(cx)} ${n(cy)})`;
const tr = (x, y, s = 1, deg = 0) => `translate(${n(x)} ${n(y)})${deg ? ` rotate(${n(deg)})` : ''}${s !== 1 ? ` scale(${s})` : ''}`;

/** Extremidad con contorno: una línea gruesa oscura y encima el color. */
function limb(x1, y1, x2, y2, w, color) {
  return line(x1, y1, x2, y2, OUT, w + 5) + line(x1, y1, x2, y2, color, w);
}

/** Estrella de brillo de 4 puntas. */
function sparkle(x, y, r, color = '#ffffff', opacity = 1) {
  const k = r * 0.28;
  return `<path d="M${n(x)} ${n(y - r)} L${n(x + k)} ${n(y - k)} L${n(x + r)} ${n(y)} L${n(x + k)} ${n(y + k)} L${n(x)} ${n(y + r)} L${n(x - k)} ${n(y + k)} L${n(x - r)} ${n(y)} L${n(x - k)} ${n(y - k)} Z" fill="${color}" opacity="${opacity}"/>`;
}

function defsGradient(id, stops, kind = 'linear', attrs = 'x1="0" y1="0" x2="0" y2="1"') {
  const s = stops.map(([off, col, op]) => `<stop offset="${off}" stop-color="${col}"${op !== undefined ? ` stop-opacity="${op}"` : ''}/>`).join('');
  return kind === 'linear'
    ? `<linearGradient id="${id}" ${attrs}>${s}</linearGradient>`
    : `<radialGradient id="${id}" ${attrs}>${s}</radialGradient>`;
}

/** Documento SVG centrado en el origen. w×h en px de mundo. */
function doc(w, h, body, defs = '', scale = RENDER_SCALE) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w * scale}" height="${h * scale}" viewBox="${-w / 2} ${-h / 2} ${w} ${h}">${defs ? `<defs>${defs}</defs>` : ''}${body}</svg>\n`;
}
/** Documento SVG con el origen en la esquina superior izquierda. */
function docTL(w, h, body, defs = '', scale = RENDER_SCALE) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w * scale}" height="${h * scale}" viewBox="0 0 ${w} ${h}">${defs ? `<defs>${defs}</defs>` : ''}${body}</svg>\n`;
}

// --- Aleatorio determinista -------------------------------------------------
function rng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  next.range = (lo, hi) => lo + (hi - lo) * next();
  next.pick = (arr) => arr[Math.floor(next() * arr.length)];
  return next;
}

// --- Salida --------------------------------------------------------------
const ASSETS = path.resolve(__dirname, '..', '..', 'assets');
const written = [];
function write(rel, content) {
  const full = path.join(ASSETS, rel);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, content);
  written.push(rel);
}

module.exports = {
  RENDER_SCALE, OUT, C, n, path: path_, circle, ellipse, rect, poly, line, g, rot, tr, limb, sparkle,
  defsGradient, doc, docTL, rng, write, written, ASSETS,
};

// Recursos de datos (.tres) fuera de assets/.
const ROOT = path.resolve(__dirname, '..', '..');
function writeData(rel, content) {
  const full = path.join(ROOT, rel);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, content);
  written.push(rel);
}

/** SpriteFrames .tres. anims: [{name, frames:[res:// paths], speed, loop}] */
function spriteFramesTres(anims) {
  const ids = new Map();
  let ext = '';
  for (const a of anims) {
    for (const f of a.frames) {
      if (!ids.has(f)) {
        const id = `${ids.size + 1}_${path.basename(f, path.extname(f)).replace(/\W/g, '')}`;
        ids.set(f, id);
        ext += `[ext_resource type="Texture2D" path="${f}" id="${id}"]\n`;
      }
    }
  }
  const animText = anims.map((a) => {
    const frames = a.frames.map((f) => `{\n"duration": 1.0,\n"texture": ExtResource("${ids.get(f)}")\n}`).join(', ');
    return `{\n"frames": [${frames}],\n"loop": ${a.loop ? 'true' : 'false'},\n"name": &"${a.name}",\n"speed": ${a.speed}\n}`;
  }).join(', ');
  return `[gd_resource type="SpriteFrames" load_steps=${ids.size + 1} format=3]\n\n${ext}\n[resource]\nanimations = [${animText}]\n`;
}
module.exports.writeData = writeData;
module.exports.spriteFramesTres = spriteFramesTres;
