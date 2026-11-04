extends Node2D
class_name Flames
## Lenguas de fuego por todo el cuerpo (coords del aldeano) que siempre apuntan para arriba,
## aunque esté tirado o colgando. Se prenden y se apagan de a poco (on).

const GLOW := Color(1.0, 0.6, 0.2, 0.16)
const LAYERS := [[1.0, Color(0.92, 0.25, 0.05, 0.92)], [0.68, Color(1.0, 0.55, 0.1)], [0.38, Color(1.0, 0.92, 0.5)]]
const TONGUES := 13
const SIZE := Vector2(7.0, 22.0)   # Medio ancho y alto de una lengua a pleno
const NECK := -8.0                 # Más arriba está la cabeza, que es más ancha que el cuerpo
const GROW := 4.0                  # Prenderse / apagarse del todo tarda 1/esto segundos
var on := true
var amount := 0.0
var _tongues: Array[Vector4] = []  # x, y de la base, tamaño, fase

func _ready() -> void:
	for i in TONGUES:
		var y := lerpf(Villager.FEET - 6.0, Villager.HEAD_TOP + 8.0, float(i) / (TONGUES - 1))
		var half := 19.0 if y < NECK else 11.0
		_tongues.append(Vector4(randf_range(-half, half), y, randf_range(0.7, 1.2), randf() * TAU))

func _process(dt: float) -> void:
	amount = move_toward(amount, 1.0 if on else 0.0, GROW * dt)
	visible = amount > 0.0
	if visible:
		queue_redraw()

func _draw() -> void:
	var t := World.anim_time
	var up: float = -(get_parent() as Node2D).global_rotation
	draw_circle(Vector2(0, -6), 34.0 * amount, GLOW, true, -1.0, true)
	for tg in _tongues:
		var h := SIZE.y * tg.z * amount * (1.0 + 0.25 * sin(t * 13.0 + tg.w) + 0.12 * sin(t * 23.0 + tg.w * 2.0))
		var w := SIZE.x * tg.z * amount
		var sway := 3.0 * sin(t * 7.0 + tg.w)
		draw_set_transform(Vector2(tg.x, tg.y), up)
		for layer: Array in LAYERS:
			var k: float = layer[0]
			draw_colored_polygon(_tongue(w * k, h * k, sway * k), layer[1])
	draw_set_transform(Vector2.ZERO)

## Lengua de fuego apoyada en (0, 0): abajo redonda, arriba en punta (que se mece con sway).
static func _tongue(w: float, h: float, sway: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var a := PI * i / 6.0
		pts.append(Vector2(cos(a) * w, sin(a) * w * 0.8))
	for i in range(1, 8):
		var u := i / 7.0
		pts.append(Vector2(-w * pow(1.0 - u, 1.3) + sway * u * u, -h * u))
	for i in range(6, 0, -1):
		var u := i / 7.0
		pts.append(Vector2(w * pow(1.0 - u, 1.3) + sway * u * u, -h * u))
	return pts
