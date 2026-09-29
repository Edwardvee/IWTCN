// Mundo: hierba (mosaico continuo), camino de tierra, arbolitos/arbustos/rocas
// muy suaves a los lados del camino y el suelo empedrado de los plots.

const L = require('./lib');
const { C, OUT, ellipse, circle, path, rect, poly, line, g, rot, tr, doc, docTL } = L;

// --- Hierba ---------------------------------------------------------------------------
const GRASS_TILE = 512;
function grassTile() {
  const r = L.rng(4242);
  const T = GRASS_TILE;
  const parts = [rect(0, 0, T, T, '#6aa74f', { noStroke: true })];
  const at = (fn) => {
    // se dibuja también desplazado un mosaico para que las juntas sean continuas
    let out = '';
    for (const dx of [-T, 0, T]) for (const dy of [-T, 0, T]) out += g(fn(), { transform: `translate(${dx} ${dy})` });
    return out;
  };
  // manchas grandes de tono
  for (let i = 0; i < 46; i++) {
    const x = r.range(0, T), y = r.range(0, T);
    const rx = r.range(30, 90), ry = r.range(20, 60);
    const col = r.pick(['#75b458', '#5f9d47', '#7bbb5c', '#639f4a']);
    parts.push(at(() => [ellipse(x, y, rx, ry, col, { noStroke: true, opacity: r.range(0.16, 0.3) })]));
  }
  // matas de hierba
  for (let i = 0; i < 260; i++) {
    const x = r.range(0, T), y = r.range(0, T);
    const s = r.range(3.5, 7);
    const col = r.pick(['#4f8c3c', '#85c465', '#5b9a45', '#94d071']);
    parts.push(at(() => [
      path(`M${x - s} ${y} L${x - s * 0.4} ${y - s * 1.5} L${x} ${y} L${x + s * 0.5} ${y - s * 1.9} L${x + s} ${y}`, 'none', { stroke: col, sw: 1.6, opacity: 0.75 }),
    ]));
  }
  // florecillas y piedrecitas
  for (let i = 0; i < 34; i++) {
    const x = r.range(0, T), y = r.range(0, T);
    const col = r.pick(['#fff1b8', '#ffffff', '#ffd6e0', '#ffe27a']);
    parts.push(at(() => [circle(x, y, 2.2, col, { noStroke: true, opacity: 0.85 }), circle(x, y, 0.9, '#e8a94a', { noStroke: true })]));
  }
  for (let i = 0; i < 14; i++) {
    const x = r.range(0, T), y = r.range(0, T);
    parts.push(at(() => [ellipse(x, y, r.range(3, 5.5), r.range(2, 3.4), '#a9b0a0', { noStroke: true, opacity: 0.55 })]));
  }
  return docTL(T, T, parts.join(''));
}

