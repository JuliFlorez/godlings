extends Power
class_name Fireball
## Fuego: se desbloquea en la tienda y se saca desde el HUD o con su tecla (Esc o click derecho lo
## guardan). Cada click en la isla o en el agua tira una bola de fuego que baja zumbando y estalla
## en llamas: los aldeanos que alcanza se prenden fuego (ver VillagerBurn: corren gritando,
## contagian a los que tocan, el agua o el diluvio los apagan y, si no, mueren carbonizados), y en la
## isla queda una mancha de hollín. A los cadáveres también los quema, y al congelado lo derrite
## (ver VillagerFreeze). En el agua se apaga con una bocanada de vapor. Ver también Frost.
## La bola, las llamas y la mira se dibujan en HUD.overlay (así de noche brillan); el hollín, en el
## piso.

const COOLDOWN := 0.7
const FALL_TIME := 0.4          # Lo que tarda en bajar
const RADIUS := 34.0            # Aldeanos con los pies a menos de esto (en el piso) se prenden
const SQUASH := 0.42            # La mira es un círculo acostado sobre el piso
const BALL_RADIUS := 8.0
const TRAIL := 46.0             # Largo de la estela
const BURST_TIME := 0.55        # Lo que duran las llamas del estallido

const C_FIRE := Color(1.0, 0.5, 0.15)
const C_HOT := Color(1.0, 0.9, 0.5)
const C_AIM := Color(1.0, 0.55, 0.25)
const C_BAD := Color(0.72, 0.74, 0.8)
const C_OUTLINE := Color(0.06, 0.06, 0.1)

var _cooldown := 0.0
var _t := 0.0
var _falling := []    # En camino: {from, to, t, wet, fire (partículas)}
var _bursts := []     # Estallidos: {pos, t, puffs}
var _fx: Painter
var _sound: AudioStreamPlayer
static var _wav: AudioStreamWAV
static var _fire_ramp: Gradient

func _init() -> void:
	id = "fire"
	title = "Fuego"
	accent = UiStyle.C_FIRE
	price = 150
	sacrifices = 3
	tooltip = "Sacar o guardar el fuego"
	locked_tooltip = "Desbloquealo en la tienda (%d ofrendas y %d sacrificios)"
	need = "Desbloqueá el fuego en la tienda"
	unlocked_text = "¡Fuego desbloqueado! Sacalo con %s"
	done = "Desbloqueado"
	shop = "Una bola de fuego que prende a los que alcanza: corren gritando y contagian a los que tocan. El agua los apaga."
	hint = "Click en la isla o el agua para tirar una bola de fuego · click derecho, %s o %s para guardarlo."

func _ready() -> void:
	_fx = Painter.new()
	_fx.paint = _paint
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.overlay.add_child(_fx)
	else:
		add_child(_fx)
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -6.0
	_sound.max_polyphony = 3
	add_child(_sound)

func _use(at: Vector2) -> void:
	_throw(at)

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	var landed := []
	for b in _falling:
		b.t += dt
		b.fire.position = get_canvas_transform() * _ball_pos(b)
		if b.t >= FALL_TIME:
			landed.append(b)
	_falling = _falling.filter(func(b: Dictionary): return b.t < FALL_TIME)
	for b in landed:
		_impact(b)
	for b in _bursts:
		b.t += dt
	_bursts = _bursts.filter(func(b: Dictionary): return b.t < BURST_TIME)

# ---- La bola ----
## Dónde cae una bola tirada a p: en la isla ahí mismo y en el agua en la superficie (el mar es un
## piso, ver WaterArea). INF si p no está ni en la isla ni en el agua.
func _target(p: Vector2) -> Vector2:
	if _on_island(p):
		return p
	var water := _water_rect()
	if water.has_point(p):
		return Vector2(p.x, maxf(p.y, water.position.y + 2.0))
	return Vector2.INF

func _throw(p: Vector2) -> void:
	var to := _target(p)
	if not to.is_finite():
		Game.say("Apuntá a la isla o al agua", get_canvas_transform() * p, UiStyle.C_WARN)
		return
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	var side := 1.0 if randf() < 0.5 else -1.0
	var b := {"from": to + Vector2(side * randf_range(70.0, 110.0), -260.0), "to": to, "t": 0.0,
			"wet": not _on_island(to), "fire": _trail_fire()}
	b.fire.position = get_canvas_transform() * (b.from as Vector2)
	_falling.append(b)

## Dónde va la bola: baja cada vez más rápido.
func _ball_pos(b: Dictionary) -> Vector2:
	var u := clampf(b.t / FALL_TIME, 0.0, 1.0)
	return (b.from as Vector2).lerp(b.to, u * u)

