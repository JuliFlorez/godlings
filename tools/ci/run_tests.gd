extends SceneTree
## Para la CI (ver .github/workflows/checks.yml): corre los tests de res://tests, los test_*.gd
## (hijos de tests/test_case.gd): cada función test_* de cada uno, en una instancia nueva, con
## before_each y after_each si los tiene. Sale con 1 si alguno falla.
## Correr con: godot --headless --path . --script res://tools/ci/run_tests.gd

func _initialize() -> void:
	var total := 0
	var failed := 0
	for path in _tests("res://tests"):
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			printerr("  MAL  %s: no se pudo cargar" % path.get_file())
			failed += 1
			continue
		for m: Dictionary in script.get_script_method_list():
			var method: String = m.name
			if not method.begins_with("test_"):
				continue
			total += 1
			var t: RefCounted = script.new()
			t.tree = self
			if t.has_method("before_each"):
				t.before_each()
			t.call(method)
			if t.has_method("after_each"):
				t.after_each()
			var fails: Array = t.failures
			if fails.is_empty():
				print("  ok   %s: %s" % [path.get_file(), method])
			else:
				failed += 1
				for f: String in fails:
					printerr("  MAL  %s: %s: %s" % [path.get_file(), method, f])
	print("Tests: %d, fallaron %d" % [total, failed])
	quit(1 if failed > 0 else 0)

func _tests(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	out.sort()
	return out
