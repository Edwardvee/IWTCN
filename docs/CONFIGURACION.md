# Dónde editar cada cosa (balance y configuración)

Casi todo el balance es **data-driven**: se edita en el Inspector de Godot abriendo el `.tres` (doble clic en el FileSystem) o directamente en el archivo de texto. No hace falta tocar código salvo donde se indica.

## 1. Reglas globales — `data/game_rules.tres` (script `resources/GameRules.gd`)

| Qué | Campo | Valor actual |
| :--- | :--- | :--- |
| Oro inicial | `starting_gold` | 80 |
| Oro por ingreso base | `base_income_amount` | 3 |
| Segundos entre ingresos base | `base_income_interval` | 3.0 (=1 oro/s) |
| Vida del castillo | `castle_max_hp` | 10000 |
| Oferta inicial con Farm garantizada | `guarantee_starting_farm` | true |
| Tropas vivas máximas por bando | `unit_cap_by_farm_level` | 3 / 8 / 12 / 24 / 36 / 60 según granjas (0 a 5) |
| Cartas en la tienda | `shop_offer_size` | 3 |
| Coste base del reroll | `reroll_base_cost` | 10 |
| Subida del reroll por uso | `reroll_cost_increment` | 3 |
| Bajada del reroll por intervalo | `reroll_decay_amount` / `reroll_decay_interval` | 1 cada 10 s |
| Reembolso al vender | `sell_refund_ratio` | 0.5 |
| Coste de cada plot (índices 0..5) | `plot_costs` | 40, 30, 20, 50, 0, 10 |
| Plots gratis al empezar | `initial_unlocked_plots` | [4] |
| Nivel máximo de estructuras | `max_structure_level` | 5 |
| Intervalo mínimo de producción con buffs | `min_production_interval` | 1.0 s |
| **Precio de cada nivel (copia) de un edificio** | `copy_cost_multipliers` | ×1 / ×1,25 / ×2,5 / ×4 / ×6 del precio base |

> Nota: los valores por defecto viven en `GameRules.gd`; el `.tres` solo guarda los que difieren. Si editas en el Inspector, Godot los escribe en el `.tres`.

### Precio escalado de edificios
Cada copia de un mismo edificio que **tienes construida** encarece la siguiente (se calcula en `GameRules.get_scaled_structure_cost`, lo usa `EconomyManager.get_card_cost`). Ejemplo con la Granja (50):

| Copia | Precio |
| :--- | :--- |
| 1ª | 50 |
| 2ª | 63 (50 × 1.25) |
| 3ª | 81 (63 × 1.30) |
| 4ª | 106 (× 1.30) … |

- Cuenta copias *actualmente construidas*: vender una granja abarata la siguiente.
- El precio que se muestra en la carta y el que se cobra son el mismo; el reembolso al vender usa lo que realmente pagaste.
- Solo afecta a estructuras (no a tropas directas ni mejoras).

## 2. Cartas y su coste — `data/cards/*.tres` (`resources/CardData.gd`)

`cost` (precio base), `shop_weight` (probabilidad en la tienda), `unit_count` (tropas por carta de unidades), `required_structure_tag` / `required_structure_count` (requisito, p. ej. Tank = 3 cuarteles).

Costes base actuales: Farm 50, Soldier Barracks 60, Archer Barracks 70, Church 80, Tower 60, 3 Soldiers 45, 2 Archers 50, Tank 100, Buffs 80–100 (Cadencia de torres 90).

Qué tipos de carta salen: `enabled_card_types` en `systems/draft/DraftManager.gd`.

## 3. Unidades — `data/units/*.tres` (`resources/UnitData.gd`)

