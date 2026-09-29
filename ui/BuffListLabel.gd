extends Label
## Mejoras globales activas del jugador local (agrupadas: "+15% Velocidad ×2").


func _ready() -> void:
	EventBus.buff_aplicado.connect(_on_buff_aplicado)
	EventBus.partida_iniciada.connect(_on_partida_iniciada)
	_refresh()


func _refresh() -> void:
	var counts: Dictionary[String, int] = {}
	var order: Array[String] = []
	for buff: BuffData in BuffSystem.get_buffs(GameManager.local_player_id):
		if not counts.has(buff.display_name):
			order.append(buff.display_name)
		counts[buff.display_name] = counts.get(buff.display_name, 0) + 1
	var parts: PackedStringArray = PackedStringArray()
	for buff_name: String in order:
		parts.append(tr(buff_name) if counts[buff_name] == 1 else "%s ×%d" % [tr(buff_name), counts[buff_name]])
	text = tr("Mejoras: %s") % ", ".join(parts) if not parts.is_empty() else ""
	visible = not parts.is_empty()


func _on_buff_aplicado(player_id: int, _buff: BuffData) -> void:
	if player_id == GameManager.local_player_id:
		_refresh()


func _on_partida_iniciada(_modo: int, _semilla: int) -> void:
	_refresh()
