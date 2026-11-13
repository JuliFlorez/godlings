extends RefCounted
class_name Tribe
## La tribu y su líder: el más aceptado de la isla. A cada uno lo aceptan más cuanto más carisma
## tiene (ver VillagerStats) y cuanto más lo quieren los demás (ver Relations.affinity; los que no
## lo quieren, restan). Cada tanto se fijan quién es (ver elect, lo llama World): para sacarle el
## lugar al líder hay que pasarlo por bastante (TAKEOVER), así no cambia a cada rato. Los chicos y
## los zombis no pueden ser líderes, y con menos de MIN_TRIBE no hay tribu.
## El líder pesa mucho más que cualquiera en lo que creen los demás: charlando convence varias
## veces más (LEADER_WEIGHT, ver VillagerStats.sway), y además todos lo van siguiendo de a poco:
## su fe se acerca sola a la del líder (ver follow), más rápido cuanto más carisma tiene él; sus
## amigos y su pareja lo siguen más, y sus enemigos no le hacen caso. Así, un líder devoto mantiene
## fiel a la tribu, y uno hereje te la va dando vuelta.
## Se ve en el carnet y con una coronita al lado del nombre (ver NameTag), y quién es el líder se
## guarda con la partida.

const MIN_TRIBE := 3                    # Con menos aldeanos no hay tribu (ni líder)
const ELECT_EVERY := 5.0                # Cada cuánto se fijan quién es el más aceptado
const CHARISMA_WEIGHT := 0.4            # Lo que suma cada punto de carisma a la aceptación...
const AFFINITY_WEIGHT := 0.2            # ...y cada punto de lo que lo quiere (o no) cada uno de los demás
const TAKEOVER := 8.0                   # Para sacarle el lugar hay que pasar al líder por esto
const LEADER_WEIGHT := 3.0              # Veces lo que convence el líder charlando (ver VillagerStats.sway)
const FOLLOW := 0.003                  # Por segundo: de lo que los separa en la fe, lo que se acercan a un líder con carisma 100...
const FOLLOW_CLOSE := 1.5               # ...(sus amigos y su pareja, más; sus enemigos, nada)
const C_LEADER := Color(1.0, 0.82, 0.3)

static var leader_id := 0               # Número de carnet del líder (0: no hay)
static var _leader_node := 0            # Su nodo (instance id; 0 si todavía no se lo buscó)

## Sin líder (al arrancar el mundo, antes de cargar una partida; ver Game.reset).
static func clear() -> void:
	leader_id = 0
	_leader_node = 0

## El líder de la tribu (null si no hay, o si ya no puede serlo: se elige otro en la próxima, ver elect).
static func leader() -> Villager:
	if _leader_node == 0:
		return null
	var v := instance_from_id(_leader_node) as Villager
	if v == null or v.id_number != leader_id or not can_lead(v):
		return null
	return v

static func is_leader(v: Villager) -> bool:
	return v != null and leader_id != 0 and v.id_number == leader_id and leader() == v

## Si puede ser el líder: vivo y en la isla, grande y sin ser un zombi.
static func can_lead(v: Villager) -> bool:
	return is_instance_valid(v) and not v.is_queued_for_deletion() and v.is_alive() and not v.drowning \
			and not v.is_zombie() and not v.is_child()

## Cuánto lo aceptan los de tribe (los vivos): su carisma más lo que lo quiere cada uno.
static func acceptance(v: Villager, tribe: Array) -> float:
	var score := v.charisma * CHARISMA_WEIGHT
	for o: Villager in tribe:
		if o != v:
			score += Relations.affinity(v, o) * AFFINITY_WEIGHT
	return score

## Los vivos que cuentan para la tribu (los zombis no).
static func members(tree: SceneTree) -> Array:
	var out := []
	for node in tree.get_nodes_in_group("villager"):
		var v := node as Villager
		if v and not v.is_queued_for_deletion() and v.is_alive() and not v.is_zombie():
			out.append(v)
	return out

## Se fijan quién es el más aceptado: si pasa al líder por bastante (o no había), es el nuevo
## líder, y sale un cartel. Devuelve el líder (null si no hay tribu o nadie puede serlo).
static func elect(tree: SceneTree) -> Villager:
	var tribe := members(tree)
	var now := leader()
	var best: Villager = null
	var best_score := -INF
	if tribe.size() >= MIN_TRIBE:
		for v: Villager in tribe:
			if not can_lead(v):
				continue
			var score := acceptance(v, tribe)
			if now != null and v != now:
				score -= TAKEOVER
			if score > best_score:
				best = v
				best_score = score
	if best == now:
		return now
	var had_one := leader_id != 0
	set_leader(best)
	if best:
		var text := "%s es el nuevo líder de la tribu" if had_one else "%s es el líder de la tribu"
		Game.announce(TranslationServer.translate(text) % VillagerCard.listed_name(best), C_LEADER)
		best.say(Villager.Bubble.SUN, Villager.REACT_TIME, false)
	return best

## v pasa a ser el líder, sin votar (null: nadie). También para la consola de trucos.
static func set_leader(v: Villager) -> void:
	leader_id = v.id_number if v else 0
	_leader_node = v.get_instance_id() if v else 0

## Para la partida guardada: el líder sigue siendo el que era (id: su carnet, ver World._load_game).
static func load_leader(id: int, tree: SceneTree) -> void:
	clear()
	for v: Villager in members(tree):
		if id != 0 and v.id_number == id:
			set_leader(v)
			return

## Cuánta fe gana (o pierde) v por segundo por seguir al líder: se acerca a lo que cree él.
static func follow(v: Villager) -> float:
	var boss := leader()
	if boss == null or boss == v:
		return 0.0
	var k := FOLLOW * boss.charisma / 100.0
	match Relations.kind(v, boss):
		Relations.Kind.ENEMY:
			return 0.0
		Relations.Kind.FRIEND, Relations.Kind.COUPLE:
			k *= FOLLOW_CLOSE
	return (boss.faith - v.faith) * k
