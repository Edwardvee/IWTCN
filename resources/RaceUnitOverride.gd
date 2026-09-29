class_name RaceUnitOverride
extends Resource
## Ajustes de UNA unidad para una raza (se suman a los generales de RaceData:
## los multiplicadores se multiplican entre sí). Todo opcional.

@export var unit_id: StringName = &""
@export var hp_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var attack_speed_multiplier: float = 1.0
@export var move_speed_multiplier: float = 1.0
@export var attack_range_multiplier: float = 1.0
## Arte propio de la raza para esta unidad (vacío = el de la unidad base).
@export var sprite_frames: SpriteFrames
## Escala del sprite (0,0 = la de la unidad base).
@export var sprite_scale: Vector2 = Vector2.ZERO


func get_validation_errors(label: String) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if unit_id == &"":
		errors.append("%s: unit_override sin unit_id" % label)
	for field: String in ["hp_multiplier", "damage_multiplier", "attack_speed_multiplier", "move_speed_multiplier", "attack_range_multiplier"]:
		if float(get(field)) <= 0.0:
			errors.append("%s: unit_override '%s' %s debe ser > 0" % [label, unit_id, field])
	return errors
