// Emotes de la partida (cuatro caritas con el mismo contorno oscuro que el resto
// del arte) y banderas del selector de idioma.
// Se dibujan en un lienzo de 128x128 con el origen en el centro.

const L = require('./lib');
const { OUT, ellipse, circle, path, rect, poly, line, g, doc, sparkle } = L;

const YELLOW = '#ffcf4a';
const YELLOW_DARK = '#e0a52a';
const GREEN = '#8fd15a';
const GREEN_DARK = '#5d9a34';

// Gota de lágrima (punta arriba).
const tear = (x, y, s = 1, fill = '#7fd3ff') =>
  path(`M${x} ${y - 9 * s} Q${x + 8 * s} ${y + 1 * s} ${x + 6 * s} ${y + 6 * s} Q${x} ${y + 12 * s} ${x - 6 * s} ${y + 6 * s} Q${x - 8 * s} ${y + 1 * s} ${x} ${y - 9 * s}Z`, fill, { sw: 2.6 });

// --- Goblin riéndose -------------------------------------------------------------------------------------
function goblinLaugh() {
  const b = [];
  // orejas grandes y puntiagudas
  b.push(path('M-34 -6 L-62 -34 L-58 4 L-36 16Z', GREEN, { sw: 4 }));
  b.push(path('M34 -6 L62 -34 L58 4 L36 16Z', GREEN, { sw: 4 }));
  b.push(path('M-38 -2 L-54 -22 L-52 2 L-38 10Z', '#d98aa8', { noStroke: true, opacity: 0.85 }));
  b.push(path('M38 -2 L54 -22 L52 2 L38 10Z', '#d98aa8', { noStroke: true, opacity: 0.85 }));
  // cabeza
  b.push(ellipse(0, 6, 44, 42, GREEN, { sw: 4.4 }));
  b.push(path('M-40 14 Q-30 44 0 48 Q30 44 40 14 Q30 34 0 36 Q-30 34 -40 14Z', GREEN_DARK, { noStroke: true, opacity: 0.55 }));
  b.push(path('M-30 -20 Q-16 -34 2 -32', 'none', { stroke: '#ffffff', sw: 4, opacity: 0.35 }));
  // ojos cerrados de risa (^ ^) y cejas
  b.push(path('M-30 -8 Q-21 -22 -11 -8', 'none', { stroke: OUT, sw: 5.6 }));
  b.push(path('M11 -8 Q21 -22 30 -8', 'none', { stroke: OUT, sw: 5.6 }));
  b.push(path('M-32 -24 Q-22 -32 -10 -26', 'none', { stroke: GREEN_DARK, sw: 4 }));
  b.push(path('M10 -26 Q22 -32 32 -24', 'none', { stroke: GREEN_DARK, sw: 4 }));
  // nariz
  b.push(path('M-4 -4 Q0 -12 4 -4 Q6 4 0 5 Q-6 4 -4 -4Z', GREEN_DARK, { sw: 2.6 }));
  // boca abierta: dientes arriba, lengua abajo
  b.push(path('M-30 10 Q0 18 30 10 Q28 42 0 46 Q-28 42 -30 10Z', '#5a1626', { sw: 4 }));
  b.push(path('M-26 12 Q0 19 26 12 L24 22 Q0 27 -24 22Z', '#fff7e0', { noStroke: true }));
  b.push(path('M-8 22 L-6 28 L-2 22Z', '#fff7e0', { sw: 1.6 }));
  b.push(ellipse(0, 40, 15, 9, '#ef7a95', { noStroke: true }));
  b.push(path('M-12 34 Q0 30 12 34', 'none', { stroke: '#c9506e', sw: 2.6 }));
  // mofletes
  b.push(ellipse(-30, 12, 8, 5, '#e58a8a', { noStroke: true, opacity: 0.6 }));
  b.push(ellipse(30, 12, 8, 5, '#e58a8a', { noStroke: true, opacity: 0.6 }));
  // lágrimas de risa y rayitas de movimiento
  b.push(tear(-54, 8, 1.1));
  b.push(tear(54, 8, 1.1));
  b.push(tear(-46, 28, 0.8));
  b.push(tear(46, 28, 0.8));
  b.push(line(-64, -46, -56, -40, OUT, 4));
  b.push(line(64, -46, 56, -40, OUT, 4));
  b.push(line(-14, -52, -12, -44, OUT, 4));
  b.push(line(14, -52, 12, -44, OUT, 4));
  return doc(128, 128, g(b, { transform: 'translate(0 4) rotate(-5)' }));
}

