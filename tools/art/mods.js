// Edificios modificadores (ModBuildings): uno por partida y jugador, elegido antes de jugar.
// Vistos en 3/4 con el mismo trazo grueso y la misma paleta que las estructuras, con diseño
// al estilo de los edificios de Warcraft 3: mina de oro, zigurat de nigromante, aserradero,
// herrería, campamento orco, puesto de estafador y cantera. Un SVG por edificio.

const L = require('./lib');
const { C, OUT, ellipse, circle, path, rect, poly, line, g, sparkle, doc } = L;

const W = 170;
const H = 180;

const PURPLE = { base: '#5b4a86', light: '#8571b8', dark: '#3b2f5c', deep: '#261d3d' };
const GREEN_GLOW = '#7dffb0';

function shadow(rx = 64, y = 68) {
  return ellipse(0, y, rx, 12, '#000000', { noStroke: true, opacity: 0.28 });
}

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

function flame(x, y, s = 1) {
  return [
    path(`M${x} ${y} Q${x - 9 * s} ${y - 12 * s} ${x - 1 * s} ${y - 28 * s} Q${x + 1 * s} ${y - 16 * s} ${x + 9 * s} ${y - 12 * s} Q${x + 8 * s} ${y - 2 * s} ${x} ${y}Z`, '#ff9c2f', { sw: 2 }),
    path(`M${x} ${y - 1} Q${x - 4 * s} ${y - 8 * s} ${x} ${y - 17 * s} Q${x + 4 * s} ${y - 8 * s} ${x} ${y - 1}Z`, '#ffe36b', { noStroke: true }),
  ].join('');
}

function log(x, y, len, r, tilt = 0) {
  const t = tilt ? `rotate(${tilt} ${x} ${y})` : '';
  return g([
    rect(x - len / 2, y - r, len, r * 2, C.wood, { r: r, sw: 2.6 }),
    line(x - len / 2 + r, y - r * 0.4, x + len / 2 - r, y - r * 0.4, C.woodLight, 2, { opacity: 0.7 }),
    ellipse(x + len / 2, y, r * 0.55, r, C.woodLight, { sw: 2.2 }),
    ellipse(x + len / 2, y, r * 0.22, r * 0.4, C.woodDark, { noStroke: true }),
  ], { transform: t });
}

