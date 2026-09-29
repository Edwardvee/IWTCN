// Estructuras vistas en 3/4 desde delante (diseño estructural al estilo de los
// edificios de Warcraft 3: casas con tejado grande, cuartel de piedra y madera,
// torre de guardia, capilla con aguja) pero con el trazo grueso del resto del arte.
// Cada estructura genera dos SVG: el edificio y una capa "_team" en blanco/gris
// que el juego tiñe con el color del bando (banderas, estandartes, toldos).

const L = require('./lib');
const { withRace, recolor } = require('./races');
const { C, OUT, ellipse, circle, path, rect, poly, line, g, rot, tr, sparkle, doc } = L;

const W = 150;
const H = 160;

const TEAM_LIGHT = '#f4f4f4';
const TEAM_MID = '#cfcfcf';
const TEAM_DARK = '#a3a3a3';

function shadow(rx = 60, y = 62) {
  return ellipse(0, y, rx, 11, '#000000', { noStroke: true, opacity: 0.26 });
}

/** Hiladas de ladrillo/piedra dentro de un rectángulo. */
function bricks(x, y, w, h, opts = {}) {
  const rowH = opts.rowH || 9;
  const brickW = opts.brickW || 16;
  const color = opts.color || C.stoneDeep;
  const out = [];
  let row = 0;
  for (let yy = y + rowH; yy < y + h - 1; yy += rowH, row++) {
    out.push(line(x + 1, yy, x + w - 1, yy, color, 1.4, { opacity: 0.55 }));
    for (let xx = x + (row % 2 ? brickW / 2 : brickW); xx < x + w - 2; xx += brickW) {
      out.push(line(xx, yy - rowH, xx, yy, color, 1.4, { opacity: 0.55 }));
    }
  }
  return out.join('');
}

/** Almenas a lo largo de x0..x1 sobre la línea y. */
function crenellations(x0, x1, y, fill = C.stone, merlonW = 9, merlonH = 9, gap = 6) {
  const out = [];
  for (let x = x0; x + merlonW <= x1 + 0.1; x += merlonW + gap) {
    out.push(rect(x, y - merlonH, merlonW, merlonH + 2, fill, { r: 1 }));
    out.push(rect(x + 1.5, y - merlonH + 1.5, merlonW * 0.35, merlonH - 2, C.stoneLight, { noStroke: true, opacity: 0.6 }));
  }
  return out.join('');
}

function shingleLines(pts, rows, color, opacity = 0.35) {
  // pts: [[xl_top,yt],[xr_top,yt],[xr_bot,yb],[xl_bot,yb]] trapecio del tejado
  const [tl, tr_, br, bl] = pts;
  const out = [];
  for (let i = 1; i < rows; i++) {
    const t = i / rows;
    const yl = tl[1] + (bl[1] - tl[1]) * t;
    const xl = tl[0] + (bl[0] - tl[0]) * t;
    const xr = tr_[0] + (br[0] - tr_[0]) * t;
    out.push(line(xl, yl, xr, yl, color, 1.6, { opacity }));
    // muescas alternas
    const step = 11;
    for (let x = xl + (i % 2 ? step / 2 : step); x < xr - 2; x += step) out.push(line(x, yl - (bl[1] - tl[1]) / rows, x, yl, color, 1.4, { opacity: opacity * 0.9 }));
  }
  return out.join('');
}

function pennant(x, y, len = 22, h = 13, o = {}) {
  const pole = o.pole === undefined ? 26 : o.pole;
  return [
    line(x, y, x, y - pole, OUT, 5),
    line(x, y, x, y - pole, C.woodLight, 2.4),
    circle(x, y - pole - 1, 2.6, C.gold, { sw: 1.5 }),
    path(`M${x} ${y - pole + 2} Q${x + len * 0.55} ${y - pole - 2} ${x + len} ${y - pole + h * 0.5} Q${x + len * 0.55} ${y - pole + h * 0.8} ${x} ${y - pole + h}Z`, TEAM_LIGHT),
    path(`M${x} ${y - pole + h * 0.55} Q${x + len * 0.55} ${y - pole + h * 0.4} ${x + len} ${y - pole + h * 0.5} Q${x + len * 0.55} ${y - pole + h * 0.8} ${x} ${y - pole + h}Z`, TEAM_MID, { noStroke: true, opacity: 0.85 }),
  ].join('');
}

