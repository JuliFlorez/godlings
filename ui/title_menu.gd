extends CanvasLayer
class_name TitleMenu
## Menú de inicio: flota en el cielo, sobre el colchón de nubes (ver CloudBank), con el
## logo, Jugar (elegir una de las partidas, ver SaveSlots), Configuración y Salir.
## Al elegir una partida emite slot_chosen y el mundo baja la cámara hasta la isla (ver
## World.lift); un click o una tecla mientras baja la apura (skip_requested).
## Mientras está abierto, y hasta que la cámara llega, el juego no recibe ni el teclado ni
## el mouse. Arriba de todo va el telón negro de los fundidos (al abrir el juego y al
## volver al menú desde la pausa).

signal slot_chosen(slot: int)
signal skip_requested

enum Mode { MENU, DESCENT, PLAYING, CLOSING }

const OPEN_FADE := 1.0            # Telón al abrir el juego
const SCREEN_FADE := 0.2          # Al cambiar de pantalla
const LEAVE_FADE := 0.6           # El menú se desvanece al empezar a bajar
const CARD_W := 224.0
const PREVIEW_SIZE := Vector2(200, 112)   # La pantalla del juego en chiquito (16:9)
const C_PANEL := Color(0.06, 0.09, 0.16, 0.94)
const C_FLOATING := Color(0.1, 0.14, 0.24, 0.95)   # Botón suelto sobre el cielo y las nubes
const C_QUIT := Color(0.75, 0.25, 0.22)
const C_PLAY_TEXT := Color(0.08, 0.14, 0.08)
const C_OUTLINE := Color(0.04, 0.12, 0.3, 0.8)

## Para dibujar la isla en las miniaturas de las partidas.
var world: World
## Telón negro de los fundidos (ataja el mouse mientras tapa).
var curtain: ColorRect
var _mode := Mode.PLAYING
var _root: Control                # Todo el menú: ataja el mouse
var _content: Control             # Logo y pantallas (se desvanece al bajar)
var _catcher: Control             # Mientras baja la cámara: ataja los clicks y los usa para apurarla
var _main: Control
var _slots: Control
var _cards: HBoxContainer
var _options: Control
var _options_panel: SettingsPanel
var _current: Control

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS   # El fundido al volver al menú es con el juego en pausa

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 24.0
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	_root.add_child(col)
	_content = col

	var logo := Logo.new()
	logo.custom_minimum_size = Vector2(0, 130)
	col.add_child(logo)
	var tagline := HUD.make_label("Cuidá (o sacrificá) a tus aldeanos", 18, HUD.C_TEXT)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_outline_color", C_OUTLINE)
	tagline.add_theme_constant_override("outline_size", 6)
	col.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	_main = _build_main()
	_slots = _build_slots()
	_options = _build_options()
	for screen: Control in [_main, _slots, _options]:
		screen.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		screen.visible = false
		col.add_child(screen)

	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.visible = false
	_catcher.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			skip_requested.emit())
	_root.add_child(_catcher)

	curtain = ColorRect.new()
	curtain.color = Color(0, 0, 0, 0)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)

## Al arrancar el juego: el menú aparece desde negro.
func open() -> void:
	_mode = Mode.MENU
	_root.visible = true
	_show(_main)
	curtain.color.a = 1.0
	create_tween().tween_property(curtain, "color:a", 0.0, OPEN_FADE)

## La cámara llegó a la isla: el juego vuelve a recibir el teclado y el mouse.
func landed() -> void:
	_mode = Mode.PLAYING
	_root.visible = false

## Funde a negro (al volver al menú desde la pausa); mientras, el juego no recibe nada.
func fade_out(duration: float) -> Tween:
	_mode = Mode.CLOSING
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(curtain, "color:a", 1.0, duration)
	return tw

