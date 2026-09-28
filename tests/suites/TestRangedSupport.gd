extends TestSuite
## Fase 5b: Archer (proyectiles) y Priest (curación).

const STEP: float = 1.0 / 60.0

var lane: LaneManager = null
var soldier: UnitData = null
var archer: UnitData = null
var priest: UnitData = null
var tank: UnitData = null


func before_each() -> void:
	if lane == null:
		lane = LaneManager.new()
		get_root().add_child(lane)
		soldier = GameManager.database.get_unit(&"soldier")
		archer = GameManager.database.get_unit(&"archer")
		priest = GameManager.database.get_unit(&"priest")
		tank = GameManager.database.get_unit(&"tank")
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 55)


func after_all() -> void:
	lane.clear_units()
	lane.queue_free()


func _run(seconds: float) -> void:
	for _step: int in roundi(seconds / STEP):
		lane.simulate_step(STEP)


## Una unidad detecta en un tick (cambio de estado) y actúa en el siguiente:
## REACT avanza lo justo para ver la primera acción.
func _react() -> void:
	lane.simulate_step(STEP)
	lane.simulate_step(STEP)


func _spawn(data: UnitData, team: int, y: float, x: float = 540.0) -> UnitBase:
	return lane.spawn_unit(data, team, Vector2(x, y))


# --- Archer --------------------------------------------------------------------

func test_archer_shoots_projectile_with_travel_time() -> void:
	var shooter: UnitBase = _spawn(archer, 0, 1600.0)
	var enemy: UnitBase = _spawn(soldier, 1, 1300.0)
	_react()
	assert_eq(shooter.get_state_name(), UnitBase.STATE_ATTACK, "enemigo a 260 px (rango 280) → ATTACK")
	assert_eq(lane.get_projectile_count(), 1, "un proyectil en vuelo")
	assert_eq(enemy.current_hp, 250.0, "el daño no es instantáneo")
	_run(0.4)
	assert_eq(enemy.current_hp, 250.0 - 42.0, "el proyectil impacta al llegar")
	assert_eq(lane.get_projectile_count(), 0, "proyectil retirado tras impactar")


func test_archer_holds_position_while_shooting() -> void:
	var shooter: UnitBase = _spawn(archer, 0, 1600.0)
	_spawn(soldier, 1, 1300.0)
	_run(1.0)
	assert_eq(shooter.global_position.y, 1600.0, "no avanza mientras dispara")


func test_projectile_fizzles_if_target_dies() -> void:
	_spawn(archer, 0, 1600.0)
	var enemy: UnitBase = _spawn(soldier, 1, 1300.0)
	_react()
	assert_eq(lane.get_projectile_count(), 1, "proyectil disparado")
	enemy.receive_damage(9999.0, 0)
	lane.simulate_step(STEP)
	assert_eq(lane.get_projectile_count(), 0, "el proyectil se pierde sin objetivo")


func test_archer_out_of_range_advances() -> void:
	var shooter: UnitBase = _spawn(archer, 0, 1600.0)
	_spawn(soldier, 1, 1200.0)
	lane.simulate_step(STEP)
	assert_eq(shooter.get_state_name(), UnitBase.STATE_ADVANCE, "a 360 px sigue avanzando")
	assert_eq(lane.get_projectile_count(), 0, "sin disparos")


# --- Priest --------------------------------------------------------------------
# Los aliados se colocan al final del carril (y = 900) para que no se muevan.

func test_priest_heals_lowest_percentage_ally() -> void:
	var healer: UnitBase = _spawn(priest, 0, 1000.0)
	var badly_hurt: UnitBase = _spawn(soldier, 0, 900.0, 500.0)
	var lightly_hurt: UnitBase = _spawn(soldier, 0, 900.0, 580.0)
	badly_hurt.receive_damage(125.0, 0)
	lightly_hurt.receive_damage(50.0, 0)
	_react()
	assert_eq(healer.get_state_name(), UnitBase.STATE_HEAL, "HEAL")
	assert_eq(badly_hurt.current_hp, 125.0 + 45.0, "cura al de menor % (50 %)")
	assert_eq(lightly_hurt.current_hp, 200.0, "no toca al de 80 %")


func test_priest_heal_cooldown() -> void:
	_spawn(priest, 0, 1000.0)
	var ally: UnitBase = _spawn(soldier, 0, 900.0)
	ally.receive_damage(150.0, 0)
	_react()
	assert_eq(ally.current_hp, 145.0, "primera cura al detectar al herido")
	_run(2.3)
	assert_eq(ally.current_hp, 145.0, "sin cura antes de 2.5 s")
	_run(0.3)
	assert_eq(ally.current_hp, 190.0, "segunda cura tras el cooldown")


func test_priest_never_overheals() -> void:
	_spawn(priest, 0, 1000.0)
	var ally: UnitBase = _spawn(soldier, 0, 900.0)
	ally.receive_damage(10.0, 0)
	_react()
	assert_eq(ally.current_hp, 250.0, "no supera max_hp")


func test_priest_ignores_full_hp_and_advances() -> void:
	var healer: UnitBase = _spawn(priest, 0, 1200.0)
	var ally: UnitBase = _spawn(soldier, 0, 900.0)
	_run(0.5)
	assert_eq(healer.get_state_name(), UnitBase.STATE_ADVANCE, "nadie herido → ADVANCE")
	assert_true(healer.global_position.y < 1200.0, "avanza")
	assert_eq(ally.current_hp, 250.0, "sin curas a vida completa")


func test_priest_does_not_heal_itself() -> void:
	var healer: UnitBase = _spawn(priest, 0, 1000.0)
	healer.receive_damage(50.0, 0)
	assert_true(healer.find_heal_target() == null, "el Priest no se cura a sí mismo")


func test_priest_holds_near_enemies_and_never_attacks() -> void:
	var healer: UnitBase = _spawn(priest, 0, 1600.0)
	var enemy: UnitBase = _spawn(soldier, 1, 1420.0)
	_run(0.1)
	assert_eq(healer.get_state_name(), UnitBase.STATE_HEAL, "enemigo en rango → se detiene a apoyar")
	assert_eq(healer.global_position.y, 1600.0, "no avanza hacia el enemigo")
	assert_eq(enemy.current_hp, 250.0, "el Priest no hace daño")
	assert_false(healer.state_machine.has_state(UnitBase.STATE_ATTACK), "un HEALER no tiene estado ATTACK")


func test_heal_never_revives() -> void:
	_spawn(priest, 0, 1000.0)
	var ally: UnitBase = _spawn(soldier, 0, 900.0)
	var enemy: UnitBase = _spawn(soldier, 1, 2200.0)
	ally.receive_damage(240.0, 0)
	lane.queue_hit(enemy, ally, 100.0)
	lane.simulate_step(STEP)
	assert_true(ally.is_dead, "muere por el golpe del mismo tick")
	assert_eq(ally.current_hp, 0.0, "la cura del mismo tick no lo revive")


# --- Mixto ---------------------------------------------------------------------

func test_mixed_battle_is_deterministic() -> void:
	var first_run: String = _mixed_battle()
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 55)
	var second_run: String = _mixed_battle()
	assert_eq(first_run, second_run, "misma entrada → mismo estado con proyectiles y curas")


func _mixed_battle() -> String:
	for data: UnitData in [soldier, archer, priest, tank]:
		lane.spawn_group(data, 0, 1)
		lane.spawn_group(data, 1, 1)
	_run(12.0)
	return str(lane.to_dict())
