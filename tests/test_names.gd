extends "res://tests/test_case.gd"
## Los nombres al azar (ver Names): cortos, con mayúscula, sin vocales iguales juntas ni malas
## palabras.

func test_first_names() -> void:
	for i in 200:
		var n := Names.first_name(tree, i % 2 == 0)
		check(n.length() > 1 and n.length() <= Names.MAX_FIRST, "el largo de " + n)
		check(n[0] == n[0].to_upper(), "la mayúscula de " + n)
		check(Names._sounds_ok(n), "suena mal: " + n)

func test_last_names() -> void:
	for i in 200:
		var n := Names.last_name(tree)
		check(n.length() > 1 and n.length() <= Names.MAX_LAST, "el largo de " + n)
		check(Names._sounds_ok(n), "suena mal: " + n)

func test_sounds_ok() -> void:
	check(not Names._sounds_ok("Tiina"), "Tiina tiene dos vocales iguales juntas")
	check(not Names._sounds_ok("Capedo"), "Capedo tiene una mala palabra adentro")
	check(Names._sounds_ok("Marina"), "Marina está bien")
