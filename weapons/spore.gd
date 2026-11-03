extends Power
class_name Spore
## Espora: un hongo zombi, como el cordyceps. Se desbloquea en la tienda y se saca desde el HUD
## o con la tecla Z (Esc o click derecho la guardan). Cada click suelta ahí una bocanada de
## esporas: a los que alcanza se les mete el hongo, y al que ya lo tenía se lo apura (ver
## Villager.catch_spore). Mientras más tiempo lo tienen, más se adueña de ellos: primero no se
## les nota, después les salen hongos y tosen esporas, después se hacen zombis que muerden a los
## sanos, y al final les brota un tallo de la cabeza y revientan en una nube de esporas (ver
## Cloud) que contagia a los que estén cerca. Curar los salva solo antes de que se hagan zombis.

const COOLDOWN := 1.2
const RADIUS := 34.0             # Aldeanos con el cuerpo a menos de esto del centro de la bocanada
const SQUASH := 0.42             # La mira es un círculo acostado sobre el piso
const PUFF_TIME := 1.4

const C_AIM := Color(0.98, 0.66, 0.28)
const C_OUTLINE := Color(0.06, 0.06, 0.1)
const C_SPORE := Color(0.96, 0.66, 0.3, 0.5)
const C_SPORE_DARK := Color(0.58, 0.38, 0.16, 0.45)
const C_MOTE := Color(1.0, 0.8, 0.45)
const C_CAP := Color(0.86, 0.6, 0.3)
const C_STEM := Color(0.95, 0.9, 0.76)

var _cooldown := 0.0
var _t := 0.0
var _puffs: Array[Vector3] = []   # x, y, edad
var _sound: AudioStreamPlayer
static var _wav: AudioStreamWAV

func _init() -> void:
	id = "spore"
	title = "Espora"
	key = KEY_Z
	accent = HUD.C_SPORE
	price = 300
	sacrifices = 8
	tooltip = "Sacar o guardar la espora [Z]"
	locked_tooltip = "Desbloqueala en la tienda (%d ofrendas y %d sacrificios)"
	need = "Desbloqueá la espora en la tienda"
	unlocked_text = "¡Espora desbloqueada! Sacala con Z"
	done = "Desbloqueada"
	shop = "Un hongo zombi, como el cordyceps: de a poco se adueña de ellos, los hace zombis que muerden a los sanos y al final les brota de la cabeza."
	hint = "Click sobre los aldeanos para meterles la espora (al que ya la tiene, se la apura) · click derecho, Esc o Z para guardarla."

func _ready() -> void:
	z_index = 30   # Encima de los aldeanos
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -8.0
	_sound.max_polyphony = 3
	add_child(_sound)

func _on_armed(_on: bool) -> void:
	queue_redraw()   # Al guardarla, que se borre la mira (guardada ya no se redibuja sola)

func _use(at: Vector2) -> void:
	_release(at)

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	for i in range(_puffs.size() - 1, -1, -1):
		_puffs[i].z += dt
		if _puffs[i].z >= PUFF_TIME:
			_puffs.remove_at(i)
	if armed or not _puffs.is_empty():
		queue_redraw()

## Suelta la bocanada en p: les mete la espora a los que alcanza.
func _release(p: Vector2) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	_puffs.append(Vector3(p.x, p.y, 0.0))
	_puff(p)
	if _wav == null:
		_wav = _make_sound()
	_sound.stream = _wav
	_sound.pitch_scale = randf_range(0.9, 1.1)
	_sound.play()
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and not v.dead and reaches(v, p, RADIUS):
			v.catch_spore(VillagerSpore.SPORE_DOSE)

## Si una nube de esporas en p, de ese radio (medido en el piso, como la mira), alcanza al aldeano.
static func reaches(v: Villager, p: Vector2, radius: float) -> bool:
	var d := v.ground_point() - p
	d.y /= SQUASH
	return d.length() < radius + Villager.BODY_HALF_W or v.body_distance(p) < radius * 0.5

## Deja una nube de esporas flotando en at (en el piso): la del zombi que reventó (ver
## VillagerSpore._burst).
static func release_cloud(tree: SceneTree, at: Vector2, radius: float) -> void:
	var parent: Node = tree.current_scene
	if parent == null:
		return
	var c := Cloud.new()
	c.radius = radius
	parent.add_child(c)
	c.global_position = at

