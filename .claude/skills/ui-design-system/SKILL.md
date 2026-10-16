---
name: ui-design-system
description: "Construye el design system de una app de iOS o macOS dentro de un archivo de Figma o de Pen, antes de diseñar pantallas. Susan (diseñadora) lo arma con los valores que decide Jonny desde el tema de la app: portada, color claro/oscuro/alto contraste, tipografía de Apple con tracking, espaciado, forma concéntrica, materiales y Liquid Glass, movimiento, SF Symbols, ícono y los componentes de la app con todos sus estados — como variantes y propiedades en Figma, o como variables + temas y slots en Pen. Nombres iguales al código para que /update-ui compare uno a uno. Incluye cómo usar Figma y Pen a fondo (componentes, variantes, versiones, librerías) y enseña al usuario a hacerlo a mano. Modos: completo, foundations, component <nombre>, sync (tema exportado → archivo), check (audita sin tocar), teach <tema>. Úsalo al crear un archivo de diseño nuevo, cuando un archivo no tenga sistema, o con 'design system', 'style guide', 'guías de estilo', 'tokens en Figma/Pen', 'componentes con variantes'."
---

# /ui-design-system — El sistema primero, en Figma o en Pen

Rutina ejecutable. **Susan**, la diseñadora del equipo, construye en el archivo el sistema que **Jonny** decide. Ningún archivo de diseño de una app recibe su primera pantalla sin pasar por aquí (regla de Jonny §"Archivo nuevo de Figma o Pen").

**Referencias de esta skill** (léelas según la herramienta, no de memoria):

| Archivo | Cuándo |
|---|---|
| [references/apple-elements.md](references/apple-elements.md) | Siempre: qué elementos lleva el sistema, con los valores verificados de Apple y lo que hay que medir en el kit |
| [references/figma-guide.md](references/figma-guide.md) | Si el archivo es de Figma: variables, modos, estilos, variantes, propiedades, slots, auto layout, librerías, kits de Apple, atajos |
| [references/pen-guide.md](references/pen-guide.md) | Si el archivo es de Pen: qué existe y qué no, estados con variables + temas, slots, librerías, trampas del MCP |
| [references/pen-app-reference.md](references/pen-app-reference.md) | Detalle de la app Pen (menús, botones, atajos) para enseñar paso a paso |

---

## Modos

| Comando | Qué hace |
|---|---|
| `/ui-design-system` | Sistema completo: foundations + componentes de la app + verificación |
| `/ui-design-system foundations` | Solo portada y tokens (color, tipo, espaciado, forma, materiales, movimiento, íconos) |
| `/ui-design-system component <nombre>` | Un componente o familia, con sus estados; crea solo los tokens que le falten |
| `/ui-design-system sync` | El tema cambió (JSON exportado desde Dev Tools o editado): actualiza variables del archivo sin rehacer nada |
| `/ui-design-system check` | Audita el archivo: qué falta, qué está suelto, qué no coincide con el tema. No toca nada |
| `/ui-design-system teach <tema>` | Explica cómo hacer algo a mano en Figma o en Pen ("variantes", "modo oscuro", "slots"), con el caso real del archivo |

---

## Quién hace qué

| Paso | Quién |
|---|---|
| 0 · Sonda: herramienta, plan, tema, plataformas, componentes de la app | Susan (Steve si la rutina la lanza él) |
| 1 · Valores: tema, preferencias, decisiones visuales nuevas | **Jonny** decide; Susan no inventa valores |
| 2–4 · Construcción en el archivo | **Susan** |
| 5 · Revisión | Sarah (contraste, tamaños, estados de accesibilidad) y Larry (HIG) |
| 6 · Entrega | Susan escribe en `STYLE_BRIEF.md`; Woz lo consume; `/update-ui` lo usa para comparar |

---

## Paso 0 — Sonda

