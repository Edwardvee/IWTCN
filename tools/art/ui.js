// Iconos de interfaz: moneda, candado, martillo, dados, iconos de mejoras y
// de cartas de unidades. Todos son SVG planos con el contorno oscuro común.

const L = require('./lib');
const { C, OUT, ellipse, circle, path, rect, poly, line, g, rot, tr, sparkle, doc } = L;
const { UNITS, idleSvg } = require('./units');

function star(cx, cy, r, fill, o = {}) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rr = i % 2 ? r * 0.45 : r;
    pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]);
  }
  return poly(pts, fill, o);
}

function coin() {
  const b = [
    circle(0, 0, 27, '#f5c33b', { sw: 3.4 }),
    circle(0, 0, 20, 'none', { stroke: '#c98a17', sw: 3 }),
    star(0, 1, 11, '#ffe58f', { sw: 2.4 }),
    path('M-19 -8 A21 21 0 0 1 -4 -20', 'none', { stroke: '#ffffff', sw: 3.4, opacity: 0.7 }),
  ];
  return doc(64, 64, b.join(''));
}

function padlock() {
  const b = [
    path('M-13 -4 L-13 -16 A13 13 0 0 1 13 -16 L13 -4', 'none', { stroke: OUT, sw: 11 }),
    path('M-13 -4 L-13 -16 A13 13 0 0 1 13 -16 L13 -4', 'none', { stroke: C.steel, sw: 5.5 }),
    rect(-21, -6, 42, 34, '#e3a938', { r: 8, sw: 3.4 }),
    rect(-21, -6, 42, 11, '#f5cb5f', { r: 8, noStroke: true, opacity: 0.8 }),
    circle(0, 10, 5.4, OUT, { noStroke: true }),
    path('M-2.4 12 L2.4 12 L3.6 22 L-3.6 22Z', OUT, { noStroke: true }),
  ];
  return doc(64, 64, g(b, { transform: 'translate(0 2)' }));
}

function hammer() {
  const b = [
    line(-18, 20, 10, -8, OUT, 13),
    line(-18, 20, 10, -8, C.woodLight, 8),
    g([
      rect(-8, -18, 34, 20, C.steel, { r: 5, sw: 3.4 }),
      rect(-8, -18, 34, 7, C.steelLight, { r: 5, noStroke: true, opacity: 0.9 }),
      rect(-8, -3, 34, 5, C.steelDeep, { noStroke: true, opacity: 0.7 }),
    ], { transform: 'rotate(45 10 -8)' }),
  ];
  return doc(72, 72, g(b, { transform: 'translate(-2 4)' }));
}

function dice() {
  const pip = (x, y) => circle(x, y, 4, OUT, { noStroke: true });
  const b = [
    rect(-24, -24, 48, 48, '#fbf4e2', { r: 11, sw: 3.6 }),
    rect(-24, -24, 48, 16, '#ffffff', { r: 11, noStroke: true, opacity: 0.7 }),
    path('M-24 8 L24 8 L24 13 Q24 24 13 24 L-13 24 Q-24 24 -24 13Z', '#e3d5b4', { noStroke: true, opacity: 0.9 }),
    pip(-12, -12), pip(12, -12), pip(0, 0), pip(-12, 12), pip(12, 12),
  ];
  return doc(72, 72, g(b, { transform: 'rotate(-12)' }));
}

// --- Mejoras (cartas violetas) ---------------------------------------------------------------------------
function buffArmor() {
  const b = [
    path('M0 -46 L38 -34 Q40 12 0 44 Q-40 12 -38 -34Z', C.steelLight, { sw: 4 }),
    path('M0 -46 L38 -34 Q40 12 0 44Z', C.steel, { noStroke: true }),
    path('M0 -34 L28 -26 Q29 8 0 33 Q-29 8 -28 -26Z', '#3f6fb5', { sw: 3.4 }),
    path('M0 -34 L28 -26 Q29 8 0 33Z', '#33599a', { noStroke: true, opacity: 0.8 }),
    rect(-5, -18, 10, 34, C.gold, { r: 2, sw: 2.6 }),
    rect(-16, -8, 32, 10, C.gold, { r: 2, sw: 2.6 }),
    path('M-20 -22 Q-18 -10 -12 -2', 'none', { stroke: '#ffffff', sw: 3, opacity: 0.6 }),
  ];
  return doc(128, 128, g(b, { transform: 'translate(0 2)' }));
}

