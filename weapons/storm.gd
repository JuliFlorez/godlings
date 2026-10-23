extends Node2D
class_name Storm
## Diluvio: se desbloquea en la tienda y se desata desde el HUD o con la tecla D (otra vez D
## lo calma antes de tiempo). Se nubla, llueve a cántaros, cada tanto truena y el mar sube:
## el agua va tapando la isla desde la orilla (Flood). A los que alcanza se los lleva flotando
## hacia afuera y, si nadie los rescata (o el agua no baja a tiempo), se ahogan como en el mar;
## los demás se apartan del agua (ver Villager._swept_by_flood). La lluvia apaga a los que se
## están quemando y las antorchas. Al terminar el agua baja y hay que esperar a que se recargue.
## No se apunta: mientras llueve se pueden seguir agarrando aldeanos (para rescatarlos).
## La lluvia y las nubes de tormenta se dibujan en el mundo, encima de todo (así de noche se
## oscurecen); el agua de la inundación, sobre la arena y debajo de los aldeanos.

signal active_changed(on: bool)

## Hay que comprarlo en la tienda antes de poder desatarlo.
static var unlocked := false
const PRICE := 250

## Para los demás: cuánto llueve (0..1), cuánto le falta para recargarse (1 = listo) y hasta
## dónde llega el agua (ver flooded_at).
static var rain := 0.0
static var charge := 1.0
static var _line := DRY                       # Orilla del agua, en rel (ver shore_rel)
static var _surge := 0.0                      # Lo que entra de más la ola de ahora
static var _shore_center := Vector2.ZERO      # La orilla de la isla: la misma que usa el mar
static var _shore_r := PackedFloat32Array()

const DURATION := 18.0           # Lo que llueve
const COOLDOWN := 25.0           # Lo que tarda en recargarse después
const RAIN_IN := 2.5             # Segundos hasta llover a pleno...
const RAIN_OUT := 3.0            # ...y hasta parar del todo
const RISE_TIME := 6.0           # Lo que tarda el agua en subir del todo...
const RECEDE_TIME := 5.0         # ...y en bajar
## Hasta dónde sube el agua, en rel: arranca afuera del dibujo (adelante, los que están
## parados en el borde tienen los pies más allá de la arena) y llega hasta tapar el 36% de
## afuera de la isla.
const DRY := 1.25
const FLOOD_LINE := 0.64
## Cada tanto entra una ola: el agua avanza de golpe un poco más y se lleva a los que se
## quedaron cerca de la orilla (los aldeanos se apartan del agua, pero no ven venir las olas).
const SURGE := 0.11
const SURGE_EVERY := 3.2
const CURRENT := 14.0            # La corriente se lleva para afuera a los que flotan (px/s)...
const DRIFT_STOP := 0.95         # ...pero sin sacarlos de la isla
const SQUASH := 0.42             # Igual que Sea.SQUASH
const DROPS := 280
const DROP_SPEED := Vector2(700.0, 1000.0)
const DROP_LEN := Vector2(10.0, 18.0)
const WIND := 0.16               # La lluvia cae torcida
const SPLASH_TIME := 0.3
const MAX_SPLASHES := 120
const THUNDER_EVERY := Vector2(3.5, 8.0)
const CLOUD_DROP := 150.0        # Las nubes de tormenta bajan desde arriba de la pantalla

const C_DROP := Color(0.82, 0.88, 1.0, 0.55)
const C_SPLASH := Color(0.86, 0.93, 1.0, 0.75)
const C_CLOUD := Color(0.3, 0.32, 0.38)
const C_CLOUD_BACK := Color(0.42, 0.44, 0.5)

var active := false
var _time_left := 0.0
var _cooldown := 0.0
var _level := 0.0                # 0 seca .. 1 inundada del todo
var _t := 0.0
var _drops := PackedVector4Array()   # x, y, velocidad, largo
var _stop_y := PackedFloat32Array()  # Donde termina cada gota (en el piso o en el agua)
var _splashes: Array[Vector3] = []   # x, y, edad
var _bank: Array[PackedVector2Array] = []   # La panza de la tormenta: la capa de atrás y la de adelante
var _thunder_t := 0.0
var _rumble_t := -1.0            # Trueno en camino (llega un poco después del destello)
var _flood: Flood
var _rain_sound: AudioStreamPlayer
var _thunder: AudioStreamPlayer

