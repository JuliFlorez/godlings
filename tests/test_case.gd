extends RefCounted
## Lo común de los tests (ver tools/ci/run_tests.gd): cada test_* anota lo que falla con check o
## check_eq, sin cortar, y el corredor muestra todo lo anotado. Sin class_name, así no suma una
## clase global al juego: los tests heredan con extends "res://tests/test_case.gd".

var tree: SceneTree             # Para lo que necesita el árbol (Names, los grupos...)
var failures: Array[String] = []

func check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)

func check_eq(got: Variant, want: Variant, what: String) -> void:
	if not _same(got, want):
		failures.append("%s: dio %s y tenía que dar %s" % [what, var_to_str(got), var_to_str(want)])

## Iguales (los números, aunque uno sea int y el otro float).
func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == typeof(b):
		return a == b
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return false
