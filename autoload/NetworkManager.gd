extends Node
## Transporte online vía relay de salas (WebSocket, Cloudflare Worker en server/relay).
## Sin reglas de gameplay. Funciona en PC, Android y Web (wss://).
##
## Modelo: el anfitrión crea una sala con código y es el servidor autoritativo
## (player 0); el invitado se une con el código y es el player 1.
##   cliente → comando serializado → relay → anfitrión (player_id fijado por el
##   rol, source NETWORK) → CommandProcessor → estado → snapshot → relay → cliente.
## El relay solo reenvía bytes. Los mensajes del juego son un Dictionary
## serializado con var_to_bytes en tramas binarias; las tramas de texto son
## avisos del relay (guest_joined / guest_left / host_left).
## Espectadores: cualquiera con el código puede entrar como espectador. Solo
## recibe los mismos snapshots que el invitado (nunca envía comandos) y ve la
## partida desde la vista del anfitrión, en directo.
## Reconexión: si el invitado se cae, la partida sigue en el anfitrión; al
## volver a entrar con el mismo código recupera el asiento y un snapshot completo.

signal status_changed(message: String)

## URL del relay desplegado. Se puede sobrescribir al lanzar: `-- --relay=ws://localhost:8787`.
const DEFAULT_RELAY_URL: String = "wss://iwtcn-relay.iwtcn.workers.dev"
const CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH: int = 4
const SNAPSHOT_INTERVAL: float = 0.1
## Versión del formato de mensajes (snapshots, comandos). Súbela si cambian:
## anfitrión e invitado/espectador con versiones distintas no se entenderían.
## 2 = snapshots compactos e incrementales.
const PROTOCOL_VERSION: int = 2
const KEEPALIVE_INTERVAL: float = 20.0
const MAIN_SCENE: String = "res://scenes/Main.tscn"
const MENU_SCENE: String = "res://scenes/Menu.tscn"

enum Role { NONE, HOST, GUEST, SPECTATOR }

var relay_url: String = DEFAULT_RELAY_URL
var room_code: String = ""

var _role: Role = Role.NONE
var _socket: WebSocketPeer = null
var _was_open: bool = false
var _guest_present: bool = false
var _spectator_count: int = 0
## Qué partes del estado ya se enviaron. Se vacía cuando entra alguien nuevo
## para que el siguiente snapshot vaya completo.
var _snapshot_cache: Dictionary = {}
var _replicator: StateReplicator = null
var _snapshot_timer: float = 0.0
var _keepalive_timer: float = 0.0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--relay="):
			relay_url = argument.trim_prefix("--relay=")
	EventBus.comando_rechazado.connect(_on_comando_rechazado)
	EventBus.partida_terminada.connect(_on_partida_terminada)


# --- API ------------------------------------------------------------------------

## Crea una sala nueva y devuelve su código (vacío si falla).
func host(desired_code: String = "") -> String:
	close()
	room_code = desired_code.to_upper() if desired_code != "" else _generate_code()
	if not _connect_socket(Role.HOST, room_code):
		room_code = ""
		return ""
	status_changed.emit(tr("Creando sala…"))
	return room_code


func join(code: String) -> Error:
	close()
	var normalized: String = code.strip_edges().to_upper()
	if normalized.length() < CODE_LENGTH:
		status_changed.emit(tr("Escribe el código de sala"))
		return ERR_INVALID_PARAMETER
	room_code = normalized
	if not _connect_socket(Role.GUEST, normalized):
		room_code = ""
		return FAILED
	status_changed.emit(tr("Conectando a la sala %s…") % normalized)
	return OK


## Entra a la sala como espectador (solo mira la partida en curso).
func spectate(code: String) -> Error:
	close()
	var normalized: String = code.strip_edges().to_upper()
	if normalized.length() < CODE_LENGTH:
		status_changed.emit(tr("Escribe el código de sala"))
		return ERR_INVALID_PARAMETER
	room_code = normalized
	if not _connect_socket(Role.SPECTATOR, normalized):
		room_code = ""
		return FAILED
	status_changed.emit(tr("Conectando a la sala %s como espectador…") % normalized)
	return OK


func close() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_role = Role.NONE
	_was_open = false
	_guest_present = false
	_spectator_count = 0
	_snapshot_cache.clear()
	room_code = ""
	_snapshot_timer = 0.0


## true si esta instancia es el invitado (no tiene autoridad sobre la partida).
func is_guest() -> bool:
	return _role == Role.GUEST


## true si esta instancia solo mira la partida de otro (espectador online).
func is_spectator() -> bool:
	return _role == Role.SPECTATOR


## Invitado o espectador: no simula, solo presenta lo que envía el anfitrión.
func is_client() -> bool:
	return _role == Role.GUEST or _role == Role.SPECTATOR


func is_online() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and (_role == Role.GUEST or _guest_present)


