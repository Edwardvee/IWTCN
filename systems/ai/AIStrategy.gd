class_name AIStrategy
extends RefCounted
## Interfaz de estrategia de IA. AIController pregunta cada cierto tiempo qué
## comando ejecutar; la estrategia solo LEE información pública a través del
## controlador y devuelve un GameCommand (o null para esperar).
## Para una IA más avanzada basta con otra subclase: el núcleo no cambia.


## null = no hacer nada en este turno de decisión (estrategia pasiva).
func choose_command(_ai: AIController) -> GameCommand:
	return null
