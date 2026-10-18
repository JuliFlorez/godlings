extends Node2D
class_name Shark
## Tiburón: patrulla el agua (solo asoma la aleta) y se come a los aldeanos que están flotando.
## Arranca apagado: se compran en la tienda (hasta MAX) y se pueden apagar y prender.
## Se lo puede agarrar de la aleta y sacar del agua: cuelga y se sacude, se lo puede tirar
## y, si cae en la isla, va saltando con la boca abierta (y se come a los aldeanos que alcanza)
## hasta volver a caerse al agua.
## Con la pistola se lo puede matar: queda panza arriba y hay que volver a comprarlo.

## Lo mataron de un tiro (el HUD lo da por perdido: hay que volver a comprarlo).
signal killed

const PRICE := 40
const MAX := 2

@export var water_path: NodePath
@export var patrol_speed := 60.0
@export var hunt_speed := 170.0
@export var bite_range := 16.0
@export var bite_cooldown := 1.5

enum State { SWIM, HELD, FLYING, LAND }

const TEXTURE := preload("res://actors/shark.png")
const SHADER := preload("res://actors/shark.gdshader")
const SPRITE_W := 150.0          # Ancho en pantalla del tiburón entero
# Referencias en píxeles del dibujo (mira a la izquierda)
const IMG_SURFACE_Y := 85.0      # Fila que queda en la línea del agua al nadar: asoma la aleta
const IMG_FIN := Rect2(200, 0, 100, 85)
const IMG_MOUTH := Vector2(100, 182)   # Centro de la boca abierta
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

# En la isla: saltitos de pescado fuera del agua, con la boca abierta (la abre shark.gdshader)
const FLOP_GRAVITY := 900.0
const FLOP_EVERY := Vector2(0.35, 0.75)
const FLOP_HOP := Vector2(150.0, 230.0)
const JAW_OPEN := 0.45           # Apertura de la boca (radianes)
const HUNT_RADIUS := 230.0       # Hasta dónde ve aldeanos para saltarles encima
const HUNT_HOP_SPEED := 190.0    # Velocidad máxima de un salto de caza
const LAND_BITE_REACH := Vector2(22.0, 18.0)   # Boca-aldeano: de costado y en profundidad

# Muerto a los tiros: panza arriba
const SHOT_FORCE := 260.0
const SHOT_HOP := 200.0          # Saltito en la arena con cada tiro
const IMG_BELLY_UP_Y := 175.0    # Flotando panza arriba: fila del dibujo que queda en la línea del agua
const DEAD_FLOAT_TIME := 2.5     # Flota un rato antes de hundirse
const DEAD_SINK_TIME := 2.2
const DEAD_LAND_TIME := 6.0      # Tirado en la isla antes de desvanecerse
const C_BLOOD := Color(0.8, 0.05, 0.05)

## Para saber si un tiro cae sobre el dibujo o en lo transparente.
static var _alpha: Image

var water_rect := Rect2(0, 570, 1150, 76)
var dir := 1.0
var _t := 0.0
var _cooldown := 0.0
var _dive := 0.0   # 0 = aleta afuera, 1 = sumergida (mientras muerde)
var active := false
var dead := false
var _tween: Tween

var state := State.SWIM
var _world: Node2D              # En la isla se muda a la capa ordenada por Y (Props)
var _sprite: Sprite2D
var _material: ShaderMaterial
var _k := 1.0                    # Escala del dibujo
var _mouth := Vector2.ZERO       # Centro de la boca (local, mirando a la izquierda)
var _jaw := 0.0                  # Apertura actual de la boca
var _chomp := 0.0                # Recién mordió: la boca queda cerrada un rato
var _prey: Villager              # En la isla: el aldeano al que le está saltando encima
var _roll := 0.0                 # 0 = derecho, 1 = panza arriba
var _dead_t := 0.0               # Desde que cayó muerto al agua (la mancha de sangre crece)
var _pooled := false             # Ya dejó su charco de sangre en la arena

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
	add_to_group("shark")
	var water := get_node_or_null(water_path)
	if water and water.has_method("get_global_rect"):
		water_rect = water.get_global_rect()
	global_position = Vector2(randf_range(_left(), _right()), water_rect.position.y)
	dir = 1.0 if randf() < 0.5 else -1.0
	_world = get_parent()

	_k = SPRITE_W / TEXTURE.get_width()
	_mouth = (IMG_MOUTH - TEXTURE.get_size() * 0.5) * _k
	if _alpha == null:
		_alpha = TEXTURE.get_image()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.scale = Vector2.ONE * _k
	_sprite.material = _material
	add_child(_sprite)

	visible = false
	set_process(false)

