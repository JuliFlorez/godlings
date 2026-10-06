extends Node2D

@onready var isle: Polygon2D = $isle
@onready var isle_sprite: Sprite2D = $SpriteIsle

const VILLAGER := preload("res://actors/villager/villager.tscn")

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

var island_level := 0
var island_poly_global: PackedVector2Array
var hud: HUD
var gun: Gun

var _base_poly_global: PackedVector2Array
var _base_sprite_scale: Vector2
var _pivot: Vector2
var _expanding := false
var _markers: Array[ExpandMarker] = []

func _ready() -> void:
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

	# Último hijo: recibe los clicks antes que el sol/luna y los aldeanos
	gun = Gun.new()
	add_child(gun)
	if hud:
		hud.gun_toggled.connect(gun.set_armed)
		gun.armed_changed.connect(hud.set_gun_armed)

	_spawn_villagers(mini(starting_villagers, capacity()))

func _process(_dt: float) -> void:
	if hud:
		hud.set_population(alive_villagers(), capacity())

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

	var aabb := Rect2(island_poly_global[0], Vector2.ZERO)
	for p in island_poly_global:
		aabb = aabb.expand(p)

	for i in n:
		var v := VILLAGER.instantiate()
		v.global_position = _rand_point_in_poly(island_poly_global, aabb)
		v.island_poly = island_poly_global
		add_child(v)

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
		hud.popup_text("¡La isla creció! Capacidad: %d aldeanos" % capacity(), _pivot + Vector2(0, -130), HUD.C_EXPAND)

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
