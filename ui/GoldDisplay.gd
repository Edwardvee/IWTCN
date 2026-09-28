extends PanelContainer
## Muestra el oro del jugador local. Solo lee: escucha oro_actualizado y
## filtra por GameManager.local_player_id.

@onready var _amount_label: Label = %GoldAmount


func _ready() -> void:
	EventBus.oro_actualizado.connect(_on_oro_actualizado)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	_show_gold(EconomyManager.get_gold(GameManager.local_player_id))


func _show_gold(amount: int) -> void:
	_amount_label.text = str(amount)


func _on_oro_actualizado(player_id: int, nuevo_total: int) -> void:
	if player_id != GameManager.local_player_id:
		return
	_show_gold(nuevo_total)


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_show_gold(EconomyManager.get_gold(GameManager.local_player_id))
