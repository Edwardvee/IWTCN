class_name TeamArt
extends RefCounted
## Arte común de los bandos: material de contorno compartido (un ShaderMaterial
## por equipo mantiene el batching) y colores de la interfaz por tipo de carta.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/team_outline.gdshader")

static var _outline_materials: Dictionary[int, ShaderMaterial] = {}


## Material que dibuja el contorno exterior con el color del bando.
static func outline_material(team: int) -> ShaderMaterial:
	var material: ShaderMaterial = _outline_materials.get(team)
	if material == null:
		material = ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		material.set_shader_parameter("outline_color", MatchTypes.team_color(team))
		_outline_materials[team] = material
	return material


## Giro del sprite de una unidad: miran hacia "arriba" en su arte; el equipo
## de arriba avanza hacia abajo.
static func facing_rotation(team: int) -> float:
	return PI if team == MatchTypes.PLAYER_TOP else 0.0
