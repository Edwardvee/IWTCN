class_name TestBalance
extends RefCounted
## Valores de equilibrio que asumen las suites. Se fijan en memoria al empezar
## el runner (no tocan los .tres) para que retocar el balance real en data/
## no rompa los tests. Los datos reales se validan en TestDataModel y
## TestScaling (que llama a restore_real()) y con tools/BalanceSim.

static var _real_values: Array = []


## Valores fijados: [recurso, propiedad, valor]. Se construye con los recursos vivos.
static func _pins() -> Array:
	var rules: GameRules = GameManager.get_rules()
	var database: GameDatabase = GameManager.database
	var pins: Array = [
		[rules, &"starting_gold", 20],
		[rules, &"castle_max_hp", 3000.0],
		[rules, &"base_income_amount", 5],
		[rules, &"unit_cap_override", 120],
		[rules, &"copy_cost_multipliers", PackedFloat32Array([1.0, 1.25, 1.625, 2.1125, 2.74625])],
		[database.get_structure(&"farm"), &"income_per_level", PackedInt32Array([25, 40, 60, 80, 100])],
		[database.get_structure(&"church"), &"spawn_interval_per_level", PackedFloat32Array([12.0, 11.0, 10.0, 9.5, 9.0])],
		[database.get_structure(&"soldier_barracks"), &"spawn_count_per_level", PackedInt32Array([2, 2, 3, 3, 4])],
		[database.get_structure(&"archer_barracks"), &"spawn_count_per_level", PackedInt32Array([1, 1, 2, 2, 3])],
		[database.get_structure(&"tower"), &"tower_damage_per_level", PackedFloat32Array([30.0, 38.0, 46.0, 55.0, 65.0])],
		[database.get_unit(&"archer"), &"attack_cooldown", 0.9],
		[database.get_card(&"card_soldiers"), &"unit_count", 3],
		[database.get_card(&"card_soldiers"), &"unit_count_by_level", PackedInt32Array()],
		[database.get_card(&"card_archers"), &"unit_count", 2],
		[database.get_card(&"card_archers"), &"unit_count_by_level", PackedInt32Array()],
	]
	for barracks_id: StringName in [&"soldier_barracks", &"archer_barracks"]:
		pins.append([database.get_structure(barracks_id), &"spawn_interval_per_level", PackedFloat32Array([8.0, 7.5, 7.0, 6.5, 6.0])])
	for scaled_id: StringName in [&"soldier_barracks", &"archer_barracks", &"church"]:
		pins.append([database.get_structure(scaled_id), &"unit_attack_speed_per_level", PackedFloat32Array()])
	for unit_speed: Array in [[&"soldier", 120.0], [&"archer", 100.0], [&"priest", 95.0], [&"tank", 70.0]]:
		pins.append([database.get_unit(unit_speed[0]), &"move_speed", unit_speed[1]])
	for card_cost: Array in [[&"card_soldiers", 30], [&"card_archers", 35], [&"card_tank", 70]]:
		pins.append([database.get_card(card_cost[0]), &"cost", card_cost[1]])
	return pins


## Fija los valores que asumen los tests (recordando los reales la primera vez).
static func apply() -> void:
	if GameManager.get_rules() == null or GameManager.database == null:
		return
	var pins: Array = _pins()
	if _real_values.is_empty():
		for pin: Array in pins:
			_real_values.append([pin[0], pin[1], (pin[0] as Resource).get(pin[1])])
	for pin: Array in pins:
		(pin[0] as Resource).set(pin[1], pin[2])


## Devuelve los valores reales de data/ (para probar el balance actual).
static func restore_real() -> void:
	for saved: Array in _real_values:
		(saved[0] as Resource).set(saved[1], saved[2])
