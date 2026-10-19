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

# --- Lanzar: soltado con impulso sale volando con la inercia del mouse ---
const THROW_SMOOTH := 25.0       # Suavizado de la velocidad del mouse (1/s)
const THROW_MIN_SPEED := 250.0   # Más lento que esto, soltarlo es solo dejarlo
const THROW_MAX_SPEED := 1800.0
const THROW_LAND_DROP := 40.0    # Lanzado sobre la isla: cuánto baja antes de poder aterrizar
var _throw_vel := Vector2.ZERO
var _launch_y := 0.0
var _flight_left_island := false # Salió de la isla durante el vuelo

# HUD / XP
@export var hud_path: NodePath
var hud: HUD
var xp_granted := false      # Evita sumar dos veces por ahogo
const SACRIFICE_OFFERING := 5

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
const WATERLINE_SHADER := preload("res://actors/villager/waterline.gdshader")
const WATERLINE_DEPTH := 4.0  # Flotando, el agua le llega a la cintura
var _waterline: ShaderMaterial

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

# --- Muerte por rayo (ver Lightning): se electrocuta (tieso, temblando y con el esqueleto a
# la vista), queda carbonizado y humeando, y se desarma en cenizas de la cabeza a los pies.
# Si le cayó en la isla se queda ahí; volando sigue cayendo y se deshace cuando queda tirado,
# y en el agua se hunde.
enum Zap { NONE, SHOCK, CHARRED, ASHES }
const SHOCK_TIME := 1.1
const CHAR_TIME := 0.8        # Carbonizado, todavía entero, antes de deshacerse
const ASH_TIME := 1.2         # Lo que tarda en deshacerse
const XRAY_HZ := 11.0         # Cuadros de rayos X por segundo
const HEAD_TOP := -44.0       # Coronilla y planta de los pies (local)
const FEET := 32.0
const CRUMBLE_EDGE := 8.0     # Lo que sobresale el borde desgranado (ver waterline.gdshader)
var zap_state := Zap.NONE
var _zap_t := 0.0
var _zap_pinned := false      # Le cayó en la isla: no se mueve de ahí
var _xray_mat: ShaderMaterial # El esqueleto: con el recorte del agua, pero sin oscurecerse
var _arcs: ZapArcs
var _smoke: CPUParticles2D
var _pile: AshPile

# --- Meteorito (ver Meteor): lo mira venir con la boca abierta y la explosión lo hace volar ---
var _scared := 0.0

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

# --- Comida: medio coco en el piso ---
const FOOD_SPEED := 1.8          # Van a la comida más rápido que cuando pasean
const EAT_REACH := 6.0
const EAT_TIME := 1.8
const FOOD_GIVE_UP := 10.0       # Si no llega en este tiempo (trabado en el borde), la deja
const FOOD_COOLDOWN := 5.0       # ...y por un rato no busca otra
var food: Coconut
var _eat_t := 0.0
var _food_t := 0.0
var _food_cooldown := 0.0
var _rig_rest := Vector2.ZERO

# --- Carnet: nombre y apellido los pone el jugador en modo seleccionar (ver VillagerCard) ---
enum Gender { MALE, FEMALE }
static var ids_issued := 0       # Números de carnet repartidos (se guarda con la partida)
var id_number := 0
var first_name := ""
var last_name := ""
var gender := Gender.MALE        # Por ahora son todos varones

# --- Voz: "¡wow!" al agarrarlo. Cada aldeano tiene su propio tono ---
const WOW := preload("res://audio/wow.wav")
const VOICE_DB := -4.0
var _voice: AudioStreamPlayer
var _voice_pitch := 1.0

# IA y animaciones
var wander_timer := 0.0
@onready var rig: VillagerRig = get_node_or_null("Rig")

func _ready() -> void:
	randomize()
	_pick_dir()
	wander_timer = randf_range(1.5, 4.0)
	input_pickable = true

	if rig:
		_rig_rest = rig.position
		_waterline = ShaderMaterial.new()
		_waterline.shader = WATERLINE_SHADER
		rig.material = _waterline

	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	_voice = AudioStreamPlayer.new()
	_voice.stream = WOW
	_voice.volume_db = VOICE_DB
	_voice_pitch = randf_range(0.9, 1.25)
	add_child(_voice)

	ids_issued += 1
	id_number = ids_issued
	_ensure_hud()
	if hud:
		hud.add_name_tag(self)

