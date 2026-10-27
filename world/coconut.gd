extends Food
class_name Coconut
## Coco: se arranca de una palmera y se tira como a los aldeanos. Si le cae encima a un
## aldeano se parte en dos mitades, y los que tienen hambre van a comérselas (ver Food).
## Como las decoraciones, el origen del nodo queda LIFT px arriba del coco, así el orden
## por Y (quién tapa a quién) es parejo con los aldeanos. "point()" es el centro del coco.

enum State { HELD, FLYING, GROUND, SINKING }

const LIFT := 24.0
const R := 8.0
const GRAB_R := R + 6.0           # Radio para agarrarlo con el mouse
const GRAVITY := 1400.0
const THROW_SMOOTH := 25.0        # Igual que los aldeanos
const THROW_MAX_SPEED := 1800.0
const LAND_DROP := 40.0           # Soltado sobre la isla: cuánto baja antes de poder caer al piso
const BOUNCE_SPEED := 280.0       # Más rápido que esto rebota al tocar el piso
const ROLL_FRICTION := 500.0
const BITES := 3                  # Mordiscos para terminarse media cáscara
const HALF_FOOD := 30.0           # El hambre que saca media cáscara

const C_SHELL := Color(0.42, 0.27, 0.13)
const C_SHELL_LIGHT := Color(0.58, 0.4, 0.22)
const C_SHELL_DARK := Color(0.27, 0.17, 0.08)
const C_FLESH := Color(0.98, 0.97, 0.92)

## Isla actual (la actualiza DecorPlacer cuando la isla crece).
static var island_poly: PackedVector2Array

var state := State.HELD
var half := 0                     # 0: entero. -1 / 1: mitad izquierda / derecha
var vel := Vector2.ZERO
var spin := 0.0
var floor_y := INF                # Mitades: altura del piso donde van a caer
var hovered := false:
	set(v):
		hovered = v
		modulate = Color(1.35, 1.3, 1.15) if v else Color.WHITE

var _angle := 0.0
var _launch_y := 0.0
var _left_island := false
var _prev_mouse := Vector2.ZERO
var _throw_vel := Vector2.ZERO
var _bites := 0

func _ready() -> void:
	add_to_group("coconut")
	if half != 0:
		add_to_group("food")
		nutrition = HALF_FOOD

func point() -> Vector2:
	return global_position + Vector2(0, LIFT)

func set_point(p: Vector2) -> void:
	global_position = p - Vector2(0, LIFT)

## Se puede agarrar con el mouse (suelto en el piso o en pleno vuelo).
func can_grab() -> bool:
	return state == State.GROUND or state == State.FLYING

func grab() -> void:
	release_eater()
	hovered = false
	state = State.HELD
	floor_y = INF
	z_index = 10
	_prev_mouse = get_global_mouse_position()
	_throw_vel = Vector2.ZERO

## Lo levantó un tornado (ver Tornado): sale volando con v (y si le cae a alguien, ¡bonk!).
func fling(v: Vector2) -> void:
	release_eater()
	hovered = false
	state = State.FLYING
	floor_y = INF
	vel = v
	spin = randf_range(-18.0, 18.0)
	_launch_y = point().y
	_left_island = false
	z_index = 10

func _input(event: InputEvent) -> void:
	# Atrapa el soltado del click izquierdo en cualquier parte de la pantalla
	if state == State.HELD and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	check_eater()
	match state:
		State.HELD:
			_hold(dt)
		State.FLYING:
			_fly(dt)
		State.GROUND:
			_rest(dt)
		State.SINKING:
			set_point(point() + Vector2(0, 22.0 * dt))
			modulate.a -= 0.9 * dt
			if modulate.a <= 0.02:
				queue_free()
	queue_redraw()

# ---- En la mano ----
func _hold(dt: float) -> void:
	var m := get_global_mouse_position()
	if dt > 0.0:
		_throw_vel = _throw_vel.lerp((m - _prev_mouse) / dt, 1.0 - exp(-THROW_SMOOTH * dt))
	_prev_mouse = m
	set_point(m)

