extends Node2D
class_name FightCloud
## La polvareda de una pelea (ver VillagerChat): una nubecita de polvo que se revuelve entre los
## dos, a la altura de las piernas (así se ven las piñas), y una estrella que salta con cada golpe
## (ver hit). Al terminar la pelea se desvanece (ver finish); si nadie la termina, se va sola.

const LIFE_MAX := 8.0            # Por si la pelea se corta sin avisar
const FADE := 0.35
const PUFFS := 6
const PUFF_R := 9.0
const SPREAD := Vector2(17.0, 6.0)
const DROP := 20.0               # Cuánto más abajo que el medio de los cuerpos
const STAR_TIME := 0.28
const C_DUST := Color(0.97, 0.94, 0.86)
const C_DUST_EDGE := Color(0.62, 0.55, 0.45)
const C_STAR := Color(1.0, 0.9, 0.3)
const C_STAR_EDGE := Color(0.75, 0.3, 0.1)

var _t := 0.0
var _out := -1.0                 # Desvaneciéndose (segundos; -1: todavía no)
var _stars: Array[Dictionary] = []   # {at (local), age, rot, size}

func _ready() -> void:
	z_index = 12

## Un golpe en at (coords del mundo): salta una estrella (strong: más grande).
func hit(at: Vector2, strong := false) -> void:
	_stars.append({"at": to_local(at), "age": 0.0, "rot": randf() * TAU, "size": 22.0 if strong else 15.0})

## Terminó la pelea: se desvanece y se borra.
func finish() -> void:
	if _out < 0.0:
		_out = 0.0

func _process(dt: float) -> void:
	_t += dt
	for s in _stars:
		s.age += dt
	_stars = _stars.filter(func(s: Dictionary) -> bool: return s.age < STAR_TIME)
	if _out >= 0.0:
		_out += dt
		modulate.a = 1.0 - _out / FADE
		if _out >= FADE:
			queue_free()
			return
	elif _t > LIFE_MAX:
		finish()
	queue_redraw()

func _draw() -> void:
	# El polvo: unas bolas que giran y laten (primero los bordes, así queda una sola nube)
	var grow := minf(1.0, _t / 0.2)
	var puffs: Array[Vector3] = []   # x, y, radio
	for i in PUFFS:
		var a := TAU * i / PUFFS + _t * 2.6
		var r := (PUFF_R + 2.5 * sin(_t * 9.0 + i * 1.7)) * grow
		puffs.append(Vector3(cos(a) * SPREAD.x, sin(a) * SPREAD.y + DROP, r))
	puffs.append(Vector3(0.0, DROP, PUFF_R * 1.2 * grow))
	for p in puffs:
		draw_circle(Vector2(p.x, p.y), p.z + 1.5, C_DUST_EDGE, true, -1.0, true)
	for p in puffs:
		draw_circle(Vector2(p.x, p.y), p.z, C_DUST, true, -1.0, true)
	# Las estrellas de los golpes: saltan y se achican
	for s in _stars:
		var k: float = s.age / STAR_TIME
		var size: float = s.size * sin(minf(1.0, k * 1.6 + 0.25) * PI * 0.5) * (1.0 - k * k * 0.6)
		var pts := PackedVector2Array()
		for i in 10:
			var a: float = s.rot + TAU * i / 10.0
			pts.append(s.at + Vector2(cos(a), sin(a)) * (size if i % 2 == 0 else size * 0.45))
		draw_colored_polygon(pts, Color(C_STAR, 1.0 - k * 0.5))
		pts.append(pts[0])
		draw_polyline(pts, Color(C_STAR_EDGE, 1.0 - k * 0.5), 1.5, true)
