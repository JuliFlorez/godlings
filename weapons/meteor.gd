extends Node2D
class_name Meteor
## Meteorito: se desbloquea en la tienda y después se saca desde el HUD o con la tecla M
## (Esc o click derecho lo guardan). Cada click en la isla o en el agua hace caer un
## meteorito en llamas que explota al llegar: los aldeanos de cerca mueren chamuscados y
## salen volando, los de más lejos salen despedidos vivos (ver Villager.blast), y en la isla
## queda un cráter con la piedra al rojo, humeando. En el agua levanta una columna de agua y
## olas. A los tiburones también los mata (ver Shark.blast), y las chozas de cerca se hacen
## pedazos (ver Decoration.smash).
## Mientras cae, los que están cerca lo miran venir con la boca abierta (Villager.scare).
## El fuego y la mira se dibujan en HUD.overlay (así de noche no se apagan); la sombra y las
## olas, en el mundo.

signal armed_changed(on: bool)

## Mientras está afuera, los clicks tiran meteoritos en vez de agarrar aldeanos.
static var armed := false
## Hay que comprarlo en la tienda antes de poder sacarlo.
static var unlocked := false
const PRICE := 150

const COOLDOWN := 2.0
const FALL_TIME := 0.8          # Lo que tarda en caer
const KILL_RADIUS := 55.0       # Aldeanos con el cuerpo a menos de esto mueren...
const PUSH_RADIUS := 110.0      # ...y hasta acá salen volando (vivos)
const BLAST_SPEED := Vector2(360.0, 600.0)   # Empujón (de costado y para arriba) en el centro
const HUT_BLAST := 560.0         # Con qué fuerza salen volando los pedazos de una choza
const ROCK_RADIUS := 10.0
const TRAIL := 110.0            # Largo de la estela
const BOOM_TIME := 0.7          # Lo que dura la bola de fuego
const WAVE_TIME := 1.4          # En el agua: lo que duran las olas
const SHAKE := 7.0              # Temblor de la pantalla al explotar (px)
const SHAKE_TIME := 0.5
const AIM_SQUASH := 0.42        # La mira es un círculo acostado sobre el piso
const CLIP_GROW := 14.0         # El cráter puede pasarse esto de la parte caminable de la isla

const C_FIRE := Color(1.0, 0.55, 0.15)
const C_HOT := Color(1.0, 0.9, 0.45)
const C_ROCK := Color(0.28, 0.2, 0.16)
const C_AIM := Color(1.0, 0.5, 0.25)
const C_BAD := Color(0.72, 0.74, 0.8)
const C_OUTLINE := Color(0.06, 0.06, 0.1)

var _cooldown := 0.0
var _falling := []    # En camino: {from, to, t, wet, rock (polígono), spin, fire, smoke}
var _booms := []      # Explosiones: {pos, t, wet, puffs}
var _shake := 0.0     # 1 recién explotó, 0 quieta
var _t := 0.0
var _fx: HUD.Painter
var _whistle: AudioStreamPlayer
var _boom: AudioStreamPlayer
static var _whistle_wav: AudioStreamWAV
static var _boom_wav: AudioStreamWAV
static var _fire_ramp: Gradient

func _ready() -> void:
	armed = false
	unlocked = false
	_fx = HUD.Painter.new()
	_fx.paint = _paint
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.overlay.add_child(_fx)
	else:
		add_child(_fx)
	_whistle = _player(-10.0)
	_boom = _player(-3.0)

func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	p.max_polyphony = 3
	add_child(p)
	return p

