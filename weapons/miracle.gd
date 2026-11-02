extends Node2D
class_name Miracle
## Milagros: poderes buenos que se desbloquean en la tienda y que, cada vez que se usan, gastan
## devoción. Se sacan desde el HUD o con su tecla (Esc o click derecho los guardan), y cada click
## baja la luz sobre el aldeano (o el cadáver) que está ahí:
## - Resurrección [L]: sobre un cadáver reciente (quedan unos segundos tirados, ver
##   Villager.CORPSE_TIME) baja un haz de luz del cielo, el cuerpo sube flotando, se endereza y
##   vuelve a la vida, sano (ver Villager.resurrect). Su familia y sus amigos te creen muchísimo
##   más, los devotos que lo ven se arrodillan y a los herejes les da miedo. A los que se murieron
##   de viejos no: ya les había llegado la hora. Tampoco a los que no dejaron cuerpo (hechos
##   cenizas, comidos o ahogados).
## - Escudo [O]: una bendición, un aura dorada que lo protege un rato de los rayos, de las
##   mordidas de zombi (ni lo persiguen) y de los contagios de gripe y de espora (ver
##   Villager.give_shield y Aura).
## - Vacuna [V]: cae del cielo una gota de luz que lo deja inmune a la espora y a la gripe por un
##   tiempo largo, pero cuesta mucha devoción. No cura: al que ya está enfermo hay que curarlo
##   antes (ver Villager.vaccinate).
## Mientras están afuera, la resurrección marca los cadáveres a los que todavía llega (con lo que
## les queda) y la vacuna, a los que ya están vacunados. World crea uno de cada tipo (kind).

signal armed_changed(on: bool)

enum Kind { RESURRECT, SHIELD, VACCINE }
## Por tipo: su tecla, su precio (ofrendas, en la tienda), lo que gasta cada vez (devoción), su
## color y lo que dicen el HUD (ver HUD.TOOLS) y la tienda.
const KINDS := {
	Kind.RESURRECT: {
		"key": KEY_L,
		"price": 200,
		"cost": 35.0,
		"color": Color(1.0, 0.94, 0.66),
		"tip": "Sacar o guardar la resurrección [L]",
		"locked_tip": "Desbloqueala en la tienda (%d ofrendas)",
		"need": "Desbloqueá la resurrección en la tienda",
		"unlocked": "¡Resurrección desbloqueada! Sacala con L",
		"done": "Desbloqueada",
		"shop": "Sobre un cadáver reciente: vuelve a la vida, sano. Su familia te cree muchísimo más y a los herejes les da miedo. Gasta bastante devoción.",
		"hint": "Click sobre un cadáver reciente para devolverle la vida (−%d devoción) · click derecho, Esc o L para guardarla.",
		"aim": "Apuntá a un cadáver",
	},
	Kind.SHIELD: {
		"key": KEY_O,
		"price": 90,
		"cost": 8.0,
		"color": Color(1.0, 0.8, 0.32),
		"tip": "Sacar o guardar el escudo [O]",
		"locked_tip": "Desbloquealo en la tienda (%d ofrendas)",
		"need": "Desbloqueá el escudo en la tienda",
		"unlocked": "¡Escudo desbloqueado! Sacalo con O",
		"done": "Desbloqueado",
		"shop": "Una bendición: un aura que protege a un aldeano un rato de los rayos, las mordidas de zombi y los contagios.",
		"hint": "Click sobre un aldeano para bendecirlo con un escudo (−%d devoción) · click derecho, Esc u O para guardarlo.",
		"aim": "Apuntá a un aldeano",
	},
	Kind.VACCINE: {
		"key": KEY_V,
		"price": 120,
		"cost": 25.0,
		"color": Color(0.42, 0.9, 0.86),
		"tip": "Sacar o guardar la vacuna [V]",
		"locked_tip": "Desbloqueala en la tienda (%d ofrendas)",
		"need": "Desbloqueá la vacuna en la tienda",
		"unlocked": "¡Vacuna desbloqueada! Sacala con V",
		"done": "Desbloqueada",
		"shop": "Deja a un aldeano inmune a la espora y a la gripe por un día entero, pero cuesta mucha devoción. No cura al que ya está enfermo.",
		"hint": "Click sobre un aldeano sano para vacunarlo contra la gripe y la espora (−%d devoción) · click derecho, Esc o V para guardarla.",
		"aim": "Apuntá a un aldeano",
	},
}

