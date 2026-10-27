extends Node2D
class_name Tornado
## Tornado: se desbloquea en la tienda y después se saca desde el HUD o con la tecla T
## (Esc o click derecho lo guardan). Manteniendo apretado el click en la isla o en el agua
## baja un tornado que sigue al mouse mientras dure (MAX_TIME); al soltar se disuelve.
## Chupa a los aldeanos que agarra (vivos o cadáveres, y también a los que pasan volando por
## adentro del embudo): los hace girar alrededor, cada vez más arriba, y al rato los revolea
## por el aire (ver Villager.enter_tornado). En el agua levanta a los que flotan y saca
## volando a los tiburones (ver Shark.fling); en la isla revolea los cocos (Coconut.fling) y
## hace pedazos las chozas (Decoration.smash): los de adentro salen y se los chupa.
## El embudo se dibuja en el mundo (Funnel, ordenado por Y con los aldeanos: lo que está
## adelante lo tapa); la mira, en HUD.overlay.

signal armed_changed(on: bool)

## Mientras está afuera, los clicks hacen bajar el tornado en vez de agarrar aldeanos.
static var armed := false
## Hay que comprarlo en la tienda antes de poder sacarlo.
static var unlocked := false
const PRICE := 200

enum State { IDLE, DOWN, FADING }

const MAX_TIME := 6.0            # Lo que puede quedarse en el piso cada vez
const COOLDOWN := 3.0            # Después de disolverse
const SPEED := 150.0             # Qué tan rápido sigue al mouse (px/s)
const CAPTURE_R := 44.0          # Radio (en el piso) en el que chupa...
const PULL_R := 130.0            # ...y hasta dónde arrastra a los que están en la isla
const PULL_SPEED := 75.0         # Qué tan fuerte los arrastra, pegado al embudo (px/s)
const TOP_H := 220.0             # Alto del embudo
const R_BOTTOM := 12.0           # Radio del embudo abajo...
const R_TOP := 58.0              # ...y arriba
const SPIN := 6.0                # Qué tan rápido giran los que levanta (rad/s; abajo más)
const RISE := 95.0               # Lo que suben por segundo (px)
const RIDE := Vector2(1.4, 2.6)  # Segundos dando vueltas antes de salir revoleados
const HOVER := Vector2(0.45, 0.9)   # Hasta qué parte del embudo suben
const FLING_OUT := Vector2(280.0, 520.0)   # Revoleo: de costado...
const FLING_UP := Vector2(260.0, 480.0)    # ...y para arriba (px/s)
const SHARK_FLING := Vector2(240.0, 880.0)
const COCONUT_FLING := Vector2(240.0, 620.0)
const HUT_FLING := 520.0         # Con qué fuerza salen volando los pedazos de una choza
const TOUCH_TIME := 0.35         # Lo que tarda el embudo en bajar hasta el piso
const FADE_TIME := 0.7           # Y en disolverse
const LIFT := 30.0               # Como un aldeano: el origen del embudo, arriba del piso (orden por Y)
const SQUASH := 0.35             # Los anillos del embudo, vistos un poco desde arriba
const AIM_SQUASH := 0.42         # La mira es un círculo acostado sobre el piso
const BANDS := 9                 # Anillos que suben por el embudo
const DEBRIS := 28               # Cosas que giran alrededor
const RIPPLE_EVERY := 0.3        # En el agua deja anillos

const C_BODY := Color(0.55, 0.51, 0.47, 0.8)
const C_BODY_WET := Color(0.66, 0.74, 0.82, 0.72)
const C_LIT := Color(0.78, 0.74, 0.68, 0.45)       # El costado que le da la luz
const C_CORE := Color(0.38, 0.35, 0.32, 0.45)      # Más oscuro en el medio
const C_BAND := Color(0.3, 0.28, 0.26, 0.7)
const C_BAND_WET := Color(0.45, 0.55, 0.66, 0.7)
const C_CLOUD := Color(0.36, 0.37, 0.42, 0.97)
const C_CLOUD_DARK := Color(0.24, 0.25, 0.29, 0.97)
const C_CLOUD_LIGHT := Color(0.5, 0.51, 0.56, 0.97)
const C_DUST := Color(0.86, 0.74, 0.52, 0.5)
const C_SPRAY := Color(0.9, 0.96, 1.0, 0.6)
const C_DEBRIS := Color(0.3, 0.23, 0.16)
const C_AIM := Color(0.85, 0.9, 1.0)
const C_BAD := Color(0.72, 0.74, 0.8)
const C_OUTLINE := Color(0.06, 0.06, 0.1)

