extends PanelContainer
## Muestra el oro del jugador local. Solo lee: escucha oro_actualizado y
## filtra por GameManager.local_player_id.

@onready var _amount_label: Label = %GoldAmount


func _ready() -> void:
	EventBus.oro_actualizado.connect(_on_oro_actualizado)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	_show_gold(EconomyManager.get_gold(GameManager.local_player_id))


## Cambios de oro menores que esto (ingreso pasivo) no muestran aviso.
const POPUP_MIN_DELTA: int = 6

var _last_amount: int = -1


func _show_gold(amount: int) -> void:
	_amount_label.text = str(amount)
	_last_amount = amount


func _on_oro_actualizado(player_id: int, nuevo_total: int) -> void:
	if player_id != GameManager.local_player_id:
		return
	var delta: int = nuevo_total - _last_amount if _last_amount >= 0 else 0
	_show_gold(nuevo_total)
	if absi(delta) >= POPUP_MIN_DELTA and is_inside_tree() and not GameManager.suppress_effects:
		_spawn_popup(delta)


## Aviso "-50" / "+25" que sube desde el contador de oro y se desvanece.
func _spawn_popup(delta: int) -> void:
	var popup: Label = Label.new()
	popup.top_level = true
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.text = "%+d" % delta
	popup.add_theme_font_size_override("font_size", 44)
	popup.add_theme_constant_override("outline_size", 8)
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if delta < 0 else Color(0.5, 1.0, 0.5))
	add_child(popup)
	popup.global_position = global_position + Vector2(size.x * 0.5 - 30.0, -20.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "global_position:y", popup.global_position.y - 90.0, 0.9)
	tween.tween_property(popup, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(popup.queue_free)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_show_gold(EconomyManager.get_gold(GameManager.local_player_id))
