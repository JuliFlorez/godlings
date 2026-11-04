extends Node2D
class_name World
## El juego arranca con la cámara allá arriba, en el cielo, con el menú de inicio (ver
## TitleMenu); al elegir una partida la carga y la cámara baja atravesando las nubes hasta
## la isla (ver lift). Recién ahí empieza a correr el juego (playing).

## La versión del juego: la que dice el menú de inicio (ver TitleMenu). Va acá y no se lee de
## project.godot porque el editor, si está abierto, lo vuelve a guardar con lo que tenía y la
## borra. (Al cambiarla, también en project.godot y en export_presets.cfg.)
const VERSION := "0.1"

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
## Con esta fe promedio en la isla la devoción se recarga a velocidad normal (ver Game.refill):
## con más, más rápido; con menos, más lento (sin parar del todo, así siempre se puede invocar).
const DEVOTION_FAITH := 65.0
const DEVOTION_RATE := Vector2(0.25, 1.5)

var island_level := 0
var island_poly_global: PackedVector2Array
var hud: HUD
var placer: DecorPlacer
var sharks: Array[Shark] = []
## Aldeanos y decoraciones, ordenados por Y para que el de adelante tape al de atrás.
var props: Node2D
## Manchas en el piso (charcos de sangre): siempre debajo de aldeanos y decoraciones.
var ground: Node2D
var _worship_t := 0.0
var _tribute := 0.0   # Lo que va quedando de ofrendas sueltas (cada rezo suma fracciones)
## Cada tanto le avisa al HUD cuánto están dejando entre todos (abajo de las ofrendas).
const TRIBUTE_SHOW_EVERY := 0.5
var _tribute_show_t := 0.0
## Brotes de gripe (ver VillagerFlu.catch_flu): cada tanto (entre 10 y 20 minutos, unos 2 o 3 días),
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
var _save_failed := false   # El último guardado falló (el aviso sale una vez, hasta que vuelva a andar)
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
## está el mouse. La vista se corre con las flechas o arrastrando con la rueda apretada,
## con o sin zoom: hasta un poco más allá de lo que se ve normalmente (ver PAN_MARGIN).
## El horizonte nunca baja de donde está (ahí el cielo, que está en su propia capa, se
## junta con el mar): para arriba se puede volver hasta ahí y no más. 0 también centra la
## vista. Solo jugando.
const ZOOM_MIN := 0.6
const ZOOM_MAX := 1.5
const ZOOM_STEP := 1.12          # Cada paso de la rueda
const ZOOM_SMOOTH := 12.0
## Cuánto más allá de lo de siempre se puede correr la vista, en parte de la pantalla (de
## mundo: lo mismo con cualquier zoom). Para los costados y para abajo; el mar alcanza.
const PAN_MARGIN := Vector2(0.35, 0.3)
const PAN_SPEED := 650.0         # Con las flechas (px de pantalla por segundo)
const PAN_SMOOTH := 10.0         # Qué tan rápido arranca y frena
var zoom := 1.0
var _zoom_target := 1.0
var _zoom_anchor := Vector2.ZERO # Punto de la pantalla que se queda quieto al hacer zoom
var _view := Vector2.ZERO        # Corrimiento de la vista (px de pantalla)
var _panning := false
var _pan_vel := Vector2.ZERO     # Con las flechas (px de pantalla por segundo)
var _homing := false             # Volviendo al tamaño normal y al centro (tecla 0)
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
	Game.reset()   # Una partida nueva (la guardada se carga al elegirla, ver _start_slot)
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

	Game.set_island(island_level, max_level())
	Game.events.expansion_points_changed.connect(func(_p): _refresh_markers())
	Game.events.shark_changed.connect(func(i: int, on: bool): sharks[i].set_active(on))
	for i in sharks.size():
		sharks[i].killed.connect(func(): Game.lose_shark(i))
	_ensure_hud()
	if hud:
		hud.set_spawn_cost(spawn_devotion_cost)
		hud.spawn_pressed.connect(_on_spawn_btn_pressed)
		hud.expand_pressed.connect(expand_island)
		hud.menu_requested.connect(_to_title)

	# Últimos hijos: reciben los clicks antes que el sol/luna y los aldeanos
	for power in _create_powers():
		add_child(power)
	placer = DecorPlacer.new()
	placer.hud = hud
	placer.props = props
	placer.island_poly = island_poly_global
	add_child(placer)
	if hud:
		hud.set_powers(Power.all())   # Sus slots en la barra
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
	# Sacar un arma o poder guarda los demás (el diluvio no se apunta: ni los guarda ni lo guardan)
	for power in Power.all():
		if power.aims:
			power.armed_changed.connect(func(on: bool):
				if on:
					_disarm(power)
					placer.stop())

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

