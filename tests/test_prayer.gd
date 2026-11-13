extends "res://tests/test_case.gd"
## Las plegarias (ver VillagerPrayer): lo que pide se guarda, y cuándo se le cumple, cuándo ya no
## hace falta y cuándo sigue esperando.

var _v: Villager

func before_each() -> void:
	_v = Villager.new()
	_v.id_number = 7

func after_each() -> void:
	_v.free()

func test_nothing_asked() -> void:
	check_eq(_v.prayer, VillagerPrayer.Ask.NONE, "recién hecho, no pide nada")
	check_eq(_v.prayer_text(), "", "ni dice nada")
	check_eq(_v.prayer_left(), 0.0, "ni espera")

func test_round_trip() -> void:
	_v._prayer.ask = VillagerPrayer.Ask.HEAL
	_v._prayer.time_left = 21.0
	_v._prayer.about = 3
	var b := Villager.new()
	b.from_dict(_v.to_dict())
	check_eq(b.prayer, VillagerPrayer.Ask.HEAL, "lo que pide")
	check_eq(b.prayer_time(), 21.0, "lo que le queda")
	check_eq(b._prayer.about, 3, "por quién")
	b.from_dict({})   # Una partida de antes: no pedía nada
	check_eq(b.prayer, VillagerPrayer.Ask.NONE, "las partidas de antes, nada")
	b.free()

func test_food() -> void:
	_v._prayer.ask = VillagerPrayer.Ask.FOOD
	_v._prayer.time_left = VillagerPrayer.PATIENCE
	_v.hunger = 80.0
	check_eq(_v._prayer.state(), VillagerPrayer.State.WAITING, "con hambre, espera")
	check_eq(_v.prayer_left(), 1.0, "con toda la paciencia")
	_v.hunger = 10.0
	check_eq(_v._prayer.state(), VillagerPrayer.State.MOOT, "si comió por su cuenta, ya no hace falta")

func test_cure() -> void:
	_v._prayer.ask = VillagerPrayer.Ask.CURE
	_v.set_flu(VillagerFlu.Stage.SICK, 20.0)
	check_eq(_v._prayer.state(), VillagerPrayer.State.WAITING, "enfermo, espera")
	_v.set_flu(VillagerFlu.Stage.IMMUNE, 20.0)
	check_eq(_v._prayer.state(), VillagerPrayer.State.MOOT, "si se curó solo, ya no hace falta")

func test_answer() -> void:
	var gift: int = VillagerPrayer.OFFERINGS[VillagerPrayer.Ask.FOOD]
	var before := Game.offerings
	var faith := 50.0
	_v.faith = faith
	_v._prayer.ask = VillagerPrayer.Ask.FOOD
	_v._prayer.answer(VillagerPrayer.Ask.CURE, 7)
	check_eq(_v.prayer, VillagerPrayer.Ask.FOOD, "curarlo no le cumple el pedido de comida")
	_v._prayer.answer(VillagerPrayer.Ask.FOOD, 8)
	check_eq(_v.prayer, VillagerPrayer.Ask.FOOD, "ni darle de comer a otro")
	_v._prayer.answer(VillagerPrayer.Ask.FOOD, 7)
	check_eq(_v.prayer, VillagerPrayer.Ask.NONE, "darle de comer a él, sí")
	check_eq(Game.offerings, before + gift, "y deja ofrendas")
	check_eq(_v.faith, faith + VillagerPrayer.FAITH_GRANTED, "y te cree más")

func test_heal_other() -> void:
	_v._prayer.ask = VillagerPrayer.Ask.HEAL
	_v._prayer.about = 3
	_v._prayer.answer(VillagerPrayer.Ask.HEAL, 4)
	check_eq(_v.prayer, VillagerPrayer.Ask.HEAL, "curar a otro que no es por quien pide, no")
	_v._prayer.answer(VillagerPrayer.Ask.HEAL, 3)
	check_eq(_v.prayer, VillagerPrayer.Ask.NONE, "curar a ese, sí")
