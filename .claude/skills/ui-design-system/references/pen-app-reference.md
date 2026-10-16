<!-- Copiado y adaptado de la skill personal /pen-designer (docs.pencil.dev leída 2026-10-16). Esta es la copia que distribuye AppleAppLab. -->

# Pen (pen.dev) — referencia completa de docs.pencil.dev

Leída el 2026-10-16 (24 páginas, todas HTTP 200; el home dice "last updated October 13, 2026"). No existen `/changelog`, `/faq`, `/release-notes`, `/core-concepts/themes` ni `/core-concepts/styles`. La marca ahora es **pen.dev**; "Pencil" sigue en el MCP `pencil`, el global `pencil` de scripts, `~/.pencil/`, `pencil_cli_` y `highagency/pencil-scripts`.

[INFERENCIA] = interpretación propia, no dicho por la doc.

Páginas: `/`, `/getting-started/{installation,authentication,ai-integration,create-your-first-design}`, `/core-concepts/{pen-files,design-as-code,pencil-interface,drawing-and-editing,ai-agents,variables,components,slots,code-on-canvas,design-libraries,build-a-design-system,import-and-export,sharing,presentations,keyboard-shortcuts}`, `/design-and-code/design-to-code`, `/troubleshooting`, `/for-developers/{the-pen-format,pen-cli}`.

---

## 1. Qué es
Herramienta de diseño vectorial que corre dentro del IDE (VS Code / Cursor), como app de escritorio o como CLI headless. Diseño y desarrollo en un mismo entorno; agentes de IA mantienen ambos consistentes. Documentos `.pen`.

## 2. Instalación y configuración
- **App:** macOS (DMG), Windows (instalador), Linux (AppImage/tarball, x64/ARM64). Versión/actualizar: menú **pen.dev** (macOS) o **Help** → **About Pen** / **Check for Updates…**.
- **Extensión IDE:** buscar "pen.dev" → **Install** → abrir/crear `*.pen`. Si abre como texto: **pen.dev: Toggle Design Mode**. También **pen.dev: New File**, **pen.dev: Open Welcome File**.
- **CLI:** `npm install -g @pen.dev/cli` (Node ≥ 22.19); `pen version` (no `--version`).
- **Cuenta:** código por email o contraseña. **Settings (⚙️) → Account** (Sign Out, Current workspace, Personal). Modelos **pen.dev Pro** usan la cuenta; **Upgrade** para planes.
- **Proveedores de IA:** **Settings → Agents**: OpenAI/Codex, Anthropic Claude Code (settings existentes, API key, Pro/Max, Bedrock, Vertex, Foundry, custom), Gemini, Cursor, Copilot, Meta, xAI, Kimi, OpenRouter, Moonshot, Deepseek, Together, Fireworks, Z.AI, OpenCode, endpoints compatibles. Estados: **Connected Automatically / Connected / Signed in / API key set / Configured**; **External config** para Bedrock/Vertex/Foundry/custom. **Clear**, **Re-check connection**.
- **MCP para clientes externos:** **Settings → MCP**: Claude Code CLI, Codex CLI, Gemini CLI, Antigravity 2.0, OpenCode CLI, Kiro CLI, Claude Desktop (ChatGPT desktop y Codex IDE comparten config de Codex). Activar agrega/actualiza la entrada `pencil` del cliente.
  - Claude Code: abrir un `.pen` en pen.dev → activar **Claude Code CLI** → reiniciar Claude Code → `/mcp` muestra `pencil` conectado.
  - Funcionamiento: cliente ↔ servidor por stdio; servidor ↔ **app en ejecución** por Unix socket / named pipe. La app debe estar abierta con un `.pen`.
- **Herramientas MCP:**

| Tool | Disponible | Qué hace |
|---|---|---|
| `get_style` | siempre | Lista o carga un estilo visual (guía para el agente) |
| `read_skill` | siempre | Instrucciones del esquema, `execute` y flujos (`pen-schema.md`, `execute.md`, guías) |
| `get_app_state` | siempre | Metadatos del documento y selección |
| `execute` | siempre | Leer, modificar, renderizar y exportar (`Insert`, `TakeScreenshot`, `Export` PNG/JPEG/WEBP/PDF/HTML…) |
| `browser` | solo con la app de escritorio | Navegador integrado |
| `spawn_agents` | con `-enable_spawn_agents` | Lanza agentes extra |

