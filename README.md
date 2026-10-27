# 🌴 Godlings

Un prototipo de **God Game / simulación de deidades** desarrollado en **Godot 4.7** (GL Compatibility).

En **Godlings**, cuidás (o sacrificás) aldeanos en una isla flotante en medio del océano.

---

## ✨ Características

- 🌥️ **Menú de inicio en el cielo**: el juego arranca allá arriba, sobre un colchón de nubes, con el logo, **Jugar**, **Configuración** y **Salir**. En Jugar hay 3 partidas, cada una con una miniatura de su isla (del tamaño que tiene, de día o de noche), sus aldeanos, ofrendas, cuándo se jugó y cuánto tiempo; las vacías dicen "Nueva partida" y las otras se pueden borrar (pregunta antes). Al elegir una, la cámara baja atravesando las nubes hasta la isla (un click o una tecla la apura); si la partida estaba de noche, el sol se pone mientras baja y sale la luna al llegar.
- 🏝️ **Isla Procedural / Poligonal**: Detección de límites orgánicos mediante polígonos 2D.
- 🌊 **Mar vivo** (`water.gdshader`): olas en perspectiva (chiquitas en el horizonte) con crestas de espuma que avanzan y cambian de forma, el reflejo del sol o la luna (largo y naranja al atardecer, rojo con la Luna de Sangre) y destellos sueltos. De lejos refleja el color del cielo. Alrededor de la isla hay una laguna turquesa con espuma en la orilla y olitas que salen (sigue la forma de la isla cuando crece), y lo que cae al agua (aldeanos, cocos, el tiburón, el meteorito) deja anillos.
- ☁️ **Nubes y gaviotas**: nubes que pasan despacio (las lejanas, más chicas y lentas) y cambian de color con la hora: blancas de día, rosadas al atardecer, azul oscuro de noche y bordó con la Luna de Sangre; cada rayo las ilumina. De día, cada tanto cruza una bandadita de gaviotas.
- 👥 **Aldeanos Interactivos**:
  - Varones y mujeres: cada aldeano invocado sale de uno u otro al azar. Las aldeanas tienen pelo largo con trenzas y cuentas (las trenzas cuelgan por delante de las manos), una pluma con flor en el pelo, top de hojas y voz más aguda. Comparten el mismo esqueleto y animaciones.
  - IA de vagabundeo aleatorio con giro hacia el centro de la isla en los bordes.
  - Mecánica de arrastrar y soltar (*drag & drop*) con el cursor.
  - Física de caída libre al soltarlos al vacío.
  - Flotación y balanceo en el agua, con animación paulatina de ahogo.
  - Sistema de rescate al regresarlos a tierra firme.
  - 🪪 **Carnet**: en modo *Seleccionar*, un click sobre un aldeano abre su carnet con foto (parpadea, y si se muere pone ojos en X), número, género y campos para ponerle nombre y apellido. El nombre queda flotando arriba de su cabeza. Abajo están sus **relaciones**: su pareja, sus amigos y sus enemigos (un click en un nombre abre el carnet de ese aldeano), y mientras el carnet está abierto, arriba de la cabeza de cada uno de ellos aparece un corazón, una carita sonriente o una carita enojada.
  - 💬 **Charlas, amigos, enemigos y parejas**: cada tanto, dos aldeanos que andan cerca se juntan a charlar: uno va hasta el lado del otro, se miran y hablan por turnos con un globito arriba de la cabeza (puntos suspensivos, preguntas, notas musicales, "ja ja", corazones o enojo) mientras mueven la boca con un bla-bla en su tono de voz. Según cómo les fue terminan sonriendo o enojados, y se van queriendo más o menos: así se hacen **amigos**, **enemigos** (que a veces terminan a los empujones, y capaz que alguno cae al agua) o, si se gustan, **pareja**. Cada vez que cambia lo que son, sale un cartel ("¡Se hicieron amigos!", "¡Son pareja!", "Se separaron"...). Hay quienes se caen bien de entrada y quienes no, los amigos charlan más seguido y cada vez mejor, y con gripe se anda de mal humor. Cuando alguien se muere, su pareja y sus amigos lloran. Las relaciones se guardan con la partida.
  - 📜 **Historial**: el botón "Historial" (al lado de la Tienda, o la tecla H) abre la lista de todo lo que pasó entre ellos, de lo más nuevo a lo más viejo y con cuánto hace: quiénes se hicieron amigos, enemigos o pareja, quiénes hicieron las paces, se separaron o dejaron de ser amigos. Tiene pestañas para ver todo o solo las amistades, las enemistades o las parejas; un click en un nombre abre el carnet de ese aldeano, y los que ya no están aparecen con una cruz. Se guarda con la partida (los últimos 100).
