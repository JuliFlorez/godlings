extends CharacterBody2D
class_name Villager

@export var speed := 40.0
var dir := Vector2.ZERO

var island_center := Vector2.ZERO
var island_poly: PackedVector2Array:
	set(value):
		island_poly = value
		if island_poly.size() > 0:
			var sum := Vector2.ZERO
			for p in island_poly:
				sum += p
			island_center = sum / float(island_poly.size())

var dragging := false
var grab_local := Vector2.ZERO   # Punto del cuerpo (local) por donde se agarró

# --- Ragdoll al arrastrar: el cuerpo cuelga como péndulo del punto de agarre ---
const BODY_COM := Vector2(0, 5)  # Centro de masa aproximado (local)
const SWING_K := 38.0            # Fuerza del péndulo
const SWING_DAMP := 1.6          # Amortiguación del balanceo
const MAX_MOUSE_ACC := 6000.0
var swing_vel := 0.0             # Velocidad angular del cuerpo (rad/s)
var _prev_mouse := Vector2.ZERO
var _mouse_vel := Vector2.ZERO
var _mouse_acc := Vector2.ZERO

# --- Lanzar: soltado con impulso sale volando con la inercia del mouse ---
const THROW_SMOOTH := 25.0       # Suavizado de la velocidad del mouse (1/s)
const THROW_MIN_SPEED := 250.0   # Más lento que esto, soltarlo es solo dejarlo
const THROW_MAX_SPEED := 1800.0
const THROW_LAND_DROP := 40.0    # Lanzado sobre la isla: cuánto baja antes de poder aterrizar
var _throw_vel := Vector2.ZERO
var _launch_y := 0.0
var _flight_left_island := false # Salió de la isla durante el vuelo

# HUD / XP
@export var hud_path: NodePath
var hud: HUD
var xp_granted := false      # Evita sumar dos veces por ahogo
const SACRIFICE_OFFERING := 5

# --- Caída / Gravedad fuera de la isla ---
const GRAVITY := 1400.0
var falling := false
var v_fall := 0.0

# --- Agua / Flotación + Ahogo ---
var in_water := false
var touching_water := false   # El cuerpo toca el área de agua (puede ser solo la orilla)
var water_surface_y := 0.0
var bob_t := 0.0
const BOB_AMP := 6.0
const BOB_SPEED := 2.2
const WATERLINE_SHADER := preload("res://actors/villager/waterline.gdshader")
const WATERLINE_DEPTH := 4.0  # Flotando, el agua le llega a la cintura
var _waterline: ShaderMaterial

# Ahogo
const DROWN_DELAY := 5.0      # Segundos antes de empezar a hundirse
const SINK_SPEED  := 120.0    # px/s al hundirse
const FADE_RATE   := 0.6      # Alfa por segundo que se reduce
var drowning := false
var drown_elapsed := 0.0

# Comido por el tiburón
var eaten := false

# --- Muerte por disparo: el cadáver sale despedido y cae en ragdoll ---
const SHOT_FORCE := 300.0     # Empuje horizontal del balazo
const SHOT_HOP := 240.0       # Saltito hacia arriba al recibir el tiro
const HEAD_Y := 0.0           # Impactos por encima de esto (local) son tiros a la cabeza
const FEET_DROP := 16.0       # Tirado en el piso, el centro queda más abajo que de pie
const CORPSE_TIME := 12.0     # Segundos tirado antes de desvanecerse
var dead := false
var corpse_grounded := false
var corpse_vel := Vector2.ZERO
var floor_y := 0.0            # Altura del "piso" donde cae el cadáver
var corpse_timer := 0.0
var fall_vx := 0.0            # Deriva horizontal al caer (cadáver empujado fuera de la isla)

# --- Muerte por rayo (ver Lightning): se electrocuta (tieso, temblando y con el esqueleto a
# la vista), queda carbonizado y humeando, y se desarma en cenizas de la cabeza a los pies.
# Si le cayó en la isla se queda ahí; volando sigue cayendo y se deshace cuando queda tirado,
# y en el agua se hunde.
enum Zap { NONE, SHOCK, CHARRED, ASHES }
const SHOCK_TIME := 1.1
const CHAR_TIME := 0.8        # Carbonizado, todavía entero, antes de deshacerse
const ASH_TIME := 1.2         # Lo que tarda en deshacerse
const XRAY_HZ := 11.0         # Cuadros de rayos X por segundo
const HEAD_TOP := -44.0       # Coronilla y planta de los pies (local)
const FEET := 32.0
const CRUMBLE_EDGE := 8.0     # Lo que sobresale el borde desgranado (ver waterline.gdshader)
var zap_state := Zap.NONE
var _zap_t := 0.0
var _zap_pinned := false      # Le cayó en la isla: no se mueve de ahí
var _xray_mat: ShaderMaterial # El esqueleto: con el recorte del agua, pero sin oscurecerse
var _arcs: ZapArcs
var _smoke: CPUParticles2D
var _pile: AshPile

# --- Meteorito (ver Meteor): lo mira venir con la boca abierta y la explosión lo hace volar ---
var _scared := 0.0

# --- Fuego: agarrado (o cayendo) arriba de la llama de una antorcha se calienta y se prende.
# Prendido fuego grita y corre desesperado por la isla, y contagia a los que toca. Tirándolo al
# agua se apaga (queda tiznado un rato); si no, se va tostando y muere carbonizado, y se hace
# cenizas como con el rayo. Un cadáver también se quema, y más rápido.
const IGNITE_TIME := 0.5         # Segundos en el fuego hasta prenderse
const HEAT_COOL := 1.5           # Lo que se enfría por segundo lejos del fuego
const BURN_TIME := 5.0           # Prendido fuego, hasta morir carbonizado
const CORPSE_BURN_TIME := 2.0
const BURN_SOOT := 0.6           # Lo tostado que llega a quedar antes de morir (ver waterline.gdshader)
const SOOT_FADE := 0.04          # Apagado, lo que se le va el tizne por segundo
const SPREAD_DIST := 16.0        # Distancia (entre centros) a la que contagia el fuego
const PANIC_SPEED := 2.6         # Veces speed corriendo prendido fuego
const PANIC_TURN := Vector2(0.25, 0.6)   # Segundos entre volantazos
const PANIC_SWERVE := 1.1        # Cuánto dobla en cada volantazo (rad)
const SCREAM_EVERY := Vector2(0.6, 1.0)
const FIRE_LIGHT_ENERGY := 0.8   # De noche ilumina alrededor, como una antorcha
var on_fire := false
var _heat := 0.0
var _burn_t := 0.0
var _soot := 0.0
var _scream_t := 0.0
var _flames: Flames
var _sparks: CPUParticles2D
var _fire_light: PointLight2D

# --- Tornado (ver Tornado): lo chupa, lo hace girar alrededor del embudo y al rato lo revolea ---
const TORNADO_COOL := 1.2        # Recién revoleado, un ratito sin que lo vuelva a chupar
var tornado: Tornado             # El que lo tiene girando (null: ninguno)
var _tornado_cool := 0.0

# --- Diluvio (ver Storm): si el agua de la inundación lo alcanza se lo lleva flotando ---
const FLOOD_DEPTH := 6.0         # Flotando en la orilla inundada, el agua le tapa las piernas
const FLOOD_FLEE := 0.07         # Si el agua está así de cerca (en rel, ver Storm.shore_rel)...
const FLOOD_FLEE_TIME := 1.2     # ...se escapa corriendo un rato para el medio de la isla
const FLOOD_FLEE_SPEED := 2.0
var flooded := false             # Flota en la isla inundada (no en el mar)
var _flee := 0.0
var _flee_bias := 0.0            # Cada uno se escapa para un lado un poco distinto

# --- Gripe: se contagia. Primero la incuba sin que se note; después anda pálido y verdoso,
# lento, se para a cada rato, estornuda (y el estornudo contagia a los que tiene adelante) y
# no reza. Al final se cura (y queda inmune un tiempo) o se muere. Aparece sola cada tanto
# (ver World) y la pueden agarrar los que se llevó el agua del diluvio. Se ve en el carnet.
enum Flu { HEALTHY, INCUBATING, SICK, IMMUNE }
const INCUBATION := Vector2(8.0, 14.0)
const SICK_TIME := Vector2(35.0, 50.0)
const IMMUNE_TIME := 120.0
const FLU_DEATH_CHANCE := 0.3
const FLU_SPEED := 0.55          # Veces speed, enfermo
const FLU_REST_CHANCE := 0.7     # Enfermo se para mucho más seguido
const FLU_TINT := 0.55           # Lo verdoso que se pone (ver waterline.gdshader)
const SNEEZE_EVERY := Vector2(3.0, 7.0)
const SNEEZE_REACH := 46.0       # Hasta dónde llega el estornudo, para adelante...
const SNEEZE_CONE := 0.6         # ...en un cono de este coseno
const SNEEZE_CATCH := 0.5        # Probabilidad de contagiar a cada uno que alcanza
const CLOSE_CATCH := 4.0         # Segundos pegado a un enfermo hasta contagiarse
const SOAKED_CATCH := 0.35       # Probabilidad de agarrársela si se lo llevó el agua del diluvio
var flu := Flu.HEALTHY
var flu_t := 0.0                 # Lo que le falta a la etapa de ahora
var _flu_tint := 0.0
var _sneeze_t := 0.0
var _exposure := 0.0
static var _sneeze_sound: AudioStreamWAV

# --- Espacio personal y empujones ---
# Los aldeanos no chocan físicamente entre sí: se esquivan con una separación suave.
# El que está agarrado sí empuja a los demás, y los puede tirar de la isla.
const SEPARATION_RADIUS := 18.0  # Distancia (entre pies) a la que empiezan a apartarse
const SEPARATION_SPEED := 35.0   # Velocidad de apartarse cuando están encimados
const BODY_HALF_W := 10.0        # Medio ancho del cuerpo (cápsula) para los empujones
const BODY_TOP := -36.0          # Extremos del cuerpo (local), igual que la colisión
const BODY_BOTTOM := 31.0
const SHOVE_TIME := 0.4          # Tras un empujón, salir de la isla = caerse
const SHOVE_FRICTION := 1500.0   # Frenado del empujón (px/s²)
const MAX_SHOVE := 600.0
var shove_vel := Vector2.ZERO
var shove_timer := 0.0

# --- Comida: medio coco en el piso ---
const FOOD_SPEED := 1.8          # Van a la comida más rápido que cuando pasean
const EAT_REACH := 6.0
const EAT_TIME := 1.8
const FOOD_GIVE_UP := 10.0       # Si no llega en este tiempo (trabado en el borde), la deja
const FOOD_COOLDOWN := 5.0       # ...y por un rato no busca otra
var food: Coconut
var _eat_t := 0.0
var _food_t := 0.0
var _food_cooldown := 0.0
var _rig_rest := Vector2.ZERO

