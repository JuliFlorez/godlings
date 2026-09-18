extends CharacterBody2D

@export var speed := 40.0
var dir := Vector2.ZERO

var island_center := Vector2.ZERO
var island_poly: PackedVector2Array:
	set(value):
		island_poly = value
		if island_poly.size() > 0:
			var sum := Vector2.ZERO
			for p in island_poly:
				sum += p
			island_center = sum / float(island_poly.size())

var dragging := false
var drag_offset := Vector2.ZERO

# HUD / XP
@export var hud_path: NodePath
var hud: HUD
var xp_granted := false      # Evita sumar dos veces por ahogo

# --- Caída / Gravedad fuera de la isla ---
const GRAVITY := 1400.0
var falling := false
var v_fall := 0.0

# --- Agua / Flotación + Ahogo ---
var in_water := false
var water_surface_y := 0.0
var bob_t := 0.0
const BOB_AMP := 6.0
const BOB_SPEED := 2.2

# Ahogo
const DROWN_DELAY := 5.0      # Segundos antes de empezar a hundirse
const SINK_SPEED  := 120.0    # px/s al hundirse
const FADE_RATE   := 0.6      # Alfa por segundo que se reduce
var drowning := false
var drown_elapsed := 0.0

# IA y animaciones
var wander_timer := 0.0
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	randomize()
	_pick_dir()
	wander_timer = randf_range(1.5, 4.0)
	input_pickable = true

	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	_ensure_hud()

func _ensure_hud() -> void:
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud") as HUD

func enter_water(surface_y: float) -> void:
	in_water = true
	falling = false
	drowning = false
	drown_elapsed = 0.0
	v_fall = 0.0
	water_surface_y = surface_y
	bob_t = 0.0
	modulate.a = 1.0
	rotation = 0.0
	z_index = 0

func exit_water() -> void:
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	rotation = 0.0
	modulate.a = 1.0

func _physics_process(dt: float) -> void:
	if dragging:
		velocity = Vector2.ZERO
		return

	# --- Agua: flotar o ahogarse ---
	if in_water:
		bob_t += dt

		# Temporizador de ahogo
		if not drowning:
			drown_elapsed += dt
			if drown_elapsed >= DROWN_DELAY:
				drowning = true
				if not xp_granted:
					xp_granted = true
					_ensure_hud()
					if hud and hud.has_method("add_xp"):
						hud.add_xp(1)
						print("[XP] +1 por sacrificio en agua. XP actual=", hud.xp)

		if drowning:
			# Hundirse y desvanecerse
			global_position.y += SINK_SPEED * dt
			modulate.a = max(0.0, modulate.a - FADE_RATE * dt)
			rotation = lerp_angle(rotation, 0.5, 3.0 * dt)
			velocity = Vector2.ZERO
			if modulate.a <= 0.02:
				queue_free()
			return
		else:
			# Flotación suave y balanceo
			var target_y := water_surface_y + sin(bob_t * BOB_SPEED) * BOB_AMP
			global_position.y = move_toward(global_position.y, target_y, 120.0 * dt)
			global_position.x += sin(bob_t * 0.8) * 10.0 * dt
			rotation = sin(bob_t * 0.9) * 0.08
			velocity = Vector2.ZERO
			return

	# --- Caída libre fuera de la isla ---
	if falling:
		v_fall += GRAVITY * dt
		global_position.y += v_fall * dt
		rotation += 2.0 * dt

		# Si cae de regreso a la tierra
		if island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly):
			_land_on_island()
			return

		var kill_y := get_viewport().get_visible_rect().size.y + 150.0
		if global_position.y > kill_y:
			queue_free()
		return

	# --- IA normal caminando en la isla ---
	velocity = dir * speed
	move_and_slide()

	# Si cruza el borde del polígono de la isla, retroceder y girar hacia el centro
	if island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(global_position, island_poly):
		global_position -= velocity * dt
		var to_center := (island_center - global_position).normalized()
		dir = to_center.rotated(randf_range(-0.35, 0.35)).normalized()
		_update_sprite_flip()
		wander_timer = randf_range(1.5, 3.5)
	else:
		wander_timer -= dt
		if wander_timer <= 0.0:
			_pick_dir()
			wander_timer = randf_range(2.0, 5.0)

func _pick_dir() -> void:
	var angle := randf() * TAU
	dir = Vector2(cos(angle), sin(angle)).normalized()
	_update_sprite_flip()

func _update_sprite_flip() -> void:
	if sprite and abs(dir.x) > 0.05:
		sprite.flip_h = dir.x < 0.0

# --- MECÁNICA DE ARRASTRE (DRAG & DROP) ---
func _process(_dt: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging:
			_start_drag()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Atrapa el soltado del click izquierdo en cualquier parte de la pantalla
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_drag()
		get_viewport().set_input_as_handled()

func _start_drag() -> void:
	dragging = true
	drag_offset = global_position - get_global_mouse_position()
	set_physics_process(false)
	z_index = 10
	# Si estaba medio desvanecido al ser rescatado, restaurar visibilidad parcial
	if drowning:
		modulate.a = max(modulate.a, 0.7)

func _stop_drag() -> void:
	dragging = false
	set_physics_process(true)
	z_index = 0

	var on_island := island_poly.size() > 0 and Geometry2D.is_point_in_polygon(global_position, island_poly)
	if on_island:
		# Rescatado o depositado en tierra firme
		_land_on_island()
	else:
		if in_water:
			# Soltado dentro del agua: continúa flotando
			falling = false
			velocity = Vector2.ZERO
		else:
			# Soltado en el aire fuera de la isla: empieza caída libre
			_start_fall()

func _start_fall() -> void:
	falling = true
	drowning = false
	drown_elapsed = 0.0
	v_fall = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0

func _land_on_island() -> void:
	falling = false
	v_fall = 0.0
	in_water = false
	drowning = false
	drown_elapsed = 0.0
	rotation = 0.0
	modulate.a = 1.0
	velocity = Vector2.ZERO
	_pick_dir()
