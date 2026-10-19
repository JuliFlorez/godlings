extends Node2D

@onready var isle: Polygon2D = $isle
@onready var isle_sprite: Sprite2D = $SpriteIsle

const VILLAGER := preload("res://actors/villager/villager.tscn")
const MUSIC := preload("res://audio/golden_hour_at_the_cove.mp3")
const BLOOD_MUSIC := preload("res://audio/the_moon_drinks_deep.mp3")

## Música de fondo: bien bajita, en loop. Entra con un fundido de unos segundos.
## Con la Luna de Sangre cambia a su propia canción (mismo volumen).
@export var music_volume_db: float = -26.0
const MUSIC_FADE_IN := 4.0
const MUSIC_CROSSFADE := 2.5
const SILENT_DB := -60.0

var _music: AudioStreamPlayer
var _blood_music: AudioStreamPlayer
var _music_tween: Tween

## Tamaños de la isla. "width" escala el ancho respecto al dibujo original
## y "capacity" es cuántos aldeanos pueden vivir a la vez en ese tamaño.
const ISLAND_LEVELS := [
	{"width": 0.55, "capacity": 5},
	{"width": 0.70, "capacity": 7},
	{"width": 0.85, "capacity": 10},
	{"width": 1.00, "capacity": 13},
	{"width": 1.15, "capacity": 17},
	{"width": 1.30, "capacity": 21},
	{"width": 1.45, "capacity": 26},
]
## La altura crece menos que el ancho para que la isla siga "acostada" sobre el agua
const HEIGHT_MIN := 0.8
const HEIGHT_MAX := 1.05

@export var spawn_devotion_cost: float = 10.0
@export var start_level: int = 0
@export var starting_villagers: int = 4
## Cada tantos segundos, cada aldeano vivo reza y deja una ofrenda.
@export var worship_interval: float = 10.0

var island_level := 0
var island_poly_global: PackedVector2Array
var hud: HUD
var gun: Gun
var lightning: Lightning
var meteor: Meteor
var placer: DecorPlacer
var sharks: Array[Shark] = []
## Aldeanos y decoraciones, ordenados por Y para que el de adelante tape al de atrás.
var props: Node2D
## Manchas en el piso (charcos de sangre): siempre debajo de aldeanos y decoraciones.
var ground: Node2D
var _worship_t := 0.0

var _base_poly_global: PackedVector2Array
var _base_sprite_scale: Vector2
var _pivot: Vector2
var _expanding := false
var _markers: Array[ExpandMarker] = []

## Partida guardada. Va aparte de las opciones (user://settings.cfg), así "Nueva partida"
## la borra sin tocar el volumen ni el idioma. Se guarda sola cada tanto y al salir.
const SAVE_PATH := "user://save.cfg"
const AUTOSAVE_INTERVAL := 20.0
var _autosave_t := 0.0
var _saving := true   # Se apaga al empezar de cero, para no volver a guardar lo que se borró

