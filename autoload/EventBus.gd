extends Node
## Bus global de eventos para comunicar sistemas desacoplados.
##
## Solo declara señales: no contiene estado ni lógica.
## Todas las señales de gameplay llevan player_id/team explícito, nunca
## "aliado/enemigo": eso es relativo al observador y lo calcula la UI
## comparando con GameManager.local_player_id.
##
## Las unidades se tipan como CharacterBody2D (UnitBase extiende de ella)
## para que el EventBus no dependa de las clases de entidades.

# Las señales se emiten desde otros scripts; el aviso "unused_signal" no aplica aquí.
@warning_ignore_start("unused_signal")

# --- Partida ---
signal partida_iniciada(modo: int, semilla: int)
signal partida_terminada(ganador_player_id: int)

# --- Economía ---
signal oro_actualizado(player_id: int, nuevo_total: int)

# --- Grid ---
## Estado local de UI (qué slot está resaltado); no es estado de gameplay.
signal slot_seleccionado(player_id: int, slot_index: int)
signal plot_desbloqueado(player_id: int, plot_index: int)
signal estructura_construida(player_id: int, slot_index: int, datos: StructureData, nivel: int)
signal estructura_fusionada(player_id: int, slot_destino: int, slot_liberado: int, nuevo_nivel: int)
signal estructura_vendida(player_id: int, slot_index: int, oro_devuelto: int)

# --- Unidades ---
signal unidad_desplegada(unidad: CharacterBody2D, team: int)
signal unidad_eliminada(unidad: CharacterBody2D, team: int)
signal unidad_convertida(unidad: CharacterBody2D, team_anterior: int, team_nuevo: int)
## Cambio de vida de una unidad: delta < 0 daño, delta > 0 curación. También
## se emite en clientes online y repeticiones al aplicar la vida replicada.
signal unidad_vida_cambiada(unidad: CharacterBody2D, delta: float)

# --- Tienda de cartas ---
## Oferta actual de la tienda de un jugador (3 cartas distintas).
signal draft_ofrecido(player_id: int, cartas: Array[CardData])
signal carta_elegida(player_id: int, carta: CardData)
signal coste_reroll_actualizado(player_id: int, coste: int)
signal buff_aplicado(player_id: int, buff: BuffData)

# --- Castillos ---
signal castillo_danado(player_id: int, vida_actual: float, vida_maxima: float)

# --- Comandos ---
signal comando_rechazado(player_id: int, tipo_comando: StringName, motivo: String)

@warning_ignore_restore("unused_signal")
