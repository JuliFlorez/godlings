extends Node2D
class_name Clouds
## Nubes que pasan despacio por el cielo, hechas de bollos como la nube del rayo: panza
## chata más oscura y brillo arriba. Las de más abajo están más lejos: más chicas, más
## lentas y medio perdidas en el color del cielo. Cuando una sale por un costado, entra
## otra nueva por el otro.
## El cielo les pasa la luz (set_light): blancas de día, rosadas y naranjas al atardecer,
## azul oscuro de noche, bordó con la Luna de Sangre, y cada rayo las ilumina.
## Con la cámara en el cielo (menú de inicio, ver camera_lift) bajan en pantalla, las lejanas menos.

@export var count := 6
@export var wind := 16.0          # px/s de las más cercanas (positivo: hacia la derecha)
var max_y := 350.0                # La panza de las más lejanas (lo pone el cielo)
var camera_lift := 0.0            # Cuánto subió la cámara (lo pone el cielo, ver World.lift)

const MIN_Y := 70.0               # La panza de las más cercanas
const MARGIN := 40.0              # Salen de la pantalla del todo antes de volver a entrar
const FAR_SCALE := 0.45           # Tamaño de las más lejanas (1 = las más cercanas)
const FAR_SPEED := 0.35
const FAR_HAZE := 0.35            # Cuánto se pierden en el cielo las más lejanas
const NEAR_PARALLAX := 0.8        # Cuánto se mueven con la cámara (1 = igual que la isla)
const FAR_PARALLAX := 0.45

# Luz según la hora (mismos puntos que el degradé del cielo, ver Sky)
const LIGHT_OFFSETS: Array[float] = [0.0, 0.3, 0.45, 0.6, 0.8, 1.0]
const BODY: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.95, 0.94, 1.0), Color(1.0, 0.87, 0.9),
		Color(1.0, 0.78, 0.6), Color(0.62, 0.42, 0.6), Color(0.2, 0.22, 0.36)]
const SHADE: Array[Color] = [Color(0.8, 0.87, 0.97), Color(0.74, 0.76, 0.95), Color(0.92, 0.66, 0.78),
		Color(0.92, 0.5, 0.45), Color(0.4, 0.24, 0.42), Color(0.11, 0.12, 0.24)]
const SHINE: Array[Color] = [Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.96, 0.94),
		Color(1.0, 0.93, 0.76), Color(0.86, 0.6, 0.66), Color(0.32, 0.35, 0.52)]
const BLOOD_BODY := Color(0.48, 0.08, 0.09)
const BLOOD_SHADE := Color(0.24, 0.03, 0.05)
const BLOOD_SHINE := Color(0.72, 0.16, 0.13)
const FLASH := Color(0.92, 0.94, 1.0)
const STORM_BODY := Color(0.5, 0.53, 0.58)
const STORM_SHADE := Color(0.33, 0.35, 0.41)
const STORM_SHINE := Color(0.62, 0.65, 0.7)

var _clouds: Array[Dictionary] = []   # {pos, far (0 = cerca, 1 = lejos), speed, puffs, half_w, base_r}
var _body := Gradient.new()
var _shade := Gradient.new()
var _shine := Gradient.new()
var _c_body := Color.WHITE
var _c_shade := SHADE[0]
var _c_shine := Color.WHITE
var _haze := Color(0.035, 0.627, 1.0)
var _t := 0.0

func _ready() -> void:
	for g: Gradient in [_body, _shade, _shine]:
		g.offsets = PackedFloat32Array(LIGHT_OFFSETS)
	_body.colors = PackedColorArray(BODY)
	_shade.colors = PackedColorArray(SHADE)
	_shine.colors = PackedColorArray(SHINE)

## Las primeras: repartidas a lo ancho, cada una en su franja para que no arranquen amontonadas.
## (En el primer cuadro y no en _ready, así ya tienen el max_y que les puso el cielo.)
func _spawn_all() -> void:
	var w := get_viewport_rect().size.x
	for i in count:
		var c := _new_cloud()
		c.pos.x = lerpf(-MARGIN, w + MARGIN, (i + randf_range(0.2, 0.8)) / count)
		_clouds.append(c)
	_sort()

## night: 0 = mediodía, 1 = noche. blood: cuánto se tiñó todo de rojo. flash: destello
## de un rayo. sky: color del cielo, en el que se pierden las nubes lejanas. storm: cuánto
## llueve (ver Storm): se ponen grises, de tormenta.
func set_light(night: float, blood: float, flash: float, sky: Color, storm := 0.0) -> void:
	var dark := 1.0 - 0.55 * night   # De noche la tormenta también es más oscura
	_c_body = _body.sample(night).lerp(BLOOD_BODY, blood).lerp(STORM_BODY * dark, storm * 0.85).lerp(FLASH, flash * 0.8)
	_c_shade = _shade.sample(night).lerp(BLOOD_SHADE, blood).lerp(STORM_SHADE * dark, storm * 0.85).lerp(FLASH.darkened(0.15), flash * 0.8)
	_c_shine = _shine.sample(night).lerp(BLOOD_SHINE, blood).lerp(STORM_SHINE * dark, storm * 0.85).lerp(Color.WHITE, flash * 0.8)
	_haze = sky