// --- Mina de oro: montículo rocoso con bocamina, vetas de oro y una vagoneta ------------------------
function goldMine() {
  const b = [];
  b.push(shadow(70));
  // montículo de roca
  b.push(path('M-72 60 Q-76 20 -56 -8 Q-44 -46 -8 -58 Q30 -66 50 -34 Q74 -6 72 60Z', C.slate));
  b.push(path('M-8 -58 Q30 -66 50 -34 Q74 -6 72 60 L34 60 Q46 6 20 -30 Q10 -50 -8 -58Z', C.slateDark, { noStroke: true, opacity: 0.45 }));
  b.push(path('M-56 -8 Q-44 -46 -8 -58 Q-30 -34 -34 0Z', C.slateLight, { noStroke: true, opacity: 0.6 }));
  // grietas de roca
  b.push(path('M-50 20 l12 -8 l6 10', 'none', { stroke: C.slateDark, sw: 2.4 }));
  b.push(path('M40 -8 l-10 10 l8 8', 'none', { stroke: C.slateDark, sw: 2.4 }));
  // vetas de oro en la roca
  for (const [x, y, s] of [[-52, 30, 1], [44, 22, 1.1], [26, -34, 0.8], [-30, -30, 0.9]]) {
    b.push(poly([[x - 7 * s, y + 3 * s], [x - 2 * s, y - 6 * s], [x + 6 * s, y - 3 * s], [x + 7 * s, y + 5 * s], [x, y + 8 * s]], C.gold, { sw: 2 }));
    b.push(poly([[x - 2 * s, y - 6 * s], [x + 6 * s, y - 3 * s], [x + 1 * s, y + 1 * s]], C.goldLight, { noStroke: true, opacity: 0.9 }));
  }
  // bocamina con marco de vigas
  b.push(path('M-30 62 L-30 4 Q0 -22 30 4 L30 62Z', '#1a1220'));
  b.push(path('M-24 62 L-24 8 Q0 -14 24 8 L24 62Z', '#0d0812', { noStroke: true }));
  b.push(rect(-36, 0, 10, 64, C.wood, { sw: 3 }));
  b.push(rect(26, 0, 10, 64, C.wood, { sw: 3 }));
  b.push(rect(-40, -6, 80, 12, C.woodLight, { r: 2, sw: 3 }));
  b.push(line(-36, 12, -26, 4, C.woodDark, 3), line(36, 12, 26, 4, C.woodDark, 3));
  // carril y vagoneta
  b.push(line(-20, 66, 18, 30, C.steelDark, 3.4));
  b.push(line(-8, 68, 30, 32, C.steelDark, 3.4));
  b.push(path('M-18 44 L20 44 L16 62 L-14 62Z', C.steelDark));
  b.push(path('M-18 44 L20 44 L19 49 L-17 49Z', C.steel, { noStroke: true }));
  for (const [x, y, r] of [[-8, 42, 7], [2, 40, 8], [11, 42, 6.5], [-2, 36, 6]]) b.push(circle(x, y, r, C.gold, { sw: 2 }));
  b.push(circle(-2, 38, 3, C.goldLight, { noStroke: true }), circle(9, 40, 2.4, C.goldLight, { noStroke: true }));
  b.push(circle(-10, 63, 5, C.steelDeep, { sw: 2.2 }), circle(10, 63, 5, C.steelDeep, { sw: 2.2 }));
  // farol colgante
  b.push(line(0, -6, 0, 6, OUT, 4));
  b.push(rect(-6, 6, 12, 14, '#ffdc8a', { r: 3, sw: 2.4 }));
  b.push(circle(0, 13, 12, '#ffdc8a', { noStroke: true, opacity: 0.25 }));
  // pepitas grandes delante
  for (const [x, y, s] of [[-56, 56, 1.3], [-42, 62, 0.9], [54, 58, 1.1]]) {
    b.push(poly([[x - 9 * s, y + 3 * s], [x - 3 * s, y - 8 * s], [x + 7 * s, y - 5 * s], [x + 9 * s, y + 5 * s], [x, y + 9 * s]], C.gold, { sw: 2.2 }));
    b.push(sparkle(x + 2 * s, y - 2 * s, 5 * s, '#ffffff', 0.9));
  }
  return g(b);
}

// --- Nigromante: zigurat escalonado con llama verde y calaveras ----------------------------------------
function necromancer() {
  const b = [];
  b.push(shadow(72));
  // tres niveles escalonados
  const tiers = [
    { x: -68, y: 22, w: 136, h: 44 },
    { x: -48, y: -14, w: 96, h: 38 },
    { x: -30, y: -46, w: 60, h: 34 },
  ];
  for (const t of tiers) {
    b.push(rect(t.x, t.y, t.w, t.h, PURPLE.base, { r: 3 }));
    b.push(rect(t.x, t.y, t.w, 9, PURPLE.light, { r: 3, noStroke: true, opacity: 0.85 }));
    b.push(path(`M${t.x + t.w * 0.68} ${t.y} L${t.x + t.w} ${t.y} L${t.x + t.w} ${t.y + t.h} L${t.x + t.w * 0.68} ${t.y + t.h}Z`, PURPLE.dark, { noStroke: true, opacity: 0.5 }));
    b.push(bricks(t.x, t.y, t.w, t.h, { rowH: 11, brickW: 19, color: PURPLE.deep }));
    // borde superior de cada nivel
    b.push(rect(t.x - 3, t.y - 4, t.w + 6, 8, PURPLE.dark, { r: 2, sw: 2.6 }));
  }
  // escalera central
  b.push(poly([[-14, 66], [14, 66], [10, 24], [-10, 24]], PURPLE.dark));
  for (let y = 60; y > 26; y -= 8) b.push(line(-13 + (66 - y) * 0.07, y, 13 - (66 - y) * 0.07, y, PURPLE.light, 2.6, { opacity: 0.8 }));
  b.push(poly([[-9, 24], [9, 24], [7, -14], [-7, -14]], PURPLE.dark, { noStroke: true, opacity: 0.0 }));
  // runas brillantes
  for (const [x, y] of [[-46, 40], [46, 40], [-30, 2], [30, 2]]) {
    b.push(circle(x, y, 9, GREEN_GLOW, { noStroke: true, opacity: 0.22 }));
    b.push(path(`M${x} ${y - 6} L${x + 5} ${y} L${x} ${y + 6} L${x - 5} ${y}Z`, 'none', { stroke: GREEN_GLOW, sw: 2 }));
    b.push(circle(x, y, 1.8, GREEN_GLOW, { noStroke: true }));
  }
  // calaveras en las esquinas
  for (const [x, y] of [[-60, 24], [60, 24]]) {
    b.push(circle(x, y, 8, C.cream, { sw: 2.2 }));
    b.push(rect(x - 4, y + 5, 8, 6, C.cream, { r: 2, sw: 2 }));
    b.push(circle(x - 3, y - 1, 2, '#1d1620', { noStroke: true }), circle(x + 3, y - 1, 2, '#1d1620', { noStroke: true }));
  }
  // altar y llama verde en la cima
  b.push(rect(-16, -56, 32, 12, PURPLE.dark, { r: 3 }));
  b.push(ellipse(0, -66, 26, 15, GREEN_GLOW, { noStroke: true, opacity: 0.22 }));
  b.push(path('M0 -56 Q-16 -68 -4 -92 Q-2 -78 10 -72 Q14 -62 0 -56Z', '#3ddc84', { sw: 2.2 }));
  b.push(path('M0 -58 Q-8 -68 0 -82 Q6 -70 6 -64 Q5 -58 0 -58Z', GREEN_GLOW, { noStroke: true }));
  b.push(sparkle(-14, -80, 5, GREEN_GLOW), sparkle(16, -88, 4, GREEN_GLOW, 0.8));
  return g(b);
}

