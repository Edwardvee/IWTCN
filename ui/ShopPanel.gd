class_name ShopPanel
extends PanelContainer
## Barra inferior: tienda de 3 cartas, reroll, oro y martillo.
##
## Solo presentación: muestra la oferta del jugador local (draft_ofrecido) y
## traduce gestos a llamadas del LocalInputController, que crea los comandos.
## Soltar una carta sobre la propia barra cancela el arrastre.

signal card_drag_started
signal card_drag_finished

var local_input: LocalInputController = null

var _card_views: Array[CardView] = []
var _drag_preview: Label = null

@onready var _card_row: HBoxContainer = %CardRow
@onready var _reroll_button: Button = %RerollButton
@onready var _hammer_button: Button = %HammerButton


func _ready() -> void:
	var offer_size: int = GameManager.get_rules().shop_offer_size if GameManager.get_rules() != null else 3
	for _index: int in offer_size:
		var view: CardView = CardView.new()
		view.drag_started.connect(_on_card_drag_started)
		view.drag_moved.connect(_on_card_drag_moved)
		view.drag_released.connect(_on_card_drag_released)
		_card_row.add_child(view)
		_card_views.append(view)
	_create_drag_preview()
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_hammer_button.toggle_mode = true
	_hammer_button.toggled.connect(_on_hammer_toggled)
	EventBus.draft_ofrecido.connect(_on_draft_ofrecido)
	EventBus.oro_actualizado.connect(_on_oro_actualizado)
	EventBus.estructura_construida.connect(func(pid: int, _s: int, _d: StructureData, _l: int) -> void: _on_estructura_cambiada(pid))
	EventBus.estructura_fusionada.connect(func(pid: int, _a: int, _b: int, _l: int) -> void: _on_estructura_cambiada(pid))
	EventBus.estructura_vendida.connect(func(pid: int, _s: int, _g: int) -> void: _on_estructura_cambiada(pid))
	EventBus.coste_reroll_actualizado.connect(_on_coste_reroll_actualizado)


## Main llama a esto al conectar la escena.
func connect_input(input: LocalInputController) -> void:
	local_input = input
	local_input.hammer_mode_changed.connect(_on_hammer_mode_changed)


func _create_drag_preview() -> void:
	_drag_preview = Label.new()
	_drag_preview.top_level = true
	_drag_preview.visible = false
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drag_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drag_preview.custom_minimum_size = Vector2(220.0, 90.0)
	_drag_preview.add_theme_font_size_override("font_size", 32)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = Color.WHITE
	_drag_preview.add_theme_stylebox_override("normal", style)
	add_child(_drag_preview)


func _refresh_affordability() -> void:
	var gold: int = EconomyManager.get_gold(GameManager.local_player_id)
	for view: CardView in _card_views:
		if view.card != null:
			view.refresh_cost()
			view.set_affordable(gold >= EconomyManager.get_card_cost(GameManager.local_player_id, view.card))


# --- Arrastre --------------------------------------------------------------------

func _on_card_drag_started(view: CardView, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_drag_preview.text = view.card.display_name
	_drag_preview.visible = true
	_move_preview(screen_position)
	local_input.begin_card_drag(view.card)
	card_drag_started.emit()


func _on_card_drag_moved(_view: CardView, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_move_preview(screen_position)
	local_input.update_card_drag(screen_position)


func _on_card_drag_released(view: CardView, screen_position: Vector2) -> void:
	if local_input == null:
		return
	_drag_preview.visible = false
	var cancelled: bool = get_global_rect().has_point(screen_position)
	local_input.end_card_drag(view.offer_index, view.card, screen_position, cancelled)
	card_drag_finished.emit()


func _move_preview(screen_position: Vector2) -> void:
	_drag_preview.global_position = screen_position - _drag_preview.size * 0.5 - Vector2(0.0, 80.0)


# --- Botones -------------------------------------------------------------------

func _on_reroll_pressed() -> void:
	GameManager.submit_command(RerollShopCommand.new(GameManager.local_player_id))


func _on_hammer_toggled(pressed: bool) -> void:
	if local_input != null:
		local_input.set_hammer_mode(pressed)


func _on_hammer_mode_changed(active: bool) -> void:
	_hammer_button.set_pressed_no_signal(active)
	_hammer_button.text = "Vender: toca" if active else "Martillo"


# --- Eventos -------------------------------------------------------------------

func _on_draft_ofrecido(player_id: int, cartas: Array[CardData]) -> void:
	if player_id != GameManager.local_player_id:
		return
	for index: int in _card_views.size():
		_card_views[index].set_card(index, cartas[index] if index < cartas.size() else null)
	_refresh_affordability()


func _on_oro_actualizado(player_id: int, _nuevo_total: int) -> void:
	if player_id == GameManager.local_player_id:
		_refresh_affordability()


func _on_estructura_cambiada(player_id: int) -> void:
	if player_id == GameManager.local_player_id:
		_refresh_affordability()


func _on_coste_reroll_actualizado(player_id: int, coste: int) -> void:
	if player_id == GameManager.local_player_id:
		_reroll_button.text = "Reroll ● %d" % coste
