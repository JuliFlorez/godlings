extends Control
class_name TopBar
## La barra de arriba (ver HUD). A la izquierda, un panel: qué día es (y cuánto le queda al día o a
## la noche, ver Sky), la XP (lo que falta para el próximo punto de expansión), el tamaño de la
## isla con el botón de Expandir, la Tienda, el Historial y abajo la pista de lo que conviene hacer.
## Al medio, el + grande para invocar aldeanos, con la devoción en un anillo alrededor, lo que
## cuesta abajo y cuántos aldeanos hay al costado. A la derecha (al lado del sol), las monedas: las
## ofrendas, con lo que te dejan rezando, y los sacrificios (la cabeza de un aldeano muerto, como
## el logo). Ocupa toda la pantalla sin atajar el mouse: los clicks los atajan solo sus paneles.

const SUMMON_SIZE := 78.0       # El + de invocar...
const RING_W := 7.0             # ...con el anillo de devoción alrededor...
const RING_GAP := 3.0           # ...un poquito separado
const PANEL_W := 250.0          # El panel de la izquierda...
const PANEL_BUTTON_H := 38.0    # ...y sus botones
const COIN_W := 118.0           # Ancho de cada moneda de arriba a la derecha
const COIN_ICON := 34.0          # Alto del ícono de cada moneda

var hud: HUD
var _day_icon: HudIcon
var _day_label: Label
var _day_bar: ProgressBar
var _xp_bar: ProgressBar
var _xp_value: Label
var _devotion_ring: DevotionRing
var _pop_value: Label
var _level_value: Label
var _spawn_btn: Button
var _expand_btn: Button
var _shop_btn: Button
var _history_btn: Button
var _hint: Label
var _offer_value: Label
var _offer_chip: Control
var _tribute_label: Label      # Abajo de las ofrendas: lo que te dejan rezando cada tanto
var _sacrifice_value: Label
var _sacrifice_chip: Control
var _spawn_cost_label: Label   # El costo abajo del +

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (Ya está en el árbol: con los offsets)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# A la izquierda, el panel
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.C_PANEL, 14, UiStyle.C_PANEL_BORDER, 1, Vector4(12, 10, 12, 12)))
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	# Qué día es, y una barrita con lo que va del día (o de la noche)
	var day_row := HBoxContainer.new()
	day_row.add_theme_constant_override("separation", 7)
	day_row.tooltip_text = "Lo que falta para que se haga de noche (o de día)"
	col.add_child(day_row)
	_day_icon = HudIcon.make("day", 16)
	day_row.add_child(_day_icon)
	_day_label = UiStyle.label("", 13, UiStyle.C_TEXT)
	_day_label.custom_minimum_size = Vector2(62, 0)
	day_row.add_child(_day_label)
	_day_bar = ProgressBar.new()
	_day_bar.show_percentage = false
	_day_bar.max_value = 1.0
	_day_bar.custom_minimum_size = Vector2(0, 6)
	_day_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_day_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_day_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_day_bar.add_theme_stylebox_override("background", UiStyle.box(UiStyle.C_TRACK, 3))
	_day_bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.C_SUN, 3))
	day_row.add_child(_day_bar)

	# XP: una barrita finita con lo que falta para el próximo punto de expansión
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 7)
	xp_row.tooltip_text = "XP: cada sacrificio suma 1; al llenarse ganás un punto para expandir la isla"
	col.add_child(xp_row)
	xp_row.add_child(HudIcon.make("xp", 16))
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 8)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_xp_bar.add_theme_stylebox_override("background", UiStyle.box(UiStyle.C_TRACK, 4))
	_xp_bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.C_XP, 4))
	xp_row.add_child(_xp_bar)
	_xp_value = UiStyle.label("", 12, UiStyle.C_MUTED)
	xp_row.add_child(_xp_value)

	# La isla: de qué tamaño es y el botón para agrandarla
	var island_row := HBoxContainer.new()
	island_row.add_theme_constant_override("separation", 6)
	col.add_child(island_row)
	var island := PanelContainer.new()
	island.tooltip_text = "Isla"
	island.add_theme_stylebox_override("panel", UiStyle.box(Color(1, 1, 1, 0.06), 9, Color(0, 0, 0, 0), 0, Vector4(8, 0, 9, 0)))
	island_row.add_child(island)
	var island_in := HBoxContainer.new()
	island_in.add_theme_constant_override("separation", 5)
	island_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	island.add_child(island_in)
	island_in.add_child(HudIcon.make("island", 16))
	_level_value = UiStyle.label("", 14, UiStyle.C_TEXT)
	island_in.add_child(_level_value)
	_expand_btn = _action_button(island_row, UiStyle.C_EXPAND)
	_expand_btn.custom_minimum_size.y = PANEL_BUTTON_H
	_expand_btn.pressed.connect(func(): hud.expand_pressed.emit())

	var shop_row := HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 8)
	col.add_child(shop_row)
	_shop_btn = _action_button(shop_row, UiStyle.C_SHOP)
	_shop_btn.custom_minimum_size.y = PANEL_BUTTON_H
	_shop_btn.text = "Tienda"
	_shop_btn.pressed.connect(hud.open_shop)
	_history_btn = _action_button(shop_row, UiStyle.C_HISTORY)
	_history_btn.custom_minimum_size.y = PANEL_BUTTON_H
	_history_btn.text = "Historial"
	_history_btn.pressed.connect(hud.toggle_history)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", UiStyle.C_MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(PANEL_W - 24.0, 0)
	col.add_child(_hint)

	_build_top()
	snap_bars()
	Game.events.loaded.connect(snap_bars)
	Game.events.offerings_gained.connect(func(_amount: int): _flash(_offer_chip))
	Game.events.sacrifices_gained.connect(func(_amount: int): _flash(_sacrifice_chip))

