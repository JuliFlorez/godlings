extends Celestial
## Luna acosadora: dibujada por código, con ojos que siguen al aldeano más cercano.
## Tocala varias veces y se vuelve la Luna Perturbadora: roja, con los cráteres
## abiertos como ojos y una boca llena de dientes.

@export var radius := 52.0

const BODY := Color(0.93, 0.93, 0.86)
const CRATER := Color(0.8, 0.81, 0.74)
const INK := Color(0.12, 0.12, 0.18)

const BLOOD := Color(0.74, 0.17, 0.14)
const BLOOD_DARK := Color(0.5, 0.08, 0.08)
const DRIP := Color(0.32, 0.02, 0.04)
const EYE_WHITE := Color(1.0, 0.95, 0.85)
const VEIN := Color(0.85, 0.1, 0.1)
## Cráteres que se abren como ojos: (x, y, radio)
const CRATER_EYES := [
	Vector3(-30, -30, 6), Vector3(2, -37, 5), Vector3(32, -30, 5),
	Vector3(-39, 6, 4.5), Vector3(39, 8, 5),
]

func _process(dt: float) -> void:
	super(dt)
	queue_redraw()

func _draw() -> void:
	var look := _look.rotated(-rotation)
	if creepy:
		_draw_creepy(look)
	else:
		_draw_calm(look)

func _draw_calm(look: Vector2) -> void:
	# Halo
	for i in 4:
		draw_circle(Vector2.ZERO, radius + 8.0 + i * 9.0, Color(0.8, 0.88, 1.0, 0.05))
	draw_circle(Vector2.ZERO, radius, BODY)

	# Cráteres
	draw_circle(Vector2(-24, -28), 9.0, CRATER)
	draw_circle(Vector2(27, -20), 6.0, CRATER)
	draw_circle(Vector2(20, 30), 8.0, CRATER)
	draw_circle(Vector2(-32, 20), 5.0, CRATER)

	# Ojos que acosan
	for side in [-1.0, 1.0]:
		var eye := Vector2(side * 17.0, -6.0)
		draw_circle(eye, 11.0, Color(1, 1, 0.97))
		draw_arc(eye, 11.0, 0.0, TAU, 24, INK, 1.5)
		draw_circle(eye + look * 5.0, 5.5, INK)
		# Cejas inclinadas hacia el centro: cara de "te estoy mirando"
		draw_line(Vector2(side * 30.0, -24.0), Vector2(side * 7.0, -18.0), INK, 3.0)

	# Sonrisa torcida con dientes
	draw_arc(Vector2(0, 14), 22.0, 0.15 * PI, 0.85 * PI, 18, INK, 3.0)
	for x in [-10.0, 0.0, 10.0]:
		var y := 14.0 + sqrt(22.0 * 22.0 - x * x)
		draw_line(Vector2(x, y - 6.0), Vector2(x, y), INK, 2.0)

func _draw_creepy(look: Vector2) -> void:
	for i in 4:
		draw_circle(Vector2.ZERO, radius + 8.0 + i * 9.0, Color(1.0, 0.2, 0.15, 0.06))
	draw_circle(Vector2.ZERO, radius, BLOOD)

	# Los cráteres se abrieron: ahora también miran
	for e: Vector3 in CRATER_EYES:
		var c := Vector2(e.x, e.y)
		draw_circle(c, e.z + 2.0, BLOOD_DARK)
		draw_circle(c, e.z, EYE_WHITE)
		draw_circle(c + look * e.z * 0.45, e.z * 0.45, INK)

	# Ojos principales: inyectados en sangre, con pupilas chiquititas
	for side: float in [-1.0, 1.0]:
		var eye := Vector2(side * 18.0, -8.0)
		draw_circle(eye, 14.0, EYE_WHITE)
		for v in 6:
			var a := TAU * v / 6.0 + side * 0.4
			var from := eye + Vector2.from_angle(a) * 14.0
			var mid := eye + Vector2.from_angle(a + 0.3) * 8.0
			draw_polyline(PackedVector2Array([from, mid, mid + Vector2.from_angle(a - 0.4) * 3.0]), VEIN, 1.2)
		draw_arc(eye, 14.0, 0.0, TAU, 28, INK, 1.5)
		var iris := eye + look * 6.0
		draw_circle(iris, 5.0, Color(0.6, 0.05, 0.05))
		draw_circle(iris, 2.0, INK)

	draw_grin(30.0, 10.0, 8.0, 28.0, 8, Color(0.2, 0.02, 0.04), EYE_WHITE)

	# Gota de sangre que no para de caer del labio
	var lip := Vector2(6.0, 10.0 + 28.0 * (1.0 - 0.2 * 0.2))
	var drip := fmod(_t * 8.0, 20.0)
	draw_line(lip, lip + Vector2(0, drip), DRIP, 2.5)
	draw_circle(lip + Vector2(0, drip), 2.8, DRIP)
