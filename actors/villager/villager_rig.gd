extends Node2D
class_name VillagerRig

## Rig esqueletal del aldeano (Skeleton2D + Bone2D).
## - En la isla: animación procedural de caminado. El dibujo es de frente, así que el paso
##   se ve de frente: el pie que da el paso sube y la pierna se acorta (la rodilla viene
##   hacia adelante), el cuerpo baja al apoyar y sube al pasar la pierna, el peso se corre
##   sobre la pierna apoyada y los brazos van al revés que las piernas, un poco atrasados.
##   Parado respira y mira para los costados. Al darse vuelta se achata y se espeja. De viejo
##   hunde la cabeza entre los hombros y arrastra los pies.
## - Agarrado / cayendo / en el agua / en un tornado: ragdoll. Cada articulación es un péndulo
##   amortiguado que responde a la gravedad y a la aceleración del cuerpo.
## - Parpadea cada tantos segundos y los balazos dejan una marca en la parte alcanzada.
## - Electrocutado por un rayo: tieso con brazos y piernas abiertos, temblando, y en los
##   cuadros de rayos X se le ve el esqueleto (ver Villager.zap).
## - Rezándote: de rodillas (el cuerpo baja y tapa las piernas) con los brazos en alto,
##   meciéndolos. Agachado de miedo: más abajo, abrazándose y con la boca abierta. Si te
##   teme, tiembla (ver Villager.pose).

const GRAVITY := 1400.0
const MAX_ACC := 7000.0       # Tope de aceleración medida (evita latigazos absurdos)
const GRAV_TORQUE := 55.0     # Qué tan fuerte la gravedad tira de los miembros
const AIR_DRAG := 0.7         # Al caer, el aire empuja los miembros hacia arriba
const BODY_SPIN_INERTIA := 0.6  # Los miembros se resisten a que el cuerpo gire

# Caminado (px de la imagen: en pantalla es más o menos un 8%)
const STEP_RATE := 8.5        # rad/s de fase a velocidad de referencia
const REF_SPEED := 40.0
const BOB := 20.0             # Cuánto sube el cuerpo al pasar la pierna (los pies no se despegan)
const SHIFT := 8.0            # El peso se corre sobre la pierna apoyada
const SWAY := 0.07            # Y el cuerpo se inclina hacia ese lado (rad)
const LIFT := 40.0            # Cuánto sube el pie que da el paso
const KNEE := 0.14            # Y cuánto se acorta esa pierna (la rodilla viene hacia adelante)
const LEG_SPLAY := 0.05       # Y cuánto se abre (rad)
const HEAD_DIP := 12.0        # La cabeza se hunde un poco al apoyar el pie
const ARM_DOWN := 1.25        # Brazos caídos al caminar (el arte está en pose T)
const ARM_FWD := 0.4          # El brazo que va adelante se cierra sobre el cuerpo (rad)...
const ARM_SHORT := 0.18       # ...se acorta (apunta hacia la cámara)...
const ARM_NEAR := 0.06        # ...y se ve un poco más grueso (está más cerca)
const ARM_BACK := 0.16        # El que va atrás se abre un poco
const ARM_WALK_K := 90.0      # Los brazos son más flojos que el resto: van un poco atrasados
const BREATH := 4.0           # Parado: sube y baja al respirar
const BREATH_RATE := 2.4      # rad/s
const LOOK := 0.12            # Parado: inclina la cabeza para un lado y otro (rad)
const LOOK_TIME := Vector2(1.5, 4.0)
const TURN_TIME := 0.18       # Segundos en darse vuelta
const STOOP_HEAD := 30.0      # Bien viejo (ver Villager.oldness): la cabeza se le hunde entre los hombros...
const STOOP_STEP := 0.5       # ...y arrastra los pies (levanta menos el pie y el cuerpo)

# Manos: el dibujo las tiene abiertas con la palma al frente (pose T). Con los brazos
# caídos eso se ve raro, así que se angostan hacia los dedos y parecen giradas de costado.
const HAND_SQUASH := 0.4      # Ancho que queda en la punta de los dedos (1 = como el dibujo)
const HAND_L := Rect2(-239, -65, 114, 115)  # Zona de la mano en el hueso (px de villager.png)
const HAND_R := Rect2(133, -68, 105, 118)
const WRIST_L := -138.0       # Donde la pulsera tapa la unión con el brazo
const WRIST_R := 158.0

# Resortes: modo caminar (rígido) vs ragdoll (flojo)
const WALK_K := 320.0
const BLEND_SPEED := 8.0      # Velocidad de transición caminar <-> ragdoll
const DEAD_LIMP := 0.2        # Muerto, los resortes casi no sostienen nada

# Impacto de bala
const HIT_SPIN := 6.0         # Sacudida de todos los miembros
const HIT_SPIN_NEAR := 24.0   # Extra para el miembro alcanzado
const HIT_RADIUS := 25.0      # px (mundo) de alcance del "extra"

# Electrocutado: pose tiesa (ángulo de cada articulación) y temblor
const SHOCK_ARM := 0.3        # Brazos un poco levantados
const SHOCK_LEG := 0.22       # Piernas abiertas
const SHOCK_JITTER := 0.15    # Temblor de cada miembro (rad)
const SHOCK_SHAKE := 22.0     # Temblor de la cadera (px de la imagen)

