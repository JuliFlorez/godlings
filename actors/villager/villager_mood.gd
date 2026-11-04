extends RefCounted
class_name VillagerMood
## El ánimo: qué tan contento está, de 0 (deprimido) a 100 (feliz). Se va acercando de a poco a lo
## que le toca por cómo está su vida (ver _mood_factors: su pareja, sus amigos y enemigos, sus hijos,
## su casa, el hambre, el sueño, la gripe, la espora y el miedo), y lo que le pasa lo sube o lo baja
## de golpe (ver add_mood) y después se le va pasando: que se le muera la pareja, un hijo o un amigo
## lo hunde y que se muera un enemigo lo alegra; las charlas, enamorarse o separarse, pelearse,
## tener un bebé, comer o que le hagas un milagro también cuentan (ver relation_mood y
## Villager._mourn). Contento charla mejor (ver Relations.chat_delta), reza más, sonríe y a veces
## canta; triste charla peor, se pelea más, camina más lento, descansa y se mete en su casa más
## seguido, no tiene bebés y, si está deprimido, a veces llora. Se ve en el carnet (con por qué
## está así) y se guarda con la partida.
## Las constantes MOOD_* de acá dicen cuánto pesa cada cosa, y las usan también los que le cambian el
## ánimo (el aldeano, la comida del cielo, el fuego); las del sueño, la espora y el altar están con
## lo suyo.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (mood, add_mood, mood_level...).

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

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	mood = randf_range(MOOD_START.x, MOOD_START.y)
	_mood_goal = mood
	_mood_say = randf_range(MOOD_SAY_EVERY.x, MOOD_SAY_EVERY.y)
	_mood_check = randf_range(0.0, MOOD_CHECK)

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
		var amount: float = f[1]
		if (amount < 0.0) == sad and absf(amount) > absf(best_v):
			best = f[0]
			best_v = amount
	return best

## Le pasó algo que lo pone más contento (o más triste). why: lo que dice el carnet de por qué
## está así (ver mood_reason), si fue fuerte.
func add_mood(amount: float, why := "") -> void:
	if not v.is_alive():
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

## Se va acercando a lo que le toca (lo que le pasó se le va pasando). Feliz, a veces canta;
## deprimido, a veces llora.
func update(dt: float) -> void:
	if not v.is_alive() or v.is_zombie():
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
	mood = move_toward(mood, _mood_goal, MOOD_DRIFT * (MOOD_DRIFT_HOME if v.inside else 1.0) * dt)
	_mood_say -= dt
	if _mood_say > 0.0:
		return
	_mood_say = randf_range(MOOD_SAY_EVERY.x, MOOD_SAY_EVERY.y)
	if v.is_idle() and v.chat_with == null and v.food == null and v.bubble_t <= 0.0 and not v.on_fire:
		match mood_level():
			Mood.HAPPY:
				v.say([Villager.Bubble.MUSIC, Villager.Bubble.SUN].pick_random(), 1.4, false)
			Mood.DEPRESSED:
				v.say(Villager.Bubble.TEAR, 1.8, false)

## Lo que le toca por cómo está su vida: [[por qué, cuánto], ...] (ver MOOD_BASE).
func _mood_factors() -> Array:
	var out := []
	var bonds := Relations.counts(v)
	if bonds[Relations.Kind.COUPLE] > 0:
		out.append(["Tiene pareja", MOOD_PARTNER])
	if bonds[Relations.Kind.FRIEND] > 0:
		out.append(["Tiene amigos", minf(bonds[Relations.Kind.FRIEND] * MOOD_FRIEND, MOOD_FRIENDS_MAX)])
	if bonds[Relations.Kind.ENEMY] > 0:
		out.append(["Tiene enemigos", maxf(bonds[Relations.Kind.ENEMY] * MOOD_ENEMY, MOOD_ENEMIES_MAX)])
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and v.id_number in o.parents and o.is_alive():
			out.append(["Tiene hijos", MOOD_KIDS])
			break
	if v._home_ok():
		out.append(["Tiene casa", MOOD_HOME])
	elif v.get_tree().has_group("hut"):
		out.append(["No tiene casa", MOOD_HOMELESS])
	if v.starving():
		out.append(["Se muere de hambre", MOOD_STARVING])
	elif v.hunger >= VillagerHunger.HUNGRY_AT:
		out.append(["Tiene hambre", MOOD_HUNGRY])
	if v.flu == VillagerFlu.Stage.SICK:
		out.append(["Tiene gripe", MOOD_SICK])
	if v.spore_shows():
		out.append(["Le crecen hongos", VillagerSpore.MOOD_SPORE])
	if v.fear > MOOD_FEAR_FROM:
		out.append(["Tiene miedo", (v.fear - MOOD_FEAR_FROM) * MOOD_FEAR])
	if v.tiredness >= VillagerSleep.EXHAUSTED_AT:
		out.append(["Se cae de sueño", VillagerSleep.MOOD_EXHAUSTED])
	elif v.tiredness >= VillagerSleep.SLEEPY_AT:
		out.append(["Tiene sueño", VillagerSleep.MOOD_SLEEPY])
	return out
