extends Node
## Idioma del juego (español / inglés).
##
## Registra las traducciones de TranslationTables en el TranslationServer, elige
## el idioma (el guardado por el jugador o, si no hay, el del sistema) y lo
## guarda en user://settings.cfg. Todo texto visible pasa por tr(); los Control
## (Label, Button…) además traducen solos el texto que reciben.
## Por defecto se usa inglés salvo que el sistema esté en español.

signal language_changed(code: String)

const SETTINGS_PATH: String = "user://settings.cfg"
const LANGUAGES: Array[String] = ["es", "en"]
const LANGUAGE_NAMES: Dictionary = {"es": "Español", "en": "English"}

var current_language: String = "en"


func _ready() -> void:
	_register_translations()
	set_language(_load_saved_language(), false)


## Cambia el idioma. persist = guardarlo para la próxima vez.
func set_language(code: String, persist: bool = true) -> void:
	if not LANGUAGES.has(code):
		code = "en"
	current_language = code
	TranslationServer.set_locale(code)
	if persist:
		_save_language(code)
	language_changed.emit(code)


## Alterna entre los idiomas disponibles (botón del menú).
func toggle_language() -> void:
	var next_index: int = (LANGUAGES.find(current_language) + 1) % LANGUAGES.size()
	set_language(LANGUAGES[next_index])


## Nombre del idioma al que cambiaría toggle_language(), en ese idioma.
func get_other_language_name() -> String:
	var next_index: int = (LANGUAGES.find(current_language) + 1) % LANGUAGES.size()
	return LANGUAGE_NAMES[LANGUAGES[next_index]]


func _register_translations() -> void:
	for pair: Array in [["en", TranslationTables.EN], ["es", TranslationTables.ES]]:
		var translation: Translation = Translation.new()
		translation.locale = pair[0]
		var messages: Dictionary = pair[1]
		for key: String in messages:
			translation.add_message(key, messages[key])
		TranslationServer.add_translation(translation)


func _load_saved_language() -> String:
	# Atajo de desarrollo: `-- --lang=en` fuerza el idioma sin tocar lo guardado.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lang=") and LANGUAGES.has(argument.trim_prefix("--lang=")):
			return argument.trim_prefix("--lang=")
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved: String = str(config.get_value("general", "language", ""))
		if LANGUAGES.has(saved):
			return saved
	return "es" if OS.get_locale_language() == "es" else "en"


func _save_language(code: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("general", "language", code)
	config.save(SETTINGS_PATH)
