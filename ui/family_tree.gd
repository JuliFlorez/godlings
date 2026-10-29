extends Control
class_name FamilyTree
## Árbol genealógico de un aldeano (vivo o muerto, ver Genealogy): arriba sus abuelos y sus
## padres, en el medio él con sus hermanos y su pareja, y abajo sus hijos y sus nietos, unidos
## con líneas (las parejas, con un corazón si siguen juntas o estaban juntas cuando se murió uno).
## Cada uno con su foto (los muertos, con los ojos en X) y su nombre (con una cruz si ya no
## está). Tocando a alguien se ve su familia; "Ver carnet" abre el carnet del que se está viendo
## (si vive). Se abre desde el carnet (ver VillagerCard); Esc, ✕ o un click afuera lo cierran.

const SLOT := Vector2(96, 100)   # Lo que ocupa cada uno (ancho) y cada generación (alto)
const PHOTO := 60.0
const PHOTO_SCALE := 0.085
const PHOTO_FOCUS := Vector2(500, 300)   # Px de villager.png en el medio de la foto (la cara)
const NAME_Y := PHOTO + 5.0
const AREA := Vector2(900, 450)  # Lo más grande que puede ser el árbol (si no entra, se achica)
const MAX_NAME := 12
const C_LINE := Color(1, 1, 1, 0.35)
const C_ALIVE := Color(0.66, 0.82, 0.94)   # El fondo de la foto: el cielo, como en el carnet
const C_DEAD := Color(0.4, 0.42, 0.48)
const C_UNKNOWN := Color(0.24, 0.27, 0.34)
const VILLAGER := preload("res://actors/villager/villager.tscn")

var hud: HUD
var focus := 0                   # El carnet del que se está viendo la familia
var _name: Label
var _card_btn: Button
var _area: Control               # Del tamaño del árbol (achicado si hace falta)
var _canvas: Canvas              # La gente y las líneas que los unen

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
	panel.add_theme_stylebox_override("panel", HUD.make_box(Color(0.06, 0.09, 0.16, 0.96), 16, HUD.C_PANEL_BORDER, 1, Vector4(18, 14, 18, 18)))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(HUD.make_label("Árbol genealógico", 20, HUD.C_TEXT))
	_name = HUD.make_label("", 16, VillagerCard.C_FAMILY)
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Es un nombre
	head.add_child(_name)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_card_btn = VillagerCard.link_button(tr("Ver carnet"), HUD.C_TEXT, func():
		var p := Genealogy.person(get_tree(), focus)
		if p.get("villager") and hud:
			close()
			hud.select_villager(p.villager))
	head.add_child(_card_btn)
	head.add_child(VillagerCard.close_button(close))
	col.add_child(HUD.make_label("Tocá a alguien para ver su familia.", 12, HUD.C_MUTED))

	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(1, 1, 1, 0.10)
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	col.add_child(sep)

	var holder := CenterContainer.new()   # El árbol, centrado en el panel
	holder.custom_minimum_size = Vector2(AREA.x, 0)
	col.add_child(holder)
	_area = Control.new()
	holder.add_child(_area)
	_canvas = Canvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(_canvas)

## Abre el árbol de la familia de id.
func open(id: int) -> void:
	visible = true
	_show(id)

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

