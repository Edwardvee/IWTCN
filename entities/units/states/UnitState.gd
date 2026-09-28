class_name UnitState
extends State
## Base de los estados de unidad: guarda la unidad a la que pertenece.
## La unidad es un Node (no RefCounted), así que no hay ciclo de referencias.

var unit: UnitBase = null


func _init(p_unit: UnitBase) -> void:
	unit = p_unit
