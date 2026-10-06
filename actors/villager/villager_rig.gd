extends Node2D
class_name VillagerRig

## Rig esqueletal del aldeano (Skeleton2D + Bone2D).
## - En la isla: animación procedural de caminado (bamboleo).
## - Agarrado / cayendo / en el agua: ragdoll. Cada articulación es un péndulo
##   amortiguado que responde a la gravedad y a la aceleración del cuerpo.

const GRAVITY := 1400.0
const MAX_ACC := 7000.0       # Tope de aceleración medida (evita latigazos absurdos)
const GRAV_TORQUE := 55.0     # Qué tan fuerte la gravedad tira de los miembros
const AIR_DRAG := 0.7         # Al caer, el aire empuja los miembros hacia arriba
const BODY_SPIN_INERTIA := 0.6  # Los miembros se resisten a que el cuerpo gire

# Caminado
const STEP_RATE := 9.0        # rad/s de fase a velocidad de referencia
const REF_SPEED := 40.0
const BOB := 14.0             # Rebote de cadera (px de la imagen)
const SWAY := 0.08            # Balanceo de cadera (rad)
const STEP_LIFT := 0.32       # Apertura de la pierna que da el paso (rad)
const ARM_DOWN := 1.25        # Brazos caídos al caminar (el arte está en pose T)
const ARM_SWING := 0.28

# Resortes: modo caminar (rígido) vs ragdoll (flojo)
const WALK_K := 320.0
const BLEND_SPEED := 8.0      # Velocidad de transición caminar <-> ragdoll
const DEAD_LIMP := 0.2        # Muerto, los resortes casi no sostienen nada

# Impacto de bala
const HIT_SPIN := 6.0         # Sacudida de todos los miembros
const HIT_SPIN_NEAR := 24.0   # Extra para el miembro alcanzado
const HIT_RADIUS := 25.0      # px (mundo) de alcance del "extra"

class Joint:
	var bone: Bone2D
	var axis: Vector2         # Dirección pivote -> punta del miembro, en espacio del hueso
	var rag_k: float          # Rigidez en ragdoll (cuánto intenta volver a la pose base)
	var grav: float           # Peso relativo frente a la gravedad
	var min_a: float
	var max_a: float
	var target := 0.0         # Pose objetivo (caminado, o reposo en ragdoll)
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
var base_scale := 1.0
var phase := 0.0
var rag := 0.0                # 0 = caminando, 1 = ragdoll total

var _prev_pos := Vector2.ZERO
var _prev_vel := Vector2.ZERO
var _acc := Vector2.ZERO
var _prev_rot := 0.0
var _dead_eyes: DeadEyes

func _ready() -> void:
	villager = get_parent() as Villager
	base_scale = absf(scale.x)
	hip_rest = hip.position

	j_head  = Joint.new(head,  Vector2.UP,    40.0, 0.35, -0.7, 0.7)
	j_arm_l = Joint.new(arm_l, Vector2.LEFT,   5.0, 1.0, -1.9, 2.4)
	j_arm_r = Joint.new(arm_r, Vector2.RIGHT,  5.0, 1.0, -2.4, 1.9)
	j_leg_l = Joint.new(leg_l, Vector2.DOWN,  10.0, 1.0, -1.3, 1.3)
	j_leg_r = Joint.new(leg_r, Vector2.DOWN,  10.0, 1.0, -1.3, 1.3)
	joints = [j_head, j_arm_l, j_arm_r, j_leg_l, j_leg_r]

	# Arranca con los brazos abajo para no ver la pose T al aparecer
	j_arm_l.angle = -ARM_DOWN
	j_arm_r.angle = ARM_DOWN
	_apply()

	_prev_pos = global_position
	_prev_rot = villager.global_rotation if villager else 0.0

	_dead_eyes = DeadEyes.new()
	_dead_eyes.visible = false
	head.add_child(_dead_eyes)

func set_dead() -> void:
	rag = 1.0
	_dead_eyes.visible = true

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

func set_facing_left(left: bool) -> void:
	scale.x = -base_scale if left else base_scale

func _process(dt: float) -> void:
	if villager == null or dt <= 0.0:
		return
	dt = minf(dt, 1.0 / 30.0)

	# --- Aceleración medida del cuerpo (en mundo) ---
	var pos := global_position
	var vel := (pos - _prev_pos) / dt
	var acc := (vel - _prev_vel) / dt
	_prev_pos = pos
	_prev_vel = vel
	_acc = _acc.lerp(acc.limit_length(MAX_ACC), 0.3)

	var ragdoll := villager.dragging or villager.falling or villager.in_water or villager.eaten or villager.dead
	rag = move_toward(rag, 1.0 if ragdoll else 0.0, BLEND_SPEED * dt)

	# Gravedad efectiva que "sienten" los miembros: g - a (+ arrastre del aire)
	var g_world := Vector2(0.0, GRAVITY) - _acc
	var damping := 2.5
	if villager.dragging:
		pass
	elif villager.falling:
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
	var s := sin(phase)
	var hip_rot := SWAY * s * amt
	var lift_l := maxf(0.0, s) * STEP_LIFT * amt
	var lift_r := maxf(0.0, -s) * STEP_LIFT * amt

	hip.rotation = hip_rot
	hip.position = hip_rest + Vector2(0.0, -absf(s) * BOB * amt)

	# Con amt = 0 (ragdoll total) esto queda en la pose de reposo: brazos abajo, resto recto
	j_head.target  = -hip_rot * 0.6
	j_arm_l.target = -ARM_DOWN + ARM_SWING * s * amt - hip_rot
	j_arm_r.target =  ARM_DOWN + ARM_SWING * s * amt - hip_rot
	j_leg_l.target =  lift_l - hip_rot
	j_leg_r.target = -lift_r - hip_rot

	# --- Simulación de cada articulación ---
	for j in joints:
		j.angle -= d_rot * BODY_SPIN_INERTIA * rag

		var k := lerpf(WALK_K, j.rag_k * (DEAD_LIMP if villager.dead else 1.0), rag)
		var c := lerpf(2.0 * sqrt(WALK_K), damping, rag)
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

func _apply() -> void:
	for j in joints:
		j.bone.rotation = j.angle

## Ojos en X que tapan los ojos del dibujo cuando el aldeano muere.
class DeadEyes extends Node2D:
	# Centros de los ojos relativos al pivote del hueso Head (px de villager.png)
	const EYES := [Vector2(-114, -165), Vector2(135, -173)]
	const WHITE := Color(0.98, 0.98, 1.0)
	const INK := Color(0.2, 0.09, 0.05)

	func _draw() -> void:
		for e: Vector2 in EYES:
			draw_circle(e, 46.0, WHITE, true, -1.0, true)
			var d := 26.0
			draw_line(e + Vector2(-d, -d), e + Vector2(d, d), INK, 18.0, true)
			draw_line(e + Vector2(-d, d), e + Vector2(d, -d), INK, 18.0, true)