func _ensure_hud() -> void:
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud") as HUD

## "Nombre Apellido" (vacío si todavía no le pusieron nombre).
func full_name() -> String:
	return ("%s %s" % [first_name, last_name]).strip_edges()

func enter_water(surface_y: float) -> void:
	touching_water = true
	water_surface_y = surface_y
	# Caminando por la orilla el cuerpo roza el agua, pero sigue en tierra
	if falling or dragging:
		Sea.ripple_at(self, Vector2(global_position.x, surface_y), 1.0 if falling else 0.6)
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
	var was_floating := in_water
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0
	# Sacado del agua de un tirón y soltado antes de que el área lo detecte:
	# _stop_drag lo dejó "flotando" fuera del agua. Que se caiga, no que camine sobre el agua.
	var on_island := island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly)
	if was_floating and not dragging and not eaten and not on_island:
		_start_fall()

func _physics_process(dt: float) -> void:
	if eaten:
		return
	if dragging:
		velocity = Vector2.ZERO
		return
	if zap_pinned():
		# Le cayó el rayo en la isla: se queda ahí hasta hacerse cenizas
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

		if drowning:
			# Hundirse y desvanecerse
			global_position.y += SINK_SPEED * dt
			modulate.a = max(0.0, modulate.a - FADE_RATE * dt)
			rotation = lerp_angle(rotation, 0.5, 3.0 * dt)
			velocity = Vector2.ZERO
			if modulate.a <= 0.02:
				# Recién acá cuenta como sacrificio: mientras se hunde todavía se lo puede rescatar
				_grant_sacrifice_xp()
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

		# Los costados de la pantalla lo rebotan: así no se pierde volando fuera de la vista
		var view := get_viewport().get_visible_rect()
		if (global_position.x < view.position.x + BODY_HALF_W and fall_vx < 0.0) \
				or (global_position.x > view.end.x - BODY_HALF_W and fall_vx > 0.0):
			fall_vx *= -0.5
			swing_vel *= -0.6

		# Lanzado dentro del agua (sin entrar de nuevo al área): al bajar vuelve a flotar
		if touching_water and v_fall > 0.0:
			_start_floating()
			return

		# Si cae de regreso a la tierra (no mientras sube, ni apenas lanzado sobre la isla)
		if island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly):
			if v_fall > 0.0 and (_flight_left_island or global_position.y - _launch_y > THROW_LAND_DROP):
				_land_on_island()
				return
		else:
			_flight_left_island = true

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
	_food_cooldown = maxf(0.0, _food_cooldown - dt)
	if food != null and _food_ai(dt):
		return
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

# --- COMIDA ---
## Parado o caminando en la isla (no agarrado, volando, en el agua ni muerto).
func is_idle() -> bool:
	return not (dragging or falling or in_water or eaten or dead)

func wants_food() -> bool:
	return food == null and is_idle() and _food_cooldown <= 0.0

func go_eat(c: Coconut) -> void:
	food = c
	_eat_t = 0.0
	_food_t = 0.0

func stop_eating() -> void:
	food = null
	_eat_t = 0.0
	if rig:
		rig.position = _rig_rest

