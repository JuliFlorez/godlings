extends SceneTree
## Capturas de pantalla de la interfaz para la CI (ver .github/workflows/checks.yml): el menú de
## inicio, el HUD de día y de noche, la barra de poderes (las dos pestañas, y apuntando), los modos
## del click, la tienda (cada pestaña), el carnet, el árbol, el cartel de la choza, el historial y la
## pausa. Sirve para ver la interfaz sin abrir el juego y para comparar antes y después de tocarla.
## Necesita dibujar de verdad (no --headless): en la CI corre con una pantalla virtual (xvfb).
## Arranca con una semilla fija, así los aldeanos salen iguales en cada corrida (lo que se mueve con
## el reloj, como las llamas o las frutas, cambia un poco).
## Correr con: godot --path . --fixed-fps 60 --script res://tools/ci/screenshots.gd -- --out=carpeta

const SLOT := 9                 # La ranura de prueba: fuera de las del menú, así no pisa una de verdad
const FPS := 60
const SEED := 1

var _out := ""
var _world: World
var _hud: HUD
var _count := 0

func _initialize() -> void:
	seed(SEED)
	SaveSlots.delete(SLOT)   # Siempre una partida nueva
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	if _out == "":
		_out = OS.get_user_data_dir().path_join("capturas")
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://world/world.tscn")
	_run()

func _run() -> void:
	await _frames(10)
	_world = current_scene as World
	if _world == null:
		_fail("no cargó el mundo")
		return
	await _seconds(TitleMenu.OPEN_FADE + 0.3)
	await _shot("title_main")
	var title := _world.title
	title._show(title._slots)
	await _seconds(TitleMenu.SCREEN_FADE + 0.2)
	await _shot("title_slots")
	title._show(title._options)
	await _seconds(TitleMenu.SCREEN_FADE + 0.2)
	await _shot("title_options")
	title._show(title._main)
	await _seconds(TitleMenu.SCREEN_FADE + 0.2)

	_world._start_slot(SLOT)
	_world._descent.set_speed_scale(40.0)
	var waited := 0
	while not _world.playing:
		await _frames(1)
		waited += 1
		if waited > FPS * 30:
			_fail("no llegó a la isla")
			return
	_hud = get_first_node_in_group("hud") as HUD
	_setup()
	await _seconds(4.0)
	await _shot("hud")

	_show_tab(true)
	await _seconds(0.3)
	await _shot("toolbar_good")
	_show_tab(false)
	var lightning := _power("lightning")
	if lightning:
		lightning.set_armed(true)
		await _seconds(0.3)
		await _shot("aiming")
		lightning.set_armed(false)

	_hud.set_select_mode(true)
	await _seconds(0.3)
	await _shot("select_mode")
	_hud.set_edit_mode(true)
	await _seconds(0.3)
	await _shot("edit_mode")
	_hud.set_drag_mode()

	for tab: Shop.Tab in [Shop.Tab.ISLAND, Shop.Tab.EVIL, Shop.Tab.GOOD, Shop.Tab.SKY]:
		_hud.open_shop(tab)
		await _seconds(0.3)
		await _shot("shop_%d" % tab)
	_hud._shop.close()

	var vs := _villagers()
	if not vs.is_empty():
		_hud.select_villager(vs[0])
		await _seconds(0.3)
		await _shot("villager_card")
		_hud._card.close()
		var kid := _kid(vs)
		_hud.open_family_tree(kid.id_number if kid else vs[0].id_number)
		await _seconds(0.3)
		await _shot("family_tree")
		_hud._family_tree.close()

	var hut := _hut()
	if hut:
		_hud.select_hut(hut)
		await _seconds(0.3)
		await _shot("hut_card")
		_hud._hut_card.close()

	_hud.toggle_history()
	await _seconds(0.3)
	await _shot("history")
	_hud.toggle_history()

	_hud._pause.open()
	await _seconds(0.3)
	await _shot("pause")
	_hud._pause.close()

	var sky = _world.get_node("Sky")   # (Sky no tiene class_name)
	sky.clock = sky.DAY_LENGTH + 20.0  # Ya de noche
	await _seconds(2.0)
	await _shot("night")

	print("Capturas: %d en %s" % [_count, _out])
	quit(0)

## Lo que tendría un jugador que ya avanzó (como en la prueba de humo): la isla grande, todos los
## poderes, ofrendas, chozas y decoraciones, más aldeanos, una pareja con un hijo y algo en el
## historial.
func _setup() -> void:
	_world.set_island_level(_world.max_level())
	for p in Power.all():
		p.unlocked = true
	Game.add_offerings(5000)
	Game.add_sacrifices(50)
	Game.fill_devotion()
	for kind: String in ["hut", "hut", "torch", "berries", "palm", "altar"]:
		var d := _decoration(kind)
		_world.props.add_child(d)
		d.global_position = _world._island_point()
	_world.debug_spawn_villagers(8)
	var vs := _villagers()
	if vs.size() >= 5:
		Relations.make(vs[0], vs[1], Relations.Kind.COUPLE)
		Relations.make(vs[2], vs[3], Relations.Kind.FRIEND)
		Relations.make(vs[3], vs[4], Relations.Kind.ENEMY)
		vs[4].parents.assign([vs[0].id_number, vs[1].id_number])
		Relations.note_birth(vs[0], vs[1])

## La pestaña de los poderes buenos o la de los malos. (Se llama por nombre porque la comparación
## corre este script también en el commit de antes, que puede tener otro HUD: la barra de abajo
## era parte del HUD hasta que pasó a PowerBar.)
func _show_tab(good: bool) -> void:
	var bar: Object = _hud.get("_bar")
	(bar if bar else _hud).call("_set_tab", good)

## Una decoración nueva de ese tipo. (La choza es una Hut desde que existe esa clase: se busca por
## nombre porque este script también corre en commits de antes, sin Hut ni Decoration.make.)
func _decoration(kind: String) -> Decoration:
	if kind == "hut":
		for c: Dictionary in ProjectSettings.get_global_class_list():
			if c["class"] == "Hut":
				return load(c["path"]).new()
	var d := Decoration.new()
	d.kind = kind
	return d

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(shot_name + ".png"))
	_count += 1
	print("Capturas: " + shot_name)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	await _frames(int(s * FPS))

func _power(id: String) -> Power:
	for p in Power.all():
		if p.id == id:
			return p
	return null

func _villagers() -> Array[Villager]:
	var out: Array[Villager] = []
	for node in get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.is_alive():
			out.append(v)
	return out

func _kid(vs: Array[Villager]) -> Villager:
	for v in vs:
		if not v.parents.is_empty():
			return v
	return null

func _hut() -> Decoration:
	for c in _world.props.get_children():
		if c is Decoration and (c as Decoration).kind == "hut":
			return c
	return null

func _fail(why: String) -> void:
	printerr("Capturas: FALLÓ: " + why)
	quit(1)