func _input(event: InputEvent) -> void:
	if _mode == Mode.PLAYING or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()   # Ninguna tecla llega al juego (ni Esc a la pausa)
	if not event.pressed or event.echo:
		return
	if _mode == Mode.DESCENT:
		skip_requested.emit()
	elif _mode == Mode.MENU and event.keycode == KEY_ESCAPE and _current != _main:
		_show(_main)

func _show(screen: Control) -> void:
	if _current:
		_current.visible = false
	_current = screen
	screen.visible = true
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, SCREEN_FADE)

func _choose(slot: int) -> void:
	if _mode != Mode.MENU:   # Doble click: ya está bajando
		return
	_mode = Mode.DESCENT
	_catcher.visible = true
	create_tween().tween_property(_content, "modulate:a", 0.0, LEAVE_FADE)
	slot_chosen.emit(slot)

# ---- Pantallas ----
func _build_main() -> Control:
	var panel := _panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(250, 0)
	panel.add_child(col)
	var play := _play_button("Jugar")
	play.custom_minimum_size = Vector2(0, 46)
	play.add_theme_font_size_override("font_size", 18)
	play.pressed.connect(func():
		_fill_cards()
		_show(_slots))
	col.add_child(play)
	var options := HUD.make_button("Configuración", Color(1, 1, 1, 0.08))
	options.pressed.connect(func():
		_options_panel.sync()
		_show(_options))
	col.add_child(options)
	var quit := HUD.make_button("Salir", C_QUIT)
	quit.pressed.connect(func():
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		get_tree().quit())
	col.add_child(quit)
	return panel

func _build_slots() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 14)
	col.add_child(_cards)
	var back := HUD.make_button("Volver", C_FLOATING)
	back.custom_minimum_size = Vector2(170, 38)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): _show(_main))
	col.add_child(back)
	return col

func _build_options() -> Control:
	var panel := _panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(320, 0)
	panel.add_child(col)
	var title := HUD.make_label("Configuración", 20, HUD.C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_options_panel = SettingsPanel.new()
	col.add_child(_options_panel)
	var back := HUD.make_button("Volver", Color(1, 1, 1, 0.08))
	back.pressed.connect(func(): _show(_main))
	col.add_child(back)
	return panel

# ---- Partidas ----
## Una tarjeta por partida, con lo que tiene guardado cada una.
func _fill_cards() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)   # Ya, para que no ocupen lugar hasta que se liberen
		c.queue_free()
	var latest := SaveSlots.latest()
	for slot in range(1, SaveSlots.COUNT + 1):
		_cards.add_child(_card(slot, SaveSlots.summary(slot), slot == latest))

