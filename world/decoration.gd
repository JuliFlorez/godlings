extends Node2D
class_name Decoration
## Decoración de la isla (palmera, arbusto, arbusto de bayas, flores, roca, antorcha),
## dibujada por código. De noche las antorchas iluminan la isla alrededor (PointLight2D); la
## lluvia del diluvio las apaga hasta que para (ver Storm). A las palmeras les crecen cocos y
## a los arbustos de bayas, bayas: los aldeanos con hambre las vienen a comer solos (ver
## BerryPick y Villager._seek_food).
## El origen del nodo queda LIFT px arriba de la base, igual que el centro de un aldeano,
## para que el orden por Y (quién tapa a quién) sea parejo entre ambos.

const LIFT := 30.0

## Catálogo de la tienda. "icon_scale" ajusta el dibujo al recuadro del ícono.
const KINDS := {
	"palm": {"name": "Palmera", "price": 15, "icon_scale": 0.42},
	"bush": {"name": "Arbusto", "price": 8, "icon_scale": 1.3},
	"berries": {"name": "Arbusto de bayas", "price": 20, "icon_scale": 1.3},
	"flowers": {"name": "Flores", "price": 6, "icon_scale": 1.7},
	"rock": {"name": "Roca", "price": 5, "icon_scale": 1.5},
	"torch": {"name": "Antorcha", "price": 12, "icon_scale": 0.62},
}

const FLOWER_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.65), Color(0.95, 0.2, 0.25), Color(1.0, 0.98, 0.95),
	Color(0.7, 0.45, 1.0), Color(1.0, 0.6, 0.15),
]

## Luz de la antorcha
const TORCH_FLAME := Vector2(0, -66)          # Centro de la llama, relativo a la base
const TORCH_LIGHT_COLOR := Color(1.0, 0.62, 0.28)
const TORCH_LIGHT_SIZE := 320                 # Diámetro del halo (px)
const TORCH_LIGHT_ENERGY := 1.15
## Hasta dónde quema: la llama y el calor que sube (px arriba de su centro)
const FLAME_HEAT: Array[float] = [0.0, 10.0, 20.0]
const FLAME_REACH := 5.0
static var _light_tex: GradientTexture2D

var kind := "palm"
var variant := 0.5          # 0..1: varía inclinación, alto, colores
var ghost := false          # Vista previa al colocar
var valid := true:
	set(v):
		valid = v
		_tint()
var hovered := false:       # El mouse está encima (se puede mover o quitar)
	set(v):
		hovered = v
		_tint()
var moving := false:        # La están arrastrando a otro lugar
	set(v):
		moving = v
		_tint()

## Zona clickeable para moverla o quitarla, relativa a la base (hacia arriba es -y).
const HIT_RECTS := {
	"palm": Rect2(-40, -128, 80, 130),
	"bush": Rect2(-23, -28, 46, 31),
	"berries": Rect2(-23, -28, 46, 31),
	"flowers": Rect2(-15, -20, 30, 23),
	"rock": Rect2(-21, -22, 42, 25),
	"torch": Rect2(-12, -78, 24, 81),
}

## Cocos de la palmera: crecen de a uno en los lugares libres de la copa y se pueden arrancar.
const COCONUT_SLOTS: Array[Vector2] = [Vector2(-7, 6), Vector2(7, 7), Vector2(0, 13)]  # Relativos a la copa
const COCONUT_R := 6.5
const COCONUT_PICK_R := 11.0        # Radio para agarrarlos con el mouse
const COCONUT_GROW_MIN := 15.0      # Segundos entre coco y coco
const COCONUT_GROW_MAX := 25.0
const COCONUT_GROW_SPEED := 1.5     # Un coco nuevo tarda 1/esto segundos en llegar a su tamaño
## Bayas del arbusto de bayas: crecen de a una, igual que los cocos, y se las comen los aldeanos.
const BERRY_SLOTS: Array[Vector2] = [Vector2(-14, -10), Vector2(-6, -19), Vector2(5, -21), Vector2(14, -12), Vector2(1, -8)]
const BERRY_START := 3              # Las que ya tiene al plantarlo
const BERRY_GROW_MIN := 18.0
const BERRY_GROW_MAX := 30.0
const BERRY_GROW_SPEED := 1.0
const BERRY_FOOD := 20.0            # El hambre que saca cada una
## Para paint: todos los cocos (o bayas) grandes, como en la tienda y en la vista previa. Tiene
## que ser con tipo: un [] suelto no entra donde se espera un Array[float].
const ALL_FRUIT: Array[float] = []
var hover_coconut := -1             # Coco de la copa bajo el mouse (se resalta)
## Los cocos de la palmera o las bayas del arbusto: si hay uno en cada lugar, y su tamaño
## (0..1: los nuevos crecen de a poco). Las bayas reservadas son las que alguien viene a comer.
var _has_fruit: Array[bool] = [true, false, false]
var _fruit_size: Array[float] = [0.0, 0.0, 0.0]
var _reserved: Array[bool] = []
var _grow_t := 0.0

