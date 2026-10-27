extends PanelContainer
class_name VillagerCard
## Carnet del aldeano: se abre con un click sobre él en modo seleccionar.
## Foto tipo carnet con el género abajo, número, y nombre y apellido para escribir
## (se ven arriba de su cabeza, ver NameTag), y su estado: sano, con gripe, curado o muerto.
## Debajo del estado (que dice si está durmiendo), cuánta hambre tiene (ver Villager.hunger;
## muerto de hambre, en rojo) y cuánto sueño (ver Villager.tiredness).
## Después, cuánto cree en vos y cuánto te teme (ver Villager.faith y fear), y qué es por eso:
## devoto, fanático, hereje o aterrado; y su ánimo (ver Villager.mood): qué tan contento está y
## por qué.
## Abajo, sus relaciones (ver Relations): su pareja, sus amigos y sus enemigos; su familia (sus
## padres y sus hijos, y "Ver árbol" para el árbol genealógico, ver FamilyTree) y su casa (la
## choza donde vive y con quién). Un click en un nombre abre el carnet de ese aldeano, y uno en la
## choza, su cartel (ver HutCard). Los chicos dicen "Nene"
## o "Nena" en vez del género.
## La foto es un rig propio del aldeano (así parpadea) que copia su cara: la boca de
## "¡wow!" si lo tiran por el aire y los ojos en X si está muerto.

const VILLAGER := preload("res://actors/villager/villager.tscn")
const MARGIN := 14.0
const TOP := 196.0               # Debajo del sol...
const BOTTOM := 96.0             # ...y arriba de la barra de poderes (si no entra, sube)
const MAX_NAME := 16
const PHOTO_SIZE := Vector2(96, 112)
const PHOTO_SCALE := 0.138
const PHOTO_FOCUS := Vector2(495, 330)   # Punto del dibujo (px de villager.png) en el centro de la foto
const PHOTO_BG := Color(0.66, 0.82, 0.94)
const PHOTO_FRAME := Color(0.96, 0.97, 1.0)
const GENDERS := {
	Villager.Gender.MALE: "Masculino",
	Villager.Gender.FEMALE: "Femenino",
}
const KIDS := {
	Villager.Gender.MALE: "Nene",
	Villager.Gender.FEMALE: "Nena",
}
const C_FAMILY := Color(1.0, 0.78, 0.45)
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
## Su ánimo: [varón, aldeana, color]
const MOODS := {
	Villager.Mood.DEPRESSED: ["Deprimido", "Deprimida", HUD.C_WARN],
	Villager.Mood.SAD: ["Triste", "Triste", Color(1.0, 0.7, 0.4)],
	Villager.Mood.OK: ["Tranquilo", "Tranquila", HUD.C_MUTED],
	Villager.Mood.CONTENT: ["Contento", "Contenta", Color(0.66, 0.88, 0.5)],
	Villager.Mood.HAPPY: ["Feliz", "Feliz", HUD.C_SHOP],
}
const C_FAITH := HUD.C_HOLY
const C_FEAR := HUD.C_EVIL
const C_HUNGER := HUD.C_FEED
const C_SLEEP := Color(0.6, 0.6, 1.0)
const MAX_LISTED_NAME := 18      # Los nombres más largos se cortan con "…"
const C_HUT := Color(0.9, 0.72, 0.46)

var hud: HUD
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
var _hunger_bar: ProgressBar
var _sleep_bar: ProgressBar
var _mood_bar: ProgressBar
var _mood_label: Label           # Deprimido, triste, tranquilo, contento o feliz...
var _mood_why: Label             # ...y por qué
var _relations: Array[HFlowContainer] = []   # Una fila por cada tipo de relación (RELATIONS)
var _family: HFlowContainer     # Sus padres y sus hijos
var _home: HFlowContainer       # Su choza y los que viven con él
var _relations_key := ""        # Lo que se está mostrando: se rearma solo si cambia

