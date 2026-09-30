class_name Projectile
extends Node2D
## Proyectil. El daño se decide al disparar y se aplica al llegar.
## Lo simula LaneManager (orden determinista); no tiene _physics_process propio.
## Sirve para unidades (Archer) y estructuras (Tower, Fase 8): source_id es
## el id lógico de quien dispara.
##
## Dos modos de objetivo:
## - unidad (target_id): teledirigido; se pierde si el objetivo muere antes.
## - castillo (target_castle_owner): vuela a un punto fijo del frente del castillo.

const RADIUS: float = 8.0
const TRAIL_LENGTH: float = 44.0
const OUTLINE_COLOR: Color = Color(0.09, 0.07, 0.12)
const SHAFT_COLOR: Color = Color(0.72, 0.5, 0.3)

var projectile_id: int = 0
var source_id: int = 0
var team: int = MatchTypes.NO_PLAYER
var target_id: int = 0
var target_castle_owner: int = MatchTypes.NO_PLAYER
var target_point: Vector2 = Vector2.ZERO
var damage: float = 0.0
var speed: float = 900.0
## Efectos del disparo (ver UnitData): daño en área y veneno.
var splash_fraction: float = 0.0
var splash_radius: float = 0.0
var poison_dps: float = 0.0
var poison_duration: float = 0.0
## Estética: color de la estela (alfa 0 = el del bando).
var tint: Color = Color(0.0, 0.0, 0.0, 0.0)

var _direction: Vector2 = Vector2.UP


## También reinicia un proyectil reutilizado del pool de LaneManager.
func setup(p_projectile_id: int, p_source_id: int, p_team: int, p_target_id: int, p_damage: float, p_speed: float) -> void:
	projectile_id = p_projectile_id
	source_id = p_source_id
	if team != p_team:
		team = p_team
		queue_redraw()
	target_id = p_target_id
	target_castle_owner = MatchTypes.NO_PLAYER
	target_point = Vector2.ZERO
	damage = p_damage
	speed = p_speed
	splash_fraction = 0.0
	splash_radius = 0.0
	poison_dps = 0.0
	poison_duration = 0.0
	if tint.a > 0.0:
		tint = Color(0.0, 0.0, 0.0, 0.0)
		queue_redraw()
	set_physics_process(false)


## Copia de la unidad que dispara sus efectos especiales (área, veneno).
func set_effects(unit_data: UnitData) -> void:
	splash_fraction = unit_data.splash_fraction
	splash_radius = unit_data.splash_radius
	poison_dps = unit_data.poison_dps
	poison_duration = unit_data.poison_duration
	var new_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
	if unit_data.has_poison():
		new_tint = Color(0.5, 0.95, 0.25)
	elif unit_data.has_splash():
		new_tint = Color(0.75, 0.5, 1.0)
	if new_tint != tint:
		tint = new_tint
		queue_redraw()


func setup_castle_target(castle_owner: int, point: Vector2) -> void:
	target_id = 0
	target_castle_owner = castle_owner
	target_point = point


func targets_castle() -> bool:
	return target_castle_owner != MatchTypes.NO_PLAYER


## Avanza hacia `destination`. Devuelve true si llega en este paso.
func simulate_towards(destination: Vector2, delta: float) -> bool:
	var to_target: Vector2 = destination - global_position
	var step: float = speed * delta
	if to_target.length() <= step:
		global_position = destination
		return true
	_direction = to_target.normalized()
	global_position += _direction * step
	rotation = _direction.angle() + PI * 0.5
	return false


func _draw() -> void:
	# Flecha que apunta hacia -Y (la rotación la orienta al objetivo): estela del
	# color del bando, asta de madera, plumas y punta de acero.
	var color: Color = tint if tint.a > 0.0 else MatchTypes.team_color(team).lightened(0.4)
	draw_line(Vector2(0.0, TRAIL_LENGTH), Vector2(0.0, 14.0), Color(color, 0.5), 5.0)
	draw_line(Vector2(0.0, 22.0), Vector2(0.0, -10.0), OUTLINE_COLOR, 6.0)
	draw_line(Vector2(0.0, 22.0), Vector2(0.0, -10.0), SHAFT_COLOR, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, -21.0), Vector2(-7.0, -8.0), Vector2(7.0, -8.0)]), OUTLINE_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, -17.0), Vector2(-4.0, -9.0), Vector2(4.0, -9.0)]), Color(0.9, 0.95, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, 22.0), Vector2(-6.0, 30.0), Vector2(0.0, 26.0), Vector2(6.0, 30.0)]), color)