// --- Camino ---------------------------------------------------------------------------------
const ROAD_W = 400;
const ROAD_H = 1470;
function road() {
  const r = L.rng(777);
  const half = 148;
  const steps = Math.round(ROAD_H / 18);
  const wob = (y, seed) => Math.sin(y / 97 + seed) * 6 + Math.sin(y / 41 + seed * 2.3) * 3.2 + Math.sin(y / 233 + seed * 0.7) * 5;
  const apron = (y) => {
    const d = Math.abs(y) - (ROAD_H / 2 - 110);
    return d > 0 ? Math.min(1, d / 110) * 34 : 0;
  };
  const edge = (side, grow) => {
    const pts = [];
    for (let i = 0; i <= steps; i++) {
      const y = -ROAD_H / 2 + (i / steps) * ROAD_H;
      const x = side * (half + apron(y) + grow) + wob(y, side > 0 ? 1.7 : 4.1) * (grow === 0 ? 1 : 0.9);
      pts.push([x, y]);
    }
    return pts;
  };
  const ring = (grow) => {
    const left = edge(-1, grow);
    const right = edge(1, grow).reverse();
    return [...left, ...right];
  };
  const shape = (grow, fill, o = {}) => poly(ring(grow), fill, { noStroke: true, ...o });
  const parts = [];
  parts.push(shape(24, '#7c6a3d', { opacity: 0.16 }));
  parts.push(shape(15, '#86703f', { opacity: 0.32 }));
  parts.push(shape(6, '#96774a', { opacity: 0.6 }));
  parts.push(poly(ring(0), '#c39c66', { sw: 3, stroke: '#9a744a', opacity: 1 }));
  // zona central más clara y erosionada
  const inner = [];
  for (let i = 0; i <= steps; i++) {
    const y = -ROAD_H / 2 + (i / steps) * ROAD_H;
    inner.push([-96 + wob(y, 2.2) * 1.3, y]);
  }
  for (let i = steps; i >= 0; i--) {
    const y = -ROAD_H / 2 + (i / steps) * ROAD_H;
    inner.push([96 + wob(y, 5.5) * 1.3, y]);
  }
  parts.push(poly(inner, '#d3ae78', { noStroke: true, opacity: 0.5 }));
  // surcos de las ruedas
  for (const side of [-1, 1]) {
    const pts = [];
    for (let i = 0; i <= steps; i++) {
      const y = -ROAD_H / 2 + (i / steps) * ROAD_H;
      pts.push(`${i === 0 ? 'M' : 'L'}${L.n(side * 52 + wob(y, side * 3) * 0.8)} ${L.n(y)}`);
    }
    const d = pts.join(' ');
    parts.push(path(d, 'none', { stroke: '#a37a48', sw: 15, opacity: 0.5 }));
    parts.push(path(d, 'none', { stroke: '#b98e56', sw: 6, opacity: 0.55 }));
  }
  // guijarros
  for (let i = 0; i < 150; i++) {
    const y = r.range(-ROAD_H / 2 + 20, ROAD_H / 2 - 20);
    const x = r.range(-half + 12, half - 12) + wob(y, 3);
    const s = r.range(2.2, 6.5);
    parts.push(ellipse(x, y, s, s * 0.7, r.pick(['#a99a86', '#8d8271', '#c9b99a', '#9d8f7b']), { noStroke: true, opacity: 0.85 }));
    if (s > 4) parts.push(ellipse(x - s * 0.25, y - s * 0.25, s * 0.4, s * 0.25, '#ffffff', { noStroke: true, opacity: 0.3 }));
  }
  // grietas y motas
  for (let i = 0; i < 70; i++) {
    const y = r.range(-ROAD_H / 2 + 10, ROAD_H / 2 - 10);
    const x = r.range(-half, half) + wob(y, 2);
    parts.push(line(x, y, x + r.range(-9, 9), y + r.range(2, 9), '#8e6a3d', 1.6, { opacity: 0.35 }));
  }
  // matas de hierba en los bordes
  for (let i = 0; i < 200; i++) {
    const y = r.range(-ROAD_H / 2 + 10, ROAD_H / 2 - 10);
    const side = r.range(0, 1) < 0.5 ? -1 : 1;
    const x = side * (half + apron(y) + r.range(-9, 7)) + wob(y, side > 0 ? 1.7 : 4.1);
    const s = r.range(3.5, 7);
    const col = r.pick(['#4f8c3c', '#85c465', '#5b9a45']);
    parts.push(path(`M${L.n(x - s)} ${L.n(y)} L${L.n(x - s * 0.3)} ${L.n(y - s * 1.6)} L${L.n(x + s * 0.2)} ${L.n(y)} L${L.n(x + s * 0.8)} ${L.n(y - s * 1.8)} L${L.n(x + s * 1.2)} ${L.n(y)}`, 'none', { stroke: col, sw: 1.7, opacity: 0.85 }));
  }
  return doc(ROAD_W, ROAD_H, parts.join(''));
}

// --- Decoración: muy suave, casi no se nota ---------------------------------------------------------------------------
function leaf(x, y, r, base, light, dark) {
  return [
    circle(x, y + r * 0.18, r, dark, { noStroke: true }),
    circle(x, y, r, base, { noStroke: true }),
    ellipse(x - r * 0.28, y - r * 0.32, r * 0.55, r * 0.38, light, { noStroke: true, opacity: 0.75 }),
  ].join('');
}

function oakBody() {
  const b = [];
  b.push(ellipse(2, 30, 30, 8, '#000000', { noStroke: true, opacity: 0.2 }));
  b.push(rect(-4, 14, 8, 17, '#6b4a2b', { r: 2, noStroke: true }));
  b.push(leaf(-15, 8, 17, '#4d8b3a', '#7fbf5d', '#356a2d'));
  b.push(leaf(15, 8, 17, '#4d8b3a', '#7fbf5d', '#356a2d'));
  b.push(leaf(0, -8, 22, '#579a42', '#8fd06a', '#3a7431'));
  b.push(leaf(-9, -18, 12, '#61a64b', '#9ada74', '#417f36'));
  return g(b, { transform: 'translate(0 4)' });
}
function treeOak() { return doc(84, 84, oakBody()); }