func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", HUD.make_box(Color(0.06, 0.09, 0.16, 0.94), 16, HUD.C_PANEL_BORDER, 1, Vector4(16, 12, 16, 16)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
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
	head.add_child(close_button(close))

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
	photo_col.add_child(caption("Género"))
	_gender = HUD.make_label("", 15, HUD.C_TEXT)
	photo_col.add_child(_gender)

	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(fields)
	_first = field(fields, "Nombre", "Sin nombre")
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 6)
	fields.add_child(gap3)
	_last = field(fields, "Apellido", "Sin apellido")
	var gap4 := Control.new()
	gap4.custom_minimum_size = Vector2(0, 6)
	fields.add_child(gap4)
	fields.add_child(caption("Estado"))
	_status = HUD.make_label("", 15, HUD.C_TEXT)
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Lo traduce _update_status (puede decir dos cosas)
	fields.add_child(_status)
	_hunger_bar = _bar(fields, "Hambre", C_HUNGER)
	_sleep_bar = _bar(fields, "Sueño", C_SLEEP)
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
	_status.text = tr(text)
	if v.is_sleeping() and not v.dead:
		_status.text += " · " + tr("durmiendo")
	_status.add_theme_color_override("font_color", col)
	_gender.text = (KIDS if v.is_child() else GENDERS)[v.gender]   # Crece con el carnet abierto
	_photo_rig.modulate = Color.WHITE.lerp(Color(0.8, 0.97, 0.68), v._flu_tint / Villager.FLU_TINT * 0.7)

