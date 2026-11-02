extends Control
class_name Shop
## Tienda: se gastan ofrendas, y en las cosas malas (los poderes malos, la Luna de Sangre y los
## tiburones) también sacrificios (ver HUD.buy). Va en pestañas, de a una por vez: la isla (decoraciones, que se
## cobran recién al colocarlas, ver DecorPlacer), los poderes malos (pistola, rayo, meteorito,
## tornado, diluvio, peste, espora y la manzana de la discordia), los buenos (curar, la vacuna, el
## escudo, la resurrección, el arco de Cupido y la pelota de la amistad), y el cielo y los tiburones
## (la Luna de Sangre y los tiburones).
## Tiene el tamaño de la pestaña más grande, así no salta al cambiar. Se vuelve a abrir en la
## última que se miró, o en la del poder bloqueado que se tocó en la barra (ver HUD.open_shop).

enum Tab { ISLAND, EVIL, GOOD, SKY }
## Por pestaña: [título, ícono (ver HUD.HudIcon), color, lo que hay]
const TABS := {
	Tab.ISLAND: ["Isla", "island", Color(1.0, 0.86, 0.42),
			"Decoraciones: se cobran recién al colocarlas. Las palmeras dan cocos y los arbustos, bayas para los que tienen hambre."],
	Tab.EVIL: ["Poderes malos", "evil", HUD.C_EVIL, "Para castigar a tus aldeanos (y sacrificarlos). Cuestan ofrendas y sacrificios."],
	Tab.GOOD: ["Poderes buenos", "holy", HUD.C_HOLY, "Para cuidar a tus aldeanos y juntarlos."],
	Tab.SKY: ["Cielo y tiburones", "shark", HUD.C_DEVOTION,
			"La Luna de Sangre se come a los que le soltás encima; los tiburones patrullan el agua. Cuestan ofrendas y sacrificios."],
}
const TAB_H := 34.0
const TAB_ICON := 18
const CARD_W := 96.0
const CARD_GAP := 8
const PREVIEW_SIZE := Vector2(76, 60)

## La pestaña que se está mirando (queda para la próxima vez, aunque se rearme la tienda).
static var _tab := Tab.ISLAND

