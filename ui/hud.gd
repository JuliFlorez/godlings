extends CanvasLayer
class_name HUD
## Panel superior izquierdo: XP (progreso al próximo punto de expansión),
## Devoción, población de la isla, botones de Invocar / Expandir, Ofrendas, Tienda e Historial
## (quién se hizo amigo, enemigo o pareja de quién, ver HistoryPanel).
## Menú inferior: modo del click (arrastrar aldeanos, seleccionarlos o editar la isla) y armas
## y poderes (los que todavía no existen dicen "Próximamente").
## Toda la interfaz se construye por código. Debajo de todo va overlay: lo que se dibuja
## encima del mundo sin el tinte de la noche (el destello, el rayo y el meteorito, ver Painter).

signal spawn_pressed
signal expand_pressed
signal expansion_points_changed(points: int)
signal gun_toggled(on: bool)
signal lightning_toggled(on: bool)
signal meteor_toggled(on: bool)
signal tornado_toggled(on: bool)
signal storm_toggled(on: bool)
signal plague_toggled(on: bool)
signal cure_toggled(on: bool)
signal feed_toggled(on: bool)
signal charm_toggled(kind: Charm.Kind, on: bool)
signal decoration_chosen(kind: String)
signal shark_changed(index: int, on: bool)
signal select_mode_changed(on: bool)
signal edit_mode_changed(on: bool)
signal menu_requested

@export var energy_max: float = 100.0
@export var energy_refill_minutes: float = 5.0  # 5 min para llenarse de 0 a 100
## XP necesaria para cada punto de expansión (el último valor se repite).
@export var xp_per_point: Array[int] = [3, 5, 8, 12, 16, 20]

## Ofrendas con las que se arranca (moneda de la tienda).
@export var start_offerings: int = 20

var xp: int = 0
var energy: float = 100.0
var expansion_points: int = 0
var offerings: int = 0
## Por tiburón (Shark.MAX): si está comprado y si está prendido.
## Si lo matan de un tiro deja de estar comprado: hay que volver a comprarlo.
var shark_owned: Array[bool] = []
var shark_on: Array[bool] = []
## Modo seleccionar: el click sobre un aldeano abre su carnet en vez de agarrarlo.
var select_mode := false
## Modo editar isla: el click es para mover las decoraciones (y el derecho, para quitarlas), y
## no agarra aldeanos ni cocos. Fuera de este modo las decoraciones no se tocan (ver
## DecorPlacer): así no se mueven sin querer.
var edit_mode := false
var _points_earned: int = 0
var _refill_rate: float = 0.0  # puntos de energía por segundo
## Lo que rinde la recarga de devoción según cuánto creen en vos (ver World._devotion_rate).
var faith_rate := 1.0

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
const C_ZAP := Color(1.0, 0.86, 0.3)
const C_METEOR := Color(1.0, 0.55, 0.22)
const C_TORNADO := Color(0.78, 0.82, 0.9)
const C_RAIN := Color(0.42, 0.62, 1.0)
const C_SOON := Color(1.0, 0.8, 0.3)
const C_OFFERING := Color(1.0, 0.84, 0.34)
const C_SHOP := Color(0.46, 0.84, 0.52)
const C_PLAGUE := Color(0.55, 0.85, 0.3)
const C_CURE := Color(1.0, 0.88, 0.45)
const C_HISTORY := Color(0.74, 0.66, 1.0)
const C_FEED := Color(1.0, 0.68, 0.32)

## Menú inferior de armas y poderes: [ícono, nombre, tecla, disponible, descripción, bueno]
## Van en dos pestañas: los malos (la carita con cuernos) y los buenos (la de la aureola).
const TOOLS := [
	["gun", "Pistola", "G", true, "Sacar o guardar la pistola [G]", false],
	["lightning", "Rayo", "R", true, "Sacar o guardar el rayo [R]", false],
	["meteor", "Meteorito", "M", true, "Sacar o guardar el meteorito [M]", false],
	["tornado", "Tornado", "T", true, "Sacar o guardar el tornado [T]", false],
	["rain", "Diluvio", "D", true, "Desatar o calmar el diluvio [D]", false],
	["plague", "Peste", "P", true, "Sacar o guardar la peste [P]", false],
	["discord", "Discordia", "E", true, "Sacar o guardar la manzana de la discordia [E]", false],
	["feed", "Comida", "F", true, "Tirarles comida [F]", true],
	["cure", "Curar", "C", true, "Sacar o guardar curar [C]", true],
	["cupid", "Cupido", "A", true, "Sacar o guardar el arco de Cupido [A]", true],
	["friendship", "Amistad", "B", true, "Sacar o guardar la pelota de la amistad [B]", true],
]
## El ícono de cada Charm (Cupido, la Discordia y la Amistad).
const CHARM_ICONS := {"cupid": Charm.Kind.CUPID, "discord": Charm.Kind.DISCORD, "friendship": Charm.Kind.FRIENDSHIP}
const C_EVIL := Color(0.92, 0.3, 0.26)
const C_HOLY := Color(1.0, 0.86, 0.4)
const TAB_SIZE := 38.0
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
var _lightning_btn: Button
var _lightning_armed := false
var _meteor_btn: Button
var _meteor_armed := false
var _tornado_btn: Button
var _tornado_armed := false
var _rain_btn: Button
var _raining := false
var _rain_charge: ColorRect   # Barrita de abajo del slot: se llena mientras el diluvio se recarga
var _plague_btn: Button
var _plague_armed := false
var _cure_btn: Button
var _cure_armed := false
var _slot_plague: StyleBoxFlat
var _slot_cure: StyleBoxFlat
var _feed_btn: Button
var _feed_armed := false
var _slot_feed: StyleBoxFlat
## Cupido, la Discordia y la Amistad (ver Charm), por tipo.
var _charm_btns: Array[Button] = [null, null, null]
var _charm_armed: Array[bool] = [false, false, false]
var _slot_charms: Array[StyleBoxFlat] = []
## Pestañas de la barra de poderes: qué slots van en cada una y cuál se ve.
var _good_tab := false
var _tab_evil: Button
var _tab_holy: Button
var _tool_slots := {}         # Button -> bueno (bool)
var _slot_zap: StyleBoxFlat
var _slot_meteor: StyleBoxFlat
var _slot_tornado: StyleBoxFlat
var _slot_rain: StyleBoxFlat
## Encima del mundo y debajo de la interfaz, sin el tinte de la noche.
var overlay: Control
var _flash_rect: ColorRect
var _flash_amount := 0.0
var _slot_idle: StyleBoxFlat
var _slot_hover: StyleBoxFlat
var _slot_active: StyleBoxFlat
var _hint: Label
var _offer_value: Label
var _offer_chip: Control
var _shop_btn: Button
var _shop: Shop
var _history_btn: Button
var _history: HistoryPanel
var _placing := false
var _decor_edit := DecorPlacer.Edit.NONE
var _pause: PauseMenu
var _drag_btn: Button
var _select_btn: Button
var _edit_btn: Button
var _slot_mode: StyleBoxFlat
var _tags: Control
var _card: VillagerCard
var _hut_card: HutCard