- Troubleshooting MCP: poner la ruta completa del archivo en el prompt y verificar con `get_app_state()`; si falla, `read_skill()` + `get_app_state()` antes de reintentar; llamadas a mano en `pen interactive`.

## 3. Archivos .pen
- "Basados en JSON", amigables con control de versiones (acepta comentarios). Esquema `version: "2.21"`; abrir en otra versión migra y escribe el formato nuevo al guardar (respaldar antes). No editar el JSON a mano: app, MCP o CLI.
- Cifrado: la doc **no** lo menciona. [INFERENCIA/conflicto: el MCP `pencil` dice que están cifrados y que solo se accedan por MCP — tratarlos como opacos.]
- Crear: **File → New File** (`⌘⇧N`). Dashboard (`⌘N`): **Recents**, **Drafts**, **Design Systems**; **New File**, **Open File**, arrastrar; vista lista o grid; **Remove from Recents**, **Delete Draft**. Borradores del dashboard se autoguardan; **Save As…** (`⌘⇧S`) para moverlos; `⌘S` guarda.
- Recuperación: cambios sin guardar van a un backup aparte; tras un crash, **Recovered changes** → **Save** / **Save As…**; **Don't Save and Discard Backup** lo borra (no es historial). En el IDE: **Reload** o **Ignore** + Save As….
- Git: guardar y cerrar antes de cambiar de rama o hacer pull; rutas relativas estables para imágenes, fuentes y librerías; conflictos: conservar ambas versiones, elegir una base y reaplicar la otra dentro de pen.dev; commits frecuentes con nombres descriptivos (`dashboard.pen`, `components.pen`).

## 4. Canvas
- Navegación: Space+arrastrar, botón medio, Shift+scroll; zoom ⌘+scroll; `⌘0` 100%, `Shift+1` todo, `Shift+2` selección. **Settings → General**: pixel grid, snap a pixel/objetos, scroll para zoom, invertir zoom, nudge (1/10 px), animaciones, tema claro/oscuro (local, no en el `.pen`).
- Paneles: **Layers** (doble clic renombra, arrastrar reordena, ojo oculta); **Properties** (alignment, layout, appearance, fill, stroke, effects, export, Code).
- Colores de selección: azul = elemento; magenta = componente origen; violeta = instancia.
- Selección: `⌘+clic` profundo; `⌘+arrastrar` selecciona anidados; `Enter` hijos; `Shift+Enter` padre; `Esc` limpia.
- Frames `A`/`F`; `⌘⌥G` envuelve en frame; `⌘G`/`⌘⇧G`; **Clip Content**.
- Formas: `R`, `O`; menú **Primitives**: Polygon, Icon; `V` mover; `H` mano; `N` nota. W/H exactos; radio en **Appearance**.
- Escala `K`: punto ancla + factor; convierte variables en valores fijos, crea overrides en instancias y fija dimensiones Fill.
- Paths `P`: clic agrega, arrastrar curva, cerrar en el primero, `Esc` abierto; `Enter` edita puntos; `X` corta; doble clic suave/esquina; `⌘J` conecta.
- Texto `T`: **Typography** (fuente, peso, tamaño, line height, letter spacing, alineación); **Layout → Resizing**: Auto width / Auto height / Fixed size. Fuentes: **Add/Manage custom fonts** (ttf, otf, woff, woff2), por documento.
- Iconos: Primitives → **Icon**, librería + picker; color con Fill. Material Symbols (Outlined/Rounded/Sharp), Lucide, Feather, Phosphor (algunas con peso 100–700).
- Fill/Stroke/Effects: **+** agrega, ojo oculta, **−** quita. Fill: Color, Gradient (Linear/Radial/Angular/Mesh), Image (Fill/Fit/Stretch), Shader; blend mode por fill. Stroke Inside/Center/Outside. Effects: Drop Shadow, Inner Shadow, Layer Blur, Background Blur, Shader.
- Imágenes: en el swatch de Fill → **Remove background**, **Vectorize image** (internet + sesión).
- Undo `⌘Z`, redo `⌘⇧Z` (el canvas debe tener foco).

