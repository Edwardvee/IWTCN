class_name ModBuildings
extends RefCounted
## Edificio modificador: antes de cada partida (tras elegir raza) cada jugador elige uno
## de 3 edificios al azar y su efecto dura toda la partida. Aquí viven el catálogo
## (nombre, descripción, arte) y los valores de cada efecto; las reglas que los aplican
## (economía, tienda, combate, castillo) consultan estas constantes.
##
## El estado (qué edificio tiene cada jugador) es PlayerState.mod_building.

const GOLD_MINE: StringName = &"gold_mine"
const NECROMANCER: StringName = &"necromancer"
const SAWMILL: StringName = &"sawmill"
const FORGE: StringName = &"forge"
const RAIDER_CAMP: StringName = &"raider_camp"
const SWINDLER: StringName = &"swindler"
const STONEMASONS: StringName = &"stonemasons"

const IDS: Array[StringName] = [GOLD_MINE, NECROMANCER, SAWMILL, FORGE, RAIDER_CAMP, SWINDLER, STONEMASONS]
## Cuántos edificios se ofrecen para elegir.
const CHOICE_COUNT: int = 3

# --- Valores de los efectos (todos editables aquí) ---
## Mina de oro: oro extra en cada ingreso base.
const GOLD_MINE_BASE_INCOME_BONUS: int = 1
## Nigromante: segundos entre resurrecciones y máximo de caídos que recuerda.
const NECROMANCER_INTERVAL: float = 12.0
const NECROMANCER_GRAVEYARD_LIMIT: int = 30
## Aserradero: rebaja del coste de construcción de estructuras.
const SAWMILL_DISCOUNT: float = 0.05
## Herrería: daño extra de tus tropas.
const FORGE_DAMAGE_BONUS: float = 0.03
## Campamento de saqueadores: oro que pierde cada granja rival en cada ciclo.
const RAIDER_FARM_PENALTY: int = 2
## Estafador: recargo del reroll para AMBOS jugadores (por cada estafador en la partida).
const SWINDLER_REROLL_SURCHARGE: int = 2
## Canteros: vida extra del castillo.
const STONEMASONS_CASTLE_HP: float = 1000.0

## Color de la resurrección del nigromante (celeste verdoso).
const REVIVED_TINT: Color = Color(0.55, 1.0, 0.85)

const _DATA: Dictionary = {
	GOLD_MINE: {
		"name": "Mina de oro",
		"description": "Tu ingreso base sube en %d de oro cada vez.",
		"icon": "res://assets/mods/gold_mine.svg",
	},
	NECROMANCER: {
		"name": "Nigromante",
		"description": "Cada %d s revive a una de tus tropas caídas, al azar.",
		"icon": "res://assets/mods/necromancer.svg",
	},
	SAWMILL: {
		"name": "Aserradero",
		"description": "Construir estructuras cuesta un %d %% menos.",
		"icon": "res://assets/mods/sawmill.svg",
	},
	FORGE: {
		"name": "Herrería",
		"description": "Tus tropas hacen un %d %% más de daño.",
		"icon": "res://assets/mods/forge.svg",
	},
	RAIDER_CAMP: {
		"name": "Campamento de saqueadores",
		"description": "Cada granja rival da %d de oro menos por ciclo (no afecta a su ingreso base).",
		"icon": "res://assets/mods/raider_camp.svg",
	},
	SWINDLER: {
		"name": "Estafador",
		"description": "Tú y tu rival pagáis %d de oro más por cada reroll.",
		"icon": "res://assets/mods/swindler.svg",
	},
	STONEMASONS: {
		"name": "Canteros",
		"description": "Tu castillo tiene %d de vida extra.",
		"icon": "res://assets/mods/stonemasons.svg",
	},
}


static func is_valid(id: StringName) -> bool:
	return _DATA.has(id)


static func display_name(id: StringName) -> String:
	return TranslationServer.translate(str(_DATA[id]["name"])) if _DATA.has(id) else ""


## Descripción con el valor del efecto ya puesto.
static func description(id: StringName) -> String:
	if not _DATA.has(id):
		return ""
	return TranslationServer.translate(str(_DATA[id]["description"])) % _effect_value(id)


static func icon(id: StringName) -> Texture2D:
	if not _DATA.has(id):
		return null
	return load(str(_DATA[id]["icon"])) as Texture2D


static func _effect_value(id: StringName) -> int:
	match id:
		GOLD_MINE:
			return GOLD_MINE_BASE_INCOME_BONUS
		NECROMANCER:
			return roundi(NECROMANCER_INTERVAL)
		SAWMILL:
			return roundi(SAWMILL_DISCOUNT * 100.0)
		FORGE:
			return roundi(FORGE_DAMAGE_BONUS * 100.0)
		RAIDER_CAMP:
			return RAIDER_FARM_PENALTY
		SWINDLER:
			return SWINDLER_REROLL_SURCHARGE
		STONEMASONS:
			return roundi(STONEMASONS_CASTLE_HP)
	return 0


## `count` edificios distintos al azar con el generador dado.
static func roll_choices(rng: RandomNumberGenerator, count: int = CHOICE_COUNT) -> Array[StringName]:
	var pool: Array[StringName] = IDS.duplicate()
	var choices: Array[StringName] = []
	while choices.size() < count and not pool.is_empty():
		choices.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return choices


## Edificio "por defecto" de un asiento a partir de la semilla (IA, espectador, F6).
@warning_ignore("integer_division")
static func pick_from_seed(match_seed: int, salt: int) -> StringName:
	return IDS[absi(match_seed / maxi(1, salt)) % IDS.size()]


## ¿Tiene este jugador ese edificio en la partida en curso?
static func has(player_id: int, id: StringName) -> bool:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	return player_state != null and player_state.mod_building == id


## Cuántos jugadores tienen ese edificio (el Estafador afecta a todos).
static func count_in_match(id: StringName) -> int:
	if GameManager.match_state == null:
		return 0
	var total: int = 0
	for player_state: PlayerState in GameManager.match_state.players:
		if player_state.mod_building == id:
			total += 1
	return total