// --- Aserradero: cobertizo de tablones con sierra circular y pilas de troncos ---------------------------
function sawmill() {
  const b = [];
  b.push(shadow(72));
  // pila de troncos a la izquierda
  for (const [x, y] of [[-50, 60], [-36, 60], [-43, 50], [-57, 50], [-50, 40]]) b.push(log(x, y, 30, 6.5));
  // paredes de tablones
  b.push(rect(-40, 0, 92, 60, C.woodLight, { r: 2 }));
  for (let x = -30; x < 50; x += 12) b.push(line(x, 2, x, 58, C.woodDark, 1.8, { opacity: 0.7 }));
  b.push(path('M30 0 L52 0 L52 60 L30 60Z', C.woodDark, { noStroke: true, opacity: 0.35 }));
  b.push(rect(-42, 50, 96, 10, C.stoneDark, { r: 2 }));
  b.push(bricks(-42, 50, 96, 10, { rowH: 5, brickW: 11 }));
  // abertura con la mesa de corte
  b.push(rect(-22, 22, 46, 30, '#2b1c12', { r: 2 }));
  b.push(rect(-26, 18, 54, 8, C.woodDark, { r: 2, sw: 2.6 }));
  b.push(log(0, 42, 40, 6, 0));
  // tejado inclinado de tablas
  b.push(path('M-56 8 L-30 -34 L46 -34 L62 8Z', C.terracotta));
  b.push(path('M-30 -34 L46 -34 L52 -20 L-40 -20Z', C.terracottaLight, { noStroke: true, opacity: 0.6 }));
  for (let i = 1; i < 5; i++) {
    const y = -34 + i * 8.4;
    b.push(line(-30 - i * 6.5, y, 46 + i * 4, y, C.terracottaDark, 1.8, { opacity: 0.7 }));
  }
  b.push(path('M-56 8 L62 8', 'none', { stroke: C.terracottaDark, sw: 5 }));
  // sierra circular grande delante, sobre un eje
  b.push(line(50, 56, 50, 30, C.woodDark, 5));
  const sx = 50, sy = 26, sr = 20;
  b.push(circle(sx, sy, sr, C.steelLight, { sw: 3 }));
  for (let a = 0; a < 16; a++) {
    const ang = (a / 16) * Math.PI * 2;
    const x1 = sx + Math.cos(ang) * sr, y1 = sy + Math.sin(ang) * sr;
    const x2 = sx + Math.cos(ang + 0.18) * (sr + 6), y2 = sy + Math.sin(ang + 0.18) * (sr + 6);
    const x3 = sx + Math.cos(ang + 0.36) * sr, y3 = sy + Math.sin(ang + 0.36) * sr;
    b.push(poly([[x1, y1], [x2, y2], [x3, y3]], C.steel, { sw: 1.8 }));
  }
  b.push(circle(sx, sy, sr * 0.62, C.steel, { sw: 2 }));
  b.push(circle(sx, sy, 5, C.steelDeep, { sw: 2 }));
  b.push(path(`M${sx - 12} ${sy - 12} A17 17 0 0 1 ${sx + 4} ${sy - 17}`, 'none', { stroke: '#ffffff', sw: 2.4 }));
  // serrín y tronco delante
  b.push(log(24, 66, 44, 7, 0));
  b.push(sparkle(-2, 12, 4, C.thatchLight, 0.9));
  return g(b);
}