- ☀️ **Sol Acosador / 🌙 Luna Acosadora**: Arrastrá el sol hasta el horizonte y se pone: el cielo pasa por el atardecer, cae la noche, salen las estrellas y sube la Luna Acosadora (que no les saca los ojos de encima a los aldeanos). Bajá la luna y vuelve el día.
  - 😱 **Modo Perturbador**: tocá el sol o la luna 5 veces seguidas y se transforman. El Sol Perturbador tiene tentáculos de fuego, cuencas vacías y una sonrisa llena de dientes; la Luna Perturbadora se pone roja, sus cráteres se abren como ojos y le gotea sangre de la boca. Otros 5 toques y vuelven a la normalidad.
- 🦈 **Tiburón**: Una aleta patrulla el agua y va a por cualquier aldeano que esté flotando. Cada aldeano comido cuenta como sacrificio (+XP). Se lo puede agarrar de la aleta y sacar del agua: se sacude colgando, se lo puede tirar y, si cae en la isla, va saltando con la boca abierta y se come a los aldeanos que alcanza hasta volver al agua. Con la pistola, el rayo o el meteorito se lo puede matar (queda panza arriba) y hay que volver a comprarlo en la tienda.
- 🌩️ **Rayo**: sacalo con R y una nube de tormenta sigue al mouse; cada click descarga un rayo que ilumina todo (también de noche). El aldeano alcanzado se electrocuta: tiembla tieso con los brazos abiertos y en los destellos se le ve el esqueleto, queda carbonizado y humeando, y se deshace en cenizas de la cabeza a los pies (si estaba volando, cae carbonizado y se deshace al quedar tirado). El rayo salta a los que están cerca, y si cae en el agua la descarga fríe a todos los que flotan alrededor, tiburones incluidos. Deja una quemadura en la arena y un montoncito de cenizas.
- ☄️ **Meteorito**: sacalo con M y apuntá a la isla o al agua: cae un meteorito en llamas (los aldeanos que están cerca lo miran venir con la boca abierta) y explota con una bola de fuego que hace temblar todo. Los de cerca mueren chamuscados y salen volando, los de más lejos salen despedidos vivos (y capaz que caen al agua). En la isla deja un cráter con la piedra al rojo que se va enfriando y humea; en el agua levanta una columna de agua y olas. También mata tiburones.
- 🌪️ **Tornado**: sacalo con T y mantené apretado el click en la isla o en el agua: baja un tornado desde su nube y lo llevás con el mouse hasta que soltás (dura 6 segundos como mucho y después tarda un poco en recargarse). Arrastra por el piso a los que están cerca, que lo miran venir con la boca abierta, y a los que agarra (vivos o cadáveres, y también a los que pasan volando por adentro) los hace girar alrededor del embudo cada vez más arriba hasta revolearlos por el aire: caen donde caigan, capaz que al agua. En el agua levanta a los que flotan y saca volando al tiburón (si cae en la isla, va saltando y comiéndose a los que alcanza); en la isla revolea los cocos, que hacen ¡bonk! si le caen a alguien.
- 🌧️ **Diluvio**: desatalo con D (otra vez D lo calma antes de tiempo). Se nubla, el cielo se pone gris, las nubes tapan al sol (o a la luna), llueve a cántaros y truena. El mar sube y el agua va tapando la isla desde la orilla, con olas que entran y salen: los aldeanos se apartan del agua y se amontonan en lo seco, pero cada tanto una ola se lleva a los que se quedaron cerca. En lo más fuerte del diluvio el agua tapa la isla entera un par de segundos y después vuelve a bajar hasta dejar seco el medio (mientras tenés a un aldeano agarrado no se ahoga). A los que agarra el agua se los lleva flotando hacia afuera y, si no los rescatás (arrastrándolos a lo seco) o el agua no baja a tiempo, se ahogan. La lluvia apaga a los que se están quemando y las antorchas (se vuelven a prender cuando para). Dura 18 segundos y después tarda en recargarse (se ve en la barrita del botón).
- 🔥 **Fuego**: sostené un aldeano arriba de la llama de una antorcha (o dejalo caer a través de ella) y en medio segundo se prende fuego. Prendido grita, corre desesperado por la isla en zigzag y le prende fuego a los que toca; de noche ilumina alrededor. Si lo tirás al agua se apaga (sale vapor y queda tiznado un rato); si no, a los 5 segundos muere carbonizado y se hace cenizas (cuenta como sacrificio). Los cadáveres también se queman, y más rápido.
- 🤧 **Gripe**: cada tanto alguien se engripa solo, y los que se llevó el agua del diluvio se pueden resfriar. Primero la incuba sin que se note (solo lo dice el carnet); después se pone pálido y verdoso, camina lento, se para a cada rato, no reza y estornuda (¡achís!): el estornudo contagia a los que tiene adelante, y quedarse pegado a un enfermo también. Al rato se cura (y queda inmune un tiempo) o se muere (cuenta como sacrificio). El carnet muestra el estado: sano, incubando gripe, enfermo de gripe, curado o muerto. Separar a los enfermos (arrastrándolos lejos de los demás) frena el contagio.
- ☠️ **Peste**: sacala con P y cada click suelta una nube verde de miasma: los aldeanos que alcanza se enferman de gripe al toque (sin incubarla y aunque estuvieran inmunes) y después se contagian solos entre ellos.
- ✨ **Curar**: sacalo con C y cada click baja un haz de luz dorada: los aldeanos que alcanza se curan de la gripe (aunque la estuvieran incubando, y quedan inmunes un rato) y, si se estaban quemando, se apagan y se les va el tizne.
- 🏝️ **Isla Expandible**: La isla tiene 7 tamaños. Empieza chica (5 aldeanos como máximo) y cada expansión sube la capacidad (hasta 26).
- 🛍️ **Tienda y Ofrendas**: cada sacrificio deja +5 ofrendas y cada aldeano vivo reza y deja +1 cada 10 segundos. En la Tienda se gastan en:
  - **Decoración**: palmeras, arbustos, flores, rocas y antorchas. Se colocan con un click sobre la isla (se cobran al colocarlas) y los aldeanos pasan por delante o por detrás según la profundidad.
  - **Armas y poderes**: la pistola se desbloquea por 60 ofrendas, el rayo por 100, el meteorito por 150, el tornado por 200, el diluvio por 250, la peste por 120 y curar por 80.