func _process(delta: float) -> void:
	# Las barras siguen a su valor con suavidad
	var k := 1.0 - exp(-10.0 * delta)
	var xp_target := _xp_bar.max_value if not Game.can_earn_points() else float(Game.xp)
	_xp_bar.value = lerpf(_xp_bar.value, xp_target, k)
	_devotion_ring.value = lerpf(_devotion_ring.value, Game.devotion, k)
	_update_day()

## Lo que muestra (lo llama HUD._refresh): la XP, la devoción, los aldeanos (y cuántos entran), si
## se puede invocar, el tamaño de la isla y si se puede agrandar, las ofrendas y los sacrificios.
func refresh(population: int, capacity: int, spawn_cost: float) -> void:
	var maxed := not Game.can_earn_points()
	_xp_bar.max_value = Game.xp_needed()
	_xp_value.text = tr("Máx") if maxed else "%d / %d" % [Game.xp, Game.xp_needed()]
	if maxed:
		_xp_bar.value = _xp_bar.max_value

	_devotion_ring.max_value = Game.DEVOTION_MAX
	_devotion_ring.cost = spawn_cost

	var full := capacity >= 0 and population >= capacity
	_pop_value.text = "%d / %d" % [maxi(population, 0), maxi(capacity, 0)]
	_pop_value.add_theme_color_override("font_color", UiStyle.C_WARN if full else UiStyle.C_TEXT)
	_level_value.text = "%d / %d" % [Game.island_level + 1, Game.island_max + 1]

	var has_energy := Game.devotion >= spawn_cost
	_spawn_btn.disabled = full or not has_energy
	_spawn_btn.tooltip_text = tr("Invocar aldeano (−%d devoción)") % int(spawn_cost) + "\n" \
			+ tr("Devoción: %d / %d") % [int(Game.devotion), int(Game.DEVOTION_MAX)]
	_spawn_btn.get_meta("icon").modulate.a = 0.45 if _spawn_btn.disabled else 1.0
	_spawn_cost_label.text = str(int(spawn_cost))
	_spawn_cost_label.add_theme_color_override("font_color", UiStyle.C_TEXT if has_energy else UiStyle.C_WARN)

	var island_maxed := Game.island_level >= Game.island_max
	_expand_btn.disabled = Game.expansion_points <= 0 or island_maxed
	_expand_btn.text = tr("Isla al máximo") if island_maxed else tr("Expandir isla (%d)") % Game.expansion_points

	_offer_value.text = str(Game.offerings)
	_sacrifice_value.text = str(Game.sacrifices)
	# Con su tecla, que sale de Controls (y acá, así sigue al idioma)
	_history_btn.tooltip_text = Controls.tip("Quién se hizo amigo, enemigo o pareja de quién", Controls.HISTORY)

## La pista de abajo del panel (ver HUD._hint_text); vacía, no se ve.
func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""

