extends Node2D
class_name Decoration
## Decoración de la isla (palmera, arbusto, flores, roca, antorcha), dibujada por código.
## El origen del nodo queda LIFT px arriba de la base, igual que el centro de un aldeano,
## para que el orden por Y (quién tapa a quién) sea parejo entre ambos.

const LIFT := 30.0

## Catálogo de la tienda. "icon_scale" ajusta el dibujo al recuadro del ícono.
const KINDS := {
	"palm": {"name": "Palmera", "price": 15, "icon_scale": 0.42},
	"bush": {"name": "Arbusto", "price": 8, "icon_scale": 1.3},
	"flowers": {"name": "Flores", "price": 6, "icon_scale": 1.7},
	"rock": {"name": "Roca", "price": 5, "icon_scale": 1.5},
	"torch": {"name": "Antorcha", "price": 12, "icon_scale": 0.62},
}

const FLOWER_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.65), Color(0.95, 0.2, 0.25), Color(1.0, 0.98, 0.95),
	Color(0.7, 0.45, 1.0), Color(1.0, 0.6, 0.15),
]

var kind := "palm"
var variant := 0.5          # 0..1: varía inclinación, alto, colores
var ghost := false          # Vista previa al colocar
var valid := true:
	set(v):
		valid = v
		modulate = (Color(1, 1, 1, 0.65) if v else Color(1.0, 0.35, 0.35, 0.65)) if ghost else Color.WHITE

func _ready() -> void:
	if not ghost:
		variant = randf()
	valid = valid

func _process(_dt: float) -> void:
	# La palmera se mece y la antorcha titila
	if kind == "palm" or kind == "torch":
		queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, LIFT))
	paint(self, kind, variant, Time.get_ticks_msec() / 1000.0)

static func price_of(k: String) -> int:
	return KINDS[k].price

## Dibuja la decoración con la base en el origen (hacia arriba es -y).
static func paint(ci: CanvasItem, k: String, v: float, t: float) -> void:
	ci.draw_colored_polygon(_ellipse(Vector2(0, 2), 20 if k == "palm" else 14, 5), Color(0, 0, 0, 0.18))
	match k:
		"palm": _paint_palm(ci, v, t)
		"bush": _paint_bush(ci, v)
		"flowers": _paint_flowers(ci, v)
		"rock": _paint_rock(ci, v)
		"torch": _paint_torch(ci, t)

static func _paint_palm(ci: CanvasItem, v: float, t: float) -> void:
	var lean := lerpf(-16.0, 16.0, v)
	var h := lerpf(92.0, 116.0, fposmod(v * 7.3, 1.0))
	# Tronco en segmentos, más finito arriba
	var n := 8
	for i in n:
		var a := float(i) / n
		var b := float(i + 1) / n
		var pa := Vector2(lean * a * a, -h * a)
		var pb := Vector2(lean * b * b, -h * b)
		var wa := lerpf(7.0, 4.0, a)
		var wb := lerpf(7.0, 4.0, b)
		var col := Color(0.55, 0.36, 0.2) if i % 2 == 0 else Color(0.48, 0.3, 0.16)
		ci.draw_colored_polygon(PackedVector2Array([pa + Vector2(-wa, 0), pb + Vector2(-wb, 0), pb + Vector2(wb, 0), pa + Vector2(wa, 0)]), col)
	var top := Vector2(lean, -h)
	# Hojas: curvas que caen, meciéndose con el viento
	var angles := [-172.0, -145.0, -118.0, -62.0, -35.0, -8.0, -90.0]
	for i in angles.size():
		var dir := Vector2.from_angle(deg_to_rad(angles[i]) + sin(t * 1.4 + i * 0.9 + v * 6.0) * 0.05)
		var length := 44.0 if i < 6 else 30.0
		var normal := dir.orthogonal()
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for s_i in 9:
			var s := s_i / 8.0
			var q := top + dir * length * s + Vector2(0, 26.0 * s * s)
			var w := 7.0 * sin(PI * s)
			upper.append(q + normal * w)
			lower.append(q - normal * w)
		lower.reverse()
		var leaf := upper + lower
		ci.draw_colored_polygon(leaf, Color(0.2, 0.6, 0.25) if i % 2 == 0 else Color(0.15, 0.5, 0.2))
		var rib := PackedVector2Array()
		for s_i in 9:
			var s := s_i / 8.0
			rib.append(top + dir * length * s + Vector2(0, 26.0 * s * s))
		ci.draw_polyline(rib, Color(0.1, 0.36, 0.14), 1.2, true)
	for o in [Vector2(-4, 4), Vector2(4, 5), Vector2(0, 8)]:
		ci.draw_circle(top + o, 4.0, Color(0.45, 0.3, 0.15), true, -1.0, true)

