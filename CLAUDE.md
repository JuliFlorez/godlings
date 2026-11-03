# Godlings: guía para trabajar en el código

God game en **Godot 4.7** (GL Compatibility), todo en GDScript (~21.000 líneas). Las mecánicas
están en `README.md`; la revisión de estructura y el plan de refactor, en `docs/PLAN.md`.

## Reglas

- **No edites a mano `world/world.tscn`, `actors/villager/villager.tscn` ni `project.godot`.** El
  editor de Godot suele estar abierto en la compu del usuario y los vuelve a guardar con lo que
  tenía, así que el cambio se pierde. Lo que haga falta se arma por código (por eso `WaterArea` se
  agranda en código y la versión está en `World.VERSION`). Si algo tiene que ir sí o sí ahí
  (autoload, InputMap, buses de audio), pedile al usuario que lo haga desde el editor.
- En la nube **no hay Godot**: no se puede correr el juego. Antes de commitear corré los chequeos
  que la CI (`.github/workflows/checks.yml`) corre en cada push:
  `pip install "gdtoolkit==4.5.0"`, `gdlint $(git ls-files '*.gd')` (la config está en
  `gdlintrc`; detecta errores de sintaxis) y `python3 tools/check_i18n.py`. El resto lo prueba el
  usuario en el juego: decile qué probar.
- Comentarios, textos del juego y docs en **español rioplatense** (voseo); commits en **inglés**
  (título corto y un cuerpo que cuenta qué cambia para el jugador).
- Si cambia una mecánica, un precio o una tecla, actualizá el README (su sección y Controles).
- La versión va en tres lugares: `World.VERSION`, `project.godot` y `export_presets.cfg`.
- Commiteá los `.uid` (y los `.import`) junto con su archivo.

## Mapa

| Dónde | Qué |
|---|---|
| `world/world.gd` (`World`) | La raíz: capas (`Ground`, y `Props` con y-sort), crea los poderes y los conecta con el HUD, población y capacidad, rezos → ofrendas, brotes de gripe, zoom y paneo, menú de inicio y bajada de la cámara, **guardado y carga** (`save_game`, `_load_game`). |
| `actors/villager/villager.gd` (`Villager`) | Todo el aldeano: física (arrastre, caída, agua, ahogo), IA (paseo, comida, charlas, casa, sueño), estados (gripe, espora y zombi, fuego, rayo, escudo, vacuna, resurrección), fe, miedo, ánimo, edad y sus sonidos sintetizados. |
| `actors/villager/villager_rig.gd` | El esqueleto 2D y lo que se dibuja encima (cara, pelo, ojos, hongos, rayos X). |
| `actors/villager/relations.gd`, `genealogy.gd`, `names.gd` | Estáticos: afinidad y vínculos por número de carnet, con el historial; los que ya no están, para el árbol; nombres al azar. |
| `actors/shark.gd` | El tiburón (en `World` se duplica hasta `Shark.MAX`). |
| `weapons/` | Un nodo por poder: `Gun`, `Lightning`, `Meteor`, `Tornado`, `Storm` (diluvio), `Plague`, `Spore`, `Cure`, `Feed`. `Charm` (Cupido, Discordia, Amistad) y `Miracle` (Resurrección, Escudo, Vacuna) van por `Kind`. |
| `ui/hud.gd` (`HUD`, grupo `"hud"`) | Arma toda la interfaz por código **y además guarda la economía**: ofrendas, sacrificios, XP, devoción, puntos de expansión, tiburones y desbloqueos (`save_state` / `load_state`). |
| `ui/` (el resto) | `shop`, `villager_card` (el carnet), `hut_card`, `family_tree`, `history_panel`, `title_menu`, `pause_menu`, `settings` y `settings_panel`, `i18n`, `debug_console` (F1, solo en debug). |
| `world/` (el resto) | `decoration` (todas, por `kind`; la choza tiene vecinos y nacimientos), `decor_placer`, `altar`, `food` / `coconut` / `manna`, `sea` y `water.gdshader`, `water_area`, `hut_debris`, `expand_marker`, `save_slots`. |
| `sky/` | `sky.gd` (reloj, día y noche, Luna de Sangre), `sun` y `moon` (`Celestial`), nubes, estrellas y gaviotas. |
| `audio/` | La música, `wow.wav` y `Synth.wav()`; cada clase sintetiza sus sonidos en sus `_make_*`. |

