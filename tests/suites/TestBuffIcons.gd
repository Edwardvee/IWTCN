extends TestSuite
## Iconos de mejoras activas: cuentan copias ("x2", "x3") y usan el icono de su carta.


func test_counts_keep_purchase_order() -> void:
	var ids: Array[StringName] = [&"buff_armor", &"buff_max_hp", &"buff_armor", &"buff_armor"]
	var counts: Dictionary[StringName, int] = BuffIcons.count_buffs(ids)
	assert_eq(counts[&"buff_armor"], 3, "3 copias de armadura")
	assert_eq(counts[&"buff_max_hp"], 1, "1 de vida")
	assert_eq(counts.keys(), [&"buff_armor", &"buff_max_hp"], "en orden de compra")


func test_label_only_from_two_copies() -> void:
	assert_eq(BuffIcons.label_for_count(1), "", "una copia: sin etiqueta")
	assert_eq(BuffIcons.label_for_count(2), "x2", "dos: x2")
	assert_eq(BuffIcons.label_for_count(3), "x3", "tres: x3")


func test_every_buff_has_an_icon() -> void:
	for buff: BuffData in GameManager.database.buffs:
		assert_true(BuffIcons.icon_for(buff.id) != null, "icono de '%s'" % buff.id)


func test_icons_follow_the_bought_buffs() -> void:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 3333)
	var icons: BuffIcons = BuffIcons.new()
	get_root().add_child(icons)
	assert_eq(icons.get_icon_count(), 0, "sin mejoras, sin iconos")
	BuffSystem.apply_buff(0, GameManager.database.get_buff(&"buff_armor"))
	BuffSystem.apply_buff(0, GameManager.database.get_buff(&"buff_armor"))
	BuffSystem.apply_buff(0, GameManager.database.get_buff(&"buff_max_hp"))
	assert_eq(icons.get_icon_count(), 2, "dos tipos de mejora")
	icons.queue_free()


func test_click_text_says_how_much_each_buff_gives() -> void:
	Localization.set_language("en", false)
	var armor: BuffData = GameManager.database.get_buff(&"buff_armor")
	assert_true(BuffIcons.describe(armor, 1).contains("take 10 % less damage"), "1 armadura: 10 %")
	assert_true(BuffIcons.describe(armor, 3).contains("take 30 % less damage"), "3 armaduras: 30 %")
	assert_true(BuffIcons.describe(armor, 3).contains("x3"), "y muestra x3")
	var production: BuffData = GameManager.database.get_buff(&"buff_production")
	assert_true(BuffIcons.describe(production, 2).contains("3.0 s faster"), "2 × 1,5 s = 3,0 s")
	for buff: BuffData in GameManager.database.buffs:
		assert_true(BuffIcons.describe(buff, 1).split("\n").size() == 2, "'%s': título y efecto" % buff.id)
	Localization.set_language("es", false)
	assert_true(BuffIcons.describe(armor, 2).contains("reciben un 20 % menos de daño"), "en español también")


func test_tapping_an_icon_opens_and_closes_its_info() -> void:
	GameManager.start_match(MatchTypes.GameMode.VS_AI, 3334)
	var icons: BuffIcons = BuffIcons.new()
	get_root().add_child(icons)
	BuffSystem.apply_buff(0, GameManager.database.get_buff(&"buff_armor"))
	var frame: Control = icons._column.get_child(0)
	assert_false(icons.is_info_visible(), "cerrado al principio")
	icons.show_info(&"buff_armor", frame)
	assert_true(icons.is_info_visible(), "al pulsar se abre")
	icons.show_info(&"buff_armor", frame)
	assert_false(icons.is_info_visible(), "al volver a pulsar se cierra")
	icons.queue_free()
