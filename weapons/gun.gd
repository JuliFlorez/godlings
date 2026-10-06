extends Node2D
class_name Gun
## Pistola: se saca desde el HUD o con la tecla G (Esc o click derecho la guardan).
## Apunta desde la esquina inferior derecha hacia el mouse; cada click dispara.
## Los aldeanos alcanzados mueren y caen en ragdoll (ver Villager.shoot).

signal armed_changed(on: bool)

## Mientras está activa, los clicks disparan en vez de agarrar aldeanos.
static var armed := false

const FIRE_COOLDOWN := 0.16
const TRACER_TIME := 0.07
const FLASH_TIME := 0.05
const DRAW_SCALE := 1.6
const MUZZLE := Vector2(50, -10)        # Boca del cañón (coords del dibujo)
const ANCHOR_FROM_CORNER := Vector2(120, 70)

const C_OUTLINE := Color(0.06, 0.06, 0.08)
const C_DARK := Color(0.17, 0.18, 0.21)
const C_MID := Color(0.29, 0.31, 0.35)
const C_LIGHT := Color(0.52, 0.55, 0.6)
const C_GRIP := Color(0.38, 0.23, 0.13)

var _cooldown := 0.0
var _kick := 0.0                        # Retroceso, 1 justo al disparar
var _flash := 0.0
var _tracers := []                      # {from, to, t} en coords globales
var _sound: AudioStreamPlayer

func _ready() -> void:
	armed = false
	visible = false
	z_index = 50
	_sound = AudioStreamPlayer.new()
	_sound.stream = _make_shot_sound()
	_sound.volume_db = -8.0
	_sound.max_polyphony = 4
	add_child(_sound)

