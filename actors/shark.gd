extends Node2D
class_name Shark
## Tiburón: una aleta triangular que patrulla el agua y se come
## a los aldeanos que están flotando.
## Arranca apagado: se compran en la tienda (hasta MAX) y se pueden apagar y prender.

const PRICE := 40
const MAX := 2

@export var water_path: NodePath
@export var patrol_speed := 60.0
@export var hunt_speed := 170.0
@export var bite_range := 16.0
@export var bite_cooldown := 1.5

const FIN_COLOR := Color(0.28, 0.32, 0.38)
# Aleta mirando a la derecha, base apoyada en y = 0
const FIN_BACK := Vector2(-12, 0)
const FIN_FRONT := Vector2(14, 0)
const FIN_TIP := Vector2(-5, -28)

var water_rect := Rect2(0, 570, 1150, 76)
var dir := 1.0
var _t := 0.0
var _cooldown := 0.0
var _dive := 0.0   # 0 = aleta afuera, 1 = sumergida (mientras muerde)
var active := false
var _tween: Tween

func _ready() -> void:
	var water := get_node_or_null(water_path)
	if water and water.has_method("get_global_rect"):
		water_rect = water.get_global_rect()
	global_position = Vector2(randf_range(_left(), _right()), water_rect.position.y)
	dir = 1.0 if randf() < 0.5 else -1.0
	visible = false
	set_process(false)

## Prendido: emerge en un lugar al azar del agua. Apagado: se sumerge y deja de cazar.
func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if on:
		global_position.x = randf_range(_left(), _right())
		_dive = 1.0
		visible = true
		set_process(true)
		_tween.tween_property(self, "_dive", 0.0, 0.5)
	else:
		_tween.tween_property(self, "_dive", 1.0, 0.3)
		_tween.tween_callback(func():
			visible = false
			set_process(false))

func _left() -> float:
	return water_rect.position.x + 20.0

func _right() -> float:
	return water_rect.end.x - 20.0

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt

	var speed := patrol_speed
	var prey := _find_prey() if active and _cooldown <= 0.0 else null
	if prey:
		var dx := prey.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = signf(dx)
		speed = hunt_speed
		if absf(dx) < bite_range:
			_bite(prey)

	global_position.x += dir * speed * dt
	if global_position.x < _left():
		dir = 1.0
	elif global_position.x > _right():
		dir = -1.0
	global_position.x = clampf(global_position.x, _left(), _right())
	global_position.y = water_rect.position.y + 3.0 + sin(_t * 3.0) * 2.0
	queue_redraw()

func _find_prey() -> Villager:
	var best: Villager = null
	var best_d := INF
	for v in get_tree().get_nodes_in_group("villager"):
		var villager := v as Villager
		if villager == null or not villager.in_water or villager.drowning or villager.dragging or villager.eaten:
			continue
		var d := absf(villager.global_position.x - global_position.x)
		if d < best_d:
			best_d = d
			best = villager
	return best

func _bite(prey: Villager) -> void:
	prey.get_eaten()
	_cooldown = bite_cooldown
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_dive", 1.0, 0.15)
	_tween.tween_interval(0.6)
	_tween.tween_property(self, "_dive", 0.0, 0.4)

func _draw() -> void:
	# Al sumergirse, la línea del agua "corta" la aleta: se dibuja solo la punta
	var k := 1.0 - _dive
	if k <= 0.02:
		return
	var tip := FIN_TIP + Vector2(0, -FIN_TIP.y * _dive)
	var pts := PackedVector2Array([
		tip + (FIN_BACK - FIN_TIP) * k,
		tip,
		tip + (FIN_FRONT - FIN_TIP) * k,
	])
	for i in pts.size():
		pts[i].x *= dir
	draw_colored_polygon(pts, FIN_COLOR)

	# Estela de espuma
	var foam := Color(1, 1, 1, 0.6 * k)
	var wobble := sin(_t * 8.0) * 2.0
	draw_line(Vector2(-dir * 16.0, 1), Vector2(-dir * (34.0 + wobble), 2), foam, 2.0)
	draw_line(Vector2(dir * 16.0, 1), Vector2(dir * 22.0, 0), foam, 2.0)