var _light: PointLight2D
var _sky: Node
var _lit := 1.0             # Antorcha: 1 prendida, 0 apagada por la lluvia del diluvio (ver Storm)

func _ready() -> void:
	if not ghost:
		variant = randf()
		_grow_t = _grow_time()
	if kind == "berries":
		_has_fruit.assign(BERRY_SLOTS.map(func(_s): return false))
		for i in BERRY_START:
			_has_fruit[i] = true
		_has_fruit.shuffle()
		_fruit_size.assign(BERRY_SLOTS.map(func(_s): return 0.0))
		_reserved.assign(BERRY_SLOTS.map(func(_s): return false))
		if not ghost:
			add_to_group("berry_bush")   # Los aldeanos con hambre los buscan
	valid = valid
	if kind == "torch" and not ghost:
		add_to_group("torch")   # Los aldeanos la buscan para saber si los tienen arriba del fuego
		_sky = get_tree().get_first_node_in_group("sky")
		_light = PointLight2D.new()
		_light.texture = _torch_light_texture()
		_light.color = TORCH_LIGHT_COLOR
		_light.position = Vector2(0, LIFT) + TORCH_FLAME
		_light.enabled = false
		add_child(_light)

func _tint() -> void:
	if ghost or moving:
		modulate = Color(1, 1, 1, 0.65) if valid else Color(1.0, 0.35, 0.35, 0.65)
	elif hovered:
		modulate = Color(1.3, 1.25, 1.1)
	else:
		modulate = Color.WHITE

## Antorcha: si el cuerpo del aldeano está en la llama o en el calor que sube de ella.
## (Mientras la mueven de lugar no quema, ni apagada por la lluvia.)
func burns(v: Villager) -> bool:
	if moving or _lit < 0.5:
		return false
	var flame := global_position + Vector2(0, LIFT) + TORCH_FLAME
	for h in FLAME_HEAT:
		if v.body_distance(flame + Vector2(0, -h)) <= FLAME_REACH:
			return true
	return false

func hit_test(global_point: Vector2) -> bool:
	var r: Rect2 = HIT_RECTS.get(kind, HIT_RECTS.flowers)
	return r.has_point(global_point - global_position - Vector2(0, LIFT))

## Centro de un coco de la copa, en coordenadas globales.
func coconut_global(i: int) -> Vector2:
	return global_position + Vector2(0, LIFT) + palm_top(variant) + COCONUT_SLOTS[i]

## Índice del coco maduro bajo el punto (el de más adelante), o -1.
func coconut_at(global_point: Vector2) -> int:
	if kind != "palm" or ghost or moving:
		return -1
	for i in range(COCONUT_SLOTS.size() - 1, -1, -1):
		if _has_fruit[i] and _fruit_size[i] >= 1.0 and coconut_global(i).distance_to(global_point) <= COCONUT_PICK_R:
			return i
	return -1

func take_coconut(i: int) -> void:
	_has_fruit[i] = false
	_fruit_size[i] = 0.0
	hover_coconut = -1
	if _grow_t <= 0.0:
		_grow_t = _grow_time()

## Arbusto de bayas: una baya madura que nadie viene a comerse, o -1.
func free_berry() -> int:
	if kind != "berries" or ghost or moving or not is_in_group("berry_bush"):
		return -1
	for i in BERRY_SLOTS.size():
		if _has_fruit[i] and _fruit_size[i] >= 1.0 and not _reserved[i]:
			return i
	return -1

## Una baya para que se la venga a comer alguien (la reserva), o null si no queda ninguna.
func pick_berry() -> Food:
	var i := free_berry()
	if i < 0:
		return null
	var b := BerryPick.new()
	b.bush = self
	b.slot = i
	_reserved[i] = true
	add_child(b)
	return b