function pineBody() {
  const b = [];
  b.push(ellipse(2, 34, 24, 7, '#000000', { noStroke: true, opacity: 0.2 }));
  b.push(rect(-3.5, 22, 7, 13, '#6b4a2b', { r: 2, noStroke: true }));
  for (const [y, w, col, hl] of [[16, 26, '#2f6d3a', '#4f9a55'], [-2, 22, '#37793f', '#5aa860'], [-18, 16, '#3f8646', '#68b96c']]) {
    b.push(poly([[-w, y + 12], [0, y - 22], [w, y + 12]], col, { noStroke: true }));
    b.push(poly([[-w, y + 12], [0, y - 22], [-w * 0.15, y + 12]], hl, { noStroke: true, opacity: 0.55 }));
  }
  return g(b, { transform: 'translate(0 2)' });
}
function treePine() { return doc(72, 92, pineBody()); }

function bush() {
  const b = [];
  b.push(ellipse(0, 14, 22, 5, '#000000', { noStroke: true, opacity: 0.18 }));
  b.push(leaf(-10, 4, 10, '#4d8b3a', '#7fbf5d', '#356a2d'));
  b.push(leaf(10, 5, 9, '#4d8b3a', '#7fbf5d', '#356a2d'));
  b.push(leaf(0, -2, 12, '#579a42', '#8fd06a', '#3a7431'));
  b.push(circle(-5, -4, 1.8, '#f7c6d0', { noStroke: true }), circle(6, 0, 1.8, '#fff2b0', { noStroke: true }));
  return doc(56, 44, b.join(''));
}

function rock() {
  const b = [];
  b.push(ellipse(1, 11, 20, 4.5, '#000000', { noStroke: true, opacity: 0.2 }));
  b.push(poly([[-17, 9], [-13, -3], [-3, -10], [9, -7], [17, 2], [15, 10]], '#9ea59a', { noStroke: true }));
  b.push(poly([[-13, -3], [-3, -10], [9, -7], [1, -1]], '#c3c9bd', { noStroke: true, opacity: 0.85 }));
  b.push(poly([[15, 10], [17, 2], [9, -7], [4, 3]], '#7d8479', { noStroke: true, opacity: 0.75 }));
  return doc(44, 32, b.join(''));
}

function flowers() {
  const r = L.rng(91);
  const b = [];
  for (let i = 0; i < 9; i++) {
    const x = r.range(-16, 16), y = r.range(-6, 6);
    b.push(line(x, y, x, y + 6, '#4f8c3c', 1.4));
    b.push(circle(x, y, 2.4, r.pick(['#ffffff', '#ffd6e0', '#ffe27a', '#d9c2ff']), { noStroke: true }));
    b.push(circle(x, y, 0.9, '#e8a94a', { noStroke: true }));
  }
  return doc(44, 26, b.join(''));
}


// --- Fondo del menú principal ----------------------------------------------------------------------------------------------------------
// Cielo del menú según la dificultad: normal (el de siempre), easy (con arcoíris y
// florecitas en el prado) y hard (cielo rojo amenazante con nubes oscuras y rayos).
const MENU_SKIES = {
  normal: { stops: [[0, '#4f9fe0'], [0.55, '#9ed3f0'], [1, '#e4f5f6']], glow: '#fff6c8', sun: '#fff2a8', cloud: '#ffffff', cloudShade: '#dcecf5' },
  easy: { stops: [[0, '#6db8f0'], [0.55, '#b5e0f7'], [1, '#f4fbf6']], glow: '#fff6c8', sun: '#fff2a8', cloud: '#ffffff', cloudShade: '#e6f2f8' },
  hard: { stops: [[0, '#2a0508'], [0.45, '#8f1c1c'], [1, '#e2582a']], glow: '#ff6a2a', sun: '#ffb14a', cloud: '#3a1418', cloudShade: '#1b0708' },
};

