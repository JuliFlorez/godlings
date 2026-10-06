extends CanvasLayer
class_name HUD
## Panel superior izquierdo: XP (progreso al próximo punto de expansión),
## Devoción, población de la isla y botones de Invocar / Expandir.
## Menú inferior: armas y poderes (los que todavía no existen dicen "Próximamente").
## Toda la interfaz se construye por código.

signal spawn_pressed
signal expand_pressed
signal expansion_points_changed(points: int)
signal gun_toggled(on: bool)

@export var energy_max: float = 100.0
@export var energy_refill_minutes: float = 5.0  # 5 min para llenarse de 0 a 100
## XP necesaria para cada punto de expansión (el último valor se repite).
@export var xp_per_point: Array[int] = [3, 5, 8, 12, 16, 20]

var xp: int = 0
var energy: float = 100.0
var expansion_points: int = 0
var _points_earned: int = 0
var _refill_rate: float = 0.0  # puntos de energía por segundo

var _population := -1
var _capacity := -1
var _island_level := 0
var _island_max := 0
var _spawn_cost := 10.0

# --- Paleta ---
const C_PANEL := Color(0.06, 0.09, 0.16, 0.78)
const C_PANEL_BORDER := Color(1, 1, 1, 0.12)
const C_TRACK := Color(1, 1, 1, 0.10)
const C_XP := Color(1.0, 0.76, 0.22)
const C_DEVOTION := Color(0.42, 0.82, 1.0)
const C_TEXT := Color(0.96, 0.97, 1.0)
const C_MUTED := Color(0.72, 0.77, 0.88)
const C_WARN := Color(1.0, 0.55, 0.45)
const C_SPAWN := Color(0.98, 0.58, 0.24)
const C_EXPAND := Color(0.98, 0.78, 0.22)
const C_GUN := Color(0.9, 0.36, 0.32)
const C_SOON := Color(1.0, 0.8, 0.3)

## Menú inferior de armas y poderes: [ícono, nombre, tecla, disponible, descripción]
const TOOLS := [
	["gun", "Pistola", "G", true, "Sacar o guardar la pistola [G]"],
	["lightning", "Rayo", "", false, "Fulminá aldeanos desde el cielo"],
	["meteor", "Meteorito", "", false, "Un meteorito que deja un cráter en la isla"],
	["tornado", "Tornado", "", false, "Un tornado que levanta aldeanos por el aire"],
	["rain", "Diluvio", "", false, "Una tormenta que inunda la orilla"],
]
const SLOT_SIZE := Vector2(76, 62)

var _root: Control
var _xp_bar: ProgressBar
var _xp_value: Label
var _energy_bar: ProgressBar
var _energy_value: Label
var _pop_value: Label
var _level_value: Label
var _points_value: Label
var _spawn_btn: Button
var _expand_btn: Button
var _gun_btn: Button
var _gun_armed := false
var _slot_idle: StyleBoxFlat
var _slot_hover: StyleBoxFlat
var _slot_active: StyleBoxFlat
var _hint: Label

func _ready() -> void:
	add_to_group("hud")
	if energy_max <= 0.0:
		energy_max = 100.0
	if energy_refill_minutes <= 0.0:
		energy_refill_minutes = 5.0
	_refill_rate = energy_max / (energy_refill_minutes * 60.0)
	energy = energy_max

	_build_ui()
	_xp_bar.value = xp
	_energy_bar.value = energy
	_refresh()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Sigue cargando aunque pierda foco

func _process(delta: float) -> void:
	# Recarga suave de Devoción
	if energy < energy_max:
		energy = min(energy_max, energy + _refill_rate * delta)
		_refresh()

	# Las barras siguen a su valor con suavidad
	var k := 1.0 - exp(-10.0 * delta)
	var xp_target := _xp_bar.max_value if not _can_earn_points() else float(xp)
	_xp_bar.value = lerpf(_xp_bar.value, xp_target, k)
	_energy_bar.value = lerpf(_energy_bar.value, energy, k)

