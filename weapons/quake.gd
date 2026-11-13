extends Power
class_name Quake
## Terremoto: se desbloquea en la tienda y se desata desde el HUD o con su tecla (otra vez la
## misma lo calma antes de tiempo). Tiembla la isla entera unos segundos: la pantalla se sacude,
## los aldeanos se asustan (los que dormían se despiertan) y los sacudones los van corriendo de
## acá para allá, así que los que están cerca del borde se caen al agua. Cada choza se puede venir
## abajo, la arena se agrieta y levanta polvo. Les da miedo y los pone tristes. Al terminar hay
## que esperar a que se recargue.
## No se apunta (como el diluvio): mientras tiembla se pueden seguir agarrando aldeanos.
## También puede venir solo, como evento al azar (ver Calamities y strike).

const DURATION := 5.0            # Lo que tiembla
const COOLDOWN := 40.0           # Lo que tarda en recargarse después
const SHAKE := 9.0               # Temblor de la pantalla en lo más fuerte (px)
const JOLT_EVERY := Vector2(0.3, 0.6)    # Cada cuánto viene un sacudón...
const JOLT_CHANCE := 0.6         # ...a cuántos corre...
const JOLT := Vector2(120.0, 300.0)      # ...y con qué fuerza (px/s: hasta unos 30 px)
const HUT_COLLAPSE := 0.4        # Probabilidad de que se venga abajo cada choza
const HUT_FORCE := 240.0         # Con qué fuerza salen sus pedazos
const FEAR := 18.0
const CRACKS := 5                # Grietas que quedan en la arena
const DUST_EVERY := 0.12

var _time_left := 0.0            # Lo que le queda de temblar (0: quieta)
var _cooldown := 0.0
var _jolt_t := 0.0
var _dust_t := 0.0
var _doomed := []                # Chozas que se van a venir abajo: [choza, cuándo (lo que queda)]
var _rumble: AudioStreamPlayer
static var _rumble_wav: AudioStreamWAV

func _init() -> void:
	id = "quake"
	title = "Terremoto"
	accent = UiStyle.C_QUAKE
	aims = false   # No se apunta: tiembla toda la isla
	price = 380
	sacrifices = 9
	tooltip = "Desatar o calmar el terremoto"
	locked_tooltip = "Desbloquealo en la tienda (%d ofrendas y %d sacrificios)"
	need = "Desbloqueá el terremoto en la tienda"
	unlocked_text = "¡Terremoto desbloqueado! Desatalo con %s"
	done = "Desbloqueado"
	shop = "Sacude la isla entera: los que están cerca del borde se caen al agua y las chozas se pueden venir abajo."
	hint = "¡Terremoto! Los que están cerca del borde se caen al agua · %s para calmarlo."

func _ready() -> void:
	_rumble = AudioStreamPlayer.new()
	_rumble.volume_db = -4.0
	add_child(_rumble)

## Recargándose no se puede desatar.
func _can_arm() -> bool:
	if _cooldown > 0.0:
		Game.announce(tr("El terremoto se está recargando (%d s)") % ceili(_cooldown), UiStyle.C_WARN)
		return false
	return true

## Al desatarlo empieza a temblar; al calmarlo (o cuando se termina), para y empieza a recargarse.
func _on_armed(on: bool) -> void:
	if on:
		strike()
	else:
		_stop()
		_cooldown = COOLDOWN

func recharge() -> float:
	return 1.0 - _cooldown / COOLDOWN

## Está temblando (lo haya desatado el jugador o haya venido solo).
func shaking() -> bool:
	return _time_left > 0.0

## Empieza a temblar ya, aunque no esté comprado ni recargado: los eventos al azar (ver
## Calamities) y el poder mismo.
func strike() -> void:
	if shaking():
		return
	_time_left = DURATION
	_jolt_t = 0.2
	_dust_t = 0.0
	if _rumble_wav == null:
		_rumble_wav = _make_rumble()
	_rumble.stream = _rumble_wav
	_rumble.pitch_scale = randf_range(0.92, 1.06)
	_rumble.play()
	Game.announce("¡Terremoto!", UiStyle.C_WARN)
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or not v.is_alive() or v.is_zombie():
			continue
		v.add_fear(FEAR)
		v.add_mood(VillagerMood.MOOD_QUAKE, "Hubo un terremoto")
		if not v.inside:
			v.scare(DURATION * 0.7, v.global_position + Vector2(randf_range(-1.0, 1.0), 0.0))
	# Qué chozas se van a venir abajo, y cuándo
	_doomed.clear()
	for node in get_tree().get_nodes_in_group("hut"):
		if randf() < HUT_COLLAPSE:
			_doomed.append([node, randf_range(DURATION * 0.15, DURATION * 0.75)])
	_crack_ground()

