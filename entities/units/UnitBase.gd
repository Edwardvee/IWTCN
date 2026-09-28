class_name UnitBase
extends CharacterBody2D
## Unidad de combate. Estadísticas desde UnitData; comportamiento en estados
## de la FSM (entities/units/states/).
##
## No tiene _physics_process propio: LaneManager llama a simulate() en orden
## de unit_id, así la simulación es determinista y solo corre en la autoridad.
## El combate en el carril es 1D: la distancia se mide solo en el eje Y
## (de borde a borde), la X es solo visual.
## No usa move_and_slide: movimiento cinemático por posición (barato en móvil).

const STATE_ADVANCE: StringName = &"advance"
const STATE_ATTACK: StringName = &"attack"
const STATE_HEAL: StringName = &"heal"
const STATE_DEAD: StringName = &"dead"
const HEAL_FLASH_COLOR: Color = Color(0.45, 1.0, 0.45)
const HEAL_FLASH_DURATION: float = 0.3
## Segundos que el cadáver permanece visible antes de liberarse.
const DEATH_DURATION: float = 0.5
## Bit de collision_layer por equipo (capas 2 y 3, ver project.godot).
const TEAM_LAYER_BITS: Array[int] = [2, 4]
const HP_BAR_HEIGHT: float = 7.0

signal health_changed(current_hp: float, max_hp: float)

var unit_id: int = 0
var team: int = MatchTypes.NO_PLAYER
var data: UnitData = null
var lane: LaneManager = null

# Estadísticas en partida (base de UnitData; los buffs las modificarán).
var max_hp: float = 1.0
var current_hp: float = 1.0
var move_speed: float = 0.0
var damage: float = 0.0
var attack_range: float = 0.0
var attack_cooldown: float = 1.0
var damage_mitigation: float = 0.0
var heal_amount: float = 0.0
var body_radius: float = 20.0

var attack_cooldown_left: float = 0.0
var target_id: int = 0
var is_dead: bool = false
## Y donde la unidad deja de avanzar (final del carril de su equipo).
var lane_end_y: float = 0.0
var state_machine: StateMachine = StateMachine.new()

var _sprite: AnimatedSprite2D = null
var _collision: CollisionShape2D = null


func setup(p_unit_id: int, p_team: int, p_data: UnitData, p_lane: LaneManager, modifiers: UnitStatModifiers = null) -> void:
	unit_id = p_unit_id
	team = p_team
	data = p_data
	lane = p_lane
	name = "Unit_%d" % unit_id
	var bonus_hp: float = modifiers.bonus_max_hp if modifiers != null else 0.0
	var bonus_damage: float = modifiers.bonus_damage if modifiers != null else 0.0
	max_hp = data.max_hp + bonus_hp
	current_hp = max_hp
	move_speed = data.move_speed
	# Una unidad sin daño base (Priest) no gana daño por bonus.
	damage = data.damage + bonus_damage if data.damage > 0.0 else 0.0
	attack_range = data.attack_range
	attack_cooldown = data.attack_cooldown
	damage_mitigation = data.damage_mitigation
	heal_amount = data.heal_amount
	body_radius = data.body_radius
	lane_end_y = lane.get_lane_end_y(team) if lane != null else global_position.y
	set_physics_process(false)
	_create_collision()
	_create_visuals()
	_apply_team()
	state_machine.add_state(STATE_ADVANCE, AdvanceState.new(self))
	# Un HEALER nunca entra en ATTACK: su estado de combate es HEAL.
	if data.is_healer():
		state_machine.add_state(STATE_HEAL, HealState.new(self))
	else:
		state_machine.add_state(STATE_ATTACK, AttackState.new(self))
	state_machine.add_state(STATE_DEAD, DeadState.new(self))
	state_machine.start(STATE_ADVANCE)


