extends "res://tests/test_case.gd"
## El estado del cuerpo del aldeano (ver Villager.body): sale de los flags, en orden de prioridad, y
## parado en la isla es lo mismo que is_idle.

var _v: Villager

func before_each() -> void:
	_v = Villager.new()

func after_each() -> void:
	_v.free()

func test_walking_is_idle() -> void:
	check_eq(_v.body(), Villager.Body.WALKING, "recién hecho, camina")
	check(_v.is_idle(), "y está parado en la isla")

func test_dead() -> void:
	_v.dead = true
	check_eq(_v.body(), Villager.Body.LYING, "muerto, tirado en el piso")
	check(not _v.is_idle(), "y no está parado")
	_v.in_water = true
	check_eq(_v.body(), Villager.Body.FLOATING, "un cadáver también flota")
	_v.dragging = true
	check_eq(_v.body(), Villager.Body.DRAGGED, "y se lo puede agarrar")

func test_water() -> void:
	_v.in_water = true
	check_eq(_v.body(), Villager.Body.FLOATING, "en el agua, flota")
	_v.drowning = true
	check_eq(_v.body(), Villager.Body.DROWNING, "hasta que se ahoga")

func test_asleep() -> void:
	_v._sleep.asleep = true   # (asleep se lee del componente: se duerme con fall_asleep)
	check_eq(_v.body(), Villager.Body.ASLEEP, "dormido")
	check(not _v.is_idle(), "y no está parado")
	_v.falling = true
	check_eq(_v.body(), Villager.Body.FALLING, "si se cae, no importa que esté dormido")

func test_eaten_wins() -> void:
	_v.dragging = true
	_v.eaten = true
	check_eq(_v.body(), Villager.Body.EATEN, "lo que se comieron ya no está")