## Los poderes, en el orden de la barra (ver HUD): primero los malos y después los buenos. Uno
## nuevo va acá (ver Power).
func _create_powers() -> Array[Power]:
	var list: Array[Power] = [Gun.new(), Lightning.new(), Meteor.new(), Tornado.new(), Storm.new(),
			Plague.new(), Spore.new(), Charm.make(Charm.Kind.DISCORD), Feed.new(), Cure.new(),
			Miracle.make(Miracle.Kind.VACCINE), Miracle.make(Miracle.Kind.SHIELD),
			Miracle.make(Miracle.Kind.RESURRECT), Charm.make(Charm.Kind.CUPID),
			Charm.make(Charm.Kind.FRIENDSHIP)]
	return list

## Guarda los poderes que se apuntan (menos keep; el diluvio no, ver Power.aims).
func _disarm(keep: Power = null) -> void:
	for power in Power.all():
		if power.aims and power != keep:
			power.set_armed(false)

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
	_update_home(dt)
	_update_zoom(dt)
	_update_pan(dt)
	Game.refill(dt, _devotion_rate())
	_worship_t += dt
	if _worship_t >= worship_interval:
		_worship_t = 0.0
		_tribute += _prayers()
		var n := int(_tribute)
		_tribute -= n
		if n > 0:
			Game.add_offerings(n)
	_update_outbreak(dt)
	if hud:
		hud.set_population(alive_villagers(), capacity())
		_tribute_show_t -= dt
		if _tribute_show_t <= 0.0:
			_tribute_show_t = TRIBUTE_SHOW_EVERY
			hud.set_tribute(_prayers(), worship_interval)

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
				_homing = false
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
				_zoom_target = 1.0
				_homing = true
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				pass   # Las mira _update_pan mientras estén apretadas
			_:
				return
		get_viewport().set_input_as_handled()

func _zoom_to(target: float, anchor: Vector2) -> void:
	_zoom_target = clampf(target, ZOOM_MIN, ZOOM_MAX)
	_zoom_anchor = anchor
	_homing = false

## Tecla 0: vuelve de a poco al tamaño normal y al centro.
func _update_home(dt: float) -> void:
	if not _homing:
		return
	var k := 1.0 - exp(-ZOOM_SMOOTH * dt)
	zoom = lerpf(zoom, 1.0, k)
	_view = _view.lerp(Vector2.ZERO, k)
	if absf(zoom - 1.0) < 0.001 and _view.length() < 0.5:
		zoom = 1.0
		_view = Vector2.ZERO
		_homing = false
	_view = _clamp_view(_view, zoom)
	_apply_view()

## Flechas: corren la vista mientras estén apretadas (arranca y frena suave). No mientras
## se escribe un nombre (en el carnet, en el cartel de una choza o en la consola).
func _update_pan(dt: float) -> void:
	var dir := Vector2.ZERO
	var focus := get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit):
		dir = Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
				float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))).normalized()
	if dir != Vector2.ZERO:
		_homing = false
	_pan_vel = _pan_vel.lerp(dir * PAN_SPEED, 1.0 - exp(-PAN_SMOOTH * dt))
	if dir == Vector2.ZERO and _pan_vel.length_squared() < 1.0:
		_pan_vel = Vector2.ZERO
		return
	_view = _clamp_view(_view - _pan_vel * dt, zoom)   # La cámara va para un lado y el mundo para el otro
	_apply_view()

