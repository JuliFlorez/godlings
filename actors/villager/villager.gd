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
var _from_water := false                # Lo agarraste del agua: si lo dejás en la isla, lo rescataste

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
var inside := false               # Está adentro de su choza (no se lo ve ni lo alcanza nada; ver VillagerHome)
## Acostado en un altar de sacrificios esperando el final del ritual (lo mueve el altar, ver Altar)
var altar: Altar

# --- Muerte por disparo: el cadáver sale despedido y cae en ragdoll ---
const SHOT_FORCE := 300.0     # Empuje horizontal del balazo
const SHOT_HOP := 240.0       # Saltito hacia arriba al recibir el tiro
const HEAD_Y := 0.0           # Impactos por encima de esto (local) son tiros a la cabeza
const FEET_DROP := 16.0       # Tirado en el piso, el centro queda más abajo que de pie
const HEAD_TOP := -44.0       # Coronilla y planta de los pies (local)
const FEET := 32.0
const CORPSE_TIME := 12.0     # Segundos tirado antes de desvanecerse
var dead := false
var corpse_grounded := false
var corpse_vel := Vector2.ZERO
var floor_y := 0.0            # Altura del "piso" donde cae el cadáver
var corpse_timer := 0.0
var fall_vx := 0.0            # Deriva horizontal al caer (cadáver empujado fuera de la isla)
var _gentle_death := false              # Se murió de gripe o de hambre (asusta menos a los que lo ven)

# --- Fuego y rayo (ver VillagerBurn): se prende fuego o lo parte un rayo, queda carbonizado y se hace cenizas ---
var _burn: VillagerBurn
## Prendido fuego: corre desesperado, grita y contagia a los que toca.
var on_fire: bool:
	get:
		return _burn.on_fire
## Electrocutándose, carbonizado o haciéndose cenizas (ver VillagerBurn.Zap).
var zap_state: VillagerBurn.Zap:
	get:
		return _burn.zap_state

# --- Meteorito (ver Meteor): lo mira venir con la boca abierta y la explosión lo hace volar ---
var _scared := 0.0

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
const SCRAM_TIME := 0.7                 # El aterrado sigue corriendo un poco después
const SCRAM_SPEED := 2.2                # Veces speed
var _scram := 0.0                       # Escapándose (de tu mano, de un zombi o de un ritual)

# --- Gripe (ver VillagerFlu): se contagia, la incuba, se enferma y se cura (queda inmune) o se muere ---
var _flu: VillagerFlu
## En qué etapa de la gripe está (ver VillagerFlu.Stage).
var flu: VillagerFlu.Stage:
	get:
		return _flu.flu
## Lo que le falta a la etapa de ahora (segundos; se guarda con la partida).
var flu_t: float:
	get:
		return _flu.flu_t

# --- Espora zombi (ver VillagerSpore): el hongo que lo va dominando hasta hacerlo zombi y brotar ---
var _spore: VillagerSpore
## Cuánto lo domina el hongo: 0 sano .. 1 brota.
var spore: float:
	get:
		return _spore.spore
	set(value):
		_spore.spore = value

# --- Escudo y vacuna (ver Miracle): el escudo es una bendición, un aura dorada (ver Miracle.Aura)
# que lo protege un rato de los rayos, de las mordidas de zombi (ni lo persiguen, y con uno cerca ni
# se asusta) y de los contagios de gripe y de espora. La vacuna lo deja inmune a la gripe y a la
# espora por un tiempo largo; no cura (el que ya está enfermo sigue enfermo). Morirse se los saca.
# Se ven en el carnet y se guardan con la partida.
const SHIELD_TIME := 75.0
const VACCINE_TIME := 360.0        # Un día entero (ver Sky)
const FAITH_SHIELDED := 6.0        # Lo bendijiste...
const FAITH_VACCINATED := 8.0      # ...o lo vacunaste
var shield_t := 0.0                # Lo que le queda del escudo...
var vaccine_t := 0.0               # ...y de la vacuna (segundos)
var _aura: Miracle.Aura

# --- Resurrección (ver Miracle): sobre un cadáver reciente baja un haz de luz, el cuerpo sube
# flotando, se endereza y vuelve a la vida, sano: sin heridas, sin gripe, sin espora, sin hambre y
# sin quemaduras. Recupera lo que tenía con los demás (si mientras tanto su pareja se puso de novia
# con otro, quedan amigos) y sale del árbol de los que ya no están. Mientras sube, los devotos que lo
# ven se arrodillan, los aterrados salen corriendo y los herejes se quedan mirando; cuando vuelve,
# su familia (su pareja, sus padres, sus hijos y sus hermanos) te cree muchísimo más, sus amigos
# también, los que lo vieron te creen más y a los herejes les da miedo (más si lo vieron). A los que
# se murieron de viejos no: ya les había llegado la hora.
const RISE_TIME := 2.4             # Lo que tarda en volver, flotando en la luz
const RISE_FLOAT := 18.0           # Lo que sube flotando (px, sobre lo que mide parado)
const RISEN_HUNGER := 25.0         # Vuelve con la panza casi llena
const FAITH_RISEN := 40.0          # El que volvió...
const FAITH_RISEN_FAMILY := 45.0   # ...su familia...
const FAITH_RISEN_FRIEND := 20.0   # ...sus amigos...
const FAITH_RISEN_SEEN := 10.0     # ...y los que lo vieron (de cerca, todo esto)
const FEAR_RISEN_HERETIC := 40.0   # Al hereje que lo ve le da miedo...
const FEAR_RISEN_HEARD := 12.0     # ...y aunque no lo vea, se entera
const MOOD_RISEN := 20.0
const MOOD_RISEN_FAMILY := 35.0
const MOOD_RISEN_FRIEND := 15.0
var _rising := 0.0                 # Volviendo a la vida: lo que le falta
var _rise_from := Vector2.ZERO     # Dónde estaba tirado...
var _rise_rot := 0.0               # ...y cómo
var _old_age_death := false        # Se murió de viejo: ya no vuelve
var _bonds_at_death: Array = []    # Lo que tenía con los demás al morirse (ver Relations.snapshot)

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
const FIGHT_SHOVE := 170.0
var shove_vel := Vector2.ZERO
var shove_timer := 0.0

# --- Hambre y comida (ver VillagerHunger): le va subiendo el hambre y sale a buscar qué comer ---
var _hunger: VillagerHunger
## El hambre: 0 lleno .. 100 la panza vacía (ver VillagerHunger).
var hunger: float:
	get:
		return _hunger.hunger
	set(value):
		_hunger.hunger = value
## Lo que se va a comer (o se está comiendo); null si nada.
var food: Food:
	get:
		return _hunger.food