## Arma el árbol alrededor de id.
func _show(id: int) -> void:
	focus = id
	for c in _canvas.get_children():
		c.queue_free()
	var tree := get_tree()
	var me := Genealogy.person(tree, id)
	_name.text = _full_name(me, id)
	_card_btn.visible = me.get("villager") != null

	# Quiénes: sus padres (y los de ellos), sus hermanos, su pareja, sus hijos y sus nietos
	var parents := _parents_of(me)
	var grand := {}   # Padre -> sus padres
	for p in parents:
		grand[p] = _parents_of(Genealogy.person(tree, p))
	var any_grand := grand.values().any(func(g: Array): return not g.is_empty())
	var siblings: Array[int] = []
	if not parents.is_empty():
		for k in Genealogy.children_of(tree, parents[0]):
			if k != id and (parents.size() < 2 or k in Genealogy.children_of(tree, parents[1])):
				siblings.append(k)
	var kids := Genealogy.children_of(tree, id)
	var partner := _partner_of(me, kids)
	var grandkids := {}   # Hijo -> sus hijos
	var any_grandkids := false
	for k in kids:
		grandkids[k] = Genealogy.children_of(tree, k)
		any_grandkids = any_grandkids or not grandkids[k].is_empty()

	# Dónde va cada uno: x en lugares (él en 0), y en generaciones (0: sus abuelos)
	var at := {}
	at[id] = Vector2(0, 2)
	for i in siblings.size():
		at[siblings[siblings.size() - 1 - i]] = Vector2(-1 - i, 2)   # Los más grandes, más a la izquierda
	if partner:
		at[partner] = Vector2(1, 2)
	var group := -siblings.size() * 0.5   # El medio de él y sus hermanos
	var spread := 1.0 if any_grand else 0.5
	for i in parents.size():
		var px := group + (0.0 if parents.size() == 1 else (-spread if i == 0 else spread))
		at[parents[i]] = Vector2(px, 1)
		var gp: Array = grand[parents[i]]
		for j in gp.size():
			at[gp[j]] = Vector2(px + (0.0 if gp.size() == 1 else (-0.5 if j == 0 else 0.5)), 0)
	var mid := 0.5 if partner else 0.0
	var width := 0.0
	for k in kids:
		width += maxf(1.0, grandkids[k].size())
	var edge := mid - width * 0.5
	for k in kids:
		var w := maxf(1.0, grandkids[k].size())
		at[k] = Vector2(edge + w * 0.5 - 0.5, 3)
		for j in grandkids[k].size():
			at[grandkids[k][j]] = Vector2(edge + j, 4)
		edge += w

	# A píxeles (sin las generaciones que no hay)
	var top := 0 if any_grand else (1 if not parents.is_empty() else 2)
	var bottom := 4 if any_grandkids else (3 if not kids.is_empty() else 2)
	var min_x := INF
	var max_x := -INF
	for k: int in at:
		min_x = minf(min_x, at[k].x)
		max_x = maxf(max_x, at[k].x)
	var spot := {}   # carnet -> arriba a la izquierda de su lugar (px)
	for k: int in at:
		spot[k] = Vector2((at[k].x - min_x) * SLOT.x, (at[k].y - top) * SLOT.y)
		var person := Person.new()
		person.id = k
		person.info = Genealogy.person(tree, k)
		person.is_focus = k == id
		person.position = spot[k]
		person.picked.connect(_show)
		_canvas.add_child(person)

	# Las líneas: las parejas y de los padres a los hijos
	_canvas.couples.clear()
	_canvas.descents.clear()
	_canvas.spots = spot
	if partner:
		_canvas.couples.append([id, partner, _together(id, partner)])
	if parents.size() == 2:
		_canvas.couples.append([parents[0], parents[1], _together(parents[0], parents[1])])
	if not parents.is_empty():
		_canvas.descents.append([parents, siblings + [id]])
	for p in parents:
		var gp: Array = grand[p]
		if gp.size() == 2:
			_canvas.couples.append([gp[0], gp[1], _together(gp[0], gp[1])])
		if not gp.is_empty():
			_canvas.descents.append([gp, [p]])
	if not kids.is_empty():
		_canvas.descents.append([[id, partner] if partner else [id], kids])
	for k in kids:
		if not grandkids[k].is_empty():
			_canvas.descents.append([[k], grandkids[k]])

	var tree_size := Vector2((max_x - min_x + 1.0) * SLOT.x, (bottom - top + 1) * SLOT.y - (SLOT.y - NAME_Y - 18.0))
	var s := minf(1.0, minf(AREA.x / tree_size.x, AREA.y / tree_size.y))
	_canvas.size = tree_size
	_canvas.scale = Vector2.ONE * s
	_area.custom_minimum_size = tree_size * s
	_canvas.queue_redraw()