## Si están comprados, por tipo (se guardan con la partida, ver HUD.save_state).
static var unlocked: Array[bool] = [false, false, false]
static var _armed: Array[bool] = [false, false, false]

const COOLDOWN := 0.5
const REACH := 14.0              # El click a menos de esto del cuerpo (o del cadáver)
const SQUASH := 0.42             # Los círculos en el piso, achatados (como Curar)
const AIM_RADIUS := 22.0
# Resurrección: el haz baja desde arriba de todo mientras el cuerpo sube (ver Villager.RISE_TIME)
const RISE_IN := 0.3             # Lo que tarda en bajar el haz...
const RISE_FADE := 0.8           # ...y en irse, ya de vuelta
const RISE_W := 30.0             # Medio ancho del haz, abajo
# Escudo: un haz como el de Curar
const BEAM_TIME := 0.9
const BEAM_HEIGHT := 150.0
# Vacuna: la gota cae del cielo y, al tocarlo, sale un anillo
const DROP_TIME := 0.35
const DROP_HEIGHT := 170.0
const RING_TIME := 0.6
## Con más de esto de la vacuna todavía (veces Villager.VACCINE_TIME) no hace falta otra.
const VACCINE_REFRESH := 0.5

const C_OUTLINE := Color(0.06, 0.06, 0.1)
const C_GOLD := Color(1.0, 0.8, 0.32)
const C_TEAL := Color(0.42, 0.9, 0.86)
const C_STONE := Color(0.68, 0.7, 0.76)

var kind := Kind.RESURRECT
var _cooldown := 0.0
var _t := 0.0
## Lo que se está dibujando: {v (el aldeano), pos (en el piso, por si ya no está), t, burst}.
var _fx: Array[Dictionary] = []
var _drawn := false              # Se dibujó algo el cuadro anterior (para borrarlo)
static var _sounds := {}         # nombre -> AudioStreamWAV

func _ready() -> void:
	_armed[kind] = false
	unlocked[kind] = false
	z_index = 30   # Encima de los aldeanos

## Si hay alguno afuera (ver HUD.aiming).
static func any_armed() -> bool:
	return _armed.has(true)