func _ready() -> void:
	add_to_group("hud")
	Settings.init()   # Volumen e idioma guardados, antes de armar los textos
	if energy_max <= 0.0:
		energy_max = 100.0
	if energy_refill_minutes <= 0.0:
		energy_refill_minutes = 5.0
	_refill_rate = energy_max / (energy_refill_minutes * 60.0)
	energy = energy_max
	offerings = start_offerings
	shark_owned.resize(Shark.MAX)
	shark_on.resize(Shark.MAX)

	_build_ui()
	_xp_bar.value = xp
	_energy_bar.value = energy
	_refresh()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Sigue cargando aunque pierda foco

	_pause = PauseMenu.new()
	_pause.hud = self
	_pause.locale_changed.connect(_on_locale_changed)
	add_child(_pause)

	# Consola de trucos (F1): solo en el editor y en exports de debug
	if OS.is_debug_build():
		var console := DebugConsole.new()
		console.hud = self
		add_child(console)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or get_tree().paused:
		return
	match event.keycode:
		KEY_S:
			set_select_mode(not select_mode)
			get_viewport().set_input_as_handled()
		KEY_H:
			if visible:   # En el menú de inicio no (todavía no hay partida)
				toggle_history()
				get_viewport().set_input_as_handled()
		KEY_I:
			if visible:
				set_edit_mode(not edit_mode)
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Recarga suave de Devoción (no durante el menú de pausa)
	if energy < energy_max and not get_tree().paused:
		energy = min(energy_max, energy + _refill_rate * faith_rate * delta)
		_refresh()

	# Las barras siguen a su valor con suavidad
	var k := 1.0 - exp(-10.0 * delta)
	var xp_target := _xp_bar.max_value if not _can_earn_points() else float(xp)
	_xp_bar.value = lerpf(_xp_bar.value, xp_target, k)
	_energy_bar.value = lerpf(_energy_bar.value, energy, k)

	if _flash_amount > 0.0:
		_flash_amount = move_toward(_flash_amount, 0.0, 6.0 * delta)
		_flash_rect.color.a = _flash_amount

	# Diluvio recargándose: la barrita se va llenando (y el ícono, apagado)
	var charging := Storm.unlocked and Storm.charge < 1.0 and not _raining
	_rain_charge.visible = charging
	if charging:
		_rain_charge.size.x = (SLOT_SIZE.x - 16.0) * Storm.charge
	if Storm.unlocked:
		_rain_btn.get_meta("icon").modulate = Color(1, 1, 1, 0.45) if charging else Color.WHITE

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
	_armed_changed(_gun_btn, on)

func set_lightning_armed(on: bool) -> void:
	_lightning_armed = on
	_armed_changed(_lightning_btn, on)

func set_meteor_armed(on: bool) -> void:
	_meteor_armed = on
	_armed_changed(_meteor_btn, on)

func set_tornado_armed(on: bool) -> void:
	_tornado_armed = on
	_armed_changed(_tornado_btn, on)

func set_raining(on: bool) -> void:
	_raining = on
	_refresh()

func set_plague_armed(on: bool) -> void:
	_plague_armed = on
	_armed_changed(_plague_btn, on)

func set_cure_armed(on: bool) -> void:
	_cure_armed = on
	_armed_changed(_cure_btn, on)

func set_feed_armed(on: bool) -> void:
	_feed_armed = on
	_armed_changed(_feed_btn, on)

## (k va último: World lo conecta con bind, que agrega al final.)
func set_charm_armed(on: bool, k: Charm.Kind) -> void:
	_charm_armed[k] = on
	_armed_changed(_charm_btns[k], on)

## Sacado con su tecla desde la otra pestaña: la barra pasa a la suya, así se ve resaltado.
func _armed_changed(btn: Button, on: bool) -> void:
	if on:
		_show_tool(btn)
	_refresh()

## Aparece de a poco (al llegar la cámara a la isla desde el menú de inicio, ver World).
func reveal(duration: float) -> void:
	visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, duration)

## Si hay un arma o poder afuera: el click es para eso (no para agarrar aldeanos, el
## tiburón, cocos ni decoraciones).
static func aiming() -> bool:
	return Gun.armed or Lightning.armed or Meteor.armed or Tornado.armed or Plague.armed or Cure.armed \
			or Feed.armed or Charm.any_armed()

