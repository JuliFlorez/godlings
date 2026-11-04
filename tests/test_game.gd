extends "res://tests/test_case.gd"
## La partida (ver Game): las ofrendas y los sacrificios, comprar, la devoción, la experiencia y los
## puntos de expansión, el guardado y los poderes comprados de las partidas de antes.

func before_each() -> void:
	Game.reset()

func after_each() -> void:
	Game.reset()

func test_buy() -> void:
	check_eq(Game.offerings, Game.START_OFFERINGS, "que arranque con las de la partida nueva")
	Game.add_offerings(100)
	Game.add_sacrifices(2)
	check(not Game.buy(50, 3), "que no alcancen los sacrificios")
	check(Game.buy(50, 2), "que alcance")
	check_eq(Game.offerings, Game.START_OFFERINGS + 50, "lo que le queda")
	check_eq(Game.sacrifices, 0, "que se queden sin sacrificios")

func test_devotion() -> void:
	check(Game.spend_devotion(30.0), "que la gaste")
	check(not Game.spend_devotion(100.0), "que no alcance")
	Game.refill(Game.DEVOTION_REFILL_TIME, 1.0)
	check_eq(Game.devotion, Game.DEVOTION_MAX, "que se recargue entera")

func test_xp_gives_points() -> void:
	Game.set_island(0, 6)
	Game.add_xp(Game.XP_PER_POINT[0])
	check_eq(Game.expansion_points, 1, "un punto")
	check_eq(Game.xp, 0, "que la experiencia vuelva a cero")
	check(Game.spend_expansion_point(), "que lo gaste")
	check(not Game.spend_expansion_point(), "que no tenga más")

func test_no_points_past_the_last_size() -> void:
	Game.set_island(5, 6)
	Game.add_xp(100)
	check_eq(Game.expansion_points, 1, "solo el que falta para el último tamaño")
	check_eq(Game.xp, 0, "y que no junte más")

func test_save_and_load() -> void:
	Game.add_offerings(77)
	Game.add_sacrifices(3)
	var d := Game.save_state()
	Game.reset()
	Game.load_state(d)
	check_eq(Game.offerings, Game.START_OFFERINGS + 77, "las ofrendas")
	check_eq(Game.sacrifices, 3, "los sacrificios")

func test_old_unlocks() -> void:
	var u := Game._old_unlocks({"gun": true, "charms": [false, true, false], "miracles": [true]})
	check_eq(u.get("gun"), true, "la pistola")
	check_eq(u.get("discord"), true, "la Discordia (la segunda de charms)")
	check_eq(u.get("resurrect"), true, "la resurrección (la primera de miracles)")
	check_eq(u.get("lightning"), false, "el rayo, que no estaba")
