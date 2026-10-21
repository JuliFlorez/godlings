extends Clouds
class_name CloudBank
## Colchón de nubes muy arriba de la isla, fuera de la pantalla mientras se juega: sobre
## él flota el menú de inicio y la cámara lo atraviesa al bajar a la isla (el cielo lo
## mueve igual que a la isla, ver Sky.lift).
## Arriba, copetes con brillo y sombra (y detrás otra fila, más chica y perdida en el
## cielo); adentro, todo nube, con manchas difusas más claras y más oscuras que se ven
## pasar al bajar; abajo, panzas oscuras. Todo va corriéndose despacio con el viento.
## La luz es la de las demás nubes (Clouds.set_light).

## En coordenadas de la isla: y = 0 es el borde de arriba de la pantalla jugando.
const TOP := -1400.0
const BOTTOM := -480.0
const WRAP := 160.0           # Más que el bollo más grande: dan la vuelta fuera de la pantalla
const DRIFT := 5.0            # px/s de los copetes de adelante
const BACK_HAZE := 0.45       # Cuánto se pierde en el cielo la fila de atrás
const DOME_SHADE := 0.5       # Qué tan oscura es la sombra de cada copete
const BODY_INSET := 16.0      # El cuerpo empieza apenas debajo de TOP, tapando lo de abajo de los copetes
const INSIDE := 60            # Manchas adentro

var _blob_tex: GradientTexture2D  # Propia y no static: guardada en el script quedaba viva al cerrar el juego
var _back: Array[Vector3] = []     # x, y, radio
var _front: Array[Vector3] = []
var _bellies: Array[Vector3] = []
var _inside: Array[Vector4] = []   # x, y, radio, tono (-1 = sombra, 1 = brillo)
var _span := 0.0                   # Ancho por el que dan la vuelta

func _ready() -> void:
	super()
	_span = get_viewport_rect().size.x + WRAP * 2.0
	_back = _row(45.0, 80.0, 70.0, 130.0, 1.0)
	_front = _row(70.0, 125.0, 20.0, 90.0, 0.9)
	var x := 0.0
	while x < _span:
		var r := randf_range(35.0, 70.0)
		_bellies.append(Vector3(x, BOTTOM - r * randf_range(0.35, 0.55), r))
		x += r * randf_range(1.1, 1.5)
	for i in INSIDE:
		var r := randf_range(60.0, 150.0)
		_inside.append(Vector4(randf() * _span, randf_range(TOP + r, BOTTOM - r * 0.8), r, randf_range(-1.0, 1.0)))

## Copetes a lo ancho, de radio entre r_min y r_max, que asoman entre above_min y
## above_max por encima de TOP. gap: separación en radios.
func _row(r_min: float, r_max: float, above_min: float, above_max: float, gap: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x := 0.0
	while x < _span:
		var r := randf_range(r_min, r_max)
		out.append(Vector3(x, TOP + r - randf_range(above_min, above_max), r))
		x += r * randf_range(gap, gap + 0.4)
	return out

## Las demás nubes no (ver Clouds._process): esto se corre solo, y se dibuja si se ve.
func _process(dt: float) -> void:
	_t += dt
	var top := position.y + TOP - 140.0
	var bottom := position.y + BOTTOM + 60.0
	if bottom > 0.0 and top < get_viewport_rect().size.y:
		queue_redraw()

func _wrap(x: float, speed: float) -> float:
	return fposmod(x + _t * speed, _span) - WRAP

func _draw() -> void:
	var x0 := -WRAP
	var x1 := _span - WRAP
	# Fila de atrás: asoma por encima de la de adelante
	var back := _c_body.lerp(_haze, BACK_HAZE)
	var back_shine := _c_shine.lerp(_haze, BACK_HAZE)
	for p in _back:
		var c := Vector2(_wrap(p.x, DRIFT * 0.5), p.y)
		draw_circle(c + Vector2(-0.06, -0.1) * p.z, p.z, back_shine, true, -1.0, true)
		draw_circle(c, p.z, back, true, -1.0, true)

	# Copetes de adelante: primero todos los brillos (asoman como un borde arriba) y
	# después cada bollo, con su sombra asomando a la derecha (a la izquierda no, que
	# debajo de las cabezas quedaría una rayita)
	var shade := _c_body.lerp(_c_shade, DOME_SHADE)
	for p in _front:
		draw_circle(Vector2(_wrap(p.x, DRIFT), p.y) + Vector2(-0.03, -0.1) * p.z, p.z * 0.97, _c_shine, true, -1.0, true)
	for p in _front:
		var c := Vector2(_wrap(p.x, DRIFT), p.y)
		draw_circle(c + Vector2(0.06, 0.04) * p.z, p.z, shade, true, -1.0, true)
		draw_circle(c, p.z, _c_body, true, -1.0, true)

	# El cuerpo, encima de los copetes (de ellos solo quedan las cabezas): nube clara
	# arriba que se va sombreando hacia la panza
	var top := TOP + BODY_INSET
	var mid := lerpf(TOP, BOTTOM, 0.4)
	draw_rect(Rect2(x0, top, x1 - x0, mid - top), _c_body)
	draw_polygon(PackedVector2Array([Vector2(x0, mid), Vector2(x1, mid), Vector2(x1, BOTTOM), Vector2(x0, BOTTOM)]),
			PackedColorArray([_c_body, _c_body, _c_shade, _c_shade]))

	# Adentro: manchas difusas que se ven pasar al atravesarla
	var tex := _blob_texture()
	for p in _inside:
		var col := _c_body.lerp(_c_shine if p.w > 0.0 else _c_shade, absf(p.w))
		var c := Vector2(_wrap(p.x, DRIFT * 0.8), p.y)
		draw_texture_rect(tex, Rect2(c - Vector2.ONE * p.z, Vector2.ONE * p.z * 2.0), false, Color(col, 0.6))

	# Panzas oscuras colgando abajo
	for p in _bellies:
		draw_circle(Vector2(_wrap(p.x, DRIFT * 0.8), p.y), p.z, _c_shade, true, -1.0, true)

## Mancha redonda: opaca al centro, se desvanece hacia el borde.
func _blob_texture() -> GradientTexture2D:
	if _blob_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(1.0, 0.5)
		_blob_tex.width = 128
		_blob_tex.height = 128
	return _blob_tex