func set_armed(on: bool) -> void:
	if on and not unlocked[kind]:
		_popup_screen(KINDS[kind].need)
		return
	if on == _armed[kind]:
		return
	_armed[kind] = on
	armed_changed.emit(on)   # Antes del cursor: al sacarlo se guarda otro, que lo deja en la flecha
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KINDS[kind].key:
			set_armed(not _armed[kind])
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _armed[kind]:
			set_armed(false)
			get_viewport().set_input_as_handled()
		return

	if not _armed[kind] or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_cast(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	for i in range(_fx.size() - 1, -1, -1):
		var fx := _fx[i]
		fx.t += dt
		var v: Villager = fx.v if is_instance_valid(fx.v) else null
		match kind:
			Kind.RESURRECT:
				if v and not v.is_queued_for_deletion():
					fx.pos = Vector2(v.global_position.x, v.floor_y + 12.0)
				if not fx.burst and fx.t >= Villager.RISE_TIME:
					# Volvió: estalla la luz
					fx.burst = true
					if v and not v.dead:
						_sparkles(v.body_center(), KINDS[kind].color, 40, Vector2(16, 26))
				if fx.t >= Villager.RISE_TIME + RISE_FADE:
					_fx.remove_at(i)
			Kind.SHIELD:
				if fx.t >= BEAM_TIME:
					_fx.remove_at(i)
			Kind.VACCINE:
				if v and not v.is_queued_for_deletion():
					fx.pos = v.to_global(Vector2(0, Villager.HEAD_TOP))
				if not fx.burst and fx.t >= DROP_TIME:
					fx.burst = true
					_sparkles(fx.pos + Vector2(0, 14), C_TEAL, 18, Vector2(10, 12))
				if fx.t >= DROP_TIME + RING_TIME:
					_fx.remove_at(i)
	var drawing := _armed[kind] or not _fx.is_empty()
	if drawing or _drawn:
		queue_redraw()
	_drawn = drawing

# ---- Lanzarlo ----
## Click en p: el milagro sobre el aldeano (o el cadáver) que está ahí, si se puede y si alcanza
## la devoción.
func _cast(p: Vector2) -> void:
	if _cooldown > 0.0:
		return
	var v := _corpse_at(p) if kind == Kind.RESURRECT else _villager_at(p)
	if v == null:
		_popup(KINDS[kind].aim, p, HUD.C_WARN)
		return
	var why := _problem(v)
	if why != "":
		_popup(why, v.body_center(), HUD.C_MUTED)
		return
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud and not hud.spend_energy(KINDS[kind].cost):
		_popup("Devoción insuficiente", v.body_center(), HUD.C_WARN)
		return
	_cooldown = COOLDOWN
	match kind:
		Kind.RESURRECT:
			v.resurrect()
			_fx.append({"v": v, "pos": Vector2(v.global_position.x, v.floor_y + 12.0), "t": 0.0, "burst": false})
			_rising_sparkles(v)
			_play("choir", -8.0)
		Kind.SHIELD:
			v.give_shield()
			_fx.append({"v": v, "pos": v.ground_point(), "t": 0.0, "burst": false})
			_sparkles(v.body_center(), C_GOLD, 22, Vector2(14, 20))
			_play("shield", -10.0)
		Kind.VACCINE:
			v.vaccinate()
			_fx.append({"v": v, "pos": v.to_global(Vector2(0, Villager.HEAD_TOP)), "t": 0.0, "burst": false})
			_play("vaccine", -10.0)

## Por qué no se puede hacer el milagro sobre v ("" si se puede).
func _problem(v: Villager) -> String:
	var female := v.gender == Villager.Gender.FEMALE
	match kind:
		Kind.RESURRECT:
			return v.revive_problem()
		Kind.SHIELD:
			if v.is_zombie():
				return "El hongo ya la domina" if female else "El hongo ya lo domina"
		Kind.VACCINE:
			if v.is_zombie():
				return "Ya no tiene cura"
			if v.flu == Villager.Flu.INCUBATING or v.flu == Villager.Flu.SICK or v.spore > 0.0:
				return "Ya está enferma: curala primero" if female else "Ya está enfermo: curalo primero"
			if v.vaccine_t > Villager.VACCINE_TIME * VACCINE_REFRESH:
				return "Ya está vacunada" if female else "Ya está vacunado"
	return ""

## El cadáver más cerca del click (o null).
func _corpse_at(p: Vector2) -> Villager:
	var best: Villager = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.revivable() and v.visible:
			var d := v.body_distance(p)
			if d < best_d:
				best = v
				best_d = d
	return best

## El aldeano vivo bajo el click (el de más adelante), o null.
func _villager_at(p: Vector2) -> Villager:
	var best: Villager = null
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or v.dead or v.eaten or v.inside or not v.visible or v.is_queued_for_deletion():
			continue
		if v.body_distance(p) < REACH and (best == null or Gun.drawn_in_front(v, best)):
			best = v
	return best

# ---- Partículas y carteles ----
## Chispitas que suben desde at.
func _sparkles(at: Vector2, color: Color, amount: int, extents: Vector2) -> void:
	var p := _particles(amount, 0.9, color)
	p.explosiveness = 0.6
	p.emission_rect_extents = extents
	get_parent().add_child(p)
	p.global_position = at - Vector2(0, 10)
	p.emitting = true
	p.finished.connect(p.queue_free)

## Mientras resucita, motas de luz que suben desde el cuerpo.
func _rising_sparkles(v: Villager) -> void:
	var p := _particles(46, Villager.RISE_TIME, KINDS[Kind.RESURRECT].color)
	p.explosiveness = 0.0   # De a poco, todo el tiempo que tarda en volver
	p.emission_rect_extents = Vector2(22, 8)
	get_parent().add_child(p)
	p.global_position = Vector2(v.global_position.x, v.floor_y)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _particles(amount: int, lifetime: float, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 50.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color_ramp = Villager._fade_ramp(color.lightened(0.4), Color(color, 0.0))
	p.z_index = 31
	return p

## Cartel que sale arriba de at (coordenadas del mundo).
func _popup(text: String, at: Vector2, color: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.popup_text(text, get_canvas_transform() * at + Vector2(0, -70), color)

## Cartel en el medio de la pantalla.
func _popup_screen(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.popup_text(text, get_viewport_rect().size * Vector2(0.5, 0.42), HUD.C_WARN)

# ---- Dibujo ----
func _draw() -> void:
	for fx in _fx:
		match kind:
			Kind.RESURRECT:
				_draw_rise(fx)
			Kind.SHIELD:
				_draw_beam(fx)
			Kind.VACCINE:
				_draw_drop(fx)
	if _armed[kind]:
		_draw_marks()
		_draw_aim()

## El haz de la resurrección: baja desde arriba de todo, se queda mientras el cuerpo sube y,
## cuando vuelve, estalla en un anillo y se apaga.
func _draw_rise(fx: Dictionary) -> void:
	var t: float = fx.t
	var a := minf(1.0, t / RISE_IN)
	if t > Villager.RISE_TIME:
		a = 1.0 - (t - Villager.RISE_TIME) / RISE_FADE
	a = clampf(a, 0.0, 1.0)
	var base: Vector2 = fx.pos
	var top := (get_canvas_transform().affine_inverse() * Vector2.ZERO).y - 20.0
	var col: Color = KINDS[Kind.RESURRECT].color
	var w := RISE_W * (0.9 + 0.1 * sin(_t * 7.0))
	# Arriba transparente y abajo, donde está el cuerpo, brillante (y adentro, un núcleo blanco)
	for layer: Array in [[w, Color(C_GOLD, 0.42 * a)], [w * 0.32, Color(1, 1, 0.92, 0.6 * a)]]:
		var lw: float = layer[0]
		var lc: Color = layer[1]
		var beam := PackedVector2Array([Vector2(base.x - lw * 0.55, top), Vector2(base.x + lw * 0.55, top),
				base + Vector2(lw, 0), base + Vector2(-lw, 0)])
		draw_polygon(beam, PackedColorArray([Color(lc, 0.0), Color(lc, 0.0), lc, lc]))
	draw_set_transform(base, 0.0, Vector2(1.0, SQUASH))
	draw_circle(Vector2.ZERO, w * 1.5, Color(col, 0.32 * a), true, -1.0, true)
	if t > Villager.RISE_TIME:
		var k := (t - Villager.RISE_TIME) / RISE_FADE
		draw_arc(Vector2.ZERO, lerpf(w, w * 3.5, k), 0.0, TAU, 40, Color(1, 1, 0.9, 0.8 * (1.0 - k)), 3.0, true)
	draw_set_transform(Vector2.ZERO)

## El haz del escudo: baja de golpe y se va apagando (como el de Curar), dorado.
func _draw_beam(fx: Dictionary) -> void:
	var k: float = fx.t / BEAM_TIME
	var a := 1.0 - k
	var w := AIM_RADIUS * (0.55 + 0.25 * sin(minf(1.0, k * 4.0) * PI * 0.5))
	var base: Vector2 = fx.pos
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-w * 0.45, -BEAM_HEIGHT), base + Vector2(w * 0.45, -BEAM_HEIGHT),
		base + Vector2(w, 0), base + Vector2(-w, 0),
	]), Color(C_GOLD, 0.35 * a))
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-w * 0.15, -BEAM_HEIGHT), base + Vector2(w * 0.15, -BEAM_HEIGHT),
		base + Vector2(w * 0.35, 0), base + Vector2(-w * 0.35, 0),
	]), Color(1, 1, 1, 0.45 * a))
	draw_set_transform(base, 0.0, Vector2(1.0, SQUASH))
	draw_circle(Vector2.ZERO, AIM_RADIUS * (0.8 + 0.6 * k), Color(C_GOLD, 0.4 * a), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)