## Bocanada de esporas anaranjadas que sube despacio.
func _puff(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.75
	p.amount = 36
	p.lifetime = 1.3
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(RADIUS, RADIUS * SQUASH)
	p.direction = Vector2.UP
	p.spread = 45.0
	p.gravity = Vector2(0, -14)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color_ramp = Villager._fade_ramp(Color(1.0, 0.76, 0.36, 0.9), Color(0.7, 0.48, 0.22, 0.0))
	p.z_index = 31
	get_parent().add_child(p)
	p.global_position = at - Vector2(0, 8)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _draw() -> void:
	# La mancha de esporas que se abre en el piso y se disipa
	for c in _puffs:
		var k := c.z / PUFF_TIME
		var r := RADIUS * (0.5 + 0.6 * ease(minf(1.0, k * 3.0), 0.4))
		var a := 1.0 - k
		draw_set_transform(Vector2(c.x, c.y), 0.0, Vector2(1.0, SQUASH))
		draw_circle(Vector2.ZERO, r, Color(C_SPORE_DARK, C_SPORE_DARK.a * a), true, -1.0, true)
		draw_circle(Vector2(0, -r * 0.2), r * 0.7, Color(C_SPORE, C_SPORE.a * a), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if armed:
		_draw_aim()

func _draw_aim() -> void:
	var m := get_global_mouse_position()
	var ready := _cooldown <= 0.0
	var col := Color(C_AIM, 0.95 if ready else 0.4)
	for pass_i in 2:
		var c := C_OUTLINE if pass_i == 0 else col
		var w := 3.5 if pass_i == 0 else 1.6
		for i in 12:   # Anillo punteado que gira, acostado sobre el piso
			var a0 := TAU * i / 12.0 + _t * 0.6
			var dash := PackedVector2Array()
			for s in 4:
				var a := a0 + TAU / 24.0 * s / 3.0
				dash.append(m + Vector2(cos(a), sin(a) * SQUASH) * RADIUS)
			draw_polyline(dash, c, w, true)
	# Un hongo chiquito en el medio
	paint_mushroom(self, m + Vector2(0, 5), 1.0, Color(1, 1, 1, 0.95 if ready else 0.45))
	if not ready:
		var k := 1.0 - _cooldown / COOLDOWN
		draw_arc(m, 14.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, C_AIM, 2.0, true)

## Un hongo de sombrerito con el pie en at (de unos 14 px de alto a k = 1): la mira y el ícono.
static func paint_mushroom(ci: CanvasItem, at: Vector2, k: float, tint := Color.WHITE) -> void:
	var stem := PackedVector2Array([at + Vector2(-2.6, 0) * k, at + Vector2(2.6, 0) * k,
			at + Vector2(2.0, -7.0) * k, at + Vector2(-2.0, -7.0) * k])
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		cap.append(at + Vector2(cos(a) * 7.5, -7.0 + sin(a) * 6.0) * k)
	cap.append(at + Vector2(3.5, -5.6) * k)
	cap.append(at + Vector2(-3.5, -5.6) * k)
	for poly: PackedVector2Array in [stem, cap]:
		var closed := poly.duplicate()
		closed.append(poly[0])
		ci.draw_polyline(closed, C_OUTLINE * tint, maxf(1.0, 2.2 * k), true)
	ci.draw_colored_polygon(stem, C_STEM * tint)
	ci.draw_colored_polygon(cap, C_CAP * tint)
	ci.draw_circle(at + Vector2(-3.0, -9.5) * k, 1.3 * k, C_STEM * tint, true, -1.0, true)
	ci.draw_circle(at + Vector2(2.2, -11.0) * k, 1.0 * k, C_STEM * tint, true, -1.0, true)

## Un soplido seco, como de polvo que sale de golpe.
static func _make_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.7)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.25)
		ph += TAU * lerpf(110.0, 55.0, k) / rate
		var env := minf(1.0, k * 30.0) * pow(1.0 - k, 2.2)
		buf[i] = (lp * 1.5 + sin(ph) * 0.4 * pow(1.0 - k, 3.0)) * env
	return Synth.wav(buf, rate, 0.9)

## Nube de esporas que queda flotando donde reventó un zombi: los que pasan por adentro (o se
## quedan ahí) se contagian. Se va achicando y disipando sola.
class Cloud extends Node2D:
	const TIME := 7.0
	const CHECK := 0.4
	var radius := 80.0
	var _t := 0.0
	var _check := 0.0
	var _motes: Array[Vector4] = []   # x, y (dentro del radio, -1..1), fase, tamaño

	func _ready() -> void:
		z_index = 15   # Encima de los aldeanos: los envuelve
		for i in 22:
			var a := randf() * TAU
			var r := sqrt(randf())
			_motes.append(Vector4(cos(a) * r, sin(a) * r, randf() * TAU, randf_range(0.6, 1.4)))

	func _process(dt: float) -> void:
		_t += dt
		if _t >= TIME:
			queue_free()
			return
		_check -= dt
		if _check <= 0.0:
			_check = CHECK
			for node in get_tree().get_nodes_in_group("villager"):
				var v := node as Villager
				if v and v.spore <= 0.0 and (v.is_idle() or v.asleep) and Spore.reaches(v, global_position, radius * _size()):
					v.catch_spore()
		queue_redraw()

	## Al final se achica.
	func _size() -> float:
		return 1.0 - 0.5 * smoothstep(TIME * 0.5, TIME, _t)

	func _draw() -> void:
		var a := minf(1.0, _t * 3.0) * (1.0 - smoothstep(TIME * 0.55, TIME, _t))
		var r := radius * _size()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
		draw_circle(Vector2.ZERO, r, Color(C_SPORE_DARK, C_SPORE_DARK.a * a * 0.55), true, -1.0, true)
		draw_circle(Vector2(0, -r * 0.25), r * 0.72, Color(C_SPORE, C_SPORE.a * a * 0.55), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		# Motas que flotan subiendo y bajando
		for m in _motes:
			var p := Vector2(m.x * r, m.y * r * SQUASH - 16.0 - 12.0 * sin(_t * 1.3 + m.z))
			draw_circle(p, 1.7 * m.w, Color(C_MOTE, 0.85 * a), true, -1.0, true)