function buffHp() {
  const heart = 'M0 40 C-46 8 -48 -22 -26 -32 C-12 -38 -2 -30 0 -20 C2 -30 12 -38 26 -32 C48 -22 46 8 0 40Z';
  const b = [
    path(heart, '#e0453f', { sw: 4.4 }),
    path('M0 40 C-46 8 -48 -22 -26 -32 C-12 -38 -2 -30 0 -20 L0 40Z', '#ee6a5c', { noStroke: true, opacity: 0.55 }),
    path('M-30 -14 Q-28 -26 -16 -27', 'none', { stroke: '#ffffff', sw: 5, opacity: 0.75 }),
    rect(-4, -12, 8, 26, '#fff4e0', { r: 2, sw: 2.4 }),
    rect(-13, -3, 26, 8, '#fff4e0', { r: 2, sw: 2.4 }),
  ];
  return doc(128, 128, g(b, { transform: 'translate(0 -2)' }));
}

function buffSpeed() {
  const b = [
    // ala
    path('M-6 -6 Q-40 -34 -52 -14 Q-38 -12 -46 -2 Q-30 0 -36 12 Q-20 8 -10 10Z', '#ffffff', { sw: 3.4 }),
    path('M-24 -4 Q-34 -10 -46 -4', 'none', { stroke: '#d5dde6', sw: 3 }),
    // bota
    path('M-2 -34 L26 -34 L26 8 Q42 12 44 28 L44 34 L-12 34 L-12 -4Z', '#8a5a34', { sw: 4 }),
    path('M-2 -34 L26 -34 L26 -20 L-2 -20Z', '#b98250', { noStroke: true }),
    rect(-12, 28, 56, 8, '#4a2f1b', { r: 3, sw: 3 }),
    line(-2, -14, 26, -14, C.gold, 3.4),
    line(0, 6, 22, 6, '#6c4326', 2.6),
    // rayas de velocidad
    line(-58, 22, -30, 22, '#ffffff', 4, { opacity: 0.85 }),
    line(-52, 32, -26, 32, '#ffffff', 3, { opacity: 0.6 }),
  ];
  return doc(128, 128, g(b, { transform: 'translate(8 -2)' }));
}

function buffProduction() {
  const teeth = [];
  for (let i = 0; i < 8; i++) teeth.push(rect(-8, -46, 16, 16, '#e3a938', { r: 3, sw: 3.4, transform: `rotate(${i * 45})` }));
  const b = [
    ...teeth,
    circle(0, 0, 34, '#f0bd4a', { sw: 4 }),
    circle(0, 0, 25, 'none', { stroke: '#b9821d', sw: 3 }),
    circle(0, 0, 12, '#3a2a4a', { sw: 3.4 }),
    path('M-24 -18 Q-16 -30 -4 -32', 'none', { stroke: '#ffffff', sw: 4, opacity: 0.6 }),
    // flecha hacia arriba
    poly([[0, -8], [10, 4], [4, 4], [4, 12], [-4, 12], [-4, 4], [-10, 4]], '#9be05f', { sw: 2.4 }),
  ];
  return doc(128, 128, g(b, { transform: 'rotate(8)' }));
}