func _stop() -> void:
	if not shaking():
		return
	_time_left = 0.0
	_doomed.clear()
	_set_shake(Vector2.ZERO)
	if _rumble.playing:
		var tw := create_tween()
		tw.tween_property(_rumble, "volume_db", -40.0, 0.4)
		tw.tween_callback(func():
			_rumble.stop()
			_rumble.volume_db = -4.0)

func _process(dt: float) -> void:
	if not armed:
		_cooldown = maxf(0.0, _cooldown - dt)
	if not shaking():
		return
	_time_left -= dt
	if _time_left <= 0.0:
		_time_left = 0.01   # (Para que _stop la apague)
		if armed:
			set_armed(false)   # Empieza a recargarse (y la apaga, ver _on_armed)
		else:
			_stop()
		return
	var k := strength()
	_set_shake(Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * SHAKE * k)
	_jolt_t -= dt
	if _jolt_t <= 0.0:
		_jolt_t = randf_range(JOLT_EVERY.x, JOLT_EVERY.y)
		_jolt(k)
	_dust_t -= dt
	if _dust_t <= 0.0:
		_dust_t = DUST_EVERY
		_dust()
	for d: Array in _doomed:
		d[1] -= dt
		if d[1] <= 0.0:
			var hut := d[0] as Hut
			if is_instance_valid(hut):
				hut.smash(hut.door() + Vector2(randf_range(-10.0, 10.0), 6.0), HUT_FORCE)
	_doomed = _doomed.filter(func(d: Array): return d[1] > 0.0)

func _notification(what: int) -> void:
	# Que no quede la pantalla corrida si pausan (o se va) justo mientras tiembla
	if (what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE) and shaking():
		_set_shake(Vector2.ZERO)

## Qué tan fuerte tiembla ahora, 0..1: arranca de a poco, llega a lo más fuerte y afloja.
func strength() -> float:
	if not shaking():
		return 0.0
	var u := 1.0 - _time_left / DURATION
	return minf(1.0, u * 5.0) * minf(1.0, (1.0 - u) * 2.5)

## Un sacudón: a varios de los que están parados en la isla los corre para un costado (el que
## queda fuera de la isla se cae, ver Villager.get_shoved) y los zarandea.
func _jolt(k: float) -> void:
	var side := 1.0 if randf() < 0.5 else -1.0   # Todos para el mismo lado: es el piso el que se mueve
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or v.inside or v.dragging or v.falling or v.in_water or v.eaten or v.tornado or v.altar \
				or v.is_frozen() or randf() > JOLT_CHANCE:
			continue
		var push := Vector2(side, randf_range(-0.5, 0.5)).normalized() * randf_range(JOLT.x, JOLT.y) * k
		v.get_shoved(Vector2.ZERO, push)
		if v.rig:
			v.rig.hit(v.body_center(), push, 0.5 * k)

## La vista la arma World (con el zoom): le pasa el temblor.
func _set_shake(off: Vector2) -> void:
	var world := get_parent()
	if world and world.is_inside_tree() and "shake" in world:
		world.shake = off

## Un punto al azar de la isla (INF si no hay isla).
func _island_point() -> Vector2:
	var world := get_parent()
	if world and world.has_method("_island_point") and world.get("island_poly_global") is PackedVector2Array \
			and not (world.get("island_poly_global") as PackedVector2Array).is_empty():
		return world.call("_island_point")
	return Vector2.INF

## Polvo que salta de la arena, acá y allá.
func _dust() -> void:
	var at := _island_point()
	if not at.is_finite():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 8
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 50.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.95, 0.84, 0.56, 0.8)
	p.z_index = 15
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

