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
- ⚡ **Sistema de Fe / Devoción & XP**:
  - Ganancia de XP por sacrificios en el agua.
  - La invocación de aldeanos consume Devoción, la cual se recarga progresivamente con el tiempo.
- 🎨 **Arte 2D**: Sprites y texturas originales.

---

## 🚀 Cómo ejecutar

1. Descargá o cloná este repositorio.
2. Abrí **Godot Engine 4.5** (o superior).
3. Seleccioná **Importar** y elegí el archivo `project.godot`.
4. Presioná **F5** para ejecutar la escena principal (`res://world.tscn`).

---

## 🎮 Controles

- **Click Izquierdo + Arrastrar**: Agarrar un aldeano y moverlo por la pantalla.
- **Soltar en la isla**: El aldeano continúa caminando normalmente (o es rescatado si estaba en el agua).
- **Soltar en el agua / vacío**: El aldeano cae y comienza a flotar / ahogarse.
- **Botón "Spawn Villager"**: Invoca un nuevo aldeano consumiendo 10 puntos de Devoción.
