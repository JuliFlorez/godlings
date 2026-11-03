extends Node2D
class_name BloodPool

const COLOR := Color(0.55, 0.02, 0.03, 0.85)
var radius := 0.0

func _ready() -> void:
	var tw := create_tween()
	tw.tween_property(self, "radius", randf_range(13.0, 18.0), 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(Villager.CORPSE_TIME)
	tw.tween_property(self, "modulate:a", 0.0, 2.0)
	tw.tween_callback(queue_free)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, radius, COLOR, true, -1.0, true)
	draw_circle(Vector2(radius * 0.35, -radius * 0.2), radius * 0.55, COLOR.darkened(0.15), true, -1.0, true)