| Stat | Campo |
| :--- | :--- |
| Vida | `max_hp` |
| Velocidad | `move_speed` |
| **Alcance** | `attack_range` (melee ≈ 45, archer 280, priest 220) |
| **Daño** | `damage` |
| Tiempo entre ataques | `attack_cooldown` |
| Reducción de daño | `damage_mitigation` (0–0.9) |
| Curación (priest) | `heal_amount` |
| Proyectil | `uses_projectile`, `projectile_speed` |
| Tamaño | `body_radius` |
| Sprites/animaciones | `sprite_frames`, `anim_*`, `sprite_scale` |

Actuales: Soldier 250 HP/35 dmg · Archer 110 HP/42 dmg/rango 280 · Tank 850 HP/25 dmg/20% mitigación · Priest 140 HP/cura 45.

## 4. Estructuras — `data/structures/*.tres` (`resources/StructureData.gd`)

Los arrays por nivel tienen 5 valores (índice 0 = Lv1). Nivel = nº de copias del edificio.

- **Granja** (`farm.tres`): `income_per_level` (12, 20, 30, 40, 50), `income_interval` (8 s), `income_shared_between_buildings`.
- **Cuarteles / Iglesia**: intervalos actuales: cuarteles 10 → 8 s, iglesia 12 → 10 s (Lv1 → Lv5). `spawn_unit`, `spawn_count_per_level`, `spawn_interval_per_level`, `unit_bonus_damage_per_extra_building` y `unit_bonus_hp_per_extra_building` (mejora de las unidades por cada edificio extra).
- **Torre** (`tower.tres`): **`tower_range_per_level`** (alcance), **`tower_damage_per_level`** (daño), `tower_cooldown_per_level`, `tower_projectile_speed`.
- **Conversión mental** (Iglesia): `conversion_min_level`, `conversion_chance`, `conversion_max_target_hp`.

## 5. Mejoras globales — `data/buffs/*.tres` (`resources/BuffData.gd`)

`stat`, `operation` (porcentaje/suma), `value`, `target_unit_ids`. Su precio está en la carta correspondiente.

`buff_tower_fire_rate` (stat `TOWER_FIRE_RATE`, `value` 0.1): cada copia comprada suma +10 % de cadencia a todas tus torres (el tiempo entre disparos se divide entre 1 + suma). Su carta solo sale en la tienda si ya tienes una torre.

## 6. IA — `systems/ai/RuleBasedStrategy.gd` y `AIController.gd`

Constantes al inicio: `PLAY_THRESHOLD`, `REROLL_RESERVE`, `SCORE_JITTER`, `SURPLUS_GOLD`; `think_interval` (export) = velocidad de reacción. Los pesos de puntuación son campos de la estrategia y `RuleBasedStrategy.create(perfil)` devuelve variantes con estilos distintos: `balanced`, `economy`, `rush`, `turtle`, `barracks`, `spam`. En el modo espectador cada semilla enfrenta dos perfiles.

Mejoras (cartas violetas): cada copia ya comprada de una mejora sube un 10 % el precio de la siguiente de ESA mejora, acumulado (`GameRules.buff_copy_cost_increase`; 100 → 110 → 121…).

## 6b. Simulador de equilibrio y ritmo — `tools/BalanceSim.tscn`

IA contra IA sin gráficos (unas 2-3 partidas por segundo). Enfrenta todos los perfiles en ambos lados del mapa y resume duración de las partidas, tasa de victoria por perfil y por lado, y economía.

```bash
godot --headless --path . res://tools/BalanceSim.tscn -- --matches=6 --quiet
```

Opciones: `--matches=N` (partidas por pareja y lado), `--profiles=a,b`, `--max-time=900`, `--seed=1000`, `--csv=ruta`, `--verbose` (traza de un atasco). Para probar un cambio sin editar los `.tres`:
`--set=rules.castle_max_hp=12000 --set=unit.soldier.damage=30 --set=structure.farm.income_per_level=12/20/30/40/50 --set=card.card_tank.cost=90`.
Rutas: `rules.<campo>`, `unit.<id>.<campo>`, `structure.<id>.<campo>`, `card.<id>.<campo>`; las listas se separan con `/`.

