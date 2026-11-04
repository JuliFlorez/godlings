extends Node2D
class_name Painter
## Lienzo en overlay que pide a paint(lienzo) que lo dibuje cada cuadro (ver Lightning y Meteor).

var paint: Callable

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if paint.is_valid():
		paint.call(self)
