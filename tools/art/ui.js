// Iconos de interfaz: moneda, candado, martillo, dados, iconos de mejoras y
// de cartas de unidades. Todos son SVG planos con el contorno oscuro común.

const L = require('./lib');
const { C, OUT, ellipse, circle, path, rect, poly, line, g, rot, tr, sparkle, doc } = L;
const { UNITS } = require('./units');

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

// --- Cartas de unidades ----------------------------------------------------------------------------------------------
function unitIcon(id, layout, w = 220, h = 130) {
  const u = UNITS[id];
  const parts = layout.map(({ x, y, s }) => g(u.idle(), { transform: `translate(${x} ${y}) scale(${s})` }));
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

function generate() {
  L.write('ui/app_icon.svg', appIcon());
  L.write('ui/coin.svg', coin());
  L.write('ui/padlock.svg', padlock());
  L.write('ui/hammer.svg', hammer());
  L.write('ui/dice.svg', dice());
  L.write('cards/buff_armor.svg', buffArmor());
  L.write('cards/buff_max_hp.svg', buffHp());
  L.write('cards/buff_move_speed.svg', buffSpeed());
  L.write('cards/buff_production.svg', buffProduction());
  L.write('cards/buff_tower_fire_rate.svg', buffFireRate());
  L.write('cards/soldiers.svg', unitIcon('soldier', [{ x: -68, y: 4, s: 1.05 }, { x: 0, y: 4, s: 1.05 }, { x: 68, y: 4, s: 1.05 }]));
  L.write('cards/archers.svg', unitIcon('archer', [{ x: -68, y: 4, s: 1.1 }, { x: 0, y: 4, s: 1.1 }, { x: 68, y: 4, s: 1.1 }]));
  L.write('cards/tank.svg', unitIcon('tank', [{ x: 0, y: 4, s: 0.86 }], 160, 130));
}

module.exports = { generate };