/** Estandarte colgante con pico. */
function banner(x, y, w = 14, h = 30) {
  return [
    rect(x - w / 2 - 2, y - 3, w + 4, 4, C.woodDark, { r: 1.5, sw: 2 }),
    path(`M${x - w / 2} ${y} L${x + w / 2} ${y} L${x + w / 2} ${y + h} L${x} ${y + h - 7} L${x - w / 2} ${y + h}Z`, TEAM_LIGHT),
    path(`M${x} ${y} L${x + w / 2} ${y} L${x + w / 2} ${y + h} L${x} ${y + h - 7}Z`, TEAM_MID, { noStroke: true, opacity: 0.9 }),
    circle(x, y + h * 0.36, w * 0.17, TEAM_DARK, { noStroke: true, opacity: 0.8 }),
  ].join('');
}

function door(x, y, w, h, fill = C.wood, arched = true) {
  const r = w / 2;
  const d = arched
    ? `M${x - r} ${y + h} L${x - r} ${y + r} Q${x} ${y - r * 0.6} ${x + r} ${y + r} L${x + r} ${y + h}Z`
    : `M${x - r} ${y + h} L${x - r} ${y} L${x + r} ${y} L${x + r} ${y + h}Z`;
  return [
    path(d, fill),
    line(x, y + 2, x, y + h, C.woodDark, 1.6, { opacity: 0.9 }),
    line(x - r + 1, y + h * 0.42, x + r - 1, y + h * 0.42, C.steelDark, 2.4),
    line(x - r + 1, y + h * 0.78, x + r - 1, y + h * 0.78, C.steelDark, 2.4),
    circle(x - 3, y + h * 0.58, 1.4, C.gold, { noStroke: true }), circle(x + 3, y + h * 0.58, 1.4, C.gold, { noStroke: true }),
  ].join('');
}

function windowSquare(x, y, s = 12, shutter = C.woodDark) {
  return [
    rect(x - s / 2 - 4, y - s / 2, 4, s, shutter, { sw: 1.8 }),
    rect(x + s / 2, y - s / 2, 4, s, shutter, { sw: 1.8 }),
    rect(x - s / 2, y - s / 2, s, s, '#ffe9a8', { sw: 2 }),
    line(x, y - s / 2, x, y + s / 2, C.woodDark, 1.4), line(x - s / 2, y, x + s / 2, y, C.woodDark, 1.4),
  ].join('');
}