## Lleva el zoom de a poco al que se pidió, dejando quieto lo que está debajo del mouse.
func _update_zoom(dt: float) -> void:
	if _homing or is_equal_approx(zoom, _zoom_target):
		return
	var world_p := (_zoom_anchor - _view) / zoom
	zoom = lerpf(zoom, _zoom_target, 1.0 - exp(-ZOOM_SMOOTH * dt))
	if absf(zoom - _zoom_target) < 0.001:
		zoom = _zoom_target
	_view = _clamp_view(_zoom_anchor - world_p * zoom, zoom)
	_apply_view()

## Para los costados: de cerca, que no se salga de lo que se ve sin zoom; de lejos, que eso
## quede adentro; y en los dos casos, hasta PAN_MARGIN más allá. Para arriba y abajo: el
## horizonte nunca más abajo de donde está, y para abajo hasta PAN_MARGIN más allá del borde
## de abajo de la pantalla sin zoom.
func _clamp_view(v: Vector2, z: float) -> Vector2:
	var size := get_viewport_rect().size
	var m := size * PAN_MARGIN * z   # El margen es de mundo: en px de pantalla, con el zoom
	var a := size.x * (1.0 - z)
	var top: float = $Sky.horizon_y * (1.0 - z)
	var bottom := size.y * (1.0 - z) - m.y
	return Vector2(clampf(v.x, minf(0.0, a) - m.x, maxf(0.0, a) + m.x), top if bottom > top else clampf(v.y, bottom, top))

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

## Los que ocupan lugar en la isla (ver Villager.is_alive): también el que se está ahogando, que
## todavía se puede rescatar. Los cadáveres no, pero resucitar pide lugar (ver Miracle._problem).
func alive_villagers() -> int:
	var n := 0
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if villager and villager.is_alive():
			n += 1
	return n

## Lo que dejan de ofrendas los que rezan (los vivos, sanos, no muertos de hambre y despiertos,
## ver Villager.prays y tribute). Con hongos (o zombis) no rezan.
func _prayers() -> float:
	var sum := 0.0
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.prays():
			sum += v.tribute()
	return sum

## Cuánto rinde la recarga de devoción según la fe promedio de la isla (sin nadie, normal).
func _devotion_rate() -> float:
	var sum := 0.0
	var n := 0
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.is_alive():
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
		if v == null or not v.is_alive():
			continue
		if v.has_flu():
			return
		if v.flu == VillagerFlu.Stage.HEALTHY and v.is_idle() and not v.protected_from_disease():
			healthy.append(v)
	if healthy.size() >= OUTBREAK_MIN:
		healthy.pick_random().catch_flu()

## Para la consola de trucos: a n aldeanos sin la espora se les mete (zombie: ya hechos zombis).
func debug_spore(n: int, zombie := false) -> int:
	var healthy: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.is_alive() and not v.inside \
				and not v.protected_from_disease() and (v.spore <= 0.0 or (zombie and not v.is_zombie())):
			healthy.append(v)
	healthy.shuffle()
	n = mini(n, healthy.size())
	for i in n:
		healthy[i].catch_spore()
		if zombie:
			healthy[i].spore = VillagerSpore.SPORE_ZOMBIE_AT
	return n

## Para la consola de trucos (y probar la resurrección): n aldeanos parados en la isla mueren de un
## tiro. Devuelve cuántos.
func debug_kill(n: int) -> int:
	var alive: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.is_idle() and not v.is_queued_for_deletion():
			alive.append(v)
	alive.shuffle()
	n = mini(n, alive.size())
	for i in n:
		var v := alive[i]
		var side := 1.0 if randf() < 0.5 else -1.0
		v.shoot(v.body_center() + Vector2(-side * 6.0, -4.0), Vector2(side, -0.1))
	return n

## Para la consola de trucos: n aldeanos sanos se agarran la gripe (ya con síntomas).
func debug_infect(n: int) -> int:
	var healthy: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.flu == VillagerFlu.Stage.HEALTHY and v.is_alive():
			healthy.append(v)
	healthy.shuffle()
	n = mini(n, healthy.size())
	for i in n:
		healthy[i].set_flu(VillagerFlu.Stage.SICK, randf_range(VillagerFlu.SICK_TIME.x, VillagerFlu.SICK_TIME.y))
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
	if alive_villagers() >= capacity():
		Game.say("¡La isla está llena!", _pivot + Vector2(0, -120), HUD.C_WARN)
		return
	# Sin devoción suficiente el + ya está apagado (ver HUD._refresh)
	if Game.spend_devotion(spawn_devotion_cost):
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
	if _expanding or island_level >= max_level() or not Game.spend_expansion_point():
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
	Game.set_island(island_level, max_level())
	Game.say(tr("¡La isla creció! Capacidad: %d aldeanos") % capacity(), _pivot + Vector2(0, -130), HUD.C_EXPAND)

