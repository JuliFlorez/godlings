extends Node2D
class_name Lightning
## Rayo: se desbloquea en la tienda y después se saca desde el HUD o con la tecla R
## (Esc o click derecho lo guardan). Mientras está afuera, una nube de tormenta sigue al
## mouse por arriba y cada click descarga un rayo justo ahí.
## Los aldeanos alcanzados se electrocutan (ver Villager.zap): se les ve el esqueleto,
## quedan carbonizados y se hacen cenizas. El rayo salta a los que están cerca y, si cae
## en el agua, la descarga se esparce y fríe a todos los que flotan alrededor (tiburones
## incluidos, ver Shark.zap).
## La nube, los rayos y la mira se dibujan en HUD.overlay: encima del mundo pero sin el
## tinte de la noche (si no, de noche el rayo se vería apagado).

signal armed_changed(on: bool)

## Mientras está afuera, los clicks lanzan rayos en vez de agarrar aldeanos.
static var armed := false
## Hay que comprarlo en la tienda antes de poder sacarlo.
static var unlocked := false
const PRICE := 100

const COOLDOWN := 0.8
const HIT_RADIUS := 16.0        # Aldeanos con el cuerpo a menos de esto del impacto
const CHAIN_RADIUS := 60.0      # Salta a otro aldeano a menos de esto (centro a centro)...
const CHAIN_MAX := 3            # ...hasta tantos saltos
const CHAIN_DELAY := 0.08       # Cada salto llega un poquito después
const WATER_RADIUS := 240.0     # En el agua la descarga llega hasta acá (a cada lado)
const BOLT_TIME := 0.55
const WATER_TIME := 0.75
const CLOUD_Y := 54.0           # Altura de la nube (px de pantalla)
const AIM_SQUASH := 0.42        # La mira es un círculo acostado sobre el piso

const C_CORE := Color(1.0, 1.0, 1.0)
const C_GLOW := Color(0.6, 0.78, 1.0)
const C_AIM := Color(1.0, 0.9, 0.4)
const C_OUTLINE := Color(0.06, 0.06, 0.1)
const C_CLOUD := Color(0.4, 0.42, 0.48)
const C_CLOUD_NIGHT := Color(0.15, 0.16, 0.22)
# Nube: bollos de [x, y, radio] alrededor del centro
const CLOUD_PUFFS: Array[Vector3] = [Vector3(-42, 6, 17), Vector3(-22, -4, 23), Vector3(2, -11, 27),
		Vector3(27, -3, 23), Vector3(46, 7, 16), Vector3(-6, 8, 22), Vector3(22, 9, 19)]

var _cooldown := 0.0
var _bolts := []                         # {main, branches, width, t, delay, flash} en coords del mundo
var _discharges := []                    # En el agua: {pos (en la superficie), t, seed, targets}
var _cloud := Vector2.ZERO               # Centro de la nube (mundo)
var _cloud_a := 0.0                      # Aparece y se va con un fundido
var _glow := 0.0                         # La nube se ilumina por dentro al descargar
var _t := 0.0
var _fx: Fx
var _thunder: AudioStreamPlayer
var _buzz: AudioStreamPlayer
static var _thunder_wav: AudioStreamWAV
static var _buzz_wav: AudioStreamWAV
static var _spark_ramp: Gradient

