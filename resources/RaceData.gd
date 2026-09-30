class_name RaceData
extends Resource
## Una raza jugable. TODO lo que la distingue vive en su archivo
## data/races/<raza>.tres (Inspector o texto): multiplicadores de vida, daño,
## velocidad y precios, ajustes por unidad concreta, nombres y arte.
##
## Los multiplicadores se aplican encima de las unidades, estructuras y cartas
## base (data/units, data/structures, data/cards), que son iguales para todas las
## razas: 1.0 = sin cambio. Los humanos (human.tres) son la raza base.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Color de la raza en menús e interfaz.
@export var accent_color: Color = Color.WHITE

@export_group("Economy")
## Precio de las cartas de cada tipo (0.8 = un 20 % más baratas).
@export var unit_card_cost_multiplier: float = 1.0
@export var structure_card_cost_multiplier: float = 1.0
@export var buff_card_cost_multiplier: float = 1.0
## Ingresos por segundo (oro base y granjas).
@export var income_multiplier: float = 1.0

@export_group("Units")
## Se aplican a TODAS las unidades de la raza.
@export var hp_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
## Ritmo de ataque (1.3 = ataca un 30 % más rápido).
@export var attack_speed_multiplier: float = 1.0
@export var move_speed_multiplier: float = 1.0
@export var attack_range_multiplier: float = 1.0
## Ajustes extra o arte por unidad concreta (soldier, archer, priest, tank).
@export var unit_overrides: Array[RaceUnitOverride] = []

@export_group("Structures")
## Velocidad de producción de cuarteles e iglesias (0.9 = ciclos un 10 % más cortos).
@export var production_interval_multiplier: float = 1.0
@export var structure_overrides: Array[RaceStructureOverride] = []

@export_group("Castle")
@export var castle_hp_multiplier: float = 1.0
@export var castle_texture: Texture2D
@export var castle_team_texture: Texture2D

@export_group("Interface")
## Voz de la raza que suena al gritar "I WANT THAT CASTLE NOW!" al empezar la partida.
@export var intro_sound: AudioStream
## Fondo de la barra de la tienda (madera de la raza). Vacío = el de siempre.
@export var shop_panel_texture: Texture2D

@export_group("Names")
## Nombre mostrado por carta: {"card_soldiers": "Goblin Soldiers", …}. Las cartas
## sin entrada usan su nombre normal.
@export var card_names: Dictionary = {}


func get_unit_override(unit_id: StringName) -> RaceUnitOverride:
	for unit_override: RaceUnitOverride in unit_overrides:
		if unit_override != null and unit_override.unit_id == unit_id:
			return unit_override
	return null


func get_structure_override(structure_id: StringName) -> RaceStructureOverride:
	for structure_override: RaceStructureOverride in structure_overrides:
		if structure_override != null and structure_override.structure_id == structure_id:
			return structure_override
	return null


## SpriteFrames de la unidad para esta raza (o los de la unidad base).
func get_unit_frames(unit: UnitData) -> SpriteFrames:
	var unit_override: RaceUnitOverride = get_unit_override(unit.art_unit_id if unit.art_unit_id != &"" else unit.id)
	if unit_override != null and unit_override.sprite_frames != null:
		return unit_override.sprite_frames
	return unit.sprite_frames


func get_unit_sprite_scale(unit: UnitData) -> Vector2:
	var unit_override: RaceUnitOverride = get_unit_override(unit.art_unit_id if unit.art_unit_id != &"" else unit.id)
	if unit_override != null and unit_override.sprite_scale != Vector2.ZERO:
		return unit.sprite_scale * (unit_override.sprite_scale / Vector2(0.5, 0.5)) if unit.art_unit_id != &"" else unit_override.sprite_scale
	return unit.sprite_scale


func get_structure_texture(structure: StructureData) -> Texture2D:
	var structure_override: RaceStructureOverride = get_structure_override(structure.id)
	if structure_override != null and structure_override.texture != null:
		return structure_override.texture
	return structure.texture


func get_structure_team_texture(structure: StructureData) -> Texture2D:
	var structure_override: RaceStructureOverride = get_structure_override(structure.id)
	if structure_override != null and structure_override.team_texture != null:
		return structure_override.team_texture
	return structure.team_texture


## Nombre de una carta para esta raza.
func get_card_name(card: CardData) -> String:
	return str(card_names.get(str(card.id), card.display_name))


## Multiplicador de precio según el tipo de carta.
func get_card_cost_multiplier(card: CardData) -> float:
	match card.card_type:
		CardData.CardType.STRUCTURE:
			return structure_card_cost_multiplier
		CardData.CardType.DIRECT_UNIT:
			return unit_card_cost_multiplier
		CardData.CardType.SABOTAGE:
			return 1.0
	return buff_card_cost_multiplier


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var label: String = "RaceData '%s'" % id
	if id == &"":
		errors.append("%s: id vacío" % label)
	for field: String in ["unit_card_cost_multiplier", "structure_card_cost_multiplier", "buff_card_cost_multiplier", "income_multiplier", "hp_multiplier", "damage_multiplier", "attack_speed_multiplier", "move_speed_multiplier", "attack_range_multiplier", "production_interval_multiplier", "castle_hp_multiplier"]:
		if float(get(field)) <= 0.0:
			errors.append("%s: %s debe ser > 0" % [label, field])
	for unit_override: RaceUnitOverride in unit_overrides:
		if unit_override == null:
			errors.append("%s: entrada nula en unit_overrides" % label)
		else:
			errors.append_array(unit_override.get_validation_errors(label))
	return errors
