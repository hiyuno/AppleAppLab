---
name: update-ui
description: "Rutina de paridad UI↔diseño. Compara una pantalla o un fragmento (nombre de pantalla o screenshot) contra su frame en la fuente de diseño del proyecto — Figma o Pen (pen.dev, archivos .pen vía MCP 'pencil') — en colores, padding, alineación, tipografía y corner radius, y actualiza el código para que coincida exactamente. Detecta la fuente sola (link de Figma, .pen en el repo o archivo activo en Pen). Woz aplica los fixes, Steve verifica con build + screenshot en simulador. Úsalo cuando el usuario diga 'revisa esto contra Figma / contra Pen / contra el diseño', 'actualiza esta pantalla completa', o pegue un screenshot pidiendo que se vea igual al diseño."
---

# /update-ui — Auditoría de paridad UI contra el diseño (Figma o Pen)

Rutina del equipo, no un agente. Steve compara el estado real de una pantalla (o un fragmento de ella) contra su frame en la **fuente de diseño del proyecto** — Figma o Pen — y corrige cada diferencia en el código — no solo lo que se ve mal a simple vista, sino todo lo que el frame define: color, spacing, alineación, tipografía, radios, iconografía.

La rutina es la misma con las dos fuentes; cambian solo los tools con los que Steve extrae la verdad del diseño (tabla en "Fuentes de diseño").

**A diferencia de `/optimize-app` o `/architecture-audit`, esta rutina no se detiene en un plan.** Los cambios de paridad visual son de bajo riesgo y reversibles (son estilos, no arquitectura) — Woz los aplica en el momento, Steve los verifica visualmente, y solo pausa a pedir confirmación si el fix implica algo estructural (mover una vista a otro archivo, cambiar un modelo, tocar navegación).

---

## Cómo se dispara

| Entrada | Qué hace Steve |
|---|---|
| `/update-ui <nombre de pantalla>` (ej. `/update-ui Quincena`, `/update-ui Home`) | Busca el frame con ese nombre en la fuente de diseño del proyecto y audita la pantalla completa |
| `/update-ui` + un screenshot de una parte específica | Usa el screenshot para acotar el alcance a ESA parte — no re-audita la pantalla entera — y ubica el frame/capa que corresponde a esa región |
| `/update-ui <nombre>` + screenshot | Ambos — el nombre desambigua la pantalla si el screenshot por sí solo es ambiguo (ej. dos pantallas comparten un componente parecido) |
| `/update-ui figma <nombre>` · `/update-ui pen <nombre>` | Fuerza la fuente cuando el proyecto tiene las dos |

Si Steve no puede identificar con confianza qué frame corresponde (nombre no encontrado, screenshot no reconocible), pregunta — una sola pregunta, mostrando las opciones más probables — en vez de adivinar.

---

## Fuentes de diseño — Figma o Pen

### Detección (en este orden, sin preguntar salvo empate)

1. El usuario escribió `figma` / `pen`, pegó un link de Figma, o dijo "contra Pen" → esa.
2. La conversación o `PRD.md` / `DESIGN_LIQUID.md` / `STYLE_BRIEF.md` ya nombran un `fileKey` de Figma o una ruta `.pen` → esa.
3. Hay un `*.pen` en el repo (`find . -name "*.pen" -not -path "*/.git/*"`) → Pen, ese archivo.
4. El MCP `pencil` responde y `get_app_state` muestra un archivo activo → Pen, el archivo activo (Steve lo nombra al usuario: *"Uso el .pen abierto en Pen: pencil-new.pen. ¿Es este?"* solo si el nombre no coincide con la app).
5. Nada → Steve pregunta una vez: link de Figma o abrir el `.pen` en Pen.

Si hay las dos fuentes y ambas tienen un frame con el nombre pedido, Steve pregunta cuál manda — y anota la respuesta en `DESIGN_LIQUID.md` como "fuente de verdad de UI" para no volver a preguntar.

### Tools equivalentes

| Necesito | Figma (MCP `figma`) | Pen (MCP `pencil`) |
|----------|---------------------|--------------------|
| Saber qué frames existen y sus ids | `get_metadata` sobre la página | `get_app_state` (archivo activo, frames raíz con id y nombre) · o `execute`: `Get(n => c.depth===0 && Print(n.id, n.name))` |
| Localizar un frame por nombre | `get_metadata` | `execute`: `Get(n => n.name === "Home" && Print(n.id))` — si hay varios, todos y Steve elige por contexto |
| Verdad del diseño: capas, valores, geometría | `get_design_context` + `get_metadata` | `execute`: `Print(Get(frameId, {depth: 6, resolveVariables: true, resolveInstances: true}))` — cada capa con `fill`, `fontSize`, `fontWeight`, `cornerRadius`, `padding`, `gap`, `alignItems`, `justifyContent` ya resueltos |
| Spacing exacto entre capas | x/y/width/height de `get_metadata` | `execute` con visitor y `ctx.bounds`: `Get(frameId, (n,c) => Print(n.name, c.bounds.x, c.bounds.y, c.bounds.width, c.bounds.height))` — bounds resueltos en coordenadas del padre; padding y gaps salen por diferencia |
| Tokens / variables | `get_variable_defs` | `execute`: `Print(GetVariables())` — colores, números y strings, con temas (`mode: light/dark`) |
| Screenshot de referencia | `get_screenshot` | `execute`: `TakeScreenshot([frameId])` — del frame o de la capa más pequeña relevante, no del documento |
| Geometría de un icono/path | `get_design_context` assets | `execute`: `Print(Get(nodeId, {includePathGeometry: true}))` |
| Componentes reutilizables e instancias | `get_metadata` (COMPONENT / INSTANCE) | `reusable: true` en el nodo base; `type: "ref"` con `descendants` en la instancia. Leer con `resolveInstances: true` para ver el árbol expandido |