// --- Herrería: edificio de piedra con chimenea, fragua encendida y yunque -----------------------------
function forge() {
  const b = [];
  b.push(shadow(70));
  // muros de piedra
  b.push(rect(-58, -4, 104, 62, C.stone, { r: 2 }));
  b.push(bricks(-58, -4, 104, 62, { rowH: 9, brickW: 17 }));
  b.push(path('M26 -4 L46 -4 L46 58 L26 58Z', C.stoneDark, { noStroke: true, opacity: 0.35 }));
  for (const x of [-58, 46]) b.push(rect(x - 3, -4, 6, 62, C.woodDark, { noStroke: true }));
  // chimenea con humo
  b.push(rect(14, -56, 22, 44, C.stone, { r: 2 }));
  b.push(bricks(14, -56, 22, 44, { rowH: 8, brickW: 10 }));
  b.push(rect(11, -60, 28, 8, C.stoneDark, { r: 2 }));
  b.push(circle(26, -70, 6, '#ffffff', { noStroke: true, opacity: 0.5 }), circle(31, -80, 5, '#ffffff', { noStroke: true, opacity: 0.35 }));
  b.push(flame(26, -60, 0.6));
  // boca de la fragua brillante
  b.push(path('M-40 58 L-40 24 Q-18 4 4 24 L4 58Z', '#24140e'));
  b.push(path('M-34 58 L-34 28 Q-18 12 -2 28 L-2 58Z', '#ff7a1c', { noStroke: true }));
  b.push(path('M-28 58 L-28 32 Q-18 22 -8 32 L-8 58Z', '#ffd24a', { noStroke: true }));
  b.push(flame(-18, 58, 1.1));
  b.push(path('M-40 58 L-40 24 Q-18 4 4 24 L4 58Z', 'none', { stroke: C.stoneDeep, sw: 5 }));
  b.push(ellipse(-18, 40, 40, 26, '#ff9c2f', { noStroke: true, opacity: 0.14 }));
  // tejado de pizarra
  b.push(path('M-66 4 L-48 -34 L36 -34 L54 4 Q-6 12 -66 4Z', C.slate));
  b.push(path('M-48 -34 L36 -34 L42 -22 L-54 -22Z', C.slateLight, { noStroke: true, opacity: 0.55 }));
  for (let i = 1; i < 4; i++) {
    const y = -34 + i * 9.5;
    b.push(line(-48 - i * 6, y, 36 + i * 6, y, C.slateDark, 1.8, { opacity: 0.6 }));
  }
  b.push(path('M-66 4 Q-6 12 54 4', 'none', { stroke: C.slateDark, sw: 5 }));
  // cartel de martillo y yunque
  b.push(rect(20, 22, 22, 22, C.woodLight, { r: 3, sw: 2.6 }));
  b.push(line(26, 40, 36, 28, C.steelDark, 3));
  b.push(rect(30, 25, 9, 5, C.steelLight, { r: 1.5, sw: 2 }));
  // yunque delante
  b.push(rect(40, 56, 26, 9, C.woodDark, { r: 2 }));
  b.push(path('M32 40 L72 40 Q66 48 60 50 L62 56 L44 56 L46 50 Q38 48 32 40Z', C.steelDeep, { sw: 3 }));
  b.push(path('M34 41 L70 41 L68 44 L36 44Z', C.steelLight, { noStroke: true, opacity: 0.85 }));
  b.push(sparkle(48, 34, 6, '#ffe36b'), sparkle(58, 30, 4, '#ffb347'), sparkle(40, 28, 3, '#ffffff', 0.8));
  return g(b);
}

