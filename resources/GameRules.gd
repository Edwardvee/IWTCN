class_name GameRules
extends Resource
## Reglas numéricas globales de la partida (economía, castillo, tienda,
## venta y plots). Todas editables desde el Inspector en data/game_rules.tres.

const PLOT_COUNT: int = 6
const SLOTS_PER_PLOT: int = 4

@export_group("Economy")
@export var starting_gold: int = 20
@export var base_income_amount: int = 3
@export var base_income_interval: float = 3.0

@export_group("Castle")
@export var castle_max_hp: float = 3000.0

@export_group("Sudden Death")
## Muerte súbita: pasados estos segundos los DOS castillos pierden vida cada segundo (evita
## las partidas eternas). 0 = desactivada.
@export var sudden_death_start: float = 420.0
## Vida que pierde cada castillo por segundo, como fracción de castle_max_hp.
@export var sudden_death_damage_fraction: float = 0.004
## Cada tantos segundos el daño se suma otra vez (x2, x3…) para que acabe sí o sí.
@export var sudden_death_ramp_interval: float = 30.0

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
## Precio de cada copia de un edificio como múltiplo del precio base de su
## carta: [1ª, 2ª, 3ª, 4ª, 5ª]. Subir de nivel = construir otra copia, así que
## esto es el coste de cada nivel. Pasar de nivel 2 a 3, 3 a 4 y 4 a 5 es mucho
## más caro que abrir el nivel 1 y 2.
@export var copy_cost_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 1.25, 2.5, 4.0, 6.0])

## Cada mejora (carta violeta) que ya tienes sube un 10 % el precio de la siguiente copia
## de ESA mejora (0.10; se acumula: 100 → 110 → 121…).
@export var buff_copy_cost_increase: float = 0.10

@export_group("Plots")
## Coste de cada plot por índice (0..5). Ver GridManager para el orden.
@export var plot_costs: PackedInt32Array = PackedInt32Array([40, 30, 20, 50, 0, 10])
## Plots desbloqueados al empezar, sin coste.
@export var initial_unlocked_plots: PackedInt32Array = PackedInt32Array([4])

@export_group("Army")
## Tropas vivas máximas por bando según el nivel de las granjas del jugador
## (nivel = nº de granjas, 0 sin granja): [0, 1, 2, 3, 4, 5]. Con el tope
## alcanzado los cuarteles dejan de producir y las cartas de unidades se
## rechazan. Ata el tamaño del ejército a la economía y acota el coste de
## simulación.
@export var unit_cap_by_farm_level: PackedInt32Array = PackedInt32Array([3, 8, 12, 24, 36, 60])
## Estructura cuyo nivel decide el tope.
@export var unit_cap_structure_id: StringName = &"farm"
## Si es > 0 sustituye a la tabla por un tope fijo (bancos de prueba y tests).
@export var unit_cap_override: int = 0

@export_group("Structures")
@export_range(1, 10) var max_structure_level: int = 5
## Límite inferior del intervalo de producción de unidades con buffs.
@export var min_production_interval: float = 1.0


## Vida que pierde cada castillo por segundo en el instante `match_time` (0 antes de la muerte súbita).
func get_sudden_death_dps(match_time: float) -> float:
	if sudden_death_start <= 0.0 or match_time < sudden_death_start:
		return 0.0
	var steps: int = 1
	if sudden_death_ramp_interval > 0.0:
		steps += floori((match_time - sudden_death_start) / sudden_death_ramp_interval)
	return castle_max_hp * sudden_death_damage_fraction * float(steps)


func get_plot_cost(plot_index: int) -> int:
	if plot_index < 0 or plot_index >= plot_costs.size():
		return -1
	return plot_costs[plot_index]


## Precio de una estructura con `owned_count` copias ya construidas: el
## multiplicador de la siguiente copia (la última se repite si hay más).
func get_scaled_structure_cost(base_cost: int, owned_count: int) -> int:
	if copy_cost_multipliers.is_empty():
		return base_cost
	var multiplier: float = copy_cost_multipliers[mini(maxi(owned_count, 0), copy_cost_multipliers.size() - 1)]
	return roundi(float(base_cost) * multiplier)


## Precio de una mejora con `owned_count` copias ya compradas (sube un
## buff_copy_cost_increase acumulado por copia).
func get_scaled_buff_cost(base_cost: int, owned_count: int) -> int:
	return roundi(float(base_cost) * pow(1.0 + buff_copy_cost_increase, maxi(owned_count, 0)))


## Tope de tropas para un jugador con `farm_level` granjas.
func get_unit_cap_for_level(farm_level: int) -> int:
	if unit_cap_override > 0:
		return unit_cap_override
	if unit_cap_by_farm_level.is_empty():
		return 1
	return unit_cap_by_farm_level[clampi(farm_level, 0, unit_cap_by_farm_level.size() - 1)]


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
	if unit_cap_by_farm_level.is_empty():
		errors.append("GameRules: unit_cap_by_farm_level vacío")
	for cap: int in unit_cap_by_farm_level:
		if cap < 1:
			errors.append("GameRules: unit_cap_by_farm_level contiene valores < 1")
			break
	if buff_copy_cost_increase < 0.0:
		errors.append("GameRules: buff_copy_cost_increase negativo")
	if copy_cost_multipliers.is_empty():
		errors.append("GameRules: copy_cost_multipliers vacío")
	for multiplier: float in copy_cost_multipliers:
		if multiplier <= 0.0:
			errors.append("GameRules: copy_cost_multipliers contiene valores <= 0")
			break
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