# --- Charlas: cada tanto, dos que andan cerca y con ganas se juntan a charlar un rato. El que
# la empieza va hasta el lado del otro, se miran y hablan por turnos (con un globito arriba de
# la cabeza y un bla-bla con su voz). Según cómo les fue se quieren más o menos (ver
# Relations): así se hacen amigos, enemigos o pareja, y los enemigos a veces terminan a los
# empujones. Cuando alguien se muere, su pareja y sus amigos lloran. Se ve en el carnet.
enum Bubble { NONE, DOTS, QUESTION, EXCLAIM, MUSIC, SUN, LAUGH, HEART, SMILE, ANGER, TEAR }
const CHAT_EVERY := Vector2(12.0, 25.0) # Después de una charla, hasta tener ganas de otra
const CHAT_SEEK := 130.0                # Hasta dónde busca con quién charlar
const CHAT_SEEK_EVERY := 0.5
const CHAT_GAP := 40.0                  # Charlando, uno al lado del otro (entre centros)
const CHAT_REACH := 3.0
const CHAT_APPROACH := 5.0              # Si no llega al lado del otro en este tiempo, lo deja
const CHAT_TURNS := Vector2i(3, 6)
const CHAT_TURN := Vector2(0.8, 1.2)    # Lo que dura el globito de cada uno
const CHAT_PAUSE := 0.3                 # Entre un turno y otro
const CHAT_MOOD := 3.0                  # Ganando o perdiendo más que esto, se les nota
const REACT_TIME := 1.6                 # La cara que ponen al terminar
const MOURN_TIME := 4.0
const FIGHT_CHANCE := 0.5               # Enemigos que se pelearon: alguno empuja al otro
const FIGHT_SHOVE := 170.0
const BABBLE_DB := -16.0
var chat_with: Villager
var bubble := Bubble.NONE               # Lo que dice (ver SpeechBubble)
var bubble_t := 0.0
var _chat_lead := false                 # La empezó él: la lleva él
var _chat_talking := false              # Ya están uno al lado del otro (si no, va yendo)
var _chat_t := 0.0
var _chat_turn := 0
var _chat_len := 0
var _chat_delta := 0.0                  # Cómo les va a ir (ver Relations.chat_delta)
var _chat_cool := 0.0                   # Hasta tener ganas de charlar
var _chat_seek := 0.0
var _talking := 0.0                     # Hablando: mueve la boca
static var _babbles: Array[AudioStreamWAV] = []

# --- Fe y miedo: cuánto creen en vos (el dios de la isla) y cuánto te temen, de 0 a 100. Con
# eso son devotos, fanáticos, herejes o aterrados (ver creed). La fe sube con los milagros
# (curarlos, rescatarlos del agua, o ver que curaste a otro) y baja de a poco si no hacés nada
# por ellos, y de golpe si se les muere la pareja o un amigo. El miedo sube con lo que ven:
# alguien que se muere cerca (más si lo querían), que los agarres o los revolees, el sol o la
# luna perturbados; y se les va pasando (charlando, más rápido). Si pasás el mouse cerca, el
# devoto se arrodilla y te reza, el fanático también pero temblando, el aterrado sale
# corriendo y el hereje ni te mira; con un arma afuera, los que te temen se agachan. Rezando
# dejan ofrendas según la fe y el miedo, y la fe recarga la devoción (ver World). Se ve en el
# carnet y se guarda con la partida.
enum Creed { DEVOUT, ZEALOT, HERETIC, TERRIFIED }
enum Pose { NONE, PRAY, COWER }         # Ver VillagerRig
const FAITH_START := Vector2(55.0, 75.0)
const FEAR_START := Vector2(0.0, 10.0)
const BELIEVES_AT := 40.0               # Con esta fe o más cree en vos...
const FEARS_AT := 50.0                  # ...y con este miedo o más te teme
const FAITH_DRIFT := 0.02               # Fe que pierde por segundo (1,2 por minuto) si no hacés nada
const FEAR_FADE := 0.12                 # Miedo que se le pasa por segundo...
const FEAR_FADE_CHAT := 3.0             # ...y charlando, el triple
const WITNESS_RADIUS := 260.0           # Hasta dónde ve lo que pasa (de cerca, más le afecta)
const WITNESS_STARE := 1.5              # Ve morir a alguien: se queda mirando, con la boca abierta
const FEAR_DEATH := 25.0                # Ver morir a alguien bien de cerca (de gripe, menos)
const FEAR_DEATH_GENTLE := 0.3
const FEAR_LOVED := 15.0                # Y si era su pareja o un amigo, más
const FAITH_LOST_PARTNER := 20.0        # Se le murió la pareja (lo haya visto o no)
const FAITH_LOST_FRIEND := 8.0
const FEAR_GRAB := 4.0                  # Que lo agarres...
const FEAR_THROW := 12.0                # ...o lo revolees
const FEAR_CREEPY := 0.4                # Por segundo, con el sol o la luna perturbados afuera
const FAITH_CURED := 15.0
const FAITH_RESCUED := 12.0             # Sacado del agua y dejado en la isla
const FAITH_MIRACLE := 4.0              # Ver de cerca que curaste a alguien
const THANKS_TIME := 1.6                # El corazoncito que pone al curarlo o rescatarlo
const HAND_NEAR := 110.0                # El mouse (tu mano) así de cerca: te nota
const SCRAM_TIME := 0.7                 # El aterrado sigue corriendo un poco después
const SCRAM_SPEED := 2.2                # Veces speed
const TRIBUTE_PAR := 70.0               # Fe más miedo que hacen 1 ofrenda por rezo
var faith := 60.0
var fear := 0.0
var pose := Pose.NONE                   # Lo que está haciendo por vos (ver VillagerRig)
var _scram := 0.0                       # Escapándose de tu mano
var _from_water := false                # Lo agarraste del agua: si lo dejás en la isla, lo rescataste
var _gentle_death := false              # Se murió de gripe (asusta menos a los que lo ven)

# --- Carnet: nombre y apellido los pone el jugador en modo seleccionar (ver VillagerCard) ---
enum Gender { MALE, FEMALE }
static var ids_issued := 0       # Números de carnet repartidos (se guarda con la partida)
var id_number := 0
var first_name := ""
var last_name := ""
const FEMALE_CHANCE := 0.5      # Al aparecer (las partidas guardadas traen el suyo)
var gender := Gender.MALE:
	set(g):
		gender = g
		if rig:
			rig.set_female(g == Gender.FEMALE)
		var pitch: Vector2 = VOICE_PITCH[g]
		_voice_pitch = randf_range(pitch.x, pitch.y)

# --- Voz: "¡wow!" al agarrarlo. Cada aldeano tiene su propio tono ---
const WOW := preload("res://audio/wow.wav")
const VOICE_DB := -4.0
const VOICE_PITCH := { Gender.MALE: Vector2(0.9, 1.25), Gender.FEMALE: Vector2(1.2, 1.5) }
var _voice: AudioStreamPlayer
var _voice_pitch := 1.0

# IA y animaciones
var wander_timer := 0.0
## Paseo: caminan un tramo y cada tanto se paran un rato. Arrancan, frenan y doblan de a poco.
const REST_CHANCE := 0.35        # Al terminar un tramo, probabilidad de quedarse quieto
const REST_TIME := Vector2(1.5, 4.0)
const WALK_ACCEL := 2.5          # Por segundo: de quieto a paso normal en 0.4 s
const TURN_RATE := 6.0           # Qué tan rápido dobla hacia la nueva dirección
const PACE := Vector2(0.85, 1.2) # Cada uno camina a su ritmo (veces speed)
var _walk := 0.0                 # 0 = quieto, 1 = a paso normal
var _heading := Vector2.ZERO     # Hacia dónde va de verdad (sigue a dir de a poco)
var _resting := false
@onready var rig: VillagerRig = get_node_or_null("Rig")

func _ready() -> void:
	randomize()
	speed *= randf_range(PACE.x, PACE.y)
	_pick_dir()
	wander_timer = randf_range(1.5, 4.0)
	_chat_cool = randf_range(2.0, CHAT_EVERY.y)
	faith = randf_range(FAITH_START.x, FAITH_START.y)   # Las partidas guardadas traen la suya
	fear = randf_range(FEAR_START.x, FEAR_START.y)
	input_pickable = true

	if rig:
		_rig_rest = rig.position
		_waterline = ShaderMaterial.new()
		_waterline.shader = WATERLINE_SHADER
		rig.material = _waterline

	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	_voice = AudioStreamPlayer.new()
	_voice.stream = WOW
	_voice.volume_db = VOICE_DB
	add_child(_voice)
	gender = Gender.FEMALE if randf() < FEMALE_CHANCE else Gender.MALE   # También elige el tono

	ids_issued += 1
	id_number = ids_issued
	_ensure_hud()
	if hud:
		hud.add_name_tag(self)

func _ensure_hud() -> void:
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud") as HUD

## "Nombre Apellido" (vacío si todavía no le pusieron nombre).
func full_name() -> String:
	return ("%s %s" % [first_name, last_name]).strip_edges()

func enter_water(surface_y: float) -> void:
	touching_water = true
	if flooded:
		return   # Flota en la isla inundada: lo maneja la inundación, no el mar
	water_surface_y = surface_y
	# Caminando por la orilla el cuerpo roza el agua, pero sigue en tierra
	if falling or dragging:
		Sea.ripple_at(self, Vector2(global_position.x, surface_y), 1.0 if falling else 0.6)
		_start_floating()

func _start_floating() -> void:
	in_water = true
	flooded = false
	falling = false
	drowning = false
	drown_elapsed = 0.0
	v_fall = 0.0
	bob_t = 0.0
	modulate.a = 1.0
	# Arrastrándolo por encima del agua sigue colgando y balanceándose
	if not dragging:
		swing_vel = 0.0
		z_index = 0

func exit_water() -> void:
	touching_water = false
	# Ahogándose se hunde por debajo del área de agua: sigue hasta desaparecer
	# (y el que flota en la isla inundada no estaba en el mar)
	if (drowning and not dragging) or flooded:
		return
	var was_floating := in_water
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0
	# Sacado del agua de un tirón y soltado antes de que el área lo detecte:
	# _stop_drag lo dejó "flotando" fuera del agua. Que se caiga, no que camine sobre el agua.
	var on_island := island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly)
	if was_floating and not dragging and not eaten and not on_island:
		_start_fall()

