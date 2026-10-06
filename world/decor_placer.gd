extends Node2D
class_name DecorPlacer
## Modo colocar: la decoración elegida en la tienda sigue al mouse (verde si se puede,
## roja si no). Click en la isla la coloca y cobra; se puede seguir colocando mientras
## alcancen las ofrendas. Click derecho o Esc termina.

const MIN_GAP := 14.0       # Distancia mínima entre decoraciones

var hud: HUD
var props: Node2D           # Contenedor ordenado por Y donde viven aldeanos y decoraciones
var island_poly: PackedVector2Array
var kind := ""
var _ghost: Decoration

func _ready() -> void:
	z_index = 20            # La vista previa por encima de todo

func start(k: String) -> void:
	stop()
	kind = k
	_ghost = Decoration.new()
	_ghost.kind = k
	_ghost.ghost = true
	add_child(_ghost)
	_update_ghost()
	if hud:
		hud.set_placing(true)

func stop() -> void:
	kind = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if hud:
		hud.set_placing(false)

func is_active() -> bool:
	return kind != ""

func _process(_dt: float) -> void:
	if _ghost:
		_update_ghost()

func _update_ghost() -> void:
	var base := get_global_mouse_position()
	_ghost.global_position = base - Vector2(0, Decoration.LIFT)
	_ghost.valid = _can_place(_ghost.global_position)

## Mismo criterio que los aldeanos: el origen tiene que caer dentro de la isla.
func _can_place(p: Vector2) -> bool:
	if island_poly.size() == 0 or not Geometry2D.is_point_in_polygon(p, island_poly):
		return false
	for c in props.get_children():
		if c is Decoration and c.global_position.distance_to(p) < MIN_GAP:
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if kind == "":
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		stop()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()  # Que no agarre aldeanos mientras coloca
		if event.button_index == MOUSE_BUTTON_RIGHT:
			stop()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_place()

func _place() -> void:
	var pos := _ghost.global_position
	var screen := get_viewport().get_canvas_transform() * pos
	if not _can_place(pos):
		hud.popup_text("Solo sobre la isla", screen, HUD.C_WARN)
		return
	var price := Decoration.price_of(kind)
	if not hud.spend_offerings(price):
		hud.popup_text("No te alcanzan las ofrendas", screen, HUD.C_WARN)
		stop()
		return
	var d := Decoration.new()
	d.kind = kind
	props.add_child(d)
	d.global_position = pos
	_puff(pos + Vector2(0, Decoration.LIFT))
	if not hud.can_afford(price):
		stop()

func _puff(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 16
	p.lifetime = 0.5
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1.0, 0.86, 0.45)
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
