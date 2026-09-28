class_name AdvanceState
extends UnitState
## ADVANCE: avanza por el carril.
## - Combate (MELEE/RANGED): pasa a ATTACK al detectar un enemigo en rango.
## - Apoyo (HEALER): pasa a HEAL si hay un aliado herido o un enemigo en rango.


func enter() -> void:
	super()
	unit.play_animation(unit.data.anim_walk)


func physics_update(delta: float) -> void:
	super(delta)
	if unit.data.is_healer():
		if unit.should_hold_to_support():
			unit.change_state(UnitBase.STATE_HEAL)
			return
	elif unit.acquire_target() != null:
		unit.change_state(UnitBase.STATE_ATTACK)
		return
	unit.advance(delta)