func _ready() -> void:
	# Capas sobre la isla y el tiburón: primero el piso, después lo que tiene altura
	ground = Node2D.new()
	ground.name = "Ground"
	ground.add_to_group("ground_layer")
	props = Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	# Tiburones: todos arrancan apagados hasta que se compran en la tienda
	sharks.append($Shark)
	for i in Shark.MAX - 1:
		var s: Shark = $Shark.duplicate()
		add_child(s)
		move_child(s, sharks[-1].get_index() + 1)
		sharks.append(s)
	var after := sharks[-1].get_index() + 1
	add_child(ground)
	move_child(ground, after)
	add_child(props)
	move_child(props, after + 1)

	for p in isle.polygon:
		_base_poly_global.append(isle.to_global(p))
	_base_sprite_scale = isle_sprite.scale
	_pivot = isle_sprite.global_position

	island_level = clampi(start_level, 0, max_level())
	_apply_island_width(ISLAND_LEVELS[island_level].width)

	_ensure_hud()
	if hud:
		hud.set_spawn_cost(spawn_devotion_cost)
		hud.set_island(island_level, max_level())
		hud.spawn_pressed.connect(_on_spawn_btn_pressed)
		hud.expand_pressed.connect(expand_island)
		hud.expansion_points_changed.connect(func(_p): _refresh_markers())
		hud.shark_changed.connect(func(i: int, on: bool): sharks[i].set_active(on))
		for i in sharks.size():
			sharks[i].killed.connect(hud.lose_shark.bind(i))
		hud.new_game_requested.connect(_new_game)

	# Últimos hijos: reciben los clicks antes que el sol/luna y los aldeanos
	gun = Gun.new()
	add_child(gun)
	lightning = Lightning.new()
	add_child(lightning)
	meteor = Meteor.new()
	add_child(meteor)
	placer = DecorPlacer.new()
	placer.hud = hud
	placer.props = props
	placer.island_poly = island_poly_global
	add_child(placer)
	if hud:
		hud.gun_toggled.connect(gun.set_armed)
		gun.armed_changed.connect(hud.set_gun_armed)
		hud.lightning_toggled.connect(lightning.set_armed)
		lightning.armed_changed.connect(hud.set_lightning_armed)
		hud.meteor_toggled.connect(meteor.set_armed)
		meteor.armed_changed.connect(hud.set_meteor_armed)
		hud.decoration_chosen.connect(func(k: String):
			_disarm()
			placer.start(k))
		# Al pasar a seleccionar, el click vuelve a ser para los aldeanos
		hud.select_mode_changed.connect(func(on: bool):
			if on:
				_disarm()
				if placer.is_active():
					placer.stop())
	# Sacar un arma o poder guarda los demás
	for w in _weapons():
		w.armed_changed.connect(func(on: bool):
			if on:
				_disarm(w)
				placer.stop())

	Villager.ids_issued = 0
	if not _load_game():
		_spawn_villagers(mini(starting_villagers, capacity()))
	_start_music()

func _weapons() -> Array[Node]:
	return [gun, lightning, meteor]

## Guarda las armas y poderes (menos keep).
func _disarm(keep: Node = null) -> void:
	for w in _weapons():
		if w != keep:
			w.set_armed(false)

func _start_music() -> void:
	_music = _make_music_player(MUSIC, "Music")
	_blood_music = _make_music_player(BLOOD_MUSIC, "BloodMusic")
	_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", music_volume_db, MUSIC_FADE_IN)
	$Sky.blood_moon_changed.connect(_on_blood_moon_changed)

func _make_music_player(stream: AudioStreamMP3, player_name: String) -> AudioStreamPlayer:
	stream.loop = true
	Settings.init()
	var p := AudioStreamPlayer.new()
	p.name = player_name
	p.stream = stream
	p.bus = Settings.MUSIC_BUS          # Lo controla la barra "Música" del menú de pausa
	p.process_mode = Node.PROCESS_MODE_ALWAYS   # Sigue sonando con el juego en pausa
	p.volume_db = SILENT_DB
	add_child(p)
	return p

## Fundido cruzado: la canción de la isla se pausa (y después sigue donde quedó),
## la de la Luna de Sangre arranca de cero cada vez.
func _on_blood_moon_changed(active: bool) -> void:
	var fade_in := _blood_music if active else _music
	var fade_out := _music if active else _blood_music
	if _music_tween:
		_music_tween.kill()
	if active and not _blood_music.playing:
		_blood_music.play()
	fade_in.stream_paused = false
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(fade_in, "volume_db", music_volume_db, MUSIC_CROSSFADE)
	_music_tween.tween_property(fade_out, "volume_db", SILENT_DB, MUSIC_CROSSFADE)
	_music_tween.chain().tween_callback(func():
		if active:
			_music.stream_paused = true
		else:
			_blood_music.stop())

func _process(dt: float) -> void:
	if hud:
		hud.set_population(alive_villagers(), capacity())
		_worship_t += dt
		if _worship_t >= worship_interval:
			_worship_t = 0.0
			var n := alive_villagers()
			if n > 0:
				hud.add_offerings(n)

	_autosave_t += dt
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		save_game()

func _notification(what: int) -> void:
	# Al cerrar la ventana (y desde "Salir del juego", que manda lo mismo)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _ensure_hud() -> void:
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud") as HUD

# ---- Población ----
func max_level() -> int:
	return ISLAND_LEVELS.size() - 1

func capacity() -> int:
	return ISLAND_LEVELS[island_level].capacity

func alive_villagers() -> int:
	var n := 0
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if villager and not villager.eaten and not villager.drowning and not villager.dead and not villager.is_queued_for_deletion():
			n += 1
	return n

