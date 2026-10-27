extends Node2D
class_name Altar
## El ritual del altar de sacrificios (lo tiene de hijo una Decoration "altar"). Soltás encima
## un aldeano vivo y grande (ver Villager._stop_drag) y queda acostado en la piedra, pataleando
## con la boca abierta, mientras suenan tambores cada vez más seguido y se avivan los braseros.
## Los que están cerca dejan lo que hacen y miran (ver Villager.witness_ritual): los devotos se
## arrodillan a rezar, los aterrados salen corriendo y los herejes se quedan mirando. Al final
## baja un rayo de luz roja, el aldeano se deshace en brasas y sale su alma, que sube al cielo.
## Da más ofrendas que una muerte común (más cuanto más creía en vos) y más sacrificios: de
## noche el doble y con la Luna de Sangre el triple (y además se lo come ella). Los que lo vieron
## se asustan, los devotos te creen más ("aceptó la ofrenda") y su pareja y su familia, mucho
## menos. Entre un ritual y otro los braseros tardan en volver a prenderse. Si lo agarrás antes
## de que termine, lo salvás. Los chicos no: son muy chicos para eso.

const RITUAL_TIME := 4.0
const COOLDOWN := 20.0              # Lo que tardan los braseros en volver a prenderse
const DRUMS: Array[float] = [0.3, 1.2, 1.9, 2.5, 2.95, 3.3, 3.6, 3.85]   # Cuándo suena cada tambor
const WITNESS_RADIUS := 320.0
const OFFERING := Vector2(8.0, 22.0)   # Ofrendas, del que no creía nada al que creía del todo
const SACRIFICES: Array[int] = [1, 2, 3]   # Sacrificios: de día, de noche y con la Luna de Sangre
const FEAR := 15.0                  # Miedo de más para los que lo vieron (de cerca)
const FAITH_DEVOUT := 8.0           # Los devotos que lo vieron: el dios aceptó la ofrenda
const FAITH_LOVED := 25.0           # Su pareja y su familia te creen mucho menos...
const MOOD_LOVED := -10.0           # ...y se ponen todavía más tristes
const STRUGGLE_EVERY := Vector2(0.2, 0.45)
const FLARE := 0.8                  # Lo que se avivan los braseros al final del ritual (veces lit)
const BEAM_TIME := 0.8
const BEAM_W := Vector2(48.0, 14.0) # Ancho del rayo de luz: arriba y abajo (px de pantalla)
const C_BEAM := Color(0.95, 0.08, 0.05)
const C_SACRIFICE := Color(1.0, 0.36, 0.3)

var deco: Decoration
var victim: Villager
var _t := 0.0
var _cooldown := 0.0
var _drum := 0
var _struggle := 0.0
var _drum_player: AudioStreamPlayer
var _boom_player: AudioStreamPlayer

func _ready() -> void:
	deco = get_parent() as Decoration
	_drum_player = AudioStreamPlayer.new()
	_drum_player.stream = _make_drum()
	_drum_player.volume_db = -4.0
	_drum_player.max_polyphony = 3
	add_child(_drum_player)
	_boom_player = AudioStreamPlayer.new()
	_boom_player.volume_db = -8.0
	add_child(_boom_player)

## Lo que pinta los braseros: lit apagados por la lluvia, avivándose durante el ritual, y
## recién después, de a poco vuelven a prenderse.
func flames(lit: float) -> float:
	if victim:
		return lit * (1.0 + FLARE * smoothstep(0.0, RITUAL_TIME, _t))
	if _cooldown > 0.0:
		return lit * clampf(1.0 - _cooldown / COOLDOWN, 0.0, 1.0)
	return lit

## Soltaron a v encima del altar (en p): si se puede, empieza el ritual. false si no lo toma
## (no lo soltaron encima, está muerto, es chico o los braseros no se prendieron todavía).
func takes(v: Villager, p: Vector2) -> bool:
	if not deco.is_in_group("altar") or deco.moving or not deco.hit_test(p) or v.dead:
		return false
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	var screen := get_viewport().get_canvas_transform() * deco.altar_top() + Vector2(0, -50)
	if v.is_child():
		if hud:
			hud.popup_text("Es muy chico para eso", screen, HUD.C_WARN)
		return false
	if victim or _cooldown > 0.0:
		if hud:
			hud.popup_text("Los braseros todavía no se prendieron", screen, HUD.C_WARN)
		return false
	_start(v)
	return true

