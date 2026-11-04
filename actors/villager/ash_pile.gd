extends Node2D
class_name AshPile
## Montoncito de cenizas donde se deshizo (en la capa del piso). Mientras se deshace le cae
## polvo encima (dust: el aldeano lo va poniendo donde se está deshaciendo) y las brasas se
## apagan solas.

const ASH := Color(0.25, 0.24, 0.24)
const ASH_TOP := Color(0.42, 0.4, 0.39)
const SOOT := Color(0.08, 0.07, 0.07, 0.5)
const EMBER := Color(1.0, 0.45, 0.1)
var width := 12.0
var amount := 0.0:   # 0..1: cuánto ya cayó
	set(v):
		amount = v
		queue_redraw()
var dust: CPUParticles2D
var done := false
var _glow := 1.0
var _specks: Array[Vector3] = []   # x, y (0..1 del montoncito), radio

func _ready() -> void:
	for i in 8:
		_specks.append(Vector3(randf_range(-0.75, 0.75), randf_range(0.2, 0.8), randf_range(0.8, 1.6)))
	dust = CPUParticles2D.new()
	dust.amount = 40
	dust.lifetime = 0.6
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(12, 1.5)
	dust.direction = Vector2.DOWN
	dust.spread = 180.0
	dust.initial_velocity_min = 5.0
	dust.initial_velocity_max = 25.0
	dust.gravity = Vector2(0, 90)
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 2.6
	dust.color_ramp = Villager._fade_ramp(Color(0.3, 0.29, 0.29), Color(0.5, 0.48, 0.47, 0.0))
	add_child(dust)

func _process(_dt: float) -> void:
	if _glow > 0.0:
		queue_redraw()

func finish() -> void:
	if done:
		return
	done = true
	dust.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "_glow", 0.0, 2.5)
	tw.tween_interval(Villager.CORPSE_TIME)
	tw.tween_property(self, "modulate:a", 0.0, 2.0)
	tw.tween_callback(queue_free)

func _draw() -> void:
	var w := width * (0.4 + 0.6 * amount)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, w * 1.4, SOOT, true, -1.0, true)   # Hollín en la arena
	draw_set_transform(Vector2.ZERO)
	var h := 9.0 * amount
	if h < 0.5:
		return
	draw_colored_polygon(_mound(w, h), ASH)
	draw_set_transform(Vector2(-w * 0.12, -h * 0.2))
	draw_colored_polygon(_mound(w * 0.65, h * 0.7), ASH_TOP)
	draw_set_transform(Vector2.ZERO)
	var t := World.anim_time
	for i in _specks.size():
		var s := _specks[i]
		var p := Vector2(s.x * w, -s.y * h * pow(1.0 - s.x * s.x, 0.6))
		if i < 3 and _glow > 0.0:   # Brasas
			draw_circle(p, 1.2, Color(EMBER, _glow * (0.5 + 0.5 * sin(t * 8.0 + i * 2.0))), true, -1.0, true)
		else:
			draw_circle(p, s.z, ASH_TOP.lightened(0.15), true, -1.0, true)

## Lomita de ancho 2w y alto h, apoyada en y = 0.
static func _mound(w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var u := lerpf(-1.0, 1.0, i / 16.0)
		pts.append(Vector2(u * w, 1.5 - h * pow(maxf(0.0, 1.0 - u * u), 0.6)))
	return pts
