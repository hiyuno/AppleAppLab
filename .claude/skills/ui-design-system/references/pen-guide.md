<!-- Copiado y adaptado de la skill personal /pen-designer (docs.pencil.dev leída 2026-10-16). Esta es la copia que distribuye AppleAppLab. -->

# Pen (pen.dev) — guía de trabajo

Guía para trabajar en **Pen** (pen.dev; el MCP y algunas rutas aún se llaman `pencil`). Dice **qué existe**, **qué no existe** y **la mejor forma** de hacer cada cosa: desde el MCP (cuando Claude edita) y desde la app (cuando el usuario quiere aprender a hacerlo). La referencia completa de la documentación está en [pen-app-reference.md](pen-app-reference.md); léela cuando necesites un detalle que aquí no está.

Antes de editar un `.pen` por MCP, **siempre**: `get_app_state()` y `read_skill()` (más `pen-schema.md` y `execute.md`). Esta guía no reemplaza esas instrucciones del MCP; las complementa con decisiones y con la forma en que el usuario lo haría a mano.

---

## Qué existe y qué no (responde esto sin adivinar)

| Pregunta típica | Respuesta | Qué usar |
|---|---|---|
| ¿Hay **variantes** de componente (como Figma)? | **No.** La documentación no las tiene. | **Variables + temas** (un componente, varios estados) o componentes separados (estructura distinta). Ver §Estados |
| ¿Hay **variables**? | **Sí**: Color, Number, String, Boolean, con **aliases** (una variable apunta a otra) | Panel **Variables** de la barra de herramientas |
| ¿Hay **temas**? | **Sí**: ejes (`mode`, `state`, `device`…) con valores; el **primer valor** es el default; los hijos heredan | Columnas del panel Variables + **Theme → Add theme** en Properties |
| ¿Hay **estilos** compartidos (text/color styles)? | **No.** `get_style` del MCP son guías visuales para el agente, no estilos del documento | Variables (+ componentes) |
| ¿Hay **slots**? | **Sí**: un frame vacío dentro de un componente → **Make slot**, con componentes sugeridos | Contenido distinto por instancia (cards, columnas) |
| ¿**Multiplayer** en tiempo real? | **No.** Colaboración = Git + share links de solo lectura | Commit del `.pen` |
| ¿Exporta **SwiftUI**? | **No** hay exportador; SwiftUI no aparece en la doc. Exporta HTML+Tailwind/CSS determinista; cualquier otro stack, pidiéndolo al agente | Para apps Apple: el código lo escribe Woz a partir del diseño (`/update-ui`) |
| ¿Importa de **Figma**? | **Sí**: archivo `.fig` completo (con imágenes) o copiar/pegar capas (**sin** imágenes) | Primitives ▸ **Import Figma**, o File ▸ Import |
| ¿Importa una **web**? | **Sí** (solo app de escritorio): ícono de globo → URL → **Import** (sin JS) o **Screenshot** | Herramienta `browser` del MCP |
| ¿Librerías compartidas? | **Sí**: **Turn this file into a library** → `*.lib.pen` (**irreversible**) | Libraries tab; los cambios se ven al reabrir el documento consumidor |

---

## Estados de un componente (la forma correcta de hacer "variantes")

**Regla de decisión:**
- Mismo esqueleto, cambian **colores, textos, números, visibilidad** → **un componente + variables con tema**. Es lo preferido: una sola fuente, se edita una vez.
- Cambia la **estructura** (otros hijos, otro layout) → **componentes separados** (`Card`, `Card / Compact`), o un **slot**.

**Receta (MCP):**
1. Eje de tema con los estados, el normal **primero** (es el default):
   ```js
   SetVariables({
     "show-play": {type:"boolean", value:[{value:true,theme:{state:"play"}},{value:false,theme:{state:"stop"}},{value:false,theme:{state:"done"}}]},
     "show-stop": {type:"boolean", value:[{value:false,theme:{state:"play"}},{value:true,theme:{state:"stop"}},{value:false,theme:{state:"done"}}]},
     "button-color": {type:"color", value:[{value:"$pill-active-bg",theme:{state:"play"}},{value:"$accent",theme:{state:"stop"}},{value:"$text-done",theme:{state:"done"}}]}
   })
   ```
   Siempre `SetVariables` en modo merge (sin `replace:true`) y con `GetVariables()` antes, para no pisar variables existentes.