## Un paso de simulación. Lo llama LaneManager (nunca el propio nodo).
func simulate(delta: float) -> void:
	if not is_dead:
		attack_cooldown_left = maxf(0.0, attack_cooldown_left - delta)
	state_machine.physics_update(delta)


func change_state(state_name: StringName) -> void:
	if is_dead and state_name != STATE_DEAD:
		return
	state_machine.transition_to(state_name)


func get_state_name() -> StringName:
	return state_machine.current_state_name


# --- Movimiento ----------------------------------------------------------------

func get_forward_direction() -> Vector2:
	return MatchTypes.forward_direction(team)


func advance(delta: float) -> void:
	var next_y: float = global_position.y + get_forward_direction().y * move_speed * delta
	if team == MatchTypes.PLAYER_BOTTOM:
		next_y = maxf(next_y, lane_end_y)
	else:
		next_y = minf(next_y, lane_end_y)
	global_position.y = next_y


func has_reached_lane_end() -> bool:
	return is_equal_approx(global_position.y, lane_end_y)


# --- Targeting y combate ---------------------------------------------------

## Distancia de borde a borde en el eje del carril.
func edge_distance_to(other: UnitBase) -> float:
	return absf(global_position.y - other.global_position.y) - (body_radius + other.body_radius)


func is_in_attack_range(other: UnitBase) -> bool:
	return edge_distance_to(other) <= attack_range


## Objetivo actual resuelto por id (nunca una referencia colgante).
func get_target() -> UnitBase:
	if target_id == 0 or lane == null:
		return null
	var target: UnitBase = lane.get_unit(target_id)
	if target == null or target.is_dead or target.team == team:
		target_id = 0
		return null
	return target


## Enemigo más cercano en rango (desempate: menor unit_id). Actualiza target_id.
func acquire_target() -> UnitBase:
	if lane == null:
		return null
	var target: UnitBase = lane.find_nearest_enemy_in_range(self, attack_range)
	target_id = target.unit_id if target != null else 0
	return target


func perform_attack(target: UnitBase) -> void:
	if data.uses_projectile:
		lane.spawn_projectile(unit_id, team, global_position, target.unit_id, damage, data.projectile_speed)
	else:
		lane.queue_hit(self, target, damage)
	attack_cooldown_left = attack_cooldown
	play_animation(data.anim_attack, true)


## El castillo rival está vivo y en rango. Las unidades enemigas tienen
## prioridad: los estados solo atacan el castillo si no hay unidad en rango.
func can_attack_enemy_castle() -> bool:
	return lane != null and not data.is_healer() and lane.can_unit_attack_castle(self)


func perform_castle_attack() -> void:
	target_id = 0
	if data.uses_projectile:
		lane.spawn_castle_projectile(unit_id, team, global_position, damage, data.projectile_speed)
	else:
		lane.queue_castle_hit(self, MatchTypes.opponent_of(team), damage)
	attack_cooldown_left = attack_cooldown
	play_animation(data.anim_attack, true)


# --- Apoyo (HEALER) ----------------------------------------------------------

## Aliado herido en rango con menor % de vida (nunca uno a vida completa).
func find_heal_target() -> UnitBase:
	if lane == null:
		return null
	return lane.find_lowest_hp_ally_in_range(self, attack_range)


func has_enemy_in_range() -> bool:
	return lane != null and lane.find_nearest_enemy_in_range(self, attack_range) != null


## Un HEALER deja de avanzar si hay a quien curar o enemigos en su rango.
func should_hold_to_support() -> bool:
	return find_heal_target() != null or has_enemy_in_range()


func perform_heal(target: UnitBase) -> void:
	lane.queue_heal(self, target, heal_amount)
	attack_cooldown_left = attack_cooldown
	play_animation(data.anim_attack, true)


## Restaura vida sin superar max_hp. Devuelve la vida realmente curada.
func receive_heal(amount: float, _source_id: int) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var applied: float = minf(amount, max_hp - current_hp)
	if applied <= 0.0:
		return 0.0
	current_hp += applied
	health_changed.emit(current_hp, max_hp)
	queue_redraw()
	_play_heal_feedback()
	return applied