func set_armed(on: bool) -> void:
	if on and not unlocked:
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.popup_text("Desbloqueá el meteorito en la tienda", get_viewport_rect().size * Vector2(0.5, 0.42), HUD.C_WARN)
		return
	if on == armed:
		return
	armed = on
	if on:
		_make_sounds()
	armed_changed.emit(on)   # Antes del cursor: al sacarlo se guardan las otras armas, que lo dejan en la flecha
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			set_armed(not armed)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and armed:
			set_armed(false)
			get_viewport().set_input_as_handled()
		return

	if not armed or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_drop(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	var landed := []
	for m in _falling:
		m.t += dt
		_place_trail(m)
		if m.t >= FALL_TIME:
			landed.append(m)
	_falling = _falling.filter(func(m: Dictionary): return m.t < FALL_TIME)
	for m in landed:
		_impact(m)
	for b in _booms:
		b.t += dt
	_booms = _booms.filter(func(b: Dictionary): return b.t < WAVE_TIME)
	_update_shake(dt)
	queue_redraw()

func _notification(what: int) -> void:
	# Que no quede la pantalla corrida si pausan (o se va) justo mientras tiembla
	if (what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE) and _shake > 0.0:
		_shake = 0.0
		_set_shake(Vector2.ZERO)

## Tiembla el mundo (la isla, el agua y lo que hay encima; el cielo no, que está lejos).
func _update_shake(dt: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - dt / SHAKE_TIME)
	_set_shake(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE * _shake * _shake)

## La vista la arma World (con el zoom): le pasa el temblor.
func _set_shake(off: Vector2) -> void:
	var world := get_parent()
	if world and world.is_inside_tree() and "shake" in world:
		world.shake = off

# ---- El meteorito ----
## Dónde cae un meteorito tirado a p: en la isla ahí mismo y en el agua en la superficie.
## INF si p no está ni en la isla ni en el agua.
func _target(p: Vector2) -> Vector2:
	if _on_island(p):
		return p
	var water := _water_rect()
	if water.has_point(p):
		return Vector2(p.x, water.position.y + 2.0)
	return Vector2.INF

func _drop(p: Vector2) -> void:
	var to := _target(p)
	if not to.is_finite():
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.popup_text("Apuntá a la isla o al agua", get_canvas_transform() * p, HUD.C_WARN)
		return
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	var side := 1.0 if randf() < 0.5 else -1.0
	var from := Vector2(to.x + side * randf_range(280.0, 380.0), -80.0)
	var m := {"from": from, "to": to, "t": 0.0, "wet": not _on_island(to), "rock": rock_shape(ROCK_RADIUS),
			"spin": randf_range(4.0, 8.0) * side, "fire": _trail_fire(), "smoke": _trail_smoke()}
	_place_trail(m)
	_falling.append(m)
	_whistle.pitch_scale = randf_range(0.95, 1.05)
	_whistle.play()
	# Los que están cerca lo ven venir
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.body_distance(to) <= PUSH_RADIUS:
			v.scare(FALL_TIME + 0.15, from)

## Dónde va la piedra: cae cada vez más rápido.
func _rock_pos(m: Dictionary) -> Vector2:
	var u := clampf(m.t / FALL_TIME, 0.0, 1.0)
	return (m.from as Vector2).lerp(m.to, u * (0.65 + 0.35 * u))

## El fuego y el humo de la estela siguen a la piedra.
func _place_trail(m: Dictionary) -> void:
	var p := _rock_pos(m)
	m.fire.position = get_canvas_transform() * p
	m.smoke.global_position = p

func _impact(m: Dictionary) -> void:
	var at: Vector2 = m.to
	var wet: bool = m.wet
	_stop(m.fire)
	_stop(m.smoke)
	_boom.pitch_scale = randf_range(0.9, 1.05)
	_boom.play()
	var puffs: Array[Vector3] = []   # Bollos de la bola de fuego: x, y (respecto al radio), tamaño
	for i in 7:
		puffs.append(Vector3(randf_range(-0.5, 0.5), randf_range(-0.45, 0.1), randf_range(0.45, 0.75)))
	_booms.append({"pos": at, "t": 0.0, "wet": wet, "puffs": puffs})
	_shake = 1.0
	var sky := get_tree().get_first_node_in_group("sky")
	if sky:
		sky.flash(0.8)
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.flash_screen(0.4)

	# Las chozas de cerca se hacen pedazos: los de adentro salen y los alcanza la explosión
	for node in get_tree().get_nodes_in_group("hut"):
		var h := node as Decoration
		if h.footprint_point(at).distance_to(at) <= KILL_RADIUS:
			h.smash(at, HUT_BLAST, 0.7)
	# Los de cerca mueren y salen volando; los de más lejos solo salen volando
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or not v.can_blast():
			continue
		var d := maxf(v.body_distance(at), 0.0)
		if d > PUSH_RADIUS:
			continue
		var away := v.body_center() - at
		var dir := away.normalized() if away.length() > 2.0 else Vector2.UP
		var k := clampf(1.0 - d / PUSH_RADIUS, 0.25, 1.0) * randf_range(0.85, 1.15)
		v.blast(Vector2(dir.x * BLAST_SPEED.x, -BLAST_SPEED.y) * k, d <= KILL_RADIUS)
	for node in get_tree().get_nodes_in_group("shark"):
		var shark := node as Shark
		if shark.alive_near(at, KILL_RADIUS + 20.0):
			shark.blast(Vector2(signf(shark.global_position.x - at.x) * 300.0, -320.0))

	_embers(at, 30)
	if wet:
		_puff(at, Color(0.85, 0.95, 1.0), 60, 560.0, 900.0, 22.0, 1.0)          # Columna de agua
		_puff(at, Color(0.92, 0.94, 0.97, 0.6), 18, 90.0, -70.0, 70.0, 1.4)     # Vapor
		Sea.ripple_at(self, at, 2.0)
		return
	var crater := Crater.new()
	var layer := get_tree().get_first_node_in_group("ground_layer")
	(layer if layer else get_parent()).add_child(crater)
	crater.global_position = at
	var poly: Variant = get_parent().get("island_poly_global")
	if poly is PackedVector2Array:
		# Un poco más grande que la parte caminable de la isla: así llega hasta el borde de la arena
		var grown := Geometry2D.offset_polygon(poly, CLIP_GROW)
		crater.clip = Transform2D(0.0, -at) * (grown[0] if not grown.is_empty() else poly as PackedVector2Array)
	_puff(at, Color(0.95, 0.82, 0.5), 40, 380.0, 800.0, 70.0, 0.9)        # Arena
	_puff(at, C_ROCK, 16, 320.0, 900.0, 60.0, 0.9)                         # Piedritas
	_puff(at, Color(0.3, 0.28, 0.27, 0.7), 24, 70.0, -50.0, 50.0, 1.8)     # Humo

func _water_rect() -> Rect2:
	var water := get_tree().get_first_node_in_group("water")
	if water and water.has_method("get_global_rect"):
		return water.get_global_rect()
	return Rect2()

func _on_island(p: Vector2) -> bool:
	var poly: Variant = get_parent().get("island_poly_global")
	return poly is PackedVector2Array and Geometry2D.is_point_in_polygon(p, poly)

## Piedra irregular, de radio r más o menos.
static func rock_shape(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(Vector2.from_angle(TAU * i / 9.0) * r * randf_range(0.75, 1.1))
	return pts

static func ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts

# ---- Partículas ----
static func _fire_gradient() -> Gradient:
	if _fire_ramp == null:
		_fire_ramp = Gradient.new()
		_fire_ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
		_fire_ramp.colors = PackedColorArray([Color(1.0, 0.97, 0.75), C_HOT, C_FIRE, Color(0.6, 0.12, 0.05, 0.0)])
	return _fire_ramp

## Fuego que va dejando la piedra (en HUD.overlay, así brilla también de noche).
func _trail_fire() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 50
	p.lifetime = 0.35
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = ROCK_RADIUS * 0.6
	p.spread = 180.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, -60)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color_ramp = _fire_gradient()
	_fx.add_child(p)
	return p

## Humo que va dejando la piedra (en el mundo).
func _trail_smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 0.9
	p.local_coords = false
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 25.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.35, 0.33, 0.32, 0.55), Color(0.55, 0.55, 0.55, 0.0)])
	p.color_ramp = ramp
	p.z_index = 15
	get_parent().add_child(p)
	return p

