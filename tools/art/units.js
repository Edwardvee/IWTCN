// Unidades vistas desde arriba (estilo RimWorld: cabeza grande, hombros, manos)
// con el aspecto grueso y saturado de Kingdom Rush. Miran hacia -Y ("arriba");
// el juego las gira 180° para el equipo de arriba. El contorno del bando lo
// dibuja un shader en el juego, aquí solo va el contorno oscuro.

const L = require('./lib');
const { withRace, recolor } = require('./races');

// Raza que se está dibujando (null = humanos). Añade orejas a las cabezas.
let raceStyle = null;
function earShapes(cy, r) {
  if (!raceStyle || !raceStyle.ears) return [];
  const e = raceStyle.ears;
  return [-1, 1].map((s) => `<polygon points="${s * (r - 3)},${cy - 4} ${s * (r + e.len)},${cy - 4 - e.rise} ${s * (r - 2)},${cy + 6}" fill="${e.color}" stroke="${OUT}" stroke-width="2.5" stroke-linejoin="round"/>`);
}
const { C, OUT, ellipse, circle, path, rect, poly, line, g, rot, tr, limb, sparkle, doc } = L;

const WALK_FRAMES = 4;
const ATTACK_FRAMES = 4;

/** Oscilación de la marcha: pies alternos, rebote y balanceo. */
function walkPose(k) {
  const phase = (k / WALK_FRAMES) * Math.PI * 2;
  const s = Math.sin(phase);
  return { stepL: s * 6, stepR: -s * 6, bob: 0.025 * Math.abs(Math.cos(phase)), sway: s * 3, swing: s * 3 };
}
const IDLE_POSE = { stepL: 0, stepR: 0, bob: 0, sway: 0, swing: 0 };

function boot(x, y, color, rx = 6, ry = 8.5) {
  return ellipse(x, y, rx, ry, color);
}

// --- Soldado: espada y escudo redondo ------------------------------------------
const SOLDIER_SIZE = 112;
function sword(hx, hy, angle, o = {}) {
  const len = o.len || 32;
  const blade = [
    path(`M-3.2 -6 L-3.2 ${-len} L0 ${-len - 7} L3.2 ${-len} L3.2 -6 Z`, C.steel),
    path(`M0 -6 L0 ${-len - 6} L3.2 ${-len} L3.2 -6 Z`, C.steelLight, { noStroke: true, opacity: 0.85 }),
    rect(-8, -8, 16, 5, C.gold, { r: 2 }),
    rect(-2.4, -4, 4.8, 12, C.leatherDark),
    circle(0, 10, 3.2, C.gold),
  ];
  return g(blade, { transform: `translate(${hx} ${hy}) rotate(${angle})` });
}

