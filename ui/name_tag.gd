extends Control
class_name NameTag
## Nombre y apellido flotando arriba de la cabeza del aldeano. Vive en la capa del HUD
## (así la noche no lo oscurece y queda por encima de todo) y sigue a la cabeza aunque
## el aldeano esté colgando, volando o tirado. Si tiene el carnet abierto, una flechita
## lo señala. Sin nombre y sin seleccionar no se ve.

# Centro y radio de la cabeza, relativos al pivote del hueso Head (px de villager.png)
const HEAD_CENTER := Vector2(-20, -259)
const HEAD_RADIUS := 290.0
const GAP := 2.0                 # Entre la cabeza y la flechita (o el nombre)
const ARROW := Vector2(6, 7)     # Medio ancho y alto de la flechita
const ARROW_BOB := 2.5           # Cuánto sube y baja la flechita
const C_OUTLINE := Color(0.05, 0.07, 0.12, 0.9)

var villager: Villager
var hud: HUD
var _label: Label
var _selected := false
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = HUD.make_label("", 13, HUD.C_TEXT)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Es un nombre: no se traduce
	_label.add_theme_color_override("font_outline_color", C_OUTLINE)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)

func _process(dt: float) -> void:
	if not is_instance_valid(villager) or villager.is_queued_for_deletion():
		queue_free()
		return
	var full := villager.full_name()
	var was_selected := _selected
	_selected = hud.selected_villager() == villager
	if _selected or was_selected:
		_t += dt
		queue_redraw()   # La flechita sube y baja (o se borra al deseleccionarlo)
	visible = (full != "" or _selected) and not villager.eaten and villager.rig != null
	if not visible:
		return

	if _label.text != full:
		_label.text = full
		_label.reset_size()
	_label.visible = full != ""
	_label.add_theme_color_override("font_color", HUD.C_XP if _selected else HUD.C_TEXT)
	modulate.a = villager.modulate.a   # Se desvanece con él (ahogado, cadáver)

	# Arriba de la cabeza en pantalla, gire como gire el aldeano
	var head := villager.rig.head
	var top := head.to_global(HEAD_CENTER) + Vector2(0, -HEAD_RADIUS * head.global_transform.x.length())
	position = (villager.get_canvas_transform() * top).round()
	var arrow_h := ARROW.y + ARROW_BOB + GAP if _selected else 0.0
	_label.position = Vector2(-_label.size.x * 0.5, -_label.size.y - GAP - arrow_h).round()

func _draw() -> void:
	if not _selected:
		return
	var y := -GAP - (0.5 + 0.5 * sin(_t * 6.0)) * ARROW_BOB
	var tri := PackedVector2Array([Vector2(-ARROW.x, y - ARROW.y), Vector2(ARROW.x, y - ARROW.y), Vector2(0, y)])
	draw_colored_polygon(tri, HUD.C_XP)
	tri.append(tri[0])
	draw_polyline(tri, C_OUTLINE, 2.0, true)
