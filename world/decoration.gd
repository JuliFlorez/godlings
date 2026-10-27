extends Node2D
class_name Decoration
## Decoración de la isla (palmera, arbusto de bayas, flores, roca, antorcha, choza, altar de
## sacrificios), dibujada por código. En el altar se sacrifican aldeanos (ver Altar). En las chozas viven los aldeanos (ver Villager.home): de noche duermen adentro
## (con la puerta iluminada y unas zetas saliendo del techo) y de día entran cada tanto a
## descansar; las parejas que están adentro juntas cada tanto tienen un bebé (ver _try_birth).
## Arriba de la puerta tienen un cartel con el nombre que les pone el jugador (ver hut_name y
## HutCard), y el meteorito, el rayo y el tornado las rompen en pedacitos (ver smash). De noche las antorchas iluminan la isla alrededor (PointLight2D); la
## lluvia del diluvio las apaga hasta que para (ver Storm). A las palmeras les crecen cocos y
## a los arbustos de bayas, bayas: los aldeanos con hambre las vienen a comer solos (ver
## BerryPick y Villager._seek_food).
## El origen del nodo queda LIFT px arriba de la base, igual que el centro de un aldeano,
## para que el orden por Y (quién tapa a quién) sea parejo entre ambos.

const LIFT := 30.0