## Prendido: emerge en un lugar al azar del agua. Apagado: se sumerge y deja de cazar.
## Si lo vuelven a comprar mientras todavía se está muriendo, sale uno nuevo.
func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if state != State.SWIM:
		_back_to_water(false)
	if dead:
		_revive()
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
	_chomp -= dt
	_dead_t += dt
	match state:
		State.SWIM:
			_swim(dt)
		State.HELD:
			_hold(dt)
		State.FLYING:
			_fly(dt)
		State.LAND:
			_flop(dt)
	_update_jaw(dt)
	_update_sprite()
	queue_redraw()

func _swim(dt: float) -> void:
	if dead:
		# Panza arriba: flota quieto entre la sangre
		global_position.y = water_rect.position.y + 3.0 + sin(_t * 2.0) * 1.5
		return
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

## Nadando el dibujo se corre hacia abajo y el agua lo corta: solo se ve la aleta
## (o la panza, si está muerto).
func _update_sprite() -> void:
	_sprite.flip_h = dir > 0.0   # El dibujo mira a la izquierda
	_sprite.scale = Vector2(_k, _k * cos(_roll * PI))   # Rueda hasta quedar panza arriba
	var swimming := state == State.SWIM
	_sprite.position = Vector2(0, _swim_offset()) if swimming else Vector2.ZERO
	_material.set_shader_parameter("cut", swimming)
	_material.set_shader_parameter("water_y", water_rect.position.y + 4.0)
	_material.set_shader_parameter("jaw", _jaw)

## Nadando: distancia del centro del cuerpo por debajo del nodo (que va en la superficie).
func _swim_offset() -> float:
	var fin_up := (TEXTURE.get_height() * 0.5 - IMG_SURFACE_Y) * _k
	var belly_up := (IMG_BELLY_UP_Y - TEXTURE.get_height() * 0.5) * _k
	return lerpf(fin_up, belly_up, _roll) + _dive * DIVE_DEPTH