## Comiendo: lo que lleva masticando (0 si no come).
var eat_t: float:
	get:
		return _hunger.eat_t

# --- Casa (ver VillagerHome): vive en una choza, de noche va a dormir adentro y de día entra a descansar ---
var _home: VillagerHome
## Su choza (null: sin casa; ver VillagerHome).
var home: Decoration:
	get:
		return _home.home
	set(value):
		_home.home = value
## Va caminando a su choza.
var going_home: bool:
	get:
		return _home.going_home
	set(value):
		_home.going_home = value

# --- Edad (ver VillagerAge): nace chiquito, crece, le salen canas, envejece y se muere de viejo ---
var _age: VillagerAge
## Días vividos (ver VillagerAge; para cambiarla con el tamaño y las canas, set_age).
var age: float:
	get:
		return _age.age
	set(value):
		_age.age = value
## A los cuántos días se muere de viejo.
var lifespan: float:
	get:
		return _age.lifespan
	set(value):
		_age.lifespan = value
## A los cuántos días le empiezan a salir canas.
var grey_age: float:
	get:
		return _age.grey_age
	set(value):
		_age.grey_age = value
## Lo que le falta para poder tener otro bebé (ver VillagerAge.BABY_COOLDOWN).
var baby_cool: float:
	get:
		return _age.baby_cool
	set(value):
		_age.baby_cool = value

# --- Sueño (ver VillagerSleep): se cansa despierto, de noche se va a dormir y de día duerme la siesta ---
var _sleep: VillagerSleep
## Durmiendo afuera, acostado en el piso (adentro de su choza es inside; ver VillagerSleep).
var asleep: bool:
	get:
		return _sleep.asleep
## El cansancio: 0 descansado .. 100 muerto de sueño (ver VillagerSleep).
var tiredness: float:
	get:
		return _sleep.tiredness
	set(value):
		_sleep.tiredness = value
## Lo que bajó para quedar acostado durmiendo (parado, 0).
var sleep_drop: float:
	get:
		return _sleep.sleep_drop

# --- Charlas (ver VillagerChat): dos que andan cerca se juntan a charlar; así se hacen amigos, enemigos o pareja ---
var _chat: VillagerChat
## Con quién está charlando (o yendo a charlar); null si con nadie.
var chat_with: Villager:
	get:
		return _chat.chat_with

# --- Fe y miedo (ver VillagerFaith): cuánto creen en vos y cuánto te temen; te rezan y dejan ofrendas ---
var _faith: VillagerFaith
## Cuánto cree en vos: 0 .. 100 (ver VillagerFaith).
var faith: float:
	get:
		return _faith.faith
	set(value):
		_faith.faith = value
## Cuánto te teme: 0 .. 100 (ver VillagerFaith).
var fear: float:
	get:
		return _faith.fear
	set(value):
		_faith.fear = value
## Lo que está haciendo por vos: rezarte o agacharse de miedo (ver VillagerRig).
var pose: VillagerFaith.Pose:
	get:
		return _faith.pose

# --- Ánimo (ver VillagerMood): qué tan contento está, por cómo está su vida y por lo que le pasa ---
var _mood: VillagerMood
## Qué tan contento está: 0 deprimido .. 100 feliz (ver VillagerMood).
var mood: float:
	get:
		return _mood.mood
	set(value):
		_mood.mood = value

# --- Cómo es: cada uno tiene la piel un poco más clara u oscura (y más amarilla o rojiza), el
# pelo de otro color y es un poco más alto o más bajo (ver set_looks y waterline.gdshader). Los
# bebés salen parecidos a sus padres (ver inherit_looks). Se guarda con la partida.
const SKIN_SPREAD := 0.4          # Tono de piel: -1 más oscura .. 1 más clara (la mayoría, cerca del medio)
const WARM_SPREAD := 0.45         # Y más amarilla o más rojiza
## Lo que se le suma al negro del pelo: casi todos negro (como el dibujo), y si no castaño
## oscuro, castaño, castaño claro o colorado
const HAIR_COLORS: Array[Color] = [Color(0, 0, 0), Color(0, 0, 0), Color(0, 0, 0), Color(0.1, 0.06, 0.04),
		Color(0.18, 0.1, 0.05), Color(0.26, 0.14, 0.07), Color(0.32, 0.1, 0.05)]
const HEIGHT := Vector2(0.92, 1.08)   # Veces el tamaño del dibujo
var skin_tone := 0.0
var skin_warm := 0.0
var hair_color := Color.BLACK
var height := 1.0

# --- Carnet: nombre y apellido salen al azar (ver Names) y el jugador los puede cambiar en modo
# seleccionar (ver VillagerCard) ---
enum Gender { MALE, FEMALE }
static var ids_issued := 0       # Números de carnet repartidos (se guarda con la partida)
var id_number := 0
var first_name := ""
var last_name := ""
var parents: Array[int] = []      # Números de carnet de sus padres (si nació en la isla)
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
# Globitos: lo que dice o la cara que pone, arriba de la cabeza (ver say)
enum Bubble { NONE, DOTS, QUESTION, EXCLAIM, MUSIC, SUN, LAUGH, HEART, SMILE, ANGER, TEAR, HUNGRY, SLEEP }
const REACT_TIME := 1.6                 # La cara que ponen al terminar
const MOURN_TIME := 4.0
const BABBLE_DB := -16.0
var bubble := Bubble.NONE               # Lo que dice (ver SpeechBubble)
var bubble_t := 0.0
var _talking := 0.0                     # Hablando: mueve la boca

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
var _rig_rest := Vector2.ZERO   # Dónde va el rig (comiendo, mastica para arriba y para abajo)

func _init() -> void:
	_age = VillagerAge.new(self)
	_home = VillagerHome.new(self)
	_faith = VillagerFaith.new(self)
	_chat = VillagerChat.new(self)
	_hunger = VillagerHunger.new(self)
	_sleep = VillagerSleep.new(self)
	_mood = VillagerMood.new(self)
	_burn = VillagerBurn.new(self)
	_flu = VillagerFlu.new(self)
	_spore = VillagerSpore.new(self)

