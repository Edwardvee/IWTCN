class_name EmoteCommand
extends GameCommand
## Mostrar un emote al rival. Solo lleva el id: la autoridad comprueba que exista
## y que hayan pasado Emotes.COOLDOWN segundos desde el último del jugador.

var emote_id: StringName = &""


func _init(p_player_id: int, p_emote_id: StringName, p_source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> void:
	player_id = p_player_id
	emote_id = p_emote_id
	source = p_source


func get_type() -> StringName:
	return &"emote"


func validate(_processor: CommandProcessor) -> String:
	if not Emotes.is_valid(emote_id):
		return Reason.make("Emote desconocido")
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null:
		return Reason.make("Jugador inválido")
	if player_state.emote_seq > 0 and GameManager.match_state.match_time - player_state.emote_time < Emotes.COOLDOWN - Emotes.COOLDOWN_TOLERANCE:
		return Reason.make("Emote en enfriamiento")
	return ""


func apply(_processor: CommandProcessor) -> bool:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	player_state.emote_id = emote_id
	player_state.emote_seq += 1
	player_state.emote_time = GameManager.match_state.match_time
	EventBus.emote_mostrado.emit(player_id, emote_id)
	return true
