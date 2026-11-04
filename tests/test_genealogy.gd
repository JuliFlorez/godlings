extends "res://tests/test_case.gd"
## Los que ya no están (ver Genealogy): anotarlos al morirse, encontrarlos, volver a la vida, sus
## hijos, los nombres tomados y el guardado.

var _mom: Villager
var _kid: Villager

func before_each() -> void:
	Genealogy.clear()
	Relations.clear()
	_mom = Villager.new()
	_mom.id_number = 10
	_mom.first_name = "Ana"
	_mom.last_name = "Pérez"
	_kid = Villager.new()
	_kid.id_number = 11
	_kid.first_name = "Beto"
	_kid.parents.assign([10, 12])

func after_each() -> void:
	_mom.free()
	_kid.free()
	Genealogy.clear()
	Relations.clear()

func test_remember_and_revive() -> void:
	Genealogy.remember(_mom)
	var p := Genealogy.person(tree, 10)
	check_eq(p.get("first"), "Ana", "el nombre")
	check_eq(p.get("dead"), true, "que se murió")
	check(Genealogy.names_taken(tree).has("Ana"), "que su nombre quede tomado")
	Genealogy.revive(10)
	check(Genealogy.person(tree, 10).is_empty(), "que al volver a la vida no esté entre los que se fueron")

func test_children() -> void:
	Genealogy.remember(_kid)
	var kids := Genealogy.children_of(tree, 10)
	check_eq(kids.size(), 1, "un hijo")
	if kids.size() == 1:
		check_eq(kids[0], 11, "que sea Beto")
	check_eq(Genealogy.children_of(tree, 12).size(), 1, "también del otro padre")

func test_save_and_load() -> void:
	Genealogy.remember(_mom)
	var rows := Genealogy.save_state()
	Genealogy.clear()
	check(Genealogy.person(tree, 10).is_empty(), "que se borre")
	Genealogy.load_state(rows)
	check_eq(Genealogy.person(tree, 10).get("last"), "Pérez", "el apellido, de vuelta")
