extends RefCounted
class_name VillagerPrayer
## Las plegarias: cada tanto, un aldeano que cree en vos te pide algo concreto y se le ve arriba
## de la cabeza (ver PrayerMark) mientras espera: comida si tiene hambre, una cura si está
## enfermo, que cures a alguien que quiere, que castigues a un enemigo o una casa si no tiene
## dónde vivir. Si se lo cumplís a tiempo te cree más, se pone contento y te deja ofrendas (y los
## que lo ven también te creen un poco más); si se le acaba la paciencia, te cree menos y se pone
## triste. Si se le pasa solo (comió por su cuenta, se curó, hizo las paces), no pasa nada.
## Los herejes no piden nada, y hay pocas plegarias a la vez (más con más aldeanos).
## Se ve en el carnet y se guarda con la partida.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (prayer, prayer_text, prayer_left, answer_prayer...).

enum Ask { NONE, FOOD, CURE, HEAL, SMITE, HOME }
enum State { WAITING, GRANTED, MOOT }
const EVERY := Vector2(50.0, 110.0)   # Cada cuánto se le ocurre pedirte algo
const FIRST := Vector2(20.0, 80.0)    # La primera, un poco antes
const RETRY := 8.0                    # Si no tenía nada que pedir (o ya había muchos pidiendo)
const PATIENCE := 50.0                # Lo que espera
const ASKING_BASE := 1                # Cuántos piden a la vez en la isla...
const ASKING_PER := 6                 # ...y uno más cada tantos aldeanos
const KNEEL_TIME := 2.5               # Al pedir, se arrodilla un momento
const FAITH_GRANTED := 10.0
const FAITH_SEEN := 3.0               # Los que ven que se la cumpliste (de cerca)
const FAITH_IGNORED := 8.0
const SMITE_CHANCE := 0.35            # Contento, pocas veces pide que castigues a un enemigo
## Lo que deja de ofrendas cuando se la cumplís
const OFFERINGS := { Ask.FOOD: 5, Ask.CURE: 6, Ask.HEAL: 8, Ask.SMITE: 10, Ask.HOME: 10 }
## Lo que se le ocurre pedir antes, si puede pedir varias cosas (lo que necesita, primero)
const WEIGHTS := { Ask.FOOD: 3.0, Ask.CURE: 4.0, Ask.HEAL: 3.0, Ask.SMITE: 1.0, Ask.HOME: 1.0 }
const WORDS := {
	Ask.FOOD: "Te pide comida",
	Ask.CURE: "Te pide una cura",
	Ask.HEAL: "Te pide que cures a %s",
	Ask.SMITE: "Te pide que castigues a %s",
	Ask.HOME: "Te pide una casa",
}

var ask := Ask.NONE
var time_left := 0.0
var about := 0                        # Por quién pide (su número de carnet; 0 si es para él)
var _next := 0.0                      # Lo que falta para que se le ocurra pedir algo

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	_next = randf_range(FIRST.x, FIRST.y)

## Para la partida guardada (ver Villager.to_dict).
func to_dict() -> Dictionary:
	return {"ask": ask, "ask_t": time_left, "ask_about": about}

func from_dict(d: Dictionary) -> void:
	ask = d.get("ask", Ask.NONE) as Ask
	time_left = d.get("ask_t", 0.0)
	about = d.get("ask_about", 0)

## Lo que le queda de paciencia: 1 recién pidió .. 0 se cansó de esperar.
func left() -> float:
	return clampf(time_left / PATIENCE, 0.0, 1.0) if ask != Ask.NONE else 0.0

## Lo que te pide, en palabras ("" si nada): para el carnet y el cartel.
func text() -> String:
	if ask == Ask.NONE:
		return ""
	var words: String = v.tr(WORDS[ask])
	if ask == Ask.HEAL or ask == Ask.SMITE:
		var o := _other()
		return words % (VillagerCard.listed_name(o) if o else "?")
	return words

## Cada frame (lo llama el aldeano): se le ocurre pedir algo, o espera a que se lo cumplas.
func update(dt: float) -> void:
	if not v.is_alive() or v.is_zombie():
		ask = Ask.NONE   # (El zombi ya no cree en nada)
		return
	if ask == Ask.NONE:
		if not _can_ask():
			return
		_next -= dt
		if _next <= 0.0:
			_next = RETRY
			pray_now()
		return
	if v.inside or v.asleep:
		return   # Durmiendo (o en su casa) no espera nada: sigue cuando sale
	match state():
		State.GRANTED:
			_granted()
		State.MOOT:
			_end()
		State.WAITING:
			time_left -= dt
			if time_left <= 0.0:
				_ignored()

## Tranquilo en la isla y creyendo en vos (los herejes no piden nada).
func _can_ask() -> bool:
	return v.is_idle() and not v.on_fire and not v.is_scared() and v.faith >= VillagerFaith.BELIEVES_AT

## Le pide algo ya, si tiene qué y no hay muchos pidiendo. force: aunque haya muchos (la consola
## de trucos). true si pidió.
func pray_now(force := false) -> bool:
	if ask != Ask.NONE or not v.is_alive() or v.is_zombie():
		return false
	if not force and _asking() >= ASKING_BASE + floori(_alive() / float(ASKING_PER)):
		return false
	var options := _options()
	if options.is_empty():
		return false
	var total := 0.0
	for o: Array in options:
		total += WEIGHTS[o[0]]
	var pick := randf() * total
	for o: Array in options:
		pick -= WEIGHTS[o[0]]
		if pick <= 0.0:
			_begin(o[0], o[1])
			return true
	_begin(options[-1][0], options[-1][1])
	return true

