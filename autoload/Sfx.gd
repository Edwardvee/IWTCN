extends Node
## Efectos de sonido de la partida: flechas, impactos, muertes, golpes al castillo,
## rebote de los edificios, habilidades de castillo, emotes y fin de partida.
## Solo presentación: escucha el EventBus (igual en local, online y repeticiones) y
## reproduce con un conjunto de reproductores reutilizables. Cada sonido tiene un
## intervalo mínimo para que un ejército entero no sature el audio.
## Los WAV salen de tools/art/audio.js (node tools/art/generate.js audio).
## El sonido de botones y avisos vive en UIFeedback (que también lo silencia).

const VOICES: int = 14
## Velocidad de las voces de presentación (1,2 = un 20 % más rápidas; el tono se compensa).
const INTRO_SPEED: float = 1.4
## Lo que suena del bando rival va un poco más bajo que lo propio.
const RIVAL_OFFSET_DB: float = -4.0

## id → [sonido, volumen dB, intervalo mínimo en s, variación de tono]
const SOUNDS: Dictionary = {
	&"arrow": [preload("res://assets/audio/arrow.wav"), -17.0, 0.07, 0.10],
	&"hit": [preload("res://assets/audio/hit.wav"), -15.0, 0.05, 0.12],
	&"death": [preload("res://assets/audio/death.wav"), -14.0, 0.10, 0.10],
	&"castle": [preload("res://assets/audio/castle.wav"), -6.0, 0.15, 0.06],
	&"boing": [preload("res://assets/audio/boing.wav"), -11.0, 0.12, 0.10],
	&"rain": [preload("res://assets/audio/rain.wav"), -6.0, 0.0, 0.0],
	&"thunder": [preload("res://assets/audio/thunder.wav"), -3.0, 0.0, 0.0],
	&"horn": [preload("res://assets/audio/horn.wav"), -6.0, 0.0, 0.0],
	&"pop": [preload("res://assets/audio/pop.wav"), -8.0, 0.0, 0.05],
	&"drum": [preload("res://assets/audio/drum.wav"), 0.0, 0.0, 0.0],
	&"laugh": [preload("res://assets/audio/laugh.wav"), -5.0, 0.0, 0.04],
	&"unlock": [preload("res://assets/audio/unlock.wav"), -6.0, 0.0, 0.0],
	&"win": [preload("res://assets/audio/win.wav"), -4.0, 0.0, 0.0],
	&"lose": [preload("res://assets/audio/lose.wav"), -4.0, 0.0, 0.0],
}

var enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _intro_player: AudioStreamPlayer = null
var _last_played: Dictionary[StringName, int] = {}
var _castle_hp: Dictionary[int, float] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioSettings.apply(AudioSettings.load_saved())
	for _index: int in VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	EventBus.proyectil_disparado.connect(func(_position: Vector2, team: int) -> void: play(&"arrow", _side_offset(team)))
	EventBus.unidad_vida_cambiada.connect(_on_unidad_vida_cambiada)
	EventBus.unidad_eliminada.connect(func(_unit: CharacterBody2D, team: int) -> void: play(&"death", _side_offset(team)))
	EventBus.castillo_danado.connect(_on_castillo_danado)
	EventBus.hechizo_lanzado.connect(_on_hechizo_lanzado)
	EventBus.emote_mostrado.connect(_on_emote_mostrado)
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void: _castle_hp.clear())
	EventBus.partida_terminada.connect(_on_partida_terminada)


## Reproduce un efecto. offset_db baja o sube su volumen (p. ej. el bando rival).
func play(sound_id: StringName, offset_db: float = 0.0) -> void:
	if not enabled or not UIFeedback.sound_enabled or GameManager.suppress_effects or not SOUNDS.has(sound_id):
		return
	var entry: Array = SOUNDS[sound_id]
	var now: int = Time.get_ticks_msec()
	var min_interval: int = roundi(float(entry[2]) * 1000.0)
	if min_interval > 0 and now - int(_last_played.get(sound_id, -100000)) < min_interval:
		return
	_last_played[sound_id] = now
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = entry[0] as AudioStream
	player.volume_db = float(entry[1]) + offset_db
	var variation: float = float(entry[3])
	player.pitch_scale = randf_range(1.0 - variation, 1.0 + variation) if variation > 0.0 else 1.0
	player.play()


## Voz de presentación de una raza (MatchIntro). Va aparte de las voces normales para que
## no se corte y respeta el interruptor de sonido.
func play_intro(stream: AudioStream) -> void:
	if not enabled or not UIFeedback.sound_enabled or GameManager.suppress_effects or stream == null:
		return
	if _intro_player == null:
		_intro_player = AudioStreamPlayer.new()
		_intro_player.bus = _create_intro_bus()
		add_child(_intro_player)
	_intro_player.stream = stream
	_intro_player.pitch_scale = INTRO_SPEED
	_intro_player.play()


## Bus propio con un cambiador de tono que deshace la subida de tono de acelerar el audio:
## el reproductor va a INTRO_SPEED (más rápido y más agudo) y este efecto baja el tono lo
## mismo, así que la voz suena más rápida pero con su tono de siempre.
func _create_intro_bus() -> StringName:
	var bus_name: StringName = &"Intro"
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	var shifter: AudioEffectPitchShift = AudioEffectPitchShift.new()
	shifter.pitch_scale = 1.0 / INTRO_SPEED
	shifter.oversampling = 8
	shifter.fft_size = AudioEffectPitchShift.FFT_SIZE_2048
	AudioServer.add_bus_effect(index, shifter)
	return bus_name


## Volumen relativo según de quién es el suceso: lo del rival suena más bajo.
func _side_offset(team: int) -> float:
	if GameManager.is_watching() or team == GameManager.local_player_id:
		return 0.0
	return RIVAL_OFFSET_DB


func _on_unidad_vida_cambiada(unit: CharacterBody2D, delta: float) -> void:
	if delta < 0.0 and is_instance_valid(unit):
		play(&"hit", _side_offset((unit as UnitBase).team))


func _on_castillo_danado(player_id: int, vida_actual: float, vida_maxima: float) -> void:
	var previous: float = _castle_hp.get(player_id, vida_maxima)
	_castle_hp[player_id] = vida_actual
	if vida_actual < previous:
		play(&"castle", _side_offset(player_id))


func _on_hechizo_lanzado(player_id: int, spell_id: StringName, _position: Vector2) -> void:
	var spell: SpellData = GameManager.database.get_spell(spell_id) if GameManager.database != null else null
	if spell == null:
		return
	var sound: StringName = &"rain"
	match spell.kind:
		SpellData.Kind.LIGHTNING:
			sound = &"thunder"
		SpellData.Kind.MILITIA:
			sound = &"horn"
	play(sound, _side_offset(player_id))


func _on_emote_mostrado(player_id: int, emote_id: StringName) -> void:
	play(&"laugh" if emote_id == &"goblin_laugh" else &"pop", _side_offset(player_id))


func _on_partida_terminada(ganador_player_id: int) -> void:
	if GameManager.is_watching() or ganador_player_id == MatchTypes.NO_PLAYER:
		return
	play(&"win" if ganador_player_id == GameManager.local_player_id else &"lose")