# Rezando o agachado de miedo (ver Villager.pose)
const KNEEL_SPEED := 4.0      # Por segundo: de parado a de rodillas en 0.25 s
const KNEEL_DROP := 85.0      # Cuánto baja el cuerpo de rodillas (px de la imagen)...
const COWER_DROP := 105.0     # ...y agachado de miedo
const KNEEL_SPLAY := 0.12     # Las rodillas un poco abiertas (rad)
const PRAY_ARMS := 0.75       # Brazos en alto (rad desde la pose T, para arriba)...
const PRAY_SWAY := 0.18       # ...meciéndose
const PRAY_SWAY_RATE := 2.6
const COWER_ARMS := -1.8      # Agachado, abrazándose (los brazos cruzados por delante)
const TREMBLE := 6.0          # Temblor de la cadera si te teme (px de la imagen)

# Aldeana: el mismo dibujo con pelo largo, trenzas y top de hojas, alineado con villager.png
# (mismos huesos y recortes). La cabeza va en una textura aparte porque las trenzas cuelgan
# por delante de las manos: su polígono llega más abajo y lo que no es cabeza es transparente.
const MALE_TEX := preload("res://actors/villager/villager.png")
const FEMALE_BODY := preload("res://actors/villager/villager_female.png")
const FEMALE_HEAD := preload("res://actors/villager/villager_female_head.png")
const FEMALE_HEAD_RECT := Rect2(146, 6, 698, 570)   # px del dibujo

class Joint:
	var bone: Bone2D
	var axis: Vector2         # Dirección pivote -> punta del miembro, en espacio del hueso
	var rag_k: float          # Rigidez en ragdoll (cuánto intenta volver a la pose base)
	var grav: float           # Peso relativo frente a la gravedad
	var min_a: float
	var max_a: float
	var target := 0.0         # Pose objetivo (caminado, o reposo en ragdoll)
	var walk_k := WALK_K      # Rigidez caminando
	var shock := 0.0          # Ángulo en la pose de electrocutado
	var angle := 0.0
	var vel := 0.0

	func _init(b: Bone2D, ax: Vector2, k: float, g: float, lo: float, hi: float) -> void:
		bone = b
		axis = ax
		rag_k = k
		grav = g
		min_a = lo
		max_a = hi

@onready var hip: Bone2D = $Skeleton2D/Hip
@onready var head: Bone2D = $Skeleton2D/Hip/Head
@onready var arm_l: Bone2D = $Skeleton2D/Hip/ArmL
@onready var arm_r: Bone2D = $Skeleton2D/Hip/ArmR
@onready var leg_l: Bone2D = $Skeleton2D/Hip/LegL
@onready var leg_r: Bone2D = $Skeleton2D/Hip/LegR

var villager: Villager
var joints: Array[Joint] = []
var j_head: Joint
var j_arm_l: Joint
var j_arm_r: Joint
var j_leg_l: Joint
var j_leg_r: Joint

var hip_rest := Vector2.ZERO
var head_rest := Vector2.ZERO
var leg_l_rest := Vector2.ZERO
var leg_r_rest := Vector2.ZERO
var base_scale := 1.0
var phase := 0.0
var rag := 0.0                # 0 = caminando, 1 = ragdoll total

var _prev_pos := Vector2.ZERO
var _prev_vel := Vector2.ZERO
var _acc := Vector2.ZERO
var _prev_rot := 0.0
var _dead_eyes: DeadEyes
var _blink: Blink
var _mouth: Mouth
var _marks := 0
var _xray: Array[XRay] = []
var _facing := 1.0            # 1 = mira a la derecha, -1 = a la izquierda (se da vuelta de a poco)
var _t := 0.0
var _look := 0.0
var _look_target := 0.0
var _look_t := 0.0
var _female := false
var _male_head_poly := PackedVector2Array()
var _male_head_uv := PackedVector2Array()
var _sneeze := 0.0            # Estornudando: la boca abierta un ratito
var _kneel := 0.0             # 0 = parado, 1 = de rodillas (rezando o agachado de miedo)
var _pose := Villager.Pose.NONE   # La última (para seguir con ella mientras se levanta)

const MAX_MARKS := 10
## Alfa de cada textura del dibujo, para saber si un tiro cayó sobre el dibujo o en un hueco.
static var _alpha := {}

func _ready() -> void:
	villager = get_parent() as Villager
	# El dibujo es grande y se ve muy achicado: con mipmaps queda suave (si no, los mechones del
	# pelo y los bordes se ven pixelados, más con el pelo teñido, ver Villager.set_looks)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	base_scale = absf(scale.x)
	_facing = -1.0 if scale.x < 0.0 else 1.0
	hip_rest = hip.position
	head_rest = head.position
	leg_l_rest = leg_l.position
	leg_r_rest = leg_r.position
	phase = randf() * TAU   # Así no caminan todos al mismo compás

	j_head  = Joint.new(head,  Vector2.UP,    40.0, 0.35, -0.7, 0.7)
	j_arm_l = Joint.new(arm_l, Vector2.LEFT,   5.0, 1.0, -1.9, 2.4)
	j_arm_r = Joint.new(arm_r, Vector2.RIGHT,  5.0, 1.0, -2.4, 1.9)
	j_leg_l = Joint.new(leg_l, Vector2.DOWN,  10.0, 1.0, -1.3, 1.3)
	j_leg_r = Joint.new(leg_r, Vector2.DOWN,  10.0, 1.0, -1.3, 1.3)
	joints = [j_head, j_arm_l, j_arm_r, j_leg_l, j_leg_r]
	j_arm_l.walk_k = ARM_WALK_K
	j_arm_r.walk_k = ARM_WALK_K
	j_arm_l.shock = SHOCK_ARM
	j_arm_r.shock = -SHOCK_ARM
	j_leg_l.shock = SHOCK_LEG
	j_leg_r.shock = -SHOCK_LEG

	# Arranca con los brazos abajo para no ver la pose T al aparecer
	j_arm_l.angle = -ARM_DOWN
	j_arm_r.angle = ARM_DOWN
	_apply()

	_prev_pos = global_position
	_prev_rot = villager.global_rotation if villager else 0.0

	_dead_eyes = DeadEyes.new()
	_dead_eyes.visible = false
	head.add_child(_dead_eyes)

	_blink = Blink.new()
	head.add_child(_blink)

	_mouth = Mouth.new()
	head.add_child(_mouth)

	_turn_hand(arm_l, HAND_L, WRIST_L)
	_turn_hand(arm_r, HAND_R, WRIST_R)

	_share_material(self)