var hud: HUD
var _balance: Label
var _sacrifice_balance: Label
var _desc: Label
var _tab_btns := {}           # Tab -> Button
var _pages := {}              # Tab -> Control
var _deco_buttons := {}       # kind -> Button
var _gun_btn: Button
var _lightning_btn: Button
var _meteor_btn: Button
var _tornado_btn: Button
var _storm_btn: Button
var _plague_btn: Button
var _spore_btn: Button
var _cure_btn: Button
var _moon_btn: Button
var _charm_btns := {}         # Charm.Kind -> Button
var _miracle_btns := {}       # Miracle.Kind -> Button
var _sharks: Array[Dictionary] = []   # Por tarjeta: {btn, icon, price, status}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Fondo oscurecido: click afuera del panel cierra
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HUD.make_box(Color(0.06, 0.09, 0.16, 0.96), 16, HUD.C_PANEL_BORDER, 1, Vector4(18, 16, 18, 18)))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(HUD.make_label("Tienda", 20, HUD.C_TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(HUD.HudIcon.make("coin", 18))
	_balance = HUD.make_label("", 16, HUD.C_OFFERING)
	head.add_child(_balance)
	var coin_gap := Control.new()
	coin_gap.custom_minimum_size = Vector2(6, 0)
	head.add_child(coin_gap)
	head.add_child(HUD.sacrifice_icon(20))
	_sacrifice_balance = HUD.make_label("", 16, HUD.C_TEXT)
	head.add_child(_sacrifice_balance)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	head.add_child(gap)
	var close_btn := _flat_button("✕")
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	col.add_child(HUD.make_label("Las ofrendas te las dejan rezando (y cada muerte); los sacrificios, cada muerte (el altar da más). Las cosas malas cuestan las dos.", 12, HUD.C_MUTED))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for t: Tab in TABS:
		_tab_btns[t] = _tab_button(tabs, t)
	_desc = HUD.make_label("", 12, HUD.C_TEXT)
	col.add_child(_desc)

	# Las páginas, una encima de la otra: se ve la de la pestaña elegida
	var pages := MarginContainer.new()
	col.add_child(pages)
	for t: Tab in TABS:
		var page := HBoxContainer.new()
		page.add_theme_constant_override("separation", 22)
		pages.add_child(page)
		_pages[t] = page
	_build_island(_pages[Tab.ISLAND])
	_build_powers(_pages[Tab.EVIL], _pages[Tab.GOOD])
	_build_sky(_pages[Tab.SKY])
	# Del tamaño de la más grande (las escondidas no cuentan para el tamaño)
	var most := Vector2.ZERO
	for page: Control in _pages.values():
		most = most.max(page.get_combined_minimum_size())
	pages.custom_minimum_size = most
	_set_tab(_tab)

## Decoraciones para la isla.
func _build_island(page: Control) -> void:
	var row := _row(page)
	for kind: String in Decoration.KINDS:
		var info: Dictionary = Decoration.KINDS[kind]
		var preview := DecorPreview.new()
		preview.kind = kind
		var b := _card(row, preview, info.name, info.price, "Colocar")
		b.pressed.connect(func():
			close()
			hud.decoration_chosen.emit(kind))
		_deco_buttons[kind] = b

## Los poderes malos y los buenos (como las pestañas de la barra).
func _build_powers(evil_page: Control, good_page: Control) -> void:
	var rows := {false: _row(evil_page), true: _row(good_page)}   # bueno -> fila
	for t in HUD.TOOLS:
		if t[0] == "feed":
			continue   # La comida no se compra: está desde el principio
		var power_row: HBoxContainer = rows[t[5]]
		var icon := CenterContainer.new()
		icon.add_child(HUD.HudIcon.make(t[0], 40))
		match t[0]:
			"gun":
				_gun_btn = _unlock_card(power_row, icon, t[1], Gun.PRICE, "", hud.unlock_gun, Gun.SACRIFICES)
			"lightning":
				_lightning_btn = _unlock_card(power_row, icon, t[1], Lightning.PRICE,
						"Fulmina aldeanos y salta a los que están cerca. En el agua fríe a todos los que flotan.", hud.unlock_lightning, Lightning.SACRIFICES)
			"meteor":
				_meteor_btn = _unlock_card(power_row, icon, t[1], Meteor.PRICE,
						"Explota y deja un cráter: mata a los que están cerca y hace volar a los demás.", hud.unlock_meteor, Meteor.SACRIFICES)
			"tornado":
				_tornado_btn = _unlock_card(power_row, icon, t[1], Tornado.PRICE,
						"Mantené el click y llevalo con el mouse: levanta aldeanos, cocos y tiburones, los hace girar y los revolea.", hud.unlock_tornado, Tornado.SACRIFICES)
			"rain":
				_storm_btn = _unlock_card(power_row, icon, t[1], Storm.PRICE,
						"Una tormenta que inunda la orilla: el agua se lleva a los que alcanza. La lluvia apaga el fuego.", hud.unlock_storm, Storm.SACRIFICES)
			"plague":
				_plague_btn = _unlock_card(power_row, icon, t[1], Plague.PRICE,
						"Una nube de miasma que enferma de gripe a los que alcanza. Después se contagian solos.", hud.unlock_plague, Plague.SACRIFICES)
			"spore":
				_spore_btn = _unlock_card(power_row, icon, t[1], Spore.PRICE,
						"Un hongo zombi, como el cordyceps: de a poco se adueña de ellos, los hace zombis que muerden a los sanos y al final les brota de la cabeza.", hud.unlock_spore, Spore.SACRIFICES)
			"cure":
				_cure_btn = _unlock_card(power_row, icon, t[1], Cure.PRICE,
						"Un haz de luz que cura la gripe (y deja inmune un rato) y la espora (si todavía no son zombis), y apaga y sana a los que se queman.", hud.unlock_cure)
			"cupid", "discord", "friendship":
				var k: Charm.Kind = HUD.CHARM_ICONS[t[0]]
				_charm_btns[k] = _unlock_card(power_row, icon, t[1], Charm.KINDS[k].price, Charm.KINDS[k].shop,
						hud.unlock_charm.bind(k), Charm.KINDS[k].sacrifices)
			"resurrect", "shield", "vaccine":
				var k: Miracle.Kind = HUD.MIRACLE_ICONS[t[0]]
				_miracle_btns[k] = _unlock_card(power_row, icon, t[1], Miracle.KINDS[k].price, Miracle.KINDS[k].shop,
						hud.unlock_miracle.bind(k))
			_:
				icon.modulate = Color(1, 1, 1, 0.45)
				var b := _card(power_row, icon, t[1], -1, "Próximamente")
				b.disabled = true

## El cielo (la Luna de Sangre y, próximamente, el Sol de Sangre) y los tiburones.
func _build_sky(page: Control) -> void:
	var sky_col := VBoxContainer.new()
	sky_col.add_theme_constant_override("separation", 10)
	page.add_child(sky_col)
	sky_col.add_child(_section("Cielo"))
	var sky_row := _row(sky_col)
	var moon_icon := CenterContainer.new()
	moon_icon.add_child(HUD.HudIcon.make("blood_moon", 44))
	_moon_btn = _unlock_card(sky_row, moon_icon, "Luna de Sangre", Moon.PRICE,
			"De noche, tocá la luna 5 veces. Soltale aldeanos encima para alimentarla.", hud.unlock_blood_moon, Moon.SACRIFICES)
	var sun_icon := CenterContainer.new()
	sun_icon.add_child(HUD.HudIcon.make("blood_sun", 44))
	sun_icon.modulate = Color(1, 1, 1, 0.45)
	_card(sky_row, sun_icon, "Sol de Sangre", -1, "Próximamente").disabled = true

	var shark_col := VBoxContainer.new()
	shark_col.add_theme_constant_override("separation", 10)
	page.add_child(shark_col)
	shark_col.add_child(_section(tr("Tiburones (máx. %d)") % Shark.MAX))
	var shark_row := _row(shark_col)
	for i in Shark.MAX:
		var icon := CenterContainer.new()
		icon.add_child(HUD.HudIcon.make("shark", 40))
		var b := _card(shark_row, icon, tr("Tiburón %d") % (i + 1), Shark.PRICE, "Comprar", Shark.SACRIFICES)
		var card := b.get_parent()
		var price: Control = card.get_node("Price")
		var status := HUD.make_label("", 12, HUD.C_TEXT)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(status)
		card.move_child(status, price.get_index())
		b.pressed.connect(func():
			if hud.shark_owned[i]:
				hud.set_shark_on(i, not hud.shark_on[i])
			else:
				hud.buy_shark()
			_sync())
		_sharks.append({"btn": b, "icon": icon, "price": price, "status": status})

## Abre la tienda (en la pestaña tab, o en la última que se miró).
func open(tab := -1) -> void:
	if tab >= 0:
		_set_tab(tab)
	visible = true
	_sync()

func _set_tab(t: Tab) -> void:
	_tab = t
	_desc.text = TABS[t][3]
	for k: Tab in _pages:
		_pages[k].visible = k == t
	for k: Tab in _tab_btns:
		var b: Button = _tab_btns[k]
		var on := k == t
		var c: Color = TABS[k][2]
		var pad := Vector4(10 + TAB_ICON + 7, 2, 14, 2)
		var box := HUD.make_box(Color(c, 0.24), 9, Color(c, 0.8), 2, pad) if on \
				else HUD.make_box(Color(1, 1, 1, 0.06), 9, Color(1, 1, 1, 0.10), 1, pad)
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box if on else HUD.make_box(Color(c, 0.14), 9, Color(c, 0.5), 1, pad))
		b.add_theme_stylebox_override("pressed", box)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(state, c if on else HUD.C_MUTED)
		b.get_meta("icon").modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)