## Cómo está hecho

- **Todo se crea por código** (`X.new()` y `add_child`); las únicas escenas son `world.tscn` y
  `villager.tscn`. La interfaz usa `HUD.make_label`, `make_button` y `make_box`.
- **No hay autoloads: el estado global son `static var`.** De la partida: `Gun.unlocked` /
  `armed` (y los de cada poder), `Storm.rain`, `Moon.blood_unlocked`, `Relations`, `Genealogy`,
  `Villager.ids_issued`, `World.play_time`. Las opciones (`Settings`) persisten a propósito.
  "Menú principal" recarga la escena y los estáticos **sobreviven**: cada poder resetea los suyos
  en su `_ready()`, y `World._ready()` resetea `Relations`, `Genealogy`, `ids_issued` y
  `play_time`. Un `static var` nuevo con estado de la partida se tiene que resetear ahí, o pasa de
  una partida a otra.
- Al HUD se llega con `get_tree().get_first_node_in_group("hud")`; a los aldeanos, con el grupo
  `"villager"`. Para saber si un aldeano está vivo, `Villager.is_alive()` (el que se está
  ahogando cuenta como vivo: se lo puede rescatar); no lo escribas a mano.
- **Traducciones**: el texto en español es la clave. Todo texto visible nuevo va a `I18n.EN` con
  su traducción, y si sacás o cambiás un texto, sacá su clave vieja (`tools/check_i18n.py` avisa
  las dos cosas). `Label` y `Button` se traducen solos; los textos con formato usan
  `tr("... %d") % x`. No armes claves en tiempo de ejecución (`replace`, concatenar).
- **Guardado**: `ConfigFile` en `user://save_N.cfg` (3 ranuras). Se escribe y se lee con
  `SaveSlots.write` / `read`, que guardan a un `.tmp`, dejan la anterior como `.bak` y la usan si
  la partida no se puede leer. Tiene versión (`meta/version`, `SaveSlots.VERSION`); las partidas
  de antes no la tienen y se migran mirando qué claves tienen. Si cambiás el formato, subí la
  versión y seguí cargando las de antes.
- **Teclas**: cada poder mira la suya en `_unhandled_input` (no hay InputMap). Ocupadas: G R M T D
  P Z E F C V O L A B; S (seleccionar), H (historial), I (editar la isla), F1 o la tecla a la
  izquierda del 1 (consola), flechas, + − 0 (zoom) y Esc. Antes de usar una, fijate que esté
  libre.

## Agregar un poder (como está hoy)

Hay que tocar: el script en `weapons/`; `World._ready()` (crearlo, conectar `armed_changed` y
`X_toggled`, sumarlo a `_weapons()`); el `HUD` (señal `X_toggled`, `set_X_armed`, `unlock_X`,
`save_state` / `load_state`, `aiming()`, `_refresh()` con su tooltip y su pista, `_build_toolbar`
y `TOOLS`); `Shop`; `I18n`; `DebugConsole` (desbloquear todo) y el README. Si es malo (cuesta
sacrificios), su tooltip de bloqueado es la clave "Desbloquealo en la tienda (%d ofrendas y %d
sacrificios)" (o "Desbloqueala"). Si tiene variantes,
seguí el patrón de `Charm` / `Miracle` (`Kind` y `KINDS`). La fase 2 de `docs/PLAN.md` propone
unificar todo esto.

## Archivos grandes

`villager.gd` (~4.000 líneas), `hud.gd` (~1.700), `shark.gd` (~1.200) y `villager_rig.gd`
(~1.150). Antes de sumarle otro sistema a `villager.gd`, ponelo en su propio archivo (fase 4 del
plan).
