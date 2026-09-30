class_name AudioSettings
extends RefCounted
## Volumen general del juego, guardado en user://settings.cfg (0 = silencio, 1 = máximo).

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "audio"
const KEY: String = "volume"
const DEFAULT_VOLUME: float = 1.0


static func load_saved() -> float:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_VOLUME
	return clampf(float(config.get_value(SECTION, KEY, DEFAULT_VOLUME)), 0.0, 1.0)


static func save(volume: float) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, KEY, clampf(volume, 0.0, 1.0))
	config.save(SETTINGS_PATH)


## Aplica el volumen al bus principal (0 = silenciado del todo).
static func apply(volume: float) -> void:
	var clamped: float = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(0, clamped <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(clamped, 0.001)))
