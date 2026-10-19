# 🌴 Godlings

Un prototipo de **God Game / simulación de deidades** desarrollado en **Godot 4.7** (GL Compatibility).

En **Godlings**, cuidás (o sacrificás) aldeanos en una isla flotante en medio del océano.

---

## ✨ Características

- 🏝️ **Isla Procedural / Poligonal**: Detección de límites orgánicos mediante polígonos 2D.
- 🌊 **Mar vivo** (`water.gdshader`): olas en perspectiva (chiquitas en el horizonte) con crestas de espuma que avanzan y cambian de forma, el reflejo del sol o la luna (largo y naranja al atardecer, rojo con la Luna de Sangre) y destellos sueltos. De lejos refleja el color del cielo. Alrededor de la isla hay una laguna turquesa con espuma en la orilla y olitas que salen (sigue la forma de la isla cuando crece), y lo que cae al agua (aldeanos, cocos, el tiburón, el meteorito) deja anillos.
- ☁️ **Nubes y gaviotas**: nubes que pasan despacio (las lejanas, más chicas y lentas) y cambian de color con la hora: blancas de día, rosadas al atardecer, azul oscuro de noche y bordó con la Luna de Sangre; cada rayo las ilumina. De día, cada tanto cruza una bandadita de gaviotas.
- 👥 **Aldeanos Interactivos**:
  - IA de vagabundeo aleatorio con giro hacia el centro de la isla en los bordes.
  - Mecánica de arrastrar y soltar (*drag & drop*) con el cursor.
  - Física de caída libre al soltarlos al vacío.
  - Flotación y balanceo en el agua, con animación paulatina de ahogo.
  - Sistema de rescate al regresarlos a tierra firme.
  - 🪪 **Carnet**: en modo *Seleccionar*, un click sobre un aldeano abre su carnet con foto (parpadea, y si se muere pone ojos en X), número, género y campos para ponerle nombre y apellido. El nombre queda flotando arriba de su cabeza.
- ☀️ **Sol Acosador / 🌙 Luna Acosadora**: Arrastrá el sol hasta el horizonte y se pone: el cielo pasa por el atardecer, cae la noche, salen las estrellas y sube la Luna Acosadora (que no les saca los ojos de encima a los aldeanos). Bajá la luna y vuelve el día.
  - 😱 **Modo Perturbador**: tocá el sol o la luna 5 veces seguidas y se transforman. El Sol Perturbador tiene tentáculos de fuego, cuencas vacías y una sonrisa llena de dientes; la Luna Perturbadora se pone roja, sus cráteres se abren como ojos y le gotea sangre de la boca. Otros 5 toques y vuelven a la normalidad.
- 🦈 **Tiburón**: Una aleta patrulla el agua y va a por cualquier aldeano que esté flotando. Cada aldeano comido cuenta como sacrificio (+XP). Se lo puede agarrar de la aleta y sacar del agua: se sacude colgando, se lo puede tirar y, si cae en la isla, va saltando con la boca abierta y se come a los aldeanos que alcanza hasta volver al agua. Con la pistola, el rayo o el meteorito se lo puede matar (queda panza arriba) y hay que volver a comprarlo en la tienda.
- 🌩️ **Rayo**: sacalo con R y una nube de tormenta sigue al mouse; cada click descarga un rayo que ilumina todo (también de noche). El aldeano alcanzado se electrocuta: tiembla tieso con los brazos abiertos y en los destellos se le ve el esqueleto, queda carbonizado y humeando, y se deshace en cenizas de la cabeza a los pies (si estaba volando, cae carbonizado y se deshace al quedar tirado). El rayo salta a los que están cerca, y si cae en el agua la descarga fríe a todos los que flotan alrededor, tiburones incluidos. Deja una quemadura en la arena y un montoncito de cenizas.
- ☄️ **Meteorito**: sacalo con M y apuntá a la isla o al agua: cae un meteorito en llamas (los aldeanos que están cerca lo miran venir con la boca abierta) y explota con una bola de fuego que hace temblar todo. Los de cerca mueren chamuscados y salen volando, los de más lejos salen despedidos vivos (y capaz que caen al agua). En la isla deja un cráter con la piedra al rojo que se va enfriando y humea; en el agua levanta una columna de agua y olas. También mata tiburones.
- 🏝️ **Isla Expandible**: La isla tiene 7 tamaños. Empieza chica (5 aldeanos como máximo) y cada expansión sube la capacidad (hasta 26).
- 🛍️ **Tienda y Ofrendas**: cada sacrificio deja +5 ofrendas y cada aldeano vivo reza y deja +1 cada 10 segundos. En la Tienda se gastan en:
  - **Decoración**: palmeras, arbustos, flores, rocas y antorchas. Se colocan con un click sobre la isla (se cobran al colocarlas) y los aldeanos pasan por delante o por detrás según la profundidad.
  - **Armas y poderes**: la pistola se desbloquea por 60 ofrendas, el rayo por 100 y el meteorito por 150; el resto viene pronto.
- ⚡ **Sistema de Fe / Devoción & XP**:
  - Cada sacrificio (ahogado o comido por el tiburón) da +1 XP.
  - Al llenar la barra de XP ganás un **punto de expansión**: aparecen orbes dorados "+" en los bordes de la isla. Tocá uno (o el botón "Expandir isla") y la isla crece.
  - La invocación de aldeanos consume Devoción, la cual se recarga progresivamente con el tiempo. No se puede invocar si la isla está llena.
- 💾 **Partida guardada**: se guarda sola cada 20 segundos y al salir (en `user://save.cfg`), y al abrir el juego se sigue donde quedó: progreso, ofrendas, compras, tamaño de la isla, aldeanos con su nombre y número de carnet, decoraciones, y si era de día o de noche (con la Luna de Sangre incluida). Los aldeanos que estaban volando o en el agua aparecen en la isla; los cadáveres y los cocos sueltos no se guardan. "Nueva partida" en el menú de pausa borra todo y empieza de cero.
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
- **Esc**: Menú de pausa (volumen, idioma, nueva partida y salir).