// --- Granja: cabaña de paja, chimenea y campo de trigo ------------------------
function farm() {
  const b = [];
  b.push(shadow(64));
  // campo de trigo delantero
  b.push(ellipse(-32, 52, 34, 11, '#7a5230', { sw: 2.5 }));
  b.push(ellipse(-32, 50, 30, 8, '#8f6238', { noStroke: true }));
  for (let i = 0; i < 9; i++) {
    const x = -54 + i * 7.2;
    const y = 50 + (i % 2) * 2.5;
    b.push(line(x, y, x - 1, y - 14, C.thatchDark, 1.6));
    b.push(path(`M${x - 1} ${y - 14} q-3 -4 0 -9 q3 5 0 9`, C.thatchLight, { sw: 1.4 }));
    b.push(path(`M${x - 1} ${y - 11} q-4 -1 -3 -6 q4 2 3 6`, C.thatch, { sw: 1.2 }));
  }
  // haces de heno redondos
  b.push(circle(50, 52, 10, C.thatch, { sw: 2.5 }));
  b.push(circle(50, 52, 6, C.thatchLight, { noStroke: true }));
  b.push(circle(50, 52, 2.5, C.thatchDark, { noStroke: true }));
  // paredes
  b.push(rect(-34, 4, 68, 52, C.cream, { r: 2 }));
  b.push(rect(-34, 4, 68, 52, C.creamDark, { noStroke: true, opacity: 0.0 }));
  b.push(path('M14 4 L34 4 L34 56 L14 56Z', C.creamDark, { noStroke: true, opacity: 0.5 }));
  b.push(rect(-36, 44, 72, 14, C.stone, { r: 2 }));
  b.push(bricks(-36, 44, 72, 14, { rowH: 7, brickW: 12 }));
  b.push(rect(-34, 4, 5, 40, C.woodDark, { noStroke: true }), rect(29, 4, 5, 40, C.woodDark, { noStroke: true }));
  b.push(line(-34, 22, 34, 22, C.woodDark, 3.5));
  b.push(door(0, 28, 17, 27));
  b.push(windowSquare(-22, 34, 10));
  b.push(windowSquare(22, 34, 10));
  // chimenea
  b.push(rect(20, -32, 13, 30, C.stone, { r: 1.5 }));
  b.push(bricks(20, -32, 13, 30, { rowH: 6, brickW: 7 }));
  b.push(rect(18, -35, 17, 6, C.stoneDark, { r: 1.5 }));
  b.push(circle(27, -46, 5, '#ffffff', { noStroke: true, opacity: 0.55 }), circle(32, -56, 4, '#ffffff', { noStroke: true, opacity: 0.4 }));
  // tejado de paja
  b.push(path('M-52 16 Q-42 -6 -26 -34 L26 -34 Q42 -6 52 16 Q0 25 -52 16Z', C.thatch));
  b.push(path('M-26 -34 L26 -34 Q34 -20 40 -6 Q0 -12 -40 -6 Q-34 -20 -26 -34Z', C.thatchLight, { noStroke: true, opacity: 0.7 }));
  b.push(path('M-52 16 Q0 25 52 16 Q0 20 -52 16Z', C.thatchDark, { noStroke: true }));
  for (let i = -3; i <= 3; i++) b.push(line(i * 12, -30 + Math.abs(i) * 2, i * 15, 16 + 3 - Math.abs(i) * 0.7, C.thatchDark, 1.6, { opacity: 0.7 }));
  b.push(path('M-24 -32 L24 -32', 'none', { stroke: C.thatchDark, sw: 4 }));
  // ventanita en el frontón
  b.push(circle(0, -14, 6, '#ffe9a8', { sw: 2.2 }), line(0, -20, 0, -8, C.woodDark, 1.5), line(-6, -14, 6, -14, C.woodDark, 1.5));

  const t = [];
  // toldo a rayas sobre la puerta y banderín en la cumbrera
  t.push(path('M-13 22 L13 22 L16 28 L-16 28Z', TEAM_LIGHT));
  t.push(path('M-3 22 L3 22 L4 28 L-4 28Z', TEAM_DARK, { noStroke: true, opacity: 0.6 }));
  t.push(path('M-13 22 L-7 22 L-9 28 L-16 28Z', TEAM_MID, { noStroke: true, opacity: 0.8 }));
  t.push(pennant(-30, -22, 24, 14, { pole: 26 }));
  return { base: g(b), team: g(t) };
}