function drawSoldier(p, arc = 0) {
  const hx = p.hx === undefined ? 17 : p.hx;
  const hy = p.hy === undefined ? -12 : p.hy;
  const ang = p.swordAng === undefined ? p.swing : p.swordAng;
  const upper = [];
  // escudo (brazo izquierdo)
  upper.push(limb(-18, 3, -21, -8 + p.swing * 0.4, 6, C.leatherDark));
  upper.push(ellipse(-25, -7 + p.swing * 0.4, 10.5, 15.5, C.woodLight, { transform: rot(-6, -25, -7) }));
  upper.push(ellipse(-25, -7 + p.swing * 0.4, 8, 12.5, C.wood, { noStroke: true, transform: rot(-6, -25, -7) }));
  upper.push(ellipse(-25, -7 + p.swing * 0.4, 10.5, 15.5, 'none', { stroke: C.steel, sw: 2.5, transform: rot(-6, -25, -7) }));
  upper.push(circle(-25, -7 + p.swing * 0.4, 4.2, C.steelLight));
  // torso
  upper.push(ellipse(0, 6, 21, 15, C.leather));
  upper.push(path('M-16 12 Q0 23 16 12 Q0 17 -16 12Z', C.leatherDark, { noStroke: true, opacity: 0.6 }));
  upper.push(ellipse(0, 4, 13, 9.5, C.steel));
  upper.push(ellipse(-3, 1, 6.5, 4, C.steelLight, { noStroke: true, opacity: 0.75 }));
  upper.push(rect(-13, 8, 26, 4, C.gold, { noStroke: true, opacity: 0.9 }));
  upper.push(circle(-19, 3, 8.5, C.steel));
  upper.push(circle(19, 3, 8.5, C.steel));
  upper.push(circle(-21, 1, 3.6, C.steelLight, { noStroke: true, opacity: 0.8 }));
  upper.push(circle(17, 1, 3.6, C.steelLight, { noStroke: true, opacity: 0.8 }));
  // brazo y espada
  upper.push(limb(18, 3, hx, hy, 6, C.leatherDark));
  upper.push(circle(hx, hy, 5, C.skin));
  const swordSvg = sword(hx, hy, ang);
  const slash = arc > 0 ? path('M-6 -26 Q-40 -30 -44 8 Q-30 -12 -6 -20 Z', '#ffffff', { noStroke: true, opacity: 0.55 * arc, transform: `translate(${arc > 0.9 ? 4 : 12} -14)` }) : '';
  // cabeza: casco con cresta
  const head = [
    ...earShapes(-5, 14),
    circle(0, -5, 14, C.steel),
    ellipse(-4, -9, 8, 5.5, C.steelLight, { noStroke: true, opacity: 0.8 }),
    path('M-3 -19 L3 -19 L3.5 8 L-3.5 8 Z', C.goldDark, { noStroke: true, opacity: 0.9 }),
    path('M-8 -15.5 Q0 -19.5 8 -15.5', 'none', { stroke: OUT, sw: 3 }),
  ];
  return g([
    boot(-8, 14 + p.stepL, C.leatherDark), boot(8, 14 + p.stepR, C.leatherDark),
    g(upper, { transform: rot(p.lean || 0, 0, 6) }),
    slash, swordSvg,
    g(head, { transform: rot((p.lean || 0) * 0.5, 0, 6) }),
  ], { transform: `scale(${1 + p.bob})` });
}

