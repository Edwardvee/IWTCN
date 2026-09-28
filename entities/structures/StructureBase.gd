class_name StructureBase
extends Node2D
## Estructura construida en un slot.
##
## Fase 3: identidad, nivel y visual (sprite animado o rectángulo de color).
## El comportamiento (ingresos, producción, disparo) llega en las Fases 7-8.
## El nivel lo decide GridManager (= nº de estructuras de este tipo del jugador).

var building_id: int = 0
var owner_id: int = MatchTypes.NO_PLAYER
var data: StructureData = null
var slot_index: int = -1
var level: int = 1
var body_size: Vector2 = Vector2(120.0, 120.0)

var _label: Label = null
var _sprite: AnimatedSprite2D = null


func setup(p_building_id: int, p_owner_id: int, p_data: StructureData, p_slot_index: int, p_body_size: Vector2) -> void:
	building_id = p_building_id
	owner_id = p_owner_id
	data = p_data
	slot_index = p_slot_index
	body_size = p_body_size
	name = "Structure_%d" % building_id
	_create_visuals()


func set_level(new_level: int) -> void:
	level = data.clamp_level(new_level) if data != null else maxi(1, new_level)
	_update_label()


func _create_visuals() -> void:
	if data == null:
		return
	if data.sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = data.sprite_frames
		if data.sprite_frames.has_animation(data.anim_idle):
			_sprite.play(data.anim_idle)
		add_child(_sprite)
	_label = Label.new()
	_label.position = -body_size * 0.5
	_label.size = body_size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_label)
	_update_label()
	queue_redraw()


func _update_label() -> void:
	if _label == null or data == null:
		return
	var short_name: String = data.short_label if data.short_label != "" else data.display_name
	_label.text = "%s\nLv%d" % [short_name, level]


func _draw() -> void:
	if data == null:
		return
	var rect: Rect2 = Rect2(-body_size * 0.5, body_size)
	if _sprite == null:
		draw_rect(rect, data.color)
	draw_rect(rect, MatchTypes.team_color(owner_id), false, 6.0)
