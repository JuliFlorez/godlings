extends Control
class_name DebugConsole
## Consola de trucos para probar el juego (F1 o la tecla de arriba del Tab para abrir/cerrar).
## Solo existe en builds de debug (el editor y los exports de debug), nunca en un release.
## Comandos: escribí "ayuda" para ver la lista.

var hud: HUD
var _log: RichTextLabel
var _line: LineEdit
var _history: Array[String] = []
var _hist_i := 0

const COMMANDS := [
	["ayuda / help", "Esta lista"],
	["dinero / money [n]", "Suma ofrendas (por defecto 99999)"],
	["devocion / devotion", "Llena la devoción"],
	["infinito / infinite", "Prende/apaga ofrendas y devoción infinitas"],
	["puntos / points [n]", "Suma puntos de expansión (por defecto los que faltan para el máximo)"],
	["isla / island [n]", "Pone la isla en ese nivel (por defecto el máximo)"],
	["aldeanos / villagers [n]", "Invoca aldeanos gratis (por defecto hasta llenar la isla)"],
	["gripe / flu [n]", "Contagia de gripe a n aldeanos sanos (por defecto 1)"],
	["charlas / chats [n]", "Simula n charlas al azar (por defecto 30) y les da ganas de charlar a todos"],
	["fe / faith [n]", "Pone la fe de todos en n, de 0 a 100 (por defecto 100)"],
	["miedo / fear [n]", "Pone el miedo de todos en n, de 0 a 100 (por defecto 100)"],
	["hambre / hunger [n]", "Pone el hambre de todos en n, de 0 a 100 (por defecto 80)"],
	["edad / age [n]", "Pone a todos en n días (por defecto 7, ya viejos; con 10 se mueren de viejos)"],
	["desbloquear / unlock", "Pistola, rayo, meteorito, tornado, diluvio, peste, discordia, curar, Cupido, amistad, Luna de Sangre y todos los tiburones"],
	["todo / all", "Todo lo anterior junto"],
	["limpiar / clear", "Borra la consola"],
]

var infinite := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = 300
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", HUD.make_box(Color(0.03, 0.05, 0.09, 0.94), 0, HUD.C_PANEL_BORDER, 1, Vector4(14, 10, 14, 10)))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 14)
	col.add_child(_log)

	_line = LineEdit.new()
	_line.add_theme_font_size_override("font_size", 15)
	_line.text_submitted.connect(_on_submit)
	_line.gui_input.connect(_on_input_key)
	col.add_child(_line)

	_print("[color=#ffd75a]%s[/color] — %s" % [tr("Consola de trucos"), tr("escribí [b]ayuda[/b] o [b]help[/b]. F1 para cerrar.")])

func _process(_dt: float) -> void:
	if infinite and hud:
		hud.offerings = maxi(hud.offerings, 99999)
		hud.energy = hud.energy_max
		hud._refresh()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F1 or event.physical_keycode == KEY_QUOTELEFT:
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	visible = not visible
	if visible:
		_line.placeholder_text = tr("Comando (ayuda para ver la lista)")   # Al abrir: sigue el idioma actual
		_line.clear()
		_line.grab_focus()
	else:
		_line.release_focus()

## Flechas arriba/abajo: comandos anteriores.
func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or _history.is_empty():
		return
	if event.keycode == KEY_UP:
		_hist_i = maxi(_hist_i - 1, 0)
	elif event.keycode == KEY_DOWN:
		_hist_i = mini(_hist_i + 1, _history.size())
	else:
		return
	_line.text = _history[_hist_i] if _hist_i < _history.size() else ""
	_line.caret_column = _line.text.length()
	_line.accept_event()

func _on_submit(text: String) -> void:
	_line.clear()
	text = text.strip_edges()
	if text == "":
		return
	_history.append(text)
	_hist_i = _history.size()
	_print("[color=#8a93a8]> %s[/color]" % text)
	run(text)

func _print(line: String) -> void:
	_log.append_text(line + "\n")

func _ok(line: String) -> void:
	_print("[color=#76d684]%s[/color]" % line)