// --- Cuartel de soldados: edificio de piedra con tejado de pizarra ---------------------
function soldierBarracks() {
  const b = [];
  b.push(shadow(68));
  // muros de piedra
  b.push(rect(-56, -2, 112, 58, C.stone, { r: 2 }));
  b.push(bricks(-56, -2, 112, 58, { rowH: 9, brickW: 17 }));
  b.push(path('M30 -2 L56 -2 L56 56 L30 56Z', C.stoneDark, { noStroke: true, opacity: 0.35 }));
  // vigas de madera
  for (const x of [-56, -18, 18, 54]) b.push(rect(x - 3, -2, 6, 58, C.woodDark, { noStroke: true }));
  b.push(rect(-58, 44, 116, 13, C.stoneDark, { r: 2 }));
  b.push(bricks(-58, 44, 116, 13, { rowH: 6.5, brickW: 13 }));
  // puerta doble arqueada con luz
  b.push(path('M-16 56 L-16 30 Q0 10 16 30 L16 56Z', '#2b1c12'));
  b.push(door(0, 27, 26, 29));
  b.push(path('M-16 56 L-16 30 Q0 10 16 30 L16 56Z', 'none', { stroke: C.stoneDeep, sw: 4.5 }));
  // ventanas y antorchas
  for (const x of [-38, 38]) {
    b.push(rect(x - 6, 16, 12, 16, '#ffdc8a', { r: 6, sw: 2.4 }));
    b.push(line(x, 16, x, 32, C.woodDark, 1.6));
  }
  for (const x of [-25, 25]) {
    b.push(line(x, 36, x, 44, C.woodDark, 3.5));
    b.push(path(`M${x} 34 Q${x - 5} 27 ${x} 20 Q${x + 5} 27 ${x} 34Z`, '#ff9c2f', { sw: 1.6 }));
    b.push(path(`M${x} 33 Q${x - 2} 28 ${x} 24 Q${x + 2} 28 ${x} 33Z`, '#ffe36b', { noStroke: true }));
  }
  // escudo y espadas cruzadas sobre la puerta
  b.push(path('M-8 3 L8 3 L8 15 Q0 21 -8 15Z', C.steelLight, { sw: 2.2 }));
  b.push(line(-6, 5, 6, 15, C.steelDark, 2), line(6, 5, -6, 15, C.steelDark, 2));
  // tejado de pizarra
  b.push(path('M-66 4 L-46 -40 L46 -40 L66 4 Q0 12 -66 4Z', C.slate));
  b.push(path('M-46 -40 L46 -40 L52 -27 L-52 -27Z', C.slateLight, { noStroke: true, opacity: 0.55 }));
  b.push(shingleLines([[-46, -40], [46, -40], [66, 4], [-66, 4]], 5, C.slateDark, 0.55));
  b.push(path('M-66 4 Q0 12 66 4 Q0 8 -66 4Z', C.slateDark, { noStroke: true }));
  b.push(path('M-46 -40 L46 -40', 'none', { stroke: C.slateDark, sw: 5 }));
  // remate dorado
  b.push(rect(-8, -46, 16, 8, C.gold, { r: 2, sw: 2 }));
  // rejilla de armas a la izquierda
  b.push(line(-92, 50, -92, 54, OUT, 0));
  const t = [];
  t.push(banner(-42, 6, 16, 32));
  t.push(banner(42, 6, 16, 32));
  t.push(pennant(0, -46, 26, 15, { pole: 24 }));
  return { base: g(b), team: g(t) };
}

