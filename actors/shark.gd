extends Node2D
class_name Shark
## Tiburón: patrulla el agua (solo asoma la aleta) y se come a los aldeanos que están flotando.
## Arranca apagado: se compran en la tienda (hasta MAX) y se pueden apagar y prender.
## Se lo puede agarrar de la aleta y sacar del agua: cuelga y se sacude, se lo puede tirar
## y, si cae en la isla, va saltando con la boca abierta (y se come a los aldeanos que alcanza)
## hasta volver a caerse al agua.
## Con la pistola, el rayo o el meteorito se lo puede matar: queda panza arriba y hay que volver a comprarlo.
## El cuerpo es blando: el dibujo va en una malla que se dobla por la columna (cabeza y cola
## cuelgan, se quedan atrás con los tirones y rebotan al caer). Muerto queda todavía más flojo.

## Lo mataron (de un tiro, un rayo o un meteorito): el HUD lo da por perdido y hay que volver a comprarlo.
signal killed

const PRICE := 40
const MAX := 2

@export var water_path: NodePath
@export var patrol_speed := 60.0
@export var hunt_speed := 170.0
@export var bite_range := 16.0
@export var bite_cooldown := 1.5

enum State { SWIM, HELD, FLYING, LAND }

const TEXTURE := preload("res://actors/shark.png")
const SHADER := preload("res://actors/shark.gdshader")
const SPRITE_W := 150.0          # Ancho en pantalla del tiburón entero
# Referencias en píxeles del dibujo (mira a la izquierda)
const IMG_SURFACE_Y := 85.0      # Fila que queda en la línea del agua al nadar: asoma la aleta
const IMG_FIN := Rect2(200, 0, 100, 85)
const IMG_MOUTH := Vector2(100, 182)   # Centro de la boca abierta
# La boca (la abre shark.gdshader): la mandíbula gira alrededor de la comisura
const IMG_HINGE := Vector2(170, 176)   # Comisura
const IMG_SNOUT := Vector2(40, 170)    # Punta del hocico, arriba de la boca
const IMG_LIP := 112.0                 # Distancia de la comisura a la punta del labio de abajo
const DIVE_DEPTH := 30.0         # Cuánto baja al sumergirse (px en pantalla)

# Agarrado: cuelga de donde se lo agarró y se sacude
const GRAVITY := 1400.0
const SWING_K := 30.0
const SWING_DAMP := 2.0
const THRASH := 40.0             # Fuerza de los coletazos
const THRASH_FREQ := 13.0
const MAX_MOUSE_ACC := 6000.0
const THROW_SMOOTH := 25.0
const THROW_MIN_SPEED := 250.0
const THROW_MAX_SPEED := 1800.0
const LAND_DROP := 40.0          # Lanzado sobre la isla: cuánto baja antes de poder caer en ella

# En la isla: saltitos de pescado fuera del agua, con la boca abierta (la abre shark.gdshader)
const FLOP_GRAVITY := 900.0
const FLOP_EVERY := Vector2(0.35, 0.75)
const FLOP_HOP := Vector2(150.0, 230.0)
const JAW_OPEN := 0.55           # Apertura de la boca (radianes)
const JAW_SPEED := Vector2(6.0, 14.0)   # Qué tan rápido la abre y la cierra (rad/s)
const HUNT_RADIUS := 230.0       # Hasta dónde ve aldeanos para saltarles encima
const HUNT_HOP_SPEED := 190.0    # Velocidad máxima de un salto de caza
const LAND_BITE_REACH := Vector2(22.0, 18.0)   # Boca-aldeano: de costado y en profundidad

# Muerto a los tiros: panza arriba
const SHOT_FORCE := 260.0
const SHOT_HOP := 200.0          # Saltito en la arena con cada tiro
const IMG_BELLY_UP_Y := 175.0    # Flotando panza arriba: fila del dibujo que queda en la línea del agua
const DEAD_FLOAT_TIME := 2.5     # Flota un rato antes de hundirse
const DEAD_SINK_TIME := 2.2
const DEAD_LAND_TIME := 6.0      # Tirado en la isla antes de desvanecerse
const C_BLOOD := Color(0.8, 0.05, 0.05)
const C_SPARK := Color(1.0, 0.92, 0.55)
const C_CHARRED := Color(0.3, 0.27, 0.25)   # Achicharrado por un rayo
const C_SINGED := Color(0.62, 0.55, 0.5)    # Chamuscado por un meteorito
# Agujeros de bala: los mismos que en los aldeanos (VillagerRig.BulletMark), del mismo tamaño en
# pantalla (villager.png se ve a 0.079 y shark.png a SPRITE_W / 512 = 0.293)
const MARK_SCALE := 0.27
const MAX_MARKS := 10
# Muerto: ojo blanco con una cruz, como los aldeanos (VillagerRig.DeadEyes), en px del dibujo
const IMG_EYE := Vector2(116.5, 115.5)   # Centro del ojo
const EYE_RADIUS := 15.0                 # Hasta el contorno
const IMG_LID := [Vector2(100, 111), Vector2(128, 100)]   # Borde de abajo del párpado (el blanco no lo tapa)
const C_INK := Color(0.05, 0.05, 0.08)

# Cuerpo blando: el dibujo va en una malla de columnas que se doblan alrededor del centro.
# Todo en píxeles del dibujo (mira a la izquierda: la cabeza a la izquierda, la cola a la derecha).
const SPINE_Y := 140.0           # Fila de la columna vertebral
const SEG := 32.0                # Ancho de cada columna de la malla
const MESH_ROWS: Array[float] = [0.0, 70.0, 140.0, 205.0, 270.0, 340.0]   # La última, debajo del dibujo: ahí cae la mandíbula abierta
# Articulaciones, del centro hacia afuera: qué segmentos de la malla doblan, de qué lado
# (-1 cabeza, 1 cola), cuánto les afecta la inercia y cuánto coletean.
const JOINT_SEGS := [[6, 7], [8, 9], [10, 11], [12, 13], [14, 15]]
const JOINT_SIDE: Array[float] = [-1.0, 1.0, 1.0, 1.0, 1.0]
const JOINT_GAIN: Array[float] = [0.6, 1.0, 1.0, 1.1, 1.2]
const JOINT_WAVE: Array[float] = [0.3, 0.45, 0.7, 0.9, 1.0]
const JOINT_MAX: Array[float] = [0.3, 0.4, 0.45, 0.5, 0.55]   # Doblez máximo de cada una (rad)
const BEND_GAIN := 1.0 / 80.0    # Cuánto dobla un tirón (rad/s por px/s)
const BEND_ROT := 0.8            # Cuánto se queda atrás cuando el cuerpo gira de golpe
const BEND_K := 140.0            # Resorte que lo endereza
const BEND_DAMP := 7.0
const BEND_K_DEAD := 45.0        # Muerto: un trapo
const BEND_DAMP_DEAD := 3.5
const BEND_MAX_DV := 900.0       # Tope de un tirón por cuadro (px/s)
const GROUND_SAG := 0.2          # Apoyado en la arena casi no se le cae la cabeza ni la cola

