extends Control
## Menú principal: VS IA, crear sala online (código) o unirse con un código.
## Solo configura y navega; la partida la arranca Main.

const MAIN_SCENE: String = "res://scenes/Main.tscn"

@onready var _code: LineEdit = %Address
@onready var _status: Label = %Status


func _ready() -> void:
	%PlayAI.pressed.connect(_on_play_ai_pressed)
	%Host.pressed.connect(_on_host_pressed)
	%Join.pressed.connect(_on_join_pressed)
	_code.text_changed.connect(_on_code_changed)
	NetworkManager.status_changed.connect(_on_status_changed)
	%LocalIP.text = "Online: el anfitrión crea una sala y comparte el código"


func _on_play_ai_pressed() -> void:
	NetworkManager.close()
	GameManager.configure_next_match(MatchTypes.GameMode.VS_AI, 0, MatchTypes.PLAYER_BOTTOM)
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_host_pressed() -> void:
	NetworkManager.host()


func _on_join_pressed() -> void:
	NetworkManager.join(_code.text)


func _on_code_changed(text: String) -> void:
	var upper: String = text.to_upper()
	if upper != text:
		var column: int = _code.caret_column
		_code.text = upper
		_code.caret_column = column


func _on_status_changed(message: String) -> void:
	_status.text = message
