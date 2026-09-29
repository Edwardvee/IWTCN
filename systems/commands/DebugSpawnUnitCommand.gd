class_name DebugSpawnUnitCommand
extends GameCommand
## Solo panel debug: hace aparecer unidades en el spawn de un jugador.
## Las cartas de unidad (DIRECT_UNIT) usarán DeployUnitCommand en la Fase 9.

const MAX_COUNT: int = 10

var unit_id: StringName = &""
var count: int = 1


func _init(p_player_id: int, p_unit_id: StringName, p_count: int) -> void:
	player_id = p_player_id
	unit_id = p_unit_id
	count = p_count
	source = GameCommand.Source.DEBUG


func get_type() -> StringName:
	return &"debug_spawn_unit"


func validate(processor: CommandProcessor) -> String:
	if source != GameCommand.Source.DEBUG:
		return Reason.make("Comando exclusivo de debug")
	if processor.get_lane() == null:
		return Reason.make("Carril no encontrado")
	if processor.get_database().get_unit(unit_id) == null:
		return Reason.make("Unidad desconocida")
	if count < 1 or count > MAX_COUNT:
		return Reason.make("Cantidad inválida")
	return ""


func apply(processor: CommandProcessor) -> bool:
	var unit_data: UnitData = processor.get_database().get_unit(unit_id)
	return processor.get_lane().spawn_group(unit_data, player_id, count).size() == count
