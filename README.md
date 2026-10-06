# 🌴 Godlings

Un prototipo de **God Game / simulación de deidades** desarrollado en **Godot 4.5** (GL Compatibility).

En **Godlings**, cuidás (o sacrificás) aldeanos en una isla flotante en medio del océano.

---

## ✨ Características

- 🏝️ **Isla Procedural / Poligonal**: Detección de límites orgánicos mediante polígonos 2D.
- 🌊 **Agua Dinámica**: Shader 2D personalizado con simulación de olas y efecto ripple (`water.gdshader`).
- 👥 **Aldeanos Interactivos**:
  - IA de vagabundeo aleatorio con giro hacia el centro de la isla en los bordes.
  - Mecánica de arrastrar y soltar (*drag & drop*) con el cursor.
  - Física de caída libre al soltarlos al vacío.
  - Flotación y balanceo en el agua, con animación paulatina de ahogo.
  - Sistema de rescate al regresarlos a tierra firme.
- ☀️ **Sol Acosador / 🌙 Luna Acosadora**: Arrastrá el sol hasta el horizonte y se pone: el cielo pasa por el atardecer, cae la noche, salen las estrellas y sube la Luna Acosadora (que no les saca los ojos de encima a los aldeanos). Bajá la luna y vuelve el día.
  - 😱 **Modo Perturbador**: tocá el sol o la luna 5 veces seguidas y se transforman. El Sol Perturbador tiene tentáculos de fuego, cuencas vacías y una sonrisa llena de dientes; la Luna Perturbadora se pone roja, sus cráteres se abren como ojos y le gotea sangre de la boca. Otros 5 toques y vuelven a la normalidad.
- 🦈 **Tiburón**: Una aleta patrulla el agua y va a por cualquier aldeano que esté flotando. Cada aldeano comido cuenta como sacrificio (+XP).
- 🏝️ **Isla Expandible**: La isla tiene 7 tamaños. Empieza chica (5 aldeanos como máximo) y cada expansión sube la capacidad (hasta 26).
- 🛍️ **Tienda y Ofrendas**: cada sacrificio deja +5 ofrendas y cada aldeano vivo reza y deja +1 cada 10 segundos. En la Tienda se gastan en:
  - **Decoración**: palmeras, arbustos, flores, rocas y antorchas. Se colocan con un click sobre la isla (se cobran al colocarlas) y los aldeanos pasan por delante o por detrás según la profundidad.
  - **Armas y poderes**: la pistola se desbloquea por 60 ofrendas; el resto viene pronto.
- ⚡ **Sistema de Fe / Devoción & XP**:
  - Cada sacrificio (ahogado o comido por el tiburón) da +1 XP.
  - Al llenar la barra de XP ganás un **punto de expansión**: aparecen orbes dorados "+" en los bordes de la isla. Tocá uno (o el botón "Expandir isla") y la isla crece.
  - La invocación de aldeanos consume Devoción, la cual se recarga progresivamente con el tiempo. No se puede invocar si la isla está llena.
- 🎨 **Arte 2D**: Sprites y texturas originales.

---

## 🚀 Cómo ejecutar

1. Descargá o cloná este repositorio.
2. Abrí **Godot Engine 4.5** (o superior).
3. Seleccioná **Importar** y elegí el archivo `project.godot`.
4. Presioná **F5** para ejecutar la escena principal (`res://world/world.tscn`).

---

## 🎮 Controles

- **Click Izquierdo + Arrastrar**: Agarrar un aldeano y moverlo por la pantalla.
- **Soltar en la isla**: El aldeano continúa caminando normalmente (o es rescatado si estaba en el agua).
- **Soltar en el agua / vacío**: El aldeano cae y comienza a flotar / ahogarse.
- **Arrastrar el sol (o la luna) hasta el horizonte**: Se pone y sale el otro astro (día ↔ noche).
- **Tocar el sol (o la luna) 5 veces seguidas**: Activa/desactiva su versión perturbadora.
- **Botón "Invocar aldeano"**: Invoca un nuevo aldeano consumiendo 10 puntos de Devoción (si hay lugar en la isla).
- **Orbe "+" en la isla / Botón "Expandir isla"**: Gasta un punto de expansión para agrandar la isla.
- **Botón "Tienda"**: Comprar decoraciones (click en la isla para colocarlas, click derecho o Esc para terminar) y desbloquear la pistola.
- **Tecla G / casilla "Pistola"**: Sacar o guardar la pistola (una vez desbloqueada en la tienda).