## Destello blanco sobre el mundo (no sobre la interfaz): el rayo. amount: 0..1.
func flash_screen(amount: float) -> void:
	_flash_amount = maxf(_flash_amount, amount)
	_flash_rect.color.a = _flash_amount

# ---- Ofrendas y tienda ----
func add_offerings(amount: int) -> void:
	offerings += amount
	_flash(_offer_chip)
	_refresh()

func can_afford(amount: int) -> bool:
	return offerings >= amount

func spend_offerings(amount: int) -> bool:
	if offerings < amount:
		return false
	offerings -= amount
	_refresh()
	return true

## Abre la tienda (en la pestaña tab, o en la última que se miró; ver Shop.Tab).
func open_shop(tab := -1) -> void:
	if _shop == null:
		_shop = Shop.new()
		_shop.hud = self
		_root.add_child(_shop)
	if _history:
		_history.close()
	_shop.open(tab)

## Abre o cierra el historial de quién se hizo amigo, enemigo o pareja de quién.
func toggle_history() -> void:
	if _history == null:
		_history = HistoryPanel.new()
		_history.hud = self
		_root.add_child(_history)
	if _history.visible:
		_history.close()
		return
	if _shop:
		_shop.close()
	_history.open()

func unlock_gun() -> bool:
	if Gun.unlocked or not spend_offerings(Gun.PRICE):
		return false
	Gun.unlocked = true
	popup_text("¡Pistola desbloqueada! Sacala con G", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_GUN.lightened(0.3))
	_refresh()
	return true

func unlock_lightning() -> bool:
	if Lightning.unlocked or not spend_offerings(Lightning.PRICE):
		return false
	Lightning.unlocked = true
	popup_text("¡Rayo desbloqueado! Sacalo con R", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_ZAP)
	_refresh()
	return true

func unlock_meteor() -> bool:
	if Meteor.unlocked or not spend_offerings(Meteor.PRICE):
		return false
	Meteor.unlocked = true
	popup_text("¡Meteorito desbloqueado! Sacalo con M", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_METEOR)
	_refresh()
	return true

func unlock_tornado() -> bool:
	if Tornado.unlocked or not spend_offerings(Tornado.PRICE):
		return false
	Tornado.unlocked = true
	popup_text("¡Tornado desbloqueado! Sacalo con T", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_TORNADO)
	_refresh()
	return true

func unlock_storm() -> bool:
	if Storm.unlocked or not spend_offerings(Storm.PRICE):
		return false
	Storm.unlocked = true
	popup_text("¡Diluvio desbloqueado! Desatalo con D", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_RAIN)
	_refresh()
	return true

func unlock_plague() -> bool:
	if Plague.unlocked or not spend_offerings(Plague.PRICE):
		return false
	Plague.unlocked = true
	popup_text("¡Peste desbloqueada! Sacala con P", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_PLAGUE)
	_refresh()
	return true

func unlock_cure() -> bool:
	if Cure.unlocked or not spend_offerings(Cure.PRICE):
		return false
	Cure.unlocked = true
	popup_text("¡Curar desbloqueado! Sacalo con C", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_CURE)
	_refresh()
	return true

func unlock_charm(k: Charm.Kind) -> bool:
	var info: Dictionary = Charm.KINDS[k]
	if Charm.unlocked[k] or not spend_offerings(info.price):
		return false
	Charm.unlocked[k] = true
	popup_text(info.unlocked, get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), info.color)
	_refresh()
	return true

func unlock_blood_moon() -> bool:
	if Moon.blood_unlocked or not spend_offerings(Moon.PRICE):
		return false
	Moon.blood_unlocked = true
	popup_text("¡Luna de Sangre desbloqueada! De noche, tocá la luna 5 veces", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), Color(1.0, 0.45, 0.4))
	return true

## Compra el primer tiburón que falta (se compran en orden).
func buy_shark() -> bool:
	var index := shark_owned.find(false)
	if index < 0 or not spend_offerings(Shark.PRICE):
		return false
	shark_owned[index] = true
	shark_on[index] = true
	shark_changed.emit(index, true)
	popup_text("¡Tiburón suelto en el agua!", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_DEVOTION)
	return true

func set_shark_on(index: int, on: bool) -> void:
	if index < 0 or index >= shark_on.size() or not shark_owned[index] or shark_on[index] == on:
		return
	shark_on[index] = on
	shark_changed.emit(index, on)

## Lo mataron de un tiro: hay que volver a comprarlo.
func lose_shark(index: int) -> void:
	shark_owned[index] = false
	shark_on[index] = false
	popup_text("¡Mataste al tiburón! Comprá otro en la tienda", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), C_WARN)

# ---- Modo del click: arrastrar, seleccionar (carnet) o editar la isla ----
func set_select_mode(on: bool) -> void:
	if on == select_mode:
		return
	if on:
		set_edit_mode(false)
	select_mode = on
	if not on:
		_card.close()
		_hut_card.close()
	select_mode_changed.emit(on)
	_refresh()

func set_edit_mode(on: bool) -> void:
	if on == edit_mode:
		return
	if on:
		set_select_mode(false)
	edit_mode = on
	edit_mode_changed.emit(on)
	_refresh()

## Vuelve a arrastrar aldeanos (ni seleccionar ni editar la isla).
func set_drag_mode() -> void:
	set_select_mode(false)
	set_edit_mode(false)

## Click sobre un aldeano en modo seleccionar: abre su carnet.
func select_villager(v: Villager) -> void:
	_hut_card.close()
	_card.open(v)

