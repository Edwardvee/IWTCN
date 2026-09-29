class_name ReplayData
extends RefCounted
## Partida grabada: cabecera (meta) + snapshots del estado autoritativo a
## intervalos fijos. Es la misma estructura que StateReplicator envía online,
## así que reproducirla reutiliza el camino del cliente y no depende de que el
## balance o las reglas actuales coincidan con las de la partida grabada.
##
## Formato en disco (zstd): var(meta) seguido de var(frames). Leer solo la
## cabecera para listar repeticiones no descomprime los snapshots.

const VERSION: int = 1
## Carpeta de repeticiones (variable para que los tests usen una temporal).
static var directory: String = "user://replays"
const EXTENSION: String = "iwr"
const MAX_SAVED: int = 15

var meta: Dictionary = {}
## Cada frame: {"t": segundos de partida, "s": snapshot}.
var frames: Array[Dictionary] = []


func _init(p_meta: Dictionary = {}) -> void:
	meta = p_meta


func add_frame(match_time: float, snapshot: Dictionary) -> void:
	frames.append({"t": match_time, "s": snapshot})


func get_duration() -> float:
	return float(frames.back()["t"]) if not frames.is_empty() else 0.0


func get_seed() -> int:
	return int(meta.get("seed", 0))


func get_winner() -> int:
	return int(meta.get("winner", MatchTypes.NO_PLAYER))


## Guarda la repetición y devuelve su ruta ("" si falla).
func save(file_name: String = "") -> String:
	DirAccess.make_dir_recursive_absolute(directory)
	if file_name == "":
		file_name = "replay_%s" % Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = "%s/%s.%s" % [directory, file_name, EXTENSION]
	var file: FileAccess = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_warning("ReplayData: no se pudo escribir %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return ""
	var stored_meta: Dictionary = meta.duplicate()
	stored_meta["version"] = VERSION
	stored_meta["duration"] = get_duration()
	stored_meta["frame_count"] = frames.size()
	file.store_var(stored_meta)
	file.store_var(frames)
	file.close()
	prune()
	return path


static func load_from(path: String) -> ReplayData:
	var file: FileAccess = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	var loaded_meta: Variant = file.get_var()
	if not loaded_meta is Dictionary or int((loaded_meta as Dictionary).get("version", 0)) != VERSION:
		return null
	var loaded_frames: Variant = file.get_var()
	if not loaded_frames is Array:
		return null
	var data: ReplayData = ReplayData.new(loaded_meta)
	for frame: Variant in loaded_frames:
		if frame is Dictionary and (frame as Dictionary).has("t") and (frame as Dictionary).has("s"):
			data.frames.append(frame)
	return data if not data.frames.is_empty() else null


static func read_meta(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {}
	var loaded_meta: Variant = file.get_var()
	return loaded_meta if loaded_meta is Dictionary else {}


## Repeticiones guardadas, la más reciente primero. Cada elemento es su meta
## más "path".
static func list_replays() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path: String in _list_paths():
		var replay_meta: Dictionary = read_meta(path)
		if replay_meta.is_empty():
			continue
		replay_meta["path"] = path
		result.append(replay_meta)
	return result


## Conserva solo las MAX_SAVED más recientes.
static func prune() -> void:
	var paths: PackedStringArray = _list_paths()
	for index: int in range(MAX_SAVED, paths.size()):
		DirAccess.remove_absolute(paths[index])


## Rutas ordenadas de más reciente a más antigua (el nombre lleva la fecha).
static func _list_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.get_extension() == EXTENSION:
			paths.append("%s/%s" % [directory, file_name])
	paths.sort()
	paths.reverse()
	return paths