func _physics_process(dt: float) -> void:
	if eaten:
		return
	if dragging:
		velocity = Vector2.ZERO
		return
	if tornado:
		# Girando en el tornado: lo mueve él (ver Tornado)
		velocity = Vector2.ZERO
		if not is_instance_valid(tornado):
			tornado = null
			_start_fall()
		return
	if zap_pinned():
		# Le cayó el rayo en la isla: se queda ahí hasta hacerse cenizas
		velocity = Vector2.ZERO
		return

	# --- Agua: flotar o ahogarse ---
	if in_water:
		bob_t += dt

		# En la isla inundada: si bajó el agua queda en tierra; si no, la corriente se lo lleva
		if flooded and not drowning:
			var feet := ground_point()
			if not Storm.flooded_at(feet):
				_flood_dry()
				return
			var drift := Storm.current_at(feet)
			global_position += drift * dt
			water_surface_y += drift.y * dt

		# Temporizador de ahogo
		if not drowning:
			drown_elapsed += dt
			if drown_elapsed >= DROWN_DELAY:
				drowning = true

		if drowning:
			# Hundirse y desvanecerse
			global_position.y += SINK_SPEED * dt
			modulate.a = max(0.0, modulate.a - FADE_RATE * dt)
			rotation = lerp_angle(rotation, 0.5, 3.0 * dt)
			velocity = Vector2.ZERO
			if modulate.a <= 0.02:
				# Recién acá cuenta como sacrificio: mientras se hunde todavía se lo puede rescatar
				_grant_sacrifice_xp()
				queue_free()
			return
		else:
			# Flotación suave y balanceo
			var target_y := water_surface_y + sin(bob_t * BOB_SPEED) * BOB_AMP
			global_position.y = move_toward(global_position.y, target_y, 120.0 * dt)
			global_position.x += sin(bob_t * 0.8) * 10.0 * dt
			var float_rot := _lie_angle() if dead else 0.0
			rotation = lerp_angle(rotation, float_rot + sin(bob_t * 0.9) * 0.08, 4.0 * dt)
			velocity = Vector2.ZERO
			return

	# --- Caída libre fuera de la isla ---
	if falling:
		v_fall += GRAVITY * dt
		global_position.y += v_fall * dt
		global_position.x += fall_vx * dt
		rotation += swing_vel * dt

		# Los costados de la pantalla lo rebotan: así no se pierde volando fuera de la vista
		# (lo que se ve del mundo: con el zoom alejado, más; ver World.zoom)
		var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
		if (global_position.x < view.position.x + BODY_HALF_W and fall_vx < 0.0) \
				or (global_position.x > view.end.x - BODY_HALF_W and fall_vx > 0.0):
			fall_vx *= -0.5
			swing_vel *= -0.6

		# Lanzado dentro del agua (sin entrar de nuevo al área): al bajar vuelve a flotar
		if touching_water and v_fall > 0.0:
			_start_floating()
			return

		# Si cae de regreso a la tierra (no mientras sube, ni apenas lanzado sobre la isla)
		if island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly):
			if v_fall > 0.0 and (_flight_left_island or global_position.y - _launch_y > THROW_LAND_DROP):
				_land_on_island()
				return
		else:
			_flight_left_island = true

		var kill_y := view.end.y + 150.0
		if global_position.y > kill_y:
			queue_free()
		return

	if dead:
		_corpse_physics(dt)
		return

	# --- IA normal caminando en la isla ---
	var gp := ground_point()
	if Storm.flooded_at(gp):
		_swept_by_flood()   # Lo alcanzó el agua
		return
	_flee = maxf(0.0, _flee - dt)
	if Storm.water_near(gp, FLOOD_FLEE):
		# Se le viene el agua encima: se escapa corriendo para el medio de la isla
		if _flee <= 0.0:
			_flee_bias = randf_range(-0.4, 0.4)
		_flee = FLOOD_FLEE_TIME
		dir = (island_center - global_position).normalized().rotated(_flee_bias)
		_update_sprite_flip()
		_resting = false
		wander_timer = maxf(wander_timer, FLOOD_FLEE_TIME)
		if food != null:
			food.release_eater()
	rotation = lerp_angle(rotation, 0.0, 10.0 * dt)
	shove_vel = shove_vel.move_toward(Vector2.ZERO, SHOVE_FRICTION * dt)
	shove_timer = maxf(0.0, shove_timer - dt)
	_food_cooldown = maxf(0.0, _food_cooldown - dt)
	if on_fire and food != null:
		food.release_eater()   # Prendido fuego no se queda comiendo
	if food != null and _food_ai(dt):
		return
	if chat_with != null and _chat_ai(dt):
		return
	_seek_chat(dt)
	# Asustado (ve venir un meteorito) se queda quieto mirándolo, y rezando o agachado de miedo
	# también; prendido fuego (o escapándose del agua o de tu mano) corre sin parar
	var hurry := on_fire or _flee > 0.0 or _scram > 0.0
	var stop := (_resting or is_scared() or pose != Pose.NONE) and not hurry
	_walk = move_toward(_walk, 0.0 if stop else 1.0, WALK_ACCEL * dt * (4.0 if hurry else 1.0))
	# Al doblar va más despacio (y si vuelve para atrás, frena y arranca de nuevo)
	_heading = _heading.lerp(dir, 1.0 - exp(-TURN_RATE * (2.0 if hurry else 1.0) * dt))
	var pace := speed
	if on_fire:
		pace *= PANIC_SPEED
	elif _flee > 0.0:
		pace *= FLOOD_FLEE_SPEED
	elif _scram > 0.0:
		pace *= SCRAM_SPEED
	elif flu == Flu.SICK:
		pace *= FLU_SPEED
	velocity = _heading * pace * smoothstep(0.0, 1.0, _walk) + _separation() + shove_vel
	var prev_pos := global_position
	move_and_slide()

	# Si cruza el borde del polígono de la isla (o se iba a meter en el agua de la
	# inundación), retroceder y girar hacia el centro. Si ya estaba afuera no se retrocede:
	# así vuelve caminando.
	var into_flood := Storm.flooded_at(ground_point())
	if into_flood or (island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(global_position, island_poly)):
		if shove_timer > 0.0:
			# Lo empujaron fuera de la isla: se cae (o al agua de la inundación: se lo lleva)
			if into_flood and Geometry2D.is_point_in_polygon(global_position, island_poly):
				_swept_by_flood()
			else:
				_fall_from_shove()
			return
		if Geometry2D.is_point_in_polygon(prev_pos, island_poly):
			global_position = prev_pos
			_heading = Vector2.ZERO   # Frena en el borde y sale para el otro lado
		var to_center := (island_center - global_position).normalized()
		dir = to_center.rotated(randf_range(-0.35, 0.35)).normalized()
		_update_sprite_flip()
		_resting = false
		wander_timer = randf_range(1.5, 3.5)
	else:
		wander_timer -= dt
		if on_fire:
			# Corre para cualquier lado, en zigzag (casi sin darse vuelta del todo)
			if wander_timer <= 0.0 or wander_timer > PANIC_TURN.y:
				_resting = false
				if dir == Vector2.ZERO:
					_pick_dir()
				else:
					dir = dir.rotated(randf_range(-PANIC_SWERVE, PANIC_SWERVE))
					_update_sprite_flip()
				wander_timer = randf_range(PANIC_TURN.x, PANIC_TURN.y)
		elif wander_timer <= 0.0:
			if not _resting and randf() < (FLU_REST_CHANCE if flu == Flu.SICK else REST_CHANCE):
				_resting = true
				wander_timer = randf_range(REST_TIME.x, REST_TIME.y)
			else:
				_resting = false
				_pick_dir()
				wander_timer = randf_range(2.0, 5.0)

# --- COMIDA ---
## Parado o caminando en la isla (no agarrado, volando, en el agua, en un tornado ni muerto).
func is_idle() -> bool:
	return not (dragging or falling or in_water or eaten or dead or tornado)

func wants_food() -> bool:
	return food == null and is_idle() and not on_fire and _food_cooldown <= 0.0

func go_eat(c: Coconut) -> void:
	food = c
	_eat_t = 0.0
	_food_t = 0.0
	_resting = false

func stop_eating() -> void:
	food = null
	_eat_t = 0.0
	if rig:
		rig.position = _rig_rest