## Click sobre una choza en modo seleccionar: abre su cartel, para ponerle nombre.
func select_hut(h: Decoration) -> void:
	_card.close()
	_hut_card.open(h)

## La choza con el cartel abierto (o null).
func selected_hut() -> Decoration:
	if _hut_card == null or not _hut_card.visible or not is_instance_valid(_hut_card.hut):
		return null
	return _hut_card.hut

## El aldeano con el carnet abierto (o null). Si ya no está (se ahogó o se cayó al vacío) es
## null aunque el carnet todavía no se haya cerrado: se cierra recién en su _process, y los
## carteles de las cabezas (ver NameTag) preguntan antes.
func selected_villager() -> Villager:
	if _card == null or not _card.visible or not is_instance_valid(_card.villager) \
			or _card.villager.is_queued_for_deletion():
		return null
	return _card.villager

## Cartel con el nombre arriba de la cabeza (cada aldeano pide el suyo al aparecer).
func add_name_tag(v: Villager) -> void:
	var tag := NameTag.new()
	tag.villager = v
	tag.hud = self
	_tags.add_child(tag)

# ---- Partida guardada (ver World.save_game) ----
## Progreso y compras.
func save_state() -> Dictionary:
	return {
		"xp": xp,
		"energy": energy,
		"offerings": offerings,
		"expansion_points": expansion_points,
		"points_earned": _points_earned,
		"gun": Gun.unlocked,
		"lightning": Lightning.unlocked,
		"meteor": Meteor.unlocked,
		"tornado": Tornado.unlocked,
		"storm": Storm.unlocked,
		"plague": Plague.unlocked,
		"cure": Cure.unlocked,
		"charms": Charm.unlocked.duplicate(),
		"blood_moon": Moon.blood_unlocked,
		"shark_owned": shark_owned,
		"shark_on": shark_on,
	}

func load_state(d: Dictionary) -> void:
	xp = d.get("xp", xp)
	energy = clampf(d.get("energy", energy), 0.0, energy_max)
	offerings = d.get("offerings", offerings)
	expansion_points = d.get("expansion_points", expansion_points)
	_points_earned = d.get("points_earned", _points_earned)
	Gun.unlocked = d.get("gun", false)
	Lightning.unlocked = d.get("lightning", false)
	Meteor.unlocked = d.get("meteor", false)
	Tornado.unlocked = d.get("tornado", false)
	Storm.unlocked = d.get("storm", false)
	Plague.unlocked = d.get("plague", false)
	Cure.unlocked = d.get("cure", false)
	var charms: Array = d.get("charms", [])
	for k in Charm.unlocked.size():
		Charm.unlocked[k] = k < charms.size() and charms[k]
	Moon.blood_unlocked = d.get("blood_moon", false)
	var owned: Array = d.get("shark_owned", [])
	var on: Array = d.get("shark_on", [])
	for i in mini(shark_owned.size(), mini(owned.size(), on.size())):
		shark_owned[i] = owned[i]
		shark_on[i] = owned[i] and on[i]
		if shark_on[i]:
			shark_changed.emit(i, true)
	_xp_bar.value = xp       # Sin la animación de las barras llenándose
	_energy_bar.value = energy
	expansion_points_changed.emit(expansion_points)
	_refresh()

## Si Esc puede abrir el menú de pausa (no la está usando la tienda, el historial, la colocación
## de decoraciones, las armas y poderes ni el carnet o el cartel de una choza, que la usan para
## cerrar/terminar/guardar).
## (El diluvio no: se calma con D.)
## Tampoco con el click apretado: en pausa se perdería el soltado de lo que se está
## arrastrando (aldeano, tiburón, coco, sol o luna) y quedaría pegado al cursor.
func esc_is_free() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false
	return not (_shop and _shop.visible) and not (_history and _history.visible) and not _placing \
			and not aiming() and _decor_edit != DecorPlacer.Edit.MOVING and not _card.visible and not _hut_card.visible

## Al cambiar de idioma: los textos con formato se rearman y la tienda se reconstruye.
func _on_locale_changed() -> void:
	_refresh()
	if _shop:
		_shop.queue_free()
		_shop = null

## Mientras se colocan decoraciones (para la pista de abajo del panel).
func set_placing(on: bool) -> void:
	_placing = on
	_refresh()

