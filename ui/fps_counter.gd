extends CanvasLayer
class_name FpsCounter
## Fotogramas por segundo en la esquina de abajo a la derecha (opción "Fotogramas (FPS)",
## ver Settings). Cuelga de la raíz, así sigue al volver al menú de inicio.

const MARGIN := 10.0
const REFRESH := 0.25   # Segundos entre actualizaciones (si no, el número no se puede leer)

var _label: Label
var _t := 0.0

func _ready() -> void:
	layer = 100   # Arriba de todo, también de los menús
	process_mode = Node.PROCESS_MODE_ALWAYS   # Sigue contando en pausa
	_label = HUD.make_label("", 13, HUD.C_TEXT)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_label)
	_update()

func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_update()

func _update() -> void:
	_t = REFRESH
	_label.text = "%d FPS" % roundi(Engine.get_frames_per_second())