var _state := State.IDLE
var _base := Vector2.ZERO        # Donde toca el piso (o el agua)
var _goal := Vector2.ZERO
var _top := Vector2.ZERO         # Arriba, en la nube: se queda atrás cuando se mueve (se inclina)
var _k := 0.0                    # 0..1: cuánto bajó el embudo (al disolverse vuelve a 0)
var _time_left := 0.0
var _cooldown := 0.0
var _wet := false                # Está sobre el agua
var _t := 0.0
var _riders := []                # Los que están girando: {v, ang, h, t, ride, spin, hover}
var _debris: Array[Vector4] = [] # u, ángulo, velocidad, tamaño
var _cloud_shape := PackedVector2Array()   # La nube de arriba (respecto a _top), armada una vez
var _cloud_light := PackedVector2Array()   # Su copete, más claro
var _ripple_t := 0.0
var _funnel: Funnel
var _fx: HUD.Painter
var _wind: AudioStreamPlayer

func _ready() -> void:
	armed = false
	unlocked = false
	_fx = HUD.Painter.new()
	_fx.paint = _paint
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.overlay.add_child(_fx)
	else:
		add_child(_fx)
	for i in DEBRIS:
		_debris.append(Vector4(randf(), randf() * TAU, randf_range(0.7, 1.3), randf_range(1.5, 3.2)))
	_cloud_shape = _cloud_outline(1.0, Vector2.ZERO)
	_cloud_light = _cloud_outline(0.55, Vector2(-4.0, -6.0))
	_wind = AudioStreamPlayer.new()
	_wind.volume_db = -60.0
	add_child(_wind)