## Catálogo de la tienda. "icon_scale" ajusta el dibujo al recuadro del ícono.
const KINDS := {
	"palm": {"name": "Palmera", "price": 15, "icon_scale": 0.42},
	"berries": {"name": "Arbusto de bayas", "price": 20, "icon_scale": 1.3},
	"flowers": {"name": "Flores", "price": 6, "icon_scale": 1.7},
	"rock": {"name": "Roca", "price": 5, "icon_scale": 1.5},
	"torch": {"name": "Antorcha", "price": 12, "icon_scale": 0.62},
	"hut": {"name": "Choza", "price": 40, "icon_scale": 0.46},
	"altar": {"name": "Altar de sacrificios", "price": 120, "icon_scale": 0.52},
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
	"berries": Rect2(-23, -28, 46, 31),
	"flowers": Rect2(-15, -20, 30, 23),
	"rock": Rect2(-21, -22, 42, 25),
	"torch": Rect2(-12, -78, 24, 81),
	"hut": Rect2(Vector2(-46, -80) * HUT_SCALE, Vector2(92, 82) * HUT_SCALE),
	"altar": Rect2(Vector2(-62, -62) * ALTAR_SCALE, Vector2(124, 64) * ALTAR_SCALE),
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
## Choza: los que viven ahí (ver residents), y una pareja que está adentro junta cada tanto
## tiene un bebé, si hay lugar en la choza y en la isla.
const HUT_BEDS := 4
const BIRTH_CHECK := 4.0            # Cada cuánto se fija
const BIRTH_CHANCE := 0.2           # Y la probabilidad cada vez
const HUT_LIGHT_SCALE := 0.5        # La luz de la puerta, de noche (más chica que la de la antorcha)
const HUT_LIGHT_ENERGY := 0.9
## Dibujo de la choza, relativo a la base y en sus medidas (al dibujarla se agranda HUT_SCALE
## veces): paredes de cañas, techo de paja hasta la punta (con los huesos cruzados arriba), la
## puerta y el cartel de madera con su nombre arriba de ella.
const HUT_SCALE := 1.4
const HUT_WALL := Vector2(38, 36)   # Medio ancho y alto de las paredes
const HUT_EAVE := Vector2(45, -33)  # Punta del alero (la derecha; los flecos llegan más abajo)
const HUT_TOP := -64.0              # Punta del techo
const HUT_DOOR := Vector2(9, 25)    # Medio ancho y alto del hueco de la puerta
const HUT_SIGN := Vector2(44, 14)   # Ancho (si el nombre no entra, se estira) y alto del cartel
const HUT_SIGN_Y := -40.0           # Centro del cartel
const HUT_SIGN_FONT := Vector2i(10, 7)   # Tamaño de letra: el más grande, y hasta dónde se achica
const HUT_CROSS := Vector2(0, -68)  # Donde se cruzan los huesos...
const HUT_BONE := Vector2(7.8, -7.2)   # ...que van de ahí hasta esto para cada lado...
const HUT_BONE_W := 1.3             # ...y así de gruesos
const HUT_CANES := 13               # Cañas de las paredes
const HUT_DEPTH := 18.0             # Lo que ocupa en el piso para atrás de la puerta
## Hojas sueltas encima de la paja: (x, y, ángulo)
const HUT_LEAVES: Array[Vector3] = [Vector3(-31, -40, 0.7), Vector3(-17, -53, -0.4), Vector3(14, -55, 0.5), Vector3(30, -42, -0.8)]
const C_HUT_INK := Color(0.22, 0.13, 0.06)   # El contorno de todo
const C_HUT_WOOD := Color(0.5, 0.31, 0.15)
## Altar de sacrificios: como la choza, se dibuja en sus medidas y se agranda ALTAR_SCALE veces.
const ALTAR_SCALE := 1.3
const ALTAR_TOP := -44.0            # La cara de arriba de la piedra (donde queda acostado el que sacrificás)
const ALTAR_LIGHT := Vector2(0, -50)   # Donde ilumina de noche (entre los braseros)
const ALTAR_LIGHT_SCALE := 1.2
const C_ALTAR_STONE := Color(0.5, 0.47, 0.52)
const C_STAIN := Color(0.42, 0.04, 0.06, 0.85)
## Las manchas de sangre de la piedra (aparecen de a una con cada sacrificio): (x, ancho, chorreado)
const ALTAR_STAINS: Array[Vector3] = [Vector3(-8, 9, 6), Vector3(14, 7, 3), Vector3(-24, 6, 4), Vector3(4, 5, 8), Vector3(26, 6, 2), Vector3(-16, 5, 5)]
var stains := 0                    # Altar: los sacrificios que se hicieron acá
var ritual: Altar                  # Altar: el que hace los sacrificios
const HUT_NAME_MAX := 14            # Letras del nombre
static var _sign_font: Font
var hut_name := "":                 # Lo que dice el cartel (lo escribe el jugador, ver HutCard)
	set(v):
		hut_name = v
		queue_redraw()
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
var _glow := 0.0            # Choza: la puerta iluminada (alguien adentro, de noche)
var _door_light: PointLight2D
var _sleepers := 0          # Choza: los que están adentro
var _birth_t := BIRTH_CHECK
var _hud: HUD               # Choza: para saber si tiene el cartel abierto

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
	if kind == "hut" and not ghost:
		add_to_group("hut")   # Los aldeanos buscan dónde vivir
		_sky = get_tree().get_first_node_in_group("sky")
		_hud = get_tree().get_first_node_in_group("hud")
		# La puerta iluminada tiene que verse aunque la noche oscurezca todo
		_door_light = PointLight2D.new()
		_door_light.texture = _torch_light_texture()
		_door_light.texture_scale = HUT_LIGHT_SCALE
		_door_light.color = TORCH_LIGHT_COLOR
		_door_light.position = Vector2(0, LIFT - HUT_DOOR.y * 0.5 * HUT_SCALE)
		_door_light.enabled = false
		add_child(_door_light)
	if kind == "altar" and not ghost:
		add_to_group("altar")   # Los aldeanos que soltás encima se sacrifican (ver Villager._stop_drag)
		ritual = Altar.new()
		add_child(ritual)
	if (kind == "torch" or kind == "altar") and not ghost:
		if kind == "torch":
			add_to_group("torch")   # Los aldeanos la buscan para saber si los tienen arriba del fuego
		_sky = get_tree().get_first_node_in_group("sky")
		_light = PointLight2D.new()
		_light.texture = _torch_light_texture()
		_light.color = TORCH_LIGHT_COLOR
		_light.position = Vector2(0, LIFT) + (TORCH_FLAME if kind == "torch" else ALTAR_LIGHT * ALTAR_SCALE)
		_light.texture_scale = 1.0 if kind == "torch" else ALTAR_LIGHT_SCALE
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
	if kind == "palm" or kind == "torch" or kind == "berries" or kind == "altar":
		queue_redraw()
	if (kind == "palm" or kind == "berries") and not ghost:
		_grow_fruit(dt)
	if kind == "hut" and not ghost:
		_update_hut(dt)
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
	var lit := _lit
	if kind == "hut":
		lit = _glow
	elif ritual:
		lit = ritual.flames(_lit)
	paint(self, kind, variant, Time.get_ticks_msec() / 1000.0, ALL_FRUIT if ghost else _fruit_size,
			lit, hut_name, Vector2(0, LIFT))
	if kind == "altar":
		# La sangre de los sacrificios: una mancha más con cada uno, chorreando por adelante
		draw_set_transform(Vector2(0, LIFT), 0.0, Vector2.ONE * ALTAR_SCALE)
		for i in mini(stains, ALTAR_STAINS.size()):
			var s := ALTAR_STAINS[i]
			draw_colored_polygon(_ellipse(Vector2(s.x, ALTAR_TOP + 1.5), s.y * 0.5, 1.4), C_STAIN)
			draw_line(Vector2(s.x + 1.0, ALTAR_TOP + 2.0), Vector2(s.x + 1.0, ALTAR_TOP + 2.0 + s.z), C_STAIN, 1.6, true)
	draw_set_transform(Vector2(0, LIFT))
	if kind == "hut" and _sleepers > 0 and _glow > 0.5:
		# Durmiendo: zetas que suben del techo
		var t := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var k := fposmod(t * 0.4 + i / 3.0, 1.0)
			var c := Vector2(22.0 + k * 16.0 + sin(k * 6.0 + i) * 3.0, HUT_TOP * HUT_SCALE + 8.0 - k * 30.0)
			SpeechBubble._text(self, "z", c, 10.0 + k * 7.0, Color(1, 1, 1, 0.9 * (1.0 - k)))
	if kind == "hut" and not ghost and _hud and _hud.selected_hut() == self:
		# Con su cartel abierto (ver HutCard): una flechita arriba, como la del carnet
		var y := (HUT_CROSS.y + HUT_BONE.y) * HUT_SCALE - 12.0 - (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)) * NameTag.ARROW_BOB
		var tri := PackedVector2Array([Vector2(-NameTag.ARROW.x, y - NameTag.ARROW.y), Vector2(NameTag.ARROW.x, y - NameTag.ARROW.y), Vector2(0, y)])
		draw_colored_polygon(tri, HUD.C_XP)
		tri.append(tri[0])
		draw_polyline(tri, NameTag.C_OUTLINE, 2.0, true)
	if hover_coconut >= 0:
		var c := palm_top(variant) + COCONUT_SLOTS[hover_coconut]
		draw_arc(c, COCONUT_R + 2.5, 0.0, TAU, 20, Color(1.0, 0.95, 0.6, 0.9), 1.5, true)