// --- Campamento de saqueadores: tiendas de pieles, empalizada y hoguera --------------------------------
function raiderCamp() {
  const b = [];
  b.push(shadow(72));
  // empalizada de estacas al fondo
  for (let x = -64; x <= 64; x += 13) {
    const h = 30 + ((Math.abs(x) * 7) % 11);
    b.push(poly([[x - 5, 4], [x - 5, 4 - h + 8], [x, 4 - h], [x + 5, 4 - h + 8], [x + 5, 4]], C.woodLight, { sw: 2.6 }));
    b.push(line(x - 1, 4 - h + 10, x - 1, 2, C.woodDark, 1.6, { opacity: 0.6 }));
  }
  b.push(line(-66, -6, 66, -6, C.leatherDark, 4));
  // tienda grande de pieles
  b.push(path('M-58 60 L-6 -44 L46 60Z', C.leather));
  b.push(path('M-6 -44 L46 60 L14 60 L-6 -8Z', C.leatherDark, { noStroke: true, opacity: 0.55 }));
  b.push(path('M-6 -44 L-22 60 L-8 60Z', '#a06a3e', { noStroke: true, opacity: 0.7 }));
  b.push(path('M-16 60 L-6 22 L4 60Z', '#1a0f0a'));
  for (const [x1, y1, x2, y2] of [[-30, 20, -20, 34], [22, 22, 12, 36], [-14, -10, -6, 4]]) b.push(line(x1, y1, x2, y2, C.leatherDark, 2.6));
  b.push(line(-6, -44, -6, -60, OUT, 6));
  b.push(line(-6, -44, -6, -60, C.woodLight, 3));
  // colmillos cruzados y pico
  b.push(path('M-6 -44 L-12 -52 M-6 -44 L0 -52', 'none', { stroke: C.cream, sw: 3.4 }));
  // estandarte con calavera
  b.push(line(48, 48, 48, -40, OUT, 6));
  b.push(line(48, 48, 48, -40, C.woodLight, 3));
  b.push(path('M48 -38 L72 -32 L66 -20 L72 -8 L48 -12Z', '#a8261e', { sw: 2.6 }));
  b.push(circle(60, -24, 5, C.cream, { noStroke: true }));
  b.push(circle(58.5, -25, 1.3, '#1d1620', { noStroke: true }), circle(61.5, -25, 1.3, '#1d1620', { noStroke: true }));
  b.push(poly([[48, -42], [43, -46], [48, -52], [53, -46]], C.steel, { sw: 2 }));
  // tienda pequeña
  b.push(path('M-72 62 L-56 22 L-40 62Z', '#8a5a34'));
  b.push(path('M-56 22 L-40 62 L-50 62Z', C.leatherDark, { noStroke: true, opacity: 0.6 }));
  // hoguera delante
  b.push(ellipse(26, 62, 22, 7, '#000000', { noStroke: true, opacity: 0.25 }));
  for (const a of [-25, 25]) b.push(line(26 - 12 * Math.sin(a * 0.02), 62, 26 + 12 * Math.sin(a * 0.02), 58, OUT, 0));
  b.push(log(26, 62, 28, 4, 18));
  b.push(log(26, 62, 28, 4, -18));
  b.push(flame(26, 58, 1.2));
  b.push(ellipse(26, 50, 26, 18, '#ff9c2f', { noStroke: true, opacity: 0.13 }));
  b.push(sparkle(34, 34, 3.5, '#ffb347', 0.9));
  return g(b);
}