## Le cayó un coco en la cabeza.
func bonk(at: Vector2) -> void:
	if rig:
		rig.hit(at, Vector2.DOWN, 0.6)
	_ensure_hud()
	if hud:
		hud.popup_text("¡Bonk!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_TEXT)

## Camina hasta su medio coco y se lo come. false si ya no tiene comida.
func _food_ai(dt: float) -> bool:
	if not is_instance_valid(food) or food.eater != self:
		stop_eating()
		return false
	var to := food.eat_spot(self) - global_position
	if _eat_t > 0.0 or to.length() <= EAT_REACH:
		# Comiendo: quieto, mirando el coco y masticando
		velocity = Vector2.ZERO
		if rig:
			rig.set_facing_left(food.point().x < global_position.x)
			rig.position = _rig_rest + Vector2(0, -absf(sin(_eat_t * 12.0)) * 2.5)
		_eat_t += dt
		food.nibble(_eat_t / EAT_TIME)
		if _eat_t >= EAT_TIME:
			var f := food
			stop_eating()
			f.finish_eating(self)
			_pick_dir()
			wander_timer = randf_range(1.5, 3.0)
		return true

	_food_t += dt
	if _food_t > FOOD_GIVE_UP:
		food.release_eater()
		_food_cooldown = FOOD_COOLDOWN
		return false
	dir = to.normalized()
	_update_sprite_flip()
	velocity = (dir * speed * FOOD_SPEED + shove_vel).limit_length(maxf(to.length() / dt, shove_vel.length()))
	var prev_pos := global_position
	move_and_slide()
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(global_position, island_poly):
		if shove_timer > 0.0:
			_fall_from_shove()
			return true
		global_position = prev_pos
		# El lugar para comer queda fuera de la isla: come estirándose desde el borde
		if to.length() < 24.0:
			_eat_t = 0.001
	return true

# --- CHARLAS ---
## Tranquilo en la isla: sin quemarse, asustarse, comer, escaparse del agua o de tu mano, ni
## rezarte o agacharse de miedo.
func can_chat() -> bool:
	return is_idle() and not on_fire and not is_scared() and _flee <= 0.0 and food == null \
			and _scram <= 0.0 and pose == Pose.NONE

func wants_chat() -> bool:
	return chat_with == null and _chat_cool <= 0.0 and can_chat()

## Con ganas de charlar, busca a alguien cerca que también tenga ganas: más seguido a su
## pareja y sus amigos, poco a sus enemigos.
func _seek_chat(dt: float) -> void:
	if not wants_chat():
		return
	_chat_seek -= dt
	if _chat_seek > 0.0:
		return
	_chat_seek = CHAT_SEEK_EVERY
	var best: Villager
	var best_w := 0.0
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or not o.wants_chat():
			continue
		var d := o.global_position.distance_to(global_position)
		if d > CHAT_SEEK:
			continue
		var w := Relations.chat_weight(self, o) * (1.5 - d / CHAT_SEEK) * randf()
		if w > best_w:
			best = o
			best_w = w
	if best:
		_start_chat(best)

func _start_chat(o: Villager) -> void:
	chat_with = o
	o.chat_with = self
	_chat_lead = true
	o._chat_lead = false
	_chat_talking = false
	_chat_t = 0.0
	_chat_turn = 0
	_chat_len = randi_range(CHAT_TURNS.x, CHAT_TURNS.y)
	_chat_delta = Relations.chat_delta(self, o)

## Charlando con chat_with: el que la empezó va hasta el lado del otro, y ahí se quedan
## mirándose y hablando por turnos (lo lleva el que la empezó). false si se cortó.
func _chat_ai(dt: float) -> bool:
	var o := chat_with
	if not is_instance_valid(o) or o.chat_with != self or not can_chat() or not o.can_chat():
		_end_chat()
		return false
	if not _chat_lead:
		_stand_facing(o)   # Espera (o charla) parado, mirándolo
		return true
	if not _chat_talking:
		_chat_t += dt
		if _chat_t > CHAT_APPROACH:
			_end_chat()
			return false
		if _walk_to_chat(o, dt):
			_chat_talking = true
			_chat_t = CHAT_PAUSE
		return true
	_stand_facing(o)
	_chat_t -= dt
	if _chat_t > 0.0:
		return true
	if _chat_turn >= _chat_len:
		_finish_chat(o)
		return true
	# Hablan por turnos: primero el que la empezó
	var speaker: Villager = self if _chat_turn % 2 == 0 else o
	_chat_turn += 1
	var time := randf_range(CHAT_TURN.x, CHAT_TURN.y)
	speaker.say(_chat_topic(o), time)
	_chat_t = time + CHAT_PAUSE
	return true

## Va caminando hasta quedar al lado del otro (del lado de donde viene; si ahí no hay isla,
## del otro). true al llegar.
func _walk_to_chat(o: Villager, dt: float) -> bool:
	var side := 1.0 if global_position.x >= o.global_position.x else -1.0
	var spot := o.global_position + Vector2(CHAT_GAP * side, 0.0)
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(spot, island_poly):
		spot = o.global_position - Vector2(CHAT_GAP * side, 0.0)
	var to := spot - global_position
	if to.length() <= CHAT_REACH:
		return true
	dir = to.normalized()
	_update_sprite_flip()
	velocity = (dir * speed + shove_vel).limit_length(maxf(to.length() / dt, shove_vel.length()))
	var prev_pos := global_position
	move_and_slide()
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(global_position, island_poly):
		if shove_timer > 0.0:
			_fall_from_shove()
			return false
		global_position = prev_pos
		# Trabado en la orilla: si ya está cerca, charlan desde ahí
		return global_position.distance_to(o.global_position) < CHAT_GAP * 1.8
	return false

## Parado mirando al otro (solo se mueve si lo empujan).
func _stand_facing(o: Villager) -> void:
	_walk = 0.0   # Al terminar arranca a caminar de a poco
	if rig:
		rig.set_facing_left(o.global_position.x < global_position.x)
	velocity = shove_vel
	if velocity == Vector2.ZERO:
		return
	var prev_pos := global_position
	move_and_slide()
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(global_position, island_poly):
		if shove_timer > 0.0:
			_fall_from_shove()
		else:
			global_position = prev_pos

## De qué habla: según lo que son y si la charla viene bien o mal.
func _chat_topic(o: Villager) -> Bubble:
	var bad := _chat_delta < -CHAT_MOOD and randf() < 0.6
	match Relations.kind(self, o):
		Relations.Kind.COUPLE:
			if bad:
				return Bubble.ANGER
			return [Bubble.HEART, Bubble.HEART, Bubble.MUSIC, Bubble.LAUGH].pick_random()
		Relations.Kind.FRIEND:
			if bad:
				return [Bubble.ANGER, Bubble.EXCLAIM].pick_random()
			return [Bubble.LAUGH, Bubble.LAUGH, Bubble.MUSIC, Bubble.SUN, Bubble.EXCLAIM].pick_random()
		Relations.Kind.ENEMY:
			if bad or randf() < 0.5:
				return Bubble.ANGER
			return [Bubble.EXCLAIM, Bubble.QUESTION].pick_random()
	if bad:
		return [Bubble.ANGER, Bubble.EXCLAIM, Bubble.QUESTION].pick_random()
	return [Bubble.DOTS, Bubble.QUESTION, Bubble.SUN, Bubble.EXCLAIM, Bubble.MUSIC, Bubble.LAUGH].pick_random()

## Terminó la charla: se quieren más o menos según cómo les fue, lo muestran con una cara (y
## si cambió lo que son, con un cartel), y cada uno sigue con lo suyo.
func _finish_chat(o: Villager) -> void:
	var ev := Relations.change(self, o, _chat_delta)
	var k := Relations.kind(self, o)
	var face := Bubble.NONE
	if ev == Relations.Event.BROKE_UP:
		face = Bubble.TEAR
	elif _chat_delta > CHAT_MOOD:
		face = Bubble.HEART if k == Relations.Kind.COUPLE else Bubble.SMILE
	elif _chat_delta < -CHAT_MOOD:
		face = Bubble.ANGER
	if face != Bubble.NONE:
		say(face, REACT_TIME, false)
		o.say(face, REACT_TIME, false)
	var n := Relations.news(ev)
	var news: String = n[0]
	var color: Color = n[1]
	# Los enemigos que se pelearon a veces terminan a los empujones
	if k == Relations.Kind.ENEMY and _chat_delta < 0.0 and randf() < FIGHT_CHANCE:
		var pusher: Villager = self if randf() < 0.5 else o
		var pushed: Villager = o if pusher == self else self
		pushed._get_pushed_by(pusher)
		if news == "":
			news = "¡Pelea!"
			color = HUD.C_WARN
	_ensure_hud()
	if hud and news != "":
		var mid := (get_global_transform_with_canvas().origin + o.get_global_transform_with_canvas().origin) * 0.5
		hud.popup_text(news, mid + Vector2(0, -100), color)
	_end_chat()
	_wander_off()
	o._wander_off()

## Se terminó (o se cortó) la charla: un rato sin ganas de otra, los dos.
func _end_chat() -> void:
	var o := chat_with
	chat_with = null
	_chat_cool = randf_range(CHAT_EVERY.x, CHAT_EVERY.y)
	if is_instance_valid(o) and o.chat_with == self:
		o.chat_with = null
		o._chat_cool = randf_range(CHAT_EVERY.x, CHAT_EVERY.y)

func _wander_off() -> void:
	_resting = false
	_pick_dir()
	wander_timer = randf_range(1.5, 3.0)

## Un enemigo lo empujó (y capaz que lo tira de la isla).
func _get_pushed_by(o: Villager) -> void:
	var push := Vector2(1.0 if global_position.x >= o.global_position.x else -1.0, 0.0)
	get_shoved(Vector2.ZERO, push * FIGHT_SHOVE)
	if rig:
		rig.hit(body_center(), push, 0.8)
	_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
	_voice.play()

## Dice algo (o pone una cara, si no talk): un globito arriba de la cabeza durante time
## segundos. Hablando mueve la boca con un bla-bla en su tono de voz.
func say(b: Bubble, time: float, talk := true) -> void:
	bubble = b
	bubble_t = time
	if not talk:
		return
	if _babbles.is_empty():
		for i in 6:
			_babbles.append(_make_babble())
	var p := AudioStreamPlayer.new()
	p.stream = _babbles.pick_random()
	p.volume_db = BABBLE_DB
	p.pitch_scale = _voice_pitch * randf_range(0.95, 1.05)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	_talking = p.stream.get_length() / p.pitch_scale

## Hablando abre y cierra la boca (0..1, ver VillagerRig).
func talk_mouth() -> float:
	return absf(sin(_talking * 18.0)) * 0.55 if _talking > 0.0 else 0.0

## Se murió: los que lo vieron se asustan (más si lo querían) y se quedan mirando; su pareja y
## sus amigos lloran un rato y pierden fe. Y deja de contar para los demás.
func _mourn() -> void:
	_ensure_hud()
	var at := body_center()
	var scary := FEAR_DEATH * (FEAR_DEATH_GENTLE if _gentle_death else 1.0)
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.dead or o.eaten or o.is_queued_for_deletion():
			continue
		var k := Relations.kind(self, o)
		var seen := o._witness(at)
		if seen > 0.0:
			var loved := k == Relations.Kind.COUPLE or k == Relations.Kind.FRIEND
			o.add_fear((scary + (FEAR_LOVED if loved else 0.0)) * seen)
			o.scare(WITNESS_STARE, at)
		match k:
			Relations.Kind.COUPLE:
				o.say(Bubble.TEAR, MOURN_TIME, false)
				o.add_faith(-FAITH_LOST_PARTNER)
				if hud:
					hud.popup_text("Perdió a su pareja", o.get_global_transform_with_canvas().origin + Vector2(0, -100), HUD.C_MUTED)
			Relations.Kind.FRIEND:
				o.say(Bubble.TEAR, MOURN_TIME * 0.6, false)
				o.add_faith(-FAITH_LOST_FRIEND)
	Relations.forget(self)

## "Bla-bla-bla": unas sílabas cortitas con la vocal que sube y baja de tono.
static func _make_babble() -> AudioStreamWAV:
	var rate := 22050
	var buf := PackedFloat32Array()
	var ph := 0.0
	for s in randi_range(4, 7):
		var n := int(rate * randf_range(0.05, 0.085))
		var f0 := randf_range(200.0, 300.0)
		var f1 := f0 * randf_range(0.8, 1.25)
		var bright := randf_range(0.2, 0.6)
		for i in n:
			var k := float(i) / n
			ph += TAU * lerpf(f0, f1, k) / rate
			var env := minf(1.0, k * 10.0) * minf(1.0, (1.0 - k) * 6.0)
			buf.append((sin(ph) + bright * sin(ph * 2.0) + 0.25 * sin(ph * 3.0)) * env * 0.3)
		for i in int(rate * randf_range(0.02, 0.045)):   # Pausita entre sílabas
			buf.append(0.0)
	return Synth.wav(buf, rate, 0.9)

# --- FE Y MIEDO ---
## Devoto, fanático, hereje o aterrado, según cuánto cree en vos y cuánto te teme.
func creed() -> Creed:
	if faith >= BELIEVES_AT:
		return Creed.ZEALOT if fear >= FEARS_AT else Creed.DEVOUT
	return Creed.TERRIFIED if fear >= FEARS_AT else Creed.HERETIC

func add_faith(amount: float) -> void:
	faith = clampf(faith + amount, 0.0, 100.0)

func add_fear(amount: float) -> void:
	fear = clampf(fear + amount, 0.0, 100.0)

## Lo que deja cada vez que reza (ver World): más cuanto más cree en vos y más te teme.
func tribute() -> float:
	return (faith + fear) / TRIBUTE_PAR

## Cuánto le afecta algo que pasó en at: 1 bien de cerca, nada si no lo vio.
func _witness(at: Vector2) -> float:
	var d := body_center().distance_to(at)
	return 0.0 if d > WITNESS_RADIUS else lerpf(1.0, 0.4, d / WITNESS_RADIUS)

## Le hiciste un milagro (lo curaste o lo rescataste): te cree más y te lo agradece. Los que
## lo vieron (si lo curaste) también te creen un poco más.
func _thank(amount: float, seen_by_others: bool) -> void:
	add_faith(amount)
	say(Bubble.HEART, THANKS_TIME, false)
	if not seen_by_others:
		return
	var at := body_center()
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != self and not o.dead and not o.eaten:
			o.add_faith(FAITH_MIRACLE * o._witness(at))

## La fe se le va gastando y el miedo se le va pasando (o crece, con el cielo perturbado). Si
## tu mano anda cerca reacciona según lo que cree: reza (pose), se escapa (_scram) o nada; y
## si sacaste un arma, el que te teme se agacha.
func _update_faith(dt: float) -> void:
	_scram = maxf(0.0, _scram - dt)
	pose = Pose.NONE
	if dead or eaten or is_queued_for_deletion():
		return
	add_faith(-FAITH_DRIFT * dt)
	add_fear(-FEAR_FADE * (FEAR_FADE_CHAT if chat_with else 1.0) * dt)
	if _creepy_sky():
		add_fear(FEAR_CREEPY * dt)
	_ensure_hud()
	if hud == null or not hud.visible or not is_idle() or on_fire or _flee > 0.0:
		return
	var hand := get_global_mouse_position()
	var near := body_center().distance_to(hand) < HAND_NEAR
	var c := creed()
	if near and c == Creed.TERRIFIED:
		# Sale corriendo para el otro lado (aunque estuviera comiendo)
		_scram = SCRAM_TIME
		dir = (global_position - hand).normalized()
		_update_sprite_flip()
		_resting = false
		if food:
			food.release_eater()
	elif food:
		return   # Comiendo, ni te mira
	elif near and c != Creed.HERETIC:
		pose = Pose.PRAY
		if rig:
			rig.set_facing_left(hand.x < global_position.x)
	elif fear >= FEARS_AT and HUD.aiming():
		pose = Pose.COWER

## El sol o la luna perturbados (o la Luna de Sangre) a la vista.
func _creepy_sky() -> bool:
	var sky := get_tree().get_first_node_in_group("sky")
	return sky != null and (sky.blood_moon or (sky.sun.creepy and sky.sun.is_up) or (sky.moon.creepy and sky.moon.is_up))

## Empuje suave para no quedar encimado con otros aldeanos en tierra.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.dragging or o.falling or o.in_water or o.eaten or o.tornado:
			continue
		var d := global_position - o.global_position
		var dist := d.length()
		if dist >= SEPARATION_RADIUS:
			continue
		if dist < 0.01:
			d = Vector2.RIGHT.rotated(randf() * TAU)
			dist = 1.0
		push += d / dist * (1.0 - dist / SEPARATION_RADIUS)
	return push.limit_length(1.0) * SEPARATION_SPEED

## Eje del cuerpo en coordenadas globales (cápsula de radio BODY_HALF_W).
func _body_segment() -> PackedVector2Array:
	return PackedVector2Array([
		to_global(Vector2(0.0, BODY_TOP + BODY_HALF_W)),
		to_global(Vector2(0.0, BODY_BOTTOM - BODY_HALF_W)),
	])

## Llamado mientras está agarrado: aparta a los aldeanos que toca.
func _shove_others() -> void:
	var mine := _body_segment()
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.dragging or o.falling or o.in_water or o.eaten or o.tornado:
			continue
		var theirs := o._body_segment()
		var pts := Geometry2D.get_closest_points_between_segments(mine[0], mine[1], theirs[0], theirs[1])
		var d := pts[1] - pts[0]
		var dist := d.length()
		if dist >= BODY_HALF_W * 2.0:
			continue
		var n := d / dist if dist > 0.01 else Vector2(1.0 if o.global_position.x >= global_position.x else -1.0, 0.0)
		# Lo saca de adentro del cuerpo, y si el golpe viene rápido, sale despedido
		o.get_shoved(n * (BODY_HALF_W * 2.0 - dist), n * maxf(_mouse_vel.dot(n), 0.0))

func get_shoved(offset: Vector2, vel: Vector2) -> void:
	global_position += offset
	vel = vel.limit_length(MAX_SHOVE)
	if dead:
		floor_y += offset.y
		if absf(vel.x) > absf(corpse_vel.x):
			corpse_vel.x = vel.x
		corpse_timer = 0.0
		return
	if vel.length() > shove_vel.length():
		shove_vel = vel
	shove_timer = SHOVE_TIME

func _fall_from_shove() -> void:
	var push := shove_vel
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	_start_fall()
	if falling:
		fall_vx = push.x
		v_fall = minf(push.y, 0.0)
		swing_vel = clampf(push.x * 0.02, -8.0, 8.0)  # Que trastabille al caer

func _grant_sacrifice_xp() -> void:
	if xp_granted:
		return
	xp_granted = true
	_mourn()   # Toda muerte pasa por acá
	_ensure_hud()
	if hud and hud.has_method("add_xp"):
		hud.add_xp(1)
		hud.add_offerings(SACRIFICE_OFFERING)
		hud.popup_text(tr("+%d ofrendas") % SACRIFICE_OFFERING, get_global_transform_with_canvas().origin + Vector2(0, -60), HUD.C_OFFERING)

# --- DISPARO / MUERTE ---
## Llamado por la pistola. hit_point y shot_dir en coordenadas globales.
func shoot(hit_point: Vector2, shot_dir: Vector2) -> void:
	if eaten:
		return
	var headshot := to_local(hit_point).y < HEAD_Y
	var power := 1.3 if headshot else 1.0
	_spawn_blood(hit_point, shot_dir, 40 if headshot else 24)
	if rig:
		rig.hit(hit_point, shot_dir, power)
		rig.add_bullet_mark(hit_point)

	var was_dead := dead
	_die()

	var push := shot_dir.normalized() * SHOT_FORCE * power
	# Giro según dónde pegó respecto al centro de masa (en la cabeza lo voltea)
	var spin := (hit_point - to_global(BODY_COM)).cross(push) * 0.0016

	if dragging:
		swing_vel += spin
	elif in_water:
		global_position.x += signf(push.x) * 4.0
		swing_vel = 0.0
	elif falling:
		fall_vx += push.x * 0.6
		v_fall = minf(v_fall, 0.0) - SHOT_HOP * 0.5
		swing_vel += spin
	else:
		if not was_dead:
			swing_vel = 0.0
		corpse_grounded = false
		corpse_vel = Vector2(push.x, minf(push.y, 0.0) - SHOT_HOP)
		# Que se desplome hacia donde lo empujaron
		swing_vel += spin + signf(push.x) * 4.0

func _die() -> void:
	if dead:
		corpse_timer = 0.0
		modulate.a = 1.0
		return
	dead = true
	corpse_grounded = false
	corpse_timer = 0.0
	floor_y = global_position.y + FEET_DROP
	velocity = Vector2.ZERO
	_grant_sacrifice_xp()
	if rig:
		rig.set_dead()

func _corpse_physics(dt: float) -> void:
	velocity = Vector2.ZERO
	global_position.x += corpse_vel.x * dt

	# Si el empujón lo sacó de la isla, cae al agua
	var ground_pt := Vector2(global_position.x, floor_y - FEET_DROP)
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(ground_pt, island_poly):
		var vx := corpse_vel.x
		var vy := corpse_vel.y
		_start_fall()
		if falling:
			fall_vx = vx
			v_fall = vy
		return

	if not corpse_grounded:
		corpse_vel.y += GRAVITY * dt
		global_position.y += corpse_vel.y * dt
		rotation += swing_vel * dt
		if global_position.y >= floor_y and corpse_vel.y > 0.0:
			global_position.y = floor_y
			if corpse_vel.y > 260.0:
				# Rebote
				corpse_vel = Vector2(corpse_vel.x * 0.55, -corpse_vel.y * 0.3)
				swing_vel *= 0.5
			else:
				corpse_grounded = true
				corpse_vel.y = 0.0
				swing_vel = 0.0
				if zap_state == Zap.NONE:   # Carbonizado ya no sangra
					_spawn_blood_pool()
		return

	# Tirado donde llega el agua de la inundación: se lo lleva flotando
	if zap_state == Zap.NONE and Storm.flooded_at(ground_point()):
		_swept_by_flood()
		return

	# Tirado en el piso: se arrastra un poco y queda acostado
	corpse_vel.x = move_toward(corpse_vel.x, 0.0, 600.0 * dt)
	rotation = lerp_angle(rotation, _lie_angle(), 10.0 * dt)
	corpse_timer += dt
	if corpse_timer > CORPSE_TIME:
		modulate.a = maxf(0.0, modulate.a - 0.8 * dt)
		if modulate.a <= 0.02:
			queue_free()

## Acostado de costado: el más cercano entre ±90°.
func _lie_angle() -> float:
	if absf(angle_difference(rotation, PI * 0.5)) <= absf(angle_difference(rotation, -PI * 0.5)):
		return PI * 0.5
	return -PI * 0.5

func _spawn_blood_pool() -> void:
	var pool := BloodPool.new()
	# En la capa del piso, así queda debajo de aldeanos y decoraciones
	var layer := get_tree().get_first_node_in_group("ground_layer")
	if layer:
		layer.add_child(pool)
	else:
		get_parent().add_child(pool)
		get_parent().move_child(pool, get_index())  # Debajo del cuerpo
	pool.global_position = Vector2(global_position.x, floor_y + 7.0)

class BloodPool extends Node2D:
	const COLOR := Color(0.55, 0.02, 0.03, 0.85)
	var radius := 0.0

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_property(self, "radius", randf_range(13.0, 18.0), 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_interval(CORPSE_TIME)
		tw.tween_property(self, "modulate:a", 0.0, 2.0)
		tw.tween_callback(queue_free)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, radius, COLOR, true, -1.0, true)
		draw_circle(Vector2(radius * 0.35, -radius * 0.2), radius * 0.55, COLOR.darkened(0.15), true, -1.0, true)

# --- RAYO ---
## Si le puede caer un rayo (vivo o cadáver; no si ya se está friendo).
func can_zap() -> bool:
	return can_blast() and modulate.a > 0.2

## Le cayó un rayo (ver Lightning): se electrocuta y muere.
func zap() -> void:
	if not can_zap():
		return
	_put_out()   # El rayo se encarga de carbonizarlo
	zap_state = Zap.SHOCK
	_zap_t = 0.0
	_zap_pinned = not (dragging or falling or in_water) and (not dead or corpse_grounded)
	_die()
	_xray_mat = ShaderMaterial.new()
	_xray_mat.shader = WATERLINE_SHADER
	_arcs = ZapArcs.new()
	add_child(_arcs)

## Electrocutado o carbonizado en la isla: se queda quieto donde le cayó.
func zap_pinned() -> bool:
	return zap_state != Zap.NONE and _zap_pinned

## 0..1: cuánto ya se hizo cenizas.
func ashes() -> float:
	return clampf(_zap_t / ASH_TIME, 0.0, 1.0) if zap_state == Zap.ASHES else 0.0

## Distancia de p a la superficie del cuerpo (la cápsula): <= 0 si cae adentro.
func body_distance(p: Vector2) -> float:
	var seg := _body_segment()
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])) - BODY_HALF_W

