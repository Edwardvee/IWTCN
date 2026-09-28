class_name State
extends RefCounted
## Estado base de una máquina de estados finita (StateMachine).
##
## Los estados son RefCounted (no nodos) para que cientos de unidades no
## multipliquen el número de nodos del árbol. Las subclases sobrescriben los
## hooks que necesiten y llaman a super() en enter()/exit()/physics_update()
## para conservar el seguimiento de tiempo.

var is_active: bool = false
## Segundos de simulación transcurridos desde enter().
var elapsed_time: float = 0.0


func enter() -> void:
	is_active = true
	elapsed_time = 0.0


func exit() -> void:
	is_active = false


## Hook de frame de render (visuales). La simulación usa physics_update.
## Vacío a propósito en la base: ningún estado actual lo necesita.
func update(_delta: float) -> void:
	return


## Paso de simulación de gameplay.
func physics_update(delta: float) -> void:
	elapsed_time += delta
