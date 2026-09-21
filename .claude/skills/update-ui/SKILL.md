---
name: update-ui
description: "Rutina de paridad UI↔Figma. Compara una pantalla o un fragmento (nombre de pantalla o screenshot) contra su frame en Figma — colores, padding, alineación, tipografía, corner radius — y actualiza el código para que coincida exactamente. Woz aplica los fixes, Steve verifica con build + screenshot en simulador. Úsalo cuando el usuario diga 'revisa esto contra Figma', 'actualiza esta pantalla completa', o pegue un screenshot pidiendo que se vea igual al diseño."
---

# /update-ui — Auditoría de paridad UI contra Figma

Rutina del equipo, no un agente. Steve compara el estado real de una pantalla (o un fragmento de ella) contra su frame en Figma, y corrige cada diferencia en el código — no solo lo que se ve mal a simple vista, sino todo lo que el frame define: color, spacing, alineación, tipografía, radios, iconografía.

**A diferencia de `/optimize-app` o `/architecture-audit`, esta rutina no se detiene en un plan.** Los cambios de paridad visual son de bajo riesgo y reversibles (son estilos, no arquitectura) — Woz los aplica en el momento, Steve los verifica visualmente, y solo pausa a pedir confirmación si el fix implica algo estructural (mover una vista a otro archivo, cambiar un modelo, tocar navegación).

---

## Cómo se dispara

| Entrada | Qué hace Steve |
|---|---|
| `/update-ui <nombre de pantalla>` (ej. `/update-ui Quincena`, `/update-ui Home`) | Busca el frame con ese nombre en el archivo de Figma conocido del proyecto y audita la pantalla completa |
| `/update-ui` + un screenshot de una parte específica | Usa el screenshot para acotar el alcance a ESA parte — no re-audita la pantalla entera — y ubica el frame/capa de Figma que corresponde a esa región |
| `/update-ui <nombre>` + screenshot | Ambos — el nombre desambigua la pantalla si el screenshot por sí solo es ambiguo (ej. dos pantallas comparten un componente parecido) |

Si Steve no puede identificar con confianza qué frame de Figma corresponde (nombre no encontrado, screenshot no reconocible), pregunta — una sola pregunta, mostrando las opciones más probables — en vez de adivinar.

---

## Antes de empezar

- **El archivo de Figma.** Si esta conversación ya tiene un `fileKey` en uso (mencionado antes, o referenciado en `PRD.md`/`DESIGN_LIQUID.md`), Steve lo reutiliza sin preguntar. Si no hay ninguno conocido, pide el link de Figma una vez.
- **`DESIGN_LIQUID.md`** (o el doc de diseño del proyecto), si existe — convenciones ya cerradas (tokens, spacing base, tabla de radios) para no reinventar cada vez.
- Si el proyecto tiene una colección de variables de Figma ("Tokens"), Steve la lee primero (`get_variable_defs` sobre el nodo) — los valores resueltos ahí son la fuente de verdad, no el hex que aparezca hardcodeado en una capa vieja que no se haya vuelto a tocar.

---

## Fase 1 — Ubicar el frame (Steve)

1. `get_metadata` sobre la página/nodo relevante para confirmar el nombre exacto y el `nodeId`.
2. Si la entrada fue un screenshot de un fragmento, acota el alcance a esa región — no asumas que el resto de la pantalla también cambió.

## Fase 2 — Extraer la verdad del diseño (Steve)

Para el/los nodo(s) del frame:
- `get_design_context` — código de referencia, screenshot, y assets.
- `get_variable_defs` — valores de color/tipografía resueltos a variables, no solo el hex de una capa suelta.
- `get_metadata` — spacing exacto: x/y/width/height de cada capa relevante, de donde salen padding y gaps por diferencia entre elementos (ej. un row simétrico → el texto debe estar centrado, no en `.leading`).

## Fase 3 — Ubicar el código actual (Steve, o Explore si el archivo no es obvio)

Encuentra el/los archivo(s) SwiftUI que implementan esa pantalla o fragmento. Si no es evidente por el nombre, usa un agente Explore para ubicarlo antes de tocar nada.

## Fase 4 — Diff sistemático

Para cada elemento visible en el frame, compara contra el código actual en este orden (colores y spacing son los que más se desalinean con el tiempo, así que van primero):

| Categoría | Qué revisar |
|---|---|
| Color | Fills, texto, bordes — contra los tokens/variables de Figma, no a ojo |
| Padding / spacing | Márgenes internos, gaps entre elementos, tamaño de containers |
| Alineación | `.leading`/`.center`/`.trailing` — si el frame es simétrico (mismo margen a ambos lados) el código debe centrar, no alinear a la izquierda por default |
| Tipografía | Tamaño, peso, tracking — contra la tabla de tipos del proyecto (`h1`–`h5`, `p big`, etc.) si existe |
| Corner radius | Contra la tabla de radios del proyecto si existe (cards / elementos internos / botones-chips / sheets suelen ser radios distintos) |
| Iconografía | SF Symbol correcto, y si Figma usa un `*.circle.fill` como proxy visual de un botón nativo (ej. `.buttonStyle(.glass)`), no tomarlo literal — revisa si el proyecto ya tiene el patrón real en un botón similar (ej. los chevrons de navegación) antes de dibujar un círculo manual |

## Fase 5 — Aplicar (Woz)

Corrige cada diferencia real. Si un fix es puramente de estilo (color, padding, alineación, fuente), se aplica directo. Si implica algo estructural — mover una vista, cambiar cómo se pasa un parámetro, tocar un modelo — Steve lo dice explícitamente y pide confirmación antes de aplicar solo esa parte.

## Fase 6 — Verificar (Steve)

1. Build.
2. Correr en el simulador fijo del proyecto (o el que esté configurado en la memoria de la sesión).
3. Screenshot de la pantalla/fragmento y comparación visual contra el screenshot de Figma (`get_screenshot`).
4. Si el usuario está probando en dispositivo real durante la sesión, instalar ahí también una vez confirmado en el simulador.

---

## Lo que esta rutina NO hace

- No rediseña — si algo en Figma es ambiguo o está incompleto, Steve pregunta, no inventa.
- No toca lógica de negocio, modelos, o flujos de navegación — solo lo visual. Si al auditar aparece un bug funcional de paso, se reporta aparte (no se mezcla en el mismo fix).
- No reemplaza a `/larry` (HIG) ni a `/sarah` (accesibilidad) — paridad con Figma no garantiza que el diseño en sí cumpla HIG o sea accesible; si Steve nota algo ahí, lo señala pero no lo resuelve dentro de esta rutina.

## Tono

Reporta lo que cambió por categoría (color, spacing, alineación...), no una narración de cada tool call. Si algo en Figma ya coincidía con el código, no lo menciones — solo lo que se corrigió.