- ⚡ **Sistema de Fe / Devoción & XP**:
  - Cada sacrificio (ahogado o comido por el tiburón) da +1 XP.
  - Al llenar la barra de XP ganás un **punto de expansión**: aparecen orbes dorados "+" en los bordes de la isla. Tocá uno (o el botón "Expandir isla") y la isla crece.
  - La invocación de aldeanos consume Devoción, la cual se recarga progresivamente con el tiempo. No se puede invocar si la isla está llena.
- 💾 **Partidas guardadas**: hay 3 (en `user://save_1.cfg`, `save_2.cfg` y `save_3.cfg`; la partida de antes, `user://save.cfg`, pasa a ser la 1). Cada una se guarda sola cada 20 segundos, al salir y al volver al menú, y al elegirla se sigue donde quedó: progreso, ofrendas, compras, tamaño de la isla, aldeanos con su nombre, su número de carnet y lo que se quieren entre ellos, decoraciones, y si era de día o de noche (con la Luna de Sangre incluida). Los aldeanos que estaban volando o en el agua aparecen en la isla; los cadáveres y los cocos sueltos no se guardan. "Menú principal" en el menú de pausa guarda y vuelve al cielo, a elegir partida.
- ⚙️ **Configuración** (en el menú de inicio y en el de pausa): volumen general, música, idioma (español o inglés), pantalla completa y un contador de fotogramas por segundo (FPS) en la esquina de abajo a la derecha. Se guarda aparte de las partidas (`user://settings.cfg`).
- 🎨 **Arte 2D**: Sprites y texturas originales.

