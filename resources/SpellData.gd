class_name SpellData
extends Resource
## Habilidad de castillo (hechizo). Se lanza arrastrándola a tu mitad del carril
## y tiene su propio tiempo de espera. Todo lo que la define vive en
## data/spells/<id>.tres (Inspector o texto).
##   ARROW_RAIN: oleadas de daño ligero en un círculo (afecta a los enemigos).
##   LIGHTNING:  mata a la unidad enemiga más cercana al punto (ignora vida y armadura).
##   MILITIA:    invoca un grupo de soldados débiles que desaparecen a los `unit.lifetime` s.

enum Kind { ARROW_RAIN, LIGHTNING, MILITIA }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ARROW_RAIN
## Segundos hasta poder lanzarlo otra vez (cada hechizo tiene el suyo).
@export var cooldown: float = 30.0
## ARROW_RAIN: radio del círculo. LIGHTNING: tolerancia para elegir la unidad. MILITIA: sin uso.
@export var radius: float = 150.0
## ARROW_RAIN: daño de cada oleada a cada unidad enemiga dentro del círculo.
@export var damage: float = 0.0
@export var waves: int = 1
@export var wave_interval: float = 0.4
## MILITIA: unidad invocada y cuántas.
@export var unit: UnitData
@export var unit_count: int = 1
@export var color: Color = Color.WHITE
@export var icon: Texture2D


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var label: String = "SpellData '%s'" % id
	if id == &"":
		errors.append("%s: id vacío" % label)
	if cooldown <= 0.0:
		errors.append("%s: cooldown debe ser > 0" % label)
	match kind:
		Kind.ARROW_RAIN:
			if radius <= 0.0 or damage <= 0.0 or waves < 1 or wave_interval <= 0.0:
				errors.append("%s: ARROW_RAIN necesita radius, damage, waves y wave_interval > 0" % label)
		Kind.LIGHTNING:
			if radius <= 0.0:
				errors.append("%s: LIGHTNING necesita radius > 0" % label)
		Kind.MILITIA:
			if unit == null or unit_count < 1:
				errors.append("%s: MILITIA necesita unit y unit_count >= 1" % label)
	return errors
