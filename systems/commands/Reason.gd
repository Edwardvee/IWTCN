class_name Reason
extends RefCounted
## Motivos de rechazo de comandos traducibles.
##
## validate() devuelve el motivo SIN traducir (la clave en español, más los
## argumentos si los hay). Se traduce al mostrarlo con Reason.text(), en el
## idioma de quien lo lee: así un invitado online lo ve en su idioma aunque el
## anfitrión (que validó el comando) juegue en otro.
##   Reason.make("Slot ocupado")                     → "Slot ocupado"
##   Reason.make("Oro insuficiente (%d)", [45])      → "Oro insuficiente (%d)\u001f45"
## Sin argumentos el motivo es la propia clave, igual que antes.

const ARGUMENT_SEPARATOR: String = "\u001f"
const ARGUMENT_DELIMITER: String = "\u001e"


static func make(key: String, arguments: Array = []) -> String:
	if arguments.is_empty():
		return key
	var parts: PackedStringArray = PackedStringArray()
	for argument: Variant in arguments:
		parts.append(str(argument))
	return key + ARGUMENT_SEPARATOR + ARGUMENT_DELIMITER.join(parts)


## Texto listo para mostrar, traducido al idioma actual.
static func text(raw: String) -> String:
	var separator_at: int = raw.find(ARGUMENT_SEPARATOR)
	if separator_at < 0:
		return TranslationServer.translate(raw)
	var template: String = TranslationServer.translate(raw.substr(0, separator_at))
	var values: Array = []
	for part: String in raw.substr(separator_at + 1).split(ARGUMENT_DELIMITER):
		if part.is_valid_int():
			values.append(part.to_int())
		elif part.is_valid_float():
			values.append(part.to_float())
		else:
			values.append(String(TranslationServer.translate(part)))
	return template % values
