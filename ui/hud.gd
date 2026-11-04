extends CanvasLayer
class_name HUD
## La interfaz del juego (grupo "hud"), toda armada por código: arriba, TopBar (el día, la XP, la
## isla, la tienda y el historial, el + de invocar con la devoción, las monedas y la pista de lo
## que conviene hacer); abajo, PowerBar (el modo del click y los poderes). Además abre los paneles
## (la tienda, el historial, el carnet, el cartel de la choza, el árbol y la pausa), lleva el modo
## del click (arrastrar, seleccionar o editar la isla), los carteles flotantes y los nombres arriba
## de las cabezas. Muestra la partida (ver Game) pero no guarda nada.
## Debajo de todo va overlay: lo que se dibuja encima del mundo sin el tinte de la noche (el
## destello, el rayo y el meteorito, ver Painter).

signal spawn_pressed
signal expand_pressed
signal decoration_chosen(kind: String)
signal select_mode_changed(on: bool)
signal edit_mode_changed(on: bool)
signal menu_requested

## Modo seleccionar: el click sobre un aldeano abre su carnet en vez de agarrarlo.
var select_mode := false
## Modo editar isla: el click es para mover las decoraciones (y el derecho, para quitarlas), y
## no agarra aldeanos ni cocos. Fuera de este modo las decoraciones no se tocan (ver
## DecorPlacer): así no se mueven sin querer.
var edit_mode := false

var _population := -1
var _capacity := -1
var _spawn_cost := 10.0

var _root: Control
var _top: TopBar
var _bar: PowerBar
## Los poderes de la barra (ver set_powers), en su orden.
var powers: Array[Power] = []
## Encima del mundo y debajo de la interfaz, sin el tinte de la noche.
var overlay: Control
var _flash_rect: ColorRect
var _flash_amount := 0.0
## Cada cuántos segundos rezan (ver World.worship_interval; también para el carnet).
var tribute_interval := 10.0
var _shop: Shop
var _history: HistoryPanel
var _placing := false
var _decor_edit := DecorPlacer.Edit.NONE
var _pause: PauseMenu
var _tags: Control
var _card: VillagerCard
var _hut_card: HutCard
var _family_tree: FamilyTree

func _ready() -> void:
	add_to_group("hud")
	Settings.init()   # Volumen e idioma guardados, antes de armar los textos
	_build_ui()
	# La partida (ver Game): muestra lo que cambia, y los carteles
	Game.events.changed.connect(_refresh)
	Game.events.point_earned.connect(_on_point_earned)
	Game.events.said.connect(popup_text)
	_refresh()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Sigue cargando aunque pierda foco

	_pause = PauseMenu.new()
	_pause.hud = self
	_pause.locale_changed.connect(_on_locale_changed)
	add_child(_pause)

	# Consola de trucos (F1): solo en el editor y en exports de debug
	if OS.is_debug_build():
		add_child(DebugConsole.new())

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
	if _flash_amount > 0.0:
		_flash_amount = move_toward(_flash_amount, 0.0, 6.0 * delta)
		_flash_rect.color.a = _flash_amount

# ---- API para otros scripts ----
## Ganaste un punto para agrandar la isla (ver Game.add_xp): la barra vuelve a empezar.
func _on_point_earned() -> void:
	_top.point_earned()
	popup_text("+1 punto de expansión", get_viewport().get_visible_rect().size * Vector2(0.5, 0.42), UiStyle.C_EXPAND)

func set_population(count: int, capacity: int) -> void:
	if count == _population and capacity == _capacity:
		return
	_population = count
	_capacity = capacity
	_refresh()

func set_spawn_cost(cost: float) -> void:
	_spawn_cost = cost
	_refresh()

## Los poderes de la barra (ver World._create_powers), en su orden: un slot para cada uno (ver
## PowerBar.set_powers). Cuando se saca o se guarda uno, cambia la pista.
func set_powers(list: Array[Power]) -> void:
	powers = list
	_bar.set_powers(list)
	for power in list:
		power.armed_changed.connect(func(_on: bool): _refresh())
	_refresh()

## Aparece de a poco (al llegar la cámara a la isla desde el menú de inicio, ver World).
func reveal(duration: float) -> void:
	visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, duration)

## Destello blanco sobre el mundo (no sobre la interfaz): el rayo. amount: 0..1.
func flash_screen(amount: float) -> void:
	_flash_amount = maxf(_flash_amount, amount)
	_flash_rect.color.a = _flash_amount

