class_name TroopCounter
extends Control
## Tropas vivas / límite del jugador local en la esquina superior derecha ("4/20"),
## con un muslito de comida al lado (como el hambre de Minecraft). El número se vuelve
## rojo cuando el ejército llega al límite. Solo presentación.

const REFRESH_INTERVAL: float = 0.2
const ICON: Texture2D = preload("res://assets/ui/drumstick.svg")
const NORMAL_COLOR: Color = Color(1.0, 0.95, 0.8)
const FULL_COLOR: Color = Color(1.0, 0.42, 0.35)

## Carril del que lee (si no se asigna, el de la escena).
var lane: LaneManager = null

var _label: Label = null
var _icon: TextureRect = null
var _timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 56)
	_label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.12))
	_label.add_theme_constant_override("outline_size", 14)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	_icon = TextureRect.new()
	_icon.texture = ICON
	_icon.custom_minimum_size = Vector2(84.0, 84.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_refresh()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= REFRESH_INTERVAL:
		_timer = 0.0
		_refresh()


## Texto "vivas/límite" (para tests).
func get_text() -> String:
	return _label.text


func _refresh() -> void:
	var source: LaneManager = lane if lane != null else get_tree().get_first_node_in_group(&"lane") as LaneManager
	if source == null or GameManager.match_state == null:
		_label.text = "0/0"
		return
	var player_id: int = GameManager.local_player_id
	var alive: int = source.get_army_count(player_id)
	var limit: int = source.get_unit_cap(player_id)
	_label.text = "%d/%d" % [alive, limit]
	_label.add_theme_color_override("font_color", FULL_COLOR if alive >= limit else NORMAL_COLOR)
