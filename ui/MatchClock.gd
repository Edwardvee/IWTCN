class_name MatchClock
extends Label
## Tiempo de partida ("2:05") bajo el contador de tropas, fuera de la barra superior y con
## la misma fuente. Solo presentación: lee MatchState.match_time, que en un cliente online
## llega en los snapshots.

const TOP: float = 122.0
const RIGHT_MARGIN: float = 20.0
const WIDTH: float = 270.0
const COLOR: Color = Color(1.0, 0.95, 0.8)
## El reloj se pone rojo cuando empieza la muerte súbita.
const SUDDEN_COLOR: Color = Color(1.0, 0.42, 0.35)

var _shown_seconds: int = -1
var _sudden_death_announced: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -(WIDTH + RIGHT_MARGIN)
	offset_right = -RIGHT_MARGIN
	offset_top = TOP
	offset_bottom = TOP + 84.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 56)
	add_theme_color_override("font_color", COLOR)
	add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	add_theme_constant_override("outline_size", 14)
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void:
		_sudden_death_announced = false
		_refresh(true))
	_refresh(true)


func _process(_delta: float) -> void:
	_refresh(false)


func _refresh(force: bool) -> void:
	var seconds: int = int(GameManager.match_state.match_time) if GameManager.match_state != null else 0
	if not force and seconds == _shown_seconds:
		return
	_shown_seconds = seconds
	text = HUD.format_time(float(seconds))
	var rules: GameRules = GameManager.get_rules()
	var sudden: bool = rules != null and rules.sudden_death_start > 0.0 and float(seconds) >= rules.sudden_death_start
	add_theme_color_override("font_color", SUDDEN_COLOR if sudden else COLOR)
	if sudden and not _sudden_death_announced:
		_sudden_death_announced = true
		var hud: HUD = get_parent() as HUD
		if hud != null and GameManager.is_match_running():
			hud.show_toast(tr("¡Muerte súbita! Los castillos pierden vida"))