## Le cayó un coco en la cabeza.
func bonk(at: Vector2) -> void:
	if rig:
		rig.hit(at, Vector2.DOWN, 0.6)
	_ensure_hud()
	if hud:
		hud.popup_text("¡Bonk!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_TEXT)

## Camina hasta su medio coco y se lo come. false si ya no tiene comida.
func _food_ai(dt: float) -> bool:
	if not is_instance_valid(food) or food.eater != self:
		stop_eating()
		return false
	var to := food.eat_spot(self) - global_position
	if _eat_t > 0.0 or to.length() <= EAT_REACH:
		# Comiendo: quieto, mirando el coco y masticando
		velocity = Vector2.ZERO
		if rig:
			rig.set_facing_left(food.point().x < global_position.x)
			rig.position = _rig_rest + Vector2(0, -absf(sin(_eat_t * 12.0)) * 2.5)
		_eat_t += dt
		food.nibble(_eat_t / EAT_TIME)
		if _eat_t >= EAT_TIME:
			var f := food
			stop_eating()
			f.finish_eating(self)
			_pick_dir()
			wander_timer = randf_range(1.5, 3.0)
		return true

	_food_t += dt
	if _food_t > FOOD_GIVE_UP:
		food.release_eater()
		_food_cooldown = FOOD_COOLDOWN
		return false
	dir = to.normalized()
	_update_sprite_flip()
	velocity = (dir * speed * FOOD_SPEED + shove_vel).limit_length(maxf(to.length() / dt, shove_vel.length()))
	var prev_pos := global_position
	move_and_slide()
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(global_position, island_poly):
		if shove_timer > 0.0:
			_fall_from_shove()
			return true
		global_position = prev_pos
		# El lugar para comer queda fuera de la isla: come estirándose desde el borde
		if to.length() < 24.0:
			_eat_t = 0.001
	return true

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
		hud.add_offerings(SACRIFICE_OFFERING)
		hud.popup_text(tr("+%d ofrendas") % SACRIFICE_OFFERING, get_global_transform_with_canvas().origin + Vector2(0, -60), HUD.C_OFFERING)

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
		rig.add_bullet_mark(hit_point)

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
				if zap_state == Zap.NONE:   # Carbonizado ya no sangra
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
	# En la capa del piso, así queda debajo de aldeanos y decoraciones
	var layer := get_tree().get_first_node_in_group("ground_layer")
	if layer:
		layer.add_child(pool)
	else:
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

# --- RAYO ---
## Si le puede caer un rayo (vivo o cadáver; no si ya se está friendo).
func can_zap() -> bool:
	return can_blast() and modulate.a > 0.2

## Le cayó un rayo (ver Lightning): se electrocuta y muere.
func zap() -> void:
	if not can_zap():
		return
	zap_state = Zap.SHOCK
	_zap_t = 0.0
	_zap_pinned = not (dragging or falling or in_water) and (not dead or corpse_grounded)
	_die()
	_xray_mat = ShaderMaterial.new()
	_xray_mat.shader = WATERLINE_SHADER
	_arcs = ZapArcs.new()
	add_child(_arcs)

## Electrocutado o carbonizado en la isla: se queda quieto donde le cayó.
func zap_pinned() -> bool:
	return zap_state != Zap.NONE and _zap_pinned

## 0..1: cuánto ya se hizo cenizas.
func ashes() -> float:
	return clampf(_zap_t / ASH_TIME, 0.0, 1.0) if zap_state == Zap.ASHES else 0.0

## Distancia de p a la superficie del cuerpo (la cápsula): <= 0 si cae adentro.
func body_distance(p: Vector2) -> float:
	var seg := _body_segment()
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])) - BODY_HALF_W

func body_center() -> Vector2:
	return to_global(BODY_COM)

func _update_zap(dt: float) -> void:
	if zap_state == Zap.NONE or eaten:
		return
	_zap_t += dt
	match zap_state:
		Zap.SHOCK:
			if _zap_t >= SHOCK_TIME:
				zap_state = Zap.CHARRED
				_zap_t = 0.0
				_arcs.queue_free()
				_start_smoke()
		Zap.CHARRED:
			if in_water and not dragging:
				drowning = true   # Carbonizado no flota: se hunde
			elif _zap_t >= CHAR_TIME and not (dragging or falling) \
					and (_zap_pinned or (corpse_grounded and corpse_timer > 0.4)):
				_start_ashes()
		Zap.ASHES:
			_pile.amount = ashes()
			if _zap_t >= ASH_TIME:
				_pile.finish()
				queue_free()
	if _smoke:
		_smoke.global_rotation = 0.0   # El humo sube aunque esté tirado
		_smoke.emitting = zap_state == Zap.CHARRED and not in_water
	_update_zap_fx()

