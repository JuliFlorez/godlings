extends Node2D
class_name Shark
## Tiburón: patrulla el agua (solo asoma la aleta) y se come a los aldeanos que están flotando.
## Arranca apagado: se compran en la tienda (hasta MAX) y se pueden apagar y prender.
## Se lo puede agarrar de la aleta y sacar del agua: cuelga y se sacude, se lo puede tirar
## y, si cae en la isla, va coleteando hasta volver a caerse al agua.

const PRICE := 40
const MAX := 2

@export var water_path: NodePath
@export var patrol_speed := 60.0
@export var hunt_speed := 170.0
@export var bite_range := 16.0
@export var bite_cooldown := 1.5

enum State { SWIM, HELD, FLYING, LAND }

const TEXTURE := preload("res://actors/shark.png")
const WATERLINE_SHADER := preload("res://actors/villager/waterline.gdshader")
const SPRITE_W := 150.0          # Ancho en pantalla del tiburón entero
# Referencias en píxeles del dibujo (mira a la izquierda)
const IMG_SURFACE_Y := 85.0      # Fila que queda en la línea del agua al nadar: asoma la aleta
const IMG_FIN := Rect2(200, 0, 100, 85)
const DIVE_DEPTH := 30.0         # Cuánto baja al sumergirse (px en pantalla)

# Agarrado: cuelga de donde se lo agarró y se sacude
const GRAVITY := 1400.0
const SWING_K := 30.0
const SWING_DAMP := 2.0
const THRASH := 40.0             # Fuerza de los coletazos
const THRASH_FREQ := 13.0
const MAX_MOUSE_ACC := 6000.0
const THROW_SMOOTH := 25.0
const THROW_MIN_SPEED := 250.0
const THROW_MAX_SPEED := 1800.0
const LAND_DROP := 40.0          # Lanzado sobre la isla: cuánto baja antes de poder caer en ella

# En la isla: saltitos de pescado fuera del agua
const FLOP_GRAVITY := 900.0
const FLOP_EVERY := Vector2(0.35, 0.75)
const FLOP_HOP := Vector2(150.0, 230.0)

var water_rect := Rect2(0, 570, 1150, 76)
var dir := 1.0
var _t := 0.0
var _cooldown := 0.0
var _dive := 0.0   # 0 = aleta afuera, 1 = sumergida (mientras muerde)
var active := false
var _tween: Tween

var state := State.SWIM
var _world: Node2D              # En la isla se muda a la capa ordenada por Y (Props)
var _sprite: Sprite2D
var _waterline: ShaderMaterial
var _k := 1.0                    # Escala del dibujo

var _grab_local := Vector2.ZERO
var _swing_vel := 0.0
var _prev_mouse := Vector2.ZERO
var _mouse_vel := Vector2.ZERO
var _mouse_acc := Vector2.ZERO
var _throw_vel := Vector2.ZERO

var _vel := Vector2.ZERO
var _spin := 0.0
var _launch_y := 0.0
var _left_island := false

var _ground := Vector2.ZERO      # En la isla: punto del piso (la altura del salto va aparte)
var _h := 0.0
var _hv := 0.0
var _ground_vel := Vector2.ZERO
var _flop_t := 0.0

func _ready() -> void:
	var water := get_node_or_null(water_path)
	if water and water.has_method("get_global_rect"):
		water_rect = water.get_global_rect()
	global_position = Vector2(randf_range(_left(), _right()), water_rect.position.y)
	dir = 1.0 if randf() < 0.5 else -1.0
	_world = get_parent()

	_k = SPRITE_W / TEXTURE.get_width()
	_waterline = ShaderMaterial.new()
	_waterline.shader = WATERLINE_SHADER
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.scale = Vector2.ONE * _k
	_sprite.material = _waterline
	add_child(_sprite)

	visible = false
	set_process(false)

## Prendido: emerge en un lugar al azar del agua. Apagado: se sumerge y deja de cazar.
func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if state != State.SWIM:
		_back_to_water(false)
	if on:
		global_position.x = randf_range(_left(), _right())
		_dive = 1.0
		visible = true
		set_process(true)
		_tween.tween_property(self, "_dive", 0.0, 0.5)
	else:
		_tween.tween_property(self, "_dive", 1.0, 0.3)
		_tween.tween_callback(func():
			visible = false
			set_process(false))

func _left() -> float:
	return water_rect.position.x + 20.0

func _right() -> float:
	return water_rect.end.x - 20.0

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	match state:
		State.SWIM:
			_swim(dt)
		State.HELD:
			_hold(dt)
		State.FLYING:
			_fly(dt)
		State.LAND:
			_flop(dt)
	_update_sprite()
	queue_redraw()

func _swim(dt: float) -> void:
	var speed := patrol_speed
	var prey := _find_prey() if active and _cooldown <= 0.0 else null
	if prey:
		var dx := prey.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = signf(dx)
		speed = hunt_speed
		if absf(dx) < bite_range:
			_bite(prey)

	global_position.x += dir * speed * dt
	if global_position.x < _left():
		dir = 1.0
	elif global_position.x > _right():
		dir = -1.0
	global_position.x = clampf(global_position.x, _left(), _right())
	global_position.y = water_rect.position.y + 3.0 + sin(_t * 3.0) * 2.0

