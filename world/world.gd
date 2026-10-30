extends Node2D
class_name World
## El juego arranca con la cámara allá arriba, en el cielo, con el menú de inicio (ver
## TitleMenu); al elegir una partida la carga y la cámara baja atravesando las nubes hasta
## la isla (ver lift). Recién ahí empieza a correr el juego (playing).

@onready var isle: Polygon2D = $isle
@onready var isle_sprite: Sprite2D = $SpriteIsle
@onready var sea: Sea = $isle/waterRend

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
## Cada tantos segundos, cada aldeano vivo, sano y no muerto de hambre reza y deja ofrendas:
## más cuanto más cree en vos y más te teme (ver Villager.tribute).
@export var worship_interval: float = 10.0
## Con esta fe promedio en la isla la devoción se recarga a velocidad normal (ver HUD.faith_rate):
## con más, más rápido; con menos, más lento (sin parar del todo, así siempre se puede invocar).
const DEVOTION_FAITH := 65.0
const DEVOTION_RATE := Vector2(0.25, 1.5)

var island_level := 0
var island_poly_global: PackedVector2Array
var hud: HUD
var gun: Gun
var lightning: Lightning
var meteor: Meteor
var tornado: Tornado
var storm: Storm
var plague: Plague
var cure: Cure
var feed: Feed
var charms: Array[Charm] = []   # Cupido, la Discordia y la Amistad (por Charm.Kind)
var placer: DecorPlacer
var sharks: Array[Shark] = []
## Aldeanos y decoraciones, ordenados por Y para que el de adelante tape al de atrás.
var props: Node2D
## Manchas en el piso (charcos de sangre): siempre debajo de aldeanos y decoraciones.
var ground: Node2D
var _worship_t := 0.0
var _tribute := 0.0   # Lo que va quedando de ofrendas sueltas (cada rezo suma fracciones)
## Brotes de gripe (ver Villager.catch_flu): cada tanto (entre 10 y 20 minutos, unos 2 o 3 días),
## si hay suficientes aldeanos.
const OUTBREAK_EVERY := Vector2(600.0, 1200.0)
const OUTBREAK_MIN := 3
var _outbreak_t := randf_range(OUTBREAK_EVERY.x, OUTBREAK_EVERY.y)

var _base_poly_global: PackedVector2Array
var _base_sprite_scale: Vector2
var _pivot: Vector2
var _expanding := false
var _markers: Array[ExpandMarker] = []

## Partida guardada, en su ranura (ver SaveSlots). Va aparte de las opciones
## (user://settings.cfg), así borrar una partida no toca el volumen ni el idioma.
## Se guarda sola cada tanto, al salir y al volver al menú.
const AUTOSAVE_INTERVAL := 20.0
var _autosave_t := 0.0
## La partida que se está jugando (1..SaveSlots.COUNT); 0 = ninguna todavía (menú de inicio).
var slot := 0
## Ya llegó la cámara a la isla: corren los rezos, el tiempo de juego y el guardado.
var playing := false
## Segundos jugados en esta partida (se guarda con ella; ver Relations.history).
static var play_time := 0.0

## Menú de inicio: la cámara arranca INTRO_HEIGHT px más arriba, con el colchón de nubes
## (ver CloudBank) abajo de la pantalla. Al elegir partida baja: primero acelerando hasta
## salir de las nubes (CLOUDS_EXIT) y después frenando hasta la isla.
const INTRO_HEIGHT := 1860.0
const CLOUDS_EXIT := 600.0
const DIVE_TIME := 2.6
const LAND_TIME := 2.4
const SKIP_SPEED := 5.0        # Un click o una tecla mientras baja la apura
## Partida de noche: el sol se pone mientras la cámara se mete en las nubes, y termina
## antes de salir de ellas (si no, se lo vería bajando en el cielo ya de noche).
const SUNSET_TIME := 1.8
const NEW_GAME_HOUR := 0.3        # Una partida nueva arranca a media mañana (parte del día, ver Sky)
const HUD_FADE := 0.6
const MENU_FADE := 0.6         # Fundido a negro al volver al menú desde la pausa
var title: TitleMenu
var _descent: Tween
## Cuánto subió la cámara (px): 0 jugando, INTRO_HEIGHT en el menú de inicio. Corre el
## lienzo del mundo (la isla y todo lo que está encima) y el cielo, que se mueve a su
## manera (ver Sky.lift). El temblor del meteorito también corre el lienzo, pero solo se
## da jugando, con la cámara abajo.
var lift := 0.0:
	set(v):
		lift = v
		_apply_view()
		$Sky.lift = lift