// --- Cuartel de arqueros: cabaña de troncos con diana ----------------------------------
function archerBarracks() {
  const b = [];
  b.push(shadow(66));
  // troncos horizontales
  b.push(rect(-46, 0, 92, 58, C.woodLight, { r: 3 }));
  for (let y = 8; y < 56; y += 9) {
    b.push(line(-45, y, 45, y, C.woodDark, 2, { opacity: 0.85 }));
    b.push(circle(-46, y - 4.5, 4.4, C.woodLight, { sw: 1.8 }));
    b.push(circle(46, y - 4.5, 4.4, C.woodLight, { sw: 1.8 }));
    b.push(circle(-46, y - 4.5, 1.6, C.woodDark, { noStroke: true, opacity: 0.8 }));
    b.push(circle(46, y - 4.5, 1.6, C.woodDark, { noStroke: true, opacity: 0.8 }));
  }
  b.push(path('M24 0 L46 0 L46 58 L24 58Z', C.woodDark, { noStroke: true, opacity: 0.35 }));
  b.push(rect(-46, 50, 92, 8, C.stoneDark, { r: 2 }));
  // puerta con arco
  b.push(path('M-11 58 L-11 30 Q0 18 11 30 L11 58Z', C.woodDark));
  b.push(path('M-8 58 L-8 32 Q0 23 8 32 L8 58Z', '#22140c', { noStroke: true }));
  // arcos colgados
  for (const x of [-32, 32]) {
    b.push(path(`M${x - 5} 18 Q${x + 9} 34 ${x - 5} 50`, 'none', { stroke: OUT, sw: 6 }));
    b.push(path(`M${x - 5} 18 Q${x + 9} 34 ${x - 5} 50`, 'none', { stroke: C.woodLight, sw: 3 }));
    b.push(line(x - 5, 18, x - 5, 50, '#f3ead2', 1.3));
  }
  // diana con flechas a la derecha
  b.push(line(56, 60, 56, 40, OUT, 7), line(56, 60, 56, 40, C.woodDark, 3.5));
  b.push(line(48, 60, 64, 60, OUT, 6), line(48, 60, 64, 60, C.woodDark, 3));
  b.push(circle(56, 28, 15, '#f6f0dc', { sw: 3 }));
  b.push(circle(56, 28, 11, '#d9483b', { noStroke: true }));
  b.push(circle(56, 28, 7, '#f6f0dc', { noStroke: true }));
  b.push(circle(56, 28, 3.5, '#d9483b', { noStroke: true }));
  b.push(line(53, 30, 41, 24, C.woodDark, 2), poly([[41, 24], [38, 21], [39, 27]], '#d9483b', { noStroke: true }));
  // tejado de tablillas de madera, empinado
  b.push(path('M-58 6 L-40 -38 L40 -38 L58 6 Q0 14 -58 6Z', '#7d5a3a'));
  b.push(path('M-40 -38 L40 -38 L46 -26 L-46 -26Z', '#a67a4d', { noStroke: true, opacity: 0.6 }));
  b.push(shingleLines([[-40, -38], [40, -38], [58, 6], [-58, 6]], 5, '#4c3320', 0.6));
  b.push(path('M-58 6 Q0 14 58 6 Q0 10 -58 6Z', '#4c3320', { noStroke: true }));
  b.push(path('M-40 -38 L40 -38', 'none', { stroke: '#4c3320', sw: 5 }));
  // musgo/hojas en el tejado
  b.push(ellipse(-24, -10, 10, 4, C.green, { noStroke: true, opacity: 0.55 }), ellipse(20, -20, 8, 3.5, C.greenLight, { noStroke: true, opacity: 0.5 }));
  // arbusto lateral
  b.push(circle(-58, 52, 9, C.green, { sw: 2.4 }), circle(-52, 48, 7, C.greenLight, { sw: 2 }));
  const t = [];
  t.push(banner(0, -2, 15, 22));
  t.push(pennant(-40, -30, 24, 14, { pole: 22 }));
  t.push(pennant(40, -30, 24, 14, { pole: 22 }));
  return { base: g(b), team: g(t) };
}

