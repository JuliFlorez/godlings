extends CanvasLayer
## Ciclo día/noche: bajás el sol hasta el horizonte y sale la luna (y al revés).
## El color del cielo y el tinte del mundo dependen de qué tan bajo está el sol.
## Con la Luna de Sangre en el cielo todo se tiñe de rojo, y cuanto más se la
## alimenta, más rojo.

signal blood_moon_changed(active: bool)

@export var horizon_y := 408.0
@export var night_tint_path: NodePath

const BLOOD_FADE := 0.5     # Por segundo: qué tan rápido entra/sale el rojo
const LEVEL_FADE := 0.8     # Por segundo: qué tan rápido se enrojece al comer

@onready var background: ColorRect = $Background
@onready var stars: Node2D = $Stars
@onready var sun: Celestial = $Sun
@onready var moon: Moon = $Moon
@onready var night_tint: CanvasModulate = get_node_or_null(night_tint_path)

var night := 0.0   # 0 = mediodía, 1 = noche cerrada
var blood_moon := false

var _sky := Gradient.new()
var _tint := Gradient.new()
var _blood_sky := Gradient.new()
var _blood_tint := Gradient.new()
var _blood := 0.0   # 0 = cielo normal, 1 = teñido del todo
var _level := 0.0   # Qué tan alimentada está la luna (suavizado)

func _ready() -> void:
	# Pasa por lila y rosa para que el azul -> naranja no se vuelva gris
	_sky.offsets = PackedFloat32Array([0.0, 0.3, 0.45, 0.6, 0.8, 1.0])
	_sky.colors = PackedColorArray([
		Color(0.035, 0.627, 1.0),   # día
		Color(0.55, 0.62, 1.0),     # lila
		Color(1.0, 0.62, 0.72),     # rosa
		Color(1.0, 0.55, 0.3),      # atardecer
		Color(0.3, 0.14, 0.38),     # crepúsculo
		Color(0.02, 0.03, 0.12),    # noche
	])
	_tint.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	_tint.colors = PackedColorArray([
		Color(1, 1, 1),
		Color(1.0, 0.82, 0.7),
		Color(0.38, 0.42, 0.7),
	])
	# Luna de Sangre: de bordó oscuro (recién transformada) a rojo sangre (bien alimentada)
	_blood_sky.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_blood_sky.colors = PackedColorArray([
		Color(0.24, 0.03, 0.06),
		Color(0.45, 0.04, 0.05),
		Color(0.7, 0.05, 0.03),
	])
	_blood_tint.offsets = PackedFloat32Array([0.0, 1.0])
	_blood_tint.colors = PackedColorArray([
		Color(0.62, 0.4, 0.45),
		Color(0.95, 0.32, 0.28),
	])

	sun.horizon_y = horizon_y
	moon.horizon_y = horizon_y
	stars.max_y = horizon_y - 10.0
	moon.hide_below()

	sun.has_set.connect(moon.rise)
	moon.has_set.connect(sun.rise)

func _process(dt: float) -> void:
	# Si el sol no está en el cielo, es de noche
	night = sun.height_t() if sun.visible else 1.0

	var active := moon.creepy and moon.visible
	if active != blood_moon:
		blood_moon = active
		blood_moon_changed.emit(active)
	_blood = move_toward(_blood, 1.0 if active else 0.0, BLOOD_FADE * dt)
	_level = move_toward(_level, moon.feed_t(), LEVEL_FADE * dt)

	background.color = _sky.sample(night).lerp(_blood_sky.sample(_level), _blood)
	var star_red := 1.0 - 0.6 * _blood
	stars.modulate = Color(1.0, star_red, star_red, smoothstep(0.65, 1.0, night))
	if night_tint:
		night_tint.color = _tint.sample(night).lerp(_blood_tint.sample(_level), _blood)