1. **Herramienta y archivo.**
   - Link de Figma en la conversación o en `STYLE_BRIEF.md` → Figma. Archivo `.pen` en `Docs/Design/` o abierto en Pen (`get_app_state()`) → Pen.
   - Ninguno: pregunta **una vez** "¿Figma o Pen?". Pen es el default del equipo si el usuario no tiene preferencia (vive en el repo, en git).
   - Figma nuevo: carga `figma-create-new-file` y crea el archivo con el nombre de la app.
2. **Plan de Figma** (`whoami`): en Starter no hay modos extra; light/dark necesita Professional o dos colecciones. Dilo antes de empezar.
3. **Herramientas del MCP:**
   - Figma: `get_figma_skill` de `figma-use` (obligatoria), `figma-generate-library` y `figma-swiftui`.
   - Pen: `get_app_state()`, `read_skill()` con `pen-schema.md` y `execute.md`.
4. **Fuente de los valores:** `Themes/<tema>.json` (`.appleapplab/Themes/` en proyectos instalados), `Docs/Design/STYLE_BRIEF.md`, `PREFERENCES.md` (`.appleapplab/PREFERENCES.md`) y `DESIGN_*.md` si existen. Sin tema elegido, para y pide a Steve la fase visual: el sistema no se inventa.
5. **Plataformas:** `project.yml` (`supportedDestinations`, `platform`). iOS, macOS o ambas cambia tipografía, tamaños de control y componentes.
6. **Componentes de la app:**
   ```bash
   grep -rhoE "\bLab[A-Z][A-Za-z]+\(" --include=*.swift . | grep -v "/Packages/\|/.build/" | sort | uniq -c | sort -rn
   ```
   Más los controles del sistema que las pantallas usen (tab bar, sheets, menús, búsqueda).
7. **Estado del archivo:** vacío · parcial · con sistema. Con sistema, la rutina **reconcilia** (actualiza en sitio, conserva ids e instancias) en vez de duplicar.

## Paso 1 — Inventario y alcance

Un solo mensaje al usuario, antes de construir:

> "Design system de **Fintrol** en **Pen**, tema **Fintrol** (oscuro, Frost, acento naranja). Plataformas: iOS y macOS. Construyo: portada, color (claro/oscuro/alto contraste), tipografía iOS y macOS, espaciado, forma, materiales, movimiento, íconos y 9 componentes: LabButton, LabTextField, LabToggleRow, LabList, LabCard, LabTabBar, LabBadge, LabEmptyState, LabProgressIndicator, cada uno con sus estados. Empiezo."

Solo se detiene si hay una decisión que no está en el tema ni en las preferencias (por ejemplo, un color de error propio). Esa la decide Jonny o el usuario, en una pregunta.

## Paso 2 — Foundations, siempre en este orden

Valores y reglas de cada punto en [apple-elements.md](references/apple-elements.md). Cómo crearlos en [figma-guide.md](references/figma-guide.md) o [pen-guide.md](references/pen-guide.md).

