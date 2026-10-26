extends ColorRect
class_name Sea
## El mar (lo dibuja water.gdshader). Cada cuadro le pasa al shader el color del cielo
## (así refleja el atardecer y la noche) y dónde está el sol o la luna, para el reflejo y
## los destellos. La forma de la isla la mide una vez de su dibujo y la ajusta cuando la
## isla crece (fit_island): la laguna y la espuma siguen la orilla.
## Lo que cae al agua deja anillos (ripple).

const BINS := 72              # Igual que en water.gdshader
const RIPPLES := 8            # Ídem
const RIPPLE_LIFE := 1.8      # Ídem
const SQUASH := 0.42          # Ídem (squash): el piso visto desde arriba
const PROFILE_STEPS := 360    # Radio de la isla en el dibujo, cada 1°

const C_SUN := Color(1.0, 0.93, 0.62)
const C_SUN_LOW := Color(1.0, 0.6, 0.3)
const C_MOON := Color(0.92, 0.95, 1.0)
const C_BLOOD_MOON := Color(1.0, 0.3, 0.25)

var _mat: ShaderMaterial
var _sky: Node
var _profile := PackedFloat32Array()   # px de textura, desde el centro de la isla
var _tex_center := Vector2.ZERO        # Centro de la isla en el dibujo (respecto al centro de la textura)
var _ripples: Array[Vector4] = []      # xy = centro, z = edad, w = tamaño
var _glint := 0.0
## La orilla de la isla, como se la pasa al shader (centro y radio en px de piso, ver
## fit_island). La inundación del diluvio usa la misma (ver Storm).
var shore_center := Vector2.ZERO
var shore_radii := PackedFloat32Array()

func _ready() -> void:
	add_to_group("sea")
	_mat = material as ShaderMaterial
	var top := get_global_transform() * Vector2.ZERO
	var bottom := get_global_transform() * size
	_mat.set_shader_parameter("horizon_y", top.y)
	_mat.set_shader_parameter("depth", bottom.y - top.y)
	_mat.set_shader_parameter("vanish_x", get_viewport_rect().size.x * 0.5)
	_mat.set_shader_parameter("squash", SQUASH)
	# Con el zoom alejado (ver World.zoom) se ve más mar: el dibujo se estira para los costados
	# y para adelante (la perspectiva sigue igual: depth es la del mar tal cual se armó)
	var k := get_global_transform().get_scale()
	var view := get_viewport_rect().size
	global_position = Vector2(-view.x * 1.5, top.y)
	size = Vector2(view.x * 4.0, (bottom.y - top.y) * 6.0) / k

## Anillos en el agua donde cae algo (ring_size: 1 = un aldeano).
func ripple(at: Vector2, ring_size := 1.0) -> void:
	if _ripples.size() >= RIPPLES:
		_ripples.pop_front()
	_ripples.append(Vector4(at.x, at.y, 0.0, ring_size))

## Lo mismo, desde cualquier nodo (si hay mar).
static func ripple_at(from: Node, at: Vector2, ring_size := 1.0) -> void:
	var sea := from.get_tree().get_first_node_in_group("sea") as Sea
	if sea:
		sea.ripple(at, ring_size)

## Ajusta la laguna y la espuma al dibujo de la isla (con su escala de ahora).
func fit_island(sprite: Sprite2D) -> void:
	if _profile.is_empty():
		_measure(sprite.texture)
	var k := sprite.global_scale * Vector2(1.0, 1.0 / SQUASH)   # px de piso por px de textura
	var radii := PackedFloat32Array()
	radii.resize(BINS)
	for i in BINS:
		var phi := -PI + TAU * i / BINS
		var theta := Vector2(cos(phi) / k.x, sin(phi) / k.y).angle()   # La misma dirección en el dibujo
		radii[i] = _radius_at(theta) * (Vector2.from_angle(theta) * k).length()
	shore_center = sprite.global_position + _tex_center * sprite.global_scale
	shore_radii = radii
	_mat.set_shader_parameter("isle_center", shore_center)
	_mat.set_shader_parameter("isle_r", radii)

## Mide desde el centro de la isla hasta dónde llega el dibujo en cada dirección.
func _measure(tex: Texture2D) -> void:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var c := Vector2(used.get_center())
	_tex_center = c - Vector2(img.get_size()) * 0.5
	var far := Vector2(img.get_size()).length()
	_profile.resize(PROFILE_STEPS)
	for i in PROFILE_STEPS:
		var dir := Vector2.from_angle(TAU * i / PROFILE_STEPS)
		var inside := 0.0
		var outside := far
		for _step in 14:   # Búsqueda binaria del borde
			var mid := (inside + outside) * 0.5
			var p := Vector2i(c + dir * mid)
			if Rect2i(Vector2i.ZERO, img.get_size()).has_point(p) and img.get_pixelv(p).a > 0.5:
				inside = mid
			else:
				outside = mid
		_profile[i] = inside

func _radius_at(theta: float) -> float:
	var f := fposmod(theta, TAU) / TAU * PROFILE_STEPS
	var i := int(f) % PROFILE_STEPS
	return lerpf(_profile[i], _profile[(i + 1) % PROFILE_STEPS], f - floorf(f))

func _process(dt: float) -> void:
	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i].z += dt
		if _ripples[i].z >= RIPPLE_LIFE:
			_ripples.remove_at(i)
	var packed := PackedVector4Array(_ripples)
	packed.resize(RIPPLES)   # Los que sobran quedan en cero: apagados
	_mat.set_shader_parameter("ripples", packed)

	if _sky == null:
		_sky = get_tree().get_first_node_in_group("sky")
		if _sky == null:
			return
	var tint: Color = _sky.night_tint.color if _sky.night_tint else Color.WHITE
	_mat.set_shader_parameter("sky_color", _untinted(_sky.background.color, tint))

	# Reflejo del astro que esté afuera: más fuerte y largo cuanto más bajo
	var sun: Celestial = _sky.sun
	var moon: Moon = _sky.moon
	var astro: Celestial = sun if sun.visible else moon
	var target := 0.0
	var col := C_SUN
	if astro.visible:
		var low := astro.height_t()
		var above := clampf((_sky.horizon_y + 20.0 - astro.position.y) / 50.0, 0.0, 1.0)   # Se apaga al hundirse
		target = lerpf(0.35, 1.0, low) * above
		if astro == sun:
			col = C_SUN.lerp(C_SUN_LOW, smoothstep(0.3, 0.9, low))
		else:
			target *= 0.7
			col = C_BLOOD_MOON if moon.creepy else C_MOON
	_glint = move_toward(_glint, target, 2.0 * dt)
	_mat.set_shader_parameter("glint", _glint)
	# El astro está en la pantalla (el cielo es otra capa) y el mar en el mundo (con zoom)
	_mat.set_shader_parameter("glint_pos", get_canvas_transform().affine_inverse() * astro.position)
	_mat.set_shader_parameter("glint_color", _untinted(col, tint))

## El agua la tiñe la noche (CanvasModulate) y el cielo no: para que lo que se refleja
## quede del color que tiene en el cielo, se le saca el tinte de antemano. Si no entra
## (se pasaría de 1), se oscurece parejo para que no cambie de tono.
static func _untinted(c: Color, tint: Color) -> Vector3:
	var v := Vector3(c.r / maxf(tint.r, 0.05), c.g / maxf(tint.g, 0.05), c.b / maxf(tint.b, 0.05))
	return v / maxf(1.0, maxf(v.x, maxf(v.y, v.z)))