func set_armed(on: bool) -> void:
	if on and not unlocked:
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.popup_text("Desbloqueá el tornado en la tienda", get_viewport_rect().size * Vector2(0.5, 0.42), HUD.C_WARN)
		return
	if on == armed:
		return
	armed = on
	if not on and _state == State.DOWN:
		_lift_off()
	armed_changed.emit(on)   # Antes del cursor: al sacarlo se guardan las otras armas, que lo dejan en la flecha
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			set_armed(not armed)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and armed:
			set_armed(false)
			get_viewport().set_input_as_handled()
		return

	if not armed or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_touch_down(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Al soltar el click (en cualquier parte de la pantalla) se disuelve
	if _state == State.DOWN and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_lift_off()

func _process(dt: float) -> void:
	_t += dt
	match _state:
		State.IDLE:
			_cooldown -= dt
		State.DOWN:
			_k = move_toward(_k, 1.0, dt / TOUCH_TIME)
			_time_left -= dt
			var m := _target(get_global_mouse_position())
			if m.is_finite():
				_goal = m
			_base = _base.move_toward(_goal, SPEED * dt)
			_wet = not _on_island(_base)
			if _k >= 1.0:
				_suck()
				_pull(dt)
			if _wet:
				_ripple_t -= dt
				if _ripple_t <= 0.0:
					_ripple_t = RIPPLE_EVERY
					Sea.ripple_at(self, _base, 1.3)
			if _time_left <= 0.0:
				_lift_off()
		State.FADING:
			_k = move_toward(_k, 0.0, dt / FADE_TIME)
			if _k <= 0.0:
				_state = State.IDLE
				_cooldown = COOLDOWN
				_funnel.queue_free()
				_funnel = null
				_wind.stop()
	if _state != State.IDLE:
		# Arriba se queda atrás y se mece: el embudo se inclina y serpentea
		var top_goal := _base + Vector2(sin(_t * 0.9) * 18.0, -TOP_H)
		_top = _top.lerp(top_goal, 1.0 - exp(-2.5 * dt))
		_funnel.global_position = _base - Vector2(0, LIFT)
		_funnel.dust.emitting = _state == State.DOWN and _k >= 1.0
		_funnel.dust.color_ramp = _funnel.spray_ramp if _wet else _funnel.dust_ramp
		_wind.volume_db = linear_to_db(maxf(_k, 0.001)) - 6.0
	_update_riders(dt)

# ---- El tornado ----
## Dónde toca el tornado con el mouse en p: en la isla ahí mismo y en el agua en la
## superficie. INF si p no está ni en la isla ni en el agua.
func _target(p: Vector2) -> Vector2:
	if _on_island(p):
		return p
	var water := _water_rect()
	if water.has_point(p):
		return Vector2(p.x, water.position.y + 2.0)
	return Vector2.INF

func _touch_down(p: Vector2) -> void:
	if _state != State.IDLE or _cooldown > 0.0:
		return
	var to := _target(p)
	if not to.is_finite():
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.popup_text("Apuntá a la isla o al agua", get_canvas_transform() * p, HUD.C_WARN)
		return
	_state = State.DOWN
	_base = to
	_goal = to
	_top = to + Vector2(0, -TOP_H)
	_k = 0.0
	_time_left = MAX_TIME
	_wet = not _on_island(to)
	_funnel = Funnel.new()
	_funnel.tornado = self
	var props: Variant = get_parent().get("props")
	(props as Node if props is Node else get_parent()).add_child(_funnel)
	_funnel.global_position = _base - Vector2(0, LIFT)
	if _wind.stream == null:
		_wind.stream = _make_wind()
	_wind.play()

## Se disuelve: revolea a todos los que tenía.
func _lift_off() -> void:
	_state = State.FADING
	for r in _riders.duplicate():
		_fling(r)

## Los que agarra (aldeanos, tiburones, cocos, chozas).
func _suck() -> void:
	if not _wet:
		for node in get_tree().get_nodes_in_group("hut"):
			var h := node as Decoration
			if _on_ground(h.footprint_point(_base), CAPTURE_R):
				h.smash(_base + Vector2(0, 30), HUT_FLING)   # Desde abajo: los pedazos salen para arriba
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.tornado == null and v.can_be_lifted() and _grabs(v):
			_capture(v)
	if _wet:
		for node in get_tree().get_nodes_in_group("shark"):
			var shark := node as Shark
			if shark.swims_near(_base.x, CAPTURE_R * 0.8):
				var side := 1.0 if randf() < 0.5 else -1.0
				shark.fling(Vector2(side * randf_range(SHARK_FLING.x * 0.5, SHARK_FLING.x), -SHARK_FLING.y * randf_range(0.85, 1.0)))
	for node in get_tree().get_nodes_in_group("coconut"):
		var c := node as Coconut
		if c and c.state == Coconut.State.GROUND and _on_ground(c.point(), CAPTURE_R):
			var side := signf(c.point().x - _base.x) if absf(c.point().x - _base.x) > 1.0 else 1.0
			c.fling(Vector2(side * randf_range(COCONUT_FLING.x * 0.5, COCONUT_FLING.x), -COCONUT_FLING.y * randf_range(0.8, 1.0)))

## A los que están cerca en la isla (parados o tirados) los va arrastrando hacia el embudo,
## y los vivos lo miran venir con la boca abierta. No los saca de la isla.
func _pull(dt: float) -> void:
	var poly: Variant = get_parent().get("island_poly_global")
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or v.tornado or not v.can_be_lifted() or not (v.is_idle() or (v.dead and v.corpse_grounded)):
			continue
		var d := (v.ground_point() - _base) * Vector2(1.0, 1.0 / AIM_SQUASH)
		if d.length() > PULL_R:
			continue
		var k := 1.0 - d.length() / PULL_R
		var step := -d.normalized() * Vector2(1.0, AIM_SQUASH) * PULL_SPEED * k * dt
		var to := v.global_position + step
		if poly is PackedVector2Array and Geometry2D.is_point_in_polygon(to, poly):
			v.global_position = to
			if v.dead:
				v.floor_y += step.y
		if not v.dead:
			v.scare(0.25, _base)

## Si el punto del piso p está a menos de r del tornado (en el piso, no en la pantalla).
func _on_ground(p: Vector2, r: float) -> bool:
	return ((p - _base) * Vector2(1.0, 1.0 / AIM_SQUASH)).length() <= r

## Lo agarra si lo tiene a los pies, o si pasa volando por adentro del embudo.
func _grabs(v: Villager) -> bool:
	if v.falling:
		var h := _base.y - v.global_position.y
		if h < 0.0 or h > TOP_H:
			return false
		var c := _axis(h / TOP_H)
		return absf(v.global_position.x - c.x) <= _radius(h / TOP_H) + 8.0
	return _on_ground(v.ground_point(), CAPTURE_R)

func _capture(v: Villager) -> void:
	var g := (v.ground_point() - _base) * Vector2(1.0, 1.0 / AIM_SQUASH)
	var side := 1.0 if randf() < 0.5 else -1.0
	_riders.append({"v": v, "ang": g.angle() if g.length() > 1.0 else randf() * TAU,
			"h": clampf(_base.y - v.ground_point().y, 0.0, TOP_H), "t": 0.0,
			"ride": randf_range(RIDE.x, RIDE.y), "spin": randf_range(5.0, 9.0) * side,
			"hover": randf_range(HOVER.x, HOVER.y)})
	v.enter_tornado(self)

## Los hace girar alrededor del embudo, subiendo, y al rato los revolea.
func _update_riders(dt: float) -> void:
	for r in _riders.duplicate():
		var v: Variant = r.v
		if not is_instance_valid(v) or v.tornado != self:
			_riders.erase(r)
			continue
		r.t += dt
		var u := clampf(r.h / TOP_H, 0.0, 1.0)
		r.ang += SPIN * (1.4 - 0.6 * u) * dt
		var target_h: float = TOP_H * r.hover + sin(r.t * 2.0) * 8.0
		r.h = move_toward(r.h, target_h, RISE * dt)
		u = clampf(r.h / TOP_H, 0.0, 1.0)
		var rad := _radius(u) * 1.15 + 6.0
		var p := _axis(u) + Vector2(cos(r.ang) * rad, sin(r.ang) * rad * SQUASH)
		v.global_position = p - Vector2(0, 8)
		v.rotation += r.spin * dt
		v.z_index = 1 if sin(r.ang) > 0.0 else 0   # Adelante del embudo o detrás
		if r.t >= r.ride and _state == State.DOWN:
			_fling(r)

## Lo suelta revoleado para afuera, para el lado en que estaba girando.
func _fling(r: Dictionary) -> void:
	_riders.erase(r)
	var v: Variant = r.v
	if not is_instance_valid(v) or v.tornado != self:
		return
	var side := signf(cos(r.ang)) if absf(cos(r.ang)) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	v.exit_tornado(Vector2(side * randf_range(FLING_OUT.x, FLING_OUT.y), -randf_range(FLING_UP.x, FLING_UP.y)))

## Punto del eje del embudo a la altura u (0 el piso, 1 arriba de todo), en el mundo.
func _axis(u: float) -> Vector2:
	var mid := (_base + _top) * 0.5 + Vector2(sin(_t * 1.3) * 10.0, 0.0)   # El medio serpentea
	return _base.lerp(mid, u).lerp(mid.lerp(_top, u), u)

## Radio del embudo a la altura u: finito abajo, ancho arriba, y ondula.
func _radius(u: float) -> float:
	return lerpf(R_BOTTOM, R_TOP, pow(u, 1.7)) * (1.0 + 0.07 * sin(u * 13.0 - _t * 8.0))

func _water_rect() -> Rect2:
	var water := get_tree().get_first_node_in_group("water")
	if water and water.has_method("get_global_rect"):
		return water.get_global_rect()
	return Rect2()

func _on_island(p: Vector2) -> bool:
	var poly: Variant = get_parent().get("island_poly_global")
	return poly is PackedVector2Array and Geometry2D.is_point_in_polygon(p, poly)

# ---- Dibujo ----
## El embudo (lo llama Funnel, en coords del mundo).
func _paint_funnel(ci: CanvasItem) -> void:
	if _k <= 0.0:
		return
	var u0 := 1.0 - _k   # De acá para arriba se ve: al bajar, la punta va llegando al piso
	var alpha := 1.0 if _state == State.DOWN else _k
	var band := C_BAND_WET if _wet else C_BAND
	if u0 < 0.05:
		_paint_swirl(ci, alpha)
	# Atrás: la mitad de atrás de los anillos y lo que gira por detrás (todo junto en una
	# sola llamada por color: muchas llamadas chiquitas son caras)
	var back := _rings(u0, PI, TAU)
	if not back.is_empty():
		ci.draw_multiline(back, Color(band, band.a * 0.5 * alpha), 1.5, true)
	_paint_debris(ci, u0, alpha, false)
	# El cuerpo: más oscuro en el medio y con un costado iluminado
	if _k > 0.03:
		var body := C_BODY_WET if _wet else C_BODY
		ci.draw_colored_polygon(_outline(u0, -1.0, 1.0), Color(body, body.a * alpha))
		ci.draw_colored_polygon(_outline(u0, -0.92, -0.45), Color(C_LIT, C_LIT.a * alpha))
		ci.draw_colored_polygon(_outline(u0, -0.2, 0.55), Color(C_CORE, C_CORE.a * alpha))
	# Adelante: los anillos (que suben) y lo que gira por delante
	var front := _rings(u0, 0.0, PI)
	if not front.is_empty():
		ci.draw_multiline(front, Color(band, band.a * alpha), 2.0, true)
	_paint_debris(ci, u0, alpha, true)
	_paint_cloud(ci, alpha)

## Franja vertical del embudo desde u0 hasta arriba, entre a y b (en radios: -1 el borde
## izquierdo, 1 el derecho).
func _outline(u0: float, a: float, b: float) -> PackedVector2Array:
	const STEPS := 22
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for s in STEPS + 1:
		var u := lerpf(u0, 1.0, float(s) / STEPS)
		var c := _axis(u)
		var r := _radius(u)
		left.append(c + Vector2(r * a, 0))
		right.append(c + Vector2(r * b, 0))
	right.reverse()
	return left + right

## Media vuelta de los anillos que suben por el embudo (de 0 a PI es la mitad de adelante),
## como segmentos para draw_multiline.
func _rings(u0: float, a0: float, a1: float) -> PackedVector2Array:
	const STEPS := 10
	var segs := PackedVector2Array()
	for i in BANDS:
		var u := fposmod(float(i) / BANDS + _t * 0.35, 1.0)
		if u < u0:
			continue
		var c := _axis(u)
		var r := _radius(u)
		var prev := c + Vector2(cos(a0) * r, sin(a0) * r * SQUASH)
		for s in range(1, STEPS + 1):
			var a := lerpf(a0, a1, float(s) / STEPS)
			var p := c + Vector2(cos(a) * r, sin(a) * r * SQUASH)
			segs.append(prev)
			segs.append(p)
			prev = p
	return segs

## Piedritas y ramitas (o gotas, en el agua) que giran alrededor y suben: rayitas gruesas,
## todas en una sola llamada.
func _paint_debris(ci: CanvasItem, u0: float, alpha: float, front: bool) -> void:
	var col := C_SPRAY if _wet else C_DEBRIS
	var segs := PackedVector2Array()
	for d in _debris:
		var u := fposmod(d.x + _t * 0.22 * d.z, 1.0)
		if u < u0:
			continue
		var a := d.y + _t * SPIN * (1.4 - 0.6 * u) * d.z
		if (sin(a) > 0.0) != front:
			continue
		var r := _radius(u) * 1.12
		var p := _axis(u) + Vector2(cos(a) * r, sin(a) * r * SQUASH)
		var along := Vector2(-sin(a), cos(a) * SQUASH).normalized() * d.w   # Estiradas en la dirección en que giran
		segs.append(p - along)
		segs.append(p + along)
	if not segs.is_empty():
		ci.draw_multiline(segs, Color(col, col.a * alpha), 2.6)

## Remolino de polvo (o de agua) donde toca, con su sombra.
func _paint_swirl(ci: CanvasItem, alpha: float) -> void:
	var c := _base
	ci.draw_colored_polygon(Meteor.ellipse(c, Vector2(CAPTURE_R * 0.8, CAPTURE_R * 0.8 * AIM_SQUASH), 20), Color(0, 0, 0, 0.12 * alpha))
	var col := C_SPRAY if _wet else C_DUST
	for i in 10:
		var a := TAU * i / 10.0 + _t * 7.0
		var rr := (18.0 + 10.0 * sin(i * 1.7 + _t * 3.0))
		var p := c + Vector2(cos(a) * rr, sin(a) * rr * AIM_SQUASH - 4.0)
		ci.draw_circle(p, 7.0 + 3.0 * sin(i * 2.3 + _t * 5.0), Color(col, col.a * alpha))

## La nube de tormenta de arriba, de donde cuelga el embudo: chata, con la panza oscura, el
## copete más claro y un remolino que gira por abajo.
func _paint_cloud(ci: CanvasItem, alpha: float) -> void:
	var a := minf(1.0, alpha * 1.5)
	var w := R_TOP * 1.7
	ci.draw_colored_polygon(Meteor.ellipse(_top + Vector2(0, 4), Vector2(w, R_TOP * 0.42), 28), Color(C_CLOUD_DARK, C_CLOUD_DARK.a * a))
	ci.draw_colored_polygon(Transform2D(0.0, _top) * _cloud_shape, Color(C_CLOUD, C_CLOUD.a * a))
	ci.draw_colored_polygon(Transform2D(0.0, _top) * _cloud_light, Color(C_CLOUD_LIGHT, C_CLOUD_LIGHT.a * a))
	var swirl := PackedVector2Array()   # Remolino en la panza (la mitad de adelante)
	for i in 6:
		var a0 := TAU * i / 6.0 + _t * 2.2
		if sin(a0) <= 0.0:
			continue
		for s in 5:
			swirl.append(_top + Vector2(cos(a0 + s * 0.12) * w * 0.7, 6.0 + sin(a0 + s * 0.12) * R_TOP * 0.3))
			swirl.append(_top + Vector2(cos(a0 + (s + 1) * 0.12) * w * 0.7, 6.0 + sin(a0 + (s + 1) * 0.12) * R_TOP * 0.3))
	if not swirl.is_empty():
		ci.draw_multiline(swirl, Color(C_CLOUD_LIGHT, 0.6 * a), 2.0, true)

## El copete de la nube (respecto a su centro): una fila de bollos a lo ancho, los del medio
## más altos. Como polígono (el borde de arriba son los arcos de los bollos), que se arma una
## sola vez: dibujar los bollos uno por uno cada cuadro es caro. k: tamaño de los bollos.
func _cloud_outline(k: float, off: Vector2) -> PackedVector2Array:
	var w := R_TOP * 1.7
	var puffs: Array[Vector3] = []   # x, y, radio
	for i in 7:
		var u := (i - 3.0) / 3.0
		puffs.append(Vector3(u * w * 0.78, -10.0 - 14.0 * (1.0 - u * u), (18.0 + 10.0 * (1.0 - u * u)) * k))
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var x := -w
	while x <= w:
		var y := 0.0
		for p in puffs:
			var dx := x - p.x
			if absf(dx) < p.z:
				y = minf(y, p.y - sqrt(p.z * p.z - dx * dx))
		top.append(Vector2(x, y) + off)
		bottom.append(Vector2(x, 2.0) + off)
		x += 3.0
	bottom.reverse()
	return top + bottom

## En HUD.overlay: la mira (y cuánto le queda al tornado mientras está abajo).
func _paint(ci: CanvasItem) -> void:
	if not armed:
		return
	ci.draw_set_transform_matrix(get_canvas_transform())
	var m := get_global_mouse_position()
	if _state == State.DOWN:
		# Lo que le queda en el piso: un arquito alrededor del mouse que se vacía
		var k := clampf(_time_left / MAX_TIME, 0.0, 1.0)
		ci.draw_arc(m, 13.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, C_OUTLINE, 4.0, true)
		ci.draw_arc(m, 13.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, C_AIM, 2.0, true)
		return
	var to := _target(m)
	var ok := to.is_finite()
	var c := to if ok else m
	var ready := _cooldown <= 0.0 and _state == State.IDLE
	var col := Color(C_AIM if ok else C_BAD, 0.95 if ready else 0.45)
	for pass_i in 2:
		var ink := C_OUTLINE if pass_i == 0 else col
		var w := 3.5 if pass_i == 0 else 1.6
		for i in 3:   # Remolino: tres brazos que giran, acostados sobre el piso
			var arm := PackedVector2Array()
			for s in 10:
				var k := s / 9.0
				var a := TAU * i / 3.0 + k * 2.4 + _t * 3.0
				var rr := CAPTURE_R * (0.25 + 0.75 * k)
				arm.append(c + Vector2(cos(a), sin(a) * AIM_SQUASH) * rr)
			ci.draw_polyline(arm, ink, w, true)
		if not ok:   # Ahí no puede bajar: una X
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				ci.draw_line(c + d.normalized() * 3.0, c + d.normalized() * 9.0, ink, w, true)
	if _cooldown > 0.0 and _state == State.IDLE:
		# Recargando: un arquito que se completa
		ci.draw_arc(c, 14.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - _cooldown / COOLDOWN), 24, C_AIM, 2.0, true)

