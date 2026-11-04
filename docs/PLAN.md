# Revisión de estructura y plan de mejoras

*3 de noviembre de 2026 · sobre la versión 0.1 (commit `3724ecd`). Fases 0 a 3 hechas; la 4, en curso.*

**Cómo la hice**: leí la arquitectura (las dos escenas, `World`, `HUD`, las armas, el guardado, la
i18n), recorrí `Villager` por secciones, medí tamaños y acoplamiento con scripts, pasé `gdlint`
(gdtoolkit 4.5) por los 53 scripts e hice un chequeo propio de traducciones. **No pude correr
Godot** en el contenedor (no hay salida a las descargas), así que nada de esto está probado en el
juego: todo sale de leer el código.

## En una línea

El código **por dentro** está muy bien (comentado, con constantes con nombre, prolijo, con las
traducciones al día). Lo que no escala es **cómo está repartido**: casi todo termina en cuatro
archivos enormes y cada feature nueva toca 14 archivos. Conviene ordenarlo ahora, antes de que
`villager.gd` llegue a las 8.000 líneas.

## Lo que está bien (y hay que mantener)

- **Comentarios y constantes**: cada número de balance tiene nombre y explicación
  (`FLU_DEATH_CHANCE`, `SHIELD_TIME`...). Es lo mejor del código.
- **Prolijo a nivel de línea**: `gdlint` parsea todo sin errores y, con una configuración que va
  con este proyecto (sin la regla de orden de definiciones, que pide separar constantes y
  variables de cada sistema, y con líneas de hasta 140), quedan 83 avisos: casi todos líneas
  largas con textos, más los archivos gigantes.
- **Traducciones al día**: de unos 150 textos que pasan por `tr()`, `.text` o `popup_text`, solo
  `"%d FPS"` no tiene clave en `I18n.EN`, y no hay claves repetidas.
- **Guardado pensado para durar**: tres ranuras, la partida de antes pasa a la ranura 1 y las
  partidas viejas se siguen cargando (la edad en segundos pasa a días, los arbustos a bayas).
- **Armar todo por código es una decisión, no un descuido**: el editor abierto vuelve a guardar
  `world.tscn` y `project.godot` con lo que tenía (está anotado en `world.gd` y `water_area.gd`).
  Tiene sentido seguir así.
- **Git sano**: los `.uid` y `.import` están commiteados, `.gitattributes` fuerza LF y los
  commits explican qué cambia para el jugador.

## Los números

| | |
|---|---|
| GDScript | ~21.300 líneas en 53 scripts (más 4 shaders) |
| `villager.gd` | 4.001 líneas: 264 constantes, 160 variables, 205 funciones, 8 enums. El 16/10 tenía 760 |
| Otros archivos de más de 1.000 líneas | `hud.gd` 1.704 · `shark.gd` 1.222 · `villager_rig.gd` 1.150 |
| Archivos que tocó cada feature | Espora zombi: 14 (≈+650 líneas en `villager.gd`). Resurrección, escudo y vacuna: 14 (≈+300) |
| Acceso al HUD | 28 búsquedas por grupo en 15 archivos, y ~85 guardas `if hud` |
| Estado global | 67 `static var` en 24 archivos: ~35 son estado de la partida, el resto caches u opciones. Sin autoloads |
| Estilos de interfaz | ~215 `add_theme_*_override` y ~90 `StyleBox` armados a mano en 12 archivos, sin `Theme` |
| Tests, CI, lint | Ninguno |

## Hallazgos

### 1. `Villager` hace de todo · prioridad alta

Un solo archivo maneja más de 25 sistemas: arrastre y revoleo, caída, agua y ahogo, balazo, rayo,
fuego, tornado, diluvio, gripe, espora y zombis, escudo y vacuna, resurrección, empujones, hambre,
casa y familia, edad, sueño, charlas, fe y miedo, altar, ánimo, apariencia, carnet y voz. Además
sintetiza 6 sonidos y define 4 clases de efectos (`BloodPool`, `ZapArcs`, `AshPile`, `Flames`).