// --- Arquero: capucha verde y arco -----------------------------------------------
const ARCHER_SIZE = 104;
function drawArcher(p, nockY = -22, arrow = false, handY = null, venom = false) {
  const bx = -3;
  const bowTipY = -20;
  const stringHandY = handY === null ? nockY : handY;
  const parts = [];
  // carcaj a la espalda
  parts.push(g([
    rect(-4, -2, 8, 22, C.leather, { r: 3 }),
    line(-2, -2, -3.5, -9, C.creamDark, 1.8), line(1, -2, 2.5, -10, '#d95b4a', 1.8), line(3, -2, 5, -8, C.creamDark, 1.8),
  ], { transform: `translate(12 13) rotate(18)` }));
  parts.push(boot(-8, 14 + p.stepL, '#4a3a22', 5.5, 8), boot(8, 14 + p.stepR, '#4a3a22', 5.5, 8));
  const upper = [];
  upper.push(ellipse(0, 6, 19, 14, C.green));
  upper.push(path('M-14 11 Q0 21 14 11 Q0 16 -14 11Z', C.greenDark, { noStroke: true, opacity: 0.65 }));
  upper.push(path('M-16 0 L14 14', 'none', { stroke: C.leather, sw: 5 }));
  upper.push(circle(-17, 3, 7, C.greenDark));
  upper.push(circle(17, 3, 7, C.greenDark));
  // brazo izquierdo sostiene el arco
  upper.push(limb(-16, 3, bx - 1, -27, 5.5, C.greenDark));
  // arco
  const pull = stringHandY;
  const bowD = `M-21 ${bowTipY} Q${bx} -50 15 ${bowTipY}`;
  upper.push(path(bowD, 'none', { stroke: OUT, sw: 8 }));
  upper.push(path(bowD, 'none', { stroke: C.woodLight, sw: 4.2 }));
  upper.push(path(`M-21 ${bowTipY} L${bx} ${pull} L15 ${bowTipY}`, 'none', { stroke: '#f3ead2', sw: 1.6 }));
  upper.push(circle(bx - 1, -27, 4.4, C.skin));
  if (arrow) {
    upper.push(line(bx, pull, bx, -42, C.woodDark, 2.6));
    upper.push(poly([[bx - 3.6, -41], [bx, -49.5], [bx + 3.6, -41]], venom ? '#7cf03a' : C.steelLight, { sw: 2 }));
    if (venom) upper.push(circle(bx, -53, 3, '#b8ff7a', { noStroke: true, opacity: 0.9 }), circle(bx + 4, -46, 1.8, '#7cf03a', { noStroke: true }));
    upper.push(poly([[bx - 4, pull + 3], [bx, pull - 2], [bx + 4, pull + 3], [bx, pull + 8]], '#d95b4a', { noStroke: true }));
  }
  // brazo que tensa
  upper.push(limb(17, 3, bx + 1, pull + 2, 5.5, C.greenDark));
  upper.push(circle(bx + 1, pull + 2, 4.4, C.skin));
  if (venom) {
    // frasco de veneno al cinto
    upper.push(circle(-13, 13, 5.4, '#7cf03a', { sw: 2.2 }), rect(-15, 5, 4, 5, C.creamDark, { r: 1.5, sw: 1.6 }), circle(-14.6, 11.6, 1.6, '#e6ffc8', { noStroke: true }));
  }
  parts.push(g(upper, { transform: rot(p.lean || 0, 0, 6) }));
  // capucha con punta atrás
  parts.push(g([
    poly([[-9, 4], [0, 19], [9, 4]], C.greenDark),
    ...earShapes(-5, 13.5),
    circle(0, -5, 13.5, C.green),
    ellipse(-4, -9, 7.5, 5, C.greenLight, { noStroke: true, opacity: 0.8 }),
    path('M-6.5 -13.5 Q0 -17 6.5 -13.5 Q0 -10 -6.5 -13.5Z', C.skin, { sw: 2 }),
    path('M0 -6 L0 14', 'none', { stroke: C.greenDark, sw: 2 }),
  ], { transform: rot((p.lean || 0) * 0.5, 0, 6) }));
  return g(parts, { transform: `scale(${1 + p.bob})` });
}

