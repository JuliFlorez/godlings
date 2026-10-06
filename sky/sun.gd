extends Celestial
## Sol: de día es el sprite tranquilo. Tocalo varias veces y se vuelve el Sol
## Perturbador, dibujado por código: tentáculos de fuego que se retuercen,
## cuencas vacías que siguen al aldeano más cercano y una sonrisa llena de dientes.

@export var radius := 36.0

const BODY := Color(0.96, 0.42, 0.07)
const RIM := Color(0.38, 0.06, 0.02)
const FLESH := Color(0.88, 0.2, 0.04)
const VOID := Color(0.05, 0.01, 0.01)
const TOOTH := Color(1.0, 0.92, 0.66)
const TENDRILS := 11
const TENDRIL_STEPS := 20

@onready var sprite: Sprite2D = $Sprite2D

## Grietas que le parten la cara
var _cracks: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-35, -6), Vector2(-27, -4), Vector2(-23, -11), Vector2(-17, -12)]),
	PackedVector2Array([Vector2(31, -17), Vector2(25, -13), Vector2(27, -6)]),
	PackedVector2Array([Vector2(-9, 35), Vector2(-7, 29), Vector2(-12, 26)]),
]

func _ready() -> void:
	super()
	creepy_changed.connect(func(c: bool): sprite.visible = not c)

func _process(dt: float) -> void:
	super(dt)
	if creepy:
		queue_redraw()

func _draw() -> void:
	if not creepy:
		return
	# Late como un corazón
	var r := radius * (1.0 + 0.06 * pow(absf(sin(_t * 2.6)), 6.0))

	for i in 4:
		draw_circle(Vector2.ZERO, r + 14.0 + i * 12.0, Color(1.0, 0.25, 0.05, 0.05))

	# Tentáculos en vez de rayos: se retuercen y se estiran
	for i in TENDRILS:
		var dir := Vector2.from_angle(TAU * i / TENDRILS + _t * 0.12)
		var perp := dir.orthogonal()
		var length := 38.0 + 10.0 * sin(_t * 2.1 + i * 1.7)
		for outline: bool in [true, false]:
			for s in TENDRIL_STEPS:
				var u := float(s) / (TENDRIL_STEPS - 1)
				var wiggle := sin(u * 5.0 - _t * 4.0 + i * 2.3) * 7.0 * u
				var p := dir * (r * 0.8 + length * u) + perp * wiggle
				var w := lerpf(7.0, 1.2, u)
				draw_circle(p, w + 2.5 if outline else w, RIM if outline else FLESH)

	draw_circle(Vector2.ZERO, r + 3.0, RIM)
	draw_circle(Vector2.ZERO, r, BODY)
	draw_circle(Vector2(-22, 14), 5.0, FLESH)
	draw_circle(Vector2(24, 12), 3.5, FLESH)
	for crack in _cracks:
		draw_polyline(crack, RIM, 2.0)

	# Cuencas vacías y desparejas, con una brasa adentro que te sigue
	var look := _look.rotated(-rotation)
	for eye in [[Vector2(-13, -8), 11.0], [Vector2(14, -9), 8.0]]:
		var c: Vector2 = eye[0]
		var er: float = eye[1]
		# Lágrimas negras: se está derritiendo
		draw_line(c + Vector2(0, er * 0.5), c + Vector2(0, er + 8.0), VOID, 3.0)
		draw_circle(c + Vector2(0, er + 8.0), 2.5, VOID)
		draw_circle(c, er, VOID)
		var pupil := c + look * (er - 4.0)
		draw_circle(pupil, 4.5, Color(1.0, 0.85, 0.3, 0.35))
		draw_circle(pupil, 2.2, Color(1.0, 1.0, 0.85))

	draw_grin(26.0, 8.0, 8.0, 18.0, 10, VOID, TOOTH)
