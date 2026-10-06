extends CanvasLayer
## Ciclo día/noche: bajás el sol hasta el horizonte y sale la luna (y al revés).
## El color del cielo y el tinte del mundo dependen de qué tan bajo está el sol.

@export var horizon_y := 408.0
@export var night_tint_path: NodePath

@onready var background: ColorRect = $Background
@onready var stars: Node2D = $Stars
@onready var sun: Celestial = $Sun
@onready var moon: Celestial = $Moon
@onready var night_tint: CanvasModulate = get_node_or_null(night_tint_path)

var night := 0.0   # 0 = mediodía, 1 = noche cerrada

var _sky := Gradient.new()
var _tint := Gradient.new()

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

	sun.horizon_y = horizon_y
	moon.horizon_y = horizon_y
	stars.max_y = horizon_y - 10.0
	moon.hide_below()

	sun.has_set.connect(moon.rise)
	moon.has_set.connect(sun.rise)

func _process(_dt: float) -> void:
	# Si el sol no está en el cielo, es de noche
	night = sun.height_t() if sun.visible else 1.0
	background.color = _sky.sample(night)
	stars.modulate.a = smoothstep(0.65, 1.0, night)
	if night_tint:
		night_tint.color = _tint.sample(night)