Lo más delicado: **el estado del cuerpo son 12 flags sueltos** (`dragging`, `falling`, `in_water`,
`drowning`, `flooded`, `dead`, `eaten`, `asleep`, `inside`, `tornado`, `altar`, `_rising`). Casi
todos se excluyen entre sí, pero nada lo garantiza: `_physics_process` (235 líneas) los revisa en
un orden de prioridad e `is_idle()` tiene que negar 9. Cada sistema nuevo suma otro flag y más
combinaciones posibles.

Propuesta:

- Un `enum Body { WALKING, DRAGGED, FALLING, FLOATING, DROWNING, TORNADO, INSIDE, ASLEEP, ALTAR,
  RISING, DEAD, EATEN }` para lo que es excluyente, con una sola función que cambia de estado (y
  hace lo de entrar y salir de cada uno). Lo que puede pasar a la vez (prendido fuego, gripe,
  espora, hambre, ánimo) sigue aparte.
- Partir por sistemas, cada uno en su archivo dentro de `actors/villager/` (por ejemplo
  `villager_spore.gd`, `villager_flu.gd`, `villager_needs.gd`, `villager_social.gd`). Pueden ser
  nodos hijos o `RefCounted` con una referencia al aldeano; lo importante es que cada sistema
  tenga juntos sus constantes, su estado, su `update(dt)` y su `to_dict()` / `from_dict()`.
- Arrancar por lo mecánico, que no cambia nada del juego: las clases de efectos a su archivo y los
  `_make_*` de sonido a un `audio/sfx.gd`. Eso solo saca unas 300 líneas.

### 2. Agregar un poder toca 14 archivos · prioridad alta

Las 11 clases de poderes repiten casi el mismo esqueleto (~40 líneas cada una): `signal
armed_changed`, `static var armed` / `unlocked`, `PRICE` / `SACRIFICES`, el reseteo en `_ready()`,
`set_armed()` con el aviso de "desbloqueala en la tienda" y el cursor, y el `_unhandled_input` con
su tecla, Esc y click derecho. Y además, por cada poder:

- **`World`**: una variable, crearlo, conectar dos señales y sumarlo a `_weapons()`.
- **`HUD`**: una señal `X_toggled`, `set_X_armed`, `unlock_X`, su clave en `save_state` /
  `load_state`, `aiming()`, su `_sync_weapon` y su `elif` de pista en `_refresh()`, su botón, su
  `StyleBox` y su fila en `TOOLS`.
- **`Shop`, `I18n`, `DebugConsole`** y el README.

`Charm` y `Miracle` ya van por buen camino (un `Kind` y un diccionario `KINDS` con precio, tecla y
textos): hay que llevar a todos ahí.

Propuesta: una clase base `Power` (`extends Node2D`) con lo común (id, tecla, precio, sacrificios,
bueno o malo, textos, cursor, `armed`, el toggle por tecla, Esc y click derecho) y un método
virtual para el click. Un registro con la lista de poderes, que recorren `World`, `HUD`, `Shop`,
el guardado y la consola. Meta: **un poder nuevo = un archivo + una línea en el registro + sus
textos**.

### 3. El estado de la partida vive en el HUD y en `static var` · prioridad media-alta

- Las monedas (ofrendas y sacrificios), la XP, la devoción, los puntos de expansión, los tiburones
  y el guardado de los desbloqueos están en `hud.gd`. Por eso la lógica del juego depende de la
  interfaz: el aldeano le pide al HUD que le sume (`if hud and hud.has_method("add_xp")`), hay ~85
  `if hud` por las dudas y `World` tiene un "fallback si no hay HUD".
- Los desbloqueos y lo que está afuera son `static var` repartidos en cada arma. Como
  `_to_title()` recarga la escena y los estáticos sobreviven, **cada clase se tiene que acordar de
  resetearlos en su `_ready()`**. Hoy está bien hecho (lo revisé arma por arma), pero es un
  contrato invisible: un estático nuevo que alguien se olvide de resetear pasa de una partida a la
  otra.

