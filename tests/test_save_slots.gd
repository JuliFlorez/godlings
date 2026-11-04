extends "res://tests/test_case.gd"
## Las partidas guardadas (ver SaveSlots): guardar y leer, la copia de la anterior, leer la copia si
## la partida está rota, la ranura dañada y borrar. Usa una ranura que el juego no usa, así no toca
## las partidas de verdad si se corre en otra compu.

const SLOT := 9

func before_each() -> void:
	SaveSlots.delete(SLOT)

func after_each() -> void:
	SaveSlots.delete(SLOT)

func test_write_and_read() -> void:
	check_eq(SaveSlots.write(SLOT, _cfg(42)), OK, "guardar")
	check(SaveSlots.exists(SLOT), "que exista")
	check(not FileAccess.file_exists(SaveSlots._temp(SLOT)), "que no quede el .tmp")
	var cfg := SaveSlots.read(SLOT)
	check(cfg != null, "que se lea")
	if cfg:
		check_eq(cfg.get_value("game", "hud", {}).get("offerings"), 42, "las ofrendas")
	var info := SaveSlots.summary(SLOT)
	check_eq(info.get("level"), 3, "el nivel del resumen")
	check_eq(info.get("villagers"), 2, "los aldeanos del resumen")
	check_eq(info.get("offerings"), 42, "las ofrendas del resumen")

func test_backup_keeps_previous() -> void:
	SaveSlots.write(SLOT, _cfg(1))
	SaveSlots.write(SLOT, _cfg(2))
	var bak := ConfigFile.new()
	check_eq(bak.load(SaveSlots._backup(SLOT)), OK, "que haya copia")
	check_eq(bak.get_value("game", "hud", {}).get("offerings"), 1, "que la copia sea la anterior")

func test_broken_file_reads_backup() -> void:
	SaveSlots.write(SLOT, _cfg(1))
	SaveSlots.write(SLOT, _cfg(2))
	_scribble(SaveSlots.path(SLOT))
	var cfg := SaveSlots.read(SLOT)
	check(cfg != null, "que lea la copia")
	if cfg:
		check_eq(cfg.get_value("game", "hud", {}).get("offerings"), 1, "las ofrendas de la copia")

func test_damaged_slot() -> void:
	SaveSlots.write(SLOT, _cfg(1))
	SaveSlots.write(SLOT, _cfg(2))
	_scribble(SaveSlots.path(SLOT))
	_scribble(SaveSlots._backup(SLOT))
	check(SaveSlots.read(SLOT) == null, "que no se pueda leer")
	check_eq(SaveSlots.summary(SLOT), {"damaged": true}, "que esté dañada")

func test_delete() -> void:
	SaveSlots.write(SLOT, _cfg(1))
	SaveSlots.write(SLOT, _cfg(2))
	SaveSlots.delete(SLOT)
	check(not SaveSlots.exists(SLOT), "que no quede nada")
	check_eq(SaveSlots.summary(SLOT), {}, "que esté vacía")

func _cfg(offerings: int) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SaveSlots.VERSION)
	cfg.set_value("island", "level", 3)
	cfg.set_value("island", "villagers", [{}, {}])
	cfg.set_value("game", "hud", {"offerings": offerings})
	return cfg

## Lo pisa con algo que no es una partida.
func _scribble(p: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("[sin cerrar\n= = =\n")
	f.close()