// Cara amarilla base (cara redonda sin rasgos).
const round = (extra = []) => [
  circle(0, 0, 50, YELLOW, { sw: 4.6 }),
  path('M-46 14 Q-30 48 0 50 Q30 48 46 14 Q30 38 0 40 Q-30 38 -46 14Z', YELLOW_DARK, { noStroke: true, opacity: 0.6 }),
  path('M-34 -28 Q-18 -42 4 -40', 'none', { stroke: '#ffffff', sw: 5, opacity: 0.55 }),
  ...extra,
];

// --- Llorando ------------------------------------------------------------------------------------------------------------
function cry() {
  const b = round([
    path('M-34 -22 Q-22 -32 -10 -24', 'none', { stroke: OUT, sw: 4.6 }),
    path('M10 -24 Q22 -32 34 -22', 'none', { stroke: OUT, sw: 4.6 }),
    path('M-32 -8 Q-21 -18 -10 -8', 'none', { stroke: OUT, sw: 5.4 }),
    path('M10 -8 Q21 -18 32 -8', 'none', { stroke: OUT, sw: 5.4 }),
    path('M-22 30 Q0 12 22 30 Q0 22 -22 30Z', OUT, { sw: 4 }),
    // chorros de lágrimas
    path('M-27 -6 Q-36 12 -34 30 Q-22 32 -20 12Z', '#7fd3ff', { sw: 2.8 }),
    path('M27 -6 Q36 12 34 30 Q22 32 20 12Z', '#7fd3ff', { sw: 2.8 }),
    tear(-46, 44, 0.9),
    tear(46, 44, 0.9),
  ]);
  return doc(128, 128, g(b, { transform: 'translate(0 2)' }));
}

// --- Enfadado --------------------------------------------------------------------------------------------------------------
function angry() {
  const flame = (x, y, s) => path(`M${x} ${y} Q${x - 10 * s} ${y - 8 * s} ${x - 4 * s} ${y - 20 * s} Q${x - 2 * s} ${y - 12 * s} ${x + 4 * s} ${y - 16 * s} Q${x + 12 * s} ${y - 6 * s} ${x} ${y}Z`, '#ff5a3c', { sw: 2.6 });
  const b = [
    flame(-30, -42, 1.1), flame(0, -48, 1.4), flame(30, -42, 1.1),
    ...round([
      circle(0, 0, 50, '#ff8a5c', { noStroke: true, opacity: 0.55 }),
      // cejas juntas y ojos
      path('M-38 -22 L-8 -8 L-8 -16 L-36 -32Z', OUT, { sw: 3 }),
      path('M38 -22 L8 -8 L8 -16 L36 -32Z', OUT, { sw: 3 }),
      circle(-19, 0, 6.4, OUT, { noStroke: true }),
      circle(19, 0, 6.4, OUT, { noStroke: true }),
      circle(-17.5, -1.8, 2, '#ffffff', { noStroke: true }),
      circle(20.5, -1.8, 2, '#ffffff', { noStroke: true }),
      // boca torcida con dientes
      path('M-24 34 Q0 16 24 34 L18 38 L8 32 L0 38 L-8 32 L-18 38Z', '#5a1626', { sw: 3.4 }),
    ]),
  ];
  return doc(128, 128, g(b, { transform: 'translate(0 8)' }));
}