## Mouse sobre una decoración puesta, o moviéndola (para la pista y para Esc).
func set_decor_edit(state: DecorPlacer.Edit) -> void:
	_decor_edit = state
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
	_xp_value.text = tr("Máx") if maxed else "%d / %d" % [xp, xp_needed()]
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
	_spawn_btn.text = tr("Invocar aldeano\n−%d devoción") % int(_spawn_cost)

	var island_maxed := _island_level >= _island_max
	_expand_btn.disabled = expansion_points <= 0 or island_maxed
	if island_maxed:
		_expand_btn.text = tr("Isla al máximo\n—")
	elif expansion_points == 1:
		_expand_btn.text = tr("Expandir isla\n1 punto")
	else:
		_expand_btn.text = tr("Expandir isla\n%d puntos") % expansion_points

	_offer_value.text = str(offerings)

	_sync_weapon(_gun_btn, Gun.unlocked, _gun_armed, _slot_active,
			"Sacar o guardar la pistola [G]", "Desbloqueala en la tienda (%d ofrendas)", Gun.PRICE)
	_sync_weapon(_lightning_btn, Lightning.unlocked, _lightning_armed, _slot_zap,
			"Sacar o guardar el rayo [R]", "Desbloquealo en la tienda (%d ofrendas)", Lightning.PRICE)
	_sync_weapon(_meteor_btn, Meteor.unlocked, _meteor_armed, _slot_meteor,
			"Sacar o guardar el meteorito [M]", "Desbloquealo en la tienda (%d ofrendas)", Meteor.PRICE)
	_sync_weapon(_tornado_btn, Tornado.unlocked, _tornado_armed, _slot_tornado,
			"Sacar o guardar el tornado [T]", "Desbloquealo en la tienda (%d ofrendas)", Tornado.PRICE)
	_sync_weapon(_rain_btn, Storm.unlocked, _raining, _slot_rain,
			"Desatar o calmar el diluvio [D]", "Desbloquealo en la tienda (%d ofrendas)", Storm.PRICE)
	_sync_weapon(_plague_btn, Plague.unlocked, _plague_armed, _slot_plague,
			"Sacar o guardar la peste [P]", "Desbloqueala en la tienda (%d ofrendas)", Plague.PRICE)
	_sync_weapon(_cure_btn, Cure.unlocked, _cure_armed, _slot_cure,
			"Sacar o guardar curar [C]", "Desbloquealo en la tienda (%d ofrendas)", Cure.PRICE)
	_sync_weapon(_feed_btn, true, _feed_armed, _slot_feed, "Tirarles comida [F]", "", 0)
	var charm_hint := ""
	for k: Charm.Kind in Charm.KINDS:
		var info: Dictionary = Charm.KINDS[k]
		_sync_weapon(_charm_btns[k], Charm.unlocked[k], _charm_armed[k], _slot_charms[k], info.tip, info.locked_tip, info.price)
		if _charm_armed[k]:
			charm_hint = info.hint

	var dragging := not select_mode and not edit_mode
	for b: Array in [[_drag_btn, dragging], [_select_btn, select_mode], [_edit_btn, edit_mode]]:
		b[0].add_theme_stylebox_override("normal", _slot_mode if b[1] else _slot_idle)
		b[0].add_theme_stylebox_override("hover", _slot_mode if b[1] else _slot_hover)

	if _placing:
		_hint.text = tr("Click en la isla para colocar · click derecho o Esc para terminar.")
	elif _gun_armed:
		_hint.text = tr("Click para disparar · click derecho, Esc o G para guardarla.")
	elif _lightning_armed:
		_hint.text = tr("Click para lanzar un rayo · click derecho, Esc o R para guardarlo.")
	elif _meteor_armed:
		_hint.text = tr("Click en la isla o el agua para tirar un meteorito · click derecho, Esc o M para guardarlo.")
	elif _tornado_armed:
		_hint.text = tr("Mantené apretado el click en la isla o el agua para que baje el tornado, y llevalo con el mouse · click derecho, Esc o T para guardarlo.")
	elif _plague_armed:
		_hint.text = tr("Click sobre los aldeanos para enfermarlos de gripe · click derecho, Esc o P para guardarla.")
	elif _cure_armed:
		_hint.text = tr("Click sobre un aldeano para curarlo de la gripe o de las quemaduras · click derecho, Esc o C para guardarlo.")
	elif _feed_armed:
		_hint.text = tr("Click en la isla para tirarles comida, o sobre un aldeano para dársela a él (−%d devoción) · click derecho, Esc o F para guardarla.") % int(Feed.COST)
	elif charm_hint != "":
		_hint.text = tr(charm_hint)
	elif _decor_edit == DecorPlacer.Edit.MOVING:
		_hint.text = tr("Soltala sobre la isla · click derecho o Esc para dejarla donde estaba.")
	elif _decor_edit == DecorPlacer.Edit.HOVER:
		_hint.text = tr("Arrastrá para moverla · click derecho para quitarla (devuelve la mitad).")
	elif _decor_edit == DecorPlacer.Edit.COCONUT:
		_hint.text = tr("Agarrá el coco y tiráselo en la cabeza a un aldeano.")
	elif _decor_edit == DecorPlacer.Edit.COCONUT_HELD:
		_hint.text = tr("Soltalo encima de un aldeano para partirlo.")
	elif _decor_edit == DecorPlacer.Edit.HUT:
		_hint.text = tr("Click para ponerle nombre al cartel de la choza.")
	elif select_mode:
		_hint.text = tr("Click en un aldeano para ver su carnet y ponerle nombre, o en una choza para escribir su cartel · S para volver a arrastrar.")
	elif edit_mode:
		_hint.text = tr("Arrastrá una decoración para moverla · click derecho para quitarla (devuelve la mitad) · I para volver a arrastrar aldeanos.")
	elif _raining:
		_hint.text = tr("¡Diluvio! Rescatá a los que se lleva el agua: arrastralos a lo seco · D para calmarlo.")
	elif full and not island_maxed:
		_hint.text = tr("Isla llena: sacrificá aldeanos para ganar puntos y expandirla.")
	elif not has_energy:
		_hint.text = tr("Devoción insuficiente: se recarga con el tiempo.")
	elif expansion_points > 0 and not island_maxed:
		_hint.text = tr("¡Tocá un orbe + en la isla para expandirla!")
	else:
		_hint.text = ""
	_hint.visible = _hint.text != ""

## Slot de un arma o poder de la tienda: resaltado mientras está afuera; bloqueado se ve
## apagado, con el cartel "En la tienda".
func _sync_weapon(slot: Button, unlocked: bool, out: bool, active: StyleBoxFlat, tip: String, locked_tip: String, price: int) -> void:
	slot.add_theme_stylebox_override("normal", active if out else _slot_idle)
	slot.add_theme_stylebox_override("hover", active if out else _slot_hover)
	slot.get_meta("lock").visible = not unlocked
	slot.get_meta("icon").modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.45)
	slot.tooltip_text = tr(tip) if unlocked else tr(locked_tip) % price

