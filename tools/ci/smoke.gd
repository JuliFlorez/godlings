extends SceneTree
## Prueba de humo para la CI (ver .github/workflows/checks.yml): arranca el mundo, empieza una
## partida nueva y la juega sola un rato, pasando por los sistemas del aldeano y por todos los
## poderes; la guarda, vuelve a cargar el mundo, carga la partida (y se fija que cada aldeano vuelva
## como se guardó) y sigue un rato más, ahora con el diluvio.
## Lo demás no lo juzga (eso se ve jugando): la CI falla si en la salida aparece un error de script
## (SCRIPT ERROR), y este script sale con 1 si la partida no arranca o no se carga igual.
## Correr con: godot --headless --path . --fixed-fps 60 --script res://tools/ci/smoke.gd

const SLOT := 9                 # La ranura de prueba: fuera de las del menú, así no pisa una de verdad
const FPS := 60                 # Cuadros por segundo (ver --fixed-fps)
const LAND_TIMEOUT := 1200      # Cuadros para llegar a la isla
const ROUND_TIME := 40          # Segundos que juega cada vuelta
## Lo que se compara de cada aldeano entre lo guardado y lo cargado (además del nombre y demás)
const SAVED_FLOATS := ["hunger", "mood", "tiredness", "faith", "fear", "spore", "flu_t", "shield_t",
		"vaccine_t", "age", "lifespan", "grey_age"]

var _world: World
var _old_id := 0                # El mundo de la vuelta anterior (mientras se borra, sigue siendo la escena)
var _step := 0
var _frame := 0                 # Cuadros desde que empezó el paso de ahora
var _round := 1                 # 1: la partida nueva; 2: la misma, guardada y vuelta a cargar
var _saved := {}                # Lo que había al guardar (ver _snapshot)

func _initialize() -> void:
	print("Prueba de humo: arranca el mundo")
	SaveSlots.delete(SLOT)   # Que la primera vuelta sea una partida nueva
	change_scene_to_file("res://world/world.tscn")

func _process(_delta: float) -> bool:
	_frame += 1
	match _step:
		0:   # Esperando el mundo (cambiar de escena tarda un cuadro)
			var w := current_scene as World
			if w and w.get_instance_id() != _old_id and w.is_inside_tree() and _frame > 5:
				_world = w
				print("Prueba de humo: elige la ranura %d (vuelta %d)" % [SLOT, _round])
				_world._start_slot(SLOT)
				if _round == 2:
					var diff := _diff(_saved, _snapshot())
					if diff != "":
						return _fail("la partida no se cargó como se guardó: " + diff)
					print("Prueba de humo: se cargó igual que como se guardó (%d aldeanos)" % (_saved.size() - 1))
				_world._descent.set_speed_scale(40.0)   # Que baje rápido
				_next()
			elif _frame > 300:
				return _fail("no cargó el mundo")
		1:   # Bajando a la isla
			if _world.playing:
				print("Prueba de humo: llegó a la isla con %d aldeanos" % _villagers().size())
				_setup()
				_next()
			elif _frame > LAND_TIMEOUT:
				return _fail("no llegó a la isla")
		2:   # Jugando
			if _frame == FPS * 2:
				_afflictions()
			elif _frame == FPS * 5:
				_use_powers()
			elif _frame == FPS * 12:
				_nightfall()
			elif _frame == FPS * 30:
				_deaths()
			elif _frame >= FPS * ROUND_TIME:
				_next()
		3:   # Fin de la vuelta
			if _round == 2:
				print("Prueba de humo: terminó con %d aldeanos vivos" % _villagers().size())
				quit(0)
				return true
			_world.save_game()
			_saved = _snapshot()
			print("Prueba de humo: guardó la partida con %d aldeanos; vuelve a cargar el mundo" % (_saved.size() - 1))
			_old_id = _world.get_instance_id()
			_world = null
			_round = 2
			_step = 0
			_frame = 0
			reload_current_scene()
	return false

## Lo que tendría un jugador que ya avanzó: la isla grande, todos los poderes, más aldeanos,
## chozas, una antorcha, bayas, una palmera, un altar y devoción de sobra. En la segunda vuelta,
## lo que se cargó, y más aldeanos (en la primera se murieron varios).
func _setup() -> void:
	if _round == 1:
		_world.set_island_level(_world.max_level())
		for p in Power.all():
			p.unlocked = true
		Game.add_offerings(5000)
		Game.add_sacrifices(50)
		for kind: String in ["hut", "hut", "hut", "torch", "berries", "palm", "altar"]:
			var d := Decoration.new()
			d.kind = kind
			_world.props.add_child(d)
			d.global_position = _world._island_point()
	Game.fill_devotion()
	_world.debug_spawn_villagers(12)
	print("Prueba de humo: %d aldeanos, todo desbloqueado, chozas y un altar" % _villagers().size())

