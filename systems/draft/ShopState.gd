class_name ShopState
extends RefCounted
## Estado lógico de la tienda de un jugador. Solo DraftManager lo modifica.

## Ids de las cartas ofrecidas, por posición (0..shop_offer_size-1).
var offer: Array[StringName] = []
var reroll_cost: int = 0
## Segundos acumulados hacia la próxima rebaja del coste de reroll.
var reroll_decay_timer: float = 0.0
var reroll_count: int = 0


func _init(base_reroll_cost: int) -> void:
	reroll_cost = base_reroll_cost


func to_dict() -> Dictionary:
	return {
		"offer": offer.duplicate(),
		"reroll_cost": reroll_cost,
		"reroll_decay_timer": reroll_decay_timer,
		"reroll_count": reroll_count,
	}