## Rayos X, carbonizado y desarmarse (ver waterline.gdshader).
func _update_zap_fx() -> void:
	if _waterline == null:
		return
	var xray := zap_state == Zap.SHOCK and fmod(_zap_t * XRAY_HZ, 1.0) < 0.5
	_waterline.set_shader_parameter("xray", xray)
	rig.set_xray(xray, _xray_mat)
	var burnt := 1.0
	var embers := 0.3
	match zap_state:
		Zap.SHOCK:
			burnt = 0.6 * _zap_t / SHOCK_TIME   # Se va tostando mientras se electrocuta
			embers = 0.0
		Zap.CHARRED:
			burnt = lerpf(0.6, 1.0, minf(1.0, _zap_t / 0.15))
			embers = lerpf(1.0, 0.3, minf(1.0, _zap_t / CHAR_TIME))
	_waterline.set_shader_parameter("burnt", burnt)
	_waterline.set_shader_parameter("embers", embers)
	if zap_state == Zap.ASHES:
		var from := to_global(Vector2(0, HEAD_TOP))
		var axis := (to_global(Vector2(0, FEET)) - from).normalized()
		var reach := ashes() * (FEET - HEAD_TOP + CRUMBLE_EDGE)
		_waterline.set_shader_parameter("crumble", reach)
		_waterline.set_shader_parameter("crumble_from", from)
		_waterline.set_shader_parameter("crumble_axis", axis)
		# El polvo se desprende de donde se está deshaciendo (hasta que ya casi no queda nada)
		_pile.dust.global_position = from + axis * minf(reach, FEET - HEAD_TOP)
		_pile.dust.global_rotation = rotation
		_pile.dust.emitting = ashes() < 0.85

func _start_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.amount = 14
	_smoke.lifetime = 1.1
	_smoke.local_coords = false
	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_smoke.emission_rect_extents = Vector2(8, 20)
	_smoke.direction = Vector2.UP
	_smoke.spread = 20.0
	_smoke.gravity = Vector2(0, -30)
	_smoke.initial_velocity_min = 12.0
	_smoke.initial_velocity_max = 30.0
	_smoke.scale_amount_min = 2.5
	_smoke.scale_amount_max = 5.0
	_smoke.color_ramp = _fade_ramp(Color(0.22, 0.21, 0.21, 0.6), Color(0.5, 0.5, 0.5, 0.0))
	_smoke.position = Vector2(0, -6)
	add_child(_smoke)

func _start_ashes() -> void:
	zap_state = Zap.ASHES
	_zap_t = 0.0
	_zap_pinned = true
	_pile = AshPile.new()
	var lying := absf(sin(rotation))
	_pile.width = lerpf(14.0, 24.0, lying)
	var layer := get_tree().get_first_node_in_group("ground_layer")
	(layer if layer else get_parent()).add_child(_pile)
	# Al pie si está parado; tirado, debajo del cuerpo
	var a := to_global(Vector2(0, HEAD_TOP))
	var b := to_global(Vector2(0, FEET))
	_pile.global_position = Vector2((a.x + b.x) * 0.5, maxf(a.y, b.y) + lying * 9.0 - 1.0)

func _exit_tree() -> void:
	# Si se va a mitad de hacerse cenizas (se lo comió el tiburón), el montoncito igual se apaga
	if is_instance_valid(_pile) and _pile.is_inside_tree():
		_pile.finish()

static func _fade_ramp(from: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([from, to])
	return g

## Chispazos que le recorren el cuerpo mientras se electrocuta (coords del aldeano).
class ZapArcs extends Node2D:
	var _arcs: Array[PackedVector2Array] = []
	var _t := 0.0

	func _process(dt: float) -> void:
		_t -= dt
		if _t > 0.0:
			return
		_t = 0.05
		_arcs.clear()
		for i in randi_range(2, 3):
			var a := Vector2(randf_range(-16.0, 16.0), randf_range(HEAD_TOP + 4.0, FEET - 4.0))
			var b := a + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 22.0)
			_arcs.append(Lightning.jagged(a, b, 0.35, 3))
		queue_redraw()

	func _draw() -> void:
		for a in _arcs:
			Lightning.paint_bolt(self, a, 1.1, 1.0)