func _ready() -> void:
	randomize()
	speed *= randf_range(PACE.x, PACE.y)
	_pick_dir()
	wander_timer = randf_range(1.5, 4.0)
	input_pickable = true

	if rig:
		_rig_rest = rig.position
		_waterline = ShaderMaterial.new()
		_waterline.shader = WATERLINE_SHADER
		rig.material = _waterline
	# Cómo es (las partidas guardadas y los bebés traen el suyo, ver set_looks)
	set_looks(clampf(randfn(0.0, SKIN_SPREAD), -1.0, 1.0), clampf(randfn(0.0, WARM_SPREAD), -1.0, 1.0),
			HAIR_COLORS.pick_random(), randf_range(HEIGHT.x, HEIGHT.y))

	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	_voice = AudioStreamPlayer.new()
	_voice.stream = WOW
	_voice.volume_db = VOICE_DB
	add_child(_voice)
	gender = Gender.FEMALE if randf() < FEMALE_CHANCE else Gender.MALE   # También elige el tono
	first_name = Names.first_name(get_tree(), gender == Gender.FEMALE)   # Las partidas guardadas traen el suyo...
	last_name = Names.last_name(get_tree())   # ...y los bebés, el de los padres

	ids_issued += 1
	id_number = ids_issued
	_ensure_hud()
	if hud:
		hud.add_name_tag(self)

func _exit_tree() -> void:
	Relations.forget(self)   # También el que se cayó al vacío
	# Si se va a mitad de hacerse cenizas (se lo comió el tiburón), el montoncito igual se apaga
	_burn.finish_ashes()

func _ensure_hud() -> void:
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud") as HUD

## "Nombre Apellido" (vacío si todavía no le pusieron nombre).
func full_name() -> String:
	return ("%s %s" % [first_name, last_name]).strip_edges()

## Tocó el agua del mar (ver WaterArea; surface_y: la orilla de adelante). El mar es un piso:
## lo que cae desde arriba (de la isla o del aire) flota en la orilla, y lo que entra más
## adelante, donde está.
func enter_water(surface_y: float) -> void:
	touching_water = true
	if flooded:
		return   # Flota en la isla inundada: lo maneja la inundación, no el mar
	water_surface_y = maxf(surface_y, global_position.y)
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
	if _rising > 0.0:
		_rise(dt)   # Volviendo a la vida: lo mueve la luz
		return
	if asleep and (dragging or falling or in_water or tornado or dead or inside):
		wake_up(false)   # Lo agarraron, lo revolearon, se lo llevó el agua...: ya no está acostado
	if dragging:
		velocity = Vector2.ZERO
		return
	if inside:
		_home.inside_ai(dt)
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

		# Lanzado dentro del agua (sin entrar de nuevo al área): al bajar hasta donde salió, vuelve
		# a flotar (el mar es un piso: no se va a la orilla)
		if touching_water and v_fall > 0.0:
			var level := WaterArea.level_at(get_tree(), _launch_y)
			if global_position.y >= level:
				water_surface_y = level
				Sea.ripple_at(self, Vector2(global_position.x, level), 0.8)
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
	if asleep:
		_sleep.sleep_ai(dt)
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
	_hunger.cool_down(dt)
	if on_fire and food != null:
		food.release_eater()   # Prendido fuego no se queda comiendo
	if is_zombie():
		# El hongo lo domina: ni come, ni charla, ni duerme, ni va a su casa; persigue a los sanos
		if _spore.zombie_ai(dt):
			return
	else:
		_spore.avoid_zombies(dt)
		if food != null and _hunger.food_ai(dt):
			return
		if chat_with != null and _chat.chat_ai(dt):
			return
		if going_home and _home.walk_home(dt):
			return
		if _sleep.seek_sleep():
			return
		_hunger.seek_food(dt)
		_home.seek_home(dt)
		_chat.seek_chat(dt)
	# Asustado (ve venir un meteorito) se queda quieto mirándolo, y rezando o agachado de miedo
	# también; prendido fuego (o escapándose del agua o de tu mano) corre sin parar
	var hurry := on_fire or _flee > 0.0 or _scram > 0.0
	var stop := (_resting or is_scared() or pose != VillagerFaith.Pose.NONE) and not hurry
	_walk = move_toward(_walk, 0.0 if stop else 1.0, WALK_ACCEL * dt * (4.0 if hurry else 1.0))
	# Al doblar va más despacio (y si vuelve para atrás, frena y arranca de nuevo)
	_heading = _heading.lerp(dir, 1.0 - exp(-TURN_RATE * (2.0 if hurry else 1.0) * dt))
	var pace := speed
	if on_fire:
		pace *= VillagerBurn.PANIC_SPEED
	elif _flee > 0.0:
		pace *= FLOOD_FLEE_SPEED
	elif _scram > 0.0:
		pace *= SCRAM_SPEED
	elif is_zombie():
		pace *= _spore.zombie_pace()
	elif spore_shows():
		pace *= VillagerSpore.SPORE_SPEED
	elif flu == VillagerFlu.Stage.SICK:
		pace *= VillagerFlu.FLU_SPEED
	elif starving():
		pace *= VillagerHunger.STARVING_SPEED
	elif is_sad():
		pace *= VillagerMood.MOOD_SAD_SPEED
	elif tiredness >= VillagerSleep.SLEEPY_AT:
		pace *= VillagerSleep.SLEEPY_SPEED
	if is_elder():
		pace *= VillagerAge.ELDER_SPEED   # Hasta escapándose
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
			if wander_timer <= 0.0 or wander_timer > VillagerBurn.PANIC_TURN.y:
				_resting = false
				if dir == Vector2.ZERO:
					_pick_dir()
				else:
					dir = dir.rotated(randf_range(-VillagerBurn.PANIC_SWERVE, VillagerBurn.PANIC_SWERVE))
					_update_sprite_flip()
				wander_timer = randf_range(VillagerBurn.PANIC_TURN.x, VillagerBurn.PANIC_TURN.y)
		elif wander_timer <= 0.0:
			var rest := VillagerFlu.FLU_REST_CHANCE if flu == VillagerFlu.Stage.SICK else (VillagerMood.MOOD_SAD_REST if is_sad() else REST_CHANCE)
			if is_zombie():
				rest = VillagerSpore.ZOMBIE_REST   # Sigue arrastrando los pies (sin nadie a quien perseguir)
			elif spore_shows():
				rest = maxf(rest, VillagerSpore.SPORE_REST)
			if is_elder() and not is_zombie():
				rest = maxf(rest, VillagerAge.ELDER_REST)
			if not _resting and randf() < rest:
				_resting = true
				wander_timer = randf_range(REST_TIME.x, REST_TIME.y)
			else:
				_resting = false
				_pick_dir()
				wander_timer = randf_range(2.0, 5.0)

## Vivo: ni muerto, ni comido, ni a punto de desaparecer. El que se está ahogando todavía está vivo
## (mientras se hunde se lo puede rescatar), así que cuenta para la capacidad de la isla (ver
## World.alive_villagers).
func is_alive() -> bool:
	return not dead and not eaten and not is_queued_for_deletion()

