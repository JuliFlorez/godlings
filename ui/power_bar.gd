extends VBoxContainer
class_name PowerBar
## La barra de abajo al centro (ver HUD): el modo del click (arrastrar aldeanos, seleccionarlos o
## editar la isla) y los poderes, en dos pestañas (los malos y los buenos). Cada poder tiene su
## slot: lo saca o lo guarda; bloqueado, se ve apagado y lleva a la tienda; resaltado mientras
## está afuera, y con una barrita abajo mientras se recarga. Ocupa toda la pantalla sin atajar el
## mouse: los clicks los atajan solo sus paneles.

const TAB_SIZE := 38.0
const SLOT_SIZE := Vector2(76, 62)

var hud: HUD
## Los poderes de la barra (ver set_powers), en su orden, y el slot de cada uno.
var powers: Array[Power] = []
var _power_slots := {}        # Power -> Button
var _power_row: HBoxContainer
## Las pestañas: qué slots van en cada una y cuál se ve.
var _good_tab := false
var _tab_evil: Button
var _tab_holy: Button
var _tool_slots := {}         # Button -> bueno (bool)
var _slot_idle: StyleBoxFlat
var _slot_hover: StyleBoxFlat
var _slot_active: StyleBoxFlat
var _slot_mode: StyleBoxFlat
var _drag_btn: Button
var _select_btn: Button
var _edit_btn: Button

func _ready() -> void:
	_slot_idle = UiStyle.box(Color(1, 1, 1, 0.06), 12, Color(1, 1, 1, 0.10), 1)
	_slot_hover = UiStyle.box(Color(1, 1, 1, 0.13), 12, Color(1, 1, 1, 0.28), 1)
	_slot_active = UiStyle.box(Color(UiStyle.C_GUN, 0.38), 12, UiStyle.C_GUN.lightened(0.3), 2)
	_slot_mode = UiStyle.box(Color(UiStyle.C_DEVOTION, 0.30), 12, UiStyle.C_DEVOTION.lightened(0.2), 2)

	# De pantalla completa, sin atajar el mouse: la barra va abajo al centro
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (Ya está en el árbol: con los offsets)
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var bottom_gap := Control.new()
	bottom_gap.custom_minimum_size = Vector2(0, 8)
	bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_gap)
	var bars := HBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_theme_constant_override("separation", 10)
	center.add_child(bars)

	# Modo del click: arrastrar aldeanos, seleccionarlos (carnet) o editar la isla
	var mode_row := _toolbar_panel(bars)
	_drag_btn = _tool_slot(mode_row, "hand", "Arrastrar", "", true, "")   # (Los tooltips, con su tecla: ver refresh)
	_drag_btn.pressed.connect(hud.set_drag_mode)
	_select_btn = _tool_slot(mode_row, "select", "Seleccionar", Controls.label(Controls.SELECT_MODE), true, "")
	_select_btn.pressed.connect(hud.set_select_mode.bind(true))
	_edit_btn = _tool_slot(mode_row, "edit", "Editar isla", Controls.label(Controls.EDIT_ISLAND), true, "")
	_edit_btn.pressed.connect(hud.set_edit_mode.bind(true))
	mode_row.get_parent().size_flags_vertical = Control.SIZE_SHRINK_END   # Abajo, a la par de los poderes

	# Poderes: arriba las pestañas (malos / buenos) y abajo los de la pestaña elegida
	var tools_col := VBoxContainer.new()
	tools_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools_col.add_theme_constant_override("separation", 4)
	bars.add_child(tools_col)
	var tabs := HBoxContainer.new()
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_theme_constant_override("separation", 6)
	tools_col.add_child(tabs)
	var tab_gap := Control.new()
	tab_gap.custom_minimum_size = Vector2(6, 0)
	tab_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_child(tab_gap)
	_tab_evil = _tab_button(tabs, "evil", "Poderes malos")
	_tab_evil.pressed.connect(_set_tab.bind(false))
	_tab_holy = _tab_button(tabs, "holy", "Poderes buenos")
	_tab_holy.pressed.connect(_set_tab.bind(true))
	var row := _toolbar_panel(tools_col)

	_power_row = row   # Los slots de los poderes van acá (ver set_powers)
	_set_tab(false)