Propuesta: un `GameState` (o `Economy`) con las monedas, la XP, la devoción, los desbloqueos y los
tiburones, con señales (`offerings_changed`...) que el HUD escucha para mostrar. Un `Game.reset()`
único, que llama `World._ready()`, para todo el estado de la partida. Y un canal para los carteles
flotantes (`Events.popup(...)`) en vez de que cada uno busque el HUD. Ojo: un autoload se registra
en `project.godot`, que el editor abierto pisa; o se agrega una vez desde el editor, o se hace como
clase con estáticos (como `Settings`), que ya funciona bien en este proyecto.

### 4. Guardado · prioridad media

- **Sin número de versión**: las migraciones adivinan por las claves que hay (`d.has("days")`,
  `"bush"`, `d.has("lifespan")`). Funciona, pero cada cambio lo hace más difícil de seguir. Sumar
  `meta/version` y una cadena de migraciones `1 → 2 → 3...`.
- **Una partida dañada se pierde sin aviso**: `SaveSlots.summary()` y `World._load_game()` tratan
  igual "no existe" que "no se pudo leer". Si un archivo queda roto, la ranura se ve vacía ("Nueva
  partida") y el siguiente autoguardado la pisa. Distinguir los dos casos, guardar una copia `.bak`
  y mirar el error que devuelve `cfg.save()` (hoy no se mira).
- **`World` mete mano en el aldeano**: `save_game()` lee `v._sleep_drop` y `v._home_ok()` y arma a
  mano un diccionario de unos 25 campos. Que cada cosa sepa guardarse (`Villager.to_dict()` /
  `from_dict()`, `Decoration.to_dict()`) y que `World` solo junte.

### 5. Detalles de correctitud · prioridad media (arreglos chicos)

- **Se puede pasar la capacidad de la isla**: `alive_villagers()` no cuenta a los que se están
  ahogando, pero mientras se hunden (~1,6 s) se los puede rescatar. Con la isla llena, en esa
  ventana se puede invocar otro (o puede nacer un bebé: `Decoration._try_birth` usa la misma
  cuenta) y, al rescatarlo, queda 6/5. Lo encontré leyendo el código; no lo probé.
- **"Vivo" está escrito de cuatro maneras**: `not dead and not eaten` (6 lugares), lo mismo más
  `not is_queued_for_deletion()` (8), más `not drowning` (2, en `World`) y solo `not dead` (8).
  Algunas diferencias son a propósito, pero conviene tener `is_alive()` y
  `counts_as_population()` en `Villager` y usarlas en todos lados.
- `_sync_weapon` arma una clave de traducción con
  `locked_tip.replace("ofrendas)", "ofrendas y %d sacrificios)")`: si alguien cambia el texto de
  origen, la traducción se rompe sin aviso. Mejor dos claves explícitas.

### 6. Interfaz · prioridad media-baja

- `hud.gd` arma toda la interfaz y además tiene la economía (punto 3). Partirlo en barra de arriba,
  barra de poderes y pista, y sacar `HudIcon` y `Painter` a su propio archivo (los usan otros 8
  archivos).
- Un `Theme` (o una clase `UiStyle` que lo arme por código, para no depender del editor) en vez de
  ~215 overrides sueltos: hoy, cambiar la tipografía o un color es buscar y reemplazar en 12
  archivos.
- Las pistas y tooltips de cada poder (la escalera de `elif` de `_refresh()`) pueden salir del
  registro de poderes.
- `Decoration` maneja sus 7 tipos con `if kind == "..."` en 16 lugares. La choza (vecinos,
  nacimientos, cartel, romperse) ya es casi otra cosa: `Hut extends Decoration`.

### 7. Teclas · prioridad baja

Hay 27 atajos repartidos en más de una docena de archivos (no se pisan: lo chequeé). Juntarlos en
un solo lugar (un `ui/controls.gd` que los registre en el `InputMap` por código) da una lista
única, permite cambiar teclas más adelante y que la sección Controles del README salga de ahí.

### 8. Rendimiento · para más adelante

Con 26 aldeanos como máximo no es un problema, pero si sube la capacidad:
`get_nodes_in_group("villager")` se llama en unas 20 funciones del aldeano, algunas en cada frame
(`_separation`, `_avoid_zombies`), y `World._process` recorre a todos dos veces por frame. Llevar
la lista de aldeanos en `World`. Los sonidos se sintetizan la primera vez que suenan (puede trabar
un instante): generarlos al cargar. Antes de optimizar los dibujos (`_draw` en cada frame en el
rig), medir con el contador de FPS en una compu lenta.

### 9. Documentación

- El README (34 KB) es una enciclopedia de mecánicas: excelente como documento de diseño, pero
  largo como README. Separar en un README corto (qué es, cómo correrlo, controles) y un
  `docs/MECANICAS.md` con todo el detalle.
- Los precios están en el código y repetidos en el README. Hoy coinciden, pero con cada cambio de
  balance hay que acordarse de los dos.
- Faltaba una guía para trabajar en el código: la agregué en `CLAUDE.md` (arquitectura, reglas y
  cómo agregar cosas), que además Claude lee solo al empezar cada sesión.

### 10. Limpiezas chicas

- `icon.svg` es el ícono por defecto de Godot y no se usa.
- `Villager.hud_path` (`@export`) no se usa.
- Queda un `print("[WORLD] Devoción insuficiente...")` en `world.gd`.
- `has_method("get_global_rect")` sobre el agua (6 lugares) puede ser `is WaterArea`, y
  `hud.has_method("add_xp")` se hace sobre una variable que ya es `HUD`.
- En `world.tscn` hay nodos en minúscula o camelCase (`isle`, `waterRend`, `waterArea`) y el resto
  en PascalCase. Cambiarlos es tocar el `.tscn`: desde el editor.
- En `export_presets.cfg`, `product_name` y `company_name` están vacíos.
- En `world/altar.gd:170` el parámetro `at` no se usa.

## Plan

Cada paso es un commit chico que se prueba en el juego antes de seguir. Las fases 0 y 1 no cambian
cómo se juega, salvo los arreglos de la capacidad y lo que se ve cuando una partida no se puede
leer o guardar.

### Fase 0 · Red de seguridad ✅

- [x] `CLAUDE.md` con la arquitectura y las reglas (junto con esta revisión).
- [x] `gdlintrc` y `tools/check_i18n.py`. Al final `gdlintrc` no limita el largo de las líneas: 44
      de las 73 de más de 140 son pares de traducción que no se pueden partir, y gdtoolkit no deja
      apagar una regla en un solo archivo. También apaga los `return` tempranos y, hasta las fases
      2 a 4, el tamaño de los archivos. El chequeo de traducciones mira todos los literales con
      pinta de texto (no solo los `tr()`), y avisa tanto lo que falta traducir como las claves que
      sobran.
- [x] GitHub Actions (`.github/workflows/checks.yml`): `gdlint` y el chequeo de traducciones en
      cada push. Corre en verde.
- [x] Las limpiezas del punto 10, menos dos: los nombres de los nodos de `world.tscn` (hay que
      cambiarlos desde el editor y a la vez los `$isle`... del código) y `company_name` en
      `export_presets.cfg` (lo tiene que decidir el usuario).

### Fase 1 · Arreglos chicos ✅

- [x] `Villager.is_alive()`, en los 33 lugares donde "vivo" estaba escrito a mano. No hizo falta
      `counts_as_population()`: con el que se ahoga contado como vivo, es lo mismo.
- [x] Que el que se está ahogando cuente para la capacidad (punto 5). Apareció otro camino para
      pasarse: resucitar con la isla llena. Ahora dice "¡La isla está llena!".
- [x] Claves explícitas en `_sync_weapon`.
- [x] Guardado: `meta/version`, escritura a `.tmp`, copia `.bak` que se usa si la partida no se
      puede leer, tarjeta "Dañada" que solo deja borrar, y aviso si no se pudo guardar.

### Fase 2 · Un solo modelo de poder ✅ (falta probarla en el juego)

- [x] Clase base `Power` (`weapons/power.gd`) y registro: cada poder entra solo al grupo `"power"`,
      y `Power.all()`, `aiming()` y `threat()` reemplazan a `HUD.aiming()` y a `Feed.armed`. La
      lista en el orden de la barra quedó en `World._create_powers`, así la base no conoce a sus
      hijos.
- [x] Todos los poderes de una vez, no de a uno: la cáscara era idéntica en los 11, así que pasar
      solo la pistola habría dejado dos mecanismos conviviendo sin probar menos riesgo. `Charm` y
      `Miracle` son `Power` con `Kind` (y `make`). `armed` y `unlocked` son de cada nodo: se terminó
      lo de resetear estáticos en `_ready()` para los poderes.
- [x] `HUD`, `World`, `Shop`, el guardado y la consola recorren la lista: se fueron 11 señales, 11
      `set_X_armed`, 10 `unlock_X` y `TOOLS`. Los desbloqueos se guardan como `{"gun": true, ...}`
      (formato 2), leyendo también las claves de antes.
- Cambios que se ven: el slot de cualquier poder afuera se resalta con la misma intensidad (antes
  variaba entre 30 y 38 %), y al desatar el diluvio con D la barra pasa a su pestaña, como con los
  demás. Un poder nuevo ahora es un archivo, una línea en `World._create_powers`, su ícono y sus
  textos.

### Fase 3 · El estado de la partida fuera del HUD ✅ (falta probarla en el juego)

- [x] `Game` (`world/game.gd`) con las monedas, la devoción, la XP y los puntos, la Luna de Sangre
      (ya no es un estático de `Moon`) y los tiburones, las compras y su guardado. Quedó como clase
      con estáticos, como `Settings`, y no como autoload, así no hay que tocar `project.godot`; las
      señales van en `Game.events` (`changed`, `loaded`, `offerings_gained`, `point_earned`,
      `shark_changed`...). El HUD solo muestra. El guardado no cambió de formato (sigue en
      `game/hud`).
- [x] Un `Game.reset()` único, lo primero de `World._ready()`: la economía, los números de carnet,
      el tiempo jugado, las relaciones, el árbol y el agua del diluvio (`Storm.clear`).
- [x] Carteles flotantes por señal: `Game.say` y `Game.announce`. Las búsquedas del HUD bajaron de
      28 a 10 y los `if hud` de 86 a 28; lo que queda es interfaz de verdad (el `overlay` donde
      dibujan el rayo, el meteorito, el tornado y el altar, el destello, las etiquetas, los modos).
- Cambio que se ve: la devoción ya no se recarga mientras baja la cámara (son unos segundos).

### Fase 4 · Partir `Villager` (en curso, un sistema por sesión)

- [x] Lo mecánico: las clases de efectos (`BloodPool`, `ZapArcs`, `AshPile`, `Flames`) y los sonidos
      (`VillagerSounds`) a sus archivos. Sin cambios en el juego.
- [x] Espora y zombis → `VillagerSpore`. Al medir el acoplamiento resultó que no era lo más suelto
      (usa 47 cosas del resto del aldeano y 13 partes suyas se usan desde otros archivos), así que
      quedó como componente: un `RefCounted` con `v` (el aldeano), y el aldeano reenvía la API de
      afuera para que no cambien los que llaman. El pase se hizo con un script que prefija lo del
      aldeano (`v.dir`, `Villager.VOICE_DB`, `self` → `v`) y otro que chequea que no quede nada
      suelto; conviene repetir lo mismo con los que siguen.
- [x] Gripe → `VillagerFlu`, con los mismos dos scripts. Usa 26 cosas del aldeano (6 son del nodo)
      y 11 partes suyas se usan desde 5 archivos. Las comparaciones repetidas pasaron a `has_flu()`
      (la está incubando o está enfermo) y el carnet ya no lee un campo privado (`flu_look()`). El
      hambre, que estaba metida entre las funciones de la gripe, quedó con la comida.
- [x] Fuego y rayo → `VillagerBurn`, juntos: quemarse del todo termina igual que el rayo
      (carbonizado, con el mismo humo, y hecho cenizas). Usa 35 cosas del aldeano (10 son del
      nodo) y 7 partes suyas se usan desde 6 archivos. `HEAD_TOP` y `FEET` quedaron en el aldeano
      (son medidas del cuerpo), igual que `body_center`, `body_distance` y `ground_point`, que se
      juntaron con `_body_segment`.
- [x] Necesidades → tres componentes en vez del `villager_needs.gd` que proponía arriba:
      `VillagerMood` (el ánimo, con los pesos `MOOD_*` de su bloque), `VillagerSleep` y
      `VillagerHunger`, un commit cada uno. Son sistemas distintos, cada uno con su estado y su
      `update`, y entre ellos se hablan por lo que reenvía el aldeano (`add_mood`, `hunger`,
      `tiredness`). El ánimo usa 19 cosas del aldeano y lo usan 10 archivos; el sueño, 38 y 7; el
      hambre, 34 y unos 10. Para estos tres el script de los anteriores pasó a ser uno solo que
      sirve para cualquier sistema, y el chequeo ahora también busca declaraciones repetidas (gdlint
      no las ve: encontró una antes de commitear), accesos a campos que se mudaron y asignaciones a
      propiedades de solo lectura. Lo que arrancaba al azar en `_ready` (el ánimo, el cansancio y
      el hambre del principio) ahora arranca en el componente; las partidas y los bebés lo pisan
      después, igual que antes.
- [x] Social → dos componentes: `VillagerChat` (las charlas) y `VillagerFaith` (la fe y el miedo),
      un commit cada uno. Cada uno usa 29 cosas del aldeano; a las charlas las usan 7 archivos y a
      la fe, 10. Charlar es de a dos: lo que hay que hacer del lado del otro (sumarlo a la charla,
      cortársela) va por lo que reenvía su aldeano (`join_chat`, `leave_chat`) en vez de tocarle
      los campos. Se quedaron en el aldeano, porque los usan todos: los globitos (`say`), el
      duelo (`_mourn`), quedarse quieto y los empujones (`get_pushed_by`, ahora público porque lo
      usa la Discordia), y salir corriendo (`_scram`, que también usan la espora y el altar).
      `witness()` también es público ahora (lo usan el altar y la espora). El script ahora también
      prefija los tipos de las firmas (`-> Bubble` → `-> Villager.Bubble`), que el chequeo
      tampoco revisaba.
- [ ] `enum Body` para los estados excluyentes: cambia el corazón de `_physics_process`, mejor
      después de probar en el juego lo de las fases 2 a 4.
- [ ] El que falta: casa y familia (y la edad).
- [ ] Que cada uno se guarde solo (`to_dict()` / `from_dict()`): por ahora `World` sigue guardando
      los campos del aldeano (la gripe, por `flu`, `flu_t` y `set_flu`; la espora, por `spore` y
      `set_spore`; el hambre, el ánimo, el sueño, la fe y el miedo, por sus propiedades).

`villager.gd` va de 4.001 a 2.148 líneas.

### Fase 5 · Interfaz (cuando haga falta)

- [ ] `UiStyle` o `Theme`, partir `hud.gd`, `HudIcon` y `Painter` a su archivo, las pistas desde el
      registro de poderes y `Hut` aparte.

### Fase 6 · Tests (cuando haya Godot en CI)

- [ ] GUT o gdUnit4 para lo que no depende de la escena: `Relations`, `Genealogy`, `Names` y las
      migraciones del guardado (más fácil después de la fase 4).
- [ ] Prueba de humo en CI: abrir el proyecto headless con Godot 4.7, cargar una partida de
      ejemplo y correr unos segundos sin errores.

**Si querés seguir sumando cosas rápido**: las fases 0 y 1 son las que más rinden por lo que
cuestan. La 2 conviene hacerla antes del próximo poder, y la 4 antes del próximo sistema del
aldeano.

## Reglas para que no vuelva a pasar

- Un archivo que pasa las 1.000 líneas se parte antes de sumarle otra cosa.
- Un sistema nuevo del aldeano va en su propio archivo.
- Un `static var` nuevo con estado de la partida se resetea en un solo lugar.
- Todo texto visible nuevo va a `I18n.EN` (lo chequea `tools/check_i18n.py` en cada push).
