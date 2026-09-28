class_name AttackState
extends UnitState
## ATTACK: golpea cuando el cooldown lo permite.
## Prioridad: 1) unidad enemiga más cercana en rango, 2) castillo rival en
## rango. Si el objetivo muere o sale de rango busca otro; si no hay nada
## que atacar, vuelve a ADVANCE.


func physics_update(delta: float) -> void:
	super(delta)
	var target: UnitBase = unit.get_target()
	if target == null or not unit.is_in_attack_range(target):
		target = unit.acquire_target()
	if target != null:
		if unit.attack_cooldown_left <= 0.0:
			unit.perform_attack(target)
		return
	if unit.can_attack_enemy_castle():
		if unit.attack_cooldown_left <= 0.0:
			unit.perform_castle_attack()
		return
	unit.change_state(UnitBase.STATE_ADVANCE)