func _release() -> void:
	state = State.FLYING
	vel = _throw_vel.limit_length(THROW_MAX_SPEED)
	spin = clampf(vel.x * 0.03, -18.0, 18.0)
	_launch_y = point().y
	_left_island = not _on_island()

# ---- Volando ----
func _fly(dt: float) -> void:
	vel.y += GRAVITY * dt
	var p := point() + vel * dt
	_angle += spin * dt
	# Los costados de la pantalla lo rebotan, como a los aldeanos
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	if (p.x < view.position.x + R and vel.x < 0.0) or (p.x > view.end.x - R and vel.x > 0.0):
		vel.x *= -0.5
	set_point(p)

	if half == 0:
		var hit := _villager_hit(p)
		if hit:
			_split(hit)
			return
		# Hay un aldeano justo abajo: que le caiga encima en vez de apoyarse antes en el piso
		if _villager_below(p):
			return

	var on := _on_island()
	if not on:
		_left_island = true
	if vel.y <= 0.0:
		return
	if floor_y < INF:
		# Mitad saltando desde la cabeza del aldeano: cae a la altura de sus pies
		if p.y >= floor_y:
			if on:
				_land()
			else:
				floor_y = INF   # Saltó fuera de la isla: sigue cayendo al agua
		return
	if on and (_left_island or p.y - _launch_y > LAND_DROP):
		_land()
	elif not on and (_left_island or p.y - _launch_y > LAND_DROP) and _in_water(p):
		_splash(p)
	elif p.y > view.end.y + 100.0:
		queue_free()

func _land() -> void:
	floor_y = point().y
	if vel.y > BOUNCE_SPEED:
		vel = Vector2(vel.x * 0.5, -vel.y * 0.3)
		spin *= 0.5
		return
	state = State.GROUND
	z_index = 0
	vel = Vector2(vel.x * 0.5, 0.0)

func _splash(p: Vector2) -> void:
	state = State.SINKING
	z_index = 0
	_burst(p, Color(0.85, 0.95, 1.0), 12, 160.0)
	Sea.ripple_at(self, p, 0.5)

# ---- En el piso ----
func _rest(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, ROLL_FRICTION * dt)
	if vel.x != 0.0:
		set_point(point() + Vector2(vel.x * dt, 0.0))
		if half == 0:
			_angle += vel.x * dt / R   # Rueda
	if half != 0:
		_angle = lerp_angle(_angle, 0.0, 10.0 * dt)   # Queda con la pulpa para arriba
	if not _on_island():
		# Rodó fuera de la isla
		release_eater()
		state = State.FLYING
		floor_y = INF
		_left_island = true
		z_index = 10

## Las mitades tiradas en la isla se pueden comer.
func available() -> bool:
	return is_free() and half != 0 and state == State.GROUND

## Dónde se para el aldeano (su centro) para comer: al costado, con los pies a la altura del coco.
func eat_spot(v: Villager) -> Vector2:
	var side := 1.0 if v.global_position.x >= point().x else -1.0
	return point() + Vector2(side * (R + 9.0), R - Villager.BODY_BOTTOM * v.scale.y)

## progress: 0..1 de lo que lleva comiendo.
func nibble(progress: float) -> void:
	var b := clampi(floori(progress * BITES), 0, BITES - 1)
	if b > _bites:
		_bites = b
		_burst(point(), C_FLESH, 5, 70.0)

func finish_eating(v: Villager) -> void:
	super(v)
	_burst(point(), C_FLESH, 8, 90.0)
	for i in 3:
		var h := Heart.new()
		get_parent().add_child(h)
		h.global_position = v.global_position + Vector2(randf_range(-12.0, 12.0), -40.0)
		h.delay = i * 0.15