## 5. Flex layout
- App: `Shift+A` agrega, `Shift+⌥A` quita; Horizontal/Vertical, **Gap**, **Padding**, grilla **Alignment**, **Space Between/Around**; tamaños fijos, **Hug Width/Height** (padre), **Fill Width/Height** (hijo); **Absolute Position**; flechas reordenan hijos.
- Trampas: un frame no abraza a hijos que lo llenan; colapsa sin tamaño fijo ni hijo con tamaño propio.
- Esquema: `layout` none/vertical/horizontal (default horizontal + fit_content); `gap`; `padding` n | [v,h] | [t,r,b,l]; `justifyContent` start/center/end/space_between/space_around; `alignItems` start/center/end; `fit_content`/`fill_container` con fallback `fit_content(100)`; `layoutPosition:"absolute"`; x/y ignorados en flex.

## 6. Componentes e instancias
- Crear: `⌘⌥K` o **Create Component** (también revierte). JSON `reusable:true`. Se pueden anidar.
- Instancias: copiar el origen o desde la pestaña **Components**; **Go to component**. JSON `type:"ref", ref:"id"`.
- Overrides: solo la propiedad editada queda override; el resto sigue al origen. JSON: propiedades en el ref; `descendants:{"childId":{…}}`, rutas anidadas `"a/b"`; si el descendant trae `type` **reemplaza** el nodo; se puede reemplazar solo `children`. No se pueden re-parentar capas heredadas.
- Swap: `⌥⇧R` Replace inside instance; `⌘⇧R` Paste to replace. JSON: reemplazo de descendant.
- Detach: **Detach instance** / `⌘⌥X` (instancias anidadas y variables siguen ligadas).
- Slots: solo un **frame vacío dentro del origen** → **Make slot** (rayado); **+** junto a **Slot** para componentes sugeridos (`slot:[ids]`, no restringen). En la instancia: arrastrar/pegar o clic en un sugerido.
- **Variantes: no existen.** La palabra solo aparece para "design variants" generadas por IA (Let it cook). [INFERENCIA: sustituto = componentes separados, overrides, slots, booleanos en visibilidad y temas.]

## 7. Variables
- Tipos **Color, Number, String, Boolean**. Toolbar → **Variables** → **Add variable**; menú de fila: renombrar, duplicar, borrar.
- **Apply variable** junto a una propiedad (colores → fills/strokes; números → spacing/font size; strings → fuentes; booleanos → visibilidad).
- **Aliases**: el valor de una variable puede ser otra del mismo tipo (picker en la celda). JSON `"$name"`.
- Con IA: adjuntar `globals.css`; desde Figma, captura de la tabla o valores sueltos. Sincronizar con código pidiéndolo al agente.
- Variables de una librería importada se actualizan al guardar la librería y reabrir el consumidor.

## 8. Temas
- Cada **columna** del panel Variables es un valor de tema (Light, Dark); **+** junto a las columnas agrega un valor; **+** junto a las pestañas agrega un **eje** (Device…); renombrar desde el menú de la columna.
- "The first value of each axis is the document default."
- JSON: `themes:{ "mode":["light","dark"] }`; valor `[{value, theme:{mode:"dark"}}, …]`; **gana la última entrada que coincide**.
- Aplicar: seleccionar frame (o instancia, según el tutorial) → Properties → **Theme → Add theme** → eje → valor. Hijos heredan salvo que fijen su propio valor del mismo eje. **Remove theme** restaura la herencia.
- Depurar: revisar Theme del elemento, de sus padres y el valor de la variable en ese tema; definir valor para cada tema; en scripts, enlazar inputs a variables.