func body_center() -> Vector2:
	return to_global(BODY_COM)

func _update_zap(dt: float) -> void:
	if zap_state == Zap.NONE or eaten:
		return
	_zap_t += dt
	match zap_state:
		Zap.SHOCK:
			if _zap_t >= SHOCK_TIME:
				zap_state = Zap.CHARRED
				_zap_t = 0.0
				_arcs.queue_free()
				_start_smoke()
		Zap.CHARRED:
			if in_water and not dragging:
				drowning = true   # Carbonizado no flota: se hunde
			elif _zap_t >= CHAR_TIME and not (dragging or falling) \
					and (_zap_pinned or (corpse_grounded and corpse_timer > 0.4)):
				_start_ashes()
		Zap.ASHES:
			_pile.amount = ashes()
			if _zap_t >= ASH_TIME:
				_pile.finish()
				queue_free()
	if _smoke:
		_smoke.global_rotation = 0.0   # El humo sube aunque esté tirado
		_smoke.emitting = zap_state == Zap.CHARRED and not in_water
	_update_zap_fx()

## Rayos X, carbonizado y desarmarse (ver waterline.gdshader).
func _update_zap_fx() -> void:
	if _waterline == null:
		return
	var xray := zap_state == Zap.SHOCK and fmod(_zap_t * XRAY_HZ, 1.0) < 0.5
	_waterline.set_shader_parameter("xray", xray)
	rig.set_xray(xray, _xray_mat)
	var burnt := 1.0
	var embers := 0.3
	match zap_state:
		Zap.SHOCK:
			burnt = 0.6 * _zap_t / SHOCK_TIME   # Se va tostando mientras se electrocuta
			embers = 0.0
		Zap.CHARRED:
			burnt = lerpf(0.6, 1.0, minf(1.0, _zap_t / 0.15))
			embers = lerpf(1.0, 0.3, minf(1.0, _zap_t / CHAR_TIME))
	_waterline.set_shader_parameter("burnt", burnt)
	_waterline.set_shader_parameter("embers", embers)
	if zap_state == Zap.ASHES:
		var from := to_global(Vector2(0, HEAD_TOP))
		var axis := (to_global(Vector2(0, FEET)) - from).normalized()
		var reach := ashes() * (FEET - HEAD_TOP + CRUMBLE_EDGE)
		_waterline.set_shader_parameter("crumble", reach)
		_waterline.set_shader_parameter("crumble_from", from)
		_waterline.set_shader_parameter("crumble_axis", axis)
		# El polvo se desprende de donde se está deshaciendo (hasta que ya casi no queda nada)
		_pile.dust.global_position = from + axis * minf(reach, FEET - HEAD_TOP)
		_pile.dust.global_rotation = rotation
		_pile.dust.emitting = ashes() < 0.85