## La gota de la vacuna: cae del cielo hasta la cabeza y, al tocarla, sale un anillo.
func _draw_drop(fx: Dictionary) -> void:
	var t: float = fx.t
	var head: Vector2 = fx.pos
	if t < DROP_TIME:
		var k := t / DROP_TIME
		var at := head - Vector2(0, DROP_HEIGHT * (1.0 - k * k))
		draw_circle(at, 9.0, Color(C_TEAL, 0.25), true, -1.0, true)   # El brillo
		paint_drop(self, at, 1.0, 1.0)
		return
	var r := (t - DROP_TIME) / RING_TIME
	var a := 1.0 - r
	draw_arc(head + Vector2(0, 30), lerpf(8.0, 44.0, r), 0.0, TAU, 32, Color(C_TEAL, 0.85 * a), 2.5, true)
	draw_arc(head + Vector2(0, 30), lerpf(4.0, 30.0, r), 0.0, TAU, 24, Color(1, 1, 1, 0.6 * a), 1.5, true)

## Mientras está afuera: la resurrección marca los cadáveres a los que llega (con un aro que se
## va gastando con lo que les queda tirados) y la vacuna, a los que ya están vacunados.
func _draw_marks() -> void:
	var col: Color = KINDS[kind].color
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or not v.visible or v.is_queued_for_deletion():
			continue
		match kind:
			Kind.RESURRECT:
				if not v.revivable() or v.revive_problem() != "":
					continue
				# Un aro en el piso que se va gastando con lo que le queda tirado (por encima de todo:
				# así se lo encuentra aunque haya gente adelante)
				var at := Vector2(v.global_position.x, v.floor_y + 10.0)
				var left := clampf(1.0 - v.corpse_timer / Villager.CORPSE_TIME, 0.0, 1.0)
				var pulse := 0.6 + 0.4 * sin(_t * 5.0)
				draw_set_transform(at, 0.0, Vector2(1.0, SQUASH))
				draw_circle(Vector2.ZERO, 26.0, Color(col, 0.22 * pulse), true, -1.0, true)
				draw_arc(Vector2.ZERO, 28.0, -PI * 0.5, -PI * 0.5 + TAU * left, 36, C_OUTLINE, 6.0, true)
				draw_arc(Vector2.ZERO, 28.0, -PI * 0.5, -PI * 0.5 + TAU * left, 36, C_GOLD, 3.0, true)
				draw_set_transform(Vector2.ZERO)
			Kind.VACCINE:
				if v.dead or v.eaten or not v.vaccinated():
					continue
				var head := v.to_global(Vector2(0, Villager.HEAD_TOP - 12.0))
				for pass_i in 2:
					var c := C_OUTLINE if pass_i == 0 else C_TEAL
					var w := 5.0 if pass_i == 0 else 2.6
					draw_line(head + Vector2(-5, 0), head + Vector2(5, 0), c, w, true)
					draw_line(head + Vector2(0, -5), head + Vector2(0, 5), c, w, true)

