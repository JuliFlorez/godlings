extends RefCounted
class_name Settings
## Opciones del jugador: volumen (general y música), idioma, pantalla completa y
## fotogramas por segundo.
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
static var fullscreen := false
static var show_fps := false
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
		fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
		show_fps = cfg.get_value("display", "show_fps", show_fps)
	_apply()
	_apply_fps()
	if fullscreen:   # En ventana no se toca: queda como la abra el sistema
		_apply_window()

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

static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	save()

static func set_show_fps(on: bool) -> void:
	show_fps = on
	_apply_fps()
	save()

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("general", "locale", locale)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "show_fps", show_fps)
	cfg.save(PATH)

static func _apply() -> void:
	_set_bus(AudioServer.get_bus_index("Master"), master)
	_set_bus(AudioServer.get_bus_index(MUSIC_BUS), music)
	TranslationServer.set_locale(locale)

static func _apply_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

## El contador cuelga de la raíz (sobrevive al recargar el mundo); se lo busca por nombre
## en vez de guardarlo en un static.
static func _apply_fps() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var counter := root.get_node_or_null("FpsCounter")
	if show_fps and counter == null:
		counter = FpsCounter.new()
		counter.name = "FpsCounter"
		root.add_child.call_deferred(counter)   # Se llama desde un _ready: la raíz está ocupada
	elif not show_fps and counter:
		counter.queue_free()

static func _set_bus(i: int, v: float) -> void:
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
