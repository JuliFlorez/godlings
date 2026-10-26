extends Control
class_name NameTag
## Nombre y apellido flotando arriba de la cabeza del aldeano. Vive en la capa del HUD
## (así la noche no lo oscurece y queda por encima de todo) y sigue a la cabeza aunque
## el aldeano esté colgando, volando o tirado. Si tiene el carnet abierto, una flechita
## lo señala; si el carnet abierto es de otro, un dibujito dice qué es de él (su pareja,
## un amigo o un enemigo, ver Relations). Arriba de todo, el globito de lo que está
## diciendo (ver SpeechBubble). Sin nada de eso no se ve.

# Centro y radio de la cabeza, relativos al pivote del hueso Head (px de villager.png)
const HEAD_CENTER := Vector2(-20, -259)
const HEAD_RADIUS := 290.0
const GAP := 2.0                 # Entre la cabeza y la flechita (o el nombre)
const ARROW := Vector2(6, 7)     # Medio ancho y alto de la flechita
const ARROW_BOB := 2.5           # Cuánto sube y baja la flechita
const MARK := 9.0                # Radio del dibujito de la relación
const MARK_ICONS := {
	Relations.Kind.COUPLE: Villager.Bubble.HEART,
	Relations.Kind.FRIEND: Villager.Bubble.SMILE,
	Relations.Kind.ENEMY: Villager.Bubble.ANGER,
}
const C_OUTLINE := Color(0.05, 0.07, 0.12, 0.9)

var villager: Villager
var hud: HUD
var _label: Label
var _bubble: SpeechBubble
var _selected := false
var _rel := Relations.Kind.NONE  # Qué es del aldeano que tiene el carnet abierto
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = HUD.make_label("", 13, HUD.C_TEXT)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Es un nombre: no se traduce
	_label.add_theme_color_override("font_outline_color", C_OUTLINE)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	_bubble = SpeechBubble.new()
	add_child(_bubble)

func _process(dt: float) -> void:
	if not is_instance_valid(villager) or villager.is_queued_for_deletion():
		queue_free()
		return
	var full := villager.full_name()
	var was_selected := _selected
	var was_rel := _rel
	var sel := hud.selected_villager()
	_selected = sel == villager
	_rel = Relations.kind(villager, sel)
	if _selected or was_selected or _rel != was_rel:
		_t += dt
		queue_redraw()   # La flechita sube y baja (o se borra al deseleccionarlo)
	var talking := villager.bubble != Villager.Bubble.NONE and villager.bubble_t > 0.0
	visible = (full != "" or _selected or _rel != Relations.Kind.NONE or talking) \
			and not villager.eaten and villager.rig != null
	if not visible:
		return

	if _label.text != full:
		_label.text = full
		_label.reset_size()
	_label.visible = full != ""
	var col := HUD.C_XP if _selected else (Relations.color(_rel) if _rel != Relations.Kind.NONE else HUD.C_TEXT)
	_label.add_theme_color_override("font_color", col)
	modulate.a = villager.modulate.a * (1.0 - villager.ashes())   # Se desvanece con él (ahogado, cadáver, cenizas)

	# Arriba de la cabeza en pantalla, gire como gire el aldeano
	var head := villager.rig.head
	var top := head.to_global(HEAD_CENTER) + Vector2(0, -HEAD_RADIUS * head.global_transform.x.length())
	position = (villager.get_canvas_transform() * top).round()
	var mark_h := 0.0
	if _selected:
		mark_h = ARROW.y + ARROW_BOB + GAP
	elif _rel != Relations.Kind.NONE:
		mark_h = MARK * 2.0 + GAP
	_label.position = Vector2(-_label.size.x * 0.5, -_label.size.y - GAP - mark_h).round()
	# El globito, arriba del nombre (o de lo que haya)
	var above := _label.position.y if _label.visible else -GAP - mark_h
	_bubble.position = Vector2(0, above - 1.0)
	_bubble.show_bubble(villager.bubble if talking else Villager.Bubble.NONE, villager.bubble_t, dt)

func _draw() -> void:
	if _selected:
		var y := -GAP - (0.5 + 0.5 * sin(_t * 6.0)) * ARROW_BOB
		var tri := PackedVector2Array([Vector2(-ARROW.x, y - ARROW.y), Vector2(ARROW.x, y - ARROW.y), Vector2(0, y)])
		draw_colored_polygon(tri, HUD.C_XP)
		tri.append(tri[0])
		draw_polyline(tri, C_OUTLINE, 2.0, true)
	elif _rel != Relations.Kind.NONE:
		var c := Vector2(0, -GAP - MARK)
		draw_circle(c, MARK + 1.5, Color(C_OUTLINE, 0.7), true, -1.0, true)
		SpeechBubble.draw_icon(self, MARK_ICONS[_rel], c, 0.75)
