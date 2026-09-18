# HUD.gd
extends CanvasLayer
class_name HUD

@export var xp_max: int = 100
@export var energy_max: float = 100.0
@export var energy_refill_minutes: float = 5.0  # 5 min para llenarse de 0 a 100

var xp: int = 0
var energy: float = 100.0
var _refill_rate: float = 0.0  # puntos de energía por segundo

@onready var xp_bar: ProgressBar = get_node_or_null("VBoxContainer/HBoxContainer/XpBar")
@onready var energy_bar: ProgressBar = get_node_or_null("VBoxContainer/HBoxContainer2/EnergyBar")

func _ready():
	add_to_group("hud")

	# Salvaguardas en caso de que vengan propiedades en null o no válidas
	if xp_max == null or xp_max <= 0:
		xp_max = 100
	if energy_max == null or energy_max <= 0.0:
		energy_max = 100.0
	if energy_refill_minutes == null or energy_refill_minutes <= 0.0:
		energy_refill_minutes = 5.0

	_refill_rate = energy_max / (energy_refill_minutes * 60.0)

	if xp_bar:
		xp_bar.max_value = xp_max
		xp_bar.show_percentage = true
	if energy_bar:
		energy_bar.max_value = energy_max
		energy_bar.show_percentage = true

	_update_bars()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Sigue cargando aunque pierda foco

func _process(delta: float):
	# Recarga suave de Devoción
	if energy < energy_max:
		energy = min(energy_max, energy + _refill_rate * delta)
		_update_bars()

# ---- API simple para usar desde otros scripts ----
func add_xp(amount: int) -> void:
	xp = clampi(xp + amount, 0, xp_max)
	_update_bars()

func spend_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		_update_bars()
		return true
	return false

func can_spend_energy(amount: float) -> bool:
	return energy >= amount

func _update_bars() -> void:
	if xp_bar:
		xp_bar.value = xp
	if energy_bar:
		energy_bar.value = energy
