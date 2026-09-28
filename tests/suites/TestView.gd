extends TestSuite
## Vista girada 180° para el jugador de arriba (solo presentación).

var camera: CameraDragController = null


func before_each() -> void:
	if camera == null:
		camera = CameraDragController.new()
		get_root().add_child(camera)
	GameManager.local_player_id = MatchTypes.PLAYER_BOTTOM
	camera.set_flipped(false)


func after_all() -> void:
	GameManager.local_player_id = MatchTypes.PLAYER_BOTTOM
	camera.queue_free()


func test_only_top_player_is_flipped() -> void:
	assert_false(ViewOrientation.is_flipped(), "player 0: vista normal")
	GameManager.local_player_id = MatchTypes.PLAYER_TOP
	assert_true(ViewOrientation.is_flipped(), "player 1: vista girada")


func test_camera_rotates_180() -> void:
	camera.set_flipped(true)
	assert_true(is_equal_approx(camera.rotation, PI), "rotación 180°")
	assert_false(camera.ignore_rotation, "la rotación se aplica a la vista")
	camera.set_flipped(false)
	assert_eq(camera.rotation, 0.0, "sin girar")


func test_flipped_camera_reserves_shop_space_at_world_top() -> void:
	camera.set_flipped(true)
	camera.focus_side(false)
	var half_height: float = camera.get_viewport_rect().size.y * 0.5
	# El borde superior del mundo queda bajo la barra de la tienda (440 px).
	assert_true(is_equal_approx(camera.position.y - half_height, -camera.bottom_padding), "margen de la tienda en el extremo superior")


func test_labels_counter_rotate() -> void:
	var label: Label = Label.new()
	label.size = Vector2(100.0, 40.0)
	GameManager.local_player_id = MatchTypes.PLAYER_TOP
	ViewOrientation.orient(label)
	assert_true(is_equal_approx(label.rotation, PI), "texto contrarrotado")
	assert_eq(label.pivot_offset, Vector2(50.0, 20.0), "gira sobre su centro")
	label.free()