static func price_of(k: String) -> int:
	return KINDS[k].price

## Copa de la palmera (donde nacen las hojas y cuelgan los cocos), relativa a la base.
static func palm_top(v: float) -> Vector2:
	return Vector2(lerpf(-16.0, 16.0, v), -lerpf(92.0, 116.0, fposmod(v * 7.3, 1.0)))

## Dibuja la decoración con la base en at, size veces más grande (hacia arriba es -y). Cambia
## la transformación del lienzo (ver draw_set_transform): no hace falta poner otra antes.
## "fruit" es el tamaño (0..1) de cada coco de la palmera o baya del arbusto (vacío: todos
## grandes, como en la tienda); "lit", cuánto está prendida la antorcha (o iluminada la puerta
## de la choza); "label", lo que dice el cartel de la choza (vacío: el cartel en blanco).
static func paint(ci: CanvasItem, k: String, v: float, t: float, fruit: Array[float] = ALL_FRUIT, lit := 1.0, label := "",
		at := Vector2.ZERO, size := 1.0) -> void:
	ci.draw_set_transform(at, 0.0, Vector2.ONE * size)
	var shadow: float = {"palm": 20.0, "hut": 44.0 * HUT_SCALE, "altar": 48.0 * ALTAR_SCALE}.get(k, 14.0)
	ci.draw_colored_polygon(_ellipse(Vector2(0, 2), shadow, 5), Color(0, 0, 0, 0.18))
	if k == "hut":
		ci.draw_set_transform(at, 0.0, Vector2.ONE * size * HUT_SCALE)   # La choza, en sus medidas
	elif k == "altar":
		ci.draw_set_transform(at, 0.0, Vector2.ONE * size * ALTAR_SCALE)
	match k:
		"palm": _paint_palm(ci, v, t, fruit)
		"berries": _paint_berry_bush(ci, v, fruit)
		"flowers": _paint_flowers(ci, v)
		"rock": _paint_rock(ci, v)
		"torch": _paint_torch(ci, t, lit)
		"hut": _paint_hut(ci, v, t, lit, label)
		"altar": _paint_altar(ci, t, lit)

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

