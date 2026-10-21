extends RefCounted
class_name SaveSlots
## Las partidas guardadas: una por ranura, cada una en su archivo (user://save_1.cfg...).
## Las escriben y las leen World.save_game y World._load_game; acá está dónde van, el
## resumen que muestran las tarjetas del menú de inicio (ver TitleMenu) y borrarlas.

const COUNT := 3
## Donde se guardaba la única partida antes de que hubiera ranuras: pasa a ser la 1.
const OLD_PATH := "user://save.cfg"

static func path(slot: int) -> String:
	return "user://save_%d.cfg" % slot

static func delete(slot: int) -> void:
	DirAccess.remove_absolute(path(slot))

## La partida de antes de las ranuras pasa a la primera (si está libre).
static func migrate() -> void:
	if FileAccess.file_exists(OLD_PATH) and not FileAccess.file_exists(path(1)):
		DirAccess.rename_absolute(OLD_PATH, path(1))

## Lo que muestra la tarjeta de la partida, o {} si la ranura está vacía.
static func summary(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path(slot)) != OK:
		return {}
	var hud: Dictionary = cfg.get_value("game", "hud", {})
	var villagers: Array = cfg.get_value("island", "villagers", [])
	return {
		"level": int(cfg.get_value("island", "level", 0)),
		"villagers": villagers.size(),
		"offerings": int(hud.get("offerings", 0)),
		"night": bool(cfg.get_value("sky", "night", false)),
		"blood_moon": bool(cfg.get_value("sky", "moon_creepy", false)),
		# Las partidas de antes no lo guardaban: la fecha del archivo
		"saved_at": float(cfg.get_value("meta", "saved_at", FileAccess.get_modified_time(path(slot)))),
		"play_time": float(cfg.get_value("meta", "play_time", 0.0)),
	}

## La que se jugó por última vez (0 si no hay ninguna).
static func latest() -> int:
	var best := 0
	var best_t := -INF
	for slot in range(1, COUNT + 1):
		var info := summary(slot)
		if not info.is_empty() and info.saved_at > best_t:
			best = slot
			best_t = info.saved_at
	return best