func _ready() -> void:
	unlocked = false
	rain = 0.0
	charge = 1.0
	_line = DRY
	_surge = 0.0
	z_index = 30   # Encima de todo lo del mundo (también de los aldeanos volando)
	var view := get_viewport_rect().size
	_drops.resize(DROPS)
	_stop_y.resize(DROPS)
	for i in DROPS:
		_new_drop(i, randf_range(-view.y, -10.0))   # Esperan arriba: van entrando de a poco
	_build_bank(view.x)
	# El agua va arriba de la arena (y de las manchas del piso) y debajo de lo que tiene altura
	_flood = Flood.new()
	_flood.island = get_parent().get("isle_sprite") as Sprite2D
	var world := get_parent()
	world.add_child(_flood)
	var props: Variant = world.get("props")
	if props is Node:
		world.move_child(_flood, (props as Node).get_index())
	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.volume_db = -60.0
	add_child(_rain_sound)
	_thunder = AudioStreamPlayer.new()
	_thunder.volume_db = -6.0
	add_child(_thunder)

## Lo desata (si está desbloqueado y recargado) o lo calma.
func set_active(on: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	var center := get_viewport_rect().size * Vector2(0.5, 0.42)
	if on and not unlocked:
		if hud:
			hud.popup_text("Desbloqueá el diluvio en la tienda", center, HUD.C_WARN)
		return
	if on == active:
		return
	if on and _cooldown > 0.0:
		if hud:
			hud.popup_text(tr("El diluvio se está recargando (%d s)") % ceili(_cooldown), center, HUD.C_WARN)
		return
	active = on
	if on:
		_time_left = DURATION
		_thunder_t = randf_range(1.0, 2.5)
		if _rain_sound.stream == null:
			_rain_sound.stream = _make_rain()
			_thunder.stream = Lightning._make_thunder()
		if hud:
			hud.popup_text("¡Se largó el diluvio!", center, HUD.C_DEVOTION)
	else:
		_cooldown = COOLDOWN
	active_changed.emit(on)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D:
		set_active(not active)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	if active:
		_time_left -= dt
		if _time_left <= 0.0:
			set_active(false)
	else:
		_cooldown = maxf(0.0, _cooldown - dt)
	charge = 1.0 - _cooldown / COOLDOWN
	rain = move_toward(rain, 1.0 if active else 0.0, dt / (RAIN_IN if active else RAIN_OUT))
	_level = move_toward(_level, 1.0 if active and rain > 0.5 else 0.0, dt / (RISE_TIME if active else RECEDE_TIME))
	_line = lerpf(DRY, FLOOD_LINE, smoothstep(0.0, 1.0, _level))
	# Olas: picos cortos, cada SURGE_EVERY segundos
	_surge = SURGE * pow(maxf(0.0, sin(_t * TAU / SURGE_EVERY)), 6.0) * smoothstep(0.0, 1.0, _level)

	var sea := get_tree().get_first_node_in_group("sea") as Sea
	if sea:
		_shore_center = sea.shore_center
		_shore_r = sea.shore_radii
	_flood.visible = _line - _surge < 1.0   # Más afuera del dibujo no hay arena que tapar
	if _flood.visible:
		_flood.sync(_line - _surge, _t, _shore_center, _shore_r)

	var sky := get_tree().get_first_node_in_group("sky")
	if sky:
		sky.storm = rain
	_update_drops(dt)
	_update_thunder(dt)

	if rain > 0.0 and not _rain_sound.playing:
		_rain_sound.play()
	elif rain <= 0.0 and _rain_sound.playing:
		_rain_sound.stop()
	_rain_sound.volume_db = linear_to_db(maxf(rain, 0.001)) - 8.0
	if rain > 0.0 or not _splashes.is_empty():
		queue_redraw()

# ---- La inundación ----
## Qué tan afuera está el punto del piso p: 0 el centro de la isla, 1 la orilla del dibujo
## (medido en el piso, como la laguna del mar: ver Sea.fit_island). INF si no hay isla.
static func shore_rel(p: Vector2) -> float:
	if _shore_r.size() != Sea.BINS:
		return INF
	var g := (p - _shore_center) * Vector2(1.0, 1.0 / SQUASH)
	var fi := (g.angle() / TAU + 0.5) * Sea.BINS
	var i0 := int(floor(fi)) % Sea.BINS
	var i1 := (i0 + 1) % Sea.BINS
	var r := lerpf(_shore_r[i0], _shore_r[i1], fi - floorf(fi))
	return g.length() / maxf(r, 1.0)

## Si el agua de la inundación tapa el punto del piso p (en la isla).
static func flooded_at(p: Vector2) -> bool:
	if _line >= DRY:
		return false
	var rel := shore_rel(p)
	return rel > _line - _surge and rel < DRY + 0.2

## Si el agua está a menos de margin (en rel) del punto del piso p, para afuera (sin contar
## la ola de ahora: no la ven venir).
static func water_near(p: Vector2, margin: float) -> bool:
	return _line < DRY and shore_rel(p) > _line - margin

## Hacia dónde lleva la corriente al que flota en la inundación (en p, punto del piso):
## para afuera, pero sin sacarlo de la isla.
static func current_at(p: Vector2) -> Vector2:
	if _line >= DRY or shore_rel(p) >= DRIFT_STOP:
		return Vector2.ZERO
	return (p - _shore_center).normalized() * CURRENT

## Llueve fuerte: apaga el fuego (ver Villager._update_fire y Decoration).
static func wet() -> bool:
	return rain > 0.4

# ---- La lluvia ----
## Gota nueva arriba de la pantalla (y: dónde arranca). Cae hasta un lugar al azar del piso o
## del mar: las que caen lejos (cerca del horizonte) son más chicas y lentas.
func _new_drop(i: int, y: float) -> void:
	var view := get_viewport_rect().size
	var horizon := _horizon()
	var stop := randf_range(horizon - 30.0, view.y + 20.0)
	var s := lerpf(0.45, 1.0, clampf((stop - horizon) / (view.y - horizon), 0.0, 1.0))
	_stop_y[i] = stop
	_drops[i] = Vector4(randf_range(-view.y * WIND - 20.0, view.x + 20.0), y,
			randf_range(DROP_SPEED.x, DROP_SPEED.y) * s, randf_range(DROP_LEN.x, DROP_LEN.y) * s)

func _horizon() -> float:
	var sky := get_tree().get_first_node_in_group("sky")
	return sky.horizon_y if sky else 408.0

func _update_drops(dt: float) -> void:
	var n := int(DROPS * rain)
	var horizon := _horizon()
	for i in DROPS:
		var d := _drops[i]
		if i >= n and d.y < -5.0:
			continue   # Las que sobran esperan arriba
		d.y += d.z * dt
		d.x += d.z * WIND * dt
		_drops[i] = d
		if d.y >= _stop_y[i]:
			if i < n and _stop_y[i] > horizon and _splashes.size() < MAX_SPLASHES:
				_splashes.append(Vector3(d.x, _stop_y[i], 0.0))
			_new_drop(i, randf_range(-60.0, -10.0))
	for i in range(_splashes.size() - 1, -1, -1):
		_splashes[i].z += dt
		if _splashes[i].z >= SPLASH_TIME:
			_splashes.remove_at(i)

func _update_thunder(dt: float) -> void:
	if _rumble_t >= 0.0:
		_rumble_t -= dt
		if _rumble_t < 0.0:
			_thunder.pitch_scale = randf_range(0.8, 1.05)
			_thunder.play()
	if not active or rain < 0.7:
		return
	_thunder_t -= dt
	if _thunder_t > 0.0:
		return
	_thunder_t = randf_range(THUNDER_EVERY.x, THUNDER_EVERY.y)
	var k := randf_range(0.45, 0.9)
	var sky := get_tree().get_first_node_in_group("sky")
	if sky:
		sky.flash(k)
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.flash_screen(k * 0.18)
	_rumble_t = randf_range(0.15, 0.9)

# ---- Dibujo ----
func _draw() -> void:
	if rain > 0.0:
		_paint_clouds()
		var segs := PackedVector2Array()
		for i in int(DROPS * rain):
			var d := _drops[i]
			if d.y > -20.0:
				segs.append(Vector2(d.x, d.y))
				segs.append(Vector2(d.x - WIND * d.w, d.y - d.w))
		if not segs.is_empty():
			draw_multiline(segs, Color(C_DROP, C_DROP.a * rain), 1.2, true)
	# Salpicaduras: anillitos acostados que se abren
	var horizon := _horizon()
	var view_h := get_viewport_rect().size.y
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for s in _splashes:
		var k := s.z / SPLASH_TIME
		var depth := lerpf(0.45, 1.0, clampf((s.y - horizon) / (view_h - horizon), 0.0, 1.0))
		var r := (2.0 + 7.0 * k) * depth
		var col := Color(C_SPLASH, C_SPLASH.a * (1.0 - k))
		for j in 8:
			var a0 := TAU * j / 8.0
			var a1 := TAU * (j + 1) / 8.0
			pts.append(Vector2(s.x + cos(a0) * r, s.y + sin(a0) * r * SQUASH))
			pts.append(Vector2(s.x + cos(a1) * r, s.y + sin(a1) * r * SQUASH))
			cols.append(col)
	if not pts.is_empty():
		draw_multiline_colors(pts, cols, 1.0, true)

## La panza de las nubes de tormenta: una fila de bollos a lo ancho de la pantalla, en dos
## capas. Se arma una sola vez como un polígono por capa (el borde de abajo son los arcos
## de los bollos): dibujar los bollos uno por uno cada cuadro es caro.
func _build_bank(width: float) -> void:
	var puffs: Array[Vector3] = []   # x, y, radio
	var x := -80.0
	while x < width + 80.0:
		puffs.append(Vector3(x + randf_range(-10.0, 10.0), randf_range(-10.0, 30.0), randf_range(40.0, 62.0)))
		x += 46.0
	for pass_i in 2:
		var pts := PackedVector2Array([Vector2(-100.0, -260.0), Vector2(width + 100.0, -260.0)])
		x = width + 100.0
		while x >= -100.0:
			var y := -260.0
			for c in puffs:
				var r := c.z * (1.0 if pass_i == 0 else 0.8)
				var dx := x - c.x
				if absf(dx) < r:
					y = maxf(y, c.y + pass_i * 14.0 + sqrt(r * r - dx * dx))
			pts.append(Vector2(x, y))
			x -= 4.0
		_bank.append(pts)

## La panza de las nubes de tormenta, que baja desde arriba de la pantalla y se mece.
func _paint_clouds() -> void:
	var drop := -CLOUD_DROP * (1.0 - ease(rain, 0.4))
	draw_set_transform(Vector2(sin(_t * 0.25) * 12.0, drop + sin(_t * 0.6) * 3.0))
	draw_colored_polygon(_bank[0], C_CLOUD_BACK)
	draw_set_transform(Vector2(sin(_t * 0.25 + 1.3) * 12.0, drop))
	draw_colored_polygon(_bank[1], C_CLOUD)
	draw_set_transform(Vector2.ZERO)

## El agua de la inundación: una copia del dibujo de la isla, encima, con flood.gdshader
## (la orilla del agua avanza desde el borde hacia el centro).
class Flood extends Sprite2D:
	const SHADER := preload("res://world/flood.gdshader")
	var island: Sprite2D
	var _mat: ShaderMaterial

	func _ready() -> void:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_mat.set_shader_parameter("squash", SQUASH)
		material = _mat
		visible = false

	## Acompaña a la isla (crece con ella) y le pasa al shader hasta dónde llega el agua.
	func sync(line: float, t: float, center: Vector2, radii: PackedFloat32Array) -> void:
		if island:
			texture = island.texture
			centered = island.centered
			offset = island.offset
			global_transform = island.global_transform
		_mat.set_shader_parameter("line", line)
		_mat.set_shader_parameter("time", t)
		_mat.set_shader_parameter("isle_center", center)
		if radii.size() == Sea.BINS:
			_mat.set_shader_parameter("isle_r", radii)

# ---- Sonido ----
## Lluvia: un siseo parejo con gotitas que pican. Se repite sin cortes (el final se funde con
## el principio).
static func _make_rain() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 3
	var fade := rate / 4
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	var hp := 0.0
	var prev := 0.0
	var lp := 0.0
	var tick := 0.0
	var peak := 0.0
	for i in n + fade:
		var noise := randf_range(-1.0, 1.0)
		hp = 0.9 * (hp + noise - prev)   # Pasa-altos: siseo
		prev = noise
		lp = lerpf(lp, hp, 0.45)
		if randf() < 0.004:
			tick = randf_range(0.4, 0.9) * (1.0 if randf() < 0.5 else -1.0)
		tick *= 0.9
		buf[i] = lp * 0.55 + tick * randf_range(0.6, 1.0)
	for i in fade:
		buf[i] = lerpf(buf[n + i], buf[i], float(i) / fade)
	buf.resize(n)
	for s in buf:
		peak = maxf(peak, absf(s))
	var w := Synth.wav(buf, rate, 0.7 / maxf(peak, 0.001))
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