2. Dentro del componente van **todos** los íconos o partes de cada estado; cada uno con `enabled:"$show-…"` y los colores en `"$button-color"`.
3. Una instancia elige su estado con `theme:{state:"stop"}`. Para componer (una fila que contiene el botón) pon el tema **en la fila**: los hijos lo heredan.
4. Para la versión con nombre ("Subtask Row / Stop"), crea una instancia `reusable:true` con `theme:{state:"stop"}` junto al original en el frame de Components.

**Trampas reales (vistas en este proyecto):**
- Un `theme` fijado en un **hijo** (o en el propio componente origen) **gana sobre el del padre**: el botón dentro de la fila se quedaba en `stop`. El origen no debe fijar tema (déjalo en `{}` y que valga el default del eje); quita `theme` de los hijos que deban heredar (`Update(path,{theme:{}})`).
- Define un valor para **cada** valor del eje en **cada** variable, o se ve mal.
- La última entrada cuyo tema coincide es la que gana.
- Un contenedor de componentes con **ancho fijo no crece** al hacer `Insert`: los nuevos empujan a los demás fuera del fondo y `ctx.problems` los marca "clipped" aunque se vean. Antes de agregar, revisa si es `fit_content`; si no, dilo o ajústalo con permiso.

**Cómo lo hace el usuario en la app:**
1. Barra de herramientas → **Variables** → pestaña del eje (p. ej. `state`) → **+** junto a los títulos de columna para un valor nuevo (p. ej. `done`); **+** junto a las pestañas para un eje nuevo.
2. **Add variable → Boolean / Color…**; llenar la celda de cada columna (puede elegir otra variable como alias).
3. En el componente origen: junto a la propiedad (visibilidad, fill, stroke…) → **Apply variable**.
4. En la instancia o en el frame que la contiene: Properties → **Theme → Add theme** → eje → valor. **Remove theme** vuelve a heredar.

---

## Componentes, instancias, slots — mejor forma

| Tarea | MCP | App |
|---|---|---|
| Crear componente | `reusable:true` en el frame | Seleccionar → **Create Component** o `⌘⌥K` (magenta = origen, violeta = instancia) |
| Instanciar | `Insert(parent,{type:"ref",ref:id, descendants:{…}})` | Copiar el origen o arrastrar desde la pestaña **Components** |
| Cambiar un hijo de una instancia | `Update(inst+"/childId",{…})` o `descendants` en el mismo `Insert`/`Copy` | Editar en la instancia (solo esa propiedad queda override) |
| Reemplazar un hijo de una instancia | `Replace(inst+"/childId",{type:…})` | `⌥⇧R` (Replace inside instance) |
| Desligar | (evitar) | **Detach instance** / `⌘⌥X` |
| Contenido distinto por instancia | `slot:[ids sugeridos]` en un frame vacío del origen; en la instancia `Replace(inst+"/slotId",{…})` e `Insert` dentro | **Make slot** en un frame vacío del origen; **+** junto a Slot para sugeridos |

- **Nunca `Replace` el componente origen** para "limpiarlo": genera un id nuevo y rompe todas sus instancias. Usa `Update`.
- Para versiones de un componente que **heredan** del base: instancia `reusable:true` del base (así se hizo `Board Column / Backlog|Today|Done` sobre `Board Column` con slots `Accessories`, `Pinned`, `Content`).
- Los slots vacíos se ven rayados en el canvas y avisan "collapsed": dales `fit_content(28)`/`fit_content(1)` de fallback.

---

## Layout y dibujo — lo que más falla

- No es CSS: **sin %**, sin `margin`, sin `alignItems: stretch/baseline`. Usa `fill_container` / `fit_content` y `gap`/`padding` en el padre.
- Un frame no puede abrazar (`fit_content`) a hijos que lo llenan (`fill_container`): colapsa.
- Texto que debe envolver: `textGrowth:"fixed-width"` + `width:"fill_container"`. El texto necesita `fill` o es invisible.
- Elementos flotantes (FAB): `layoutPosition:"absolute"` y calcula `y` con `Get(..., visit)` → `ctx.bounds` (no adivines).
- Iconos: `type:"icon"`, librerías `lucide`, `feather`, `phosphor`, `Material Symbols Outlined|Rounded|Sharp`. Si el MCP avisa "icon not found", usa el nombre real (p. ej. `circle-check`, no `check-circle`).
- App: `Shift+A` agrega flex layout; Hug/Fill en el panel; **Absolute Position** saca un hijo del flujo.

---

## Trabajar por MCP sin romper nada