## Cuánto cree en vos, cuánto te teme y qué es por eso.
func _update_creed() -> void:
	var v := villager
	_faith_bar.value = v.faith
	_fear_bar.value = v.fear
	_hunger_bar.value = v.hunger
	_sleep_bar.value = v.tiredness
	_sleep_bar.modulate = Color(1.0, 0.55, 0.5) if v.tiredness >= Villager.EXHAUSTED_AT else Color.WHITE
	_mood_bar.value = v.mood
	var m: Array = MOODS[v.mood_level()]
	_mood_label.text = m[1] if v.gender == Villager.Gender.FEMALE else m[0]
	_mood_label.add_theme_color_override("font_color", m[2])
	(_mood_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = m[2]
	_mood_why.text = v.mood_reason()
	_mood_why.visible = _mood_why.text != "" and not v.dead
	_mood_label.visible = not v.dead
	_hunger_bar.modulate = Color(1.0, 0.55, 0.5) if v.starving() else Color.WHITE
	var c: Array = CREEDS[v.creed()]
	_creed.text = c[1] if v.gender == Villager.Gender.FEMALE else c[0]
	_creed.add_theme_color_override("font_color", c[2])
	# Muerto ya no siente nada
	_creed.visible = not v.dead
	for bar: ProgressBar in [_faith_bar, _fear_bar, _hunger_bar, _sleep_bar, _mood_bar]:
		bar.modulate.a = 0.4 if v.dead else 1.0

## Su pareja, sus amigos y sus enemigos (los vivos), con el nombre de cada uno (o su número
## si no tiene) en el color de la relación.
func _update_relations() -> void:
	var lists := {}
	for r: Array in RELATIONS:
		lists[r[0]] = []
	var family: Array[Villager] = []
	for node in villager.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o.dead or o.eaten or o.is_queued_for_deletion():
			continue
		var k := Relations.kind(villager, o)
		if lists.has(k):
			lists[k].append(o)
		if o.id_number in villager.parents or villager.id_number in o.parents:
			family.append(o)
	var housemates: Array[Villager] = []
	if villager._home_ok():
		housemates.assign(villager.home.residents().filter(func(o: Villager): return o != villager))
	var key := TranslationServer.get_locale()   # Los que no tienen nombre dicen "N.º" en el idioma
	for k in lists:
		lists[k].sort_custom(func(a: Villager, b: Villager): return a.id_number < b.id_number)
		for o: Villager in lists[k]:
			key += "%d:%d:%s;" % [k, o.id_number, o.full_name()]
	key += "|%s|%s|%s|" % [villager._home_ok(), villager.inside, villager.home.hut_name if villager._home_ok() else ""]
	for o: Villager in family + housemates:
		key += "%d:%s;" % [o.id_number, o.full_name()]
	if key == _relations_key:
		return
	_relations_key = key
	_fill(_family, family, C_FAMILY)
	if family.is_empty():
		for c in _family.get_children():
			c.queue_free()   # Sin la raya: queda solo "Ver árbol"
	var who := villager.id_number
	_family.add_child(link_button(tr("Ver árbol"), HUD.C_DEVOTION, func():   # Otro color: no es un pariente
		if hud:
			hud.open_family_tree(who)))
	for c in _home.get_children():
		c.queue_free()
	if not villager._home_ok():
		_home.add_child(HUD.make_label("Sin casa", 14, Color(HUD.C_MUTED, 0.6)))
	else:
		var hut := villager.home
		_home.add_child(link_button(HutCard.title_of(hut), C_HUT, func():
			if is_instance_valid(hut) and hud:
				hud.select_hut(hut)))
		if villager.inside:
			_home.add_child(HUD.make_label("adentro", 14, HUD.C_MUTED))
		for o in housemates:
			_home.add_child(_person_button(o, HUD.C_MUTED))
	for i in RELATIONS.size():
		_fill(_relations[i], lists[RELATIONS[i][0]], Relations.color(RELATIONS[i][0]))

## Pone en la fila los nombres de people (o una raya si no hay nadie).
func _fill(flow: HFlowContainer, people: Array, col: Color) -> void:
	for c in flow.get_children():
		c.queue_free()
	if people.is_empty():
		flow.add_child(HUD.make_label("—", 14, Color(HUD.C_MUTED, 0.6)))
	for o: Villager in people:
		flow.add_child(_person_button(o, col))

## El nombre de alguien con quien tiene una relación: un click abre su carnet.
func _person_button(o: Villager, col: Color) -> Button:
	return link_button(listed_name(o), col, func():
		if is_instance_valid(o):
			open(o))

## El nombre para las listas (cortado si es largo), o su número si no tiene.
static func listed_name(o: Villager) -> String:
	var who := o.full_name()
	if who == "":
		return "%s %04d" % [TranslationServer.translate("N.º"), o.id_number]
	if who.length() > MAX_LISTED_NAME:
		return who.left(MAX_LISTED_NAME - 1) + "…"
	return who

## Un nombre en una lista, que se toca (abre el carnet de alguien, o el cartel de una choza).
static func link_button(text: String, col: Color, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
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
	b.pressed.connect(on_pressed)
	return b

## La ✕ para cerrar, arriba a la derecha.
static func close_button(on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = "✕"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(28, 28)
	b.add_theme_stylebox_override("normal", HUD.make_box(Color(1, 1, 1, 0.08), 8))
	b.add_theme_stylebox_override("hover", HUD.make_box(Color(1, 1, 1, 0.18), 8))
	b.add_theme_stylebox_override("pressed", HUD.make_box(Color(1, 1, 1, 0.26), 8))
	b.pressed.connect(on_pressed)
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
	_photo_rig.material = villager.looks_material()   # Su piel y su pelo
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
	head.add_child(caption("Creencia"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_creed = HUD.make_label("", 14, HUD.C_TEXT)
	head.add_child(_creed)
	_faith_bar = _bar(box, "Fe", C_FAITH)
	_fear_bar = _bar(box, "Miedo", C_FEAR)
	_mood_bar = _bar(box, "Ánimo", HUD.C_MUTED)
	_mood_label = HUD.make_label("", 12, HUD.C_TEXT)
	_mood_label.custom_minimum_size = Vector2(70, 0)
	_mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mood_bar.get_parent().add_child(_mood_label)
	var why_row := HBoxContainer.new()   # Abajo de la barrita, corrido como ella
	why_row.add_theme_constant_override("separation", 6)
	box.add_child(why_row)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(REL_CAPTION_W, 0)
	why_row.add_child(indent)
	_mood_why = HUD.make_label("", 12, HUD.C_MUTED)
	_mood_why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mood_why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	why_row.add_child(_mood_why)

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
	box.add_child(caption("Relaciones"))
	for r: Array in RELATIONS:
		_relations.append(_relation_row(box, r[1], r[2]))
	_family = _relation_row(box, "Familia", Villager.Bubble.SUN)
	_home = _relation_row(box, "Casa", Villager.Bubble.NONE, true)

## Una fila: el dibujito, el título y los nombres (devuelve dónde van los nombres). hut: el
## dibujito es una choza.
func _relation_row(box: Control, title: String, bubble: Villager.Bubble, hut := false) -> HFlowContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var icon := RelationIcon.new()
	icon.kind = bubble
	icon.hut = hut
	row.add_child(icon)
	var caption := HUD.make_label(title, 13, HUD.C_MUTED)
	caption.custom_minimum_size = Vector2(REL_CAPTION_W, 0)
	caption.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(caption)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 3)
	row.add_child(flow)
	return flow

static func caption(text: String) -> Label:
	var l := HUD.make_label(text, 11, HUD.C_MUTED)
	l.uppercase = true   # Mayúsculas al mostrar, así el texto sigue siendo la clave de traducción
	return l

static func field(parent: Control, title: String, placeholder: String, max_length := MAX_NAME) -> LineEdit:
	parent.add_child(caption(title))
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_length
	e.select_all_on_focus = true
	e.custom_minimum_size = Vector2(176, 32)
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
	var hut := false              # Una choza chiquita (la fila de la casa)

	func _ready() -> void:
		custom_minimum_size = Vector2(20, 22)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if hut:
			Decoration.paint(self, "hut", 0.5, 0.0, Decoration.ALL_FRUIT, 1.0, "", Vector2(size.x * 0.5, size.y - 2.0), 0.16)
			return
		SpeechBubble.draw_icon(self, kind, size * 0.5, 0.72)