## En la isla abre la boca en cada salto: del todo si va a comerse a alguien.
func _update_jaw(dt: float) -> void:
	var target := 0.0
	if dead:
		target = JAW_OPEN * 0.25   # Muerto, con la boca floja
	elif state == State.LAND and (_h > 0.0 or _hv > 0.0) and _chomp <= 0.0:
		target = JAW_OPEN if is_instance_valid(_prey) else JAW_OPEN * 0.6
	_jaw = move_toward(_jaw, target, (3.0 if target > _jaw else 10.0) * dt)

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
	if dead:
		# Mancha de sangre en el agua
		var r := minf(_dead_t * 50.0, 60.0)
		draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, r, Color(C_BLOOD, 0.45), true, -1.0, true)
		draw_circle(Vector2(r * 0.3, 0.0), r * 0.6, Color(C_BLOOD.darkened(0.2), 0.4), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
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
	_prey = null
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
	if dead:
		_die_on_land()

func _flop(dt: float) -> void:
	if _h > 0.0 or _hv > 0.0:
		_hv -= FLOP_GRAVITY * dt
		_h += _hv * dt
		_ground += _ground_vel * dt
		var tilt := 0.0 if dead else -dir * 0.35 * signf(_hv)
		rotation = lerp_angle(rotation, tilt, 8.0 * dt)
		if _h <= 0.0:
			_h = 0.0
			_hv = 0.0
			_ground_vel = Vector2.ZERO
			_puff(_ground + Vector2(0, 14), Color(0.93, 0.8, 0.55), 8)
			if dead:
				_bleed_on_sand()
	elif dead:
		rotation = lerp_angle(rotation, 0.0, 10.0 * dt)
	else:
		# Tirado en la arena: coletea y cada tanto pega un salto
		rotation = lerp_angle(rotation, sin(_t * 18.0) * 0.12, 12.0 * dt)
		_flop_t -= dt
		if _flop_t <= 0.0:
			_flop_t = randf_range(FLOP_EVERY.x, FLOP_EVERY.y)
			_hop()
	global_position = _ground - Vector2(0, _h)
	if not dead:
		_bite_on_land()

	# Se salió de la isla de un salto: se cae
	if not _on_island(_ground):
		_set_on_land_layer(false)
		z_index = 10
		state = State.FLYING
		_vel = Vector2(_ground_vel.x, -_hv)
		_spin = dir * 3.0
		_left_island = true
		_launch_y = global_position.y

## Salta hacia el aldeano más cercano para caerle con la boca encima.
## Si no ve a nadie salta para cualquier lado (casi siempre hacia el agua).
func _hop() -> void:
	_hv = randf_range(FLOP_HOP.x, FLOP_HOP.y)
	_prey = _find_land_prey() if _cooldown <= 0.0 else null
	if _prey == null:
		dir = 1.0 if randf() < 0.5 else -1.0
		_ground_vel = Vector2(dir * randf_range(20.0, 60.0), randf_range(30.0, 70.0))
		return
	var to_x := _prey.global_position.x - _ground.x
	if absf(to_x) > 4.0:
		dir = signf(to_x)
	var target := Vector2(_prey.global_position.x + dir * _mouth.x, _prey.global_position.y)
	var air_time := 2.0 * _hv / FLOP_GRAVITY
	_ground_vel = ((target - _ground) / air_time).limit_length(HUNT_HOP_SPEED)

func _is_land_prey(v: Villager) -> bool:
	return v != null and not (v.dragging or v.falling or v.in_water or v.eaten) and _on_island(v.global_position)

func _find_land_prey() -> Villager:
	var best: Villager = null
	var best_d := HUNT_RADIUS
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if not _is_land_prey(villager):
			continue
		var d := villager.global_position.distance_to(_ground)
		if d < best_d:
			best_d = d
			best = villager
	return best

## Con la boca abierta, se come al aldeano que le queda adentro.
func _bite_on_land() -> void:
	if _cooldown > 0.0 or _jaw < JAW_OPEN * 0.5:
		return
	var mouth := _mouth_global()
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if not _is_land_prey(villager):
			continue
		if absf(villager.global_position.x - mouth.x) < LAND_BITE_REACH.x \
				and absf(villager.global_position.y - _ground.y) < LAND_BITE_REACH.y:
			villager.get_eaten(mouth)
			_cooldown = bite_cooldown
			_chomp = 0.3
			_prey = null
			_flop_t = randf_range(0.6, 0.9)   # Se queda masticando un momento
			return

func _mouth_global() -> Vector2:
	var m := Vector2(-_mouth.x if _sprite.flip_h else _mouth.x, _mouth.y)
	return to_global(m + _sprite.position)

# ---- A los tiros ----
## ¿Un tiro en este punto le pega? Nadando, solo en la aleta; si no, sobre el dibujo
## (lo transparente no cuenta).
func is_shot_at(p: Vector2) -> bool:
	if not visible or not (active or dead) or modulate.a < 0.3:
		return false
	if state == State.SWIM:
		if not dead:
			return _hit(p)
		if p.y > water_rect.position.y + 4.0:
			return false   # Flotando panza arriba: lo que está bajo el agua no se ve
	if absf(_sprite.scale.y) < 0.05:
		return false
	var px := (to_local(p) - _sprite.position) / _sprite.scale
	if _sprite.flip_h:
		px.x = -px.x
	px += TEXTURE.get_size() * 0.5
	if not Rect2(Vector2.ZERO, TEXTURE.get_size()).has_point(px):
		return false
	return _alpha.get_pixelv(Vector2i(px)).a > 0.5

## Si se dibuja delante del aldeano (para saber a cuál de los dos le pega un tiro).
func is_in_front_of(v: Villager) -> bool:
	if state == State.SWIM or v.z_index > z_index:
		return false   # En el agua los aldeanos flotan por encima de él
	if v.z_index < z_index:
		return true
	return state == State.LAND and global_position.y >= v.global_position.y

## Le pegaron un tiro (ver Gun): se muere y hay que volver a comprarlo en la tienda.
## Muerto se lo puede seguir baleando: sangra y, en la isla, salta con cada tiro.
func shoot(at: Vector2, shot_dir: Vector2) -> void:
	_puff(at, C_BLOOD, 30, 260.0, shot_dir)
	var push := shot_dir.normalized() * SHOT_FORCE
	var was_dead := dead
	if not dead:
		dead = true
		active = false
		_prey = null
		killed.emit()
	match state:
		State.SWIM:
			if not was_dead:
				_die_in_water()
		State.HELD:
			state = State.FLYING
			_vel = push
			_spin = clampf(_swing_vel, -10.0, 10.0)
			_launch_y = global_position.y
			_left_island = not _on_island(global_position)
		State.FLYING:
			_vel += push
			_spin += signf(push.x) * 3.0
		State.LAND:
			_hv = maxf(_hv, SHOT_HOP)
			_ground_vel = Vector2(push.x * 0.5, 0.0)
			_die_on_land()

## Muerto en el agua: rueda panza arriba, flota un rato entre la sangre y se hunde.
func _die_in_water() -> void:
	if _tween:
		_tween.kill()
	_dead_t = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "_roll", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(self, "_dive", 0.0, 0.4)
	_tween.tween_interval(DEAD_FLOAT_TIME)
	_tween.tween_property(self, "_dive", 1.0, DEAD_SINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, DEAD_SINK_TIME)
	_tween.tween_callback(_vanish)

## Muerto en la isla: queda panza arriba y al rato se desvanece (cada tiro reinicia la cuenta).
func _die_on_land() -> void:
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	if _h <= 0.0 and _hv <= 0.0:
		_bleed_on_sand()
	_tween = create_tween()
	_tween.tween_property(self, "_roll", 1.0, 0.35)
	_tween.tween_interval(DEAD_LAND_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, 1.5)
	_tween.tween_callback(_vanish)

func _bleed_on_sand() -> void:
	if _pooled:
		return
	_pooled = true
	var pool := Villager.BloodPool.new()
	pool.scale = Vector2.ONE * 2.5
	var layer := get_tree().get_first_node_in_group("ground_layer")
	(layer if layer else get_parent()).add_child(pool)
	pool.global_position = _ground + Vector2(0, 24)

## Terminó de morirse: desaparece hasta que lo vuelvan a comprar.
func _vanish() -> void:
	_back_to_water(false)
	_revive()
	visible = false
	set_process(false)

func _revive() -> void:
	dead = false
	_roll = 0.0
	_jaw = 0.0
	_pooled = false
	modulate.a = 1.0
	rotation = 0.0

# ---- De vuelta al agua ----
func _back_to_water(splash: bool) -> void:
	_set_on_land_layer(false)
	state = State.SWIM
	z_index = 0
	rotation = 0.0
	_prey = null
	global_position = Vector2(clampf(global_position.x, _left(), _right()), water_rect.position.y + 3.0)
	if absf(_vel.x) > 20.0:
		dir = signf(_vel.x)
	if not splash:
		return
	_splash(global_position, 36)
	if dead:
		_die_in_water()
		return
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

func _puff(at: Vector2, color: Color, amount: int, speed := 140.0, toward := Vector2.UP) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.6
	p.direction = toward
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