## 9. Librerías y design systems
- Crear: guardar → Libraries → **Turn this file into a library** (irreversible) → `*.lib.pen`.
- Importar: Libraries → elegir (incluye defaults) o **+** junto a **Imported Libraries**. JSON `imports:{alias:"ruta.pen"}`. Usar desde la pestaña Components.
- Actualizaciones: al reabrir el consumidor; los overrides ganan. Librería faltante: **Locate**.
- Copiar entre documentos: desde `.lib.pen` pregunta **Yes, import** (ligado) o **No, paste verbatim copies**; de un `.pen` normal no queda liga (variables y temas viajan). Conflictos: **Use existing** / **Add renamed** → **Paste**. Las fuentes no viajan.
- Tutorial: `starter.lib.pen` (variables surface, ink, accent, space, font-body, font-size con Light/Dark; Button; Card con slot **Actions** que sugiere Button) + `consumer.pen` (Card con Theme → Dark; cambiar accent a `#7C3AED` en la librería y reabrir).

## 10. Estilos
No hay estilos de documento (texto/color/efecto). `get_style` = estilo visual para el agente. [INFERENCIA: variables + componentes cumplen ese papel.]

## 11. Figma
Archivo completo: chevron bajo el ícono de rectángulo → **Import Figma**, o **File > Import Image/SVG/Figma...** (escritorio), o arrastrar `.fig`. Capas sueltas: copiar/pegar (**sin imágenes**). Variables: captura de la tabla o valores, y pedir al agente.

## 12. Código
- Con agente: `⌘K` (o chat del IDE). Stacks: React (JS/TS), Next.js, Vue, Svelte, HTML/CSS; Tailwind, CSS Modules, Styled Components; shadcn/ui, Radix, Chakra, MUI; iconos Lucide, Heroicons, FontAwesome, React Icons. "not limited to a specific framework".
- Sin agente: Properties → **Code** → **HTML + Tailwind** / **HTML + CSS** → **Copy HTML** / **Export HTML**; **Code export settings** (assets, **Include HTML scaffold**); `⌘⌥C`; `Export()` por MCP.
- **SwiftUI/iOS/macOS: no se mencionan.** [INFERENCIA: solo pidiéndolo al agente.]
- Código → diseño: "Recreate the Button component from src/components/Button.tsx" con el `.pen` en el workspace; revisar el resultado.
- Sincronía en dos sentidos: solo cuando se pide; ciclos recomendados (nuevo: diseñar → generar → refinar → actualizar diseño; existente: importar → cambiar → sincronizar; design system: variables → CSS → cambios en ambos). `design.pen` en la raíz junto a `src/`.

## 13. Navegador / web
Solo escritorio: globo → URL (localhost ok); **Select an element**, **Import** (capas editables, sin JS), Zoom/dispositivo; **Screenshot** (elemento, Full Page, Visible Area). MCP `browser`. Nodo `browser` en el esquema (url, deviceId, zoom, scroll).

## 14. Scripts, shaders, notas
- **Script** (`</>`): nodo 200×200; ruta a `.js` relativa al `.pen`; cabecera `@schema` + `@input nombre: tipo = default` (number(min,max), string, boolean, color, enum, ref); global `pencil` (`width`, `height`, `input.*`); devuelve nodos. Límites: 1000 nodos, 2 s, sin componentes, sin DOM/red/archivos/async, `Math.random` determinista, fuera del undo. **Convert to layers**. Ejemplos: `highagency/pencil-scripts`.
- **Shaders**: WebGL 1.0 fragment, como fill o efecto; uniforms con `@directive`; `@resolution`, `@time`; `pencil:object`, `pencil:background`; enlazables a variables.
- Nodos `note` (`N`), `prompt` (content, model), `context`; toda entidad puede tener `context`. [INFERENCIA: instrucciones/contexto para agentes.]
- Agente en la app: sesiones (pestaña Agent, **New (+)**), selector de modelo y esfuerzo, **Stop generation**, contexto (selección automática, **Add image or file**), permisos (**Allow/Deny**, **Switch to Auto**, **Dangerously skip permissions**), **Context usage**, **Est. cost**, skills (`/`, **Pick a skill**, **Add SKILL.md file…**), **Parallel agents** (1–6, Split Work / Side by Side), **Let it cook** (Layout/Style, 2–6 variantes).

