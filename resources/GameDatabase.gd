class_name GameDatabase
extends Resource
## Catálogo único de datos del juego. Los comandos y la red se refieren a los
## datos por id (StringName); la base de datos resuelve id → Resource.
## Llamar a build_index() tras cargar.

@export var rules: GameRules
@export var units: Array[UnitData] = []
@export var structures: Array[StructureData] = []
@export var buffs: Array[BuffData] = []
@export var cards: Array[CardData] = []

var _units_by_id: Dictionary[StringName, UnitData] = {}
var _structures_by_id: Dictionary[StringName, StructureData] = {}
var _buffs_by_id: Dictionary[StringName, BuffData] = {}
var _cards_by_id: Dictionary[StringName, CardData] = {}


func build_index() -> void:
	_units_by_id.clear()
	_structures_by_id.clear()
	_buffs_by_id.clear()
	_cards_by_id.clear()
	for unit: UnitData in units:
		if unit != null:
			_units_by_id[unit.id] = unit
	for structure: StructureData in structures:
		if structure != null:
			_structures_by_id[structure.id] = structure
	for buff: BuffData in buffs:
		if buff != null:
			_buffs_by_id[buff.id] = buff
	for card: CardData in cards:
		if card != null:
			_cards_by_id[card.id] = card


func get_unit(unit_id: StringName) -> UnitData:
	return _units_by_id.get(unit_id, null)


func get_structure(structure_id: StringName) -> StructureData:
	return _structures_by_id.get(structure_id, null)


func get_buff(buff_id: StringName) -> BuffData:
	return _buffs_by_id.get(buff_id, null)


func get_card(card_id: StringName) -> CardData:
	return _cards_by_id.get(card_id, null)


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if rules == null:
		errors.append("GameDatabase: falta rules")
	else:
		errors.append_array(rules.get_validation_errors())

	var seen_ids: Dictionary[StringName, bool] = {}
	for unit: UnitData in units:
		if unit == null:
			errors.append("GameDatabase: entrada nula en units")
			continue
		_check_duplicate(errors, seen_ids, unit.id)
		errors.append_array(unit.get_validation_errors())
	for structure: StructureData in structures:
		if structure == null:
			errors.append("GameDatabase: entrada nula en structures")
			continue
		_check_duplicate(errors, seen_ids, structure.id)
		errors.append_array(structure.get_validation_errors())
		if rules != null and structure.max_level != rules.max_structure_level:
			errors.append("StructureData '%s': max_level distinto de rules.max_structure_level" % structure.id)
		if structure.spawn_unit != null and not units.has(structure.spawn_unit):
			errors.append("StructureData '%s': spawn_unit no está en units" % structure.id)
	for buff: BuffData in buffs:
		if buff == null:
			errors.append("GameDatabase: entrada nula en buffs")
			continue
		_check_duplicate(errors, seen_ids, buff.id)
		errors.append_array(buff.get_validation_errors())
	for card: CardData in cards:
		if card == null:
			errors.append("GameDatabase: entrada nula en cards")
			continue
		_check_duplicate(errors, seen_ids, card.id)
		errors.append_array(card.get_validation_errors())
		if card.structure != null and not structures.has(card.structure):
			errors.append("CardData '%s': structure no está en structures" % card.id)
		if card.buff != null and not buffs.has(card.buff):
			errors.append("CardData '%s': buff no está en buffs" % card.id)
		if card.unit != null and not units.has(card.unit):
			errors.append("CardData '%s': unit no está en units" % card.id)
	if rules != null and cards.size() < rules.shop_offer_size:
		errors.append("GameDatabase: hay menos cartas que shop_offer_size")
	return errors


## Los ids son únicos en toda la base de datos, no solo por categoría,
## para que un id en un comando de red nunca sea ambiguo.
func _check_duplicate(errors: PackedStringArray, seen_ids: Dictionary[StringName, bool], entry_id: StringName) -> void:
	if seen_ids.has(entry_id):
		errors.append("GameDatabase: id duplicado '%s'" % entry_id)
	seen_ids[entry_id] = true
