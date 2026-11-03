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
const IMMUNE_TIME := 600.0       # Más que lo que dura un brote: así se termina y no se la vuelven a pasar
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

# --- Espora zombi: un hongo como el cordyceps. Se agarra por la espora (el poder, ver Spore), por
# la mordida de un zombi, por la tos de uno al que ya le salen hongos o por la nube que suelta un
# zombi al brotar. Mientras más tiempo lo tiene, más se adueña de él (spore, de 0 a 1):
# - Incubando: no se le nota nada, salvo algún tic (solo lo dice el carnet).
# - Con hongos: le salen manchas de micelio que se extienden desde la cabeza hasta los pies, le
#   crecen hongos en el pelo, tiembla, camina lento, no reza, anda triste y tose esporas (que
#   contagian a los que tiene enfrente).
# - Zombi: el hongo lo domina. Los ojos lechosos, la piel gris, tallos de cordyceps en la cabeza
#   y los brazos estirados; ya no come, no duerme, no charla ni te reza: arrastra los pies y
#   persigue a los sanos para morderlos (y contagiarlos). Los que lo ven cerca salen corriendo.
# - Al final se queda duro, de rodillas, le brota de la cabeza un tallo enorme y revienta en una
#   nube de esporas que contagia a los que están cerca (y queda flotando un rato), y se muere.
# Curar lo salva solo antes de que se haga zombi. Se ve en el carnet y se guarda con la partida.
enum Infection { NONE, INCUBATING, SPREADING, ZOMBIE }
const SPORE_TIME := Vector2(130.0, 170.0)   # Segundos desde que se contagia hasta que brota
const SPORE_START := 0.02          # Recién contagiado
const SPORE_DOSE := 0.12           # Otra dosis (el poder) al que ya la tenía: lo apura
const SPORE_SPREAD_AT := 0.22      # Desde acá se le nota...
const SPORE_ZOMBIE_AT := 0.6       # ...desde acá es un zombi...
const SPORE_BLOOM_TIME := 4.5      # ...y al llegar a 1 brota: lo que tarda en crecerle el tallo
const SPORE_LOOK := 0.5            # Por segundo: lo que tardan en aparecer (o irse) las manchas
const SPORE_SPEED := 0.75          # Veces speed, con hongos...
const SPORE_REST := 0.6            # ...y se para más seguido
const SPORE_COUGH_EVERY := Vector2(7.0, 13.0)
const SPORE_COUGH_REACH := 40.0
const SPORE_COUGH_CATCH := 0.3
const ZOMBIE_SPEED := 0.55         # Arrastrando los pies (veces speed)...
const ZOMBIE_CHASE := 1.0          # ...persiguiendo a alguien...
const ZOMBIE_LUNGE := 2.0          # ...y ya encima, se le tira
const ZOMBIE_LUNGE_AT := 55.0
const ZOMBIE_SEEK := 240.0         # Hasta dónde busca a quién morder
const ZOMBIE_SEEK_EVERY := 0.5
const ZOMBIE_REST := 0.15
const BITE_REACH := 20.0
const BITE_COOLDOWN := 3.5
const BITE_TIME := 0.7             # Quieto, mordiendo
const BITE_SHOVE := 150.0
const GROAN_EVERY := Vector2(4.0, 9.0)
const GROAN_TIME := 1.1
const ZOMBIE_DREAD := 85.0         # Un zombi así de cerca: los demás salen corriendo...
const FEAR_ZOMBIE := 6.0           # ...y se asustan (por segundo)
const DREAD_CHECK := 0.25
const DREAD_FREEZE := 0.9          # Al verlo, a veces se queda duro del susto un ratito...
const DREAD_FREEZE_CHANCE := 0.35  # ...(una vez cada vez que se le acerca uno)
const BURST_RADIUS := 95.0         # La nube del brote alcanza a los que están a esto
const MOOD_SPORE := -20.0          # Le crecen hongos
const MOOD_BITTEN := -12.0
const FAITH_BITTEN := 6.0          # ¿Y su dios dónde estaba?
var spore := 0.0                   # 0 sano .. 1 brota (ver Infection)
var _spore_rate := 1.0 / 150.0     # Por segundo (cada uno a su ritmo)
var _spore_fx := 0.0               # Lo que se le ve (sigue a spore de a poco, ver SPORE_LOOK)
var _spore_seen := Infection.NONE  # La etapa en la que estaba (para avisar cuando cambia)
var _spore_burst := false          # Ya reventó el tallo
var _bloom := 0.0                  # Brotando: 0..1 lo que creció el tallo
var _cough_t := 0.0
var _groan_t := 0.0
var _groaning := 0.0               # Gimiendo: abre la boca
var _bite_cool := 0.0
var _bite_t := 0.0
var _prey: Villager                # A quién persigue (zombi)
var _prey_seek := 0.0
var _dread_check := 0.0
var _dread_seen := false           # Ya vio al zombi que tiene cerca (para no paralizarse otra vez)
static var _groan_sound: AudioStreamWAV
static var _bite_sound: AudioStreamWAV
static var _cough_sound: AudioStreamWAV
static var _burst_sound: AudioStreamWAV

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
var shove_vel := Vector2.ZERO
var shove_timer := 0.0

# --- Hambre y comida: el hambre (0 lleno, 100 la panza vacía) les va subiendo. Con un poco ya
# comen lo que tengan cerca, y con hambre de verdad salen a buscar por toda la isla (y lo dicen
# con un globito): un medio coco tirado, el pan que les tirás o las bayas de un arbusto (ver
# Food). Muertos de hambre caminan más lento, no rezan, se enojan charlando y te creen cada vez
# menos; con la panza vacía aguantan un rato y se mueren. Se ve en el carnet y se guarda.
const HUNGER_RATE := 0.2         # Por segundo: de lleno a la panza vacía en algo más de 8 minutos
const HUNGER_START := Vector2(5.0, 35.0)
const SNACK_AT := 20.0           # Con esto ya come si tiene algo cerca...
const SNACK_REACH := 220.0
const HUNGRY_AT := 50.0          # ...y con esto sale a buscar por toda la isla (y lo dice)
const STARVING_AT := 85.0        # Muerto de hambre
const STARVING_SPEED := 0.7      # Veces speed
const STARVE_TIME := 60.0        # Con la panza vacía aguanta esto
const FAITH_DRIFT_STARVING := 0.1   # Fe que pierde de más por segundo, muerto de hambre
const HUNGRY_SAY_EVERY := Vector2(8.0, 14.0)
const FOOD_SEEK_EVERY := 0.6
const FOOD_SPEED := 1.8          # Van a la comida más rápido que cuando pasean
const EAT_REACH := 6.0
const EAT_TIME := 1.8
const FOOD_GIVE_UP := 10.0       # Si no llega en este tiempo (trabado en el borde), la deja
const FOOD_COOLDOWN := 5.0       # ...y por un rato no busca otra
var hunger := 0.0
var food: Food
var _eat_t := 0.0
var _food_t := 0.0
var _food_cooldown := 0.0
var _food_seek := 0.0
var _starve_t := 0.0
var _hungry_say := 0.0
var _rig_rest := Vector2.ZERO

# --- Casa y familia: cada uno se busca una choza donde vivir (ver Decoration "hut"): con su
# pareja si tiene (en la de alguno de los dos, o en una con lugar para los dos) y si no, en
# cualquiera con lugar. De noche se van a dormir adentro hasta que se hace de día, y de día
# entran cada tanto a descansar un rato (las parejas, juntas). Adentro no se lo ve ni lo alcanza
# nada (ni rayos ni meteoritos ni la peste); si le agarra hambre de verdad sale a comer. Las
# parejas que están adentro juntas a veces tienen un bebé (ver Decoration._try_birth y la edad,
# más abajo).
const BABY_COOLDOWN := 180.0      # Después de tener un bebé, lo que tarda una pareja en tener otro
const SLEEP_AT := 0.6             # Con la noche así de cerrada (ver Sky.night) se van a dormir...
const WAKE_AT := 0.4              # ...y salen cuando aclara
const REST_EVERY := Vector2(70.0, 140.0)   # De día, cada cuánto entran a descansar...
const REST_INSIDE := Vector2(12.0, 25.0)   # ...y lo que se quedan
const HOME_CHECK := 2.0           # Cada cuánto se fija dónde vivir
const HOME_REACH := 6.0
const HOME_GIVE_UP := 15.0        # Si no llega a la puerta en este tiempo, lo deja
var home: Decoration              # Su choza (null: sin casa)
var inside := false               # Está adentro de su choza
var parents: Array[int] = []      # Números de carnet de sus padres (si nació en la isla)
var baby_cool := 0.0
var _going_home := false
var _home_t := 0.0
var _inside_t := 0.0
var _rest_t := 0.0
var _home_check := 0.0

# --- Edad: nace chiquito y crece hasta ser grande (ADULT_AGE); de chico no se pone de novio ni
# tiene hijos. Los que invocás ya son grandes (SPAWN_AGE). Con los días le salen canas, cada uno a
# su edad (ver greyness y waterline.gdshader), y de viejo (ELDER_AGE) se encorva y se achica un
# poco, camina más despacio arrastrando los pies, se cansa antes, se para más seguido y ya no
# tiene hijos. Cada uno vive lo suyo (lifespan): cuando le llega la hora, parado en la isla (o
# durmiendo, y ahí ni se despierta), se muere de viejo. La edad son los días vividos: pasan con
# los del cielo (ver Sky.passed; si adelantás el sol o la luna, también). Se ve en el carnet y se
# guarda con la partida.
const ADULT_AGE := 2.0                            # A los 2 días ya es grande
const BABY_SIZE := 0.5                            # El tamaño al nacer (veces el de un grande)
const SPAWN_AGE := Vector2(2.0, 4.0)              # Los que invocás (y los de la partida nueva)
const ELDER_AGE := 7.0                            # Desde acá es viejo (y en ELDER_DAYS, bien viejo)...
const ELDER_DAYS := 1.5
const LIFESPAN := Vector2(8.0, 10.0)              # ...y se muere de viejo entre los 8 y los 10 días
const GREY_AGE := Vector2(4.0, 6.0)               # Le empiezan a salir canas (a los hijos, como a alguno de los padres)...
const GREY_DAYS := 3.5                            # ...y en estos días le queda todo el pelo blanco
const ELDER_SHRINK := 0.94                        # Bien viejo es un poco más bajo (veces su altura)
const ELDER_SPEED := 0.75                         # Viejo camina más despacio...
const ELDER_REST := 0.55                          # ...se para más seguido...
const ELDER_TIRED := 1.3                          # ...y se cansa más rápido
var age := ADULT_AGE                  # Días vividos
var lifespan := LIFESPAN.x            # A los cuántos días se muere de viejo
var grey_age := GREY_AGE.x            # A los cuántos días le empiezan a salir canas