## Parado o caminando en la isla (no agarrado, volando, en el agua, en un tornado, adentro de su
## choza ni muerto).
func is_idle() -> bool:
	return not (dragging or falling or in_water or eaten or dead or tornado or inside or asleep or altar)

## Qué tan de noche es (0 mediodía, 1 noche cerrada; ver Sky.night).
func _night() -> float:
	var sky := get_tree().get_first_node_in_group("sky")
	return sky.night if sky else 0.0

# --- COMIDA (lo que el resto del juego le pregunta al aldeano; ver VillagerHunger) ---
func starving() -> bool:
	return _hunger.starving()

func feed(amount: float) -> void:
	_hunger.feed(amount)

func go_eat(f: Food) -> void:
	_hunger.go_eat(f)

func stop_eating() -> void:
	_hunger.stop_eating()

## Le cayó un coco en la cabeza.
func bonk(at: Vector2) -> void:
	if rig:
		rig.hit(at, Vector2.DOWN, 0.6)
	Game.say("¡Bonk!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_TEXT)
	add_mood(VillagerMood.MOOD_BONKED, "Le cayó un coco en la cabeza")

# --- CHARLAS (lo que el resto del juego le pregunta al aldeano; ver VillagerChat) ---
func can_chat() -> bool:
	return _chat.can_chat()

func wants_chat() -> bool:
	return _chat.wants_chat()

func end_chat() -> void:
	_chat.end_chat()

func join_chat(o: Villager) -> void:
	_chat.join_chat(o)

func leave_chat() -> void:
	_chat.leave_chat()

func clear_chat_cool() -> void:
	_chat.clear_chat_cool()

# --- GLOBITOS ---
## Dice algo (o pone una cara, si no talk): un globito arriba de la cabeza durante time
## segundos. Hablando mueve la boca con un bla-bla en su tono de voz.
func say(b: Bubble, time: float, talk := true) -> void:
	bubble = b
	bubble_t = time
	if not talk:
		return
	var p := AudioStreamPlayer.new()
	p.stream = VillagerSounds.babble()
	p.volume_db = BABBLE_DB
	p.pitch_scale = _voice_pitch * randf_range(0.95, 1.05)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	_talking = p.stream.get_length() / p.pitch_scale

## Hablando abre y cierra la boca (0..1, ver VillagerRig).
func talk_mouth() -> float:
	return absf(sin(_talking * 18.0)) * 0.55 if _talking > 0.0 else 0.0

# --- ÁNIMO (lo que el resto del juego le pregunta al aldeano; ver VillagerMood) ---
func mood_level() -> VillagerMood.Mood:
	return _mood.mood_level()

func is_sad() -> bool:
	return _mood.is_sad()

func mood_reason() -> String:
	return _mood.mood_reason()

func add_mood(amount: float, why := "") -> void:
	_mood.add_mood(amount, why)

func relation_mood(ev: Relations.Event) -> void:
	_mood.relation_mood(ev)

# --- SUEÑO (lo que el resto del juego le pregunta al aldeano; ver VillagerSleep) ---
func is_sleeping() -> bool:
	return _sleep.is_sleeping()

func wake_up(stand := true) -> void:
	_sleep.wake_up(stand)

# --- EDAD (lo que el resto del juego le pregunta al aldeano; ver VillagerAge) ---
func is_child() -> bool:
	return _age.is_child()

func is_elder() -> bool:
	return _age.is_elder()

func days() -> int:
	return _age.days()

func oldness() -> float:
	return _age.oldness()

func greyness() -> float:
	return _age.greyness()

func can_have_baby() -> bool:
	return _age.can_have_baby()

func set_age(a: float) -> void:
	_age.set_age(a)

# --- CÓMO ES ---
## La piel (tono, y más amarilla o rojiza), el color del pelo y la altura.
func set_looks(tone: float, warm: float, hair: Color, h: float) -> void:
	skin_tone = tone
	skin_warm = warm
	hair_color = hair
	height = h
	if _waterline:
		_paint_looks(_waterline)
	set_age(age)

## Le pone a mat (el material del rig, o el de la foto del carnet) la piel y el pelo de este.
func _paint_looks(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("skin_tone", skin_tone)
	mat.set_shader_parameter("skin_warm", skin_warm)
	mat.set_shader_parameter("hair_color", Vector3(hair_color.r, hair_color.g, hair_color.b))
	mat.set_shader_parameter("grey", greyness())

## Para la foto del carnet: un material con su piel y su pelo (con las canas que tiene).
func looks_material() -> ShaderMaterial:
	return material_for(skin_tone, skin_warm, hair_color, greyness())

## Un material con esa piel, ese pelo y esas canas (para las fotos: el carnet, el árbol genealógico).
static func material_for(tone: float, warm: float, hair: Color, grey := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WATERLINE_SHADER
	m.set_shader_parameter("skin_tone", tone)
	m.set_shader_parameter("skin_warm", warm)
	m.set_shader_parameter("hair_color", Vector3(hair.r, hair.g, hair.b))
	m.set_shader_parameter("grey", grey)
	return m

## Recién nacido: sale parecido a sus padres (la piel y la altura, entre las de los dos; el
## pelo, el de alguno, y las canas le salen más o menos a la edad que a alguno).
func inherit_looks(a: Villager, b: Villager) -> void:
	set_looks(clampf((a.skin_tone + b.skin_tone) * 0.5 + randfn(0.0, 0.12), -1.0, 1.0),
			clampf((a.skin_warm + b.skin_warm) * 0.5 + randfn(0.0, 0.12), -1.0, 1.0),
			(a if randf() < 0.5 else b).hair_color,
			clampf((a.height + b.height) * 0.5 + randf_range(-0.02, 0.02), HEIGHT.x, HEIGHT.y))
	grey_age = clampf((a if randf() < 0.5 else b).grey_age + randf_range(-0.5, 0.5), VillagerAge.GREY_AGE.x, VillagerAge.GREY_AGE.y)

# --- CASA (lo que el resto del juego le pregunta al aldeano; ver VillagerHome) ---
func has_home() -> bool:
	return _home.has_home()

func can_go_home() -> bool:
	return _home.can_go_home()

func go_home() -> void:
	_home.go_home()

func enter_home() -> void:
	_home.enter_home()

func lose_home() -> void:
	_home.lose_home()

func leave_home() -> void:
	_home.leave_home()

# --- FE Y MIEDO (lo que el resto del juego le pregunta al aldeano; ver VillagerFaith) ---
func creed() -> VillagerFaith.Creed:
	return _faith.creed()

func add_faith(amount: float) -> void:
	_faith.add_faith(amount)

func add_fear(amount: float) -> void:
	_faith.add_fear(amount)

func tribute() -> float:
	return _faith.tribute()

func prays() -> bool:
	return _faith.prays()

func prayer_block() -> String:
	return _faith.prayer_block()

func witness(at: Vector2) -> float:
	return _faith.witness(at)

# --- CUERPO Y EMPUJONES ---
## Empuje suave para no quedar encimado con otros aldeanos en tierra.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.dragging or o.falling or o.in_water or o.eaten or o.tornado or o.inside:
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

## Distancia de p a la superficie del cuerpo (la cápsula): <= 0 si cae adentro.
func body_distance(p: Vector2) -> float:
	var seg := _body_segment()
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])) - BODY_HALF_W