function menuFlowers(r) {
  const out = [];
  const colors = ['#ff6f91', '#ffd23f', '#ffffff', '#c98bff', '#ff9a4d', '#7fd1ff'];
  const add = (x, y, scale) => {
    const col = r.pick(colors);
    const petals = [];
    for (let k = 0; k < 5; k++) petals.push(ellipse(0, -7, 4.6, 7.4, col, { sw: 1.5, transform: `rotate(${k * 72})` }));
    out.push({ y, body: g([line(0, 2, 0, 20, '#3f7d32', 2.6), ellipse(4, 13, 6.5, 2.8, '#4f9a3f', { noStroke: true }), ...petals, circle(0, 0, 3.8, '#f5b83a', { sw: 1.2 })], { transform: `translate(${L.n(x)} ${L.n(y)}) scale(${L.n(scale)})` }) });
  };
  // franja de prado que asoma entre el castillo y el panel del menú (se ve en todo el ancho)
  for (let i = 0; i < 46; i++) add(r.range(10, 1070), r.range(668, 742), r.range(1.1, 1.7));
  // laterales del panel, más abajo
  for (let i = 0; i < 70; i++) {
    const y = r.range(742, 1900);
    const side = r() < 0.5 ? -1 : 1;
    add(540 + side * r.range(470, 535), y, r.range(1.4, 2.2));
  }
  // suelta unas flores sobre las colinas, a los lados del castillo
  for (let i = 0; i < 18; i++) add(r() < 0.5 ? r.range(10, 70) : r.range(1010, 1070), r.range(560, 668), r.range(0.9, 1.3));
  out.sort((a, b) => a.y - b.y);
  return out.map((f) => f.body);
}

// Pétalos que flotan por el cielo de la dificultad fácil.
function menuPetals(r) {
  const out = [];
  for (let i = 0; i < 16; i++) {
    const x = r.range(20, 1060), y = r.range(30, 640);
    out.push(ellipse(0, 0, 9, 5, r.pick(['#ffb3c7', '#ffffff', '#ffd6e0', '#ffe27a']), { noStroke: true, opacity: 0.9, transform: `translate(${L.n(x)} ${L.n(y)}) rotate(${L.n(r.range(-60, 60))})` }));
  }
  return out;
}

