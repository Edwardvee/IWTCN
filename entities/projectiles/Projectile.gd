class_name Projectile
extends Node2D
## Proyectil teledirigido. El daño se decide al disparar y se aplica al llegar.
## Si el objetivo muere antes de la llegada, el proyectil se pierde.
## Lo simula LaneManager (orden determinista); no tiene _physics_process propio.
## Sirve tanto para unidades (Archer) como para estructuras (Tower, Fase 8):
## source_id es el id lógico de quien dispara.

const RADIUS: float = 8.0
const TRAIL_LENGTH: float = 40.0

var projectile_id: int = 0
var source_id: int = 0
var team: int = MatchTypes.NO_PLAYER
var target_id: int = 0
var damage: float = 0.0
var speed: float = 900.0

var _direction: Vector2 = Vector2.UP


func setup(p_projectile_id: int, p_source_id: int, p_team: int, p_target_id: int, p_damage: float, p_speed: float) -> void:
	projectile_id = p_projectile_id
	source_id = p_source_id
	team = p_team
	target_id = p_target_id
	damage = p_damage
	speed = p_speed
	name = "Projectile_%d" % projectile_id
	set_physics_process(false)


## Avanza hacia `target_position`. Devuelve true si llega en este paso.
func simulate_towards(target_position: Vector2, delta: float) -> bool:
	var to_target: Vector2 = target_position - global_position
	var step: float = speed * delta
	if to_target.length() <= step:
		global_position = target_position
		return true
	_direction = to_target.normalized()
	global_position += _direction * step
	rotation = _direction.angle() + PI * 0.5
	return false


func _draw() -> void:
	var color: Color = MatchTypes.team_color(team).lightened(0.4)
	draw_line(Vector2(0.0, TRAIL_LENGTH), Vector2.ZERO, color, 6.0)
	draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
	draw_circle(Vector2.ZERO, RADIUS * 0.6, color)
