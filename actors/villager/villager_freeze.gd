extends RefCounted
class_name VillagerFreeze
## Congelarse (ver Frost): queda adentro de un bloque de hielo, tieso y quieto donde está, y al rato
## se derrite solo (gotea y el hielo se va achicando y poniendo transparente).
## - Congelado se lo puede agarrar y revolear como cualquiera, pero no se mueve: brazos y piernas
##   quedan duros (ver VillagerRig). Si cae a la isla desde alto (ver SHATTER_SPEED), le pegan un
##   tiro o lo alcanza una explosión, el hielo se hace pedazos y él también: se muere.
## - En el agua el bloque flota: mientras está congelado no se ahoga (ver Villager._water_physics).
## - El fuego lo descongela: si se prende (una antorcha, la bola de fuego, otro que se quema) se
##   derrite de golpe en vez de prenderse. Y al revés: al que se está quemando, el hielo lo apaga en
##   vez de congelarlo (ver Frost).
## No se guarda con la partida, como el fuego: dura unos segundos.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (is_frozen, freeze, thaw).

const FREEZE_TIME := 9.0          # Segundos congelado...
const THAW_TIME := 2.0            # ...de los cuales los últimos se está derritiendo
const SHATTER_SPEED := 700.0      # Cayendo a la isla más rápido que esto (px/s), se rompe
const C_TINT := Color(0.85, 1.0, 1.3)   # Congelado se pone azulado (ver Villager.rig)
var frozen := false
var _t := 0.0                     # Lo que le queda congelado
var _block: IceBlock
var _drips: CPUParticles2D
var _sound: AudioStreamPlayer
static var _freeze_wav: AudioStreamWAV
static var _shatter_wav: AudioStreamWAV

var v: Villager

func _init(villager: Villager) -> void:
	v = villager

## Si lo puede congelar el hielo: vivo y en algún lado donde lo alcance (no adentro de su choza, en
## el altar, comido, en un tornado ni volviendo a la vida).
func can_freeze() -> bool:
	return v.is_alive() and not v.inside and v.altar == null and v.tornado == null and v._rising <= 0.0 \
			and v.zap_state == VillagerBurn.Zap.NONE

## Lo congela (o, si ya estaba, vuelve a empezar la cuenta). Al que se está quemando lo apaga.
func freeze() -> void:
	if not can_freeze():
		return
	if v.on_fire:
		v._burn.put_out(true)   # El hielo lo apaga, con vapor
		return
	var was := frozen
	frozen = true
	_t = FREEZE_TIME
	if was:
		return
	v.wake_up(false)
	if v.food:
		v.food.release_eater()
	v.end_chat()
	v.velocity = Vector2.ZERO
	if v.rig:
		v.rig.modulate = C_TINT
	if _block == null:
		_block = IceBlock.new()
		v.add_child(_block)   # Después del Rig: el hielo va por delante del cuerpo
		_drips = _make_drips()
		v.add_child(_drips)
	_block.visible = true
	_block.melt = 0.0
	_drips.emitting = false
	_play(freeze_sound(), 1.0)
	v.add_fear(VillagerFaith.FEAR_GRAB)
	v.add_mood(VillagerMood.MOOD_FROZEN, "La congelaste" if v.gender == Villager.Gender.FEMALE else "Lo congelaste")
	Game.say("¡Congelado!" if v.gender == Villager.Gender.MALE else "¡Congelada!",
			v.get_global_transform_with_canvas().origin + Vector2(0, -70), UiStyle.C_ICE)

## Se derrite (solo, con el fuego o si lo curás): sin el bloque ni el tinte.
func thaw() -> void:
	if not frozen:
		return
	frozen = false
	_t = 0.0
	_clear()

## El hielo se hizo pedazos (y él también: ver Villager._die, que llama acá).
func shatter() -> void:
	if not frozen:
		return
	frozen = false
	_t = 0.0
	_clear()
	_spawn_shards()
	_play(_shatter_sound(), randf_range(0.9, 1.1))

## Cada frame (lo llama el aldeano): la cuenta para derretirse y el goteo.
func update(dt: float) -> void:
	if not frozen:
		return
	if not v.dragging:   # Agarrado no se derrite: espera a que lo suelten (así no se escurre de la mano)
		_t -= dt
	var melt := clampf(1.0 - _t / THAW_TIME, 0.0, 1.0)
	_block.melt = melt
	_drips.emitting = melt > 0.0 and not v.in_water
	_drips.global_rotation = 0.0   # Gotean para abajo aunque esté tirado o colgando
	if _t <= 0.0:
		thaw()

## Cayó a la isla a v_fall (px/s, ver Villager._land_on_island): desde alto se rompe.
func landed(v_fall: float) -> void:
	if frozen and v_fall >= SHATTER_SPEED:
		v._die()   # (Morirse rompe el hielo, ver Villager._die)

func _clear() -> void:
	if v.rig:
		v.rig.modulate = Color.WHITE
	if _block:
		_block.visible = false
		_drips.emitting = false

func _play(stream: AudioStream, pitch: float) -> void:
	if _sound == null:
		_sound = AudioStreamPlayer.new()
		_sound.volume_db = -6.0
		v.add_child(_sound)
	_sound.stream = stream
	_sound.pitch_scale = pitch
	_sound.play()

