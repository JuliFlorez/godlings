extends Node2D
class_name Celestial
## Astro arrastrable (sol o luna). Si lo soltás cerca del horizonte se pone
## y emite `has_set` para que salga el otro. Si lo tocás varias veces seguidas
## se vuelve perturbador (y otra tanda de toques lo calma).

signal has_set
signal creepy_changed(is_creepy: bool)

@export var pick_radius := 65.0
@export var set_margin := 70.0   # Soltarlo a esta distancia (o menos) del horizonte lo hace ponerse
@export var sway := 0.06         # Balanceo en reposo (radianes)
@export var taps_to_transform := 5

const HIDDEN_DEPTH := 220.0      # Qué tan abajo del horizonte queda escondido
const TAP_SLOP := 8.0            # Si el puntero se mueve menos que esto, fue un toque y no un arrastre
const TAP_WINDOW_MS := 500       # Tiempo máximo entre toques para que cuenten como seguidos

var horizon_y := 408.0
var rest_pos := Vector2.ZERO
var is_up := true
var dragging := false
var creepy := false
var _drag_offset := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _moved := false
var _taps := 0
var _last_tap_ms := -TAP_WINDOW_MS
var _shake := 0.0
var _look := Vector2.DOWN
var _t := 0.0
var _tween: Tween
var _fx_tween: Tween

func _ready() -> void:
	rest_pos = position

func _process(dt: float) -> void:
	_t += dt
	_shake = move_toward(_shake, 0.0, dt * 1.5)
	# El perturbador nunca se queda quieto del todo
	var jitter := _shake * 0.3 + (0.02 if creepy else 0.0)
	rotation = sin(_t * 0.8) * sway + randf_range(-jitter, jitter)

	var to_target := _nearest_villager_pos() - global_position
	var target_look := to_target.normalized() if to_target.length() > 1.0 else Vector2.DOWN
	_look = _look.lerp(target_look, 1.0 - exp(-6.0 * dt))

func _nearest_villager_pos() -> Vector2:
	var best := global_position + Vector2.DOWN * 200.0
	var best_d := INF
	for v in get_tree().get_nodes_in_group("villager"):
		var d := global_position.distance_squared_to(v.global_position)
		if d < best_d:
			best_d = d
			best = v.global_position
	return best

func _pointer_pos(event: InputEventMouse) -> Vector2:
	return get_canvas_transform().affine_inverse() * event.position

func _unhandled_input(event: InputEvent) -> void:
	if not is_up or dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var p := _pointer_pos(event)
		if p.distance_to(position) <= pick_radius:
			dragging = true
			_moved = false
			_press_pos = p
			if _tween:
				_tween.kill()
			_drag_offset = position - p
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Movimiento y soltado se atrapan en _input para que no los coman los botones del HUD
	if not dragging:
		return
	if event is InputEventMouseMotion:
		var p := _pointer_pos(event)
		if not _moved and p.distance_to(_press_pos) < TAP_SLOP:
			return
		_moved = true
		p += _drag_offset
		var vp := get_viewport_rect().size
		position = Vector2(clampf(p.x, 0.0, vp.x), clampf(p.y, 0.0, horizon_y + 40.0))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		get_viewport().set_input_as_handled()
		if not _moved:
			_register_tap()
		elif position.y >= horizon_y - set_margin:
			sink()

func _register_tap() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms > TAP_WINDOW_MS:
		_taps = 0
	_last_tap_ms = now
	_taps += 1
	if _taps >= taps_to_transform:
		_taps = 0
		set_creepy(not creepy)
	else:
		# Cada toque lo hace temblar un poco más: avisa que algo se viene
		_shake = maxf(_shake, float(_taps) / taps_to_transform * 0.5)
		_pop(0.85, 0.35)

func set_creepy(value: bool) -> void:
	creepy = value
	_shake = 1.0
	_pop(1.4, 0.8)
	creepy_changed.emit(creepy)
	queue_redraw()

func _pop(from_scale: float, duration: float) -> void:
	if _fx_tween:
		_fx_tween.kill()
	scale = Vector2.ONE * from_scale
	_fx_tween = create_tween()
	_fx_tween.tween_property(self, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## 0 = en lo alto del cielo, 1 = en el horizonte o más abajo
func height_t() -> float:
	return clampf(inverse_lerp(rest_pos.y, horizon_y + 40.0, position.y), 0.0, 1.0)

func sink() -> void:
	is_up = false
	_restart_tween()
	_tween.tween_property(self, "position:y", horizon_y + HIDDEN_DEPTH, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		hide()
		has_set.emit())

func rise() -> void:
	position = Vector2(rest_pos.x, horizon_y + HIDDEN_DEPTH)
	show()
	_restart_tween()
	_tween.tween_property(self, "position", rest_pos, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): is_up = true)

## Deja el astro escondido bajo el horizonte sin animación
func hide_below() -> void:
	is_up = false
	position = Vector2(rest_pos.x, horizon_y + HIDDEN_DEPTH)
	hide()

## Boca abierta con dientes filosos. Las comisuras quedan en (±half_width, corner_y);
## el labio de arriba baja `upper_drop` en el centro y el de abajo `lower_drop`.
func draw_grin(half_width: float, corner_y: float, upper_drop: float, lower_drop: float,
		teeth: int, inside: Color, tooth: Color) -> void:
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var steps := teeth * 2
	for s in steps + 1:
		var t := lerpf(-1.0, 1.0, float(s) / steps)
		var bulge := 1.0 - t * t
		upper.append(Vector2(t * half_width, corner_y + upper_drop * bulge))
		lower.append(Vector2(t * half_width, corner_y + lower_drop * bulge))

	var mouth := upper.duplicate()
	for i in range(lower.size() - 2, 0, -1):   # Las comisuras ya están en `upper`
		mouth.append(lower[i])
	draw_colored_polygon(mouth, inside)

	for k in teeth:
		var mid := k * 2 + 1
		var h := (lower[mid].y - upper[mid].y) * 0.45
		draw_colored_polygon(PackedVector2Array([upper[mid - 1], upper[mid + 1], upper[mid] + Vector2(0, h)]), tooth)
		draw_colored_polygon(PackedVector2Array([lower[mid - 1], lower[mid + 1], lower[mid] - Vector2(0, h)]), tooth)

func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
