class_name CastSpellCommand
extends GameCommand
## Lanzar una habilidad de castillo en un punto de TU mitad del carril. La autoridad
## comprueba que exista, que su tiempo de espera haya pasado y que el punto sea tuyo;
## la espera se comparte entre todos los hechizos; el rayo además necesita un enemigo cerca del punto (si no, no gasta el hechizo).

var spell_id: StringName = &""
var position: Vector2 = Vector2.ZERO


func _init(p_player_id: int, p_spell_id: StringName, p_position: Vector2, p_source: GameCommand.Source = GameCommand.Source.LOCAL_PLAYER) -> void:
	player_id = p_player_id
	spell_id = p_spell_id
	position = p_position
	source = p_source


func get_type() -> StringName:
	return &"cast_spell"


func validate(processor: CommandProcessor) -> String:
	var spell: SpellData = processor.get_database().get_spell(spell_id)
	if spell == null:
		return Reason.make("Hechizo desconocido")
	var lane: LaneManager = processor.get_lane()
	if lane == null:
		return Reason.make("Carril no encontrado")
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	if player_state == null:
		return Reason.make("Jugador inválido")
	if GameManager.match_state.match_time < player_state.get_spell_ready_at(spell_id) - Spells.COOLDOWN_TOLERANCE:
		return Reason.make("Hechizo en enfriamiento")
	if not lane.is_valid_deploy_position(player_id, position):
		return Reason.make("Lanza el hechizo en tu mitad del carril")
	if spell.kind == SpellData.Kind.LIGHTNING and lane.find_unit_near(MatchTypes.opponent_of(player_id), position, spell.radius) == null:
		return Reason.make("No hay enemigos donde apuntas")
	return ""


func apply(processor: CommandProcessor) -> bool:
	var spell: SpellData = processor.get_database().get_spell(spell_id)
	var lane: LaneManager = processor.get_lane()
	var player_state: PlayerState = GameManager.get_player_state(player_id)
	var effect_position: Vector2 = position
	match spell.kind:
		SpellData.Kind.ARROW_RAIN:
			lane.start_arrow_rain(player_id, position, spell.radius, spell.damage, spell.waves, spell.wave_interval)
		SpellData.Kind.LIGHTNING:
			var victim: UnitBase = lane.find_unit_near(MatchTypes.opponent_of(player_id), position, spell.radius)
			if victim == null:
				return false
			effect_position = victim.global_position
			victim.receive_damage(victim.max_hp + victim.current_hp + 1.0, 0, true)
		SpellData.Kind.MILITIA:
			lane.spawn_group_at(spell.unit, player_id, spell.unit_count, position, true)
	# La espera es compartida: lanzar un hechizo deja también en enfriamiento a los demás.
	var ready_at: float = GameManager.match_state.match_time + spell.cooldown
	for other: SpellData in processor.get_database().spells:
		player_state.set_spell_ready_at(other.id, maxf(player_state.get_spell_ready_at(other.id), ready_at))
	player_state.spell_id = spell_id
	player_state.spell_position = effect_position
	player_state.spell_seq += 1
	EventBus.hechizo_lanzado.emit(player_id, spell_id, effect_position)
	return true