## Gotas que caen del bloque mientras se derrite.
func _make_drips() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.6
	p.local_coords = false
	p.emitting = false
	p.position = Vector2(0, IceBlock.BOTTOM - 2.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(IceBlock.HALF_W * 0.8, 1.0)
	p.direction = Vector2.DOWN
	p.spread = 5.0
	p.gravity = Vector2(0, 400)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = Color(0.75, 0.9, 1.0, 0.8)
	return p

## Pedazos de hielo que saltan para todos lados.
func _spawn_shards() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 36
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(IceBlock.HALF_W, (IceBlock.BOTTOM - IceBlock.TOP) * 0.5)
	p.direction = Vector2.UP
	p.spread = 80.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 300.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color_ramp = Villager._fade_ramp(Color(0.85, 0.95, 1.0, 0.95), Color(0.6, 0.85, 1.0, 0.0))
	p.z_index = 15
	v.get_parent().add_child(p)
	p.global_position = v.to_global(Vector2(0, (IceBlock.TOP + IceBlock.BOTTOM) * 0.5))
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---- Sonido ----
## El crujido de congelarse (también lo usa Frost).
static func freeze_sound() -> AudioStreamWAV:
	if _freeze_wav == null:
		_freeze_wav = _make_freeze()
	return _freeze_wav

static func _shatter_sound() -> AudioStreamWAV:
	if _shatter_wav == null:
		_shatter_wav = _make_shatter()
	return _shatter_wav

## Crujido que se cierra: ruido agudo que se apaga, con chasquidos sueltos.
static func _make_freeze() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.6)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var prev := 0.0
	for i in n:
		var k := float(i) / n
		var noise := randf_range(-1.0, 1.0)
		var hiss := (noise - prev) * 0.5   # Pasa-altos: un siseo de hielo
		prev = noise
		var crack := randf_range(-1.0, 1.0) if randf() < 0.015 * (1.0 - k) else 0.0
		buf[i] = (hiss * 0.8 * (1.0 - k) + crack) * minf(1.0, k * 30.0)
	return Synth.wav(buf, rate, 0.8)

## Vidrio que se rompe: un golpe y tintineos agudos que se apagan.
static func _make_shatter() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.9)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var tones: Array[Vector2] = []   # Frecuencia, a qué altura arranca (0..1)
	for i in 7:
		tones.append(Vector2(randf_range(2200.0, 4800.0), randf_range(0.0, 0.35)))
	var prev := 0.0
	for i in n:
		var t := float(i) / rate
		var k := float(i) / n
		var noise := randf_range(-1.0, 1.0)
		var hit := (noise - prev) * exp(-t * 25.0)
		prev = noise
		var ring := 0.0
		for tone in tones:
			if k >= tone.y:
				var tt := t - tone.y * n / rate
				ring += sin(TAU * tone.x * tt) * exp(-tt * 9.0) * 0.25
		buf[i] = hit + ring
	return Synth.wav(buf, rate, 0.85)

## El bloque de hielo, por delante del cuerpo: transparente y celeste, con brillos y el borde claro.
## melt: 0 entero .. 1 derretido (se achica de arriba y se pone transparente).
class IceBlock extends Node2D:
	const TOP := -54.0         # Arriba de la coronilla (ver Villager.HEAD_TOP)...
	const BOTTOM := 35.0       # ...y abajo de los pies (Villager.FEET)
	const HALF_W := 28.0       # Que entre el pelo
	const C_ICE := Color(0.7, 0.9, 1.0, 0.42)
	const C_EDGE := Color(0.92, 0.98, 1.0, 0.9)
	const C_SHINE := Color(1, 1, 1, 0.55)
	var melt := 0.0:
		set(value):
			melt = value
			queue_redraw()
	var _corners: PackedVector2Array

	func _ready() -> void:
		# Un poco irregular, para que no parezca una caja
		_corners = PackedVector2Array()
		for p: Vector2 in [Vector2(-HALF_W, TOP), Vector2(HALF_W, TOP), Vector2(HALF_W, BOTTOM), Vector2(-HALF_W, BOTTOM)]:
			_corners.append(p + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))

	func _draw() -> void:
		var a := 1.0 - melt * 0.85
		var top := lerpf(0.0, (BOTTOM - TOP) * 0.35, melt)   # Se derrite de arriba
		var pts := PackedVector2Array([_corners[0] + Vector2(2, top), _corners[1] + Vector2(-2, top), _corners[2], _corners[3]])
		draw_colored_polygon(pts, Color(C_ICE, C_ICE.a * a))
		# Una cara de costado, más clara, para que tenga volumen
		var side := PackedVector2Array([pts[1], pts[1] + Vector2(5, 4), pts[2] + Vector2(5, -3), pts[2]])
		draw_colored_polygon(side, Color(C_EDGE, 0.25 * a))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(C_EDGE, C_EDGE.a * a), 1.5, true)
		# Brillos en diagonal
		for s: Vector3 in [Vector3(-18, -32, 20), Vector3(-10, -10, 10), Vector3(12, 12, 14)]:
			var from := Vector2(s.x, s.y + top * 0.5)
			draw_line(from, from + Vector2(s.z * 0.45, -s.z), Color(C_SHINE, C_SHINE.a * a), 2.0, true)