| # | Bloque | Qué se crea | Desde |
|---|---|---|---|
| 1 | **Portada** | App, tema y fecha, plataformas, herramienta, versión del kit de Apple, y una lista de **valores medidos** (lo que Apple no publica y se tomó del kit) | Tema `name` |
| 2 | **Color** | Primitivos → semánticos. Modos Light · Dark, y Light HC · Dark HC si el plan lo permite. Semánticos del tema con su nombre de campo; semánticos del sistema como `system/label`, `system/secondaryLabel`, `system/separator`, `system/background`, `system/groupedBackground`… | `accentColor`, `backgroundColor`, `secondaryColor`, `tertiaryColor`, colores de contorno, `appearanceMode` |
| 3 | **Tipografía** | Los 11 estilos de Apple por plataforma (iOS 17 pt base; macOS 13 pt base) con peso, tamaño, interlineado y **tracking a mano**; variante enfatizada. Muestra a tamaño Large y AX3 | `fontDesign`, `fontWeight` |
| 4 | **Espaciado** | Escala 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48. Los valores sueltos del tema se redondean al paso más cercano y se anota el redondeo | `spacing` de cada patrón |
| 5 | **Forma** | Radios por componente, cápsula y la regla concéntrica (`r_inner = r_outer − padding`) con un ejemplo anidado. Esquinas continuas | `cornerStyle`, `cornerRadius` de cada patrón |
| 6 | **Materiales** | Componente **Glass** (regular/clear, claro/oscuro, tinte, presionado, Reduce Transparency, Increase Contrast) mostrado sobre contenido; materiales estándar para contenido; **material de ventana** del tema y su transparencia; fallback para iOS 17–25 / macOS 14–15 | `windowMaterial`, `transparency`, `wallpaper`, `titleBarStyle` |
| 7 | **Profundidad** | Solo lo que el tema define; sin escala de sombras inventada | `elevation` |
| 8 | **Movimiento** | Duración + rebote por patrón y la regla de Reduce Motion. Figma: variables Timing/Easing; Pen: anotado en portada | `motionSpeedMultiplier`, `duration` de cada patrón |
| 9 | **Íconos** | Hoja con los SF Symbols que usa la app, peso, escala y modo de render. En Pen, el equivalente lucide/phosphor con el nombre SF anotado | `iconRenderingMode` |
| 10 | **Ícono de la app** | Enlace a la plantilla oficial o a Icon Composer y las 6 apariencias; si es 3D, nota para Ed | — |

**Nombres = código.** Cada variable lleva el nombre del campo del tema (`accentColor`) o del semántico del sistema (`system/secondaryLabel`). En Figma, además, **code syntax iOS** con el nombre que usa SwiftUI. En Pen, la variable `$accentColor`. Así `/update-ui` compara uno a uno y un JSON exportado desde Dev Tools vuelve al archivo sin traducir.

## Paso 3 — Componentes

**Orden por dependencia:** íconos → Glass → botón → campo de texto y búsqueda → toggle, checkbox, radio → segmented, slider, stepper → fila de lista y lista → tarjeta → badge, progreso, estado vacío → barras (navegación, toolbar, tab bar, sidebar) → sheet, alert, menú.

**Del sistema o propio:**
- Si es un control del sistema sin personalizar (teclado, alert estándar, barra de estado), se **instancia del kit oficial de Apple** (Figma) o se arma una vez como referencia (Pen). No se redibuja cada vez.
- Si la app lo personaliza, es un componente propio con el nombre del `Lab*` o de la vista SwiftUI.

**Estados obligatorios** (detalle en apple-elements.md §11): normal, presionado, deshabilitado, seleccionado si aplica, **foco** siempre en campos de texto. macOS además **hover** y **anillo de foco de teclado**. Componentes de glass: claro/oscuro y tintado.

**Cómo se modela un estado — la decisión es la misma, la herramienta cambia:**

| Cambia… | Figma | Pen |
|---|---|---|
| Colores, textos, visibilidad con el mismo esqueleto | **Variante** (`State=Pressed`) | **Un componente + eje de tema** (`state: default \| pressed \| disabled \| focused`) y variables por estado |
| Mostrar u ocultar una parte | **Boolean property** | Variable booleana en `enabled` |
| Qué ícono o subcomponente | **Instance swap** con preferred instances | Reemplazo dentro de la instancia (`⌥⇧R`) o slot con sugeridos |
| El texto | **Text property** | Override de texto en la instancia |
| Contenido libre por instancia | **Slot** | **Slot** |
| La estructura completa | Otro componente | Otro componente |
| Una versión con nombre que hereda del base ("Board Column / Today") | Variante o instancia anidada en otro componente | Instancia `reusable:true` del base con su tema |

**Tamaño:** más de ~30 combinaciones de variantes → dividir en subcomponentes. Tamaños de control (mini…extraLarge) como propiedad `Size` solo si la app los usa.

**Mostrar los estados:** cada componente tiene un tablero con **instancias** de todos sus estados en claro y oscuro, lado a lado. El componente maestro queda en su página o en la fila de Components, fuera del tablero.

## Paso 4 — Organización del archivo

