extends Control
class_name Shop
## Tienda: se gastan ofrendas en decoraciones para la isla, el cielo (Luna de Sangre),
## tiburones y poderes: los malos (pistola, rayo, meteorito, tornado, diluvio, peste y la
## manzana de la discordia) y los buenos (curar, el arco de Cupido y la pelota de la amistad).
## Arriba van las decoraciones, el cielo y los tiburones, y abajo los poderes, como en las
## pestañas de la barra. Las decoraciones se cobran recién al colocarlas (ver DecorPlacer).

const CARD_W := 96.0
const CARD_GAP := 8
const PREVIEW_SIZE := Vector2(76, 60)

var hud: HUD
var _balance: Label
var _deco_buttons := {}       # kind -> Button
var _gun_btn: Button
var _lightning_btn: Button
var _meteor_btn: Button
var _tornado_btn: Button
var _storm_btn: Button
var _plague_btn: Button
var _cure_btn: Button
var _moon_btn: Button
var _charm_btns := {}         # Charm.Kind -> Button
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
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	head.add_child(gap)
	var close_btn := _flat_button("✕")
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	col.add_child(HUD.make_label("Ganás ofrendas con cada sacrificio y cuando tus aldeanos rezan.", 12, HUD.C_MUTED))

	# Decoración, cielo y tiburones comparten fila (y abajo, los poderes malos y los buenos)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	col.add_child(top)
	var deco_col := VBoxContainer.new()
	deco_col.add_theme_constant_override("separation", 10)
	top.add_child(deco_col)
	deco_col.add_child(_section("Decoración para la isla"))
	var deco_row := HBoxContainer.new()
	deco_row.add_theme_constant_override("separation", CARD_GAP)
	deco_col.add_child(deco_row)
	for kind: String in Decoration.KINDS:
		var info: Dictionary = Decoration.KINDS[kind]
		var preview := DecorPreview.new()
		preview.kind = kind
		var b := _card(deco_row, preview, info.name, info.price, "Colocar")
		b.pressed.connect(func():
			close()
			hud.decoration_chosen.emit(kind))
		_deco_buttons[kind] = b

	var sky_col := VBoxContainer.new()
	sky_col.add_theme_constant_override("separation", 10)
	top.add_child(sky_col)
	sky_col.add_child(_section("Cielo"))
	var sky_row := HBoxContainer.new()
	sky_row.add_theme_constant_override("separation", CARD_GAP)
	sky_col.add_child(sky_row)
	var moon_icon := CenterContainer.new()
	moon_icon.add_child(HUD.HudIcon.make("blood_moon", 44))
	_moon_btn = _unlock_card(sky_row, moon_icon, "Luna de Sangre", Moon.PRICE,
			"De noche, tocá la luna 5 veces. Soltale aldeanos encima para alimentarla.", hud.unlock_blood_moon)
	var sun_icon := CenterContainer.new()
	sun_icon.add_child(HUD.HudIcon.make("blood_sun", 44))
	sun_icon.modulate = Color(1, 1, 1, 0.45)
	_card(sky_row, sun_icon, "Sol de Sangre", -1, "Próximamente").disabled = true

	var shark_col := VBoxContainer.new()
	shark_col.add_theme_constant_override("separation", 10)
	top.add_child(shark_col)
	shark_col.add_child(_section(tr("Tiburones (máx. %d)") % Shark.MAX))
	var shark_row := HBoxContainer.new()
	shark_row.add_theme_constant_override("separation", CARD_GAP)
	shark_col.add_child(shark_row)
	for i in Shark.MAX:
		var icon := CenterContainer.new()
		icon.add_child(HUD.HudIcon.make("shark", 40))
		var b := _card(shark_row, icon, tr("Tiburón %d") % (i + 1), Shark.PRICE, "Comprar")
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

	# Los poderes, malos y buenos (como las pestañas de la barra)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 22)
	col.add_child(bottom)
	var power_rows := {}   # bueno -> fila
	for good: bool in [false, true]:
		var power_col := VBoxContainer.new()
		power_col.add_theme_constant_override("separation", 10)
		bottom.add_child(power_col)
		power_col.add_child(_section("Poderes buenos" if good else "Poderes malos"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", CARD_GAP)
		power_col.add_child(row)
		power_rows[good] = row
	for t in HUD.TOOLS:
		var power_row: HBoxContainer = power_rows[t[5]]
		var icon := CenterContainer.new()
		icon.add_child(HUD.HudIcon.make(t[0], 40))
		match t[0]:
			"gun":
				_gun_btn = _unlock_card(power_row, icon, t[1], Gun.PRICE, "", hud.unlock_gun)
			"lightning":
				_lightning_btn = _unlock_card(power_row, icon, t[1], Lightning.PRICE,
						"Fulmina aldeanos y salta a los que están cerca. En el agua fríe a todos los que flotan.", hud.unlock_lightning)
			"meteor":
				_meteor_btn = _unlock_card(power_row, icon, t[1], Meteor.PRICE,
						"Explota y deja un cráter: mata a los que están cerca y hace volar a los demás.", hud.unlock_meteor)
			"tornado":
				_tornado_btn = _unlock_card(power_row, icon, t[1], Tornado.PRICE,
						"Mantené el click y llevalo con el mouse: levanta aldeanos, cocos y tiburones, los hace girar y los revolea.", hud.unlock_tornado)
			"rain":
				_storm_btn = _unlock_card(power_row, icon, t[1], Storm.PRICE,
						"Una tormenta que inunda la orilla: el agua se lleva a los que alcanza. La lluvia apaga el fuego.", hud.unlock_storm)
			"plague":
				_plague_btn = _unlock_card(power_row, icon, t[1], Plague.PRICE,
						"Una nube de miasma que enferma de gripe a los que alcanza. Después se contagian solos.", hud.unlock_plague)
			"cure":
				_cure_btn = _unlock_card(power_row, icon, t[1], Cure.PRICE,
						"Un haz de luz que cura la gripe (y deja inmune un rato) y apaga y sana a los que se queman.", hud.unlock_cure)
			"cupid", "discord", "friendship":
				var k: Charm.Kind = HUD.CHARM_ICONS[t[0]]
				_charm_btns[k] = _unlock_card(power_row, icon, t[1], Charm.KINDS[k].price, Charm.KINDS[k].shop,
						hud.unlock_charm.bind(k))
			_:
				icon.modulate = Color(1, 1, 1, 0.45)
				var b := _card(power_row, icon, t[1], -1, "Próximamente")
				b.disabled = true

func open() -> void:
	visible = true
	_sync()

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
	for kind: String in _deco_buttons:
		_deco_buttons[kind].disabled = not hud.can_afford(Decoration.price_of(kind))
	_sync_unlock(_gun_btn, Gun.unlocked, Gun.PRICE, "Desbloqueada")
	_sync_unlock(_lightning_btn, Lightning.unlocked, Lightning.PRICE, "Desbloqueado")
	_sync_unlock(_meteor_btn, Meteor.unlocked, Meteor.PRICE, "Desbloqueado")
	_sync_unlock(_tornado_btn, Tornado.unlocked, Tornado.PRICE, "Desbloqueado")
	_sync_unlock(_storm_btn, Storm.unlocked, Storm.PRICE, "Desbloqueado")
	_sync_unlock(_plague_btn, Plague.unlocked, Plague.PRICE, "Desbloqueada")
	_sync_unlock(_cure_btn, Cure.unlocked, Cure.PRICE, "Desbloqueado")
	_sync_unlock(_moon_btn, Moon.blood_unlocked, Moon.PRICE, "Desbloqueada")
	for k: Charm.Kind in _charm_btns:
		_sync_unlock(_charm_btns[k], Charm.unlocked[k], Charm.KINDS[k].price, Charm.KINDS[k].done)
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
			b.disabled = i != next or not hud.can_afford(Shark.PRICE)

## done: lo que dice una vez desbloqueado ("Desbloqueada" o "Desbloqueado", según el artículo).
func _sync_unlock(b: Button, unlocked: bool, price: int, done: String) -> void:
	b.text = done if unlocked else "Desbloquear"
	b.disabled = unlocked or not hud.can_afford(price)

# ---- Construcción ----
## Tarjeta de algo que se desbloquea una sola vez (armas, poderes, la Luna de Sangre).
func _unlock_card(parent: Control, preview: Control, title: String, price: int, tip: String, unlock: Callable) -> Button:
	var b := _card(parent, preview, title, price, "Desbloquear")
	b.tooltip_text = tip
	b.pressed.connect(func():
		unlock.call()
		_sync())
	return b

func _section(title: String) -> Label:
	var l := HUD.make_label(title, 11, HUD.C_MUTED)
	l.uppercase = true   # Mayúsculas al mostrar, así el texto sigue siendo la clave de traducción
	return l

## Tarjeta de un artículo; devuelve el botón de comprar. price < 0: sin precio.
func _card(parent: Control, preview: Control, title: String, price: int, action: String) -> Button:
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
	v.add_child(name_l)

	var price_row := HBoxContainer.new()
	price_row.name = "Price"
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 4)
	v.add_child(price_row)
	if price >= 0:
		price_row.add_child(HUD.HudIcon.make("coin", 12))
		price_row.add_child(HUD.make_label(str(price), 12, HUD.C_OFFERING))
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
		draw_set_transform(Vector2(size.x * 0.5, size.y - 6.0), 0.0, Vector2(s, s))
		Decoration.paint(self, kind, 0.5, Time.get_ticks_msec() / 1000.0)
