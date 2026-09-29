extends SceneTree
## Genera ui/theme.tres (tema global de la interfaz). Ejecutar tras editar:
## godot --headless --path . --script res://tools/BuildTheme.gd

const OUTLINE: Color = Color(0.09, 0.07, 0.12)
const CREAM: Color = Color(1.0, 0.95, 0.83)
const OUT_PATH: String = "res://ui/theme.tres"

## Paletas de botón: cara, cara al pasar, cara al pulsar, texto.
const PALETTES: Dictionary[String, Array] = {
	"": [Color("f2b640"), Color("ffc95c"), Color("dc9c2b"), Color("3b2410")],
	"Primary": [Color("7cc95a"), Color("94dd70"), Color("62b040"), Color("133008")],
	"Danger": [Color("e8604f"), Color("f57a69"), Color("c94636"), Color("fff0e6")],
	"Wood": [Color("b5773f"), Color("c98a50"), Color("9a6230"), Color("fff0d2")],
	"Stone": [Color("8f98a6"), Color("a5aebb"), Color("79828f"), Color("15181f")],
}


func _init() -> void:
	var theme: Theme = Theme.new()
	_build_buttons(theme)
	_build_labels(theme)
	_build_panels(theme)
	_build_inputs(theme)
	_build_sliders(theme)
	var error: Error = ResourceSaver.save(theme, OUT_PATH)
	print("theme -> %s (%s)" % [OUT_PATH, error_string(error)])
	quit(0 if error == OK else 1)


func _button_box(face: Color, state: String, radius: int = 18) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = OUTLINE
	box.set_corner_radius_all(radius)
	box.set_border_width_all(4)
	# Borde inferior grueso: es el "labio" del botón; al pulsar se hunde.
	match state:
		"pressed":
			box.border_width_bottom = 6
			box.content_margin_top = 16.0
			box.content_margin_bottom = 8.0
			box.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
			box.shadow_size = 2
			box.shadow_offset = Vector2(0.0, 1.0)
		"disabled":
			box.border_width_bottom = 10
			box.content_margin_top = 10.0
			box.content_margin_bottom = 14.0
		_:
			box.border_width_bottom = 11
			box.content_margin_top = 10.0
			box.content_margin_bottom = 14.0
			box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
			box.shadow_size = 6
			box.shadow_offset = Vector2(0.0, 5.0)
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	return box


func _build_buttons(theme: Theme) -> void:
	for variation: String in PALETTES:
		var palette: Array = PALETTES[variation]
		var type_name: String = "Button" if variation == "" else variation + "Button"
		if variation != "":
			theme.set_type_variation(type_name, "Button")
		var face: Color = palette[0]
		var hover: Color = palette[1]
		var pressed: Color = palette[2]
		var text: Color = palette[3]
		theme.set_stylebox("normal", type_name, _button_box(face, "normal"))
		theme.set_stylebox("hover", type_name, _button_box(hover, "normal"))
		theme.set_stylebox("pressed", type_name, _button_box(pressed, "pressed"))
		theme.set_stylebox("hover_pressed", type_name, _button_box(pressed.lightened(0.08), "pressed"))
		theme.set_stylebox("disabled", type_name, _button_box(Color(0.5, 0.48, 0.44), "disabled"))
		theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color", "font_pressed_color"]:
			theme.set_color(color_name, type_name, text)
		theme.set_color("font_disabled_color", type_name, Color(0.9, 0.88, 0.84, 0.75))
		theme.set_color("font_outline_color", type_name, Color(0.0, 0.0, 0.0, 0.0))
		theme.set_constant("outline_size", type_name, 0)
		if variation in ["Danger", "Wood"]:
			# Texto claro sobre fondo oscuro: con contorno para que se lea bien.
			theme.set_color("font_outline_color", type_name, OUTLINE)
			theme.set_constant("outline_size", type_name, 6)


func _build_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_outline_color", "Label", OUTLINE)
	theme.set_constant("outline_size", "Label", 6)
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.0))


func _build_panels(theme: Theme) -> void:
	# Placa de madera oscura con filo dorado.
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.17, 0.11, 0.08, 0.96)
	panel.border_color = Color("e2a93b")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(16)
	panel.set_content_margin_all(14.0)
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel.shadow_size = 8
	panel.shadow_offset = Vector2(0.0, 4.0)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	# Barra superior: tablón oscuro con la línea dorada abajo.
	var bar: StyleBoxFlat = StyleBoxFlat.new()
	bar.bg_color = Color(0.13, 0.08, 0.06, 0.94)
	bar.border_color = Color("e2a93b")
	bar.border_width_bottom = 4
	bar.content_margin_left = 16.0
	bar.content_margin_right = 16.0
	bar.content_margin_top = 8.0
	bar.content_margin_bottom = 10.0
	theme.set_type_variation("TopBar", "PanelContainer")
	theme.set_stylebox("panel", "TopBar", bar)
	# Placa clara (pergamino) para fondos de cartas y avisos.
	var parchment: StyleBoxFlat = StyleBoxFlat.new()
	parchment.bg_color = Color("efe0bd")
	parchment.border_color = OUTLINE
	parchment.set_border_width_all(4)
	parchment.set_corner_radius_all(18)
	parchment.set_content_margin_all(16.0)
	theme.set_type_variation("Parchment", "PanelContainer")
	theme.set_stylebox("panel", "Parchment", parchment)


func _build_inputs(theme: Theme) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.09, 0.07)
	normal.border_color = OUTLINE
	normal.set_border_width_all(4)
	normal.border_width_top = 6
	normal.set_corner_radius_all(16)
	normal.content_margin_left = 20.0
	normal.content_margin_right = 20.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.border_color = Color("e2a93b")
	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("read_only", "LineEdit", normal)
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", Color(1.0, 0.95, 0.83, 0.4))
	theme.set_color("caret_color", "LineEdit", Color("f2b640"))
	theme.set_color("selection_color", "LineEdit", Color(0.95, 0.72, 0.25, 0.4))


func _build_sliders(theme: Theme) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.09, 0.06, 0.05)
	track.border_color = OUTLINE
	track.set_border_width_all(3)
	track.set_corner_radius_all(10)
	track.content_margin_top = 10.0
	track.content_margin_bottom = 10.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color("f2b640")
	fill.border_color = OUTLINE
	fill.set_border_width_all(3)
	fill.set_corner_radius_all(10)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
