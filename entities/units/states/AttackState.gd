class_name AttackState
extends UnitState
## ATTACK: golpea al objetivo cuando el cooldown lo permite. Si el objetivo
## muere o sale de rango, busca otro; si no hay, vuelve a ADVANCE.


func physics_update(delta: float) -> void:
	super(delta)
	var target: UnitBase = unit.get_target()
	if target == null or not unit.is_in_attack_range(target):
		target = unit.acquire_target()
	if target == null:
		unit.change_state(UnitBase.STATE_ADVANCE)
		return
	if unit.attack_cooldown_left <= 0.0:
		unit.perform_attack(target)