## Arma la mano como una malla aparte (el Sprite del brazo termina en la pulsera) y la
## angosta desde la muñeca hasta la punta de los dedos.
func _turn_hand(arm: Bone2D, area: Rect2, wrist_x: float) -> void:
	const COLS := 6
	var sprite: Polygon2D = arm.get_node("Sprite")
	var to_uv := sprite.uv[0] - sprite.polygon[0]
	var tip_x := area.position.x if wrist_x < 0.0 else area.end.x
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in COLS + 1:
		var x := lerpf(area.position.x, area.end.x, float(i) / COLS)
		var squash := lerpf(1.0, HAND_SQUASH, clampf((x - wrist_x) / (tip_x - wrist_x), 0.0, 1.0))
		for y: float in [area.position.y, 0.0, area.end.y]:
			pts.append(Vector2(x, y * squash))
			uvs.append(Vector2(x, y) + to_uv)
	var quads := []
	for i in COLS:
		for row in 2:
			var a := i * 3 + row
			quads.append(PackedInt32Array([a, a + 3, a + 4, a + 1]))
	var hand := Polygon2D.new()
	hand.name = "Hand"
	hand.texture = sprite.texture
	hand.polygon = pts
	hand.uv = uvs
	hand.polygons = quads
	arm.add_child(hand)
	arm.move_child(hand, 0)  # Detrás del brazo, así la pulsera tapa la unión

## Varón o aldeana: cambia las texturas (sirve antes o después de _ready).
func set_female(on: bool) -> void:
	if on == _female:
		return
	_female = on
	var head_sprite: Polygon2D = $Skeleton2D/Hip/Head/Sprite
	if _male_head_poly.is_empty():
		_male_head_poly = head_sprite.polygon
		_male_head_uv = head_sprite.uv
	var body := FEMALE_BODY if on else MALE_TEX
	for path in ["Hip", "Hip/LegL", "Hip/LegR", "Hip/ArmL", "Hip/ArmR"]:
		var bone := get_node("Skeleton2D/" + path)
		bone.get_node("Sprite").texture = body
		if bone.has_node("Hand"):
			bone.get_node("Hand").texture = body
	head_sprite.texture = FEMALE_HEAD if on else MALE_TEX
	if on:
		var to_uv := _male_head_uv[0] - _male_head_poly[0]
		var r := FEMALE_HEAD_RECT
		var uv := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var poly := PackedVector2Array()
		for p in uv:
			poly.append(p - to_uv)
		head_sprite.polygon = poly
		head_sprite.uv = uv
	else:
		head_sprite.polygon = _male_head_poly
		head_sprite.uv = _male_head_uv

