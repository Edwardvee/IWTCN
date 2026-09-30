class_name Sabotage
extends RefCounted
## Cartas de sabotaje: se compran en la tienda como cualquier carta pero su efecto cae sobre
## el RIVAL. No necesitan objetivo: el elemento afectado (estructura, hueco de la tienda) se
## elige al azar con el generador de combate de la partida, así que es determinista.
##   FREEZE_STRUCTURE  congela una estructura rival sabotage_value segundos (no produce ni dispara)
##   BLOCK_SHOP_SLOT   bloquea un hueco de su tienda sabotage_value segundos
##   FORCE_REROLL      renueva su tienda al instante (sin coste para él)
##   STEAL_GOLD        le roba hasta sabotage_value de oro
##   SILENCE_SPELLS    sus hechizos de castillo no se pueden lanzar durante sabotage_value segundos
## La autoridad llama a can_apply (validación) y a apply (efecto) desde PlayCardCommand.


## "" si la carta puede lanzarse ahora; si no, el motivo del rechazo.
static func can_apply(card: CardData, attacker_id: int, draft: DraftManager) -> String:
	var target_state: PlayerState = GameManager.get_player_state(MatchTypes.opponent_of(attacker_id))
	if target_state == null:
		return Reason.make("Jugador inválido")
	var now: float = GameManager.match_state.match_time
	match card.sabotage_kind:
		CardData.SabotageKind.FREEZE_STRUCTURE:
			if _freezable_slots(target_state, now).is_empty():
				return Reason.make("El rival no tiene estructuras que congelar")
		CardData.SabotageKind.BLOCK_SHOP_SLOT:
			if target_state.shop.offer.is_empty():
				return Reason.make("La tienda del rival está vacía")
		CardData.SabotageKind.STEAL_GOLD:
			if target_state.gold <= 0:
				return Reason.make("El rival no tiene oro que robar")
		CardData.SabotageKind.FORCE_REROLL:
			if draft == null:
				return Reason.make("Tienda no disponible")
	return ""


## Aplica el efecto sobre el rival (ya validado y pagado). false si no pudo.
static func apply(card: CardData, attacker_id: int, draft: DraftManager) -> bool:
	var target_id: int = MatchTypes.opponent_of(attacker_id)
	var target_state: PlayerState = GameManager.get_player_state(target_id)
	if target_state == null:
		return false
	var now: float = GameManager.match_state.match_time
	var rng: RandomNumberGenerator = GameManager.match_state.random.get_stream(MatchRandom.STREAM_COMBAT, target_id)
	var detail: String = ""
	match card.sabotage_kind:
		CardData.SabotageKind.FREEZE_STRUCTURE:
			var slots: PackedInt32Array = _freezable_slots(target_state, now)
			if slots.is_empty():
				return false
			var slot_index: int = slots[rng.randi_range(0, slots.size() - 1)]
			target_state.frozen_slots[slot_index] = now + card.sabotage_value
			var structure: StructureData = GameManager.database.get_structure(target_state.grid.get_slot(slot_index).structure_id)
			detail = structure.display_name if structure != null else ""
		CardData.SabotageKind.BLOCK_SHOP_SLOT:
			if target_state.shop.offer.is_empty():
				return false
			target_state.shop.block(rng.randi_range(0, target_state.shop.offer.size() - 1), now + card.sabotage_value)
		CardData.SabotageKind.FORCE_REROLL:
			if draft == null:
				return false
			draft.refresh_offer(target_id)
		CardData.SabotageKind.STEAL_GOLD:
			var amount: int = mini(roundi(card.sabotage_value), target_state.gold)
			if amount <= 0 or not EconomyManager.spend_gold(target_id, amount):
				return false
			EconomyManager.add_gold(attacker_id, amount)
			detail = str(amount)
		CardData.SabotageKind.SILENCE_SPELLS:
			for spell: SpellData in GameManager.database.spells:
				target_state.set_spell_ready_at(spell.id, maxf(target_state.get_spell_ready_at(spell.id), now + card.sabotage_value))
	EventBus.sabotaje_aplicado.emit(attacker_id, target_id, card.sabotage_kind, detail)
	return true


## Estructuras del jugador que se pueden congelar ahora (con algo dentro y no ya congeladas).
static func _freezable_slots(player_state: PlayerState, now: float) -> PackedInt32Array:
	var slots: PackedInt32Array = PackedInt32Array()
	for slot_index: int in player_state.grid.get_occupied_slots():
		if not player_state.is_slot_frozen(slot_index, now):
			slots.append(slot_index)
	return slots
