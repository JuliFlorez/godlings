class_name UiStyle
## El estilo de la interfaz, en un solo lugar: la paleta (los colores de los paneles, los textos,
## la XP, la devoción, las ofrendas y el de cada poder) y las piezas con las que se arma todo
## (texto, botón, caja, ventana y contorno). Para cambiar un color o cómo se ve un botón en todo el
## juego, es acá. Todo es estático: UiStyle.C_TEXT, UiStyle.label(...).

# --- Paleta ---
const C_PANEL := Color(0.06, 0.09, 0.16, 0.78)          # Los paneles del HUD (las ventanas, más opacas)
const C_PANEL_BORDER := Color(1, 1, 1, 0.12)
const C_INK := Color(0.05, 0.07, 0.12, 0.9)             # El contorno de los textos y globitos sobre el mundo
const C_TRACK := Color(1, 1, 1, 0.10)                   # El fondo de las barras
const C_XP := Color(1.0, 0.76, 0.22)
const C_DEVOTION := Color(0.42, 0.82, 1.0)
const C_TEXT := Color(0.96, 0.97, 1.0)
const C_MUTED := Color(0.72, 0.77, 0.88)
const C_WARN := Color(1.0, 0.55, 0.45)
const C_SPAWN := Color(0.98, 0.58, 0.24)
const C_EXPAND := Color(0.98, 0.78, 0.22)
const C_GUN := Color(0.9, 0.36, 0.32)
const C_ZAP := Color(1.0, 0.86, 0.3)
const C_METEOR := Color(1.0, 0.55, 0.22)
const C_TORNADO := Color(0.78, 0.82, 0.9)
const C_RAIN := Color(0.42, 0.62, 1.0)
const C_SOON := Color(1.0, 0.8, 0.3)
const C_OFFERING := Color(1.0, 0.84, 0.34)
const C_SHOP := Color(0.46, 0.84, 0.52)
const C_PLAGUE := Color(0.55, 0.85, 0.3)
const C_SPORE := Color(0.98, 0.64, 0.28)
const C_CURE := Color(1.0, 0.88, 0.45)
const C_HISTORY := Color(0.74, 0.66, 1.0)
const C_FEED := Color(1.0, 0.68, 0.32)
const C_SUN := Color(1.0, 0.8, 0.3)
const C_MOON := Color(0.72, 0.76, 1.0)
const C_EVIL := Color(0.92, 0.3, 0.26)
const C_HOLY := Color(1.0, 0.86, 0.4)

const WINDOW_RADIUS := 16       # Las esquinas de las ventanas (ver window)

## Un texto de ese tamaño y color, centrado en vertical.
static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Botón de los menús (pausa, opciones, inicio), del color de fondo que se le pida.
static func button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", box(color, 8, color.lightened(0.25), 1))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15), 8, color.lightened(0.45), 1))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 8, color.darkened(0.3), 1))
	return b

## Una caja redondeada: el fondo, el radio de las esquinas, el borde y su ancho, y el margen de
## adentro (izquierda, arriba, derecha, abajo).
static func box(bg: Color, radius: int, border := Color(0, 0, 0, 0), border_w := 0, pad := Vector4.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	return s

## El fondo de las ventanas (la tienda, el carnet, el historial, la pausa...): el azul de los
## paneles, con esa opacidad, y el margen de adentro.
static func window(alpha: float, pad: Vector4) -> StyleBoxFlat:
	return box(Color(C_PANEL, alpha), WINDOW_RADIUS, C_PANEL_BORDER, 1, pad)

## Le pone contorno a un texto (para que se lea encima del mundo o del cielo).
static func outline(l: Label, size: int, color := C_INK) -> void:
	l.add_theme_color_override("font_outline_color", color)
	l.add_theme_constant_override("outline_size", size)