| Figma (páginas) | Pen (canvas, ver `/clean-canvas`) |
|---|---|
| Cover · Foundations · --- · Components (o una por familia) · Patterns · --- · Screens · Playground | Fila 1: Portada, Design System (tokens), Components, Estados. Abajo: flujo de pantallas numerado. Debajo de cada pantalla: exploraciones |

Frames de pantalla con el **mismo nombre que la vista SwiftUI**. En Figma, los nombres de página son los encabezados del panel Assets: nómbralas para quien busca.

## Paso 5 — Verificación

- [ ] Ningún valor suelto: todo relleno, borde, radio, gap y padding enlazado a una variable. Figma: recorrer nodos con `boundVariables` vacíos; Pen: buscar hexes repetidos con `Get`.
- [ ] Cada variable de color tiene valor en **todos** los modos o temas.
- [ ] Contraste: 4.5:1 texto hasta 17 pt, 3:1 desde 18 pt o negrita, en claro y oscuro (Sarah).
- [ ] Objetivos táctiles 44 pt iOS / 28 pt macOS.
- [ ] Todos los estados de cada componente, foco incluido; hover y anillo de foco en macOS.
- [ ] Glass solo en la capa funcional, mostrado sobre contenido, con su fallback anotado.
- [ ] Captura del tablero de cada componente en claro y oscuro, revisada a escala normal (texto cortado, contraste, vacíos).
- [ ] Larry: revisión rápida HIG del sistema antes de la primera pantalla.

## Paso 6 — Entrega

- `Docs/Design/STYLE_BRIEF.md`: link o ruta del archivo, colecciones y nombres de variables, lista de componentes, valores medidos del kit.
- Si el sistema reveló que el tema necesita un campo nuevo (por ejemplo, un color de error), queda como **propuesta** para AppleAppLabUI en `PROJECT_LEARNINGS.md` (Tipo: `propuesta`).
- Una línea al usuario:
  > "Sistema listo en **Fintrol.pen**: 24 variables en claro/oscuro, 22 estilos de texto (iOS y macOS), 9 componentes con 41 estados. Valores medidos del kit: 3, anotados en la portada. Siguiente: la primera pantalla."

## sync — el tema cambió

1. Lee el JSON nuevo y el anterior (`git diff Themes/<tema>.json`).
2. Actualiza **solo** las variables que cambiaron, en sitio (Figma: `setValueForMode`; Pen: `SetVariables` en modo merge, nunca `replace`). No toques ids ni instancias.
3. Captura los tableros afectados y reporta qué cambió.

## check — auditar sin tocar

Reporta, por bloque del Paso 2 y por componente: ✅ completo · 🟡 parcial (qué falta) · 🔴 ausente. Lista los valores sueltos con el nodo y la variable que debería usar. Cierra con el comando para completar: `/ui-design-system foundations` o `component <nombre>`.

## teach — cuando el usuario quiere aprender

1. Pasos numerados en la app, con los nombres exactos de paneles, botones y atajos de la guía de la herramienta.
2. Con su caso real: su componente, sus variables.
3. Si la documentación no cubre un detalle de la interfaz, dilo y propón cómo comprobarlo. No inventes un botón.
4. Ofrece hacerlo por MCP para que lo vea armado en el panel.

Temas frecuentes: "variantes en Figma", "estados en Pen sin variantes", "modo oscuro", "slots", "librería compartida", "versiones de un componente", "pasar un componente de Figma a Pen".

---

## Lo que esta rutina NO hace

- No decide la dirección visual: eso es de Jonny y del tema.
- No diseña pantallas: termina cuando el sistema está listo.
- No escribe SwiftUI: lo hace Woz; `/update-ui` compara.
- No copia valores de Apple de memoria: lo no publicado se mide en el kit 27 y se anota.
- No reconstruye un sistema existente: reconcilia en sitio.
- Nunca lee un `.pen` con `Read` o `Grep`: solo el MCP `pencil`.

## Tono

Claro, breve, visual. Dice qué creó por bloque, con conteos. En el idioma del usuario; términos de Apple, Figma y Pen en inglés.
