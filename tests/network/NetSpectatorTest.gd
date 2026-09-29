extends SceneTree
## Prueba online, lado espectador. Se lanza con NetServerTest y NetClientTest
## (mismo relay) unos segundos DESPUÉS de que empiece la partida, para probar
## la entrada a mitad de partida:
##   (antes: cd server/relay && npx wrangler dev)
##   godot --headless --path . -s res://tests/network/NetServerTest.gd -- --relay=ws://localhost:8787
##   godot --headless --path . -s res://tests/network/NetClientTest.gd -- --relay=ws://localhost:8787
##   (≈6 s después)
##   godot --headless --path . -s res://tests/network/NetSpectatorTest.gd -- --relay=ws://localhost:8787
## Comprueba: entra a la partida en curso, ve el estado replicado, no tiene
## autoridad y no puede enviar comandos.

const TIMEOUT: float = 40.0

var _time: float = 0.0
var _joined_at: float = -1.0
var _done: bool = false


func _initialize() -> void:
	(func() -> void: root.get_node("NetworkManager").call("spectate", "TEST")).call_deferred()
	print("[spectator] conectando")


func _process(delta: float) -> bool:
	_time += delta
	var game: Node = root.get_node("GameManager")
	if _joined_at < 0.0 and current_scene != null and current_scene.name == "Main" and game.call("is_match_running"):
		_joined_at = _time
		print("[spectator] dentro de la partida, modo=%d local_player_id=%d" % [game.get("game_mode"), game.get("local_player_id")])
	if _joined_at >= 0.0 and _time - _joined_at > 1.5 and not _done:
		_done = true
		var network: Node = root.get_node("NetworkManager")
		var lane: Node = current_scene.get_node("World/Lane")
		var script: GDScript = load("res://systems/commands/RerollShopCommand.gd") as GDScript
		var command_sent: bool = game.call("submit_command", script.new(1))
		print("[spectator] CHECK es espectador=%s (esperado true)" % network.call("is_spectator"))
		print("[spectator] CHECK solo mira=%s (esperado true)" % game.call("is_watching"))
		print("[spectator] CHECK sin autoridad=%s (esperado true)" % (not game.call("is_authority")))
		print("[spectator] CHECK soldiers del anfitrión visibles=%d (esperado 2)" % lane.call("get_alive_count", 0))
		print("[spectator] CHECK tiempo de partida replicado=%.1f s (esperado > 1)" % game.get("match_state").get("match_time"))
		print("[spectator] CHECK comando rechazado=%s (esperado true)" % (not command_sent))
		print("[spectator] CHECK barra de espectador presente=%s" % (current_scene.find_child("*", true, false) != null and _has_spectator_bar()))
		network.call("close")
		return true
	return _time > TIMEOUT


func _has_spectator_bar() -> bool:
	for node: Node in current_scene.get_node("UI/HUD").get_children():
		if node.get_script() != null and str(node.get_script().resource_path).ends_with("SpectatorBar.gd"):
			return true
	return false