## 15. Colaboración
Sin multiplayer en tiempo real. Git + **Share → Create share link** (**Snapshot shared**, **Copy link**; cualquiera con el link ve y descarga). **Missing dependencies** (Cancel / **Continue anyway**), **Share Upload Failed**. **Update snapshot**; **Delete share link**. Destinatarios: **Download file** (ZIP). Workspaces/organizaciones (Settings → Account; CLI `--workspace`).

## 16. Exportar
Properties (abajo): PNG/JPEG/WEBP/PDF, 1x/2x/3x → **Export layer** (varias → `export.zip`; PDF una capa por página). **Copy as → Copy as PNG** (`⌘⇧C`). Slides: frames raíz en **Slides**, **Present** (`⌘Enter`), **Export PDF** (todas / seleccionadas). CLI: `pen --in design.pen --export hero.png --export-scale 2` (`--export-type pdf|jpeg|webp`).

## 17. CLI
`pen login` (`~/.pencil/session-cli.json`), `pen status`, `pen codex-login/logout`, `pen version`. Agente: `pen --in a.pen --out b.pen --prompt "…"` con `-f`, `--agent claude|codex|google|xai|openrouter`, `--model`, `--effort`, `--list-models`, `--repo`, `--workspace`, `--tasks`, `--enable-preview`/`--preview-output`, `--usage`, `--verbose`, `--verbose-mcp`, `--max-failed-calls`. Interactivo: `pen interactive -o out.pen` o `-a desktop -i file.pen`; dentro `tool({…})`, `save()`, `exit()`. Variables: `PEN_CLI_KEY`, `PEN_AGENT_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `XAI_API_KEY`, `PEN_API_BASE`, `DEBUG`. CI: `PEN_CLI_KEY` + `ANTHROPIC_API_KEY`.

## 18. Atajos
`?` lista. Chat `⌘K`, `⌘T`, `Ctrl+Tab`. Herramientas V, K, H, R, O, A/F, T, N, P; mantener Z para zoom. Edición: `⌘D`, `⌘⇧R`, `⌘⇧C`, `⌘⌥C`, `⌘G`/`⌘⇧G`, `⌘⌥G`, `Shift+A`/`Shift+⌥A`, `Shift+H`/`Shift+V`. Alinear `⌥`+W/A/S/D/H/V; orden `⌘[`/`⌘]`, `[`/`]`. Componentes `⌘⌥K`, `⌘⌥X`, `⌥⇧R`. Canvas `⌘'`, `⌘⇧'`, `⌘+`/`⌘-`/`⌘0`, `Shift+1`/`Shift+2`. Archivos `⌘S`, `⌘⇧S`, `⌘O`, `⌘N`, `⌘⇧N`.

## 19. Límites conocidos
Pegar desde Figma sin imágenes · librería irreversible · cambios de librería al reabrir · fuentes por documento · no re-parentar heredados en instancias · escalar fija variables y crea overrides · límites de scripts · remove background/vectorize requieren internet y sesión · import web sin JS y solo escritorio · share links públicos · CLI `--tasks` solo la primera; export CLI puede fallar con exit 0 (verificar el archivo) · formato puede cambiar · MCP requiere la app abierta con documento · undo puede aplicar a un campo de texto · cambiar de proveedor puede perder contexto.

## 20. Buenas prácticas de la doc
`.pen` en el repo junto al código, nombres descriptivos, commits frecuentes · nunca editar el JSON · guardar y cerrar antes de Git; conflictos dentro de pen.dev · rutas relativas estables · variables en vez de valores fijos, un valor por tema, aliases · slots + sugeridos · nombrar el archivo objetivo y confirmar con `get_app_state()`; `read_skill()` antes y tras fallos · revisar cada cambio del agente · tokens sincronizados con CSS vía agente · revisar imports contra la fuente · mantener app y extensión al día · no publicar secretos ni diseños privados en reportes.

**No están en la doc:** SwiftUI/iOS, variantes de componente, estilos compartidos, multiplayer, cifrado, comentarios en share links, changelog, FAQ.
