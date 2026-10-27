extends Node2D
class_name Charm
## Poderes para las relaciones (ver Relations.make): se desbloquean en la tienda y se sacan
## desde el HUD o con su tecla (Esc o click derecho los guardan). Como la pistola, cada click
## dispara desde la esquina de abajo a la derecha hacia el mouse, pero lo que sale es un
## proyectil que vuela en arco; si apuntaste a un aldeano, lo sigue hasta darle.
## - Arco de Cupido [A] (bueno): la flecha (con un corazón de punta) deja flechado al que le
##   da, con un aro rosa a los pies; la siguiente que le da a otro los enamora, aunque no se
##   gustaran. Si alguno tenía pareja la deja, y el ex queda enemigo del nuevo, de celos.
## - Manzana de la Discordia [E] (malo): una manzana dorada que cae en la isla, y todos los
##   que estaban cerca se pelean por ella: quedan enemigos entre todos (las parejas se separan)
##   y se empujan.
## - Pelota de la Amistad [B] (bueno): rebota de aldeano en aldeano, siempre al más cercano
##   que todavía no tocó (hasta MAX_TOUCH), y los que tocó quedan amigos entre todos (los
##   enemigos hacen las paces; las parejas siguen siendo pareja).
## World crea uno de cada tipo (kind).

signal armed_changed(on: bool)

enum Kind { CUPID, DISCORD, FRIENDSHIP }
## Por tipo: su tecla, su precio, su color (el de la relación que arma) y lo que dicen el HUD
## (ver HUD.TOOLS) y la tienda.
const KINDS := {
	Kind.CUPID: {
		"key": KEY_A,
		"price": 70,
		"color": Color(1.0, 0.52, 0.74),
		"tip": "Sacar o guardar el arco de Cupido [A]",
		"locked_tip": "Desbloquealo en la tienda (%d ofrendas)",
		"need": "Desbloqueá el arco de Cupido en la tienda",
		"unlocked": "¡Arco de Cupido desbloqueado! Sacalo con A",
		"done": "Desbloqueado",
		"shop": "Flechá a un aldeano y después a otro: se enamoran. Si tenían pareja la dejan, y el ex queda celoso.",
		"hint": "Flechá a un aldeano y después a otro para que se enamoren · click derecho, Esc o A para guardarlo.",
	},
	Kind.DISCORD: {
		"key": KEY_E,
		"price": 60,
		"color": Color(1.0, 0.45, 0.4),
		"tip": "Sacar o guardar la manzana de la discordia [E]",
		"locked_tip": "Desbloqueala en la tienda (%d ofrendas)",
		"need": "Desbloqueá la manzana de la discordia en la tienda",
		"unlocked": "¡Manzana de la discordia desbloqueada! Sacala con E",
		"done": "Desbloqueada",
		"shop": "Una manzana dorada: los que estén cerca de donde cae se pelean por ella y quedan enemigos.",
		"hint": "Tirá la manzana cerca de varios aldeanos: se pelean por ella · click derecho, Esc o E para guardarla.",
	},
	Kind.FRIENDSHIP: {
		"key": KEY_B,
		"price": 50,
		"color": Color(0.46, 0.84, 0.52),
		"tip": "Sacar o guardar la pelota de la amistad [B]",
		"locked_tip": "Desbloqueala en la tienda (%d ofrendas)",
		"need": "Desbloqueá la pelota de la amistad en la tienda",
		"unlocked": "¡Pelota de la amistad desbloqueada! Sacala con B",
		"done": "Desbloqueada",
		"shop": "Rebota de aldeano en aldeano y todos los que toca se hacen amigos (los enemigos hacen las paces).",
		"hint": "Tirale la pelota a un aldeano: rebota entre los que están cerca y se hacen amigos · click derecho, Esc o B para guardarla.",
	},
}

## Si están comprados, por tipo (se guardan con la partida, ver HUD.save_state).
static var unlocked: Array[bool] = [false, false, false]
static var _armed: Array[bool] = [false, false, false]

