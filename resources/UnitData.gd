class_name UnitData
extends Resource
## Definición data-driven de un tipo de unidad.
## Las entidades (UnitBase) leen de aquí sus estadísticas base; los buffs
## se aplican encima en tiempo de partida, nunca modificando este Resource.

enum Role { MELEE, RANGED, HEALER }
## Forma de respaldo cuando no hay sprite_frames (vertical slice).
enum Shape { SQUARE, TRIANGLE, CIRCLE, DIAMOND }

## Identificador estable usado por comandos y red (p.ej. &"soldier").
@export var id: StringName = &""
@export var display_name: String = ""
@export var role: Role = Role.MELEE

@export_group("Stats")
@export var max_hp: float = 100.0
@export var move_speed: float = 100.0
@export var attack_range: float = 45.0
## Segundos entre ataques (o curaciones, si es HEALER).
@export var attack_cooldown: float = 1.0
@export var damage: float = 0.0
## Fracción del daño entrante que se ignora (0.2 = recibe incoming × 0.8).
@export_range(0.0, 0.9, 0.01) var damage_mitigation: float = 0.0
## Solo HEALER: vida restaurada por curación.
@export var heal_amount: float = 0.0

@export_group("Projectile")
@export var uses_projectile: bool = false
@export var projectile_speed: float = 900.0

@export_group("Special")
## Daño en área: fracción del daño del golpe (0.15 = 15 %) que reciben también los
## enemigos a menos de splash_radius del objetivo. 0 = sin daño en área.
@export_range(0.0, 1.0, 0.01) var splash_fraction: float = 0.0
@export var splash_radius: float = 0.0
## Veneno: cada golpe deja al objetivo con poison_dps de daño por segundo durante
## poison_duration segundos (no se acumula: se renueva). Ignora la armadura.
@export var poison_dps: float = 0.0
@export var poison_duration: float = 0.0
## Solo unidades temporales (milicias): segundos que permanecen en el campo. 0 = permanente.
@export var lifetime: float = 0.0
## Si no está vacío, la raza usa el arte y la escala que tenga para esa otra unidad
## (las milicias se ven como soldados de su raza).
@export var art_unit_id: StringName = &""

@export_group("Visual")
## Sprite animado opcional. Si es null se dibuja fallback_shape.
@export var sprite_frames: SpriteFrames
@export var anim_walk: StringName = &"walk"
@export var anim_attack: StringName = &"attack"
@export var anim_death: StringName = &"death"
@export var sprite_scale: Vector2 = Vector2.ONE
@export var fallback_shape: Shape = Shape.SQUARE
@export var fallback_color: Color = Color.WHITE
## Radio del cuerpo, usado para el tamaño visual y la colisión.
@export var body_radius: float = 20.0


func has_splash() -> bool:
	return splash_fraction > 0.0 and splash_radius > 0.0


func has_poison() -> bool:
	return poison_dps > 0.0 and poison_duration > 0.0


func is_healer() -> bool:
	return role == Role.HEALER


func has_sprite_animation() -> bool:
	return sprite_frames != null


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var label: String = "UnitData '%s'" % id
	if id == &"":
		errors.append("%s: id vacío" % label)
	if max_hp <= 0.0:
		errors.append("%s: max_hp debe ser > 0" % label)
	if move_speed < 0.0:
		errors.append("%s: move_speed negativo" % label)
	if attack_range <= 0.0:
		errors.append("%s: attack_range debe ser > 0" % label)
	if attack_cooldown <= 0.0:
		errors.append("%s: attack_cooldown debe ser > 0" % label)
	if damage_mitigation < 0.0 or damage_mitigation > 0.9:
		errors.append("%s: damage_mitigation fuera de [0, 0.9]" % label)
	if is_healer():
		if heal_amount <= 0.0:
			errors.append("%s: HEALER necesita heal_amount > 0" % label)
	elif damage <= 0.0:
		errors.append("%s: unidad de combate necesita damage > 0" % label)
	if splash_fraction > 0.0 and splash_radius <= 0.0:
		errors.append("%s: splash_fraction necesita splash_radius > 0" % label)
	if (poison_dps > 0.0) != (poison_duration > 0.0):
		errors.append("%s: poison_dps y poison_duration van juntos" % label)
	if lifetime < 0.0:
		errors.append("%s: lifetime negativo" % label)
	if uses_projectile and projectile_speed <= 0.0:
		errors.append("%s: projectile_speed debe ser > 0" % label)
	if body_radius <= 0.0:
		errors.append("%s: body_radius debe ser > 0" % label)
	return errors