## Para saber si un tiro cae sobre el dibujo o en lo transparente.
static var _alpha: Image
## Qué píxeles del dibujo son la mandíbula de abajo (ver _make_jaw_mask).
static var _jaw_mask: ImageTexture

var water_rect := Rect2(0, 570, 1150, 76)
var dir := 1.0
var _t := 0.0
var _cooldown := 0.0
var _dive := 0.0   # 0 = aleta afuera, 1 = sumergida (mientras muerde)
var active := false
var dead := false
var _tween: Tween

var state := State.SWIM
var _world: Node2D              # En la isla se muda a la capa ordenada por Y (Props)
var _sprite: Node2D              # Dibuja la malla (en píxeles del dibujo, centrada)
var _material: ShaderMaterial
var _tex: Texture2D = TEXTURE    # El dibujo de este tiburón: con los balazos, una copia pintada
var _marked: Image               # La copia, si ya le pegaron
var _marks := 0
var _k := 1.0                    # Escala del dibujo
var _mouth := Vector2.ZERO       # Centro de la boca (local, mirando a la izquierda)
var _jaw := 0.0                  # Apertura actual de la boca
var _chomp := 0.0                # Recién mordió: la boca queda cerrada un rato
var _prey: Villager              # En la isla: el aldeano al que le está saltando encima
var _roll := 0.0                 # 0 = derecho, 1 = panza arriba
var _dead_t := 0.0               # Desde que cayó muerto al agua (la mancha de sangre crece)
var _pooled := false             # Ya dejó su charco de sangre en la arena

var _cols := 0                   # Segmentos de la malla (columnas - 1)
var _bend := PackedFloat32Array()        # Doblez de cada articulación
var _bend_vel := PackedFloat32Array()
var _spine := PackedVector2Array()       # Por columna: punto de la columna (malla, centrada)
var _col_ang := PackedFloat32Array()     # Por columna: cuánto giró
var _mesh_pts := PackedVector2Array()
var _mesh_uvs := PackedVector2Array()
var _mesh_cols := PackedColorArray()
var _mesh_idx := PackedInt32Array()
var _prev_pos := Vector2.ZERO            # Para medir los tirones
var _prev_vel := Vector2.ZERO
var _prev_hand := Vector2.ZERO
var _prev_hand_vel := Vector2.ZERO
var _prev_rot := 0.0
var _prev_spin := 0.0
var _jolt_reset := true
var _thrash := 1.0               # Agarrado: qué tan fuerte se sacude ahora (va a rachas)
var _thrash_goal := 1.0
var _thrash_t := 0.0

var _grab_tex := Vector2.ZERO    # Punto del dibujo del que está agarrado
var _swing_vel := 0.0
var _prev_mouse := Vector2.ZERO
var _mouse_vel := Vector2.ZERO
var _mouse_acc := Vector2.ZERO
var _throw_vel := Vector2.ZERO

var _vel := Vector2.ZERO
var _spin := 0.0
var _launch_y := 0.0
var _left_island := false

var _ground := Vector2.ZERO      # En la isla: punto del piso (la altura del salto va aparte)
var _h := 0.0
var _hv := 0.0
var _ground_vel := Vector2.ZERO
var _flop_t := 0.0

func _ready() -> void:
	add_to_group("shark")
	var water := get_node_or_null(water_path)
	if water and water.has_method("get_global_rect"):
		water_rect = water.get_global_rect()
	global_position = Vector2(randf_range(_left(), _right()), water_rect.position.y)
	dir = 1.0 if randf() < 0.5 else -1.0
	_world = get_parent()

	_k = SPRITE_W / TEXTURE.get_width()
	_mouth = (IMG_MOUTH - TEXTURE.get_size() * 0.5) * _k
	if _alpha == null:
		_alpha = TEXTURE.get_image()
		_jaw_mask = _make_jaw_mask(_alpha)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("jaw_mask", _jaw_mask)
	_material.set_shader_parameter("hinge", IMG_HINGE)
	_material.set_shader_parameter("snout", IMG_SNOUT)
	_sprite = Node2D.new()
	_sprite.scale = Vector2.ONE * _k
	_sprite.material = _material
	_sprite.draw.connect(_draw_body)
	# Interno: así world.gd puede duplicar el tiburón sin copiar este sprite
	add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)
	_setup_mesh()

	visible = false
	set_process(false)