// --- Estafador: puesto de mercader sombrío con toldo a rayas, saco de monedas y dados ----------------------
function swindler() {
  const b = [];
  b.push(shadow(66));
  // postes
  b.push(rect(-58, -22, 7, 84, C.woodDark, { sw: 2.6 }));
  b.push(rect(51, -22, 7, 84, C.woodDark, { sw: 2.6 }));
  // fondo oscuro del puesto
  b.push(rect(-54, -18, 108, 50, '#2a2036', { r: 2 }));
  b.push(rect(-54, -18, 108, 50, '#000000', { noStroke: true, opacity: 0.12 }));
  // estantes con frascos
  b.push(rect(-50, 0, 44, 5, C.woodLight, { sw: 2 }));
  for (const [x, col] of [[-44, '#7ddc6b'], [-34, '#c96bff'], [-24, '#ffcf4d'], [-14, '#7ec7ff']]) {
    b.push(rect(x - 4, -14, 8, 14, col, { r: 3, sw: 2 }));
    b.push(rect(x - 2, -18, 4, 5, C.cream, { r: 1, sw: 1.6 }));
  }
  // ojos brillantes en la sombra (el estafador)
  b.push(ellipse(28, -2, 3.2, 4.2, '#fff27a', { noStroke: true }), ellipse(38, -2, 3.2, 4.2, '#fff27a', { noStroke: true }));
  b.push(path('M22 -16 Q33 -30 44 -16 L44 12 L22 12Z', '#3b2a52', { noStroke: true, opacity: 0.85 }));
  b.push(ellipse(28, -2, 3.2, 4.2, '#fff27a', { noStroke: true }), ellipse(38, -2, 3.2, 4.2, '#fff27a', { noStroke: true }));
  // mostrador
  b.push(rect(-62, 30, 124, 30, C.woodLight, { r: 3 }));
  for (let x = -46; x < 56; x += 22) b.push(line(x, 32, x, 58, C.woodDark, 1.8, { opacity: 0.7 }));
  b.push(rect(-64, 26, 128, 9, C.wood, { r: 3, sw: 3 }));
  // toldo a rayas verde y morado
  const stripes = ['#3f9c58', '#6b3fa0'];
  for (let i = 0; i < 6; i++) {
    const x0 = -66 + i * 22;
    b.push(path(`M${x0} -22 L${x0 + 22} -22 L${x0 + 27} -2 Q${x0 + 24} 6 ${x0 + 16} 2 Q${x0 + 8} 6 ${x0 - 5} -2Z`, stripes[i % 2], { sw: 2.6 }));
  }
  b.push(path('M-66 -22 L-52 -52 L52 -52 L66 -22Z', '#4b3a66'));
  b.push(path('M-52 -52 L52 -52 L56 -40 L-56 -40Z', '#7a62a0', { noStroke: true, opacity: 0.7 }));
  b.push(path('M-66 -22 L66 -22', 'none', { stroke: '#261d3d', sw: 4 }));
  // signo de monedas colgando
  b.push(line(0, -22, 0, -10, OUT, 4));
  b.push(circle(0, -6, 10, C.gold, { sw: 2.6 }));
  b.push(path('M-2.5 -10 Q3 -12 2 -8 Q-3 -5 -2 -1 Q3 1 3 -3', 'none', { stroke: C.goldDark, sw: 2 }));
  // saco de monedas y monedas en el mostrador
  b.push(path('M-48 30 Q-58 8 -46 -2 Q-36 -8 -30 2 Q-22 12 -30 30Z', '#8a6b3d'));
  b.push(path('M-46 -2 Q-38 -12 -32 -2 Q-38 2 -46 -2Z', '#a8875a', { sw: 2 }));
  b.push(circle(-39, 12, 7, C.gold, { sw: 2 }));
  b.push(path('M-39 8 v8 M-42 10.5 h6', 'none', { stroke: C.goldDark, sw: 1.8 }));
  for (const [x, y] of [[-12, 28], [-4, 25], [4, 28]]) b.push(ellipse(x, y, 7, 3.4, C.gold, { sw: 2 }));
  // dados
  for (const x of [22, 38]) {
    b.push(rect(x - 6, 20, 12, 12, C.cream, { r: 2.5, sw: 2.4 }));
  }
  for (const [x, y] of [[20, 22], [24, 30], [22, 26], [36, 22], [40, 30], [36, 30], [40, 22]]) b.push(circle(x, y, 1.4, '#1d1620', { noStroke: true }));
  return g(b);
}