Objetivo de ritmo con los datos actuales: mediana de 4-5 min, p10 ≥ 3 min, p90 ≤ 6 min, ninguna partida sin terminar, perfiles entre 40 % y 60 % y lado de abajo/arriba entre 45 % y 55 %. Las IA son sencillas: sirven para detectar extremos, no para el ajuste fino.

Los tests (`tests/TestBalance.gd`) fijan sus propios valores en memoria, así que retocar los `.tres` no los rompe.

## 6c. Espectador y repeticiones

- **Espectador local** (menú → *Modo espectador*): IA contra IA en el dispositivo, con pausa y velocidad x1/x2/x4/x8. Atajo de desarrollo: ejecutar `res://scenes/Main.tscn` con `-- --spectate`.
- **Repeticiones** (menú → *Repeticiones*): cada partida contra la IA, de espectador o como anfitrión online se graba sola (`user://replays/*.iwr`, zstd, se conservan las 15 últimas). Se reproducen con pausa, velocidad, barra de progreso y reinicio. Guardan snapshots del estado (no comandos), así que siguen funcionando aunque cambie el balance. Código: `systems/replay/`.
- **Espectador online** (menú → escribir el código de sala → *Ver sala como espectador*): mira en directo una partida online desde la vista del anfitrión. Hasta 8 espectadores por sala; no pueden enviar comandos. Requiere el relay actualizado (ver más abajo).
- **Selector de raza** (`ui/RaceSelect.gd`, tras pulsar Jugar contra la IA o al unirse una sala online): 5 s para elegir entre las razas con una rueda estilo GTA (la elegida al centro, las otras abajo; tocar una la trae al centro) o pulsar Elegir para fijarla antes. Al acabar el tiempo queda fijada la que esté al centro. Contra la IA arranca la partida; online el anfitrión espera la raza del invitado (máx. 4 s tras fijar la suya) y arranca. La última raza usada se recuerda. Protocolo online v4 (mensajes `select` y `race`).
- **Menú de partida** (botón ≡ arriba a la izquierda, `ui/PauseMenu.gd`): Continuar, Opciones (volumen general, guardado en `settings.cfg`) y Rendirse (`SurrenderCommand`, con confirmación). Solo contra la IA pausa el juego; en online la partida sigue en marcha. No aparece en la cuenta atrás, de espectador ni en repeticiones. Con Escape también se abre y se cierra.
- **Feedback visual**: números flotantes de daño/curación (`ui/FloatingTextLayer.gd`), avisos verdes de acciones completadas y rojos de errores, resaltado de slots válidos al arrastrar una estructura, "faltan N" en cartas inasequibles y aviso de oro (`-50`).

## 7. Mapa, carril y cámara (código/escena)

- Carril: exports de `systems/combat/LaneManager.gd` (`lane_top_y`, `lane_bottom_y`, `lane_half_width`, …) y separación de spawn (constantes arriba).
- Grid: `grid_size`, `plot_gap`… en `systems/grid/GridManager.gd`. Plots y slots por plot son constantes en `GameRules.gd` (`PLOT_COUNT`, `SLOTS_PER_PLOT`); cambiarlos exige ajustar `plot_costs` y el layout.
- Cámara: `systems/camera/CameraDragController.gd`.

## 8. Añadir contenido nuevo

Crear el `.tres` (unidad → estructura → carta) y registrarlo en `data/game_database.tres`. Los tests (`TestDataModel`) validan que los datos sean coherentes.

## Ejecutar tests

```bash
"D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path D:\GodotGames\iwtcn res://tests/TestRunner.tscn
```

---

# Partida online (relay en Cloudflare)

Modo 1 vs 1 por **código de sala**, sin IPs, sin abrir puertos y sin VPN. Funciona en Web (itch.io), PC y Android.

