extends Area2D
class_name WaterArea
## El agua del mar: lo que cae o se suelta adentro flota (ver Villager.enter_water, Shark).
## Arranca en la orilla de adelante (la superficie de siempre, delante de la isla) y va hacia la
## cámara hasta mucho más allá de lo que se llega a ver con la cámara corrida para abajo o el zoom
## alejado (ver World.PAN_MARGIN y ZOOM_MIN), y a los costados tanto como el dibujo del mar (ver
## Sea). El mar es un piso: cada cosa flota a su distancia (lo que cae desde arriba, en la orilla).
## La forma de la escena es la franja de la orilla; el resto se agrega al arrancar (así no hay
## que tocar world.tscn, que el editor abierto vuelve a guardar).

## Tamaño del agua, en pantallas (de ancho, centrado; y de alto, desde la orilla para abajo).
const REACH := Vector2(4.0, 1.8)

@onready var col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("water")   # Los cocos lo buscan para saber si cayeron al agua
	monitoring = true
	monitorable = true
	_extend()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

## Desde la orilla (el borde de arriba de la franja de la escena) hasta REACH.
func _extend() -> void:
	if not (col and col.shape is RectangleShape2D):
		return
	var top := _surface_y()
	var view := get_viewport_rect().size
	var size := view * REACH
	var shape := RectangleShape2D.new()
	shape.size = size / col.global_scale.abs()
	col.shape = shape
	col.global_position = Vector2(view.x * 0.5, top + size.y * 0.5)

func _surface_y() -> float:
	if col and col.shape is RectangleShape2D:
		var r := col.shape as RectangleShape2D
		var half_h := r.size.y * 0.5
		var top_local := Vector2(0, -half_h)
		return col.to_global(top_local).y
	return global_position.y

func get_global_rect() -> Rect2:
	if col and col.shape is RectangleShape2D:
		var half := (col.shape as RectangleShape2D).size * 0.5
		var a := col.to_global(-half)
		var b := col.to_global(half)
		return Rect2(a, Vector2.ZERO).expand(b)
	return Rect2(global_position, Vector2.ZERO)

## La superficie del mar a la distancia y (en la orilla si está más atrás).
static func level_at(tree: SceneTree, y: float) -> float:
	var w := tree.get_first_node_in_group("water")
	if w == null or not w.has_method("get_global_rect"):
		return y
	var r: Rect2 = w.get_global_rect()
	return clampf(y, r.position.y, r.end.y)

func _on_body_entered(b: Node) -> void:
	if b.has_method("enter_water"):
		b.enter_water(_surface_y())

func _on_body_exited(b: Node) -> void:
	if b.has_method("exit_water"):
		b.exit_water()