# --- Sueño: el cansancio (0 descansado, 100 muerto de sueño) le va subiendo despierto y se le
# va pasando durmiendo. De noche se va a dormir: a su choza si tiene, y si no se acuesta en el
# piso donde esté (y se levanta de peor ánimo). Con sueño camina más lento, bosteza y anda de
# peor ánimo; muerto de sueño se va a dormir la siesta aunque sea de día (a su choza, o donde
# esté). Descansando de día en su choza también se le pasa un poco. Se despierta cuando aclara
# (o cuando descansó, si era una siesta), si le agarra hambre de verdad, si viene el agua, si se
# asusta o si lo agarrás. Dormido no charla ni reza. Se ve en el carnet y se guarda.
const TIRED_RATE := 0.17          # Por segundo despierto: de descansado a muerto de sueño en unos 10 minutos
const SLEEP_RECOVER := 1.0        # Por segundo durmiendo (una noche alcanza y sobra)...
const REST_RECOVER := 0.4         # ...y descansando de día en su choza
const TIRED_START := Vector2(0.0, 30.0)
const SLEEPY_AT := 60.0           # Con sueño...
const EXHAUSTED_AT := 90.0        # ...y muerto de sueño
const NAP_UNTIL := 25.0           # La siesta dura hasta que el cansancio baja a esto
const SLEEPY_SPEED := 0.85
const YAWN_EVERY := Vector2(10.0, 18.0)
const LIE_DOWN := 2.0             # Por segundo: lo que tarda en acostarse
const MOOD_SLEEPY := -8.0
const MOOD_EXHAUSTED := -18.0
const MOOD_SLEPT_WELL := 4.0      # Durmió en su casa
const MOOD_SLEPT_ROUGH := -5.0    # Durmió en el piso
const MOOD_WOKEN := -3.0          # Lo despertaste
var tiredness := 0.0
var asleep := false               # Durmiendo afuera, acostado en el piso (adentro de su choza es inside)
var _napping := false             # Durmiendo la siesta (de día)
var _slept_inside := false        # Pasó la noche en su choza (al salir, durmió bien)
var _sleep_k := 0.0               # Acostándose: 0 parado, 1 acostado
var _sleep_drop := 0.0            # Lo que bajó para quedar acostado
var _lie_side := 1.0              # Para qué lado se acuesta
var _yawn := 0.0

# --- Charlas: cada tanto, dos que andan cerca y con ganas se juntan a charlar un rato. El que
# la empieza va hasta el lado del otro, se miran y hablan por turnos (con un globito arriba de
# la cabeza y un bla-bla con su voz). Según cómo les fue se quieren más o menos (ver
# Relations): así se hacen amigos, enemigos o pareja, y los enemigos a veces terminan a los
# empujones. Cuando alguien se muere, su pareja y sus amigos lloran. Se ve en el carnet.
enum Bubble { NONE, DOTS, QUESTION, EXCLAIM, MUSIC, SUN, LAUGH, HEART, SMILE, ANGER, TEAR, HUNGRY, SLEEP }
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
const TRIBUTE_PAR := 110.0              # Fe más miedo que hacen 1 ofrenda por rezo
var faith := 60.0
var fear := 0.0
var pose := Pose.NONE                   # Lo que está haciendo por vos (ver VillagerRig)
var _scram := 0.0                       # Escapándose de tu mano
var _from_water := false                # Lo agarraste del agua: si lo dejás en la isla, lo rescataste
var _gentle_death := false              # Se murió de gripe o de hambre (asusta menos a los que lo ven)
var _worship := 0.0                     # Viendo un ritual en el altar: lo que le queda de rodillas...
var _worship_at := Vector2.ZERO         # ...rezando para ahí (ver witness_ritual)
## Acostado en un altar de sacrificios esperando el final del ritual (lo mueve el altar, ver Altar)
var altar: Altar

# --- Ánimo: qué tan contento está, de 0 (deprimido) a 100 (feliz). Se va acercando de a poco a
# lo que le toca por cómo está su vida (ver _mood_factors: su pareja, sus amigos y enemigos, sus
# hijos, su casa, el hambre, la gripe y el miedo), y lo que le pasa lo sube o lo baja de golpe
# (ver add_mood) y después se le va pasando: que se le muera la pareja, un hijo o un amigo lo
# hunde y que se muera un enemigo lo alegra; las charlas, enamorarse o separarse, pelearse, tener
# un bebé, comer o que le hagas un milagro también cuentan (ver relation_mood y _mourn).
# Contento charla mejor (ver Relations.chat_delta), reza más, sonríe y a veces canta; triste
# charla peor, se pelea más, camina más lento, descansa y se mete en su casa más seguido, no
# tiene bebés y, si está deprimido, a veces llora. Se ve en el carnet (con por qué está así) y
# se guarda con la partida.
enum Mood { DEPRESSED, SAD, OK, CONTENT, HAPPY }
const MOOD_LEVELS: Array[float] = [20.0, 40.0, 60.0, 80.0]   # Dónde empieza cada uno, de triste a feliz
const MOOD_START := Vector2(50.0, 70.0)
const MOOD_BASE := 55.0            # Lo que le toca sin nada a favor ni en contra, y lo que suma...
const MOOD_PARTNER := 12.0         # ...tener pareja...
const MOOD_FRIEND := 4.0           # ...cada amigo...
const MOOD_FRIENDS_MAX := 12.0
const MOOD_ENEMY := -4.0           # ...cada enemigo...
const MOOD_ENEMIES_MAX := -12.0
const MOOD_KIDS := 6.0             # ...tener hijos...
const MOOD_HOME := 5.0             # ...tener casa (o no tenerla, si en la isla hay chozas)...
const MOOD_HOMELESS := -6.0
const MOOD_HUNGRY := -10.0         # ...el hambre...
const MOOD_STARVING := -25.0
const MOOD_SICK := -15.0           # ...la gripe...
const MOOD_FEAR := -0.25           # ...y el miedo (por punto, de MOOD_FEAR_FROM para arriba)
const MOOD_FEAR_FROM := 20.0
const MOOD_DRIFT := 0.15           # Por segundo: lo que se acerca a lo que le toca...
const MOOD_DRIFT_HOME := 2.0       # ...(descansando en su casa, el doble)
const MOOD_CHECK := 1.0            # Cada cuánto se fija qué le toca
## Lo que le pasa, de golpe
const MOOD_LOST_PARTNER := -45.0
const MOOD_LOST_CHILD := -40.0
const MOOD_LOST_PARENT := -30.0
const MOOD_LOST_FRIEND := -15.0
const MOOD_ENEMY_DIED := 10.0
const MOOD_SAW_DEATH := -6.0       # Ver morir bien de cerca a alguien que no era nada suyo
const MOOD_CHAT := 0.4             # Veces lo que se quieren de más (o de menos) después de charlar
const MOOD_SHOVED := -8.0          # Lo empujaron en una pelea
const MOOD_LOST_HOME := -15.0      # Le rompieron la casa
const MOOD_ATE := 0.15             # Por cada punto de hambre que se le va comiendo
const MOOD_MIRACLE := 10.0         # Lo curaste o lo rescataste
const MOOD_MANNA := 6.0            # Comió comida del cielo
const MOOD_THROWN := -6.0
const MOOD_BONKED := -5.0
const MOOD_BURNED := -12.0         # Se prendió fuego y se salvó
## Cuando cambia lo que es con alguien (ver Relations): [cuánto, por qué]
const MOOD_EVENTS := {
	Relations.Event.FRIENDS: [8.0, "Se hizo un amigo"],
	Relations.Event.ENEMIES: [-8.0, "Se hizo un enemigo"],
	Relations.Event.MADE_UP: [6.0, "Hizo las paces"],
	Relations.Event.COUPLE: [20.0, "Se enamoró"],
	Relations.Event.BROKE_UP: [-20.0, "Se separó"],
	Relations.Event.DRIFTED: [-4.0, "Se distanció de un amigo"],
	Relations.Event.BIRTH: [25.0, "Tuvo un bebé"],
}
const MOOD_NOTE := 5.0             # Lo que le pasa desde esto (más o menos) es "por qué está así"...
const MOOD_REMEMBER := 90.0        # ...durante esto (ver mood_reason)
const MOOD_SAY_EVERY := Vector2(14.0, 26.0)   # Feliz canta; deprimido llora
const MOOD_SAD_SPEED := 0.8        # Triste camina más lento...
const MOOD_SAD_REST := 0.55        # ...se para más seguido...
const MOOD_SAD_HOME := 0.5         # ...y se mete en su casa más seguido (veces REST_EVERY)
const MOOD_BABY_AT := 45.0         # Para tener un bebé, los dos al menos así de contentos
const MOOD_TRIBUTE := Vector2(0.6, 1.4)   # Lo que rinde su rezo, de deprimido a feliz
var mood := 60.0
var _mood_goal := 60.0
var _mood_factors_now: Array = []  # Lo que cuenta ahora (ver _mood_factors)
var _mood_check := 0.0
var _mood_say := 0.0
var _mood_why := ""                # Lo último fuerte que le pasó...
var _mood_why_amount := 0.0
var _mood_why_t := INF             # ...y hace cuánto

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
	hunger = randf_range(HUNGER_START.x, HUNGER_START.y)
	_hungry_say = randf_range(HUNGRY_SAY_EVERY.x, HUNGRY_SAY_EVERY.y)
	mood = randf_range(MOOD_START.x, MOOD_START.y)
	tiredness = randf_range(TIRED_START.x, TIRED_START.y)
	_yawn = randf_range(YAWN_EVERY.x, YAWN_EVERY.y)
	_mood_goal = mood
	_mood_say = randf_range(MOOD_SAY_EVERY.x, MOOD_SAY_EVERY.y)
	_mood_check = randf_range(0.0, MOOD_CHECK)
	_rest_t = randf_range(REST_EVERY.x, REST_EVERY.y)
	_home_check = randf_range(0.0, HOME_CHECK)
	age = randf_range(SPAWN_AGE.x, SPAWN_AGE.y)   # Los bebés y las partidas guardadas traen la suya
	lifespan = randf_range(LIFESPAN.x, LIFESPAN.y)
	grey_age = randf_range(GREY_AGE.x, GREY_AGE.y)
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
		_inside_ai(dt)
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
		_sleep_ai(dt)
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
	if is_zombie():
		# El hongo lo domina: ni come, ni charla, ni duerme, ni va a su casa; persigue a los sanos
		if _zombie_ai(dt):
			return
	else:
		_avoid_zombies(dt)
		if food != null and _food_ai(dt):
			return
		if chat_with != null and _chat_ai(dt):
			return
		if _going_home and _walk_home(dt):
			return
		if _seek_sleep():
			return
		_seek_food(dt)
		_seek_home(dt)
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
	elif is_zombie():
		pace *= _zombie_pace()
	elif spore_shows():
		pace *= SPORE_SPEED
	elif flu == Flu.SICK:
		pace *= FLU_SPEED
	elif starving():
		pace *= STARVING_SPEED
	elif is_sad():
		pace *= MOOD_SAD_SPEED
	elif tiredness >= SLEEPY_AT:
		pace *= SLEEPY_SPEED
	if is_elder():
		pace *= ELDER_SPEED   # Hasta escapándose
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
			var rest := FLU_REST_CHANCE if flu == Flu.SICK else (MOOD_SAD_REST if is_sad() else REST_CHANCE)
			if is_zombie():
				rest = ZOMBIE_REST   # Sigue arrastrando los pies (sin nadie a quien perseguir)
			elif spore_shows():
				rest = maxf(rest, SPORE_REST)
			if is_elder() and not is_zombie():
				rest = maxf(rest, ELDER_REST)
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