## Lo que tiene para pedir ahora: [qué, por quién].
func _options() -> Array:
	var out := []
	if v.hunger >= VillagerHunger.HUNGRY_AT:
		out.append([Ask.FOOD, 0])
	if _ill(v):
		out.append([Ask.CURE, 0])
	# Una casa, si en la isla hay chozas y no le quedó lugar en ninguna (sin chozas nadie extraña una)
	if not v.has_home() and not v.get_tree().get_nodes_in_group("hut").is_empty() and v._home._free_hut(1) == null:
		out.append([Ask.HOME, 0])
	var loved: Array[Villager] = []
	var enemies: Array[Villager] = []
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == v or not o.is_alive() or o.inside:
			continue
		var k := Relations.kind(v, o)
		var family := o.id_number in v.parents or v.id_number in o.parents
		if _ill(o) and (family or k == Relations.Kind.COUPLE or k == Relations.Kind.FRIEND):
			loved.append(o)
		elif k == Relations.Kind.ENEMY and not o.is_child() and not o.is_zombie():
			enemies.append(o)
	if not loved.is_empty():
		out.append([Ask.HEAL, loved.pick_random().id_number])
	if not enemies.is_empty() and not v.is_child() and (v.is_sad() or randf() < SMITE_CHANCE):
		out.append([Ask.SMITE, enemies.pick_random().id_number])
	return out

## Enfermo de algo que se cura (con gripe, o con hongos y todavía él).
static func _ill(o: Villager) -> bool:
	return o.is_sick() or (o.spore_shows() and not o.is_zombie())

func _begin(what: Ask, who: int) -> void:
	ask = what
	about = who
	time_left = PATIENCE
	v.say(Villager.Bubble.EXCLAIM, 1.6)
	v._faith.worship(KNEEL_TIME, v.global_position)
	_tell(text(), UiStyle.C_DEVOTION)

## Cómo viene lo que pidió: ya está (GRANTED), ya no hace falta (MOOT) o sigue esperando. La
## comida y la cura se las cumplís vos (ver answer): si se le pasa solo, no cuenta.
func state() -> State:
	match ask:
		Ask.FOOD:
			return State.MOOT if v.hunger < VillagerHunger.HUNGRY_AT else State.WAITING
		Ask.CURE:
			return State.WAITING if _ill(v) else State.MOOT
		Ask.HEAL:
			var o := _other()
			return State.WAITING if o and o.is_alive() and _ill(o) else State.MOOT
		Ask.SMITE:
			var o := _other()
			if o == null or not o.is_alive():
				return State.GRANTED   # Se murió (como sea): lo escuchaste
			return State.WAITING if Relations.kind(v, o) == Relations.Kind.ENEMY else State.MOOT
		Ask.HOME:
			return State.GRANTED if v.has_home() else State.WAITING
	return State.MOOT

## Le hiciste lo que what pide a who (su número de carnet): si era lo que él estaba pidiendo, se
## la cumpliste. Lo llama el aldeano (ver Villager.answer_prayers) cuando le das de comer del
## cielo o lo curás.
func answer(what: Ask, who: int) -> void:
	if ask != what or v.inside:
		return
	if (what == Ask.HEAL and about == who) or (what != Ask.HEAL and who == v.id_number):
		_granted()

func _granted() -> void:
	var gift: int = OFFERINGS[ask]
	Game.add_offerings(gift)
	_tell(v.tr("Plegaria cumplida: +%d ofrendas") % gift, UiStyle.C_OFFERING)
	v.add_faith(FAITH_GRANTED)
	v.add_mood(VillagerMood.MOOD_PRAYER_GRANTED, "Le cumpliste una plegaria")
	v.say(Villager.Bubble.LAUGH if ask == Ask.SMITE else Villager.Bubble.HEART, VillagerFaith.THANKS_TIME, false)
	if v.is_inside_tree():
		var at := v.body_center()
		for node in v.get_tree().get_nodes_in_group("villager"):
			var o := node as Villager
			if o and o != v and o.is_alive():
				o.add_faith(FAITH_SEEN * o.witness(at))
	_end()

func _ignored() -> void:
	_tell("No escuchaste su plegaria", UiStyle.C_MUTED)
	v.add_faith(-FAITH_IGNORED)
	v.add_mood(VillagerMood.MOOD_PRAYER_IGNORED, "No escuchaste su plegaria")
	v.say(Villager.Bubble.TEAR, VillagerFaith.THANKS_TIME, false)
	_end()

func _end() -> void:
	ask = Ask.NONE
	about = 0
	time_left = 0.0
	_next = randf_range(EVERY.x, EVERY.y)

## Un cartel flotante arriba de él.
func _tell(words: String, color: Color) -> void:
	if v.is_inside_tree():
		Game.say(words, v.get_global_transform_with_canvas().origin + Vector2(0, -95), color)

## Por quién pide (null si ya no está en la isla).
func _other() -> Villager:
	if about == 0 or not v.is_inside_tree():
		return null
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o.id_number == about:
			return o
	return null

## Cuántos están pidiendo algo ahora, y cuántos vivos hay en la isla.
func _asking() -> int:
	var n := 0
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o.is_alive() and o.prayer != Ask.NONE:
			n += 1
	return n

func _alive() -> int:
	var n := 0
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o.is_alive():
			n += 1
	return n
