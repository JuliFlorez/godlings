extends Node2D

@onready var isle: Polygon2D = $isle
@onready var spawn_btn: Button = get_node_or_null("UI/SpawnBtn")

const VILLAGER := preload("res://actors/Villager.tscn")

var island_poly_global: PackedVector2Array
var hud: HUD

@export var spawn_devotion_cost: float = 10.0

func _ready() -> void:
	island_poly_global = []
	for p in isle.polygon:
		island_poly_global.append(isle.to_global(p))

	_ensure_hud()

	if spawn_btn:
		spawn_btn.text = "Spawn Villager\n(-%d Devotion)" % int(spawn_devotion_cost)

	_spawn_villagers(8)

func _ensure_hud() -> void:
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud") as HUD

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

	if hud:
		if hud.spend_energy(spawn_devotion_cost):
			_spawn_villagers(1)
		else:
			print("[WORLD] Devoción insuficiente para crear un aldeano (requiere %d)." % int(spawn_devotion_cost))
	else:
		# Fallback si no hay HUD presente
		_spawn_villagers(1)