func _start_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.amount = 14
	_smoke.lifetime = 1.1
	_smoke.local_coords = false
	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_smoke.emission_rect_extents = Vector2(8, 20)
	_smoke.direction = Vector2.UP
	_smoke.spread = 20.0
	_smoke.gravity = Vector2(0, -30)
	_smoke.initial_velocity_min = 12.0
	_smoke.initial_velocity_max = 30.0
	_smoke.scale_amount_min = 2.5
	_smoke.scale_amount_max = 5.0
	_smoke.color_ramp = _fade_ramp(Color(0.22, 0.21, 0.21, 0.6), Color(0.5, 0.5, 0.5, 0.0))
	_smoke.position = Vector2(0, -6)
	add_child(_smoke)

func _start_ashes() -> void:
	zap_state = Zap.ASHES
	_zap_t = 0.0
	_zap_pinned = true
	_pile = AshPile.new()
	var lying := absf(sin(rotation))
	_pile.width = lerpf(14.0, 24.0, lying)
	var layer := get_tree().get_first_node_in_group("ground_layer")
	(layer if layer else get_parent()).add_child(_pile)
	# Al pie si está parado; tirado, debajo del cuerpo
	var a := to_global(Vector2(0, HEAD_TOP))
	var b := to_global(Vector2(0, FEET))
	_pile.global_position = Vector2((a.x + b.x) * 0.5, maxf(a.y, b.y) + lying * 9.0 - 1.0)

func _exit_tree() -> void:
	Relations.forget(self)   # También el que se cayó al vacío
	# Si se va a mitad de hacerse cenizas (se lo comió el tiburón), el montoncito igual se apaga
	if is_instance_valid(_pile) and _pile.is_inside_tree():
		_pile.finish()

static func _fade_ramp(from: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([from, to])
	return g

## Chispazos que le recorren el cuerpo mientras se electrocuta (coords del aldeano).
class ZapArcs extends Node2D:
	var _arcs: Array[PackedVector2Array] = []
	var _t := 0.0

	func _process(dt: float) -> void:
		_t -= dt
		if _t > 0.0:
			return
		_t = 0.05
		_arcs.clear()
		for i in randi_range(2, 3):
			var a := Vector2(randf_range(-16.0, 16.0), randf_range(HEAD_TOP + 4.0, FEET - 4.0))
			var b := a + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 22.0)
			_arcs.append(Lightning.jagged(a, b, 0.35, 3))
		queue_redraw()

	func _draw() -> void:
		for a in _arcs:
			Lightning.paint_bolt(self, a, 1.1, 1.0)

## Montoncito de cenizas donde se deshizo (en la capa del piso). Mientras se deshace le cae
## polvo encima (dust: el aldeano lo va poniendo donde se está deshaciendo) y las brasas se
## apagan solas.
class AshPile extends Node2D:
	const ASH := Color(0.25, 0.24, 0.24)
	const ASH_TOP := Color(0.42, 0.4, 0.39)
	const SOOT := Color(0.08, 0.07, 0.07, 0.5)
	const EMBER := Color(1.0, 0.45, 0.1)
	var width := 12.0
	var amount := 0.0:   # 0..1: cuánto ya cayó
		set(v):
			amount = v
			queue_redraw()
	var dust: CPUParticles2D
	var done := false
	var _glow := 1.0
	var _specks: Array[Vector3] = []   # x, y (0..1 del montoncito), radio

	func _ready() -> void:
		for i in 8:
			_specks.append(Vector3(randf_range(-0.75, 0.75), randf_range(0.2, 0.8), randf_range(0.8, 1.6)))
		dust = CPUParticles2D.new()
		dust.amount = 40
		dust.lifetime = 0.6
		dust.local_coords = false
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.emission_rect_extents = Vector2(12, 1.5)
		dust.direction = Vector2.DOWN
		dust.spread = 180.0
		dust.initial_velocity_min = 5.0
		dust.initial_velocity_max = 25.0
		dust.gravity = Vector2(0, 90)
		dust.scale_amount_min = 1.2
		dust.scale_amount_max = 2.6
		dust.color_ramp = Villager._fade_ramp(Color(0.3, 0.29, 0.29), Color(0.5, 0.48, 0.47, 0.0))
		add_child(dust)

	func _process(_dt: float) -> void:
		if _glow > 0.0:
			queue_redraw()

	func finish() -> void:
		if done:
			return
		done = true
		dust.emitting = false
		var tw := create_tween()
		tw.tween_property(self, "_glow", 0.0, 2.5)
		tw.tween_interval(CORPSE_TIME)
		tw.tween_property(self, "modulate:a", 0.0, 2.0)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var w := width * (0.4 + 0.6 * amount)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, w * 1.4, SOOT, true, -1.0, true)   # Hollín en la arena
		draw_set_transform(Vector2.ZERO)
		var h := 9.0 * amount
		if h < 0.5:
			return
		draw_colored_polygon(_mound(w, h), ASH)
		draw_set_transform(Vector2(-w * 0.12, -h * 0.2))
		draw_colored_polygon(_mound(w * 0.65, h * 0.7), ASH_TOP)
		draw_set_transform(Vector2.ZERO)
		var t := Time.get_ticks_msec() / 1000.0
		for i in _specks.size():
			var s := _specks[i]
			var p := Vector2(s.x * w, -s.y * h * pow(1.0 - s.x * s.x, 0.6))
			if i < 3 and _glow > 0.0:   # Brasas
				draw_circle(p, 1.2, Color(EMBER, _glow * (0.5 + 0.5 * sin(t * 8.0 + i * 2.0))), true, -1.0, true)
			else:
				draw_circle(p, s.z, ASH_TOP.lightened(0.15), true, -1.0, true)

	## Lomita de ancho 2w y alto h, apoyada en y = 0.
	static func _mound(w: float, h: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 17:
			var u := lerpf(-1.0, 1.0, i / 16.0)
			pts.append(Vector2(u * w, 1.5 - h * pow(maxf(0.0, 1.0 - u * u), 0.6)))
		return pts

# --- METEORITO ---
## Si lo puede alcanzar una explosión (vivo o cadáver; no si se está friendo por un rayo).
func can_blast() -> bool:
	return not eaten and zap_state == Zap.NONE and not is_queued_for_deletion()

## Ve venir un meteorito desde from: lo mira, con la boca abierta, durante time segundos.
func scare(time: float, from: Vector2) -> void:
	_scared = maxf(_scared, time)
	if rig and is_idle():
		rig.set_facing_left(from.x < global_position.x)

func is_scared() -> bool:
	return _scared > 0.0

## Lo alcanzó la explosión de un meteorito (ver Meteor) y sale volando con push. Si es letal
## muere chamuscado; si no, sale despedido vivo (y capaz que cae al agua).
func blast(push: Vector2, lethal: bool) -> void:
	if not can_blast():
		return
	var dir := push.normalized()
	if lethal:
		_spawn_blood(body_center(), dir, 18)
		_die()
		if _waterline:
			_waterline.set_shader_parameter("burnt", 0.45)   # Chamuscado (ver waterline.gdshader)
	elif not dead:
		_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
		_voice.play()
	if rig:
		rig.hit(body_center(), dir, 1.2)
	if dragging:
		return
	_launch(push, island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly))
	swing_vel = clampf(swing_vel + randf_range(-6.0, 6.0), -12.0, 12.0)   # Que dé vueltas en el aire

# --- FUEGO ---
func _update_fire(dt: float) -> void:
	if eaten or zap_state != Zap.NONE or is_queued_for_deletion():
		return
	if on_fire:
		if in_water or Storm.wet():   # El agua (o la lluvia del diluvio) lo apaga
			_put_out(true)
			return
		_burn_t += dt
		var burn_time := CORPSE_BURN_TIME if dead else BURN_TIME
		_soot = maxf(_soot, BURN_SOOT * minf(1.0, _burn_t / burn_time))
		_waterline.set_shader_parameter("burnt", _soot)
		_waterline.set_shader_parameter("embers", 0.5 + 0.3 * sin(_burn_t * 9.0))
		_sparks.global_rotation = 0.0   # Suben aunque esté tirado o colgando
		_smoke.global_rotation = 0.0
		_update_fire_light()
		if not dead:
			_scream_t -= dt
			if _scream_t <= 0.0:
				_scream_t = randf_range(SCREAM_EVERY.x, SCREAM_EVERY.y)
				_voice.pitch_scale = _voice_pitch * randf_range(1.05, 1.2)
				_voice.play()
		if _burn_t >= burn_time:
			_burn_out()
		return

	# Apagado: el tizne se le va de a poco
	if _soot > 0.0 and not dead:
		_soot = maxf(0.0, _soot - SOOT_FADE * dt)
		_waterline.set_shader_parameter("burnt", _soot)
		_waterline.set_shader_parameter("embers", 0.0)

	if _touching_fire():
		_heat += dt
		if _heat >= IGNITE_TIME:
			ignite()
	else:
		_heat = maxf(0.0, _heat - HEAT_COOL * dt)

## En la llama de una antorcha (solo agarrado o volando: caminando pasa por delante o por
## detrás), o pegado a otro aldeano que se está quemando. Con la lluvia no se prende.
func _touching_fire() -> bool:
	if in_water or modulate.a < 0.2 or Storm.wet():
		return false
	if dragging or falling:
		for t in get_tree().get_nodes_in_group("torch"):
			if (t as Decoration).burns(self):
				return true
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != self and o.on_fire and o.global_position.distance_to(global_position) < SPREAD_DIST:
			return true
	return false