## Deja de echar partículas y se borra cuando se apagan las que quedan.
static func _stop(e: CPUParticles2D) -> void:
	e.emitting = false
	var tw := e.create_tween()
	tw.tween_interval(e.lifetime)
	tw.tween_callback(e.queue_free)

## Brasas que saltan de la explosión (en HUD.overlay).
func _embers(at: Vector2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.9
	p.direction = Vector2.UP
	p.spread = 75.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 600)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color_ramp = _fire_gradient()
	_fx.add_child(p)
	p.position = get_canvas_transform() * at
	p.emitting = true
	p.finished.connect(p.queue_free)

## Arena, piedritas, agua o humo en el mundo. gravity < 0: sube.
func _puff(at: Vector2, color: Color, amount: int, speed: float, gravity: float, spread: float, lifetime: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = color
	p.z_index = 15
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---- Dibujo ----
## En el mundo: la sombra que crece mientras cae y las olas en el agua.
func _draw() -> void:
	for m in _falling:
		var u := clampf(m.t / FALL_TIME, 0.0, 1.0)
		var r := lerpf(6.0, KILL_RADIUS * 0.55, u)
		draw_colored_polygon(ellipse(m.to, Vector2(r, r * AIM_SQUASH)), Color(0, 0, 0, 0.1 + 0.25 * u))
	for b in _booms:
		if not b.wet:
			continue
		for i in 3:   # Olas que se abren (la mitad de adelante, sobre el agua)
			var k: float = b.t - i * 0.18
			if k <= 0.0:
				continue
			var r := 20.0 + k * 220.0
			var wave := PackedVector2Array()
			for s in 17:
				var a := PI * s / 16.0
				wave.append(b.pos + Vector2(cos(a) * r, sin(a) * (6.0 + k * 4.0)))
			draw_polyline(wave, Color(1, 1, 1, 0.7 * (1.0 - b.t / WAVE_TIME)), 2.0, true)

## En HUD.overlay: la piedra con su estela, las explosiones y la mira.
func _paint(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(get_canvas_transform())
	for m in _falling:
		_paint_meteor(ci, m)
	for b in _booms:
		if b.t < BOOM_TIME:
			_paint_boom(ci, b)
	if armed:
		_paint_aim(ci)

func _paint_meteor(ci: CanvasItem, m: Dictionary) -> void:
	var p := _rock_pos(m)
	var dir: Vector2 = ((m.to as Vector2) - m.from).normalized()
	var side := dir.orthogonal()
	var flick := 1.0 + sin(_t * 47.0) * 0.06 + sin(_t * 31.0) * 0.05
	# Estela: capas de fuego cada vez más angostas, cortas y claras
	for layer: Array in [[2.0, 1.0, Color(C_FIRE, 0.35)], [1.35, 0.75, Color(C_FIRE, 0.85)], [0.8, 0.5, Color(C_HOT, 0.95)]]:
		var w: float = ROCK_RADIUS * layer[0]
		var tail: Vector2 = p - dir * TRAIL * layer[1] * flick
		ci.draw_colored_polygon(PackedVector2Array([p + side * w, tail, p - side * w]), layer[2])
		ci.draw_circle(p, w, layer[2], true, -1.0, true)
	# La piedra, girando, con el borde al rojo
	var rock: PackedVector2Array = Transform2D(m.t * m.spin, p) * (m.rock as PackedVector2Array)
	ci.draw_colored_polygon(rock, C_ROCK)
	rock.append(rock[0])
	ci.draw_polyline(rock, C_FIRE, 2.0, true)

func _paint_boom(ci: CanvasItem, b: Dictionary) -> void:
	var u: float = b.t / BOOM_TIME
	var c: Vector2 = b.pos
	var a := 1.0 - u
	var grow := 1.0 - pow(1.0 - u, 3.0)
	var size := KILL_RADIUS * (0.5 if b.wet else 1.0)
	# Onda expansiva sobre el piso
	var ring := ellipse(c, Vector2(1.0, AIM_SQUASH) * PUSH_RADIUS * 1.3 * grow, 32)
	ring.append(ring[0])
	ci.draw_polyline(ring, Color(C_HOT, 0.7 * a), 3.0, true)
	# Bola de fuego que sube: humo por fuera, fuego y el centro blanco, que se apaga primero
	var r := size * (0.35 + 0.75 * grow)
	var center := c + Vector2(0, -size * 0.6 * grow)
	for layer: Array in [[1.0, Color(0.22, 0.16, 0.13, 0.6 * a)], [0.8, Color(C_FIRE, 0.9 * a)], [0.55, Color(C_HOT, a)]]:
		for puff: Vector3 in b.puffs:
			ci.draw_circle(center + Vector2(puff.x, puff.y) * r, r * puff.z * layer[0], layer[1], true, -1.0, true)
	ci.draw_circle(center, r * 0.35 * a, Color(1, 1, 1, a), true, -1.0, true)

func _paint_aim(ci: CanvasItem) -> void:
	var m := get_global_mouse_position()
	var to := _target(m)
	var ok := to.is_finite()
	var c := to if ok else m
	var ready := _cooldown <= 0.0
	var col := Color(C_AIM if ok else C_BAD, 0.95 if ready else 0.45)
	if ok:   # Hasta dónde salen volando
		var outer := ellipse(c, Vector2(1.0, AIM_SQUASH) * PUSH_RADIUS, 40)
		outer.append(outer[0])
		ci.draw_polyline(outer, Color(col, col.a * 0.35), 1.2, true)
	for pass_i in 2:
		var ink := C_OUTLINE if pass_i == 0 else col
		var w := 3.5 if pass_i == 0 else 1.6
		for i in 16:   # Hasta dónde mueren: punteado, girando
			var a0 := TAU * i / 16.0 - _t * 0.8
			var dash := PackedVector2Array()
			for s in 4:
				var a := a0 + TAU / 32.0 * s / 3.0
				dash.append(c + Vector2(cos(a), sin(a) * AIM_SQUASH) * KILL_RADIUS)
			ci.draw_polyline(dash, ink, w, true)
		# En el medio: una cruz, o una X si ahí no puede caer
		var arms := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT] if ok \
				else [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]
		for d: Vector2 in arms:
			ci.draw_line(c + d.normalized() * 3.0, c + d.normalized() * 9.0, ink, w, true)
	if not ready:
		# Recargando: un arquito que se completa
		ci.draw_arc(c, 14.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - _cooldown / COOLDOWN), 24, C_AIM, 2.0, true)