# --- COMIDA ---
## Parado o caminando en la isla (no agarrado, volando, en el agua, en un tornado, adentro de su
## choza ni muerto).
func is_idle() -> bool:
	return not (dragging or falling or in_water or eaten or dead or tornado or inside or asleep or altar)

## Con hambre (aunque sea un poco), libre y tranquilo en la isla.
func wants_food() -> bool:
	return food == null and chat_with == null and is_idle() and not on_fire and _food_cooldown <= 0.0 \
			and hunger >= SNACK_AT and not _going_home and not is_zombie()

## Muerto de hambre (ver STARVING_AT).
func starving() -> bool:
	return hunger >= STARVING_AT and not dead

## Comió: se le va el hambre.
func feed(amount: float) -> void:
	add_mood(minf(amount, hunger) * MOOD_ATE)
	hunger = maxf(0.0, hunger - amount)
	_starve_t = 0.0

## Va a comerse f (lo reserva, así no va otro).
func go_eat(f: Food) -> void:
	food = f
	f.claim(self)
	_eat_t = 0.0
	_food_t = 0.0
	_resting = false

## Con hambre, busca lo más cerca para comer: algo tirado (un medio coco, el pan que le
## tiraste) o una baya de un arbusto. Con poca hambre, solo si está cerca.
func _seek_food(dt: float) -> void:
	if not wants_food():
		return
	_food_seek -= dt
	if _food_seek > 0.0:
		return
	_food_seek = FOOD_SEEK_EVERY
	var best_d := INF if hunger >= HUNGRY_AT else SNACK_REACH
	var best: Food = null
	var bush: Decoration = null
	for node in get_tree().get_nodes_in_group("food"):
		var f := node as Food
		if f and f.available() and f.point().distance_to(global_position) < best_d:
			best = f
			best_d = f.point().distance_to(global_position)
	for node in get_tree().get_nodes_in_group("berry_bush"):
		var b := node as Decoration
		var d := b.global_position.distance_to(global_position)
		if b.free_berry() >= 0 and d < best_d:
			bush = b
			best_d = d
	if bush:
		best = bush.pick_berry()
	if best:
		go_eat(best)

func stop_eating() -> void:
	food = null
	_eat_t = 0.0
	if rig:
		rig.position = _rig_rest

