class_name Controls
## Todas las teclas del juego, en un solo lugar (KEYS): cada acción con sus teclas. setup() las
## registra en el InputMap por código (no en project.godot: el editor lo vuelve a guardar con lo que
## tenía), y cada uno pregunta por la suya: event.is_action_pressed(Controls.HISTORY). La de cada
## poder es "power_" + su id (ver Power.action).
## Los textos que nombran una tecla (los tooltips, las pistas, los avisos) la sacan de acá (ver
## label y tip): para cambiar una tecla alcanza con cambiarla en KEYS. La tabla de teclas del README
## sale del comentario de cada una (tools/controls_doc.py la arma, y la CI se fija que esté al día),
## y tests/test_controls.gd se fija que no se pisen.

const SELECT_MODE := &"select_mode"
const EDIT_ISLAND := &"edit_island"
const HISTORY := &"history"
const BACK := &"back"
const CONSOLE := &"console"
const ZOOM_IN := &"zoom_in"
const ZOOM_OUT := &"zoom_out"
const ZOOM_RESET := &"zoom_reset"
const PAN_LEFT := &"pan_left"
const PAN_RIGHT := &"pan_right"
const PAN_UP := &"pan_up"
const PAN_DOWN := &"pan_down"
const PAN := [PAN_LEFT, PAN_RIGHT, PAN_UP, PAN_DOWN]   # Las que mueven la cámara

## Acción -> sus teclas (la primera es la que nombran los textos). Una por línea, con lo que hace en
## el comentario: es lo que dice la tabla de teclas del README (ver tools/controls_doc.py).
const KEYS := {
	&"power_gun": [KEY_G],                          # Sacar o guardar la pistola
	&"power_lightning": [KEY_R],                    # Sacar o guardar el rayo
	&"power_meteor": [KEY_M],                       # Sacar o guardar el meteorito
	&"power_tornado": [KEY_T],                      # Sacar o guardar el tornado
	&"power_storm": [KEY_D],                        # Desatar o calmar el diluvio
	&"power_plague": [KEY_P],                       # Sacar o guardar la peste
	&"power_spore": [KEY_Z],                        # Sacar o guardar la espora zombi
	&"power_discord": [KEY_E],                      # Sacar o guardar la manzana de la discordia
	&"power_feed": [KEY_F],                         # Sacar o guardar la comida
	&"power_cure": [KEY_C],                         # Sacar o guardar curar
	&"power_vaccine": [KEY_V],                      # Sacar o guardar la vacuna
	&"power_shield": [KEY_O],                       # Sacar o guardar el escudo
	&"power_resurrect": [KEY_L],                    # Sacar o guardar la resurrección
	&"power_cupid": [KEY_A],                        # Sacar o guardar el arco de Cupido
	&"power_friendship": [KEY_B],                   # Sacar o guardar la pelota de la amistad
	&"select_mode": [KEY_S],                        # Arrastrar o seleccionar: el click abre el carnet de un aldeano o el cartel de una choza
	&"edit_island": [KEY_I],                        # Editar la isla: mover y quitar decoraciones
	&"history": [KEY_H],                            # Abrir o cerrar el historial
	&"back": [KEY_ESCAPE],                          # Guardar el poder, cerrar lo que esté abierto o abrir el menú de pausa
	&"console": [KEY_F1],                           # Consola de trucos (solo en el editor y en exports de debug)
	&"zoom_in": [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD],  # Acercar
	&"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],      # Alejar
	&"zoom_reset": [KEY_0, KEY_KP_0],               # Volver al tamaño normal y al centro
	&"pan_left": [KEY_LEFT],                        # Mover la cámara a la izquierda
	&"pan_right": [KEY_RIGHT],                      # Mover la cámara a la derecha
	&"pan_up": [KEY_UP],                            # Mover la cámara para arriba
	&"pan_down": [KEY_DOWN],                        # Mover la cámara para abajo
}
## Las que van por el lugar de la tecla y no por lo que dice (cambia con el teclado): la consola
## también se abre con la de la izquierda del 1.
const PHYSICAL := {
	&"console": [KEY_QUOTELEFT],
}
## Cómo se nombran en los textos las que Godot nombra de otra forma.
const NAMES := {KEY_ESCAPE: "Esc"}

## Registra las acciones en el InputMap (una vez; "Menú principal" recarga el mundo y lo vuelve a
## llamar). Lo llama World al arrancar.
static func setup() -> void:
	for action: StringName in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.keycode = k
			InputMap.action_add_event(action, ev)
		for k: Key in PHYSICAL.get(action, []):
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

## La tecla de la acción, como la nombran los textos ("G", "Esc", "F1").
static func label(action: StringName) -> String:
	var k: Key = KEYS[action][0]
	return NAMES.get(k, OS.get_keycode_string(k))

## Un tooltip con su tecla al final: "Abrir el historial [H]" (text se traduce).
static func tip(text: String, action: StringName) -> String:
	return "%s [%s]" % [TranslationServer.translate(text), label(action)]
