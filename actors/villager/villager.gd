extends CharacterBody2D
class_name Villager

@export var speed := 40.0
var dir := Vector2.ZERO

var island_center := Vector2.ZERO
var island_poly: PackedVector2Array:
	set(value):
		island_poly = value
		if island_poly.size() > 0:
			var sum := Vector2.ZERO
			for p in island_poly:
				sum += p
			island_center = sum / float(island_poly.size())

var dragging := false
var grab_local := Vector2.ZERO   # Punto del cuerpo (local) por donde se agarró

# --- Ragdoll al arrastrar: el cuerpo cuelga como péndulo del punto de agarre ---
const BODY_COM := Vector2(0, 5)  # Centro de masa aproximado (local)
const SWING_K := 38.0            # Fuerza del péndulo
const SWING_DAMP := 1.6          # Amortiguación del balanceo
const MAX_MOUSE_ACC := 6000.0
var swing_vel := 0.0             # Velocidad angular del cuerpo (rad/s)
var _prev_mouse := Vector2.ZERO
var _mouse_vel := Vector2.ZERO
var _mouse_acc := Vector2.ZERO

# HUD / XP
@export var hud_path: NodePath
var hud: HUD
var xp_granted := false      # Evita sumar dos veces por ahogo

# --- Caída / Gravedad fuera de la isla ---
const GRAVITY := 1400.0
var falling := false
var v_fall := 0.0

# --- Agua / Flotación + Ahogo ---
var in_water := false
var touching_water := false   # El cuerpo toca el área de agua (puede ser solo la orilla)
var water_surface_y := 0.0
var bob_t := 0.0
const BOB_AMP := 6.0
const BOB_SPEED := 2.2

# Ahogo
const DROWN_DELAY := 5.0      # Segundos antes de empezar a hundirse
const SINK_SPEED  := 120.0    # px/s al hundirse
const FADE_RATE   := 0.6      # Alfa por segundo que se reduce
var drowning := false
var drown_elapsed := 0.0

# Comido por el tiburón
var eaten := false

# --- Muerte por disparo: el cadáver sale despedido y cae en ragdoll ---
const SHOT_FORCE := 300.0     # Empuje horizontal del balazo
const SHOT_HOP := 240.0       # Saltito hacia arriba al recibir el tiro
const HEAD_Y := 0.0           # Impactos por encima de esto (local) son tiros a la cabeza
const FEET_DROP := 16.0       # Tirado en el piso, el centro queda más abajo que de pie
const CORPSE_TIME := 12.0     # Segundos tirado antes de desvanecerse
var dead := false
var corpse_grounded := false
var corpse_vel := Vector2.ZERO
var floor_y := 0.0            # Altura del "piso" donde cae el cadáver
var corpse_timer := 0.0
var fall_vx := 0.0            # Deriva horizontal al caer (cadáver empujado fuera de la isla)

# --- Espacio personal y empujones ---
# Los aldeanos no chocan físicamente entre sí: se esquivan con una separación suave.
# El que está agarrado sí empuja a los demás, y los puede tirar de la isla.
const SEPARATION_RADIUS := 18.0  # Distancia (entre pies) a la que empiezan a apartarse
const SEPARATION_SPEED := 35.0   # Velocidad de apartarse cuando están encimados
const BODY_HALF_W := 10.0        # Medio ancho del cuerpo (cápsula) para los empujones
const BODY_TOP := -36.0          # Extremos del cuerpo (local), igual que la colisión
const BODY_BOTTOM := 31.0
const SHOVE_TIME := 0.4          # Tras un empujón, salir de la isla = caerse
const SHOVE_FRICTION := 1500.0   # Frenado del empujón (px/s²)
const MAX_SHOVE := 600.0
var shove_vel := Vector2.ZERO
var shove_timer := 0.0

# IA y animaciones
var wander_timer := 0.0
@onready var rig: VillagerRig = get_node_or_null("Rig")

func _ready() -> void:
	randomize()
	_pick_dir()
	wander_timer = randf_range(1.5, 4.0)
	input_pickable = true

	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	_ensure_hud()

func _ensure_hud() -> void:
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud") as HUD

func enter_water(surface_y: float) -> void:
	touching_water = true
	water_surface_y = surface_y
	# Caminando por la orilla el cuerpo roza el agua, pero sigue en tierra
	if falling or dragging:
		_start_floating()

func _start_floating() -> void:
	in_water = true
	falling = false
	drowning = false
	drown_elapsed = 0.0
	v_fall = 0.0
	bob_t = 0.0
	modulate.a = 1.0
	# Arrastrándolo por encima del agua sigue colgando y balanceándose
	if not dragging:
		swing_vel = 0.0
		z_index = 0

