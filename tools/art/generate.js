// Regenera todo el arte procedural: node tools/art/generate.js [unidades|estructuras|mundo|ui|audio|emotes]
// Salida en assets/ (SVG/WAV) y en data/ (SpriteFrames .tres). Es determinista.

const L = require('./lib');

const modules = {
  unidades: () => require('./units').generate(),
  estructuras: () => require('./structures').generate(),
  mundo: () => require('./world').generate(),
  ui: () => require('./ui').generate(),
  audio: () => require('./audio').generate(),
  emotes: () => require('./emotes').generate(),
  // Unidades y estructuras de las razas (goblin, elf). Ver tools/art/races.js.
  razas: () => {
    for (const race of Object.keys(require('./races').RACES)) {
      require('./units').generate(race);
      require('./structures').generate(race);
    }
  },
};

const wanted = process.argv.slice(2);
const names = wanted.length ? wanted : Object.keys(modules);
for (const name of names) {
  if (!modules[name]) {
    console.error(`Módulo desconocido: ${name} (opciones: ${Object.keys(modules).join(', ')})`);
    process.exit(1);
  }
  try {
    modules[name]();
  } catch (e) {
    if (e.code === 'MODULE_NOT_FOUND' && wanted.length === 0) continue; // módulos aún no escritos
    throw e;
  }
}
console.log(`${L.written.length} archivos escritos en assets/`);