// --- Sacerdote: túnica clara, halo y bastón -----------------------------------------
const PRIEST_SIZE = 128;
function drawPriest(p, cast = 0) {
  const parts = [];
  parts.push(boot(-7, 17 + p.stepL, C.creamDark, 5.5, 7), boot(7, 17 + p.stepR, C.creamDark, 5.5, 7));
  const glowR = 10 + cast * 9;
  const staffTopY = -36 - cast * 3;
  const staff = [
    circle(18, staffTopY - 4, glowR + 4, '#9be8ff', { noStroke: true, opacity: 0.18 + cast * 0.12 }),
    circle(18, staffTopY - 4, glowR, '#b8f1ff', { noStroke: true, opacity: 0.35 + cast * 0.15 }),
    line(18, 16, 18, staffTopY, OUT, 8), line(18, 16, 18, staffTopY, C.gold, 4),
    circle(18, staffTopY - 4, 6.5, '#e6fbff'),
    circle(16.5, staffTopY - 6, 2.5, '#ffffff', { noStroke: true }),
  ];
  const robe = [
    ellipse(0, 9, 24, 18, C.cream),
    path('M-18 15 Q0 27 18 15 Q0 20 -18 15Z', C.creamDark, { noStroke: true, opacity: 0.85 }),
    ellipse(0, 9, 24, 18, 'none', { stroke: C.gold, sw: 2.6 }),
    path('M-4 -6 L4 -6 L4 22 L-4 22 Z', C.gold, { noStroke: true, opacity: 0.95 }),
    circle(-21, 3, 8.5, C.cream), circle(21, 3, 8.5, C.cream),
  ];
  const lx = cast > 0 ? -14 : -16;
  const ly = cast > 0 ? -21 : -13;
  const handL = [
    limb(-19, 4, lx, ly, 5.5, C.creamDark),
    circle(lx, ly, 4.6, C.skin),
  ];
  const handR = [limb(19, 4, 18, -8, 5.5, C.creamDark), circle(18, -8, 4.6, C.skin)];
  const head = [
    ...earShapes(-9, 12.5),
    circle(0, -9, 12.5, C.cream),
    ellipse(-4, -13, 7, 4.6, C.white, { noStroke: true, opacity: 0.8 }),
    path('M-7 -16 Q0 -22 7 -16 Q0 -11.5 -7 -16Z', C.skin, { sw: 2 }),
    path('M0 -8 L0 8', 'none', { stroke: C.creamDark, sw: 2 }),
  ];
  const halo = [
    circle(0, -9, 19, C.goldLight, { noStroke: true, opacity: 0.5 }),
    ellipse(0, -9, 19, 19, 'none', { stroke: OUT, sw: 6 }),
    ellipse(0, -9, 19, 19, 'none', { stroke: C.gold, sw: 3 }),
  ];
  const sparks = cast > 0 ? [sparkle(-26, -30, 6, '#ffffff', 0.9 * cast), sparkle(28, -14, 5, '#e6fbff', 0.9 * cast), sparkle(-8, -42, 4, '#ffe58f', 0.9 * cast)] : [];
  parts.push(g(robe, { transform: rot(p.sway, 0, 8) }));
  parts.push(...handR, ...staff, ...handL);
  parts.push(g([...halo, ...head], { transform: rot(p.sway * 0.5, 0, 8) }));
  parts.push(...sparks);
  return g(parts, { transform: `scale(${1 + p.bob})` });
}

// --- Tanque: armadura completa, escudo torre y maza ---------------------------------------
const TANK_SIZE = 148;
function drawTank(p, swing = 0) {
  const parts = [];
  parts.push(boot(-12, 20 + p.stepL, C.steelDeep, 9, 11), boot(12, 20 + p.stepR, C.steelDeep, 9, 11));
  const upper = [];
  // escudo torre a la izquierda
  upper.push(limb(-27, 5, -30, -14, 8, C.steelDark));
  upper.push(rect(-46, -48, 32, 56, C.slateLight, { r: 8 }));
  upper.push(rect(-42, -44, 24, 48, C.slate, { r: 5, noStroke: true, opacity: 0.85 }));
  upper.push(path('M-46 -48 L-14 -48 L-14 -30 L-46 -30Z', C.steelLight, { noStroke: true, opacity: 0.35 }));
  upper.push(line(-30, -44, -30, 4, C.gold, 4));
  upper.push(circle(-30, -20, 6.5, C.gold));
  upper.push(circle(-30, -20, 3, C.goldDark, { noStroke: true }));
  for (const [rx, ry] of [[-41, -42], [-19, -42], [-41, 2], [-19, 2]]) upper.push(circle(rx, ry, 2.4, C.steelLight, { sw: 1.5 }));
  // torso
  upper.push(ellipse(0, 7, 31, 20, C.steelDark));
  upper.push(ellipse(0, 4, 21, 13.5, C.steel));
  upper.push(ellipse(-5, 0, 10, 5.5, C.steelLight, { noStroke: true, opacity: 0.7 }));
  upper.push(path('M-22 13 Q0 28 22 13 Q0 20 -22 13Z', C.steelDeep, { noStroke: true, opacity: 0.6 }));
  upper.push(rect(-20, 10, 40, 5, C.gold, { noStroke: true, opacity: 0.9 }));
  // hombreras con pinchos
  for (const sx of [-1, 1]) {
    upper.push(poly([[sx * 33, -6], [sx * 42, -14], [sx * 38, -1]], C.steelLight, { sw: 2 }));
    upper.push(circle(sx * 30, 5, 13, C.steel));
    upper.push(circle(sx * 32, 2, 5.5, C.steelLight, { noStroke: true, opacity: 0.8 }));
  }
  // martillo a la derecha
  const ang = swing;
  upper.push(limb(29, 5, 30, -14, 8, C.steelDark));
  upper.push(g([
    rect(-3, -42, 6, 58, C.woodDark, { r: 2 }),
    rect(-13, -58, 26, 22, C.steel, { r: 4 }),
    rect(-13, -58, 26, 7, C.steelLight, { r: 4, noStroke: true, opacity: 0.8 }),
    rect(-13, -43, 26, 6, C.steelDeep, { noStroke: true, opacity: 0.7 }),
    circle(-8, -47, 1.8, C.gold, { noStroke: true }), circle(8, -47, 1.8, C.gold, { noStroke: true }),
  ], { transform: `translate(30 -14) rotate(${ang})` }));
  upper.push(circle(30, -14, 6.5, C.steelDeep));
  parts.push(g(upper, { transform: rot(p.lean || 0, 0, 8) }));
  // yelmo cerrado con cresta
  parts.push(g([
    circle(0, -6, 18, C.steelDark),
    circle(0, -6, 15, C.steel, { noStroke: true }),
    ellipse(-5, -11, 9, 6, C.steelLight, { noStroke: true, opacity: 0.85 }),
    rect(-3.5, -24, 7, 36, C.goldDark, { noStroke: true, opacity: 0.95 }),
    path('M-11 -18 Q0 -23 11 -18', 'none', { stroke: OUT, sw: 4 }),
    line(-9, -15, 9, -15, OUT, 2.4),
  ], { transform: rot((p.lean || 0) * 0.5, 0, 8) }));
  return g(parts, { transform: `scale(${1 + p.bob})` });
}