## Nadando el dibujo se corre hacia abajo y el agua lo corta: solo se ve la aleta.
func _update_sprite() -> void:
	_sprite.flip_h = dir > 0.0   # El dibujo mira a la izquierda
	var swimming := state == State.SWIM
	_sprite.position = Vector2(0, _swim_offset()) if swimming else Vector2.ZERO
	_waterline.set_shader_parameter("cut", swimming)
	_waterline.set_shader_parameter("water_y", water_rect.position.y + 4.0)

## Nadando: distancia del centro del cuerpo por debajo del nodo (que va en la superficie).
func _swim_offset() -> float:
	return (TEXTURE.get_height() * 0.5 - IMG_SURFACE_Y) * _k + _dive * DIVE_DEPTH

func _find_prey() -> Villager:
	var best: Villager = null
	var best_d := INF
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if villager == null or not villager.in_water or villager.drowning or villager.dragging or villager.eaten:
			continue
		var d := absf(villager.global_position.x - global_position.x)
		if d < best_d:
			best_d = d
			best = villager
	return best

func _bite(prey: Villager) -> void:
	prey.get_eaten()
	_cooldown = bite_cooldown
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_dive", 1.0, 0.15)
	_tween.tween_interval(0.6)
	_tween.tween_property(self, "_dive", 0.0, 0.4)

func _draw() -> void:
	if state != State.SWIM:
		return
	# Estela de espuma
	var k := 1.0 - _dive
	if k <= 0.02:
		return
	var foam := Color(1, 1, 1, 0.6 * k)
	var wobble := sin(_t * 8.0) * 2.0
	draw_line(Vector2(-dir * 16.0, 1), Vector2(-dir * (34.0 + wobble), 2), foam, 2.0)
	draw_line(Vector2(dir * 16.0, 1), Vector2(dir * 22.0, 0), foam, 2.0)

# ---- Agarrarlo ----
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if not active or state == State.HELD or Gun.armed or get_tree().paused:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	var m := get_global_mouse_position()
	if not _hit(m) or _villager_at(m):
		return
	_start_hold(m)
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Atrapa el soltado del click izquierdo en cualquier parte de la pantalla
	if state == State.HELD and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release()
		get_viewport().set_input_as_handled()

## ¿El punto toca al tiburón? Nadando solo cuenta la aleta (con margen, que se mueve rápido).
func _hit(p: Vector2) -> bool:
	if state == State.SWIM:
		if _dive > 0.6:
			return false
		var fin := Rect2(IMG_FIN.position * _k, IMG_FIN.size * _k)
		fin.position -= TEXTURE.get_size() * 0.5 * _k
		fin.position.y += _swim_offset()
		if dir > 0.0:
			fin.position.x = -fin.end.x
		return fin.grow(10.0).has_point(p - global_position)
	var body := Rect2(-TEXTURE.get_size() * 0.5 * _k, TEXTURE.get_size() * _k).grow(-8.0)
	return body.has_point(to_local(p))