## Cráter que deja en la isla (en la capa del piso): borde de arena levantado, el pozo y la
## piedra en el medio, al rojo, que se va enfriando y humea. Recortado por el borde de la isla.
class Crater extends Node2D:
	const LIFE := 40.0
	const RADIUS := 34.0
	const SQUASH := 0.42
	const C_SOOT := Color(0.12, 0.08, 0.05, 0.5)
	const C_RIM := Color(1.0, 0.9, 0.62)
	const C_HOLE := Color(0.62, 0.43, 0.22)
	const C_DEEP := Color(0.4, 0.26, 0.13)
	## La isla, en coords del cráter (vacío: sin recorte).
	var clip := PackedVector2Array()
	var _heat := 1.0      # 1 recién caído, 0 frío
	var _layers := []     # [polígonos recortados, color]: se arman al dibujarlo por primera vez
	var _glow: Array[PackedVector2Array] = []
	var _rock: PackedVector2Array
	var _cracks: Array[PackedVector2Array] = []   # Grietas de la piedra, al rojo mientras está caliente
	var _debris: Array[Vector3] = []   # Escombros alrededor: x, y, radio
	var _smoke: CPUParticles2D

	func _ready() -> void:
		_rock = Meteor.rock_shape(9.0)
		for i in 3:
			var tip := _rock[randi() % _rock.size()] * 0.85
			_cracks.append(PackedVector2Array([Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)),
					tip * 0.5 + tip.orthogonal() * randf_range(-0.15, 0.15), tip]))
		for i in 10:
			var a := randf() * TAU
			var d := randf_range(1.2, 1.9) * RADIUS
			_debris.append(Vector3(cos(a) * d, sin(a) * d * SQUASH, randf_range(1.2, 2.6)))
		_smoke = CPUParticles2D.new()
		_smoke.amount = 10
		_smoke.lifetime = 1.6
		_smoke.local_coords = false
		_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_smoke.emission_sphere_radius = 6.0
		_smoke.direction = Vector2.UP
		_smoke.spread = 20.0
		_smoke.initial_velocity_min = 12.0
		_smoke.initial_velocity_max = 30.0
		_smoke.gravity = Vector2(0, -20)
		_smoke.scale_amount_min = 3.0
		_smoke.scale_amount_max = 6.0
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(0.3, 0.28, 0.27, 0.55), Color(0.5, 0.5, 0.5, 0.0)])
		_smoke.color_ramp = ramp
		_smoke.position = Vector2(0, -2)
		add_child(_smoke)
		var tw := create_tween()
		tw.tween_property(self, "_heat", 0.0, 8.0)
		tw.tween_interval(LIFE)
		tw.tween_property(self, "modulate:a", 0.0, 3.0)
		tw.tween_callback(queue_free)

	func _process(_dt: float) -> void:
		if _heat > 0.0:
			_smoke.emitting = _heat > 0.2
			queue_redraw()

	func _draw() -> void:
		var r := Vector2(RADIUS, RADIUS * SQUASH)
		if _layers.is_empty():
			# Hollín alrededor, el borde levantado, el pozo y lo más hondo (corrido hacia
			# adelante: se ve la pared de atrás)
			for l: Array in [[1.75, 0.0, C_SOOT], [1.18, 0.0, C_RIM], [1.0, 1.0, C_HOLE], [0.68, 3.0, C_DEEP]]:
				_layers.append([_clipped(Meteor.ellipse(Vector2(0, l[1]), r * l[0])), l[2]])
			_glow = _clipped(Meteor.ellipse(Vector2(0, 3), r * 0.5))
		for l: Array in _layers:
			for poly: PackedVector2Array in l[0]:
				draw_colored_polygon(poly, l[1])
		for poly in _glow:
			draw_colored_polygon(poly, Color(C_FIRE, 0.75 * _heat))
		for d in _debris:
			if clip.is_empty() or Geometry2D.is_point_in_polygon(Vector2(d.x, d.y), clip):
				draw_circle(Vector2(d.x, d.y), d.z, C_ROCK, true, -1.0, true)
		# La piedra: oscura y con brillo arriba; mientras está caliente, el borde y las grietas al rojo
		var at := Transform2D(0.0, Vector2(0, -1))
		var rock := at * _rock
		draw_colored_polygon(rock, C_ROCK)
		draw_colored_polygon(Transform2D(0.0, Vector2(0.55, 0.45), 0.0, Vector2(-1.5, -4.0)) * _rock, C_ROCK.lightened(0.25))
		if _heat > 0.0:
			var hot := Color(C_HOT.lerp(C_FIRE, 1.0 - _heat), _heat)
			for c in _cracks:
				draw_polyline(at * c, hot, 1.3, true)
			rock.append(rock[0])
			draw_polyline(rock, Color(C_FIRE, 0.9 * _heat), 1.5, true)

	func _clipped(poly: PackedVector2Array) -> Array[PackedVector2Array]:
		if clip.is_empty():
			var whole: Array[PackedVector2Array] = [poly]
			return whole
		return Geometry2D.intersect_polygons(poly, clip)

