class_name PauseMenu
extends Control
## Menú de partida: botón arriba a la izquierda que abre Continuar / Opciones / Rendirse.
## En VS IA pausa el juego mientras está abierto; en online la partida sigue en
## marcha (el rival no puede esperar). Rendirse se envía como SurrenderCommand.
## Solo aparece jugando (no en la cuenta atrás, ni de espectador o repetición).

const MENU_BUTTON_SIZE: float = 96.0
const MENU_BUTTON_POSITION: Vector2 = Vector2(24.0, 132.0)

var _menu_button: Button = null
var _overlay: ColorRect = null
var _pages: Dictionary[StringName, Control] = {}
var _live_note: Label = null
var _volume_slider: HSlider = null
var _paused_by_menu: bool = false


func _ready() -> void:
	# Debe seguir vivo con el árbol en pausa para poder reanudar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_button()
	_build_overlay()
	EventBus.partida_terminada.connect(func(_winner: int) -> void: close_menu())
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void: close_menu())
	_refresh_button()


func _exit_tree() -> void:
	# Salir de la escena con el menú abierto no debe dejar el juego pausado.
	if _paused_by_menu:
		get_tree().paused = false


func _process(_delta: float) -> void:
	_refresh_button()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _menu_button.visible:
		if is_open():
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _overlay.visible


## VS IA es la única partida que se puede pausar.
func pauses_game() -> bool:
	return GameManager.game_mode == MatchTypes.GameMode.VS_AI


func open_menu() -> void:
	if not _menu_button.visible or is_open():
		return
	_show_page(&"main")
	_overlay.visible = true
	_live_note.visible = not pauses_game()
	if pauses_game():
		get_tree().paused = true
		_paused_by_menu = true


func close_menu() -> void:
	_overlay.visible = false
	if _paused_by_menu:
		get_tree().paused = false
		_paused_by_menu = false


func surrender() -> void:
	close_menu()
	GameManager.submit_command(SurrenderCommand.new(GameManager.local_player_id))


func _refresh_button() -> void:
	_menu_button.visible = GameManager.is_match_running() and not GameManager.is_watching()


func _build_button() -> void:
	_menu_button = Button.new()
	_menu_button.text = "≡"
	_menu_button.theme_type_variation = &"StoneButton"
	_menu_button.add_theme_font_size_override("font_size", 64)
	_menu_button.custom_minimum_size = Vector2(MENU_BUTTON_SIZE, MENU_BUTTON_SIZE)
	_menu_button.position = MENU_BUTTON_POSITION
	_menu_button.size = Vector2(MENU_BUTTON_SIZE, MENU_BUTTON_SIZE)
	_menu_button.pressed.connect(open_menu)
	add_child(_menu_button)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.02, 0.05, 0.72)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(760.0, 0.0)
	center.add_child(card)
	var stack: VBoxContainer = VBoxContainer.new()
	card.add_child(stack)

	var main_page: VBoxContainer = _make_page(stack, tr("Menú"))
	_live_note = Label.new()
	_live_note.text = tr("La partida sigue en marcha")
	_live_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_live_note.add_theme_font_size_override("font_size", 30)
	_live_note.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_page.add_child(_live_note)
	_add_button(main_page, tr("Continuar"), &"PrimaryButton", close_menu)
	_add_button(main_page, tr("Opciones"), &"WoodButton", _show_page.bind(&"options"))
	_add_button(main_page, tr("Rendirse"), &"DangerButton", _show_page.bind(&"confirm"))
	_pages[&"main"] = main_page

	var options_page: VBoxContainer = _make_page(stack, tr("Opciones"))
	var volume_label: Label = Label.new()
	volume_label.text = tr("Volumen")
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_label.add_theme_font_size_override("font_size", 40)
	options_page.add_child(volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = AudioSettings.load_saved()
	_volume_slider.custom_minimum_size = Vector2(560.0, 64.0)
	_volume_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(_on_volume_changed)
	options_page.add_child(_volume_slider)
	_add_button(options_page, tr("Atrás"), &"StoneButton", _show_page.bind(&"main"))
	_pages[&"options"] = options_page

	var confirm_page: VBoxContainer = _make_page(stack, tr("¿Seguro que quieres rendirte?"))
	_add_button(confirm_page, tr("Sí, rendirme"), &"DangerButton", surrender)
	_add_button(confirm_page, tr("No, seguir jugando"), &"PrimaryButton", _show_page.bind(&"main"))
	_pages[&"confirm"] = confirm_page
	_show_page(&"main")


func _make_page(parent: Control, title: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 28)
	var label: Label = Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(640.0, 0.0)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_constant_override("outline_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	page.add_child(label)
	parent.add_child(page)
	return page


func _add_button(page: Control, text: String, variation: StringName, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(560.0, 110.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 44)
	button.pressed.connect(callback)
	page.add_child(button)


func _show_page(page_id: StringName) -> void:
	for id: StringName in _pages:
		_pages[id].visible = id == page_id


func _on_volume_changed(value: float) -> void:
	AudioSettings.apply(value)
	AudioSettings.save(value)
