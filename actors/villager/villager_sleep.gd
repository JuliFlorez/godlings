extends RefCounted
class_name VillagerSleep
## El sueño: el cansancio (0 descansado, 100 muerto de sueño) le va subiendo despierto y se le va
## pasando durmiendo. De noche se va a dormir: a su choza si tiene, y si no se acuesta en el piso
## donde esté (y se levanta de peor ánimo). Con sueño camina más lento, bosteza y anda de peor
## ánimo; muerto de sueño se va a dormir la siesta aunque sea de día (a su choza, o donde esté).
## Descansando de día en su choza también se le pasa un poco. Se despierta cuando aclara (o cuando
## descansó, si era una siesta), si le agarra hambre de verdad, si viene el agua, si se asusta o si
## lo agarrás. Dormido no charla ni reza. Se ve en el carnet y se guarda.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (asleep, tiredness, wake_up...).

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
var napping := false              # Durmiendo la siesta (de día)
var slept_inside := false         # Pasó la noche en su choza (al salir, durmió bien)
var _sleep_k := 0.0               # Acostándose: 0 parado, 1 acostado
var sleep_drop := 0.0             # Lo que bajó para quedar acostado
var _lie_side := 1.0              # Para qué lado se acuesta
var _yawn := 0.0

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	tiredness = randf_range(TIRED_START.x, TIRED_START.y)
	_yawn = randf_range(YAWN_EVERY.x, YAWN_EVERY.y)

## Durmiendo: acostado en el piso, o en su choza de noche (o durmiendo la siesta).
func is_sleeping() -> bool:
	return asleep or (v.inside and (v._night() >= VillagerHome.SLEEP_AT or napping))

## Ya descansó: de la noche (hasta SLEEPY_AT) o de la siesta, que dura más (hasta NAP_UNTIL).
func rested() -> bool:
	return tiredness <= (NAP_UNTIL if napping else SLEEPY_AT)

## Se acuesta en el piso y se duerme.
func fall_asleep() -> void:
	asleep = true
	_sleep_k = 0.0
	sleep_drop = 0.0
	_lie_side = -1.0 if randf() < 0.5 else 1.0
	v.velocity = Vector2.ZERO
	v._resting = false

## Se despierta y, si estaba acostado en el piso, se levanta. stand: false si lo agarraron o se
## lo llevó algo (ahí ya no está acostado donde estaba).
func wake_up(stand := true) -> void:
	if not asleep:
		return
	asleep = false
	napping = false
	if stand:
		v.global_position.y -= sleep_drop
		v._pick_dir()
		v.wander_timer = randf_range(1.0, 2.5)
	sleep_drop = 0.0
	_sleep_k = 0.0
	if v.bubble == Villager.Bubble.SLEEP:
		v.bubble_t = 0.0

## Salió de su choza (ver VillagerHome.leave_home): se terminó la siesta o la noche adentro.
func left_home() -> void:
	napping = false
	slept_inside = false

## El cansancio sube despierto y baja durmiendo (o descansando en su choza). Con sueño bosteza.
func update(dt: float) -> void:
	if not v.is_alive() or v.is_zombie():
		return   # (El zombi no se cansa)
	if is_sleeping():
		tiredness -= SLEEP_RECOVER * dt
		slept_inside = slept_inside or v.inside
	elif v.inside:
		tiredness -= REST_RECOVER * dt
	else:
		tiredness += TIRED_RATE * (Villager.ELDER_TIRED if v.is_elder() else 1.0) * dt
	tiredness = clampf(tiredness, 0.0, 100.0)
	if tiredness < SLEEPY_AT or is_sleeping():
		return
	_yawn -= dt
	if _yawn <= 0.0:
		_yawn = randf_range(YAWN_EVERY.x, YAWN_EVERY.y)
		if v.chat_with == null and v.bubble_t <= 0.0 and v.is_idle():
			v.say(Villager.Bubble.SLEEP, 1.4, false)

## De noche, el que no tiene casa se acuesta donde está; de día, muerto de sueño se va a su
## choza a dormir la siesta (o, si no tiene, se duerme donde está). true si se durmió.
func seek_sleep() -> bool:
	if not _can_sleep():
		return false
	if v._night() >= VillagerHome.SLEEP_AT:
		if v.has_home() and v.can_go_home():
			return false   # Se va a su choza (ver _seek_home)
		napping = tiredness >= EXHAUSTED_AT   # Muerto de sueño: aunque tenga hambre, duerme hasta descansar
		fall_asleep()
		return true
	if tiredness < EXHAUSTED_AT:
		return false
	napping = true
	if v.can_go_home():
		v.go_home()
		return false
	fall_asleep()
	return true

## Durmiendo en el piso: se acuesta de a poco y le salen unas zetas. Se despierta cuando aclara
## (o, si era una siesta, cuando descansó), si le agarra hambre de verdad (en la siesta, solo si
## se muere de hambre), si se prende fuego o si se le viene el agua.
func sleep_ai(dt: float) -> void:
	v.velocity = Vector2.ZERO
	_sleep_k = move_toward(_sleep_k, 1.0, LIE_DOWN * dt)
	v.rotation = lerp_angle(0.0, _lie_side * PI * 0.5, _sleep_k)
	var drop := Villager.FEET_DROP * v.scale.y * _sleep_k
	v.global_position.y += drop - sleep_drop
	sleep_drop = drop
	if v.bubble_t <= 0.0:
		v.say(Villager.Bubble.SLEEP, 2.0, false)
	var day := v._night() < VillagerHome.WAKE_AT
	var hungry := v.starving() or (v.hunger >= VillagerHunger.HUNGRY_AT and not napping)
	if hungry or v.on_fire or Storm.water_near(v.ground_point(), Villager.FLOOD_FLEE) \
			or (day and rested()):
		if day and not napping:
			v.add_mood(MOOD_SLEPT_ROUGH, "Durmió en el piso")
		wake_up()

## Se puede quedar dormido: tranquilo en la isla, sin nada que hacer y sin hambre de verdad
## (muerto de sueño, aunque tenga hambre; muerto de hambre, nunca).
func _can_sleep() -> bool:
	return v.is_idle() and v.chat_with == null and v.food == null and not v.on_fire and v._flee <= 0.0 \
			and v._scram <= 0.0 and not v.is_scared() and v.pose == VillagerFaith.Pose.NONE and not v.starving() \
			and (v.hunger < VillagerHunger.HUNGRY_AT or tiredness >= EXHAUSTED_AT) and not v.is_zombie() \
			and not v.going_home and not Storm.water_near(v.ground_point(), Villager.FLOOD_FLEE)