### Reglas propias de Pen

- **Los `.pen` están cifrados.** Solo se leen con el MCP `pencil`. Nunca `Read`, `Grep` ni `cat` sobre un `.pen`; nunca se parchea a mano.
- **Solo lectura en esta rutina.** `update-ui` extrae la verdad del diseño y cambia el código. No usa `Insert`/`Update`/`Delete` sobre el `.pen`: si el diseño está mal o incompleto, Steve pregunta y, si hay que cambiarlo, es Jonny en Pen, no esta rutina.
- **Pen no es CSS.** `padding` puede ser número, `[v, h]` o `[t, r, b, l]`; `cornerRadius` número o `[4 esquinas]`; `fill` puede ser un color, una lista de fills o un `$variable`. Steve resuelve con `resolveVariables: true` y traduce a SwiftUI con los tokens del proyecto, no copia el hex.
- **`fill_container` / `fit_content`** en Pen equivalen a `.frame(maxWidth: .infinity)` / tamaño intrínseco en SwiftUI; `layout: "vertical"|"horizontal"` con `gap` → `VStack`/`HStack(spacing:)`; `alignItems`/`justifyContent` → `alignment` y `Spacer`. Un frame simétrico en Pen (mismo padding a ambos lados) → el contenido va centrado, igual que con Figma.
- **Iconos.** Pen usa librerías web (`lucide`, `phosphor`, Material Symbols). En SwiftUI se mapean al SF Symbol equivalente; Steve anota el mapeo en `DESIGN_LIQUID.md` la primera vez que aparece cada icono para no re-decidirlo.
- **Un `.pen` en el repo** va en `Design/` (`clean-folder-project` lo respeta) y se rastrea en git como binario; Ivan no lo trata como secreto porque el cifrado es de formato, no de contenido sensible — salvo que el diseño incluya datos reales de usuarios en mockups, que no debería.
- **Multiplayer.** El documento puede cambiar mientras Steve lo lee. Si un id no aparece, re-lee con `get_app_state`; no asumas que se borró.

---

## Antes de empezar

- **La fuente de diseño** — detectada como arriba. Si esta conversación ya tiene un `fileKey` de Figma o un `.pen` en uso, Steve lo reutiliza sin preguntar.
- **`DESIGN_LIQUID.md`** (o el doc de diseño del proyecto), si existe — convenciones ya cerradas (tokens, spacing base, tabla de radios, mapeo de iconos Pen → SF Symbols) para no reinventar cada vez.
- **Tokens primero.** Si el diseño tiene variables (colección "Tokens" en Figma; `GetVariables()` en Pen), Steve las lee antes que cualquier capa — los valores resueltos ahí son la fuente de verdad, no el hex que aparezca hardcodeado en una capa vieja que no se haya vuelto a tocar.

---

## Fase 1 — Ubicar el frame (Steve)

1. Figma: `get_metadata` sobre la página/nodo relevante. Pen: `get_app_state` y, si el nombre no está en los frames raíz, `execute` con visitor por nombre. En ambos casos se confirma nombre exacto e id.
2. Si la entrada fue un screenshot de un fragmento, acota el alcance a esa región — no asumas que el resto de la pantalla también cambió. En Pen, la región se ubica bajando por `Get(frameId, {depth: 2})` hasta el subframe que coincide con el screenshot.

## Fase 2 — Extraer la verdad del diseño (Steve)

Para el/los nodo(s) del frame, con los tools de la tabla de arriba según la fuente:
- **Capas y valores resueltos** — Figma `get_design_context`; Pen `Get(frameId, {depth: 6, resolveVariables: true, resolveInstances: true})`.
- **Tokens** — Figma `get_variable_defs`; Pen `GetVariables()` — valores de color/tipografía resueltos a variables, no solo el hex de una capa suelta.
- **Spacing exacto** — Figma x/y/width/height de `get_metadata`; Pen `ctx.bounds` del visitor — de donde salen padding y gaps por diferencia entre elementos (ej. un row simétrico → el texto debe estar centrado, no en `.leading`).
- **Screenshot de referencia** — Figma `get_screenshot`; Pen `TakeScreenshot([frameId])`. Se guarda mentalmente para la Fase 6, no se vuelve a pedir.

## Fase 3 — Ubicar el código actual (Steve, o Explore si el archivo no es obvio)