## Todo el rig se dibuja con el material del Rig (el recorte de la línea del agua).
func _share_material(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem:
			c.use_parent_material = true
		_share_material(c)

func set_dead() -> void:
	rag = 1.0
	_dead_eyes.visible = true
	_blink.queue_free()

## Rayos X: muestra o esconde el esqueleto (lo arma la primera vez). mat: con qué se dibuja
## (el recorte del agua, pero sin oscurecerse como el cuerpo).
func set_xray(on: bool, mat: Material) -> void:
	if on and _xray.is_empty():
		for part: Array in [[head, "head"], [hip, "torso"], [arm_l, "arm_l"], [arm_r, "arm_r"], [leg_l, "leg_l"], [leg_r, "leg_r"]]:
			var bone: Bone2D = part[0]
			var x := XRay.new()
			x.part = part[1]
			x.material = mat
			bone.add_child(x)
			# Justo encima de su dibujo: así los brazos y la cabeza siguen tapando al torso
			if bone != head:
				bone.move_child(x, bone.get_node("Sprite").get_index() + 1)
			_xray.append(x)
	for x in _xray:
		x.visible = on

## Para la foto del carnet (un rig suelto, sin aldeano): pone la misma cara que el
## aldeano, con la boca de "¡wow!" y los ojos en X si está muerto.
func copy_face(from: VillagerRig) -> void:
	_mouth.target = from._mouth.target
	_mouth.mood = from._mouth.mood
	if is_instance_valid(_blink) and is_instance_valid(from._blink):
		_blink.asleep = from._blink.asleep
	if from._dead_eyes.visible and not _dead_eyes.visible:
		set_dead()

## Deja un agujero de bala pegado a la parte del cuerpo alcanzada (coords globales),
## así sigue al miembro cuando se mueve. Si el punto cayó en un hueco transparente
## (la colisión es un rectángulo), se busca el dibujo más cerca yendo hacia el centro.
func add_bullet_mark(point: Vector2) -> void:
	if _marks >= MAX_MARKS:
		return
	var sprites: Array[Polygon2D] = []
	for b: Node in [head, arm_r, arm_l, hip, leg_r, leg_l]:  # Del que se dibuja arriba al de abajo
		sprites.append(b.get_node("Sprite"))
	var center := villager.to_global(Villager.BODY_COM) if villager else global_position
	for step in 11:
		var p := point.lerp(center, step / 10.0)
		for s in sprites:
			var local := s.to_local(p)
			if not Geometry2D.is_point_in_polygon(local, s.polygon):
				continue
			var alpha := _alpha_of(s.texture)
			var px := Vector2i(local + s.uv[0] - s.polygon[0])
			if Rect2i(Vector2i.ZERO, alpha.get_size()).has_point(px) and alpha.get_pixelv(px).a > 0.5:
				var mark := BulletMark.new()
				mark.position = local
				mark.rotation = randf() * TAU
				mark.use_parent_material = true
				s.add_child(mark)
				_marks += 1
				return

static func _alpha_of(tex: Texture2D) -> Image:
	var key := tex.resource_path   # Por la ruta: guardar la textura en un static da "leaked at exit"
	if not _alpha.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		_alpha[key] = img
	return _alpha[key]

## Sacude los miembros según dónde y hacia dónde pegó el tiro (coords globales).
func hit(point: Vector2, dir: Vector2, strength := 1.0) -> void:
	# Con el rig espejado, girar el hueso en + se ve antihorario en pantalla
	var flip := -1.0 if scale.x < 0.0 else 1.0
	for j in joints:
		var base := j.bone.global_position
		var tip := j.bone.to_global(j.axis * j.bone.get_length())
		var closest := Geometry2D.get_closest_point_to_segment(point, base, tip)
		var near := clampf(1.0 - point.distance_to(closest) / HIT_RADIUS, 0.0, 1.0)
		var spin := (tip - base).normalized().cross(dir.normalized()) * flip
		j.vel += spin * (HIT_SPIN + HIT_SPIN_NEAR * near) * strength + randf_range(-3.0, 3.0)

## Se da vuelta de a poco (ver _process): se achata hasta quedar de canto y se espeja.
func set_facing_left(left: bool) -> void:
	_facing = -1.0 if left else 1.0

## 1 si mira a la derecha, -1 a la izquierda (aunque se esté dando vuelta).
func facing() -> float:
	return _facing

## ¡Achís! Abre la boca un instante (ver Villager._sneeze).
func sneeze() -> void:
	_sneeze = 0.3

func _process(dt: float) -> void:
	if villager == null or dt <= 0.0:
		return
	dt = minf(dt, 1.0 / 30.0)
	_t += dt
	scale.x = move_toward(scale.x, _facing * base_scale, 2.0 * base_scale / TURN_TIME * dt)

	# --- Aceleración medida del cuerpo (en mundo) ---
	var pos := global_position
	var vel := (pos - _prev_pos) / dt
	var acc := (vel - _prev_vel) / dt
	_prev_pos = pos
	_prev_vel = vel
	_acc = _acc.lerp(acc.limit_length(MAX_ACC), 0.3)
	if _zap_pose():
		return

	var ragdoll := villager.dragging or villager.falling or villager.in_water or villager.eaten or villager.dead \
			or villager.tornado != null
	rag = move_toward(rag, 1.0 if ragdoll else 0.0, BLEND_SPEED * dt)

	# Boca: "¡wow!" mientras lo tienen agarrado, va volando (o girando en un tornado), ve venir
	# un meteorito, se quema o estornuda; masticando cuando come, y moviéndose cuando charla
	_sneeze = maxf(0.0, _sneeze - dt)
	if villager.dead:
		_mouth.target = 0.0
	elif villager.dragging or villager.falling or villager.tornado != null or villager.is_scared() or villager.on_fire \
			or _sneeze > 0.0:
		_mouth.target = 1.0
	elif villager.food and villager._eat_t > 0.0:
		_mouth.target = absf(sin(villager._eat_t * 12.0)) * 0.45
	else:
		_mouth.target = villager.talk_mouth()
	if is_instance_valid(_blink):
		_blink.asleep = villager.asleep
	# Cerrada, la boca dice cómo anda: sonríe contento y la tuerce para abajo triste
	_mouth.mood = 0.0 if villager.dead else clampf((villager.mood - 50.0) / 30.0, -1.0, 1.0)

	# Gravedad efectiva que "sienten" los miembros: g - a (+ arrastre del aire)
	var g_world := Vector2(0.0, GRAVITY) - _acc
	var damping := 2.5
	if villager.dragging:
		pass
	elif villager.falling or villager.tornado != null:
		g_world -= vel * AIR_DRAG
	elif villager.in_water:
		# Casi sin peso y con mucha resistencia: flotan perezosos
		g_world = Vector2(0.0, GRAVITY * 0.2) - _acc * 0.3
		damping = 6.0
	elif villager.dead:
		if villager.corpse_grounded:
			# Tirado en el piso: los miembros se quedan desparramados donde cayeron
			g_world *= 0.15
			damping = 9.0
		else:
			g_world -= vel * AIR_DRAG

	# Pasar a espacio del rig (sin rotación del cuerpo y espejado si mira a la izquierda)
	var body_rot := villager.global_rotation
	var g_rig := g_world.rotated(-body_rot) / GRAVITY
	if scale.x < 0.0:
		g_rig.x = -g_rig.x

	# Si el cuerpo gira (péndulo al arrastrar, giro al caer), los miembros se quedan atrás
	var d_rot := angle_difference(_prev_rot, body_rot)
	_prev_rot = body_rot
	if scale.x < 0.0:
		d_rot = -d_rot

	# --- Pose objetivo de caminado ---
	var speed := villager.velocity.length()
	var walking := speed > 1.0 and rag < 1.0
	if walking:
		phase = fmod(phase + STEP_RATE * (speed / REF_SPEED) * dt, TAU)
	var amt := clampf(speed / REF_SPEED, 0.0, 1.0) * (1.0 - rag)
	var still := (1.0 - amt) * (1.0 - rag)   # Parado en la isla
	var old := villager.oldness()
	var step := amt * (1.0 - STOOP_STEP * old)
	var s := sin(phase)
	var lift_l := maxf(0.0, s) * step        # Pie izquierdo en el aire (0..1)
	var lift_r := maxf(0.0, -s) * step
	var contact := pow(1.0 - absf(s), 3.0) * amt   # Recién apoyó: el peso cae
	var hip_rot := SWAY * s * amt
	var rise := absf(s) * BOB * step + sin(_t * BREATH_RATE) * BREATH * still

	# De rodillas: el cuerpo baja y las piernas se quedan donde están (el cuerpo las tapa)
	if villager.pose != Villager.Pose.NONE:
		_pose = villager.pose
	_kneel = move_toward(_kneel, 1.0 if villager.pose != Villager.Pose.NONE else 0.0, KNEEL_SPEED * dt)
	var kneel := smoothstep(0.0, 1.0, _kneel) * (1.0 - rag)
	var cower := _pose == Villager.Pose.COWER
	if kneel > 0.0:
		rise -= (COWER_DROP if cower else KNEEL_DROP) * kneel
		if villager.fear >= Villager.FEARS_AT:
			rise += randf_range(-1.0, 1.0) * TREMBLE * kneel

	hip.rotation = hip_rot
	hip.position = hip_rest + Vector2(SHIFT * s * amt, -rise)
	_place_leg(leg_l, leg_l_rest, lift_l)
	_place_leg(leg_r, leg_r_rest, lift_r)
	head.position = head_rest + Vector2(0.0, HEAD_DIP * contact + STOOP_HEAD * old * (1.0 - rag))
	# El brazo de un lado va adelante cuando sube la pierna del otro
	arm_l.scale = Vector2(1.0 - ARM_SHORT * lift_r, 1.0 + ARM_NEAR * lift_r)
	arm_r.scale = Vector2(1.0 - ARM_SHORT * lift_l, 1.0 + ARM_NEAR * lift_l)
	_update_look(dt, still)

	# Con amt = 0 (ragdoll total) esto queda en la pose de reposo: brazos abajo, resto recto
	j_head.target  = -hip_rot * 0.6 + _look
	j_arm_l.target = -ARM_DOWN - ARM_FWD * lift_r + ARM_BACK * lift_l - hip_rot
	j_arm_r.target =  ARM_DOWN + ARM_FWD * lift_l - ARM_BACK * lift_r - hip_rot
	j_leg_l.target =  LEG_SPLAY * lift_l - hip_rot
	j_leg_r.target = -LEG_SPLAY * lift_r - hip_rot
	if kneel > 0.0:
		var arms := COWER_ARMS if cower else PRAY_ARMS + sin(_t * PRAY_SWAY_RATE) * PRAY_SWAY
		j_arm_l.target = lerpf(j_arm_l.target, arms, kneel)
		j_arm_r.target = lerpf(j_arm_r.target, -arms, kneel)
		j_leg_l.target = lerpf(j_leg_l.target, KNEEL_SPLAY, kneel)
		j_leg_r.target = lerpf(j_leg_r.target, -KNEEL_SPLAY, kneel)
		if cower:
			_mouth.target = maxf(_mouth.target, 0.6 * kneel)

	# --- Simulación de cada articulación ---
	for j in joints:
		j.angle -= d_rot * BODY_SPIN_INERTIA * rag

		var k := lerpf(j.walk_k, j.rag_k * (DEAD_LIMP if villager.dead else 1.0), rag)
		var c := lerpf(2.0 * sqrt(j.walk_k), damping, rag)
		var axis := j.axis.rotated(hip.rotation + j.angle)
		var torque := axis.cross(g_rig) * GRAV_TORQUE * j.grav * rag

		j.vel += (k * (j.target - j.angle) - c * j.vel + torque) * dt
		j.angle += j.vel * dt

		# Límites de la articulación con un pequeño rebote
		if j.angle < j.min_a:
			j.angle = j.min_a
			j.vel = absf(j.vel) * 0.25
		elif j.angle > j.max_a:
			j.angle = j.max_a
			j.vel = -absf(j.vel) * 0.25

	_apply()

## Pone la pierna para que el pie quede apoyado (o levantado, lift de 0 a 1) donde va,
## aunque la cadera suba, se corra o se incline.
func _place_leg(leg: Bone2D, rest: Vector2, lift: float) -> void:
	var pivot := hip_rest + rest - Vector2(0.0, LIFT * lift)   # En el esqueleto
	leg.position = (pivot - hip.position).rotated(-hip.rotation)
	leg.scale = Vector2(1.0, 1.0 - KNEE * lift)

## Parado, cada tanto inclina la cabeza para un lado (o la endereza). Caminando, derecha.
func _update_look(dt: float, still: float) -> void:
	_look_t -= dt
	if still < 0.5:
		_look_target = 0.0
	elif _look_t <= 0.0:
		_look_t = randf_range(LOOK_TIME.x, LOOK_TIME.y)
		_look_target = 0.0 if randf() < 0.3 else randf_range(-LOOK, LOOK)
	_look = move_toward(_look, _look_target * still, 0.6 * dt)

## Vuelve a su lugar los huesos que mueve el caminado (para las poses que no caminan).
func _rest_walk_pose() -> void:
	leg_l.position = leg_l_rest
	leg_r.position = leg_r_rest
	leg_l.scale = Vector2.ONE
	leg_r.scale = Vector2.ONE
	head.position = head_rest
	arm_l.scale = Vector2.ONE
	arm_r.scale = Vector2.ONE

## Electrocutándose: tieso con brazos y piernas abiertos, temblando y gritando. Carbonizado
## en la isla se queda duro así hasta hacerse cenizas. true si ya se encargó de los huesos.
func _zap_pose() -> bool:
	if villager.zap_state == Villager.Zap.NONE:
		return false
	if villager.zap_state != Villager.Zap.SHOCK:
		return villager.zap_pinned()
	_mouth.target = randf_range(0.7, 1.0)
	_rest_walk_pose()
	hip.position = hip_rest + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHOCK_SHAKE
	hip.rotation = randf_range(-0.05, 0.05)
	for j in joints:
		j.angle = j.shock + randf_range(-SHOCK_JITTER, SHOCK_JITTER)
		j.vel = 0.0
	rag = 1.0
	_prev_rot = villager.global_rotation
	_apply()
	return true

func _apply() -> void:
	for j in joints:
		j.bone.rotation = j.angle

## Ojos en X que tapan los ojos del dibujo cuando el aldeano muere.
class DeadEyes extends Node2D:
	# Centros de los ojos relativos al pivote del hueso Head (px de villager.png)
	const EYES := [Vector2(-139, -185), Vector2(154, -193)]
	const WHITE := Color(0.98, 0.98, 1.0)
	const INK := Color(0.2, 0.09, 0.05)

	func _draw() -> void:
		for e: Vector2 in EYES:
			draw_circle(e, 56.0, WHITE, true, -1.0, true)
			var d := 30.0
			draw_line(e + Vector2(-d, -d), e + Vector2(d, d), INK, 18.0, true)
			draw_line(e + Vector2(-d, d), e + Vector2(d, -d), INK, 18.0, true)

## Párpados que bajan un instante cada tantos segundos.
class Blink extends Node2D:
	# Blanco de cada ojo relativo al pivote del hueso Head: [centro, radios] (px de villager.png)
	const EYES := [[Vector2(-137, -191), Vector2(73, 60)], [Vector2(151, -194), Vector2(63, 61)]]
	const SKIN := Color("c48262")
	const LASH := Color(0.36, 0.2, 0.13)
	const CLOSE := 0.06   # Segundos en bajar
	const HOLD := 0.05    # Cerrados
	const OPEN := 0.09    # En volver a abrir
	const COLS := 16

	var asleep := false   # Durmiendo: los ojos se cierran y quedan cerrados
	var _wait := 0.0
	var _t := -1.0        # < 0: ojos abiertos, esperando
	var _closed := 0.0    # 0 = abiertos, 1 = cerrados

	func _ready() -> void:
		_wait = randf_range(0.5, 4.0)  # Que no parpadeen todos juntos

	func _process(dt: float) -> void:
		if asleep or (_t < 0.0 and _closed > 0.0):
			# Se le cierran despacio; al despertarse, los abre
			_closed = move_toward(_closed, 1.0 if asleep else 0.0, dt * (1.5 if asleep else 4.0))
			_t = -1.0
			queue_redraw()
			return
		if _t < 0.0:
			_wait -= dt
			if _wait > 0.0:
				return
			_t = 0.0
		_t += dt
		if _t < CLOSE:
			_closed = _t / CLOSE
		elif _t < CLOSE + HOLD:
			_closed = 1.0
		elif _t < CLOSE + HOLD + OPEN:
			_closed = 1.0 - (_t - CLOSE - HOLD) / OPEN
		else:
			_t = -1.0
			_closed = 0.0
			# De vez en cuando, doble parpadeo
			_wait = 0.12 if randf() < 0.2 else randf_range(2.0, 5.0)
		queue_redraw()

	func _draw() -> void:
		if _closed <= 0.0:
			return
		var skin := PackedColorArray([SKIN, SKIN, SKIN, SKIN])
		for e: Array in EYES:
			var c: Vector2 = e[0]
			var r: Vector2 = e[1]
			var cut := c.y - r.y + 2.0 * r.y * _closed   # Borde inferior del párpado
			var top := PackedVector2Array()
			var edge := PackedVector2Array()
			for i in COLS + 1:
				var x := r.x * (2.0 * i / COLS - 1.0)
				var h := r.y * sqrt(maxf(0.0, 1.0 - (x / r.x) * (x / r.x)))
				top.append(Vector2(c.x + x, c.y - h))
				edge.append(Vector2(c.x + x, clampf(cut, c.y - h, c.y + h)))
			for i in COLS:
				draw_primitive(PackedVector2Array([top[i], top[i + 1], edge[i + 1], edge[i]]), skin, PackedVector2Array())
			draw_polyline(edge, LASH, 10.0, true)

## Boca abierta en "O" que tapa la boquita del dibujo (una línea). target: 0 cerrada, 1 abierta.
class Mouth extends Node2D:
	# Relativo al pivote del hueso Head (px de villager.png)
	const CENTER := Vector2(11, -82)
	const LINE_HALF := Vector2(72, 16)   # Lo que hay que tapar de la boca dibujada
	const SIZE := Vector2(44, 56)         # Radios de la "O" bien abierta
	const SKIN := Color("c48262")
	const INSIDE := Color(0.32, 0.07, 0.06)
	const TONGUE := Color(0.86, 0.38, 0.4)
	const LIP := Color(0.36, 0.2, 0.13)
	const OPEN_SPEED := 14.0
	const CLOSE_SPEED := 6.0
	const SMILE_HALF := 50.0             # Cerrada: medio ancho de la sonrisa (o de la boca triste)...
	const SMILE_DEPTH := 24.0            # ...y cuánto se curva, del todo
	const MOOD_MIN := 0.33               # Con menos que esto queda la línea del dibujo

	var target := 0.0
	var mood := 0.0:                     # -1 triste .. 1 contento (ver Villager.mood)
		set(v):
			if absf(v - mood) > 0.01:
				mood = v
				queue_redraw()
	var _open := 0.0

	func _process(dt: float) -> void:
		var speed := OPEN_SPEED if target > _open else CLOSE_SPEED
		var prev := _open
		_open = move_toward(_open, target, speed * dt)
		if _open != prev:
			queue_redraw()

	func _draw() -> void:
		if _open <= 0.01:
			_draw_closed()
			return
		var k := ease(_open, 0.6)
		# Tapa la línea de la boca original (con la piel) y abre la "O" encima
		draw_colored_polygon(_ellipse(CENTER, LINE_HALF * Vector2(1.0, 1.3)), Color(SKIN, minf(1.0, _open * 3.0)))
		var r := SIZE * Vector2(lerpf(1.25, 1.0, k), 1.0) * k
		r.y = maxf(r.y, 8.0)
		draw_colored_polygon(_ellipse(CENTER, r), INSIDE)
		draw_colored_polygon(_ellipse(CENTER + Vector2(0, r.y * 0.45), Vector2(r.x * 0.62, r.y * 0.4)), TONGUE)
		draw_polyline(_ellipse(CENTER, r, true), LIP, 9.0, true)

	## Cerrada: tapa la línea del dibujo y la curva para arriba (sonrisa) o para abajo.
	func _draw_closed() -> void:
		var k := (absf(mood) - MOOD_MIN) / (1.0 - MOOD_MIN)
		if k <= 0.0:
			return
		var bend := signf(mood) * k * SMILE_DEPTH   # El medio más abajo que las puntas: sonrisa
		draw_colored_polygon(_ellipse(CENTER, LINE_HALF * Vector2(1.0, 1.3)), SKIN)
		var pts := PackedVector2Array()
		for i in 13:
			var u := lerpf(-1.0, 1.0, i / 12.0)
			pts.append(CENTER + Vector2(u * SMILE_HALF, bend * (1.0 - u * u - 0.5)))
		draw_polyline(pts, LIP, 9.0, true)

	static func _ellipse(c: Vector2, r: Vector2, closed := false) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 25:
			if i == 24 and not closed:
				break
			var a := TAU * i / 24.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts

## Agujero de bala con una mancha de sangre alrededor (px de villager.png).
## (Shark pinta la misma marca sobre su dibujo.)
class BulletMark extends Node2D:
	const BLOOD := Color(0.55, 0.04, 0.04)
	const HOLE := Color(0.16, 0.02, 0.02)
	const RADIUS := 30.0
	const HOLE_RADIUS := 15.0
	const BLOB_DIST := Vector2(20.0, 34.0)    # Manchitas alrededor: a qué distancia del centro
	const BLOB_RADIUS := Vector2(9.0, 15.0)
	var _blobs: Array[Vector3] = []   # x, y, radio

	func _ready() -> void:
		_blobs = random_blobs()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, RADIUS, BLOOD, true, -1.0, true)
		for b in _blobs:
			draw_circle(Vector2(b.x, b.y), b.z, BLOOD, true, -1.0, true)
		draw_circle(Vector2.ZERO, HOLE_RADIUS, HOLE, true, -1.0, true)

	## Entre 3 y 5 manchitas alrededor del agujero: x, y, radio.
	static func random_blobs() -> Array[Vector3]:
		var blobs: Array[Vector3] = []
		for i in randi_range(3, 5):
			var a := randf() * TAU
			blobs.append(Vector3(cos(a), sin(a), 0.0) * randf_range(BLOB_DIST.x, BLOB_DIST.y) \
					+ Vector3(0, 0, randf_range(BLOB_RADIUS.x, BLOB_RADIUS.y)))
		return blobs

