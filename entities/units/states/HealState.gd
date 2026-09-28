class_name HealState
extends UnitState
## HEAL (solo HEALER): se queda quieto apoyando.
## Cada cooldown cura al aliado herido en rango con menor % de vida
## (nunca a unidades a vida completa). Vuelve a ADVANCE cuando no hay
## heridos ni enemigos en rango.


func enter() -> void:
	super()
	unit.play_animation(unit.data.anim_walk)


func physics_update(delta: float) -> void:
	super(delta)
	var heal_target: UnitBase = unit.find_heal_target()
	if heal_target == null and not unit.has_enemy_in_range():
		unit.change_state(UnitBase.STATE_ADVANCE)
		return
	if heal_target != null and unit.attack_cooldown_left <= 0.0:
		unit.perform_heal(heal_target)