func eat_berry(i: int) -> void:
	_has_fruit[i] = false
	_fruit_size[i] = 0.0
	_reserved[i] = false
	if _grow_t <= 0.0:
		_grow_t = _grow_time()

func unreserve(i: int) -> void:
	_reserved[i] = false

func _grow_time() -> float:
	if kind == "berries":
		return randf_range(BERRY_GROW_MIN, BERRY_GROW_MAX)
	return randf_range(COCONUT_GROW_MIN, COCONUT_GROW_MAX)

func _process(dt: float) -> void:
	# La palmera se mece, la antorcha titila y a las bayas se las van comiendo
	if kind == "palm" or kind == "torch" or kind == "berries":
		queue_redraw()
	if (kind == "palm" or kind == "berries") and not ghost:
		_grow_fruit(dt)
	if _light:
		# La lluvia la apaga enseguida; cuando para, se vuelve a prender de a poco
		_lit = move_toward(_lit, 0.0 if Storm.wet() else 1.0, dt * (2.0 if Storm.wet() else 0.6))
		# Se prende a medida que oscurece; de día no ilumina nada
		var night: float = _sky.night if _sky else 0.0
		var dark := smoothstep(0.55, 0.95, night)
		var t := Time.get_ticks_msec() / 1000.0 + variant * 10.0
		var flick := 1.0 + sin(t * 17.0) * 0.06 + sin(t * 29.0) * 0.04
		_light.energy = TORCH_LIGHT_ENERGY * dark * flick * _lit
		_light.enabled = dark > 0.01 and _lit > 0.01

## Halo radial compartido por todas las antorchas: blanco al centro, se apaga hacia afuera.
static func _torch_light_texture() -> GradientTexture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = TORCH_LIGHT_SIZE
		_light_tex.height = TORCH_LIGHT_SIZE
	return _light_tex

## Cada tanto nace un coco (o una baya) en un lugar libre; los nuevos crecen de a poco. Las
## bayas que alguien se está comiendo no (se van achicando, ver BerryPick).
func _grow_fruit(dt: float) -> void:
	var speed := COCONUT_GROW_SPEED if kind == "palm" else BERRY_GROW_SPEED
	var free_slots: Array[int] = []
	for i in _has_fruit.size():
		if i < _reserved.size() and _reserved[i]:
			continue
		_fruit_size[i] = move_toward(_fruit_size[i], 1.0 if _has_fruit[i] else 0.0, dt * speed)
		if not _has_fruit[i]:
			free_slots.append(i)
	if free_slots.is_empty():
		return
	_grow_t -= dt
	if _grow_t <= 0.0:
		_has_fruit[free_slots.pick_random()] = true
		_grow_t = _grow_time()

func _draw() -> void:
	draw_set_transform(Vector2(0, LIFT))
	paint(self, kind, variant, Time.get_ticks_msec() / 1000.0, ALL_FRUIT if ghost else _fruit_size, _lit)
	if hover_coconut >= 0:
		var c := palm_top(variant) + COCONUT_SLOTS[hover_coconut]
		draw_arc(c, COCONUT_R + 2.5, 0.0, TAU, 20, Color(1.0, 0.95, 0.6, 0.9), 1.5, true)

static func price_of(k: String) -> int:
	return KINDS[k].price

## Copa de la palmera (donde nacen las hojas y cuelgan los cocos), relativa a la base.
static func palm_top(v: float) -> Vector2:
	return Vector2(lerpf(-16.0, 16.0, v), -lerpf(92.0, 116.0, fposmod(v * 7.3, 1.0)))

## Dibuja la decoración con la base en el origen (hacia arriba es -y).
## "fruit" es el tamaño (0..1) de cada coco de la palmera o baya del arbusto (vacío: todos
## grandes, como en la tienda); "lit", cuánto está prendida la antorcha.
static func paint(ci: CanvasItem, k: String, v: float, t: float, fruit: Array[float] = ALL_FRUIT, lit := 1.0) -> void:
	ci.draw_colored_polygon(_ellipse(Vector2(0, 2), 20 if k == "palm" else 14, 5), Color(0, 0, 0, 0.18))
	match k:
		"palm": _paint_palm(ci, v, t, fruit)
		"bush": _paint_bush(ci, v)
		"berries": _paint_berry_bush(ci, v, fruit)
		"flowers": _paint_flowers(ci, v)
		"rock": _paint_rock(ci, v)
		"torch": _paint_torch(ci, t, lit)

