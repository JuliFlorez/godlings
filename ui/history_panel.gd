extends Control
class_name HistoryPanel
## Historial: quién se hizo amigo, enemigo o pareja de quién (y quiénes hicieron las paces, se
## separaron o dejaron de ser amigos), del más nuevo al más viejo (ver Relations.history).
## Se abre con el botón "Historial" del panel de arriba o con H. Arriba, pestañas para ver
## todo o solo amistades, enemistades o parejas. Un click en un nombre abre el carnet de ese
## aldeano; los que ya no están llevan una cruz.

## Pestañas: [título, eventos que muestra (vacío: todos), tipo de relación (para el color)]
const FILTERS := [
	["Todo", [], Relations.Kind.NONE],
	["Amistades", [Relations.Event.FRIENDS, Relations.Event.DRIFTED], Relations.Kind.FRIEND],
	["Enemistades", [Relations.Event.ENEMIES, Relations.Event.MADE_UP], Relations.Kind.ENEMY],
	["Parejas", [Relations.Event.COUPLE, Relations.Event.BROKE_UP, Relations.Event.BIRTH], Relations.Kind.COUPLE],
]
## Cómo se cuenta cada cosa: [lo que hicieron, dibujito]
const EVENTS := {
	Relations.Event.FRIENDS: ["se hicieron amigos", Villager.Bubble.SMILE],
	Relations.Event.DRIFTED: ["dejaron de ser amigos", Villager.Bubble.DOTS],
	Relations.Event.ENEMIES: ["se hicieron enemigos", Villager.Bubble.ANGER],
	Relations.Event.MADE_UP: ["hicieron las paces", Villager.Bubble.SUN],
	Relations.Event.COUPLE: ["se pusieron de novios", Villager.Bubble.HEART],
	Relations.Event.BROKE_UP: ["se separaron", Villager.Bubble.TEAR],
	Relations.Event.BIRTH: ["tuvieron un bebé", Villager.Bubble.HEART],
}
const LIST_SIZE := Vector2(540, 330)
const TIME_W := 76.0
const MAX_NAME := 18             # Los nombres más largos se cortan con "…"
const REFRESH := 0.5             # Cada cuánto se fija si cambió algo (y actualiza el "hace...")
const EMPTY := "Todavía no pasó nada. Cuando dos aldeanos charlan se van haciendo amigos o enemigos, y acá queda anotado."
const EMPTY_FILTER := "Nada de esto todavía."

