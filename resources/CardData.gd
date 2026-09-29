class_name CardData
extends Resource
## Definición data-driven de una carta de la tienda.
##
## La UI y la tienda solo necesitan: tipo, coste, peso, destino de soltado
## y requisitos de desbloqueo. El efecto lo resuelve el sistema de cartas
## a partir del recurso referenciado (structure / buff / unit).

enum CardType { STRUCTURE, GLOBAL_BUFF, DIRECT_UNIT }
## Dónde se suelta la carta al arrastrarla desde la tienda.
enum DropTarget { PLOT, LANE, ANYWHERE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var card_type: CardType = CardType.STRUCTURE
@export var cost: int = 0
## Peso relativo de aparición en la tienda (mayor = más frecuente).
@export var shop_weight: int = 10

@export_group("Effect")
@export var structure: StructureData
@export var buff: BuffData
@export var unit: UnitData
## Unidades por carta. Si unit_count_by_level no está vacío se usa esa tabla.
@export var unit_count: int = 1
## Estructura cuyo nivel decide cuántas unidades salen (p. ej. soldier_barracks)
## y unidades por nivel 0..5 de esa estructura.
@export var unit_count_structure: StringName = &""
@export var unit_count_by_level: PackedInt32Array = PackedInt32Array()

@export_group("Unlock")
## Si no está vacío, la carta solo aparece cuando el jugador tiene al menos
## `required_structure_count` niveles de estructuras con esta etiqueta.
@export var required_structure_tag: StringName = &""
@export var required_structure_count: int = 0

@export_group("Visual")
@export var icon: Texture2D
@export var color: Color = Color.WHITE


## Cuántas unidades despliega esta carta para `player_id` ahora mismo (depende
## del nivel de su cuartel si la carta tiene tabla).
func get_unit_count_for(player_id: int) -> int:
	if unit_count_by_level.is_empty() or unit_count_structure == &"":
		return unit_count
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	var level: int = player_state.grid.count_structures(unit_count_structure) if player_state != null else 0
	return unit_count_by_level[clampi(level, 0, unit_count_by_level.size() - 1)]


func get_drop_target() -> DropTarget:
	match card_type:
		CardType.STRUCTURE:
			return DropTarget.PLOT
		CardType.DIRECT_UNIT:
			return DropTarget.LANE
	return DropTarget.ANYWHERE


func has_unlock_requirement() -> bool:
	return required_structure_tag != &"" and required_structure_count > 0


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var label: String = "CardData '%s'" % id
	if id == &"":
		errors.append("%s: id vacío" % label)
	if cost < 0:
		errors.append("%s: cost negativo" % label)
	if shop_weight <= 0:
		errors.append("%s: shop_weight debe ser > 0" % label)
	match card_type:
		CardType.STRUCTURE:
			if structure == null:
				errors.append("%s: STRUCTURE sin structure" % label)
		CardType.GLOBAL_BUFF:
			if buff == null:
				errors.append("%s: GLOBAL_BUFF sin buff" % label)
		CardType.DIRECT_UNIT:
			if unit == null:
				errors.append("%s: DIRECT_UNIT sin unit" % label)
			if unit_count < 1:
				errors.append("%s: unit_count debe ser >= 1" % label)
			for count: int in unit_count_by_level:
				if count < 1:
					errors.append("%s: unit_count_by_level contiene valores < 1" % label)
					break
	if required_structure_tag != &"" and required_structure_count <= 0:
		errors.append("%s: required_structure_tag sin required_structure_count" % label)
	return errors
