# Dónde editar cada cosa (balance y configuración)

Casi todo el balance es **data-driven**: se edita en el Inspector de Godot abriendo el `.tres` (doble clic en el FileSystem) o directamente en el archivo de texto. No hace falta tocar código salvo donde se indica.

## 1. Reglas globales — `data/game_rules.tres` (script `resources/GameRules.gd`)

| Qué | Campo | Valor actual |
| :--- | :--- | :--- |
| Oro inicial | `starting_gold` | 20 |
| Oro por ingreso base | `base_income_amount` | 5 |
| Segundos entre ingresos base | `base_income_interval` | 3.0 (=1.67 oro/s) |
| Vida del castillo | `castle_max_hp` | 3000 |
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

Costes base actuales: Farm 50, Soldier Barracks 60, Archer Barracks 70, Church 80, Tower 60, 3 Soldiers 30, 2 Archers 35, Tank 70, Buffs 80–100.

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

- **Granja** (`farm.tres`): `income_per_level` (25, 40, 60, 80, 100), `income_interval` (8 s), `income_shared_between_buildings`.
- **Cuarteles / Iglesia**: `spawn_unit`, `spawn_count_per_level`, `spawn_interval_per_level`, `unit_bonus_damage_per_extra_building` y `unit_bonus_hp_per_extra_building` (mejora de las unidades por cada edificio extra).
- **Torre** (`tower.tres`): **`tower_range_per_level`** (alcance), **`tower_damage_per_level`** (daño), `tower_cooldown_per_level`, `tower_projectile_speed`.
- **Conversión mental** (Iglesia): `conversion_min_level`, `conversion_chance`, `conversion_max_target_hp`.

## 5. Mejoras globales — `data/buffs/*.tres` (`resources/BuffData.gd`)

`stat`, `operation` (porcentaje/suma), `value`, `target_unit_ids`. Su precio está en la carta correspondiente.

## 6. IA — `systems/ai/RuleBasedStrategy.gd` y `AIController.gd`

Constantes al inicio: `PLAY_THRESHOLD`, `REROLL_RESERVE`, `SCORE_JITTER`, `SURPLUS_GOLD`; `think_interval` (export) = velocidad de reacción. Las puntuaciones por carta están en `score_card` / `_score_structure`. Es lo único de balance que está en código.

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

## Probar en local

```bash
cd server/relay && npx wrangler dev          # relay en ws://localhost:8787
```
Lanza el juego con `-- --relay=ws://localhost:8787` (argumento de usuario tras `--`) en dos instancias. Para el test automático: `tests/network/NetServerTest.gd` y `NetClientTest.gd` (instrucciones en su cabecera).

## Límites del plan gratuito
Verifica las cifras vigentes en la documentación de Cloudflare (Workers y Durable Objects, plan Free). Cada partida usa ~20 mensajes/s; para unos pocos amigos queda muy por debajo de los límites diarios. El relay no tiene login: quien conozca el código puede entrar a una sala libre, y el código dura lo que dure la sala.