## El centro del cuerpo (más o menos el de masa), en coordenadas globales.
func body_center() -> Vector2:
	return to_global(BODY_COM)

## Punto del piso debajo de él (para la inundación y el tornado): sus pies, o la superficie
## del mar si está flotando ahí.
func ground_point() -> Vector2:
	if in_water and not flooded:
		return global_position + Vector2(0, WATERLINE_DEPTH)
	if dead and corpse_grounded and not in_water:
		return global_position + Vector2(0, (FEET - 2.0 - FEET_DROP) * scale.y)   # Acostado
	if asleep:
		return global_position + Vector2(0, (FEET - 2.0) * scale.y - sleep_drop)   # Acostándose a dormir
	return global_position + Vector2(0, (FEET - 2.0) * scale.y)   # (Los chicos son más bajos)

## Llamado mientras está agarrado: aparta a los aldeanos que toca.
func _shove_others() -> void:
	var mine := _body_segment()
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.dragging or o.falling or o.in_water or o.eaten or o.tornado or o.inside:
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

## Un enemigo lo empujó (y capaz que lo tira de la isla).
func get_pushed_by(o: Villager) -> void:
	var push := Vector2(1.0 if global_position.x >= o.global_position.x else -1.0, 0.0)
	get_shoved(Vector2.ZERO, push * FIGHT_SHOVE)
	if rig:
		rig.hit(body_center(), push, 0.8)
	_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
	_voice.play()

func _fall_from_shove() -> void:
	var push := shove_vel
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	_start_fall()
	if falling:
		fall_vx = push.x
		v_fall = minf(push.y, 0.0)
		swing_vel = clampf(push.x * 0.02, -8.0, 8.0)  # Que trastabille al caer

# --- ALTAR ---
## Lo soltaste encima del altar (ver Altar): queda acostado en la piedra, pataleando y con la
## boca abierta, hasta el final del ritual (lo mueve el altar).
func lay_on_altar(a: Altar) -> void:
	altar = a
	wake_up(false)
	going_home = false
	if food:
		food.release_eater()
	if chat_with:
		end_chat()
	set_physics_process(false)
	velocity = Vector2.ZERO
	rotation = (1.0 if randf() < 0.5 else -1.0) * PI * 0.5
	z_index = 1   # Arriba de la piedra (por el orden por Y quedaría detrás del altar)
	_scared = Altar.RITUAL_TIME + 1.0   # La boca abierta (ver VillagerRig)
	add_fear(VillagerFaith.FEAR_THROW)

## Ya no hay altar (lo quitaron): se cae de la piedra.
func leave_altar() -> void:
	altar = null
	z_index = 0
	set_physics_process(true)
	_start_fall()

## El final del ritual (ver Altar): cuenta como sacrificio, con lo que da el altar, y se
## deshace en brasas.
func sacrifice(offering: int, sacrifices: int) -> void:
	altar = null
	eaten = true   # Ya no está (como si se lo hubiera comido el tiburón)
	_grant_sacrifice_xp(offering, sacrifices)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 0.3, 0.15, 0.0), 0.35)
	tw.tween_callback(queue_free)

## Ve que en el altar (en at) van a sacrificar a alguien (ver Altar): deja lo que está haciendo
## y mira. El devoto (o el fanático) se arrodilla a rezar, el aterrado sale corriendo y el hereje
## se queda mirando con la boca abierta.
func witness_ritual(time: float, at: Vector2) -> void:
	if not is_idle() or on_fire or is_zombie():
		return
	if chat_with:
		end_chat()
	if food:
		food.release_eater()
	match creed():
		VillagerFaith.Creed.DEVOUT, VillagerFaith.Creed.ZEALOT:
			_faith.worship(time, at)
		VillagerFaith.Creed.TERRIFIED:
			_scram = time * 0.5
			dir = (global_position - at).normalized()
			_update_sprite_flip()
			_resting = false
		_:
			scare(time, at)

# --- DISPARO / MUERTE ---
## Llamado por la pistola. hit_point y shot_dir en coordenadas globales.
func shoot(hit_point: Vector2, shot_dir: Vector2) -> void:
	if eaten or _rising > 0.0:
		return   # (Volviendo a la vida no lo toca nada)
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
	floor_y = global_position.y + FEET_DROP - sleep_drop   # Durmiendo ya estaba acostado
	velocity = Vector2.ZERO
	_drop_shield()   # Morirse se lleva el escudo y la vacuna
	vaccine_t = 0.0
	_grant_sacrifice_xp()
	if rig:
		rig.set_dead()

## Cuenta como sacrificio: XP, sacrificios y ofrendas (el altar da más, ver Altar).
func _grant_sacrifice_xp(offering := SACRIFICE_OFFERING, sacrifices := 1) -> void:
	if xp_granted:
		return
	xp_granted = true
	Genealogy.remember(self)   # Queda en el árbol genealógico (antes del duelo: todavía tiene pareja)
	_mourn()   # Toda muerte pasa por acá
	Game.add_xp(1)
	Game.add_sacrifices(sacrifices)
	Game.add_offerings(offering)
	Game.say(tr("+%d ofrendas") % offering, get_global_transform_with_canvas().origin + Vector2(0, -60), HUD.C_OFFERING)

