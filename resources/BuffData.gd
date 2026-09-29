class_name BuffData
extends Resource
## Modificador global de estadísticas para un jugador.
##
## Para añadir un buff nuevo basta con crear un .tres; solo hace falta tocar
## código si se añade un Stat nuevo al enum.
## PERCENT usa fracciones: 0.15 = +15 %. FLAT suma el valor tal cual.

## TOWER_FIRE_RATE: PERCENT, +0.10 = las torres disparan un 10 % más rápido
## (se suma por cada copia comprada). No afecta a las unidades.
enum Stat { MOVE_SPEED, MAX_HP, DAMAGE_MITIGATION, DAMAGE, PRODUCTION_INTERVAL, TOWER_FIRE_RATE }
enum Operation { PERCENT, FLAT }

@export var id: StringName = &""
@export var display_name: String = ""
@export var stat: Stat = Stat.MOVE_SPEED
@export var operation: Operation = Operation.PERCENT
@export var value: float = 0.0
## Unidades afectadas por id. Vacío = todas. Ignorado en PRODUCTION_INTERVAL y TOWER_FIRE_RATE.
@export var target_unit_ids: Array[StringName] = []


func affects_unit(unit_id: StringName) -> bool:
	return target_unit_ids.is_empty() or target_unit_ids.has(unit_id)


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var label: String = "BuffData '%s'" % id
	if id == &"":
		errors.append("%s: id vacío" % label)
	if is_zero_approx(value):
		errors.append("%s: value es 0, el buff no tendría efecto" % label)
	return errors
