extends Node2D
class_name Birds
## Gaviotas: de vez en cuando cruza el cielo una bandadita (de una a tres), que aletea un
## rato y planea otro. Las de más abajo están más lejos: más chicas y más lentas.
## Al atardecer se ven como siluetas oscuras y de noche no salen.

const GAP := Vector2(14.0, 35.0)    # Segundos entre una bandada y la siguiente
const MIN_Y := 90.0
const MAX_Y := 300.0
const MARGIN := 40.0
const C_DAY := Color(0.26, 0.29, 0.36)
const C_DUSK := Color(0.12, 0.08, 0.16)

var _birds := []   # {pos, vel, size, wing (fase), beat (1 = aleteando), flapping, mode_t}
var _wait := 0.0
var _sky: Node

func _ready() -> void:
	_wait = randf_range(3.0, 8.0)   # La primera sale enseguida

func _night() -> float:
	if _sky == null:
		_sky = get_tree().get_first_node_in_group("sky")
	return _sky.night if _sky else 0.0

func _process(dt: float) -> void:
	var night := _night()
	modulate.a = 1.0 - smoothstep(0.65, 0.8, night)
	_wait -= dt
	if _wait <= 0.0:
		_wait = randf_range(GAP.x, GAP.y)
		if night < 0.65:
			_spawn_flock()
	if _birds.is_empty():
		return

	var w := get_viewport_rect().size.x
	for b in _birds:
		b.pos += b.vel * dt
		b.wing += dt * 11.0
		b.mode_t -= dt
		if b.mode_t <= 0.0:
			b.flapping = not b.flapping
			b.mode_t = randf_range(1.0, 2.2) if b.flapping else randf_range(1.5, 3.5)
		b.beat = move_toward(b.beat, 1.0 if b.flapping else 0.0, 3.0 * dt)
		b.pos.y += (-14.0 if b.flapping else 6.0) * b.beat * dt   # Aleteando sube, planeando baja
	_birds = _birds.filter(func(b: Dictionary): return b.pos.x > -MARGIN and b.pos.x < w + MARGIN)
	queue_redraw()

func _spawn_flock() -> void:
	var w := get_viewport_rect().size.x
	var dir := 1.0 if randf() < 0.5 else -1.0
	var y := randf_range(MIN_Y, MAX_Y)
	var far := inverse_lerp(MIN_Y, MAX_Y, y)
	var size := lerpf(1.35, 0.75, far)
	var speed := randf_range(45.0, 65.0) * size
	for i in randi_range(1, 3):
		var flapping := randf() < 0.7
		_birds.append({
			"pos": Vector2(-MARGIN * 0.5 if dir > 0.0 else w + MARGIN * 0.5, y) - Vector2(dir * i * 26.0, randf_range(-14.0, 14.0)) * size,
			"vel": Vector2(dir * speed * randf_range(0.95, 1.05), 0.0),
			"size": size * randf_range(0.9, 1.1),
			"wing": randf() * TAU,
			"beat": 1.0 if flapping else 0.0,
			"flapping": flapping,
			"mode_t": randf_range(0.5, 2.0),
		})

func _draw() -> void:
	var col := C_DAY.lerp(C_DUSK, smoothstep(0.3, 0.7, _night()))
	for b in _birds:
		var s: float = b.size
		var p: Vector2 = b.pos
		var up: float = sin(b.wing) * b.beat + 0.3 * (1.0 - b.beat)   # 1 = alas arriba; planeando, una "M"
		var pts := PackedVector2Array()
		for side: float in [-1.0, 1.0]:
			var elbow := p + Vector2(side * 6.0, -1.5 - 4.0 * up) * s
			var tip := p + Vector2(side * 12.0, 1.0 - 7.0 * up) * s
			if side < 0.0:
				pts.append_array([tip, elbow, p])
			else:
				pts.append_array([elbow, tip])
		draw_polyline(pts, col, 1.8 * s, true)
		draw_circle(p + Vector2(0, 0.5) * s, 1.4 * s, col, true, -1.0, true)
