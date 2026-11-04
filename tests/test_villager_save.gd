extends "res://tests/test_case.gd"
## Lo que se guarda de cada aldeano (ver Villager.to_dict y from_dict, y los de cada componente):
## vuelve igual, y las partidas de antes (con la edad en segundos) se cargan en la misma etapa de la
## vida.

const FIELDS := ["id_number", "first_name", "last_name", "gender", "hunger", "mood", "tiredness",
		"faith", "fear", "flu", "flu_t", "spore", "age", "lifespan", "grey_age"]

func test_round_trip() -> void:
	var a := Villager.new()
	a.id_number = 7
	a.first_name = "Ana"
	a.last_name = "Pérez"
	a.gender = Villager.Gender.FEMALE
	a.hunger = 42.0
	a.mood = 33.0
	a.tiredness = 71.0
	a.faith = 12.0
	a.fear = 80.0
	a.set_flu(VillagerFlu.Stage.SICK, 20.0)
	a.set_age(5.5)
	a.parents.assign([3, 4])
	var b := Villager.new()
	b.from_dict(a.to_dict())
	for k: String in FIELDS:
		check_eq(b.get(k), a.get(k), k)
	check_eq(b.parents.size(), 2, "los padres")
	a.free()
	b.free()

func test_old_age_in_seconds() -> void:
	var v := Villager.new()
	v.from_dict({"age": 150.0, "lifespan": 3000.0, "grey_age": 100.0})   # Una partida de antes
	var to_days := VillagerAge.ADULT_AGE / (15.0 * 20.0)
	check_eq(v.age, 150.0 * to_days, "la edad, en días")
	check_eq(v.lifespan, 3000.0 * to_days, "lo que vive, en días")
	v.free()