## Sus padres (los que se saben), primero el papá.
func _parents_of(p: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if p.is_empty():
		return out
	for k: int in p.parents:
		out.append(k)
	var tree := get_tree()
	out.sort_custom(func(a: int, b: int):
		return Genealogy.person(tree, a).get("gender", 0) < Genealogy.person(tree, b).get("gender", 0))
	return out

## Su pareja: la de ahora (o la que tenía cuando se murió), y si no, el papá o la mamá de su
## último hijo. 0: nadie.
func _partner_of(p: Dictionary, kids: Array[int]) -> int:
	if p.is_empty():
		return 0
	if p.get("partner", 0) != 0:
		return p.partner
	var tree := get_tree()
	for i in range(kids.size() - 1, -1, -1):
		for k: int in Genealogy.person(tree, kids[i]).get("parents", []):
			if k != p.id:
				return k
	return 0

## Si a y b son (o eran, cuando se murió alguno) pareja.
func _together(a: int, b: int) -> bool:
	var tree := get_tree()
	var pa := Genealogy.person(tree, a)
	var pb := Genealogy.person(tree, b)
	return pa.get("partner", 0) == b or pb.get("partner", 0) == a

## Nombre y apellido (o el número, si no tiene), con una cruz si ya no está.
static func _full_name(p: Dictionary, id: int) -> String:
	if p.is_empty():
		return TranslationServer.translate("Desconocido")
	var n := ("%s %s" % [p.first, p.last]).strip_edges()
	if n == "":
		n = "%s %04d" % [TranslationServer.translate("N.º"), id]
	return ("† " if p.dead else "") + n

## Lo que dibuja las líneas (debajo de la gente).
class Canvas extends Control:
	var spots := {}              # carnet -> arriba a la izquierda de su lugar
	var couples: Array = []      # [a, b, juntos]
	var descents: Array = []     # [padres, hijos]

	func _photo_mid(id: int) -> Vector2:
		return spots[id] + Vector2(FamilyTree.SLOT.x * 0.5, FamilyTree.PHOTO * 0.5)

	func _draw() -> void:
		for c: Array in couples:
			var a := _photo_mid(c[0])
			var b := _photo_mid(c[1])
			draw_line(a, b, FamilyTree.C_LINE, 2.0, true)
			if c[2]:
				var m := (a + b) * 0.5
				draw_colored_polygon(SpeechBubble._heart(m, 6.0), SpeechBubble.C_HEART)
		for d: Array in descents:
			var parents: Array = d[0]
			var kids: Array = d[1]
			var from := Vector2.ZERO
			for p: int in parents:
				from += _photo_mid(p)
			from /= parents.size()
			if parents.size() == 1:
				from.y += FamilyTree.PHOTO * 0.5   # Desde abajo de la foto
			var kid_top: float = spots[kids[0]].y - 4.0
			var bus := kid_top - 12.0
			var xs: Array[float] = [from.x]
			for k: int in kids:
				xs.append(_photo_mid(k).x)
			draw_line(from, Vector2(from.x, bus), FamilyTree.C_LINE, 2.0, true)
			draw_line(Vector2(xs.min(), bus), Vector2(xs.max(), bus), FamilyTree.C_LINE, 2.0, true)
			for k: int in kids:
				var x := _photo_mid(k).x
				draw_line(Vector2(x, bus), Vector2(x, kid_top), FamilyTree.C_LINE, 2.0, true)

## Uno del árbol: su foto (o un signo de pregunta, si no se sabe quién era) y su nombre. Un
## click muestra su familia.
class Person extends Control:
	signal picked(id: int)
	var id := 0
	var info: Dictionary
	var is_focus := false
	var _hover := false

	func _ready() -> void:
		size = Vector2(FamilyTree.SLOT.x, FamilyTree.NAME_Y + 18.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = FamilyTree._full_name(info, id)
		var photo := ColorRect.new()
		photo.position = Vector2((FamilyTree.SLOT.x - FamilyTree.PHOTO) * 0.5, 0.0)
		photo.size = Vector2.ONE * FamilyTree.PHOTO
		photo.clip_contents = true
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(photo)
		if info.is_empty():
			photo.color = FamilyTree.C_UNKNOWN
			var q := HUD.make_label("?", 30, HUD.C_MUTED)
			q.size = photo.size
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			photo.add_child(q)
		else:
			photo.color = FamilyTree.C_DEAD if info.dead else FamilyTree.C_ALIVE
			var body: Node = FamilyTree.VILLAGER.instantiate()
			var rig: VillagerRig = body.get_node("Rig")
			body.remove_child(rig)
			body.free()
			rig.set_female(info.gender == Villager.Gender.FEMALE)
			var looks: Array = info.looks   # Las partidas de antes no tienen las canas
			rig.material = Villager.material_for(looks[0], looks[1], looks[2], looks[3] if looks.size() > 3 else 0.0)
			rig.scale = Vector2.ONE * FamilyTree.PHOTO_SCALE
			# El Skeleton2D del rig está en (-512, -512): cada px del dibujo es (px - 512) en el rig
			rig.position = photo.size * 0.5 - (FamilyTree.PHOTO_FOCUS - Vector2(512, 512)) * FamilyTree.PHOTO_SCALE
			photo.add_child(rig)
			if info.dead:
				rig.set_dead()
				photo.modulate = Color(0.85, 0.85, 0.9)
		var label := HUD.make_label(_short_name(), 12, HUD.C_TEXT if not info.get("dead", true) else HUD.C_MUTED)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Es un nombre
		label.position = Vector2(0, FamilyTree.NAME_Y)
		label.size = Vector2(FamilyTree.SLOT.x, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		mouse_entered.connect(func():
			_hover = true
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			queue_redraw())
		gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				picked.emit(id))

	## El nombre, o el número; con una cruz si ya no está (cortado si es largo).
	func _short_name() -> String:
		if info.is_empty():
			return "%s %04d" % [TranslationServer.translate("N.º"), id]
		var n: String = info.first if info.first != "" else ("%s %04d" % [TranslationServer.translate("N.º"), id])
		if n.length() > FamilyTree.MAX_NAME:
			n = n.left(FamilyTree.MAX_NAME - 1) + "…"
		return ("† " if info.dead else "") + n

	## El marco de la foto: dorado el del que se está viendo, blanco con el mouse encima.
	func _draw() -> void:
		var r := Rect2(Vector2((FamilyTree.SLOT.x - FamilyTree.PHOTO) * 0.5, 0.0), Vector2.ONE * FamilyTree.PHOTO)
		if is_focus:
			draw_rect(r.grow(3.0), HUD.C_XP)
		elif _hover:
			draw_rect(r.grow(2.0), Color(1, 1, 1, 0.8))
		else:
			draw_rect(r.grow(1.0), Color(1, 1, 1, 0.18))