func _ready() -> void:
	armed = false
	unlocked = false
	_fx = Fx.new()
	_fx.lightning = self
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.overlay.add_child(_fx)
	else:
		add_child(_fx)
	_thunder = _player(-4.0)
	_buzz = _player(-9.0)

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
			hud.popup_text("Desbloqueá el rayo en la tienda", get_viewport_rect().size * Vector2(0.5, 0.42), HUD.C_WARN)
		return
	if on == armed:
		return
	armed = on
	if on:
		_make_sounds()
		if _cloud_a <= 0.0:
			_cloud = _cloud_target()
	armed_changed.emit(on)   # Antes del cursor: al sacarlo se guarda la pistola, que lo deja en la flecha
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			set_armed(not armed)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and armed:
			set_armed(false)
			get_viewport().set_input_as_handled()
		return

	if not armed or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_strike(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	_glow = move_toward(_glow, 0.0, 3.0 * dt)
	_cloud_a = move_toward(_cloud_a, 1.0 if armed else 0.0, 4.0 * dt)
	if armed:
		_cloud = _cloud.lerp(_cloud_target(), 1.0 - exp(-6.0 * dt))

	for b in _bolts:
		b.t += dt
	_bolts = _bolts.filter(func(b: Dictionary): return b.t < b.delay + BOLT_TIME)
	for d in _discharges:
		d.t += dt
	_discharges = _discharges.filter(func(d: Dictionary): return d.t < WATER_TIME)

	# Destello: con cada golpe del rayo se ilumina todo (también de noche)
	var flash := 0.0
	for b in _bolts:
		if b.flash:
			flash = maxf(flash, intensity(b.t - b.delay))
	if flash > 0.0:
		var sky := get_tree().get_first_node_in_group("sky")
		if sky:
			sky.flash(flash)
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.flash_screen(flash * 0.3)

## Dónde va la nube: arriba de todo, encima del mouse.
func _cloud_target() -> Vector2:
	return get_canvas_transform().affine_inverse() * Vector2(get_viewport().get_mouse_position().x, CLOUD_Y)

# ---- El rayo ----
func _strike(at: Vector2) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	_glow = 1.0
	var from := _cloud + Vector2(randf_range(-16.0, 16.0), 14.0)
	_bolts.append(_make_bolt(from, at))
	_thunder.pitch_scale = randf_range(0.85, 1.1)
	_thunder.play()
	_sparks(at, 26)

	# Los que están justo donde cae
	var direct: Array[Villager] = []
	for v in _targets():
		if v.body_distance(at) <= HIT_RADIUS:
			direct.append(v)
	var victims := direct.duplicate()
	var zapped_sharks: Array[Shark] = []
	for node in get_tree().get_nodes_in_group("shark"):
		var shark := node as Shark
		if shark.is_shot_at(at):
			shark.zap(at)
			zapped_sharks.append(shark)

	# En el agua la descarga se esparce: fríe a todos los que flotan cerca
	var water := _water_rect()
	var wet := water.has_point(at) and not _on_island(at)
	for v in direct:
		wet = wet or v.in_water
	if wet:
		var center := Vector2(at.x, water.position.y if water.has_area() else at.y)
		var targets: Array[Node2D] = []
		for v in _targets():
			if v.in_water and absf(v.global_position.x - at.x) <= WATER_RADIUS and not victims.has(v):
				victims.append(v)
				targets.append(v)
				_sparks(v.body_center(), 10)
		for node in get_tree().get_nodes_in_group("shark"):
			var shark := node as Shark
			if not zapped_sharks.has(shark) and shark.swims_near(at.x, WATER_RADIUS):
				shark.zap(shark.global_position)
				targets.append(shark)
		_discharges.append({"pos": center, "t": 0.0, "seed": randi(), "targets": targets})
		_puff(center, Color(0.85, 0.95, 1.0), 26, 260.0, 700.0)       # Salpicadura
		_puff(center, Color(0.9, 0.92, 0.95, 0.6), 14, 70.0, -60.0)   # Vapor

	for v in victims:
		v.zap()

	# Salta a los que están cerca (en el agua ya se esparce sola)
	var chain := direct.filter(func(v: Villager): return not v.in_water)
	var jumps := 0
	while jumps < CHAIN_MAX and not chain.is_empty():
		var src: Villager = chain.pop_front()
		var next := _nearest(src.body_center(), victims)
		if next == null:
			continue
		jumps += 1
		victims.append(next)
		chain.append(next)
		var delay := CHAIN_DELAY * jumps
		_bolts.append(_make_arc(src.body_center(), next.body_center(), delay))
		get_tree().create_timer(delay).timeout.connect(_zap_later.bind(next))

	if not victims.is_empty():
		_buzz.pitch_scale = randf_range(0.92, 1.08)
		_buzz.play()

	# El piso: si le pegó a alguien parado en la isla, la quemadura queda a sus pies
	var ground := at
	for v in direct:
		if not (v.in_water or v.falling):
			ground = v.global_position + Vector2(0, Villager.FEET - 2.0)
			break
	if _on_island(ground):
		var s := Scorch.new()
		var layer := get_tree().get_first_node_in_group("ground_layer")
		(layer if layer else get_parent()).add_child(s)
		s.global_position = ground
		_puff(ground, Color(0.35, 0.33, 0.33, 0.7), 12, 60.0, -80.0)  # Humo

## (Sin tipo: para cuando llega el salto, el aldeano puede ya no existir.)
func _zap_later(v) -> void:
	if is_instance_valid(v) and v.can_zap():
		v.zap()
		_sparks(v.body_center(), 10)

## Aldeanos a los que les puede caer un rayo (vivos o cadáveres, no los que ya se están friendo).
func _targets() -> Array[Villager]:
	var out: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.can_zap():
			out.append(v)
	return out

## El más cercano a p (que no esté en el agua ni en la lista), o null.
func _nearest(p: Vector2, skip: Array) -> Villager:
	var best: Villager = null
	var best_d := CHAIN_RADIUS
	for v in _targets():
		if v.in_water or skip.has(v):
			continue
		var d := v.body_center().distance_to(p)
		if d < best_d:
			best_d = d
			best = v
	return best

func _water_rect() -> Rect2:
	var water := get_tree().get_first_node_in_group("water")
	if water and water.has_method("get_global_rect"):
		return water.get_global_rect()
	return Rect2()

func _on_island(p: Vector2) -> bool:
	var poly: Variant = get_parent().get("island_poly_global")
	return poly is PackedVector2Array and Geometry2D.is_point_in_polygon(p, poly)

## El rayo principal, con sus ramas.
func _make_bolt(from: Vector2, to: Vector2) -> Dictionary:
	var main := jagged(from, to, 0.18, 6)
	var branches: Array[PackedVector2Array] = []
	var length := from.distance_to(to)
	for i in randi_range(2, 4):
		var start := main[randi_range(int(main.size() * 0.15), int(main.size() * 0.7))]
		var side := 1.0 if randf() < 0.5 else -1.0
		var dir := (to - from).normalized().rotated(randf_range(0.35, 0.8) * side)
		branches.append(jagged(start, start + dir * length * randf_range(0.12, 0.3), 0.3, 4))
	return {"main": main, "branches": branches, "width": 3.2, "t": 0.0, "delay": 0.0, "flash": true}

## Un salto del rayo de un aldeano a otro.
func _make_arc(from: Vector2, to: Vector2, delay: float) -> Dictionary:
	return {"main": jagged(from, to, 0.3, 4), "branches": [], "width": 1.8, "t": 0.0, "delay": delay, "flash": false}

## Línea quebrada de a hacia b: subdivide y corre cada punto medio de costado.
## roughness: cuánto se aparta respecto al largo.
static func jagged(a: Vector2, b: Vector2, roughness: float, depth: int, rng: RandomNumberGenerator = null) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var disp := a.distance_to(b) * roughness
	for i in depth:
		var out := PackedVector2Array()
		for j in pts.size() - 1:
			var p := pts[j]
			var q := pts[j + 1]
			var r := rng.randf_range(-1.0, 1.0) if rng else randf_range(-1.0, 1.0)
			out.append(p)
			out.append((p + q) * 0.5 + (q - p).orthogonal().normalized() * disp * r)
		out.append(pts[pts.size() - 1])
		pts = out
		disp *= 0.5
	return pts

## Brillo del rayo según su edad: destella, se apaga un instante y vuelve a pegar un par de
## veces por el mismo camino, como uno de verdad.
static func intensity(age: float) -> float:
	if age < 0.0:
		return 0.0
	if age < 0.07:
		return 1.0
	if age < 0.11:
		return 0.3
	if age < 0.19:
		return 0.95
	if age < 0.24:
		return 0.25
	if age < 0.29:
		return 0.75
	return maxf(0.0, 0.75 * (1.0 - (age - 0.29) / (BOLT_TIME - 0.29)))

## Dibuja una línea de rayo: resplandor azulado y el centro blanco. k: brillo (0..1).
static func paint_bolt(ci: CanvasItem, pts: PackedVector2Array, width: float, k: float) -> void:
	ci.draw_polyline(pts, Color(C_GLOW, 0.18 * k), width * 5.0, true)
	ci.draw_polyline(pts, Color(C_GLOW, 0.55 * k), width * 2.2, true)
	ci.draw_polyline(pts, Color(C_CORE, k), width, true)

# ---- Efectos ----
## Chispas que saltan (en HUD.overlay, así brillan también de noche).
func _sparks(at: Vector2, amount: int) -> void:
	if _spark_ramp == null:
		_spark_ramp = Gradient.new()
		_spark_ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		_spark_ramp.colors = PackedColorArray([Color(1, 1, 1), Color(1.0, 0.95, 0.55), Color(1.0, 0.6, 0.2), Color(1.0, 0.4, 0.1, 0.0)])
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.55
	p.direction = Vector2.UP
	p.spread = 85.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 330.0
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color_ramp = _spark_ramp
	_fx.add_child(p)
	p.position = get_canvas_transform() * at
	p.emitting = true
	p.finished.connect(p.queue_free)

## Polvo, humo o agua en el mundo. gravity < 0: sube.
func _puff(at: Vector2, color: Color, amount: int, speed: float, gravity: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 60.0
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

# ---- Dibujo (lo llama Fx, desde HUD.overlay) ----
func _paint(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(get_canvas_transform())
	if _cloud_a > 0.0:
		_paint_cloud(ci)
	for d in _discharges:
		_paint_discharge(ci, d)
	for b in _bolts:
		var age: float = b.t - b.delay
		var k := intensity(age)
		if k <= 0.0:
			continue
		var main: PackedVector2Array = b.main
		paint_bolt(ci, main, b.width, k)
		var kb := k * clampf(1.0 - age / BOLT_TIME * 1.6, 0.0, 1.0)   # Las ramas se apagan antes
		for br: PackedVector2Array in b.branches:
			paint_bolt(ci, br, b.width * 0.5, kb)
		if b.flash:
			var end := main[main.size() - 1]
			ci.draw_circle(end, 28.0 * k, Color(C_GLOW, 0.25 * k), true, -1.0, true)
			ci.draw_circle(end, 10.0 * k, Color(C_CORE, 0.85 * k), true, -1.0, true)
	if armed:
		_paint_aim(ci)

func _paint_cloud(ci: CanvasItem) -> void:
	var sky := get_tree().get_first_node_in_group("sky")
	var night: float = sky.night if sky else 0.0
	var base := C_CLOUD.lerp(C_CLOUD_NIGHT, night)
	var a := _cloud_a
	for p in CLOUD_PUFFS:   # Panza más oscura
		ci.draw_circle(_cloud + Vector2(p.x, p.y + 6.0), p.z, Color(base.darkened(0.35), a), true, -1.0, true)
	for p in CLOUD_PUFFS:
		var wobble := Vector2(sin(_t * 1.3 + p.x), cos(_t * 1.1 + p.y)) * 1.5
		ci.draw_circle(_cloud + Vector2(p.x, p.y) + wobble, p.z, Color(base, a), true, -1.0, true)
	for p in CLOUD_PUFFS:   # Brillo arriba
		if p.y < 2.0:
			ci.draw_circle(_cloud + Vector2(p.x - 3.0, p.y - 5.0), p.z * 0.55, Color(base.lightened(0.18), a * 0.8), true, -1.0, true)
	# Se ilumina por dentro al descargar, y mientras se recarga chisporrotea
	if _glow > 0.0:
		ci.draw_circle(_cloud + Vector2(0, 2), 36.0, Color(0.85, 0.9, 1.0, 0.55 * _glow * a), true, -1.0, true)
	if _cooldown > 0.0 and randf() < 0.25:
		var s := _cloud + Vector2(randf_range(-36.0, 36.0), randf_range(4.0, 14.0))
		paint_bolt(ci, jagged(s, s + Vector2(randf_range(-14.0, 14.0), randf_range(6.0, 14.0)), 0.4, 2), 1.0, 0.6 * a)

func _paint_aim(ci: CanvasItem) -> void:
	var m := get_global_mouse_position()
	var ready := _cooldown <= 0.0
	var col := Color(C_AIM, 0.95 if ready else 0.4)
	var r := HIT_RADIUS + Villager.BODY_HALF_W
	for pass_i in 2:
		var c := C_OUTLINE if pass_i == 0 else col
		var w := 3.5 if pass_i == 0 else 1.6
		for i in 12:   # Anillo punteado que gira, acostado sobre el piso
			var a0 := TAU * i / 12.0 + _t * 1.2
			var dash := PackedVector2Array()
			for s in 4:
				var a := a0 + TAU / 24.0 * s / 3.0
				dash.append(m + Vector2(cos(a), sin(a) * AIM_SQUASH) * r)
			ci.draw_polyline(dash, c, w, true)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			ci.draw_line(m + d * 3.0, m + d * 8.0, c, w, true)
	if not ready:
		# Recargando: un arquito que se completa
		var k := 1.0 - _cooldown / COOLDOWN
		ci.draw_arc(m, 12.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, C_AIM, 2.0, true)

func _paint_discharge(ci: CanvasItem, d: Dictionary) -> void:
	var age: float = d.t
	var k := 1.0 - age / WATER_TIME
	var reach := WATER_RADIUS * minf(1.0, age / 0.15)
	var c: Vector2 = d.pos
	# Resplandor sobre el agua
	var glow := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		glow.append(c + Vector2(cos(a) * reach * 0.8, sin(a) * 9.0 + 4.0))
	ci.draw_colored_polygon(glow, Color(C_GLOW, 0.22 * k))
	# Chispazos que corren por la superficie (cambian cada tanto: chisporrotea)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([d.seed, int(age / 0.04)])
	for i in 7:
		var x := c.x + rng.randf_range(-reach, reach)
		var y := c.y + rng.randf_range(0.0, 7.0)
		var span := rng.randf_range(22.0, 60.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		paint_bolt(ci, jagged(Vector2(x, y), Vector2(x + span, y + rng.randf_range(-3.0, 5.0)), 0.25, 3, rng), 1.4, k)
	for target in d.targets:   # (Sin tipo: puede que ya no exista)
		if is_instance_valid(target):
			var p: Vector2 = target.body_center() if target is Villager else target.global_position
			paint_bolt(ci, jagged(c, p, 0.2, 4, rng), 1.6, k)

## Dibuja la nube, los rayos y la mira desde HUD.overlay.
class Fx extends Node2D:
	var lightning: Lightning

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if is_instance_valid(lightning):
			lightning._paint(self)

## Quemadura en la arena donde cayó el rayo (en la capa del piso).
class Scorch extends Node2D:
	const LIFE := 16.0
	const RADIUS := 22.0
	const SQUASH := 0.38
	var _cracks: Array[PackedVector2Array] = []
	var _hot := 1.0      # Brasa del medio, que se apaga enseguida

	func _ready() -> void:
		var n := randi_range(5, 7)
		for i in n:
			var a := TAU * i / n + randf_range(-0.3, 0.3)
			var tip := Vector2(cos(a), sin(a) * SQUASH) * RADIUS * randf_range(1.0, 1.5)
			_cracks.append(Lightning.jagged(Vector2.ZERO, tip, 0.25, 2))
		var tw := create_tween()
		tw.tween_property(self, "_hot", 0.0, 1.5)
		tw.tween_interval(LIFE)
		tw.tween_property(self, "modulate:a", 0.0, 3.0)
		tw.tween_callback(queue_free)

	func _process(_dt: float) -> void:
		if _hot > 0.0:
			queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
		draw_circle(Vector2.ZERO, RADIUS, Color(0.1, 0.07, 0.05, 0.5), true, -1.0, true)
		draw_circle(Vector2.ZERO, RADIUS * 0.6, Color(0.05, 0.03, 0.02, 0.7), true, -1.0, true)
		if _hot > 0.0:
			draw_circle(Vector2.ZERO, RADIUS * 0.35, Color(1.0, 0.5, 0.15, 0.8 * _hot), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		for c in _cracks:
			draw_polyline(c, Color(0.06, 0.04, 0.03, 0.7), 1.5, true)

# ---- Sonido ----
func _make_sounds() -> void:
	if _thunder_wav == null:
		_thunder_wav = _make_thunder()
		_buzz_wav = _make_buzz()
	_thunder.stream = _thunder_wav
	_buzz.stream = _buzz_wav

## Trueno sintetizado: un chasquido seco, un golpe grave y un retumbe que va y viene.
static func _make_thunder() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 2.6)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var brown := 0.0
	var rumble_lp := 0.0
	var ph1 := randf() * TAU
	var ph2 := randf() * TAU
	var peak := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.5)
		brown = clampf(brown * 0.995 + noise * 0.06, -1.0, 1.0)   # Ruido marrón: grave
		rumble_lp = lerpf(rumble_lp, brown, 0.08)
		var crack := lp * exp(-t * 28.0) * 1.6
		var roll := 0.6 + 0.4 * sin(TAU * 1.7 * t + ph1) * sin(TAU * 0.9 * t + ph2)
		var rumble := rumble_lp * minf(1.0, t * 12.0) * exp(-t * 1.25) * roll * 3.0
		var thump := sin(TAU * 48.0 * t) * exp(-t * 9.0) * 0.5
		buf[i] = crack + rumble + thump
		peak = maxf(peak, absf(buf[i]))
	return _to_wav(buf, rate, 0.95 / maxf(peak, 0.001))

## Zumbido de electrocutado: un "bzzz" con chisporroteo que se corta a rachas.
static func _make_buzz() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.1
	var n := int(rate * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / rate
		var saw := fmod(t * 120.0, 1.0) * 2.0 - 1.0
		var square := 1.0 if fmod(t * 240.0, 1.0) < 0.5 else -1.0
		var noise := randf_range(-1.0, 1.0) if randf() < 0.3 else 0.0
		hp = 0.7 * (hp + noise - prev)   # Pasa-altos: chasquidos finitos
		prev = noise
		var gate := 1.0 if sin(TAU * 17.0 * t) > -0.3 else 0.35
		var env := minf(1.0, t * 50.0) * pow(maxf(0.0, 1.0 - t / dur), 1.2)
		buf[i] = (saw * 0.35 + square * 0.12 + hp * 0.5) * gate * env
	return _to_wav(buf, rate, 0.9)

static func _to_wav(buf: PackedFloat32Array, rate: int, gain: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
