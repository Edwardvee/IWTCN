class_name GameRules
extends Resource
## Reglas numéricas globales de la partida (economía, castillo, tienda,
## venta y plots). Todas editables desde el Inspector en data/game_rules.tres.

const PLOT_COUNT: int = 6
const SLOTS_PER_PLOT: int = 4

@export_group("Economy")
@export var starting_gold: int = 20
@export var base_income_amount: int = 5
@export var base_income_interval: float = 3.0

@export_group("Castle")
@export var castle_max_hp: float = 3000.0

@export_group("Shop")
@export var shop_offer_size: int = 3
@export var reroll_base_cost: int = 10
## Cuánto sube el coste del reroll cada vez que se usa.
@export var reroll_cost_increment: int = 3
## Cuánto baja el coste del reroll cada `reroll_decay_interval` segundos (nunca por debajo de reroll_base_cost).
@export var reroll_decay_amount: int = 1
@export var reroll_decay_interval: float = 10.0
## La primera oferta de cada jugador incluye siempre una carta de Farm.
@export var guarantee_starting_farm: bool = true

@export_group("Selling")
## Fracción del oro invertido que se devuelve al vender (0.5 = la mitad).
@export_range(0.0, 1.0, 0.05) var sell_refund_ratio: float = 0.5

@export_group("Structure Pricing")
## Multiplicador del precio de la 2ª copia de un edificio (1.25 = +25%).
@export var second_copy_cost_multiplier: float = 1.25
## Multiplicador acumulado de la 3ª copia y siguientes (1.30 = +30% sobre la anterior).
@export var extra_copy_cost_multiplier: float = 1.30

@export_group("Plots")
## Coste de cada plot por índice (0..5). Ver GridManager para el orden.
@export var plot_costs: PackedInt32Array = PackedInt32Array([40, 30, 20, 50, 0, 10])
## Plots desbloqueados al empezar, sin coste.
@export var initial_unlocked_plots: PackedInt32Array = PackedInt32Array([4])

@export_group("Army")
## Tropas vivas máximas por bando. Con más, los cuarteles dejan de producir y
## las cartas de unidades se rechazan: acota el caos del carril y el coste
## de simulación (cada unidad busca objetivos entre todas las demás).
@export var max_units_per_team: int = 80

@export_group("Structures")
@export_range(1, 10) var max_structure_level: int = 5
## Límite inferior del intervalo de producción de unidades con buffs.
@export var min_production_interval: float = 1.0


func get_plot_cost(plot_index: int) -> int:
	if plot_index < 0 or plot_index >= plot_costs.size():
		return -1
	return plot_costs[plot_index]


## Precio de una estructura con `owned_count` copias ya construidas.
## Copia 1 = base; copia 2 = base × second; copia 3+ = anterior × extra.
func get_scaled_structure_cost(base_cost: int, owned_count: int) -> int:
	var cost: float = float(base_cost)
	for copy_index: int in owned_count:
		cost *= second_copy_cost_multiplier if copy_index == 0 else extra_copy_cost_multiplier
	return roundi(cost)


func get_sell_refund(invested_gold: int) -> int:
	return floori(float(invested_gold) * sell_refund_ratio)


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if starting_gold < 0:
		errors.append("GameRules: starting_gold negativo")
	if base_income_amount < 0 or base_income_interval <= 0.0:
		errors.append("GameRules: base_income inválido")
	if castle_max_hp <= 0.0:
		errors.append("GameRules: castle_max_hp debe ser > 0")
	if shop_offer_size < 1:
		errors.append("GameRules: shop_offer_size debe ser >= 1")
	if reroll_base_cost < 0 or reroll_cost_increment < 0 or reroll_decay_amount < 0:
		errors.append("GameRules: costes de reroll negativos")
	if reroll_decay_interval <= 0.0:
		errors.append("GameRules: reroll_decay_interval debe ser > 0")
	if max_units_per_team < 1:
		errors.append("GameRules: max_units_per_team debe ser >= 1")
	if plot_costs.size() != PLOT_COUNT:
		errors.append("GameRules: plot_costs tiene %d valores, se esperaban %d" % [plot_costs.size(), PLOT_COUNT])
	for cost: int in plot_costs:
		if cost < 0:
			errors.append("GameRules: plot_costs contiene valores negativos")
			break
	if initial_unlocked_plots.is_empty():
		errors.append("GameRules: debe haber al menos un plot inicial")
	for plot_index: int in initial_unlocked_plots:
		if plot_index < 0 or plot_index >= PLOT_COUNT:
			errors.append("GameRules: initial_unlocked_plots contiene índice inválido %d" % plot_index)
	return errors
