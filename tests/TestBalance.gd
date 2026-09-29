class_name TestBalance
extends RefCounted
## Valores de equilibrio que asumen las suites. Se fijan en memoria al empezar
## el runner (no tocan los .tres) para que retocar el balance real en data/
## no rompa los tests. Los datos reales se validan en TestDataModel y con
## tools/BalanceSim.


static func apply() -> void:
	var rules: GameRules = GameManager.get_rules()
	var database: GameDatabase = GameManager.database
	if rules == null or database == null:
		return
	rules.starting_gold = 20
	rules.castle_max_hp = 3000.0
	database.get_structure(&"farm").income_per_level = PackedInt32Array([25, 40, 60, 80, 100])
	for barracks_id: StringName in [&"soldier_barracks", &"archer_barracks"]:
		database.get_structure(barracks_id).spawn_interval_per_level = PackedFloat32Array([8.0, 7.5, 7.0, 6.5, 6.0])
	database.get_structure(&"church").spawn_interval_per_level = PackedFloat32Array([12.0, 11.0, 10.0, 9.5, 9.0])
	for unit_speed: Array in [[&"soldier", 120.0], [&"archer", 100.0], [&"priest", 95.0], [&"tank", 70.0]]:
		database.get_unit(unit_speed[0]).move_speed = unit_speed[1]
	for card_cost: Array in [[&"card_soldiers", 30], [&"card_archers", 35], [&"card_tank", 70]]:
		database.get_card(card_cost[0]).cost = card_cost[1]
	rules.max_units_per_team = 120
