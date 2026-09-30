extends Node2D
## Galería de revisión del arte: muestra los sprites con su contorno de equipo.
## godot --path . res://tools/ArtGallery.tscn -- --page=units|structures --unit=soldier
## Con --write-movie sirve para sacar capturas sin arrancar una partida.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/team_outline.gdshader")
const UNIT_IDS: Array[String] = ["soldier", "archer", "priest", "tank", "cavalry", "mage", "venom_archer"]
const STRUCTURE_IDS: Array[String] = ["farm", "soldier_barracks", "archer_barracks", "church", "tower", "castle"]


var _units_dir: String = "res://data/units"
var _structures_prefix: String = ""


func _ready() -> void:
	var page: String = "units"
	var unit_id: String = "soldier"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):
			page = arg.substr(7)
		elif arg.begins_with("--race="):
			_units_dir = "res://data/races/%s" % arg.substr(7)
			_structures_prefix = "%s/" % arg.substr(7)
		elif arg.begins_with("--unit="):
			unit_id = arg.substr(7)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.38, 0.55, 0.3)
	background.size = Vector2(1080, 1920)
	add_child(background)
	match page:
		"units":
			_page_units(unit_id)
		"structures":
			_page_structures()
		"cards":
			_page_cards()
		"ui":
			_page_ui()


func _team_material(team: int) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_color", MatchTypes.team_color(team))
	return material


func _add_sprite(texture: Texture2D, team: int, at: Vector2, zoom: float) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(0.5, 0.5) * zoom
	sprite.material = _team_material(team)
	sprite.position = at
	sprite.rotation = PI * team
	add_child(sprite)


func _page_units(unit_id: String) -> void:
	var frames: SpriteFrames = load("%s/%s_frames.tres" % [_units_dir, unit_id]) as SpriteFrames
	if frames == null:
		return
	# Grande (2x): idle + marcha y ataque, por equipo.
	for team: int in 2:
		var x: float = 100.0
		var y: float = 130.0 + team * 460.0
		_add_sprite(frames.get_frame_texture(&"idle", 0), team, Vector2(x, y), 2.0)
		for frame: int in frames.get_frame_count(&"walk"):
			x += 200.0
			_add_sprite(frames.get_frame_texture(&"walk", frame), team, Vector2(x, y), 2.0)
		x = 100.0
		y += 200.0
		for frame: int in frames.get_frame_count(&"attack"):
			_add_sprite(frames.get_frame_texture(&"attack", frame), team, Vector2(x, y), 2.0)
			x += 200.0
	# Tamaño real de juego: todas las unidades en fila.
	var real_x: float = 80.0
	for id: String in UNIT_IDS:
		var unit_frames: SpriteFrames = load("%s/%s_frames.tres" % [_units_dir, id]) as SpriteFrames
		for team: int in 2:
			_add_sprite(unit_frames.get_frame_texture(&"walk", 0), team, Vector2(real_x, 1000.0 + team * 110.0), 1.0)
		real_x += 120.0


func _page_structures() -> void:
	var x: float = 100.0
	var y: float = 140.0
	for id: String in STRUCTURE_IDS:
		var base: Texture2D = load("res://assets/structures/%s%s.svg" % [_structures_prefix, id]) as Texture2D
		var team_layer: Texture2D = load("res://assets/structures/%s%s_team.svg" % [_structures_prefix, id]) as Texture2D
		if base == null:
			continue
		for team: int in 2:
			var at: Vector2 = Vector2(x + team * 480.0 + 100.0, y)
			var body: Sprite2D = Sprite2D.new()
			body.texture = base
			body.scale = Vector2(0.5, 0.5)
			body.position = at
			add_child(body)
			if team_layer != null:
				var overlay: Sprite2D = Sprite2D.new()
				overlay.texture = team_layer
				overlay.scale = Vector2(0.5, 0.5)
				overlay.position = at
				overlay.modulate = MatchTypes.team_color(team)
				add_child(overlay)
		y += 300.0
		if y > 1700.0:
			y = 140.0
			x += 240.0


func _page_cards() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(20.0, 40.0)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 24)
	add_child(grid)
	var index: int = 0
	for card: CardData in GameManager.database.cards:
		var view: CardView = CardView.new()
		grid.add_child(view)
		view.set_card(index, card)
		view.set_affordable(index % 4 != 3, 12)
		index += 1


func _page_ui() -> void:
	var paths: Array[String] = [
		"res://assets/ui/app_icon.svg", "res://assets/ui/coin.svg", "res://assets/ui/padlock.svg",
		"res://assets/ui/hammer.svg", "res://assets/ui/dice.svg", "res://assets/cards/buff_armor.svg",
		"res://assets/cards/buff_max_hp.svg", "res://assets/cards/buff_move_speed.svg",
		"res://assets/cards/buff_production.svg", "res://assets/cards/buff_tower_fire_rate.svg",
		"res://assets/cards/soldiers.svg", "res://assets/cards/archers.svg", "res://assets/cards/tank.svg",
	]
	var x: float = 20.0
	var y: float = 20.0
	for path: String in paths:
		var texture: Texture2D = load(path) as Texture2D
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.position = Vector2(x, y)
		add_child(rect)
		x += texture.get_width() + 20.0
		if x > 900.0:
			x = 20.0
			y += 300.0
