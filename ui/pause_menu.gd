extends Control
class_name PauseMenu
## Menú de pausa (Esc): volumen general y de música, idioma, nueva partida y salir del juego.
## Mientras está abierto el juego queda en pausa. Esc no lo abre si la tienda,
## la colocación de decoraciones o la pistola están usando esa tecla.

signal locale_changed

var hud: HUD
var _master_value: Label
var _music_value: Label
var _master_slider: HSlider
var _music_slider: HSlider
var _lang_buttons := {}       # código -> Button
var _actions: Control         # Continuar / Nueva partida / Salir
var _confirm: Control         # "¿Empezar de cero?" antes de borrar la partida

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	panel.add_theme_stylebox_override("panel", HUD.make_box(Color(0.06, 0.09, 0.16, 0.97), 16, HUD.C_PANEL_BORDER, 1, Vector4(22, 18, 22, 20)))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := HUD.make_label("Pausa", 22, HUD.C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var m := _slider_row(col, "Volumen general", Settings.master, Settings.set_master)
	_master_slider = m[0]
	_master_value = m[1]
	var mu := _slider_row(col, "Música", Settings.music, Settings.set_music)
	_music_slider = mu[0]
	_music_value = mu[1]

	col.add_child(HUD.make_label("Idioma", 14, HUD.C_TEXT))
	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 8)
	col.add_child(langs)
	for l: Array in Settings.LOCALES:
		var code: String = l[0]
		var b := _button(l[1], Color(1, 1, 1, 0.08))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Cada idioma con su nombre
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Settings.set_locale(code)
			_sync()
			locale_changed.emit())
		langs.add_child(b)
		_lang_buttons[code] = b

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 12)
	col.add_child(_actions)
	var resume := _button("Continuar", HUD.C_SHOP)
	resume.add_theme_color_override("font_color", Color(0.08, 0.14, 0.08))
	resume.add_theme_color_override("font_hover_color", Color(0.08, 0.14, 0.08))
	resume.pressed.connect(close)
	_actions.add_child(resume)
	var new_game := _button("Nueva partida", Color(1, 1, 1, 0.08))
	new_game.pressed.connect(_show_confirm.bind(true))
	_actions.add_child(new_game)
	var quit := _button("Salir del juego", Color(0.75, 0.25, 0.22))
	quit.pressed.connect(func():
		Settings.save()
		# Igual que cerrar la ventana: así el mundo guarda la partida antes de salir
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		get_tree().quit())
	_actions.add_child(quit)

	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 12)
	col.add_child(_confirm)
	var warn := HUD.make_label("¿Empezar de cero? Se pierden la isla, los aldeanos, las ofrendas y todo lo comprado.", 14, HUD.C_WARN)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.custom_minimum_size = Vector2(296, 0)
	_confirm.add_child(warn)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 8)
	_confirm.add_child(answers)
	var cancel := _button("Cancelar", Color(1, 1, 1, 0.08))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_show_confirm.bind(false))
	answers.add_child(cancel)
	var wipe := _button("Sí, borrar todo", Color(0.75, 0.25, 0.22))
	wipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wipe.pressed.connect(func(): hud.new_game_requested.emit())
	answers.add_child(wipe)

	var note := HUD.make_label("La partida se guarda sola.", 12, HUD.C_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)
	_show_confirm(false)

func open() -> void:
	visible = true
	get_tree().paused = true
	_show_confirm(false)
	_sync()

func close() -> void:
	visible = false
	get_tree().paused = false

func _show_confirm(on: bool) -> void:
	_actions.visible = not on
	_confirm.visible = on

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if visible:
		close()
	elif hud and hud.esc_is_free():
		open()
	else:
		return
	get_viewport().set_input_as_handled()

func _sync() -> void:
	_master_slider.set_value_no_signal(Settings.master * 100.0)
	_music_slider.set_value_no_signal(Settings.music * 100.0)
	_master_value.text = "%d%%" % roundi(Settings.master * 100.0)
	_music_value.text = "%d%%" % roundi(Settings.music * 100.0)
	for code: String in _lang_buttons:
		var on := code == Settings.locale
		var b: Button = _lang_buttons[code]
		b.add_theme_stylebox_override("normal", HUD.make_box(Color(HUD.C_DEVOTION, 0.35) if on else Color(1, 1, 1, 0.08), 8, HUD.C_DEVOTION if on else Color(1, 1, 1, 0.12), 1))

# ---- Construcción ----
func _slider_row(parent: Control, title: String, value: float, setter: Callable) -> Array:
	var head := HBoxContainer.new()
	parent.add_child(head)
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
	parent.add_child(s)
	return [s, value_l]

func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", HUD.make_box(color, 8, color.lightened(0.25), 1))
	b.add_theme_stylebox_override("hover", HUD.make_box(color.lightened(0.15), 8, color.lightened(0.45), 1))
	b.add_theme_stylebox_override("pressed", HUD.make_box(color.darkened(0.15), 8, color.darkened(0.3), 1))
	return b