## Recargándose (el diluvio): la barrita de abajo del slot se va llenando y el ícono, apagado.
func _process(_delta: float) -> void:
	for power in powers:
		var fill := power.recharge()
		var charging := power.unlocked and fill < 1.0 and not power.armed
		var slot: Button = _power_slots[power]
		var bar: ColorRect = slot.get_meta("charge")
		bar.visible = charging
		if charging:
			bar.size.x = (SLOT_SIZE.x - 16.0) * fill
		if power.unlocked:
			slot.get_meta("icon").modulate = Color(1, 1, 1, 0.45) if charging else Color.WHITE

## Los poderes de la barra (ver World._create_powers), en su orden: un slot para cada uno, en la
## pestaña de los malos o de los buenos.
func set_powers(list: Array[Power]) -> void:
	powers = list
	for power in powers:
		_power_slots[power] = _power_slot(power)
		power.armed_changed.connect(_on_power_armed.bind(power))
	# Del ancho de la pestaña más llena: así la barra no salta al cambiar de pestaña
	var most := 0
	for good: bool in [false, true]:
		most = maxi(most, _tool_slots.values().count(good))
	_power_row.custom_minimum_size.x = most * SLOT_SIZE.x + (most - 1) * _power_row.get_theme_constant("separation")
	_set_tab(false)

## Sacado con su tecla desde la otra pestaña: la barra pasa a la suya, así se ve resaltado.
## (power va último: se conecta con bind, que lo agrega al final.)
func _on_power_armed(on: bool, power: Power) -> void:
	if on:
		_show_tool(_power_slots[power])

## Cómo se ve cada slot (lo llama HUD._refresh): el poder que está afuera, resaltado; bloqueado,
## apagado y con el cartel "En la tienda"; y resaltado el modo del click que está puesto.
func refresh() -> void:
	for power in powers:
		var slot: Button = _power_slots[power]
		_sync_weapon(slot, power.unlocked, power.armed, slot.get_meta("active"), power.slot_tooltip(), power.locked_tooltip,
				power.price, power.sacrifices)
	var dragging := not hud.select_mode and not hud.edit_mode
	for b: Array in [[_drag_btn, dragging], [_select_btn, hud.select_mode], [_edit_btn, hud.edit_mode]]:
		b[0].add_theme_stylebox_override("normal", _slot_mode if b[1] else _slot_idle)
		b[0].add_theme_stylebox_override("hover", _slot_mode if b[1] else _slot_hover)
	# Con su tecla, que sale de Controls (y acá, así siguen al idioma)
	_drag_btn.tooltip_text = Controls.tip("Agarrá y tirá aldeanos", Controls.SELECT_MODE)
	_select_btn.tooltip_text = Controls.tip("Click en un aldeano para ver su carnet, o en una choza para ponerle nombre",
			Controls.SELECT_MODE)
	_edit_btn.tooltip_text = Controls.tip("Mover y quitar decoraciones, sin agarrar aldeanos", Controls.EDIT_ISLAND)

## Slot de un arma o poder de la tienda: resaltado mientras está afuera; bloqueado se ve
## apagado, con el cartel "En la tienda" (y lo que cuesta: las cosas malas, también sacrificios).
func _sync_weapon(slot: Button, unlocked: bool, out: bool, active: StyleBoxFlat, tip: String, locked_tip: String, price: int,
		sacrifice_cost := 0) -> void:
	slot.add_theme_stylebox_override("normal", active if out else _slot_idle)
	slot.add_theme_stylebox_override("hover", active if out else _slot_hover)
	slot.get_meta("lock").visible = not unlocked
	slot.get_meta("icon").modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.45)
	if unlocked:
		slot.tooltip_text = tip   # (Ya traducido y con la tecla, ver Power.slot_tooltip)
	elif sacrifice_cost > 0:
		slot.tooltip_text = tr(locked_tip) % [price, sacrifice_cost]   # El texto "... ofrendas y %d sacrificios)"
	else:
		slot.tooltip_text = tr(locked_tip) % price

## Muestra los poderes malos o los buenos.
func _set_tab(good: bool) -> void:
	_good_tab = good
	for slot: Button in _tool_slots:
		slot.visible = _tool_slots[slot] == good
	for tab: Button in [_tab_evil, _tab_holy]:
		var on := (tab == _tab_holy) == good
		var col := UiStyle.C_HOLY if tab == _tab_holy else UiStyle.C_EVIL
		var r := int(TAB_SIZE * 0.5)
		var box := UiStyle.box(Color(col, 0.32), r, col.lightened(0.25), 2) if on \
				else UiStyle.box(Color(UiStyle.C_PANEL, 0.9), r, Color(1, 1, 1, 0.14), 1)
		var hover := box if on else UiStyle.box(Color(col, 0.18), r, Color(col, 0.6), 1)
		tab.add_theme_stylebox_override("normal", box)
		tab.add_theme_stylebox_override("hover", hover)
		tab.add_theme_stylebox_override("pressed", hover)
		tab.get_meta("icon").modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)