## Esqueleto que se le ve al electrocutarse, en los cuadros en que el cuerpo se pone oscuro
## (ver waterline.gdshader). Uno por hueso, así cada parte sigue a su miembro; en px de
## villager.png relativos al pivote de cada hueso.
class XRay extends Node2D:
	const BONE := Color(0.92, 0.97, 1.0)
	const GLOW := Color(0.5, 0.78, 1.0, 0.45)
	const HOLE := Color(0.05, 0.08, 0.22)   # Cuencas y huecos: el color de la silueta
	const W := 30.0       # Grosor de los huesos
	const HALO := 22.0    # Resplandor alrededor
	var part := ""

	var _lines: Array[PackedVector2Array] = []   # Huesos largos
	var _widths: Array[float] = []
	var _knobs: Array[Vector3] = []              # Articulaciones: x, y, radio
	var _blobs: Array[PackedVector2Array] = []   # Partes rellenas (cráneo, pelvis)
	var _holes: Array[PackedVector2Array] = []   # Huecos encima de lo relleno
	var _cuts: Array[PackedVector2Array] = []    # Rayitas de hueco (dientes, vértebras)

	func _ready() -> void:
		match part:
			"head": _skull()
			"torso": _torso()
			"arm_l": _arm(-1.0, 138.0, 228.0)
			"arm_r": _arm(1.0, 152.0, 232.0)
			"leg_l": _leg(-1.0)
			"leg_r": _leg(1.0)

	func _draw() -> void:
		for b in _blobs:
			var halo := Geometry2D.offset_polygon(b, HALO)
			if not halo.is_empty():
				draw_colored_polygon(halo[0], GLOW)
		for i in _lines.size():
			draw_polyline(_lines[i], GLOW, _widths[i] + HALO * 2.0, true)
		for k in _knobs:
			draw_circle(Vector2(k.x, k.y), k.z + HALO, GLOW, true, -1.0, true)
		for b in _blobs:
			draw_colored_polygon(b, BONE)
		for i in _lines.size():
			draw_polyline(_lines[i], BONE, _widths[i], true)
		for k in _knobs:
			draw_circle(Vector2(k.x, k.y), k.z, BONE, true, -1.0, true)
		for h in _holes:
			draw_colored_polygon(h, HOLE)
		for c in _cuts:
			draw_polyline(c, HOLE, 9.0, true)

	func _line(pts: Array, w := W) -> void:
		_lines.append(PackedVector2Array(pts))
		_widths.append(w)

	func _skull() -> void:
		var cranium := _ellipse(Vector2(0, -250), Vector2(225, 200))
		var jaw := PackedVector2Array([Vector2(-150, -140), Vector2(150, -140), Vector2(132, -32),
				Vector2(60, -6), Vector2(-60, -6), Vector2(-132, -32)])
		var merged := Geometry2D.merge_polygons(cranium, jaw)
		_blobs.append(merged[0] if not merged.is_empty() else cranium)
		_holes.append(_ellipse(Vector2(-139, -185), Vector2(68, 62)))   # Cuencas de los ojos
		_holes.append(_ellipse(Vector2(154, -193), Vector2(64, 62)))
		_holes.append(PackedVector2Array([Vector2(8, -152), Vector2(-20, -106), Vector2(36, -106)]))   # Nariz
		_cuts.append(PackedVector2Array([Vector2(-105, -66), Vector2(115, -66)]))   # Dientes
		for x in range(-90, 111, 33):
			_cuts.append(PackedVector2Array([Vector2(x, -92), Vector2(x, -42)]))

	func _torso() -> void:
		_line([Vector2(0, -262), Vector2(0, 30)], W * 1.1)   # Columna
		for i in 9:
			var y := -238.0 + i * 32.0
			_cuts.append(PackedVector2Array([Vector2(-14, y), Vector2(14, y)]))
		for side: float in [-1.0, 1.0]:
			_line([Vector2(side * 10, -246), Vector2(side * 100, -226)], W * 0.8)   # Clavícula
			for i in 4:   # Costillas: salen de la columna, se abren y vuelven hacia adelante
				var y0 := -196.0 + i * 38.0
				var rx := 128.0 - i * 12.0
				var rib := []
				for s in 9:
					var a := lerpf(-PI * 0.5, PI * 0.32, s / 8.0)
					rib.append(Vector2(side * rx * cos(a), y0 + 30.0 * sin(a)))
				_line(rib, W * 0.75)
			# Pelvis
			_blobs.append(_ellipse(Vector2(side * 60, 15), Vector2(62, 42)))
			_holes.append(_ellipse(Vector2(side * 58, 22), Vector2(20, 16)))
		_blobs.append(PackedVector2Array([Vector2(-26, -12), Vector2(26, -12), Vector2(0, 42)]))   # Sacro

	## side: -1 el brazo izquierdo (va hacia -x), 1 el derecho. wrist / tip: x de la muñeca y
	## de la punta de los dedos (la mano se angosta hacia los dedos, ver HAND_SQUASH).
	func _arm(side: float, wrist: float, tip: float) -> void:
		var elbow := wrist * 0.52
		_line([Vector2(side * 8, 0), Vector2(side * elbow, 2)])   # Húmero
		_line([Vector2(side * elbow, -6), Vector2(side * (wrist - 6), -8)], W * 0.6)   # Antebrazo
		_line([Vector2(side * elbow, 8), Vector2(side * (wrist - 6), 9)], W * 0.6)
		_knobs.append(Vector3(side * 8, 0, 19))
		_knobs.append(Vector3(side * elbow, 1, 16))
		_knobs.append(Vector3(side * wrist, 0, 15))
		for f: float in [-1.0, -0.35, 0.35, 1.0]:   # Dedos
			_line([Vector2(side * (wrist + 8), f * 12), Vector2(side * tip, f * 22)], W * 0.4)
		_line([Vector2(side * (wrist + 10), -12), Vector2(side * (wrist + 40), -30)], W * 0.4)   # Pulgar

	func _leg(side: float) -> void:
		_line([Vector2(-side * 2, 4), Vector2(side * 4, 62)])    # Fémur
		_line([Vector2(side * 4, 66), Vector2(side * 2, 112)], W * 0.8)   # Tibia
		_knobs.append(Vector3(side * 4, 64, 17))
		_knobs.append(Vector3(side * 2, 116, 15))
		_line([Vector2(side * 5, 122), Vector2(side * 68, 130)], W * 0.6)   # Pie

	static func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts
