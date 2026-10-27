extends Node2D
class_name SpeechBubble
## Globito arriba de la cabeza de un aldeano con lo que está diciendo (ver Villager.say): un
## dibujito (un corazón, una carita, una nota, el sol, un muslo si tiene hambre...) o unos signos. Aparece con un saltito
## y se achica al irse. Lo pone NameTag; (0, 0) es la punta de la colita.
## Los dibujitos también los usan el carnet y NameTag para las relaciones (ver draw_icon).

const SIZE := Vector2(40, 30)
const TAIL := Vector2(5, 7)          # Medio ancho y alto de la colita
const RADIUS := 10
const LINE_W := 2.0
const C_BG := Color(0.99, 0.99, 1.0, 0.97)
const C_LINE := Color(0.05, 0.07, 0.12, 0.9)
const C_INK := Color(0.16, 0.18, 0.26)
const C_HEART := Color(0.93, 0.25, 0.42)
const C_ANGER := Color(1.0, 0.42, 0.32)
const C_FACE := Color(1.0, 0.82, 0.3)
const C_SAD := Color(0.78, 0.86, 0.95)
const C_TEAR := Color(0.3, 0.6, 1.0)
const BG := {
	Villager.Bubble.HEART: Color(1.0, 0.9, 0.95, 0.97),
	Villager.Bubble.ANGER: Color(1.0, 0.86, 0.83, 0.97),
	Villager.Bubble.TEAR: Color(0.88, 0.93, 1.0, 0.97),
	Villager.Bubble.SLEEP: Color(0.92, 0.92, 1.0, 0.97),
}
const POP := 0.2                     # Segundos en aparecer
const SHRINK := 0.15                 # Lo que tarda en irse

var kind := Villager.Bubble.NONE
var _t := 0.0
static var _boxes := {}              # Color de fondo -> StyleBoxFlat

func _ready() -> void:
	visible = false

## Lo que dice y cuánto le falta (lo actualiza NameTag cada cuadro).
func show_bubble(k: Villager.Bubble, time_left: float, dt: float) -> void:
	if k == Villager.Bubble.NONE or time_left <= 0.0:
		kind = Villager.Bubble.NONE   # Así lo siguiente que diga aparece con su saltito
		visible = false
		return
	if k != kind:
		kind = k
		_t = 0.0
		queue_redraw()
	visible = true
	_t += dt
	# Sale con un saltito (se pasa un poco y vuelve) y al final se achica
	var u := minf(1.0, _t / POP) - 1.0
	var s := 1.0 + 2.7 * u * u * u + 1.7 * u * u
	scale = Vector2.ONE * maxf(0.0, s * minf(1.0, time_left / SHRINK))

func _draw() -> void:
	var rect := Rect2(Vector2(-SIZE.x * 0.5, -TAIL.y - SIZE.y), SIZE)
	var bg: Color = BG.get(kind, C_BG)
	if not _boxes.has(bg):
		_boxes[bg] = HUD.make_box(bg, RADIUS, C_LINE, int(LINE_W))
	(_boxes[bg] as StyleBoxFlat).draw(get_canvas_item(), rect)
	# La colita tapa el borde de abajo del globo donde se junta con él
	var l := Vector2(-TAIL.x, -TAIL.y)
	var r := Vector2(TAIL.x * 0.5, -TAIL.y)
	var tip := Vector2(-1.0, 0.0)
	draw_colored_polygon(PackedVector2Array([l + Vector2(0, -LINE_W - 0.5), r + Vector2(0, -LINE_W - 0.5), tip]), bg)
	draw_line(l, tip, C_LINE, LINE_W, true)
	draw_line(r, tip, C_LINE, LINE_W, true)
	draw_icon(self, kind, rect.get_center(), 1.0)

## Dibuja el dibujito de k centrado en c (en ci, desde su _draw). s: escala (1 = del globo,
## unos 18 px).
static func draw_icon(ci: CanvasItem, k: Villager.Bubble, c: Vector2, s: float) -> void:
	match k:
		Villager.Bubble.DOTS:
			for i in 3:
				ci.draw_circle(c + Vector2((i - 1) * 7.0, 1.0) * s, 2.3 * s, C_INK, true, -1.0, true)
		Villager.Bubble.QUESTION:
			_text(ci, "?", c, 20.0 * s, Color(0.22, 0.45, 0.88))
		Villager.Bubble.EXCLAIM:
			_text(ci, "!", c, 20.0 * s, Color(0.95, 0.48, 0.12))
		Villager.Bubble.LAUGH:
			_text(ci, ci.tr("ja ja"), c, 13.0 * s, C_INK)
		Villager.Bubble.MUSIC:
			# Dos corcheas unidas
			var col := Color(0.52, 0.3, 0.82)
			for x: float in [-5.0, 5.0]:
				var head := c + Vector2(x - 2.0, 5.0 - x * 0.2) * s
				ci.draw_set_transform(head, -0.4, Vector2(1.0, 0.75))
				ci.draw_circle(Vector2.ZERO, 3.2 * s, col, true, -1.0, true)
				ci.draw_set_transform(Vector2.ZERO)
				ci.draw_line(head + Vector2(2.6, -0.5) * s, c + Vector2(x + 0.6, -7.5 - x * 0.2) * s, col, 1.6 * s, true)
			ci.draw_line(c + Vector2(-4.4, -6.5) * s, c + Vector2(5.6, -8.5) * s, col, 3.0 * s, true)
		Villager.Bubble.SUN:
			var col := Color(1.0, 0.72, 0.1)
			ci.draw_circle(c, 5.0 * s, col, true, -1.0, true)
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0)
				ci.draw_line(c + d * 7.0 * s, c + d * 9.5 * s, col, 1.8 * s, true)
		Villager.Bubble.HEART:
			ci.draw_colored_polygon(_heart(c, 9.0 * s), C_HEART)
		Villager.Bubble.SMILE:
			_face(ci, c, s, C_FACE)
			ci.draw_arc(c + Vector2(0, 1.0) * s, 4.6 * s, 0.35, PI - 0.35, 10, C_INK, 1.6 * s, true)
		Villager.Bubble.ANGER:
			# Carita roja con las cejas fruncidas
			_face(ci, c, s, C_ANGER)
			ci.draw_line(c + Vector2(-5.5, -5.5) * s, c + Vector2(-1.2, -3.6) * s, C_INK, 1.7 * s, true)
			ci.draw_line(c + Vector2(5.5, -5.5) * s, c + Vector2(1.2, -3.6) * s, C_INK, 1.7 * s, true)
			ci.draw_arc(c + Vector2(0, 7.5) * s, 4.0 * s, PI + 0.6, TAU - 0.6, 10, C_INK, 1.6 * s, true)
		Villager.Bubble.TEAR:
			# Cara triste con una lágrima
			_face(ci, c, s, C_SAD)
			ci.draw_arc(c + Vector2(0, 7.0) * s, 4.0 * s, PI + 0.5, TAU - 0.5, 10, C_INK, 1.6 * s, true)
			var drop := PackedVector2Array()
			var t := c + Vector2(-4.0, 2.5) * s
			for i in 9:
				var a := PI * i / 8.0
				drop.append(t + Vector2(cos(a), sin(a)) * 1.9 * s)
			drop.append(t + Vector2(0, -4.0) * s)
			ci.draw_colored_polygon(drop, C_TEAR)
		Villager.Bubble.SLEEP:
			# Zetas: duerme (o tiene sueño)
			var col := Color(0.36, 0.38, 0.85)
			_text(ci, "z", c + Vector2(-5.0, 3.0) * s, 11.0 * s, col)
			_text(ci, "Z", c + Vector2(4.0, -2.0) * s, 16.0 * s, col)
		Villager.Bubble.HUNGRY:
			# Un muslo de pollo: tiene hambre
			var bone := Color(0.97, 0.95, 0.88)
			ci.draw_line(c + Vector2(1.0, 1.0) * s, c + Vector2(6.5, 6.5) * s, bone, 2.6 * s, true)
			for o: Vector2 in [Vector2(6.0, 8.2), Vector2(8.2, 6.0)]:
				ci.draw_circle(c + o * s, 1.7 * s, bone, true, -1.0, true)
			ci.draw_set_transform(c + Vector2(-2.0, -2.0) * s, -PI * 0.25, Vector2(1.0, 0.72))
			ci.draw_circle(Vector2.ZERO, 6.4 * s, Color(0.62, 0.32, 0.12), true, -1.0, true)
			ci.draw_circle(Vector2(-1.5, -1.5) * s, 4.6 * s, Color(0.82, 0.48, 0.2), true, -1.0, true)
			ci.draw_set_transform(Vector2.ZERO)

## Carita redonda con los ojos.
static func _face(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c, 8.5 * s, col, true, -1.0, true)
	ci.draw_arc(c, 8.5 * s, 0.0, TAU, 24, col.darkened(0.35), 1.2 * s, true)
	ci.draw_circle(c + Vector2(-3.0, -2.2) * s, 1.3 * s, C_INK, true, -1.0, true)
	ci.draw_circle(c + Vector2(3.0, -2.2) * s, 1.3 * s, C_INK, true, -1.0, true)

## Corazón de medio ancho r centrado en c.
static func _heart(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var p := Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		pts.append(c + (p - Vector2(0, 2.5)) * r / 16.0)   # La forma va de -12 a 17: centrada
	return pts

static func _text(ci: CanvasItem, text: String, c: Vector2, size: float, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(round(size))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	ci.draw_string(font, Vector2(c.x - w * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
