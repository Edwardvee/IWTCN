class_name AIDifficulty
extends RefCounted
## Niveles de dificultad de la IA rival. Ninguno hace trampa: la IA sigue usando
## las mismas reglas, oro y comandos que un jugador. Cambia CÓMO juega:
##   EASY:   reacciona despacio, a veces no hace nada, a veces compra una carta al
##           azar y puntúa con mucho ruido. Ingresa un 25 % menos.
##   NORMAL: la IA de siempre (estilo equilibrado), sin ventajas.
##   HARD:   reacciona el doble de rápido, casi no se equivoca y presiona pronto
##           (RuleBasedStrategy.PROFILE_HARD). Ingresa un 30 % más.
## Las ventajas de ingresos son declaradas (ver docs) y solo afectan a la IA.
## Ajustes y su justificación en tools/BalanceSim (perfiles easy / normal / hard).

enum Level { EASY, NORMAL, HARD }

const DEFAULT_LEVEL: Level = Level.NORMAL
## Multiplicadores de ingresos de la IA por nivel.
const EASY_INCOME: float = 0.85
const HARD_INCOME: float = 1.15
const SETTINGS_SECTION: String = "game"
const SETTINGS_KEY: String = "ai_difficulty"

## Nombre estable de cada nivel (settings, simulador, argumentos).
const NAMES: Dictionary = {
	Level.EASY: &"easy",
	Level.NORMAL: &"normal",
	Level.HARD: &"hard",
}


## Nombre traducido para mostrar al jugador.
static func display_name(level: Level) -> String:
	match level:
		Level.EASY:
			return TranslationServer.translate("Fácil")
		Level.HARD:
			return TranslationServer.translate("Difícil")
	return TranslationServer.translate("Normal")


## Nivel a partir de su nombre estable; -1 si no existe.
static func level_from_name(level_name: StringName) -> int:
	for level: int in NAMES:
		if NAMES[level] == level_name:
			return level
	return -1


## Configura un AIController para el nivel: tiempo de reacción y estrategia.
static func apply(ai: AIController, level: Level) -> void:
	match level:
		Level.EASY:
			ai.think_interval = 3.0
			ai.spell_use_chance = 0.5
			ai.income_multiplier = EASY_INCOME
			ai.strategy = RuleBasedStrategy.create(RuleBasedStrategy.PROFILE_EASY)
		Level.HARD:
			ai.think_interval = 0.5
			ai.spell_use_chance = 1.0
			ai.income_multiplier = HARD_INCOME
			ai.strategy = RuleBasedStrategy.create(RuleBasedStrategy.PROFILE_HARD)
		_:
			ai.think_interval = 1.0
			ai.spell_use_chance = 1.0
			ai.income_multiplier = 1.0
			ai.strategy = RuleBasedStrategy.create(RuleBasedStrategy.PROFILE_BALANCED)


## Como apply pero por nombre, aceptando también los perfiles de estilo
## (economy, rush…) con la reacción normal. El simulador lo usa.
static func apply_by_name(ai: AIController, profile_name: StringName) -> void:
	var level: int = level_from_name(profile_name)
	if level >= 0:
		apply(ai, level as Level)
		return
	ai.think_interval = 1.0
	ai.spell_use_chance = 1.0
	ai.income_multiplier = 1.0
	ai.strategy = RuleBasedStrategy.create(profile_name)


static func next_level(level: Level) -> Level:
	return ((level + 1) % Level.size()) as Level


# --- Preferencia guardada ---------------------------------------------------------

static func load_saved() -> Level:
	var config: ConfigFile = ConfigFile.new()
	if config.load(Localization.SETTINGS_PATH) != OK:
		return DEFAULT_LEVEL
	var saved: int = level_from_name(StringName(str(config.get_value(SETTINGS_SECTION, SETTINGS_KEY, ""))))
	return saved as Level if saved >= 0 else DEFAULT_LEVEL


static func save(level: Level) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(Localization.SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, str(NAMES[level]))
	config.save(Localization.SETTINGS_PATH)
