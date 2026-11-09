extends HBoxContainer
class_name ArrowRow
## Una fila de cosas (los slots de la barra de poderes, las tarjetas de la tienda) que muestra de a
## shown y tiene una flecha a cada lado para correrla de a una; con la rueda del mouse encima,
## también. Así la barra y la tienda no se estiran hasta los bordes de la pantalla y se pueden
## agregar más cosas sin que dejen de entrar.
## Lo que va en la fila se agrega a row; set_items dice cuáles están en juego (por ejemplo, los de
## la pestaña elegida) y en qué orden. Las flechas siempre ocupan su lugar (así la fila no cambia
## de ancho): si todo entra, no se ven.

const ARROW_W := 24.0

## Cuántas se ven a la vez.
var shown := 8
## Donde van las cosas de la fila.
var row: HBoxContainer
var _items: Array[Control] = []
var _first := 0
var _left: Button
var _right: Button

func _init(count := 8, gap := 8) -> void:
	shown = count
	add_theme_constant_override("separation", 6)
	_left = _arrow("left", -1)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	add_child(row)
	_right = _arrow("right", 1)

## Las que están en juego, en orden (vacío: todas las de row). Las demás de row se esconden.
## Vuelve al principio.
func set_items(list: Array[Control] = []) -> void:
	_items = list.duplicate()
	if _items.is_empty():
		for c in row.get_children():
			_items.append(c as Control)
	_first = 0
	_layout()

## Corre la fila lo justo para que se vea item (si está en juego).
func show_item(item: Control) -> void:
	var i := _items.find(item)
	if i < 0:
		return
	if i < _first:
		_first = i
	elif i >= _first + shown:
		_first = i - shown + 1
	_layout()

## Corre la fila steps lugares (negativo: para la izquierda).
func scroll(steps: int) -> void:
	_first += steps
	_layout()

func _layout() -> void:
	_first = clampi(_first, 0, maxi(0, _items.size() - shown))
	for c in row.get_children():
		(c as Control).visible = false
	for i in _items.size():
		_items[i].visible = i >= _first and i < _first + shown
	var over := _items.size() > shown
	_set_arrow(_left, over, _first > 0)
	_set_arrow(_right, over, _first + shown < _items.size())

## Con la rueda del mouse encima, corre la fila (y no hace zoom en el mundo).
func _input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or _items.size() <= shown or not is_visible_in_tree():
		return
	if not get_global_rect().has_point(get_global_mouse_position()):
		return
	match wheel.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			scroll(-1)
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			scroll(1)
		_:
			return
	get_viewport().set_input_as_handled()

func _arrow(kind: String, step: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(ARROW_W, 0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UiStyle.box(Color(1, 1, 1, 0.08), 8, Color(1, 1, 1, 0.14), 1))
	b.add_theme_stylebox_override("hover", UiStyle.box(Color(1, 1, 1, 0.16), 8, Color(1, 1, 1, 0.32), 1))
	b.add_theme_stylebox_override("pressed", UiStyle.box(Color(1, 1, 1, 0.22), 8, Color(1, 1, 1, 0.4), 1))
	b.add_theme_stylebox_override("disabled", UiStyle.box(Color(1, 1, 1, 0.03), 8, Color(1, 1, 1, 0.06), 1))
	b.pressed.connect(scroll.bind(step))
	add_child(b)
	var px := 14
	var icon := HudIcon.make(kind, px)
	# Anclada al centro del botón y corrida la mitad de su tamaño (el preset con MINSIZE no la corre:
	# todavía no tiene tamaño)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -px * 0.5
	icon.offset_top = -px * 0.5
	icon.offset_right = px * 0.5
	icon.offset_bottom = px * 0.5
	b.add_child(icon)
	b.set_meta("icon", icon)
	return b

## Se ve si hace falta (over), y apagada si ya no se puede correr para ese lado.
func _set_arrow(b: Button, over: bool, can: bool) -> void:
	b.disabled = not (over and can)
	b.modulate.a = (1.0 if can else 0.35) if over else 0.0
	b.mouse_filter = Control.MOUSE_FILTER_STOP if over else Control.MOUSE_FILTER_IGNORE