func _impact(b: Dictionary) -> void:
	var at: Vector2 = b.to
	_stop(b.fire)
	if _wav == null:
		_wav = _make_sound()
	_sound.stream = _wav
	_sound.pitch_scale = randf_range(0.9, 1.1)
	_sound.play()
	if b.wet:
		_puff(at, Color(0.92, 0.95, 0.98, 0.7), 26, 70.0, -60.0, 50.0, 1.2)   # Vapor
		Sea.ripple_at(self, at, 0.8)
		return
	var puffs: Array[Vector3] = []   # Llamas del estallido: x, y (respecto al radio), tamaño
	for i in 8:
		puffs.append(Vector3(randf_range(-0.9, 0.9), randf_range(-0.3, 0.2), randf_range(0.3, 0.55)))
	_bursts.append({"pos": at, "t": 0.0, "puffs": puffs})
	_embers(at, 24)
	_puff(at, Color(0.3, 0.28, 0.27, 0.6), 16, 50.0, -40.0, 40.0, 1.5)   # Humo
	var scorch := Scorch.new()
	var layer := get_tree().get_first_node_in_group("ground_layer")
	(layer if layer else get_parent()).add_child(scorch)
	scorch.global_position = at
	var poly: Variant = get_parent().get("island_poly_global")
	if poly is PackedVector2Array:
		scorch.clip = Transform2D(0.0, -at) * (poly as PackedVector2Array)
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.can_blast() and not v.in_water and _hits(v, at):
			v.ignite()

## Si el estallido en p alcanza al aldeano (medido en el piso, como la mira).
func _hits(v: Villager, p: Vector2) -> bool:
	var d := v.ground_point() - p
	d.y /= SQUASH
	return d.length() < RADIUS + Villager.BODY_HALF_W or v.body_distance(p) < RADIUS * 0.5

func _water_rect() -> Rect2:
	var water := get_tree().get_first_node_in_group("water") as WaterArea
	if water:
		return water.get_global_rect()
	return Rect2()

func _on_island(p: Vector2) -> bool:
	var poly: Variant = get_parent().get("island_poly_global")
	return poly is PackedVector2Array and Geometry2D.is_point_in_polygon(p, poly)

# ---- Partículas ----
static func _fire_gradient() -> Gradient:
	if _fire_ramp == null:
		_fire_ramp = Gradient.new()
		_fire_ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
		_fire_ramp.colors = PackedColorArray([Color(1.0, 0.97, 0.75), C_HOT, C_FIRE, Color(0.6, 0.12, 0.05, 0.0)])
	return _fire_ramp

## Fuego que va dejando la bola (en HUD.overlay, así brilla también de noche).
func _trail_fire() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 30
	p.lifetime = 0.25
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = BALL_RADIUS * 0.6
	p.spread = 180.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.gravity = Vector2(0, -80)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color_ramp = _fire_gradient()
	_fx.add_child(p)
	return p

## Deja de echar partículas y se borra cuando se apagan las que quedan.
static func _stop(e: CPUParticles2D) -> void:
	e.emitting = false
	var tw := e.create_tween()
	tw.tween_interval(e.lifetime)
	tw.tween_callback(e.queue_free)

