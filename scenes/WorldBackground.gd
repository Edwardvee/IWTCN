class_name WorldBackground
extends Node2D
## Suelo del mundo: hierba, camino de tierra entre los castillos y arbolitos,
## arbustos y rocas muy suaves a los lados. Solo presentación (semilla propia,
## no toca el RNG de la partida).

const GRASS: Texture2D = preload("res://assets/world/grass.svg")
const ROAD: Texture2D = preload("res://assets/world/road.svg")
const DECOR: Array[Texture2D] = [
	preload("res://assets/world/tree_oak.svg"),
	preload("res://assets/world/tree_pine.svg"),
	preload("res://assets/world/bush.svg"),
	preload("res://assets/world/rock.svg"),
	preload("res://assets/world/flowers.svg"),
]
## Probabilidad acumulada de cada elemento de DECOR.
const DECOR_WEIGHTS: Array[float] = [0.34, 0.64, 0.84, 0.92, 1.0]
## Alfa por elemento: los árboles apenas se notan; flores y rocas algo más.
const DECOR_ALPHA: Array[float] = [0.3, 0.3, 0.36, 0.45, 0.55]
const RASTER_SCALE: float = 0.5
const DECOR_SEED: int = 20260929

@export var world_size: Vector2 = Vector2(1080.0, 3200.0)
## Margen de hierba fuera del mundo (pantallas anchas, márgenes de la cámara).
@export var margin: float = 600.0
@export var road_center: Vector2 = Vector2(540.0, 1600.0)
@export var road_half_width: float = 150.0
@export var road_top: float = 900.0
@export var road_bottom: float = 2300.0
@export var decor_count: int = 120


func _ready() -> void:
	_create_ground()
	_create_road()
	_scatter_decor()


func _create_ground() -> void:
	var ground: Sprite2D = Sprite2D.new()
	ground.texture = GRASS
	ground.centered = false
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.scale = Vector2.ONE * RASTER_SCALE
	ground.region_enabled = true
	var full: Vector2 = (world_size + Vector2.ONE * margin * 2.0) / RASTER_SCALE
	ground.region_rect = Rect2(Vector2.ZERO, full)
	ground.position = -Vector2.ONE * margin
	add_child(ground)


func _create_road() -> void:
	var road: Sprite2D = Sprite2D.new()
	road.texture = ROAD
	road.scale = Vector2.ONE * RASTER_SCALE
	road.position = road_center
	add_child(road)


func _scatter_decor() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = DECOR_SEED
	var placed: Array[Dictionary] = []
	for index: int in decor_count:
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		# Más densidad junto al camino, cada vez menos hacia los bordes del mundo.
		var distance: float = pow(rng.randf(), 1.6) * (world_size.x * 0.5 - road_half_width - 30.0)
		var x: float = road_center.x + side * (road_half_width + 26.0 + distance)
		var y: float = rng.randf_range(road_top - 60.0, road_bottom + 60.0)
		var pick: float = rng.randf()
		var kind: int = 0
		while kind < DECOR_WEIGHTS.size() - 1 and pick > DECOR_WEIGHTS[kind]:
			kind += 1
		placed.append({"kind": kind, "position": Vector2(x, y), "scale": rng.randf_range(0.85, 1.2), "flip": rng.randf() < 0.5})
	# De arriba abajo: lo más cercano a la cámara se dibuja encima.
	placed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["position"].y < b["position"].y)
	for item: Dictionary in placed:
		var kind: int = item["kind"]
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = DECOR[kind]
		sprite.position = item["position"]
		sprite.scale = Vector2(-1.0 if item["flip"] else 1.0, 1.0) * RASTER_SCALE * float(item["scale"])
		sprite.modulate.a = DECOR_ALPHA[kind]
		add_child(sprite)