func exit_water() -> void:
	touching_water = false
	# Ahogándose se hunde por debajo del área de agua: sigue hasta desaparecer
	if drowning and not dragging:
		return
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0

func _physics_process(dt: float) -> void:
	if eaten:
		return
	if dragging:
		velocity = Vector2.ZERO
		return

	# --- Agua: flotar o ahogarse ---
	if in_water:
		bob_t += dt

		# Temporizador de ahogo
		if not drowning:
			drown_elapsed += dt
			if drown_elapsed >= DROWN_DELAY:
				drowning = true
				_grant_sacrifice_xp()

		if drowning:
			# Hundirse y desvanecerse
			global_position.y += SINK_SPEED * dt
			modulate.a = max(0.0, modulate.a - FADE_RATE * dt)
			rotation = lerp_angle(rotation, 0.5, 3.0 * dt)
			velocity = Vector2.ZERO
			if modulate.a <= 0.02:
				queue_free()
			return
		else:
			# Flotación suave y balanceo
			var target_y := water_surface_y + sin(bob_t * BOB_SPEED) * BOB_AMP
			global_position.y = move_toward(global_position.y, target_y, 120.0 * dt)
			global_position.x += sin(bob_t * 0.8) * 10.0 * dt
			var float_rot := _lie_angle() if dead else 0.0
			rotation = lerp_angle(rotation, float_rot + sin(bob_t * 0.9) * 0.08, 4.0 * dt)
			velocity = Vector2.ZERO
			return

	# --- Caída libre fuera de la isla ---
	if falling:
		v_fall += GRAVITY * dt
		global_position.y += v_fall * dt
		global_position.x += fall_vx * dt
		rotation += swing_vel * dt

		# Si cae de regreso a la tierra
		if island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly):
			_land_on_island()
			return

		var kill_y := get_viewport().get_visible_rect().size.y + 150.0
		if global_position.y > kill_y:
			queue_free()
		return

	if dead:
		_corpse_physics(dt)
		return

	# --- IA normal caminando en la isla ---
	rotation = lerp_angle(rotation, 0.0, 10.0 * dt)
	shove_vel = shove_vel.move_toward(Vector2.ZERO, SHOVE_FRICTION * dt)
	shove_timer = maxf(0.0, shove_timer - dt)
	velocity = dir * speed + _separation() + shove_vel
	var prev_pos := global_position
	move_and_slide()

	# Si cruza el borde del polígono de la isla, retroceder y girar hacia el centro.
	# Si ya estaba afuera no se retrocede: así vuelve caminando.
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(global_position, island_poly):
		if shove_timer > 0.0:
			# Lo empujaron fuera de la isla: se cae
			_fall_from_shove()
			return
		if Geometry2D.is_point_in_polygon(prev_pos, island_poly):
			global_position = prev_pos
		var to_center := (island_center - global_position).normalized()
		dir = to_center.rotated(randf_range(-0.35, 0.35)).normalized()
		_update_sprite_flip()
		wander_timer = randf_range(1.5, 3.5)
	else:
		wander_timer -= dt
		if wander_timer <= 0.0:
			_pick_dir()
			wander_timer = randf_range(2.0, 5.0)

## Empuje suave para no quedar encimado con otros aldeanos en tierra.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.dragging or o.falling or o.in_water or o.eaten:
			continue
		var d := global_position - o.global_position
		var dist := d.length()
		if dist >= SEPARATION_RADIUS:
			continue
		if dist < 0.01:
			d = Vector2.RIGHT.rotated(randf() * TAU)
			dist = 1.0
		push += d / dist * (1.0 - dist / SEPARATION_RADIUS)
	return push.limit_length(1.0) * SEPARATION_SPEED

## Eje del cuerpo en coordenadas globales (cápsula de radio BODY_HALF_W).
func _body_segment() -> PackedVector2Array:
	return PackedVector2Array([
		to_global(Vector2(0.0, BODY_TOP + BODY_HALF_W)),
		to_global(Vector2(0.0, BODY_BOTTOM - BODY_HALF_W)),
	])

## Llamado mientras está agarrado: aparta a los aldeanos que toca.
func _shove_others() -> void:
	var mine := _body_segment()
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.dragging or o.falling or o.in_water or o.eaten:
			continue
		var theirs := o._body_segment()
		var pts := Geometry2D.get_closest_points_between_segments(mine[0], mine[1], theirs[0], theirs[1])
		var d := pts[1] - pts[0]
		var dist := d.length()
		if dist >= BODY_HALF_W * 2.0:
			continue
		var n := d / dist if dist > 0.01 else Vector2(1.0 if o.global_position.x >= global_position.x else -1.0, 0.0)
		# Lo saca de adentro del cuerpo, y si el golpe viene rápido, sale despedido
		o.get_shoved(n * (BODY_HALF_W * 2.0 - dist), n * maxf(_mouse_vel.dot(n), 0.0))

