extends Node
## Respuesta táctil de todos los botones del juego: al pulsar se hunden y
## rebotan, sueltan un destello con chispas y suena un "toc". Se engancha
## solo a cada BaseButton que entra al árbol, así cubre menú, HUD y paneles
## sin tocar cada escena. Solo presentación.

const PRESS_SCALE: Vector2 = Vector2(0.94, 0.94)
const HOVER_SCALE: Vector2 = Vector2(1.03, 1.03)
const CLICK_SOUND: AudioStream = preload("res://assets/audio/click.wav")
const CONFIRM_SOUND: AudioStream = preload("res://assets/audio/confirm.wav")
const ERROR_SOUND: AudioStream = preload("res://assets/audio/error.wav")
const META_TWEEN: StringName = &"_fx_tween"
const META_WIRED: StringName = &"_fx_wired"

## Desactiva el sonido de los botones (p.ej. una futura opción de ajustes).
var sound_enabled: bool = true

var _player: AudioStreamPlayer = null
var _cue_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = CLICK_SOUND
	_player.volume_db = -8.0
	add_child(_player)
	_cue_player = AudioStreamPlayer.new()
	_cue_player.volume_db = -6.0
	add_child(_cue_player)
	get_tree().node_added.connect(_on_node_added)
	EventBus.estructura_construida.connect(func(pid: int, _s: int, _d: StructureData, _l: int) -> void: _play_cue(pid, CONFIRM_SOUND))
	EventBus.plot_desbloqueado.connect(func(pid: int, _p: int) -> void: _play_cue(pid, CONFIRM_SOUND))
	EventBus.carta_elegida.connect(func(pid: int, _c: CardData) -> void: _play_cue(pid, CONFIRM_SOUND))
	EventBus.comando_rechazado.connect(func(pid: int, _t: StringName, _m: String) -> void: _play_cue(pid, ERROR_SOUND))


## Avisos sonoros de las acciones del jugador local (no de la IA ni del espectador).
func _play_cue(player_id: int, stream: AudioStream) -> void:
	if not sound_enabled or player_id != GameManager.local_player_id or GameManager.is_watching():
		return
	_cue_player.stream = stream
	_cue_player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(META_WIRED):
		_wire(node as BaseButton)


func _wire(button: BaseButton) -> void:
	button.set_meta(META_WIRED, true)
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))
	button.mouse_entered.connect(_on_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_mouse_exited.bind(button))


func _scale_to(button: BaseButton, target: Vector2, duration: float, overshoot: bool) -> void:
	if not button.is_inside_tree():
		return
	button.pivot_offset = button.size * 0.5
	var previous: Tween = button.get_meta(META_TWEEN, null) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	var tween: Tween = button.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if overshoot:
		tween.tween_property(button, "scale", target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(button, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.set_meta(META_TWEEN, tween)


func _on_button_down(button: BaseButton) -> void:
	if button.disabled:
		return
	_scale_to(button, PRESS_SCALE, 0.06, false)


func _on_button_up(button: BaseButton) -> void:
	var rest: Vector2 = HOVER_SCALE if button.is_hovered() and not button.disabled else Vector2.ONE
	_scale_to(button, rest, 0.22, true)


func _on_mouse_entered(button: BaseButton) -> void:
	if button.disabled or button.button_pressed and not button.toggle_mode:
		return
	_scale_to(button, HOVER_SCALE, 0.1, false)


func _on_mouse_exited(button: BaseButton) -> void:
	_scale_to(button, Vector2.ONE, 0.12, false)


func _on_button_pressed(button: BaseButton) -> void:
	if sound_enabled and _player != null:
		_player.pitch_scale = randf_range(0.94, 1.06)
		_player.play()
	var burst: ClickBurst = ClickBurst.new()
	button.add_child(burst)
	var origin: Vector2 = button.get_local_mouse_position() if button.is_hovered() else button.size * 0.5
	burst.start(Rect2(Vector2.ZERO, button.size).grow(-6.0).abs(), origin)


## Anillo de luz y chispas que salen del punto pulsado y se desvanecen.
class ClickBurst:
	extends Control

	const DURATION: float = 0.42
	const SPARK_COUNT: int = 8

	var _origin: Vector2 = Vector2.ZERO
	var _bounds: Rect2 = Rect2()
	var _time: float = 0.0
	var _angles: PackedFloat32Array = PackedFloat32Array()
	var _speeds: PackedFloat32Array = PackedFloat32Array()

	func start(bounds: Rect2, origin: Vector2) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_bounds = bounds
		_origin = Vector2(clampf(origin.x, bounds.position.x, bounds.end.x), clampf(origin.y, bounds.position.y, bounds.end.y))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		for index: int in SPARK_COUNT:
			_angles.append((float(index) + rng.randf_range(-0.3, 0.3)) / SPARK_COUNT * TAU)
			_speeds.append(rng.randf_range(0.7, 1.2))

	func _process(delta: float) -> void:
		_time += delta
		if _time >= DURATION:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress: float = _time / DURATION
		var ease_out: float = 1.0 - pow(1.0 - progress, 3.0)
		var fade: float = 1.0 - progress
		var radius: float = lerpf(8.0, maxf(_bounds.size.x, _bounds.size.y) * 0.32, ease_out)
		draw_arc(_origin, radius, 0.0, TAU, 40, Color(1.0, 0.97, 0.85, 0.75 * fade), 5.0 * fade + 1.0, true)
		for index: int in _angles.size():
			var distance: float = ease_out * 58.0 * _speeds[index]
			var point: Vector2 = _origin + Vector2.from_angle(_angles[index]) * distance
			draw_circle(point, 4.5 * fade + 1.0, Color(1.0, 0.86, 0.4, fade))