// --- ¡Bien jugado! (pulgar arriba) ------------------------------------------------------------------------
function thumbsUp() {
  const b = [];
  b.push(circle(0, 0, 54, '#fff1b8', { noStroke: true, opacity: 0.35 }));
  // muñeca / manga
  b.push(rect(-46, -2, 24, 52, '#4d8fff', { r: 6, sw: 4 }));
  b.push(rect(-46, -2, 9, 52, '#7cb0ff', { r: 4, noStroke: true, opacity: 0.8 }));
  // puño
  b.push(path('M-20 4 L-6 -4 Q8 -28 14 -50 Q22 -58 28 -48 Q32 -32 24 -8 L46 -8 Q58 -6 56 6 Q58 12 52 16 Q56 24 48 28 Q50 36 42 38 Q40 46 30 46 L-20 46Z', '#f1c39b', { sw: 4.4 }));
  b.push(path('M-20 4 L-6 -4 Q8 -28 14 -50 Q22 -58 28 -48 Q32 -32 24 -8', 'none', { stroke: '#ffffff', sw: 3.4, opacity: 0.4 }));
  // dedos
  for (const y of [6, 17, 28, 38]) b.push(path(`M56 ${y - 2} Q34 ${y + 2} 12 ${y}`, 'none', { stroke: '#c98f68', sw: 2.8 }));
  b.push(sparkle(-30, -36, 13, '#fff3b0'));
  b.push(sparkle(50, -40, 9, '#fff3b0', 0.9));
  b.push(sparkle(-52, -14, 6, '#ffffff', 0.9));
  return doc(128, 128, g(b, { transform: 'translate(0 4)' }));
}

// --- Banderas ------------------------------------------------------------------------------------------------------------------
// Rectángulos redondeados 96x64 con brillo suave, listos para un botón.
const flagFrame = (inner, id) => {
  const defs = `<clipPath id="${id}"><rect x="-46" y="-30" width="92" height="60" rx="9"/></clipPath>`;
  return doc(96, 64, [
    `<g clip-path="url(#${id})">${inner}</g>`,
    path('M-46 -30 L46 -30 L46 -8 Q0 4 -46 -8Z', '#ffffff', { noStroke: true, opacity: 0.16, transform: 'translate(0 0)' }),
    rect(-46, -30, 92, 60, 'none', { r: 9, sw: 3.6 }),
  ].join(''), defs);
};

function flagSpain() {
  return flagFrame([
    rect(-50, -34, 100, 68, '#c8202f', { noStroke: true }),
    rect(-50, -15, 100, 30, '#f7c331', { noStroke: true }),
    // escudo sencillo
    rect(-30, -8, 12, 16, '#c8202f', { r: 3, sw: 1.8 }),
    rect(-28, -5, 8, 4, '#f7c331', { noStroke: true }),
    rect(-30, -11, 12, 4, '#a5762a', { r: 1.5, sw: 1.4 }),
  ].join(''), 'clip_es');
}

function flagUS() {
  const stripes = [];
  for (let i = 0; i < 13; i++) stripes.push(rect(-50, -34 + i * (68 / 13), 100, 68 / 13 + 0.4, i % 2 ? '#ffffff' : '#c8202f', { noStroke: true }));
  const stars = [];
  for (let row = 0; row < 4; row++) for (let col = 0; col < 5; col++) stars.push(circle(-44 + col * 7 + (row % 2) * 3.5, -26 + row * 7, 1.5, '#ffffff', { noStroke: true }));
  return flagFrame([
    ...stripes,
    rect(-50, -34, 46, 37, '#2b4fa8', { noStroke: true }),
    ...stars,
  ].join(''), 'clip_us');
}

// Lista de emotes de la partida (mismo orden que systems/emotes/Emotes.gd).
const EMOTES = { emote_goblin_laugh: goblinLaugh, emote_cry: cry, emote_angry: angry, emote_gg: thumbsUp };

function generate() {
  for (const [name, fn] of Object.entries(EMOTES)) L.write(`emotes/${name}.svg`, fn());
  L.write('ui/flag_es.svg', flagSpain());
  L.write('ui/flag_us.svg', flagUS());
}

module.exports = { generate };