## Grietas en la arena (en la capa del piso), que se van borrando.
func _crack_ground() -> void:
	var poly: Variant = get_parent().get("island_poly_global")
	if not (poly is PackedVector2Array) or (poly as PackedVector2Array).is_empty():
		return
	var layer := get_tree().get_first_node_in_group("ground_layer")
	for i in CRACKS:
		var at := _island_point()
		var crack := Crack.new()
		(layer if layer else get_parent()).add_child(crack)
		crack.global_position = at
		crack.build(Transform2D(0.0, -at) * (poly as PackedVector2Array))

## Una grieta en la arena: una línea quebrada con un par de ramas, aplastada como el piso. Se abre
## mientras tiembla y después se va borrando.
class Crack extends Node2D:
	const LIFE := 25.0
	const SQUASH := 0.42
	const C_DARK := Color(0.33, 0.22, 0.12, 0.85)
	const C_EDGE := Color(1.0, 0.92, 0.68, 0.6)
	var _lines: Array[PackedVector2Array] = []
	var _open := 0.0   # 0 cerrada .. 1 abierta del todo

	## clip: la isla, en coords de la grieta (los pedazos que quedarían afuera no se dibujan).
	func build(clip: PackedVector2Array) -> void:
		var dir := Vector2.from_angle(randf() * TAU)
		_lines.append(_branch(Vector2.ZERO, dir, randi_range(5, 8), clip))
		_lines.append(_branch(Vector2.ZERO, -dir, randi_range(4, 7), clip))
		var main := _lines[0]
		if main.size() > 3:
			_lines.append(_branch(main[2], dir.rotated(randf_range(0.6, 1.1) * (1.0 if randf() < 0.5 else -1.0)), 3, clip))
		var tw := create_tween()
		tw.tween_property(self, "_open", 1.0, 1.2)
		tw.tween_interval(LIFE)
		tw.tween_property(self, "modulate:a", 0.0, 4.0)
		tw.tween_callback(queue_free)

	func _branch(from: Vector2, dir: Vector2, steps: int, clip: PackedVector2Array) -> PackedVector2Array:
		var pts := PackedVector2Array([from])
		var p := from
		for i in steps:
			dir = dir.rotated(randf_range(-0.7, 0.7))
			var q := p + Vector2(dir.x, dir.y * SQUASH) * randf_range(7.0, 13.0)
			if not Geometry2D.is_point_in_polygon(q, clip):
				break
			pts.append(q)
			p = q
		return pts

	func _process(_dt: float) -> void:
		if _open < 1.0:
			queue_redraw()

	func _draw() -> void:
		for line in _lines:
			var n := maxi(2, ceili(line.size() * _open))
			if line.size() < 2:
				continue
			var shown := line.slice(0, mini(n, line.size()))
			var lit := PackedVector2Array()
			for p in shown:
				lit.append(p + Vector2(0, 1.5))
			draw_polyline(lit, C_EDGE, 1.5, true)
			draw_polyline(shown, C_DARK, 2.2, true)

# ---- Sonido ----
## Un retumbe grave y largo, con golpes sueltos: arranca de a poco y afloja al final.
static func _make_rumble() -> AudioStreamWAV:
	var rate := 22050
	var dur := DURATION + 0.8
	var n := int(rate * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var brown := 0.0
	var deep := 0.0
	var thump := 0.0
	var phase := 0.0
	var peak := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := randf_range(-1.0, 1.0)
		brown = clampf(brown * 0.996 + noise * 0.05, -1.0, 1.0)   # Ruido marrón: grave
		deep = lerpf(deep, brown, 0.04)
		if randf() < 6.0 / rate:
			thump = 1.0   # Un golpe cada tanto
		thump *= 0.9995
		phase += TAU * (38.0 + 10.0 * sin(t * 3.0)) / rate
		var env := minf(1.0, t * 2.5) * minf(1.0, (dur - t) * 1.2)
		buf[i] = (deep * 3.0 + sin(phase) * 0.35 * (0.5 + thump) + noise * 0.04) * env
		peak = maxf(peak, absf(buf[i]))
	return Synth.wav(buf, rate, 0.95 / maxf(peak, 0.001))