- El anfitrión pulsa *Crear sala online* y ve un código de 4 letras; el amigo lo escribe y pulsa *Unirse*.
- Ambos se conectan por `wss://` a un Cloudflare Worker (`server/relay/`) que solo reenvía mensajes. El anfitrión sigue siendo el que simula la partida; el invitado envía comandos y recibe snapshots (10/s).
- Si el invitado se cae, puede volver a entrar con el mismo código y recupera su asiento. Si se va el anfitrión, la sala termina.
- **Espectadores**: con el mismo código se puede entrar como espectador (`role=spectator`, hasta 8). Reciben los mismos snapshots que el invitado, en directo, y pueden entrar a mitad de partida. El relay descarta cualquier mensaje que envíen.
- Código del cliente: `autoload/NetworkManager.gd`. Relay: `server/relay/src/index.js`.

## Puesta en marcha (una sola vez)

1. Crea una cuenta gratuita en https://dash.cloudflare.com (sin tarjeta).
2. Despliega el relay:
   ```bash
   cd server/relay
   npm install
   npx wrangler login
   npx wrangler deploy
   ```
   Te imprime la URL, p. ej. `https://iwtcn-relay.tuusuario.workers.dev`.
3. En `autoload/NetworkManager.gd` cambia `DEFAULT_RELAY_URL` a esa URL con `wss://` (`wss://iwtcn-relay.tuusuario.workers.dev`). Sin barra final.
4. Exporta el juego (Web, Windows, Android) y súbelo a itch.io. Para Web: export con *Thread Support* desactivado, comprimido en ZIP con `index.html`, y marca "This file will be played in the browser".

**Importante:** el espectador online necesita el relay nuevo. Tras actualizar el código hay que volver a desplegar (`cd server/relay && npx wrangler deploy`). Con el relay antiguo, jugar y unirse siguen funcionando, pero *Ver sala como espectador* será rechazado.

## Probar en local

```bash
cd server/relay && npx wrangler dev          # relay en ws://localhost:8787
```
Lanza el juego con `-- --relay=ws://localhost:8787` (argumento de usuario tras `--`) en dos instancias. Para el test automático: `tests/network/NetServerTest.gd`, `NetClientTest.gd` y `NetSpectatorTest.gd` (instrucciones en su cabecera).

## Límites del plan gratuito
Verifica las cifras vigentes en la documentación de Cloudflare (Workers y Durable Objects, plan Free). Cada partida usa ~20 mensajes/s; para unos pocos amigos queda muy por debajo de los límites diarios. El relay no tiene login: quien conozca el código puede entrar a una sala libre, y el código dura lo que dure la sala.

---

# Idiomas (español / inglés)

- **Cambiar de idioma:** botón en la parte superior del menú (muestra el idioma al que cambia). Se guarda en `user://settings.cfg`. Por defecto: español si el sistema está en español, inglés en cualquier otro caso. Atajo de desarrollo: `-- --lang=en`.
- **Dónde están los textos:** `systems/i18n/TranslationTables.gd`. La clave es el texto tal como está en el código o en los `.tres` (español para la interfaz, inglés para nombres de contenido como *Farm*). `EN` traduce al inglés y `ES` da la versión en español de los nombres en inglés.
- **Añadir un texto nuevo:** envolverlo en `tr("…")` (o `Reason.make("…")` si es un motivo de rechazo de comando) y añadir su versión en inglés en `EN`. Si es un nombre o descripción de contenido en un `.tres`, añadirlo a `EN` (y a `ES` si lleva nombres en inglés). Los textos de `Label`/`Button` se traducen solos, pero los que llevan formato (`%d`, `%s`) necesitan `tr()` explícito.
- **Motivos de rechazo:** `validate()` devuelve `Reason.make(clave, argumentos)` y se traduce donde se muestra (`Reason.text()`), así un invitado online lo ve en su propio idioma aunque el anfitrión juegue en otro.
- **Seguridad:** `tests/suites/TestLocalization.gd` escanea el código y falla si falta alguna traducción, si no coinciden los `%d/%s`, o si un nombre o descripción del contenido no está traducido.
- `ui/DebugPanel.gd` (solo desarrollo) queda en español. El fallback del proyecto es `es`; por eso las claves en inglés de contenido también tienen entrada en `EN`.