# ---- API para otros scripts ----
func add_xp(amount: int) -> void:
	if not _can_earn_points():
		_refresh()
		return
	xp += amount
	while xp >= xp_needed() and _can_earn_points():
		xp -= xp_needed()
		_points_earned += 1
		expansion_points += 1
		_xp_bar.value = 0.0
		_flash(_expand_btn)
		popup_text("+1 punto de expansión", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_EXPAND)
		expansion_points_changed.emit(expansion_points)
	if not _can_earn_points():
		xp = 0
	_refresh()

func xp_needed() -> int:
	if xp_per_point.is_empty():
		return 10
	return xp_per_point[mini(_points_earned, xp_per_point.size() - 1)]

func spend_expansion_point() -> bool:
	if expansion_points <= 0:
		return false
	expansion_points -= 1
	expansion_points_changed.emit(expansion_points)
	_refresh()
	return true

func spend_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		_refresh()
		return true
	return false

func can_spend_energy(amount: float) -> bool:
	return energy >= amount

func set_population(count: int, capacity: int) -> void:
	if count == _population and capacity == _capacity:
		return
	_population = count
	_capacity = capacity
	_refresh()

func set_island(level: int, max_level: int) -> void:
	_island_level = level
	_island_max = max_level
	_refresh()

func set_spawn_cost(cost: float) -> void:
	_spawn_cost = cost
	_refresh()

func set_gun_armed(on: bool) -> void:
	_gun_armed = on
	_refresh()

## Texto flotante que sube y se desvanece (posición en pantalla).
func popup_text(text: String, screen_pos: Vector2, color: Color = C_TEXT) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.12, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	l.position = screen_pos - Vector2(l.get_combined_minimum_size().x * 0.5, 0)
	l.scale = Vector2(0.6, 0.6)
	l.pivot_offset = l.get_combined_minimum_size() * 0.5
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.chain().tween_callback(l.queue_free)

# ---- Estado ----
func _can_earn_points() -> bool:
	return _island_max == 0 or _island_level + expansion_points < _island_max

func _refresh() -> void:
	if _root == null:
		return
	var maxed := not _can_earn_points()
	_xp_bar.max_value = xp_needed()
	_xp_value.text = "Máx" if maxed else "%d / %d" % [xp, xp_needed()]
	if maxed:
		_xp_bar.value = _xp_bar.max_value

	_energy_bar.max_value = energy_max
	_energy_value.text = "%d / %d" % [int(energy), int(energy_max)]

	var full := _capacity >= 0 and _population >= _capacity
	_pop_value.text = "%d / %d" % [maxi(_population, 0), maxi(_capacity, 0)]
	_pop_value.add_theme_color_override("font_color", C_WARN if full else C_TEXT)
	_level_value.text = "%d / %d" % [_island_level + 1, _island_max + 1]
	_points_value.text = str(expansion_points)

	var has_energy := energy >= _spawn_cost
	_spawn_btn.disabled = full or not has_energy
	_spawn_btn.text = "Invocar aldeano\n−%d devoción" % int(_spawn_cost)

	var island_maxed := _island_level >= _island_max
	_expand_btn.disabled = expansion_points <= 0 or island_maxed
	if island_maxed:
		_expand_btn.text = "Isla al máximo\n—"
	else:
		_expand_btn.text = "Expandir isla\n%d punto%s" % [expansion_points, "" if expansion_points == 1 else "s"]

	_gun_btn.add_theme_stylebox_override("normal", _slot_active if _gun_armed else _slot_idle)
	_gun_btn.add_theme_stylebox_override("hover", _slot_active if _gun_armed else _slot_hover)

	if _gun_armed:
		_hint.text = "Click para disparar · click derecho, Esc o G para guardarla."
	elif full and not island_maxed:
		_hint.text = "Isla llena: sacrificá aldeanos para ganar puntos y expandirla."
	elif not has_energy:
		_hint.text = "Devoción insuficiente: se recarga con el tiempo."
	elif expansion_points > 0 and not island_maxed:
		_hint.text = "¡Tocá un orbe + en la isla para expandirla!"
	else:
		_hint.text = ""
	_hint.visible = _hint.text != ""

func _flash(c: Control) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate", Color(1.6, 1.5, 1.2), 0.12)
	tw.tween_property(c, "modulate", Color.WHITE, 0.4)