## Ganaste un punto para agrandar la isla (ver HUD): la barra de XP vuelve a empezar y el botón de
## Expandir brilla.
func point_earned() -> void:
	_xp_bar.value = 0.0
	_flash(_expand_btn)

## Las barras en su valor, sin animarlas (al armar el HUD y al cargar una partida).
func snap_bars() -> void:
	_xp_bar.value = Game.xp
	_devotion_ring.value = Game.devotion

## Lo que te dejan rezando todos juntos cada interval segundos (ver HUD.set_tribute): va abajo
## de las ofrendas (apagado si no reza nadie).
func set_tribute(amount: float, interval: float) -> void:
	_tribute_label.text = HUD.per_prayer(amount, interval)
	_tribute_label.add_theme_color_override("font_color", UiStyle.C_OFFERING if amount > 0.0 else UiStyle.C_MUTED)

## Qué día es y lo que va del día (o de la noche), con el sol o la luna.
func _update_day() -> void:
	var sky := get_tree().get_first_node_in_group("sky")
	if sky == null:
		return
	var night: bool = sky.is_night
	_day_icon.kind = "night" if night else "day"
	_day_icon.queue_redraw()
	_day_label.text = (tr("Noche %d") if night else tr("Día %d")) % sky.day
	_day_bar.value = 1.0 - sky.phase()
	(_day_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = UiStyle.C_MOON if night else UiStyle.C_SUN

## Un brillo cortito (ganaste ofrendas, sacrificios o un punto de expansión).
func _flash(c: Control) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate", Color(1.6, 1.5, 1.2), 0.12)
	tw.tween_property(c, "modulate", Color.WHITE, 0.4)

## Arriba al medio, el + grande para invocar aldeanos: alrededor, la devoción (un anillo que se
## llena); abajo, lo que cuesta, y al costado, cuántos aldeanos hay. Arriba a la derecha, las
## ofrendas y los sacrificios.
func _build_top() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 6.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var summon := VBoxContainer.new()
	summon.add_theme_constant_override("separation", -8)   # El costo se apoya en el anillo
	summon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(summon)
	var ring_size := SUMMON_SIZE + (RING_GAP + RING_W) * 2.0
	var ring_box := Control.new()   # El anillo con el + adentro (y los aldeanos al costado, afuera)
	ring_box.custom_minimum_size = Vector2(ring_size, ring_size)
	ring_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summon.add_child(ring_box)
	_devotion_ring = DevotionRing.new()
	_devotion_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_devotion_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_box.add_child(_devotion_ring)
	_spawn_btn = Button.new()
	_spawn_btn.position = Vector2.ONE * (RING_GAP + RING_W)
	_spawn_btn.size = Vector2(SUMMON_SIZE, SUMMON_SIZE)
	_spawn_btn.custom_minimum_size = Vector2(SUMMON_SIZE, SUMMON_SIZE)
	_spawn_btn.pivot_offset = Vector2(SUMMON_SIZE, SUMMON_SIZE) * 0.5
	_spawn_btn.focus_mode = Control.FOCUS_NONE
	var r := int(SUMMON_SIZE * 0.5)
	for state: Array in [["normal", UiStyle.C_SPAWN, UiStyle.C_SPAWN.lightened(0.45)], ["hover", UiStyle.C_SPAWN.lightened(0.12), Color.WHITE],
			["pressed", UiStyle.C_SPAWN.darkened(0.15), UiStyle.C_SPAWN.darkened(0.3)], ["disabled", Color(UiStyle.C_PANEL, 0.55), Color(1, 1, 1, 0.18)]]:
		var box := UiStyle.box(state[1], r, state[2], 3)
		box.shadow_color = Color(0, 0, 0, 0.28)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 3)
		_spawn_btn.add_theme_stylebox_override(state[0], box)
	var plus := HudIcon.make("plus", int(SUMMON_SIZE * 0.62))
	plus.position = Vector2(SUMMON_SIZE, SUMMON_SIZE) * 0.19
	_spawn_btn.add_child(plus)
	_spawn_btn.set_meta("icon", plus)
	_spawn_btn.pressed.connect(func():
		var tw := _spawn_btn.create_tween()
		_spawn_btn.scale = Vector2.ONE * 1.15
		tw.tween_property(_spawn_btn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hud.spawn_pressed.emit())
	ring_box.add_child(_spawn_btn)
	# Cuántos aldeanos hay (y cuántos entran), al costado
	var pop := PanelContainer.new()
	pop.tooltip_text = "Aldeanos"
	pop.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.C_PANEL, 17, UiStyle.C_PANEL_BORDER, 1, Vector4(8, 3, 12, 3)))
	ring_box.add_child(pop)
	var pop_row := HBoxContainer.new()
	pop_row.add_theme_constant_override("separation", 5)
	pop_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.add_child(pop_row)
	pop_row.add_child(HudIcon.make("villager", 22))
	_pop_value = UiStyle.label("", 18, UiStyle.C_TEXT)
	pop_row.add_child(_pop_value)
	pop.position = Vector2(ring_size + 6.0, (ring_size - pop.get_combined_minimum_size().y) * 0.5)
	# Lo que cuesta: una gotita de devoción y el número
	var cost := PanelContainer.new()
	cost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE   # Que no le saque clicks al +
	cost.add_theme_stylebox_override("panel", UiStyle.box(Color(0.06, 0.09, 0.16, 0.92), 10, UiStyle.C_DEVOTION.darkened(0.2), 1, Vector4(7, 1, 9, 1)))
	summon.add_child(cost)
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 3)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.add_child(cost_row)
	cost_row.add_child(HudIcon.make("devotion", 13))
	_spawn_cost_label = UiStyle.label("", 13, UiStyle.C_TEXT)
	cost_row.add_child(_spawn_cost_label)

	var coins := VBoxContainer.new()
	coins.add_theme_constant_override("separation", 6)
	add_child(coins)
	_offer_value = _coin(coins, HudIcon.make("coin", int(COIN_ICON)), "Ofrendas: abajo, lo que te dejan tus aldeanos rezando cada 10 segundos")
	_offer_chip = _offer_value.get_parent().get_parent()
	# Abajo del número, lo que te dejan rezando (ver set_tribute)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -5)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_value.get_parent().add_child(stack)
	_offer_value.reparent(stack)
	_tribute_label = UiStyle.label("", 11, UiStyle.C_OFFERING)
	_tribute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tribute_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Lo traduce set_tribute (lleva el número)
	stack.add_child(_tribute_label)
	set_tribute(0.0, hud.tribute_interval)
	_sacrifice_value = _coin(coins, HudIcon.sacrifice(COIN_ICON),
			"Sacrificios: cada muerte suma uno (en el altar, más). Se gastan en la tienda: las cosas malas cuestan ofrendas y sacrificios")
	_sacrifice_chip = _sacrifice_value.get_parent().get_parent()
	coins.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	coins.grow_horizontal = Control.GROW_DIRECTION_BEGIN