## El arbusto con sus bayas rojas.
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

## Choza de cañas de bambú con techo de paja (con hojas encima y dos huesos cruzados en la
## punta), la puerta con su marco de madera y arriba de ella el cartel, que dice label.
## glow: la puerta iluminada (0..1), de noche con alguien adentro.
static func _paint_hut(ci: CanvasItem, v: float, t: float, glow: float, label: String) -> void:
	var ink := C_HUT_INK
	var wood := C_HUT_WOOD
	var w := HUT_WALL.x
	var h := HUT_WALL.y
	# Las paredes: cañas paradas, cada una con sus nudos, y postes en las esquinas
	var post := 5.0
	ci.draw_rect(Rect2(-w, -h, w * 2.0, h), Color(0.34, 0.2, 0.09))   # Lo que se ve entre caña y caña
	var cane := hut_cane(v)
	var canes := HUT_CANES
	var cw := (w - post) * 2.0 / canes
	for i in canes:
		var x := -w + post + cw * i
		var c := cane if i % 2 == 0 else cane.darkened(0.08)
		ci.draw_rect(Rect2(x + 0.5, -h, cw - 1.0, h), c)
		ci.draw_line(Vector2(x + 1.4, -h), Vector2(x + 1.4, 0), c.lightened(0.3), 0.8)   # El brillo
		var y := -4.0 - fposmod(i * 0.37 + v, 1.0) * 8.0
		while y > -h:
			ci.draw_line(Vector2(x + 0.5, y), Vector2(x + cw - 0.5, y), c.darkened(0.3), 1.0)
			y -= 11.0
	for x: float in [-w, w - post]:
		ci.draw_rect(Rect2(x, -h, post, h), wood)
		ci.draw_rect(Rect2(x, -h, post, h), ink, false, 1.0)
	ci.draw_rect(Rect2(-w, -h, w * 2.0, h), ink, false, 1.2)
	# La puerta: un hueco oscuro que de noche, con alguien adentro, se ilumina; con su marco
	var dw := HUT_DOOR.x
	var dh := HUT_DOOR.y
	if glow > 0.01:
		ci.draw_circle(Vector2(0, -dh * 0.5), 18.0 * glow, Color(1.0, 0.65, 0.25, 0.18 * glow), true, -1.0, true)
	ci.draw_rect(Rect2(-dw, -dh, dw * 2.0, dh), Color(0.17, 0.1, 0.05).lerp(Color(1.0, 0.72, 0.32), glow))
	for x: float in [-dw - 3.5, dw]:
		ci.draw_rect(Rect2(x, -dh, 3.5, dh), wood)
		ci.draw_rect(Rect2(x, -dh, 3.5, dh), ink, false, 1.0)
	var lintel := Rect2(-dw - 5.0, -dh - 3.5, dw * 2.0 + 10.0, 3.5)
	ci.draw_rect(lintel, wood.lightened(0.08))
	ci.draw_rect(lintel, ink, false, 1.0)
	# El techo de paja: baja de la punta un poco abombado y termina en flecos
	var straw := hut_straw(v)
	var roof := PackedVector2Array()
	for i in 9:   # De la punta al alero de la izquierda...
		var s := i / 8.0
		roof.append(Vector2(-lerpf(3.0, HUT_EAVE.x, s), lerpf(HUT_TOP, HUT_EAVE.y, pow(s, 1.25))))
	var fringe := 15
	for i in range(1, fringe):   # ...los flecos...
		var tip := 2.0 + 2.5 * fposmod(i * 0.61 + v * 3.0, 1.0)
		roof.append(Vector2(lerpf(-HUT_EAVE.x, HUT_EAVE.x, float(i) / fringe), HUT_EAVE.y + (tip if i % 2 == 1 else -1.5)))
	for i in range(8, -1, -1):   # ...y del alero de la derecha a la punta
		var s := i / 8.0
		roof.append(Vector2(lerpf(3.0, HUT_EAVE.x, s), lerpf(HUT_TOP, HUT_EAVE.y, pow(s, 1.25))))
	ci.draw_colored_polygon(roof, straw)
	for i in 11:   # Las pajas
		var s := lerpf(-1.0, 1.0, i / 10.0)
		var bottom := Vector2(s * (HUT_EAVE.x - 5.0), HUT_EAVE.y - 1.0)
		var top := Vector2(s * 3.0, HUT_TOP + 3.0).lerp(bottom, 0.1 + 0.25 * fposmod(i * 0.53 + v, 1.0))
		ci.draw_line(top, bottom, straw.darkened(0.2), 1.0, true)
	roof.append(roof[0])
	ci.draw_polyline(roof, ink, 1.2, true)
	# Hojas sueltas encima de la paja
	for i in HUT_LEAVES.size():
		_leaf(ci, Vector2(HUT_LEAVES[i].x, HUT_LEAVES[i].y), HUT_LEAVES[i].z, leaf_color(i), ink)
	# Dos huesos cruzados en la punta
	for d: Vector2 in [HUT_BONE, HUT_BONE * Vector2(-1, 1)]:
		_bone(ci, HUT_CROSS - d, HUT_CROSS + d, ink, HUT_BONE_W)
	_paint_hut_sign(ci, label, ink)
	if glow > 0.01:
		# Humito que sale de arriba, de noche
		for i in 3:
			var k := fposmod(t * 0.25 + i / 3.0, 1.0)
			ci.draw_circle(Vector2(-12.0 + sin(k * 5.0 + i) * 3.0, HUT_TOP + 4.0 - k * 22.0), 2.5 + k * 3.0, Color(0.85, 0.85, 0.9, 0.35 * glow * (1.0 - k)), true, -1.0, true)

