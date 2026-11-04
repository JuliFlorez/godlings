extends "res://tests/test_case.gd"
## Las teclas (ver Controls): que se registren una sola vez, que no se pisen, que cada poder tenga
## la suya y que los textos que las nombran se armen bien, en español y en inglés.

var _locale := ""

func before_each() -> void:
	Controls.setup()
	I18n.register()
	_locale = TranslationServer.get_locale()

func after_each() -> void:
	TranslationServer.set_locale(_locale)

func test_setup_once() -> void:
	Controls.setup()   # Otra vez: "Menú principal" recarga el mundo
	for action: StringName in Controls.KEYS:
		var want: int = Controls.KEYS[action].size() + Controls.PHYSICAL.get(action, []).size()
		check_eq(InputMap.action_get_events(action).size(), want, "las teclas de %s" % action)

func test_no_key_twice() -> void:
	var used := {}   # Tecla -> acción
	for action: StringName in Controls.KEYS:
		for k: Key in Controls.KEYS[action]:
			check(not used.has(k), "%s y %s usan la misma tecla (%s)" % [used.get(k, ""), action, OS.get_keycode_string(k)])
			used[k] = action
	for action: StringName in Controls.PHYSICAL:
		for k: Key in Controls.PHYSICAL[action]:
			check(not used.has(k), "%s y %s usan la misma tecla (%s)" % [used.get(k, ""), action, OS.get_keycode_string(k)])
			used[k] = action

func test_keys_match() -> void:
	check(_key(KEY_G).is_action_pressed(&"power_gun"), "la G saca la pistola")
	check(not _key(KEY_G).is_action_pressed(Controls.HISTORY), "y no abre el historial")
	check(_key(KEY_KP_ADD).is_action_pressed(Controls.ZOOM_IN), "el + del teclado numérico acerca")
	var quote := InputEventKey.new()
	quote.physical_keycode = KEY_QUOTELEFT
	quote.pressed = true
	check(quote.is_action_pressed(Controls.CONSOLE), "la de la izquierda del 1 abre la consola")
	check_eq(Controls.label(Controls.BACK), "Esc", "cómo se llama Esc en los textos")

func test_every_power_has_its_key() -> void:
	for p in _powers():
		check(Controls.KEYS.has(p.action()), "la tecla de " + p.id)
		p.free()

func test_texts_with_keys() -> void:
	for locale: String in ["es", "en"]:
		TranslationServer.set_locale(locale)
		for p in _powers():
			var key := p.key_label()
			var hint := p.hint_text()
			check(not hint.contains("%") and hint.contains(key), "%s, %s: la pista (%s)" % [locale, p.id, hint])
			check(p.slot_tooltip().ends_with("[%s]" % key), "%s, %s: el tooltip (%s)" % [locale, p.id, p.slot_tooltip()])
			if p.unlocked_text != "":
				var msg := p.unlocked_message()
				check(msg.ends_with(key) and not msg.contains("%"), "%s, %s: el cartel de desbloqueado (%s)" % [locale, p.id, msg])
			p.free()

## Los poderes de la barra, como los arma el mundo (sin el árbol).
func _powers() -> Array[Power]:
	var w := World.new()
	var list := w._create_powers()
	w.free()
	return list

func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	return ev
