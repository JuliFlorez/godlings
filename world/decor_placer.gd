extends Node2D
class_name DecorPlacer
## Modo colocar: la decoración elegida en la tienda sigue al mouse (verde si se puede,
## roja si no). Click en la isla la coloca y cobra; se puede seguir colocando mientras
## alcancen las ofrendas. Click derecho o Esc termina.
##
## Fuera de ese modo, las decoraciones ya puestas se editan: se arrastran con click
## izquierdo para moverlas (si se sueltan fuera de la isla vuelven a su lugar) y con
## click derecho se quitan, devolviendo la mitad de lo que costaron.

const MIN_GAP := 14.0       # Distancia mínima entre decoraciones
const REFUND := 0.5         # Parte del precio que se devuelve al quitar una decoración

enum Edit { NONE, HOVER, MOVING }

var hud: HUD
var props: Node2D           # Contenedor ordenado por Y donde viven aldeanos y decoraciones
var island_poly: PackedVector2Array
var kind := ""
var _ghost: Decoration

var _hovered: Decoration
var _moving: Decoration
var _move_from := Vector2.ZERO
var _grab_offset := Vector2.ZERO

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
	_cancel_move()
	_set_hovered(null)
	if hud:
		hud.set_placing(false)

func is_active() -> bool:
	return kind != ""

func _process(_dt: float) -> void:
	if _ghost:
		_update_ghost()
	elif _moving:
		_moving.global_position = get_global_mouse_position() - _grab_offset
		_moving.valid = _can_place(_moving.global_position, _moving)
	else:
		_set_hovered(_pick(get_global_mouse_position()))

func _update_ghost() -> void:
	var base := get_global_mouse_position()
	_ghost.global_position = base - Vector2(0, Decoration.LIFT)
	_ghost.valid = _can_place(_ghost.global_position)

## Mismo criterio que los aldeanos: el origen tiene que caer dentro de la isla.
func _can_place(p: Vector2, ignore: Decoration = null) -> bool:
	if island_poly.size() == 0 or not Geometry2D.is_point_in_polygon(p, island_poly):
		return false
	for c in props.get_children():
		if c is Decoration and c != ignore and c.global_position.distance_to(p) < MIN_GAP:
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if kind == "":
		_edit_input(event)
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

func _input(event: InputEvent) -> void:
	# Atrapa el soltado del click izquierdo en cualquier parte de la pantalla
	if _moving and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop()
		get_viewport().set_input_as_handled()

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

# ---- Editar decoraciones ya puestas ----
func _edit_input(event: InputEvent) -> void:
	if _moving:
		var esc: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
		var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
		if esc or right:
			_cancel_move()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var d := _pick(get_global_mouse_position())
	if d == null:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_start_move(d)
		get_viewport().set_input_as_handled()   # Que no agarre al aldeano de atrás
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_remove(d)
		get_viewport().set_input_as_handled()

## La decoración bajo el mouse (la de más adelante), o null si no hay o si hay un
## aldeano delante: agarrar aldeanos tiene prioridad.
func _pick(p: Vector2) -> Decoration:
	if Gun.armed or get_tree().paused or get_viewport().gui_get_hovered_control() != null:
		return null
	var front: Decoration
	for c in props.get_children():
		if c is Decoration and c.hit_test(p) and (front == null or c.global_position.y > front.global_position.y):
			front = c
	if front == null:
		return null
	for v in get_tree().get_nodes_in_group("villager"):
		if v is Villager and v.dragging:
			return null
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	for hit in get_world_2d().direct_space_state.intersect_point(q, 8):
		var v := hit.collider as Villager
		if v and v.global_position.y >= front.global_position.y:
			return null
	return front

func _set_hovered(d: Decoration) -> void:
	if d == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.hovered = false
	_hovered = d
	if d:
		d.hovered = true
	if not Gun.armed:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if d else Input.CURSOR_ARROW)
	_sync_hud()

func _start_move(d: Decoration) -> void:
	_set_hovered(null)
	_moving = d
	_move_from = d.global_position
	_grab_offset = get_global_mouse_position() - d.global_position
	d.moving = true
	d.valid = true
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	_sync_hud()

func _drop() -> void:
	var d := _moving
	if not _can_place(d.global_position, d):
		hud.popup_text("Solo sobre la isla", get_viewport().get_canvas_transform() * d.global_position, HUD.C_WARN)
		_cancel_move()
		return
	_moving = null
	d.moving = false
	_puff(d.global_position + Vector2(0, Decoration.LIFT), 8)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_sync_hud()

## Vuelve a donde estaba antes de agarrarla.
func _cancel_move() -> void:
	if _moving == null:
		return
	var d := _moving
	_moving = null
	d.moving = false
	var tw := d.create_tween()
	tw.tween_property(d, "global_position", _move_from, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not Gun.armed:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_sync_hud()

func _remove(d: Decoration) -> void:
	_set_hovered(null)
	var refund := maxi(1, int(Decoration.price_of(d.kind) * REFUND))
	hud.add_offerings(refund)
	hud.popup_text(tr("+%d ofrendas") % refund, get_viewport().get_canvas_transform() * d.global_position + Vector2(0, -40), HUD.C_OFFERING)
	_puff(d.global_position + Vector2(0, Decoration.LIFT))
	# Fuera de Props: ya no cuenta para el espacio libre ni se puede volver a agarrar
	d.reparent(get_parent())
	var tw := d.create_tween()
	tw.tween_property(d, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(d.queue_free)

func _sync_hud() -> void:
	if hud:
		hud.set_decor_edit(Edit.MOVING if _moving else (Edit.HOVER if _hovered else Edit.NONE))

func _puff(at: Vector2, amount := 16) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
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