func close() -> void:
	visible = false

func _process(_dt: float) -> void:
	if visible:
		_sync()  # Las ofrendas pueden subir mientras está abierta

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _sync() -> void:
	_balance.text = str(hud.offerings)
	_sacrifice_balance.text = str(hud.sacrifices)
	for kind: String in _deco_buttons:
		_deco_buttons[kind].disabled = not hud.can_afford(Decoration.price_of(kind))
	_sync_unlock(_gun_btn, Gun.unlocked, Gun.PRICE, "Desbloqueada", Gun.SACRIFICES)
	_sync_unlock(_lightning_btn, Lightning.unlocked, Lightning.PRICE, "Desbloqueado", Lightning.SACRIFICES)
	_sync_unlock(_meteor_btn, Meteor.unlocked, Meteor.PRICE, "Desbloqueado", Meteor.SACRIFICES)
	_sync_unlock(_tornado_btn, Tornado.unlocked, Tornado.PRICE, "Desbloqueado", Tornado.SACRIFICES)
	_sync_unlock(_storm_btn, Storm.unlocked, Storm.PRICE, "Desbloqueado", Storm.SACRIFICES)
	_sync_unlock(_plague_btn, Plague.unlocked, Plague.PRICE, "Desbloqueada", Plague.SACRIFICES)
	_sync_unlock(_spore_btn, Spore.unlocked, Spore.PRICE, "Desbloqueada", Spore.SACRIFICES)
	_sync_unlock(_cure_btn, Cure.unlocked, Cure.PRICE, "Desbloqueado")
	_sync_unlock(_moon_btn, Moon.blood_unlocked, Moon.PRICE, "Desbloqueada", Moon.SACRIFICES)
	for k: Charm.Kind in _charm_btns:
		_sync_unlock(_charm_btns[k], Charm.unlocked[k], Charm.KINDS[k].price, Charm.KINDS[k].done, Charm.KINDS[k].sacrifices)
	for k: Miracle.Kind in _miracle_btns:
		_sync_unlock(_miracle_btns[k], Miracle.unlocked[k], Miracle.KINDS[k].price, Miracle.KINDS[k].done)
	var next := hud.shark_owned.find(false)   # Se compran en orden: el primero que falta
	for i in _sharks.size():
		var s: Dictionary = _sharks[i]
		var b: Button = s.btn
		var bought := hud.shark_owned[i]
		var on := bought and hud.shark_on[i]
		s.price.visible = not bought
		s.status.visible = bought
		s.status.text = "Activo" if on else "Apagado"
		s.status.add_theme_color_override("font_color", HUD.C_SHOP if on else HUD.C_MUTED)
		s.icon.modulate = Color.WHITE if on or not bought else Color(1, 1, 1, 0.45)
		if bought:
			b.text = "Desactivar" if on else "Activar"
			b.disabled = false
		else:
			# (Si matan al primero y el segundo sigue vivo, se recompra el primero)
			b.text = "Comprar"
			b.disabled = i != next or not hud.can_buy(Shark.PRICE, Shark.SACRIFICES)

