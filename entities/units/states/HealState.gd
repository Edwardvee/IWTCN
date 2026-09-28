class_name HealState
extends UnitState
## HEAL (solo HEALER): se queda quieto apoyando.
## Cada cooldown cura al aliado herido en rango con menor % de vida
## (nunca a unidades a vida completa) y, con su propio cooldown, intenta la
## conversión mental si su equipo la tiene habilitada. Vuelve a ADVANCE
## cuando no hay heridos ni enemigos en rango.


func enter() -> void:
	super()
	unit.play_animation(unit.data.anim_walk)


func physics_update(delta: float) -> void:
	super(delta)
	var heal_target: UnitBase = unit.find_heal_target()
	var enemy_near: bool = unit.has_enemy_in_range()
	if heal_target == null and not enemy_near:
		unit.change_state(UnitBase.STATE_ADVANCE)
		return
	if heal_target != null and unit.attack_cooldown_left <= 0.0:
		unit.perform_heal(heal_target)
	if enemy_near:
		unit.try_mind_conversion()