# ---- Sonido ----
func _make_sounds() -> void:
	if _whistle_wav == null:
		_whistle_wav = _make_whistle()
		_boom_wav = _make_boom()
	_whistle.stream = _whistle_wav
	_boom.stream = _boom_wav

## Silbido que baja mientras cae, con un rugido de fuego que va creciendo.
static func _make_whistle() -> AudioStreamWAV:
	var rate := 22050
	var dur := FALL_TIME + 0.05
	var n := int(rate * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var u := t / dur
		phase += TAU * lerpf(1500.0, 520.0, u * u) * (1.0 + 0.01 * sin(TAU * 7.0 * t)) / rate
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.15)
		var env := minf(1.0, t * 8.0) * (0.35 + 0.65 * u) * minf(1.0, (dur - t) * 40.0)
		buf[i] = (sin(phase) * 0.55 + lp * 0.6 * u) * env
	return Synth.wav(buf, rate, 0.8)

## Explosión: un golpe grave que baja, el estallido, un retumbe largo y chisporroteo.
static func _make_boom() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 2.4)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var brown := 0.0
	var deep := 0.0
	var phase := 0.0
	var peak := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.3)
		brown = clampf(brown * 0.996 + noise * 0.05, -1.0, 1.0)   # Ruido marrón: grave
		deep = lerpf(deep, brown, 0.05)
		phase += TAU * lerpf(85.0, 32.0, minf(1.0, t * 2.0)) / rate
		var thump := sin(phase) * exp(-t * 5.0) * 1.2
		var blast := lp * exp(-t * 7.0) * 1.4
		var rumble := deep * exp(-t * 1.6) * 3.0
		var crackle := randf_range(-1.0, 1.0) * exp(-t * 2.5) * 0.5 if randf() < 0.02 else 0.0
		buf[i] = thump + blast + rumble + crackle
		peak = maxf(peak, absf(buf[i]))
	return Synth.wav(buf, rate, 0.95 / maxf(peak, 0.001))