function buffFireRate() {
  const b = [
    // llamas de la flecha
    path('M-40 34 Q-52 14 -34 8 Q-38 -4 -24 -8 Q-24 6 -14 10 Q-8 22 -18 34Z', '#ff9c2f', { sw: 3 }),
    path('M-34 30 Q-42 18 -30 14 Q-30 6 -22 4 Q-22 14 -16 18 Q-14 26 -22 30Z', '#ffe36b', { noStroke: true }),
    // flecha
    line(-24, 26, 34, -32, OUT, 12),
    line(-24, 26, 34, -32, C.woodLight, 6),
    poly([[30, -48], [50, -50], [48, -30], [36, -34]], C.steelLight, { sw: 3.2 }),
    poly([[-30, 32], [-40, 22], [-26, 18]], '#e0453f', { sw: 2.4 }),
    poly([[-22, 40], [-32, 30], [-18, 26]], '#e0453f', { sw: 2.4 }),
    // brillos de velocidad
    line(-8, -40, 12, -40, '#ffffff', 4, { opacity: 0.8 }),
    line(-20, -30, 0, -30, '#ffffff', 3, { opacity: 0.6 }),
    sparkle(40, 28, 9, '#fff3b0', 0.95),
  ];
  return doc(128, 128, b.join(''));
}


// --- Cartas de sabotaje (rojas): caen sobre el rival ----------------------------------------------------------------
function sabFreeze() {
  const arms = [];
  for (let i = 0; i < 3; i++) {
    arms.push(g([
      line(-44, 0, 44, 0, OUT, 12), line(-44, 0, 44, 0, '#dff6ff', 7),
      poly([[-44, 0], [-34, -9], [-30, 0], [-34, 9]], '#dff6ff', { sw: 2.4 }),
      poly([[44, 0], [34, -9], [30, 0], [34, 9]], '#dff6ff', { sw: 2.4 }),
      line(-22, 0, -32, -13, '#dff6ff', 5), line(-22, 0, -32, 13, '#dff6ff', 5),
      line(22, 0, 32, -13, '#dff6ff', 5), line(22, 0, 32, 13, '#dff6ff', 5),
    ], { transform: `rotate(${i * 60})` }));
  }
  const b = [
    circle(0, 0, 52, '#7cc7ff', { sw: 4, opacity: 0.9 }),
    circle(0, 0, 52, 'none', { stroke: '#e8f8ff', sw: 3, opacity: 0.8 }),
    ...arms,
    circle(0, 0, 9, '#ffffff', { sw: 3 }),
    sparkle(-40, -40, 8, '#ffffff'), sparkle(42, 38, 6, '#ffffff', 0.9),
  ];
  return doc(128, 128, b.join(''));
}

function sabBlock() {
  const b = [
    // carta inclinada
    rect(-38, -50, 76, 100, '#2f2440', { r: 9, sw: 4, transform: 'rotate(-10)' }),
    rect(-30, -42, 60, 48, '#5a4778', { r: 6, noStroke: true, transform: 'rotate(-10)' }),
    // candado
    path('M-20 -4 L-20 -22 Q-20 -44 0 -44 Q20 -44 20 -22 L20 -4', 'none', { stroke: OUT, sw: 15 }),
    path('M-20 -4 L-20 -22 Q-20 -44 0 -44 Q20 -44 20 -22 L20 -4', 'none', { stroke: '#cfd8e3', sw: 8 }),
    rect(-32, -6, 64, 52, '#f0bd4a', { r: 9, sw: 4.4 }),
    rect(-32, -6, 64, 16, '#ffe07a', { r: 9, noStroke: true, opacity: 0.8 }),
    circle(0, 16, 8, '#3a2a4a', { sw: 3 }),
    rect(-3.5, 18, 7, 16, '#3a2a4a', { r: 2.5, noStroke: true }),
    sparkle(40, -34, 8, '#fff3b0'),
  ];
  return doc(128, 128, b.join(''));
}