func _draw_aim() -> void:
	var m := get_global_mouse_position()
	var ready := _cooldown <= 0.0
	var col: Color = KINDS[kind].color
	var line := Color(col, 0.95 if ready else 0.4)
	for pass_i in 2:
		var c := C_OUTLINE if pass_i == 0 else line
		var w := 3.5 if pass_i == 0 else 1.6
		var ring := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			ring.append(m + Vector2(cos(a), sin(a) * SQUASH) * AIM_RADIUS)
		draw_polyline(ring, c, w, true)
	# Brillitos que giran alrededor y el ícono del milagro al lado
	for i in 3:
		var a := _t * 2.0 + TAU * i / 3.0
		draw_circle(m + Vector2(cos(a), sin(a) * SQUASH) * AIM_RADIUS, 2.2, Color(col.lightened(0.5), 0.9), true, -1.0, true)
	paint_icon(self, kind, 22.0, m + Vector2(12, -34))
	if not ready:
		var k := 1.0 - _cooldown / COOLDOWN
		draw_arc(m, 12.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, col, 2.0, true)

## La gota de la vacuna (centrada en at, s veces su tamaño).
static func paint_drop(ci: CanvasItem, at: Vector2, s: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		pts.append(at + Vector2(cos(a), sin(a)) * 5.5 * s)
	pts.append(at + Vector2(0, -11.0) * s)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_colored_polygon(pts, Color(C_TEAL, alpha))
	ci.draw_polyline(outline, Color(C_OUTLINE, alpha), 1.5 * s, true)
	ci.draw_circle(at + Vector2(-2.0, -1.0) * s, 1.6 * s, Color(1, 1, 1, 0.8 * alpha), true, -1.0, true)

## El ícono de cada uno (para el HUD, la tienda y al lado de la mira), en un cuadrado de s px que
## empieza en at: una lápida con una aureola, un escudo dorado y una jeringa.
static func paint_icon(ci: CanvasItem, k: Kind, s: float, at := Vector2.ZERO) -> void:
	var lw := maxf(1.0, s * 0.05)
	match k:
		Kind.RESURRECT:
			# Rayos de luz detrás de la lápida, y una aureola arriba
			var glow: Color = KINDS[Kind.RESURRECT].color
			var top := at + Vector2(0.5, 0.38) * s
			for i in 5:
				var d := Vector2.from_angle(lerpf(-PI * 0.9, -PI * 0.1, i / 4.0))
				ci.draw_line(top + d * s * 0.3, top + d * s * 0.46, Color(glow, 0.85), maxf(1.2, s * 0.06), true)
			ci.draw_rect(Rect2(at + Vector2(0.3, 0.42) * s, Vector2(0.4, 0.46) * s), C_STONE)
			ci.draw_circle(at + Vector2(0.5, 0.42) * s, s * 0.2, C_STONE, true, -1.0, true)
			ci.draw_rect(Rect2(at + Vector2(0.22, 0.86) * s, Vector2(0.56, 0.08) * s), Color(0.45, 0.62, 0.3))
			var ink := C_STONE.darkened(0.45)
			ci.draw_line(at + Vector2(0.5, 0.38) * s, at + Vector2(0.5, 0.7) * s, ink, maxf(1.2, s * 0.06), true)
			ci.draw_line(at + Vector2(0.4, 0.48) * s, at + Vector2(0.6, 0.48) * s, ink, maxf(1.2, s * 0.06), true)
			ci.draw_set_transform(at + Vector2(0.5, 0.1) * s, 0.0, Vector2(1.0, 0.38))
			ci.draw_arc(Vector2.ZERO, s * 0.2, 0.0, TAU, 20, C_GOLD, maxf(1.5, s * 0.1), true)
			ci.draw_set_transform(Vector2.ZERO)
		Kind.SHIELD:
			var shield := PackedVector2Array()
			for xy: Vector2 in [Vector2(0.5, 0.06), Vector2(0.88, 0.2), Vector2(0.84, 0.52), Vector2(0.72, 0.74),
					Vector2(0.5, 0.94), Vector2(0.28, 0.74), Vector2(0.16, 0.52), Vector2(0.12, 0.2)]:
				shield.append(at + xy * s)
			var inner := PackedVector2Array()
			var c := at + Vector2(0.5, 0.48) * s
			for p in shield:
				inner.append(c + (p - c) * 0.72)
			ci.draw_colored_polygon(shield, C_GOLD)
			ci.draw_colored_polygon(inner, C_GOLD.lightened(0.35))
			ci.draw_rect(Rect2(at + Vector2(0.45, 0.24) * s, Vector2(0.1, 0.5) * s), Color(1, 1, 0.95))
			ci.draw_rect(Rect2(at + Vector2(0.32, 0.38) * s, Vector2(0.36, 0.1) * s), Color(1, 1, 0.95))
			shield.append(shield[0])
			ci.draw_polyline(shield, C_GOLD.darkened(0.45), lw, true)
		Kind.VACCINE:
			# Una jeringa en diagonal, con el líquido turquesa
			var a := at + Vector2(0.3, 0.7) * s       # Donde empieza la aguja
			var b := at + Vector2(0.72, 0.28) * s     # Donde está el émbolo
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x) * s * 0.11
			var glass := Color(0.86, 0.93, 0.97)
			var mid := a.lerp(b, 0.62)
			ci.draw_line(a, a - d * s * 0.24, Color(0.8, 0.82, 0.88), maxf(1.2, s * 0.05), true)
			ci.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), glass)
			ci.draw_colored_polygon(PackedVector2Array([a + n, mid + n, mid - n, a - n]), C_TEAL)
			ci.draw_line(b + n * 1.6, b - n * 1.6, Color(0.55, 0.6, 0.7), maxf(1.5, s * 0.07), true)
			ci.draw_line(b, b + d * s * 0.16, Color(0.55, 0.6, 0.7), maxf(1.2, s * 0.06), true)
			var thumb := b + d * s * 0.16
			ci.draw_line(thumb + n, thumb - n, Color(0.55, 0.6, 0.7), maxf(1.5, s * 0.08), true)
			ci.draw_polyline(PackedVector2Array([a + n, b + n, b - n, a - n, a + n]), C_OUTLINE, lw, true)

