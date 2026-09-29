# Dónde editar cada cosa (balance y configuración)

Casi todo el balance es **data-driven**: se edita en el Inspector de Godot abriendo el `.tres` (doble clic en el FileSystem) o directamente en el archivo de texto. No hace falta tocar código salvo donde se indica.

## 1. Reglas globales — `data/game_rules.tres` (script `resources/GameRules.gd`)

| Qué | Campo | Valor actual |
| :--- | :--- | :--- |
| Oro inicial | `starting_gold` | 50 |
| Oro por ingreso base | `base_income_amount` | 5 |
| Segundos entre ingresos base | `base_income_interval` | 3.0 (=1.67 oro/s) |
| Vida del castillo | `castle_max_hp` | 10000 |
| Oferta inicial con Farm garantizada | `guarantee_starting_farm` | true |
| Tropas vivas máximas por bando | `max_units_per_team` | 80 |
| Cartas en la tienda | `shop_offer_size` | 3 |
| Coste base del reroll | `reroll_base_cost` | 10 |
| Subida del reroll por uso | `reroll_cost_increment` | 3 |
| Bajada del reroll por intervalo | `reroll_decay_amount` / `reroll_decay_interval` | 1 cada 10 s |
| Reembolso al vender | `sell_refund_ratio` | 0.5 |
| Coste de cada plot (índices 0..5) | `plot_costs` | 40, 30, 20, 50, 0, 10 |
| Plots gratis al empezar | `initial_unlocked_plots` | [4] |
| Nivel máximo de estructuras | `max_structure_level` | 5 |
| Intervalo mínimo de producción con buffs | `min_production_interval` | 1.0 s |
| **Sobreprecio 2ª copia de un edificio** | `second_copy_cost_multiplier` | 1.25 |
| **Sobreprecio 3ª copia y siguientes** | `extra_copy_cost_multiplier` | 1.30 |

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