func _on_expand_finished() -> void:
	_expanding = false
	_refresh_markers()

# ---- Orbes de expansión ----
func _refresh_markers() -> void:
	var want := Game.expansion_points > 0 and island_level < max_level() and not _expanding
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
	Game.set_island(island_level, max_level())
	_refresh_markers()

## Para la consola de trucos: aldeanos gratis (sin pasarse de la capacidad).
func debug_spawn_villagers(n: int) -> void:
	_spawn_villagers(clampi(n, 0, capacity() - alive_villagers()))

# ---- Partida guardada ----
## Guarda lo que hace a la partida: progreso y compras (ver Game.save_state), el tamaño
## de la isla, los aldeanos con su carnet y lo que se quieren entre ellos (con el historial,
## ver Relations), las decoraciones y cómo está el cielo.
## Lo que pasa en el momento no (cadáveres, cocos sueltos, aldeanos volando o en el
## agua): los vivos que no estaban parados en la isla aparecen en ella al cargar.
## Solo jugando: en el menú de inicio no hay partida, y mientras la cámara baja ya está
## guardada tal cual se cargó.
func save_game() -> void:
	if not playing:
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
		if v == null or not v.is_alive() or v.drowning:   # El que se está hundiendo no se guarda
			continue
		var feet := v.global_position - Vector2(0, v.sleep_drop)   # Si está acostado durmiendo, parado
		var standing := (v.is_idle() or v.asleep) and Geometry2D.is_point_in_polygon(feet, island_poly_global)
		villagers.append({
			"pos": feet if standing else _island_point(),
			"id": v.id_number,
			"first_name": v.first_name,
			"last_name": v.last_name,
			"gender": v.gender,
			"flu": v.flu,
			"flu_t": v.flu_t,
			"spore": v.spore,
			"shield": v.shield_t,
			"vaccine": v.vaccine_t,
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
	cfg.set_value("game", "hud", Game.save_state())   # (Se llama "hud" porque antes lo tenía él)
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
	cfg.set_value("meta", "version", SaveSlots.VERSION)
	cfg.set_value("meta", "saved_at", Time.get_unix_time_from_system())   # Para el menú de inicio
	cfg.set_value("meta", "play_time", play_time)
	var err := SaveSlots.write(slot, cfg)
	if err != OK:
		push_error("No se pudo guardar la partida %d: %s" % [slot, error_string(err)])
		if not _save_failed:
			Game.announce("No se pudo guardar la partida", HUD.C_WARN)
	_save_failed = err != OK

## Sigue la partida guardada en la ranura. false si estaba vacía (arranca una nueva). Si el archivo
## está roto, sigue desde la copia (ver SaveSlots.read); el menú no deja elegir una ranura dañada.
func _load_game() -> bool:
	var cfg := SaveSlots.read(slot)
	if cfg == null:
		return false
	var version: int = cfg.get_value("meta", "version", 0)   # 0: de antes de que tuviera versión
	if version > SaveSlots.VERSION:
		push_warning("La partida %d es de una versión más nueva del juego (formato %d)" % [slot, version])
	play_time = cfg.get_value("meta", "play_time", 0.0)
	Game.load_state(cfg.get_value("game", "hud", {}))
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
		v.set_flu(d.get("flu", VillagerFlu.Stage.HEALTHY) as VillagerFlu.Stage, d.get("flu_t", 0.0))
		v.set_spore(d.get("spore", 0.0))
		# Después de la espora (si no, el escudo no la dejaría volver a meterse)
		if d.get("shield", 0.0) > 0.0:
			v.give_shield(d.shield, false)
		if d.get("vaccine", 0.0) > 0.0:
			v.vaccinate(d.vaccine, false)
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
