extends VBoxContainer
## Panel de desarrollo. Emite los MISMOS comandos que usarán el jugador y la
## IA (con source DEBUG) sobre el slot seleccionado de cualquiera de los dos
## grids. Solo existe en builds de depuración.

const GOLD_GRANT: int = 100
const CASTLE_DAMAGE: int = 1000
const FONT_SIZE: int = 30

var _target_player_id: int = MatchTypes.NO_PLAYER
var _target_slot: int = -1

var _panel: PanelContainer = null
var _target_label: Label = null
var _gold_label: Label = null


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_build_ui()
	EventBus.slot_seleccionado.connect(_on_slot_seleccionado)
	EventBus.oro_actualizado.connect(_on_oro_actualizado)
	_refresh_labels()


func _build_ui() -> void:
	var toggle: Button = _make_button("DEBUG")
	toggle.toggle_mode = true
	toggle.toggled.connect(_on_toggle)
	add_child(toggle)

	_panel = PanelContainer.new()
	_panel.visible = false
	add_child(_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_panel.add_child(content)

	_target_label = _make_label()
	content.add_child(_target_label)
	_gold_label = _make_label()
	content.add_child(_gold_label)

	var build_grid: GridContainer = GridContainer.new()
	build_grid.columns = 2
	content.add_child(build_grid)
	for card: CardData in GameManager.database.cards:
		if card.card_type != CardData.CardType.STRUCTURE:
			continue
		var button: Button = _make_button("%s (%d)" % [card.display_name, card.cost])
		button.pressed.connect(_on_build_pressed.bind(card.id))
		build_grid.add_child(button)

	var sell_button: Button = _make_button("Vender slot")
	sell_button.pressed.connect(_on_sell_pressed)
	content.add_child(sell_button)

	var gold_row: HBoxContainer = HBoxContainer.new()
	content.add_child(gold_row)
	for player_id: int in MatchTypes.PLAYER_COUNT:
		var gold_button: Button = _make_button("+%d oro P%d" % [GOLD_GRANT, player_id])
		gold_button.pressed.connect(_on_add_gold_pressed.bind(player_id))
		gold_row.add_child(gold_button)

	var ai_button: Button = _make_button("IA: ON")
	ai_button.toggle_mode = true
	ai_button.toggled.connect(_on_ai_toggled.bind(ai_button))
	content.add_child(ai_button)

	var castle_row: HBoxContainer = HBoxContainer.new()
	content.add_child(castle_row)
	for player_id: int in MatchTypes.PLAYER_COUNT:
		var castle_button: Button = _make_button("-%d castillo P%d" % [CASTLE_DAMAGE, player_id])
		castle_button.pressed.connect(_on_damage_castle_pressed.bind(player_id))
		castle_row.add_child(castle_button)

	var spawn_grid: GridContainer = GridContainer.new()
	spawn_grid.columns = 2
	content.add_child(spawn_grid)
	for unit: UnitData in GameManager.database.units:
		for player_id: int in MatchTypes.PLAYER_COUNT:
			var spawn_button: Button = _make_button("P%d: %s" % [player_id, unit.display_name])
			spawn_button.pressed.connect(_on_spawn_pressed.bind(player_id, unit.id))
			spawn_grid.add_child(spawn_button)


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.custom_minimum_size = Vector2(0.0, 72.0)
	return button


func _make_label() -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	return label


func _refresh_labels() -> void:
	if _target_slot < 0:
		_target_label.text = "Objetivo: toca un slot"
	else:
		_target_label.text = "Objetivo: P%d slot %d" % [_target_player_id, _target_slot]
	_gold_label.text = "Oro  P0: %d   P1: %d" % [EconomyManager.get_gold(0), EconomyManager.get_gold(1)]


func _on_toggle(pressed: bool) -> void:
	_panel.visible = pressed


func _on_build_pressed(card_id: StringName) -> void:
	GameManager.submit_command(BuildCommand.new(_target_player_id, card_id, _target_slot, GameCommand.Source.DEBUG))


func _on_sell_pressed() -> void:
	GameManager.submit_command(SellCommand.new(_target_player_id, _target_slot, GameCommand.Source.DEBUG))


func _on_add_gold_pressed(player_id: int) -> void:
	GameManager.submit_command(DebugAddGoldCommand.new(player_id, GOLD_GRANT))


## Pulsado = IA en pausa (para probar sistemas sin que el rival juegue).
func _on_ai_toggled(paused: bool, button: Button) -> void:
	var ai: AIController = get_tree().get_first_node_in_group(&"ai_controller") as AIController
	if ai == null:
		return
	ai.enabled = not paused
	button.text = "IA: OFF" if paused else "IA: ON"


func _on_damage_castle_pressed(player_id: int) -> void:
	GameManager.submit_command(DebugDamageCastleCommand.new(player_id, float(CASTLE_DAMAGE)))


func _on_spawn_pressed(player_id: int, unit_id: StringName) -> void:
	GameManager.submit_command(DebugSpawnUnitCommand.new(player_id, unit_id, 1))


func _on_slot_seleccionado(player_id: int, slot_index: int) -> void:
	_target_player_id = player_id
	_target_slot = slot_index
	_refresh_labels()


func _on_oro_actualizado(_player_id: int, _nuevo_total: int) -> void:
	_refresh_labels()