## Mandíbula de abajo: lo que queda debajo de la línea comisura-hocico, pero siguiendo el
## zigzag de los dientes: los de arriba cuelgan por debajo de la línea y se quedan en la cabeza,
## los de abajo asoman por encima y se van con la mandíbula. Blanco = mandíbula, gris = se borra.
static func _make_jaw_mask(img: Image) -> ImageTexture:
	var size := img.get_size()
	var mask := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	var ax := (IMG_SNOUT - IMG_HINGE).normalized()
	var down := Vector2(ax.y, -ax.x)
	var x0 := int(IMG_SNOUT.x - 4.0)
	var x1 := int(IMG_HINGE.x + 2.0)
	var y0 := int(minf(IMG_HINGE.y, IMG_SNOUT.y) - 30.0)
	for y in range(y0, size.y):
		for x in range(x0, x1):
			var rel := Vector2(x, y) + Vector2(0.5, 0.5) - IMG_HINGE
			var along := rel.dot(ax)
			if along > 0.0 and along < IMG_LIP + 4.0 and rel.dot(down) > 0.0:
				mask.set_pixel(x, y, Color.WHITE)

	# Dientes: manchas color hueso cerca de la línea. Los de arriba son triángulos con la punta
	# para abajo (más anchos arriba) o están bien por encima de la línea.
	var band := Rect2i(x0, y0, x1 - x0, 60)
	var owner := {}   # Píxel -> true si es de la mandíbula
	for y in range(band.position.y, band.end.y):
		for x in range(band.position.x, band.end.x):
			var start := Vector2i(x, y)
			if owner.has(start) or not _is_tooth(img, start):
				continue
			var pts: Array[Vector2i] = [start]
			owner[start] = false
			var i := 0
			while i < pts.size():
				for n: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var q := pts[i] + n
					if band.has_point(q) and not owner.has(q) and _is_tooth(img, q):
						owner[q] = false
						pts.append(q)
				i += 1
			var top_y := pts[0].y
			var bottom_y := pts[0].y
			var center := Vector2.ZERO
			for q in pts:
				top_y = mini(top_y, q.y)
				bottom_y = maxi(bottom_y, q.y)
				center += Vector2(q)
			center /= pts.size()
			var top := 0
			var bottom := 0
			for q in pts:
				top += int(q.y <= top_y + 1)
				bottom += int(q.y >= bottom_y - 1)
			var upper := top > bottom or (center - IMG_HINGE).dot(down) < -6.0
			for q in pts:
				owner[q] = not upper
	# Los contornos y la encía van con lo que tengan más cerca: primero se expanden los dientes
	# (así se llevan su contorno entero) y después entra también la piel de cada labio (la de
	# abajo de la línea es de la mandíbula).
	var front: Array = owner.keys()
	for step in 9:
		if step == 3:
			for y in range(band.position.y, band.end.y):
				for x in range(band.position.x, band.end.x):
					var p := Vector2i(x, y)
					var c := img.get_pixelv(p)
					if owner.has(p) or c.a <= 0.5 or c.b < c.r - 0.02 or maxf(c.r, maxf(c.g, c.b)) < 0.35:
						continue
					owner[p] = mask.get_pixelv(p).r > 0.5
					front.append(p)
		var next: Array = []
		for q: Vector2i in front:
			for n: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var r: Vector2i = q + n
				if band.has_point(r) and not owner.has(r) and img.get_pixelv(r).a > 0.01:
					owner[r] = owner[q]
					next.append(r)
		front = next
	for q: Vector2i in owner:
		mask.set_pixelv(q, Color.WHITE if owner[q] else Color.BLACK)
	# Puntitos casi transparentes sueltos (restos del recorte del dibujo): con la boca cerrada no
	# se ven, pero abierta quedarían flotando entre los dientes. Gris = no se dibujan.
	for y in range(band.position.y, band.end.y):
		for x in range(band.position.x, band.end.x):
			var a := img.get_pixel(x, y).a
			if a <= 0.0 or a >= 0.25:
				continue
			var loose := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if img.get_pixel(clampi(x + dx, 0, size.x - 1), clampi(y + dy, 0, size.y - 1)).a > 0.5:
						loose = false
			if loose:
				mask.set_pixel(x, y, Color(0.5, 0.5, 0.5))
	return ImageTexture.create_from_image(mask)

static func _is_tooth(img: Image, p: Vector2i) -> bool:
	var c := img.get_pixelv(p)
	return c.a > 0.5 and c.r > 0.59 and c.g > 0.51 and c.r - c.b > 0.01

## Prendido: emerge en un lugar al azar del agua. Apagado: se sumerge y deja de cazar.
## Si lo vuelven a comprar mientras todavía se está muriendo, sale uno nuevo.
func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if state != State.SWIM:
		_back_to_water(false)
	if dead:
		_revive()
	if on:
		global_position.x = randf_range(_left(), _right())
		_jolt_reset = true
		_dive = 1.0
		visible = true
		set_process(true)
		_tween.tween_property(self, "_dive", 0.0, 0.5)
	else:
		_tween.tween_property(self, "_dive", 1.0, 0.3)
		_tween.tween_callback(func():
			visible = false
			set_process(false))

func _left() -> float:
	return water_rect.position.x + 20.0

func _right() -> float:
	return water_rect.end.x - 20.0

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	_chomp -= dt
	_dead_t += dt
	match state:
		State.SWIM:
			_swim(dt)
		State.HELD:
			_hold(dt)
		State.FLYING:
			_fly(dt)
		State.LAND:
			_flop(dt)
	_update_jaw(dt)
	_update_bend(dt)
	_update_sprite()
	queue_redraw()

func _swim(dt: float) -> void:
	if dead:
		# Panza arriba: flota quieto entre la sangre
		global_position.y = water_rect.position.y + 3.0 + sin(_t * 2.0) * 1.5
		return
	var speed := patrol_speed
	var prey := _find_prey() if active and _cooldown <= 0.0 else null
	if prey:
		var dx := prey.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = signf(dx)
		speed = hunt_speed
		if absf(dx) < bite_range:
			_bite(prey)

	global_position.x += dir * speed * dt
	if global_position.x < _left():
		dir = 1.0
	elif global_position.x > _right():
		dir = -1.0
	global_position.x = clampf(global_position.x, _left(), _right())
	global_position.y = water_rect.position.y + 3.0 + sin(_t * 3.0) * 2.0

## Nadando el dibujo se corre hacia abajo y el agua lo corta: solo se ve la aleta
## (o la panza, si está muerto).
func _update_sprite() -> void:
	_place_sprite()
	_material.set_shader_parameter("cut", state == State.SWIM)
	_material.set_shader_parameter("water_y", water_rect.position.y + 4.0)
	_material.set_shader_parameter("jaw", _jaw)
	_build_mesh()
	_sprite.queue_redraw()

## El dibujo mira a la izquierda: dado vuelta en X cuando va a la derecha, y en Y cuando
## rueda panza arriba.
func _place_sprite() -> void:
	_sprite.scale = Vector2(-_k if dir > 0.0 else _k, _k * cos(_roll * PI))
	_sprite.position = Vector2(0, _swim_offset()) if state == State.SWIM else Vector2.ZERO

## Nadando: distancia del centro del cuerpo por debajo del nodo (que va en la superficie).
func _swim_offset() -> float:
	var fin_up := (TEXTURE.get_height() * 0.5 - IMG_SURFACE_Y) * _k
	var belly_up := (IMG_BELLY_UP_Y - TEXTURE.get_height() * 0.5) * _k
	return lerpf(fin_up, belly_up, _roll) + _dive * DIVE_DEPTH

