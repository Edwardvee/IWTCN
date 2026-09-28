class_name StateMachine
extends RefCounted
## Máquina de estados por nombre. El dueño registra estados con add_state()
## y cambia con transition_to(). Los estados no guardan referencia a la
## máquina (evita ciclos de RefCounted): piden el cambio a su dueño.

signal state_changed(from_state: StringName, to_state: StringName)

var current_state: State = null
var current_state_name: StringName = &""

var _states: Dictionary[StringName, State] = {}


func add_state(state_name: StringName, state: State) -> void:
	_states[state_name] = state


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func start(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_error("StateMachine.start: estado desconocido '%s'" % state_name)
		return
	current_state_name = state_name
	current_state = _states[state_name]
	current_state.enter()


func transition_to(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_error("StateMachine.transition_to: estado desconocido '%s'" % state_name)
		return
	if state_name == current_state_name:
		return
	var previous_name: StringName = current_state_name
	if current_state != null:
		current_state.exit()
	current_state_name = state_name
	current_state = _states[state_name]
	current_state.enter()
	state_changed.emit(previous_name, state_name)


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func update(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func get_elapsed_in_state() -> float:
	return current_state.elapsed_time if current_state != null else 0.0
