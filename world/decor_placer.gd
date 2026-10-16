extends Node2D
class_name DecorPlacer
## Modo colocar: la decoración elegida en la tienda sigue al mouse (verde si se puede,
## roja si no). Click en la isla la coloca y cobra; se puede seguir colocando mientras
## alcancen las ofrendas. Click derecho o Esc termina.
##
## Fuera de ese modo, las decoraciones ya puestas se editan: se arrastran con click
## izquierdo para moverlas (si se sueltan fuera de la isla vuelven a su lugar) y con
## click derecho se quitan, devolviendo la mitad de lo que costaron.
## Los cocos (en la copa de las palmeras o sueltos) también se agarran con click izquierdo.

const MIN_GAP := 14.0       # Distancia mínima entre decoraciones
const REFUND := 0.5         # Parte del precio que se devuelve al quitar una decoración

enum Edit { NONE, HOVER, MOVING, COCONUT, COCONUT_HELD }

var hud: HUD
var props: Node2D           # Contenedor ordenado por Y donde viven aldeanos y decoraciones
var island_poly: PackedVector2Array:
	set(v):
		island_poly = v
		Coconut.island_poly = v
var kind := ""
var _ghost: Decoration

## Lo que está bajo el mouse: {"deco": Decoration}, {"palm": Decoration, "slot": int}
## (un coco en la copa), {"nut": Coconut} (un coco suelto), o vacío.
var _hover := {}
var _moving: Decoration
var _move_from := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _held_nut: Coconut

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
	_set_hover({})
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
	elif _held_nut:
		# El coco se suelta solo (escucha el click); acá solo se nota que ya no está en la mano
		if not is_instance_valid(_held_nut) or _held_nut.state != Coconut.State.HELD:
			_held_nut = null
			if not Gun.armed:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			_sync_hud()
	else:
		_set_hover(_pick(get_global_mouse_position()))

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

# ---- Editar decoraciones ya puestas y agarrar cocos ----
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
	var h := _pick(get_global_mouse_position())
	if h.is_empty():
		return
	get_viewport().set_input_as_handled()   # Que no agarre al aldeano de atrás
	if event.button_index == MOUSE_BUTTON_LEFT:
		if h.has("nut"):
			_grab_nut(h.nut)
		elif h.has("palm"):
			var nut := Coconut.new()
			props.add_child(nut)
			nut.set_point(h.palm.coconut_global(h.slot))
			h.palm.take_coconut(h.slot)
			_grab_nut(nut)
		else:
			_start_move(h.deco)
	elif event.button_index == MOUSE_BUTTON_RIGHT and h.has("deco"):
		_remove(h.deco)

## Lo que se puede agarrar bajo el mouse (lo de más adelante): primero los cocos sueltos,
## después los de las palmeras y por último las decoraciones. Vacío si no hay nada o si
## hay un aldeano delante: agarrar aldeanos tiene prioridad.
func _pick(p: Vector2) -> Dictionary:
	if Gun.armed or _held_nut or get_tree().paused or get_viewport().gui_get_hovered_control() != null:
		return {}
	for v in get_tree().get_nodes_in_group("villager"):
		if v is Villager and v.dragging:
			return {}
	var best := {}
	var best_y := -INF
	for n in get_tree().get_nodes_in_group("coconut"):
		if n is Coconut and n.can_grab() and n.point().distance_to(p) <= Coconut.GRAB_R and n.global_position.y > best_y:
			best = {"nut": n}
			best_y = n.global_position.y
	if best.is_empty():
		for c in props.get_children():
			if c is Decoration and c.global_position.y > best_y:
				var slot: int = c.coconut_at(p)
				if slot >= 0:
					best = {"palm": c, "slot": slot}
					best_y = c.global_position.y
	if best.is_empty():
		for c in props.get_children():
			if c is Decoration and c.hit_test(p) and c.global_position.y > best_y:
				best = {"deco": c}
				best_y = c.global_position.y
	if best.is_empty():
		return {}
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	for hit in get_world_2d().direct_space_state.intersect_point(q, 8):
		var v := hit.collider as Villager
		if v and v.global_position.y >= best_y:
			return {}
	return best

func _set_hover(h: Dictionary) -> void:
	if h == _hover:
		return
	_show_hover(_hover, false)
	_hover = h
	_show_hover(h, true)
	if not Gun.armed:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW if h.is_empty() else Input.CURSOR_POINTING_HAND)
	_sync_hud()

func _show_hover(h: Dictionary, on: bool) -> void:
	if h.has("deco") and is_instance_valid(h.deco):
		h.deco.hovered = on
	elif h.has("palm") and is_instance_valid(h.palm):
		h.palm.hover_coconut = h.slot if on else -1
	elif h.has("nut") and is_instance_valid(h.nut):
		h.nut.hovered = on

func _grab_nut(n: Coconut) -> void:
	_set_hover({})
	n.grab()
	_held_nut = n
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	_sync_hud()

func _start_move(d: Decoration) -> void:
	_set_hover({})
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
	_set_hover({})
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
	if not hud:
		return
	var state := Edit.NONE
	if _moving:
		state = Edit.MOVING
	elif _held_nut:
		state = Edit.COCONUT_HELD
	elif _hover.has("deco"):
		state = Edit.HOVER
	elif not _hover.is_empty():
		state = Edit.COCONUT
	hud.set_decor_edit(state)

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
