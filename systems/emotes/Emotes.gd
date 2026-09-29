class_name Emotes
extends RefCounted
## Emotes de la partida (como en Clash Royale): caritas que un jugador muestra
## a su rival. Aquí viven la lista, el arte y el tiempo de espera; el comando
## que los envía es EmoteCommand y el HUD que los dibuja es EmotePanel.
## Arte generado por tools/art/emotes.js (node tools/art/generate.js emotes).

## Segundos que hay que esperar entre un emote y el siguiente del mismo jugador.
const COOLDOWN: float = 3.0
## Margen de la autoridad para que la latencia online no rechace un emote que
## el jugador envió justo al acabar su espera.
const COOLDOWN_TOLERANCE: float = 0.3
## Segundos que se ve un emote en pantalla.
const DISPLAY_TIME: float = 2.4

## Orden = orden en el selector.
const IDS: Array[StringName] = [&"goblin_laugh", &"cry", &"angry", &"gg"]

const TEXTURES: Dictionary = {
	&"goblin_laugh": preload("res://assets/emotes/emote_goblin_laugh.svg"),
	&"cry": preload("res://assets/emotes/emote_cry.svg"),
	&"angry": preload("res://assets/emotes/emote_angry.svg"),
	&"gg": preload("res://assets/emotes/emote_gg.svg"),
}


static func is_valid(emote_id: StringName) -> bool:
	return IDS.has(emote_id)


static func get_texture(emote_id: StringName) -> Texture2D:
	return TEXTURES.get(emote_id, null) as Texture2D