func _spawn_villagers(n: int) -> void:
	if island_poly_global.size() == 0:
		return
	for i in n:
		_add_villager(_island_point())

func _add_villager(pos: Vector2) -> Villager:
	var v: Villager = VILLAGER.instantiate()
	v.global_position = pos
	v.island_poly = island_poly_global
	props.add_child(v)
	return v

## Un punto al azar dentro de la isla.
func _island_point() -> Vector2:
	var aabb := Rect2(island_poly_global[0], Vector2.ZERO)
	for p in island_poly_global:
		aabb = aabb.expand(p)
	return _rand_point_in_poly(island_poly_global, aabb)

func _rand_point_in_poly(poly: PackedVector2Array, box: Rect2) -> Vector2:
	for i in 200:
		var p := Vector2(
			randf_range(box.position.x, box.end.x),
			randf_range(box.position.y, box.end.y)
		)
		if Geometry2D.is_point_in_polygon(p, poly):
			return p
	return box.get_center()

func _on_spawn_btn_pressed() -> void:
	_ensure_hud()
	if alive_villagers() >= capacity():
		if hud:
			hud.popup_text("¡La isla está llena!", _pivot + Vector2(0, -120), HUD.C_WARN)
		return

	if hud:
		if hud.spend_energy(spawn_devotion_cost):
			_spawn_villagers(1)
		else:
			print("[WORLD] Devoción insuficiente para crear un aldeano (requiere %d)." % int(spawn_devotion_cost))
	else:
		# Fallback si no hay HUD presente
		_spawn_villagers(1)

# ---- Tamaño de la isla ----
func _apply_island_width(w: float) -> void:
	var t := inverse_lerp(ISLAND_LEVELS[0].width, ISLAND_LEVELS[max_level()].width, w)
	var k := Vector2(w, lerpf(HEIGHT_MIN, HEIGHT_MAX, t))

	var global_pts := PackedVector2Array()
	var local_pts := PackedVector2Array()
	for p in _base_poly_global:
		var g := _pivot + (p - _pivot) * k
		global_pts.append(g)
		local_pts.append(isle.to_local(g))
	isle.polygon = local_pts
	isle_sprite.scale = _base_sprite_scale * k
	island_poly_global = global_pts

	for v in get_tree().get_nodes_in_group("villager"):
		if v is Villager:
			v.island_poly = island_poly_global
	if placer:
		placer.island_poly = island_poly_global
	_place_markers()

func expand_island() -> void:
	if _expanding or island_level >= max_level():
		return
	_ensure_hud()
	if hud and not hud.spend_expansion_point():
		return

	_expanding = true
	_clear_markers()
	var from: float = ISLAND_LEVELS[island_level].width
	island_level += 1
	var to: float = ISLAND_LEVELS[island_level].width

	var tw := create_tween()
	tw.tween_method(_apply_island_width, from, to, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_expand_finished)

	_sand_burst(_edge_point(-1.0))
	_sand_burst(_edge_point(1.0))
	if hud:
		hud.set_island(island_level, max_level())
		hud.popup_text(tr("¡La isla creció! Capacidad: %d aldeanos") % capacity(), _pivot + Vector2(0, -130), HUD.C_EXPAND)

func _on_expand_finished() -> void:
	_expanding = false
	_refresh_markers()

# ---- Orbes de expansión ----
func _refresh_markers() -> void:
	var want := hud != null and hud.expansion_points > 0 and island_level < max_level() and not _expanding
	if want and _markers.is_empty():
		for side in [-1.0, 1.0]:
			var m := ExpandMarker.new()
			m.outward = side
			m.activated.connect(expand_island)
			add_child(m)
			_markers.append(m)
		_place_markers()
	elif not want:
		_clear_markers()

func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.dismiss()
	_markers.clear()

func _place_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.global_position = Vector2(_edge_point(m.outward).x - m.outward * 26.0, _pivot.y - 24.0)

## Punto más a la izquierda (side = -1) o a la derecha (side = 1) de la isla.
func _edge_point(side: float) -> Vector2:
	var best := _pivot
	for p in island_poly_global:
		if (p.x - best.x) * side > 0.0:
			best = p
	return best