## Montoncito de cenizas donde se deshizo (en la capa del piso). Mientras se deshace le cae
## polvo encima (dust: el aldeano lo va poniendo donde se está deshaciendo) y las brasas se
## apagan solas.
class AshPile extends Node2D:
	const ASH := Color(0.25, 0.24, 0.24)
	const ASH_TOP := Color(0.42, 0.4, 0.39)
	const SOOT := Color(0.08, 0.07, 0.07, 0.5)
	const EMBER := Color(1.0, 0.45, 0.1)
	var width := 12.0
	var amount := 0.0:   # 0..1: cuánto ya cayó
		set(v):
			amount = v
			queue_redraw()
	var dust: CPUParticles2D
	var done := false
	var _glow := 1.0
	var _specks: Array[Vector3] = []   # x, y (0..1 del montoncito), radio

	func _ready() -> void:
		for i in 8:
			_specks.append(Vector3(randf_range(-0.75, 0.75), randf_range(0.2, 0.8), randf_range(0.8, 1.6)))
		dust = CPUParticles2D.new()
		dust.amount = 40
		dust.lifetime = 0.6
		dust.local_coords = false
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.emission_rect_extents = Vector2(12, 1.5)
		dust.direction = Vector2.DOWN
		dust.spread = 180.0
		dust.initial_velocity_min = 5.0
		dust.initial_velocity_max = 25.0
		dust.gravity = Vector2(0, 90)
		dust.scale_amount_min = 1.2
		dust.scale_amount_max = 2.6
		dust.color_ramp = Villager._fade_ramp(Color(0.3, 0.29, 0.29), Color(0.5, 0.48, 0.47, 0.0))
		add_child(dust)

	func _process(_dt: float) -> void:
		if _glow > 0.0:
			queue_redraw()

	func finish() -> void:
		if done:
			return
		done = true
		dust.emitting = false
		var tw := create_tween()
		tw.tween_property(self, "_glow", 0.0, 2.5)
		tw.tween_interval(CORPSE_TIME)
		tw.tween_property(self, "modulate:a", 0.0, 2.0)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var w := width * (0.4 + 0.6 * amount)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, w * 1.4, SOOT, true, -1.0, true)   # Hollín en la arena
		draw_set_transform(Vector2.ZERO)
		var h := 9.0 * amount
		if h < 0.5:
			return
		draw_colored_polygon(_mound(w, h), ASH)
		draw_set_transform(Vector2(-w * 0.12, -h * 0.2))
		draw_colored_polygon(_mound(w * 0.65, h * 0.7), ASH_TOP)
		draw_set_transform(Vector2.ZERO)
		var t := Time.get_ticks_msec() / 1000.0
		for i in _specks.size():
			var s := _specks[i]
			var p := Vector2(s.x * w, -s.y * h * pow(1.0 - s.x * s.x, 0.6))
			if i < 3 and _glow > 0.0:   # Brasas
				draw_circle(p, 1.2, Color(EMBER, _glow * (0.5 + 0.5 * sin(t * 8.0 + i * 2.0))), true, -1.0, true)
			else:
				draw_circle(p, s.z, ASH_TOP.lightened(0.15), true, -1.0, true)

	## Lomita de ancho 2w y alto h, apoyada en y = 0.
	static func _mound(w: float, h: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 17:
			var u := lerpf(-1.0, 1.0, i / 16.0)
			pts.append(Vector2(u * w, 1.5 - h * pow(maxf(0.0, 1.0 - u * u), 0.6)))
		return pts

# --- METEORITO ---
## Si lo puede alcanzar una explosión (vivo o cadáver; no si se está friendo por un rayo).
func can_blast() -> bool:
	return not eaten and zap_state == Zap.NONE and not is_queued_for_deletion()

## Ve venir un meteorito desde from: lo mira, con la boca abierta, durante time segundos.
func scare(time: float, from: Vector2) -> void:
	_scared = maxf(_scared, time)
	if rig and is_idle():
		rig.set_facing_left(from.x < global_position.x)

func is_scared() -> bool:
	return _scared > 0.0

## Lo alcanzó la explosión de un meteorito (ver Meteor) y sale volando con push. Si es letal
## muere chamuscado; si no, sale despedido vivo (y capaz que cae al agua).
func blast(push: Vector2, lethal: bool) -> void:
	if not can_blast():
		return
	var dir := push.normalized()
	if lethal:
		_spawn_blood(body_center(), dir, 18)
		_die()
		if _waterline:
			_waterline.set_shader_parameter("burnt", 0.45)   # Chamuscado (ver waterline.gdshader)
	elif not dead:
		_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
		_voice.play()
	if rig:
		rig.hit(body_center(), dir, 1.2)
	if dragging:
		return
	_launch(push, island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly))
	swing_vel = clampf(swing_vel + randf_range(-6.0, 6.0), -12.0, 12.0)   # Que dé vueltas en el aire

