extends Area2D

@onready var col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _surface_y() -> float:
	if col and col.shape is RectangleShape2D:
		var r := col.shape as RectangleShape2D
		var half_h := r.size.y * 0.5
		var top_local := Vector2(0, -half_h)
		return col.to_global(top_local).y
	return global_position.y

func _on_body_entered(b: Node) -> void:
	if b is CollisionObject2D:
		print("[WATER] entered: ", b.name, " layer=", (b as CollisionObject2D).collision_layer)
	if b.has_method("enter_water"):
		b.enter_water(_surface_y())

func _on_body_exited(b: Node) -> void:
	if b.has_method("exit_water"):
		b.exit_water()