## Les pasa de todo: gripe, espora, un zombi, hambre, sueño, tristeza, miedo, vejez y fuego.
func _afflictions() -> void:
	print("Prueba de humo: gripe, espora, zombi, hambre, sueño, tristeza, miedo, vejez y fuego")
	_world.debug_infect(2)
	_world.debug_spore(1)
	_world.debug_spore(1, true)
	var vs := _villagers()
	if vs.size() < 6:
		return
	vs[0].hunger = 100.0
	vs[1].tiredness = 95.0
	vs[2].mood = 5.0
	vs[3].set_age(7.5)
	vs[4]._burn.ignite()   # (Prenderse fuego no se reenvía: se prende en una antorcha)
	vs[5].faith = 10.0
	vs[5].fear = 90.0

## Usa cada poder una vez sobre algún aldeano, como el click (la resurrección, sobre un cadáver).
## En la segunda vuelta también desata el diluvio (en la primera se los llevaría a casi todos antes
## de guardar).
func _use_powers() -> void:
	_world.debug_kill(1)
	var corpse := _corpse()
	for p in Power.all():
		if not p.aims:
			continue
		var vs := _villagers()
		if vs.is_empty():
			break
		Game.fill_devotion()
		var at: Vector2 = vs[randi() % vs.size()].body_center()
		if p is Miracle and (p as Miracle).kind == Miracle.Kind.RESURRECT and corpse:
			at = corpse.body_center()
		p.set_armed(true)
		p._use(at)
		p.set_armed(false)
		print("Prueba de humo: usó " + p.id)
	if _round == 2:
		for p in Power.all():
			if not p.aims:
				p.set_armed(true)
				print("Prueba de humo: desató " + p.id)

## Cae la noche: se van a dormir (a su choza, o en el piso).
func _nightfall() -> void:
	var sky = _world.get_node("Sky")   # (Sky no tiene class_name)
	sky.clock = sky.DAY_LENGTH - 0.5
	print("Prueba de humo: cae la noche")

## Uno se muere de viejo (apenas está parado en la isla) y a otro le pegan un tiro.
func _deaths() -> void:
	var vs := _villagers()
	if not vs.is_empty():
		vs[0].set_age(10.5)
	_world.debug_kill(1)
	print("Prueba de humo: uno de viejo y uno de un tiro")

## Lo que se guarda de cada aldeano vivo (los que se están hundiendo no se guardan, ver
## World.save_game), por carnet, y lo de la partida en "game".
func _snapshot() -> Dictionary:
	var out := {"game": {"offerings": Game.offerings, "sacrifices": Game.sacrifices,
			"level": _world.island_level, "decorations": _decorations()}}
	for node in get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or not v.is_alive() or v.drowning:
			continue
		var d := {"name": v.full_name(), "gender": v.gender, "flu": v.flu, "home": v.has_home(),
				"parents": Array(v.parents)}
		for f: String in SAVED_FLOATS:
			d[f] = float(v.get(f))
		out[v.id_number] = d
	return out

## Lo que no coincide entre dos _snapshot ("" si nada).
func _diff(saved: Dictionary, loaded: Dictionary) -> String:
	if saved.size() != loaded.size():
		return "se guardaron %d aldeanos y se cargaron %d" % [saved.size() - 1, loaded.size() - 1]
	for id: Variant in saved:
		if not loaded.has(id):
			return "no se cargó el carnet %s" % str(id)
		var a: Dictionary = saved[id]
		var b: Dictionary = loaded[id]
		for k: String in a:
			var same: bool = absf(a[k] - b[k]) < 0.01 if a[k] is float else a[k] == b[k]
			if not same:
				return "%s, %s: se guardó %s y se cargó %s" % [str(id), k, str(a[k]), str(b[k])]
	return ""

func _decorations() -> int:
	var n := 0
	for c in _world.props.get_children():
		if c is Decoration:
			n += 1
	return n

func _villagers() -> Array[Villager]:
	var out: Array[Villager] = []
	for node in get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.is_alive():
			out.append(v)
	return out

func _corpse() -> Villager:
	for node in get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.dead and not v.is_queued_for_deletion():
			return v
	return null

func _next() -> void:
	_step += 1
	_frame = 0

func _fail(why: String) -> bool:
	printerr("Prueba de humo: FALLÓ: " + why)
	quit(1)
	return true