func _start(v: Villager) -> void:
	victim = v
	_t = 0.0
	_drum = 0
	_struggle = 0.0
	v.lay_on_altar(self)
	var at := deco.altar_top()
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != v and not o.dead and not o.eaten and o.body_center().distance_to(at) <= WITNESS_RADIUS:
			o.witness_ritual(RITUAL_TIME + 1.5, at)

## Lo sacaron del altar antes de tiempo (o quitaron el altar): no hay sacrificio.
func release() -> void:
	victim = null

func _process(dt: float) -> void:
	_cooldown = maxf(0.0, _cooldown - dt)
	if victim == null:
		return
	if not is_instance_valid(victim) or victim.altar != self or victim.dead or victim.eaten \
			or not deco.is_in_group("altar"):
		if is_instance_valid(victim) and victim.altar == self:
			victim.leave_altar()
		victim = null
		return
	_t += dt
	# Acostado arriba de la piedra (si mueven el altar, va con él), pataleando
	victim.global_position = deco.altar_top() + Vector2(0, -Villager.BODY_HALF_W * victim.scale.y)
	_struggle -= dt
	if _struggle <= 0.0 and victim.rig:
		_struggle = randf_range(STRUGGLE_EVERY.x, STRUGGLE_EVERY.y)
		victim.rig.hit(victim.body_center() + Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0)),
				Vector2.from_angle(randf() * TAU), 0.5)
	# Los tambores, cada vez más seguido
	if _drum < DRUMS.size() and _t >= DRUMS[_drum]:
		_drum += 1
		_drum_player.pitch_scale = randf_range(0.95, 1.05) * (1.0 + 0.04 * _drum)
		_drum_player.play()
	if _t >= RITUAL_TIME:
		_finish()

## El final: baja el rayo de luz roja, el aldeano se deshace y su alma sube. Lo que da y lo que
## les pasa a los que lo vieron (antes de que se muera: después ya no cuenta para nadie).
func _finish() -> void:
	var v := victim
	victim = null
	_cooldown = COOLDOWN
	var at := deco.altar_top()
	var sky := get_tree().get_first_node_in_group("sky")
	var blood: bool = sky != null and sky.blood_moon
	var night: bool = sky != null and sky.is_night
	var gained: int = SACRIFICES[2 if blood else (1 if night else 0)]
	var offering := roundi(lerpf(OFFERING.x, OFFERING.y, v.faith / 100.0))
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == v or o.dead or o.eaten:
			continue
		var seen := o._witness(at)
		if seen > 0.0:
			o.add_fear(FEAR * seen)
			if o.creed() == Villager.Creed.DEVOUT or o.creed() == Villager.Creed.ZEALOT:
				o.add_faith(FAITH_DEVOUT * seen)
		if Relations.kind(v, o) == Relations.Kind.COUPLE or o.id_number in v.parents or v.id_number in o.parents:
			o.add_faith(-FAITH_LOVED)
			o.add_mood(MOOD_LOVED, "Sacrificaste a alguien que quería")
	if blood:
		var moon := get_tree().get_first_node_in_group("moon") as Moon
		if moon:
			moon.feed()   # Con la Luna de Sangre, se lo come ella
	deco.stains += 1
	deco.queue_redraw()
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.flash_screen(0.25)
		hud.popup_text(tr("+%d sacrificios") % gained if gained > 1 else tr("+1 sacrificio"),
				get_viewport().get_canvas_transform() * at + Vector2(0, -95), C_SACRIFICE)
		_beam(hud, at)
	if sky:
		sky.flash(0.35)
	if _boom_player.stream == null:
		_boom_player.stream = Meteor._make_boom()
	_boom_player.play()
	_embers(v.body_center())
	var soul := Soul.new()
	deco.get_parent().add_child(soul)
	soul.global_position = v.body_center()
	v.sacrifice(offering, gained)