static func _paint_bush(ci: CanvasItem, v: float) -> void:
	var dark := Color(0.14, 0.44, 0.2).lerp(Color(0.2, 0.5, 0.16), v)
	var light := dark.lightened(0.25)
	for c in [Vector2(-10, -8), Vector2(10, -8), Vector2(0, -15)]:
		ci.draw_circle(c, 11.0, dark, true, -1.0, true)
	for c in [Vector2(-12, -11), Vector2(7, -12), Vector2(-3, -19)]:
		ci.draw_circle(c, 5.0, light, true, -1.0, true)

static func _paint_flowers(ci: CanvasItem, v: float) -> void:
	var col := FLOWER_COLORS[int(v * FLOWER_COLORS.size()) % FLOWER_COLORS.size()]
	var stems := [Vector2(-9, -9), Vector2(-3, -14), Vector2(4, -11), Vector2(10, -7), Vector2(0, -6)]
	for s: Vector2 in stems:
		ci.draw_line(Vector2(s.x * 0.6, 0), s, Color(0.2, 0.55, 0.22), 1.5, true)
	for s: Vector2 in stems:
		for p in 5:
			ci.draw_circle(s + Vector2.from_angle(TAU * p / 5.0) * 2.6, 2.2, col, true, -1.0, true)
		ci.draw_circle(s, 1.6, Color(1.0, 0.85, 0.2), true, -1.0, true)

static func _paint_rock(ci: CanvasItem, v: float) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		var r := 1.0 + sin(i * 2.7 + v * 10.0) * 0.12
		pts.append(Vector2(cos(a) * 16.0 * r, minf(-9.0 + sin(a) * 11.0 * r, 0.0)))
	ci.draw_colored_polygon(pts, Color(0.56, 0.56, 0.6))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.32, 0.32, 0.36), 1.5, true)
	ci.draw_colored_polygon(_ellipse(Vector2(-5, -13), 6, 3), Color(0.72, 0.72, 0.76))
	ci.draw_circle(Vector2(16, -3), 4.0, Color(0.5, 0.5, 0.54), true, -1.0, true)

static func _paint_torch(ci: CanvasItem, t: float) -> void:
	var flick := 1.0 + sin(t * 17.0) * 0.08 + sin(t * 29.0) * 0.05
	ci.draw_circle(Vector2(0, -66), 26.0 * flick, Color(1.0, 0.6, 0.2, 0.14), true, -1.0, true)
	ci.draw_line(Vector2(0, 0), Vector2(0, -50), Color(0.5, 0.32, 0.17), 4.0, true)
	for y in [-14.0, -30.0]:
		ci.draw_line(Vector2(-2.5, y), Vector2(2.5, y - 2), Color(0.35, 0.22, 0.1), 2.0, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -50), Vector2(7, -50), Vector2(9, -58), Vector2(-9, -58)]), Color(0.4, 0.26, 0.12))
	ci.draw_colored_polygon(_ellipse(Vector2(0, -66), 6.5 * flick, 10.0 * flick), Color(1.0, 0.5, 0.12))
	ci.draw_colored_polygon(_ellipse(Vector2(0, -63), 3.2, 5.5 * flick), Color(1.0, 0.92, 0.55))

static func _ellipse(c: Vector2, rx: float, ry: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
