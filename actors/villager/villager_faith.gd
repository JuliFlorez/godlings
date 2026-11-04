extends RefCounted
class_name VillagerFaith
## La fe y el miedo: cuánto creen en vos (el dios de la isla) y cuánto te temen, de 0 a 100. Con eso
## son devotos, fanáticos, herejes o aterrados (ver creed). La fe sube con los milagros (curarlos,
## rescatarlos del agua, o ver que curaste a otro) y baja de a poco si no hacés nada por ellos, y de
## golpe si se les muere la pareja o un amigo. El miedo sube con lo que ven: alguien que se muere
## cerca (más si lo querían), que los agarres o los revolees, el sol o la luna perturbados; y se les
## va pasando (charlando, más rápido). Si pasás el mouse cerca, el devoto se arrodilla y te reza, el
## fanático también pero temblando, el aterrado sale corriendo y el hereje ni te mira; con un arma
## afuera, los que te temen se agachan. Rezando dejan ofrendas según la fe y el miedo, y la fe
## recarga la devoción (ver World). Se ve en el carnet y se guarda con la partida.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (faith, fear, creed, add_faith...).

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
const TRIBUTE_PAR := 110.0              # Fe más miedo que hacen 1 ofrenda por rezo
var faith := 60.0
var fear := 0.0
var pose := Pose.NONE                   # Lo que está haciendo por vos (ver VillagerRig)
var _worship := 0.0                     # Viendo un ritual en el altar: lo que le queda de rodillas...
var _worship_at := Vector2.ZERO         # ...rezando para ahí (ver worship)

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	faith = randf_range(FAITH_START.x, FAITH_START.y)   # Las partidas guardadas traen la suya
	fear = randf_range(FEAR_START.x, FEAR_START.y)

## Para la partida guardada (ver Villager.to_dict).
func to_dict() -> Dictionary:
	return {"faith": faith, "fear": fear}

func from_dict(d: Dictionary) -> void:
	faith = d.get("faith", faith)
	fear = d.get("fear", fear)

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
	return (faith + fear) / TRIBUTE_PAR * lerpf(VillagerMood.MOOD_TRIBUTE.x, VillagerMood.MOOD_TRIBUTE.y, v.mood / 100.0)

## Si te reza (y deja ofrendas, ver World._prayers).
func prays() -> bool:
	return prayer_block() == ""

## Por qué no te reza ahora ("" si reza): se murió, se está ahogando, es un zombi, le crecen
## hongos, tiene gripe, se muere de hambre o está durmiendo (se ve en el carnet).
func prayer_block() -> String:
	if not v.is_alive():
		return "Muerto"
	if v.drowning:
		return "Se está ahogando"
	if v.is_zombie():
		return "Es un zombi"
	if v.spore_shows():
		return "Le crecen hongos"
	if v.is_sick():
		return "Tiene gripe"
	if v.starving():
		return "Se muere de hambre"
	if v.is_sleeping():
		return "Está durmiendo"
	return ""

## Cuánto le afecta algo que pasó en at: 1 bien de cerca, nada si no lo vio.
func witness(at: Vector2) -> float:
	if v.inside:
		return 0.0   # Adentro de su choza no ve nada
	var d := v.body_center().distance_to(at)
	return 0.0 if d > WITNESS_RADIUS else lerpf(1.0, 0.4, d / WITNESS_RADIUS)

## Le hiciste un milagro (lo curaste o lo rescataste): te cree más y te lo agradece. Los que
## lo vieron (si lo curaste) también te creen un poco más.
func thank(amount: float, seen_by_others: bool) -> void:
	add_faith(amount)
	v.add_mood(VillagerMood.MOOD_MIRACLE, "Le hiciste un milagro")
	v.say(Villager.Bubble.HEART, THANKS_TIME, false)
	if not seen_by_others:
		return
	var at := v.body_center()
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != v and o.is_alive():
			o.add_faith(FAITH_MIRACLE * o.witness(at))

## Ve un ritual en el altar (ver Villager.witness_ritual): se queda de rodillas un rato, rezando
## para ese lado.
func worship(time: float, at: Vector2) -> void:
	_worship = time
	_worship_at = at

## La fe se le va gastando y el miedo se le va pasando (o crece, con el cielo perturbado). Si
## tu mano anda cerca reacciona según lo que cree: reza (pose), se escapa (Villager._scram) o
## nada; y si sacaste un arma, el que te teme se agacha.
func update(dt: float) -> void:
	pose = Pose.NONE
	if not v.is_alive() or v.is_zombie():
		return   # (El zombi ya no cree en nada ni le tiene miedo a nada)
	add_faith(-(FAITH_DRIFT + (VillagerHunger.FAITH_DRIFT_STARVING if v.starving() else 0.0)) * dt)
	add_fear(-FEAR_FADE * (FEAR_FADE_CHAT if v.chat_with else 1.0) * dt)
	if _creepy_sky():
		add_fear(FEAR_CREEPY * dt)
	if _worship > 0.0:
		# Viendo un ritual en el altar: de rodillas, rezando para ese lado
		_worship -= dt
		if v.is_idle() and not v.on_fire:
			pose = Pose.PRAY
			if v.rig:
				v.rig.set_facing_left(_worship_at.x < v.global_position.x)
		return
	v._ensure_hud()
	if v.hud == null or not v.hud.visible or not v.is_idle() or v.on_fire or v._flee > 0.0:
		return
	var hand := v.get_global_mouse_position()
	var near := v.body_center().distance_to(hand) < HAND_NEAR
	var c := creed()
	if near and c == Creed.TERRIFIED:
		# Sale corriendo para el otro lado (aunque estuviera comiendo)
		v._scram = Villager.SCRAM_TIME
		v.dir = (v.global_position - hand).normalized()
		v._update_sprite_flip()
		v._resting = false
		if v.food:
			v.food.release_eater()
	elif v.food:
		return   # Comiendo, ni te mira
	elif near and c != Creed.HERETIC:
		pose = Pose.PRAY
		if v.rig:
			v.rig.set_facing_left(hand.x < v.global_position.x)
	elif fear >= FEARS_AT and Power.threat():   # Con un arma o poder afuera (con la comida, no)
		pose = Pose.COWER

## El sol o la luna perturbados (o la Luna de Sangre) a la vista.
func _creepy_sky() -> bool:
	var sky := v.get_tree().get_first_node_in_group("sky")
	return sky != null and (sky.blood_moon or (sky.sun.creepy and sky.sun.is_up) or (sky.moon.creepy and sky.moon.is_up))
