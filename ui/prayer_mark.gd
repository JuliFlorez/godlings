extends Node2D
class_name PrayerMark
## Lo que un aldeano te está pidiendo (ver VillagerPrayer), arriba de su cabeza mientras espera:
## un redondel dorado con el dibujito (un muslo: comida; una cruz verde: una cura; un corazón con
## una cruz: que cures a alguien que quiere; un rayo: que castigues a un enemigo; una casita) y
## alrededor un aro que se va gastando con la paciencia que le queda (al final, rojo y latiendo).
## Lo pone NameTag; (0, 0) es el centro.

const RADIUS := 11.0
const RING_W := 3.0
const C_BG := Color(1.0, 0.97, 0.86, 0.97)
const C_RING := UiStyle.C_OFFERING
const C_LATE := UiStyle.C_WARN
const C_CROSS := Color(0.25, 0.72, 0.38)
const C_BOLT := Color(0.98, 0.72, 0.1)
const C_HOUSE := Color(0.62, 0.4, 0.2)
const C_ROOF := Color(0.86, 0.36, 0.26)
const LATE := 0.25                   # Con esta paciencia o menos, apura
const POP := 0.2                     # Segundos en aparecer

var ask := VillagerPrayer.Ask.NONE
var _left := 1.0
var _t := 0.0

func _ready() -> void:
	visible = false

## Lo que pide y la paciencia que le queda (1..0); lo actualiza NameTag cada cuadro.
func show_ask(a: VillagerPrayer.Ask, left: float, dt: float) -> void:
	if a == VillagerPrayer.Ask.NONE:
		ask = a
		visible = false
		return
	if a != ask:
		ask = a
		_t = 0.0
	_left = left
	_t += dt
	visible = true
	# Sale con un saltito, y cuando se le acaba la paciencia late
	var u := minf(1.0, _t / POP) - 1.0
	var s := 1.0 + 2.7 * u * u * u + 1.7 * u * u
	if left <= LATE:
		s *= 1.0 + 0.08 * sin(_t * 10.0)
	scale = Vector2.ONE * maxf(0.0, s)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + RING_W + 1.0, UiStyle.C_INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, RADIUS, C_BG, true, -1.0, true)
	if _left > 0.0:
		var col := C_LATE if _left <= LATE else C_RING
		draw_arc(Vector2.ZERO, RADIUS + RING_W * 0.5, -PI * 0.5, -PI * 0.5 + TAU * _left, 32, col, RING_W, true)
	draw_ask(self, ask, Vector2.ZERO, 0.62)

## El dibujito de lo que pide, centrado en c (s: escala, como SpeechBubble.draw_icon).
static func draw_ask(ci: CanvasItem, a: VillagerPrayer.Ask, c: Vector2, s: float) -> void:
	match a:
		VillagerPrayer.Ask.FOOD:
			SpeechBubble.draw_icon(ci, Villager.Bubble.HUNGRY, c, s)
		VillagerPrayer.Ask.CURE:
			_cross(ci, c, 8.0 * s, 5.0 * s, C_CROSS)
		VillagerPrayer.Ask.HEAL:
			SpeechBubble.draw_icon(ci, Villager.Bubble.HEART, c, s)
			_cross(ci, c + Vector2(0, -0.5) * s, 4.5 * s, 2.6 * s, Color.WHITE)
		VillagerPrayer.Ask.SMITE:
			var bolt := PackedVector2Array([Vector2(2, -10), Vector2(-6, 1), Vector2(-1, 1), Vector2(-3, 10),
					Vector2(6, -2), Vector2(1, -2), Vector2(4, -10)])
			for i in bolt.size():
				bolt[i] = c + bolt[i] * s
			ci.draw_colored_polygon(bolt, C_BOLT)
			bolt.append(bolt[0])
			ci.draw_polyline(bolt, C_BOLT.darkened(0.45), 1.2 * s, true)
		VillagerPrayer.Ask.HOME:
			ci.draw_rect(Rect2(c + Vector2(-6, -1) * s, Vector2(12, 9) * s), C_HOUSE)
			ci.draw_rect(Rect2(c + Vector2(-1.5, 3) * s, Vector2(3, 5) * s), C_HOUSE.darkened(0.5))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -1) * s, c + Vector2(0, -10) * s,
					c + Vector2(9, -1) * s]), C_ROOF)

## Una cruz de medio largo r y de ancho w.
static func _cross(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color) -> void:
	ci.draw_rect(Rect2(c - Vector2(r, w * 0.5), Vector2(r * 2.0, w)), col)
	ci.draw_rect(Rect2(c - Vector2(w * 0.5, r), Vector2(w, r * 2.0)), col)
