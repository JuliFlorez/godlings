extends PanelContainer
class_name VillagerCard
## Carnet del aldeano: se abre con un click sobre él en modo seleccionar.
## Foto tipo carnet con el género abajo, número, y nombre y apellido para escribir
## (se ven arriba de su cabeza, ver NameTag), y su estado: sano, con gripe, curado o muerto.
## Después, cuánto cree en vos y cuánto te teme (ver Villager.faith y fear), y qué es por eso:
## devoto, fanático, hereje o aterrado.
## Abajo, sus relaciones (ver Relations): su pareja, sus amigos y sus enemigos. Un click en
## un nombre abre el carnet de ese aldeano.
## La foto es un rig propio del aldeano (así parpadea) que copia su cara: la boca de
## "¡wow!" si lo tiran por el aire y los ojos en X si está muerto.

const VILLAGER := preload("res://actors/villager/villager.tscn")
const MARGIN := 14.0
const TOP := 196.0               # Debajo del sol...
const BOTTOM := 96.0             # ...y arriba de la barra de poderes (si no entra, sube)
const MAX_NAME := 16
const PHOTO_SIZE := Vector2(104, 124)
const PHOTO_SCALE := 0.15
const PHOTO_FOCUS := Vector2(495, 330)   # Punto del dibujo (px de villager.png) en el centro de la foto
const PHOTO_BG := Color(0.66, 0.82, 0.94)
const PHOTO_FRAME := Color(0.96, 0.97, 1.0)
const GENDERS := {
	Villager.Gender.MALE: "Masculino",
	Villager.Gender.FEMALE: "Femenino",
}
const RELATIONS := [
	[Relations.Kind.COUPLE, "Pareja", Villager.Bubble.HEART],
	[Relations.Kind.FRIEND, "Amigos", Villager.Bubble.SMILE],
	[Relations.Kind.ENEMY, "Enemigos", Villager.Bubble.ANGER],
]
const REL_CAPTION_W := 66.0
## Lo que es según su fe y su miedo: [varón, aldeana, color]
const CREEDS := {
	Villager.Creed.DEVOUT: ["Devoto", "Devota", HUD.C_HOLY],
	Villager.Creed.ZEALOT: ["Fanático", "Fanática", HUD.C_METEOR],
	Villager.Creed.HERETIC: ["Hereje", "Hereje", HUD.C_MUTED],
	Villager.Creed.TERRIFIED: ["Aterrado", "Aterrada", HUD.C_WARN],
}
const C_FAITH := HUD.C_HOLY
const C_FEAR := HUD.C_EVIL
const MAX_LISTED_NAME := 18      # Los nombres más largos se cortan con "…"

var villager: Villager
var _number: Label
var _gender: Label
var _first: LineEdit
var _last: LineEdit
var _photo: Control
var _photo_rig: VillagerRig
var _status: Label
var _creed: Label
var _faith_bar: ProgressBar
var _fear_bar: ProgressBar
var _relations: Array[HFlowContainer] = []   # Una fila por cada tipo de relación (RELATIONS)
var _relations_key := ""        # Lo que se está mostrando: se rearma solo si cambia

func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", HUD.make_box(Color(0.06, 0.09, 0.16, 0.94), 16, HUD.C_PANEL_BORDER, 1, Vector4(16, 12, 16, 16)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(HUD.make_label("Carnet de aldeano", 17, HUD.C_TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(HUD.make_label("N.º", 12, HUD.C_MUTED))
	_number = HUD.make_label("", 14, HUD.C_XP)
	head.add_child(_number)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(4, 0)
	head.add_child(gap)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_stylebox_override("normal", HUD.make_box(Color(1, 1, 1, 0.08), 8))
	close_btn.add_theme_stylebox_override("hover", HUD.make_box(Color(1, 1, 1, 0.18), 8))
	close_btn.add_theme_stylebox_override("pressed", HUD.make_box(Color(1, 1, 1, 0.26), 8))
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)

	# Foto con marco blanco y, abajo, el género
	var photo_col := VBoxContainer.new()
	photo_col.add_theme_constant_override("separation", 0)
	body.add_child(photo_col)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HUD.make_box(PHOTO_FRAME, 6, Color(0, 0, 0, 0), 0, Vector4(4, 4, 4, 4)))
	photo_col.add_child(frame)
	_photo = ColorRect.new()
	_photo.color = PHOTO_BG
	_photo.custom_minimum_size = PHOTO_SIZE
	_photo.clip_contents = true
	frame.add_child(_photo)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 8)
	photo_col.add_child(gap2)
	photo_col.add_child(_caption("Género"))
	_gender = HUD.make_label("", 15, HUD.C_TEXT)
	photo_col.add_child(_gender)

	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(fields)
	_first = _field(fields, "Nombre", "Sin nombre")
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 6)
	fields.add_child(gap3)
	_last = _field(fields, "Apellido", "Sin apellido")
	var gap4 := Control.new()
	gap4.custom_minimum_size = Vector2(0, 6)
	fields.add_child(gap4)
	fields.add_child(_caption("Estado"))
	_status = HUD.make_label("", 15, HUD.C_TEXT)
	fields.add_child(_status)
	_build_creed(col)
	_build_relations(col)
	_first.text_changed.connect(func(t: String):
		if villager:
			villager.first_name = t.strip_edges())
	_last.text_changed.connect(func(t: String):
		if villager:
			villager.last_name = t.strip_edges())
	# Enter pasa del nombre al apellido, y del apellido termina
	_first.text_submitted.connect(func(_t: String): _last.grab_focus())
	_last.text_submitted.connect(func(_t: String): _last.release_focus())

