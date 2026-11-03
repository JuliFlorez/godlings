extends Node2D
class_name ZapArcs
## Chispazos que le recorren el cuerpo mientras se electrocuta (coords del aldeano).

var _arcs: Array[PackedVector2Array] = []
var _t := 0.0

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.05
	_arcs.clear()
	for i in randi_range(2, 3):
		var a := Vector2(randf_range(-16.0, 16.0), randf_range(Villager.HEAD_TOP + 4.0, Villager.FEET - 4.0))
		var b := a + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 22.0)
		_arcs.append(Lightning.jagged(a, b, 0.35, 3))
	queue_redraw()

func _draw() -> void:
	for a in _arcs:
		Lightning.paint_bolt(self, a, 1.1, 1.0)
