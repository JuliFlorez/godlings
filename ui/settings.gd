extends RefCounted
class_name Settings
## Opciones del jugador: volumen (general y música) e idioma.
## Se guardan en user://settings.cfg y se aplican al arrancar.
## Los textos del juego están escritos en español y se usan como claves de traducción
## (ver I18n); los Label/Button se traducen solos, y los textos con formato usan tr().

const PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
## [código, nombre en su propio idioma]
const LOCALES := [["es", "Español"], ["en", "English"]]

static var master := 1.0     # 0..1
static var music := 1.0      # 0..1
static var locale := "es"
static var _initialized := false

## Prepara buses, traducciones y opciones guardadas. Se puede llamar varias veces.
static func init() -> void:
	if _initialized:
		return
	_initialized = true
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, MUSIC_BUS)
		AudioServer.set_bus_send(i, "Master")
	I18n.register()

	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master = clampf(cfg.get_value("audio", "master", master), 0.0, 1.0)
		music = clampf(cfg.get_value("audio", "music", music), 0.0, 1.0)
		locale = cfg.get_value("general", "locale", locale)
	_apply()

static func set_master(v: float) -> void:
	master = clampf(v, 0.0, 1.0)
	_apply()
	save()

static func set_music(v: float) -> void:
	music = clampf(v, 0.0, 1.0)
	_apply()
	save()

static func set_locale(code: String) -> void:
	locale = code
	_apply()
	save()

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("general", "locale", locale)
	cfg.save(PATH)

static func _apply() -> void:
	_set_bus(AudioServer.get_bus_index("Master"), master)
	_set_bus(AudioServer.get_bus_index(MUSIC_BUS), music)
	TranslationServer.set_locale(locale)

static func _set_bus(i: int, v: float) -> void:
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