## Salta directo a un nivel de isla, sin gastar puntos (consola de trucos y partida guardada).
func set_island_level(level: int) -> void:
	level = clampi(level, 0, max_level())
	if _expanding or level == island_level:
		return
	_clear_markers()
	island_level = level
	_apply_island_width(ISLAND_LEVELS[island_level].width)
	if hud:
		hud.set_island(island_level, max_level())
	_refresh_markers()

## Para la consola de trucos: aldeanos gratis (sin pasarse de la capacidad).
func debug_spawn_villagers(n: int) -> void:
	_spawn_villagers(clampi(n, 0, capacity() - alive_villagers()))

# ---- Partida guardada ----
## Guarda lo que hace a la partida: progreso y compras (ver HUD.save_state), el tamaño
## de la isla, los aldeanos con su carnet, las decoraciones y cómo está el cielo.
## Lo que pasa en el momento no (cadáveres, cocos sueltos, aldeanos volando o en el
## agua): los vivos que no estaban parados en la isla aparecen en ella al cargar.
func save_game() -> void:
	if not _saving or hud == null:
		return
	var villagers := []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or v.dead or v.eaten or v.drowning or v.is_queued_for_deletion():
			continue
		var standing := v.is_idle() and Geometry2D.is_point_in_polygon(v.global_position, island_poly_global)
		villagers.append({
			"pos": v.global_position if standing else _island_point(),
			"id": v.id_number,
			"first_name": v.first_name,
			"last_name": v.last_name,
			"gender": v.gender,
		})
	var decorations := []
	for c in props.get_children():
		var d := c as Decoration
		if d:
			decorations.append({"kind": d.kind, "pos": placer.resting_position(d), "variant": d.variant})

	var sky := $Sky
	var cfg := ConfigFile.new()
	cfg.set_value("game", "hud", hud.save_state())
	cfg.set_value("island", "level", island_level)
	cfg.set_value("island", "villagers", villagers)
	cfg.set_value("island", "next_id", Villager.ids_issued)
	cfg.set_value("island", "decorations", decorations)
	cfg.set_value("sky", "night", sky.moon.visible)
	cfg.set_value("sky", "sun_creepy", sky.sun.creepy)
	cfg.set_value("sky", "moon_creepy", sky.moon.creepy)
	cfg.set_value("sky", "moon_fed", sky.moon.feed_level)
	cfg.save(SAVE_PATH)

## Sigue la partida guardada. false si no había ninguna (arranca una nueva).
func _load_game() -> bool:
	var cfg := ConfigFile.new()
	if hud == null or cfg.load(SAVE_PATH) != OK:
		return false
	hud.load_state(cfg.get_value("game", "hud", {}))
	set_island_level(cfg.get_value("island", "level", island_level))
	for d: Dictionary in cfg.get_value("island", "decorations", []):
		if not Decoration.KINDS.has(d.get("kind")):
			continue
		var deco := Decoration.new()
		deco.kind = d.kind
		props.add_child(deco)
		deco.global_position = d.get("pos", _island_point())
		deco.variant = d.get("variant", deco.variant)   # Después de _ready, que elige una al azar
	for d: Dictionary in cfg.get_value("island", "villagers", []):
		var v := _add_villager(d.get("pos", _island_point()))
		v.id_number = d.get("id", v.id_number)
		v.first_name = d.get("first_name", "")
		v.last_name = d.get("last_name", "")
		v.gender = d.get("gender", Villager.Gender.MALE)
	Villager.ids_issued = cfg.get_value("island", "next_id", Villager.ids_issued)

	var sky := $Sky
	if cfg.get_value("sky", "night", false):
		sky.start_at_night()
	if cfg.get_value("sky", "sun_creepy", false):
		sky.sun.set_creepy(true)
	if cfg.get_value("sky", "moon_creepy", false):
		sky.moon.set_creepy(true)
		sky.moon.feed_level = cfg.get_value("sky", "moon_fed", 0)
	return true

## "Nueva partida" (menú de pausa): borra lo guardado y arranca de cero.
func _new_game() -> void:
	_saving = false
	DirAccess.remove_absolute(SAVE_PATH)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().paused = false
	get_tree().reload_current_scene()

func _sand_burst(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 36
	p.lifetime = 0.8
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 520)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.86, 0.45)
	p.z_index = 15
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
