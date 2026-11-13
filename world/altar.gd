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
## Sacrificar al líder de la tribu da un sacrificio de más, pero toda la tribu (menos sus
## enemigos) te cree menos.
## Mientras tenés agarrado a un aldeano, arriba del altar se ve lo que te daría sacrificarlo y lo
## que te costaría (ver Preview, reward y toll).

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
const LEADER_SACRIFICES := 1        # Sacrificar al líder: un sacrificio de más...
const LEADER_FAITH := 10.0          # ...pero toda la tribu (menos sus enemigos) te cree esto menos
const STRUGGLE_EVERY := Vector2(0.2, 0.45)
const FLARE := 0.8                  # Lo que se avivan los braseros al final del ritual (veces lit)
const BEAM_TIME := 0.8
const BEAM_W := Vector2(48.0, 14.0) # Ancho del rayo de luz: arriba y abajo (px de pantalla)
const C_BEAM := Color(0.95, 0.08, 0.05)
const C_SACRIFICE := Color(1.0, 0.36, 0.3)
const PREVIEW_LIFT := 125.0        # Lo que queda el cartel de lo que da por arriba de la piedra (que no lo tape el que tenés agarrado)

var deco: Decoration
var victim: Villager
var _t := 0.0
var _cooldown := 0.0
var _drum := 0
var _struggle := 0.0
var _drum_player: AudioStreamPlayer
var _boom_player: AudioStreamPlayer
var _preview: Preview   # El cartel de lo que da (en el HUD; se crea la primera vez)

func _exit_tree() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()

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
	var screen := get_viewport().get_canvas_transform() * deco.altar_top() + Vector2(0, -50)
	if v.is_child():
		Game.say("Es muy chico para eso", screen, UiStyle.C_WARN)
		return false
	if victim or _cooldown > 0.0:
		Game.say("Los braseros todavía no se prendieron", screen, UiStyle.C_WARN)
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
		if o and o != v and o.is_alive() and o.body_center().distance_to(at) <= WITNESS_RADIUS:
			o.witness_ritual(RITUAL_TIME + 1.5, at)

## Lo sacaron del altar antes de tiempo (o quitaron el altar): no hay sacrificio.
func release() -> void:
	victim = null

## Lo que da sacrificar a v ahora: "offerings" (más cuanto más cree en vos), "sacrifices" (de
## noche, con la Luna de Sangre y si es el líder, más), "xp", y "time": 0 de día, 1 de noche, 2
## Luna de Sangre.
func reward(v: Villager) -> Dictionary:
	var sky := get_tree().get_first_node_in_group("sky")
	var time := 0
	if sky != null and sky.blood_moon:
		time = 2
	elif sky != null and sky.is_night:
		time = 1
	return {"offerings": roundi(lerpf(OFFERING.x, OFFERING.y, v.faith / 100.0)),
			"sacrifices": SACRIFICES[time] + (LEADER_SACRIFICES if v.is_leader() else 0), "xp": 1, "time": time}

## Lo que cuesta sacrificar a v ahora: "mourners" (su pareja, sus amigos y su familia, que lo van
## a llorar y te van a creer menos), "glad" (sus enemigos, que se alegran), "witnesses" (los que
## están cerca y lo van a ver), "prayers" (las ofrendas que te deja cuando reza, que se pierden;
## 0 si ahora no reza) y "leader" (si es el líder de la tribu).
func toll(v: Villager) -> Dictionary:
	var at := deco.altar_top()
	var mourners := 0
	var glad := 0
	var witnesses := 0
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == v or not o.is_alive() or o.is_zombie():
			continue   # (El zombi ya no siente nada, ver Villager._mourn)
		var k := Relations.kind(v, o)
		if k == Relations.Kind.COUPLE or k == Relations.Kind.FRIEND or o.id_number in v.parents \
				or v.id_number in o.parents:
			mourners += 1
		elif k == Relations.Kind.ENEMY:
			glad += 1
		if o.witness(at) > 0.0:
			witnesses += 1
	return {"mourners": mourners, "glad": glad, "witnesses": witnesses,
			"prayers": v.tribute() if v.prays() else 0.0, "leader": v.is_leader()}

func _process(dt: float) -> void:
	_cooldown = maxf(0.0, _cooldown - dt)
	_update_preview()
	if victim == null:
		return
	if not is_instance_valid(victim) or victim.altar != self or not victim.is_alive() \
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