## Se murió: los que lo vieron se asustan (más si lo querían) y se quedan mirando; su pareja, sus
## amigos y su familia lloran un rato, pierden fe y se ponen tristes, y sus enemigos se alegran.
## Y deja de contar para los demás.
func _mourn() -> void:
	var at := body_center()
	var scary := VillagerFaith.FEAR_DEATH * (VillagerFaith.FEAR_DEATH_GENTLE if _gentle_death else 1.0)
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or not o.is_alive() or o.is_zombie():
			continue   # (El zombi ya no siente nada)
		var k := Relations.kind(self, o)
		var seen := o.witness(at)
		if seen > 0.0:
			var loved := k == Relations.Kind.COUPLE or k == Relations.Kind.FRIEND
			o.add_fear((scary + (VillagerFaith.FEAR_LOVED if loved else 0.0)) * seen)
			o.scare(VillagerFaith.WITNESS_STARE, at)
		match k:
			Relations.Kind.COUPLE:
				o.say(Bubble.TEAR, MOURN_TIME, false)
				o.add_faith(-VillagerFaith.FAITH_LOST_PARTNER)
				o.add_mood(VillagerMood.MOOD_LOST_PARTNER, "Se le murió la pareja")
				Game.say("Perdió a su pareja", o.get_global_transform_with_canvas().origin + Vector2(0, -100), HUD.C_MUTED)
			Relations.Kind.FRIEND:
				o.say(Bubble.TEAR, MOURN_TIME * 0.6, false)
				o.add_faith(-VillagerFaith.FAITH_LOST_FRIEND)
				o.add_mood(VillagerMood.MOOD_LOST_FRIEND, "Se le murió un amigo")
			Relations.Kind.ENEMY:
				o.add_mood(VillagerMood.MOOD_ENEMY_DIED, "Se murió un enemigo")
				if o.bubble_t <= 0.0:
					o.say(Bubble.LAUGH, REACT_TIME, false)
			_:
				if seen > 0.0:
					o.add_mood(VillagerMood.MOOD_SAW_DEATH * seen, "Vio morir a alguien")
		# Su familia
		var female := gender == Gender.FEMALE
		if o.id_number in parents:
			o.say(Bubble.TEAR, MOURN_TIME, false)
			o.add_mood(VillagerMood.MOOD_LOST_CHILD, "Se le murió una hija" if female else "Se le murió un hijo")
		elif id_number in o.parents:
			o.say(Bubble.TEAR, MOURN_TIME * 0.8, false)
			o.add_mood(VillagerMood.MOOD_LOST_PARENT, "Se le murió la mamá" if female else "Se le murió el papá")
	_bonds_at_death = Relations.snapshot(self)   # Por si vuelve a la vida (ver resurrect)
	Relations.forget(self)

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
				if zap_state == VillagerBurn.Zap.NONE:   # Carbonizado ya no sangra
					_spawn_blood_pool()
		return

	# Tirado donde llega el agua de la inundación: se lo lleva flotando
	if zap_state == VillagerBurn.Zap.NONE and Storm.flooded_at(ground_point()):
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

# --- FUEGO Y RAYO (lo que el resto del juego le pregunta al aldeano; ver VillagerBurn) ---
func can_zap() -> bool:
	return _burn.can_zap()

func zap() -> void:
	_burn.zap()

func zap_pinned() -> bool:
	return _burn.zap_pinned()

func ashes() -> float:
	return _burn.ashes()

# --- METEORITO ---
## Si lo puede alcanzar una explosión (vivo o cadáver; no si se está friendo por un rayo ni si
## está volviendo a la vida).
func can_blast() -> bool:
	return not eaten and not inside and altar == null and zap_state == VillagerBurn.Zap.NONE and _rising <= 0.0 \
			and not is_queued_for_deletion()

## Ve venir un meteorito desde from: lo mira, con la boca abierta, durante time segundos.
func scare(time: float, from: Vector2) -> void:
	if is_zombie():
		return   # Al zombi no lo asusta nada
	wake_up()   # Se despierta del susto
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

# --- TORNADO ---
## Si un tornado lo puede chupar (vivo o cadáver; no si se está friendo por un rayo, ni
## recién revoleado).
func can_be_lifted() -> bool:
	return can_blast() and not dragging and _tornado_cool <= 0.0 and modulate.a > 0.3

## Lo chupó un tornado: deja lo que estaba haciendo y desde ahora lo mueve él (ver Tornado).
func enter_tornado(t: Tornado) -> void:
	wake_up(false)
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
		if randf() < VillagerFlu.SOAKED_CATCH:
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

# --- GRIPE (lo que el resto del juego le pregunta al aldeano; ver VillagerFlu) ---
func is_sick() -> bool:
	return _flu.is_sick()

func has_flu() -> bool:
	return _flu.has_flu()

func flu_look() -> float:
	return _flu.flu_look()

func catch_flu() -> void:
	_flu.catch_flu()

func set_flu(state: VillagerFlu.Stage, time_left: float) -> void:
	_flu.set_flu(state, time_left)

func infect() -> void:
	_flu.infect()

