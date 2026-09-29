class_name StructureData
extends Resource
## Definición data-driven de un tipo de estructura.
##
## Nivel = cantidad de edificios del mismo tipo fusionados (Lv3 = 3 granjas).
## Los valores por nivel se guardan en arrays: índice 0 = Lv1.

enum Kind { FARM, SPAWNER, TOWER }

## Identificador estable usado por comandos y red (p.ej. &"farm").
@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.FARM
## Etiquetas para reglas data-driven (p.ej. &"barracks" desbloquea el Tank).
@export var tags: Array[StringName] = []
@export_range(1, 10) var max_level: int = 5

@export_group("Farm")
@export var income_per_level: PackedInt32Array = PackedInt32Array()
@export var income_interval: float = 8.0
## true: income_per_level es el ingreso TOTAL de todas las granjas del
## jugador, repartido entre ellas (Lv3 = 3 granjas = +60 en total).
## false: cada granja da income_per_level de su nivel (3 granjas = +60 cada una).
@export var income_shared_between_buildings: bool = true

@export_group("Spawner")
@export var spawn_unit: UnitData
@export var spawn_count_per_level: PackedInt32Array = PackedInt32Array()
@export var spawn_interval_per_level: PackedFloat32Array = PackedFloat32Array()
## Mejora de las unidades de spawn_unit por cada estructura adicional de
## este tipo (la primera da las estadísticas base).
## Velocidad de ataque de las unidades que produce (o compras con carta) según
## el nivel de ESTA estructura, índices 0..max_level (0 = sin ninguna). Es un
## multiplicador de su ritmo de ataque base: 1.2 = ataca un 20 % más rápido.
## Se fija al aparecer la unidad. Vacío = sin escalado.
@export var unit_attack_speed_per_level: PackedFloat32Array = PackedFloat32Array()
@export var unit_bonus_damage_per_extra_building: float = 0.0
@export var unit_bonus_hp_per_extra_building: float = 0.0

@export_group("Tower")
@export var tower_range_per_level: PackedFloat32Array = PackedFloat32Array()
@export var tower_damage_per_level: PackedFloat32Array = PackedFloat32Array()
@export var tower_cooldown_per_level: PackedFloat32Array = PackedFloat32Array()
@export var tower_projectile_speed: float = 900.0

@export_group("Mind Conversion")
## Nivel mínimo que habilita la conversión en sus unidades. 0 = nunca.
@export var conversion_min_level: int = 0
@export_range(0.0, 1.0, 0.01) var conversion_chance: float = 0.05
@export var conversion_max_target_hp: float = 600.0

@export_group("Visual")
## Sprite animado opcional. Si es null se dibuja un rectángulo de `color`.
@export var sprite_frames: SpriteFrames
## Arte estático del edificio y capa de "color de equipo" (blanca/gris, se
## tiñe con el bando). Tienen prioridad sobre el rectángulo de `color`.
@export var texture: Texture2D
@export var team_texture: Texture2D
## Ajuste fino del tamaño del arte respecto al hueco del slot.
@export var art_scale: float = 1.0
@export var anim_idle: StringName = &"idle"
@export var color: Color = Color.WHITE
## Texto corto para el placeholder visual (p.ej. "FARM").
@export var short_label: String = ""


func is_valid_level(level: int) -> bool:
	return level >= 1 and level <= max_level


func clamp_level(level: int) -> int:
	return clampi(level, 1, max_level)


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


func get_income(level: int) -> int:
	return _int_at_level(income_per_level, level)


func get_spawn_count(level: int) -> int:
	return _int_at_level(spawn_count_per_level, level)


func get_spawn_interval(level: int) -> float:
	return _float_at_level(spawn_interval_per_level, level)


func get_tower_range(level: int) -> float:
	return _float_at_level(tower_range_per_level, level)


func get_tower_damage(level: int) -> float:
	return _float_at_level(tower_damage_per_level, level)


func get_tower_cooldown(level: int) -> float:
	return _float_at_level(tower_cooldown_per_level, level)


## Multiplicador de velocidad de ataque de las unidades a nivel `level` (0 = sin estructura).
func get_unit_attack_speed(level: int) -> float:
	if unit_attack_speed_per_level.is_empty():
		return 1.0
	return unit_attack_speed_per_level[clampi(level, 0, unit_attack_speed_per_level.size() - 1)]


func enables_conversion(level: int) -> bool:
	return conversion_min_level > 0 and level >= conversion_min_level


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var label: String = "StructureData '%s'" % id
	if id == &"":
		errors.append("%s: id vacío" % label)
	match kind:
		Kind.FARM:
			_check_level_array(errors, label, "income_per_level", income_per_level.size())
			if income_interval <= 0.0:
				errors.append("%s: income_interval debe ser > 0" % label)
			for value: int in income_per_level:
				if value <= 0:
					errors.append("%s: income_per_level contiene valores <= 0" % label)
					break
		Kind.SPAWNER:
			if spawn_unit == null:
				errors.append("%s: SPAWNER sin spawn_unit" % label)
			_check_level_array(errors, label, "spawn_count_per_level", spawn_count_per_level.size())
			_check_level_array(errors, label, "spawn_interval_per_level", spawn_interval_per_level.size())
			if not unit_attack_speed_per_level.is_empty() and unit_attack_speed_per_level.size() != max_level + 1:
				errors.append("%s: unit_attack_speed_per_level tiene %d valores, se esperaban %d (niveles 0..%d)" % [label, unit_attack_speed_per_level.size(), max_level + 1, max_level])
			for value: float in unit_attack_speed_per_level:
				if value <= 0.0:
					errors.append("%s: unit_attack_speed_per_level contiene valores <= 0" % label)
					break
			for value: float in spawn_interval_per_level:
				if value <= 0.0:
					errors.append("%s: spawn_interval_per_level contiene valores <= 0" % label)
					break
		Kind.TOWER:
			_check_level_array(errors, label, "tower_range_per_level", tower_range_per_level.size())
			_check_level_array(errors, label, "tower_damage_per_level", tower_damage_per_level.size())
			_check_level_array(errors, label, "tower_cooldown_per_level", tower_cooldown_per_level.size())
			if tower_projectile_speed <= 0.0:
				errors.append("%s: tower_projectile_speed debe ser > 0" % label)
	if conversion_min_level < 0 or conversion_min_level > max_level:
		errors.append("%s: conversion_min_level fuera de [0, max_level]" % label)
	return errors


func _check_level_array(errors: PackedStringArray, label: String, field: String, size: int) -> void:
	if size != max_level:
		errors.append("%s: %s tiene %d valores, se esperaban %d" % [label, field, size, max_level])


func _int_at_level(values: PackedInt32Array, level: int) -> int:
	if values.is_empty():
		return 0
	return values[mini(clamp_level(level), values.size()) - 1]


func _float_at_level(values: PackedFloat32Array, level: int) -> float:
	if values.is_empty():
		return 0.0
	return values[mini(clamp_level(level), values.size()) - 1]
