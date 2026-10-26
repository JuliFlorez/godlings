extends Node2D
class_name Plague
## Peste: se desbloquea en la tienda y se saca desde el HUD o con la tecla P (Esc o click
## derecho la guardan). Cada click suelta una nube verde de miasma ahí: los aldeanos que
## agarra se enferman de gripe al toque, sin incubarla y aunque estuvieran inmunes (ver
## Villager.infect). Después se contagian solos entre ellos. Ver también Cure.

signal armed_changed(on: bool)

## Mientras está afuera, los clicks sueltan la peste en vez de agarrar aldeanos.
static var armed := false
## Hay que comprarla en la tienda antes de poder sacarla.
static var unlocked := false
const PRICE := 120

const COOLDOWN := 1.0
const RADIUS := 44.0             # Aldeanos con el cuerpo a menos de esto del centro de la nube
const SQUASH := 0.42             # La mira es un círculo acostado sobre el piso
const CLOUD_TIME := 1.6

const C_AIM := Color(0.6, 0.95, 0.35)
const C_OUTLINE := Color(0.06, 0.06, 0.1)
const C_MIASMA := Color(0.45, 0.78, 0.25, 0.5)
const C_MIASMA_DARK := Color(0.32, 0.42, 0.18, 0.45)

var _cooldown := 0.0
var _t := 0.0
var _clouds: Array[Vector3] = []   # x, y, edad
var _sound: AudioStreamPlayer
static var _wav: AudioStreamWAV

func _ready() -> void:
	armed = false
	unlocked = false
	z_index = 30   # Encima de los aldeanos
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -8.0
	_sound.max_polyphony = 3
	add_child(_sound)

func set_armed(on: bool) -> void:
	if on and not unlocked:
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.popup_text("Desbloqueá la peste en la tienda", get_viewport_rect().size * Vector2(0.5, 0.42), HUD.C_WARN)
		return
	if on == armed:
		return
	armed = on
	armed_changed.emit(on)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			set_armed(not armed)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and armed:
			set_armed(false)
			get_viewport().set_input_as_handled()
		return

	if not armed or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_release(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	for i in range(_clouds.size() - 1, -1, -1):
		_clouds[i].z += dt
		if _clouds[i].z >= CLOUD_TIME:
			_clouds.remove_at(i)
	if armed or not _clouds.is_empty():
		queue_redraw()

## Suelta la nube en p: enferma a los que alcanza.
func _release(p: Vector2) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	_clouds.append(Vector3(p.x, p.y, 0.0))
	_puff(p)
	if _wav == null:
		_wav = _make_sound()
	_sound.stream = _wav
	_sound.pitch_scale = randf_range(0.9, 1.1)
	_sound.play()
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and _hits(v, p):
			v.infect()

## Si la nube en p alcanza al aldeano (medido en el piso, como la mira).
func _hits(v: Villager, p: Vector2) -> bool:
	var d := v.ground_point() - p
	d.y /= SQUASH
	return d.length() < RADIUS + Villager.BODY_HALF_W or v.body_distance(p) < RADIUS * 0.5

## Bocanada de miasma verde que sube despacio.
func _puff(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 40
	p.lifetime = 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(RADIUS, RADIUS * SQUASH)
	p.direction = Vector2.UP
	p.spread = 40.0
	p.gravity = Vector2(0, -18)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color_ramp = Villager._fade_ramp(Color(0.55, 0.85, 0.3, 0.65), Color(0.35, 0.45, 0.2, 0.0))
	p.z_index = 31
	get_parent().add_child(p)
	p.global_position = at - Vector2(0, 10)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _draw() -> void:
	# La mancha de miasma que se abre en el piso y se disipa
	for c in _clouds:
		var k := c.z / CLOUD_TIME
		var r := RADIUS * (0.5 + 0.6 * ease(minf(1.0, k * 3.0), 0.4))
		var a := 1.0 - k
		draw_set_transform(Vector2(c.x, c.y), 0.0, Vector2(1.0, SQUASH))
		draw_circle(Vector2.ZERO, r, Color(C_MIASMA_DARK, C_MIASMA_DARK.a * a), true, -1.0, true)
		draw_circle(Vector2(0, -r * 0.2), r * 0.7, Color(C_MIASMA, C_MIASMA.a * a), true, -1.0, true)
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
			var a0 := TAU * i / 12.0 - _t * 0.8
			var dash := PackedVector2Array()
			for s in 4:
				var a := a0 + TAU / 24.0 * s / 3.0
				dash.append(m + Vector2(cos(a), sin(a) * SQUASH) * RADIUS)
			draw_polyline(dash, c, w, true)
		# Calavera chiquita en el medio
		draw_circle(m + Vector2(0, -2), 5.5, c, pass_i == 1, w if pass_i == 0 else -1.0, true)
		draw_rect(Rect2(m + Vector2(-3.0, 2.0), Vector2(6.0, 4.0)), c, pass_i == 1, w if pass_i == 0 else -1.0)
	for side: float in [-1.0, 1.0]:
		draw_circle(m + Vector2(side * 2.2, -2.5), 1.4, C_OUTLINE, true, -1.0, true)
	if not ready:
		var k := 1.0 - _cooldown / COOLDOWN
		draw_arc(m, 12.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, C_AIM, 2.0, true)

## Un soplido grave que burbujea.
static func _make_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.9)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.08)   # Pasa-bajos: soplido sordo
		ph += TAU * (70.0 + 25.0 * sin(k * 40.0)) / rate
		var env := minf(1.0, k * 8.0) * pow(1.0 - k, 1.5)
		buf[i] = (lp * 2.2 + sin(ph) * 0.35 * (0.5 + 0.5 * sin(k * 55.0))) * env
	return Synth.wav(buf, rate, 0.9)
