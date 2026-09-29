extends Node
## Ayuda para capturas: arranca Main en modo espectador y coloca la cámara.
## godot --path . res://tools/GameShot.tscn -- --cam-y=1600 --speed=4
## (usar con --write-movie; ver tools/ArtGallery.gd)


func _ready() -> void:
	var cam_y: float = 1600.0
	var speed: float = 1.0
	var vs_ai: bool = false
	var seat: int = MatchTypes.PLAYER_BOTTOM
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--vs":
			vs_ai = true
		elif arg == "--top":
			seat = MatchTypes.PLAYER_TOP
		elif arg.begins_with("--cam-y="):
			cam_y = float(arg.substr(8))
		elif arg.begins_with("--speed="):
			speed = float(arg.substr(8))
	Engine.time_scale = speed
	var mode: MatchTypes.GameMode = MatchTypes.GameMode.VS_AI if vs_ai else MatchTypes.GameMode.SPECTATE
	GameManager.configure_next_match(mode, 12345, seat)
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	if vs_ai:
		return
	var camera: Camera2D = main.get_node("Camera2D")
	camera.set_process_unhandled_input(false)
	camera.position.y = cam_y
	camera.set_script(null)
	camera.position = Vector2(540.0, cam_y)