## Anfitrión con alguien mirando o jugando contra él (hay que enviar snapshots).
func _has_viewers() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and _role == Role.HOST and (_guest_present or _spectator_count > 0)


func get_spectator_count() -> int:
	return _spectator_count


## La escena de partida registra su replicador (null al salir).
func register_replicator(replicator: StateReplicator) -> void:
	_replicator = replicator


## Cliente: envía un comando al anfitrión. El resultado llega en el snapshot
## (o como comando_rechazado).
func send_command(command: GameCommand) -> bool:
	if _role != Role.GUEST or not is_online():
		return false
	_send({"k": "cmd", "data": CommandCodec.encode(command)})
	return true


# --- Conexión -------------------------------------------------------------------

func _connect_socket(role: Role, code: String) -> bool:
	_socket = WebSocketPeer.new()
	var role_name: String = "host"
	if role == Role.GUEST:
		role_name = "guest"
	elif role == Role.SPECTATOR:
		role_name = "spectator"
	var error: Error = _socket.connect_to_url("%s/room/%s?role=%s" % [relay_url, code, role_name])
	if error != OK:
		_socket = null
		status_changed.emit(tr("No se pudo conectar al relay (%s)") % error_string(error))
		return false
	_role = role
	_was_open = false
	_guest_present = false
	_spectator_count = 0
	_keepalive_timer = 0.0
	return true