## done: lo que dice una vez desbloqueado ("Desbloqueada" o "Desbloqueado", según el artículo).
## sacrifice_cost: lo que cuesta en sacrificios (las cosas malas).
func _sync_unlock(b: Button, unlocked: bool, price: int, done: String, sacrifice_cost := 0) -> void:
	b.text = done if unlocked else "Desbloquear"
	b.disabled = unlocked or not hud.can_buy(price, sacrifice_cost)

# ---- Construcción ----
## Tarjeta de algo que se desbloquea una sola vez (armas, poderes, la Luna de Sangre).
func _unlock_card(parent: Control, preview: Control, title: String, price: int, tip: String, unlock: Callable,
		sacrifice_cost := 0) -> Button:
	var b := _card(parent, preview, title, price, "Desbloquear", sacrifice_cost)
	b.tooltip_text = tip
	b.pressed.connect(func():
		unlock.call()
		_sync())
	return b

## Pestaña con su ícono adelante del título.
func _tab_button(parent: Control, t: Tab) -> Button:
	var b := Button.new()
	b.text = TABS[t][0]
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, TAB_H)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(_set_tab.bind(t))
	parent.add_child(b)
	var icon := HUD.HudIcon.make(TABS[t][1], TAB_ICON)
	icon.position = Vector2(10, (TAB_H - TAB_ICON) * 0.5)
	b.add_child(icon)
	b.set_meta("icon", icon)
	return b