# ---- Construcción de la UI ----
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", _box(C_PANEL, 14, C_PANEL_BORDER, 1, Vector4(16, 14, 16, 14)))
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var xp_row := _bar_row(col, "xp", "XP", C_XP)
	_xp_bar = xp_row[0]
	_xp_value = xp_row[1]
	var en_row := _bar_row(col, "devotion", "Devoción", C_DEVOTION)
	_energy_bar = en_row[0]
	_energy_value = en_row[1]

	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(1, 1, 1, 0.10)
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	col.add_child(sep)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	col.add_child(stats)
	_pop_value = _stat_chip(stats, "villager", "Aldeanos")
	_level_value = _stat_chip(stats, "island", "Isla")
	_points_value = _stat_chip(stats, "point", "Puntos")

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	_spawn_btn = _action_button(buttons, C_SPAWN)
	_spawn_btn.pressed.connect(func(): spawn_pressed.emit())
	_expand_btn = _action_button(buttons, C_EXPAND)
	_expand_btn.pressed.connect(func(): expand_pressed.emit())

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", C_MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(268, 0)
	col.add_child(_hint)

	_build_toolbar()

func _build_toolbar() -> void:
	_slot_idle = _box(Color(1, 1, 1, 0.06), 12, Color(1, 1, 1, 0.10), 1)
	_slot_hover = _box(Color(1, 1, 1, 0.13), 12, Color(1, 1, 1, 0.28), 1)
	_slot_active = _box(Color(C_GUN, 0.38), 12, C_GUN.lightened(0.3), 2)

	# Abajo al centro: dock de pantalla completa que no bloquea el mouse
	var dock := VBoxContainer.new()
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_constant_override("separation", 0)
	_root.add_child(dock)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(center)
	var bottom_gap := Control.new()
	bottom_gap.custom_minimum_size = Vector2(0, 8)
	bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(bottom_gap)

	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP  # Los clicks en la barra no llegan al mundo
	bar.add_theme_stylebox_override("panel", _box(C_PANEL, 14, C_PANEL_BORDER, 1, Vector4(8, 8, 8, 8)))
	center.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	for t in TOOLS:
		var slot := _tool_slot(row, t[0], t[1], t[2], t[3], t[4])
		if t[0] == "gun":
			_gun_btn = slot
			_gun_btn.pressed.connect(func(): gun_toggled.emit(not _gun_armed))

func _tool_slot(parent: Control, kind: String, title: String, key: String, available: bool, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SLOT_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_stylebox_override("normal", _slot_idle)
	b.add_theme_stylebox_override("hover", _slot_hover)
	b.add_theme_stylebox_override("pressed", _slot_active)
	b.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.03), 12, Color(1, 1, 1, 0.06), 1))
	parent.add_child(b)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := HudIcon.make(kind, 26)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var name_l := _label(title, 11, C_TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)

	if key != "":
		var k := _label(key, 10, C_MUTED)
		k.position = Vector2(8, 4)
		b.add_child(k)

	if not available:
		b.disabled = true
		icon.modulate = Color(1, 1, 1, 0.5)
		name_l.modulate = Color(1, 1, 1, 0.55)
		_soon_sign(b)
	return b

## Cartelito de "Próximamente" pegado sobre el borde superior del slot.
func _soon_sign(slot: Control) -> void:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _box(C_SOON, 4, C_SOON.darkened(0.4), 1, Vector4(4, 0, 4, 0)))
	badge.add_child(_label("PRÓXIMAMENTE", 8, Color(0.18, 0.11, 0.02)))
	slot.add_child(badge)
	var sz := badge.get_combined_minimum_size()
	badge.size = sz
	badge.pivot_offset = sz * 0.5
	badge.position = Vector2(SLOT_SIZE.x * 0.5 - sz.x * 0.5, -sz.y * 0.55)
	badge.rotation = deg_to_rad(-6.0)