## Una moneda de arriba a la derecha: el ícono y cuántas hay (devuelve el número).
func _coin(parent: Control, icon: Control, tip: String) -> Label:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(COIN_W, 0)
	chip.tooltip_text = tip
	chip.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.C_PANEL, 21, UiStyle.C_PANEL_BORDER, 1, Vector4(6, 4, 14, 4)))
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(icon)
	var value := UiStyle.label("", 21, UiStyle.C_TEXT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
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
	b.add_theme_stylebox_override("normal", UiStyle.box(color, 10, color.lightened(0.3), 1))
	b.add_theme_stylebox_override("hover", UiStyle.box(color.lightened(0.15), 10, color.lightened(0.5), 1))
	b.add_theme_stylebox_override("pressed", UiStyle.box(color.darkened(0.15), 10, color.darkened(0.3), 1))
	b.add_theme_stylebox_override("disabled", UiStyle.box(Color(1, 1, 1, 0.07), 10, Color(1, 1, 1, 0.08), 1))
	parent.add_child(b)
	return b

## El anillo de devoción alrededor del +: se llena desde arriba, en el sentido del reloj, con la
## devoción. Si no alcanza para invocar (cost), apagado.
class DevotionRing extends Control:
	var max_value := 100.0
	var cost := 10.0
	var value := 0.0:
		set(v):
			if not is_equal_approx(v, value):
				value = v
				queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - TopBar.RING_W * 0.5
		draw_arc(c, r, 0.0, TAU, 64, Color(0.06, 0.09, 0.16, 0.75), TopBar.RING_W + 3.0, true)
		var k := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
		if k > 0.002:
			var col := UiStyle.C_DEVOTION if value >= cost else UiStyle.C_DEVOTION.darkened(0.45)
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * k, maxi(3, int(64.0 * k)), col, TopBar.RING_W, true)
