extends Node2D
class_name HutDebris
## Un pedacito de una choza rota (ver Decoration.smash): una caña partida, un palo, una mata de
## paja, una hoja, un hueso o el cartel con su nombre. Sale volando, rebota en el piso, queda
## tirado un rato (en el piso, debajo de los aldeanos) y se desvanece; si cae fuera de la isla
## se hunde en el agua. Se dibuja en las medidas de la choza (ver Decoration.HUT_SCALE).
## burst arma todos los de una choza.

enum Kind { CANE, PLANK, STRAW, LEAF, BONE, SIGN }

const GRAVITY := 1300.0
const BOUNCE_SPEED := 220.0           # Más rápido que esto rebota al tocar el piso
const FRICTION := 500.0
const REST := Vector2(9.0, 14.0)      # Lo que queda tirado antes de desvanecerse (s)
const FADE := 1.5
const FLOOR := Vector2(-14.0, 30.0)   # Dónde cae: más atrás o más adelante del piso de la choza
const STRAW_TUFTS := 14
const C_BURNT := Color(0.32, 0.27, 0.24)

var kind := Kind.CANE
var size := Vector2(4, 12)            # Caña, palo o mata de paja (en las medidas de la choza)
var color := Color.WHITE
var label := ""                       # El cartel: lo que decía
var vel := Vector2.ZERO
var spin := 0.0
var floor_y := INF                    # La altura del piso donde cae
var _resting := false
var _sinking := false
var _rest_t := 0.0
var _lie := 0.0                       # Tirado: el ángulo en el que queda acostado

## Rompe la choza h: arma sus pedacitos donde estaba cada uno, los tira para afuera desde from
## (force: con cuánta fuerza, px/s) y levanta polvo. burnt (0..1): qué tan chamuscados.
static func burst(h: Decoration, from: Vector2, force: float, burnt := 0.0) -> void:
	var parent := h.get_parent()
	var base := h.door()
	var w := Decoration.HUT_WALL
	var cane := Decoration.hut_cane(h.variant)
	var post := 5.0
	var cw := (w.x - post) * 2.0 / Decoration.HUT_CANES
	var pieces: Array[HutDebris] = []
	# Las cañas, partidas (de cada una sale un pedazo)
	for i in Decoration.HUT_CANES:
		var length := randf_range(10.0, 20.0)
		pieces.append(_piece(Kind.CANE, Vector2(-w.x + post + cw * (i + 0.5), -randf_range(length * 0.5, w.y - length * 0.5)),
				Vector2(cw - 1.0, length), cane if i % 2 == 0 else cane.darkened(0.08)))
	# Los postes de las esquinas (partidos al medio) y el marco de la puerta
	for x: float in [-w.x + post * 0.5, w.x - post * 0.5]:
		for y: float in [-w.y * 0.25, -w.y * 0.75]:
			pieces.append(_piece(Kind.PLANK, Vector2(x, y), Vector2(post, w.y * 0.5), Decoration.C_HUT_WOOD))
	var door := Decoration.HUT_DOOR
	for x: float in [-door.x - 1.75, door.x + 1.75]:
		pieces.append(_piece(Kind.PLANK, Vector2(x, -door.y * 0.5), Vector2(3.5, door.y), Decoration.C_HUT_WOOD))
	pieces.append(_piece(Kind.PLANK, Vector2(0, -door.y - 1.75), Vector2(door.x * 2.0 + 10.0, 3.5), Decoration.C_HUT_WOOD.lightened(0.08)))
	# Matas de paja de todo el techo
	var eave := Decoration.HUT_EAVE
	for i in STRAW_TUFTS:
		var u := randf()   # 0 el alero, 1 la punta
		var half := eave.x * (1.0 - u) * 0.9
		pieces.append(_piece(Kind.STRAW, Vector2(randf_range(-half, half), lerpf(eave.y, Decoration.HUT_TOP + 6.0, u)),
				Vector2(randf_range(9.0, 13.0), randf_range(6.0, 9.0)), Decoration.hut_straw(h.variant).darkened(randf_range(0.0, 0.1))))
	# Las hojas, los huesos y el cartel
	for i in Decoration.HUT_LEAVES.size():
		var l := Decoration.HUT_LEAVES[i]
		var leaf := _piece(Kind.LEAF, Vector2(l.x, l.y), Vector2.ZERO, Decoration.leaf_color(i))
		leaf.rotation = l.z
		pieces.append(leaf)
	for d: Vector2 in [Decoration.HUT_BONE, Decoration.HUT_BONE * Vector2(-1, 1)]:
		var bone := _piece(Kind.BONE, Decoration.HUT_CROSS, Vector2.ZERO, Color.WHITE)
		bone.rotation = d.angle()
		pieces.append(bone)
	var board := _piece(Kind.SIGN, Vector2(0, Decoration.HUT_SIGN_Y), Vector2.ZERO, Color.WHITE)
	board.label = h.hut_name
	pieces.append(board)

	for p in pieces:
		var at := base + p.position * Decoration.HUT_SCALE
		var away := at - from
		var dir := away.normalized() if away.length() > 1.0 else Vector2.UP
		p.vel = Vector2(dir.x * force * randf_range(0.5, 1.1) + randf_range(-50.0, 50.0),
				-force * randf_range(0.45, 0.95) + minf(dir.y, 0.0) * force * 0.3)
		p.spin = randf_range(-12.0, 12.0)
		p.floor_y = base.y + randf_range(FLOOR.x, FLOOR.y)
		p.scale = Vector2.ONE * Decoration.HUT_SCALE
		if burnt > 0.0:
			p.self_modulate = Color.WHITE.lerp(C_BURNT, burnt * randf_range(0.6, 1.0))
		p.z_index = 10   # Volando, por encima de todo (como los cocos)
		parent.add_child(p)
		p.global_position = at
	_dust(parent, base, Decoration.hut_straw(h.variant), 26, 260.0)
	_dust(parent, base, Color(0.93, 0.83, 0.6, 0.8), 20, 160.0)   # Arena

