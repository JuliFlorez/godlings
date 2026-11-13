extends VBoxContainer
class_name SettingsPanel
## Las opciones (ver Settings): volumen general y de música, idioma, pantalla completa,
## fotogramas por segundo, cómo se dan vuelta los aldeanos y si hay eventos al azar.
## Va en el menú de pausa y en el de inicio; cada cambio se aplica y se guarda al toque.

signal locale_changed

var _master_value: Label
var _music_value: Label
var _master_slider: HSlider
var _music_slider: HSlider
var _lang_buttons := {}       # código -> Button
var _window_buttons := {}     # pantalla completa (bool) -> Button
var _fps_buttons := {}        # mostrar (bool) -> Button
var _turn_buttons := {}       # de a poco (bool) -> Button
var _event_buttons := {}      # eventos al azar (bool) -> Button

func _ready() -> void:
	add_theme_constant_override("separation", 8)

	var m := _slider_row("Volumen general", Settings.master, Settings.set_master)
	_master_slider = m[0]
	_master_value = m[1]
	var mu := _slider_row("Música", Settings.music, Settings.set_music)
	_music_slider = mu[0]
	_music_value = mu[1]

	# Todas las filas de botones van en una sola línea (el título a la izquierda), para que el
	# panel entre debajo del logo en el menú de inicio
	var langs := _choice_row("Idioma", true)
	for l: Array in Settings.LOCALES:
		var code: String = l[0]
		var b := _choice(langs, l[1])
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Cada idioma con su nombre
		b.pressed.connect(func():
			Settings.set_locale(code)
			sync()
			locale_changed.emit())
		_lang_buttons[code] = b

	var window := _choice_row("Pantalla", true)
	for full: bool in [false, true]:
		var b := _choice(window, "Pantalla completa" if full else "Ventana")
		b.pressed.connect(func():
			Settings.set_fullscreen(full)
			sync())
		_window_buttons[full] = b

	var fps := _choice_row("Fotogramas (FPS)", true)
	for on: bool in [false, true]:
		var b := _choice(fps, "Mostrar" if on else "Ocultar")
		b.pressed.connect(func():
			Settings.set_show_fps(on)
			sync())
		_fps_buttons[on] = b

	var turn := _choice_row("Darse vuelta", true)
	for smooth: bool in [false, true]:
		var b := _choice(turn, "De a poco" if smooth else "De golpe")
		b.pressed.connect(func():
			Settings.set_smooth_turn(smooth)
			sync())
		_turn_buttons[smooth] = b

	# Brotes de gripe, lluvias de meteoritos y terremotos que vienen solos (ver Calamities)
	var events := _choice_row("Eventos al azar", true)
	for on: bool in [false, true]:
		var b := _choice(events, "Activados" if on else "Desactivados")
		b.tooltip_text = "Cada tanto pasa algo solo: un brote de gripe, una lluvia de meteoritos o un terremoto"
		b.pressed.connect(func():
			Settings.set_random_events(on)
			sync())
		_event_buttons[on] = b
	sync()

## Muestra los valores de ahora (al abrir el menú).
func sync() -> void:
	_master_slider.set_value_no_signal(Settings.master * 100.0)
	_music_slider.set_value_no_signal(Settings.music * 100.0)
	_master_value.text = "%d%%" % roundi(Settings.master * 100.0)
	_music_value.text = "%d%%" % roundi(Settings.music * 100.0)
	for code: String in _lang_buttons:
		_mark(_lang_buttons[code], code == Settings.locale)
	for full: bool in _window_buttons:
		_mark(_window_buttons[full], full == Settings.fullscreen)
	for on: bool in _fps_buttons:
		_mark(_fps_buttons[on], on == Settings.show_fps)
	for smooth: bool in _turn_buttons:
		_mark(_turn_buttons[smooth], smooth == Settings.smooth_turn)
	for on: bool in _event_buttons:
		_mark(_event_buttons[on], on == Settings.random_events)

func _mark(b: Button, on: bool) -> void:
	b.add_theme_stylebox_override("normal", UiStyle.box(Color(UiStyle.C_DEVOTION, 0.35) if on else Color(1, 1, 1, 0.08), 8, UiStyle.C_DEVOTION if on else Color(1, 1, 1, 0.12), 1))

# ---- Construcción ----
## Título, barra y valor en una sola línea (así el panel entra debajo del logo en el menú de inicio).
func _slider_row(title: String, value: float, setter: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	row.add_child(UiStyle.label(title, 14, UiStyle.C_TEXT))
	var value_l := UiStyle.label("", 13, UiStyle.C_MUTED)
	value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_l.custom_minimum_size = Vector2(38, 0)

	var s := HSlider.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	s.value = value * 100.0
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(0, 20)
	s.add_theme_stylebox_override("slider", UiStyle.box(UiStyle.C_TRACK, 4, Color(0, 0, 0, 0), 0, Vector4(0, 4, 0, 4)))
	s.add_theme_stylebox_override("grabber_area", UiStyle.box(UiStyle.C_DEVOTION, 4, Color(0, 0, 0, 0), 0, Vector4(0, 4, 0, 4)))
	s.add_theme_stylebox_override("grabber_area_highlight", UiStyle.box(UiStyle.C_DEVOTION.lightened(0.2), 4, Color(0, 0, 0, 0), 0, Vector4(0, 4, 0, 4)))
	s.value_changed.connect(func(v: float):
		setter.call(v / 100.0)
		value_l.text = "%d%%" % roundi(v))
	row.add_child(s)
	row.add_child(value_l)
	return [s, value_l]

## Título y una fila de botones para elegir uno de ellos (devuelve la fila).
## inline: el título va a la izquierda, en la misma fila que los botones.
func _choice_row(title: String, inline := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := UiStyle.label(title, 14, UiStyle.C_TEXT)
	if inline:
		row.add_child(label)
	else:
		add_child(label)
	add_child(row)
	return row

func _choice(row: HBoxContainer, text: String) -> Button:
	var b := UiStyle.button(text, Color(1, 1, 1, 0.08))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	return b