// --- Caballería (humanos): caballo visto desde arriba, jinete con lanza --------------------------------------
const CAVALRY_SIZE = 170;
function drawCavalry(p, thrust = 0) {
  const HORSE = '#8b5a2b', HORSE_DARK = '#5a3620', HORSE_LIGHT = '#b07a45';
  const parts = [];
  // patas (alternan al galopar)
  const hoof = (x, y) => ellipse(x, y, 6, 9, '#2e2118');
  parts.push(hoof(-15, -14 + p.stepL * 1.4), hoof(15, -14 + p.stepR * 1.4), hoof(-15, 40 + p.stepR * 1.4), hoof(15, 40 + p.stepL * 1.4));
  // cola
  parts.push(path('M0 56 Q-12 74 -4 88 Q6 76 4 58Z', HORSE_DARK));
  // cuerpo y cabeza del caballo
  parts.push(ellipse(0, 22, 25, 42, HORSE));
  parts.push(ellipse(-8, 8, 8, 28, HORSE_LIGHT, { noStroke: true, opacity: 0.55 }));
  parts.push(path('M-20 50 Q0 66 20 50 Q0 58 -20 50Z', HORSE_DARK, { noStroke: true, opacity: 0.6 }));
  parts.push(ellipse(0, -34, 13, 22, HORSE));
  parts.push(poly([[-12, -42], [-19, -58], [-6, -50]], HORSE_DARK, { sw: 2.4 }), poly([[12, -42], [19, -58], [6, -50]], HORSE_DARK, { sw: 2.4 }));
  parts.push(ellipse(0, -50, 8, 8, HORSE_LIGHT, { noStroke: true, opacity: 0.7 }));
  parts.push(path('M0 -56 L0 6', 'none', { stroke: HORSE_DARK, sw: 6 }));
  // manta y silla con el azul del reino
  parts.push(rect(-22, 4, 44, 30, '#3f6fb5', { r: 8 }));
  parts.push(rect(-22, 4, 44, 9, '#7cb0ff', { r: 8, noStroke: true, opacity: 0.6 }));
  parts.push(rect(-22, 26, 44, 6, C.gold, { noStroke: true, opacity: 0.9 }));
  // lanza (a la derecha del jinete, apuntando hacia delante)
  const lanceY = -thrust * 22;
  parts.push(g([
    line(0, 40, 0, -104, OUT, 8), line(0, 40, 0, -104, C.woodLight, 4.4),
    poly([[-5, -102], [0, -126], [5, -102]], C.steelLight, { sw: 2.6 }),
    poly([[0, -96], [22, -90], [0, -80]], '#d9483b', { sw: 2.2 }),
  ], { transform: `translate(26 ${lanceY})` }));
  // jinete
  const rider = [
    limb(-17, 16, -21, 4, 6, C.leatherDark),
    ellipse(-25, 6, 9, 13, C.woodLight),
    ellipse(-25, 6, 6.5, 10, C.wood, { noStroke: true }),
    circle(-25, 6, 3.6, C.steelLight),
    ellipse(0, 20, 19, 14, C.steel),
    ellipse(-3, 16, 8, 5, C.steelLight, { noStroke: true, opacity: 0.75 }),
    rect(-13, 22, 26, 4, C.gold, { noStroke: true, opacity: 0.9 }),
    circle(-17, 19, 8, C.steel), circle(17, 19, 8, C.steel),
    limb(17, 19, 26, 8 + lanceY, 6, C.leatherDark),
    circle(26, 8 + lanceY, 5, C.skin),
  ];
  parts.push(g(rider, { transform: rot(p.lean || 0, 0, 22) }));
  parts.push(g([
    ...earShapes(6, 13),
    circle(0, 6, 13, C.steel),
    ellipse(-4, 2, 7.5, 5, C.steelLight, { noStroke: true, opacity: 0.8 }),
    path('M-3 -8 L3 -8 L3.5 18 L-3.5 18 Z', C.goldDark, { noStroke: true, opacity: 0.9 }),
    path('M-8 -3 Q0 -7 8 -3', 'none', { stroke: OUT, sw: 3 }),
    path('M0 -6 Q-8 -20 -3 -30 Q4 -22 0 -6Z', '#d9483b', { sw: 2 }),
  ], { transform: rot((p.lean || 0) * 0.5, 0, 22) }));
  return g(parts, { transform: `scale(${1 + p.bob})` });
}