Encuentra el/los archivo(s) SwiftUI que implementan esa pantalla o fragmento. Si no es evidente por el nombre, usa un agente Explore para ubicarlo antes de tocar nada.

## Fase 4 — Diff sistemático

Para cada elemento visible en el frame, compara contra el código actual en este orden (colores y spacing son los que más se desalinean con el tiempo, así que van primero):

| Categoría | Qué revisar |
|---|---|
| Color | Fills, texto, bordes — contra los tokens/variables del diseño (Figma o `GetVariables()` de Pen), no a ojo |
| Padding / spacing | Márgenes internos, gaps entre elementos, tamaño de containers |
| Alineación | `.leading`/`.center`/`.trailing` — si el frame es simétrico (mismo margen a ambos lados) el código debe centrar, no alinear a la izquierda por default |
| Tipografía | Tamaño, peso, tracking — contra la tabla de tipos del proyecto (`h1`–`h5`, `p big`, etc.) si existe |
| Corner radius | Contra la tabla de radios del proyecto si existe (cards / elementos internos / botones-chips / sheets suelen ser radios distintos) |
| Iconografía | SF Symbol correcto. Si Figma usa un `*.circle.fill`, o Pen un icono `lucide`/`phosphor` dentro de un círculo, como proxy visual de un botón nativo (ej. `.buttonStyle(.glass)`), no tomarlo literal — revisa si el proyecto ya tiene el patrón real en un botón similar (ej. los chevrons de navegación) antes de dibujar un círculo manual. Iconos de Pen → SF Symbol equivalente, mapeo anotado en `DESIGN_LIQUID.md` |

## Fase 5 — Aplicar (Woz)

Corrige cada diferencia real. Si un fix es puramente de estilo (color, padding, alineación, fuente), se aplica directo. Si implica algo estructural — mover una vista, cambiar cómo se pasa un parámetro, tocar un modelo — Steve lo dice explícitamente y pide confirmación antes de aplicar solo esa parte.

## Fase 6 — Verificar (Steve)

1. Build.
2. Correr en el simulador fijo del proyecto (o el que esté configurado en la memoria de la sesión). En macOS, la app en la ventana real.
3. **Chequeo de los cuatro bordes — con números, no a ojo.** Para el elemento más externo de cada lado (título arriba, botones del pie abajo, primer campo a la izquierda, último control a la derecha), mide su frame real (resumen de accesibilidad del screenshot de la app, o un `debugOutline`) y compara su distancia al borde de la pantalla/ventana contra los `bounds` del diseño (Pen `ctx.bounds`; Figma `get_metadata`). Tolerancia: 1 pt. Si algo toca el borde o lo pasa, la verificación **falla**, aunque "se vea bien".
4. **Capturas con margen.** Todo screenshot/zoom de verificación incluye ~20 pt **fuera** de la ventana o pantalla. Un recorte que termina exactamente en el borde oculta un corte: el botón cortado parece un botón normal.
5. Screenshot de la pantalla/fragmento y comparación visual contra el screenshot del diseño (Figma `get_screenshot`; Pen `TakeScreenshot([frameId])`).
6. Si el usuario está probando en dispositivo real durante la sesión, instalar ahí también una vez confirmado en el simulador.

**Si algo sale mal: medir antes de corregir.** No se aplica un fix de layout sin haber medido el frame real y confirmado la causa (qué contenedor propone qué tamaño). Un fix por suposición que no arregla nada cuesta una vuelta completa de build + verificación. Si el primer fix falla, pasa a `/global-fix` en vez de encadenar suposiciones.

**Si el fix cambió cómo se presenta una vista** (sheet ↔ overlay ↔ inline ↔ popover ↔ ventana propia), el chequeo de los cuatro bordes se repite para esa vista **y** para la vista/ventana que la contiene: cambiar el contenedor cambia la propuesta de tamaño y el safe area (ver `KNOWN_ISSUES.md` AAL-MAC-015).

---

## Lo que esta rutina NO hace

- No rediseña — si algo en Figma o en el `.pen` es ambiguo o está incompleto, Steve pregunta, no inventa. Y no escribe en el `.pen`: cambiar el diseño es de Jonny en Pen, no de esta rutina.
- No toca lógica de negocio, modelos, o flujos de navegación — solo lo visual. Si al auditar aparece un bug funcional de paso, se reporta aparte (no se mezcla en el mismo fix).
- No reemplaza a `/larry` (HIG) ni a `/sarah` (accesibilidad) — paridad con el diseño no garantiza que el diseño en sí cumpla HIG o sea accesible; si Steve nota algo ahí, lo señala pero no lo resuelve dentro de esta rutina.
- No usa el `browser` de Pen ni `Export` a HTML: eso es para web; aquí el destino siempre es SwiftUI.

## Tono

Reporta lo que cambió por categoría (color, spacing, alineación...), no una narración de cada tool call, y di en una línea qué fuente usó ("contra `Home` en Figma" / "contra `Home` en `Design/app.pen`"). Si algo en el diseño ya coincidía con el código, no lo menciones — solo lo que se corrigió.
