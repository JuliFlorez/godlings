extends PanelContainer
class_name HutCard
## Cartel de la choza: se abre con un click sobre ella en modo seleccionar (o tocando la casa
## en el carnet de un aldeano, ver VillagerCard). Tiene el dibujo de la choza, el nombre para
## escribir (se ve en el cartel de arriba de la puerta, ver Decoration.hut_name) y los que
## viven ahí: un click en uno abre su carnet. Mientras está abierto, una flechita señala la choza.

const PREVIEW_SIZE := Vector2(132, 104)
const PREVIEW_SCALE := 1.1
const PREVIEW_GROUND := 12.0     # Lo que queda de arena abajo de la choza
const C_SAND := Color(0.93, 0.83, 0.6)

var hud: HUD
var hut: Decoration
var _name: LineEdit
var _preview: Preview
var _beds: Label
var _residents: HFlowContainer
var _residents_key := ""         # Lo que se está mostrando: se rearma solo si cambia

func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", HUD.make_box(Color(0.06, 0.09, 0.16, 0.94), 16, HUD.C_PANEL_BORDER, 1, Vector4(16, 12, 16, 16)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(HUD.make_label("Choza", 17, HUD.C_TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(VillagerCard.close_button(close))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)

	# El dibujo, enmarcado como la foto del carnet
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HUD.make_box(VillagerCard.PHOTO_FRAME, 6, Color(0, 0, 0, 0), 0, Vector4(4, 4, 4, 4)))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(frame)
	_preview = Preview.new()
	_preview.custom_minimum_size = PREVIEW_SIZE
	_preview.card = self
	frame.add_child(_preview)

	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(fields)
	_name = VillagerCard.field(fields, "Cartel", "Sin nombre", Decoration.HUT_NAME_MAX)
	_name.text_changed.connect(func(t: String):
		if is_instance_valid(hut):
			hut.hut_name = t.strip_edges()
			_preview.queue_redraw())
	_name.text_submitted.connect(func(_t: String): _name.release_focus())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	fields.add_child(gap)
	var row := HBoxContainer.new()
	fields.add_child(row)
	row.add_child(VillagerCard.caption("Viven acá"))
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)
	_beds = HUD.make_label("", 12, HUD.C_MUTED)
	row.add_child(_beds)
	_residents = HFlowContainer.new()
	_residents.custom_minimum_size = Vector2(176, 0)   # Lo mismo que el nombre
	_residents.add_theme_constant_override("h_separation", 6)
	_residents.add_theme_constant_override("v_separation", 3)
	fields.add_child(_residents)

## "Choza" si no le pusieron nombre.
static func title_of(h: Decoration) -> String:
	return h.hut_name if h.hut_name != "" else TranslationServer.translate("Choza")

func open(h: Decoration) -> void:
	hut = h
	_name.release_focus()
	_name.text = h.hut_name
	_residents_key = "-"   # Que se rearme
	_update_residents()
	visible = true
	_preview.queue_redraw()
	_place()

## Arriba a la derecha, donde va el carnet.
func _place() -> void:
	reset_size()
	var view := get_viewport_rect().size
	position = Vector2(view.x - size.x - VillagerCard.MARGIN,
			clampf(view.y - VillagerCard.BOTTOM - size.y, VillagerCard.MARGIN, VillagerCard.TOP))

func close() -> void:
	_name.release_focus()
	visible = false
	hut = null

func _process(_dt: float) -> void:
	if not visible:
		return
	if not is_instance_valid(hut) or not hut.is_in_group("hut") or hut.is_queued_for_deletion():
		close()   # La quitaron
		return
	_update_residents()
	_place()

## Los que viven ahí (y cuántos lugares quedan).
func _update_residents() -> void:
	var people := hut.residents()
	people.sort_custom(func(a: Villager, b: Villager): return a.id_number < b.id_number)
	var key := TranslationServer.get_locale()   # Los que no tienen nombre dicen "N.º" en el idioma
	for o in people:
		key += "%d:%s:%s;" % [o.id_number, o.full_name(), o.inside]
	if key == _residents_key:
		return
	_residents_key = key
	_beds.text = "%d / %d" % [people.size(), Decoration.HUT_BEDS]
	for c in _residents.get_children():
		c.queue_free()
	if people.is_empty():
		_residents.add_child(HUD.make_label("—", 14, Color(HUD.C_MUTED, 0.6)))
	for o in people:
		# Los que están adentro, más claritos
		_residents.add_child(VillagerCard.link_button(VillagerCard.listed_name(o), HUD.C_TEXT if o.inside else HUD.C_MUTED, func():
			if is_instance_valid(o) and hud:
				hud.select_villager(o)))

func _input(event: InputEvent) -> void:
	# Click afuera: deja de escribir (si no, G o S escribirían en el cartel)
	if visible and event is InputEventMouseButton and event.pressed \
			and not get_global_rect().has_point(get_global_mouse_position()):
		_name.release_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

## La choza sobre la arena, con el cielo atrás.
class Preview extends Control:
	var card: HutCard

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), VillagerCard.PHOTO_BG)
		var ground := size.y - PREVIEW_GROUND
		draw_rect(Rect2(0, ground - 4.0, size.x, size.y - ground + 4.0), C_SAND)
		if card == null or not is_instance_valid(card.hut):
			return
		draw_set_transform(Vector2(size.x * 0.5, ground), 0.0, Vector2.ONE * PREVIEW_SCALE)
		Decoration.paint(self, "hut", card.hut.variant, 0.0, Decoration.ALL_FRUIT, 0.0, card.hut.hut_name)
