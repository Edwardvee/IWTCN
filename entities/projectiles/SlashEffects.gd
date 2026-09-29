class_name SlashEffects
extends Node2D
## Efecto de "tajo" con sonido cuando un golpe cuerpo a cuerpo impacta
## (unidad o castillo). Escucha EventBus.golpe_cuerpo_a_cuerpo. Solo presentación.

const SLASH_SOUND: AudioStream = preload("res://assets/audio/slash.wav")
const MAX_ACTIVE: int = 40
const MIN_SOUND_GAP_MS: int = 60

var _active: int = 0
var _player: AudioStreamPlayer = null
var _last_sound_ms: int = 0


func _ready() -> void:
	z_index = 5
	_player = AudioStreamPlayer.new()
	_player.stream = SLASH_SOUND
	_player.volume_db = -9.0
	add_child(_player)
	EventBus.golpe_cuerpo_a_cuerpo.connect(_on_hit)


func _on_hit(hit_position: Vector2, attacker_team: int) -> void:
	if GameManager.suppress_effects or _active >= MAX_ACTIVE:
		return
	var slash: Slash = Slash.new()
	slash.position = hit_position
	slash.color = MatchTypes.team_color(attacker_team).lightened(0.55)
	# El tajo cruza en diagonal, con un ángulo distinto cada vez.
	slash.rotation = randf_range(-0.9, 0.9) + (PI if attacker_team == MatchTypes.PLAYER_TOP else 0.0)
	slash.finished.connect(func() -> void: _active -= 1)
	_active += 1
	add_child(slash)
	var now: int = Time.get_ticks_msec()
	if now - _last_sound_ms >= MIN_SOUND_GAP_MS:
		_last_sound_ms = now
		_player.pitch_scale = randf_range(0.9, 1.15)
		_player.play()


class Slash:
	extends Node2D

	signal finished

	const DURATION: float = 0.24
	const RADIUS: float = 34.0

	var color: Color = Color.WHITE
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		if _time >= DURATION:
			finished.emit()
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress: float = _time / DURATION
		var sweep: float = 1.0 - pow(1.0 - progress, 3.0)
		var fade: float = 1.0 - progress
		# Media luna que se abre con el giro y se afina al desvanecerse.
		var start: float = -1.1
		var end: float = start + 2.2 * sweep
		var thickness: float = 12.0 * fade + 2.0
		draw_arc(Vector2.ZERO, RADIUS, start, end, 20, Color(0.09, 0.07, 0.12, 0.7 * fade), thickness + 5.0, true)
		draw_arc(Vector2.ZERO, RADIUS, start, end, 20, Color(1.0, 1.0, 1.0, fade), thickness, true)
		draw_arc(Vector2.ZERO, RADIUS - 4.0, start + 0.2, end, 20, Color(color, 0.8 * fade), thickness * 0.5, true)
		for index: int in 3:
			var angle: float = end - 0.35 * index
			var spark: Vector2 = Vector2.from_angle(angle) * (RADIUS + 8.0 + 10.0 * progress)
			draw_circle(spark, 3.0 * fade + 0.5, Color(1.0, 0.95, 0.7, fade))