## El aura del escudo (ver Villager.give_shield): una burbuja dorada alrededor del cuerpo, con un
## brillo que la recorre y un aro en el piso. Aparece inflándose, se ilumina cuando para algo (ver
## Villager._ward_off) y, cuando se está por terminar, titila cada vez más rápido.
class Aura extends Node2D:
	const CENTER := Vector2(0, -5)       # Coordenadas del aldeano
	const RADII := Vector2(27, 45)
	const FLOOR := Vector2(0, 30)
	const FLOOR_RADII := Vector2(22, 6)
	const POINTS := 32
	const GROW_TIME := 0.3
	const FADE_FROM := 8.0               # Le queda esto: empieza a titilar
	const C_FILL := Color(1.0, 0.9, 0.55)
	const C_RIM := Color(1.0, 0.82, 0.38)

	var villager: Villager
	var flash := 0.0                     # 1 recién paró algo (se apaga solo)
	var _t := 0.0
	var _grow := 0.0
	var _ring := PackedVector2Array()    # Una elipse de radio 1, cerrada

	func _ready() -> void:
		for i in POINTS + 1:
			var a := TAU * i / POINTS
			_ring.append(Vector2(cos(a), sin(a)))

	func _process(dt: float) -> void:
		_t += dt
		_grow = minf(1.0, _grow + dt / GROW_TIME)
		flash = maxf(0.0, flash - dt * 2.0)
		queue_redraw()

	func _draw() -> void:
		if villager == null:
			return
		var a := _grow
		var left := villager.shield_t
		if left < FADE_FROM:
			var hz := lerpf(5.0, 1.2, left / FADE_FROM)
			a *= 0.35 + 0.65 * (0.5 + 0.5 * cos(_t * TAU * hz))
		var size := RADII * (0.6 + 0.4 * ease(_grow, 0.4)) * (1.0 + 0.03 * sin(_t * 3.0) + 0.08 * flash)
		var shell := PackedVector2Array()
		for p in _ring:
			shell.append(CENTER + p * size)
		var fill := shell.duplicate()
		fill.remove_at(fill.size() - 1)   # El último repite el primero
		draw_colored_polygon(fill, Color(C_FILL, 0.16 * a + 0.25 * flash))
		draw_polyline(shell, Color(C_RIM, 0.3 * a + 0.3 * flash), 7.0, true)   # El resplandor del borde...
		draw_polyline(shell, Color(C_RIM.lightened(0.3), 0.9 * a + 0.1 * flash), 2.2, true)   # ...y el borde
		# Un brillo que la recorre, y dos chispitas que giran alrededor
		var from := int(fmod(_t * 10.0, POINTS))
		var shine := PackedVector2Array()
		for i in 7:
			shine.append(shell[(from + i) % POINTS])
		draw_polyline(shine, Color(1, 1, 0.95, 0.9 * a), 3.0, true)
		for i in 2:
			var ang := _t * 1.6 + PI * i
			draw_circle(CENTER + Vector2(cos(ang), sin(ang) * 0.35) * size.x * 1.05, 2.2, Color(1, 1, 0.9, 0.95 * a))
		# El aro en el piso (parado en la isla)
		if villager.is_idle():
			var floor_ring := PackedVector2Array()
			for p in _ring:
				floor_ring.append(FLOOR + p * FLOOR_RADII * (1.0 + 0.15 * flash))
			draw_polyline(floor_ring, Color(C_RIM, 0.75 * a + 0.25 * flash), 2.0, true)