## Las cañas y la paja de cada choza son un poco distintas (v: su variante).
static func hut_cane(v: float) -> Color:
	return Color(0.86, 0.79, 0.42).lerp(Color(0.8, 0.78, 0.4), v)

static func hut_straw(v: float) -> Color:
	return Color(0.92, 0.76, 0.38).lerp(Color(0.86, 0.7, 0.33), v)

## Las hojas del techo, una verde y una seca.
static func leaf_color(i: int) -> Color:
	return Color(0.55, 0.56, 0.24) if i % 2 == 0 else Color(0.66, 0.42, 0.18)

## El cartel de madera de la choza, centrado en y, con el nombre (si no entra, se achica la
## letra y después se estira el cartel).
static func _paint_hut_sign(ci: CanvasItem, label: String, ink: Color, y := HUT_SIGN_Y) -> void:
	var font := _hut_sign_font()
	var fs := HUT_SIGN_FONT.x
	var text_w := 0.0
	if label != "":
		text_w = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while fs > HUT_SIGN_FONT.y and text_w > HUT_SIGN.x - 8.0:
			fs -= 1
			text_w = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := maxf(HUT_SIGN.x, text_w + 8.0)
	var board := Rect2(-sw * 0.5, y - HUT_SIGN.y * 0.5, sw, HUT_SIGN.y)
	var plank := Color(0.74, 0.53, 0.31)
	ci.draw_rect(board, plank)
	for g: Vector3 in [Vector3(0.08, -3.5, 0.45), Vector3(0.5, -0.5, 0.42), Vector3(0.2, 3.0, 0.5)]:   # Vetas: (desde, y, largo)
		var x := board.position.x + 2.0 + (sw - 4.0) * g.x
		ci.draw_line(Vector2(x, y + g.y), Vector2(x + (sw - 4.0) * g.z, y + g.y), plank.darkened(0.1), 0.8)
	ci.draw_rect(board, ink, false, 1.2)
	if label != "":
		var base := y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		ci.draw_string(font, Vector2(-text_w * 0.5, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.1, 0.04))

