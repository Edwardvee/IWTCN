extends SceneTree
## Prueba online, lado cliente (ver NetServerTest.gd).
## Envía reroll y desbloqueo de plot, intenta un comando debug (debe
## rechazarse), comprueba el estado replicado, se desconecta y se reconecta.

const TIMEOUT: float = 40.0

var _time: float = 0.0
var _step: int = 0
var _step_time: float = 0.0
var _rejections: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	root.get_node("EventBus").connect("comando_rechazado", _on_rejected)
	# Los autoloads aún no están en el árbol: se conecta en el primer frame.
	(func() -> void: root.get_node("NetworkManager").call("join", "TEST")).call_deferred()
	print("[client] conectando")


func _on_rejected(_player_id: int, command_type: StringName, reason: String) -> void:
	_rejections.append("%s: %s" % [command_type, reason])


func _in_online_match() -> bool:
	var game: Node = root.get_node("GameManager")
	if current_scene == null or current_scene.name != "Main" or not game.call("is_match_running"):
		return false
	var state: RefCounted = game.call("get_player_state", 1)
	return state != null and (state.get("shop").get("offer") as Array).size() > 0


func _submit(path: String, args: Array) -> void:
	var script: GDScript = load(path) as GDScript
	root.get_node("GameManager").call("submit_command", script.callv("new", args))


func _advance() -> void:
	_step += 1
	_step_time = _time


func _process(delta: float) -> bool:
	_time += delta
	var game: Node = root.get_node("GameManager")
	var since: float = _time - _step_time
	match _step:
		0:
			if _in_online_match():
				print("[client] partida iniciada, local_player_id=%d, oro=%d" % [game.get("local_player_id"), root.get_node("EconomyManager").call("get_gold", 1)])
				_submit("res://systems/commands/RerollShopCommand.gd", [1])
				_advance()
		1:
			if since > 1.0:
				_submit("res://systems/commands/UnlockPlotCommand.gd", [1, 5])
				_submit("res://systems/commands/DebugAddGoldCommand.gd", [1, 9999])
				_advance()
		2:
			if since > 2.0:
				var state: RefCounted = game.call("get_player_state", 1)
				var lane: Node = current_scene.get_node("World/Lane")
				var grid_node: Node = current_scene.get_node("World/EnemyGrid")
				print("[client] CHECK coste reroll replicado=%d (esperado 13)" % state.get("shop").get("reroll_cost"))
				print("[client] CHECK plot 5 replicado=%s  nodos del grid actualizados=%s" % [state.get("grid").call("is_plot_unlocked", 5), not (grid_node.get_child(5).get_node("LockOverlay") as Node2D).visible])
				print("[client] CHECK oro replicado=%d (esperado <= 5: 20 - 10 - 10 + ingresos)" % state.get("gold"))
				print("[client] CHECK soldiers del servidor visibles=%d (esperado 2)" % lane.call("get_alive_count", 0))
				print("[client] CHECK comando debug rechazado=%s (%s)" % [not _rejections.is_empty(), ", ".join(_rejections)])
				root.get_node("NetworkManager").call("close")
				print("[client] desconectado a propósito")
				_advance()
		3:
			if since > 2.0:
				root.get_node("NetworkManager").call("join", "TEST")
				print("[client] reconectando")
				_advance()
		4:
			if since > 1.0 and _in_online_match():
				var state_after: RefCounted = game.call("get_player_state", 1)
				print("[client] CHECK reconexión: plot 5 sigue desbloqueado=%s, castillo=%.0f" % [state_after.get("grid").call("is_plot_unlocked", 5), state_after.get("castle_hp")])
				return true
	return _time > TIMEOUT
