# Godlings: guía para trabajar en el código

God game en **Godot 4.7** (GL Compatibility), todo en GDScript (~21.700 líneas, sin los tests). Las
mecánicas están en `README.md`; la revisión de estructura y el plan de refactor, en `docs/PLAN.md`.

## Reglas

- **No edites a mano `world/world.tscn`, `actors/villager/villager.tscn` ni `project.godot`.** El
  editor de Godot suele estar abierto en la compu del usuario y los vuelve a guardar con lo que
  tenía, así que el cambio se pierde. Lo que haga falta se arma por código (por eso `WaterArea` se
  agranda en código y la versión está en `World.VERSION`). Si algo tiene que ir sí o sí ahí
  (autoload, InputMap, buses de audio), pedile al usuario que lo haga desde el editor.
- En la nube **no hay Godot**: no se puede correr el juego. Antes de commitear corré lo que no lo
  necesita: `pip install "gdtoolkit==4.5.0"`, `gdlint $(git ls-files '*.gd')` (la config está en
  `gdlintrc`; detecta errores de sintaxis) y `python3 tools/check_i18n.py`. gdlint no ve todo: una
  variable declarada dos veces o un miembro que ya no existe pasan. Eso lo encuentra la CI, que sí
  corre Godot (ver Tests y CI): después de pushear, fijate que pase. Lo que la CI no ve (cómo se
  juega) lo prueba el usuario en el juego: decile qué probar.
- Comentarios, textos del juego y docs en **español rioplatense** (voseo); commits en **inglés**
  (título corto y un cuerpo que cuenta qué cambia para el jugador).
- Si cambia una mecánica, un precio o una tecla, actualizá el README (su sección y Controles).
- La versión va en tres lugares: `World.VERSION`, `project.godot` y `export_presets.cfg`.
- Commiteá los `.uid` (y los `.import`) junto con su archivo.

## Mapa