## Al sacar un poder con su tecla, que se vea en la barra (pasa a su pestaña).
func _show_tool(btn: Button) -> void:
	if _tool_slots.has(btn) and _tool_slots[btn] != _good_tab:
		_set_tab(_tool_slots[btn])

## Pestaña redonda con un ícono (la carita con cuernos o con aureola).
func _tab_button(parent: Control, kind: String, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TAB_SIZE, TAB_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	parent.add_child(b)
	var icon := HudIcon.make(kind, int(TAB_SIZE) - 8)
	icon.position = Vector2(4, 4)
	b.add_child(icon)
	b.set_meta("icon", icon)
	return b

## El slot de un poder: lo saca o lo guarda, y bloqueado lleva a la tienda (a la pestaña de los
## poderes buenos o de los malos). Abajo tiene una barrita que se llena mientras se recarga.
func _power_slot(power: Power) -> Button:
	var slot := _tool_slot(_power_row, power.icon_kind(), power.title, power.key_label(), true,
			power.slot_tooltip())
	_tool_slots[slot] = power.good
	var active := UiStyle.box(Color(power.accent, 0.32), 12, power.accent.lightened(0.3), 2)
	slot.set_meta("active", active)
	slot.add_theme_stylebox_override("pressed", active)
	slot.set_meta("lock", _slot_badge(slot, "EN LA TIENDA", UiStyle.C_SHOP))
	var bar := ColorRect.new()
	bar.color = power.accent
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(8.0, SLOT_SIZE.y - 6.0)
	bar.size = Vector2(0.0, 3.0)
	bar.visible = false
	slot.add_child(bar)
	slot.set_meta("charge", bar)
	slot.pressed.connect(func():
		if power.unlocked:
			power.set_armed(not power.armed)
		else:
			hud.open_shop(Shop.Tab.GOOD if power.good else Shop.Tab.EVIL))
	return slot

## Panel de la barra de abajo; devuelve la fila donde van los slots.
func _toolbar_panel(parent: Control) -> HBoxContainer:
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP  # Los clicks en la barra no llegan al mundo
	bar.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.C_PANEL, 14, UiStyle.C_PANEL_BORDER, 1, Vector4(8, 8, 8, 8)))
	parent.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	return row

func _tool_slot(parent: Control, kind: String, title: String, key: String, available: bool, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SLOT_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_stylebox_override("normal", _slot_idle)
	b.add_theme_stylebox_override("hover", _slot_hover)
	b.add_theme_stylebox_override("pressed", _slot_active)
	b.add_theme_stylebox_override("disabled", UiStyle.box(Color(1, 1, 1, 0.03), 12, Color(1, 1, 1, 0.06), 1))
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
	var name_l := UiStyle.label(title, 11, UiStyle.C_TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)

	if key != "":
		var k := UiStyle.label(key, 10, UiStyle.C_MUTED)
		k.position = Vector2(8, 4)
		b.add_child(k)

	b.set_meta("icon", icon)
	if not available:
		b.disabled = true
		icon.modulate = Color(1, 1, 1, 0.5)
		name_l.modulate = Color(1, 1, 1, 0.55)
		_slot_badge(b, "PRÓXIMAMENTE", UiStyle.C_SOON)
	return b

## Cartelito ("Próximamente", "En la tienda") pegado sobre el borde superior del slot.
func _slot_badge(slot: Control, text: String, color: Color) -> Control:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", UiStyle.box(color, 4, color.darkened(0.4), 1, Vector4(4, 0, 4, 0)))
	badge.add_child(UiStyle.label(text, 8, Color(0.18, 0.11, 0.02)))
	slot.add_child(badge)
	var sz := badge.get_combined_minimum_size()
	badge.size = sz
	badge.pivot_offset = sz * 0.5
	badge.position = Vector2(SLOT_SIZE.x * 0.5 - sz.x * 0.5, -sz.y * 0.55)
	badge.rotation = deg_to_rad(-6.0)
	return badge
