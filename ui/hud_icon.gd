extends Control
class_name HudIcon
## Íconos vectoriales simples para la interfaz (el HUD, la tienda, el carnet, el menú de inicio...),
## por nombre (kind), con los colores de la paleta (ver UiStyle). Y la moneda de los sacrificios,
## que es un pedazo del logo (ver sacrifice).

## El dibujo de cada Charm y de cada Miracle, por su ícono.
const CHARM_ICONS := {"cupid": Charm.Kind.CUPID, "discord": Charm.Kind.DISCORD, "friendship": Charm.Kind.FRIENDSHIP}
const MIRACLE_ICONS := {"resurrect": Miracle.Kind.RESURRECT, "shield": Miracle.Kind.SHIELD, "vaccine": Miracle.Kind.VACCINE}
const SACRIFICE_ICON := preload("res://icon.png")
const SACRIFICE_HEAD := Rect2(15, 78, 481, 357)   # Donde está la cabeza en el logo

var kind := ""

static func make(k: String, px: int) -> HudIcon:
	var i := HudIcon.new()
	i.kind = k
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return i

## La moneda de los sacrificios: la cabeza de un aldeano muerto, como el logo (de px de alto;
## también para la tienda).
static func sacrifice(px: float) -> TextureRect:
	var head := TextureRect.new()
	var trimmed := AtlasTexture.new()   # Sin el margen vacío del logo: que la cabeza llene la moneda
	trimmed.atlas = SACRIFICE_ICON
	trimmed.region = SACRIFICE_HEAD
	head.texture = trimmed
	head.custom_minimum_size = Vector2(px * SACRIFICE_HEAD.size.aspect(), px)
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return head

