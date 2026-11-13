extends Node
class_name Calamities
## Los eventos al azar: cada tanto, sin que el jugador haga nada, a la isla le pasa algo: un brote
## de gripe (varios se contagian a la vez), una lluvia de meteoritos (caen dos o tres, de a uno,
## buscando los lugares más despejados de la isla) o un terremoto (ver Quake). Sale un cartel en el medio de la
## pantalla que avisa un momento antes, para llegar a hacer algo (vacunar, correr a los del borde).
## Se apagan en la Configuración ("Eventos al azar", ver Settings.random_events): apagados no pasa
## ninguno, y tampoco la gripe que cada tanto alguien se agarra solo (ver World._update_outbreak).
## Con pocos aldeanos, o mientras llueve el diluvio, no pasa nada: espera.
## Lo crea World. No se guarda: al cargar la partida, la cuenta arranca de nuevo.

enum Kind { FLU, METEORS, QUAKE }
const EVERY := Vector2(240.0, 480.0)   # Cada cuánto pasa algo (de 4 a 8 minutos)
const FIRST := Vector2(150.0, 300.0)   # El primero de la partida
const RETRY := 20.0                    # Si no era momento (pocos aldeanos, llueve), prueba de nuevo en esto
const MIN_VILLAGERS := 3
const WARNING := 3.5                   # El cartel sale esto antes
const FLU_SICK := Vector2i(2, 4)       # A cuántos les agarra la gripe
const METEORS := Vector2i(2, 3)        # Cuántos meteoritos caen...
const METEOR_GAP := Vector2(0.6, 1.4)  # ...cada cuánto...
const METEOR_TRIES := 4                # ...y entre cuántos puntos al azar elige el más despejado
## El cartel que avisa cada uno
const WARNINGS := {
	Kind.FLU: "¡Anda dando vueltas una gripe!",
	Kind.METEORS: "¡Se viene una lluvia de meteoritos!",
	Kind.QUAKE: "La tierra empieza a temblar...",
}

var world: World
var _next := 0.0            # Lo que falta para el próximo
var _coming := -1           # El que ya avisó y está por pasar (-1: ninguno)...
var _coming_t := 0.0        # ...en esto
var _meteors_left := 0      # Lluvia de meteoritos: los que faltan caer...
var _meteor_t := 0.0        # ...y lo que falta para el próximo

func _init() -> void:
	_next = randf_range(FIRST.x, FIRST.y)

func _process(dt: float) -> void:
	if world == null or not world.playing:
		return
	# Lo que ya empezó termina aunque los apaguen justo
	if _meteors_left > 0:
		_meteor_t -= dt
		if _meteor_t <= 0.0:
			_meteor_t = randf_range(METEOR_GAP.x, METEOR_GAP.y)
			_meteors_left -= 1
			_drop_meteor()
	if _coming >= 0:
		_coming_t -= dt
		if _coming_t <= 0.0:
			var kind := _coming as Kind
			_coming = -1
			_happen(kind)
		return
	if not Settings.random_events:
		return
	_next -= dt
	if _next > 0.0:
		return
	if not _good_moment():
		_next = RETRY
		return
	_next = randf_range(EVERY.x, EVERY.y)
	announce(Kind.values().pick_random())

## Avisa que viene kind (el cartel) y lo deja por pasar en un momento. También la consola de trucos.
func announce(kind: Kind) -> void:
	_coming = kind
	_coming_t = WARNING
	Game.announce(WARNINGS[kind], UiStyle.C_WARN)

## Hay a quién le pase algo y no hay ya otra cosa pasando (el diluvio, un terremoto, meteoritos).
func _good_moment() -> bool:
	if _meteors_left > 0 or Storm.rain > 0.0:
		return false
	var quake := _power("quake") as Quake
	if quake and quake.shaking():
		return false
	var alive := 0
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.is_alive():
			alive += 1
	return alive >= MIN_VILLAGERS

func _happen(kind: Kind) -> void:
	match kind:
		Kind.FLU:
			_flu()
		Kind.METEORS:
			_meteors_left = randi_range(METEORS.x, METEORS.y)
			_meteor_t = 0.0
		Kind.QUAKE:
			var quake := _power("quake") as Quake
			if quake:
				quake.strike()

## Brote de gripe: unos cuantos sanos se contagian a la vez (la incuban primero, como siempre; a
## los vacunados y a los que tienen el escudo no les entra).
func _flu() -> void:
	var healthy: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.is_alive() and v.flu == VillagerFlu.Stage.HEALTHY and not v.is_zombie():
			healthy.append(v)
	healthy.shuffle()
	for i in mini(randi_range(FLU_SICK.x, FLU_SICK.y), healthy.size()):
		healthy[i].catch_flu()

## Cae un meteorito en un punto al azar de la isla.
func _drop_meteor() -> void:
	var meteor := _power("meteor") as Meteor
	if meteor == null or world.island_poly_global.is_empty():
		return
	# De unos cuantos puntos al azar, el que tiene menos aldeanos encima: asusta y revolea, pero no
	# arrasa con la aldea (para eso está el poder)
	var best := Vector2.ZERO
	var best_hit := -1
	for i in METEOR_TRIES:
		var at := world._island_point()
		var hit := 0
		for node in get_tree().get_nodes_in_group("villager"):
			var v := node as Villager
			if v and v.is_alive() and v.body_distance(at) <= Meteor.KILL_RADIUS:
				hit += 1
		if best_hit < 0 or hit < best_hit:
			best = at
			best_hit = hit
	meteor.fall(best)

func _power(id: String) -> Power:
	for p in Power.all():
		if p.id == id:
			return p
	return null