# ---- Ofrendas, sacrificios y tienda ----
## Lo que te dejan rezando todos juntos cada interval segundos (ver World._prayers): va abajo
## de las ofrendas (ver TopBar.set_tribute).
func set_tribute(amount: float, interval: float) -> void:
	tribute_interval = interval
	_top.set_tribute(amount, interval)

## "+1,5 cada 10 s": lo que dejan (amount) cada vez que rezan (cada interval segundos).
static func per_prayer(amount: float, interval: float) -> String:
	return TranslationServer.translate("+%s cada %d s") % [decimal(amount), int(interval)]

## Un número con un decimal ("1,5"; en inglés, "1.5").
static func decimal(x: float) -> String:
	var s := "%.1f" % x
	return s.replace(".", ",") if TranslationServer.get_locale().begins_with("es") else s

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

## Abre el árbol genealógico de la familia del aldeano con ese carnet (ver FamilyTree).
func open_family_tree(id: int) -> void:
	if _family_tree == null:
		_family_tree = FamilyTree.new()
		_family_tree.hud = self
		_root.add_child(_family_tree)
	_card.close()
	_hut_card.close()
	_family_tree.open(id)

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
			and not (_family_tree and _family_tree.visible) \
			and not Power.aiming() and _decor_edit != DecorPlacer.Edit.MOVING and not _card.visible and not _hut_card.visible

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
func popup_text(text: String, screen_pos: Vector2, color: Color = UiStyle.C_TEXT) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	UiStyle.outline(l, 6)
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
## Vuelve a mostrar todo (cambió la partida, el modo del click, un poder que se sacó...).
func _refresh() -> void:
	if _root == null:
		return
	_top.refresh(_population, _capacity, _spawn_cost)
	_bar.refresh()
	_top.set_hint(_hint_text())

## La pista de abajo del panel de la izquierda: lo que conviene hacer ahora (la del poder que se
## está apuntando, la del modo del click, por qué no se puede invocar...), o nada.
func _hint_text() -> String:
	var aimed_hint := ""   # La pista del que se está apuntando...
	var out_hint := ""     # ...y la del que está afuera sin apuntar (el diluvio: va más abajo)
	for power in powers:
		if power.armed:
			if power.aims:
				aimed_hint = power.hint_text()
			else:
				out_hint = power.hint_text()
	var full := _capacity >= 0 and _population >= _capacity
	var island_maxed := Game.island_level >= Game.island_max
	if _placing:
		return tr("Click en la isla para colocar · click derecho o Esc para terminar.")
	if aimed_hint != "":
		return aimed_hint
	match _decor_edit:
		DecorPlacer.Edit.MOVING:
			return tr("Soltala sobre la isla · click derecho o Esc para dejarla donde estaba.")
		DecorPlacer.Edit.HOVER:
			return tr("Arrastrá para moverla · click derecho para quitarla (devuelve la mitad).")
		DecorPlacer.Edit.COCONUT:
			return tr("Agarrá el coco y tiráselo en la cabeza a un aldeano.")
		DecorPlacer.Edit.COCONUT_HELD:
			return tr("Soltalo encima de un aldeano para partirlo.")
		DecorPlacer.Edit.HUT:
			return tr("Click para ponerle nombre al cartel de la choza.")
	if select_mode:
		return tr("Click en un aldeano para ver su carnet y ponerle nombre, o en una choza para escribir su cartel · S para volver a arrastrar.")
	if edit_mode:
		return tr("Arrastrá una decoración para moverla · click derecho para quitarla (devuelve la mitad) · I para volver a arrastrar aldeanos.")
	if out_hint != "":
		return out_hint
	if full and not island_maxed:
		return tr("Isla llena: sacrificá aldeanos para ganar puntos y expandirla.")
	if Game.devotion < _spawn_cost:
		return tr("Devoción insuficiente: se recarga con el tiempo.")
	if Game.expansion_points > 0 and not island_maxed:
		return tr("¡Tocá un orbe + en la isla para expandirla!")
	return ""

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

	_top = TopBar.new()   # Arriba: el panel de la izquierda, el + de invocar y las monedas
	_top.hud = self
	_root.add_child(_top)
	_bar = PowerBar.new()   # Abajo: el modo del click y los poderes
	_bar.hud = self
	_root.add_child(_bar)

	_card = VillagerCard.new()
	_card.hud = self
	_root.add_child(_card)
	_hut_card = HutCard.new()
	_hut_card.hud = self
	_root.add_child(_hut_card)