const ANCHOR_FROM_CORNER := Vector2(120, 70)   # Donde se dibuja el arco (o la manzana, o la pelota)
const DRAW_SCALE := 1.6
const COOLDOWN := { Kind.CUPID: 0.45, Kind.DISCORD: 1.2, Kind.FRIENDSHIP: 0.9 }
const SPEED := { Kind.CUPID: 1300.0, Kind.DISCORD: 700.0, Kind.FRIENDSHIP: 850.0 }   # px/s en línea recta
const ARC := { Kind.CUPID: 0.05, Kind.DISCORD: 0.35, Kind.FRIENDSHIP: 0.25 }        # Lo que sube (veces la distancia)
const FLIGHT := Vector2(0.2, 1.0)              # Segundos de vuelo, como mucho y como poco
const SQUASH := 0.42                           # Los círculos en el piso, achatados (como Curar)
# Cupido
const PIERCE_TIME := 15.0        # Flechado, esperando la segunda flecha
const STUCK_TIME := 1.6          # Lo que quedan las flechas clavadas
const LOVE_TIME := 3.0           # El corazón de los dos al enamorarse
# Discordia
const DISCORD_RADIUS := 110.0
const FIGHT_CHANCE := 0.6        # Cada dos que se pelean, que uno empuje al otro
const APPLE_TIME := 3.0          # Lo que queda la manzana tirada
# Amistad
const BOUNCE_RANGE := 170.0      # Hasta dónde busca al próximo
const MAX_TOUCH := 5
const HOP_TIME := 0.38
const HOP_ARC := 45.0
const BALL_TIME := 1.5           # Lo que queda la pelota tirada

const C_OUTLINE := Color(0.06, 0.06, 0.1)
const C_WOOD := Color(0.62, 0.42, 0.22)
const C_GOLD := Color(1.0, 0.8, 0.25)
const C_PINK := Color(1.0, 0.52, 0.74)
const C_HEART := Color(0.93, 0.25, 0.42)
const BALL_COLORS := [Color(0.95, 0.3, 0.3), Color.WHITE, Color(0.3, 0.55, 1.0), Color.WHITE, Color(1.0, 0.85, 0.25), Color.WHITE]

var kind := Kind.CUPID
var _cooldown := 0.0
var _t := 0.0
var _pull := 1.0                 # Cupido: la cuerda tensa (1) o recién disparada (0)
var _shots: Array[Shot] = []
## Lo que quedó tirado o clavado, y los corazoncitos que suben: {what, pos, t, time, ...}.
var _left: Array[Dictionary] = []
var _pierced: Villager           # Cupido: el flechado, esperando la segunda flecha
var _pierce_t := 0.0
static var _sounds := {}         # nombre -> AudioStreamWAV

## Un proyectil volando: de from a to en time segundos, subiendo arc en el medio. Si apuntaste
## a un aldeano lo sigue (to se mueve con él).
class Shot:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var target: Villager
	var pos := Vector2.ZERO
	var prev := Vector2.ZERO
	var t := 0.0
	var time := 0.5
	var arc := 0.0
	var spin := 0.0
	var touched: Array[Villager] = []   # La pelota: los que ya tocó
	var dropping := false               # La pelota: ya no hay a quién más, cae al piso

func _ready() -> void:
	_armed[kind] = false
	unlocked[kind] = false
	z_index = 50

## Si hay alguno afuera (ver HUD.aiming).
static func any_armed() -> bool:
	return _armed.has(true)

