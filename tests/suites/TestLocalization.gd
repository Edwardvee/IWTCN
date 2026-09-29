extends TestSuite
## Textos en español e inglés: no falta ninguna clave, los %d/%s coinciden y el
## cambio de idioma funciona.

const SCAN_ROOTS: PackedStringArray = ["res://autoload", "res://entities", "res://resources", "res://scenes", "res://systems", "res://ui"]
const SKIPPED_FILES: PackedStringArray = ["res://systems/i18n/TranslationTables.gd"]
## ui/DebugPanel.gd es solo de desarrollo y queda en español.
const CARD_TYPE_KEYS: PackedStringArray = ["ESTRUCTURA", "UNIDADES", "MEJORA"]


func after_all() -> void:
	Localization.set_language("es", false)


func before_each() -> void:
	Localization.set_language("es", false)


## Todos los literales de tr("…"), Reason.make("…") y TranslationServer.translate("…").
func _collect_source_keys() -> Dictionary:
	var keys: Dictionary = {}
	var regex: RegEx = RegEx.new()
	regex.compile("(?:\\btr|Reason\\.make|TranslationServer\\.translate)\\(\"((?:[^\"\\\\]|\\\\.)*)\"")
	var pending: PackedStringArray = SCAN_ROOTS.duplicate()
	while not pending.is_empty():
		var directory: String = pending[pending.size() - 1]
		pending.resize(pending.size() - 1)
		for sub_directory: String in DirAccess.get_directories_at(directory):
			pending.append("%s/%s" % [directory, sub_directory])
		for file_name: String in DirAccess.get_files_at(directory):
			var path: String = "%s/%s" % [directory, file_name]
			if file_name.get_extension() != "gd" or SKIPPED_FILES.has(path) or path.ends_with("DebugPanel.gd"):
				continue
			for match: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
				keys[match.get_string(1).c_unescape()] = path
	return keys


func _specifiers(text: String) -> PackedStringArray:
	var regex: RegEx = RegEx.new()
	regex.compile("%[-+0#]*\\d*(?:\\.\\d+)?[sdfx]")
	var found: PackedStringArray = PackedStringArray()
	for match: RegExMatch in regex.search_all(text.replace("%%", "")):
		found.append(match.get_string().substr(match.get_string().length() - 1))
	return found


func test_every_text_in_code_has_an_english_version() -> void:
	var keys: Dictionary = _collect_source_keys()
	assert_true(keys.size() > 80, "se encuentran los textos del código (%d)" % keys.size())
	var missing: PackedStringArray = PackedStringArray()
	for key: String in keys:
		if not TranslationTables.EN.has(key):
			missing.append("%s (%s)" % [key.replace("\n", "\\n"), keys[key]])
	assert_true(missing.is_empty(), "faltan en TranslationTables.EN: %s" % " | ".join(missing))


func test_card_type_labels_are_translated() -> void:
	for key: String in CARD_TYPE_KEYS:
		assert_true(TranslationTables.EN.has(key), "tipo de carta '%s' traducido" % key)


func test_format_specifiers_match_between_languages() -> void:
	for table: Dictionary in [TranslationTables.EN, TranslationTables.ES]:
		for key: String in table:
			assert_eq(_specifiers(str(table[key])), _specifiers(key), "mismos %%d/%%s en '%s'" % key.replace("\n", "\\n"))


func test_every_spanish_override_also_exists_in_english() -> void:
	# Si el inglés no tiene la clave, el TranslationServer cae al español.
	for key: String in TranslationTables.ES:
		assert_true(TranslationTables.EN.has(key), "'%s' está en EN además de en ES" % key)


func test_game_content_has_both_languages() -> void:
	var database: GameDatabase = GameManager.database
	var strings: Array[String] = []
	for card: CardData in database.cards:
		strings.append(card.display_name)
		strings.append(card.description)
	for structure: StructureData in database.structures:
		strings.append(structure.display_name)
		if structure.short_label != "":
			strings.append(structure.short_label)
	for unit: UnitData in database.units:
		strings.append(unit.display_name)
	for buff: BuffData in database.buffs:
		strings.append(buff.display_name)
	for text: String in strings:
		assert_true(TranslationTables.EN.has(text) or TranslationTables.ES.has(text), "el contenido '%s' tiene traducción" % text)


func test_switching_language_changes_text() -> void:
	assert_eq(tr("Slot ocupado"), "Slot ocupado", "español: la clave")
	assert_eq(tr("Farm"), "Granja", "español: nombre de contenido en inglés → español")
	Localization.set_language("en", false)
	assert_eq(tr("Slot ocupado"), "Slot is occupied", "inglés")
	assert_eq(tr("Farm"), "Farm", "inglés: el nombre no cambia")
	assert_eq(tr("Despliega Soldiers en el carril. Cuántos salen depende del nivel de tu Soldier Barracks (3 a 5)."), "Deploys Soldiers in the lane. How many depends on your Soldier Barracks level (3 to 5).", "descripción en inglés")
	Localization.set_language("es", false)
	assert_eq(tr("Despliega Soldiers en el carril. Cuántos salen depende del nivel de tu Soldier Barracks (3 a 5)."), "Despliega Soldados en el carril. Cuántos salen depende del nivel de tu Cuartel de soldados (3 a 5).", "descripción en español")


func test_unknown_language_falls_back_to_english() -> void:
	Localization.set_language("fr", false)
	assert_eq(Localization.current_language, "en", "idioma no soportado → inglés")


func test_toggle_language() -> void:
	Localization.toggle_language()
	var after_first: String = Localization.current_language
	Localization.toggle_language()
	assert_true(after_first != "es" and Localization.current_language == "es", "alterna es ↔ en")
	assert_eq(Localization.get_other_language_name(), "English", "ofrece el otro idioma")


func test_rejection_reasons_are_translated_where_they_are_read() -> void:
	assert_eq(Reason.make("Slot ocupado"), "Slot ocupado", "sin argumentos el motivo es la clave (compatibilidad)")
	var with_arguments: String = Reason.make("Oro insuficiente (%d)", [45])
	assert_eq(Reason.text(with_arguments), "Oro insuficiente (45)", "español con argumentos")
	Localization.set_language("en", false)
	assert_eq(Reason.text(with_arguments), "Not enough gold (45)", "el mismo motivo se lee en inglés")
	assert_eq(Reason.text(Reason.make("Máximo de %s alcanzado (Lv%d)", ["Farm", 5])), "Maximum Farm reached (Lv5)", "argumentos de texto y número")
	Localization.set_language("es", false)
	assert_eq(Reason.text(Reason.make("Máximo de %s alcanzado (Lv%d)", ["Farm", 5])), "Máximo de Granja alcanzado (Lv5)", "los nombres de contenido se traducen")


func test_real_rejection_message_is_localized_end_to_end() -> void:
	# Un motivo real del juego (Grid) pasa por Reason y se lee en ambos idiomas.
	var grid: GridManager = GridManager.new()
	get_root().add_child(grid)
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 1)
	var reason: String = grid.can_build(0, GameManager.database.get_structure(&"farm"))
	assert_eq(Reason.text(reason), "Plot bloqueado", "español")
	Localization.set_language("en", false)
	assert_eq(Reason.text(reason), "Plot is locked", "inglés")
	Localization.set_language("es", false)
	grid.queue_free()