## En la isla abre la boca en cada salto: del todo si va a comerse a alguien.
## Agarrado o por el aire tira tarascones.
func _update_jaw(dt: float) -> void:
	var target := 0.0
	if dead:
		target = JAW_OPEN * 0.25   # Muerto, con la boca floja
	elif state == State.LAND and (_h > 0.0 or _hv > 0.0) and _chomp <= 0.0:
		target = JAW_OPEN if is_instance_valid(_prey) else JAW_OPEN * 0.7
	elif state == State.HELD or state == State.FLYING:
		target = JAW_OPEN * clampf(0.2 + sin(_t * 4.5) * 1.2, 0.0, 1.0)
	_jaw = move_toward(_jaw, target, (JAW_SPEED.x if target > _jaw else JAW_SPEED.y) * dt)

# ---- Cuerpo blando ----
func _setup_mesh() -> void:
	var size := TEXTURE.get_size()
	_cols = int(size.x / SEG)
	_bend.resize(JOINT_SEGS.size())
	_bend_vel.resize(JOINT_SEGS.size())
	_spine.resize(_cols + 1)
	_col_ang.resize(_cols + 1)
	var rows := MESH_ROWS.size()
	_mesh_pts.resize((_cols + 1) * rows)
	_mesh_cols.resize(_mesh_pts.size())
	_mesh_cols.fill(Color.WHITE)
	for c in _cols + 1:
		for r in rows:
			_mesh_uvs.append(Vector2(c * SEG, MESH_ROWS[r]) / size)
	for c in _cols:
		for r in rows - 1:
			var a := c * rows + r
			var b := a + rows
			_mesh_idx.append_array([a, b, b + 1, a, b + 1, a + 1])
	_build_mesh()

## Mueve las articulaciones: cada una es un péndulo con resorte que siente los tirones del
## cuerpo (y la gravedad, si nada lo sostiene). Todo en el marco del dibujo.
func _update_bend(dt: float) -> void:
	if dt <= 0.0:
		return
	var hand := get_global_mouse_position() if state == State.HELD else global_position
	var vel := (global_position - _prev_pos) / dt
	var hand_vel := (hand - _prev_hand) / dt
	var spin := angle_difference(_prev_rot, rotation) / dt
	var dv := (vel - _prev_vel).limit_length(BEND_MAX_DV)
	var hand_dv := (hand_vel - _prev_hand_vel).limit_length(BEND_MAX_DV)
	var dw := clampf(spin - _prev_spin, -15.0, 15.0)
	if _jolt_reset or global_position.distance_to(_prev_pos) > 60.0:
		_jolt_reset = false
		vel = Vector2.ZERO
		hand_vel = Vector2.ZERO
		spin = 0.0
		dv = Vector2.ZERO
		hand_dv = Vector2.ZERO
		dw = 0.0
	_prev_pos = global_position
	_prev_vel = vel
	_prev_hand = hand
	_prev_hand_vel = hand_vel
	_prev_rot = rotation
	_prev_spin = spin

	var g := 0.0   # En el agua flota
	match state:
		State.HELD, State.FLYING:
			g = GRAVITY
		State.LAND:
			g = FLOP_GRAVITY if (_h > 0.0 or _hv > 0.0) else FLOP_GRAVITY * GROUND_SAG
	var sx := signf(_sprite.scale.x)
	var sy := 1.0 if _sprite.scale.y >= 0.0 else -1.0
	var kick := _to_body(Vector2(0.0, g * dt) - dv, sx, sy)
	var hand_kick := _to_body(Vector2(0.0, g * dt) - hand_dv, sx, sy)
	dw *= sx * sy
	spin *= sx * sy

	if state == State.HELD and not dead:
		_thrash_t -= dt
		if _thrash_t <= 0.0:
			_thrash_t = randf_range(0.3, 1.0)
			_thrash_goal = randf_range(0.2, 1.0)
		_thrash = move_toward(_thrash, _thrash_goal, 3.0 * dt)
	var k := BEND_K_DEAD if dead else BEND_K
	var damp := BEND_DAMP_DEAD if dead else BEND_DAMP
	var base := PackedFloat32Array([0.0, 0.0])   # Lo que ya giró la cadena de cada lado (cabeza, cola)
	for j in JOINT_SEGS.size():
		var side := JOINT_SIDE[j]
		var s := 0 if side < 0.0 else 1
		var dir_out := Vector2(side, 0.0).rotated(base[s] + _bend[j] * 0.5)
		var at := Vector2(_joint_start(j) * _k, 0.0)   # Desde el centro, en pantalla
		var w := _bend_vel[j]
		if _held_between(j):
			# Entre el centro y la mano: el que cuelga de acá es el resto del cuerpo, y lo que
			# siente son los tirones de la mano
			w += JOINT_GAIN[j] * BEND_GAIN * dir_out.cross(hand_kick)
		else:
			w += JOINT_GAIN[j] * BEND_GAIN * dir_out.cross(kick + at * spin * spin * dt)
			w -= dw * BEND_ROT
		w += (-k * (_bend[j] - _wave(j)) - damp * w) * dt
		var a := _bend[j] + w * dt
		if absf(a) > JOINT_MAX[j]:
			a = clampf(a, -JOINT_MAX[j], JOINT_MAX[j])
			w *= -0.3   # Rebota contra el tope
		_bend[j] = a
		_bend_vel[j] = w
		base[s] += a

## Coletazos: una onda que corre de la cabeza a la cola.
func _wave(j: int) -> float:
	if dead:
		return 0.0
	var amp := 0.0
	var freq := 0.0
	match state:
		State.HELD:
			amp = 0.32 * _thrash
			freq = THRASH_FREQ
		State.FLYING:
			amp = 0.2
			freq = THRASH_FREQ
		State.LAND:
			if _h > 0.0 or _hv > 0.0:
				amp = 0.1
				freq = 10.0
			else:
				amp = 0.35
				freq = 18.0
		State.SWIM:
			amp = 0.12
			freq = 7.0
	return amp * JOINT_WAVE[j] * sin(_t * freq - j * 0.9)

## Mundo -> marco del dibujo (sin girar, mirando a la izquierda y panza abajo).
func _to_body(v: Vector2, sx: float, sy: float) -> Vector2:
	v = v.rotated(-rotation)
	return Vector2(v.x * sx, v.y * sy)

## Agarrado de un punto lejos del centro: ¿la articulación queda entre el centro y la mano?
func _held_between(j: int) -> bool:
	if state != State.HELD:
		return false
	var off := _grab_tex.x - _cols * SEG * 0.5
	return signf(off) == JOINT_SIDE[j] and absf(off) > absf(_joint_start(j)) + 4.0