## Se prende fuego.
func ignite() -> void:
	if on_fire or eaten or zap_state != Zap.NONE:
		return
	on_fire = true
	_burn_t = 0.0
	_scream_t = 0.0
	_resting = false
	wander_timer = 0.0
	if _flames == null:
		_flames = Flames.new()
		add_child(_flames)   # Después del Rig: las llamas van por delante del cuerpo
		_sparks = _make_sparks()
		add_child(_sparks)
	_flames.on = true
	_sparks.emitting = true
	if _smoke == null:
		_start_smoke()
	_smoke.emitting = true
	if _fire_light == null:
		_fire_light = PointLight2D.new()
		_fire_light.texture = Decoration._torch_light_texture()
		_fire_light.color = Decoration.TORCH_LIGHT_COLOR
		_fire_light.enabled = false
		add_child(_fire_light)
	_ensure_hud()
	if hud and not dead:
		hud.popup_text("¡Se prendió fuego!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_WARN)

## Se apaga. steam: cayó al agua (sale vapor).
func _put_out(steam := false) -> void:
	if not on_fire:
		return
	on_fire = false
	_heat = 0.0
	_flames.on = false
	_sparks.emitting = false
	_smoke.emitting = false
	_fire_light.enabled = false
	_waterline.set_shader_parameter("embers", 0.0)
	if steam:
		_spawn_steam()
		_ensure_hud()
		if hud and not dead:
			hud.popup_text("¡Fiuuu!", get_global_transform_with_canvas().origin + Vector2(0, -60), HUD.C_TEXT)

## Se terminó de quemar: muere carbonizado y después se hace cenizas (ver _update_zap).
func _burn_out() -> void:
	var pinned := not (dragging or falling or in_water) and (not dead or corpse_grounded)
	_put_out()
	_die()
	zap_state = Zap.CHARRED
	_zap_t = 0.0
	_zap_pinned = pinned
	_soot = 1.0

func _update_fire_light() -> void:
	var sky := get_tree().get_first_node_in_group("sky")
	var night: float = sky.night if sky else 0.0
	var dark := smoothstep(0.55, 0.95, night)
	_fire_light.enabled = dark > 0.01
	_fire_light.energy = FIRE_LIGHT_ENERGY * dark * (1.0 + sin(_burn_t * 19.0) * 0.08 + sin(_burn_t * 31.0) * 0.05)

## Chispas que se desprenden y suben (en coords del mundo: si lo mueven, dejan estela).
func _make_sparks() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 18
	p.lifetime = 0.8
	p.local_coords = false
	p.position = Vector2(0, -6)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(9, 22)
	p.direction = Vector2.UP
	p.spread = 35.0
	p.gravity = Vector2(0, -70)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color_ramp = _fade_ramp(Color(1.0, 0.85, 0.35), Color(0.9, 0.25, 0.05, 0.0))
	return p

## Lenguas de fuego por todo el cuerpo (coords del aldeano) que siempre apuntan para arriba,
## aunque esté tirado o colgando. Se prenden y se apagan de a poco (on).
class Flames extends Node2D:
	const GLOW := Color(1.0, 0.6, 0.2, 0.16)
	const LAYERS := [[1.0, Color(0.92, 0.25, 0.05, 0.92)], [0.68, Color(1.0, 0.55, 0.1)], [0.38, Color(1.0, 0.92, 0.5)]]
	const TONGUES := 13
	const SIZE := Vector2(7.0, 22.0)   # Medio ancho y alto de una lengua a pleno
	const NECK := -8.0                 # Más arriba está la cabeza, que es más ancha que el cuerpo
	const GROW := 4.0                  # Prenderse / apagarse del todo tarda 1/esto segundos
	var on := true
	var amount := 0.0
	var _tongues: Array[Vector4] = []  # x, y de la base, tamaño, fase

	func _ready() -> void:
		for i in TONGUES:
			var y := lerpf(FEET - 6.0, HEAD_TOP + 8.0, float(i) / (TONGUES - 1))
			var half := 19.0 if y < NECK else 11.0
			_tongues.append(Vector4(randf_range(-half, half), y, randf_range(0.7, 1.2), randf() * TAU))

	func _process(dt: float) -> void:
		amount = move_toward(amount, 1.0 if on else 0.0, GROW * dt)
		visible = amount > 0.0
		if visible:
			queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var up: float = -(get_parent() as Node2D).global_rotation
		draw_circle(Vector2(0, -6), 34.0 * amount, GLOW, true, -1.0, true)
		for tg in _tongues:
			var h := SIZE.y * tg.z * amount * (1.0 + 0.25 * sin(t * 13.0 + tg.w) + 0.12 * sin(t * 23.0 + tg.w * 2.0))
			var w := SIZE.x * tg.z * amount
			var sway := 3.0 * sin(t * 7.0 + tg.w)
			draw_set_transform(Vector2(tg.x, tg.y), up)
			for layer: Array in LAYERS:
				var k: float = layer[0]
				draw_colored_polygon(_tongue(w * k, h * k, sway * k), layer[1])
		draw_set_transform(Vector2.ZERO)

	## Lengua de fuego apoyada en (0, 0): abajo redonda, arriba en punta (que se mece con sway).
	static func _tongue(w: float, h: float, sway: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 7:
			var a := PI * i / 6.0
			pts.append(Vector2(cos(a) * w, sin(a) * w * 0.8))
		for i in range(1, 8):
			var u := i / 7.0
			pts.append(Vector2(-w * pow(1.0 - u, 1.3) + sway * u * u, -h * u))
		for i in range(6, 0, -1):
			var u := i / 7.0
			pts.append(Vector2(w * pow(1.0 - u, 1.3) + sway * u * u, -h * u))
		return pts

## Bocanada de vapor al apagarse en el agua.
func _spawn_steam() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 24
	p.lifetime = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10, 6)
	p.direction = Vector2.UP
	p.spread = 30.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color_ramp = _fade_ramp(Color(0.95, 0.97, 1.0, 0.8), Color(0.85, 0.9, 0.95, 0.0))
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, -10)
	p.emitting = true
	p.finished.connect(p.queue_free)

## Punto del piso debajo de él (para la inundación y el tornado): sus pies, o la superficie
## del mar si está flotando ahí.
func ground_point() -> Vector2:
	if in_water and not flooded:
		return global_position + Vector2(0, WATERLINE_DEPTH)
	if dead and corpse_grounded and not in_water:
		return global_position + Vector2(0, FEET - 2.0 - FEET_DROP)   # Acostado
	return global_position + Vector2(0, FEET - 2.0)

# --- TORNADO ---
## Si un tornado lo puede chupar (vivo o cadáver; no si se está friendo por un rayo, ni
## recién revoleado).
func can_be_lifted() -> bool:
	return can_blast() and not dragging and _tornado_cool <= 0.0 and modulate.a > 0.3

## Lo chupó un tornado: deja lo que estaba haciendo y desde ahora lo mueve él (ver Tornado).
func enter_tornado(t: Tornado) -> void:
	tornado = t
	if food:
		food.release_eater()
	falling = false
	in_water = false
	flooded = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0
	corpse_grounded = false
	velocity = Vector2.ZERO
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	if not dead:
		_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
		_voice.play()

## El tornado lo suelta revoleado con vel: sale volando (y cae donde caiga).
func exit_tornado(vel: Vector2) -> void:
	tornado = null
	_tornado_cool = TORNADO_COOL
	_launch(vel, false)
	swing_vel = clampf(swing_vel + randf_range(-9.0, 9.0), -12.0, 12.0)   # Sale dando vueltas

# --- DILUVIO ---
## Lo alcanzó el agua de la inundación (ver Storm): queda flotando donde está y la corriente
## se lo lleva hacia la orilla. Como en el mar, si no lo rescatan se ahoga (si el agua baja
## antes, se salva).
func _swept_by_flood() -> void:
	if food:
		food.release_eater()
	_start_floating()
	flooded = true
	water_surface_y = global_position.y + FLOOD_DEPTH
	z_index = 0
	velocity = Vector2.ZERO
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	if not dead:
		_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
		_voice.play()
		if randf() < SOAKED_CATCH:
			catch_flu()   # Empapado se resfría (se le nota recién al rato)

## Bajó el agua: queda en tierra donde estaba (vivo sigue caminando).
func _flood_dry() -> void:
	flooded = false
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0
	if dead:
		corpse_grounded = true
		floor_y = global_position.y
		corpse_vel = Vector2.ZERO
		return
	_land_on_island()

# --- GRIPE ---
## Se contagió: la incuba un rato sin que se note (solo lo dice el carnet). Los sanos nada más:
## el que ya la tiene o se acaba de curar no.
func catch_flu() -> void:
	if flu != Flu.HEALTHY or dead or eaten:
		return
	flu = Flu.INCUBATING
	flu_t = randf_range(INCUBATION.x, INCUBATION.y)
	_exposure = 0.0

## Para cargar la partida: en qué etapa estaba y lo que le faltaba.
func set_flu(state: Flu, time_left: float) -> void:
	flu = state
	flu_t = time_left
	_flu_tint = FLU_TINT if flu == Flu.SICK else 0.0
	_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y)

## La peste (ver Plague): se enferma ya, sin incubarla y aunque estuviera inmune.
func infect() -> void:
	if dead or eaten or flu == Flu.SICK:
		return
	flu = Flu.SICK
	flu_t = randf_range(SICK_TIME.x, SICK_TIME.y)
	_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y) * 0.5
	_exposure = 0.0

## El poder de curar (ver Cure): se le va la gripe (queda inmune) y, si se estaba quemando,
## se apaga y se le va el tizne. true si tenía algo que curar.
func cure() -> bool:
	if dead or eaten or zap_state != Zap.NONE:
		return false
	var flu_cured := flu == Flu.INCUBATING or flu == Flu.SICK
	if flu_cured:
		_recover()   # Ya dice "¡Se curó!"
	var burns := on_fire or _soot > 0.0
	if burns:
		_put_out()
		_soot = 0.0
		_heat = 0.0
		if _waterline:
			_waterline.set_shader_parameter("burnt", 0.0)
		_ensure_hud()
		if hud and not flu_cured:
			hud.popup_text("¡Se curó!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SHOP)
	if flu_cured or burns:
		_thank(FAITH_CURED, true)
	return flu_cured or burns

## Enfermo de verdad (con síntomas, contagia y no reza).
func is_sick() -> bool:
	return flu == Flu.SICK and not dead

func _update_flu(dt: float) -> void:
	if eaten or is_queued_for_deletion():
		return
	if not dead:
		match flu:
			Flu.HEALTHY:
				_update_exposure(dt)
			Flu.INCUBATING:
				flu_t -= dt
				if flu_t <= 0.0:
					flu = Flu.SICK
					flu_t = randf_range(SICK_TIME.x, SICK_TIME.y)
					_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y) * 0.5
			Flu.SICK:
				flu_t -= dt
				if is_idle() and not on_fire:
					_sneeze_t -= dt
					if _sneeze_t <= 0.0:
						_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y)
						_sneeze()
					# Termina parado en la isla: no se muere colgando del mouse ni flotando
					if flu_t <= 0.0:
						if randf() < FLU_DEATH_CHANCE:
							_die_of_flu()
						else:
							_recover()
			Flu.IMMUNE:
				flu_t -= dt
				if flu_t <= 0.0:
					flu = Flu.HEALTHY
	# Se pone verdoso de a poco (y muerto de gripe se queda así)
	var tint := FLU_TINT if flu == Flu.SICK else 0.0
	if not dead or tint > 0.0:
		_flu_tint = move_toward(_flu_tint, tint, dt * 0.15)
	if _waterline:
		_waterline.set_shader_parameter("sick", _flu_tint)

## Sano y parado en la isla: si se queda pegado a un enfermo, al rato se contagia.
func _update_exposure(dt: float) -> void:
	var near := false
	if is_idle():
		for node in get_tree().get_nodes_in_group("villager"):
			var o := node as Villager
			if o and o != self and o.is_sick() and o.is_idle() \
					and o.global_position.distance_to(global_position) < SEPARATION_RADIUS * 1.4:
				near = true
				break
	_exposure = _exposure + dt if near else maxf(0.0, _exposure - dt * 0.5)
	if _exposure >= CLOSE_CATCH:
		catch_flu()