function sabReroll() {
  const die = (x, y, rotDeg, dots) => g([
    rect(-24, -24, 48, 48, '#fff8e6', { r: 10, sw: 4 }),
    rect(-24, -24, 48, 14, '#ffffff', { r: 10, noStroke: true, opacity: 0.7 }),
    ...dots.map(([dx, dy]) => circle(dx, dy, 5, '#d63a3a', { noStroke: true })),
  ], { transform: `translate(${x} ${y}) rotate(${rotDeg})` });
  const b = [
    die(-16, 14, -14, [[-10, -10], [10, 10], [0, 0], [10, -10], [-10, 10]]),
    die(20, -18, 18, [[-9, -9], [9, 9], [0, 0]]),
    // flecha circular roja
    path('M-46 -22 A50 50 0 0 1 22 -50', 'none', { stroke: OUT, sw: 15 }),
    path('M-46 -22 A50 50 0 0 1 22 -50', 'none', { stroke: '#ff5b4f', sw: 8 }),
    poly([[22, -64], [44, -48], [18, -36]], '#ff5b4f', { sw: 3 }),
    path('M46 30 A50 50 0 0 1 -22 52', 'none', { stroke: OUT, sw: 15 }),
    path('M46 30 A50 50 0 0 1 -22 52', 'none', { stroke: '#ff5b4f', sw: 8 }),
    poly([[-22, 66], [-44, 50], [-18, 38]], '#ff5b4f', { sw: 3 }),
  ];
  return doc(128, 128, b.join(''));
}

function sabSteal() {
  const b = [
    // saco de oro
    path('M-34 46 Q-52 8 -30 -12 L-16 -30 L16 -30 L30 -12 Q52 8 34 46Z', '#9a6b3a', { sw: 4.4 }),
    path('M-16 -30 L16 -30 L30 -12 L-30 -12Z', '#b98552', { noStroke: true, opacity: 0.8 }),
    path('M-24 -14 Q0 -4 24 -14', 'none', { stroke: OUT, sw: 9 }),
    path('M-24 -14 Q0 -4 24 -14', 'none', { stroke: '#e8c55a', sw: 4.4 }),
    path('M-14 -30 Q0 -44 14 -30', 'none', { stroke: '#e8c55a', sw: 5 }),
    circle(0, 16, 15, '#f5c33b', { sw: 3.4 }),
    star(0, 17, 8, '#ffe58f', { sw: 2 }),
    // monedas que salen volando
    circle(38, -34, 11, '#f5c33b', { sw: 3 }), circle(50, -10, 9, '#f5c33b', { sw: 3 }),
    // daga que perfora el saco
    line(-46, -46, -8, -6, OUT, 12), line(-46, -46, -8, -6, '#dfe6ee', 6),
    rect(-58, -60, 22, 10, '#5a3a22', { r: 4, sw: 3, transform: 'rotate(-45 -47 -55)' }),
  ];
  return doc(128, 128, b.join(''));
}

function sabSilence() {
  const b = [
    // varita/estrella de hechizo
    star(0, -2, 40, '#c99bff', { sw: 4.4 }),
    star(0, -2, 22, '#efdcff', { noStroke: true, opacity: 0.85 }),
    // señal de prohibido
    circle(0, 0, 50, 'none', { stroke: OUT, sw: 17 }),
    circle(0, 0, 50, 'none', { stroke: '#ff4d4d', sw: 10 }),
    line(-35, 35, 35, -35, OUT, 17), line(-35, 35, 35, -35, '#ff4d4d', 10),
  ];
  return doc(128, 128, b.join(''));
}

// --- Cartas de unidades ----------------------------------------------------------------------------------------------
function unitIcon(id, layout, w = 220, h = 130) {
  const parts = layout.map(({ x, y, s }) => g(idleSvg(id), { transform: `translate(${x} ${y}) scale(${s})` }));
  return doc(w, h, parts.join(''));
}