## Brasas que saltan del estallido (en HUD.overlay).
func _embers(at: Vector2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color_ramp = _fire_gradient()
	_fx.add_child(p)
	p.position = get_canvas_transform() * at
	p.emitting = true
	p.finished.connect(p.queue_free)

## Humo o vapor en el mundo (gravity < 0: sube).
func _puff(at: Vector2, color: Color, amount: int, speed: float, gravity: float, spread: float, lifetime: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.z_index = 15
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---- Dibujo (en HUD.overlay: la bola, las llamas y la mira) ----
func _paint(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(get_canvas_transform())
	for b in _falling:
		_paint_ball(ci, b)
	for b in _bursts:
		_paint_burst(ci, b)
	if armed:
		_paint_aim(ci)

func _paint_ball(ci: CanvasItem, b: Dictionary) -> void:
	var p := _ball_pos(b)
	var dir: Vector2 = ((b.to as Vector2) - b.from).normalized()
	var side := dir.orthogonal()
	var flick := 1.0 + sin(_t * 47.0) * 0.08 + sin(_t * 29.0) * 0.06
	for layer: Array in [[1.8, 1.0, Color(C_FIRE, 0.4)], [1.25, 0.7, Color(C_FIRE, 0.9)], [0.75, 0.45, Color(C_HOT, 1.0)]]:
		var w: float = BALL_RADIUS * layer[0]
		var tail: Vector2 = p - dir * TRAIL * layer[1] * flick
		ci.draw_colored_polygon(PackedVector2Array([p + side * w, tail, p - side * w]), layer[2])
		ci.draw_circle(p, w, layer[2], true, -1.0, true)
	ci.draw_circle(p, BALL_RADIUS * 0.4, Color(1, 1, 0.92), true, -1.0, true)

func _paint_burst(ci: CanvasItem, b: Dictionary) -> void:
	var u: float = b.t / BURST_TIME
	var a := 1.0 - u
	var grow := 1.0 - pow(1.0 - u, 3.0)
	var c: Vector2 = b.pos
	# Anillo de fuego que se abre sobre el piso
	var ring := Meteor.ellipse(c, Vector2(1.0, SQUASH) * RADIUS * (0.4 + 0.8 * grow), 28)
	ring.append(ring[0])
	ci.draw_polyline(ring, Color(C_HOT, 0.8 * a), 3.0, true)
	# Llamas que suben y se apagan
	var r := RADIUS * (0.5 + 0.5 * grow)
	for layer: Array in [[1.0, Color(C_FIRE, 0.85 * a)], [0.6, Color(C_HOT, a)]]:
		for puff: Vector3 in b.puffs:
			var at := c + Vector2(puff.x * r, puff.y * r * SQUASH - r * 0.5 * grow)
			ci.draw_circle(at, r * puff.z * layer[0] * (1.0 - u * 0.5), layer[1], true, -1.0, true)

func _paint_aim(ci: CanvasItem) -> void:
	var m := get_global_mouse_position()
	var to := _target(m)
	var ok := to.is_finite()
	var c := to if ok else m
	var ready := _cooldown <= 0.0
	var col := Color(C_AIM if ok else C_BAD, 0.95 if ready else 0.45)
	for pass_i in 2:
		var ink := C_OUTLINE if pass_i == 0 else col
		var w := 3.5 if pass_i == 0 else 1.6
		for i in 12:   # Hasta dónde prende: punteado, girando
			var a0 := TAU * i / 12.0 + _t * 0.9
			var dash := PackedVector2Array()
			for s in 4:
				var a := a0 + TAU / 24.0 * s / 3.0
				dash.append(c + Vector2(cos(a), sin(a) * SQUASH) * RADIUS)
			ci.draw_polyline(dash, ink, w, true)
		if ok:   # Una llamita en el medio
			var flame := PackedVector2Array([c + Vector2(0, -11), c + Vector2(4.5, -3), c + Vector2(3.5, 2),
					c + Vector2(0, 3.5), c + Vector2(-3.5, 2), c + Vector2(-4.5, -3)])
			if pass_i == 0:
				flame.append(flame[0])
				ci.draw_polyline(flame, ink, w, true)
			else:
				ci.draw_colored_polygon(flame, col)
		else:   # Una X: ahí no puede caer
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				ci.draw_line(c + d.normalized() * 3.0, c + d.normalized() * 9.0, ink, w, true)
	if not ready:
		ci.draw_arc(c, 14.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - _cooldown / COOLDOWN), 24, C_AIM, 2.0, true)

## Hollín que deja en la isla (en la capa del piso): se va borrando. Recortado por el borde de la isla.
class Scorch extends Node2D:
	const LIFE := 14.0
	const SIZE := Vector2(28.0, 12.0)   # Radios de la mancha (acostada sobre el piso)
	## La isla, en coords del hollín (vacío: sin recorte).
	var clip := PackedVector2Array()
	var _layers := []   # [polígonos recortados, color]: se arman al dibujarlo por primera vez

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_interval(LIFE)
		tw.tween_property(self, "modulate:a", 0.0, 3.0)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		if _layers.is_empty():
			for l: Array in [[1.0, Color(0.14, 0.09, 0.05, 0.35)], [0.65, Color(0.1, 0.06, 0.03, 0.45)]]:
				var poly := Meteor.ellipse(Vector2.ZERO, SIZE * l[0])
				_layers.append([[poly] if clip.is_empty() else Geometry2D.intersect_polygons(poly, clip), l[1]])
		for l: Array in _layers:
			for poly: PackedVector2Array in l[0]:
				draw_colored_polygon(poly, l[1])

# ---- Sonido ----
## ¡Fuuum!: un soplido que se prende de golpe y chisporrotea.
static func _make_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.8)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var deep := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.25)
		deep = lerpf(deep, noise, 0.04)
		var whoosh := (lp * 0.9 + deep * 2.5) * minf(1.0, t * 25.0) * exp(-t * 4.0)
		var crackle := randf_range(-1.0, 1.0) * exp(-t * 3.0) * 0.6 if randf() < 0.01 else 0.0
		buf[i] = whoosh + crackle
	return Synth.wav(buf, rate, 0.9)
