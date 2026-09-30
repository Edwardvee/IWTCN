extends TestSuite
## Efectos de sonido: todos existen, se reproducen y el intervalo mínimo frena la saturación.


func before_each() -> void:
	Sfx.enabled = true
	UIFeedback.sound_enabled = true
	GameManager.suppress_effects = false
	Sfx._last_played.clear()


func after_all() -> void:
	GameManager.suppress_effects = false


func _playing_voices() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in Sfx._players:
		if player.playing:
			count += 1
	return count


func test_every_sound_is_a_loaded_stream() -> void:
	for sound_id: StringName in Sfx.SOUNDS:
		var stream: AudioStream = Sfx.SOUNDS[sound_id][0] as AudioStream
		assert_true(stream != null and stream.get_length() > 0.05, "'%s' existe y dura algo" % sound_id)


func test_events_have_their_sounds() -> void:
	for sound_id: StringName in [&"arrow", &"hit", &"death", &"castle", &"boing", &"rain", &"thunder", &"horn", &"pop", &"laugh", &"unlock", &"win", &"lose"]:
		assert_true(Sfx.SOUNDS.has(sound_id), "sonido '%s' registrado" % sound_id)


func test_minimum_interval_limits_spam() -> void:
	Sfx.play(&"hit")
	var first: int = Sfx._last_played[&"hit"]
	for _repeat: int in 20:
		Sfx.play(&"hit")
	assert_eq(Sfx._last_played[&"hit"], first, "20 golpes seguidos no reinician el sonido")


func test_muting_and_suppressing() -> void:
	UIFeedback.sound_enabled = false
	Sfx.play(&"pop")
	assert_false(Sfx._last_played.has(&"pop"), "silenciado: no suena")
	UIFeedback.sound_enabled = true
	GameManager.suppress_effects = true
	Sfx.play(&"pop")
	assert_false(Sfx._last_played.has(&"pop"), "sin efectos (repeticiones/simulador): no suena")
	GameManager.suppress_effects = false
	Sfx.play(&"pop")
	assert_true(Sfx._last_played.has(&"pop"), "con todo activo, suena")
