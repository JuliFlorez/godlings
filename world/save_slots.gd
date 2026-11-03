extends RefCounted
class_name SaveSlots
## Las partidas guardadas: una por ranura, cada una en su archivo (user://save_1.cfg...).
## Las arman y las cargan World.save_game y World._load_game, que escriben y leen con write y
## read; acá está dónde van, el resumen que muestran las tarjetas del menú de inicio (ver
## TitleMenu) y borrarlas.
## Al guardar se escribe primero un .tmp y recién después pasa a ser la partida; la de antes queda
## como copia (.bak). Si el archivo de la partida no se puede leer (se cortó la luz justo cuando se
## guardaba, por ejemplo), se lee la copia; si tampoco, la ranura está dañada: el menú lo dice y no
## la pisa con una partida nueva.

const COUNT := 3
## La versión del formato (meta/version, ver World.save_game). Si cambia el formato, subirla y seguir
## cargando las de antes:
## - 0: las de antes de que tuviera versión; se cargan mirando qué claves tienen (ver World._load_game).
## - 1: con versión.
## - 2: los poderes comprados van juntos en game/hud/unlocked, {id: bool} (ver Game.save_state y
##   _old_unlocks, que lee los de antes).
const VERSION := 2
## Donde se guardaba la única partida antes de que hubiera ranuras: pasa a ser la 1.
const OLD_PATH := "user://save.cfg"

static func path(slot: int) -> String:
	return "user://save_%d.cfg" % slot

static func _backup(slot: int) -> String:
	return path(slot) + ".bak"

static func _temp(slot: int) -> String:
	return path(slot) + ".tmp"

## Guarda la partida en su ranura (ver arriba): OK, o el error de lo que falló. Si falla, lo que
## estaba guardado queda como estaba.
static func write(slot: int, cfg: ConfigFile) -> Error:
	var err := cfg.save(_temp(slot))
	if err != OK:
		return err
	if FileAccess.file_exists(path(slot)):
		err = _replace(path(slot), _backup(slot))
		if err != OK:
			return err
	return _replace(_temp(slot), path(slot))

## Mueve from a to, aunque to ya exista.
static func _replace(from: String, to: String) -> Error:
	if FileAccess.file_exists(to):
		var err := DirAccess.remove_absolute(to)
		if err != OK:
			return err
	return DirAccess.rename_absolute(from, to)

## La partida de la ranura (o su copia, si el archivo está roto), o null si no hay ninguna que se
## pueda leer.
static func read(slot: int) -> ConfigFile:
	for p: String in [path(slot), _backup(slot)]:
		if not FileAccess.file_exists(p):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(p) == OK:
			return cfg
		push_warning("No se pudo leer la partida guardada en %s" % p)
	return null

## Si hay algo guardado en la ranura (aunque no se pueda leer).
static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot)) or FileAccess.file_exists(_backup(slot))

static func delete(slot: int) -> void:
	for p: String in [path(slot), _backup(slot), _temp(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

## La partida de antes de las ranuras pasa a la primera (si está libre).
static func migrate() -> void:
	if FileAccess.file_exists(OLD_PATH) and not exists(1):
		DirAccess.rename_absolute(OLD_PATH, path(1))

## Lo que muestra la tarjeta de la partida: {} si la ranura está vacía, y {"damaged": true} si hay
## algo guardado pero no se puede leer (ni la copia).
static func summary(slot: int) -> Dictionary:
	var cfg := read(slot)
	if cfg == null:
		return {"damaged": true} if exists(slot) else {}
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
		if info.has("saved_at") and info.saved_at > best_t:
			best = slot
			best_t = info.saved_at
	return best