## Ejecuta un comando (también se puede llamar desde otros scripts o tests).
func run(text: String) -> void:
	var parts := text.to_lower().split(" ", false)
	var cmd := parts[0]
	var arg := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else -1
	var world = get_tree().current_scene   # world.gd (sin class_name)
	match cmd:
		"ayuda", "help", "?":
			for c: Array in COMMANDS:
				_print("  [b]%s[/b] — %s" % [c[0], tr(c[1])])
		"dinero", "money", "ofrendas":
			var n := arg if arg > 0 else 99999
			hud.add_offerings(n)
			_ok(tr("+%d ofrendas (total %d)") % [n, hud.offerings])
		"devocion", "devoción", "devotion", "energia", "energy":
			hud.energy = hud.energy_max
			hud._refresh()
			_ok(tr("Devoción llena"))
		"infinito", "infinite", "dios", "god":
			infinite = not infinite
			_ok(tr("Ofrendas y devoción infinitas: %s") % tr("SÍ" if infinite else "NO"))
		"puntos", "points", "xp":
			var missing: int = world.max_level() - world.island_level - hud.expansion_points
			var n := arg if arg > 0 else maxi(missing, 1)
			hud.expansion_points += n
			hud.expansion_points_changed.emit(hud.expansion_points)
			hud._refresh()
			_ok(tr("+%d puntos de expansión") % n)
		"isla", "island":
			var lvl: int = world.max_level() if arg < 0 else arg - 1
			world.set_island_level(lvl)
			_ok(tr("Isla en nivel %d / %d") % [world.island_level + 1, world.max_level() + 1])
		"aldeanos", "villagers":
			var room: int = world.capacity() - world.alive_villagers()
			var n := mini(arg if arg > 0 else room, room)
			world.debug_spawn_villagers(n)
			_ok(tr("+%d aldeanos") % n)
		"gripe", "flu", "enfermar", "infect":
			_ok(tr("%d aldeanos con gripe") % world.debug_infect(arg if arg > 0 else 1))
		"charlas", "chats", "charlar", "chat":
			_ok(tr("%d charlas: %d amistades, %d enemistades y %d parejas") % _simulate_chats(arg if arg > 0 else 30))
		"fe", "faith":
			var n := clampi(arg if arg >= 0 else 100, 0, 100)
			_ok(tr("%d aldeanos con fe %d") % [_set_all("faith", n), n])
		"miedo", "fear":
			var n := clampi(arg if arg >= 0 else 100, 0, 100)
			_ok(tr("%d aldeanos con miedo %d") % [_set_all("fear", n), n])
		"hambre", "hunger":
			var n := clampi(arg if arg >= 0 else 80, 0, 100)
			_ok(tr("%d aldeanos con hambre %d") % [_set_all("hunger", n), n])
		"edad", "age", "días", "años", "envejecer":
			var n := arg if arg >= 0 else int(Villager.ELDER_AGE)
			var count := 0
			for node in get_tree().get_nodes_in_group("villager"):
				var v := node as Villager
				if v and not v.dead and not v.eaten and not v.is_queued_for_deletion():
					v.set_age(n)
					count += 1
			_ok(tr("%d aldeanos con %d días") % [count, n])
		"desbloquear", "unlock":
			_unlock_all()
		"todo", "all":
			run("dinero")
			run("isla")
			run("aldeanos")
			run("devocion")
			_unlock_all()
		"limpiar", "clear", "cls":
			_log.clear()
		_:
			_print("[color=#ff8c73]%s[/color]" % (tr("No conozco \"%s\". Escribí ayuda (o help).") % cmd))

## A todos los vivos les pone value en prop (faith o fear). Devuelve a cuántos.
func _set_all(prop: String, value: float) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and not v.dead and not v.eaten and not v.is_queued_for_deletion():
			v.set(prop, value)
			n += 1
	return n

## n charlas entre dos aldeanos vivos al azar, de una (sin que se junten). Después todos
## quedan con ganas de charlar. Devuelve [charlas, amistades, enemistades, parejas] que
## hay ahora.
func _simulate_chats(n: int) -> Array:
	var alive: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and not v.dead and not v.eaten and not v.is_queued_for_deletion():
			alive.append(v)
			v._chat_cool = 0.0
	if alive.size() < 2:
		return [0, 0, 0, 0]
	for i in n:
		alive.shuffle()
		Relations.change(alive[0], alive[1], Relations.chat_delta(alive[0], alive[1]))
	var count := {Relations.Kind.FRIEND: 0, Relations.Kind.ENEMY: 0, Relations.Kind.COUPLE: 0}
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var k := Relations.kind(alive[i], alive[j])
			if count.has(k):
				count[k] += 1
	return [n, count[Relations.Kind.FRIEND], count[Relations.Kind.ENEMY], count[Relations.Kind.COUPLE]]

func _unlock_all() -> void:
	Gun.unlocked = true
	Lightning.unlocked = true
	Meteor.unlocked = true
	Tornado.unlocked = true
	Storm.unlocked = true
	Plague.unlocked = true
	Cure.unlocked = true
	for k in Charm.unlocked.size():
		Charm.unlocked[k] = true
	Moon.blood_unlocked = true
	for i in Shark.MAX:
		if not hud.shark_owned[i]:
			hud.shark_owned[i] = true
			hud.shark_on[i] = true
			hud.shark_changed.emit(i, true)
	hud._refresh()
	_ok(tr("Desbloqueado: pistola, rayo, meteorito, tornado, diluvio, peste, discordia, curar, Cupido, amistad, Luna de Sangre y %d tiburones") % Shark.MAX)
