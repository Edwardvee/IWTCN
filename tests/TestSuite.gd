class_name TestSuite
extends RefCounted
## Base de las suites de test. Cada método que empieza por "test_" es un caso.
## Si la suite define before_each(), el runner lo llama antes de cada caso;
## si define after_all(), lo llama al terminar la suite (liberar nodos, señales).

var failures: PackedStringArray = PackedStringArray()


func reset_results() -> void:
	failures = PackedStringArray()


func has_failed() -> bool:
	return not failures.is_empty()


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_false(condition: bool, message: String) -> void:
	if condition:
		failures.append(message)


## Variant: comparación genérica entre cualquier par de valores.
func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (esperado: %s, obtenido: %s)" % [message, str(expected), str(actual)])


func get_root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