# ---- Sonido ----
func _play(sound: String, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sound_for(sound)
	p.volume_db = db
	p.pitch_scale = randf_range(0.97, 1.03)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## (También lo usa Villager: "block", cuando el escudo para algo.)
static func sound_for(sound: String) -> AudioStreamWAV:
	if not _sounds.has(sound):
		_sounds[sound] = _make_sound(sound)
	return _sounds[sound]

static func _make_sound(sound: String) -> AudioStreamWAV:
	var rate := 22050
	var buf := PackedFloat32Array()
	match sound:
		"choir":
			# Un coro que crece ("aaah", un acorde mayor con vibrato) y campanitas que suben
			var n := int(rate * 2.9)
			buf.resize(n)
			var chord := [220.0, 277.18, 329.63, 440.0, 554.37]
			for i in n:
				var t := float(i) / rate
				var env := smoothstep(0.0, 0.9, t) * (1.0 - smoothstep(2.1, 2.9, t))
				var s := 0.0
				for j in chord.size():
					var f: float = chord[j]
					var ph := TAU * f * t + 0.5 * sin(TAU * 5.0 * t + j)
					s += sin(ph) + 0.35 * sin(ph * 2.0) + 0.15 * sin(ph * 3.0)
				buf[i] = s * env * 0.07
			var bells := [880.0, 1108.73, 1318.51, 1760.0]
			for j in bells.size():
				var start := int(rate * (0.8 + 0.28 * j))
				for i in range(start, n):
					var t := float(i - start) / rate
					var f: float = bells[j]
					buf[i] += sin(TAU * f * t) * exp(-t * 4.0) * minf(1.0, t * 200.0) * 0.18
		"shield":
			# Un "fuuum" que se infla y una campana
			var n := int(rate * 0.9)
			buf.resize(n)
			var ph := 0.0
			for i in n:
				var t := float(i) / rate
				var k := float(i) / n
				ph += TAU * lerpf(200.0, 340.0, k) / rate
				buf[i] = sin(ph) * sin(k * PI) * 0.3
				var tb := t - 0.12
				if tb > 0.0:
					buf[i] += (sin(TAU * 1046.5 * tb) + 0.4 * sin(TAU * 1568.0 * tb)) * exp(-tb * 5.0) * minf(1.0, tb * 300.0) * 0.22
		"vaccine":
			# "Plip-plin": una gota y un brillito
			var n := int(rate * 0.7)
			buf.resize(n)
			var notes := [[0.0, 1568.0, 1318.5], [0.12, 2093.0, 2093.0]]
			for note: Array in notes:
				var start := int(rate * float(note[0]))
				for i in range(start, n):
					var t := float(i - start) / rate
					var f := lerpf(float(note[1]), float(note[2]), minf(1.0, t * 20.0))
					buf[i] += sin(TAU * f * t) * exp(-t * 9.0) * minf(1.0, t * 300.0) * 0.3
		"block":
			# "¡Tin!": algo que rebota contra el escudo
			var n := int(rate * 0.4)
			buf.resize(n)
			for i in n:
				var t := float(i) / rate
				var env := exp(-t * 12.0) * minf(1.0, t * 400.0)
				buf[i] = (sin(TAU * 2349.0 * t) + 0.6 * sin(TAU * 3520.0 * t) + 0.3 * sin(TAU * 5274.0 * t)) * env * 0.22
	return Synth.wav(buf, rate, 1.0)
