class_name MindConversion
extends RefCounted
## Reglas de la conversión mental (Priest de una Church de nivel suficiente).
## Todo se calcula a partir del estado de partida y del stream de combate de
## MatchRandom: misma semilla → mismas conversiones.


## Estructura que habilita la conversión para las unidades `unit_data` del
## jugador (p. ej. Church con nivel ≥ conversion_min_level), o null.
static func get_active_source(player_id: int, unit_data: UnitData) -> StructureData:
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null or GameManager.database == null or unit_data == null:
		return null
	for structure: StructureData in GameManager.database.structures:
		if structure.kind != StructureData.Kind.SPAWNER or structure.spawn_unit != unit_data:
			continue
		var count: int = player_state.grid.count_structures(structure.id)
		if count > 0 and structure.enables_conversion(structure.clamp_level(count)):
			return structure
	return null


static func roll(rng: RandomNumberGenerator, chance: float) -> bool:
	return rng.randf() < chance


static func get_rng() -> RandomNumberGenerator:
	return GameManager.match_state.random.get_stream(MatchRandom.STREAM_COMBAT)