---

# Rendimiento

- **Medir:** `godot --headless --path . res://tools/PerfBench.tscn -- --units=80 --seconds=20` enfrenta dos ejércitos (con torres y curanderos) y muestra ms por tick de `LaneManager.simulate_step` (media, p50, p99, máx), tiempo por fase, tamaño de los snapshots y memoria de una repetición. Referencia en PC (80 tropas por bando, unas 150 unidades vivas): **≈1,0 ms por tick** (antes 2,6 ms); con 150 por bando ≈3,2 ms (antes 12 ms). En móvil cuenta con 3-5 veces más.
- **Búsqueda de objetivos:** índice espacial por equipo ordenado por Y (`LaneManager._refresh_index`), que solo se usa dentro de `simulate_step`; fuera de ahí (tests, IA) se recorren todas las unidades. `lane.use_spatial_index = false` lo desactiva; `TestPerformance` comprueba que una batalla larga acaba idéntica con y sin índice. El reparto de blancos usa un hash de los `unit_id`, así que no depende del orden de recorrido.
- **Contadores y pool:** `get_alive_count` usa una caché que se invalida al aparecer, morir o convertirse una unidad. Los proyectiles se reutilizan (`_acquire_projectile` / `_release_projectile`, pool de 96).
- **Red y repeticiones:** el carril viaja en arrays planos (`LaneManager.to_snapshot`, ~8 veces menos que `to_dict`), y `StateReplicator.build_delta_snapshot(cache)` omite cuadrícula, tienda y mejoras si no cambiaron. Con 150 unidades: ~5 KB por snapshot (antes ~48 KB) y una repetición de 1 minuto ocupa ~5 MB en memoria (antes ~120 MB). Al entrar un invitado o espectador se vacía la caché y el siguiente snapshot va completo. `NetworkManager.PROTOCOL_VERSION` avisa si anfitrión e invitado/espectador tienen versiones incompatibles.
- **Interfaz:** los golpes al castillo se agrupan (una actualización de texto por fotograma), los números flotantes miden su texto una sola vez y escalan con el transform en vez de cambiar de tamaño de fuente, y `physics/common/max_physics_steps_per_frame` está en 4 para que un móvil lento no entre en espiral de pasos de física.
- **Si añades sistemas nuevos:** no recorras `_units` en cada tick; usa `_select_candidates` para búsquedas por posición y mide con PerfBench antes y después.

---

# Dificultad de la IA

Botón *Dificultad* en el menú (Fácil → Normal → Difícil); se recuerda en `user://settings.cfg` y solo afecta a *Jugar contra la IA*. Código: `systems/ai/AIDifficulty.gd`.

| Nivel | Reacción | Comportamiento | Ingresos de la IA |
| :--- | :--- | :--- | :--- |
| Fácil | cada 3,0 s | 50 % de turnos sin hacer nada, 35 % de compras al azar, mucho ruido en la puntuación, no hace reroll, estilo pasivo | ×0,85 |
| Normal | cada 1,0 s | La IA equilibrada de siempre | ×1,0 |
| Difícil | cada 0,5 s | Presión temprana (cuarteles y tropas, una sola granja), casi sin errores | ×1,15 |

- Las ventajas y desventajas de ingresos están declaradas (`AIDifficulty.EASY_INCOME` / `HARD_INCOME`) y solo cambian el oro que llega por ingreso base y granjas (`EconomyManager.add_income`); ventas y reembolsos no se multiplican. Las decisiones siguen pasando por los mismos comandos que las de un jugador.
- Medido con `tools/BalanceSim` (`--profiles=easy,normal,hard --matches=12`): Normal gana ≈88 % al Fácil, y el Difícil gana ≈71 % al Normal y el 100 % al Fácil. Para reajustar, cambia los multiplicadores y los campos del perfil `PROFILE_EASY` / `PROFILE_HARD` en `RuleBasedStrategy.create`.
- El modo espectador y el simulador siguen enfrentando estilos (`economy`, `rush`, `turtle`…), no niveles; con `--profiles=easy,normal,hard` el simulador también acepta los niveles.