func _flash(c: Control) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate", Color(1.6, 1.5, 1.2), 0.12)
	tw.tween_property(c, "modulate", Color.WHITE, 0.4)

# ---- Construcción de la UI ----
func _build_ui() -> void:
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(0.93, 0.96, 1.0, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_flash_rect)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Nombres arriba de las cabezas: debajo de todos los paneles
	_tags = Control.new()
	_tags.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tags)

	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", make_box(C_PANEL, 14, C_PANEL_BORDER, 1, Vector4(16, 14, 16, 14)))
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

	var shop_row := HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 8)
	col.add_child(shop_row)
	_offer_value = _stat_chip(shop_row, "coin", "Ofrendas")
	_offer_chip = _offer_value.get_parent().get_parent()
	_shop_btn = _action_button(shop_row, C_SHOP)
	_shop_btn.text = "Tienda"
	_shop_btn.pressed.connect(open_shop)
	_history_btn = _action_button(shop_row, C_HISTORY)
	_history_btn.text = "Historial"
	_history_btn.tooltip_text = "Quién se hizo amigo, enemigo o pareja de quién [H]"
	_history_btn.pressed.connect(toggle_history)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", C_MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(268, 0)
	col.add_child(_hint)

	_build_toolbar()

	_card = VillagerCard.new()
	_card.hud = self
	_root.add_child(_card)
	_hut_card = HutCard.new()
	_hut_card.hud = self
	_root.add_child(_hut_card)

func _build_toolbar() -> void:
	_slot_idle = make_box(Color(1, 1, 1, 0.06), 12, Color(1, 1, 1, 0.10), 1)
	_slot_hover = make_box(Color(1, 1, 1, 0.13), 12, Color(1, 1, 1, 0.28), 1)
	_slot_active = make_box(Color(C_GUN, 0.38), 12, C_GUN.lightened(0.3), 2)
	_slot_mode = make_box(Color(C_DEVOTION, 0.30), 12, C_DEVOTION.lightened(0.2), 2)
	_slot_zap = make_box(Color(C_ZAP, 0.32), 12, C_ZAP.lightened(0.3), 2)
	_slot_meteor = make_box(Color(C_METEOR, 0.34), 12, C_METEOR.lightened(0.3), 2)
	_slot_tornado = make_box(Color(C_TORNADO, 0.3), 12, C_TORNADO.lightened(0.3), 2)
	_slot_rain = make_box(Color(C_RAIN, 0.34), 12, C_RAIN.lightened(0.3), 2)
	_slot_plague = make_box(Color(C_PLAGUE, 0.3), 12, C_PLAGUE.lightened(0.3), 2)
	_slot_cure = make_box(Color(C_CURE, 0.3), 12, C_CURE.lightened(0.3), 2)
	_slot_feed = make_box(Color(C_FEED, 0.32), 12, C_FEED.lightened(0.3), 2)
	for k: Charm.Kind in Charm.KINDS:
		var col: Color = Charm.KINDS[k].color
		_slot_charms.append(make_box(Color(col, 0.32), 12, col.lightened(0.3), 2))

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
	var bars := HBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_theme_constant_override("separation", 10)
	center.add_child(bars)

	# Modo del click: arrastrar aldeanos, seleccionarlos (carnet) o editar la isla
	var mode_row := _toolbar_panel(bars)
	_drag_btn = _tool_slot(mode_row, "hand", "Arrastrar", "", true, "Agarrá y tirá aldeanos [S]")
	_drag_btn.pressed.connect(set_drag_mode)
	_select_btn = _tool_slot(mode_row, "select", "Seleccionar", "S", true, "Click en un aldeano para ver su carnet, o en una choza para ponerle nombre [S]")
	_select_btn.pressed.connect(set_select_mode.bind(true))
	_edit_btn = _tool_slot(mode_row, "edit", "Editar isla", "I", true, "Mover y quitar decoraciones, sin agarrar aldeanos [I]")
	_edit_btn.pressed.connect(set_edit_mode.bind(true))
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

	for t in TOOLS:
		var slot := _tool_slot(row, t[0], t[1], t[2], t[3], t[4])
		_tool_slots[slot] = t[5]
		match t[0]:
			"gun":
				_gun_btn = _weapon_slot(slot, _slot_active, func(): return Gun.unlocked,
						func(): gun_toggled.emit(not _gun_armed))
			"lightning":
				_lightning_btn = _weapon_slot(slot, _slot_zap, func(): return Lightning.unlocked,
						func(): lightning_toggled.emit(not _lightning_armed))
			"meteor":
				_meteor_btn = _weapon_slot(slot, _slot_meteor, func(): return Meteor.unlocked,
						func(): meteor_toggled.emit(not _meteor_armed))
			"tornado":
				_tornado_btn = _weapon_slot(slot, _slot_tornado, func(): return Tornado.unlocked,
						func(): tornado_toggled.emit(not _tornado_armed))
			"rain":
				_rain_btn = _weapon_slot(slot, _slot_rain, func(): return Storm.unlocked,
						func(): storm_toggled.emit(not _raining))
				_rain_charge = ColorRect.new()
				_rain_charge.color = C_RAIN
				_rain_charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_rain_charge.position = Vector2(8.0, SLOT_SIZE.y - 6.0)
				_rain_charge.size = Vector2(0.0, 3.0)
				_rain_charge.visible = false
				slot.add_child(_rain_charge)
			"plague":
				_plague_btn = _weapon_slot(slot, _slot_plague, func(): return Plague.unlocked,
						func(): plague_toggled.emit(not _plague_armed))
			"cure":
				_cure_btn = _weapon_slot(slot, _slot_cure, func(): return Cure.unlocked,
						func(): cure_toggled.emit(not _cure_armed))
			"feed":   # Está desde el principio
				_feed_btn = _weapon_slot(slot, _slot_feed, func(): return true,
						func(): feed_toggled.emit(not _feed_armed))
			"cupid", "discord", "friendship":
				var k: Charm.Kind = CHARM_ICONS[t[0]]
				_charm_btns[k] = _weapon_slot(slot, _slot_charms[k], func(): return Charm.unlocked[k],
						func(): charm_toggled.emit(k, not _charm_armed[k]))
	# Del ancho de la pestaña más llena: así la barra no salta al cambiar de pestaña
	var most := 0
	for good: bool in [false, true]:
		most = maxi(most, _tool_slots.values().count(good))
	row.custom_minimum_size.x = most * SLOT_SIZE.x + (most - 1) * row.get_theme_constant("separation")
	_set_tab(false)