func get_shoved(offset: Vector2, vel: Vector2) -> void:
	global_position += offset
	vel = vel.limit_length(MAX_SHOVE)
	if dead:
		floor_y += offset.y
		if absf(vel.x) > absf(corpse_vel.x):
			corpse_vel.x = vel.x
		corpse_timer = 0.0
		return
	if vel.length() > shove_vel.length():
		shove_vel = vel
	shove_timer = SHOVE_TIME

func _fall_from_shove() -> void:
	var push := shove_vel
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	_start_fall()
	if falling:
		fall_vx = push.x
		v_fall = minf(push.y, 0.0)
		swing_vel = clampf(push.x * 0.02, -8.0, 8.0)  # Que trastabille al caer

func _grant_sacrifice_xp() -> void:
	if xp_granted:
		return
	xp_granted = true
	_ensure_hud()
	if hud and hud.has_method("add_xp"):
		hud.add_xp(1)

# --- DISPARO / MUERTE ---
## Llamado por la pistola. hit_point y shot_dir en coordenadas globales.
func shoot(hit_point: Vector2, shot_dir: Vector2) -> void:
	if eaten:
		return
	var headshot := to_local(hit_point).y < HEAD_Y
	var power := 1.3 if headshot else 1.0
	_spawn_blood(hit_point, shot_dir, 40 if headshot else 24)
	if rig:
		rig.hit(hit_point, shot_dir, power)

	var was_dead := dead
	_die()

	var push := shot_dir.normalized() * SHOT_FORCE * power
	# Giro según dónde pegó respecto al centro de masa (en la cabeza lo voltea)
	var spin := (hit_point - to_global(BODY_COM)).cross(push) * 0.0016

	if dragging:
		swing_vel += spin
	elif in_water:
		global_position.x += signf(push.x) * 4.0
		swing_vel = 0.0
	elif falling:
		fall_vx += push.x * 0.6
		v_fall = minf(v_fall, 0.0) - SHOT_HOP * 0.5
		swing_vel += spin
	else:
		if not was_dead:
			swing_vel = 0.0
		corpse_grounded = false
		corpse_vel = Vector2(push.x, minf(push.y, 0.0) - SHOT_HOP)
		# Que se desplome hacia donde lo empujaron
		swing_vel += spin + signf(push.x) * 4.0

func _die() -> void:
	if dead:
		corpse_timer = 0.0
		modulate.a = 1.0
		return
	dead = true
	corpse_grounded = false
	corpse_timer = 0.0
	floor_y = global_position.y + FEET_DROP
	velocity = Vector2.ZERO
	_grant_sacrifice_xp()
	if rig:
		rig.set_dead()

func _corpse_physics(dt: float) -> void:
	velocity = Vector2.ZERO
	global_position.x += corpse_vel.x * dt

	# Si el empujón lo sacó de la isla, cae al agua
	var ground_pt := Vector2(global_position.x, floor_y - FEET_DROP)
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(ground_pt, island_poly):
		var vx := corpse_vel.x
		var vy := corpse_vel.y
		_start_fall()
		if falling:
			fall_vx = vx
			v_fall = vy
		return

	if not corpse_grounded:
		corpse_vel.y += GRAVITY * dt
		global_position.y += corpse_vel.y * dt
		rotation += swing_vel * dt
		if global_position.y >= floor_y and corpse_vel.y > 0.0:
			global_position.y = floor_y
			if corpse_vel.y > 260.0:
				# Rebote
				corpse_vel = Vector2(corpse_vel.x * 0.55, -corpse_vel.y * 0.3)
				swing_vel *= 0.5
			else:
				corpse_grounded = true
				corpse_vel.y = 0.0
				swing_vel = 0.0
				_spawn_blood_pool()
		return

	# Tirado en el piso: se arrastra un poco y queda acostado
	corpse_vel.x = move_toward(corpse_vel.x, 0.0, 600.0 * dt)
	rotation = lerp_angle(rotation, _lie_angle(), 10.0 * dt)
	corpse_timer += dt
	if corpse_timer > CORPSE_TIME:
		modulate.a = maxf(0.0, modulate.a - 0.8 * dt)
		if modulate.a <= 0.02:
			queue_free()

## Acostado de costado: el más cercano entre ±90°.
func _lie_angle() -> float:
	if absf(angle_difference(rotation, PI * 0.5)) <= absf(angle_difference(rotation, -PI * 0.5)):
		return PI * 0.5
	return -PI * 0.5

func _spawn_blood_pool() -> void:
	var pool := BloodPool.new()
	get_parent().add_child(pool)
	get_parent().move_child(pool, get_index())  # Debajo del cuerpo
	pool.global_position = Vector2(global_position.x, floor_y + 7.0)

