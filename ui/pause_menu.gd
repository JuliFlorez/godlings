extends Control
class_name PauseMenu
## Menú de pausa (Esc): las opciones (volumen, idioma y pantalla, ver SettingsPanel),
## volver al menú de inicio y salir del juego. Mientras está abierto el juego queda en
## pausa. Esc no lo abre si la tienda, la colocación de decoraciones o la pistola están
## usando esa tecla.

signal locale_changed

var hud: HUD
var _options: SettingsPanel

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

	_options = SettingsPanel.new()
	_options.locale_changed.connect(locale_changed.emit)
	col.add_child(_options)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)
	var resume := HUD.make_button("Continuar", HUD.C_SHOP)
	resume.add_theme_color_override("font_color", Color(0.08, 0.14, 0.08))
	resume.add_theme_color_override("font_hover_color", Color(0.08, 0.14, 0.08))
	resume.pressed.connect(close)
	col.add_child(resume)
	# Guarda y vuelve al cielo, a elegir partida (ver World._to_title)
	var menu := HUD.make_button("Menú principal", Color(1, 1, 1, 0.08))
	menu.pressed.connect(func(): hud.menu_requested.emit())
	col.add_child(menu)
	var quit := HUD.make_button("Salir del juego", Color(0.75, 0.25, 0.22))
	quit.pressed.connect(func():
		Settings.save()
		# Igual que cerrar la ventana: así el mundo guarda la partida antes de salir
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		get_tree().quit())
	col.add_child(quit)

	var note := HUD.make_label("La partida se guarda sola.", 12, HUD.C_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)

func open() -> void:
	visible = true
	get_tree().paused = true
	_options.sync()

func close() -> void:
	visible = false
	get_tree().paused = false

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