## Muestra los poderes malos o los buenos.
func _set_tab(good: bool) -> void:
	_good_tab = good
	for slot: Button in _tool_slots:
		slot.visible = _tool_slots[slot] == good
	for tab: Button in [_tab_evil, _tab_holy]:
		var on := (tab == _tab_holy) == good
		var col := C_HOLY if tab == _tab_holy else C_EVIL
		var r := int(TAB_SIZE * 0.5)
		var box := make_box(Color(col, 0.32), r, col.lightened(0.25), 2) if on \
				else make_box(Color(C_PANEL, 0.9), r, Color(1, 1, 1, 0.14), 1)
		var hover := box if on else make_box(Color(col, 0.18), r, Color(col, 0.6), 1)
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

## Arma o poder que se compra en la tienda: lo saca o lo guarda, y bloqueado lleva a la tienda
## (a la pestaña de los poderes buenos o de los malos, según cuál sea).
func _weapon_slot(slot: Button, active: StyleBoxFlat, unlocked: Callable, toggle: Callable) -> Button:
	slot.add_theme_stylebox_override("pressed", active)
	slot.set_meta("lock", _slot_badge(slot, "EN LA TIENDA", C_SHOP))
	slot.pressed.connect(func():
		if unlocked.call():
			toggle.call()
		else:
			open_shop(Shop.Tab.GOOD if _tool_slots.get(slot, false) else Shop.Tab.EVIL))
	return slot

## Panel de la barra de abajo; devuelve la fila donde van los slots.
func _toolbar_panel(parent: Control) -> HBoxContainer:
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP  # Los clicks en la barra no llegan al mundo
	bar.add_theme_stylebox_override("panel", make_box(C_PANEL, 14, C_PANEL_BORDER, 1, Vector4(8, 8, 8, 8)))
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
	b.add_theme_stylebox_override("disabled", make_box(Color(1, 1, 1, 0.03), 12, Color(1, 1, 1, 0.06), 1))
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
	var name_l := make_label(title, 11, C_TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)

	if key != "":
		var k := make_label(key, 10, C_MUTED)
		k.position = Vector2(8, 4)
		b.add_child(k)

	b.set_meta("icon", icon)
	if not available:
		b.disabled = true
		icon.modulate = Color(1, 1, 1, 0.5)
		name_l.modulate = Color(1, 1, 1, 0.55)
		_slot_badge(b, "PRÓXIMAMENTE", C_SOON)
	return b

## Cartelito ("Próximamente", "En la tienda") pegado sobre el borde superior del slot.
func _slot_badge(slot: Control, text: String, color: Color) -> Control:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", make_box(color, 4, color.darkened(0.4), 1, Vector4(4, 0, 4, 0)))
	badge.add_child(make_label(text, 8, Color(0.18, 0.11, 0.02)))
	slot.add_child(badge)
	var sz := badge.get_combined_minimum_size()
	badge.size = sz
	badge.pivot_offset = sz * 0.5
	badge.position = Vector2(SLOT_SIZE.x * 0.5 - sz.x * 0.5, -sz.y * 0.55)
	badge.rotation = deg_to_rad(-6.0)
	return badge