1. **El documento cambia mientras trabajas** (el usuario edita a la vez). Si un id "no existe", **relee** (`get_app_state`, `Get`) en vez de recrear; no deshagas lo que el usuario hizo.
2. Lee la selección del usuario con `get_app_state()`: "este botón" = el nodo seleccionado.
3. Un `execute` que falla se revierte entero: corrige con `edits` + `editId`, no reenvíes el snippet.
4. Pantallas nuevas en la raíz con `FindEmptySpace` y `placeholder:true` mientras trabajas; quítalo al terminar cada pantalla.
5. Verifica con `Get(..., (n,c)=>c.problems&&…)` y `TakeScreenshot` del nodo más pequeño que importe. Avisos "clipped" dentro de un frame aún `placeholder` suelen ser falsos positivos: confírmalos con la captura.
6. Captura de un frame **transparente** sale sobre blanco: los rellenos semitransparentes se ven claros. Captura el frame contenedor oscuro para juzgar color.
7. Tokens de la app → `SetVariables`; nunca hexes sueltos repetidos. Fuente: ver §Tipografía en `../SKILL.md` (SF Pro si está instalada en la Mac; si no, Inter con las métricas de Apple y se anota).
8. Nunca leas el `.pen` con `Read`/`Grep` (el MCP lo trata como cifrado/opaco) ni edites su JSON a mano.

---

## Diseño ↔ código

- **HTML**: Properties ▸ **Code** ▸ **HTML + Tailwind** / **HTML + CSS** ▸ **Copy/Export HTML** (`⌘⌥C`), o `Export([ids],"html-tailwind",path)` por MCP. Determinista, sin agente.
- **React/Vue/Svelte/Next, shadcn, Tailwind…**: pidiéndolo al agente de Pen o a Claude con el `.pen` en el mismo workspace.
- **SwiftUI (apps del equipo)**: no hay exportador. El diseño es la fuente; Woz implementa y `/update-ui` compara pantalla ↔ frame (colores, padding, radios, tipografía) leyendo variables con `GetVariables()`.
- **Código → diseño**: "Recrea el componente X de `src/…`" con el `.pen` en el repo; revisar estructura y estilos después.
- Sincronizar tokens: variables de Pen ↔ CSS/Assets por petición explícita al agente; revisar ambos lados.

---

## Archivos, Git y librerías

- El `.pen` vive en el repo junto al código (convención del equipo: `Docs/Design/<App>.pen`). Guarda (`⌘S`) y **cierra** antes de cambiar de rama o hacer pull; conflictos se resuelven **dentro de Pen** (elige una versión base y reaplica la otra), nunca en el JSON.
- Mantén imágenes, fuentes y librerías en rutas relativas estables; las fuentes custom son por documento.
- Abrir un `.pen` en una versión nueva de Pen lo migra al guardar: respalda antes.
- Librería: guardar → Libraries ▸ **Turn this file into a library** (irreversible, queda `*.lib.pen`). Consumidores: Libraries ▸ **+** junto a Imported Libraries. Los cambios llegan al **reabrir** el consumidor; los overrides de instancias se conservan.
- Compartir: **Share → Create share link** (cualquiera con el link ve y descarga; revocar con **Delete share link**).

---

## Atajos que conviene enseñar

`⌘K` chat · `⌘⌥K` crear componente · `⌘⌥X` detach · `⌥⇧R` reemplazar dentro de instancia · `Shift+A` flex layout · `⌘⌥G` envolver en frame · `⌘G`/`⌘⇧G` agrupar/desagrupar · `⌘D` duplicar · `⌘⇧C` copiar como PNG · `⌘⌥C` copiar como HTML · `Shift+1`/`Shift+2` encuadrar todo/selección · `⌘0` 100% · `?` lista completa. Herramientas: V mover, F/A frame, R rect, O elipse, T texto, P pluma, N nota, K escala, H mano.

---

## Cuando el usuario pregunta "¿cómo lo hago yo?"

Explícale el camino en la app (paneles y botones exactos de esta skill o de [pen-app-reference.md](pen-app-reference.md)), en pasos numerados, y ofrece hacerlo por MCP. Si la documentación no cubre un detalle de la interfaz, dilo ("la documentación lo describe para frames; para instancias debería ser igual") en vez de inventar un botón.

Fuente: https://docs.pencil.dev (24 páginas, leídas 2026-10-16) + experiencia con el MCP `pencil` en ToDoPro.
