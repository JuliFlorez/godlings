extends Node2D
class_name Power
## Un arma o poder de la barra de abajo (ver HUD): se desbloquea en la tienda (ver Shop) y se saca o
## se guarda con su tecla o tocando su slot. Mientras está afuera el click es para él (ver aiming):
## el izquierdo lo usa y el derecho (o Esc) lo guarda, y sacarlo guarda a los demás (ver World). El
## diluvio no se apunta (aims = false): su tecla lo desata o lo calma, y ni guarda a los demás ni
## ellos a él.
##
## Cada poder es una clase hija que en _init() dice cómo es (su id, su tecla, lo que cuesta, sus
## textos...) y hace lo suyo en _use (el click), _on_armed (al sacarlo o guardarlo) y, si hace falta,
## _can_arm. World los crea en el orden de la barra (ver World._create_powers): un poder nuevo va
## ahí, con su ícono en HUD.HudIcon y sus textos en I18n.EN.

signal armed_changed(on: bool)

const GROUP := "power"

# ---- Cómo es (lo dice cada poder en su _init) ----
## Con lo que se guarda en la partida (ver Game.save_state).
var id := ""
## El dibujo de su slot y de su tarjeta en la tienda (ver HUD.HudIcon); si no dice, el de su id.
var icon := ""
## Su nombre en la barra y en la tienda.
var title := ""
## La tecla que lo saca y lo guarda.
var key := KEY_NONE
## Bueno (la pestaña de la aureola) o malo (la de los cuernos; los malos cuestan también sacrificios).
var good := false
## Su color: el del slot mientras está afuera y el del cartel al desbloquearlo.
var accent := Color.WHITE
## Lo que cuesta en la tienda: ofrendas y, si es malo, sacrificios (ver Game.buy)...
var price := 0
var sacrifices := 0
## ...y la devoción que gasta cada vez que se usa (la dice su pista, ver hint_text).
var cost := 0.0
## Está desde el principio, no se compra (la comida).
var always := false
## Mientras está afuera, el click es para él.
var aims := true
## Con él afuera, los que te temen se agachan (ver Villager; con la comida, no).
var scares := true
## Sus textos, en español (son las claves de traducción, ver I18n): el tooltip del slot y el de
## bloqueado (con lo que cuesta: "...(%d ofrendas)" o, si es malo, "...(%d ofrendas y %d
## sacrificios)"), el cartel si lo querés sacar sin haberlo comprado y el de cuando se compra, lo que
## dice la tienda una vez comprado ("Desbloqueado" o "Desbloqueada") y su descripción, y la pista de
## abajo mientras está afuera (con un %d si gasta devoción, ver cost).
var tooltip := ""
var locked_tooltip := ""
var need := ""
var unlocked_text := ""
var done := ""
var shop := ""
var hint := ""

# ---- Cómo está (se guarda con la partida, ver Game.save_state) ----
var unlocked := false
var armed := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		add_to_group(GROUP)   # Acá y no en _ready, así no depende de que los hijos llamen a super()

## Lo saca (si está comprado y se puede) o lo guarda.
func set_armed(on: bool) -> void:
	if on and not unlocked:
		Game.announce(need, HUD.C_WARN)
		return
	if on == armed or (on and not _can_arm()):
		return
	armed = on
	_on_armed(on)
	armed_changed.emit(on)   # Antes del cursor: al sacarlo se guardan los demás, que lo dejan en la flecha
	if aims:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == key:
			set_armed(not armed)
			get_viewport().set_input_as_handled()
		elif aims and armed and event.keycode == KEY_ESCAPE:
			set_armed(false)
			get_viewport().set_input_as_handled()
		return
	if not (aims and armed and event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_use(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		set_armed(false)
		get_viewport().set_input_as_handled()

## El dibujo de su slot (ver icon).
func icon_kind() -> String:
	return icon if icon != "" else id

## La pista de abajo mientras está afuera (con lo que gasta cada vez, si gasta).
func hint_text() -> String:
	return tr(hint) % int(cost) if cost > 0.0 else tr(hint)

## Lo que le falta para poder usarlo otra vez (1: listo; mientras tanto el slot tiene una barrita
## que se va llenando, ver HUD).
func recharge() -> float:
	return 1.0

## El color del cartel al desbloquearlo.
func unlock_color() -> Color:
	return accent

# ---- Lo de cada poder ----
## Click izquierdo con el poder afuera, en at (en el mundo).
func _use(_at: Vector2) -> void:
	pass

## Al sacarlo (on) o al guardarlo, antes de avisar (armed_changed).
func _on_armed(_on: bool) -> void:
	pass

## Si se puede sacar ahora; si no, que diga por qué (el diluvio, mientras se recarga).
func _can_arm() -> bool:
	return true

# ---- Todos ----
## Los que hay, en el orden de la barra (ver World._create_powers).
static func all() -> Array[Power]:
	var list: Array[Power] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		list.assign(tree.get_nodes_in_group(GROUP))
	return list

## El que está afuera apuntando (o null): mientras tanto el click es para él, no para agarrar
## aldeanos, el tiburón, cocos ni decoraciones.
static func armed_power() -> Power:
	for p in all():
		if p.aims and p.armed:
			return p
	return null

static func aiming() -> bool:
	return armed_power() != null

## Si hay uno afuera que asusta (ver scares).
static func threat() -> bool:
	var p := armed_power()
	return p != null and p.scares
