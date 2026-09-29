class_name HUD
extends Control
## HUD principal. Solo lee estado (GameManager/EventBus); nunca lo modifica.

const REFRESH_INTERVAL: float = 0.25
const TOAST_DURATION: float = 2.0

const SUCCESS_TOAST_COLOR: Color = Color(0.1, 0.4, 0.15, 0.9)

var _refresh_accumulator: float = 0.0
var _toast_time_left: float = 0.0
var _error_style: StyleBox = null
var _success_style: StyleBoxFlat = null
var _toast_tween: Tween = null

@onready var _match_info: Label = %MatchInfo
@onready var _toast: Label = %Toast


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	EventBus.partida_terminada.connect(_on_partida_terminada)
	EventBus.comando_rechazado.connect(_on_comando_rechazado)
	EventBus.estructura_construida.connect(_on_estructura_construida)
	EventBus.estructura_vendida.connect(_on_estructura_vendida)
	EventBus.plot_desbloqueado.connect(_on_plot_desbloqueado)
	EventBus.carta_elegida.connect(_on_carta_elegida)
	_error_style = _toast.get_theme_stylebox("normal")
	_success_style = (_error_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	_success_style.bg_color = SUCCESS_TOAST_COLOR
	_toast.visible = false
	_refresh()


func _process(delta: float) -> void:
	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_time_left <= 0.0:
			_toast.visible = false
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_INTERVAL:
		return
	_refresh_accumulator = 0.0
	_refresh()


func _refresh() -> void:
	var state: MatchState = GameManager.match_state
	if state == null:
		_match_info.text = tr("Sin partida")
		return
	if GameManager.is_watching():
		_match_info.text = tr("%s · %s · oro abajo %d / arriba %d%s") % [
			MatchTypes.game_mode_name(GameManager.game_mode),
			format_time(state.match_time),
			EconomyManager.get_gold(MatchTypes.PLAYER_BOTTOM),
			EconomyManager.get_gold(MatchTypes.PLAYER_TOP),
			_describe_ai_profiles(),
		]
		return
	# Oro rival visible solo como información de desarrollo (VS AI).
	var opponent_id: int = MatchTypes.opponent_of(GameManager.local_player_id)
	_match_info.text = tr("%s · seed %d · %.1f s · rival: %d oro") % [
		MatchTypes.game_mode_name(GameManager.game_mode),
		state.match_seed,
		state.match_time,
		EconomyManager.get_gold(opponent_id),
	] + _describe_troops()


## " · tropas 5/12": ejército vivo y tope actual (depende de las granjas).
func _describe_troops() -> String:
	var lane: LaneManager = get_tree().get_first_node_in_group(&"lane") as LaneManager
	if lane == null:
		return ""
	var player_id: int = GameManager.local_player_id
	return tr(" · tropas %d/%d") % [lane.get_alive_count(player_id), lane.get_unit_cap(player_id)]


## " · abajo: rush · arriba: turtle" en espectador local (vacío en otros modos).
func _describe_ai_profiles() -> String:
	if GameManager.game_mode != MatchTypes.GameMode.SPECTATE:
		return ""
	var names: Dictionary[int, String] = {}
	for node: Node in get_tree().get_nodes_in_group(&"ai_controller"):
		var ai: AIController = node as AIController
		var rule_based: RuleBasedStrategy = ai.strategy as RuleBasedStrategy if ai != null else null
		if rule_based != null:
			names[ai.player_id] = str(rule_based.profile_name)
	if names.size() < MatchTypes.PLAYER_COUNT:
		return ""
	return tr(" · abajo: %s · arriba: %s") % [names[MatchTypes.PLAYER_BOTTOM], names[MatchTypes.PLAYER_TOP]]


static func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## success = aviso verde de acción completada; si no, aviso rojo de error.
func show_toast(message: String, success: bool = false) -> void:
	_toast.text = message
	_toast.add_theme_stylebox_override("normal", _success_style if success else _error_style)
	_toast.visible = true
	_toast_time_left = TOAST_DURATION
	_toast.pivot_offset = _toast.size * 0.5
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	if success:
		_toast.scale = Vector2(0.85, 0.85)
		_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Sacudida horizontal para que el error no pase desapercibido.
		var base_x: float = _toast.position.x
		_toast.scale = Vector2.ONE
		for offset: float in [-14.0, 14.0, -9.0, 9.0, 0.0]:
			_toast_tween.tween_property(_toast, "position:x", base_x + offset, 0.04)


func _is_local_event(player_id: int) -> bool:
	return player_id == GameManager.local_player_id and not GameManager.is_watching()


func _on_estructura_construida(player_id: int, _slot_index: int, datos: StructureData, nivel: int) -> void:
	if _is_local_event(player_id):
		show_toast(tr("%s construida · Lv%d") % [tr(datos.display_name), nivel], true)


func _on_estructura_vendida(player_id: int, _slot_index: int, oro_devuelto: int) -> void:
	if _is_local_event(player_id):
		show_toast(tr("Estructura vendida · +%d oro") % oro_devuelto, true)


func _on_plot_desbloqueado(player_id: int, _plot_index: int) -> void:
	if _is_local_event(player_id):
		show_toast(tr("Plot desbloqueado"), true)


func _on_carta_elegida(player_id: int, carta: CardData) -> void:
	if not _is_local_event(player_id):
		return
	match carta.card_type:
		CardData.CardType.DIRECT_UNIT:
			show_toast(tr("Desplegado: %d × %s") % [carta.get_unit_count_for(player_id), tr(carta.display_name)], true)
		CardData.CardType.GLOBAL_BUFF:
			show_toast(tr("Mejora activada · %s") % tr(carta.display_name), true)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_refresh()


func _on_partida_terminada(_ganador_player_id: int) -> void:
	_refresh()


func _on_comando_rechazado(player_id: int, _tipo_comando: StringName, motivo: String) -> void:
	# En builds de depuración se muestran también los rechazos del rival.
	if GameManager.is_watching():
		return
	if player_id != GameManager.local_player_id and not OS.is_debug_build():
		return
	show_toast(Reason.text(motivo))
