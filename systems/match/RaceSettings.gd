class_name RaceSettings
extends RefCounted
## Raza elegida por el jugador, guardada en user://settings.cfg.

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "game"
const KEY: String = "player_race"
const DEFAULT_RACE: StringName = &"human"


static func load_saved() -> StringName:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_RACE
	var saved: String = str(config.get_value(SECTION, KEY, ""))
	return StringName(saved) if saved != "" else DEFAULT_RACE


static func save(race_id: StringName) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, KEY, str(race_id))
	config.save(SETTINGS_PATH)