// --- Mago (elfos): túnica violeta, sombrero puntiagudo y bastón con orbe ---------------------------
const MAGE_SIZE = 128;
function drawMage(p, cast = 0) {
  const ROBE = '#5b3d9a', ROBE_DARK = '#3d2870', ROBE_LIGHT = '#8a68d6';
  const parts = [];
  parts.push(boot(-7, 17 + p.stepL, ROBE_DARK, 5.5, 7), boot(7, 17 + p.stepR, ROBE_DARK, 5.5, 7));
  const orbY = -38 - cast * 4;
  const glow = 9 + cast * 10;
  parts.push(g([
    circle(20, orbY - 4, glow + 8, '#d9a8ff', { noStroke: true, opacity: 0.16 + cast * 0.14 }),
    circle(20, orbY - 4, glow, '#e6c4ff', { noStroke: true, opacity: 0.4 + cast * 0.2 }),
    line(20, 16, 20, orbY, OUT, 8), line(20, 16, 20, orbY, C.woodLight, 4),
    circle(20, orbY - 4, 7.4, '#f2dcff'),
    circle(18.4, orbY - 6.4, 2.6, '#ffffff', { noStroke: true }),
    poly([[13, orbY + 2], [20, orbY + 12], [27, orbY + 2]], C.gold, { sw: 2 }),
  ]));
  parts.push(g([
    ellipse(0, 9, 24, 18, ROBE),
    path('M-18 15 Q0 27 18 15 Q0 20 -18 15Z', ROBE_DARK, { noStroke: true, opacity: 0.85 }),
    ellipse(0, 9, 24, 18, 'none', { stroke: C.gold, sw: 2.6 }),
    path('M-4 -6 L4 -6 L4 22 L-4 22 Z', C.gold, { noStroke: true, opacity: 0.95 }),
    ellipse(-6, 2, 8, 5, ROBE_LIGHT, { noStroke: true, opacity: 0.6 }),
    circle(-21, 3, 8.5, ROBE), circle(21, 3, 8.5, ROBE),
  ], { transform: rot(p.sway, 0, 8) }));
  const lx = cast > 0 ? -14 : -17;
  const ly = cast > 0 ? -22 : -12;
  parts.push(limb(19, 4, 20, -8, 5.5, ROBE_DARK), circle(20, -8, 4.6, C.skin));
  parts.push(limb(-19, 4, lx, ly, 5.5, ROBE_DARK), circle(lx, ly, 4.6, C.skin));
  // cabeza con sombrero de bruja visto desde arriba: ala circular y punta caída
  parts.push(g([
    ...earShapes(-9, 12.5),
    circle(0, -9, 12.5, C.skin),
    ellipse(0, -6, 21, 19, ROBE_DARK),
    ellipse(0, -6, 21, 19, 'none', { stroke: C.gold, sw: 2.4 }),
    path('M-12 -8 Q0 -46 10 -30 Q4 -20 12 -8 Q0 -2 -12 -8Z', ROBE),
    path('M-6 -12 Q-2 -30 6 -30', 'none', { stroke: ROBE_LIGHT, sw: 3, opacity: 0.7 }),
    rect(-11, -10, 22, 5, C.gold, { r: 2, noStroke: true, opacity: 0.9 }),
  ], { transform: rot(p.sway * 0.5, 0, 8) }));
  if (cast > 0) parts.push(sparkle(-28, -30, 6, '#ffffff', 0.9 * cast), sparkle(30, -14, 5, '#f2dcff', 0.9 * cast), sparkle(4, -52, 4, '#ffe58f', 0.9 * cast));
  return g(parts, { transform: `scale(${1 + p.bob})` });
}

