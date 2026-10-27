extends Node2D
class_name Cure
## Curar: se desbloquea en la tienda y se saca desde el HUD o con la tecla C (Esc o click
## derecho lo guardan). Cada click baja un haz de luz dorada: los aldeanos que alcanza se
## curan de la gripe (aunque la estuvieran incubando, y quedan inmunes un rato) y, si se
## estaban quemando, se apagan y se les va el tizne (ver Villager.cure). Ver también Plague.

signal armed_changed(on: bool)

## Mientras está afuera, los clicks curan en vez de agarrar aldeanos.
static var armed := false
## Hay que comprarlo en la tienda antes de poder sacarlo.
static var unlocked := false
const PRICE := 80

const COOLDOWN := 0.5
const RADIUS := 26.0             # Aldeanos con el cuerpo a menos de esto del centro del haz
const SQUASH := 0.42
const BEAM_TIME := 0.9
const BEAM_HEIGHT := 150.0

const C_AIM := Color(1.0, 0.88, 0.45)
const C_OUTLINE := Color(0.06, 0.06, 0.1)
const C_BEAM := Color(1.0, 0.93, 0.6)

var _cooldown := 0.0
var _t := 0.0
var _beams: Array[Vector3] = []   # x, y, edad
var _sound: AudioStreamPlayer
static var _wav: AudioStreamWAV

func _ready() -> void:
	armed = false
	unlocked = false
	z_index = 30   # Encima de los aldeanos
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -10.0
	_sound.max_polyphony = 3
	add_child(_sound)

func set_armed(on: bool) -> void:
	if on and not unlocked:
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.popup_text("Desbloqueá curar en la tienda", get_viewport_rect().size * Vector2(0.5, 0.42), HUD.C_WARN)
		return
	if on == armed:
		return
	armed = on
	queue_redraw()   # Al guardarlo, que se borre la mira (guardado ya no se redibuja solo)
	armed_changed.emit(on)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			set_armed(not armed)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and armed:
			set_armed(false)
			get_viewport().set_input_as_handled()
		return

	if not armed or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_heal(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	for i in range(_beams.size() - 1, -1, -1):
		_beams[i].z += dt
		if _beams[i].z >= BEAM_TIME:
			_beams.remove_at(i)
	if armed or not _beams.is_empty():
		queue_redraw()

## Baja el haz en p: cura a los que alcanza.
func _heal(p: Vector2) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	_beams.append(Vector3(p.x, p.y, 0.0))
	_sparkles(p)
	if _wav == null:
		_wav = _make_sound()
	_sound.stream = _wav
	_sound.pitch_scale = randf_range(0.95, 1.08)
	_sound.play()
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and _hits(v, p) and v.cure():
			_sparkles(v.body_center())

func _hits(v: Villager, p: Vector2) -> bool:
	var d := v.ground_point() - p
	d.y /= SQUASH
	return d.length() < RADIUS + Villager.BODY_HALF_W or v.body_distance(p) < RADIUS * 0.5

## Chispitas doradas que suben.
func _sparkles(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 24
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 20)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 50.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color_ramp = Villager._fade_ramp(Color(1.0, 0.95, 0.65), Color(1.0, 0.8, 0.3, 0.0))
	p.z_index = 31
	get_parent().add_child(p)
	p.global_position = at - Vector2(0, 10)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _draw() -> void:
	# El haz de luz: baja de golpe y se va apagando, con un círculo de luz en el piso
	for b in _beams:
		var k := b.z / BEAM_TIME
		var a := 1.0 - k
		var w := RADIUS * (0.55 + 0.25 * sin(minf(1.0, k * 4.0) * PI * 0.5))
		var base := Vector2(b.x, b.y)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-w * 0.45, -BEAM_HEIGHT), base + Vector2(w * 0.45, -BEAM_HEIGHT),
			base + Vector2(w, 0), base + Vector2(-w, 0),
		]), Color(C_BEAM, 0.35 * a))
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-w * 0.15, -BEAM_HEIGHT), base + Vector2(w * 0.15, -BEAM_HEIGHT),
			base + Vector2(w * 0.35, 0), base + Vector2(-w * 0.35, 0),
		]), Color(1, 1, 1, 0.45 * a))
		draw_set_transform(base, 0.0, Vector2(1.0, SQUASH))
		draw_circle(Vector2.ZERO, RADIUS * (0.8 + 0.4 * k), Color(C_BEAM, 0.4 * a), true, -1.0, true)
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
		var ring := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			ring.append(m + Vector2(cos(a), sin(a) * SQUASH) * RADIUS)
		draw_polyline(ring, c, w, true)
		# Una crucecita en el medio
		draw_line(m + Vector2(0, -7), m + Vector2(0, 7), c, w + 1.0, true)
		draw_line(m + Vector2(-7, 0), m + Vector2(7, 0), c, w + 1.0, true)
	# Brillitos que giran alrededor
	for i in 3:
		var a := _t * 2.0 + TAU * i / 3.0
		draw_circle(m + Vector2(cos(a), sin(a) * SQUASH) * RADIUS, 2.2, Color(1, 1, 0.9, 0.9), true, -1.0, true)
	if not ready:
		var k := 1.0 - _cooldown / COOLDOWN
		draw_arc(m, 12.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, C_AIM, 2.0, true)

## Campanitas: tres notas que suben, con brillo.
static func _make_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.9)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes := [784.0, 988.0, 1319.0]   # Sol, si, mi
	for j in notes.size():
		var start := int(rate * 0.08 * j)
		for i in range(start, n):
			var t := float(i - start) / rate
			var env := exp(-t * 5.0) * minf(1.0, t * 200.0)
			var f: float = notes[j]
			buf[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env * 0.3
	return Synth.wav(buf, rate, 1.0)