# Arte y efectos

Todo el arte es procedural y se regenera con Node (sin dependencias):

```
node tools/art/generate.js            # todo
node tools/art/generate.js unidades   # unidades | estructuras | mundo | ui | audio | emotes
godot --headless --path . --import    # reimportar los SVG/WAV nuevos
godot --headless --path . --script res://tools/BuildTheme.gd   # regenera ui/theme.tres
```

| Qué | Dónde se edita | Dónde se usa |
|---|---|---|
| Unidades (caminar, atacar, reposo) | `tools/art/units.js` → `assets/units/*` y `data/units/*_frames.tres` | `UnitData.sprite_frames`; el contorno del bando lo dibuja `assets/shaders/team_outline.gdshader` (material compartido en `entities/base/TeamArt.gd`) |
| Estructuras y castillo | `tools/art/structures.js` → `assets/structures/<id>.svg` + `<id>_team.svg` (capa de estandartes teñida con el color del bando) | `StructureData.texture` / `team_texture`, `Castle.gd` |
| Hierba, camino, árboles, suelo de plots, fondos del menú (uno por dificultad: fácil con flores, normal, difícil con cielo rojo) | `tools/art/world.js` | `scenes/WorldBackground.gd` (densidad y opacidad de la decoración), `Plot.gd`, `ui/MainMenu.gd` (`BACKGROUNDS`) |
| Emotes (4 caritas) y banderas del selector de idioma | `tools/art/emotes.js` → `assets/emotes/*`, `assets/ui/flag_*.svg` | `systems/emotes/Emotes.gd`, `ui/EmotePanel.gd`, `ui/MainMenu.gd` |
| Iconos, cartas de mejoras y de unidades, icono de la app, madera de la tienda por raza (humanos `assets/bgShopPanel.png`, goblins oscura, elfos blanca) | `tools/art/ui.js` | `CardData.icon`, `CardView.gd`, `ShopPanel.gd` (fondo = `RaceData.shop_panel_texture`) |
| Tema de la UI (botones, paneles, campos) | `tools/BuildTheme.gd` → `ui/theme.tres` | tema global (`project.godot`); variaciones `PrimaryButton`, `WoodButton`, `DangerButton`, `StoneButton`, `TopBar` |
| Efectos de botón (hundir/rebote, destello, sonido) | `autoload/UIFeedback.gd` | se engancha solo a todo `BaseButton`; `sound_enabled` lo silencia |
| Sonidos: interfaz (clic, confirmar, error) y de partida (flechas, impactos, muertes, castillo, rebote, hechizos, emotes, desbloqueo, victoria/derrota) | `tools/art/audio.js` | `UIFeedback.gd` (interfaz) y `autoload/Sfx.gd` (partida; intervalo mínimo por sonido y volumen más bajo para el rival) |

Colores de las cartas por tipo (borde): estructuras amarillo, unidades azul, mejoras violeta (`CardView.TYPE_COLORS`).

Para revisar el arte sin jugar: `godot --path . res://tools/ArtGallery.tscn -- --page=units --unit=soldier` (páginas `units`, `structures`, `cards`, `ui`) y `res://tools/GameShot.tscn` (partida con cámara fija; `--vs`, `--top`, `--cam-y=N`).


**Emotes** (`Emotes.gd`): 4 emotes (goblin riéndose, llorar, enfado, pulgar arriba). `EmoteCommand` los envía; la autoridad exige `Emotes.COOLDOWN` = 3 s entre emotes del mismo jugador (con `COOLDOWN_TOLERANCE` para la latencia online) y viajan a los clientes en el snapshot (`emote` / `emote_seq` del jugador). `EmotePanel` dibuja el botón, el selector y los globos.