// --- Iglesia: capilla blanca con aguja dorada y vidriera ------------------------------------
function church() {
  const b = [];
  b.push(shadow(64));
  // alas laterales
  for (const s of [-1, 1]) {
    b.push(rect(s > 0 ? 20 : -50, 12, 30, 44, C.cream, { r: 2 }));
    b.push(bricks(s > 0 ? 20 : -50, 12, 30, 44, { rowH: 8, brickW: 12, color: C.creamDark }));
    b.push(path(`M${s * 20} 16 L${s * 36} -8 L${s * 50 + s * 6} 16Z`, '#9c5a48'));
    b.push(path(`M${s * 20} 16 L${s * 36} -8 L${s * 36} 16Z`, '#7f4536', { noStroke: true, opacity: 0.4 }));
    b.push(rect(s * 35 - 4.5, 26, 9, 15, '#8fd3ff', { r: 4.5, sw: 2.2 }));
  }
  // nave central
  b.push(rect(-24, -8, 48, 66, C.cream, { r: 2 }));
  b.push(bricks(-24, -8, 48, 66, { rowH: 9, brickW: 14, color: C.creamDark }));
  b.push(path('M6 -8 L24 -8 L24 58 L6 58Z', C.creamDark, { noStroke: true, opacity: 0.45 }));
  // contrafuertes
  for (const x of [-26, 26]) b.push(rect(x - 3, 8, 6, 50, C.stone, { r: 1.5, sw: 2.2 }));
  // puerta ojival con luz cálida
  b.push(path('M-11 58 L-11 34 Q0 14 11 34 L11 58Z', '#ffe08a'));
  b.push(path('M-11 58 L-11 34 Q0 14 11 34 L11 58Z', 'none', { stroke: C.goldDark, sw: 4 }));
  b.push(line(0, 24, 0, 58, C.goldDark, 2.4));
  b.push(path('M-11 44 L11 44', 'none', { stroke: C.goldDark, sw: 2 }));
  // rosetón
  b.push(circle(0, 8, 10, '#5fb0e8', { sw: 3 }));
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    b.push(line(0, 8, Math.cos(a) * 10, 8 + Math.sin(a) * 10, C.goldDark, 1.4));
  }
  b.push(circle(0, 8, 3.4, '#ffe58f', { sw: 1.6 }));
  // aguja/campanario
  b.push(rect(-15, -44, 30, 36, C.cream, { r: 2 }));
  b.push(bricks(-15, -44, 30, 36, { rowH: 8, brickW: 11, color: C.creamDark }));
  b.push(path('M4 -44 L15 -44 L15 -8 L4 -8Z', C.creamDark, { noStroke: true, opacity: 0.45 }));
  b.push(path('M-7 -14 L-7 -30 Q0 -40 7 -30 L7 -14Z', '#2b1c12'));
  b.push(circle(0, -24, 3.5, C.gold, { sw: 1.6 }));
  // cono dorado
  b.push(path('M-19 -42 L0 -70 L19 -42 Q0 -37 -19 -42Z', C.gold));
  b.push(path('M0 -70 L19 -42 Q10 -40 4 -40Z', C.goldDark, { noStroke: true, opacity: 0.7 }));
  b.push(path('M-11 -48 L-2 -63', 'none', { stroke: C.goldLight, sw: 3 }));
  // sol/cruz dorada
  b.push(line(0, -70, 0, -84, OUT, 6.5), line(-6, -78, 6, -78, OUT, 6.5));
  b.push(line(0, -70, 0, -84, C.goldLight, 3), line(-6, -78, 6, -78, C.goldLight, 3));
  // tejado de la nave
  b.push(path('M-32 -6 L-20 -20 L20 -20 L32 -6 Q0 0 -32 -6Z', '#9c5a48'));
  b.push(path('M-32 -6 Q0 0 32 -6 Q0 -3 -32 -6Z', '#6f3a2c', { noStroke: true }));
  // brillo santo
  b.push(sparkle(-34, -40, 6, '#fff6c8', 0.9), sparkle(36, -54, 5, '#fff6c8', 0.9));
  const t = [];
  t.push(banner(-18, 22, 11, 26));
  t.push(banner(18, 22, 11, 26));
  return { base: g(b), team: g(t) };
}