# --- TIBURÓN ---
## En el agua se hunde. En la isla (mouth = la boca del tiburón) se lo chupa hacia la boca.
func get_eaten(mouth := Vector2.INF) -> void:
	if eaten:
		return
	eaten = true
	set_physics_process(false)
	_grant_sacrifice_xp()
	_spawn_blood()
	var tw := create_tween().set_parallel()
	if mouth.is_finite():
		tw.tween_property(self, "global_position", mouth, 0.18).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "scale", Vector2.ONE * 0.2, 0.18).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "modulate:a", 0.0, 0.18).set_delay(0.06)
	else:
		tw.tween_property(self, "global_position:y", global_position.y + 45.0, 0.35).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_property(self, "rotation", 0.8, 0.35)
	tw.chain().tween_callback(queue_free)

# --- LUNA DE SANGRE ---
## Soltado sobre la Luna de Sangre: se lo chupa hacia la boca y se lo traga.
func _feed_to(moon: Moon) -> void:
	eaten = true
	set_physics_process(false)
	_grant_sacrifice_xp()
	var mouth := get_canvas_transform().affine_inverse() * moon.mouth_screen_pos()
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "global_position", mouth, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2.ONE * 0.15, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + TAU, 0.3)
	tw.chain().tween_callback(func():
		moon.feed()
		_spawn_blood(global_position, Vector2.UP, 36)
		queue_free())

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
	_update_zap(dt)
	_update_waterline()
	_scared = maxf(0.0, _scared - dt)

## Flotando (o hundiéndose) lo que queda debajo de la superficie no se ve.
func _update_waterline() -> void:
	if _waterline == null:
		return
	var cut := in_water and not dragging
	for m: ShaderMaterial in [_waterline, _xray_mat]:
		if m == null:
			continue
		m.set_shader_parameter("cut", cut)
		if cut:
			m.set_shader_parameter("water_y", water_surface_y + WATERLINE_DEPTH)

func _update_drag(dt: float) -> void:
	var m := get_global_mouse_position()
	if dt > 0.0:
		var mv := (m - _prev_mouse) / dt
		var ma := ((mv - _mouse_vel) / dt).limit_length(MAX_MOUSE_ACC)
		_mouse_vel = mv
		_mouse_acc = _mouse_acc.lerp(ma, 0.35)
		_throw_vel = _throw_vel.lerp(mv, 1.0 - exp(-THROW_SMOOTH * dt))
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
		if event.pressed and not dragging and not eaten and not HUD.aiming():
			# En modo seleccionar no se lo agarra: se abre su carnet
			_ensure_hud()
			if hud and hud.select_mode:
				hud.select_villager(self)
			else:
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
	_throw_vel = Vector2.ZERO
	swing_vel = 0.0
	fall_vx = 0.0
	_zap_pinned = false   # Carbonizado también se lo puede levantar: se deshace al volver a quedar tirado
	set_physics_process(false)
	z_index = 10
	if not dead:
		_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
		_voice.play()
	if dead:
		corpse_timer = 0.0
		modulate.a = 1.0
	# Si estaba medio desvanecido al ser rescatado, restaurar visibilidad parcial
	if drowning:
		modulate.a = max(modulate.a, 0.7)

func _stop_drag() -> void:
	dragging = false
	var moon := get_tree().get_first_node_in_group("moon") as Moon
	if moon and moon.can_eat_at(get_viewport().get_mouse_position()):
		_feed_to(moon)
		return
	set_physics_process(true)
	z_index = 0

	var throw := _throw_vel.limit_length(THROW_MAX_SPEED)
	var on_island := island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly)
	if throw.length() >= THROW_MIN_SPEED:
		_launch(throw, on_island)
	elif on_island:
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
	_launch_y = global_position.y
	_flight_left_island = true

## Soltado con impulso: sale volando con la velocidad del mouse, incluso desde el agua.
func _launch(vel: Vector2, from_island: bool) -> void:
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0
	falling = true
	corpse_grounded = false
	velocity = Vector2.ZERO
	fall_vx = vel.x
	v_fall = vel.y
	swing_vel = clampf(swing_vel + vel.x * 0.004, -12.0, 12.0)  # Que gire en el aire
	_launch_y = global_position.y
	_flight_left_island = not from_island
	z_index = 10  # Volando pasa por delante de palmeras y aldeanos

func _land_on_island() -> void:
	falling = false
	z_index = 0
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