## Agarrar aldeanos tiene prioridad (uno flotando encima de la aleta).
func _villager_at(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collide_with_bodies = true
	for r in get_world_2d().direct_space_state.intersect_point(q, 8):
		if r.collider is Villager and not r.collider.eaten:
			return true
	return false

func _start_hold(m: Vector2) -> void:
	if _tween:
		_tween.kill()
	if state == State.SWIM:
		# Sale del agua: el nodo pasa a estar en el centro del cuerpo
		global_position.y += _swim_offset()
		_dive = 0.0
		rotation = 0.0
		_splash(Vector2(global_position.x, water_rect.position.y), 26)
	_set_on_land_layer(false)
	state = State.HELD
	_grab_local = to_local(m)
	_prev_mouse = m
	_mouse_vel = Vector2.ZERO
	_mouse_acc = Vector2.ZERO
	_throw_vel = Vector2.ZERO
	_swing_vel = 0.0
	z_index = 10

func _hold(dt: float) -> void:
	var m := get_global_mouse_position()
	if dt > 0.0:
		var mv := (m - _prev_mouse) / dt
		var ma := ((mv - _mouse_vel) / dt).limit_length(MAX_MOUSE_ACC)
		_mouse_vel = mv
		_mouse_acc = _mouse_acc.lerp(ma, 0.35)
		_throw_vel = _throw_vel.lerp(mv, 1.0 - exp(-THROW_SMOOTH * dt))
	_prev_mouse = m

	# Cuelga como péndulo del punto agarrado y encima se sacude a coletazos
	var g := Vector2(0.0, GRAVITY) - _mouse_acc
	var r := (-_grab_local).rotated(rotation)
	if r.length() > 4.0:
		_swing_vel += SWING_K * r.normalized().cross(g / GRAVITY) * dt
	_swing_vel += sin(_t * THRASH_FREQ) * THRASH * dt
	_swing_vel *= exp(-SWING_DAMP * dt)
	rotation += _swing_vel * dt
	global_position = m - _grab_local.rotated(rotation)

func _release() -> void:
	var throw := _throw_vel.limit_length(THROW_MAX_SPEED)
	if throw.length() < THROW_MIN_SPEED and _on_island(global_position):
		_start_land()
		return
	state = State.FLYING
	_vel = throw if throw.length() >= THROW_MIN_SPEED else Vector2.ZERO
	_spin = clampf(_swing_vel + _vel.x * 0.004, -10.0, 10.0)
	_launch_y = global_position.y
	_left_island = not _on_island(global_position)

# ---- Volando ----
func _fly(dt: float) -> void:
	_vel.y += GRAVITY * dt
	global_position += _vel * dt
	rotation += _spin * dt

	var view := get_viewport().get_visible_rect()
	var half_w := SPRITE_W * 0.5
	if (global_position.x < view.position.x + half_w and _vel.x < 0.0) \
			or (global_position.x > view.end.x - half_w and _vel.x > 0.0):
		_vel.x *= -0.5
		_spin *= -0.6

	if _on_island(global_position):
		if _vel.y > 0.0 and (_left_island or global_position.y - _launch_y > LAND_DROP):
			_start_land()
	else:
		_left_island = true
		if global_position.y >= water_rect.position.y + 8.0 and _vel.y > 0.0:
			_back_to_water(true)

# ---- En la isla ----
func _start_land() -> void:
	state = State.LAND
	_ground = global_position
	_h = 0.0
	_hv = 0.0
	_ground_vel = Vector2.ZERO
	_flop_t = randf_range(0.2, 0.4)
	z_index = 0
	_set_on_land_layer(true)
	_puff(_ground + Vector2(0, 14), Color(0.93, 0.8, 0.55), 14)

func _flop(dt: float) -> void:
	if _h > 0.0 or _hv > 0.0:
		_hv -= FLOP_GRAVITY * dt
		_h += _hv * dt
		_ground += _ground_vel * dt
		rotation = lerp_angle(rotation, -dir * 0.35 * signf(_hv), 8.0 * dt)
		if _h <= 0.0:
			_h = 0.0
			_hv = 0.0
			_ground_vel = Vector2.ZERO
			_puff(_ground + Vector2(0, 14), Color(0.93, 0.8, 0.55), 8)
	else:
		# Tirado en la arena: coletea y cada tanto pega un salto (casi siempre hacia el agua)
		rotation = lerp_angle(rotation, sin(_t * 18.0) * 0.12, 12.0 * dt)
		_flop_t -= dt
		if _flop_t <= 0.0:
			_flop_t = randf_range(FLOP_EVERY.x, FLOP_EVERY.y)
			_hv = randf_range(FLOP_HOP.x, FLOP_HOP.y)
			dir = 1.0 if randf() < 0.5 else -1.0
			_ground_vel = Vector2(dir * randf_range(20.0, 60.0), randf_range(30.0, 70.0))
	global_position = _ground - Vector2(0, _h)

	# Se salió de la isla de un salto: se cae
	if not _on_island(_ground):
		_set_on_land_layer(false)
		z_index = 10
		state = State.FLYING
		_vel = Vector2(_ground_vel.x, -_hv)
		_spin = dir * 3.0
		_left_island = true
		_launch_y = global_position.y

# ---- De vuelta al agua ----
func _back_to_water(splash: bool) -> void:
	_set_on_land_layer(false)
	state = State.SWIM
	z_index = 0
	rotation = 0.0
	global_position = Vector2(clampf(global_position.x, _left(), _right()), water_rect.position.y + 3.0)
	if absf(_vel.x) > 20.0:
		dir = signf(_vel.x)
	if not splash:
		return
	_splash(global_position, 36)
	_cooldown = 0.8
	_dive = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(0.5)
	_tween.tween_property(self, "_dive", 0.0, 0.5)

## En la isla va en Props, así los aldeanos de adelante lo tapan y él tapa a los de atrás.
## En el agua vuelve a su lugar de siempre: debajo de los aldeanos.
func _set_on_land_layer(on: bool) -> void:
	var props: Node = _world.get("props")
	if on and props and get_parent() != props:
		reparent(props)
	elif not on and get_parent() != _world:
		reparent(_world)
		var ground: Node = _world.get("ground")
		if ground:
			_world.move_child(self, ground.get_index())

func _on_island(p: Vector2) -> bool:
	var poly: Variant = _world.get("island_poly_global")
	return poly is PackedVector2Array and poly.size() > 0 and Geometry2D.is_point_in_polygon(p, poly)

func _splash(at: Vector2, amount: int) -> void:
	_puff(at, Color(0.85, 0.95, 1.0), amount, 260.0)

func _puff(at: Vector2, color: Color, amount: int, speed := 140.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector2.UP
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = color
	p.z_index = 15
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