func set_armed(on: bool) -> void:
	if on and not unlocked[kind]:
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.popup_text(KINDS[kind].need, get_viewport_rect().size * Vector2(0.5, 0.42), HUD.C_WARN)
		return
	if on == _armed[kind]:
		return
	_armed[kind] = on
	armed_changed.emit(on)   # Antes del cursor: al sacarlo se guarda el rayo, que lo deja en la flecha
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
		_throw(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	_pull = move_toward(_pull, 1.0 if _cooldown <= 0.0 else 0.0, 5.0 * dt)
	if _armed[kind]:
		global_position = get_canvas_transform().affine_inverse() * (get_viewport_rect().size - ANCHOR_FROM_CORNER)
	for i in range(_shots.size() - 1, -1, -1):
		if _fly(_shots[i], dt):
			_shots.remove_at(i)
	for i in range(_left.size() - 1, -1, -1):
		_left[i].t += dt
		if _left[i].t >= _left[i].time:
			_left.remove_at(i)
	if _pierced != null:
		_pierce_t -= dt
		if not _alive(_pierced):
			_pierced = null
		elif _pierce_t <= 0.0:
			_popup("Se le pasó el flechazo", _pierced.global_position, HUD.C_MUTED)
			_pierced = null
	queue_redraw()   # Siempre: así al guardarlo (o cuando termina lo último) no queda dibujado

# ---- Disparo ----
func _throw(at: Vector2) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN[kind]
	_pull = 0.0
	var s := Shot.new()
	s.target = _villager_at(at)
	s.from = global_position + Vector2.from_angle(_aim_angle()) * 18.0
	s.to = _aim_point(s.target) if s.target else at
	s.pos = s.from
	s.prev = s.from
	var d := s.from.distance_to(s.to)
	s.time = clampf(d / SPEED[kind], FLIGHT.x, FLIGHT.y)
	s.arc = d * ARC[kind]
	_shots.append(s)
	_play("twang" if kind == Kind.CUPID else "whoosh")

## Adónde va a parar si apuntaste a v: la flecha y la pelota al cuerpo, la manzana a los pies.
func _aim_point(v: Villager) -> Vector2:
	return v.ground_point() if kind == Kind.DISCORD else v.body_center()

## Lo mueve por su arco. true cuando terminó (cayó o le dio a alguien y ya no sigue).
func _fly(s: Shot, dt: float) -> bool:
	s.t += dt
	s.spin += dt * (4.0 if kind == Kind.DISCORD else 9.0)
	if _alive(s.target):
		s.to = _aim_point(s.target)
	var u := minf(1.0, s.t / s.time)
	s.prev = s.pos
	s.pos = s.from.lerp(s.to, u) + Vector2(0.0, -s.arc * 4.0 * u * (1.0 - u))
	if u < 1.0:
		return false
	match kind:
		Kind.CUPID:
			_land_arrow(s)
		Kind.DISCORD:
			_land_apple(s)
		Kind.FRIENDSHIP:
			return _land_ball(s)
	return true

# ---- Cupido ----
func _land_arrow(s: Shot) -> void:
	var angle := (s.pos - s.prev).angle()
	if _alive(s.target):
		var v := s.target
		# Clavada en el cuerpo: lo sigue mientras se mueve
		_left.append({"what": "arrow", "villager": v, "offset": v.to_local(s.pos), "angle": angle - v.global_rotation,
				"t": 0.0, "time": STUCK_TIME})
		_float_hearts(s.pos, 4)
		_pierce(v)
	elif _on_island(s.pos):
		_left.append({"what": "arrow", "pos": s.pos, "angle": angle, "t": 0.0, "time": STUCK_TIME})   # En la arena
	else:
		_puff(s.pos, Color(0.85, 0.95, 1.0), 12)   # Al agua

## La primera flecha deja flechado a v; la siguiente que le da a otro los enamora.
func _pierce(v: Villager) -> void:
	if _alive(_pierced) and _pierced != v:
		var a := _pierced
		_pierced = null
		_match(a, v)
		return
	_pierced = v
	_pierce_t = PIERCE_TIME
	v.say(Villager.Bubble.HEART, 1.5, false)
	_play("plink")
	_popup("¡Flechado! Ahora flechá a otro", v.global_position, C_PINK)

## a y b se enamoran. Si alguno tenía pareja la deja, y el ex queda enemigo del nuevo, de celos.
func _match(a: Villager, b: Villager) -> void:
	for v: Villager in [a, b]:
		var rival := b if v == a else a
		for o in _villagers():
			if o != a and o != b and Relations.kind(v, o) == Relations.Kind.COUPLE:
				Relations.make(v, o, Relations.Kind.NONE)
				Relations.make(o, rival, Relations.Kind.ENEMY)
				o.say(Villager.Bubble.ANGER, LOVE_TIME, false)
				_popup("¡Celos!", o.global_position, Relations.color(Relations.Kind.ENEMY))
	var ev := Relations.make(a, b, Relations.Kind.COUPLE)
	for v: Villager in [a, b]:
		v.say(Villager.Bubble.HEART, LOVE_TIME, false)
		_float_hearts(v.body_center(), 8)
	_play("bells")
	var news := Relations.news(ev) if ev != Relations.Event.NONE else ["¡Más enamorados!", C_PINK]
	_popup(news[0], (a.global_position + b.global_position) * 0.5, news[1])

# ---- Discordia ----
## Cae la manzana: los que estaban cerca se pelean por ella.
func _land_apple(s: Shot) -> void:
	var p := s.pos
	if not _on_island(p):
		_puff(p, Color(0.85, 0.95, 1.0), 16)
		return
	_left.append({"what": "apple", "pos": p, "angle": s.spin, "t": 0.0, "time": APPLE_TIME})
	_play("thud")
	var near: Array[Villager] = []
	for v in _villagers():
		var d := v.ground_point() - p
		d.y /= SQUASH
		if v.is_idle() and d.length() < DISCORD_RADIUS:
			near.append(v)
	if near.size() < 2:
		if near.size() == 1:
			_popup("No tiene con quién pelearse", near[0].global_position, HUD.C_MUTED)
		return
	var any := false
	for i in near.size():
		for j in range(i + 1, near.size()):
			if Relations.make(near[i], near[j], Relations.Kind.ENEMY) == Relations.Event.ENEMIES:
				any = true
	for v in near:
		v.say(Villager.Bubble.ANGER, 2.0, false)
		if v.rig:
			v.rig.set_facing_left(p.x < v.global_position.x)
	# Se empujan de a dos
	near.shuffle()
	for i in range(0, near.size() - 1, 2):
		if randf() < FIGHT_CHANCE:
			near[i + 1]._get_pushed_by(near[i])
	var news := Relations.news(Relations.Event.ENEMIES) if any else ["¡Discordia!", Relations.color(Relations.Kind.ENEMY)]
	_popup(news[0], p, news[1])

# ---- Amistad ----
## La pelota le dio a alguien (o llegó al piso). Si le dio, rebota al más cercano que todavía
## no tocó; cuando no hay más, los que tocó se hacen amigos y la pelota cae al lado. true si
## terminó.
func _land_ball(s: Shot) -> bool:
	if not s.dropping and _alive(s.target) and not s.touched.has(s.target):
		var v := s.target
		s.touched.append(v)
		v.say(Villager.Bubble.LAUGH, 1.4, false)
		if v.rig:
			v.rig.hit(s.pos, (s.pos - s.prev).normalized(), 0.4)
		_play("boing")
		var next := _next_friend(s)
		if next and s.touched.size() < MAX_TOUCH:
			_hop(s, next.body_center(), next)
			return false
		_befriend(s.touched)
		# Rebota al piso, para el lado que venía
		var side := signf(s.pos.x - s.from.x) if s.pos.x != s.from.x else 1.0
		s.dropping = true
		_hop(s, v.ground_point() + Vector2(side * randf_range(25.0, 45.0), 3.0), null)
		return false
	if _on_island(s.pos):
		_left.append({"what": "ball", "pos": s.pos, "angle": s.spin, "t": 0.0, "time": BALL_TIME})
	else:
		_puff(s.pos, Color(0.85, 0.95, 1.0), 12)
	return true

## El más cercano (vivo y en la isla) que la pelota todavía no tocó, o null.
func _next_friend(s: Shot) -> Villager:
	var from := s.target.body_center()
	var best: Villager = null
	var best_d := BOUNCE_RANGE
	for v in _villagers():
		var d := v.body_center().distance_to(from)
		if v.is_idle() and not s.touched.has(v) and d < best_d:
			best = v
			best_d = d
	return best

func _hop(s: Shot, to: Vector2, target: Villager) -> void:
	s.from = s.pos
	s.to = to
	s.target = target
	s.t = 0.0
	s.time = HOP_TIME
	s.arc = HOP_ARC

## Los que tocó la pelota quedan amigos entre todos (las parejas siguen siendo pareja).
func _befriend(group: Array[Villager]) -> void:
	var friends := group.filter(func(v): return _alive(v))
	if friends.size() < 2:
		if friends.size() == 1:
			_popup("No tiene con quién jugar", friends[0].global_position, HUD.C_MUTED)
		return
	var any := false
	var mid := Vector2.ZERO
	for i in friends.size():
		mid += friends[i].global_position
		for j in range(i + 1, friends.size()):
			if Relations.kind(friends[i], friends[j]) != Relations.Kind.COUPLE \
					and Relations.make(friends[i], friends[j], Relations.Kind.FRIEND) == Relations.Event.FRIENDS:
				any = true
	for v: Villager in friends:
		v.say(Villager.Bubble.SMILE, 2.0, false)
	var news := Relations.news(Relations.Event.FRIENDS) if any else ["¡Qué buena onda!", Relations.color(Relations.Kind.FRIEND)]
	_popup(news[0], mid / friends.size(), news[1])

# ---- Ayudas ----
## Vivo y en el juego (v puede ser uno que ya no está, por eso sin tipo).
static func _alive(v: Variant) -> bool:
	return is_instance_valid(v) and not v.dead and not v.eaten and not v.is_queued_for_deletion()

func _villagers() -> Array[Villager]:
	var out: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		if _alive(node):
			out.append(node)
	return out

## El aldeano vivo bajo el punto (el de más adelante), o null.
func _villager_at(at: Vector2) -> Villager:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collide_with_bodies = true
	var best: Villager = null
	for r in get_world_2d().direct_space_state.intersect_point(q, 16):
		var v := r.collider as Villager
		if v and _alive(v) and (best == null or Gun.drawn_in_front(v, best)):
			best = v
	return best

func _on_island(p: Vector2) -> bool:
	var poly: Variant = get_parent().get("island_poly_global")
	return poly is PackedVector2Array and Geometry2D.is_point_in_polygon(p, poly)

func _aim_angle() -> float:
	return (get_global_mouse_position() - global_position).angle()

## Cartel que sube desde arriba de la cabeza de alguien parado en at (coords del mundo).
func _popup(text: String, at: Vector2, color: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.popup_text(text, get_canvas_transform() * at + Vector2(0, -100), color)

## Corazoncitos que suben desde at y se desvanecen.
func _float_hearts(at: Vector2, n: int) -> void:
	for i in n:
		_left.append({"what": "heart", "pos": at + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 4.0)),
				"vel": Vector2(randf_range(-18.0, 18.0), randf_range(-50.0, -28.0)), "size": randf_range(3.5, 6.0),
				"t": 0.0, "time": randf_range(0.8, 1.3)})

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
func _draw() -> void:
	for l in _left:
		_draw_left(l)
	if _alive(_pierced):
		_draw_pierced()
	for s in _shots:
		var xf := Transform2D(0.0, to_local(s.pos))
		match kind:
			Kind.CUPID:
				paint_arrow(self, Transform2D((s.pos - s.prev).angle(), to_local(s.pos)), 1.0)
			Kind.DISCORD:
				paint_apple(self, xf.rotated_local(s.spin), 1.0)
			Kind.FRIENDSHIP:
				paint_ball(self, xf.rotated_local(s.spin), 1.0)
	if _armed[kind]:
		_draw_aim()
		_draw_launcher()

