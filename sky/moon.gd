extends Celestial
class_name Moon
## Luna acosadora: dibujada por código, con ojos que siguen al aldeano más cercano.
## Tocala varias veces y se vuelve la Luna de Sangre: roja, con los cráteres
## abiertos como ojos y una boca llena de dientes.
## Como Luna de Sangre se la puede alimentar soltándole aldeanos encima: cada uno
## que se come pone el cielo más rojo (hasta MAX_FEED). Calmarla la deja en cero.

signal fed(level: int)

@export var radius := 52.0

const MAX_FEED := 6
const EAT_MARGIN := 14.0         # Soltarlo hasta esta distancia del borde también cuenta
const SMELL_RANGE := 2.6         # En radios: desde acá abre la boca al ver un aldeano agarrado

var feed_level := 0
var _gape := 0.0                 # 0 = boca normal, 1 = bien abierta esperando comida
var _chomp := 0.0                # 1 = mandíbula cerrada (tragando)
var _chomp_tween: Tween

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

func _ready() -> void:
	super()
	add_to_group("moon")
	creepy_changed.connect(func(c: bool):
		if not c:
			feed_level = 0
			fed.emit(feed_level))

func _process(dt: float) -> void:
	super(dt)
	var hungry := creepy and visible and _villager_held_near()
	_gape = move_toward(_gape, 1.0 if hungry else 0.0, dt * 4.0)
	queue_redraw()

## 0..1: qué tan alimentada está (para el color del cielo).
func feed_t() -> float:
	return float(feed_level) / MAX_FEED

## Si soltar algo en este punto de la pantalla se lo da de comer.
func can_eat_at(screen_pos: Vector2) -> bool:
	return creepy and visible and _local(screen_pos).length() <= radius + EAT_MARGIN

## Dónde está la boca, en coordenadas de pantalla.
func mouth_screen_pos() -> Vector2:
	return get_global_transform_with_canvas() * Vector2(0, 24)

## Se tragó un aldeano: mordisco, sacudón y el cielo un poco más rojo.
func feed() -> void:
	feed_level = mini(feed_level + 1, MAX_FEED)
	_shake = 1.0
	_pop(1.25, 0.7)
	if _chomp_tween:
		_chomp_tween.kill()
	_chomp_tween = create_tween()
	_chomp_tween.tween_property(self, "_chomp", 1.0, 0.08)
	_chomp_tween.tween_interval(0.12)
	_chomp_tween.tween_property(self, "_chomp", 0.0, 0.35)
	fed.emit(feed_level)

func _local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos

func _villager_held_near() -> bool:
	var mouse := get_viewport().get_mouse_position()
	if _local(mouse).length() > radius * SMELL_RANGE:
		return false
	for v in get_tree().get_nodes_in_group("villager"):
		if (v as Villager) and v.dragging:
			return true
	return false

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
	# Cuanto más comió, más fuerte el resplandor
	var glow := 0.06 + 0.05 * feed_t()
	for i in 4:
		draw_circle(Vector2.ZERO, radius + 8.0 + i * (9.0 + 3.0 * feed_t()), Color(1.0, 0.2, 0.15, glow))
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

	# Con un aldeano cerca abre la boca; al tragar la cierra de golpe
	var jaw := lerpf(28.0 + 12.0 * _gape, 9.0, _chomp)
	draw_grin(30.0 + 4.0 * _gape, 10.0, 8.0, jaw, 8, Color(0.2, 0.02, 0.04), EYE_WHITE)

	# Gota de sangre que no para de caer del labio
	var lip := Vector2(6.0, 10.0 + jaw * (1.0 - 0.2 * 0.2))
	var drip := fmod(_t * (8.0 + 6.0 * feed_t()), 20.0)
	draw_line(lip, lip + Vector2(0, drip), DRIP, 2.5)
	draw_circle(lip + Vector2(0, drip), 2.8, DRIP)
