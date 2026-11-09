extends Power
class_name Frost
## Hielo: se desbloquea en la tienda y se saca desde el HUD o con su tecla (Esc o click derecho lo
## guardan). Cada click suelta un soplo helado ahí: el piso se cubre de escarcha y los aldeanos que
## alcanza quedan adentro de un bloque de hielo, quietos, hasta que se derriten solos (ver
## VillagerFreeze). Congelados se los puede agarrar y revolear: si caen de alto se hacen pedazos. Al
## que se está quemando, en cambio, lo apaga. Ver también Fireball.

const COOLDOWN := 1.0
const RADIUS := 38.0             # Aldeanos con los pies a menos de esto (en el piso)
const SQUASH := 0.42             # La mira es un círculo acostado sobre el piso
const PATCH_TIME := 1.6          # Lo que dura la escarcha en el piso

const C_AIM := Color(0.65, 0.9, 1.0)
const C_OUTLINE := Color(0.06, 0.06, 0.1)
const C_FROST := Color(0.85, 0.95, 1.0, 0.55)
const C_FROST_DEEP := Color(0.55, 0.8, 1.0, 0.4)

var _cooldown := 0.0
var _t := 0.0
var _patches: Array[Vector3] = []   # x, y, edad
var _sound: AudioStreamPlayer

func _init() -> void:
	id = "ice"
	title = "Hielo"
	accent = UiStyle.C_ICE
	price = 160
	sacrifices = 3
	tooltip = "Sacar o guardar el hielo"
	locked_tooltip = "Desbloquealo en la tienda (%d ofrendas y %d sacrificios)"
	need = "Desbloqueá el hielo en la tienda"
	unlocked_text = "¡Hielo desbloqueado! Sacalo con %s"
	done = "Desbloqueado"
	shop = "Un soplo helado que encierra en un bloque de hielo a los que alcanza. Se derriten solos, pero si se caen de alto se rompen. Al que se quema, lo apaga."
	hint = "Click sobre los aldeanos para congelarlos · click derecho, %s o %s para guardarlo."

func _ready() -> void:
	z_index = 30   # Encima de los aldeanos
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -6.0
	_sound.max_polyphony = 3
	add_child(_sound)

func _on_armed(_on: bool) -> void:
	queue_redraw()   # Al guardarlo, que se borre la mira (guardado ya no se redibuja solo)

func _use(at: Vector2) -> void:
	_blow(at)

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	for i in range(_patches.size() - 1, -1, -1):
		_patches[i].z += dt
		if _patches[i].z >= PATCH_TIME:
			_patches.remove_at(i)
	if armed or not _patches.is_empty():
		queue_redraw()

## Suelta el soplo helado en p: congela a los que alcanza.
func _blow(p: Vector2) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	_patches.append(Vector3(p.x, p.y, 0.0))
	_snow(p)
	_sound.stream = VillagerFreeze.freeze_sound()
	_sound.pitch_scale = randf_range(1.1, 1.3)
	_sound.play()
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.can_freeze() and _hits(v, p):
			v.freeze()

## Si el soplo en p alcanza al aldeano (medido en el piso, como la mira).
func _hits(v: Villager, p: Vector2) -> bool:
	var d := v.ground_point() - p
	d.y /= SQUASH
	return d.length() < RADIUS + Villager.BODY_HALF_W or v.body_distance(p) < RADIUS * 0.5

## Copos y cristalitos que se abren y caen brillando.
func _snow(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 46
	p.lifetime = 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(RADIUS * 0.5, RADIUS * SQUASH * 0.5)
	p.direction = Vector2.UP
	p.spread = 70.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 110.0
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color_ramp = Villager._fade_ramp(Color(1, 1, 1, 0.95), Color(0.6, 0.85, 1.0, 0.0))
	p.z_index = 31
	get_parent().add_child(p)
	p.global_position = at - Vector2(0, 8)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _draw() -> void:
	# La escarcha que se abre en el piso, con puntas de hielo, y se derrite
	for c in _patches:
		var k := c.z / PATCH_TIME
		var r := RADIUS * (0.4 + 0.7 * ease(minf(1.0, k * 4.0), 0.4))
		var a := 1.0 - k
		var at := Vector2(c.x, c.y)
		draw_set_transform(at, 0.0, Vector2(1.0, SQUASH))
		draw_circle(Vector2.ZERO, r, Color(C_FROST_DEEP, C_FROST_DEEP.a * a), true, -1.0, true)
		draw_circle(Vector2.ZERO, r * 0.7, Color(C_FROST, C_FROST.a * a), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		for i in 7:   # Cristales que salen del centro
			var dir := Vector2.from_angle(TAU * i / 7.0 + c.x)
			var tip := at + Vector2(dir.x, dir.y * SQUASH) * r * 1.05
			var base := at + Vector2(dir.x, dir.y * SQUASH) * r * 0.55
			var n := Vector2(-dir.y, dir.x * SQUASH) * 3.0
			draw_colored_polygon(PackedVector2Array([base + n, tip, base - n]), Color(1, 1, 1, 0.75 * a))
	if armed:
		_draw_aim()

func _draw_aim() -> void:
	var m := get_global_mouse_position()
	var ready := _cooldown <= 0.0
	var col := Color(C_AIM, 0.95 if ready else 0.4)
	for pass_i in 2:
		var ink := C_OUTLINE if pass_i == 0 else col
		var w := 3.5 if pass_i == 0 else 1.6
		for i in 12:   # Anillo punteado que gira, acostado sobre el piso
			var a0 := TAU * i / 12.0 - _t * 0.6
			var dash := PackedVector2Array()
			for s in 4:
				var a := a0 + TAU / 24.0 * s / 3.0
				dash.append(m + Vector2(cos(a), sin(a) * SQUASH) * RADIUS)
			draw_polyline(dash, ink, w, true)
		paint_flake(self, m, 7.0, ink, w)   # Un copo de nieve en el medio
	if not ready:
		var k := 1.0 - _cooldown / COOLDOWN
		draw_arc(m, 12.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, C_AIM, 2.0, true)

## Un copo de nieve de radio r en c: seis brazos con dos ramitas cada uno (también el ícono, ver HudIcon).
static func paint_flake(ci: CanvasItem, c: Vector2, r: float, color: Color, width: float) -> void:
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0 - PI * 0.5)
		ci.draw_line(c, c + d * r, color, width, true)
		var mid := c + d * r * 0.55
		for side: float in [-1.0, 1.0]:
			ci.draw_line(mid, mid + d.rotated(side * 0.8) * r * 0.35, color, width * 0.8, true)