| Dónde | Qué |
|---|---|
| `world/world.gd` (`World`) | La raíz: capas (`Ground`, y `Props` con y-sort), crea los poderes y los conecta con el HUD, población y capacidad, rezos → ofrendas, brotes de gripe, zoom y paneo, menú de inicio y bajada de la cámara, **guardado y carga** (`save_game`, `_load_game`). |
| `actors/villager/villager.gd` (`Villager`) | El aldeano: el cuerpo y su física (arrastre, caída, agua, ahogo, empujones; en qué estado está lo dice `body()`, ver `enum Body`), el paseo, cómo es y su carnet, el escudo, la vacuna y la resurrección, los globitos (`say`) y el duelo. Cada sistema está en su componente (ver Archivos grandes). |
| `actors/villager/villager_age.gd` (`VillagerAge`) | Un componente del aldeano: la edad (crece, le salen canas, envejece, se muere de viejo) y si puede tener un bebé. |
| `actors/villager/villager_burn.gd` (`VillagerBurn`) | Un componente del aldeano: el fuego y el rayo (se prende o lo electrocuta, queda carbonizado y se hace cenizas). |
| `actors/villager/villager_chat.gd` (`VillagerChat`) | Un componente del aldeano: las charlas (con quién, ir hasta el otro, hablar por turnos, cómo les fue, las peleas). |
| `actors/villager/villager_faith.gd` (`VillagerFaith`) | Un componente del aldeano: la fe y el miedo (devoto, fanático, hereje o aterrado), los rezos y las ofrendas, y cómo reacciona a tu mano. |
| `actors/villager/villager_flu.gd` (`VillagerFlu`) | Un componente del aldeano: la gripe (la incuba, se enferma, estornuda y contagia, y se cura o se muere). |
| `actors/villager/villager_home.gd` (`VillagerHome`) | Un componente del aldeano: la casa (en qué choza vive, ir a dormir o a descansar, entrar y salir). |
| `actors/villager/villager_hunger.gd` (`VillagerHunger`) | Un componente del aldeano: el hambre y la comida (busca qué comer, va, mastica, se muere de hambre). |
| `actors/villager/villager_mood.gd` (`VillagerMood`) | Un componente del aldeano: el ánimo (lo que le toca por cómo está su vida, lo que le pasa, por qué está así) y los pesos `MOOD_*`. |
| `actors/villager/villager_sleep.gd` (`VillagerSleep`) | Un componente del aldeano: el sueño (el cansancio, dormir de noche y la siesta, acostarse y despertarse). |
| `actors/villager/villager_spore.gd` (`VillagerSpore`) | Un componente del aldeano: la espora zombi (contagio, hongos, el zombi que persigue y muerde, el brote) y el miedo de los sanos a los zombis. |
| `actors/villager/villager_sounds.gd`, `blood_pool.gd`, `zap_arcs.gd`, `ash_pile.gd`, `flames.gd` | Los sonidos sintetizados del aldeano y sus efectos (el charco de sangre, los chispazos del rayo, las cenizas, las llamas). |
| `actors/villager/villager_rig.gd` | El esqueleto 2D y lo que se dibuja encima (cara, pelo, ojos, hongos, rayos X). |
| `actors/villager/relations.gd`, `genealogy.gd`, `names.gd` | Estáticos: afinidad y vínculos por número de carnet, con el historial; los que ya no están, para el árbol; nombres al azar. |
| `actors/shark.gd` | El tiburón (en `World` se duplica hasta `Shark.MAX`). |
| `weapons/` | Un nodo por poder, todos hijos de `Power` (`power.gd`: lo común, y `Power.all()` / `aiming()`): `Gun`, `Lightning`, `Meteor`, `Tornado`, `Storm` (diluvio, no se apunta), `Plague`, `Spore`, `Cure`, `Feed`. `Charm` (Cupido, Discordia, Amistad) y `Miracle` (Resurrección, Escudo, Vacuna) van por `Kind`. `World._create_powers` los crea en el orden de la barra. |
| `world/game.gd` (`Game`) | La partida, en estáticos: ofrendas, sacrificios, devoción, XP y puntos de expansión, la Luna de Sangre y los tiburones comprados, las compras (`buy`, `unlock_power`...) y su guardado (`save_state` / `load_state`). `Game.reset()` borra todo lo de la partida; `Game.events` avisa lo que cambia; `Game.say` / `announce` muestran un cartel flotante. |
| `ui/hud.gd` (`HUD`, grupo `"hud"`) | La interfaz: arma `TopBar` y `PowerBar`, abre los paneles (tienda, historial, carnet, cartel de la choza, árbol, pausa), lleva el modo del click, la pista y los carteles flotantes, y **muestra** la partida: escucha `Game.events`. No guarda nada. |
| `ui/top_bar.gd` (`TopBar`), `ui/power_bar.gd` (`PowerBar`) | La barra de arriba (el día, la XP, la isla, la tienda y el historial, el + de invocar con la devoción, las monedas) y la de abajo (el modo del click y los poderes, con `set_powers`). |
| `ui/ui_style.gd` (`UiStyle`) | El estilo de la interfaz: la paleta (`UiStyle.C_TEXT`, `C_PANEL`, el color de cada poder...) y las piezas (`label`, `button`, `box`, `window`, `outline`). |
| `ui/hud_icon.gd` (`HudIcon`), `ui/painter.gd` (`Painter`) | Los íconos vectoriales por nombre (y la moneda de los sacrificios), y el lienzo del `overlay` donde dibujan el rayo, el meteorito y el tornado. |
| `ui/` (el resto) | `shop`, `villager_card` (el carnet), `hut_card`, `family_tree`, `history_panel`, `title_menu`, `pause_menu`, `settings` y `settings_panel`, `i18n`, `debug_console` (F1, solo en debug). |
| `world/` (el resto) | `decoration` (todas, por `kind`; se crean con `Decoration.make(kind)`), `hut` (`Hut`, la choza: los que viven ahí, los nacimientos, el cartel y romperse), `decor_placer`, `altar`, `food` / `coconut` / `manna`, `sea` y `water.gdshader`, `water_area`, `hut_debris`, `expand_marker`, `save_slots`. |
| `sky/` | `sky.gd` (reloj, día y noche, Luna de Sangre), `sun` y `moon` (`Celestial`), nubes, estrellas y gaviotas. |
| `audio/` | La música, `wow.wav` y `Synth.wav()`; cada clase sintetiza sus sonidos en sus `_make_*`. |
| `tests/`, `tools/ci/` | Los tests y lo que corre la CI con Godot (ver Tests y CI). No van en el juego exportado. |

## Cómo está hecho

- **Todo se crea por código** (`X.new()` y `add_child`); las únicas escenas son `world.tscn` y
  `villager.tscn`. La interfaz se arma con `UiStyle`: sus colores y sus piezas (`UiStyle.label`,
  `button`, `box`, `window`, `outline`). Un color o un estilo que se repite va ahí, no suelto en
  cada panel.
- **No hay autoloads: el estado global son `static var`.** De la partida: todo `Game`, y además
  `Villager.ids_issued`, `World.play_time`, `Relations`, `Genealogy` y el agua del diluvio
  (`Storm.rain`...). "Menú principal" recarga la escena y los estáticos **sobreviven**: los borra
  `Game.reset()`, lo primero de `World._ready()`. Un `static var` nuevo con algo de la partida se
  borra ahí, o pasa de una partida a otra. Las opciones (`Settings`) persisten a propósito, y
  `World.anim_time` (el reloj de lo que se anima al dibujarse) no es de la partida. (Si está afuera
  y si se compró cada poder no es estático: es de cada nodo, `armed` y `unlocked`.)
- **Para cobrar, pagar o sumar**, `Game` (`Game.buy`, `Game.spend_devotion`, `Game.add_offerings`...),
  nunca el HUD. **Para un cartel flotante**, `Game.say(texto, posición en la pantalla, color)`, o
  `Game.announce(texto, color)` en el medio de la pantalla: no hace falta buscar el HUD.
