class_name CommandCodec
extends RefCounted
## Serializa los comandos que un cliente puede enviar al servidor.
## Lista blanca: solo acciones de jugador (jugar carta, reroll, vender,
## desbloquear plot, emote). Los comandos debug nunca se decodifican desde la red.
## El player_id y el source NO viajan: el servidor los fija según el peer.


static func encode(command: GameCommand) -> Dictionary:
	var data: Dictionary = {"type": command.get_type()}
	if command is PlayCardCommand:
		var play: PlayCardCommand = command as PlayCardCommand
		data["offer_index"] = play.offer_index
		data["card_id"] = play.card_id
		data["slot_index"] = play.slot_index
		data["deploy_position"] = play.deploy_position
	elif command is SellCommand:
		data["slot_index"] = (command as SellCommand).slot_index
	elif command is EmoteCommand:
		data["emote_id"] = (command as EmoteCommand).emote_id
	elif command is UnlockPlotCommand:
		data["plot_index"] = (command as UnlockPlotCommand).plot_index
	return data


## Devuelve null si el tipo no está permitido o los datos son inválidos.
static func decode(data: Dictionary) -> GameCommand:
	var network: GameCommand.Source = GameCommand.Source.NETWORK
	var type: StringName = StringName(str(data.get("type", "")))
	match type:
		&"play_card":
			if not (data.get("offer_index") is int and data.get("slot_index") is int and data.get("deploy_position") is Vector2):
				return null
			var card_id: StringName = StringName(str(data.get("card_id", "")))
			return PlayCardCommand.new(MatchTypes.NO_PLAYER, data["offer_index"], card_id, data["slot_index"], data["deploy_position"], network)
		&"reroll_shop":
			return RerollShopCommand.new(MatchTypes.NO_PLAYER, network)
		&"sell":
			if not data.get("slot_index") is int:
				return null
			return SellCommand.new(MatchTypes.NO_PLAYER, data["slot_index"], network)
		&"emote":
			var emote_id: StringName = StringName(str(data.get("emote_id", "")))
			if not Emotes.is_valid(emote_id):
				return null
			return EmoteCommand.new(MatchTypes.NO_PLAYER, emote_id, network)
		&"unlock_plot":
			if not data.get("plot_index") is int:
				return null
			return UnlockPlotCommand.new(MatchTypes.NO_PLAYER, data["plot_index"], network)
	return null