## Zoom (rueda del mouse, + y -, o 0 para volver): agranda o achica el mundo hacia donde
## está el mouse, y de cerca se puede correr la vista arrastrando con la rueda apretada.
## El horizonte nunca baja de donde está (ahí el cielo, que está en su propia capa, se
## junta con el mar): alejándose se queda fijo, y de cerca solo puede subir. Solo jugando.
const ZOOM_MIN := 0.6
const ZOOM_MAX := 1.5
const ZOOM_STEP := 1.12          # Cada paso de la rueda
const ZOOM_SMOOTH := 12.0
var zoom := 1.0
var _zoom_target := 1.0
var _zoom_anchor := Vector2.ZERO # Punto de la pantalla que se queda quieto al hacer zoom
var _view := Vector2.ZERO        # Corrimiento de la vista (px de pantalla)
var _panning := false
## Temblor del meteorito (px de pantalla, ver Meteor).
var shake := Vector2.ZERO:
	set(v):
		shake = v
		_apply_view()

## Arma la vista: el zoom, la cámara subida (lift) y el temblor.
func _apply_view() -> void:
	get_viewport().canvas_transform = Transform2D(Vector2(zoom, 0.0), Vector2(0.0, zoom),
			_view + Vector2(0.0, lift) + shake)

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
		hud.menu_requested.connect(_to_title)

	# Últimos hijos: reciben los clicks antes que el sol/luna y los aldeanos
	gun = Gun.new()
	add_child(gun)
	lightning = Lightning.new()
	add_child(lightning)
	meteor = Meteor.new()
	add_child(meteor)
	tornado = Tornado.new()
	add_child(tornado)
	storm = Storm.new()
	add_child(storm)
	plague = Plague.new()
	add_child(plague)
	cure = Cure.new()
	add_child(cure)
	feed = Feed.new()
	add_child(feed)
	for k: Charm.Kind in Charm.KINDS:
		var c := Charm.new()
		c.kind = k
		add_child(c)
		charms.append(c)
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
		hud.tornado_toggled.connect(tornado.set_armed)
		tornado.armed_changed.connect(hud.set_tornado_armed)
		hud.plague_toggled.connect(plague.set_armed)
		plague.armed_changed.connect(hud.set_plague_armed)
		hud.cure_toggled.connect(cure.set_armed)
		cure.armed_changed.connect(hud.set_cure_armed)
		hud.feed_toggled.connect(feed.set_armed)
		feed.armed_changed.connect(hud.set_feed_armed)
		hud.charm_toggled.connect(func(k: Charm.Kind, on: bool): charms[k].set_armed(on))
		for c in charms:
			c.armed_changed.connect(hud.set_charm_armed.bind(c.kind))
		# El diluvio no se apunta: no guarda las armas ni ellas a él
		hud.storm_toggled.connect(storm.set_active)
		storm.active_changed.connect(hud.set_raining)
		hud.decoration_chosen.connect(func(k: String):
			_disarm()
			placer.start(k))
		# Al pasar a seleccionar (o a editar la isla), el click vuelve a ser para los aldeanos (o
		# para las decoraciones)
		for mode_changed: Signal in [hud.select_mode_changed, hud.edit_mode_changed]:
			mode_changed.connect(func(on: bool):
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
	play_time = 0.0
	Relations.clear()
	Genealogy.clear()
	_start_music()

	# Arranca en el cielo, con el menú de inicio; la partida se carga al elegirla
	SaveSlots.migrate()
	if hud:
		hud.visible = false   # Aparece al llegar a la isla (ver _on_landed)
	title = TitleMenu.new()
	title.world = self
	title.slot_chosen.connect(_start_slot)
	title.skip_requested.connect(func():
		if _descent and _descent.is_running():
			_descent.set_speed_scale(SKIP_SPEED))
	add_child(title)   # Último de todos: le llegan las teclas antes que al resto del juego
	lift = INTRO_HEIGHT
	title.open()

func _weapons() -> Array[Node]:
	var all: Array[Node] = [gun, lightning, meteor, tornado, plague, cure, feed]
	all.append_array(charms)
	return all

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
	if not playing:
		return
	_update_zoom(dt)
	if hud:
		hud.set_population(alive_villagers(), capacity())
		hud.faith_rate = _devotion_rate()
		_worship_t += dt
		if _worship_t >= worship_interval:
			_worship_t = 0.0
			_tribute += _prayers()
			var n := int(_tribute)
			_tribute -= n
			if n > 0:
				hud.add_offerings(n)
		_update_outbreak(dt)

	play_time += dt
	_autosave_t += dt
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		save_game()

func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					var k := ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
					_zoom_to(_zoom_target * k, event.position)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _panning:
		_view = _clamp_view(_view + event.relative, zoom)
		_apply_view()
	elif event is InputEventKey and event.pressed:
		var mid := get_viewport_rect().size * 0.5
		match event.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom_to(_zoom_target * ZOOM_STEP, mid)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_to(_zoom_target / ZOOM_STEP, mid)
			KEY_0, KEY_KP_0:
				_zoom_to(1.0, mid)
			_:
				return
		get_viewport().set_input_as_handled()

func _zoom_to(target: float, anchor: Vector2) -> void:
	_zoom_target = clampf(target, ZOOM_MIN, ZOOM_MAX)
	_zoom_anchor = anchor

## Lleva el zoom de a poco al que se pidió, dejando quieto lo que está debajo del mouse.
func _update_zoom(dt: float) -> void:
	if is_equal_approx(zoom, _zoom_target):
		return
	var world_p := (_zoom_anchor - _view) / zoom
	zoom = lerpf(zoom, _zoom_target, 1.0 - exp(-ZOOM_SMOOTH * dt))
	if absf(zoom - _zoom_target) < 0.001:
		zoom = _zoom_target
	_view = _clamp_view(_zoom_anchor - world_p * zoom, zoom)
	_apply_view()

## Para los costados: de cerca, que no se salga de lo que se ve sin zoom; de lejos, que eso
## quede adentro. Para arriba y abajo: el horizonte nunca más abajo de donde está, y de cerca
## tampoco más allá del borde de abajo de la pantalla sin zoom.
func _clamp_view(v: Vector2, z: float) -> Vector2:
	var size := get_viewport_rect().size
	var a := size.x * (1.0 - z)
	var top: float = $Sky.horizon_y * (1.0 - z)
	var bottom := size.y * (1.0 - z)
	return Vector2(clampf(v.x, minf(0.0, a), maxf(0.0, a)), top if bottom > top else clampf(v.y, bottom, top))

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

## Lo que dejan de ofrendas los que rezan (los vivos, sanos, no muertos de hambre y despiertos,
## ver Villager.tribute).
func _prayers() -> float:
	var sum := 0.0
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and not v.eaten and not v.drowning and not v.dead and not v.is_sick() and not v.starving() \
				and not v.is_sleeping() and not v.is_queued_for_deletion():
			sum += v.tribute()
	return sum

## Cuánto rinde la recarga de devoción según la fe promedio de la isla (sin nadie, normal).
func _devotion_rate() -> float:
	var sum := 0.0
	var n := 0
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and not v.eaten and not v.drowning and not v.dead and not v.is_queued_for_deletion():
			sum += v.faith
			n += 1
	if n == 0:
		return 1.0
	return clampf(sum / n / DEVOTION_FAITH, DEVOTION_RATE.x, DEVOTION_RATE.y)

func sick_villagers() -> int:
	var n := 0
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if villager and villager.is_sick() and not villager.is_queued_for_deletion():
			n += 1
	return n

## Cada tanto alguien se agarra la gripe solo (si no hay ya alguien con gripe dando vueltas).
func _update_outbreak(dt: float) -> void:
	_outbreak_t -= dt
	if _outbreak_t > 0.0:
		return
	_outbreak_t = randf_range(OUTBREAK_EVERY.x, OUTBREAK_EVERY.y)
	var healthy: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or v.dead or v.eaten:
			continue
		if v.flu == Villager.Flu.INCUBATING or v.flu == Villager.Flu.SICK:
			return
		if v.flu == Villager.Flu.HEALTHY and v.is_idle():
			healthy.append(v)
	if healthy.size() >= OUTBREAK_MIN:
		healthy.pick_random().catch_flu()

## Para la consola de trucos: n aldeanos sanos se agarran la gripe (ya con síntomas).
func debug_infect(n: int) -> int:
	var healthy: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.flu == Villager.Flu.HEALTHY and not v.dead and not v.eaten:
			healthy.append(v)
	healthy.shuffle()
	n = mini(n, healthy.size())
	for i in n:
		healthy[i].set_flu(Villager.Flu.SICK, randf_range(Villager.SICK_TIME.x, Villager.SICK_TIME.y))
	return n

func _spawn_villagers(n: int) -> void:
	if island_poly_global.size() == 0:
		return
	for i in n:
		add_villager(_island_point())

## Un aldeano nuevo en pos (también los bebés que nacen en las chozas, ver Decoration).
func add_villager(pos: Vector2) -> Villager:
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
## Cuánto se estira la isla (respecto al dibujo original) con ese ancho.
func _island_scale(w: float) -> Vector2:
	var t := inverse_lerp(ISLAND_LEVELS[0].width, ISLAND_LEVELS[max_level()].width, w)
	return Vector2(w, lerpf(HEIGHT_MIN, HEIGHT_MAX, t))

## Dónde queda el dibujo de la isla en la pantalla con ese tamaño (para las miniaturas
## de las partidas en el menú de inicio).
func island_rect(level: int) -> Rect2:
	var k := _island_scale(ISLAND_LEVELS[clampi(level, 0, max_level())].width)
	var size := isle_sprite.texture.get_size() * _base_sprite_scale * k
	return Rect2(_pivot - size * 0.5, size)

func _apply_island_width(w: float) -> void:
	var k := _island_scale(w)

	var global_pts := PackedVector2Array()
	var local_pts := PackedVector2Array()
	for p in _base_poly_global:
		var g := _pivot + (p - _pivot) * k
		global_pts.append(g)
		local_pts.append(isle.to_local(g))
	isle.polygon = local_pts
	isle_sprite.scale = _base_sprite_scale * k
	sea.fit_island(isle_sprite)
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
## de la isla, los aldeanos con su carnet y lo que se quieren entre ellos (con el historial,
## ver Relations), las decoraciones y cómo está el cielo.
## Lo que pasa en el momento no (cadáveres, cocos sueltos, aldeanos volando o en el
## agua): los vivos que no estaban parados en la isla aparecen en ella al cargar.
## Solo jugando: en el menú de inicio no hay partida, y mientras la cámara baja ya está
## guardada tal cual se cargó.
func save_game() -> void:
	if not playing or hud == null:
		return
	var decorations := []
	var deco_index := {}   # Decoration -> lugar en la lista (para saber en qué choza vive cada uno)
	for c in props.get_children():
		var d := c as Decoration
		if d:
			deco_index[d] = decorations.size()
			var entry := {"kind": d.kind, "pos": placer.resting_position(d), "variant": d.variant}
			if d.hut_name != "":
				entry.name = d.hut_name   # Lo que dice el cartel de la choza
			if d.stains > 0:
				entry.stains = d.stains   # La sangre del altar
			decorations.append(entry)
	var villagers := []
	var ids := []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v == null or v.dead or v.eaten or v.drowning or v.is_queued_for_deletion():
			continue
		var feet := v.global_position - Vector2(0, v._sleep_drop)   # Si está acostado durmiendo, parado
		var standing := (v.is_idle() or v.asleep) and Geometry2D.is_point_in_polygon(feet, island_poly_global)
		villagers.append({
			"pos": feet if standing else _island_point(),
			"id": v.id_number,
			"first_name": v.first_name,
			"last_name": v.last_name,
			"gender": v.gender,
			"flu": v.flu,
			"flu_t": v.flu_t,
			"faith": v.faith,
			"fear": v.fear,
			"hunger": v.hunger,
			"mood": v.mood,
			"tired": v.tiredness,
			"looks": [v.skin_tone, v.skin_warm, v.hair_color, v.height],
			"days": v.age,
			"lifespan_days": v.lifespan,
			"grey_days": v.grey_age,
			"parents": v.parents,
			"home": deco_index.get(v.home, -1) if v._home_ok() else -1,
		})
		ids.append(v.id_number)

	var sky := $Sky
	var cfg := ConfigFile.new()
	cfg.set_value("game", "hud", hud.save_state())
	cfg.set_value("island", "level", island_level)
	cfg.set_value("island", "villagers", villagers)
	cfg.set_value("island", "next_id", Villager.ids_issued)
	cfg.set_value("island", "relations", Relations.save_state(ids))
	cfg.set_value("island", "history", Relations.history)
	cfg.set_value("island", "family", Genealogy.save_state())   # Los que ya no están, para el árbol genealógico
	cfg.set_value("island", "decorations", decorations)
	cfg.set_value("sky", "night", sky.is_night)
	cfg.set_value("sky", "clock", sky.clock)
	cfg.set_value("sky", "day", sky.day)
	cfg.set_value("sky", "sun_creepy", sky.sun.creepy)
	cfg.set_value("sky", "moon_creepy", sky.moon.creepy)
	cfg.set_value("sky", "moon_fed", sky.moon.feed_level)
	cfg.set_value("meta", "saved_at", Time.get_unix_time_from_system())   # Para el menú de inicio
	cfg.set_value("meta", "play_time", play_time)
	cfg.save(SaveSlots.path(slot))

## Sigue la partida guardada en la ranura. false si estaba vacía (arranca una nueva).
func _load_game() -> bool:
	var cfg := ConfigFile.new()
	if hud == null or cfg.load(SaveSlots.path(slot)) != OK:
		return false
	play_time = cfg.get_value("meta", "play_time", 0.0)
	hud.load_state(cfg.get_value("game", "hud", {}))
	set_island_level(cfg.get_value("island", "level", island_level))
	var decos := []   # En el mismo orden que la lista guardada (null las que ya no existen)
	for d: Dictionary in cfg.get_value("island", "decorations", []):
		# Los arbustos comunes ya no están: los de las partidas de antes pasan a ser de bayas
		var kind: String = "berries" if d.get("kind") == "bush" else d.get("kind", "")
		if not Decoration.KINDS.has(kind):
			decos.append(null)
			continue
		var deco := Decoration.new()
		deco.kind = kind
		props.add_child(deco)
		deco.global_position = d.get("pos", _island_point())
		deco.variant = d.get("variant", deco.variant)   # Después de _ready, que elige una al azar
		deco.hut_name = d.get("name", "")
		deco.stains = d.get("stains", 0)
		decos.append(deco)
	var loaded: Array[Villager] = []
	for d: Dictionary in cfg.get_value("island", "villagers", []):
		var v := add_villager(d.get("pos", _island_point()))
		loaded.append(v)
		v.id_number = d.get("id", v.id_number)
		v.first_name = d.get("first_name", "")
		v.last_name = d.get("last_name", "")
		v.gender = d.get("gender", Villager.Gender.MALE)
		v.set_flu(d.get("flu", Villager.Flu.HEALTHY) as Villager.Flu, d.get("flu_t", 0.0))
		v.faith = d.get("faith", v.faith)
		v.fear = d.get("fear", v.fear)
		v.hunger = d.get("hunger", v.hunger)
		v.mood = d.get("mood", v.mood)
		v.tiredness = d.get("tired", v.tiredness)
		var looks: Array = d.get("looks", [])
		if looks.size() == 4:
			v.set_looks(looks[0], looks[1], looks[2], looks[3])
		var age := v.age   # La que le tocó en _ready
		if d.has("days"):
			age = d.days
			v.lifespan = d.get("lifespan_days", v.lifespan)
			v.grey_age = d.get("grey_days", v.grey_age)
		elif d.has("age"):
			# Partidas de antes, con la edad en segundos (años de 20 s): pasa a días en la misma etapa
			# de la vida (los 15 años de grande son los ADULT_AGE días de ahora)
			var to_days := Villager.ADULT_AGE / (15.0 * 20.0)
			if d.has("lifespan"):
				age = d.age * to_days
				v.lifespan = d.lifespan * to_days
				v.grey_age = clampf(d.get("grey_age", 0.0) * 20.0 * to_days, Villager.GREY_AGE.x, Villager.GREY_AGE.y)
			elif d.age < 15.0 * 20.0:
				age = d.age * to_days   # Y antes los grandes no envejecían: los chicos sí traen la suya
		v.set_age(age)
		v.parents.assign(d.get("parents", []))
		var h: int = d.get("home", -1)
		if h >= 0 and h < decos.size() and decos[h] != null and decos[h].kind == "hut":
			v.home = decos[h]
	Villager.ids_issued = cfg.get_value("island", "next_id", Villager.ids_issued)
	Relations.load_state(cfg.get_value("island", "relations", []))
	Relations.load_history(cfg.get_value("island", "history", []))
	Genealogy.load_state(cfg.get_value("island", "family", []))
	# Los que no tenían nombre (de antes de que salieran al azar, ver Names): uno nuevo, y el
	# apellido de sus padres si alguno lo tiene (de los más viejos a los más nuevos, así los padres
	# ya tienen el suyo)
	loaded.sort_custom(func(a: Villager, b: Villager) -> bool: return a.id_number < b.id_number)
	for v in loaded:
		if v.first_name == "":
			v.first_name = Names.first_name(get_tree(), v.gender == Villager.Gender.FEMALE)
		if v.last_name == "":
			for p: int in v.parents:
				var last: String = Genealogy.person(get_tree(), p).get("last", "")
				if last != "":
					v.last_name = last
					break
			if v.last_name == "":
				v.last_name = Names.last_name(get_tree())

	var sky := $Sky
	sky.day = cfg.get_value("sky", "day", 1)
	if cfg.get_value("sky", "night", false):
		sky.resume = cfg.get_value("sky", "clock", 0.0)
		sky.start_at_night(SUNSET_TIME)
	else:
		sky.clock = cfg.get_value("sky", "clock", NEW_GAME_HOUR * sky.DAY_LENGTH)
	if cfg.get_value("sky", "sun_creepy", false):
		sky.sun.set_creepy(true)
	if cfg.get_value("sky", "moon_creepy", false):
		sky.moon.set_creepy(true)
		sky.moon.feed_level = cfg.get_value("sky", "moon_fed", 0)
	return true

# ---- Menú de inicio ----
## Partida elegida en el menú de inicio: la carga (o arranca una nueva) y la cámara baja
## atravesando las nubes hasta la isla.
func _start_slot(s: int) -> void:
	slot = s
	if not _load_game():
		_spawn_villagers(mini(starting_villagers, capacity()))
		$Sky.clock = NEW_GAME_HOUR * $Sky.DAY_LENGTH
	_descent = create_tween()
	_descent.tween_property(self, "lift", CLOUDS_EXIT, DIVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_descent.tween_property(self, "lift", 0.0, LAND_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_descent.tween_callback(_on_landed)

func _on_landed() -> void:
	playing = true
	$Sky.running = true   # Desde ahora el día y la noche pasan solos
	title.landed()
	if hud:
		hud.reveal(HUD_FADE)

## "Menú principal" (menú de pausa): guarda, funde a negro y vuelve a cargar el mundo,
## que arranca otra vez en el cielo con el menú de inicio.
func _to_title() -> void:
	save_game()
	playing = false
	$Sky.running = false
	# Todo con el juego en pausa (el menú de pausa sigue abierto mientras se oscurece)
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	for p in [_music, _blood_music]:
		_music_tween.tween_property(p, "volume_db", SILENT_DB, MENU_FADE)
	title.fade_out(MENU_FADE).tween_callback(func():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		get_tree().paused = false
		get_tree().reload_current_scene())

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
