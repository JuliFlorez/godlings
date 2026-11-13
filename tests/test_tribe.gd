extends "res://tests/test_case.gd"
## El carisma y el líder de la tribu (ver VillagerStats y Tribe): los carismáticos charlan mejor,
## a cada uno lo aceptan por su carisma y por lo que lo quieren, y el líder pesa más en lo que
## creen los demás (charlando, y porque lo siguen).

var _a: Villager
var _b: Villager
var _c: Villager

func before_each() -> void:
	Relations.clear()
	Tribe.clear()
	_a = _villager(1)
	_b = _villager(2)
	_c = _villager(3)

func after_each() -> void:
	for v: Villager in [_a, _b, _c]:
		v.free()
	Relations.clear()
	Tribe.clear()

func test_charisma_helps_chats() -> void:
	var dull := 0.0
	var charming := 0.0
	for i in 400:
		_a.charisma = 0.0
		_b.charisma = 0.0
		dull += Relations.chat_delta(_a, _b)
		_a.charisma = 100.0
		_b.charisma = 100.0
		charming += Relations.chat_delta(_a, _b)
	check(charming > dull, "con carisma charlan mejor")

func test_acceptance() -> void:
	_a.charisma = 50.0
	var tribe := [_a, _b, _c]
	check_eq(Tribe.acceptance(_a, tribe), 50.0 * Tribe.CHARISMA_WEIGHT, "sin que nadie lo quiera, su carisma")
	Relations.change(_a, _b, 50.0)
	Relations.change(_a, _c, -20.0)
	check_eq(Tribe.acceptance(_a, tribe), 50.0 * Tribe.CHARISMA_WEIGHT + 30.0 * Tribe.AFFINITY_WEIGHT,
			"más lo que lo quieren (y menos lo que no)")

func test_leader() -> void:
	check(not Tribe.is_leader(_a), "sin líder")
	check_eq(Tribe.leader(), null, "nadie")
	Tribe.set_leader(_a)
	check(Tribe.is_leader(_a), "a es el líder")
	check(not Tribe.is_leader(_b), "b no")
	Tribe.set_leader(null)
	check(not Tribe.is_leader(_a), "ya no")

func test_leader_persuades_more() -> void:
	_a.charisma = 60.0
	_a.faith = 90.0
	_b.faith = 40.0
	var plain := _a.persuasion(_b)
	check_eq(plain, 50.0 * VillagerStats.PERSUADE * 0.6, "lo que convence por su carisma")
	Tribe.set_leader(_a)
	check(is_equal_approx(_a.persuasion(_b), plain * Tribe.LEADER_WEIGHT), "de líder, varias veces más")

func test_exchange() -> void:
	_a.charisma = 100.0
	_b.charisma = 0.0
	_a.faith = 80.0
	_b.faith = 20.0
	VillagerStats.exchange(_a, _b)
	check_eq(_a.faith, 80.0, "al que no tiene carisma no le hacen caso")
	check_eq(_b.faith, 20.0 + 60.0 * VillagerStats.PERSUADE, "y el otro lo convence")

func test_follow_the_leader() -> void:
	_a.charisma = 100.0
	_a.faith = 100.0
	_b.faith = 0.0
	check_eq(Tribe.follow(_b), 0.0, "sin líder, nada")
	Tribe.set_leader(_a)
	check_eq(Tribe.follow(_a), 0.0, "el líder no se sigue a sí mismo")
	check_eq(Tribe.follow(_b), 100.0 * Tribe.FOLLOW, "lo sigue: cree más")
	_a.faith = 0.0
	_b.faith = 100.0
	check_eq(Tribe.follow(_b), -100.0 * Tribe.FOLLOW, "con un líder hereje, cree menos")
	Relations.make(_a, _b, Relations.Kind.FRIEND)
	check(is_equal_approx(Tribe.follow(_b), -100.0 * Tribe.FOLLOW * Tribe.FOLLOW_CLOSE), "su amigo lo sigue más")
	Relations.make(_a, _b, Relations.Kind.ENEMY)
	check_eq(Tribe.follow(_b), 0.0, "su enemigo no le hace caso")

func test_children_inherit() -> void:
	_a.charisma = 100.0
	_b.charisma = 100.0
	var sum := 0.0
	for i in 50:
		_c.inherit_stats(_a, _b)
		sum += _c.charisma
	check(sum / 50.0 > 75.0, "los hijos de dos carismáticos salen carismáticos")

func _villager(id: int) -> Villager:
	var v := Villager.new()
	v.id_number = id
	v.first_name = "Aldeano%d" % id
	return v