func _bar_row(parent: Control, icon: String, title: String, color: Color) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	head.add_child(HudIcon.make(icon, 16))
	var name_l := make_label(title, 14, C_TEXT)
	head.add_child(name_l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var value_l := make_label("", 13, C_MUTED)
	head.add_child(value_l)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", make_box(C_TRACK, 6))
	bar.add_theme_stylebox_override("fill", make_box(color, 6, color.lightened(0.35), 1))
	box.add_child(bar)
	return [bar, value_l]

func _stat_chip(parent: Control, icon: String, title: String) -> Label:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", make_box(Color(1, 1, 1, 0.06), 9, Color(0, 0, 0, 0), 0, Vector4(8, 6, 8, 6)))
	parent.add_child(chip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	chip.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	v.add_child(top)
	top.add_child(HudIcon.make(icon, 14))
	top.add_child(make_label(title, 11, C_MUTED))
	var value := make_label("", 16, C_TEXT)
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
	b.add_theme_stylebox_override("normal", make_box(color, 10, color.lightened(0.3), 1))
	b.add_theme_stylebox_override("hover", make_box(color.lightened(0.15), 10, color.lightened(0.5), 1))
	b.add_theme_stylebox_override("pressed", make_box(color.darkened(0.15), 10, color.darkened(0.3), 1))
	b.add_theme_stylebox_override("disabled", make_box(Color(1, 1, 1, 0.07), 10, Color(1, 1, 1, 0.08), 1))
	parent.add_child(b)
	return b

static func make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Botón de los menús (pausa, opciones, inicio).
static func make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", make_box(color, 8, color.lightened(0.25), 1))
	b.add_theme_stylebox_override("hover", make_box(color.lightened(0.15), 8, color.lightened(0.45), 1))
	b.add_theme_stylebox_override("pressed", make_box(color.darkened(0.15), 8, color.darkened(0.3), 1))
	return b

static func make_box(bg: Color, radius: int, border := Color(0, 0, 0, 0), border_w := 0, pad := Vector4.ZERO) -> StyleBoxFlat:
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

## Lienzo en overlay que pide a paint(lienzo) que lo dibuje cada cuadro (ver Lightning y Meteor).
class Painter extends Node2D:
	var paint: Callable

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)

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
			"coin":
				draw_circle(c, s * 0.48, HUD.C_OFFERING.darkened(0.25), true, -1.0, true)
				draw_circle(c, s * 0.38, HUD.C_OFFERING, true, -1.0, true)
				draw_arc(c, s * 0.24, 0.0, TAU, 16, HUD.C_OFFERING.darkened(0.3), maxf(1.0, s * 0.08), true)
			"gun":
				var grip := _pts([0.16, 0.48, 0.42, 0.48, 0.36, 0.9, 0.08, 0.86])
				draw_colored_polygon(grip, HUD.C_GUN)
				draw_arc(Vector2(0.5, 0.52) * s, s * 0.1, 0.0, PI, 8, Color(0.75, 0.78, 0.85), 2.0, true)
				draw_rect(Rect2(Vector2(0.06, 0.26) * s, Vector2(0.88, 0.22) * s), Color(0.75, 0.78, 0.85))
				draw_rect(Rect2(Vector2(0.84, 0.2) * s, Vector2(0.06, 0.06) * s), Color(0.75, 0.78, 0.85))
			"shark":
				draw_colored_polygon(_pts([0.18, 0.74, 0.38, 0.1, 0.86, 0.74]), Color(0.58, 0.64, 0.74))
				draw_line(Vector2(0.04, 0.76) * s, Vector2(0.96, 0.76) * s, HUD.C_DEVOTION, 2.5, true)
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
					draw_line(Vector2(x, s * 0.72), Vector2(x - s * 0.08, s * 0.96), HUD.C_DEVOTION, 2.5, true)
			"plague":
				# Calavera en una nube verde
				var green := HUD.C_PLAGUE
				for p: Vector3 in [Vector3(0.28, 0.62, 0.2), Vector3(0.72, 0.62, 0.2), Vector3(0.5, 0.7, 0.22)]:
					draw_circle(Vector2(p.x, p.y) * s, p.z * s, Color(green, 0.45), true, -1.0, true)
				var bone := Color(0.92, 0.95, 0.85)
				draw_circle(Vector2(0.5, 0.4) * s, s * 0.26, bone, true, -1.0, true)
				draw_rect(Rect2(Vector2(0.36, 0.52) * s, Vector2(0.28, 0.18) * s), bone)
				for side: float in [-1.0, 1.0]:
					draw_circle(Vector2(0.5 + side * 0.1, 0.42) * s, s * 0.07, Color(0.2, 0.32, 0.1), true, -1.0, true)
				draw_line(Vector2(0.45, 0.6) * s, Vector2(0.45, 0.7) * s, Color(0.2, 0.32, 0.1), maxf(1.0, s * 0.04), true)
				draw_line(Vector2(0.55, 0.6) * s, Vector2(0.55, 0.7) * s, Color(0.2, 0.32, 0.1), maxf(1.0, s * 0.04), true)
			"evil":
				# Carita roja con cuernitos (la pestaña de los poderes malos)
				var face := Vector2(0.5, 0.58) * s
				var horn := HUD.C_EVIL.darkened(0.35)
				for side: float in [-1.0, 1.0]:
					draw_colored_polygon(_pts([0.5 + side * 0.14, 0.34, 0.5 + side * 0.32, 0.4,
							0.5 + side * 0.36, 0.04]), horn)
				draw_circle(face, s * 0.36, HUD.C_EVIL, true, -1.0, true)
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
				draw_arc(Vector2.ZERO, s * 0.3, 0.0, TAU, 24, HUD.C_HOLY, maxf(2.0, s * 0.16), true)
				draw_set_transform(Vector2.ZERO)
				var ink := Color(0.35, 0.26, 0.12)
				for side: float in [-1.0, 1.0]:
					# Ojitos cerrados, contentos
					draw_arc(face + Vector2(side * 0.13, -0.02) * s, s * 0.06, PI, TAU, 6, ink, maxf(1.2, s * 0.05), true)
				draw_arc(face + Vector2(0, 0.06) * s, s * 0.13, 0.15 * PI, 0.85 * PI, 8, ink, maxf(1.2, s * 0.05), true)
			"cupid", "discord", "friendship":
				Charm.paint_icon(self, HUD.CHARM_ICONS[kind], s)
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
				draw_circle(c, s * 0.46, Color(HUD.C_CURE, 0.25), true, -1.0, true)
				draw_rect(Rect2(Vector2(0.39, 0.14) * s, Vector2(0.22, 0.72) * s), HUD.C_CURE)
				draw_rect(Rect2(Vector2(0.14, 0.39) * s, Vector2(0.72, 0.22) * s), HUD.C_CURE)
				draw_rect(Rect2(Vector2(0.44, 0.19) * s, Vector2(0.06, 0.62) * s), Color(1, 1, 0.92, 0.7))

	## Polígono a partir de coordenadas normalizadas (0..1) del ícono.
	func _pts(xy: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(0, xy.size(), 2):
			out.append(Vector2(xy[i], xy[i + 1]) * size.x)
		return out