func _new_cloud() -> Dictionary:
	var far := randf()
	var k := lerpf(1.0, FAR_SCALE, far)
	var half_w := randf_range(55.0, 95.0) * k
	var base_r := randf_range(15.0, 20.0) * k
	var puffs: Array[Vector3] = []   # x, y (desde la panza), radio
	# Fila de abajo, pareja: de acá sale la panza chata
	var n := maxi(2, ceili(half_w * 2.0 / (base_r * 1.3)))
	for i in n + 1:
		puffs.append(Vector3(lerpf(-half_w + base_r, half_w - base_r, float(i) / n), -base_r * 0.2, base_r))
	# Copete: dos o tres bollos grandes, el del medio más alto
	var tops := randi_range(2, 3)
	for i in tops:
		var r := randf_range(22.0, 30.0) * k * (1.2 if i == 1 else 1.0)
		var x := lerpf(-half_w * 0.55, half_w * 0.55, (i + 0.5) / tops) + randf_range(-8.0, 8.0) * k
		puffs.append(Vector3(x, -base_r * 0.3 - r * randf_range(0.5, 0.75), r))
	var speed := wind * lerpf(1.0, FAR_SPEED, far) * randf_range(0.85, 1.15)
	var y := lerpf(MIN_Y, max_y, far) + randf_range(-15.0, 15.0)
	var x := -half_w - MARGIN if speed > 0.0 else get_viewport_rect().size.x + half_w + MARGIN
	return {"pos": Vector2(x, y), "far": far, "speed": speed, "puffs": puffs,
			"half_w": half_w, "base_r": base_r, "phase": randf() * TAU}

## Las lejanas se dibujan primero (quedan detrás).
func _sort() -> void:
	_clouds.sort_custom(func(a: Dictionary, b: Dictionary): return a.far > b.far)

func _process(dt: float) -> void:
	if _clouds.is_empty():
		_spawn_all()
	_t += dt
	var w := get_viewport_rect().size.x
	var replaced := false
	for i in _clouds.size():
		var c := _clouds[i]
		c.pos.x += c.speed * dt
		if c.pos.x - c.half_w > w + MARGIN or c.pos.x + c.half_w < -MARGIN:
			_clouds[i] = _new_cloud()
			replaced = true
	if replaced:
		_sort()
	queue_redraw()

func _draw() -> void:
	for c in _clouds:
		var haze: float = c.far * FAR_HAZE
		var pos: Vector2 = c.pos + Vector2(0.0, camera_lift * lerpf(NEAR_PARALLAX, FAR_PARALLAX, c.far))
		var half_w: float = c.half_w
		var base_r: float = c.base_r
		var lift := base_r * 0.4   # Cuánto asoma la panza oscura por debajo
		var puffs: Array[Vector3] = c.puffs
		var radii: Array[float] = []
		for j in puffs.size():   # Los bollos se inflan y desinflan apenas
			radii.append(puffs[j].z * (1.0 + 0.04 * sin(_t * 0.7 + c.phase + j * 1.7)))
		var shade := _c_shade.lerp(_haze, haze)
		var body := _c_body.lerp(_haze, haze)
		var shine := _c_shine.lerp(_haze, haze)
		_paint_shape(pos, puffs, radii, half_w, base_r, shade)
		for j in puffs.size():   # Brillo: asoma como un borde arriba de los bollos del copete
			var p := puffs[j]
			if p.y < -base_r * 0.3:
				var r := radii[j]
				draw_circle(pos + Vector2(p.x - r * 0.08, p.y - lift - r * 0.1), r, shine, true, -1.0, true)
		_paint_shape(pos - Vector2(0, lift), puffs, radii, half_w, base_r, body)

## La silueta: los bollos y una franja que deja la panza chata.
func _paint_shape(pos: Vector2, puffs: Array[Vector3], radii: Array[float], half_w: float, base_r: float, color: Color) -> void:
	for j in puffs.size():
		draw_circle(pos + Vector2(puffs[j].x, puffs[j].y), radii[j], color, true, -1.0, true)
	draw_rect(Rect2(pos.x - half_w + base_r, pos.y - base_r, (half_w - base_r) * 2.0, base_r * 1.8), color)