## El rayo de luz roja que baja del cielo hasta el altar (en el overlay del HUD, así de noche
## no se apaga).
func _beam(hud: HUD, at: Vector2) -> void:
	var painter := HUD.Painter.new()
	var t0 := Time.get_ticks_msec()
	painter.paint = func(ci: CanvasItem):
		var k := 1.0 - (Time.get_ticks_msec() - t0) / 1000.0 / BEAM_TIME
		if k <= 0.0 or not is_instance_valid(deco):
			return
		var bottom := get_viewport().get_canvas_transform() * deco.altar_top()
		for layer in 3:   # Un halo ancho y, adentro, el rayo
			var w := BEAM_W * (1.0 - layer * 0.35) * (0.6 + 0.4 * k)
			var col := Color(C_BEAM.lerp(Color(1.0, 0.8, 0.6), layer * 0.35), (0.35 + 0.3 * layer) * k)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(bottom.x - w.x * 0.5, 0.0), Vector2(bottom.x + w.x * 0.5, 0.0),
					Vector2(bottom.x + w.y * 0.5, bottom.y), Vector2(bottom.x - w.y * 0.5, bottom.y)]), col)
		ci.draw_circle(bottom, 26.0 * k, Color(C_BEAM, 0.35 * k), true, -1.0, true)
	hud.overlay.add_child(painter)
	get_tree().create_timer(BEAM_TIME).timeout.connect(painter.queue_free)

## Brasas y humo donde estaba.
func _embers(at: Vector2) -> void:
	for spec: Array in [[Meteor._fire_gradient(), 36, 260.0, -120.0, 1.0], [null, 18, 70.0, -60.0, 1.6]]:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.explosiveness = 0.85
		p.amount = spec[1]
		p.lifetime = spec[4]
		p.direction = Vector2.UP
		p.spread = 60.0
		p.initial_velocity_min = spec[2] * 0.3
		p.initial_velocity_max = spec[2]
		p.gravity = Vector2(0, spec[3])
		p.scale_amount_min = 2.0
		p.scale_amount_max = 4.5
		if spec[0]:
			p.color_ramp = spec[0]
		else:
			p.color = Color(0.25, 0.22, 0.24, 0.7)
		p.z_index = 15
		deco.get_parent().add_child(p)
		p.global_position = at
		p.emitting = true
		p.finished.connect(p.queue_free)

## Un golpe de tambor grave (tono que baja, con un chasquido al principio).
static func _make_drum() -> AudioStreamWAV:
	var rate := 22050
	var buf := PackedFloat32Array()
	var ph := 0.0
	var n := int(rate * 0.4)
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(150.0, 55.0, minf(1.0, k * 3.0)) / rate
		buf.append(sin(ph) * exp(-k * 7.0) + randf_range(-1.0, 1.0) * 0.3 * exp(-k * 60.0))
	return Synth.wav(buf, rate, 0.9)

## El alma del sacrificado: un fantasmita blanco que sube al cielo meciéndose y se desvanece.
class Soul extends Node2D:
	const RISE := 70.0      # Px por segundo
	const LIFE := 2.4
	var _t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(dt: float) -> void:
		_t += dt
		position.y -= RISE * dt
		position.x += sin(_t * 3.0) * 20.0 * dt
		modulate.a = clampf(1.0 - (_t - LIFE * 0.5) / (LIFE * 0.5), 0.0, 1.0)
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var body := PackedVector2Array()
		for i in 13:   # La cabeza redonda
			var a := PI + PI * i / 12.0
			body.append(Vector2(cos(a), sin(a)) * 9.0)
		for i in 7:    # La colita ondulada, abajo
			var x := lerpf(9.0, -9.0, i / 6.0)
			body.append(Vector2(x, 10.0 + (3.0 if i % 2 == 0 else 0.0) + sin(_t * 8.0 + i) * 1.5))
		draw_colored_polygon(body, Color(1.0, 1.0, 1.0, 0.85))
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(side * 3.2, -1.5), 1.6, Color(0.15, 0.15, 0.25), true, -1.0, true)
		draw_circle(Vector2.ZERO, 16.0, Color(1.0, 1.0, 1.0, 0.12), true, -1.0, true)
