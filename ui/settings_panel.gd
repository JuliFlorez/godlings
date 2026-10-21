extends VBoxContainer
class_name SettingsPanel
## Las opciones (ver Settings): volumen general y de música, idioma y pantalla completa.
## Va en el menú de pausa y en el de inicio; cada cambio se aplica y se guarda al toque.

signal locale_changed

var _master_value: Label
var _music_value: Label
var _master_slider: HSlider
var _music_slider: HSlider
var _lang_buttons := {}       # código -> Button
var _window_buttons := {}     # pantalla completa (bool) -> Button

func _ready() -> void:
	add_theme_constant_override("separation", 12)

	var m := _slider_row("Volumen general", Settings.master, Settings.set_master)
	_master_slider = m[0]
	_master_value = m[1]
	var mu := _slider_row("Música", Settings.music, Settings.set_music)
	_music_slider = mu[0]
	_music_value = mu[1]

	var langs := _choice_row("Idioma")
	for l: Array in Settings.LOCALES:
		var code: String = l[0]
		var b := _choice(langs, l[1])
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Cada idioma con su nombre
		b.pressed.connect(func():
			Settings.set_locale(code)
			sync()
			locale_changed.emit())
		_lang_buttons[code] = b

	var window := _choice_row("Pantalla")
	for full: bool in [false, true]:
		var b := _choice(window, "Pantalla completa" if full else "Ventana")
		b.pressed.connect(func():
			Settings.set_fullscreen(full)
			sync())
		_window_buttons[full] = b
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

func _mark(b: Button, on: bool) -> void:
	b.add_theme_stylebox_override("normal", HUD.make_box(Color(HUD.C_DEVOTION, 0.35) if on else Color(1, 1, 1, 0.08), 8, HUD.C_DEVOTION if on else Color(1, 1, 1, 0.12), 1))

# ---- Construcción ----
func _slider_row(title: String, value: float, setter: Callable) -> Array:
	var head := HBoxContainer.new()
	add_child(head)
	head.add_child(HUD.make_label(title, 14, HUD.C_TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var value_l := HUD.make_label("", 13, HUD.C_MUTED)
	head.add_child(value_l)

	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	s.value = value * 100.0
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(0, 20)
	s.add_theme_stylebox_override("slider", HUD.make_box(HUD.C_TRACK, 4, Color(0, 0, 0, 0), 0, Vector4(0, 4, 0, 4)))
	s.add_theme_stylebox_override("grabber_area", HUD.make_box(HUD.C_DEVOTION, 4, Color(0, 0, 0, 0), 0, Vector4(0, 4, 0, 4)))
	s.add_theme_stylebox_override("grabber_area_highlight", HUD.make_box(HUD.C_DEVOTION.lightened(0.2), 4, Color(0, 0, 0, 0), 0, Vector4(0, 4, 0, 4)))
	s.value_changed.connect(func(v: float):
		setter.call(v / 100.0)
		value_l.text = "%d%%" % roundi(v))
	add_child(s)
	return [s, value_l]

## Título y una fila de botones para elegir uno de ellos (devuelve la fila).
func _choice_row(title: String) -> HBoxContainer:
	add_child(HUD.make_label(title, 14, HUD.C_TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	return row

func _choice(row: HBoxContainer, text: String) -> Button:
	var b := HUD.make_button(text, Color(1, 1, 1, 0.08))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	return b
