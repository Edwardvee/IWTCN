class_name Spells
extends RefCounted
## Constantes comunes de las habilidades de castillo (los datos de cada una
## están en data/spells/*.tres, ver SpellData).

## Margen de la autoridad para que la latencia online no rechace un hechizo
## lanzado justo al acabar su espera.
const COOLDOWN_TOLERANCE: float = 0.3