## El embudo en el mundo, en Props: se ordena por Y con los aldeanos y las decoraciones.
## Lo dibuja el tornado (ver _paint_funnel); acá van también el polvo que levanta.
class Funnel extends Node2D:
	var tornado: Tornado
	var dust: CPUParticles2D
	var dust_ramp := Villager._fade_ramp(C_DUST, Color(C_DUST, 0.0))
	var spray_ramp := Villager._fade_ramp(C_SPRAY, Color(C_SPRAY, 0.0))

	func _ready() -> void:
		dust = CPUParticles2D.new()
		dust.amount = 26
		dust.lifetime = 0.9
		dust.local_coords = false
		dust.position = Vector2(0, LIFT)
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.emission_rect_extents = Vector2(16, 4)
		dust.direction = Vector2.UP
		dust.spread = 75.0
		dust.initial_velocity_min = 60.0
		dust.initial_velocity_max = 160.0
		dust.gravity = Vector2(0, 220)
		dust.scale_amount_min = 2.0
		dust.scale_amount_max = 4.5
		dust.color_ramp = dust_ramp
		add_child(dust)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(-global_position)   # Lo dibuja en coords del mundo
		tornado._paint_funnel(self)

# ---- Sonido ----
## Viento que ruge: ruido filtrado con un silbido que sube y baja, y un retumbe grave.
## Se repite sin cortes (el final se funde con el principio).
static func _make_wind() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 3
	var fade := rate / 4
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	var lp1 := 0.0
	var lp2 := 0.0
	var brown := 0.0
	var peak := 0.0
	for i in n + fade:
		var t := float(i) / rate
		var noise := randf_range(-1.0, 1.0)
		# Ciclos enteros en los 3 s del loop: 2/3 Hz y 5/3 Hz
		var cut := 0.07 + 0.035 * sin(TAU * t * 2.0 / 3.0) + 0.02 * sin(TAU * t * 5.0 / 3.0)
		lp1 = lerpf(lp1, noise, cut)
		lp2 = lerpf(lp2, lp1, cut)
		brown = clampf(brown * 0.996 + noise * 0.05, -1.0, 1.0)
		buf[i] = lp2 * 2.4 + brown * 0.7
	for i in fade:
		buf[i] = lerpf(buf[n + i], buf[i], float(i) / fade)
	buf.resize(n)
	for s in buf:
		peak = maxf(peak, absf(s))
	var w := Synth.wav(buf, rate, 0.8 / maxf(peak, 0.001))
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
