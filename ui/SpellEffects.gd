class_name SpellEffects
extends Node2D
## Efectos visuales de las habilidades de castillo (lluvia de flechas, rayo e
## invocación de milicias). Solo presentación: escucha EventBus.hechizo_lanzado, así
## que funciona igual en local, online y repeticiones. Todo se dibuja en un _draw.

const RAIN_LIFE: float = 2.6
const BOLT_LIFE: float = 0.45
const SUMMON_LIFE: float = 0.9
const MAX_EFFECTS: int = 12

class Effect:
	var kind: SpellData.Kind = SpellData.Kind.ARROW_RAIN
	var position: Vector2 = Vector2.ZERO
	var radius: float = 150.0
	var color: Color = Color.WHITE
	var age: float = 0.0
	var life: float = 1.0
	var seed_value: int = 0

var _effects: Array[Effect] = []


func _ready() -> void:
	z_index = 190
	EventBus.hechizo_lanzado.connect(_on_hechizo_lanzado)
	EventBus.partida_iniciada.connect(func(_mode: int, _seed: int) -> void: _effects.clear())


func get_effect_count() -> int:
	return _effects.size()


func _on_hechizo_lanzado(player_id: int, spell_id: StringName, position_in_world: Vector2) -> void:
	if GameManager.suppress_effects or GameManager.database == null:
		return
	var spell: SpellData = GameManager.database.get_spell(spell_id)
	if spell == null:
		return
	if _effects.size() >= MAX_EFFECTS:
		_effects.remove_at(0)
	var effect: Effect = Effect.new()
	effect.kind = spell.kind
	effect.position = position_in_world
	effect.radius = spell.radius if spell.kind != SpellData.Kind.MILITIA else 110.0
	effect.color = spell.color
	effect.seed_value = hash([player_id, spell_id, roundi(position_in_world.x), roundi(position_in_world.y)])
	match spell.kind:
		SpellData.Kind.ARROW_RAIN:
			effect.life = RAIN_LIFE
		SpellData.Kind.LIGHTNING:
			effect.life = BOLT_LIFE
		SpellData.Kind.MILITIA:
			effect.life = SUMMON_LIFE
	_effects.append(effect)


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	var index: int = 0
	while index < _effects.size():
		_effects[index].age += delta
		if _effects[index].age >= _effects[index].life:
			_effects.remove_at(index)
		else:
			index += 1
	queue_redraw()


func _draw() -> void:
	for effect: Effect in _effects:
		match effect.kind:
			SpellData.Kind.ARROW_RAIN:
				_draw_rain(effect)
			SpellData.Kind.LIGHTNING:
				_draw_bolt(effect)
			SpellData.Kind.MILITIA:
				_draw_summon(effect)


func _draw_rain(effect: Effect) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = effect.seed_value
	var fade: float = 1.0 - clampf((effect.age - (effect.life - 0.5)) / 0.5, 0.0, 1.0)
	draw_arc(effect.position, effect.radius, 0.0, TAU, 48, Color(effect.color, 0.35 * fade), 5.0)
	var flip: float = -1.0 if ViewOrientation.is_flipped() else 1.0
	for arrow: int in 34:
		var angle: float = rng.randf() * TAU
		var distance: float = sqrt(rng.randf()) * effect.radius
		var landing: Vector2 = effect.position + Vector2(cos(angle), sin(angle)) * distance
		var start_time: float = rng.randf() * (effect.life - 0.9)
		var t: float = (effect.age - start_time) / 0.35
		if t < 0.0 or t > 1.6:
			continue
		if t <= 1.0:
			var head: Vector2 = landing - Vector2(0.0, 380.0 * flip) * (1.0 - t)
			var tail: Vector2 = head - Vector2(0.0, 46.0 * flip)
			draw_line(tail, head, Color(0.09, 0.07, 0.12, fade), 7.0)
			draw_line(tail, head, Color(0.85, 0.65, 0.4, fade), 3.6)
			draw_circle(head, 5.0, Color(0.92, 0.96, 1.0, fade))
		else:
			draw_circle(landing, 9.0 * (t - 1.0) * 4.0 + 3.0, Color(effect.color, 0.5 * fade * (1.6 - t)))


func _draw_bolt(effect: Effect) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = effect.seed_value
	var progress: float = effect.age / effect.life
	var alpha: float = 1.0 - progress
	var flip: float = -1.0 if ViewOrientation.is_flipped() else 1.0
	var points: PackedVector2Array = PackedVector2Array()
	var top: Vector2 = effect.position - Vector2(0.0, 900.0 * flip)
	var segments: int = 9
	for step: int in segments + 1:
		var t: float = float(step) / float(segments)
		var point: Vector2 = top.lerp(effect.position, t)
		if step > 0 and step < segments:
			point.x += rng.randf_range(-42.0, 42.0)
		points.append(point)
	draw_polyline(points, Color(0.55, 0.75, 1.0, alpha * 0.55), 22.0)
	draw_polyline(points, Color(1.0, 0.98, 0.7, alpha), 9.0)
	draw_polyline(points, Color(1.0, 1.0, 1.0, alpha), 4.0)
	draw_circle(effect.position, 70.0 * (0.4 + progress), Color(0.75, 0.88, 1.0, alpha * 0.55))
	draw_arc(effect.position, 110.0 * (0.3 + progress), 0.0, TAU, 36, Color(1.0, 1.0, 0.8, alpha), 6.0)


func _draw_summon(effect: Effect) -> void:
	var progress: float = effect.age / effect.life
	var alpha: float = 1.0 - progress
	draw_arc(effect.position, effect.radius * (0.3 + progress * 0.9), 0.0, TAU, 40, Color(effect.color, alpha), 8.0)
	draw_arc(effect.position, effect.radius * (0.15 + progress * 0.6), 0.0, TAU, 32, Color(1.0, 1.0, 1.0, alpha * 0.8), 4.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = effect.seed_value
	for spark: int in 10:
		var angle: float = rng.randf() * TAU
		var spread: float = effect.radius * (0.2 + progress) * rng.randf_range(0.6, 1.1)
		draw_circle(effect.position + Vector2(cos(angle), sin(angle)) * spread - Vector2(0.0, progress * 40.0), 5.0 * alpha + 1.0, Color(1.0, 0.95, 0.7, alpha))
