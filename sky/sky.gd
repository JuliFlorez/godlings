extends CanvasLayer
## Ciclo día/noche: bajás el sol hasta el horizonte y sale la luna (y al revés).
## El color del cielo, el de las nubes y el tinte del mundo dependen de qué tan bajo está el sol.
## Con la Luna de Sangre en el cielo todo se tiñe de rojo, y cuanto más se la
## alimenta, más rojo. Cada rayo ilumina todo un instante (ver flash). Con el diluvio
## (ver storm) se pone gris y oscuro, y las nubes tapan al sol y a la luna.
## Con la cámara en el cielo (menú de inicio, ver lift) se ve el colchón de nubes de allá
## arriba (CloudBank) y el cielo de arriba es más oscuro.

signal blood_moon_changed(active: bool)

@export var horizon_y := 408.0
@export var night_tint_path: NodePath

const BLOOD_FADE := 0.5     # Por segundo: qué tan rápido entra/sale el rojo
const LEVEL_FADE := 0.8     # Por segundo: qué tan rápido se enrojece al comer
const FLASH_FADE := 14.0    # Por segundo: qué tan rápido se apaga el destello de un rayo
const C_FLASH_SKY := Color(0.86, 0.9, 1.0)
const BIRDS_PARALLAX := 0.7 # Cuánto se mueven las gaviotas con la cámara (1 = igual que la isla)
## Cielo de altura: desde HIGH_FROM px de cámara arriba se va oscureciendo, hasta
## HIGH_DARK en HIGH_FULL (arriba de la pantalla; abajo, cerca de las nubes, no).
const HIGH_FROM := 300.0
const HIGH_FULL := 1500.0
const HIGH_DARK := 0.5
## Diluvio (ver Storm): con la tormenta el cielo se pone gris y todo se oscurece.
const C_STORM_SKY := Color(0.33, 0.38, 0.45)
const C_STORM_TINT := Color(0.62, 0.66, 0.74)   # Multiplica el tinte de ahora (de día y de noche)
const STORM_HIDE := 0.8          # Cuánto tapan las nubes de tormenta al sol y a la luna

@onready var background: ColorRect = $Background
@onready var stars: Node2D = $Stars
@onready var clouds: Clouds = $Clouds
@onready var birds: Birds = $Birds
@onready var sun: Celestial = $Sun
@onready var moon: Moon = $Moon
@onready var night_tint: CanvasModulate = get_node_or_null(night_tint_path)

var night := 0.0   # 0 = mediodía, 1 = noche cerrada
## Si la partida está de noche (lo que se guarda): desde que se termina de poner el sol
## hasta que se termina de poner la luna, o desde que se carga una partida de noche.
var is_night := false
var blood_moon := false
## Cuánto llueve (lo pone Storm): 0 despejado, 1 tormenta cerrada.
var storm := 0.0
var bank: CloudBank
## Cuánto subió la cámara (ver World.lift). Lo lejano se mueve menos: el sol, la luna y
## las estrellas nada; las nubes y las gaviotas menos que la isla; el colchón de nubes,
## igual que la isla.
var lift := 0.0:
	set(v):
		lift = v
		clouds.camera_lift = v
		birds.position.y = v * BIRDS_PARALLAX
		bank.position.y = v

var _sky := Gradient.new()
var _tint := Gradient.new()
var _blood_sky := Gradient.new()
var _blood_tint := Gradient.new()
var _blood := 0.0   # 0 = cielo normal, 1 = teñido del todo
var _level := 0.0   # Qué tan alimentada está la luna (suavizado)
var _flash := 0.0   # Destello de un rayo: 1 = todo iluminado

func _ready() -> void:
	add_to_group("sky")   # Las antorchas leen `night` para saber cuándo prenderse
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
	clouds.max_y = horizon_y - 58.0
	moon.hide_below()

	sun.has_set.connect(moon.rise)
	moon.has_set.connect(sun.rise)
	sun.has_set.connect(func(): is_night = true)
	moon.has_set.connect(func(): is_night = false)

	# Encima de todo lo del cielo: al atravesarlo tapa también al sol y a la luna
	bank = CloudBank.new()
	add_child(bank)
	# El cielo de altura, sobre el fondo y debajo de todo lo demás
	var high := HUD.Painter.new()
	high.paint = _paint_high
	add_child(high)
	move_child(high, background.get_index() + 1)

## Partida guardada de noche: mientras la cámara baja a la isla, el sol se pone (en
## sunset segundos) y después sale la luna.
func start_at_night(sunset: float) -> void:
	is_night = true
	sun.sink(sunset)

## Un rayo ilumina el cielo y la isla (también de noche). amount: 0..1.
func flash(amount: float) -> void:
	_flash = maxf(_flash, amount)

func _process(dt: float) -> void:
	_flash = move_toward(_flash, 0.0, FLASH_FADE * dt)
	# Si el sol no está en el cielo, es de noche
	night = sun.height_t() if sun.visible else 1.0

	var active := moon.creepy and moon.visible
	if active != blood_moon:
		blood_moon = active
		blood_moon_changed.emit(active)
	_blood = move_toward(_blood, 1.0 if active else 0.0, BLOOD_FADE * dt)
	_level = move_toward(_level, moon.feed_t(), LEVEL_FADE * dt)

	var storm_sky := C_STORM_SKY.darkened(night * 0.7)
	background.color = _sky.sample(night).lerp(_blood_sky.sample(_level), _blood).lerp(storm_sky, storm * 0.8) \
			.lerp(C_FLASH_SKY, _flash * 0.65)
	var star_red := 1.0 - 0.6 * _blood
	stars.modulate = Color(1.0, star_red, star_red, smoothstep(0.65, 1.0, night) * (1.0 - storm))
	# Con la tormenta el sol y la luna casi no se ven, detrás de las nubes
	var behind := Color(1.0, 1.0, 1.0, 1.0 - STORM_HIDE * storm)
	sun.modulate = behind
	moon.modulate = behind
	clouds.set_light(night, _blood, _flash, background.color, storm)
	bank.set_light(night, _blood, _flash, background.color)
	if night_tint:
		var tint := _tint.sample(night).lerp(_blood_tint.sample(_level), _blood)
		night_tint.color = tint.lerp(tint * C_STORM_TINT, storm).lerp(Color.WHITE, _flash)

## Cielo de altura: degradé del color del cielo, más oscuro arriba, a transparente abajo.
func _paint_high(ci: CanvasItem) -> void:
	var dark := smoothstep(HIGH_FROM, HIGH_FULL, lift) * HIGH_DARK
	if dark <= 0.0:
		return
	var size := ci.get_viewport_rect().size
	var top := Color(background.color.darkened(0.55), dark)
	var clear := Color(top, 0.0)
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([top, top, clear, clear]))