## Dónde empieza a doblar la articulación (del lado del centro), en píxeles del dibujo desde el centro.
func _joint_start(j: int) -> float:
	var segs: Array = JOINT_SEGS[j]
	var col: int = segs.max() + 1 if JOINT_SIDE[j] < 0.0 else segs.min()
	return col * SEG - _cols * SEG * 0.5

## Arma la malla doblada: cada columna gira lo que suman las articulaciones desde el centro.
func _build_mesh() -> void:
	var inc := PackedFloat32Array()
	inc.resize(_cols)
	for j in JOINT_SEGS.size():
		var segs: Array = JOINT_SEGS[j]
		for s: int in segs:
			inc[s] += _bend[j] / segs.size()
	var mid := int(_cols / 2.0)
	var turn := PackedFloat32Array()   # Por segmento: cuánto giró
	turn.resize(_cols)
	var acc := 0.0
	for s in range(mid, _cols):
		acc += inc[s]
		turn[s] = acc
	acc = 0.0
	for s in range(mid - 1, -1, -1):
		acc += inc[s]
		turn[s] = acc

	var half := TEXTURE.get_size() * 0.5
	_spine[mid] = Vector2(mid * SEG, SPINE_Y) - half
	_col_ang[mid] = 0.0
	for c in range(mid + 1, _cols + 1):
		_spine[c] = _spine[c - 1] + Vector2.from_angle(turn[c - 1]) * SEG
		_col_ang[c] = turn[c - 1] if c == _cols else (turn[c - 1] + turn[c]) * 0.5
	for c in range(mid - 1, -1, -1):
		_spine[c] = _spine[c + 1] - Vector2.from_angle(turn[c]) * SEG
		_col_ang[c] = turn[c] if c == 0 else (turn[c] + turn[c - 1]) * 0.5

	var rows := MESH_ROWS.size()
	for c in _cols + 1:
		var n := Vector2.from_angle(_col_ang[c] + PI * 0.5)
		for r in rows:
			_mesh_pts[c * rows + r] = _spine[c] + n * (MESH_ROWS[r] - SPINE_Y)

func _draw_body() -> void:
	RenderingServer.canvas_item_add_triangle_array(_sprite.get_canvas_item(), _mesh_idx, _mesh_pts,
			_mesh_cols, _mesh_uvs, PackedInt32Array(), PackedFloat32Array(), _tex.get_rid())

## Punto del dibujo (en píxeles) -> dónde quedó en la malla doblada.
func _deform(t: Vector2) -> Vector2:
	var f := clampf(t.x / SEG, 0.0, _cols - 0.001)
	var c := int(f)
	var u := f - c
	var a := lerpf(_col_ang[c], _col_ang[c + 1], u)
	return _spine[c].lerp(_spine[c + 1], u) + Vector2.from_angle(a + PI * 0.5) * (t.y - SPINE_Y)

## Al revés: punto de la malla doblada -> qué píxel del dibujo cae ahí.
## Prueba cada segmento, se queda con el que mejor cae y lo afina (en las curvas,
## lejos de la columna, los segmentos se superponen).
func _undeform(p: Vector2) -> Vector2:
	var best := p + TEXTURE.get_size() * 0.5
	var best_err := _deform(best).distance_squared_to(p)
	for s in _cols:
		var d := (_spine[s + 1] - _spine[s]) / SEG
		var rel := p - _spine[s]
		var along := rel.dot(d)
		if along < -SEG * 0.5 or along > SEG * 1.5:
			continue
		var t := Vector2(s * SEG + along, SPINE_Y + d.cross(rel))
		var err := _deform(t).distance_squared_to(p)
		if err < best_err:
			best = t
			best_err = err
	for i in 4:
		var f := clampf(best.x / SEG, 0.0, _cols - 0.001)
		var c := int(f)
		var a := lerpf(_col_ang[c], _col_ang[c + 1], f - c)
		var t := best + (p - _deform(best)).rotated(-a)
		var err := _deform(t).distance_squared_to(p)
		if err >= best_err:
			break
		best = t
		best_err = err
	return best

## Punto del nodo -> píxel del dibujo.
func _local_to_texture(local: Vector2) -> Vector2:
	return _undeform(_sprite.transform.affine_inverse() * local)

## Píxel del dibujo -> punto del nodo.
func _texture_to_local(t: Vector2) -> Vector2:
	return _sprite.transform * _deform(t)

func _find_prey() -> Villager:
	var best: Villager = null
	var best_d := INF
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if villager == null or not villager.in_water or villager.drowning or villager.dragging or villager.eaten:
			continue
		var d := absf(villager.global_position.x - global_position.x)
		if d < best_d:
			best_d = d
			best = villager
	return best

func _bite(prey: Villager) -> void:
	prey.get_eaten()
	_cooldown = bite_cooldown
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_dive", 1.0, 0.15)
	_tween.tween_interval(0.6)
	_tween.tween_property(self, "_dive", 0.0, 0.4)

