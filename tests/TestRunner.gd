extends Node
## Ejecuta todas las suites y cierra el juego con código 0 (ok) o 1 (fallos).
## Uso: godot --headless --path <proyecto> res://tests/TestRunner.tscn

const SUITE_PATHS: PackedStringArray = [
	"res://tests/suites/TestFoundation.gd",
	"res://tests/suites/TestDataModel.gd",
	"res://tests/suites/TestEconomy.gd",
	"res://tests/suites/TestGrid.gd",
	"res://tests/suites/TestUnits.gd",
	"res://tests/suites/TestRangedSupport.gd",
	"res://tests/suites/TestLane.gd",
	"res://tests/suites/TestStructures.gd",
	"res://tests/suites/TestShop.gd",
	"res://tests/suites/TestBuffs.gd",
	"res://tests/suites/TestConversion.gd",
	"res://tests/suites/TestWinLoss.gd",
	"res://tests/suites/TestAI.gd",
	"res://tests/suites/TestNetwork.gd",
	"res://tests/suites/TestView.gd",
	"res://tests/suites/TestReplay.gd",
	"res://tests/suites/TestLocalization.gd",
	"res://tests/suites/TestPerformance.gd",
]


func _ready() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	# Los tests asumen una economía inicial fija; el valor real de balance vive
	# en data/game_rules.tres y se ajusta sin tocar los tests.
	TestBalance.apply()
	# Los tests comparan textos en español (las claves); el idioma real se prueba en TestLocalization.
	Localization.set_language("es", false)
	var total: int = 0
	var failed: int = 0
	for suite_path: String in SUITE_PATHS:
		var suite_script: GDScript = load(suite_path) as GDScript
		if suite_script == null:
			push_error("No se pudo cargar la suite %s" % suite_path)
			failed += 1
			continue
		var suite: TestSuite = suite_script.new() as TestSuite
		print("== %s" % suite_path.get_file())
		for method: Dictionary in suite.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			suite.reset_results()
			if suite.has_method("before_each"):
				suite.call("before_each")
			suite.call(method_name)
			if suite.has_failed():
				failed += 1
				print("  FAIL %s" % method_name)
				for failure: String in suite.failures:
					print("       - %s" % failure)
			else:
				print("  PASS %s" % method_name)
		if suite.has_method("after_all"):
			suite.call("after_all")
	print("RESULTADO: %d/%d tests OK" % [total - failed, total])
	get_tree().quit(1 if failed > 0 else 0)