func _bar_row(parent: Control, icon: String, title: String, color: Color) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	head.add_child(HudIcon.make(icon, 16))
	var name_l := _label(title, 14, C_TEXT)
	head.add_child(name_l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var value_l := _label("", 13, C_MUTED)
	head.add_child(value_l)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", _box(C_TRACK, 6))
	bar.add_theme_stylebox_override("fill", _box(color, 6, color.lightened(0.35), 1))
	box.add_child(bar)
	return [bar, value_l]

func _stat_chip(parent: Control, icon: String, title: String) -> Label:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.06), 9, Color(0, 0, 0, 0), 0, Vector4(8, 6, 8, 6)))
	parent.add_child(chip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	chip.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	v.add_child(top)
	top.add_child(HudIcon.make(icon, 14))
	top.add_child(_label(title, 11, C_MUTED))
	var value := _label("", 16, C_TEXT)
	v.add_child(value)
	return value

func _action_button(parent: Control, color: Color) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	b.add_theme_color_override("font_hover_color", Color(0.12, 0.08, 0.04))
	b.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.04))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_stylebox_override("normal", _box(color, 10, color.lightened(0.3), 1))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.15), 10, color.lightened(0.5), 1))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.15), 10, color.darkened(0.3), 1))
	b.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.07), 10, Color(1, 1, 1, 0.08), 1))
	parent.add_child(b)
	return b

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _box(bg: Color, radius: int, border := Color(0, 0, 0, 0), border_w := 0, pad := Vector4.ZERO) -> StyleBoxFlat:
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

## Íconos vectoriales simples para el HUD.
class HudIcon extends Control:
	var kind := ""

	static func make(k: String, px: int) -> HudIcon:
		var i := HudIcon.new()
		i.kind = k
		i.custom_minimum_size = Vector2(px, px)
		i.mouse_filter = Control.MOUSE_FILTER_IGNORE
		i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return i

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
				draw_colored_polygon(pts, HUD.C_XP)
			"devotion":
				# Gota
				var pts := PackedVector2Array()
				for i in 17:
					var a := PI * i / 16.0
					pts.append(c + Vector2(0, s * 0.12) + Vector2(cos(a), sin(a)) * s * 0.34)
				pts.append(c + Vector2(-s * 0.05, -s * 0.5))
				draw_colored_polygon(pts, HUD.C_DEVOTION)
			"villager":
				draw_circle(c + Vector2(0, -s * 0.22), s * 0.2, HUD.C_SPAWN, true, -1.0, true)
				draw_rect(Rect2(c.x - s * 0.26, c.y + s * 0.02, s * 0.52, s * 0.44), HUD.C_SPAWN)
			"island":
				var pts := PackedVector2Array()
				for i in 13:
					var a := PI * i / 12.0
					pts.append(c + Vector2(0, s * 0.12) + Vector2(cos(a) * s * 0.5, -sin(a) * s * 0.32))
				draw_colored_polygon(pts, Color(1.0, 0.86, 0.42))
				draw_line(Vector2(0, s * 0.8), Vector2(s, s * 0.8), HUD.C_DEVOTION, 2.0, true)
			"point":
				draw_circle(c, s * 0.48, HUD.C_EXPAND, true, -1.0, true)
				draw_line(c - Vector2(s * 0.26, 0), c + Vector2(s * 0.26, 0), Color.WHITE, 2.0, true)
				draw_line(c - Vector2(0, s * 0.26), c + Vector2(0, s * 0.26), Color.WHITE, 2.0, true)
			"gun":
				var grip := _pts([0.16, 0.48, 0.42, 0.48, 0.36, 0.9, 0.08, 0.86])
				draw_colored_polygon(grip, HUD.C_GUN)
				draw_arc(Vector2(0.5, 0.52) * s, s * 0.1, 0.0, PI, 8, Color(0.75, 0.78, 0.85), 2.0, true)
				draw_rect(Rect2(Vector2(0.06, 0.26) * s, Vector2(0.88, 0.22) * s), Color(0.75, 0.78, 0.85))
				draw_rect(Rect2(Vector2(0.84, 0.2) * s, Vector2(0.06, 0.06) * s), Color(0.75, 0.78, 0.85))
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
					draw_line(Vector2(x, s * 0.72), Vector2(x - s * 0.08, s * 0.96), HUD.C_DEVOTION, 2.5, true)

	## Polígono a partir de coordenadas normalizadas (0..1) del ícono.
	func _pts(xy: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(0, xy.size(), 2):
			out.append(Vector2(xy[i], xy[i + 1]) * size.x)
		return out