func _card(slot: int, info: Dictionary, latest: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.add_theme_stylebox_override("panel", HUD.make_box(C_PANEL, 14, HUD.C_XP if latest else HUD.C_PANEL_BORDER,
			2 if latest else 1, Vector4(12, 10, 12, 12)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(HUD.make_label(tr("Partida %d") % slot, 16, HUD.C_TEXT))
	if latest:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(spacer)
		head.add_child(HUD.make_label("Última jugada", 11, HUD.C_XP))

	var preview := SlotPreview.new()
	preview.world = world
	preview.info = info
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(preview)

	if info.is_empty():
		var empty := HUD.make_label("Vacía", 16, HUD.C_TEXT)
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_outline_color", C_OUTLINE)
		empty.add_theme_constant_override("outline_size", 5)
		preview.add_child(empty)
		col.add_child(_filler())
		var start := _play_button("Nueva partida")
		start.pressed.connect(_choose.bind(slot))
		col.add_child(start)
		return card

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	col.add_child(stats)
	_chip(stats, "villager", str(info.villagers), "Aldeanos")
	_chip(stats, "island", "%d / %d" % [info.level + 1, World.ISLAND_LEVELS.size()], "Isla")
	_chip(stats, "coin", str(info.offerings), "Ofrendas")
	var last_played := HUD.make_label(_last_played(info), 12, HUD.C_MUTED)
	last_played.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Ya viene traducido
	col.add_child(last_played)
	col.add_child(_filler())

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	col.add_child(actions)
	var play := _play_button("Jugar")
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(_choose.bind(slot))
	actions.add_child(play)
	var delete_btn := HUD.make_button("Borrar", C_QUIT)
	delete_btn.custom_minimum_size = Vector2(74, 38)
	actions.add_child(delete_btn)

	# Antes de borrar, pregunta (en la misma tarjeta)
	var confirm := VBoxContainer.new()
	confirm.add_theme_constant_override("separation", 8)
	confirm.visible = false
	col.add_child(confirm)
	var warn := HUD.make_label("¿Borrar esta partida? No se puede deshacer.", 13, HUD.C_WARN)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.custom_minimum_size = Vector2(CARD_W - 24.0, 0)
	confirm.add_child(warn)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 8)
	confirm.add_child(answers)
	var cancel := HUD.make_button("Cancelar", Color(1, 1, 1, 0.08))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answers.add_child(cancel)
	var wipe := HUD.make_button("Borrar", C_QUIT)
	wipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answers.add_child(wipe)

	delete_btn.pressed.connect(func():
		actions.visible = false
		confirm.visible = true)
	cancel.pressed.connect(func():
		actions.visible = true
		confirm.visible = false)
	wipe.pressed.connect(func():
		SaveSlots.delete(slot)
		_fill_cards())
	return card

## Ícono y número (aldeanos, tamaño de la isla, ofrendas).
func _chip(parent: Control, icon: String, value: String, tip: String) -> void:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.tooltip_text = tip
	chip.add_theme_stylebox_override("panel", HUD.make_box(Color(1, 1, 1, 0.06), 8, Color(0, 0, 0, 0), 0, Vector4(6, 5, 6, 5)))
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(HUD.HudIcon.make(icon, 14))
	row.add_child(HUD.make_label(value, 14, HUD.C_TEXT))

## Cuándo se jugó por última vez ("Hoy, 14:32", "Ayer, 09:05" o la fecha) y cuánto en total.
func _last_played(info: Dictionary) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60   # A la hora de acá
	var saved := int(info.saved_at) + bias
	var d := Time.get_datetime_dict_from_unix_time(saved)
	var days := floori((Time.get_unix_time_from_system() + bias) / 86400.0) - floori(saved / 86400.0)
	var hour := "%02d:%02d" % [d.hour, d.minute]
	var text: String
	if days == 0:
		text = tr("Hoy, %s") % hour
	elif days == 1:
		text = tr("Ayer, %s") % hour
	elif Settings.locale == "en":
		text = "%d/%d/%d" % [d.month, d.day, d.year]
	else:
		text = "%d/%d/%d" % [d.day, d.month, d.year]
	var minutes := floori(info.play_time / 60.0)
	if minutes >= 60:
		text += " · %d h %02d min" % [floori(minutes / 60.0), minutes % 60]
	elif minutes > 0:
		text += " · %d min" % minutes
	return text

# ---- Piezas ----
func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HUD.make_box(C_PANEL, 16, HUD.C_PANEL_BORDER, 1, Vector4(20, 18, 20, 20)))
	return p

## Botón verde de jugar, con el texto oscuro (como "Continuar" en la pausa).
func _play_button(text: String) -> Button:
	var b := HUD.make_button(text, HUD.C_SHOP)
	b.add_theme_color_override("font_color", C_PLAY_TEXT)
	b.add_theme_color_override("font_hover_color", C_PLAY_TEXT)
	b.add_theme_color_override("font_pressed_color", C_PLAY_TEXT)
	return b

## Ocupa el lugar que sobra (así los botones de todas las tarjetas quedan a la misma altura).
func _filler() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## "Godlings" con las letras que suben y bajan de a una, como flotando.
class Logo extends Control:
	const TEXT := "Godlings"
	const FONT_SIZE := 100
	const FILL := Color(1.0, 0.86, 0.36)
	const EDGE := Color(0.42, 0.2, 0.05)
	const SHADOW := Color(0.02, 0.1, 0.3, 0.3)
	var _font := FontVariation.new()
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font.base_font = get_theme_default_font()
		_font.variation_embolden = 0.9

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var widths: Array[float] = []
		var total := 0.0
		for ch in TEXT:
			widths.append(_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
			total += widths[-1]
		var x := (size.x - total) * 0.5
		var base := (size.y + _font.get_ascent(FONT_SIZE) - _font.get_descent(FONT_SIZE)) * 0.5
		for i in TEXT.length():
			var p := Vector2(x, base + sin(_t * 1.8 - i * 0.55) * 5.0)
			draw_string_outline(_font, p + Vector2(0, 7), TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 16, SHADOW)
			draw_string_outline(_font, p, TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 14, EDGE)
			draw_string(_font, p, TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, FILL)
			x += widths[i]

## Miniatura de una partida: la pantalla del juego en chiquito, de día o de noche (o con
## la Luna de Sangre), con la isla del tamaño que tiene. Sin partida, solo cielo y mar.
class SlotPreview extends Control:
	const SKY_DAY := Color(0.035, 0.627, 1.0)     # Como el cielo (Sky)
	const SKY_NIGHT := Color(0.04, 0.05, 0.16)
	const SKY_BLOOD := Color(0.4, 0.04, 0.06)
	const SEA := Color(0.1, 0.5, 0.88)            # Entre los azules de water.gdshader
	const NIGHT_TINT := Color(0.38, 0.42, 0.7)    # Como el tinte de la noche (Sky)
	const BLOOD_TINT := Color(0.62, 0.4, 0.45)
	const SUN := Color(1.0, 0.78, 0.3)
	const MOON := Color(0.93, 0.93, 0.86)
	const BLOOD_MOON := Color(0.85, 0.2, 0.15)
	const STARS := [Vector2(0.08, 0.2), Vector2(0.2, 0.55), Vector2(0.31, 0.15), Vector2(0.45, 0.4),
			Vector2(0.58, 0.12), Vector2(0.66, 0.62), Vector2(0.94, 0.75), Vector2(0.38, 0.8)]

	var world: World
	var info: Dictionary

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		var sky = world.get_node("Sky")
		var k := size.x / world.get_viewport_rect().size.x   # De la pantalla del juego a la miniatura
		var horizon: float = sky.horizon_y * k
		var night: bool = info.get("night", false)
		var blood: bool = night and info.get("blood_moon", false)
		var tint := Color.WHITE
		var sky_color := SKY_DAY
		if night:
			tint = BLOOD_TINT if blood else NIGHT_TINT
			sky_color = SKY_BLOOD if blood else SKY_NIGHT
		draw_style_box(HUD.make_box(sky_color, 8), Rect2(Vector2.ZERO, size))

		if night:
			for s: Vector2 in STARS:
				draw_circle(s * Vector2(size.x, horizon), 0.9, Color(1, 1, 0.9, 0.85))
		var astro = sky.moon if night else sky.sun
		var at: Vector2 = astro.rest_pos * k
		var r: float = astro.radius * k
		if night:
			draw_circle(at, r * 0.8, BLOOD_MOON if blood else MOON, true, -1.0, true)
		else:
			draw_circle(at, r * 1.7, Color(SUN, 0.25), true, -1.0, true)
			draw_circle(at, r, SUN, true, -1.0, true)

		var sea := HUD.make_box(SEA * tint, 8)
		sea.corner_radius_top_left = 0
		sea.corner_radius_top_right = 0
		draw_style_box(sea, Rect2(0.0, horizon, size.x, size.y - horizon))
		draw_line(Vector2(0.0, horizon), Vector2(size.x, horizon), Color(1, 1, 1, 0.5) * tint, 1.0)

		if not info.is_empty():
			var isle := world.island_rect(info.level)
			draw_texture_rect(world.isle_sprite.texture, Rect2(isle.position * k, isle.size * k), false, tint)