## La letra del cartel: la de siempre pero más gruesa y con campo de distancia, así se ve
## nítida con cualquier zoom (la común, agrandada, se ve borrosa).
static func _hut_sign_font() -> Font:
	if _sign_font == null:
		var base := ThemeDB.fallback_font
		if base is FontFile:
			var msdf := (base as FontFile).duplicate() as FontFile
			msdf.multichannel_signed_distance_field = true
			base = msdf
		var bold := FontVariation.new()
		bold.base_font = base
		bold.variation_embolden = 0.5
		_sign_font = bold
	return _sign_font

## Una hoja en punta, con su nervadura.
static func _leaf(ci: CanvasItem, c: Vector2, angle: float, col: Color, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var s := i / 6.0 if i <= 6 else (12 - i) / 6.0
		var side := -1.0 if i <= 6 else 1.0
		pts.append(c + Vector2(lerpf(-5.0, 5.0, s), side * 2.2 * sin(PI * s)).rotated(angle))
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(ink, 0.8), 0.8, true)
	ci.draw_line(c + Vector2(-4.5, 0).rotated(angle), c + Vector2(4.5, 0).rotated(angle), col.darkened(0.3), 0.7, true)

## Un hueso de a a b, con dos bolitas en cada punta; k: qué tan grueso.
static func _bone(ci: CanvasItem, a: Vector2, b: Vector2, ink: Color, k := 1.0) -> void:
	var n := (b - a).normalized().orthogonal() * 1.3 * k
	for outline: bool in [true, false]:
		var col := ink if outline else Color(0.96, 0.93, 0.84)
		var grow := 0.9 if outline else 0.0
		ci.draw_line(a, b, col, (2.4 + grow * 2.0) * k, true)
		for e: Vector2 in [a, b]:
			for side: float in [-1.0, 1.0]:
				ci.draw_circle(e + n * side, (1.7 + grow) * k, col, true, -1.0, true)

## Altar de sacrificios: una mesa de piedra con runas sobre una tarima de dos escalones, una
## calavera con dos huesos cruzados entre las patas y dos braseros a los costados. lit: los
## braseros (0 apagados por la lluvia, 1 prendidos, más de 1 avivados por un ritual).
static func _paint_altar(ci: CanvasItem, t: float, lit: float) -> void:
	var ink := C_HUT_INK
	var stone := C_ALTAR_STONE
	var dark := stone.darkened(0.22)
	# La tarima, de dos escalones
	for r: Rect2 in [Rect2(-46, -8, 92, 8), Rect2(-38, -16, 76, 8)]:
		ci.draw_rect(r, stone if r.position.y < -8.0 else dark)
		ci.draw_line(r.position + Vector2(1.0, 1.2), Vector2(r.end.x - 1.0, r.position.y + 1.2), stone.lightened(0.18), 1.0)
		ci.draw_rect(r, ink, false, 1.2)
	# Las patas, y entre ellas la calavera
	for x: float in [-28.0, 16.0]:
		ci.draw_rect(Rect2(x, -34, 12, 18), dark)
		ci.draw_rect(Rect2(x, -34, 12, 18), ink, false, 1.2)
	for d: Vector2 in [Vector2(6, -5), Vector2(-6, -5)]:
		_bone(ci, Vector2(0, -25) - d, Vector2(0, -25) + d, ink, 0.6)
	_skull(ci, Vector2(0, -25), 5.0, ink)
	# La piedra de arriba, con runas talladas adelante
	var top := ALTAR_TOP
	var slab := Rect2(-36, top, 72, 10)
	ci.draw_rect(slab, stone)
	ci.draw_rect(Rect2(-36, top, 72, 3), stone.lightened(0.18))   # La cara de arriba
	for i in 5:
		var x := -28.0 + i * 14.0
		var rune := PackedVector2Array([Vector2(x - 2.5, top + 8.0), Vector2(x, top + 4.5), Vector2(x + 2.5, top + 8.0)]) \
				if i % 2 == 0 else PackedVector2Array([Vector2(x - 2.0, top + 4.5), Vector2(x + 2.0, top + 8.0), Vector2(x - 2.0, top + 8.0)])
		ci.draw_polyline(rune, dark.darkened(0.2), 1.0, true)
	ci.draw_rect(slab, ink, false, 1.2)
	# Los braseros
	for side: float in [-1.0, 1.0]:
		var x := side * 53.0
		ci.draw_rect(Rect2(x - 4.0, -30, 8, 30), dark)
		ci.draw_rect(Rect2(x - 4.0, -30, 8, 30), ink, false, 1.2)
		var bowl := PackedVector2Array()
		for i in 9:
			var a := PI * i / 8.0
			bowl.append(Vector2(x - cos(a) * 9.0, -36.0 + sin(a) * 6.0))
		ci.draw_colored_polygon(bowl, Color(0.62, 0.38, 0.16))
		bowl.append(bowl[0])
		ci.draw_polyline(bowl, ink, 1.2, true)
		ci.draw_colored_polygon(_ellipse(Vector2(x, -36.0), 8.0, 1.6), Color(0.4, 0.08, 0.04).lerp(Color(1.0, 0.45, 0.12), minf(lit, 1.0)))
		if lit > 0.05:
			_brazier_flame(ci, Vector2(x, -36.0), lit, t + side * 3.0)