## Un pedacito de la choza en at (en sus medidas, respecto a la base: burst lo pone en su lugar).
static func _piece(k: Kind, at: Vector2, sz: Vector2, col: Color) -> HutDebris:
	var p := HutDebris.new()
	p.kind = k
	p.position = at
	p.size = sz
	p.color = col
	return p

static func _dust(parent: Node, at: Vector2, col: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.8
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = col
	p.z_index = 15
	parent.add_child(p)
	p.global_position = at + Vector2(0, -20)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _process(dt: float) -> void:
	if _sinking:
		modulate.a -= dt * 1.5
		position.y += 12.0 * dt
		if modulate.a <= 0.0:
			queue_free()
		return
	if _resting:
		vel.x = move_toward(vel.x, 0.0, FRICTION * dt)
		position.x += vel.x * dt
		rotation = lerp_angle(rotation, _lie, 10.0 * dt)
		_rest_t -= dt
		modulate.a = clampf(_rest_t / FADE, 0.0, 1.0)
		if _rest_t <= 0.0:
			queue_free()
		return
	vel.y += GRAVITY * dt
	global_position += vel * dt
	rotation += spin * dt
	if vel.y > 0.0 and global_position.y >= floor_y:
		_touch_down()
	elif global_position.y > (get_canvas_transform().affine_inverse() * get_viewport_rect()).end.y + 100.0:
		queue_free()   # Se fue de la pantalla

## Llegó a la altura del piso: en la isla rebota o queda tirado (acostado); afuera se hunde en
## el agua, o sigue cayendo si abajo no hay nada.
func _touch_down() -> void:
	var p := Vector2(global_position.x, floor_y)
	if Coconut.island_poly.size() > 0 and Geometry2D.is_point_in_polygon(p, Coconut.island_poly):
		global_position.y = floor_y
		if vel.y > BOUNCE_SPEED:
			vel = Vector2(vel.x * 0.5, -vel.y * 0.3)
			spin *= 0.5
			return
		_resting = true
		vel.y = 0.0
		_rest_t = randf_range(REST.x, REST.y)
		var off := PI * 0.5 if size.y > size.x else 0.0   # Lo largo queda acostado
		_lie = snappedf(rotation - off, PI) + off
		z_index = 0
		var layer := get_tree().get_first_node_in_group("ground_layer")
		if layer:
			reparent.call_deferred(layer)   # Tirado en el piso: los aldeanos le pasan por encima
		return
	var water := get_tree().get_first_node_in_group("water")
	if water and water.get_global_rect().has_point(p):
		_sinking = true
		z_index = 0
		Sea.ripple_at(self, p, 0.35)
		return
	floor_y = INF

func _draw() -> void:
	var ink := Decoration.C_HUT_INK
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	match kind:
		Kind.CANE:
			# Partida: las puntas, astilladas
			var pts := PackedVector2Array([Vector2(-hx, -hy + 1.5), Vector2(-hx * 0.2, -hy), Vector2(hx * 0.4, -hy + 2.0), Vector2(hx, -hy + 0.5),
					Vector2(hx, hy - 1.0), Vector2(hx * 0.1, hy), Vector2(-hx * 0.5, hy - 2.0), Vector2(-hx, hy)])
			draw_colored_polygon(pts, color)
			draw_line(Vector2(-hx + 0.9, -hy + 1.5), Vector2(-hx + 0.9, hy - 0.5), color.lightened(0.3), 0.8)   # El brillo
			draw_line(Vector2(-hx, hy * 0.2), Vector2(hx, hy * 0.2), color.darkened(0.3), 1.0)   # Un nudo
			pts.append(pts[0])
			draw_polyline(pts, ink, 0.9, true)
		Kind.PLANK:
			draw_rect(Rect2(-size * 0.5, size), color)
			draw_rect(Rect2(-size * 0.5, size), ink, false, 1.0)
		Kind.STRAW:
			var pts := PackedVector2Array([Vector2(-hx, hy), Vector2(-hx * 0.7, -hy * 0.6), Vector2(-hx * 0.3, 0.0), Vector2(0.0, -hy),
					Vector2(hx * 0.3, 0.0), Vector2(hx * 0.7, -hy * 0.6), Vector2(hx, hy)])
			draw_colored_polygon(pts, color)
			for x: float in [-0.35, 0.0, 0.35]:
				draw_line(Vector2(x * hx, hy), Vector2(x * hx * 1.3, -hy * 0.4), color.darkened(0.2), 0.8, true)
			pts.append(pts[0])
			draw_polyline(pts, Color(ink, 0.8), 0.8, true)
		Kind.LEAF:
			Decoration._leaf(self, Vector2.ZERO, 0.0, color, ink)
		Kind.BONE:
			var half := Decoration.HUT_BONE.length()
			Decoration._bone(self, Vector2(-half, 0), Vector2(half, 0), ink, Decoration.HUT_BONE_W)
		Kind.SIGN:
			Decoration._paint_hut_sign(self, label, ink, 0.0)