# ---- Aldeanos ----
func _bonkable(v: Villager) -> bool:
	return v != null and v.is_idle()

func _villager_hit(p: Vector2) -> Villager:
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if not _bonkable(v):
			continue
		var seg := v._body_segment()
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])) < Villager.BODY_HALF_W + R:
			return v
	return null

func _villager_below(p: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if _bonkable(v) and absf(p.x - v.global_position.x) < Villager.BODY_HALF_W + R \
				and p.y < v.global_position.y + Villager.BODY_BOTTOM:
			return true
	return false

## ¡Bonk! El coco se parte y las dos mitades saltan para los costados.
func _split(v: Villager) -> void:
	v.bonk(point())
	var feet := v.global_position.y + Villager.BODY_BOTTOM - R
	for side in [-1, 1]:
		var h := Coconut.new()
		h.half = side
		h.state = State.FLYING
		h.vel = Vector2(side * randf_range(70.0, 130.0) + vel.x * 0.15, -randf_range(200.0, 280.0))
		h.spin = side * randf_range(8.0, 14.0)
		h.floor_y = feet + randf_range(-3.0, 6.0)
		h.z_index = 10
		get_parent().add_child(h)
		h.set_point(point())
	_burst(point(), C_FLESH, 10, 150.0)
	_burst(point(), C_SHELL, 6, 120.0)
	queue_free()

# ---- Utilidades ----
func _on_island() -> bool:
	return island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly)

func _in_water(p: Vector2) -> bool:
	var w := get_tree().get_first_node_in_group("water")
	return w != null and w.get_global_rect().has_point(p)

func _burst(at: Vector2, color: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.45
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 600)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.z_index = 11
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---- Dibujo ----
func _draw() -> void:
	if state == State.GROUND:
		draw_set_transform(Vector2(0, LIFT))
		draw_colored_polygon(_ellipse(Vector2(0, R * 0.9), R * 1.1, R * 0.35), Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2(0, LIFT), _angle)
	if half == 0:
		paint_whole(self, Vector2.ZERO, R)
	else:
		_paint_half(R * (1.0 - 0.22 * _bites))

## Coco entero (también lo usa la palmera para los de la copa).
static func paint_whole(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, C_SHELL, true, -1.0, true)
	ci.draw_circle(c + Vector2(-r, -r) * 0.3, r * 0.38, C_SHELL_LIGHT, true, -1.0, true)
	if r > 3.0:
		for o in [Vector2(0.2, 0.25), Vector2(0.45, 0.05), Vector2(0.45, 0.45)]:
			ci.draw_circle(c + o * r, r * 0.12, C_SHELL_DARK, true, -1.0, true)

## Media cáscara con la pulpa para arriba.
func _paint_half(r: float) -> void:
	var shell := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		shell.append(Vector2(cos(a) * r * 1.1, sin(a) * r * 0.9))
	draw_colored_polygon(shell, C_SHELL)
	draw_colored_polygon(_ellipse(Vector2.ZERO, r * 1.1, r * 0.38), C_SHELL_DARK)
	draw_colored_polygon(_ellipse(Vector2(0, 0.3), r * 0.85, r * 0.26), C_FLESH)

static func _ellipse(c: Vector2, rx: float, ry: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## Corazoncito que sube y se desvanece (aldeano contento después de comer).
class Heart extends Node2D:
	var delay := 0.0

	func _ready() -> void:
		z_index = 12
		modulate.a = 0.0
		scale = Vector2.ONE * 0.8
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(self, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(self, "scale", Vector2.ONE * 1.4, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "position:y", position.y - 24.0, 1.0).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.6)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var col := Color(1.0, 0.35, 0.5)
		draw_circle(Vector2(-2.6, -1.5), 3.0, col, true, -1.0, true)
		draw_circle(Vector2(2.6, -1.5), 3.0, col, true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-5.4, -0.5), Vector2(5.4, -0.5), Vector2(0, 5.5)]), col)