func set_armed(on: bool) -> void:
	if on == armed:
		return
	armed = on
	visible = on
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)
	armed_changed.emit(on)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			set_armed(not armed)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and armed:
			set_armed(false)
			get_viewport().set_input_as_handled()
		return

	if not armed or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_shoot(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_cooldown -= dt
	_flash -= dt
	_kick = move_toward(_kick, 0.0, 7.0 * dt)
	for t in _tracers:
		t.t -= dt
	_tracers = _tracers.filter(func(t): return t.t > 0.0)

	if not armed:
		return
	var screen := get_viewport_rect().size - ANCHOR_FROM_CORNER
	global_position = get_canvas_transform().affine_inverse() * screen
	queue_redraw()

# ---- Disparo ----
func _shoot(at: Vector2) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = FIRE_COOLDOWN
	_kick = 1.0
	_flash = FLASH_TIME
	_sound.pitch_scale = randf_range(0.9, 1.1)
	_sound.play()

	var muzzle := _muzzle_global()
	var dir := (at - muzzle).normalized()
	_tracers.append({"from": muzzle, "to": at, "t": TRACER_TIME})

	var hit := _target_at(at)
	if hit is Villager:
		(hit as Villager).shoot(at, dir)
	elif hit is Area2D:
		_puff(at, Color(0.85, 0.95, 1.0), 14)       # Salpicadura en el agua
	elif _on_island(at):
		_puff(at, Color(0.93, 0.8, 0.55), 10)       # Polvo de arena

## Lo que hay bajo el punto: un aldeano (el de más adelante), el agua o nada.
func _target_at(at: Vector2) -> Object:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var best: Villager = null
	var water: Area2D = null
	for r in get_world_2d().direct_space_state.intersect_point(q, 16):
		var c: Object = r.collider
		if c is Villager and not c.eaten:
			if best == null or c.get_index() > best.get_index():
				best = c
		elif c is Area2D and c.has_method("get_global_rect"):
			water = c
	return best if best else water

func _on_island(p: Vector2) -> bool:
	var poly: Variant = get_parent().get("island_poly_global")
	return poly is PackedVector2Array and Geometry2D.is_point_in_polygon(p, poly)

func _puff(at: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.45
	p.direction = Vector2.UP
	p.spread = 60.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = color
	p.z_index = 15
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---- Dibujo ----
func _aim_angle() -> float:
	return (get_global_mouse_position() - global_position).angle()

func _flip() -> float:
	# Apuntando a la izquierda se espeja en vertical para que la culata quede abajo
	return -1.0 if cos(_aim_angle()) < 0.0 else 1.0

func _gun_xform() -> Transform2D:
	var a := _aim_angle()
	var flip := _flip()
	var recoil_back := Vector2.from_angle(a) * -10.0 * _kick
	return Transform2D(a - 0.35 * _kick * flip, Vector2(DRAW_SCALE, DRAW_SCALE * flip), 0.0, recoil_back)

func _muzzle_global() -> Vector2:
	return global_position + _gun_xform() * MUZZLE

func _draw() -> void:
	# Trazadoras (en coords locales sin transformar)
	for t in _tracers:
		var k: float = t.t / TRACER_TIME
		draw_line(to_local(t.from), to_local(t.to), Color(1.0, 0.92, 0.6, k), 2.0, true)

	# Mira en el cursor
	var m := get_local_mouse_position()
	for pass_i in 2:
		var col := C_OUTLINE if pass_i == 0 else Color.WHITE
		var w := 3.5 if pass_i == 0 else 1.5
		draw_arc(m, 9.0, 0.0, TAU, 24, col, w, true)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(m + d * 5.0, m + d * 13.0, col, w, true)

	draw_set_transform_matrix(_gun_xform())
	_draw_pistol()
	if _flash > 0.0:
		_draw_flash()
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_pistol() -> void:
	# Culata
	var grip := PackedVector2Array([Vector2(-7, -4), Vector2(9, -4), Vector2(4, 25), Vector2(-13, 23)])
	draw_colored_polygon(grip, C_GRIP)
	draw_polyline(grip + PackedVector2Array([grip[0]]), C_OUTLINE, 1.5, true)
	for i in 3:
		draw_line(Vector2(-6 + i * 0.6, 4 + i * 6), Vector2(5 - i * 0.6, 4 + i * 6), C_GRIP.darkened(0.3), 1.0)
	# Guardamonte y gatillo
	draw_arc(Vector2(15, 1), 7.0, 0.0, PI, 10, C_OUTLINE, 2.0, true)
	draw_line(Vector2(14, -2), Vector2(12, 5), C_DARK, 2.0, true)
	# Armazón
	draw_rect(Rect2(-9, -6, 42, 6), C_DARK)
	draw_rect(Rect2(-9, -6, 42, 6), C_OUTLINE, false, 1.5)
	# Corredera
	draw_rect(Rect2(-11, -16, 60, 11), C_MID)
	draw_line(Vector2(-10, -15), Vector2(48, -15), C_LIGHT, 1.5)
	for i in 4:
		draw_line(Vector2(-7 + i * 3, -13), Vector2(-7 + i * 3, -8), C_DARK, 1.0)
	draw_rect(Rect2(-11, -16, 60, 11), C_OUTLINE, false, 1.5)
	# Miras y boca
	draw_rect(Rect2(43, -19, 3, 3), C_OUTLINE)
	draw_rect(Rect2(-9, -19, 4, 3), C_OUTLINE)
	draw_rect(Rect2(47, -12, 2, 4), Color.BLACK)

func _draw_flash() -> void:
	var c := MUZZLE + Vector2(10, 0)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		var r := 1.0 if i % 2 == 0 else 0.45
		var v := Vector2(cos(a) * 14.0, sin(a) * 8.0) * r
		outer.append(c + v)
		inner.append(c + v * 0.5)
	draw_colored_polygon(outer, Color(1.0, 0.6, 0.15))
	draw_colored_polygon(inner, Color(1.0, 0.97, 0.75))

# ---- Sonido ----
## Disparo sintetizado: ruido filtrado con caída rápida + un "golpe" grave.
func _make_shot_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.35)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.35)
		var crack := noise * exp(-t * 300.0)
		var body := lp * exp(-t * 16.0) * 0.9
		var thump := sin(TAU * 70.0 * t) * exp(-t * 22.0) * 0.8
		var v := clampf(crack + body + thump, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