// --- Definiciones de animación -------------------------------------------------------
const ATTACK_SOLDIER = [
  { swordAng: 55, hx: 20, hy: -4, lean: 7 },
  { swordAng: -5, hx: 14, hy: -20, lean: -4, arc: 0.6 },
  { swordAng: -68, hx: 10, hy: -18, lean: -7, arc: 1 },
  { swordAng: -18, hx: 15, hy: -14, lean: -2 },
];
const ATTACK_ARCHER = [
  { nockY: -14, arrow: true },
  { nockY: -4, arrow: true },
  { nockY: -22, arrow: false },
  { nockY: -20, arrow: false },
];
const ATTACK_TANK = [-30, -55, 25, 8];
const ATTACK_PRIEST = [0.4, 1, 0.8, 0.3];
const ATTACK_CAVALRY = [0, 0.6, 1, 0.3];

// Unidades especiales: cada una solo la usa su raza (race) y se dibuja con su paleta.
const UNITS = {
  soldier: {
    size: SOLDIER_SIZE,
    walk: (k) => drawSoldier({ ...walkPose(k) }),
    idle: () => drawSoldier({ ...IDLE_POSE }),
    attack: (k) => {
      const a = ATTACK_SOLDIER[k];
      return drawSoldier({ ...IDLE_POSE, ...a }, a.arc || 0);
    },
  },
  archer: {
    size: ARCHER_SIZE,
    walk: (k) => drawArcher({ ...walkPose(k) }),
    idle: () => drawArcher({ ...IDLE_POSE }),
    attack: (k) => {
      const a = ATTACK_ARCHER[k];
      return drawArcher({ ...IDLE_POSE, lean: k === 1 ? 3 : 0 }, a.nockY, a.arrow);
    },
  },
  priest: {
    size: PRIEST_SIZE,
    walk: (k) => drawPriest({ ...walkPose(k) }),
    idle: () => drawPriest({ ...IDLE_POSE }),
    attack: (k) => drawPriest({ ...IDLE_POSE }, ATTACK_PRIEST[k]),
  },
  cavalry: {
    race: null,
    special: true,
    size: CAVALRY_SIZE,
    walk: (k) => drawCavalry({ ...walkPose(k) }),
    idle: () => drawCavalry({ ...IDLE_POSE }),
    attack: (k) => drawCavalry({ ...IDLE_POSE, lean: k === 2 ? -4 : 2 }, ATTACK_CAVALRY[k]),
  },
  mage: {
    race: 'elf',
    special: true,
    size: MAGE_SIZE,
    walk: (k) => drawMage({ ...walkPose(k) }),
    idle: () => drawMage({ ...IDLE_POSE }),
    attack: (k) => drawMage({ ...IDLE_POSE }, ATTACK_PRIEST[k]),
  },
  venom_archer: {
    race: 'goblin',
    special: true,
    size: ARCHER_SIZE,
    walk: (k) => drawArcher({ ...walkPose(k) }, -22, false, null, true),
    idle: () => drawArcher({ ...IDLE_POSE }, -22, false, null, true),
    attack: (k) => {
      const a = ATTACK_ARCHER[k];
      return drawArcher({ ...IDLE_POSE, lean: k === 1 ? 3 : 0 }, a.nockY, a.arrow, null, true);
    },
  },
  tank: {
    size: TANK_SIZE,
    walk: (k) => drawTank({ ...walkPose(k), swing: 0 }, walkPose(k).swing),
    idle: () => drawTank({ ...IDLE_POSE }, 0),
    attack: (k) => drawTank({ ...IDLE_POSE, lean: k === 2 ? -5 : (k === 0 ? 4 : 0) }, ATTACK_TANK[k]),
  },
};

