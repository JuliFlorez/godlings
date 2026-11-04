extends "res://tests/test_case.gd"
## Lo que son entre ellos (ver Relations): amigos, enemigos y pareja según lo que se quieren, lo
## que decide un poder, el historial, olvidar al que se murió, volver a la vida y el guardado.

var _a: Villager
var _b: Villager
var _c: Villager

func before_each() -> void:
	Relations.clear()
	_a = _villager(1)
	_b = _villager(2)
	_c = _villager(3)

func after_each() -> void:
	for v: Villager in [_a, _b, _c]:
		v.free()
	Relations.clear()

func test_friends_and_enemies() -> void:
	check_eq(Relations.change(_a, _b, Relations.FRIEND_AT), Relations.Event.FRIENDS, "se hacen amigos")
	check_eq(Relations.kind(_a, _b), Relations.Kind.FRIEND, "son amigos")
	check_eq(Relations.counts(_a)[Relations.Kind.FRIEND], 1, "a tiene un amigo")
	var drift := Relations.FRIEND_KEEP - Relations.FRIEND_AT - 1.0
	check_eq(Relations.change(_a, _b, drift), Relations.Event.DRIFTED, "se distancian")
	check_eq(Relations.kind(_a, _b), Relations.Kind.NONE, "ya no son nada")
	check_eq(Relations.change(_a, _c, Relations.ENEMY_AT), Relations.Event.ENEMIES, "se hacen enemigos")
	var peace := Relations.ENEMY_KEEP - Relations.ENEMY_AT + 1.0
	check_eq(Relations.change(_a, _c, peace), Relations.Event.MADE_UP, "hacen las paces")

func test_powers_decide() -> void:
	check_eq(Relations.make(_a, _b, Relations.Kind.COUPLE), Relations.Event.COUPLE, "Cupido los hace pareja")
	check_eq(Relations.partner_id(_a), 2, "la pareja de a es b")
	check_eq(Relations.partner_id(_b), 1, "la pareja de b es a")
	check_eq(Relations.make(_a, _b, Relations.Kind.COUPLE), Relations.Event.NONE, "ya eran pareja")
	check_eq(Relations.make(_a, _b, Relations.Kind.ENEMY), Relations.Event.ENEMIES, "la Discordia los hace enemigos")
	check_eq(Relations.partner_id(_a), 0, "a ya no tiene pareja")
	check_eq(Relations.history.size(), 3, "en el historial: pareja, se separan y enemigos")

func test_couple_breaks_up() -> void:
	Relations.make(_a, _b, Relations.Kind.COUPLE)
	var fade := Relations.BREAK_UP_AT - Relations.MADE_COUPLE - 1.0
	check_eq(Relations.change(_a, _b, fade), Relations.Event.BROKE_UP, "se separan")
	check_eq(Relations.kind(_a, _b), Relations.Kind.NONE, "ya no son pareja")

func test_forget_and_restore() -> void:
	Relations.make(_a, _b, Relations.Kind.COUPLE)
	Relations.make(_a, _c, Relations.Kind.FRIEND)
	var rows := Relations.snapshot(_a)
	Relations.forget(_a)
	check_eq(Relations.kind(_a, _b), Relations.Kind.NONE, "olvidado")
	check_eq(Relations.counts(_b)[Relations.Kind.COUPLE], 0, "b queda sin pareja")
	Relations.restore(_a, rows, {2: _b, 3: _c})
	check_eq(Relations.kind(_a, _b), Relations.Kind.COUPLE, "vuelve a ser su pareja")
	check_eq(Relations.kind(_a, _c), Relations.Kind.FRIEND, "vuelve a ser su amigo")

func test_restore_when_partner_moved_on() -> void:
	Relations.make(_a, _b, Relations.Kind.COUPLE)
	var rows := Relations.snapshot(_a)
	Relations.forget(_a)
	Relations.make(_b, _c, Relations.Kind.COUPLE)   # Mientras tanto, b se puso de novia con c
	Relations.restore(_a, rows, {2: _b, 3: _c})
	check_eq(Relations.kind(_a, _b), Relations.Kind.FRIEND, "quedan amigos")
	check_eq(Relations.partner_id(_b), 3, "b sigue con c")

func test_save_and_load() -> void:
	Relations.make(_a, _b, Relations.Kind.COUPLE)
	Relations.make(_a, _c, Relations.Kind.ENEMY)
	var rows := Relations.save_state([1, 2, 3])
	Relations.clear()
	Relations.load_state(rows)
	check_eq(Relations.kind(_a, _b), Relations.Kind.COUPLE, "la pareja")
	check_eq(Relations.kind(_a, _c), Relations.Kind.ENEMY, "los enemigos")
	check_eq(Relations.affinity(_a, _b), Relations.MADE_COUPLE, "lo que se quieren")
	check_eq(Relations.save_state([1, 2]).size(), 1, "solo los que se guardan")

func test_chat_weight() -> void:
	check_eq(Relations.chat_weight(_a, _b), 1.0, "sin nada entre ellos")
	Relations.make(_a, _b, Relations.Kind.COUPLE)
	check_eq(Relations.chat_weight(_a, _b), 4.0, "con su pareja, mucho más")

func test_history_keeps_the_last() -> void:
	for i in Relations.HISTORY_MAX + 10:
		Relations.note_birth(_a, _b)
	check_eq(Relations.history.size(), Relations.HISTORY_MAX, "se borran los más viejos")

func test_kind_of_nobody() -> void:
	check_eq(Relations.kind(_a, null), Relations.Kind.NONE, "con nadie")
	check_eq(Relations.kind(_a, _a), Relations.Kind.NONE, "consigo mismo")

func _villager(id: int) -> Villager:
	var v := Villager.new()
	v.id_number = id
	v.first_name = "Aldeano%d" % id
	return v
