extends "res://tests/test_case.gd"
## Los eventos al azar (ver Calamities) y el terremoto (ver Quake): cada evento tiene su cartel, y
## el terremoto arranca quieto, recargado y sin apuntar.

func test_every_event_warns() -> void:
	for kind: int in Calamities.Kind.values():
		check(Calamities.WARNINGS.has(kind), "el evento %d tiene su cartel" % kind)
		check(I18n.EN.has(Calamities.WARNINGS[kind]), "y está traducido")

func test_quake_starts_calm() -> void:
	var q := Quake.new()
	check(not q.shaking(), "recién hecho, no tiembla")
	check_eq(q.strength(), 0.0, "ni tiene fuerza")
	check_eq(q.recharge(), 1.0, "y está recargado")
	check(not q.aims, "no se apunta: tiembla toda la isla")
	check(q.sacrifices > 0, "es un poder malo: cuesta sacrificios")
	q.free()

func test_events_can_be_turned_off() -> void:
	var was := Settings.random_events
	var c := Calamities.new()
	Settings.random_events = false   # (Sin guardar: set_random_events escribe las opciones)
	c._next = 0.0
	c._process(1.0)   # Sin mundo no hace nada, y apagados tampoco
	check_eq(c._coming, -1, "apagados, no viene nada")
	Settings.random_events = was
	c.free()