/** Escribe los SVG y el SpriteFrames de una unidad. */
function writeUnit(id, u, dir, dataDir, race) {
  const svg = (body) => recolor(doc(u.size, u.size, body), race);
  L.write(`${dir}/${id}/idle.svg`, svg(u.idle()));
  for (let k = 0; k < WALK_FRAMES; k++) L.write(`${dir}/${id}/walk_${k}.svg`, svg(u.walk(k)));
  for (let k = 0; k < ATTACK_FRAMES; k++) L.write(`${dir}/${id}/attack_${k}.svg`, svg(u.attack(k)));
  const res = (name) => `res://assets/${dir}/${id}/${name}.svg`;
  L.writeData(`${dataDir}/${id}_frames.tres`, L.spriteFramesTres([
    { name: 'idle', frames: [res('idle')], speed: 5, loop: true },
    { name: 'walk', frames: [0, 1, 2, 3].map((k) => res(`walk_${k}`)), speed: 8, loop: true },
    { name: 'attack', frames: [0, 1, 2, 3].map((k) => res(`attack_${k}`)), speed: 14, loop: false },
  ]));
}

/** Genera las unidades de los humanos (raceId null) o de una raza (ver races.js). */
function generate(raceId = null) {
  withRace(raceId, (race) => {
    raceStyle = race;
    const dir = raceId ? `units/${raceId}` : 'units';
    const dataDir = raceId ? `data/races/${raceId}` : 'data/units';
    for (const [id, u] of Object.entries(UNITS)) {
      if (!u.special) writeUnit(id, u, dir, dataDir, race);
    }
    raceStyle = null;
  });
  if (!raceId) generateSpecials();
}

/** Unidades especiales: una por raza, dibujadas con la paleta de su raza. */
function generateSpecials() {
  for (const [id, u] of Object.entries(UNITS)) {
    if (!u.special) continue;
    withRace(u.race, (race) => {
      raceStyle = race;
      writeUnit(id, u, 'units', 'data/units', race);
      raceStyle = null;
    });
  }
}

/** SVG (sin envolver) de la pose de reposo de una unidad con la paleta de su raza. */
function idleSvg(id) {
  const u = UNITS[id];
  return withRace(u.race || null, (race) => {
    raceStyle = race;
    try {
      return recolor(u.idle(), race);
    } finally {
      raceStyle = null;
    }
  });
}

module.exports = { UNITS, WALK_FRAMES, ATTACK_FRAMES, generate, idleSvg };