class BloodPool extends Node2D:
	const COLOR := Color(0.55, 0.02, 0.03, 0.85)
	var radius := 0.0

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_property(self, "radius", randf_range(13.0, 18.0), 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_interval(CORPSE_TIME)
		tw.tween_property(self, "modulate:a", 0.0, 2.0)
		tw.tween_callback(queue_free)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, radius, COLOR, true, -1.0, true)
		draw_circle(Vector2(radius * 0.35, -radius * 0.2), radius * 0.55, COLOR.darkened(0.15), true, -1.0, true)

# --- TIBURÓN ---
func get_eaten() -> void:
	if eaten:
		return
	eaten = true
	set_physics_process(false)
	_grant_sacrifice_xp()
	_spawn_blood()
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "global_position:y", global_position.y + 45.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_property(self, "rotation", 0.8, 0.35)
	tw.chain().tween_callback(queue_free)

func _spawn_blood(at: Vector2 = global_position, toward: Vector2 = Vector2.UP, amount := 28) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.7
	p.direction = toward
	p.spread = 50.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = Color(0.8, 0.05, 0.05)
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

func _pick_dir() -> void:
	var angle := randf() * TAU
	dir = Vector2(cos(angle), sin(angle)).normalized()
	_update_sprite_flip()

func _update_sprite_flip() -> void:
	if rig and abs(dir.x) > 0.05:
		rig.set_facing_left(dir.x < 0.0)

# --- MECÁNICA DE ARRASTRE (DRAG & DROP) ---
func _process(dt: float) -> void:
	if dragging:
		_update_drag(dt)

func _update_drag(dt: float) -> void:
	var m := get_global_mouse_position()
	if dt > 0.0:
		var mv := (m - _prev_mouse) / dt
		var ma := ((mv - _mouse_vel) / dt).limit_length(MAX_MOUSE_ACC)
		_mouse_vel = mv
		_mouse_acc = _mouse_acc.lerp(ma, 0.35)
	_prev_mouse = m

	# Gravedad efectiva en el marco de la mano: al sacudir, el cuerpo se queda atrás
	var g := Vector2(0.0, GRAVITY) - _mouse_acc
	var r := (BODY_COM - grab_local).rotated(rotation)
	if r.length() > 4.0:
		swing_vel += SWING_K * r.normalized().cross(g / GRAVITY) * dt
	swing_vel *= exp(-SWING_DAMP * dt)
	rotation += swing_vel * dt

	# El punto agarrado queda pegado al cursor
	global_position = m - grab_local.rotated(rotation)
	_shove_others()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging and not eaten and not Gun.armed:
			_start_drag()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Atrapa el soltado del click izquierdo en cualquier parte de la pantalla
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_drag()
		get_viewport().set_input_as_handled()

func _start_drag() -> void:
	dragging = true
	grab_local = (get_global_mouse_position() - global_position).rotated(-rotation)
	_prev_mouse = get_global_mouse_position()
	_mouse_vel = Vector2.ZERO
	_mouse_acc = Vector2.ZERO
	swing_vel = 0.0
	fall_vx = 0.0
	set_physics_process(false)
	z_index = 10
	if dead:
		corpse_timer = 0.0
		modulate.a = 1.0
	# Si estaba medio desvanecido al ser rescatado, restaurar visibilidad parcial
	if drowning:
		modulate.a = max(modulate.a, 0.7)

func _stop_drag() -> void:
	dragging = false
	set_physics_process(true)
	z_index = 0

	var on_island := island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly)
	if on_island:
		# Rescatado o depositado en tierra firme
		_land_on_island()
	else:
		if in_water:
			# Soltado dentro del agua: continúa flotando
			falling = false
			velocity = Vector2.ZERO
		else:
			# Soltado en el aire fuera de la isla: empieza caída libre
			_start_fall()

func _start_fall() -> void:
	if touching_water:
		_start_floating()
		return
	falling = true
	drowning = false
	drown_elapsed = 0.0
	v_fall = 0.0
	corpse_grounded = false
	velocity = Vector2.ZERO
	# Mantiene la rotación y el giro del ragdoll al soltarlo
	swing_vel = clampf(swing_vel, -12.0, 12.0)

func _land_on_island() -> void:
	falling = false
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0
	velocity = Vector2.ZERO
	if dead:
		# El cadáver cae al piso desde donde está y sigue rodando un poco
		corpse_grounded = false
		corpse_vel = Vector2(fall_vx * 0.5, 0.0)
		floor_y = global_position.y + FEET_DROP
		fall_vx = 0.0
		v_fall = 0.0
		return
	v_fall = 0.0
	swing_vel = 0.0
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	_pick_dir()