- Al HUD (para lo que es de la interfaz: el `overlay` donde dibujan el rayo y el meteorito, el
  destello, las etiquetas, los modos del click) se llega con
  `get_tree().get_first_node_in_group("hud")`; a los aldeanos, con el grupo
  `"villager"`; a los poderes, con `Power.all()` (grupo `"power"`), y si hay uno apuntando (el
  click es para él), `Power.aiming()`. Para saber si un aldeano está vivo, `Villager.is_alive()`
  (el que se está ahogando cuenta como vivo: se lo puede rescatar); no lo escribas a mano.
- **Traducciones**: el texto en español es la clave. Todo texto visible nuevo va a `I18n.EN` con
  su traducción, y si sacás o cambiás un texto, sacá su clave vieja (`tools/check_i18n.py` avisa
  las dos cosas). `Label` y `Button` se traducen solos; los textos con formato usan
  `tr("... %d") % x`. No armes claves en tiempo de ejecución (`replace`, concatenar).
- **Guardado**: `ConfigFile` en `user://save_N.cfg` (3 ranuras). Se escribe y se lee con
  `SaveSlots.write` / `read`, que guardan a un `.tmp`, dejan la anterior como `.bak` y la usan si
  la partida no se puede leer. Tiene versión (`meta/version`, `SaveSlots.VERSION`); las partidas
  de antes no la tienen y se migran mirando qué claves tienen. Si cambiás el formato, subí la
  versión y seguí cargando las de antes. Cada aldeano se guarda con `Villager.to_dict()` /
  `from_dict()`, que le piden su parte a cada componente: un campo nuevo de un sistema del aldeano
  va en el `to_dict` / `from_dict` de su componente.
- **Teclas**: la de cada poder es su `key` (la atiende `Power`); las demás, cada uno en su
  `_unhandled_input` (no hay InputMap). Ocupadas: G R M T D
  P Z E F C V O L A B; S (seleccionar), H (historial), I (editar la isla), F1 o la tecla a la
  izquierda del 1 (consola), flechas, + − 0 (zoom) y Esc. Antes de usar una, fijate que esté
  libre.

## Tests y CI

La CI (`.github/workflows/checks.yml`) corre en cada push tres jobs:

- `checks`: gdlint y las traducciones.
- `godot`: baja Godot 4.7.2 y, sin pantalla, compila todos los scripts
  (`tools/ci/check_scripts.gd`), corre los tests (`tools/ci/run_tests.gd`) y juega una partida sola
  (`tools/ci/smoke.gd`: de todo un poco, la guarda, la vuelve a cargar y compara cada aldeano).
  Falla si Godot escribe un error de script.
- `screens`: con una pantalla virtual saca 18 capturas de la interfaz (`tools/ci/screenshots.gd`),
  saca las mismas en el commit de antes del push y dice en el log cuáles cambiaron, dónde y cómo
  (`tools/ci/compare_screens.py`; al final, "Iguales: N de 18"). Si tocaste algo que se ve y no
  querías cambiarlo, tienen que dar todas iguales. Se puede correr a mano contra cualquier commit
  (el input `antes`). Las capturas quedan en el artefacto "capturas" de cada corrida.

Los resultados se miran con las herramientas de GitHub (`actions_list`, `get_job_logs`).

Un test nuevo va en `tests/test_algo.gd`: `extends "res://tests/test_case.gd"` y funciones
`test_*` con `check(cond, qué)` y `check_eq(lo_que_dio, lo_esperado, qué)`; `before_each` y
`after_each` si hacen falta. Cada test corre en una instancia nueva. Las pruebas que juegan usan la
ranura 9 (no pisan las de verdad) y una semilla fija; por eso lo que se anima al dibujarse usa
`World.anim_time` y no `Time.get_ticks_msec()`, y por eso no hay `randomize()`.

## Agregar un poder

Una clase hija de `Power` en `weapons/` que en `_init()` dice cómo es (id, nombre, tecla, si es
bueno, color, precio y sacrificios, sus textos: ver los comentarios de `Power`) y hace lo suyo en
`_use(at)` (el click), `_on_armed(on)` y, si hace falta, `_can_arm()` o `recharge()`. Se agrega en
`World._create_powers`, en su lugar de la barra, con su ícono en `HudIcon` y sus textos en
`I18n.EN`; la barra, la tienda, el guardado y la consola lo toman solos. Si es malo (cuesta
sacrificios), su `locked_tooltip` es "Desbloquealo en la tienda (%d ofrendas y %d sacrificios)" (o
"Desbloqueala"). Si tiene variantes, seguí el patrón de `Charm` / `Miracle` (`Kind`, `KINDS` y
`make`). Sumale su sección al README.

## Archivos grandes

`villager.gd` (~2.000 líneas), `shark.gd` (~1.200) y `villager_rig.gd` (~1.150). Un sistema nuevo
del aldeano va en su propio componente, como `VillagerFlu` o `VillagerMood` (están en el Mapa): un
`RefCounted` con `v` (el aldeano), que el aldeano crea en `_init()` y llama desde su loop. Lo que se
usa desde afuera, el aldeano lo reenvía (`is_zombie()`, la propiedad `spore`...), así no cambian los
que llaman. Adentro del componente, lo del aldeano va con `v.` (`v.dir`, `v.add_mood()`,
`v.global_position`) y sus constantes con `Villager.`; `self` es el componente, el aldeano es `v`.