func _draw() -> void:
	if state != State.SWIM:
		return
	if dead:
		# Mancha de sangre en el agua
		var r := minf(_dead_t * 50.0, 60.0)
		draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, r, Color(C_BLOOD, 0.45), true, -1.0, true)
		draw_circle(Vector2(r * 0.3, 0.0), r * 0.6, Color(C_BLOOD.darkened(0.2), 0.4), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		return
	# Estela de espuma
	var k := 1.0 - _dive
	if k <= 0.02:
		return
	var foam := Color(1, 1, 1, 0.6 * k)
	var wobble := sin(_t * 8.0) * 2.0
	draw_line(Vector2(-dir * 16.0, 1), Vector2(-dir * (34.0 + wobble), 2), foam, 2.0)
	draw_line(Vector2(dir * 16.0, 1), Vector2(dir * 22.0, 0), foam, 2.0)

# ---- Agarrarlo ----
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if not active or state == State.HELD or HUD.aiming() or get_tree().paused:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	var m := get_global_mouse_position()
	if not _hit(m) or _villager_at(m):
		return
	_start_hold(m)
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Atrapa el soltado del click izquierdo en cualquier parte de la pantalla
	if state == State.HELD and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release()
		get_viewport().set_input_as_handled()

## ¿El punto toca al tiburón? Nadando solo cuenta la aleta (con margen, que se mueve rápido).
func _hit(p: Vector2) -> bool:
	if state == State.SWIM:
		if _dive > 0.6:
			return false
		var fin := Rect2(IMG_FIN.position * _k, IMG_FIN.size * _k)
		fin.position -= TEXTURE.get_size() * 0.5 * _k
		fin.position.y += _swim_offset()
		if dir > 0.0:
			fin.position.x = -fin.end.x
		return fin.grow(10.0).has_point(p - global_position)
	var body := Rect2(-TEXTURE.get_size() * 0.5 * _k, TEXTURE.get_size() * _k).grow(-8.0)
	return body.has_point(to_local(p))

## Agarrar aldeanos tiene prioridad (uno flotando encima de la aleta).
func _villager_at(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collide_with_bodies = true
	for r in get_world_2d().direct_space_state.intersect_point(q, 8):
		if r.collider is Villager and not r.collider.eaten:
			return true
	return false

func _start_hold(m: Vector2) -> void:
	if _tween:
		_tween.kill()
	if state == State.SWIM:
		# Sale del agua: el nodo pasa a estar en el centro del cuerpo
		global_position.y += _swim_offset()
		_dive = 0.0
		rotation = 0.0
		_splash(Vector2(global_position.x, water_rect.position.y), 26)
	_set_on_land_layer(false)
	state = State.HELD
	_prey = null
	_place_sprite()
	_grab_tex = _local_to_texture(to_local(m))
	_thrash = 1.0
	_jolt_reset = true
	_prev_mouse = m
	_mouse_vel = Vector2.ZERO
	_mouse_acc = Vector2.ZERO
	_throw_vel = Vector2.ZERO
	_swing_vel = 0.0
	z_index = 10

func _hold(dt: float) -> void:
	var m := get_global_mouse_position()
	if dt > 0.0:
		var mv := (m - _prev_mouse) / dt
		var ma := ((mv - _mouse_vel) / dt).limit_length(MAX_MOUSE_ACC)
		_mouse_vel = mv
		_mouse_acc = _mouse_acc.lerp(ma, 0.35)
		_throw_vel = _throw_vel.lerp(mv, 1.0 - exp(-THROW_SMOOTH * dt))
	_prev_mouse = m

	# Cuelga como péndulo del punto agarrado y encima se sacude a coletazos
	var grab := _texture_to_local(_grab_tex)
	var g := Vector2(0.0, GRAVITY) - _mouse_acc
	var r := (-grab).rotated(rotation)
	if r.length() > 4.0:
		_swing_vel += SWING_K * r.normalized().cross(g / GRAVITY) * dt
	_swing_vel += sin(_t * THRASH_FREQ) * THRASH * _thrash * dt
	_swing_vel *= exp(-SWING_DAMP * dt)
	rotation += _swing_vel * dt
	global_position = m - grab.rotated(rotation)

func _release() -> void:
	var throw := _throw_vel.limit_length(THROW_MAX_SPEED)
	if throw.length() < THROW_MIN_SPEED and _on_island(global_position):
		_start_land()
		return
	state = State.FLYING
	_vel = throw if throw.length() >= THROW_MIN_SPEED else Vector2.ZERO
	_spin = clampf(_swing_vel + _vel.x * 0.004, -10.0, 10.0)
	_launch_y = global_position.y
	_left_island = not _on_island(global_position)

# ---- Volando ----
func _fly(dt: float) -> void:
	_vel.y += GRAVITY * dt
	global_position += _vel * dt
	rotation += _spin * dt

	var view := get_viewport().get_visible_rect()
	var half_w := SPRITE_W * 0.5
	if (global_position.x < view.position.x + half_w and _vel.x < 0.0) \
			or (global_position.x > view.end.x - half_w and _vel.x > 0.0):
		_vel.x *= -0.5
		_spin *= -0.6

	if _on_island(global_position):
		if _vel.y > 0.0 and (_left_island or global_position.y - _launch_y > LAND_DROP):
			_start_land()
	else:
		_left_island = true
		if global_position.y >= water_rect.position.y + 8.0 and _vel.y > 0.0:
			_back_to_water(true)

# ---- En la isla ----
func _start_land() -> void:
	state = State.LAND
	_ground = global_position
	_h = 0.0
	_hv = 0.0
	_ground_vel = Vector2.ZERO
	_flop_t = randf_range(0.2, 0.4)
	z_index = 0
	_set_on_land_layer(true)
	_puff(_ground + Vector2(0, 14), Color(0.93, 0.8, 0.55), 14)
	if dead:
		_die_on_land()

func _flop(dt: float) -> void:
	if _h > 0.0 or _hv > 0.0:
		_hv -= FLOP_GRAVITY * dt
		_h += _hv * dt
		_ground += _ground_vel * dt
		var tilt := 0.0 if dead else -dir * 0.35 * signf(_hv)
		rotation = lerp_angle(rotation, tilt, 8.0 * dt)
		if _h <= 0.0:
			_h = 0.0
			_hv = 0.0
			_ground_vel = Vector2.ZERO
			_puff(_ground + Vector2(0, 14), Color(0.93, 0.8, 0.55), 8)
			if dead:
				_bleed_on_sand()
	elif dead:
		rotation = lerp_angle(rotation, 0.0, 10.0 * dt)
	else:
		# Tirado en la arena: coletea (lo dobla _wave) y cada tanto pega un salto
		rotation = lerp_angle(rotation, sin(_t * 18.0) * 0.04, 12.0 * dt)
		_flop_t -= dt
		if _flop_t <= 0.0:
			_flop_t = randf_range(FLOP_EVERY.x, FLOP_EVERY.y)
			_hop()
	global_position = _ground - Vector2(0, _h)
	if not dead:
		_bite_on_land()

	# Se salió de la isla de un salto: se cae
	if not _on_island(_ground):
		_set_on_land_layer(false)
		z_index = 10
		state = State.FLYING
		_vel = Vector2(_ground_vel.x, -_hv)
		_spin = dir * 3.0
		_left_island = true
		_launch_y = global_position.y

## Salta hacia el aldeano más cercano para caerle con la boca encima.
## Si no ve a nadie salta para cualquier lado (casi siempre hacia el agua).
func _hop() -> void:
	_hv = randf_range(FLOP_HOP.x, FLOP_HOP.y)
	_prey = _find_land_prey() if _cooldown <= 0.0 else null
	if _prey == null:
		dir = 1.0 if randf() < 0.5 else -1.0
		_ground_vel = Vector2(dir * randf_range(20.0, 60.0), randf_range(30.0, 70.0))
		return
	var to_x := _prey.global_position.x - _ground.x
	if absf(to_x) > 4.0:
		dir = signf(to_x)
	var target := Vector2(_prey.global_position.x + dir * _mouth.x, _prey.global_position.y)
	var air_time := 2.0 * _hv / FLOP_GRAVITY
	_ground_vel = ((target - _ground) / air_time).limit_length(HUNT_HOP_SPEED)

func _is_land_prey(v: Villager) -> bool:
	return v != null and not (v.dragging or v.falling or v.in_water or v.eaten) and _on_island(v.global_position)

func _find_land_prey() -> Villager:
	var best: Villager = null
	var best_d := HUNT_RADIUS
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if not _is_land_prey(villager):
			continue
		var d := villager.global_position.distance_to(_ground)
		if d < best_d:
			best_d = d
			best = villager
	return best

## Con la boca abierta, se come al aldeano que le queda adentro.
func _bite_on_land() -> void:
	if _cooldown > 0.0 or _jaw < JAW_OPEN * 0.5:
		return
	var mouth := _mouth_global()
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if not _is_land_prey(villager):
			continue
		if absf(villager.global_position.x - mouth.x) < LAND_BITE_REACH.x \
				and absf(villager.global_position.y - _ground.y) < LAND_BITE_REACH.y:
			villager.get_eaten(mouth)
			_cooldown = bite_cooldown
			_chomp = 0.3
			_prey = null
			_flop_t = randf_range(0.6, 0.9)   # Se queda masticando un momento
			return

func _mouth_global() -> Vector2:
	return to_global(_texture_to_local(IMG_MOUTH))

# ---- A los tiros ----
## ¿Un tiro en este punto le pega? Nadando, solo en la aleta; si no, sobre el dibujo
## (lo transparente no cuenta).
func is_shot_at(p: Vector2) -> bool:
	if not visible or not (active or dead) or modulate.a < 0.3:
		return false
	if state == State.SWIM:
		if not dead:
			return _hit(p)
		if p.y > water_rect.position.y + 4.0:
			return false   # Flotando panza arriba: lo que está bajo el agua no se ve
	if absf(_sprite.scale.y) < 0.05:
		return false
	var px := _local_to_texture(to_local(p))
	if not Rect2(Vector2.ZERO, TEXTURE.get_size()).has_point(px):
		return false
	return _alpha.get_pixelv(Vector2i(px)).a > 0.5

## Si se dibuja delante del aldeano (para saber a cuál de los dos le pega un tiro).
func is_in_front_of(v: Villager) -> bool:
	if state == State.SWIM or v.z_index > z_index:
		return false   # En el agua los aldeanos flotan por encima de él
	if v.z_index < z_index:
		return true
	return state == State.LAND and global_position.y >= v.global_position.y

## Le pegaron un tiro (ver Gun): se muere y hay que volver a comprarlo en la tienda.
## Muerto se lo puede seguir baleando: sangra y, en la isla, salta con cada tiro.
func shoot(at: Vector2, shot_dir: Vector2) -> void:
	_puff(at, C_BLOOD, 30, 260.0, shot_dir)
	_add_bullet_mark(at)
	_kill(shot_dir.normalized() * SHOT_FORCE)

## Le cayó un rayo, o lo agarró la descarga en el agua (ver Lightning): se muere achicharrado.
func zap(at: Vector2) -> void:
	_puff(at, C_SPARK, 26, 300.0)
	_sprite.modulate = C_CHARRED
	_kill(Vector2.ZERO)

## Lo alcanzó la explosión de un meteorito (ver Meteor): se muere chamuscado y sale despedido.
func blast(push: Vector2) -> void:
	_puff(global_position, C_BLOOD, 24, 260.0, push.normalized())
	_sprite.modulate = C_SINGED
	_kill(push)

## Si está vivo a menos de radius de p (para la explosión del meteorito).
func alive_near(p: Vector2, radius: float) -> bool:
	return visible and active and not dead and global_position.distance_to(p) <= radius

## Si está nadando cerca de x (para la descarga del rayo en el agua).
func swims_near(x: float, radius: float) -> bool:
	return visible and active and not dead and state == State.SWIM and absf(global_position.x - x) <= radius

## Se muere (si no lo estaba) y sale despedido según push.
func _kill(push: Vector2) -> void:
	var was_dead := dead
	if not dead:
		dead = true
		active = false
		_prey = null
		_paint_dead_eye()
		killed.emit()
	match state:
		State.SWIM:
			if not was_dead:
				_die_in_water()
		State.HELD:
			state = State.FLYING
			_vel = push
			_spin = clampf(_swing_vel, -10.0, 10.0)
			_launch_y = global_position.y
			_left_island = not _on_island(global_position)
		State.FLYING:
			_vel += push
			_spin += signf(push.x) * 3.0
		State.LAND:
			_hv = maxf(_hv, SHOT_HOP)
			_ground_vel = Vector2(push.x * 0.5, 0.0)
			_die_on_land()

## Deja un agujero de bala pintado en el dibujo (coords globales): así se dobla con el cuerpo
## y, si pegó en la mandíbula, se va con ella. Si el punto cayó en un borde transparente, se
## busca el dibujo yendo hacia el centro.
func _add_bullet_mark(at: Vector2) -> void:
	if _marks >= MAX_MARKS:
		return
	var size := Vector2i(TEXTURE.get_size())
	var t := _local_to_texture(to_local(at))
	for step in 11:
		var p := Vector2i(t.lerp(Vector2(size) * 0.5, step / 10.0))
		if Rect2i(Vector2i.ZERO, size).has_point(p) and _alpha.get_pixelv(p).a > 0.5:
			_paint_mark(Vector2(p) + Vector2(0.5, 0.5))
			_marks += 1
			return

## Pinta la marca de VillagerRig.BulletMark centrada en c (px del dibujo), solo sobre el dibujo.
func _paint_mark(c: Vector2) -> void:
	if _marked == null:
		_marked = _alpha.duplicate()
	var blobs := VillagerRig.BulletMark.random_blobs()
	var reach := (VillagerRig.BulletMark.BLOB_DIST.y + VillagerRig.BulletMark.BLOB_RADIUS.y) * MARK_SCALE + 1.0
	var area := Rect2i(Vector2i(c - Vector2.ONE * reach), Vector2i.ONE * int(reach * 2.0 + 2.0))
	area = area.intersection(Rect2i(Vector2i.ZERO, _marked.get_size()))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var px := _marked.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			var blood := _cover(p, c, VillagerRig.BulletMark.RADIUS * MARK_SCALE)
			for b in blobs:
				blood = maxf(blood, _cover(p, c + Vector2(b.x, b.y) * MARK_SCALE, b.z * MARK_SCALE))
			var hole := _cover(p, c, VillagerRig.BulletMark.HOLE_RADIUS * MARK_SCALE)
			var col := px.lerp(VillagerRig.BulletMark.BLOOD, blood).lerp(VillagerRig.BulletMark.HOLE, hole)
			col.a = px.a
			_marked.set_pixel(x, y, col)
	_upload_marked()

## Ojo de muerto: tapa el ojo de blanco (sin pisar el párpado) y le pinta una cruz,
## con las proporciones de VillagerRig.DeadEyes.
func _paint_dead_eye() -> void:
	if _marked == null:
		_marked = _alpha.duplicate()
	var lid_a: Vector2 = IMG_LID[0]
	var lid_b: Vector2 = IMG_LID[1]
	var c := IMG_EYE + Vector2(0.5, 1.5)   # La cruz, en el medio de lo que deja ver el párpado
	var d := EYE_RADIUS * 30.0 / 56.0
	var half_w := EYE_RADIUS * 18.0 / 56.0 * 0.5
	var r := int(EYE_RADIUS) + 1
	for y in range(int(IMG_EYE.y) - r, int(IMG_EYE.y) + r + 1):
		for x in range(int(IMG_EYE.x) - r, int(IMG_EYE.x) + r + 1):
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			var lid := clampf((lid_b - lid_a).normalized().cross(p - lid_a) - 0.5, 0.0, 1.0)
			var white := minf(_cover(p, IMG_EYE, EYE_RADIUS - 2.0), lid)
			var cross := maxf(_cover_line(p, c + Vector2(-d, -d), c + Vector2(d, d), half_w),
					_cover_line(p, c + Vector2(-d, d), c + Vector2(d, -d), half_w))
			if white <= 0.0:
				continue
			var px := _marked.get_pixel(x, y)
			var col := px.lerp(VillagerRig.DeadEyes.WHITE, white).lerp(C_INK, minf(cross, white))
			col.a = px.a
			_marked.set_pixel(x, y, col)
	_upload_marked()

static func _cover_line(p: Vector2, a: Vector2, b: Vector2, half_width: float) -> float:
	var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
	return clampf(half_width - p.distance_to(closest) + 0.5, 0.0, 1.0)

func _upload_marked() -> void:
	if _tex is ImageTexture:
		(_tex as ImageTexture).update(_marked)
	else:
		_tex = ImageTexture.create_from_image(_marked)

## Cuánto del píxel p tapa un círculo (con el borde suavizado).
static func _cover(p: Vector2, center: Vector2, radius: float) -> float:
	return clampf(radius - p.distance_to(center) + 0.5, 0.0, 1.0)

## Muerto en el agua: rueda panza arriba, flota un rato entre la sangre y se hunde.
func _die_in_water() -> void:
	if _tween:
		_tween.kill()
	_dead_t = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "_roll", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(self, "_dive", 0.0, 0.4)
	_tween.tween_interval(DEAD_FLOAT_TIME)
	_tween.tween_property(self, "_dive", 1.0, DEAD_SINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, DEAD_SINK_TIME)
	_tween.tween_callback(_vanish)

## Muerto en la isla: queda panza arriba y al rato se desvanece (cada tiro reinicia la cuenta).
func _die_on_land() -> void:
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	if _h <= 0.0 and _hv <= 0.0:
		_bleed_on_sand()
	_tween = create_tween()
	_tween.tween_property(self, "_roll", 1.0, 0.35)
	_tween.tween_interval(DEAD_LAND_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, 1.5)
	_tween.tween_callback(_vanish)

func _bleed_on_sand() -> void:
	if _pooled:
		return
	_pooled = true
	var pool := Villager.BloodPool.new()
	pool.scale = Vector2.ONE * 2.5
	var layer := get_tree().get_first_node_in_group("ground_layer")
	(layer if layer else get_parent()).add_child(pool)
	pool.global_position = _ground + Vector2(0, 24)

## Terminó de morirse: desaparece hasta que lo vuelvan a comprar.
func _vanish() -> void:
	_back_to_water(false)
	_revive()
	visible = false
	set_process(false)

func _revive() -> void:
	dead = false
	_roll = 0.0
	_jaw = 0.0
	_pooled = false
	modulate.a = 1.0
	rotation = 0.0
	_bend.fill(0.0)
	_bend_vel.fill(0.0)
	_tex = TEXTURE
	_marked = null
	_marks = 0
	_sprite.modulate = Color.WHITE

# ---- De vuelta al agua ----
func _back_to_water(splash: bool) -> void:
	_set_on_land_layer(false)
	state = State.SWIM
	z_index = 0
	rotation = 0.0
	_prey = null
	_jolt_reset = true
	global_position = Vector2(clampf(global_position.x, _left(), _right()), water_rect.position.y + 3.0)
	if absf(_vel.x) > 20.0:
		dir = signf(_vel.x)
	if not splash:
		return
	_splash(global_position, 36)
	if dead:
		_die_in_water()
		return
	_cooldown = 0.8
	_dive = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(0.5)
	_tween.tween_property(self, "_dive", 0.0, 0.5)

## En la isla va en Props, así los aldeanos de adelante lo tapan y él tapa a los de atrás.
## En el agua vuelve a su lugar de siempre: debajo de los aldeanos.
func _set_on_land_layer(on: bool) -> void:
	var props: Node = _world.get("props")
	if on and props and get_parent() != props:
		reparent(props)
	elif not on and get_parent() != _world:
		reparent(_world)
		var ground: Node = _world.get("ground")
		if ground:
			_world.move_child(self, ground.get_index())

func _on_island(p: Vector2) -> bool:
	var poly: Variant = _world.get("island_poly_global")
	return poly is PackedVector2Array and poly.size() > 0 and Geometry2D.is_point_in_polygon(p, poly)

func _splash(at: Vector2, amount: int) -> void:
	_puff(at, Color(0.85, 0.95, 1.0), amount, 260.0)

func _puff(at: Vector2, color: Color, amount: int, speed := 140.0, toward := Vector2.UP) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.6
	p.direction = toward
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = color
	p.z_index = 15
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