func open(v: Villager) -> void:
	villager = v
	_number.text = "%04d" % v.id_number
	_gender.text = GENDERS[v.gender]
	_first.release_focus()
	_last.release_focus()
	_first.text = v.first_name
	_last.text = v.last_name
	_new_photo()
	_relations_key = "-"   # Que se rearme
	_update_relations()
	visible = true
	_place()

## Arriba a la derecha (con la altura que tenga ahora: cambia con la lista de relaciones).
func _place() -> void:
	reset_size()
	var view := get_viewport_rect().size
	position = Vector2(view.x - size.x - MARGIN, clampf(view.y - BOTTOM - size.y, MARGIN, TOP))

func close() -> void:
	_first.release_focus()
	_last.release_focus()
	visible = false
	villager = null

func _process(_dt: float) -> void:
	if not visible:
		return
	if not is_instance_valid(villager) or villager.is_queued_for_deletion():
		close()   # Se lo comieron, se ahogó o se cayó al vacío
		return
	if villager.rig:
		_photo_rig.copy_face(villager.rig)
	_update_status()
	_update_creed()
	_update_relations()
	_place()

## Sano, incubando la gripe, enfermo, inmune o muerto. En la foto también se lo ve verdoso.
func _update_status() -> void:
	var v := villager
	var text := "Sano"
	var col := HUD.C_SHOP
	if v.dead:
		text = "Muerto"
		col = HUD.C_MUTED
	else:
		match v.flu:
			Villager.Flu.INCUBATING:
				text = "Incubando gripe"
				col = HUD.C_SOON
			Villager.Flu.SICK:
				text = "Enfermo de gripe"
				col = HUD.C_WARN
			Villager.Flu.IMMUNE:
				text = "Curado (inmune)"
				col = HUD.C_DEVOTION
	_status.text = text
	_status.add_theme_color_override("font_color", col)
	_photo_rig.modulate = Color.WHITE.lerp(Color(0.8, 0.97, 0.68), v._flu_tint / Villager.FLU_TINT * 0.7)

## Cuánto cree en vos, cuánto te teme y qué es por eso.
func _update_creed() -> void:
	var v := villager
	_faith_bar.value = v.faith
	_fear_bar.value = v.fear
	var c: Array = CREEDS[v.creed()]
	_creed.text = c[1] if v.gender == Villager.Gender.FEMALE else c[0]
	_creed.add_theme_color_override("font_color", c[2])
	# Muerto ya no siente nada
	_creed.visible = not v.dead
	for bar: ProgressBar in [_faith_bar, _fear_bar]:
		bar.modulate.a = 0.4 if v.dead else 1.0

## Su pareja, sus amigos y sus enemigos (los vivos), con el nombre de cada uno (o su número
## si no tiene) en el color de la relación.
func _update_relations() -> void:
	var lists := {}
	for r: Array in RELATIONS:
		lists[r[0]] = []
	for node in villager.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o.dead or o.eaten or o.is_queued_for_deletion():
			continue
		var k := Relations.kind(villager, o)
		if lists.has(k):
			lists[k].append(o)
	var key := TranslationServer.get_locale()   # Los que no tienen nombre dicen "N.º" en el idioma
	for k in lists:
		lists[k].sort_custom(func(a: Villager, b: Villager): return a.id_number < b.id_number)
		for o: Villager in lists[k]:
			key += "%d:%d:%s;" % [k, o.id_number, o.full_name()]
	if key == _relations_key:
		return
	_relations_key = key
	for i in RELATIONS.size():
		var flow := _relations[i]
		for c in flow.get_children():
			c.queue_free()
		var people: Array = lists[RELATIONS[i][0]]
		if people.is_empty():
			var none := HUD.make_label("—", 14, Color(HUD.C_MUTED, 0.6))
			flow.add_child(none)
		for o: Villager in people:
			flow.add_child(_person_button(o, Relations.color(RELATIONS[i][0])))