// --- Torre de guardia: torre de piedra con techo cónico -----------------------------------------
function tower() {
  const b = [];
  b.push(shadow(46));
  // cuerpo cónico
  b.push(path('M-28 60 L-22 -20 L22 -20 L28 60 Q0 68 -28 60Z', C.stone));
  b.push(bricks(-27, -20, 54, 80, { rowH: 10, brickW: 15 }));
  b.push(path('M8 -20 L22 -20 L28 60 Q16 63 8 62Z', C.stoneDark, { noStroke: true, opacity: 0.4 }));
  b.push(path('M-28 60 L-22 -20', 'none', { stroke: OUT, sw: 3 }));
  b.push(path('M-28 60 Q0 68 28 60', 'none', { stroke: OUT, sw: 3 }));
  // zócalo
  b.push(rect(-32, 48, 64, 14, C.stoneDark, { r: 3 }));
  b.push(bricks(-32, 48, 64, 14, { rowH: 7, brickW: 12 }));
  // puerta y aspilleras
  b.push(path('M-8 60 L-8 42 Q0 32 8 42 L8 60Z', C.woodDark));
  b.push(line(-8, 50, 8, 50, C.steelDark, 2));
  for (const y of [8, 26]) b.push(rect(-2.5, y - 8, 5, 16, '#1d1620', { r: 2.5, sw: 1.8 }));
  // plataforma de madera con almenas
  b.push(path('M-32 -18 L32 -18 L28 -28 L-28 -28Z', C.woodLight));
  b.push(path('M-32 -18 L32 -18 L30 -22 L-30 -22Z', C.woodDark, { noStroke: true, opacity: 0.55 }));
  for (let x = -26; x <= 26; x += 13) b.push(rect(x - 3, -28, 6, 12, C.woodDark, { noStroke: true }));
  // parte alta con ventana de arquero
  b.push(rect(-22, -52, 44, 26, C.stoneLight, { r: 2 }));
  b.push(bricks(-22, -52, 44, 26, { rowH: 8, brickW: 12 }));
  b.push(path('M6 -52 L22 -52 L22 -26 L6 -26Z', C.stoneDark, { noStroke: true, opacity: 0.4 }));
  b.push(rect(-9, -46, 18, 14, '#1d1620', { r: 3, sw: 2.4 }));
  b.push(rect(-7, -44, 14, 10, '#3d3450', { r: 2, noStroke: true }));
  b.push(line(0, -45, 0, -33, C.steelDark, 1.6));
  // techo cónico
  b.push(path('M-30 -50 L0 -84 L30 -50 Q0 -42 -30 -50Z', C.slate));
  b.push(path('M0 -84 L30 -50 Q14 -46 6 -46Z', C.slateDark, { noStroke: true, opacity: 0.65 }));
  b.push(path('M-20 -55 L-3 -76', 'none', { stroke: C.slateLight, sw: 3.5 }));
  b.push(path('M-30 -50 Q0 -42 30 -50', 'none', { stroke: OUT, sw: 3 }));
  b.push(circle(0, -86, 3.5, C.gold, { sw: 2 }));
  const t = [];
  t.push(pennant(0, -86, 26, 15, { pole: 14 }));
  t.push(banner(-14, -24, 12, 26));
  return { base: g(b), team: g(t) };
}

// --- Castillo: fortaleza con torres, muralla y puerta ------------------------------------------------
const CASTLE_W = 400;
const CASTLE_H = 184;
function castleTower(x, topY = -70) {
  const b = [];
  b.push(rect(x - 24, topY + 26, 48, 96 + topY * 0 - 26 + 4, C.stone, { r: 3 }));
  b.push(bricks(x - 24, topY + 26, 48, 96 - 26 + 4, { rowH: 9, brickW: 14 }));
  b.push(path(`M${x + 8} ${topY + 26} L${x + 24} ${topY + 26} L${x + 24} 60 L${x + 8} 60Z`, C.stoneDark, { noStroke: true, opacity: 0.4 }));
  b.push(rect(x - 28, topY + 20, 56, 10, C.stoneDark, { r: 2 }));
  for (const y of [topY + 44, topY + 78 - 6]) b.push(rect(x - 3, y, 6, 16, '#1d1620', { r: 3, sw: 2 }));
  b.push(path(`M${x - 30} ${topY + 22} L${x} ${topY - 26} L${x + 30} ${topY + 22} Q${x} ${topY + 30} ${x - 30} ${topY + 22}Z`, C.terracotta));
  b.push(path(`M${x} ${topY - 26} L${x + 30} ${topY + 22} Q${x + 14} ${topY + 27} ${x + 6} ${topY + 26}Z`, C.terracottaDark, { noStroke: true, opacity: 0.6 }));
  b.push(path(`M${x - 20} ${topY + 12} L${x - 4} ${topY - 14}`, 'none', { stroke: C.terracottaLight, sw: 3.5 }));
  b.push(circle(x, topY - 28, 3.4, C.gold, { sw: 2 }));
  return b.join('');
}

