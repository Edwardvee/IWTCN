class_name DeadState
extends UnitState
## DEAD: estado final. No se mueve ni ataca; se desvanece durante
## UnitBase.DEATH_DURATION y después el LaneManager libera el nodo.


func enter() -> void:
	super()
	unit.play_animation(unit.data.anim_death)


func physics_update(delta: float) -> void:
	super(delta)
	unit.modulate.a = clampf(1.0 - elapsed_time / UnitBase.DEATH_DURATION, 0.0, 1.0)