---

## 🚀 Cómo ejecutar

1. Descargá o cloná este repositorio.
2. Abrí **Godot Engine 4.7** (o superior).
3. Seleccioná **Importar** y elegí el archivo `project.godot`.
4. Presioná **F5** para ejecutar la escena principal (`res://world/world.tscn`).

---

## 🎮 Controles

- **Click Izquierdo + Arrastrar**: Agarrar un aldeano y moverlo por la pantalla.
- **Botón "Arrastrar / Seleccionar" (tecla S)**: Cambia lo que hace el click sobre los aldeanos: agarrarlos o abrir su carnet para ponerles nombre (Esc o ✕ lo cierran).
- **Soltar en la isla**: El aldeano continúa caminando normalmente (o es rescatado si estaba en el agua).
- **Soltar en el agua / vacío**: El aldeano cae y comienza a flotar / ahogarse.
- **Arrastrar el sol (o la luna) hasta el horizonte**: Se pone y sale el otro astro (día ↔ noche).
- **Tocar el sol (o la luna) 5 veces seguidas**: Activa/desactiva su versión perturbadora.
- **Botón "Invocar aldeano"**: Invoca un nuevo aldeano consumiendo 10 puntos de Devoción (si hay lugar en la isla).
- **Orbe "+" en la isla / Botón "Expandir isla"**: Gasta un punto de expansión para agrandar la isla.
- **Botón "Tienda"**: Comprar decoraciones (click en la isla para colocarlas, click derecho o Esc para terminar) y desbloquear armas y poderes.
- **Click en la aleta del tiburón + Arrastrar**: Sacarlo del agua (soltalo en el agua, tiralo o dejalo en la isla).
- **Tecla G / casilla "Pistola"**: Sacar o guardar la pistola (una vez desbloqueada en la tienda). Sirve para aldeanos y tiburones.
- **Tecla R / botón "Rayo"**: Sacar o guardar el rayo (una vez desbloqueado en la tienda). Cada click lanza un rayo; click derecho o Esc lo guardan.
- **Tecla M / botón "Meteorito"**: Sacar o guardar el meteorito (una vez desbloqueado en la tienda). Click en la isla o en el agua para tirarlo; click derecho o Esc lo guardan.
- **Tecla T / botón "Tornado"**: Sacar o guardar el tornado (una vez desbloqueado en la tienda). Mantené apretado el click en la isla o en el agua para que baje y llevalo con el mouse; al soltar se disuelve. Click derecho o Esc lo guardan.
- **Tecla D / botón "Diluvio"**: Desatar o calmar el diluvio (una vez desbloqueado en la tienda). Mientras llueve se pueden seguir agarrando aldeanos para rescatarlos.
- **Tecla P / botón "Peste"**: Sacar o guardar la peste (una vez desbloqueada en la tienda). Click sobre los aldeanos para enfermarlos; click derecho o Esc la guardan.
- **Tecla C / botón "Curar"**: Sacar o guardar curar (una vez desbloqueado en la tienda). Click sobre un aldeano para curarlo; click derecho o Esc lo guardan.
- **Rueda del mouse (o + y -)**: Zoom para acercarse o alejarse (hacia donde está el mouse); 0 vuelve al tamaño normal. De cerca, arrastrando con la rueda apretada se corre la vista. Alejándose entra la isla más grande sin chocar con los paneles.
- **Click o cualquier tecla mientras baja la cámara**: La apura hasta la isla.
- **Esc**: Menú de pausa (volumen, idioma, pantalla completa, menú principal y salir). En el menú de inicio vuelve a la pantalla principal.