static func _paint_palm(ci: CanvasItem, v: float, t: float, nuts: Array[float]) -> void:
	var top := palm_top(v)
	var lean := top.x
	var h := -top.y
	# Tronco en segmentos, más finito arriba
	var n := 8
	for i in n:
		var a := float(i) / n
		var b := float(i + 1) / n
		var pa := Vector2(lean * a * a, -h * a)
		var pb := Vector2(lean * b * b, -h * b)
		var wa := lerpf(7.0, 4.0, a)
		var wb := lerpf(7.0, 4.0, b)
		var col := Color(0.55, 0.36, 0.2) if i % 2 == 0 else Color(0.48, 0.3, 0.16)
		ci.draw_colored_polygon(PackedVector2Array([pa + Vector2(-wa, 0), pb + Vector2(-wb, 0), pb + Vector2(wb, 0), pa + Vector2(wa, 0)]), col)
	# Hojas: curvas que caen, meciéndose con el viento
	var angles := [-172.0, -145.0, -118.0, -62.0, -35.0, -8.0, -90.0]
	for i in angles.size():
		var dir := Vector2.from_angle(deg_to_rad(angles[i]) + sin(t * 1.4 + i * 0.9 + v * 6.0) * 0.05)
		var length := 44.0 if i < 6 else 30.0
		var normal := dir.orthogonal()
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for s_i in 9:
			var s := s_i / 8.0
			var q := top + dir * length * s + Vector2(0, 26.0 * s * s)
			var w := 7.0 * sin(PI * s)
			upper.append(q + normal * w)
			lower.append(q - normal * w)
		lower.reverse()
		var leaf := upper + lower
		ci.draw_colored_polygon(leaf, Color(0.2, 0.6, 0.25) if i % 2 == 0 else Color(0.15, 0.5, 0.2))
		var rib := PackedVector2Array()
		for s_i in 9:
			var s := s_i / 8.0
			rib.append(top + dir * length * s + Vector2(0, 26.0 * s * s))
		ci.draw_polyline(rib, Color(0.1, 0.36, 0.14), 1.2, true)
	for i in COCONUT_SLOTS.size():
		var size := 1.0 if nuts.is_empty() else nuts[i]
		if size > 0.0:
			Coconut.paint_whole(ci, top + COCONUT_SLOTS[i], COCONUT_R * size)

static func _paint_bush(ci: CanvasItem, v: float) -> void:
	var dark := Color(0.14, 0.44, 0.2).lerp(Color(0.2, 0.5, 0.16), v)
	var light := dark.lightened(0.25)
	for c in [Vector2(-10, -8), Vector2(10, -8), Vector2(0, -15)]:
		ci.draw_circle(c, 11.0, dark, true, -1.0, true)
	for c in [Vector2(-12, -11), Vector2(7, -12), Vector2(-3, -19)]:
		ci.draw_circle(c, 5.0, light, true, -1.0, true)

## El arbusto (un verde más azulado que el común) con sus bayas rojas.
static func _paint_berry_bush(ci: CanvasItem, v: float, fruit: Array[float]) -> void:
	var dark := Color(0.12, 0.38, 0.24).lerp(Color(0.16, 0.42, 0.22), v)
	var light := dark.lightened(0.22)
	for c in [Vector2(-10, -8), Vector2(10, -8), Vector2(0, -15)]:
		ci.draw_circle(c, 11.0, dark, true, -1.0, true)
	for c in [Vector2(-12, -11), Vector2(7, -12), Vector2(-3, -19)]:
		ci.draw_circle(c, 5.0, light, true, -1.0, true)
	for i in BERRY_SLOTS.size():
		var size := 1.0 if fruit.is_empty() else fruit[i]
		if size <= 0.0:
			continue
		var c := BERRY_SLOTS[i]
		ci.draw_circle(c, 3.4 * size, Color(0.45, 0.04, 0.12), true, -1.0, true)
		ci.draw_circle(c, 2.8 * size, Color(0.88, 0.16, 0.26), true, -1.0, true)
		ci.draw_circle(c + Vector2(-0.9, -0.9) * size, 1.0 * size, Color(1.0, 0.8, 0.82, 0.85), true, -1.0, true)