var hud: HUD
var _filter := 0
var _tabs: Array[Button] = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _times: Array = []           # [Label, segundos jugados] de cada fila
var _key := ""                   # Lo que se está mostrando: se rearma solo si cambia
var _refresh_t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Fondo oscurecido: click afuera del panel cierra
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HUD.make_box(Color(0.06, 0.09, 0.16, 0.96), 16, HUD.C_PANEL_BORDER, 1, Vector4(18, 16, 18, 18)))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(HUD.make_label("Historial", 20, HUD.C_TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_stylebox_override("normal", HUD.make_box(Color(1, 1, 1, 0.08), 8))
	close_btn.add_theme_stylebox_override("hover", HUD.make_box(Color(1, 1, 1, 0.18), 8))
	close_btn.add_theme_stylebox_override("pressed", HUD.make_box(Color(1, 1, 1, 0.26), 8))
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	col.add_child(HUD.make_label("Quién se hizo amigo, enemigo o pareja de quién.", 12, HUD.C_MUTED))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for i in FILTERS.size():
		var b := Button.new()
		b.text = FILTERS[i][0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_set_filter.bind(i))
		tabs.add_child(b)
		_tabs.append(b)

	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(1, 1, 1, 0.10)
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	col.add_child(sep)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = LIST_SIZE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var margin := MarginContainer.new()   # Que el "hace..." no quede pegado a la barra
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	_scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	margin.add_child(_list)
	_set_filter(0)

func open() -> void:
	visible = true
	_key = ""   # Que se rearme
	_scroll.scroll_vertical = 0
	_update()

func close() -> void:
	visible = false

func _process(dt: float) -> void:
	if not visible:
		return
	_refresh_t -= dt
	if _refresh_t <= 0.0:
		_update()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _set_filter(i: int) -> void:
	_filter = i
	for j in _tabs.size():
		var b := _tabs[j]
		var on := j == i
		var c := Relations.color(FILTERS[j][2])
		var pad := Vector4(12, 2, 12, 2)
		var box := HUD.make_box(Color(c, 0.24), 8, Color(c, 0.8), 2, pad) if on \
				else HUD.make_box(Color(1, 1, 1, 0.06), 8, Color(1, 1, 1, 0.10), 1, pad)
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box if on else HUD.make_box(Color(c, 0.14), 8, Color(c, 0.5), 1, pad))
		b.add_theme_stylebox_override("pressed", box)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(state, c if on else HUD.C_MUTED)
	if _scroll:
		_scroll.scroll_vertical = 0
	if visible:
		_update()

## Rearma la lista si cambió algo (otro evento, otra pestaña, otro idioma, alguien al que le
## pusieron nombre o que ya no está), y actualiza el "hace...".
func _update() -> void:
	_refresh_t = REFRESH
	var alive := {}   # carnet -> Villager
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and not v.dead and not v.eaten and not v.is_queued_for_deletion():
			alive[v.id_number] = v
	var only: Array = FILTERS[_filter][1]
	var shown: Array[Dictionary] = []
	var key := "%d;%d;%s;" % [Relations.history_version, _filter, TranslationServer.get_locale()]
	for i in range(Relations.history.size() - 1, -1, -1):
		var e := Relations.history[i]
		if not EVENTS.has(e.event) or not (only.is_empty() or only.has(e.event)):
			continue
		shown.append(e)
		for id: int in [e.a, e.b]:
			var v: Villager = alive.get(id)
			key += "%d:%s;" % [id, v.full_name() if v else "†"]
	if key != _key:
		_key = key
		_rebuild(shown, alive)
	for t: Array in _times:
		t[0].text = _ago(t[1])

func _rebuild(shown: Array[Dictionary], alive: Dictionary) -> void:
	for c in _list.get_children():
		c.queue_free()
	_times.clear()
	if shown.is_empty():
		var l := HUD.make_label(EMPTY if Relations.history.is_empty() else EMPTY_FILTER, 13, HUD.C_MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(LIST_SIZE.x - 20.0, 0)
		_list.add_child(l)
		return
	for e in shown:
		_list.add_child(_row(e, alive))

## "😊 Ana y Pedro se hicieron amigos ........ hace 2 min"
func _row(e: Dictionary, alive: Dictionary) -> Control:
	var info: Array = EVENTS[e.event]
	var col := _color(e.event)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := EventIcon.new()
	icon.kind = info[1]
	row.add_child(icon)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 2)
	row.add_child(flow)
	var b := _person(e.b, e.get("b_name", ""), alive, col)
	flow.add_child(_person(e.a, e.get("a_name", ""), alive, col))
	flow.add_child(HUD.make_label(_and(b.text), 14, HUD.C_TEXT))
	flow.add_child(b)
	flow.add_child(HUD.make_label(info[0], 14, HUD.C_TEXT))
	var time := HUD.make_label("", 12, HUD.C_MUTED)
	time.custom_minimum_size = Vector2(TIME_W, 24)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(time)
	_times.append([time, e.time])
	return row

## El nombre de alguien (o su número, si no tiene). Si sigue vivo, un click abre su carnet; si
## no, va apagado y con una cruz.
func _person(id: int, saved_name: String, alive: Dictionary, col: Color) -> Button:
	var v: Villager = alive.get(id)
	var who := v.full_name() if v else saved_name
	if who == "":
		who = "%s %04d" % [tr("N.º"), id]
	elif who.length() > MAX_NAME:
		who = who.left(MAX_NAME - 1) + "…"
	var b := Button.new()
	b.text = who if v else who + " †"
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Es un nombre
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	var pad := Vector4(5, 0, 5, 0)
	if v == null:
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", Color(col, 0.5))
		b.add_theme_stylebox_override("disabled", HUD.make_box(Color(1, 1, 1, 0.05), 6, Color(0, 0, 0, 0), 0, pad))
		return b
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.35))
	b.add_theme_color_override("font_pressed_color", col.darkened(0.2))
	b.add_theme_stylebox_override("normal", HUD.make_box(Color(col, 0.1), 6, Color(0, 0, 0, 0), 0, pad))
	b.add_theme_stylebox_override("hover", HUD.make_box(Color(col, 0.22), 6, Color(0, 0, 0, 0), 0, pad))
	b.add_theme_stylebox_override("pressed", HUD.make_box(Color(col, 0.3), 6, Color(0, 0, 0, 0), 0, pad))
	b.pressed.connect(func():
		if is_instance_valid(v):
			close()
			hud.select_villager(v))
	return b

## El color de cada cosa, el mismo del cartel que sale cuando pasa (ver Villager._finish_chat).
static func _color(ev: Relations.Event) -> Color:
	match ev:
		Relations.Event.FRIENDS:
			return Relations.color(Relations.Kind.FRIEND)
		Relations.Event.ENEMIES:
			return Relations.color(Relations.Kind.ENEMY)
		Relations.Event.COUPLE, Relations.Event.BIRTH:
			return Relations.color(Relations.Kind.COUPLE)
		Relations.Event.MADE_UP:
			return HUD.C_DEVOTION
	return HUD.C_MUTED

## "y", que en castellano antes de i se vuelve "e" (Ana e Isabel, pero Ana y Hierro).
func _and(next: String) -> String:
	var w := next.to_lower().trim_prefix("h")
	if TranslationServer.get_locale().begins_with("es") and (w.begins_with("i") or w.begins_with("í")) \
			and not w.substr(1, 1) in ["a", "e", "o", "u"]:
		return "e"
	return tr("y")

## Cuánto hace (en tiempo jugado).
func _ago(t: float) -> String:
	var s := World.play_time - t
	if s < 60.0:
		return tr("recién")
	if s < 3600.0:
		return tr("hace %d min") % int(s / 60.0)
	return tr("hace %d h") % int(s / 3600.0)

## El dibujito de lo que pasó, en un globito redondo como los de las charlas (ver SpeechBubble).
class EventIcon extends Control:
	var kind := Villager.Bubble.NONE

	func _ready() -> void:
		custom_minimum_size = Vector2(24, 24)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 12.0, SpeechBubble.BG.get(kind, SpeechBubble.C_BG), true, -1.0, true)
		SpeechBubble.draw_icon(self, kind, size * 0.5, 0.62)