// Icono de la aplicación: castillo con estandartes azules sobre cielo y colina.
function appIcon() {
  const { castleParts } = require('./structures');
  const recolor = (svg) => svg.replace(/#f4f4f4/g, '#4d8fff').replace(/#cfcfcf/g, '#3b73dc').replace(/#a3a3a3/g, '#2b58b3');
  const castle = castleParts();
  const defs = L.defsGradient('sky', [[0, '#4f9fe0'], [1, '#bfe6f5']]);
  const b = [
    rect(-128, -128, 256, 256, 'url(#sky)', { r: 46, noStroke: true }),
    path('M-128 40 Q-40 -10 40 30 T128 20 L128 82 Q128 128 82 128 L-82 128 Q-128 128 -128 82Z', '#6aa855', { noStroke: true }),
    circle(84, -78, 26, '#fff2a8', { noStroke: true, opacity: 0.95 }),
    g([castle.base, recolor(castle.team)], { transform: 'translate(0 26) scale(0.6)' }),
    rect(-128, -128, 256, 256, 'none', { r: 46, sw: 7 }),
  ];
  return doc(256, 256, b.join(''), defs, 1);
}

// --- Fondo de la tienda (barra inferior) según la raza -----------------------------------------------------------
// Humanos usan assets/bgShopPanel.png (madera normal); goblins madera oscura y
// elfos madera blanca. Mismo formato que el PNG: 1080x420 con borde oscuro.
const SHOP_WOODS = {
  goblin: { base: '#4f3826', grain: '#382619', grainLight: '#684a33', shade: '#1d130d', top: '#8a6b4c', rough: true },
  elf: { base: '#efe6d2', grain: '#d2c5a6', grainLight: '#fbf6ea', shade: '#b6a98c', top: '#ffffff', rough: false },
};

function shopWood(kind) {
  const w = SHOP_WOODS[kind];
  const W = 1080, H = 420;
  const r = L.rng(kind === 'elf' ? 707 : 303);
  const defs = L.defsGradient('shade', [[0, w.shade, 0], [1, w.shade, 0.85]])
    + `<clipPath id="clip"><rect x="4" y="4" width="${W - 8}" height="${H - 8}" rx="14"/></clipPath>`;
  const p = [rect(4, 4, W - 8, H - 8, w.base, { r: 14, noStroke: true })];
  const inner = [];
  // tablones: juntas horizontales
  for (const y of kind === 'elf' ? [104, 208, 312] : [96, 196, 300]) {
    inner.push(rect(0, y, W, 5, w.grain, { noStroke: true, opacity: 0.9 }));
    inner.push(rect(0, y + 5, W, 3, w.grainLight, { noStroke: true, opacity: 0.35 }));
  }
  // veta
  for (let i = 0; i < (kind === 'elf' ? 60 : 44); i++) {
    const y = r.range(10, H - 30), x = r.range(-60, W - 100), len = r.range(90, 320);
    if (w.rough) {
      inner.push(line(x, y, x + len, y, w.grain, r.range(3, 6), { opacity: 0.7 }));
    } else {
      const wave = r.range(-6, 6);
      inner.push(path(`M${L.n(x)} ${L.n(y)} Q${L.n(x + len / 2)} ${L.n(y + wave)} ${L.n(x + len)} ${L.n(y)}`, 'none', { stroke: w.grain, sw: r.range(1.6, 3.4), opacity: 0.75 }));
    }
  }
  // nudos
  for (let i = 0; i < 4; i++) {
    const x = r.range(80, W - 80), y = r.range(30, 330);
    inner.push(ellipse(x, y, 16, 8, w.grain, { noStroke: true, opacity: 0.8 }), ellipse(x, y, 8, 3.6, w.shade, { noStroke: true, opacity: 0.45 }));
  }
  if (w.rough) {
    // grietas y clavos de hierro
    for (let i = 0; i < 7; i++) {
      const x = r.range(40, W - 40), y = r.range(20, 330);
      inner.push(path(`M${L.n(x)} ${L.n(y)} l${L.n(r.range(8, 20))} ${L.n(r.range(12, 26))} l${L.n(r.range(-10, 6))} ${L.n(r.range(10, 22))}`, 'none', { stroke: w.shade, sw: 2.6, opacity: 0.6 }));
    }
    for (const x of [30, W - 30]) for (const y of [50, 150, 250, 350]) inner.push(circle(x, y, 6, '#7d7566', { sw: 2 }), circle(x - 1.5, y - 1.5, 2, '#cfc6ad', { noStroke: true, opacity: 0.8 }));
  } else {
    // hojitas sutiles a lo largo del borde superior
    for (let x = 60; x < W; x += 120) {
      inner.push(path(`M${x} 26 q10 -12 24 -6 q-8 12 -24 6Z`, '#bfe0c2', { noStroke: true, opacity: 0.8 }));
    }
  }
  p.push(`<g clip-path="url(#clip)">${inner.join('')}</g>`);
  p.push(rect(4, 4, W - 8, 8, w.top, { r: 4, noStroke: true, opacity: 0.6 }));
  p.push(`<g clip-path="url(#clip)">${rect(4, 250, W - 8, H - 254, 'url(#shade)', { noStroke: true })}</g>`);
  p.push(rect(4, 4, W - 8, H - 8, 'none', { r: 14, sw: 8 }));
  return L.docTL(W, H, p.join(''), defs, 1);
}

// --- Iconos de habilidades de castillo ---------------------------------------------------------------------------
function spellArrowRain() {
  const arrow = (x, y, a) => g([
    line(0, 18, 0, -14, OUT, 7), line(0, 18, 0, -14, C.woodLight, 3.4),
    poly([[-5, -12], [0, -26], [5, -12]], C.steelLight, { sw: 2.4 }),
    poly([[0, 22], [-6, 30], [0, 26], [6, 30]], '#d9483b', { noStroke: true }),
  ], { transform: `translate(${x} ${y}) rotate(${180 + a})` });
  const b = [
    circle(0, 12, 40, '#ffd27a', { noStroke: true, opacity: 0.35 }),
    ellipse(0, 34, 42, 11, '#000000', { noStroke: true, opacity: 0.22 }),
    arrow(-26, -6, -14), arrow(0, -14, 0), arrow(26, -4, 14), arrow(-12, 16, -8), arrow(14, 18, 8),
    sparkle(32, -30, 8, '#fff3b0', 0.95), sparkle(-34, -26, 6, '#ffffff', 0.9),
  ];
  return doc(128, 128, b.join(''));
}

function spellLightning() {
  const b = [
    circle(0, 0, 50, '#a8d6ff', { noStroke: true, opacity: 0.28 }),
    poly([[6, -52], [-22, 2], [-3, 2], [-14, 50], [26, -12], [6, -12], [22, -52]], '#ffe66b', { sw: 4.4 }),
    poly([[6, -46], [-14, -2], [4, -2], [-2, 22], [14, -20], [0, -20], [12, -46]], '#fff7b8', { noStroke: true, opacity: 0.85 }),
    sparkle(-32, -26, 8, '#ffffff', 0.95), sparkle(36, 24, 7, '#cfe8ff', 0.95), sparkle(-30, 30, 5, '#fff3b0', 0.9),
  ];
  return doc(128, 128, b.join(''));
}

function spellMilitia() {
  const tiny = (x, y, s) => g(idleSvg('soldier'), { transform: `translate(${x} ${y}) scale(${s})` });
  const b = [
    circle(0, 8, 46, '#bfe6a8', { noStroke: true, opacity: 0.35 }),
    ellipse(0, 38, 46, 11, '#000000', { noStroke: true, opacity: 0.22 }),
    tiny(-28, 10, 0.62), tiny(28, 10, 0.62), tiny(0, 4, 0.78),
    sparkle(0, -40, 9, '#fff3b0', 0.95), sparkle(-40, -12, 6, '#ffffff', 0.9),
  ];
  return doc(128, 128, b.join(''));
}

// Muslito de pollo (icono de "tropas", como el hambre de Minecraft o la comida de Warcraft):
// hueso con dos nudillos y, en el otro extremo, la carne dorada que se afina hacia el hueso.
function drumstickParts() {
  const meat = 'M-13 -6 C-10 -24 10 -34 28 -26 C46 -18 48 8 32 19 C18 28 -2 24 -11 7 Z';
  const b = [
    // hueso (caña + dos nudillos)
    line(-14, 0, -34, 0, OUT, 15), line(-14, 0, -34, 0, '#fff4dc', 8.5),
    circle(-40, -7, 8, '#fff4dc', { sw: 3.4 }), circle(-40, 7, 8, '#fff4dc', { sw: 3.4 }),
    ellipse(-41, -9, 3.2, 2, '#ffffff', { noStroke: true, opacity: 0.9 }),
    // carne
    path(meat, '#c66f26', { sw: 4.6 }),
    path('M-4 2 C-6 -14 8 -24 22 -20 C34 -16 36 -2 30 4 C20 -8 4 -8 -4 2 Z', '#e8a04f', { noStroke: true, opacity: 0.95 }),
    path('M4 -22 Q18 -28 30 -20', 'none', { stroke: '#fff2c9', sw: 4, opacity: 0.85 }),
    path('M-6 12 C6 22 26 22 36 10', 'none', { stroke: '#8a4413', sw: 4.4, opacity: 0.75 }),
    // marca de la carne junto al hueso
    path('M-13 -6 C-8 -2 -8 4 -11 7', 'none', { stroke: '#8a4413', sw: 3.2, opacity: 0.9 }),
  ];
  return b;
}

function drumstick() {
  return doc(72, 72, g(drumstickParts(), { transform: 'translate(2 2) rotate(-38) scale(0.84)' }));
}

// Carta de mejora del límite de tropas: el muslito de comida con un más verde.
function buffTroopCap() {
  const b = [
    g(drumstickParts(), { transform: 'translate(-4 8) rotate(-38) scale(1.5)' }),
    circle(32, -32, 22, '#3fae4a', { sw: 4 }),
    rect(24, -35, 16, 6, '#ffffff', { r: 2, noStroke: true }),
    rect(29, -40, 6, 16, '#ffffff', { r: 2, noStroke: true }),
    sparkle(-40, -38, 8, '#fff3b0', 0.95),
  ];
  return doc(128, 128, b.join(''));
}

function generate() {
  L.write('ui/app_icon.svg', appIcon());
  L.write('ui/coin.svg', coin());
  L.write('ui/padlock.svg', padlock());
  L.write('ui/hammer.svg', hammer());
  L.write('ui/dice.svg', dice());
  L.write('ui/drumstick.svg', drumstick());
  L.write('ui/shop_wood_goblin.svg', shopWood('goblin'));
  L.write('ui/shop_wood_elf.svg', shopWood('elf'));
  L.write('cards/buff_armor.svg', buffArmor());
  L.write('cards/buff_max_hp.svg', buffHp());
  L.write('cards/buff_move_speed.svg', buffSpeed());
  L.write('cards/buff_production.svg', buffProduction());
  L.write('cards/buff_tower_fire_rate.svg', buffFireRate());
  L.write('cards/buff_troop_cap.svg', buffTroopCap());
  L.write('cards/sabotage_freeze.svg', sabFreeze());
  L.write('cards/sabotage_block.svg', sabBlock());
  L.write('cards/sabotage_reroll.svg', sabReroll());
  L.write('cards/sabotage_steal.svg', sabSteal());
  L.write('cards/sabotage_silence.svg', sabSilence());
  L.write('cards/soldiers.svg', unitIcon('soldier', [{ x: -68, y: 4, s: 1.05 }, { x: 0, y: 4, s: 1.05 }, { x: 68, y: 4, s: 1.05 }]));
  L.write('cards/archers.svg', unitIcon('archer', [{ x: -68, y: 4, s: 1.1 }, { x: 0, y: 4, s: 1.1 }, { x: 68, y: 4, s: 1.1 }]));
  L.write('cards/tank.svg', unitIcon('tank', [{ x: 0, y: 4, s: 0.86 }], 160, 130));
  L.write('cards/cavalry.svg', unitIcon('cavalry', [{ x: 0, y: 6, s: 0.72 }], 160, 130));
  L.write('cards/mage.svg', unitIcon('mage', [{ x: 0, y: 6, s: 0.95 }], 160, 130));
  L.write('cards/venom_archer.svg', unitIcon('venom_archer', [{ x: -34, y: 6, s: 1.1 }, { x: 34, y: 6, s: 1.1 }], 160, 130));
  L.write('spells/arrow_rain.svg', spellArrowRain());
  L.write('spells/lightning.svg', spellLightning());
  L.write('spells/militia.svg', spellMilitia());
}

module.exports = { generate };