// --- Canteros: cantera con bloques tallados, grúa de madera y cabaña ---------------------------------------
function stonemasons() {
  const b = [];
  b.push(shadow(72));
  // pared de roca al fondo
  b.push(path('M-72 6 Q-70 -30 -44 -40 L-14 -52 L40 -40 Q68 -30 72 6Z', C.slate));
  b.push(path('M-14 -52 L40 -40 Q68 -30 72 6 L40 6 Q34 -22 12 -36Z', C.slateDark, { noStroke: true, opacity: 0.45 }));
  for (let i = 0; i < 4; i++) b.push(line(-60 + i * 30, 6, -54 + i * 30, -26 - (i % 2) * 8, C.slateDark, 2.2, { opacity: 0.7 }));
  // escalones de cantera
  b.push(rect(-72, 4, 144, 16, C.stone, { r: 2 }));
  b.push(bricks(-72, 4, 144, 16, { rowH: 8, brickW: 22 }));
  // bloques apilados a la derecha
  const block = (x, y, w, h) => {
    b.push(rect(x, y, w, h, C.stoneLight, { r: 2, sw: 2.8 }));
    b.push(rect(x, y, w, h * 0.28, '#ffffff', { r: 2, noStroke: true, opacity: 0.4 }));
    b.push(path(`M${x + w * 0.7} ${y} L${x + w} ${y} L${x + w} ${y + h} L${x + w * 0.7} ${y + h}Z`, C.stoneDark, { noStroke: true, opacity: 0.35 }));
  };
  block(30, 44, 38, 22);
  block(44, 22, 34, 22);
  block(12, 44, 20, 22);
  // bloque a medio tallar con cincel
  block(-46, 36, 46, 30);
  b.push(line(-40, 40, -14, 40, C.stoneDeep, 1.6, { opacity: 0.6 }));
  b.push(line(-40, 46, -20, 46, C.stoneDeep, 1.6, { opacity: 0.6 }));
  b.push(rect(-20, 24, 5, 22, C.steelDark, { r: 1.5, sw: 2 }));
  b.push(rect(-26, 18, 17, 8, C.wood, { r: 2, sw: 2.4 }));
  b.push(sparkle(-14, 32, 6, '#ffffff'), sparkle(-6, 28, 3.5, '#ffffff', 0.8));
  // grúa de madera
  b.push(line(-60, 62, -60, -26, OUT, 9));
  b.push(line(-60, 62, -60, -26, C.woodLight, 5));
  b.push(line(-60, -26, -10, -46, OUT, 8));
  b.push(line(-60, -26, -10, -46, C.woodLight, 4));
  b.push(line(-60, 10, -34, -34, OUT, 6));
  b.push(line(-60, 10, -34, -34, C.wood, 3));
  b.push(line(-14, -44, -14, -14, OUT, 4));
  b.push(line(-14, -44, -14, -14, C.leather, 2));
  b.push(rect(-24, -14, 20, 12, C.stoneLight, { r: 2, sw: 2.6 }));
  b.push(circle(-14, -46, 5, C.steelDark, { sw: 2.2 }));
  // cabaña pequeña
  b.push(rect(4, -22, 34, 24, C.creamDark, { r: 1.5 }));
  b.push(path('M-2 -20 L21 -44 L44 -20Z', C.terracotta));
  b.push(path('M21 -44 L44 -20 L30 -20Z', C.terracottaDark, { noStroke: true, opacity: 0.6 }));
  b.push(rect(16, -12, 10, 14, '#2b1c12', { r: 4, sw: 2 }));
  // pico apoyado
  b.push(line(56, 62, 68, 30, OUT, 5));
  b.push(line(56, 62, 68, 30, C.woodLight, 2.6));
  b.push(path('M58 30 Q68 24 80 32 Q70 30 66 34Z', C.steel, { sw: 2.2 }));
  return g(b);
}

const MODS = {
  gold_mine: goldMine,
  necromancer,
  sawmill,
  forge,
  raider_camp: raiderCamp,
  swindler,
  stonemasons,
};

function generate() {
  for (const [id, fn] of Object.entries(MODS)) L.write(`mods/${id}.svg`, doc(W, H, fn()));
}

module.exports = { MODS, generate };