## Le cayó un coco en la cabeza.
func bonk(at: Vector2) -> void:
	if rig:
		rig.hit(at, Vector2.DOWN, 0.6)
	Game.say("¡Bonk!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_TEXT)
	add_mood(MOOD_BONKED, "Le cayó un coco en la cabeza")

## Camina hasta su comida y se la come. false si ya no tiene.
func _food_ai(dt: float) -> bool:
	if not is_instance_valid(food) or food.eater != self:
		stop_eating()
		return false
	var to := food.eat_spot(self) - global_position
	if _eat_t > 0.0 or to.length() <= EAT_REACH:
		# Comiendo: quieto, mirando la comida y masticando
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
			and _scram <= 0.0 and pose == Pose.NONE and not _going_home and not is_zombie()

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

## De qué habla: según lo que son y si la charla viene bien o mal.
func _chat_topic(o: Villager) -> Bubble:
	if mood_level() == Mood.DEPRESSED and randf() < 0.4:
		return [Bubble.TEAR, Bubble.DOTS].pick_random()   # Deprimido no tiene ganas de nada
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
	if absf(_chat_delta) > CHAT_MOOD:   # Cómo les fue también les cambia el ánimo
		var why := "Charló lindo" if _chat_delta > 0.0 else "Discutió"
		add_mood(_chat_delta * MOOD_CHAT, why)
		o.add_mood(_chat_delta * MOOD_CHAT, why)
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
	# (más si andan tristes)
	if k == Relations.Kind.ENEMY and _chat_delta < 0.0 and randf() < FIGHT_CHANCE * lerpf(1.6, 0.6, (mood + o.mood) / 200.0):
		var pusher: Villager = self if randf() < 0.5 else o
		var pushed: Villager = o if pusher == self else self
		pushed._get_pushed_by(pusher)
		pushed.add_mood(MOOD_SHOVED, "Se peleó a los empujones")
		if news == "":
			news = "¡Pelea!"
			color = HUD.C_WARN
	if news != "":
		var mid := (get_global_transform_with_canvas().origin + o.get_global_transform_with_canvas().origin) * 0.5
		Game.say(news, mid + Vector2(0, -100), color)
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

## Se murió: los que lo vieron se asustan (más si lo querían) y se quedan mirando; su pareja, sus
## amigos y su familia lloran un rato, pierden fe y se ponen tristes, y sus enemigos se alegran.
## Y deja de contar para los demás.
func _mourn() -> void:
	var at := body_center()
	var scary := FEAR_DEATH * (FEAR_DEATH_GENTLE if _gentle_death else 1.0)
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or not o.is_alive() or o.is_zombie():
			continue   # (El zombi ya no siente nada)
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
				o.add_mood(MOOD_LOST_PARTNER, "Se le murió la pareja")
				Game.say("Perdió a su pareja", o.get_global_transform_with_canvas().origin + Vector2(0, -100), HUD.C_MUTED)
			Relations.Kind.FRIEND:
				o.say(Bubble.TEAR, MOURN_TIME * 0.6, false)
				o.add_faith(-FAITH_LOST_FRIEND)
				o.add_mood(MOOD_LOST_FRIEND, "Se le murió un amigo")
			Relations.Kind.ENEMY:
				o.add_mood(MOOD_ENEMY_DIED, "Se murió un enemigo")
				if o.bubble_t <= 0.0:
					o.say(Bubble.LAUGH, REACT_TIME, false)
			_:
				if seen > 0.0:
					o.add_mood(MOOD_SAW_DEATH * seen, "Vio morir a alguien")
		# Su familia
		var female := gender == Gender.FEMALE
		if o.id_number in parents:
			o.say(Bubble.TEAR, MOURN_TIME, false)
			o.add_mood(MOOD_LOST_CHILD, "Se le murió una hija" if female else "Se le murió un hijo")
		elif id_number in o.parents:
			o.say(Bubble.TEAR, MOURN_TIME * 0.8, false)
			o.add_mood(MOOD_LOST_PARENT, "Se le murió la mamá" if female else "Se le murió el papá")
	_bonds_at_death = Relations.snapshot(self)   # Por si vuelve a la vida (ver resurrect)
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

# --- ÁNIMO ---
## Deprimido, triste, tranquilo, contento o feliz.
func mood_level() -> Mood:
	var level := 0
	for at in MOOD_LEVELS:
		if mood >= at:
			level += 1
	return level as Mood

## Triste o deprimido.
func is_sad() -> bool:
	return mood < MOOD_LEVELS[1]

## Le pasó algo que lo pone más contento (o más triste). why: lo que dice el carnet de por qué
## está así (ver mood_reason), si fue fuerte.
func add_mood(amount: float, why := "") -> void:
	if not is_alive():
		return
	mood = clampf(mood + amount, 0.0, 100.0)
	if why != "" and absf(amount) >= MOOD_NOTE \
			and (absf(amount) >= absf(_mood_why_amount) or _mood_why_t > MOOD_REMEMBER * 0.25):
		_mood_why = why
		_mood_why_amount = amount
		_mood_why_t = 0.0

## Cambió lo que es con alguien, o tuvo un bebé (ver Relations._note).
func relation_mood(ev: Relations.Event) -> void:
	if MOOD_EVENTS.has(ev):
		add_mood(MOOD_EVENTS[ev][0], MOOD_EVENTS[ev][1])

## Lo que le toca por cómo está su vida: [[por qué, cuánto], ...] (ver MOOD_BASE).
func _mood_factors() -> Array:
	var out := []
	var bonds := Relations.counts(self)
	if bonds[Relations.Kind.COUPLE] > 0:
		out.append(["Tiene pareja", MOOD_PARTNER])
	if bonds[Relations.Kind.FRIEND] > 0:
		out.append(["Tiene amigos", minf(bonds[Relations.Kind.FRIEND] * MOOD_FRIEND, MOOD_FRIENDS_MAX)])
	if bonds[Relations.Kind.ENEMY] > 0:
		out.append(["Tiene enemigos", maxf(bonds[Relations.Kind.ENEMY] * MOOD_ENEMY, MOOD_ENEMIES_MAX)])
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and id_number in o.parents and o.is_alive():
			out.append(["Tiene hijos", MOOD_KIDS])
			break
	if _home_ok():
		out.append(["Tiene casa", MOOD_HOME])
	elif get_tree().has_group("hut"):
		out.append(["No tiene casa", MOOD_HOMELESS])
	if starving():
		out.append(["Se muere de hambre", MOOD_STARVING])
	elif hunger >= HUNGRY_AT:
		out.append(["Tiene hambre", MOOD_HUNGRY])
	if flu == Flu.SICK:
		out.append(["Tiene gripe", MOOD_SICK])
	if spore_shows():
		out.append(["Le crecen hongos", MOOD_SPORE])
	if fear > MOOD_FEAR_FROM:
		out.append(["Tiene miedo", (fear - MOOD_FEAR_FROM) * MOOD_FEAR])
	if tiredness >= EXHAUSTED_AT:
		out.append(["Se cae de sueño", MOOD_EXHAUSTED])
	elif tiredness >= SLEEPY_AT:
		out.append(["Tiene sueño", MOOD_SLEEPY])
	return out

## Se va acercando a lo que le toca (lo que le pasó se le va pasando). Feliz, a veces canta;
## deprimido, a veces llora.
func _update_mood(dt: float) -> void:
	if not is_alive() or is_zombie():
		return   # (El zombi ya no está ni contento ni triste)
	_mood_why_t += dt
	_mood_check -= dt
	if _mood_check <= 0.0:
		_mood_check = MOOD_CHECK
		_mood_factors_now = _mood_factors()
		_mood_goal = MOOD_BASE
		for f: Array in _mood_factors_now:
			_mood_goal += f[1]
		_mood_goal = clampf(_mood_goal, 0.0, 100.0)
	mood = move_toward(mood, _mood_goal, MOOD_DRIFT * (MOOD_DRIFT_HOME if inside else 1.0) * dt)
	_mood_say -= dt
	if _mood_say > 0.0:
		return
	_mood_say = randf_range(MOOD_SAY_EVERY.x, MOOD_SAY_EVERY.y)
	if is_idle() and chat_with == null and food == null and bubble_t <= 0.0 and not on_fire:
		match mood_level():
			Mood.HAPPY:
				say([Bubble.MUSIC, Bubble.SUN].pick_random(), 1.4, false)
			Mood.DEPRESSED:
				say(Bubble.TEAR, 1.8, false)

## Por qué está así (para el carnet): lo último fuerte que le pasó, si fue hace poco y va para
## el mismo lado, y si no lo que más le pesa (o le alegra) de su vida. Tranquilo, nada.
func mood_reason() -> String:
	var level := mood_level()
	if level == Mood.OK:
		return ""
	var sad := level < Mood.OK
	if _mood_why != "" and _mood_why_t < MOOD_REMEMBER and (_mood_why_amount < 0.0) == sad:
		return _mood_why
	var best := ""
	var best_v := 0.0
	for f: Array in _mood_factors_now:
		var v: float = f[1]
		if (v < 0.0) == sad and absf(v) > absf(best_v):
			best = f[0]
			best_v = v
	return best

# --- SUEÑO ---
## Durmiendo: acostado en el piso, o en su choza de noche (o durmiendo la siesta).
func is_sleeping() -> bool:
	return asleep or (inside and (_night() >= SLEEP_AT or _napping))

## El cansancio sube despierto y baja durmiendo (o descansando en su choza). Con sueño bosteza.
func _update_sleep(dt: float) -> void:
	if not is_alive() or is_zombie():
		return   # (El zombi no se cansa)
	if is_sleeping():
		tiredness -= SLEEP_RECOVER * dt
		_slept_inside = _slept_inside or inside
	elif inside:
		tiredness -= REST_RECOVER * dt
	else:
		tiredness += TIRED_RATE * (ELDER_TIRED if is_elder() else 1.0) * dt
	tiredness = clampf(tiredness, 0.0, 100.0)
	if tiredness < SLEEPY_AT or is_sleeping():
		return
	_yawn -= dt
	if _yawn <= 0.0:
		_yawn = randf_range(YAWN_EVERY.x, YAWN_EVERY.y)
		if chat_with == null and bubble_t <= 0.0 and is_idle():
			say(Bubble.SLEEP, 1.4, false)

## Se puede quedar dormido: tranquilo en la isla, sin nada que hacer y sin hambre de verdad
## (muerto de sueño, aunque tenga hambre; muerto de hambre, nunca).
func _can_sleep() -> bool:
	return is_idle() and chat_with == null and food == null and not on_fire and _flee <= 0.0 \
			and _scram <= 0.0 and not is_scared() and pose == Pose.NONE and not starving() \
			and (hunger < HUNGRY_AT or tiredness >= EXHAUSTED_AT) and not is_zombie() \
			and not _going_home and not Storm.water_near(ground_point(), FLOOD_FLEE)

## De noche, el que no tiene casa se acuesta donde está; de día, muerto de sueño se va a su
## choza a dormir la siesta (o, si no tiene, se duerme donde está). true si se durmió.
func _seek_sleep() -> bool:
	if not _can_sleep():
		return false
	if _night() >= SLEEP_AT:
		if _home_ok() and _can_go_home():
			return false   # Se va a su choza (ver _seek_home)
		_napping = tiredness >= EXHAUSTED_AT   # Muerto de sueño: aunque tenga hambre, duerme hasta descansar
		fall_asleep()
		return true
	if tiredness < EXHAUSTED_AT:
		return false
	_napping = true
	if _can_go_home():
		_go_home()
		return false
	fall_asleep()
	return true

## Se acuesta en el piso y se duerme.
func fall_asleep() -> void:
	asleep = true
	_sleep_k = 0.0
	_sleep_drop = 0.0
	_lie_side = -1.0 if randf() < 0.5 else 1.0
	velocity = Vector2.ZERO
	_resting = false

## Durmiendo en el piso: se acuesta de a poco y le salen unas zetas. Se despierta cuando aclara
## (o, si era una siesta, cuando descansó), si le agarra hambre de verdad (en la siesta, solo si
## se muere de hambre), si se prende fuego o si se le viene el agua.
func _sleep_ai(dt: float) -> void:
	velocity = Vector2.ZERO
	_sleep_k = move_toward(_sleep_k, 1.0, LIE_DOWN * dt)
	rotation = lerp_angle(0.0, _lie_side * PI * 0.5, _sleep_k)
	var drop := FEET_DROP * scale.y * _sleep_k
	global_position.y += drop - _sleep_drop
	_sleep_drop = drop
	if bubble_t <= 0.0:
		say(Bubble.SLEEP, 2.0, false)
	var day := _night() < WAKE_AT
	var hungry := starving() or (hunger >= HUNGRY_AT and not _napping)
	if hungry or on_fire or Storm.water_near(ground_point(), FLOOD_FLEE) \
			or (day and tiredness <= (NAP_UNTIL if _napping else SLEEPY_AT)):
		if day and not _napping:
			add_mood(MOOD_SLEPT_ROUGH, "Durmió en el piso")
		wake_up()

## Se despierta y, si estaba acostado en el piso, se levanta. stand: false si lo agarraron o se
## lo llevó algo (ahí ya no está acostado donde estaba).
func wake_up(stand := true) -> void:
	if not asleep:
		return
	asleep = false
	_napping = false
	if stand:
		global_position.y -= _sleep_drop
		_pick_dir()
		wander_timer = randf_range(1.0, 2.5)
	_sleep_drop = 0.0
	_sleep_k = 0.0
	if bubble == Bubble.SLEEP:
		bubble_t = 0.0

# --- EDAD ---
## Todavía es chico (ver ADULT_AGE).
func is_child() -> bool:
	return age < ADULT_AGE

## Ya es viejo (ver ELDER_AGE).
func is_elder() -> bool:
	return age >= ELDER_AGE

## Cuántos días enteros vivió.
func days() -> int:
	return int(age)

## Qué tan viejo está: 0 hasta ELDER_AGE, 1 ELDER_DAYS después (bien encorvado, ver VillagerRig).
func oldness() -> float:
	return clampf((age - ELDER_AGE) / ELDER_DAYS, 0.0, 1.0)

## Cuántas canas tiene: 0 ninguna .. 1 el pelo todo blanco (ver GREY_AGE y waterline.gdshader).
func greyness() -> float:
	return clampf((age - grey_age) / GREY_DAYS, 0.0, 1.0)

## La edad (al pasar los días, al nacer y al cargar la partida), con el tamaño que le toca (con su
## altura) y sus canas.
func set_age(a: float) -> void:
	age = a
	var grow := lerpf(BABY_SIZE, 1.0, clampf(age / ADULT_AGE, 0.0, 1.0))
	scale = Vector2.ONE * grow * lerpf(1.0, ELDER_SHRINK, oldness()) * height
	if _waterline:
		_waterline.set_shader_parameter("grey", greyness())

## Le llegó la hora: se muere tranquilo donde está (si estaba durmiendo, ni se despierta).
func _die_of_old_age() -> void:
	Game.say("Murió de vieja" if gender == Gender.FEMALE else "Murió de viejo",
			get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_MUTED)
	if food:
		food.release_eater()
	_gentle_death = true
	_old_age_death = true
	var lying := asleep
	_die()
	if not lying:
		swing_vel = (1.0 if randf() < 0.5 else -1.0) * randf_range(2.0, 3.0)   # Se cae para un costado, despacito
		corpse_vel = Vector2.ZERO

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
	grey_age = clampf((a if randf() < 0.5 else b).grey_age + randf_range(-0.5, 0.5), GREY_AGE.x, GREY_AGE.y)

# --- CASA Y FAMILIA ---
## Grande (y no viejo), sano (sin gripe ni espora), no muerto de hambre, más o menos contento y
## sin un bebé reciente.
func can_have_baby() -> bool:
	return not is_child() and not is_elder() and not dead and not is_sick() and not starving() \
			and baby_cool <= 0.0 and mood >= MOOD_BABY_AT and spore <= 0.0

## Le pasan los días (de chico crece; de grande le salen canas y de viejo se achica) y, si le
## llegó la hora, se muere de viejo. Se le va pasando lo del último bebé y cada tanto se fija
## dónde vivir.
func _update_family(dt: float) -> void:
	if not is_alive():
		return
	baby_cool = maxf(0.0, baby_cool - dt)
	var was_child := is_child()
	var sky := get_tree().get_first_node_in_group("sky")
	if sky and sky.passed > 0.0:
		set_age(age + sky.passed)
	if was_child and not is_child():
		if visible:
			Game.say("¡Ya es grande!", get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_SHOP)
	# Termina parado en la isla (o durmiendo): no se muere colgando del mouse, flotando ni adentro
	if age >= lifespan and (is_idle() or asleep) and not on_fire:
		_die_of_old_age()
		return
	_home_check -= dt
	if _home_check <= 0.0:
		_home_check = HOME_CHECK
		_update_home()

## Su choza sigue estando (no la quitaron).
func _home_ok() -> bool:
	return is_instance_valid(home) and home.is_in_group("hut") and not home.is_queued_for_deletion()

## Su pareja (viva), o null.
func _partner() -> Villager:
	var id := Relations.partner_id(self)
	if id == 0:
		return null
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.id_number == id and v.is_alive():
			return v
	return null

## Dónde vivir: con su pareja (en la choza de alguno de los dos, si hay lugar, o en una con
## lugar para los dos) y si no, en cualquier choza con lugar. Adentro no se muda.
func _update_home() -> void:
	if home and not _home_ok():
		home = null
	if inside:
		return
	var p := _partner()
	if p and p.home != home:
		if p._home_ok() and p.home.free_beds() >= 1:
			home = p.home
		elif home and home.free_beds() >= 1 and not p.inside:
			p.home = home
		elif not p.inside:
			var h := _free_hut(2)
			if h:
				home = h
				p.home = h
		return
	if home == null:
		home = _free_hut(1)

## La choza más cerca con al menos beds lugares libres, o null.
func _free_hut(beds: int) -> Decoration:
	var best: Decoration = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("hut"):
		var h := node as Decoration
		var d := h.door().distance_to(global_position)
		if h and not h.moving and h.free_beds() >= beds and d < best_d:
			best = h
			best_d = d
	return best

## De noche, o de día cada tanto, se va a su choza (si está tranquilo y sin hambre de verdad).
## Las parejas que viven juntas se van juntas.
func _seek_home(dt: float) -> void:
	_rest_t -= dt
	if not _can_go_home():
		return
	if _night() >= SLEEP_AT or _rest_t <= 0.0:
		_go_home()
		var p := _partner()
		if p and p.home == home and p._can_go_home():
			p._go_home()

func _can_go_home() -> bool:
	return _home_ok() and not _going_home and is_idle() and not on_fire and food == null \
			and chat_with == null and _flee <= 0.0 and _scram <= 0.0 and pose == Pose.NONE \
			and hunger < HUNGRY_AT and not home.moving and not is_zombie()

func _go_home() -> void:
	_going_home = true
	_home_t = 0.0
	_rest_t = randf_range(REST_EVERY.x, REST_EVERY.y) * (MOOD_SAD_HOME if is_sad() else 1.0)
	_resting = false

## Dónde se para para entrar: con los pies en la puerta.
func _door_spot() -> Vector2:
	return home.door() - Vector2(0, (FEET - 2.0) * scale.y)

## Camina hasta la puerta de su choza y entra. false si ya no va.
func _walk_home(dt: float) -> bool:
	if not _home_ok() or not is_idle() or home.moving:
		_going_home = false
		return false
	_home_t += dt
	if _home_t > HOME_GIVE_UP:
		_going_home = false
		return false
	var to := _door_spot() - global_position
	if to.length() <= HOME_REACH:
		_going_home = false
		enter_home()
		return true
	dir = to.normalized()
	_update_sprite_flip()
	velocity = (dir * speed + shove_vel).limit_length(maxf(to.length() / dt, shove_vel.length()))
	var prev_pos := global_position
	move_and_slide()
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(global_position, island_poly):
		if shove_timer > 0.0:
			_going_home = false
			_fall_from_shove()
			return true
		global_position = prev_pos
		if to.length() < 30.0:   # La puerta queda en la orilla: entra desde ahí
			_going_home = false
			enter_home()
	return true

## Entra a su choza: no se lo ve ni lo alcanza nada hasta que sale.
func enter_home() -> void:
	inside = true
	_going_home = false
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_inside_t = randf_range(REST_INSIDE.x, REST_INSIDE.y)
	if chat_with:
		_end_chat()
	if food:
		food.release_eater()

## Le rompieron la choza (ver Decoration.smash): si estaba adentro sale de golpe, y se queda
## sin casa (después se busca otra).
func lose_home() -> void:
	if inside:
		_leave_home()
	home = null
	add_mood(MOOD_LOST_HOME, "Le rompieron la casa")

## Sale por la puerta (o donde estaba, si le quitaron la choza).
func _leave_home() -> void:
	inside = false
	_napping = false
	_slept_inside = false
	visible = true
	$CollisionShape2D.set_deferred("disabled", false)
	if _home_ok():
		global_position = _door_spot() + Vector2(0, 4)
	_rest_t = randf_range(REST_EVERY.x, REST_EVERY.y) * (MOOD_SAD_HOME if is_sad() else 1.0)
	dir = Vector2(randf_range(-0.8, 0.8), 1.0).normalized()
	_update_sprite_flip()
	_walk = 0.0
	_heading = Vector2.ZERO
	wander_timer = randf_range(1.5, 3.0)

## Adentro: se queda hasta que se hace de día (o, de día, hasta que descansó), o hasta que le
## agarra hambre de verdad. Si le quitaron la choza, sale.
func _inside_ai(dt: float) -> void:
	velocity = Vector2.ZERO
	if is_zombie():
		_leave_home()   # Se hizo zombi adentro: sale (ver _spore_turned)
		return
	if not _home_ok():
		_leave_home()
		home = null
		return
	global_position = _door_spot()   # Si mueven la choza, va con ella
	_inside_t -= dt
	# De día sale cuando descansó (de la noche, o de la siesta: ahí no importa _inside_t)
	var rested := tiredness <= (NAP_UNTIL if _napping else SLEEPY_AT)
	if hunger >= HUNGRY_AT or (_night() < WAKE_AT and rested and (_inside_t <= 0.0 or _napping)):
		if _slept_inside and hunger < HUNGRY_AT:
			add_mood(MOOD_SLEPT_WELL, "Durmió bien")
		_leave_home()

## Qué tan de noche es (0 mediodía, 1 noche cerrada; ver Sky.night).
func _night() -> float:
	var sky := get_tree().get_first_node_in_group("sky")
	return sky.night if sky else 0.0

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

## Lo que deja cada vez que reza (ver World): más cuanto más cree en vos y más te teme, y
## cuanto más contento está.
func tribute() -> float:
	return (faith + fear) / TRIBUTE_PAR * lerpf(MOOD_TRIBUTE.x, MOOD_TRIBUTE.y, mood / 100.0)

## Si te reza (y deja ofrendas, ver World._prayers).
func prays() -> bool:
	return prayer_block() == ""

## Por qué no te reza ahora ("" si reza): se murió, se está ahogando, es un zombi, le crecen
## hongos, tiene gripe, se muere de hambre o está durmiendo (se ve en el carnet).
func prayer_block() -> String:
	if not is_alive():
		return "Muerto"
	if drowning:
		return "Se está ahogando"
	if is_zombie():
		return "Es un zombi"
	if spore_shows():
		return "Le crecen hongos"
	if is_sick():
		return "Tiene gripe"
	if starving():
		return "Se muere de hambre"
	if is_sleeping():
		return "Está durmiendo"
	return ""

## Cuánto le afecta algo que pasó en at: 1 bien de cerca, nada si no lo vio.
func _witness(at: Vector2) -> float:
	if inside:
		return 0.0   # Adentro de su choza no ve nada
	var d := body_center().distance_to(at)
	return 0.0 if d > WITNESS_RADIUS else lerpf(1.0, 0.4, d / WITNESS_RADIUS)

## Le hiciste un milagro (lo curaste o lo rescataste): te cree más y te lo agradece. Los que
## lo vieron (si lo curaste) también te creen un poco más.
func _thank(amount: float, seen_by_others: bool) -> void:
	add_faith(amount)
	add_mood(MOOD_MIRACLE, "Le hiciste un milagro")
	say(Bubble.HEART, THANKS_TIME, false)
	if not seen_by_others:
		return
	var at := body_center()
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != self and o.is_alive():
			o.add_faith(FAITH_MIRACLE * o._witness(at))

## La fe se le va gastando y el miedo se le va pasando (o crece, con el cielo perturbado). Si
## tu mano anda cerca reacciona según lo que cree: reza (pose), se escapa (_scram) o nada; y
## si sacaste un arma, el que te teme se agacha.
func _update_faith(dt: float) -> void:
	_scram = maxf(0.0, _scram - dt)
	pose = Pose.NONE
	if not is_alive() or is_zombie():
		return   # (El zombi ya no cree en nada ni le tiene miedo a nada)
	add_faith(-(FAITH_DRIFT + (FAITH_DRIFT_STARVING if starving() else 0.0)) * dt)
	add_fear(-FEAR_FADE * (FEAR_FADE_CHAT if chat_with else 1.0) * dt)
	if _creepy_sky():
		add_fear(FEAR_CREEPY * dt)
	if _worship > 0.0:
		# Viendo un ritual en el altar: de rodillas, rezando para ese lado
		_worship -= dt
		if is_idle() and not on_fire:
			pose = Pose.PRAY
			if rig:
				rig.set_facing_left(_worship_at.x < global_position.x)
		return
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
	elif fear >= FEARS_AT and Power.threat():   # Con un arma o poder afuera (con la comida, no)
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

func _fall_from_shove() -> void:
	var push := shove_vel
	shove_vel = Vector2.ZERO
	shove_timer = 0.0
	_start_fall()
	if falling:
		fall_vx = push.x
		v_fall = minf(push.y, 0.0)
		swing_vel = clampf(push.x * 0.02, -8.0, 8.0)  # Que trastabille al caer

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

# --- ALTAR ---
## Lo soltaste encima del altar (ver Altar): queda acostado en la piedra, pataleando y con la
## boca abierta, hasta el final del ritual (lo mueve el altar).
func lay_on_altar(a: Altar) -> void:
	altar = a
	wake_up(false)
	_going_home = false
	if food:
		food.release_eater()
	if chat_with:
		_end_chat()
	set_physics_process(false)
	velocity = Vector2.ZERO
	rotation = (1.0 if randf() < 0.5 else -1.0) * PI * 0.5
	z_index = 1   # Arriba de la piedra (por el orden por Y quedaría detrás del altar)
	_scared = Altar.RITUAL_TIME + 1.0   # La boca abierta (ver VillagerRig)
	add_fear(FEAR_THROW)

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
		_end_chat()
	if food:
		food.release_eater()
	match creed():
		Creed.DEVOUT, Creed.ZEALOT:
			_worship = time
			_worship_at = at
		Creed.TERRIFIED:
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
	floor_y = global_position.y + FEET_DROP - _sleep_drop   # Durmiendo ya estaba acostado
	velocity = Vector2.ZERO
	_drop_shield()   # Morirse se lleva el escudo y la vacuna
	vaccine_t = 0.0
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

## Le cayó un rayo (ver Lightning): se electrocuta y muere. Con el escudo, el rayo rebota.
func zap() -> void:
	if not can_zap():
		return
	if shielded():
		_ward_off(true)
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
## Si lo puede alcanzar una explosión (vivo o cadáver; no si se está friendo por un rayo ni si
## está volviendo a la vida).
func can_blast() -> bool:
	return not eaten and not inside and altar == null and zap_state == Zap.NONE and _rising <= 0.0 \
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

# --- FUEGO ---
func _update_fire(dt: float) -> void:
	if eaten or zap_state != Zap.NONE or _rising > 0.0 or is_queued_for_deletion():
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
	if not dead:
		Game.say("¡Se prendió fuego!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_WARN)

## Se apaga. steam: cayó al agua (sale vapor).
func _put_out(steam := false) -> void:
	if not on_fire:
		return
	on_fire = false
	add_mood(MOOD_BURNED, "Se prendió fuego")
	_heat = 0.0
	_flames.on = false
	_sparks.emitting = false
	_smoke.emitting = false
	_fire_light.enabled = false
	_waterline.set_shader_parameter("embers", 0.0)
	if steam:
		_spawn_steam()
		if not dead:
			Game.say("¡Fiuuu!", get_global_transform_with_canvas().origin + Vector2(0, -60), HUD.C_TEXT)

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
		return global_position + Vector2(0, (FEET - 2.0 - FEET_DROP) * scale.y)   # Acostado
	if asleep:
		return global_position + Vector2(0, (FEET - 2.0) * scale.y - _sleep_drop)   # Acostándose a dormir
	return global_position + Vector2(0, (FEET - 2.0) * scale.y)   # (Los chicos son más bajos)

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
	if flu != Flu.HEALTHY or not is_alive():
		return
	if protected_from_disease():
		_exposure = 0.0
		_ward_off()
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

## La peste (ver Plague): se enferma ya, sin incubarla y aunque estuviera inmune (con el escudo o
## vacunado, no).
func infect() -> void:
	if not is_alive() or inside or flu == Flu.SICK:
		return
	if protected_from_disease():
		_ward_off()
		return
	flu = Flu.SICK
	flu_t = randf_range(SICK_TIME.x, SICK_TIME.y)
	_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y) * 0.5
	_exposure = 0.0

## El poder de curar (ver Cure): se le va la gripe (queda inmune), la espora (si todavía no es
## un zombi: ahí ya no tiene cura) y, si se estaba quemando, se apaga y se le va el tizne. true
## si tenía algo que curar.
func cure() -> bool:
	if not is_alive() or inside or zap_state != Zap.NONE:
		return false
	var zombie := is_zombie()   # Al zombi ya no lo salva nada (si se quema, se apaga igual)
	var said := false   # Ya dijo "¡Se curó!"
	var flu_cured := not zombie and (flu == Flu.INCUBATING or flu == Flu.SICK)
	if flu_cured:
		_recover()   # Ya dice "¡Se curó!"
		said = true
	var spore_cured := spore > 0.0 and not zombie
	if spore_cured:
		_clear_spore()
		if not said:
			Game.say("¡Se curó!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SHOP)
			said = true
	elif zombie:
		Game.say("Ya no tiene cura", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_MUTED)
	var burns := on_fire or _soot > 0.0
	if burns:
		_put_out()
		_soot = 0.0
		_heat = 0.0
		if _waterline:
			_waterline.set_shader_parameter("burnt", 0.0)
		if not said and not zombie:
			Game.say("¡Se curó!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SHOP)
	var cured := flu_cured or spore_cured or burns
	if cured and not zombie:
		_thank(FAITH_CURED, true)
	return cured

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
	Game.say("¡Achís!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_TEXT)
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
	Game.say("¡Se curó!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SHOP)

## Le sube el hambre; con hambre lo dice cada tanto, y con la panza vacía aguanta un rato
## (parado en la isla, como con la gripe) y se muere.
func _update_hunger(dt: float) -> void:
	if not is_alive() or is_zombie():
		return   # (El zombi no tiene hambre: lo alimenta el hongo)
	hunger = minf(100.0, hunger + HUNGER_RATE * dt)
	if hunger < 100.0:
		_starve_t = 0.0
	elif (is_idle() or asleep) and not on_fire:
		_starve_t += dt
		if _starve_t >= STARVE_TIME:
			_die_of_hunger()
			return
	if hunger >= HUNGRY_AT and food == null:
		_hungry_say -= dt * (2.0 if starving() else 1.0)
		if _hungry_say <= 0.0:
			_hungry_say = randf_range(HUNGRY_SAY_EVERY.x, HUNGRY_SAY_EVERY.y)
			if chat_with == null and bubble_t <= 0.0 and is_idle():
				say(Bubble.HUNGRY, 1.6, false)

func _die_of_hunger() -> void:
	Game.say("Murió de hambre", get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_WARN)
	if food:
		food.release_eater()
	_gentle_death = true
	_die()
	swing_vel = (1.0 if randf() < 0.5 else -1.0) * randf_range(2.5, 4.0)   # Se cae para un costado
	corpse_vel = Vector2.ZERO

## No aguantó: se desploma donde está (cuenta como sacrificio, como cualquier muerte).
func _die_of_flu() -> void:
	Game.say("Murió de gripe", get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_WARN)
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

# --- ESPORA ---
## En qué etapa de la espora está (ver Infection).
func infection() -> Infection:
	if spore <= 0.0:
		return Infection.NONE
	if spore < SPORE_SPREAD_AT:
		return Infection.INCUBATING
	if spore < SPORE_ZOMBIE_AT:
		return Infection.SPREADING
	return Infection.ZOMBIE

## Ya se le nota la espora: le crecen hongos, tose y no reza (el zombi también).
func spore_shows() -> bool:
	return spore >= SPORE_SPREAD_AT and not dead

## El hongo lo domina: es un zombi.
func is_zombie() -> bool:
	return spore >= SPORE_ZOMBIE_AT and not dead

## Lo que se le ve de la espora, 0..1 (ver waterline.gdshader y VillagerRig.Fungus).
func spore_look() -> float:
	return _spore_fx

## Qué tan zombi se lo ve, 0..1: los brazos estirados y la cabeza caída (ver VillagerRig).
func zombie_look() -> float:
	if dead:
		return 0.0
	return smoothstep(SPORE_ZOMBIE_AT - 0.04, SPORE_ZOMBIE_AT + 0.02, _spore_fx)

## Brotando: lo que ya le creció el tallo de la cabeza, 0..1.
func bloom_amount() -> float:
	return _bloom

## Ya le reventó el tallo (ver _burst).
func bloom_burst() -> bool:
	return _spore_burst

## La boca del zombi: entreabierta, y gimiendo se abre más (ver VillagerRig).
func zombie_mouth() -> float:
	if _groaning <= 0.0:
		return 0.3
	return 0.3 + 0.6 * sin((1.0 - _groaning / GROAN_TIME) * PI)

## Se le metió la espora (el poder, una mordida, una tos o la nube de un brote). Al que ya la
## tenía, dose lo apura. Adentro de su choza no le llega, ni con el escudo o vacunado.
func catch_spore(dose := 0.0) -> void:
	if not is_alive() or inside:
		return
	if protected_from_disease():
		_ward_off()
		return
	if spore > 0.0:
		spore = minf(1.0, spore + dose)
		return
	spore = SPORE_START
	_spore_rate = 1.0 / randf_range(SPORE_TIME.x, SPORE_TIME.y)
	_cough_t = randf_range(SPORE_COUGH_EVERY.x, SPORE_COUGH_EVERY.y)

## Para cargar la partida: cuánto lo dominaba el hongo (se le ve tal cual, sin avisar nada).
func set_spore(value: float) -> void:
	_clear_spore()
	if value <= 0.0:
		return
	catch_spore()
	spore = minf(value, 1.0)
	_spore_fx = spore
	_spore_seen = infection()
	_update_spore_look()

## Ya no tiene la espora (lo curaste): las manchas y los hongos se le van de a poco.
func _clear_spore() -> void:
	spore = 0.0
	_bloom = 0.0
	_spore_burst = false
	_spore_seen = Infection.NONE
	_prey = null
	_bite_t = 0.0

## La espora avanza (también durmiendo o adentro de su choza). Con hongos tose; zombi gime, y al
## final, parado en la isla, le brota el tallo de la cabeza y revienta.
func _update_spore(dt: float) -> void:
	_bite_cool = maxf(0.0, _bite_cool - dt)
	if spore > 0.0 and is_alive():
		spore = minf(1.0, spore + _spore_rate * dt)
		var stage := infection()
		if stage != _spore_seen:
			_spore_turned(stage)
		match stage:
			Infection.SPREADING:
				_cough_t -= dt
				if _cough_t <= 0.0:
					_cough_t = randf_range(SPORE_COUGH_EVERY.x, SPORE_COUGH_EVERY.y)
					if is_idle() and not on_fire:
						_cough()
			Infection.ZOMBIE:
				_groan_t -= dt
				if _groan_t <= 0.0:
					_groan_t = randf_range(GROAN_EVERY.x, GROAN_EVERY.y)
					if visible:
						_groan()
				# Brota parado en la isla (no colgando del mouse, volando, flotando ni en el altar)
				if spore >= 1.0 and is_idle() and not on_fire:
					_bloom = minf(1.0, _bloom + dt / SPORE_BLOOM_TIME)
					if _bloom >= 1.0:
						_burst()
	_update_spore_look(dt)

## Las manchas de hongo (ver waterline.gdshader) siguen a la espora de a poco.
func _update_spore_look(dt := 0.0) -> void:
	if spore <= 0.0 and _spore_fx <= 0.0:
		return
	_spore_fx = move_toward(_spore_fx, spore, SPORE_LOOK * dt)
	if _waterline:
		_waterline.set_shader_parameter("spore", _spore_fx)

## Pasó a otra etapa de la espora: se le empieza a notar (le salen hongos) o se hizo zombi.
func _spore_turned(stage: Infection) -> void:
	_spore_seen = stage
	match stage:
		Infection.SPREADING:
			_cough_t = randf_range(SPORE_COUGH_EVERY.x, SPORE_COUGH_EVERY.y) * 0.5
			if visible:
				Game.say("¡Le salen hongos!", get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_SPORE)
		Infection.ZOMBIE:
			# Deja todo lo que estaba haciendo (y si estaba adentro de su choza, sale)
			wake_up()
			if inside:
				_leave_home()
			if chat_with:
				_end_chat()
			if food:
				food.release_eater()
			_going_home = false
			_resting = false
			_prey = null
			_groan_t = randf_range(0.2, 0.8)
			Game.say("¡Se hizo zombi!", get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_WARN)
			# Los que lo ven se asustan y se quedan mirando
			var at := body_center()
			for node in get_tree().get_nodes_in_group("villager"):
				var o := node as Villager
				if o and o != self and o.is_alive() and not o.is_zombie():
					var seen := o._witness(at)
					if seen > 0.0:
						o.add_fear(FEAR_DEATH * 0.6 * seen)
						o.scare(WITNESS_STARE, at)

## ¡Cof! Tose una nubecita de esporas para adelante: contagia a los que tiene enfrente.
func _cough() -> void:
	var facing := rig.facing() if rig else 1.0
	var mouth := to_global(Vector2(7.0 * facing, -24.0))
	if rig:
		rig.hit(mouth, Vector2(facing, 0.6), 0.3)
		rig.sneeze()
	_spawn_spores(mouth, Vector2(facing, -0.1), 14, 0.6)
	if _cough_sound == null:
		_cough_sound = _make_cough()
	_play_sfx(_cough_sound, VOICE_DB - 5.0, _voice_pitch * randf_range(0.9, 1.05))
	Game.say("¡Cof!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SPORE)
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == self or o.spore > 0.0 or not (o.is_idle() or o.asleep):
			continue
		var d := o.global_position - global_position
		if d.length() < SPORE_COUGH_REACH and (d.length() < SEPARATION_RADIUS or d.normalized().x * facing > SNEEZE_CONE) \
				and randf() < SPORE_COUGH_CATCH:
			o.catch_spore()

## "Uuurgh": el zombi gime (con la boca abierta, ver zombie_mouth).
func _groan() -> void:
	if _groan_sound == null:
		_groan_sound = _make_groan()
	_play_sfx(_groan_sound, VOICE_DB - 6.0, _voice_pitch * randf_range(0.85, 1.0))
	_groaning = GROAN_TIME

## Zombi: arrastrando los pies, busca al sano más cerca y lo persigue; ya encima se le tira y lo
## muerde. Brotando se queda duro donde está. true si ya se encargó de moverlo (quieto); false si
## camina para donde dice dir (ver _physics_process).
func _zombie_ai(dt: float) -> bool:
	if spore >= 1.0 or _bloom > 0.0:
		_prey = null
		_hold_still()
		return true
	if _bite_t > 0.0:
		_bite_t -= dt
		if _has_prey():
			_stand_facing(_prey)
		else:
			_hold_still()
		return true
	_prey_seek -= dt
	if not _has_prey():
		_prey = null
	if _prey_seek <= 0.0:
		_prey_seek = ZOMBIE_SEEK_EVERY
		_prey = _find_prey()
	if _prey == null:
		return false   # Nadie cerca: deambula
	var to := _prey.global_position - global_position
	if to.length() <= BITE_REACH:
		if _bite_cool <= 0.0:
			_bite(_prey)
		else:
			_stand_facing(_prey)
		return true
	dir = to.normalized()
	_update_sprite_flip()
	_resting = false
	wander_timer = maxf(wander_timer, 1.0)   # Que el paseo no le cambie el rumbo
	return false

## Veces speed del zombi: arrastra los pies, persiguiendo a alguien va más rápido y ya encima se
## le tira.
func _zombie_pace() -> float:
	if not _has_prey():
		return ZOMBIE_SPEED
	if _prey.global_position.distance_to(global_position) < ZOMBIE_LUNGE_AT:
		return ZOMBIE_LUNGE
	return ZOMBIE_CHASE

## Si o es alguien a quien morder: vivo, sin la espora ni el escudo, en la isla (despierto o
## durmiendo en el piso; no adentro de su choza) y no muy lejos.
func _prey_ok(o: Villager) -> bool:
	return is_instance_valid(o) and o != self and not o.is_queued_for_deletion() and o.spore <= 0.0 \
			and not o.dead and not o.shielded() and (o.is_idle() or o.asleep) \
			and o.global_position.distance_to(global_position) < ZOMBIE_SEEK * 1.3

## Sigue teniendo a quién perseguir (no se lo comió el tiburón, no se curó...).
func _has_prey() -> bool:
	return is_instance_valid(_prey) and _prey_ok(_prey)

## El más cerca para morder (o null).
func _find_prey() -> Villager:
	var best: Villager = null
	var best_d := ZOMBIE_SEEK
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or not _prey_ok(o):
			continue
		var d := o.global_position.distance_to(global_position)
		if d < best_d:
			best = o
			best_d = d
	return best

## Se le tira encima y lo muerde.
func _bite(o: Villager) -> void:
	_bite_cool = BITE_COOLDOWN
	_bite_t = BITE_TIME
	if rig:
		rig.set_facing_left(o.global_position.x < global_position.x)
		rig.lunge()
	if _bite_sound == null:
		_bite_sound = _make_bite()
	_play_sfx(_bite_sound, VOICE_DB - 2.0, randf_range(0.9, 1.1))
	o.get_bitten(self)

## Lo mordió un zombi: grita, sangra, sale empujado (capaz que se cae de la isla) y corriendo, y
## se le metió la espora. Con el escudo no le pasa nada (y el zombi rebota).
func get_bitten(z: Villager) -> void:
	if shielded():
		_ward_off(true)
		z.get_shoved(Vector2.ZERO, Vector2(signf(z.global_position.x - global_position.x), 0.0) * BITE_SHOVE)
		return
	wake_up()
	if chat_with:
		_end_chat()
	if food:
		food.release_eater()
	_going_home = false
	var push := Vector2(1.0 if global_position.x >= z.global_position.x else -1.0, 0.0)
	_spawn_blood(body_center() + Vector2(-push.x * 6.0, -14.0), push + Vector2.UP * 0.5, 12)
	if rig:
		rig.hit(body_center(), push, 0.9)
	_voice.pitch_scale = _voice_pitch * randf_range(1.05, 1.2)
	_voice.play()
	get_shoved(Vector2.ZERO, push * BITE_SHOVE)
	_scram = SCRAM_TIME * 2.0
	dir = (push + (island_center - global_position).normalized() * 0.5).normalized()
	_update_sprite_flip()
	_resting = false
	wander_timer = maxf(wander_timer, _scram)
	add_fear(FEAR_THROW)
	add_faith(-FAITH_BITTEN)
	add_mood(MOOD_BITTEN, "La mordió un zombi" if gender == Gender.FEMALE else "Lo mordió un zombi")
	Game.say("¡Mordida!", get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_WARN)
	catch_spore()

## Con un zombi cerca se asusta y sale corriendo para el otro lado (y un poco para el medio de la
## isla, así no lo arrincona contra la orilla). A veces, al verlo, primero se queda duro del susto.
func _avoid_zombies(dt: float) -> void:
	if on_fire or shielded():
		return   # (Con el escudo, ni se asusta: no lo pueden morder)
	_dread_check -= dt
	if _dread_check > 0.0:
		return
	_dread_check = DREAD_CHECK
	var near: Villager = null
	var best := ZOMBIE_DREAD
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != self and o.is_zombie() and o.is_idle():
			var d := o.global_position.distance_to(global_position)
			if d < best:
				best = d
				near = o
	if near == null:
		_dread_seen = false
		return
	add_fear(FEAR_ZOMBIE * DREAD_CHECK)
	if is_scared():
		return   # Duro del susto, mirándolo con la boca abierta
	if not _dread_seen:
		_dread_seen = true
		if randf() < DREAD_FREEZE_CHANCE:
			scare(DREAD_FREEZE, near.body_center())
			if food:
				food.release_eater()
			if chat_with:
				_end_chat()
			return
	_scram = maxf(_scram, SCRAM_TIME)
	var away := (global_position - near.global_position).normalized()
	dir = (away + (island_center - global_position).normalized() * 0.35).normalized()
	_update_sprite_flip()
	_resting = false
	wander_timer = maxf(wander_timer, SCRAM_TIME)
	if food:
		food.release_eater()
	if chat_with:
		_end_chat()

## Le revienta el tallo de la cabeza: suelta una nube de esporas que contagia a los que están
## cerca (y a los que ya la tenían los apura), la nube queda flotando un rato (ver Spore.Cloud) y
## se muere.
func _burst() -> void:
	_spore_burst = true
	var tip := rig.bloom_tip() if rig else body_center() + Vector2(0, -40)
	var feet := ground_point()
	_spawn_spores(tip, Vector2.UP, 70, 1.6)
	if _burst_sound == null:
		_burst_sound = _make_burst()
	_play_sfx(_burst_sound, VOICE_DB, randf_range(0.9, 1.1))
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != self and not o.dead and Spore.reaches(o, feet, BURST_RADIUS):
			o.catch_spore(SPORE_DOSE * 0.5)
	Spore.release_cloud(get_tree(), feet, BURST_RADIUS * 0.8)
	Game.say("La consumió la espora" if gender == Gender.FEMALE else "Lo consumió la espora",
			get_global_transform_with_canvas().origin + Vector2(0, -90), HUD.C_SPORE)
	if food:
		food.release_eater()
	_die()
	swing_vel = (1.0 if randf() < 0.5 else -1.0) * randf_range(2.0, 3.0)   # Se cae para un costado
	corpse_vel = Vector2.ZERO

## Esporas que salen de at para el lado de toward (la tos, el brote).
func _spawn_spores(at: Vector2, toward: Vector2, amount: int, power: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = 0.6 + 0.5 * power
	p.direction = toward
	p.spread = 30.0 if power < 1.0 else 80.0
	p.initial_velocity_min = 30.0 * power
	p.initial_velocity_max = 95.0 * power
	p.damping_min = 25.0
	p.damping_max = 50.0
	p.gravity = Vector2(0, 12)
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.2 + 1.2 * power
	p.color_ramp = _fade_ramp(Color(1.0, 0.76, 0.36, 0.95), Color(0.85, 0.58, 0.28, 0.0))
	p.z_index = 15
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

## Un sonido suelto (se borra solo al terminar).
func _play_sfx(stream: AudioStream, db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## "Uuurgh": una vocal grave y ronca que baja.
static func _make_groan() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * GROAN_TIME)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(125.0, 80.0, k) * (1.0 + 0.03 * sin(k * 40.0)) / rate
		var saw := 0.0
		for h in range(1, 7):
			saw += sin(ph * h) / h
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.15)   # Aire
		var growl := 0.6 + 0.4 * sin(TAU * 28.0 * i / rate)   # Ronco
		var env := minf(1.0, k * 6.0) * pow(1.0 - k, 0.8)
		buf[i] = (saw * 0.4 * growl + lp * 0.5) * env
	return Synth.wav(buf, rate, 0.8)

## Mordida: un golpe sordo y un crujido.
static func _make_bite() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.22)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var prev := 0.0
	var hp := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(160.0, 60.0, k) / rate
		var noise := randf_range(-1.0, 1.0)
		hp = 0.7 * (hp + noise - prev)   # Pasa-altos: el crujido
		prev = noise
		var crunch := hp * (0.5 + 0.5 * signf(sin(k * 90.0)))   # A golpecitos
		buf[i] = (sin(ph) * 0.9 * pow(1.0 - k, 3.0) + crunch * 0.6 * pow(1.0 - k, 1.5)) * minf(1.0, k * 60.0)
	return Synth.wav(buf, rate, 0.9)

## "¡Cof, cof!": dos soplidos roncos.
static func _make_cough() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.42)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var k := fmod(t, 0.2) / 0.2   # Cada "cof" dura 0.2 s
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		ph += TAU * 170.0 / rate
		var loud := 1.0 if t < 0.2 else (0.7 if t < 0.4 else 0.0)
		var env := minf(1.0, k * 30.0) * pow(1.0 - k, 2.5) * loud
		buf[i] = (lp * 0.9 + sin(ph) * 0.3) * env
	return Synth.wav(buf, rate, 0.9)

## El tallo que revienta: un "¡pfuum!" sordo que se va apagando.
static func _make_burst() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.9)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), lerpf(0.4, 0.05, k))   # Lo agudo se apaga primero
		ph += TAU * lerpf(140.0, 45.0, sqrt(k)) / rate
		var env := minf(1.0, k * 80.0) * pow(1.0 - k, 2.0)
		buf[i] = (lp * 1.6 + sin(ph) * 0.8 * pow(1.0 - k, 4.0)) * env
	return Synth.wav(buf, rate, 0.9)

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
		_thank(FAITH_SHIELDED, false)

## Lo vacunaste (ver Miracle): no se contagia de gripe ni de espora por un tiempo (time, en
## segundos). thank: te lo agradece.
func vaccinate(time := VACCINE_TIME, thank := true) -> void:
	vaccine_t = maxf(vaccine_t, time)
	if thank:
		Game.say("¡Vacunada!" if gender == Gender.FEMALE else "¡Vacunado!",
				get_global_transform_with_canvas().origin + Vector2(0, -80), Miracle.C_TEAL)
		_thank(FAITH_VACCINATED, false)

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
	if zap_state != Zap.NONE:
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
		_put_out()
	var at := Vector2(global_position.x, floor_y)
	for node in get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != self and o.is_alive() and o._witness(at) > 0.0:
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
	if flu == Flu.INCUBATING or flu == Flu.SICK:
		flu = Flu.IMMUNE
		flu_t = IMMUNE_TIME
	_flu_tint = 0.0
	_clear_spore()
	_spore_fx = 0.0
	hunger = minf(hunger, RISEN_HUNGER)
	_starve_t = 0.0
	_soot = 0.0
	_heat = 0.0
	if _waterline:
		for param: String in ["burnt", "embers", "sick", "spore"]:
			_waterline.set_shader_parameter(param, 0.0)
	if rig:
		rig.set_alive()
	if food:
		food.release_eater()
	if chat_with:
		_end_chat()
	_going_home = false
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
	say(Bubble.HEART, THANKS_TIME, false)
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
		var heretic := o.creed() == Creed.HERETIC
		var seen := o._witness(at)
		var family := id == partner or id in parents or id_number in o.parents \
				or parents.any(func(p: int) -> bool: return p in o.parents)
		if family:
			o.add_faith(FAITH_RISEN_FAMILY)
			o.add_mood(MOOD_RISEN_FAMILY, "Resucitaste a alguien de su familia")
			o.say(Bubble.HEART, THANKS_TIME * 1.5, false)
		elif friends.has(id):
			o.add_faith(FAITH_RISEN_FRIEND)
			o.add_mood(MOOD_RISEN_FRIEND, "Resucitaste a un amigo")
			o.say(Bubble.HEART, THANKS_TIME, false)
		elif seen > 0.0 and not heretic:
			o.add_faith(FAITH_RISEN_SEEN * seen)
		if heretic:
			o.add_fear(FEAR_RISEN_HERETIC * seen if seen > 0.0 else FEAR_RISEN_HEARD)
			if seen > 0.0:
				o.scare(WITNESS_STARE, at)

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
	_update_spore(dt)
	_update_hunger(dt)
	_update_family(dt)
	_update_faith(dt)
	_update_mood(dt)
	_update_sleep(dt)
	_update_wards(dt)
	_update_waterline()
	_scared = maxf(0.0, _scared - dt)
	_tornado_cool = maxf(0.0, _tornado_cool - dt)
	_chat_cool = maxf(0.0, _chat_cool - dt)
	_talking = maxf(0.0, _talking - dt)
	_groaning = maxf(0.0, _groaning - dt)
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
		add_mood(MOOD_WOKEN, "La despertaste" if gender == Gender.FEMALE else "Lo despertaste")
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
	if is_zombie():
		_groan()   # No grita: gime
	elif not dead:
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
			add_fear(FEAR_THROW)
			add_mood(MOOD_THROWN, "La revoleaste" if gender == Gender.FEMALE else "Lo revoleaste")
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
			_thank(FAITH_RESCUED, false)   # Lo rescataste