func _draw_left(l: Dictionary) -> void:
	var fade := 1.0 - smoothstep(0.7, 1.0, l.t / l.time)
	match l.what:
		"arrow":
			var pos: Vector2 = l.get("pos", Vector2.ZERO)
			var angle: float = l.angle
			if l.has("villager"):
				if not is_instance_valid(l.villager):
					return
				pos = l.villager.to_global(l.offset)
				angle += l.villager.global_rotation
			paint_arrow(self, Transform2D(angle, to_local(pos)), fade)
		"apple":
			var p := to_local(l.pos)
			draw_set_transform(p + Vector2(0, 7), 0.0, Vector2(1.0, SQUASH))
			draw_circle(Vector2.ZERO, 16.0 + sin(_t * 6.0) * 2.0, Color(C_GOLD, 0.3 * fade), true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
			paint_apple(self, Transform2D(l.angle * 0.2, p), fade)
		"ball":
			paint_ball(self, Transform2D(l.angle, to_local(l.pos) + Vector2(0, -6)), fade)
		"heart":
			var p := to_local(l.pos + l.vel * l.t)
			draw_colored_polygon(SpeechBubble._heart(p, l.size), Color(C_HEART, fade))

## El flechado: un aro rosa a los pies que late, y si el arco está afuera, una línea de
## puntos hasta el mouse (¿con quién?).
func _draw_pierced() -> void:
	var feet := to_local(_pierced.ground_point())
	var beat := 0.5 + 0.5 * sin(_t * 7.0)
	draw_set_transform(feet, 0.0, Vector2(1.0, SQUASH))
	draw_arc(Vector2.ZERO, 18.0 + beat * 3.0, 0.0, TAU, 32, Color(C_PINK, 0.5 + 0.4 * beat), 3.0, true)
	draw_set_transform(Vector2.ZERO)
	if _armed[kind]:
		draw_dashed_line(to_local(_pierced.body_center()), get_local_mouse_position(), Color(C_PINK, 0.7), 2.0, 6.0)

func _draw_aim() -> void:
	var m := get_local_mouse_position()
	var col: Color = KINDS[kind].color
	var ready := _cooldown <= 0.0
	if kind == Kind.DISCORD:
		# El círculo de los que se van a pelear
		for pass_i in 2:
			var ring := PackedVector2Array()
			for i in 41:
				var a := TAU * i / 40.0
				ring.append(m + Vector2(cos(a), sin(a) * SQUASH) * DISCORD_RADIUS)
			draw_polyline(ring, C_OUTLINE if pass_i == 0 else Color(col, 0.9 if ready else 0.4), 3.5 if pass_i == 0 else 1.6, true)
	for pass_i in 2:
		var c := C_OUTLINE if pass_i == 0 else (Color(col, 0.95) if ready else Color(col, 0.4))
		var w := 3.5 if pass_i == 0 else 1.6
		draw_arc(m, 9.0, 0.0, TAU, 24, c, w, true)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(m + d * 5.0, m + d * 13.0, c, w, true)
	if not ready:
		var k := 1.0 - _cooldown / float(COOLDOWN[kind])
		draw_arc(m, 16.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, col, 2.0, true)

## En la esquina: el arco tenso con la flecha puesta, o la manzana, o la pelota (cuando están
## listos para tirar).
func _draw_launcher() -> void:
	var base := Transform2D(_aim_angle(), Vector2.ONE * DRAW_SCALE, 0.0, Vector2.ZERO)
	var ready := _cooldown <= 0.0
	match kind:
		Kind.CUPID:
			# El arco mira al mouse; la cuerda se tensa hasta la flecha
			var c := Vector2(-14, 0)
			var top := c + Vector2.from_angle(-1.15) * 22.0
			var bottom := c + Vector2.from_angle(1.15) * 22.0
			var nock := Vector2(lerpf(top.x, -18.0, _pull), 0.0)
			draw_set_transform_matrix(base)
			draw_polyline(PackedVector2Array([top, nock, bottom]), Color(1, 1, 1, 0.9), 1.0, true)
			draw_arc(c, 22.0, -1.15, 1.15, 16, C_OUTLINE, 5.0, true)
			draw_arc(c, 22.0, -1.15, 1.15, 16, C_GOLD, 3.0, true)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			if ready:
				paint_arrow(self, base * Transform2D(0.0, Vector2(nock.x + 30.0, 0.0)), 1.0)
		Kind.DISCORD:
			if ready:
				paint_apple(self, Transform2D(sin(_t * 2.0) * 0.15, Vector2.ONE * DRAW_SCALE, 0.0, Vector2(0, sin(_t * 3.0) * 2.0)), 1.0)
		Kind.FRIENDSHIP:
			if ready:
				paint_ball(self, Transform2D(_t, Vector2.ONE * DRAW_SCALE, 0.0, Vector2(0, -absf(sin(_t * 4.0)) * 6.0)), 1.0)

## Flecha con un corazón de punta, en las coords de xf (la punta en el origen, apuntando a +x).
static func paint_arrow(ci: CanvasItem, xf: Transform2D, alpha: float) -> void:
	ci.draw_set_transform_matrix(xf)
	ci.draw_line(Vector2(-28, 0), Vector2(-6, 0), Color(C_OUTLINE, alpha), 3.5, true)
	ci.draw_line(Vector2(-28, 0), Vector2(-6, 0), Color(C_WOOD, alpha), 1.8, true)
	for side: float in [-1.0, 1.0]:   # Plumas
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-29, 0), Vector2(-22, 0), Vector2(-25, 5.0 * side),
				Vector2(-32, 5.0 * side)]), Color(C_PINK, alpha))
	# La punta: un corazón acostado, con la punta para adelante
	ci.draw_set_transform_matrix(xf * Transform2D(-PI * 0.5, Vector2(-5, 0)))
	ci.draw_colored_polygon(SpeechBubble._heart(Vector2.ZERO, 5.5), Color(C_HEART, alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

## Manzana dorada (con su cabito y una hojita), centrada en el origen de xf.
static func paint_apple(ci: CanvasItem, xf: Transform2D, alpha: float) -> void:
	ci.draw_set_transform_matrix(xf)
	ci.draw_circle(Vector2.ZERO, 8.2, Color(C_OUTLINE, alpha), true, -1.0, true)
	ci.draw_circle(Vector2.ZERO, 7.0, Color(C_GOLD, alpha), true, -1.0, true)
	ci.draw_circle(Vector2(1.5, 1.5), 4.5, Color(C_GOLD.darkened(0.12), alpha), true, -1.0, true)
	ci.draw_circle(Vector2(-2.5, -2.5), 2.0, Color(1, 1, 0.85, 0.85 * alpha), true, -1.0, true)
	ci.draw_line(Vector2(0, -6), Vector2(1.5, -10.5), Color(0.35, 0.22, 0.1, alpha), 1.8, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(1.5, -9.5), Vector2(5.5, -12.5), Vector2(8.5, -10),
			Vector2(4.5, -8)]), Color(0.4, 0.75, 0.3, alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

## Pelota de playa, de gajos de colores, centrada en el origen de xf.
static func paint_ball(ci: CanvasItem, xf: Transform2D, alpha: float) -> void:
	ci.draw_set_transform_matrix(xf)
	var r := 8.0
	ci.draw_circle(Vector2.ZERO, r + 1.2, Color(C_OUTLINE, alpha), true, -1.0, true)
	for i in 6:
		var pts := PackedVector2Array([Vector2.ZERO])
		for j in 5:
			pts.append(Vector2.from_angle(TAU * (i + j / 4.0) / 6.0) * r)
		ci.draw_colored_polygon(pts, Color(BALL_COLORS[i], alpha))
	ci.draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, alpha), true, -1.0, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

## El ícono de cada uno (para el HUD y la tienda), de s px de lado: un corazón flechado, la
## manzana y la pelota.
static func paint_icon(ci: CanvasItem, k: Kind, s: float) -> void:
	var c := Vector2(s, s) * 0.5
	match k:
		Kind.CUPID:
			ci.draw_colored_polygon(SpeechBubble._heart(c + Vector2(-0.04, 0.04) * s, s * 0.3), C_HEART)
			paint_arrow(ci, Transform2D(-PI * 0.25, Vector2.ONE * s / 34.0, 0.0, Vector2(0.86, 0.14) * s), 1.0)
		Kind.DISCORD:
			paint_apple(ci, Transform2D(0.0, Vector2.ONE * s / 24.0, 0.0, c + Vector2(0, 0.06) * s), 1.0)
		Kind.FRIENDSHIP:
			paint_ball(ci, Transform2D(0.3, Vector2.ONE * s / 20.0, 0.0, c), 1.0)

# ---- Sonido ----
func _play(sound: String) -> void:
	if not _sounds.has(sound):
		_sounds[sound] = _make_sound(sound)
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[sound]
	p.volume_db = -9.0
	p.pitch_scale = randf_range(0.94, 1.06)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

static func _make_sound(sound: String) -> AudioStreamWAV:
	match sound:
		"twang":   # La cuerda del arco
			return _tone(240.0, 170.0, 0.35, 10.0, 0.25)
		"plink":   # Flechado
			return _tone(1320.0, 1320.0, 0.45, 7.0, 0.0)
		"thud":    # La manzana contra la arena
			return _tone(120.0, 55.0, 0.3, 14.0, 0.35)
		"boing":   # La pelota rebotando
			return _tone(480.0, 220.0, 0.32, 6.0, 0.0)
		"bells":   # Enamorados: las campanitas de Curar
			return Cure._make_sound()
	return _whoosh()

## Un tono que va de f0 a f1 Hz y se apaga (decay: por segundo), con un golpe de ruido al
## principio (noise: cuánto).
static func _tone(f0: float, f1: float, dur: float, decay: float, noise: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		ph += TAU * lerpf(f0, f1, float(i) / n) / rate
		var env := exp(-t * decay) * minf(1.0, t * 300.0)
		buf[i] = (sin(ph) + 0.3 * sin(ph * 2.0)) * env * 0.5 + randf_range(-1.0, 1.0) * noise * exp(-t * 40.0)
	return Synth.wav(buf, rate, 1.0)

## "Fiuu": ruido que sube y baja, de algo que pasa volando.
static func _whoosh() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.3)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), lerpf(0.05, 0.3, k))
		buf[i] = lp * sin(k * PI) * 0.9
	return Synth.wav(buf, rate, 1.0)