static func _paint_flowers(ci: CanvasItem, v: float) -> void:
	var col := FLOWER_COLORS[int(v * FLOWER_COLORS.size()) % FLOWER_COLORS.size()]
	var stems := [Vector2(-9, -9), Vector2(-3, -14), Vector2(4, -11), Vector2(10, -7), Vector2(0, -6)]
	for s: Vector2 in stems:
		ci.draw_line(Vector2(s.x * 0.6, 0), s, Color(0.2, 0.55, 0.22), 1.5, true)
	for s: Vector2 in stems:
		for p in 5:
			ci.draw_circle(s + Vector2.from_angle(TAU * p / 5.0) * 2.6, 2.2, col, true, -1.0, true)
		ci.draw_circle(s, 1.6, Color(1.0, 0.85, 0.2), true, -1.0, true)

static func _paint_rock(ci: CanvasItem, v: float) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		var r := 1.0 + sin(i * 2.7 + v * 10.0) * 0.12
		pts.append(Vector2(cos(a) * 16.0 * r, minf(-9.0 + sin(a) * 11.0 * r, 0.0)))
	ci.draw_colored_polygon(pts, Color(0.56, 0.56, 0.6))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.32, 0.32, 0.36), 1.5, true)
	ci.draw_colored_polygon(_ellipse(Vector2(-5, -13), 6, 3), Color(0.72, 0.72, 0.76))
	ci.draw_circle(Vector2(16, -3), 4.0, Color(0.5, 0.5, 0.54), true, -1.0, true)

## lit: 1 prendida, 0 apagada (la llama se achica hacia la copa y quedan las brasas).
static func _paint_torch(ci: CanvasItem, t: float, lit := 1.0) -> void:
	var flick := 1.0 + sin(t * 17.0) * 0.08 + sin(t * 29.0) * 0.05
	if lit > 0.05:
		ci.draw_circle(Vector2(0, -66), 26.0 * flick, Color(1.0, 0.6, 0.2, 0.14 * lit), true, -1.0, true)
	ci.draw_line(Vector2(0, 0), Vector2(0, -50), Color(0.5, 0.32, 0.17), 4.0, true)
	for y in [-14.0, -30.0]:
		ci.draw_line(Vector2(-2.5, y), Vector2(2.5, y - 2), Color(0.35, 0.22, 0.1), 2.0, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -50), Vector2(7, -50), Vector2(9, -58), Vector2(-9, -58)]), Color(0.4, 0.26, 0.12))
	if lit < 1.0:
		ci.draw_colored_polygon(_ellipse(Vector2(0, -58), 7.0, 2.2), Color(0.32, 0.09, 0.04))   # Brasas mojadas
	if lit > 0.05:   # Al apagarse la llama se achica hacia la copa
		ci.draw_colored_polygon(_ellipse(Vector2(0, -58.0 - 8.0 * lit), 6.5 * flick * lit, 10.0 * flick * lit), Color(1.0, 0.5, 0.12))
		ci.draw_colored_polygon(_ellipse(Vector2(0, -58.0 - 5.0 * lit), 3.2 * lit, 5.5 * flick * lit), Color(1.0, 0.92, 0.55))

static func _ellipse(c: Vector2, rx: float, ry: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## Una baya del arbusto que un aldeano viene a comerse (ver Food). La dibuja el arbusto: esto
## solo la reserva mientras tanto, y se va cuando se la comen o cuando se queda sin quien se
## la coma (o si mueven el arbusto).
class BerryPick extends Food:
	var bush: Decoration
	var slot := 0

	func _init() -> void:
		nutrition = Decoration.BERRY_FOOD

	func _process(dt: float) -> void:
		if bush.moving:
			release_eater()
			return
		super(dt)

	func point() -> Vector2:
		return bush.global_position + Vector2(0, Decoration.LIFT)

	## Al costado del arbusto.
	func eat_spot(v: Villager) -> Vector2:
		var side := 1.0 if v.global_position.x >= point().x else -1.0
		return point() + Vector2(side * 24.0, -Villager.BODY_BOTTOM)

	## La baya se va achicando.
	func nibble(progress: float) -> void:
		bush._fruit_size[slot] = 1.0 - 0.7 * progress

	func finish_eating(v: Villager) -> void:
		bush.eat_berry(slot)
		super(v)

	func _lost_eater() -> void:
		bush.unreserve(slot)
		queue_free()