func _draw() -> void:
	var s := size.x
	var c := size * 0.5
	match kind:
		"xp":
			var pts := PackedVector2Array()
			for i in 10:
				var r := s * (0.5 if i % 2 == 0 else 0.22)
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, UiStyle.C_XP)
		"day":
			# Un solcito
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2.from_angle(a) * s * 0.33, c + Vector2.from_angle(a) * s * 0.5, UiStyle.C_SUN, maxf(1.5, s * 0.09), true)
			draw_circle(c, s * 0.26, UiStyle.C_SUN, true, -1.0, true)
		"night":
			# Una medialuna
			draw_circle(c, s * 0.42, UiStyle.C_MOON, true, -1.0, true)
			draw_circle(c + Vector2(0.2, -0.12) * s, s * 0.36, Color(0.1, 0.13, 0.24), true, -1.0, true)
		"devotion":
			# Gota
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(0, s * 0.12) + Vector2(cos(a), sin(a)) * s * 0.34)
			pts.append(c + Vector2(-s * 0.05, -s * 0.5))
			draw_colored_polygon(pts, UiStyle.C_DEVOTION)
		"villager":
			draw_circle(c + Vector2(0, -s * 0.22), s * 0.2, UiStyle.C_SPAWN, true, -1.0, true)
			draw_rect(Rect2(c.x - s * 0.26, c.y + s * 0.02, s * 0.52, s * 0.44), UiStyle.C_SPAWN)
		"island":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				pts.append(c + Vector2(0, s * 0.12) + Vector2(cos(a) * s * 0.5, -sin(a) * s * 0.32))
			draw_colored_polygon(pts, Color(1.0, 0.86, 0.42))
			draw_line(Vector2(0, s * 0.8), Vector2(s, s * 0.8), UiStyle.C_DEVOTION, 2.0, true)
		"point":
			draw_circle(c, s * 0.48, UiStyle.C_EXPAND, true, -1.0, true)
			draw_line(c - Vector2(s * 0.26, 0), c + Vector2(s * 0.26, 0), Color.WHITE, 2.0, true)
			draw_line(c - Vector2(0, s * 0.26), c + Vector2(0, s * 0.26), Color.WHITE, 2.0, true)
		"hand":
			# Mano abierta, para agarrar
			var skin := Color(0.98, 0.8, 0.62)
			var w := s * 0.13
			for i in 4:
				var x := s * (0.33 + i * 0.12)
				var tip := s * (0.2 if i == 1 or i == 2 else 0.26)
				draw_line(Vector2(x, s * 0.56), Vector2(x, tip), skin, w, true)
				draw_circle(Vector2(x, tip), w * 0.5, skin, true, -1.0, true)
			draw_line(Vector2(0.3, 0.66) * s, Vector2(0.14, 0.46) * s, skin, w, true)
			draw_circle(Vector2(0.14, 0.46) * s, w * 0.5, skin, true, -1.0, true)
			draw_rect(Rect2(Vector2(0.27, 0.48) * s, Vector2(0.48, 0.24) * s), skin)
			draw_circle(Vector2(0.51, 0.7) * s, s * 0.24, skin, true, -1.0, true)
		"select":
			# Flecha del mouse
			var arrow := _pts([0.26, 0.06, 0.26, 0.84, 0.44, 0.67, 0.57, 0.95, 0.71, 0.89, 0.58, 0.61, 0.82, 0.61])
			draw_colored_polygon(arrow, Color.WHITE)
			arrow.append(arrow[0])
			draw_polyline(arrow, Color(0.1, 0.13, 0.22), maxf(1.5, s * 0.06), true)
		"plus":
			# Una cruz gorda blanca con borde
			var a := 0.12
			var b := 0.42
			var cross := _pts([0.5 - a, 0.5 - b, 0.5 + a, 0.5 - b, 0.5 + a, 0.5 - a, 0.5 + b, 0.5 - a, 0.5 + b, 0.5 + a,
					0.5 + a, 0.5 + a, 0.5 + a, 0.5 + b, 0.5 - a, 0.5 + b, 0.5 - a, 0.5 + a, 0.5 - b, 0.5 + a, 0.5 - b, 0.5 - a,
					0.5 - a, 0.5 - a])
			draw_colored_polygon(cross, Color.WHITE)
			cross.append(cross[0])
			draw_polyline(cross, Color(0.45, 0.2, 0.05), maxf(2.0, s * 0.05), true)
		"coin":
			draw_circle(c, s * 0.48, UiStyle.C_OFFERING.darkened(0.25), true, -1.0, true)
			draw_circle(c, s * 0.38, UiStyle.C_OFFERING, true, -1.0, true)
			draw_arc(c, s * 0.24, 0.0, TAU, 16, UiStyle.C_OFFERING.darkened(0.3), maxf(1.0, s * 0.08), true)
		"gun":
			var grip := _pts([0.16, 0.48, 0.42, 0.48, 0.36, 0.9, 0.08, 0.86])
			draw_colored_polygon(grip, UiStyle.C_GUN)
			draw_arc(Vector2(0.5, 0.52) * s, s * 0.1, 0.0, PI, 8, Color(0.75, 0.78, 0.85), 2.0, true)
			draw_rect(Rect2(Vector2(0.06, 0.26) * s, Vector2(0.88, 0.22) * s), Color(0.75, 0.78, 0.85))
			draw_rect(Rect2(Vector2(0.84, 0.2) * s, Vector2(0.06, 0.06) * s), Color(0.75, 0.78, 0.85))
		"shark":
			draw_colored_polygon(_pts([0.18, 0.74, 0.38, 0.1, 0.86, 0.74]), Color(0.58, 0.64, 0.74))
			draw_line(Vector2(0.04, 0.76) * s, Vector2(0.96, 0.76) * s, UiStyle.C_DEVOTION, 2.5, true)
		"blood_moon":
			draw_circle(c, s * 0.48, Color(1.0, 0.2, 0.15, 0.25), true, -1.0, true)
			draw_circle(c, s * 0.4, Color(0.74, 0.17, 0.14), true, -1.0, true)
			for side: float in [-1.0, 1.0]:
				draw_circle(c + Vector2(side * 0.14, -0.06) * s, s * 0.09, Color(1.0, 0.95, 0.85), true, -1.0, true)
				draw_circle(c + Vector2(side * 0.14, -0.04) * s, s * 0.04, Color(0.12, 0.12, 0.18), true, -1.0, true)
			draw_arc(c + Vector2(0, 0.06) * s, s * 0.18, 0.15 * PI, 0.85 * PI, 10, Color(0.2, 0.02, 0.04), maxf(1.5, s * 0.06), true)
		"blood_sun":
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				draw_line(c + d * s * 0.3, c + d * s * 0.48, Color(0.88, 0.2, 0.04), maxf(1.5, s * 0.07), true)
			draw_circle(c, s * 0.3, Color(0.96, 0.42, 0.07), true, -1.0, true)
			for side: float in [-1.0, 1.0]:
				draw_circle(c + Vector2(side * 0.1, -0.05) * s, s * 0.06, Color(0.05, 0.01, 0.01), true, -1.0, true)
			draw_arc(c + Vector2(0, 0.04) * s, s * 0.13, 0.15 * PI, 0.85 * PI, 8, Color(0.05, 0.01, 0.01), maxf(1.5, s * 0.05), true)
		"lightning":
			draw_colored_polygon(_pts([0.6, 0.0, 0.16, 0.56, 0.46, 0.56, 0.34, 1.0, 0.84, 0.4, 0.54, 0.4, 0.72, 0.0]), Color(1.0, 0.9, 0.3))
		"meteor":
			draw_colored_polygon(_pts([0.98, 0.02, 0.22, 0.48, 0.52, 0.78]), Color(1.0, 0.62, 0.2, 0.6))
			draw_circle(Vector2(0.36, 0.64) * s, s * 0.26, Color(1.0, 0.45, 0.15), true, -1.0, true)
			draw_circle(Vector2(0.32, 0.68) * s, s * 0.12, Color(1.0, 0.82, 0.45), true, -1.0, true)
		"tornado":
			for i in 5:
				var y := s * (0.1 + i * 0.2)
				var w := s * (0.46 - i * 0.08)
				var x := c.x + sin(i * 1.3) * s * 0.06
				draw_line(Vector2(x - w, y), Vector2(x + w, y), Color(0.8, 0.85, 0.92), 3.0, true)
		"rain":
			var cloud := Color(0.82, 0.86, 0.94)
			draw_circle(Vector2(0.32, 0.4) * s, s * 0.18, cloud, true, -1.0, true)
			draw_circle(Vector2(0.56, 0.3) * s, s * 0.24, cloud, true, -1.0, true)
			draw_circle(Vector2(0.76, 0.44) * s, s * 0.16, cloud, true, -1.0, true)
			draw_rect(Rect2(Vector2(0.32, 0.4) * s, Vector2(0.44, 0.2) * s), cloud)
			for i in 3:
				var x := s * (0.3 + i * 0.2)
				draw_line(Vector2(x, s * 0.72), Vector2(x - s * 0.08, s * 0.96), UiStyle.C_DEVOTION, 2.5, true)
		"plague":
			# Calavera en una nube verde
			var green := UiStyle.C_PLAGUE
			for p: Vector3 in [Vector3(0.28, 0.62, 0.2), Vector3(0.72, 0.62, 0.2), Vector3(0.5, 0.7, 0.22)]:
				draw_circle(Vector2(p.x, p.y) * s, p.z * s, Color(green, 0.45), true, -1.0, true)
			var bone := Color(0.92, 0.95, 0.85)
			draw_circle(Vector2(0.5, 0.4) * s, s * 0.26, bone, true, -1.0, true)
			draw_rect(Rect2(Vector2(0.36, 0.52) * s, Vector2(0.28, 0.18) * s), bone)
			for side: float in [-1.0, 1.0]:
				draw_circle(Vector2(0.5 + side * 0.1, 0.42) * s, s * 0.07, Color(0.2, 0.32, 0.1), true, -1.0, true)
			draw_line(Vector2(0.45, 0.6) * s, Vector2(0.45, 0.7) * s, Color(0.2, 0.32, 0.1), maxf(1.0, s * 0.04), true)
			draw_line(Vector2(0.55, 0.6) * s, Vector2(0.55, 0.7) * s, Color(0.2, 0.32, 0.1), maxf(1.0, s * 0.04), true)
		"spore":
			# Un hongo soltando esporas
			for p: Vector3 in [Vector3(0.24, 0.3, 0.05), Vector3(0.76, 0.24, 0.045), Vector3(0.62, 0.1, 0.035),
					Vector3(0.36, 0.12, 0.04), Vector3(0.84, 0.46, 0.035)]:
				draw_circle(Vector2(p.x, p.y) * s, p.z * s, Color(UiStyle.C_SPORE, 0.85), true, -1.0, true)
			Spore.paint_mushroom(self, Vector2(0.5, 0.92) * s, s / 19.0)
		"evil":
			# Carita roja con cuernitos (la pestaña de los poderes malos)
			var face := Vector2(0.5, 0.58) * s
			var horn := UiStyle.C_EVIL.darkened(0.35)
			for side: float in [-1.0, 1.0]:
				draw_colored_polygon(_pts([0.5 + side * 0.14, 0.34, 0.5 + side * 0.32, 0.4,
						0.5 + side * 0.36, 0.04]), horn)
			draw_circle(face, s * 0.36, UiStyle.C_EVIL, true, -1.0, true)
			var ink := Color(0.25, 0.03, 0.03)
			for side: float in [-1.0, 1.0]:
				# Cejas en V y ojitos
				draw_line(face + Vector2(side * 0.24, -0.14) * s, face + Vector2(side * 0.06, -0.06) * s, ink, maxf(1.5, s * 0.06), true)
				draw_circle(face + Vector2(side * 0.13, 0.0) * s, s * 0.045, ink, true, -1.0, true)
			draw_arc(face + Vector2(0, 0.06) * s, s * 0.16, 0.15 * PI, 0.85 * PI, 8, ink, maxf(1.5, s * 0.06), true)
		"holy":
			# Carita clarita con aureola (la pestaña de los poderes buenos)
			var face := Vector2(0.5, 0.6) * s
			draw_circle(face, s * 0.34, Color(1.0, 0.96, 0.86), true, -1.0, true)
			draw_set_transform(Vector2(0.5, 0.15) * s, 0.0, Vector2(1.0, 0.38))
			draw_arc(Vector2.ZERO, s * 0.3, 0.0, TAU, 24, UiStyle.C_HOLY, maxf(2.0, s * 0.16), true)
			draw_set_transform(Vector2.ZERO)
			var ink := Color(0.35, 0.26, 0.12)
			for side: float in [-1.0, 1.0]:
				# Ojitos cerrados, contentos
				draw_arc(face + Vector2(side * 0.13, -0.02) * s, s * 0.06, PI, TAU, 6, ink, maxf(1.2, s * 0.05), true)
			draw_arc(face + Vector2(0, 0.06) * s, s * 0.13, 0.15 * PI, 0.85 * PI, 8, ink, maxf(1.2, s * 0.05), true)
		"cupid", "discord", "friendship":
			Charm.paint_icon(self, CHARM_ICONS[kind], s)
		"resurrect", "shield", "vaccine":
			Miracle.paint_icon(self, MIRACLE_ICONS[kind], s)
		"feed":
			Manna.paint_bread(self, c + Vector2(0, 0.04) * s, s / 24.0)
		"edit":
			# Un lápiz sobre la isla
			draw_colored_polygon(_pts([0.02, 0.96, 0.16, 0.8, 0.5, 0.74, 0.84, 0.8, 0.98, 0.96]), Color(1.0, 0.86, 0.42))
			var tip := Vector2(0.22, 0.78) * s
			var back := Vector2(0.84, 0.16) * s
			var d := (tip - back).normalized()
			var n := Vector2(-d.y, d.x) * s * 0.11
			var band := back + d * s * 0.14
			var cone := tip - d * s * 0.2
			draw_colored_polygon(PackedVector2Array([back + n, band + n, band - n, back - n]), Color(1.0, 0.55, 0.62))
			draw_colored_polygon(PackedVector2Array([band + n, cone + n, cone - n, band - n]), Color(1.0, 0.8, 0.25))
			draw_colored_polygon(PackedVector2Array([cone + n, tip, cone - n]), Color(0.93, 0.8, 0.6))
			draw_colored_polygon(PackedVector2Array([tip + (cone - tip) * 0.4 + n * 0.4, tip, tip + (cone - tip) * 0.4 - n * 0.4]), Color(0.2, 0.2, 0.26))
			var outline := PackedVector2Array([back + n, cone + n, tip, cone - n, back - n, back + n])
			draw_polyline(outline, Color(0.1, 0.13, 0.22), maxf(1.0, s * 0.045), true)
		"cure":
			# Cruz dorada con brillo
			draw_circle(c, s * 0.46, Color(UiStyle.C_CURE, 0.25), true, -1.0, true)
			draw_rect(Rect2(Vector2(0.39, 0.14) * s, Vector2(0.22, 0.72) * s), UiStyle.C_CURE)
			draw_rect(Rect2(Vector2(0.14, 0.39) * s, Vector2(0.72, 0.22) * s), UiStyle.C_CURE)
			draw_rect(Rect2(Vector2(0.44, 0.19) * s, Vector2(0.06, 0.62) * s), Color(1, 1, 0.92, 0.7))

## Polígono a partir de coordenadas normalizadas (0..1) del ícono.
func _pts(xy: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, xy.size(), 2):
		out.append(Vector2(xy[i], xy[i + 1]) * size.x)
	return out
