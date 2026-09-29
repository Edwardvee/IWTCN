// Estilos visuales de las razas jugables. Cada raza reutiliza las siluetas de las
// unidades y estructuras humanas con su propia paleta (C), sustituciones de
// colores fijos (hexMap) y, en las unidades, orejas. Salida en assets/units/<raza>/,
// assets/structures/<raza>/ y data/races/<raza>/*_frames.tres. Para cambiar el
// aspecto de una raza edita este archivo y ejecuta: node tools/art/generate.js razas

const L = require('./lib');

const RACES = {
  goblin: {
    // Piel verde, metal oxidado, capucha de cuero y chamanes morados.
    palette: {
      skin: '#8fd15a', skinDark: '#5d9a34',
      steel: '#a39a86', steelLight: '#cfc6ad', steelDark: '#6d6555', steelDeep: '#4a443a',
      gold: '#d6a03f', goldLight: '#f0cd7c', goldDark: '#8f6a22',
      leather: '#6d4a2b', leatherDark: '#472e19',
      green: '#9a5a2c', greenLight: '#c98a4e', greenDark: '#623518', greenDeep: '#41230f',
      cream: '#a56ac9', creamDark: '#763f9a',
      wood: '#6e4a2c', woodLight: '#93683f', woodDark: '#453019', woodDeep: '#2c1d0f',
      stone: '#8c8676', stoneLight: '#aaa38f', stoneDark: '#635e51', stoneDeep: '#443f36',
      terracotta: '#5f7f34', terracottaLight: '#86a84a', terracottaDark: '#3b5320',
      thatch: '#a8934a', thatchLight: '#cdb96e', thatchDark: '#75662d',
      slate: '#5d5648', slateLight: '#7a7261', slateDark: '#3c372d',
    },
    hexMap: { '#9c5a48': '#55702c', '#7f4536': '#3b5320', '#6f3a2c': '#2b3c17', '#7d5a3a': '#4e5a2a', '#a67a4d': '#7a7a3f', '#d9483b': '#7a2f8f', '#8fd3ff': '#d9ff7a', '#5fb0e8': '#a3d84a' },
    ears: { len: 15, rise: -3, color: '#8fd15a' },
    unitScale: 0.42,
  },
  elf: {
    // Piel clara, armaduras plateadas, capas verde bosque y detalles dorados.
    palette: {
      skin: '#f8e6d2', skinDark: '#d9b99a',
      steel: '#e2ebf5', steelLight: '#ffffff', steelDark: '#a8bbd1', steelDeep: '#7388a3',
      gold: '#ffd24d', goldLight: '#fff0a6', goldDark: '#c99a1f',
      leather: '#3f7d55', leatherDark: '#265238',
      green: '#2f9e75', greenLight: '#6de3b3', greenDark: '#1c6a4f', greenDeep: '#124434',
      cream: '#eaf9ef', creamDark: '#b7dcc6',
      wood: '#c9a56d', woodLight: '#e3c78f', woodDark: '#8d6d3e', woodDeep: '#5f4726',
      stone: '#e6e1d3', stoneLight: '#f6f2e8', stoneDark: '#b9b3a2', stoneDeep: '#8d8778',
      terracotta: '#2e9c78', terracottaLight: '#57cf9f', terracottaDark: '#17664d',
      thatch: '#e8cf7a', thatchLight: '#fbeaa8', thatchDark: '#b99a3d',
      slate: '#7f93ad', slateLight: '#a5b8d0', slateDark: '#566a85',
    },
    hexMap: { '#9c5a48': '#2a9270', '#7f4536': '#17664d', '#6f3a2c': '#0f4a37', '#7d5a3a': '#b88f52', '#a67a4d': '#dcc088', '#d9483b': '#2fbf8a', '#8fd3ff': '#c8f5ff', '#5fb0e8': '#66d3c4' },
    ears: { len: 22, rise: 9, color: '#f8e6d2' },
    unitScale: 0.52,
  },
};

/** Ejecuta fn con la paleta de la raza aplicada a L.C (y la restaura después). */
function withRace(raceId, fn) {
  const race = raceId ? RACES[raceId] : null;
  if (!race) return fn(null);
  const saved = { ...L.C };
  Object.assign(L.C, race.palette);
  try {
    return fn(race);
  } finally {
    Object.assign(L.C, saved);
  }
}

/** Cambia los colores fijos (que no están en la paleta) de un SVG según la raza. */
function recolor(svg, race) {
  if (!race) return svg;
  let out = svg;
  for (const [from, to] of Object.entries(race.hexMap)) out = out.split(from).join(to);
  return out;
}

module.exports = { RACES, withRace, recolor };