## Las llamas de un brasero (k: qué tan grandes; más de 1, avivadas).
static func _brazier_flame(ci: CanvasItem, base: Vector2, k: float, t: float) -> void:
	var flick := 1.0 + sin(t * 17.0) * 0.08 + sin(t * 29.0) * 0.05
	var h := 9.0 * k * flick
	ci.draw_circle(base + Vector2(0, -h * 0.6), 9.0 * minf(k, 1.6), Color(1.0, 0.6, 0.2, 0.22 * minf(k, 1.0)), true, -1.0, true)
	ci.draw_colored_polygon(_ellipse(base + Vector2(0, -h * 0.8), 6.0 * minf(k, 1.6) * flick, h), Color(1.0, 0.48, 0.12))
	ci.draw_colored_polygon(_ellipse(base + Vector2(0, -h * 0.5), 3.0 * minf(k, 1.6), h * 0.55), Color(1.0, 0.92, 0.55))

## Una calavera chiquita, de frente.
static func _skull(ci: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	var bone := Color(0.96, 0.93, 0.84)
	var jaw := Rect2(c + Vector2(-r * 0.55, r * 0.4), Vector2(r * 1.1, r * 0.65))
	ci.draw_rect(jaw.grow(0.9), ink)
	ci.draw_circle(c, r + 0.9, ink, true, -1.0, true)
	ci.draw_rect(jaw, bone)
	ci.draw_circle(c, r, bone, true, -1.0, true)
	for side: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(side * r * 0.42, 0.05 * r), r * 0.28, ink, true, -1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.35), c + Vector2(-r * 0.15, r * 0.6), c + Vector2(r * 0.15, r * 0.6)]), ink)
	for i in 3:
		var x := c.x + lerpf(-r * 0.28, r * 0.28, i / 2.0)
		ci.draw_line(Vector2(x, jaw.position.y + 1.0), Vector2(x, jaw.end.y), ink, 0.6)

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

## Altar: el medio de la cara de arriba de la piedra, donde queda acostado el que sacrificás.
func altar_top() -> Vector2:
	return global_position + Vector2(0, LIFT + ALTAR_TOP * ALTAR_SCALE)

## Choza: el piso frente a la puerta, donde entra y sale el que vive ahí.
func door() -> Vector2:
	return global_position + Vector2(0, LIFT)

## Choza: el punto del piso que ocupa (del frente hasta HUT_DEPTH para atrás) más cerca de p.
## Para saber si la alcanzó el meteorito, el rayo o el tornado.
func footprint_point(p: Vector2) -> Vector2:
	var half := HUT_WALL.x * HUT_SCALE
	var base := door()
	return Vector2(clampf(p.x, base.x - half, base.x + half), clampf(p.y, base.y - HUT_DEPTH * HUT_SCALE, base.y))