## El cartel de lo que da: solo mientras tenés agarrado a un aldeano vivo y el altar está libre
## (si no se puede, dice por qué). Va en la pantalla, así de noche no se apaga.
func _update_preview() -> void:
	var held: Villager = null
	if victim == null and deco.is_in_group("altar") and not deco.moving and deco.is_visible_in_tree():
		for node in get_tree().get_nodes_in_group("villager"):
			var o := node as Villager
			if o and o.dragging and not o.dead:
				held = o
				break
	if held == null:
		if _preview:
			_preview.visible = false
		return
	if _preview == null:
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud == null:
			return
		_preview = Preview.new()
		hud.add_world_label(_preview)
	var why := ""
	if held.is_child():
		why = "Es muy chico para eso"
	elif _cooldown > 0.0:
		why = "Los braseros todavía no se prendieron"
	_preview.show_reward(held, reward(held), toll(held), why, deco.hit_test(held.get_global_mouse_position()))
	_preview.visible = true
	var at := get_viewport().get_canvas_transform() * (deco.altar_top() + Vector2(0, -PREVIEW_LIFT))
	_preview.position = (at - Vector2(_preview.size.x * 0.5, _preview.size.y)).round()

## El final: baja el rayo de luz roja, el aldeano se deshace y su alma sube. Lo que da y lo que
## les pasa a los que lo vieron (antes de que se muera: después ya no cuenta para nadie).
func _finish() -> void:
	var v := victim
	victim = null
	_cooldown = COOLDOWN
	var at := deco.altar_top()
	var sky := get_tree().get_first_node_in_group("sky")
	var got := reward(v)
	var blood: bool = got.time == 2
	var gained: int = got.sacrifices
	var offering: int = got.offerings
	var leader := v.is_leader()
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == v or not o.is_alive():
			continue
		if leader and not o.is_zombie() and Relations.kind(v, o) != Relations.Kind.ENEMY:
			o.add_faith(-LEADER_FAITH)   # Era el líder: la tribu te cree menos (sus enemigos, no)
		var seen := o.witness(at)
		if seen > 0.0:
			o.add_fear(FEAR * seen)
			if o.creed() == VillagerFaith.Creed.DEVOUT or o.creed() == VillagerFaith.Creed.ZEALOT:
				o.add_faith(FAITH_DEVOUT * seen)
		if Relations.kind(v, o) == Relations.Kind.COUPLE or o.id_number in v.parents or v.id_number in o.parents:
			o.add_faith(-FAITH_LOVED)
			o.add_mood(MOOD_LOVED, "Sacrificaste a alguien que quería")
	if leader:
		var female := v.gender == Villager.Gender.FEMALE
		Game.announce(tr("Sacrificaste a la líder de la tribu" if female else "Sacrificaste al líder de la tribu"),
				Tribe.C_LEADER)
	if blood:
		var moon := get_tree().get_first_node_in_group("moon") as Moon
		if moon:
			moon.feed()   # Con la Luna de Sangre, se lo come ella
	deco.stains += 1
	deco.queue_redraw()
	Game.say(tr("+%d sacrificios") % gained if gained > 1 else tr("+1 sacrificio"),
			get_viewport().get_canvas_transform() * at + Vector2(0, -95), C_SACRIFICE)
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.flash_screen(0.25)
		_beam(hud)
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
func _beam(hud: HUD) -> void:
	var painter := Painter.new()
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