# --- CURAR ---
## El poder de curar (ver Cure): se le va la gripe (queda inmune), la espora (si todavía no es
## un zombi: ahí ya no tiene cura) y, si se estaba quemando, se apaga y se le va el tizne. true
## si tenía algo que curar.
func cure() -> bool:
	if not is_alive() or inside or zap_state != VillagerBurn.Zap.NONE:
		return false
	var zombie := is_zombie()   # Al zombi ya no lo salva nada (si se quema, se apaga igual)
	var said := false   # Ya dijo "¡Se curó!"
	var flu_cured := not zombie and has_flu()
	if flu_cured:
		_flu.recover()   # Ya dice "¡Se curó!"
		said = true
	var spore_cured := spore > 0.0 and not zombie
	if spore_cured:
		_spore.clear()
		if not said:
			Game.say("¡Se curó!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SHOP)
			said = true
	elif zombie:
		Game.say("Ya no tiene cura", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_MUTED)
	var burns := _burn.has_burns()
	if burns:
		_burn.heal()
		if not said and not zombie:
			Game.say("¡Se curó!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SHOP)
	var cured := flu_cured or spore_cured or burns
	if cured and not zombie:
		_faith.thank(VillagerFaith.FAITH_CURED, true)
	return cured

# --- ESPORA (lo que el resto del juego le pregunta al aldeano; ver VillagerSpore) ---
func infection() -> VillagerSpore.Infection:
	return _spore.infection()

func spore_shows() -> bool:
	return _spore.spore_shows()

func is_zombie() -> bool:
	return _spore.is_zombie()

func spore_look() -> float:
	return _spore.spore_look()

func zombie_look() -> float:
	return _spore.zombie_look()

func bloom_amount() -> float:
	return _spore.bloom_amount()

func bloom_burst() -> bool:
	return _spore.bloom_burst()

func zombie_mouth() -> float:
	return _spore.zombie_mouth()

func catch_spore(dose := 0.0) -> void:
	_spore.catch_spore(dose)

func set_spore(value: float) -> void:
	_spore.set_spore(value)

func get_bitten(z: Villager) -> void:
	_spore.get_bitten(z)

## Un sonido suelto (se borra solo al terminar).
func _play_sfx(stream: AudioStream, db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## Un degradé de from a to, para las partículas que se desvanecen (lo usan los componentes).
static func _fade_ramp(from: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([from, to])
	return g

# --- ESCUDO Y VACUNA ---
## Tiene el escudo (ver Miracle).
func shielded() -> bool:
	return shield_t > 0.0 and not dead

## Está vacunado (ver Miracle).
func vaccinated() -> bool:
	return vaccine_t > 0.0 and not dead

## No se contagia de nada: tiene el escudo o está vacunado.
func protected_from_disease() -> bool:
	return shielded() or vaccinated()

## Lo bendijiste con el escudo (ver Miracle): un aura que lo protege un rato (time, en segundos; las
## partidas guardadas traen lo que le quedaba). thank: te lo agradece (es un milagro).
func give_shield(time := SHIELD_TIME, thank := true) -> void:
	shield_t = maxf(shield_t, time)
	if _aura == null:
		_aura = Miracle.Aura.new()
		_aura.villager = self
		add_child(_aura)   # Después del Rig: va por delante del cuerpo
	if thank:
		Game.say("¡Bendecida!" if gender == Gender.FEMALE else "¡Bendecido!",
				get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_HOLY)
		_faith.thank(FAITH_SHIELDED, false)

## Lo vacunaste (ver Miracle): no se contagia de gripe ni de espora por un tiempo (time, en
## segundos). thank: te lo agradece.
func vaccinate(time := VACCINE_TIME, thank := true) -> void:
	vaccine_t = maxf(vaccine_t, time)
	if thank:
		Game.say("¡Vacunada!" if gender == Gender.FEMALE else "¡Vacunado!",
				get_global_transform_with_canvas().origin + Vector2(0, -80), Miracle.C_TEAL)
		_faith.thank(FAITH_VACCINATED, false)

## El escudo paró algo (un contagio, un rayo o una mordida): brilla. loud: además suena y lo dice
## (el rayo y la mordida). Vacunado no se nota nada.
func _ward_off(loud := false) -> void:
	if not shielded():
		return
	if is_instance_valid(_aura):
		_aura.flash = 1.0
	if loud:
		_play_sfx(Miracle.sound_for("block"), VOICE_DB - 4.0, randf_range(0.95, 1.08))
		Game.say("¡Protegida!" if gender == Gender.FEMALE else "¡Protegido!",
				get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_HOLY)

## El escudo y la vacuna se van gastando.
func _update_wards(dt: float) -> void:
	if not is_alive():
		return
	vaccine_t = maxf(0.0, vaccine_t - dt)
	if shield_t > 0.0:
		shield_t -= dt
		if shield_t <= 0.0:
			_drop_shield()

## Se le terminó el escudo (o se murió): el aura se va.
func _drop_shield() -> void:
	shield_t = 0.0
	if is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null

# --- RESURRECCIÓN ---
## Es un cadáver (entero o no) sobre el que se podría hacer el milagro (ver revive_problem).
func revivable() -> bool:
	return dead and not eaten and _rising <= 0.0 and not is_queued_for_deletion()

## Está volviendo a la vida (flotando en la luz).
func is_rising() -> bool:
	return _rising > 0.0

## Por qué no puede volver a la vida ("" si puede; ver Miracle).
func revive_problem() -> String:
	if zap_state != VillagerBurn.Zap.NONE:
		return "No quedó nada para resucitar"
	if _old_age_death:
		return "Ya le había llegado la hora"
	if in_water:
		return "Primero sacala del agua" if gender == Gender.FEMALE else "Primero sacalo del agua"
	if falling or tornado or dragging:
		return "Solo sobre la isla"
	return ""

## El milagro (ver Miracle): sube flotando en la luz, se endereza y vuelve a la vida (ver _rise y
## _come_back). Mientras tanto no lo alcanza nada. Los que lo ven dejan lo que están haciendo y
## miran: los devotos se arrodillan, los aterrados salen corriendo y los herejes se quedan mirando
## con la boca abierta (ver witness_ritual).
func resurrect() -> void:
	_rising = RISE_TIME
	_rise_from = global_position
	_rise_rot = rotation
	corpse_grounded = false   # Que los brazos y las piernas cuelguen mientras sube (ver VillagerRig)
	corpse_vel = Vector2.ZERO
	corpse_timer = 0.0
	swing_vel = 0.0
	modulate.a = 1.0
	if on_fire:
		_burn.put_out()
	var at := Vector2(global_position.x, floor_y)
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != self and o.is_alive() and o.witness(at) > 0.0:
			o.witness_ritual(RISE_TIME + 0.5, at)

## Volviendo a la vida: sube flotando mientras se endereza, y baja hasta quedar parado.
func _rise(dt: float) -> void:
	velocity = Vector2.ZERO
	_rising = maxf(0.0, _rising - dt)
	var k := 1.0 - _rising / RISE_TIME
	var stand_y := floor_y - FEET_DROP
	var land := smoothstep(0.75, 1.0, k)
	var y := lerpf(_rise_from.y, stand_y - RISE_FLOAT, smoothstep(0.0, 0.55, k))
	y = lerpf(y, stand_y, land)
	global_position = Vector2(_rise_from.x, y + sin(k * TAU * 2.0) * 1.5 * (1.0 - land))
	rotation = lerp_angle(_rise_rot, 0.0, smoothstep(0.1, 0.6, k))
	if _rising <= 0.0:
		_come_back()

## Volvió a la vida: parado donde estaba tirado, sano, sin heridas y con lo que tenía con los demás.
func _come_back() -> void:
	dead = false
	xp_granted = false   # Si se vuelve a morir, cuenta otra vez
	_gentle_death = false
	corpse_grounded = false
	corpse_timer = 0.0
	corpse_vel = Vector2.ZERO
	rotation = 0.0
	swing_vel = 0.0
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	global_position.y = floor_y - FEET_DROP
	# Sano: sin gripe, sin espora, con la panza casi llena y sin quemaduras
	_flu.heal()
	_spore.clear()
	_spore.spore_fx = 0.0
	_hunger.heal()
	_burn.heal()
	if _waterline:
		for param: String in ["burnt", "embers", "sick", "spore"]:
			_waterline.set_shader_parameter(param, 0.0)
	if rig:
		rig.set_alive()
	if food:
		food.release_eater()
	if chat_with:
		end_chat()
	going_home = false
	_walk = 0.0
	_heading = Vector2.ZERO
	_resting = true
	wander_timer = 1.5
	_scared = 1.2   # Se queda un ratito con la boca abierta: ¡está vivo!
	# Vuelve a contar para los demás
	Genealogy.revive(id_number)
	var alive := {}   # carnet -> aldeano
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != self and o.is_alive():
			alive[o.id_number] = o
	var bonds := _bonds_at_death
	_bonds_at_death = []
	Relations.restore(self, bonds, alive)
	_celebrate(bonds, alive)

## Volvió: él te cree muchísimo más y se alegra; su familia y sus amigos también (y lo festejan),
## los que lo vieron te creen más y a los herejes les da miedo (más si lo vieron). bonds: lo que
## tenía con los demás al morirse; alive: los vivos, por carnet.
func _celebrate(bonds: Array, alive: Dictionary) -> void:
	Game.say("¡Volvió a la vida!", get_global_transform_with_canvas().origin + Vector2(0, -90), HUD.C_HOLY)
	add_faith(FAITH_RISEN)
	add_mood(MOOD_RISEN, "Volvió de la muerte")
	say(Bubble.HEART, VillagerFaith.THANKS_TIME, false)
	var partner := 0
	var friends := {}
	for r: Array in bonds:
		match int(r[2]):
			Relations.Kind.COUPLE:
				partner = r[0]
			Relations.Kind.FRIEND:
				friends[r[0]] = true
	var at := body_center()
	for id: int in alive:
		var o: Villager = alive[id]
		if o.is_zombie():
			continue   # (El zombi ya no siente nada)
		var heretic := o.creed() == VillagerFaith.Creed.HERETIC
		var seen := o.witness(at)
		var family := id == partner or id in parents or id_number in o.parents \
				or parents.any(func(p: int) -> bool: return p in o.parents)
		if family:
			o.add_faith(FAITH_RISEN_FAMILY)
			o.add_mood(MOOD_RISEN_FAMILY, "Resucitaste a alguien de su familia")
			o.say(Bubble.HEART, VillagerFaith.THANKS_TIME * 1.5, false)
		elif friends.has(id):
			o.add_faith(FAITH_RISEN_FRIEND)
			o.add_mood(MOOD_RISEN_FRIEND, "Resucitaste a un amigo")
			o.say(Bubble.HEART, VillagerFaith.THANKS_TIME, false)
		elif seen > 0.0 and not heretic:
			o.add_faith(FAITH_RISEN_SEEN * seen)
		if heretic:
			o.add_fear(FEAR_RISEN_HERETIC * seen if seen > 0.0 else FEAR_RISEN_HEARD)
			if seen > 0.0:
				o.scare(VillagerFaith.WITNESS_STARE, at)

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

## Parado mirando al otro (solo se mueve si lo empujan).
func _stand_facing(o: Villager) -> void:
	if rig:
		rig.set_facing_left(o.global_position.x < global_position.x)
	_hold_still()

## Quieto donde está: solo se mueve si lo empujan (y si lo empujan fuera de la isla, se cae).
func _hold_still() -> void:
	_walk = 0.0   # Al terminar arranca a caminar de a poco
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

func _wander_off() -> void:
	_resting = false
	_pick_dir()
	wander_timer = randf_range(1.5, 3.0)

# --- MECÁNICA DE ARRASTRE (DRAG & DROP) ---
func _process(dt: float) -> void:
	if dragging:
		_update_drag(dt)
	_burn.update(dt)
	_flu.update(dt)
	_spore.update(dt)
	_hunger.update(dt)
	_age.update(dt)
	_home.update(dt)
	_scram = maxf(0.0, _scram - dt)
	_faith.update(dt)
	_mood.update(dt)
	_sleep.update(dt)
	_update_wards(dt)
	_update_waterline()
	_scared = maxf(0.0, _scared - dt)
	_tornado_cool = maxf(0.0, _tornado_cool - dt)
	_chat.update(dt)
	_talking = maxf(0.0, _talking - dt)
	_spore.groaning = maxf(0.0, _spore.groaning - dt)
	bubble_t = maxf(0.0, bubble_t - dt)

## Flotando (o hundiéndose) lo que queda debajo de la superficie no se ve.
func _update_waterline() -> void:
	if _waterline == null:
		return
	var cut := in_water and not dragging
	for m: ShaderMaterial in [_waterline, _burn.xray_mat]:
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
		if event.pressed and not dragging and not eaten and _rising <= 0.0 and not Power.aiming():
			# En modo seleccionar no se lo agarra: se abre su carnet. Editando la isla, nada
			_ensure_hud()
			if hud and hud.edit_mode:
				return
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
	if altar:
		altar.release()   # Lo sacaste del altar a tiempo
		altar = null
	if asleep:
		wake_up(false)
		add_mood(VillagerSleep.MOOD_WOKEN, "La despertaste" if gender == Gender.FEMALE else "Lo despertaste")
	dragging = true
	grab_local = (get_global_mouse_position() - global_position).rotated(-rotation)
	_prev_mouse = get_global_mouse_position()
	_mouse_vel = Vector2.ZERO
	_mouse_acc = Vector2.ZERO
	_throw_vel = Vector2.ZERO
	swing_vel = 0.0
	fall_vx = 0.0
	_burn.unpin()   # Carbonizado también se lo puede levantar: se deshace al volver a quedar tirado
	set_physics_process(false)
	z_index = 10
	if is_zombie():
		_spore.groan()   # No grita: gime
	elif not dead:
		_voice.pitch_scale = _voice_pitch * randf_range(0.96, 1.04)
		_voice.play()
		add_fear(VillagerFaith.FEAR_GRAB)
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
	for node in get_tree().get_nodes_in_group("altar"):
		var a := (node as Decoration).ritual
		if a and a.takes(self, get_global_mouse_position()):
			return   # Lo soltaste encima de un altar
	set_physics_process(true)
	z_index = 0

	var throw := _throw_vel.limit_length(THROW_MAX_SPEED)
	var on_island := island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly)
	if throw.length() >= THROW_MIN_SPEED:
		if not dead:
			add_fear(VillagerFaith.FEAR_THROW)
			add_mood(VillagerMood.MOOD_THROWN, "La revoleaste" if gender == Gender.FEMALE else "Lo revoleaste")
		_launch(throw, on_island)
	elif on_island:
		# Rescatado o depositado en tierra firme
		_land_on_island()
	else:
		if in_water:
			# Soltado dentro del agua: sigue flotando donde lo soltaste (no vuelve a la orilla)
			falling = false
			velocity = Vector2.ZERO
			water_surface_y = WaterArea.level_at(get_tree(), global_position.y)
		else:
			# Soltado en el aire fuera de la isla: empieza caída libre
			_start_fall()

func _start_fall() -> void:
	if touching_water:
		water_surface_y = WaterArea.level_at(get_tree(), global_position.y)   # Ahí mismo (o en la orilla)
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
		if not is_zombie():
			_faith.thank(VillagerFaith.FAITH_RESCUED, false)   # Lo rescataste