function menuBackground(variant = 'normal') {
  const { castleParts } = require('./structures');
  const r = L.rng(31337);
  const W = 1080, H = 1920;
  const sky = MENU_SKIES[variant];
  const defs = [
    L.defsGradient('sky', sky.stops),
    L.defsGradient('meadow', [[0, '#79bb5a'], [1, '#4f8f3d']]),
    L.defsGradient('glow', [[0, sky.glow, 0.9], [1, sky.glow, 0]], 'radial', 'cx="0.5" cy="0.5" r="0.5"'),
  ].join('');
  const p = [];
  p.push(rect(0, 0, W, 700, 'url(#sky)', { noStroke: true }));
  p.push(circle(860, 210, 210, 'url(#glow)', { noStroke: true }));
  p.push(circle(860, 210, variant === 'hard' ? 84 : 62, sky.sun, { noStroke: true, opacity: 0.95 }));
  if (variant === 'easy') {
    // arcoíris suave detrás de las nubes
    ['#ff6b6b', '#ffa94d', '#ffe66d', '#8ce99a', '#74c0fc', '#b197fc'].forEach((col, i) => {
      const rad = 380 - i * 20;
      p.push(path(`M${300 - rad + 200} 660 A${rad} ${rad} 0 0 1 ${300 + rad + 200} 660`, 'none', { stroke: col, sw: 20, opacity: 0.5, noStroke: false }));
    });
  }
  if (variant === 'hard') {
    // rayos lejanos
    for (const [x, y, s] of [[250, 60, 1], [700, 40, 0.8]]) {
      p.push(poly([[0, 0], [-26, 120], [-4, 116], [-38, 250], [30, 96], [6, 100], [26, 0]], '#ffe9a0', { noStroke: true, opacity: 0.85, transform: `translate(${x} ${y}) scale(${s})` }));
    }
  }
  // nubes
  for (const [x, y, s] of [[170, 150, 1.1], [560, 90, 0.8], [930, 380, 0.9], [90, 430, 0.7]]) {
    p.push(g([ellipse(0, 0, 90, 26, sky.cloud, { noStroke: true }), ellipse(-30, -18, 42, 26, sky.cloud, { noStroke: true }), ellipse(24, -24, 50, 30, sky.cloud, { noStroke: true }), ellipse(0, 10, 80, 14, sky.cloudShade, { noStroke: true, opacity: 0.6 })], { transform: `translate(${x} ${y}) scale(${s})` }));
  }
  if (variant === 'hard') {
    // murciélagos
    for (const [x, y, s] of [[330, 300, 1], [430, 240, 0.7], [700, 330, 0.9], [120, 560, 0.8]]) {
      p.push(path('M0 0 Q-14 -14 -34 -6 Q-24 0 -20 10 Q-10 0 0 8 Q10 0 20 10 Q24 0 34 -6 Q14 -14 0 0Z', '#12050a', { noStroke: true, transform: `translate(${x} ${y}) scale(${s})` }));
    }
  }
  // colinas lejanas
  p.push(path('M0 560 Q180 470 380 540 T760 520 T1080 500 L1080 760 L0 760Z', '#7fb96a', { noStroke: true }));
  p.push(path('M0 620 Q260 540 520 610 T1080 590 L1080 820 L0 820Z', '#6aa855', { noStroke: true }));
  p.push(rect(0, 680, W, H - 680, 'url(#meadow)', { noStroke: true }));
  // camino hacia el castillo
  p.push(path('M470 690 L610 690 L900 1400 L900 1920 L180 1920 L180 1400Z', '#c39c66', { noStroke: true }));
  p.push(path('M470 690 L610 690 L900 1400 L900 1920 L840 1920 L560 690Z', '#a8804d', { noStroke: true, opacity: 0.35 }));
  // castillo con estandartes azules
  const recolor = (svg) => svg.replace(/#f4f4f4/g, '#4d8fff').replace(/#cfcfcf/g, '#3b73dc').replace(/#a3a3a3/g, '#2b58b3');
  const castle = castleParts();
  p.push(g([castle.base, recolor(castle.team)], { transform: 'translate(540 500) scale(2.15)' }));
  if (variant === 'easy') p.push(...menuFlowers(L.rng(555)), ...menuPetals(L.rng(556)));
  // árboles a los lados
  const trees = [];
  for (let i = 0; i < 16; i++) {
    const side = i % 2 ? 1 : -1;
    const y = 760 + Math.floor(i / 2) * 150 + r.range(-20, 20);
    const spread = 150 + (y - 700) * 0.55;
    const x = 540 + side * (spread + r.range(30, 240));
    trees.push({ y, body: g(r() < 0.5 ? oakBody() : pineBody(), { transform: `translate(${L.n(x)} ${L.n(y)}) scale(${L.n(1.2 + (y - 700) / 900)})` }) });
  }
  trees.sort((a, b) => a.y - b.y);
  p.push(...trees.map((t) => t.body));
  return docTL(W, H, p.join(''), defs, 1);
}

// --- Suelo de los plots: adoquines ------------------------------------------------------------------------------------------
const PLOT_W = 327;
const PLOT_H = 340;
function plotFloor() {
  const r = L.rng(2024);
  const parts = [rect(0, 0, PLOT_W, PLOT_H, '#4a3f35', { noStroke: true })];
  const rows = 12;
  const rowH = PLOT_H / rows;
  for (let row = 0; row < rows; row++) {
    const y = row * rowH;
    let x = -r.range(0, 24);
    while (x < PLOT_W) {
      const w = r.range(22, 38);
      const col = r.pick(['#67594a', '#706150', '#62544a', '#786955', '#6b5c4b']);
      parts.push(rect(x + 1.5, y + 1.5, w - 3, rowH - 3, col, { r: 5, noStroke: true }));
      parts.push(rect(x + 3, y + 2.5, w - 8, 3, '#ffffff', { r: 1.5, noStroke: true, opacity: 0.06 }));
      x += w;
    }
  }
  return docTL(PLOT_W, PLOT_H, parts.join(''));
}

function generate() {
  L.write('world/grass.svg', grassTile());
  L.write('world/road.svg', road());
  L.write('world/tree_oak.svg', treeOak());
  L.write('world/tree_pine.svg', treePine());
  L.write('world/bush.svg', bush());
  L.write('world/rock.svg', rock());
  L.write('world/flowers.svg', flowers());
  L.write('world/plot_floor.svg', plotFloor());
  L.write('ui/menu_bg.svg', menuBackground('normal'));
  L.write('ui/menu_bg_easy.svg', menuBackground('easy'));
  L.write('ui/menu_bg_hard.svg', menuBackground('hard'));
}

module.exports = { generate, GRASS_TILE, ROAD_W, ROAD_H };