func is_injured() -> bool:
	return not is_dead and current_hp < max_hp


func calculate_damage_taken(incoming: float) -> float:
	return incoming * (1.0 - clampf(damage_mitigation, 0.0, 0.9))


## Aplica daño (ya mitigado aquí). Devuelve el daño realmente recibido.
func receive_damage(incoming: float, _source_id: int) -> float:
	if is_dead or incoming <= 0.0:
		return 0.0
	var applied: float = minf(calculate_damage_taken(incoming), current_hp)
	current_hp -= applied
	health_changed.emit(current_hp, max_hp)
	queue_redraw()
	if current_hp <= 0.0:
		die()
	return applied


func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_hp = 0.0
	target_id = 0
	_collision.set_deferred("disabled", true)
	state_machine.transition_to(STATE_DEAD)
	queue_redraw()


func is_ready_to_free() -> bool:
	return is_dead and state_machine.get_elapsed_in_state() >= DEATH_DURATION


func get_hp_ratio() -> float:
	return current_hp / max_hp if max_hp > 0.0 else 0.0


func to_dict() -> Dictionary:
	return {
		"unit_id": unit_id,
		"team": team,
		"unit_type": data.id,
		"position": global_position,
		"hp": current_hp,
		"max_hp": max_hp,
		"state": get_state_name(),
		"target_id": target_id,
		"attack_cooldown_left": attack_cooldown_left,
	}


# --- Visual ----------------------------------------------------------------

func play_animation(animation_name: StringName, restart: bool = false) -> void:
	if _sprite == null or not _sprite.sprite_frames.has_animation(animation_name):
		return
	if restart or _sprite.animation != animation_name:
		_sprite.play(animation_name)
		if restart:
			_sprite.frame = 0


func _play_heal_feedback() -> void:
	modulate = HEAL_FLASH_COLOR
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, HEAL_FLASH_DURATION)


func _create_collision() -> void:
	_collision = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = body_radius
	_collision.shape = shape
	add_child(_collision)


func _create_visuals() -> void:
	if data.sprite_frames == null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = data.sprite_frames
	_sprite.scale = data.sprite_scale
	add_child(_sprite)


func _apply_team() -> void:
	collision_layer = TEAM_LAYER_BITS[team] if MatchTypes.is_valid_player_id(team) else 0
	collision_mask = 0
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	if _sprite == null:
		_draw_shape(data.fallback_shape, body_radius, MatchTypes.team_color(team))
		_draw_shape(data.fallback_shape, body_radius * 0.45, data.fallback_color)
	var bar_width: float = body_radius * 2.0 + 10.0
	var bar_rect: Rect2 = Rect2(-bar_width * 0.5, -body_radius - 16.0, bar_width, HP_BAR_HEIGHT)
	draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 0.75))
	var ratio: float = get_hp_ratio()
	draw_rect(Rect2(bar_rect.position, Vector2(bar_width * ratio, HP_BAR_HEIGHT)), Color.RED.lerp(Color.LIME_GREEN, ratio))


func _draw_shape(shape: UnitData.Shape, radius: float, color: Color) -> void:
	var forward: Vector2 = get_forward_direction()
	var side: Vector2 = Vector2(-forward.y, forward.x)
	match shape:
		UnitData.Shape.SQUARE:
			draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), color)
		UnitData.Shape.CIRCLE:
			draw_circle(Vector2.ZERO, radius, color)
		UnitData.Shape.TRIANGLE:
			draw_colored_polygon(PackedVector2Array([
				forward * radius,
				-forward * radius + side * radius,
				-forward * radius - side * radius,
			]), color)
		UnitData.Shape.DIAMOND:
			draw_colored_polygon(PackedVector2Array([
				forward * radius, side * radius, -forward * radius, -side * radius,
			]), color)