## El nombre de alguien con quien tiene una relación: un click abre su carnet.
func _person_button(o: Villager, col: Color) -> Button:
	var b := Button.new()
	var who := o.full_name()
	if who == "":
		who = "%s %04d" % [tr("N.º"), o.id_number]
	elif who.length() > MAX_LISTED_NAME:
		who = who.left(MAX_LISTED_NAME - 1) + "…"
	b.text = who
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Es un nombre
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.35))
	b.add_theme_color_override("font_pressed_color", col.darkened(0.2))
	var pad := Vector4(5, 0, 5, 0)
	b.add_theme_stylebox_override("normal", HUD.make_box(Color(col, 0.1), 6, Color(0, 0, 0, 0), 0, pad))
	b.add_theme_stylebox_override("hover", HUD.make_box(Color(col, 0.22), 6, Color(0, 0, 0, 0), 0, pad))
	b.add_theme_stylebox_override("pressed", HUD.make_box(Color(col, 0.3), 6, Color(0, 0, 0, 0), 0, pad))
	b.pressed.connect(func():
		if is_instance_valid(o):
			open(o))
	return b

func _input(event: InputEvent) -> void:
	# Click afuera del carnet: deja de escribir (si no, G o S escribirían en el nombre)
	if visible and event is InputEventMouseButton and event.pressed \
			and not get_global_rect().has_point(get_global_mouse_position()):
		_first.release_focus()
		_last.release_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

## Un rig nuevo para cada aldeano (el de un muerto ya perdió los párpados).
func _new_photo() -> void:
	if _photo_rig:
		_photo_rig.queue_free()
	var body := VILLAGER.instantiate()
	_photo_rig = body.get_node("Rig")
	body.remove_child(_photo_rig)
	body.free()
	_photo_rig.set_female(villager.gender == Villager.Gender.FEMALE)
	_photo_rig.scale = Vector2.ONE * PHOTO_SCALE
	# El Skeleton2D del rig está en (-512, -512): cada px del dibujo es (px - 512) en el rig
	_photo_rig.position = PHOTO_SIZE * 0.5 - (PHOTO_FOCUS - Vector2(512, 512)) * PHOTO_SCALE
	_photo.add_child(_photo_rig)

# ---- Construcción ----
func _build_creed(parent: Control) -> void:
	_separator(parent)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	parent.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(_caption("Creencia"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_creed = HUD.make_label("", 14, HUD.C_TEXT)
	head.add_child(_creed)
	_faith_bar = _bar(box, "Fe", C_FAITH)
	_fear_bar = _bar(box, "Miedo", C_FEAR)

## Una barrita de 0 a 100 con su nombre adelante.
func _bar(parent: Control, title: String, col: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var caption := HUD.make_label(title, 13, HUD.C_MUTED)
	caption.custom_minimum_size = Vector2(REL_CAPTION_W, 0)
	row.add_child(caption)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", HUD.make_box(HUD.C_TRACK, 5))
	bar.add_theme_stylebox_override("fill", HUD.make_box(col, 5, col.lightened(0.35), 1))
	row.add_child(bar)
	return bar

func _separator(parent: Control) -> void:
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(1, 1, 1, 0.10)
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	parent.add_child(sep)

func _build_relations(parent: Control) -> void:
	_separator(parent)
	var box := VBoxContainer.new()   # Más apretado que el resto del carnet
	box.add_theme_constant_override("separation", 3)
	parent.add_child(box)
	box.add_child(_caption("Relaciones"))
	for r: Array in RELATIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var icon := RelationIcon.new()
		icon.kind = r[2]
		row.add_child(icon)
		var caption := HUD.make_label(r[1], 13, HUD.C_MUTED)
		caption.custom_minimum_size = Vector2(REL_CAPTION_W, 0)
		caption.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(caption)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 3)
		row.add_child(flow)
		_relations.append(flow)

func _caption(text: String) -> Label:
	var l := HUD.make_label(text, 11, HUD.C_MUTED)
	l.uppercase = true   # Mayúsculas al mostrar, así el texto sigue siendo la clave de traducción
	return l

func _field(parent: Control, caption: String, placeholder: String) -> LineEdit:
	parent.add_child(_caption(caption))
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = MAX_NAME
	e.select_all_on_focus = true
	e.custom_minimum_size = Vector2(176, 36)
	e.add_theme_font_size_override("font_size", 15)
	e.add_theme_color_override("font_color", HUD.C_TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(HUD.C_MUTED, 0.45))
	e.add_theme_color_override("caret_color", HUD.C_DEVOTION)
	e.add_theme_color_override("selection_color", Color(HUD.C_DEVOTION, 0.35))
	e.add_theme_stylebox_override("normal", HUD.make_box(Color(1, 1, 1, 0.07), 8, Color(1, 1, 1, 0.12), 1, Vector4(10, 4, 10, 4)))
	e.add_theme_stylebox_override("focus", HUD.make_box(Color(0, 0, 0, 0), 8, HUD.C_DEVOTION, 2))
	parent.add_child(e)
	return e

## El dibujito de cada tipo de relación (ver SpeechBubble.draw_icon).
class RelationIcon extends Control:
	var kind := Villager.Bubble.NONE

	func _ready() -> void:
		custom_minimum_size = Vector2(20, 22)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		SpeechBubble.draw_icon(self, kind, size * 0.5, 0.72)