## Choza: se rompe en pedacitos que salen volando desde from (ver HutDebris), con fuerza force
## (px/s) y burnt (0..1) de chamuscados. Los que estaban adentro salen de golpe (y los alcanza
## lo que la rompió) y todos se quedan sin casa. No devuelve nada: hay que comprar otra.
## Mientras la mueven de lugar no le pasa nada.
func smash(from: Vector2, force: float, burnt := 0.0) -> void:
	if not is_in_group("hut") or moving or is_queued_for_deletion():
		return
	for v in residents():
		v.lose_home()
	remove_from_group("hut")
	HutDebris.burst(self, from, force, burnt)
	queue_free()

## Choza: los que viven ahí (vivos).
func residents() -> Array[Villager]:
	var out: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.home == self and not v.dead and not v.eaten and not v.is_queued_for_deletion():
			out.append(v)
	return out

## Choza: cuántos más entran.
func free_beds() -> int:
	return HUT_BEDS - residents().size()

## Choza: la puerta se ilumina de noche si hay alguien adentro, y cada tanto se fija si la
## pareja que está adentro tiene un bebé.
func _update_hut(dt: float) -> void:
	var inside := residents().filter(func(v: Villager): return v.inside)
	_sleepers = inside.size()
	var night: float = _sky.night if _sky else 0.0
	_glow = move_toward(_glow, 1.0 if _sleepers > 0 and night > 0.5 else 0.0, dt * 1.5)
	_door_light.enabled = _glow > 0.01
	_door_light.energy = HUT_LIGHT_ENERGY * _glow
	queue_redraw()
	_birth_t -= dt
	if _birth_t > 0.0:
		return
	_birth_t = BIRTH_CHECK
	_try_birth(inside)

## Una pareja adentro (los dos grandes, sin gripe ni muertos de hambre y sin bebé reciente),
## con lugar en la choza y en la isla: a veces tiene un bebé, que nace adentro y vive con ellos.
func _try_birth(inside: Array) -> void:
	var world := get_parent().get_parent() as World   # La choza está en Props, adentro de World
	if world == null or free_beds() < 1 or world.alive_villagers() >= world.capacity():
		return
	for i in inside.size():
		for j in range(i + 1, inside.size()):
			var a: Villager = inside[i]
			var b: Villager = inside[j]
			if Relations.kind(a, b) == Relations.Kind.COUPLE and a.can_have_baby() and b.can_have_baby() \
					and randf() < BIRTH_CHANCE:
				_birth(world, a, b)
				return

func _birth(world: World, a: Villager, b: Villager) -> void:
	var baby := world.add_villager(door())
	baby.set_age(0.0)
	baby.inherit_looks(a, b)   # Parecido a sus padres
	baby.parents.assign([a.id_number, b.id_number])
	baby.faith = (a.faith + b.faith) * 0.5   # Cree en vos como sus padres
	baby.fear = 0.0
	baby.hunger = 0.0
	baby.last_name = a.last_name if a.last_name != "" else b.last_name
	baby.home = self
	baby.enter_home()   # Nace adentro
	for p: Villager in [a, b]:
		p.baby_cool = Villager.BABY_COOLDOWN
	Relations.note_birth(a, b)
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.popup_text("¡Nació un bebé!", get_global_transform_with_canvas().origin + Vector2(0, HUT_TOP * HUT_SCALE), Relations.color(Relations.Kind.COUPLE))
	for i in 4:
		var h := Coconut.Heart.new()
		get_parent().add_child(h)
		h.global_position = global_position + Vector2(randf_range(-16.0, 16.0), -20.0)
		h.delay = i * 0.15

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
		return point() + Vector2(side * 24.0, -Villager.BODY_BOTTOM * v.scale.y)

	## La baya se va achicando.
	func nibble(progress: float) -> void:
		bush._fruit_size[slot] = 1.0 - 0.7 * progress

	func finish_eating(v: Villager) -> void:
		bush.eat_berry(slot)
		super(v)

	func _lost_eater() -> void:
		bush.unreserve(slot)
		queue_free()