## El cartel que flota arriba del altar mientras tenés agarrado a un aldeano: las ofrendas, los
## sacrificios y la XP que te daría sacrificarlo ahora (o por qué no se puede), y abajo lo que te
## costaría (ver Altar.toll): si es el líder, cuántos lo van a llorar, cuántos se van a alegrar,
## cuántos lo van a ver y las ofrendas de sus rezos que se pierden. El borde se pone rojo cuando
## lo tenés encima del altar: si lo soltás ahí, empieza el ritual.
class Preview extends PanelContainer:
	const CAPTIONS: Array[String] = ["Sacrificio de día", "Sacrificio de noche", "Sacrificio con Luna de Sangre"]
	const ICON_PX := 16
	const C_GLAD := Color(0.62, 0.86, 0.5)
	var _caption: Label
	var _row: HBoxContainer
	var _offerings: Label
	var _sacrifices: Label
	var _xp: Label
	var _line: ColorRect          # La raya entre lo que da y lo que cuesta
	var _costs: VBoxContainer     # Lo que cuesta: una línea por cosa
	var _shown := []   # Lo que muestra ahora (para no rearmarlo cada cuadro)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_build_reward(box)
		_line = ColorRect.new()
		_line.color = UiStyle.C_PANEL_BORDER
		_line.custom_minimum_size = Vector2(0, 1)
		_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_line)
		_costs = VBoxContainer.new()
		_costs.add_theme_constant_override("separation", 0)
		_costs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_costs)

	## Arriba: de qué es el sacrificio (de día, de noche...) y lo que da, con sus íconos.
	func _build_reward(box: VBoxContainer) -> void:
		_caption = UiStyle.label("", 11, UiStyle.C_MUTED)
		_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Lo traduce show_reward
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_caption)
		_row = HBoxContainer.new()
		_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_row.add_theme_constant_override("separation", 4)
		_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_row)
		_offerings = _amount(HudIcon.make("coin", ICON_PX), UiStyle.C_OFFERING)
		_sacrifices = _amount(HudIcon.sacrifice(ICON_PX), Altar.C_SACRIFICE)
		_xp = _amount(HudIcon.make("xp", ICON_PX), UiStyle.C_XP)

	## Un ícono y su número, en la fila (separado del anterior).
	func _amount(icon: Control, color: Color) -> Label:
		if _row.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(8, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_row.add_child(gap)
		_row.add_child(icon)
		var l := UiStyle.label("", 15, color)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Es un número
		_row.add_child(l)
		return l

	## Lo que da sacrificar a v (got, ver Altar.reward) y lo que cuesta (cost, ver Altar.toll); why,
	## por qué no se puede (o ""); over, si está encima del altar.
	func show_reward(v: Villager, got: Dictionary, cost: Dictionary, why: String, over: bool) -> void:
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		var prayers := ""   # Como texto: así solo cambia cuando cambia lo que se ve
		if cost.prayers > 0.0:
			prayers = tr("Rezos perdidos: −%s cada %d s") % [HUD.decimal(cost.prayers), int(hud.tribute_interval if hud else 10.0)]
		var female := v.gender == Villager.Gender.FEMALE
		var shown := [got.offerings, got.sacrifices, got.xp, got.time, why, over, cost.mourners, cost.glad,
				cost.witnesses, prayers, cost.leader, female]
		if shown == _shown:
			return
		_shown = shown
		_show_costs(cost, prayers, female, v.is_child())
		var time: int = got.time
		_caption.text = tr(why) if why != "" else tr(CAPTIONS[time])
		_caption.add_theme_color_override("font_color",
				UiStyle.C_WARN if why != "" else (Altar.C_SACRIFICE if time > 0 else UiStyle.C_MUTED))
		_offerings.text = "+%d" % got.offerings
		_sacrifices.text = "+%d" % got.sacrifices
		_xp.text = "+%d" % got.xp
		_row.modulate.a = 0.4 if why != "" else 1.0
		_costs.modulate.a = _row.modulate.a
		var hot := over and why == ""
		add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_PANEL, 0.9), 10,
				Altar.C_SACRIFICE if hot else UiStyle.C_PANEL_BORDER, 2 if hot else 1, Vector4(10, 4, 10, 6)))
		reset_size()

	## Abajo, lo que cuesta: una línea por cosa (las que no pasan, no van). Un chico no se puede
	## sacrificar: ahí no va nada.
	func _show_costs(cost: Dictionary, prayers: String, female: bool, child: bool) -> void:
		for c in _costs.get_children():
			c.free()
		if not child:
			if cost.leader:
				_cost_line(tr("Es la líder: la tribu te va a creer menos" if female
						else "Es el líder: la tribu te va a creer menos"), Tribe.C_LEADER)
			if cost.mourners > 0:
				_cost_line(tr("La van a llorar: %d" if female else "Lo van a llorar: %d") % cost.mourners, UiStyle.C_WARN)
			if cost.glad > 0:
				_cost_line(tr("Se van a alegrar: %d") % cost.glad, C_GLAD)
			if cost.witnesses > 0:
				_cost_line(tr("La van a ver: %d" if female else "Lo van a ver: %d") % cost.witnesses, UiStyle.C_MUTED)
			if prayers != "":
				_cost_line(prayers, UiStyle.C_OFFERING.darkened(0.15))
		_line.visible = _costs.get_child_count() > 0
		_costs.visible = _line.visible

	func _cost_line(text: String, color: Color) -> void:
		var l := UiStyle.label(text, 12, color)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Ya viene traducido (lleva el número)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_costs.add_child(l)

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
