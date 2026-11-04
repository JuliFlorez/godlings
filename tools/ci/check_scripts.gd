extends SceneTree
## Para la CI (ver .github/workflows/checks.yml): carga todos los scripts del proyecto para que
## Godot los compile y avise lo que gdlint no ve (un miembro o una clase que no existe, un tipo
## equivocado, una variable declarada dos veces...). Sale con 1 si alguno no compila; el detalle
## (archivo y línea) lo escribe Godot en la salida.
## Correr con: godot --headless --path . --script res://tools/ci/check_scripts.gd

func _initialize() -> void:
	var paths := _scripts("res://")
	var broken: Array[String] = []
	for path in paths:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			broken.append(path)
	if broken.is_empty():
		print("Compilan los %d scripts." % paths.size())
		quit(0)
	else:
		printerr("No compilan %d de %d scripts: %s" % [broken.size(), paths.size(), ", ".join(broken)])
		quit(1)

## Todos los .gd de dir y de sus carpetas (menos las ocultas, como .godot).
func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_scripts(dir.path_join(d)))
	return out