function castle() {
  const b = [];
  b.push(ellipse(0, 66, 190, 12, '#000000', { noStroke: true, opacity: 0.26 }));
  // muralla
  b.push(rect(-176, -6, 352, 64, C.stone, { r: 2 }));
  b.push(bricks(-176, -6, 352, 64, { rowH: 10, brickW: 17 }));
  b.push(path('M-176 40 L176 40 L176 58 L-176 58Z', C.stoneDark, { noStroke: true, opacity: 0.3 }));
  b.push(crenellations(-172, 172, -6, C.stone, 11, 10, 8));
  // torres laterales
  b.push(castleTower(-152, -48));
  b.push(castleTower(152, -48));
  // torre del homenaje detrás
  b.push(rect(-42, -64, 84, 46, C.stoneLight, { r: 2 }));
  b.push(bricks(-42, -64, 84, 46, { rowH: 9, brickW: 15 }));
  b.push(path('M12 -64 L42 -64 L42 -18 L12 -18Z', C.stoneDark, { noStroke: true, opacity: 0.35 }));
  b.push(crenellations(-42, 42, -64, C.stoneLight, 11, 10, 7));
  for (const x of [-22, 22]) b.push(rect(x - 3, -54, 6, 16, '#1d1620', { r: 3, sw: 2 }));
  // cuerpo del portón
  b.push(rect(-64, -22, 128, 80, C.stone, { r: 3 }));
  b.push(bricks(-64, -22, 128, 80, { rowH: 10, brickW: 17 }));
  b.push(path('M30 -22 L64 -22 L64 58 L30 58Z', C.stoneDark, { noStroke: true, opacity: 0.3 }));
  b.push(crenellations(-64, 64, -22, C.stone, 12, 11, 7));
  // portón con rastrillo
  b.push(path('M-24 58 L-24 20 Q0 -6 24 20 L24 58Z', '#1d1420'));
  b.push(path('M-20 58 L-20 22 Q0 0 20 22 L20 58Z', '#2f2230', { noStroke: true }));
  for (let x = -14; x <= 14; x += 9.3) b.push(line(x, 58, x, 12 + Math.abs(x) * 0.5, C.steelDark, 3.4));
  for (const y of [28, 42]) b.push(line(-19, y, 19, y, C.steelDark, 3.4));
  b.push(path('M-24 58 L-24 20 Q0 -6 24 20 L24 58Z', 'none', { stroke: C.stoneDeep, sw: 5 }));
  b.push(circle(0, 3, 4, C.gold, { sw: 2 }));
  // antorchas junto al portón
  for (const x of [-38, 38]) {
    b.push(line(x, 36, x, 46, C.woodDark, 4));
    b.push(path(`M${x} 32 Q${x - 6} 24 ${x} 14 Q${x + 6} 24 ${x} 32Z`, '#ff9c2f', { sw: 1.8 }));
    b.push(path(`M${x} 31 Q${x - 2.5} 25 ${x} 19 Q${x + 2.5} 25 ${x} 31Z`, '#ffe36b', { noStroke: true }));
  }
  const t = [];
  t.push(banner(0, -30, 22, 40));
  for (const x of [-152, 152]) t.push(pennant(x, -76, 30, 17, { pole: 14 }));
  t.push(pennant(0, -74, 30, 17, { pole: 12 }));
  for (const x of [-100, 100]) t.push(banner(x, -2, 16, 30));
  return { base: g(b), team: g(t) };
}

const STRUCTURES = {
  farm: { fn: farm, w: W, h: H },
  soldier_barracks: { fn: soldierBarracks, w: W, h: H },
  archer_barracks: { fn: archerBarracks, w: W, h: H },
  church: { fn: church, w: W, h: 160 },
  tower: { fn: tower, w: W, h: 160 },
  castle: { fn: castle, w: CASTLE_W, h: CASTLE_H },
};

/** Genera las estructuras de los humanos (raceId null) o de una raza (ver races.js). */
function generate(raceId = null) {
  withRace(raceId, (race) => {
    const dir = raceId ? `structures/${raceId}` : 'structures';
    for (const [id, s] of Object.entries(STRUCTURES)) {
      const parts = s.fn();
      L.write(`${dir}/${id}.svg`, recolor(doc(s.w, s.h, parts.base), race));
      L.write(`${dir}/${id}_team.svg`, doc(s.w, s.h, parts.team));
    }
  });
}

module.exports = { STRUCTURES, generate, castleParts: castle };
