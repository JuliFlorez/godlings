extends Node2D
class_name ExpandMarker
## Punto de expansión: un orbe dorado con un "+" que sale del borde de la isla
## cuando hay puntos disponibles. Al tocarlo, la isla crece.

signal activated

const RADIUS := 15.0
const COLOR := Color(1.0, 0.78, 0.22)

## -1 = borde izquierdo, 1 = borde derecho (hacia dónde apuntan las flechas)
var outward := 1.0
var _t := 0.0
var _hover := false
var _alive := true

func _ready() -> void:
	z_index = 20
	_t = randf() * TAU
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(dt: float) -> void:
	_t += dt
	_hover = _alive and _hit(get_global_mouse_position())
	queue_redraw()

func _bob() -> Vector2:
	return Vector2(0, sin(_t * 3.0) * 4.0)

func _hit(global_p: Vector2) -> bool:
	return to_local(global_p).distance_to(_bob()) <= RADIUS * 1.6

func _unhandled_input(event: InputEvent) -> void:
	if not _alive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _hit(get_global_mouse_position()):
			get_viewport().set_input_as_handled()
			activated.emit()

func dismiss() -> void:
	if not _alive:
		return
	_alive = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _draw() -> void:
	var c := _bob()
	var pulse := 1.0 + sin(_t * 5.0) * 0.08
	var grow := 1.12 if _hover else 1.0

	# Halo
	draw_circle(c, RADIUS * 2.1 * pulse, Color(1, 0.85, 0.3, 0.10), true, -1.0, true)
	draw_circle(c, RADIUS * 1.55 * pulse, Color(1, 0.85, 0.3, 0.22), true, -1.0, true)

	# Orbe
	draw_circle(c + Vector2(0, 2), RADIUS * grow, Color(0.55, 0.32, 0.05, 0.45), true, -1.0, true)
	draw_circle(c, RADIUS * grow, COLOR, true, -1.0, true)
	draw_circle(c + Vector2(-4, -5) * grow, RADIUS * 0.35 * grow, Color(1, 1, 1, 0.45), true, -1.0, true)
	draw_arc(c, RADIUS * grow, 0.0, TAU, 32, Color(1, 0.96, 0.8), 2.0, true)

	# "+"
	var a := RADIUS * 0.5 * grow
	draw_line(c - Vector2(a, 0), c + Vector2(a, 0), Color.WHITE, 4.0, true)
	draw_line(c - Vector2(0, a), c + Vector2(0, a), Color.WHITE, 4.0, true)

	# Flechas hacia afuera: "la isla crece para este lado"
	for i in 2:
		var phase := fmod(_t * 1.2 + i * 0.5, 1.0)
		var x := outward * (RADIUS + 8.0 + phase * 14.0)
		var col := Color(1, 1, 1, 0.8 * (1.0 - phase))
		var tip := c + Vector2(x + outward * 5.0, 0)
		draw_line(tip, c + Vector2(x, -5), col, 2.5, true)
		draw_line(tip, c + Vector2(x, 5), col, 2.5, true)