func _process(delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				_on_socket_open()
			while _socket != null and _socket.get_available_packet_count() > 0:
				_on_packet(_socket.get_packet(), _socket.was_string_packet())
			_tick_open(delta)
		WebSocketPeer.STATE_CLOSED:
			_on_socket_closed(_socket.get_close_code(), _socket.get_close_reason())


func _tick_open(delta: float) -> void:
	if _socket == null:
		return
	_keepalive_timer += delta
	if _keepalive_timer >= KEEPALIVE_INTERVAL:
		_keepalive_timer = 0.0
		_socket.send_text("ping")
	if _has_viewers() and _replicator != null:
		_snapshot_timer += delta
		if _snapshot_timer >= SNAPSHOT_INTERVAL:
			_snapshot_timer = 0.0
			_broadcast_snapshot()


func _on_socket_open() -> void:
	if _role == Role.HOST:
		status_changed.emit(tr("Sala %s creada. Pasa el código a tu rival.") % room_code)
	elif _role == Role.SPECTATOR:
		status_changed.emit(tr("Conectado como espectador. Esperando la partida…"))
	else:
		status_changed.emit(tr("Conectado. Esperando inicio…"))


func _on_socket_closed(code: int, reason: String) -> void:
	var role: Role = _role
	var in_match: bool = GameManager.is_match_running() and GameManager.game_mode == MatchTypes.GameMode.ONLINE
	var message: String = tr(reason) if reason != "" else tr("Conexión con el relay perdida")
	if not _was_open and reason == "":
		message = tr("No se pudo conectar al relay")
	close()
	status_changed.emit(message)
	# Invitado o espectador que pierde la conexión en plena partida: al menú.
	if (role == Role.GUEST or role == Role.SPECTATOR) and in_match:
		get_tree().change_scene_to_file(MENU_SCENE)
	print_debug("NetworkManager: socket cerrado (%d) %s" % [code, reason])


func _send(message: Dictionary) -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send(var_to_bytes(message))


func _on_packet(packet: PackedByteArray, is_text: bool) -> void:
	if is_text:
		_on_relay_notice(packet.get_string_from_utf8())
		return
	var message: Variant = bytes_to_var(packet)
	if not message is Dictionary:
		return
	var data: Dictionary = message
	match str(data.get("k", "")):
		"cmd":
			if _role == Role.HOST:
				_host_receive_command(data.get("data", {}))
		"start":
			# "for" evita que un invitado arranque con el aviso de un espectador y viceversa.
			var target: String = str(data.get("for", "guest"))
			if (_role == Role.GUEST and target == "guest" or _role == Role.SPECTATOR and target == "spectator") and int(data.get("v", 1)) != PROTOCOL_VERSION:
				status_changed.emit(tr("Versión del juego incompatible: actualiza"))
				close()
				return
			if _role == Role.GUEST and target == "guest":
				_guest_start_match(int(data.get("seed", 0)), int(data.get("player_id", MatchTypes.PLAYER_TOP)))
			elif _role == Role.SPECTATOR and target == "spectator":
				_spectator_start_match(int(data.get("seed", 0)))
		"snap":
			if is_client() and _replicator != null:
				_replicator.apply_snapshot(data.get("snapshot", {}))
		"rej":
			if _role == Role.GUEST:
				EventBus.comando_rechazado.emit(GameManager.local_player_id, StringName(str(data.get("type", ""))), str(data.get("reason", "")))
		"end":
			if is_client():
				GameManager.end_match(int(data.get("winner", MatchTypes.NO_PLAYER)))


func _on_relay_notice(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	match str((parsed as Dictionary).get("t", "")):
		"guest_joined":
			if _role == Role.HOST:
				_host_on_guest_joined()
		"guest_left":
			if _role == Role.HOST:
				_guest_present = false
				status_changed.emit(tr("Rival desconectado: la partida sigue, esperando reconexión"))
		"spectator_joined":
			if _role == Role.HOST:
				_spectator_count += 1
				_host_on_spectator_joined()
		"spectator_left":
			if _role == Role.HOST:
				_spectator_count = maxi(0, _spectator_count - 1)
		"host_left":
			# El relay cierra el socket justo después; el mensaje se muestra en _on_socket_closed.
			status_changed.emit(tr("El anfitrión se desconectó"))


# --- Anfitrión ------------------------------------------------------------------

func _host_on_guest_joined() -> void:
	_guest_present = true
	_snapshot_cache.clear()
	var reconnecting: bool = GameManager.is_match_running() and GameManager.game_mode == MatchTypes.GameMode.ONLINE
	if reconnecting:
		_send({"k": "start", "v": PROTOCOL_VERSION, "for": "guest", "seed": GameManager.match_state.match_seed, "player_id": MatchTypes.PLAYER_TOP})
		status_changed.emit(tr("Rival reconectado"))
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var match_seed: int = maxi(1, rng.randi())
	_send({"k": "start", "v": PROTOCOL_VERSION, "for": "guest", "seed": match_seed, "player_id": MatchTypes.PLAYER_TOP})
	# Los espectadores que ya esperaban en la sala arrancan con la misma semilla.
	if _spectator_count > 0:
		_send({"k": "start", "v": PROTOCOL_VERSION, "for": "spectator", "seed": match_seed})
	GameManager.configure_next_match(MatchTypes.GameMode.ONLINE, match_seed, MatchTypes.PLAYER_BOTTOM)
	status_changed.emit(tr("Rival conectado"))
	get_tree().change_scene_to_file(MAIN_SCENE)


## Un espectador entró: si hay partida en curso se le manda la semilla para que
## arranque la escena; los snapshots (con el estado completo) empiezan a llegarle
## en cuanto está listo. Si aún no hay partida, arrancará con la siguiente.
func _host_on_spectator_joined() -> void:
	_snapshot_cache.clear()
	status_changed.emit(tr("Espectadores: %d") % _spectator_count)
	if GameManager.is_match_running() and GameManager.game_mode == MatchTypes.GameMode.ONLINE:
		_send({"k": "start", "v": PROTOCOL_VERSION, "for": "spectator", "seed": GameManager.match_state.match_seed})


func _host_receive_command(data: Dictionary) -> void:
	var command: GameCommand = CommandCodec.decode(data)
	if command == null:
		_send({"k": "rej", "type": str(data.get("type", "?")), "reason": Reason.make("Comando no permitido")})
		return
	# El cliente nunca decide quién es: lo fija el rol.
	command.player_id = MatchTypes.PLAYER_TOP
	command.source = GameCommand.Source.NETWORK
	GameManager.submit_command(command)


func _broadcast_snapshot() -> void:
	if GameManager.match_state != null and _replicator != null:
		_send({"k": "snap", "snapshot": _replicator.build_delta_snapshot(_snapshot_cache)})


func _on_comando_rechazado(player_id: int, tipo_comando: StringName, motivo: String) -> void:
	if _role == Role.HOST and is_online() and player_id == MatchTypes.PLAYER_TOP:
		_send({"k": "rej", "type": str(tipo_comando), "reason": motivo})


func _on_partida_terminada(ganador_player_id: int) -> void:
	if _has_viewers():
		_broadcast_snapshot()
		_send({"k": "end", "winner": ganador_player_id})


# --- Invitado -------------------------------------------------------------------

func _guest_start_match(match_seed: int, player_id: int) -> void:
	GameManager.configure_next_match(MatchTypes.GameMode.ONLINE, match_seed, player_id)
	status_changed.emit(tr("Partida encontrada"))
	get_tree().change_scene_to_file(MAIN_SCENE)


func _spectator_start_match(match_seed: int) -> void:
	# Ya mirando esta partida (p. ej. aviso repetido): no reiniciar la escena.
	if GameManager.is_match_running() and GameManager.game_mode == MatchTypes.GameMode.ONLINE and GameManager.match_state.match_seed == match_seed:
		return
	GameManager.configure_next_match(MatchTypes.GameMode.ONLINE, match_seed, MatchTypes.PLAYER_BOTTOM)
	status_changed.emit(tr("Partida encontrada"))
	get_tree().change_scene_to_file(MAIN_SCENE)


# --- Utilidades -----------------------------------------------------------------

func _generate_code() -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var code: String = ""
	for _i: int in CODE_LENGTH:
		code += CODE_ALPHABET[rng.randi_range(0, CODE_ALPHABET.length() - 1)]
	return code
