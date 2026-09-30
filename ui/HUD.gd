class_name HUD
extends Control
## HUD principal. Solo lee estado (GameManager/EventBus); nunca lo modifica.

const TOAST_DURATION: float = 2.0

const SUCCESS_TOAST_COLOR: Color = Color(0.1, 0.4, 0.15, 0.9)

var _toast_time_left: float = 0.0
var _error_style: StyleBox = null
var _success_style: StyleBoxFlat = null
var _toast_tween: Tween = null
## Cartas con requisito (unidades especiales, Tank) que el jugador local ya tiene desbloqueadas.
var _unlocked_cards: Dictionary[StringName, bool] = {}

@onready var _toast: Label = %Toast


func _ready() -> void:
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	EventBus.partida_terminada.connect(_on_partida_terminada)
	EventBus.comando_rechazado.connect(_on_comando_rechazado)
	EventBus.estructura_construida.connect(_on_estructura_construida)
	EventBus.estructura_vendida.connect(_on_estructura_vendida)
	EventBus.plot_desbloqueado.connect(_on_plot_desbloqueado)
	EventBus.carta_elegida.connect(_on_carta_elegida)
	EventBus.sabotaje_aplicado.connect(_on_sabotaje_aplicado)
	_error_style = _toast.get_theme_stylebox("normal")
	_success_style = (_error_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	_success_style.bg_color = SUCCESS_TOAST_COLOR
	_toast.visible = false


func _process(delta: float) -> void:
	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_time_left <= 0.0:
			_toast.visible = false


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
		_check_unlocked_cards(true)


func _on_estructura_vendida(player_id: int, _slot_index: int, oro_devuelto: int) -> void:
	if _is_local_event(player_id):
		show_toast(tr("Estructura vendida · +%d oro") % oro_devuelto, true)
		_check_unlocked_cards(false)


## Avisa (arriba, como el resto de avisos) de las cartas con requisito que acaban de
## desbloquearse. announce = false solo actualiza el registro (al vender).
func _check_unlocked_cards(announce: bool) -> void:
	var player_state: PlayerState = GameManager.get_player_state(GameManager.local_player_id)
	if player_state == null or GameManager.database == null:
		return
	var race: RaceData = GameManager.get_race(GameManager.local_player_id)
	for card: CardData in GameManager.database.cards:
		if not card.has_unlock_requirement() or card.card_type != CardData.CardType.DIRECT_UNIT:
			continue
		var unlocked: bool = card.is_unlocked_for(player_state, GameManager.database)
		if unlocked and not _unlocked_cards.has(card.id):
			_unlocked_cards[card.id] = true
			if announce:
				var card_name: String = race.get_card_name(card) if race != null else card.display_name
				# Con retraso: primero se ve el aviso de "construida" y luego este.
				get_tree().create_timer(TOAST_DURATION + 0.1).timeout.connect(_announce_unlock.bind(tr("¡Unidad desbloqueada: %s!") % tr(card_name)))
		elif not unlocked:
			_unlocked_cards.erase(card.id)


func _announce_unlock(message: String) -> void:
	show_toast(message, true)
	Sfx.play(&"unlock")


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


## Aviso rojo a quien sufre el sabotaje y verde a quien lo lanza (solo lo ve el jugador local).
func _on_sabotaje_aplicado(atacante_id: int, objetivo_id: int, kind: int, detail: String) -> void:
	var text: String = ""
	var victim: bool = _is_local_event(objetivo_id)
	if victim:
		match kind:
			CardData.SabotageKind.FREEZE_STRUCTURE:
				text = tr("¡Sabotaje! %s congelada") % tr(detail)
			CardData.SabotageKind.BLOCK_SHOP_SLOT:
				text = tr("¡Sabotaje! Una carta de tu tienda quedó bloqueada")
			CardData.SabotageKind.FORCE_REROLL:
				text = tr("¡Sabotaje! Tu tienda fue renovada")
			CardData.SabotageKind.STEAL_GOLD:
				text = tr("¡Sabotaje! Te robaron %d de oro") % int(detail)
			CardData.SabotageKind.SILENCE_SPELLS:
				text = tr("¡Sabotaje! Tus hechizos quedaron silenciados")
	elif _is_local_event(atacante_id):
		match kind:
			CardData.SabotageKind.FREEZE_STRUCTURE:
				text = tr("Rival: %s congelada") % tr(detail)
			CardData.SabotageKind.BLOCK_SHOP_SLOT:
				text = tr("Rival: una carta de su tienda bloqueada")
			CardData.SabotageKind.FORCE_REROLL:
				text = tr("Rival: su tienda fue renovada")
			CardData.SabotageKind.STEAL_GOLD:
				text = tr("Rival: le robaste %d de oro") % int(detail)
			CardData.SabotageKind.SILENCE_SPELLS:
				text = tr("Rival: sus hechizos quedaron silenciados")
	if text == "":
		return
	show_toast(text, not victim)
	Sfx.play(&"thunder" if victim else &"laugh")


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_unlocked_cards.clear()


func _on_partida_terminada(_ganador_player_id: int) -> void:
	pass


func _on_comando_rechazado(player_id: int, _tipo_comando: StringName, motivo: String) -> void:
	if GameManager.is_watching():
		return
	# En builds de depuración se muestran también los rechazos de la IA rival,
	# pero nunca online: allí el rival es una persona y el aviso no es suyo.
	if player_id != GameManager.local_player_id and (NetworkManager.is_online() or not OS.is_debug_build()):
		return
	show_toast(Reason.text(motivo))
