extends Node2D
## Estrellas que titilan de noche. El cielo controla su alfa (modulate.a).

@export var count := 90
var max_y := 400.0

var _stars: Array[Vector3] = []   # x, y, fase
var _t := 0.0

func _ready() -> void:
	var w := get_viewport_rect().size.x
	for i in count:
		_stars.append(Vector3(randf() * w, randf() * max_y, randf() * TAU))

func _process(dt: float) -> void:
	if modulate.a <= 0.01:
		return
	_t += dt
	queue_redraw()

func _draw() -> void:
	for s in _stars:
		var a := 0.55 + 0.45 * sin(_t * 2.0 + s.z)
		draw_circle(Vector2(s.x, s.y), 1.0 + fmod(s.z, 1.0), Color(1, 1, 0.9, a))