---

# Unidades especiales y habilidades de castillo

**Unidades especiales** (una por raza, carta de unidad con `required_race` y `required_structure_id` + `required_structure_count` = 3 cuarteles del MISMO tipo):

| Raza | Unidad | Carta | Requisito | Rasgos |
|---|---|---|---|---|
| Humanos | Caballería (`cavalry`) | 100 | 3 × Soldier Barracks | vida 620, rápida, 5 % del daño en área (radio 90) |
| Elfos | Mago (`mage`) | 100 | 3 × Archer Barracks | vida 55, daño 110, proyectil, 15 % en área (radio 120) |
| Goblins | Arquero venenoso (`venom_archer`) | 70 (la más barata) | 3 × Archer Barracks | golpe 10 + veneno 20 dps durante 4 s (ignora armadura, no se acumula) |

Todo está en `data/units/*.tres` (campos del grupo *Special* de `UnitData`: `splash_fraction`, `splash_radius`, `poison_dps`, `poison_duration`, `lifetime`, `art_unit_id`) y `data/cards/card_cavalry|mage|venom_archer.tres`. Los multiplicadores de la raza se aplican encima (el veneno no escala con el daño). Su arte sale de `tools/art/units.js` (paleta de su raza).

**Habilidades de castillo** (`data/spells/*.tres`, `SpellData`; botones a la derecha, se arrastran a TU mitad del carril; la espera de 30 s es COMPARTIDA: lanzar una deja a las otras dos en enfriamiento):
- **Lluvia de flechas** (`arrow_rain`): 6 oleadas de 18 de daño cada 0,4 s a los enemigos de un círculo de radio 170.
- **Rayo** (`lightning`): mata a la unidad enemiga más cercana al punto (tolerancia 130); sin enemigos cerca no se lanza ni gasta espera.
- **Llamar a las milicias** (`summon_militia`): 6 soldados débiles (`militia`: vida 45, daño 9) que desaparecen a los 20 s; no cuentan para el tope de tropas.
La IA también las usa (`AIController._try_cast_spell`; en Fácil solo la mitad de las veces). El simulador acepta `--set=spell.<id>.<campo>=…`.

---

# Escalado por nivel de estructura

- **Tope de tropas:** depende del nivel de las granjas (nº de granjas): 0 → 3, 1 → 8, 2 → 12, 3 → 24, 4 → 36, 5 → 60 (`GameRules.unit_cap_by_farm_level`). Con el tope alcanzado los cuarteles no producen y las cartas de unidades se rechazan. `unit_cap_override > 0` lo sustituye por un tope fijo (bancos de prueba).
- **Precio de cada nivel:** `copy_cost_multipliers` [1, 1,25, 2,5, 4, 6] × precio base de la carta. Ej. Farm (50): 50 / 63 / 125 / 200 / 300; Soldier Barracks (60): 60 / 75 / 150 / 240 / 360.
- **Velocidad de ataque de las unidades** (`StructureData.unit_attack_speed_per_level`, niveles 0 a 5 de SU cuartel; 0 = sin cuartel, también para unidades compradas con carta): 0,9 / 1,0 / 1,2 / 1,8 / 1,8 / 2,0 ataques por segundo respecto a su ritmo base (arquero base = 1,0 s). Se fija al aparecer la unidad. Aplica a Soldier Barracks, Archer Barracks e Iglesia; el Tank (sin cuartel propio) no escala.
- **Unidades por carta** (`CardData.unit_count_by_level`, nivel de su cuartel): Soldiers 3 / 3 / 3 / 4 / 4 / 5; Archers 2 / 2 / 2 / 3 / 3 / 4; Tank siempre 1.
- Los tests fijan sus propios valores (`tests/TestBalance.gd`); `TestScaling` prueba estos datos reales.