## ¡Achís! Se sacude, le salen gotitas para adelante y contagia a los que tiene enfrente.
func _sneeze() -> void:
	var facing := rig.facing() if rig else 1.0
	var mouth := to_global(Vector2(7.0 * facing, -24.0))
	if rig:
		rig.hit(mouth, Vector2(facing, 0.6), 0.35)
		rig.sneeze()
	_spawn_droplets(mouth, Vector2(facing, 0.15))
	if _sneeze_sound == null:
		_sneeze_sound = _make_sneeze()
	var p := AudioStreamPlayer.new()
	p.stream = _sneeze_sound
	p.volume_db = VOICE_DB - 4.0
	p.pitch_scale = _voice_pitch * randf_range(0.92, 1.05)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	_ensure_hud()
	if hud:
		hud.popup_text("¡Achís!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_TEXT)
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.flu != Flu.HEALTHY or not o.is_idle():
			continue
		var d := o.global_position - global_position
		if d.length() < SNEEZE_REACH and (d.length() < SEPARATION_RADIUS or d.normalized().x * facing > SNEEZE_CONE) \
				and randf() < SNEEZE_CATCH:
			o.catch_flu()

func _recover() -> void:
	flu = Flu.IMMUNE
	flu_t = IMMUNE_TIME
	_ensure_hud()
	if hud:
		hud.popup_text("¡Se curó!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SHOP)

## No aguantó: se desploma donde está (cuenta como sacrificio, como cualquier muerte).
func _die_of_flu() -> void:
	_ensure_hud()
	if hud:
		hud.popup_text("Murió de gripe", get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_WARN)
	if food:
		food.release_eater()
	_gentle_death = true
	_die()
	swing_vel = (1.0 if randf() < 0.5 else -1.0) * randf_range(2.5, 4.0)   # Se cae para un costado
	corpse_vel = Vector2.ZERO

func _spawn_droplets(at: Vector2, toward: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 16
	p.lifetime = 0.5
	p.direction = toward
	p.spread = 22.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4
	p.color_ramp = _fade_ramp(Color(0.8, 0.95, 0.7, 0.85), Color(0.75, 0.9, 0.65, 0.0))
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

## "Aaa... ¡chís!": una vocal que sube y un soplido de ruido.
static func _make_sneeze() -> AudioStreamWAV:
	var rate := 22050
	var vowel := int(rate * 0.24)
	var burst := int(rate * 0.2)
	var buf := PackedFloat32Array()
	buf.resize(vowel + burst)
	var ph := 0.0
	for i in vowel:
		var k := float(i) / vowel
		ph += TAU * lerpf(230.0, 360.0, k * k) / rate
		var env := minf(1.0, k * 12.0) * (0.55 + 0.45 * k)
		buf[i] = (sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.0)) * env * 0.35
	var prev := 0.0
	var hp := 0.0
	for i in burst:
		var k := float(i) / burst
		var noise := randf_range(-1.0, 1.0)
		hp = 0.85 * (hp + noise - prev)   # Pasa-altos: la "ch" y la "s"
		prev = noise
		var env := minf(1.0, k * 40.0) * pow(1.0 - k, 2.0)
		buf[vowel + i] = (hp * 0.8 + sin(ph + TAU * 420.0 * i / rate) * 0.25 * (1.0 - k)) * env
	return Synth.wav(buf, rate, 0.9)

# --- TIBURÓN ---
## En el agua se hunde. En la isla (mouth = la boca del tiburón) se lo chupa hacia la boca.
func get_eaten(mouth := Vector2.INF) -> void:
	if eaten:
		return
	eaten = true
	set_physics_process(false)
	_grant_sacrifice_xp()
	_spawn_blood()
	var tw := create_tween().set_parallel()
	if mouth.is_finite():
		tw.tween_property(self, "global_position", mouth, 0.18).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "scale", Vector2.ONE * 0.2, 0.18).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "modulate:a", 0.0, 0.18).set_delay(0.06)
	else:
		tw.tween_property(self, "global_position:y", global_position.y + 45.0, 0.35).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_property(self, "rotation", 0.8, 0.35)
	tw.chain().tween_callback(queue_free)

# --- LUNA DE SANGRE ---
## Soltado sobre la Luna de Sangre: se lo chupa hacia la boca y se lo traga.
func _feed_to(moon: Moon) -> void:
	eaten = true
	set_physics_process(false)
	_grant_sacrifice_xp()
	var mouth := get_canvas_transform().affine_inverse() * moon.mouth_screen_pos()
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "global_position", mouth, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2.ONE * 0.15, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", rotation + TAU, 0.3)
	tw.chain().tween_callback(func():
		moon.feed()
		_spawn_blood(global_position, Vector2.UP, 36)
		queue_free())

func _spawn_blood(at: Vector2 = global_position, toward: Vector2 = Vector2.UP, amount := 28) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.7
	p.direction = toward
	p.spread = 50.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = Color(0.8, 0.05, 0.05)
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

func _pick_dir() -> void:
	var angle := randf() * TAU
	dir = Vector2(cos(angle), sin(angle)).normalized()
	_update_sprite_flip()

func _update_sprite_flip() -> void:
	if rig and abs(dir.x) > 0.05:
		rig.set_facing_left(dir.x < 0.0)

# --- MECÁNICA DE ARRASTRE (DRAG & DROP) ---
func _process(dt: float) -> void:
	if dragging:
		_update_drag(dt)
	_update_fire(dt)
	_update_zap(dt)
	_update_flu(dt)
	_update_faith(dt)
	_update_waterline()
	_scared = maxf(0.0, _scared - dt)
	_tornado_cool = maxf(0.0, _tornado_cool - dt)
	_chat_cool = maxf(0.0, _chat_cool - dt)
	_talking = maxf(0.0, _talking - dt)
	bubble_t = maxf(0.0, bubble_t - dt)

## Flotando (o hundiéndose) lo que queda debajo de la superficie no se ve.
func _update_waterline() -> void:
	if _waterline == null:
		return
	var cut := in_water and not dragging
	for m: ShaderMaterial in [_waterline, _xray_mat]:
		if m == null:
			continue
		m.set_shader_parameter("cut", cut)
		if cut:
			m.set_shader_parameter("water_y", water_surface_y + WATERLINE_DEPTH)

func _update_drag(dt: float) -> void:
	var m := get_global_mouse_position()
	if dt > 0.0:
		var mv := (m - _prev_mouse) / dt
		var ma := ((mv - _mouse_vel) / dt).limit_length(MAX_MOUSE_ACC)
		_mouse_vel = mv
		_mouse_acc = _mouse_acc.lerp(ma, 0.35)
		_throw_vel = _throw_vel.lerp(mv, 1.0 - exp(-THROW_SMOOTH * dt))
	_prev_mouse = m

	# Gravedad efectiva en el marco de la mano: al sacudir, el cuerpo se queda atrás
	var g := Vector2(0.0, GRAVITY) - _mouse_acc
	var r := (BODY_COM - grab_local).rotated(rotation)
	if r.length() > 4.0:
		swing_vel += SWING_K * r.normalized().cross(g / GRAVITY) * dt
	swing_vel *= exp(-SWING_DAMP * dt)
	rotation += swing_vel * dt

	# El punto agarrado queda pegado al cursor
	global_position = m - grab_local.rotated(rotation)
	_shove_others()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging and not eaten and not HUD.aiming():
			# En modo seleccionar no se lo agarra: se abre su carnet
			_ensure_hud()
			if hud and hud.select_mode:
				hud.select_villager(self)
			else:
				_start_drag()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Atrapa el soltado del click izquierdo en cualquier parte de la pantalla
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_drag()
		get_viewport().set_input_as_handled()

func _start_drag() -> void:
	dragging = true
	grab_local = (get_global_mouse_position() - global_position).rotated(-rotation)
	_prev_mouse = get_global_mouse_position()
	_mouse_vel = Vector2.ZERO
	_mouse_acc = Vector2.ZERO
	_throw_vel = Vector2.ZERO
	swing_vel = 0.0
	fall_vx = 0.0
	_zap_pinned = false   # Carbonizado también se lo puede levantar: se deshace al volver a quedar tirado
	set_physics_process(false)
	z_index = 10
	if not dead:
		_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
		_voice.play()
		add_fear(FEAR_GRAB)
	_from_water = not dead and (in_water or flooded)
	if dead:
		corpse_timer = 0.0
		modulate.a = 1.0
	# Si estaba medio desvanecido al ser rescatado, restaurar visibilidad parcial
	if drowning:
		modulate.a = max(modulate.a, 0.7)
	# Sacado del agua de la inundación: ya no flota (soltado en el agua, vuelve a flotar)
	if flooded:
		flooded = false
		in_water = false
		drowning = false
		drown_elapsed = 0.0

func _stop_drag() -> void:
	dragging = false
	var moon := get_tree().get_first_node_in_group("moon") as Moon
	if moon and moon.can_eat_at(get_viewport().get_mouse_position()):
		_feed_to(moon)
		return
	set_physics_process(true)
	z_index = 0

	var throw := _throw_vel.limit_length(THROW_MAX_SPEED)
	var on_island := island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly)
	if throw.length() >= THROW_MIN_SPEED:
		if not dead:
			add_fear(FEAR_THROW)
		_launch(throw, on_island)
	elif on_island:
		# Rescatado o depositado en tierra firme
		_land_on_island()
	else:
		if in_water:
			# Soltado dentro del agua: continúa flotando
			falling = false
			velocity = Vector2.ZERO
		else:
			# Soltado en el aire fuera de la isla: empieza caída libre
			_start_fall()

func _start_fall() -> void:
	if touching_water:
		_start_floating()
		return
	falling = true
	drowning = false
	drown_elapsed = 0.0
	v_fall = 0.0
	corpse_grounded = false
	velocity = Vector2.ZERO
	# Mantiene la rotación y el giro del ragdoll al soltarlo
	swing_vel = clampf(swing_vel, -12.0, 12.0)
	_launch_y = global_position.y
	_flight_left_island = true

## Soltado con impulso: sale volando con la velocidad del mouse, incluso desde el agua.
func _launch(vel: Vector2, from_island: bool) -> void:
	in_water = false
	flooded = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0
	falling = true
	corpse_grounded = false
	velocity = Vector2.ZERO
	fall_vx = vel.x
	v_fall = vel.y
	swing_vel = clampf(swing_vel + vel.x * 0.004, -12.0, 12.0)  # Que gire en el aire
	_launch_y = global_position.y
	_flight_left_island = not from_island
	z_index = 10  # Volando pasa por delante de palmeras y aldeanos

func _land_on_island() -> void:
	falling = false
	z_index = 0
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	modulate.a = 1.0
	velocity = Vector2.ZERO
	if dead:
		# El cadáver cae al piso desde donde está y sigue rodando un poco
		corpse_grounded = false
		corpse_vel = Vector2(fall_vx * 0.5, 0.0)
		floor_y = global_position.y + FEET_DROP
		fall_vx = 0.0
		v_fall = 0.0
		return
	v_fall = 0.0
	swing_vel = 0.0
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	_walk = 0.0   # Arranca a caminar de a poco
	_heading = Vector2.ZERO
	_pick_dir()
	if _from_water:
		_from_water = false
		_thank(FAITH_RESCUED, false)   # Lo rescataste