## Una fila de tarjetas (de su alto, aunque la página sea más alta: si no, se estiran).
func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(row)
	return row

func _section(title: String) -> Label:
	var l := HUD.make_label(title, 11, HUD.C_MUTED)
	l.uppercase = true   # Mayúsculas al mostrar, así el texto sigue siendo la clave de traducción
	return l

## Tarjeta de un artículo; devuelve el botón de comprar. price < 0: sin precio. sacrifice_cost:
## lo que cuesta además en sacrificios (las cosas malas), al lado de las ofrendas.
func _card(parent: Control, preview: Control, title: String, price: int, action: String, sacrifice_cost := 0) -> Button:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.add_theme_stylebox_override("panel", HUD.make_box(Color(1, 1, 1, 0.06), 12, Color(1, 1, 1, 0.10), 1, Vector4(10, 10, 10, 10)))
	parent.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)

	preview.custom_minimum_size = PREVIEW_SIZE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(preview)
	var name_l := HUD.make_label(title, 13, HUD.C_TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Los nombres largos ("Arbusto de bayas") en dos renglones, así la tienda entra a lo ancho
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(PREVIEW_SIZE.x, 0)
	v.add_child(name_l)

	var price_row := HBoxContainer.new()
	price_row.name = "Price"
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 4)
	v.add_child(price_row)
	if price >= 0:
		price_row.add_child(HUD.HudIcon.make("coin", 12))
		price_row.add_child(HUD.make_label(str(price), 12, HUD.C_OFFERING))
		if sacrifice_cost > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(3, 0)
			price_row.add_child(gap)
			price_row.add_child(HUD.sacrifice_icon(14))
			price_row.add_child(HUD.make_label(str(sacrifice_cost), 12, HUD.C_TEXT))
	else:
		price_row.add_child(HUD.make_label("—", 12, HUD.C_MUTED))

	var b := Button.new()
	b.text = action
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_font_size_override("font_size", 12)
	var ink := Color(0.08, 0.14, 0.08)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, ink)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_stylebox_override("normal", HUD.make_box(HUD.C_SHOP, 8, HUD.C_SHOP.lightened(0.3), 1))
	b.add_theme_stylebox_override("hover", HUD.make_box(HUD.C_SHOP.lightened(0.15), 8, HUD.C_SHOP.lightened(0.5), 1))
	b.add_theme_stylebox_override("pressed", HUD.make_box(HUD.C_SHOP.darkened(0.15), 8, HUD.C_SHOP.darkened(0.3), 1))
	b.add_theme_stylebox_override("disabled", HUD.make_box(Color(1, 1, 1, 0.07), 8, Color(1, 1, 1, 0.08), 1))
	v.add_child(b)
	return b

func _flat_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(28, 28)
	b.add_theme_stylebox_override("normal", HUD.make_box(Color(1, 1, 1, 0.08), 8))
	b.add_theme_stylebox_override("hover", HUD.make_box(Color(1, 1, 1, 0.18), 8))
	b.add_theme_stylebox_override("pressed", HUD.make_box(Color(1, 1, 1, 0.26), 8))
	return b

## Vista previa de una decoración, con su mismo dibujo.
class DecorPreview extends Control:
	var kind := ""

	func _process(_dt: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var s: float = Decoration.KINDS[kind].icon_scale
		Decoration.paint(self, kind, 0.5, Time.get_ticks_msec() / 1000.0, Decoration.ALL_FRUIT, 1.0, "",
				Vector2(size.x * 0.5, size.y - 6.0), s)
