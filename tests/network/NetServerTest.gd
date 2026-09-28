extends SceneTree
## Prueba online, lado anfitrión. Ejecutar junto a NetClientTest.gd:
##   (antes: cd server/relay && npx wrangler dev)
##   godot --headless --path . -s res://tests/network/NetServerTest.gd -- --relay=ws://localhost:8787
##   godot --headless --path . -s res://tests/network/NetClientTest.gd -- --relay=ws://localhost:8787
## Las clases de juego se cargan en runtime: los scripts -s compilan antes que los autoloads.

const TIMEOUT: float = 40.0

var _time: float = 0.0
var _match_started_at: float = -1.0
var _spawned: bool = false
var _done: bool = false
var _reconnected: bool = false


func _initialize() -> void:
	# Los autoloads aún no están en el árbol: se abre el puerto en el primer frame.
	(func() -> void: root.get_node("NetworkManager").call("host", "TEST")).call_deferred()
	root.get_node("NetworkManager").connect("status_changed", _on_status)
	print("[server] esperando cliente")


func _on_status(message: String) -> void:
	if message == "Rival reconectado":
		_reconnected = true
		print("[server] rival reconectado: mismo asiento (player 1)")


func _process(delta: float) -> bool:
	_time += delta
	var game: Node = root.get_node("GameManager")
	if _match_started_at < 0.0 and current_scene != null and current_scene.name == "Main" and game.call("is_match_running"):
		_match_started_at = _time
		print("[server] partida iniciada, local_player_id=%d" % game.get("local_player_id"))
	if _match_started_at >= 0.0 and not _spawned and _time - _match_started_at > 1.0:
		_spawned = true
		var spawn: GDScript = load("res://systems/commands/DebugSpawnUnitCommand.gd") as GDScript
		game.call("submit_command", spawn.new(0, &"soldier", 2))
		print("[server] 2 soldiers del player 0 desplegados")
	if _match_started_at >= 0.0 and _time - _match_started_at > 16.0 and not _done:
		_done = true
		var state: RefCounted = game.call("get_player_state", 1)
		var shop: RefCounted = state.get("shop")
		var grid: RefCounted = state.get("grid")
		print("[server] CHECK reroll_count P1=%d (esperado 1)" % shop.get("reroll_count"))
		print("[server] CHECK plot 5 P1 desbloqueado=%s" % grid.call("is_plot_unlocked", 5))
		print("[server] CHECK reconexión recibida=%s" % _reconnected)
		return true
	return _time > TIMEOUT
