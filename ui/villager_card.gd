extends PanelContainer
class_name VillagerCard
## Carnet del aldeano: se abre con un click sobre él en modo seleccionar.
## Foto tipo carnet con el género abajo, número, y nombre y apellido para escribir
## (se ven arriba de su cabeza, ver NameTag).
## La foto es un rig propio del aldeano (así parpadea) que copia su cara: la boca de
## "¡wow!" si lo tiran por el aire y los ojos en X si está muerto.

const VILLAGER := preload("res://actors/villager/villager.tscn")
const MARGIN := 14.0
const TOP := 196.0               # Debajo del sol
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

var villager: Villager
var _number: Label
var _gender: Label
var _first: LineEdit
var _last: LineEdit
var _photo: Control
var _photo_rig: VillagerRig

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
	visible = true
	reset_size()
	position = Vector2(get_viewport_rect().size.x - size.x - MARGIN, TOP)

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
	_photo_rig.scale = Vector2.ONE * PHOTO_SCALE
	# El Skeleton2D del rig está en (-512, -512): cada px del dibujo es (px - 512) en el rig
	_photo_rig.position = PHOTO_SIZE * 0.5 - (PHOTO_FOCUS - Vector2(512, 512)) * PHOTO_SCALE
	_photo.add_child(_photo_rig)

# ---- Construcción ----
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
