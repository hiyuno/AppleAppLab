# Xcode 27: Acceso de Agentes Externos

## Resumen ejecutivo

Xcode 27 (instalado y verificado en esta máquina: **Xcode 27.0, build 27A266a**) trae un MCP server nativo — `xcrun mcpbridge` — que conecta agentes externos (Claude Code, Cursor, Codex, Gemini) al proceso vivo de Xcode. Se habilita en **Settings → Intelligence → Model Context Protocol → "Allow external agents to use Xcode tools"** y se registra en el agente con `claude mcp add --scope user --transport stdio xcode -- xcrun mcpbridge`.

**Importante — timing de carga:** los tools del server solo aparecen en una sesión de Claude Code que arrancó *después* de registrar el server. Si lo registras a mitad de una sesión, esa sesión sigue sin verlos aunque `claude mcp list` reporte `✔ Connected` (esa marca es solo el handshake de transporte). Abre una sesión nueva para usarlos.

## Fuentes

- **Verificado en esta máquina** (2026-09-14): probing directo del proceso `xcrun mcpbridge` vía JSON-RPC 2.0 sobre stdio (protocolo MCP `2025-06-18`), con Xcode 27 corriendo. `serverInfo`: `{"name":"xcode-tools","version":"25317"}`. Esta es la fuente primaria de las secciones 2–4 de este documento — no un resumen de terceros.
- [Enabling the Xcode 27 MCP Server in Claude Code](https://crunchybagel.com/enabling-the-xcode-27-mcp-server-in-claude-code/) — setup, coincide con lo verificado.
- [How to use Xcode 27 MCP Server - Wendy Liga](https://wendyliga.com/blog/how-to-use-xcode-27-mcp-server/)
- [Xcode 27: The Future of Agent-Driven Development - DEV Community](https://dev.to/arshtechpro/xcode-27-the-future-of-agent-driven-development-is-here-12fk)
- Apple Developer Documentation: [Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode) — no accesible directamente en el fetch inicial; revalidar contra esta página antes de citarla como fuente oficial en una auditoría real.

---

## 1. Cómo habilitar el acceso (Setup) — verificado

### En Xcode
1. **Settings (Preferences) → Intelligence → Model Context Protocol**
2. Activa **"Allow external agents to use Xcode tools"**

### Desde el agente externo

```bash
claude mcp add --scope user --transport stdio xcode -- xcrun mcpbridge
```

Verifica transporte (no confirma que el toggle esté activo, solo que el proceso responde):
```bash
claude mcp list
```

**Gate adicional — aprobación por agente (verificado 2026-09-15).** El toggle de Settings no es suficiente. La primera llamada a cualquier tool desde un agente falla con:

> *"This agent isn't approved to use Xcode's tools yet. Call `XcodeOpenWorkspace` or `XcodeNewProject` first: opening or creating a project is what asks the user to approve this agent, together with access to that project's folder."*

Es decir: `XcodeOpenWorkspace`/`XcodeNewProject` dispara un **diálogo de aprobación en la UI de Xcode**, una vez por identidad de agente (no una vez por máquina). El usuario tiene que aceptarlo ahí. Hasta que eso pase, cualquier otro tool (`XcodeListWorkspaces` incluido) devuelve ese error. Esto explica por qué una sesión nueva de Claude Code con el MCP registrado y el toggle activo puede seguir fallando en el primer intento: falta ese clic.

**Verificación real de capacidades** (lo que se usó para construir este documento — útil para Craig/Avie si algún día se necesita automatizar esto fuera de una sesión interactiva de Claude Code):

```bash
python3 - <<'EOF'
import subprocess, json, select
proc = subprocess.Popen(["xcrun", "mcpbridge"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
def send(o): proc.stdin.write((json.dumps(o)+"\n").encode()); proc.stdin.flush()
def recv():
    r,_,_ = select.select([proc.stdout], [], [], 10)
    return proc.stdout.readline() if r else None
send({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"0.1"}}})
print(recv())
send({"jsonrpc":"2.0","method":"notifications/initialized"})
send({"jsonrpc":"2.0","id":2,"method":"tools/list"})
print(recv())
proc.terminate()
EOF
```

Requiere Xcode 27 corriendo con el toggle activo; si no, `mcpbridge` responde igual al handshake pero las llamadas a tools fallan o devuelven vacío.

---

## 2. Los 53 tools reales — verificados en esta instalación

El server se llama `xcode-tools` (`serverInfo.version: "25317"`). Agrupados por función:

### Build & compilación
- **`BuildProject`** — compila y espera; devuelve errores estructurados (`filePath`, `lineNumber`, `classification`, `message`) y ruta al log completo.
- **`GetBuildLog`** — lee el log del build actual o más reciente; filtra por severidad (`error`/`warning`/`remark`), regex de mensaje o glob de archivo.
- **`GetTargetBuildSettings`** / **`UpdateTargetBuildSetting`** — lee/edita build settings de un target. La descripción es explícita: *"Do NOT try to parse `project.pbxproj` directly"*.
- **`GetFileCompilerFlags`** / **`UpdateFileCompilerFlags`** — flags por archivo (Compiler Flags de Build Phases). Nota propia del tool: para `.swift` estos flags no necesariamente afectan el build porque la unidad de compilación es el módulo — usar `OTHER_SWIFT_FLAGS` a nivel target en su lugar.

### Run, Stop, Debug
- **`RunProject`** / **`StopProject`** — equivalentes a ⌘R / ⌘.
- **`InvokeDebuggerCommand`** — manda comandos LLDB crudos (`bt`, `po self`, `breakpoint set`, `continue`, `thread step-over`, etc.) a la sesión de debug activa de Xcode. Comparte estado con la consola de debug de la UI — si el agente hace `continue`, también avanza lo que el humano ve. Requiere chequear `process status` antes de comandos que asumen el proceso detenido.
- **`RunCodeSnippet`** — ejecuta un snippet arbitrario en el contexto de un archivo (targets de app, framework, library o CLI) y devuelve el output de `print`. Es un REPL real.

### Testing
- **`GetTestList`** — hasta 100 tests inline, lista completa en archivo grep-friendly (`TEST_TARGET`, `TEST_IDENTIFIER`, `TEST_FILE_PATH`).
- **`RunAllTests`** / **`RunSomeTests`** — corre el test plan activo completo o una selección.
- **`XcodeListTestPlans`** / **`XcodeSwitchTestPlan`** — el test plan activo condiciona qué corre `GetTestList`/`RunAllTests`/`RunSomeTests` y también el build-for-testing.

### Previews (SwiftUI)
- **`RenderPreview`** — renderiza un `#Preview` o `PreviewProvider` a imagen. Soporta overrides de variantes, localización, timeline index (Widgets/Live Activities) y toggle state — descubribles vía el campo `supportedCanvasControlOverrides` de una invocación previa.

### Device & simulador — control de UI en vivo
Flujo de sesión explícito (no es un solo tool):
1. **`DeviceInteractionStartSession`** (sin workspace) o **`DeviceInteractionStartWorkspaceSession`** (con workspace, habilita install+run) — busca/bootea el device, devuelve `interactionSessionKey`.
2. **`DeviceInteractionInstallAndRun`** — build, instala y corre la app en el device de la sesión.
3. **`DeviceInteractionSynthesize`** — ejecuta un comando de interacción (`interactionCommand`, ej. `"t 100 200"` para tap) y devuelve screenshot + **UI hierarchy** (accesibilidad) + logs de consola. El tool advierte explícitamente: *"Always use positions based on the most recent hierarchy dump. Never try to guess positions from a screenshot only."*
4. **`DeviceInteractionEndSession`** — cierra la sesión. El tool insiste en que dejarla abierta es costoso y afecta la UI visible al usuario.

### Diagnóstico de producción — App Store Connect en vivo
- **`GetTopCrashIssues`** / **`GetCrashIssueLogs`** — top crash signatures de los últimos 14 días y logs detallados por signature, con "expert triage knowledge". Viene de **"Apple's crash reporting service"** — datos reales de producción/TestFlight, no simulados.
- **`GetTopFieldPerformanceIssues`** / **`GetFieldPerformanceIssueLogs`** — lanzamientos lentos, hangs, disk writes, energía — mismos datos que Xcode Organizer, vía field report API.
- Ambos grupos auto-resuelven `bundle_id`/`platform` del scheme activo si no se especifican, y aceptan `is_beta` para elegir TestFlight vs. App Store.
- **Implicación de seguridad concreta:** un agente externo con este MCP conectado puede leer telemetría de crash/performance de usuarios reales sin pasar por App Store Connect directamente — hereda la sesión/autenticación que Xcode ya tiene. Ver sección de Ivan más abajo.

### Console output
- **`GetConsoleOutput`** — stdout/stderr y OSLog de una sesión de lanzamiento, con filtro por regex, severidad OSLog (`error`/`fault`/`info`/`debug`/`default`), líneas de contexto tipo `grep -C`, y metadata completa (subsystem, category, pid, tid, sender function/file/line) cuando se pide.

### Proyecto — filesystem virtual, no filesystem real
`XcodeGlob`, `XcodeGrep`, `XcodeLS`, `XcodeRead`, `XcodeWrite`, `XcodeUpdate`, `XcodeMV`, `XcodeRM`, `XcodeMakeDir` — **operan sobre la organización del proyecto Xcode (project navigator), no sobre paths de filesystem crudos.** Es una distinción real, no cosmética: un grupo del navigator puede no corresponder 1:1 a una carpeta en disco. `XcodeRead`/`XcodeGrep` devuelven contenido con backslashes/comillas/saltos de línea JSON-escapados — hay que tenerlo en cuenta al interpretar la salida.

### Targets, schemes, destinos, workspaces
`XcodeListTargets`, `XcodeNewTarget`, `XcodeListSchemes`, `XcodeSwitchScheme`, `XcodeListRunDestinations`, `XcodeSwitchRunDestination`, `XcodeListWorkspaces`, `XcodeOpenWorkspace`, `XcodeCloseWorkspace`, `XcodeNewProject`, `XcodeListTemplates`, `XcodeRefreshCodeIssuesInFile`.

### Entitlements & Info.plist — nunca editar el archivo a mano
- **`AddEntitlement`** — la descripción es explícita sobre cuándo *no* usarlo: nunca para frameworks estándar (SwiftUI, UIKit, MapKit, etc.), nunca para privacy usage strings (eso es `AddInfoPlist`). Instruye: *"It is IMPORTANT that you do not edit the entitlement file directly unless told to."*
- **`AddInfoPlist`** — mismo patrón, misma advertencia sobre no tocar el archivo directamente aunque `GENERATE_INFOPLIST_FILE` esté activo.

### Localización — gateado por skill propio de Xcode
- **`LocalizationPlanner`**, **`StringCatalogRead`**, **`StringCatalogContext`**, **`StringCatalogEdit`** — los cuatro tienen la misma instrucción en su descripción: *"Before calling this tool, you MUST activate the `xcode-integration:translation` [o `translation-coordinator`] skill. Do not call this tool without first loading that skill's instructions."*
- Esas dos skills viven en texto plano dentro de Xcode.app: `/Applications/Xcode.app/Contents/PlugIns/IDEXCStringsSupport.framework/Versions/A/Resources/Skills/{translation,translation-coordinator}/SKILL.md.packaged` (más `translation/references/styleguide_<locale>.md.packaged`). Kim las lee de ahí antes de usar los tools — siempre la versión del Xcode instalado, sin mantenimiento. No se exportan con `skills export`; las otras 10 sí (§5).

---

## 3. Qué NO cubre este MCP

- **CI/headless.** Todo depende de una sesión de Xcode con GUI activa (`xcrun mcpbridge` es un bridge hacia el proceso vivo). No sirve para runners sin cabeza — el pipeline de release sigue siendo `xcodebuild`/`xcodebuild -exportArchive` reproducible por línea de comandos (ver `/craig`).
- **Archivado y export para distribución.** No hay tool de archive/export en la lista de 53. Exportar para App Store o Developer ID sigue siendo terreno de Woz/Craig vía `xcodebuild`.
- **Git.** No hay tools de control de versiones — es responsabilidad del agente externo fuera de este MCP.
- **Firma de código / notarización.** No expuesto aquí; sigue siendo `codesign`/`notarytool` vía shell.

---

## 4. Flujo de trabajo típico

1. `XcodeListWorkspaces` / `XcodeOpenWorkspace` — identificar el workspace.
2. `XcodeGlob`/`XcodeGrep`/`XcodeRead` — explorar.
3. `XcodeWrite`/`XcodeUpdate` — editar.
4. `BuildProject` → `GetBuildLog` si hay errores.
5. `RunAllTests`/`RunSomeTests` → `GetTestList` para saber qué correr.
6. `RenderPreview` para verificar UI, o `DeviceInteractionStart*Session` → `DeviceInteractionSynthesize` para un flujo interactivo real en simulador/dispositivo.
7. `GetConsoleOutput` / `InvokeDebuggerCommand` para diagnosticar.

Todo esto sin que el desarrollador toque Xcode manualmente — pero cualquier acción de `InvokeDebuggerCommand` o `DeviceInteractionSynthesize` es visible y comparte estado con la UI que el usuario tiene abierta.

---

## 5. Skills oficiales de Apple para agentes — y quién las usa en el equipo

Además de los tools, Xcode 27 ship **12 skills** escritas por Apple para agentes, marcadas como *"supersede prior training"*. Diez se exportan con:

```bash
xcrun mcpbridge run-agent skills export --output-dir ~/.claude/xcode-skills --replace-existing
```

`setup.sh` y `/update-team` lo hacen solos cuando el build de Xcode cambia (sello en `~/.claude/xcode-skills/.xcode-build`) y enlazan cada carpeta en `~/.claude/skills/<name>`, así aparecen como `/swiftui-specialist`, `/device-interaction`, etc. en todos los proyectos. **Nunca se vendorizan en el repo**: están atadas al build de Xcode y se actualizan con él. Las dos de traducción no se exportan; viven en el framework (§2 Localización).

| Skill de Apple | Dueño en el equipo | Cuándo | Regla de conflicto |
|---|---|---|---|
| `swiftui-specialist` | Woz | al escribir o revisar SwiftUI | Apple manda en API, observación, `ForEach`, animación; **AppleAppLabUI / `PATTERNS.md` / `DESIGN_*.md` mandan en qué componente**. Conflicto → `PROJECT_LEARNINGS.md` + Avie |
| `swiftui-whats-new-27` | Woz (Avie decide) | solo si el target es ≥ iOS/macOS 26 | nunca sube el deployment target por adoptar una API |
| `app-intents-specialist` / `app-intents-whats-new-27` | Eve | intents, entities, `AppShortcutsProvider`; whats-new solo target ≥ 26 | idem |
| `modernize-tests` | Bertrand recomienda, Woz ejecuta bajo `go <n>` | migración XCTest → Swift Testing | UI tests (XCUIAutomation) y `measure { }` se quedan en XCTest |
| `device-interaction` (**subagente**: Agent tool, `general-purpose`) | quien verifica, invoca: Woz post-feature · Bertrand `TEST_PLAN` y re-medición · Chris matriz de dispositivos · Sarah lee la hierarchy | verificación en simulador/dispositivo | **una sesión por simulador** — dentro de rutinas la abre Bertrand y los demás leen su salida |
| `audit-xcode-security-settings` | Ivan lee (briefing, discovery, tabla), Woz aplica bajo `go <n>` | Pase 2 de Ivan | Ivan no ejecuta "Plan & Approve" ni crea su decision document; omite TLS/firma/privacidad — siguen en el checklist de Ivan |
| `translation` / `translation-coordinator` (en Xcode.app) | Kim | precondición obligatoria de `StringCatalog*` y `LocalizationPlanner` | nunca escribir `.xcstrings` a mano con el MCP conectado |
| `adopt-c-bounds-safety`, `uikit-app-modernization`, `building-document-based-swiftui-applications` | Avie caso a caso | código C, UIKit heredado, apps de documentos (target ≥ 27) | fuera del flujo estándar |

## 6. Reglas de equipo

- **Fallback, declarado una sola vez.** Steve sonda `mcp__xcode__*` al arrancar y marca cada encargo con `MCP xcode: sí/no`. Con `no`, cada skill sigue con su paso manual o de `xcodebuild` sin mencionarlo — los skills no repiten la cláusula. (`.claude/skills/steve/SKILL.md` §1 Reúne evidencia.)
- **Telemetría de producción** (`GetTopCrashIssues`, `GetCrashIssueLogs`, `GetTopFieldPerformanceIssues`, `GetFieldPerformanceIssueLogs`): uso rutinario por Phil, Bertrand, `/optimize-app` Fase 1 y `/app-store-ready` Fase 5 — se anuncia en una línea qué bundle y canal se consulta, y se **redacta PII** de los logs antes de escribirlos en cualquier `*.md`. Un log sin redactar es hallazgo Medium de Ivan.
- **Nunca en CI.** `mcpbridge` necesita Xcode con GUI; no hay tools de archive, export, `codesign` ni `notarytool`. Release = `xcodebuild` reproducible (Craig).
- **RenderPreview:** Woz renderiza al entregar y adjunta; Jonny compara contra `DESIGN_*.md`; Larry contra la HIG (con overrides de variante); Kim con `locale`; Eve con `timelineIndex`/`toggleState`.
- **Un solo plan activo por zona** cubre también los planes que nacen de skills de Apple: sus cambios entran como etapas de la rutina dueña, sin documento propio.
- **Incidentes del toolchain** → `PROJECT_LEARNINGS.md` con fingerprint `tooling/xcode-mcp/<Tool>` y build de Xcode.

## Dónde vive cada integración

Steve (sonda, fallback, memoria, modelo) · Avie (frontera arquitectura vs. API, skills de C/UIKit/documentos) · Woz (loop de desarrollo, `swiftui-*`, verificación post-feature) · Bertrand (tests en vivo, `device-interaction`, `modernize-tests`, telemetría) · Ivan (gate, `audit-xcode-security-settings`, regla de PII) · Kim (String Catalogs) · Chris (matriz de dispositivos) · Sarah (UI hierarchy como evidencia) · Larry (renders con overrides) · Eve (widgets por `timelineIndex`, `app-intents-*`) · Craig (nunca en CI) · Phil (crash rate medido) · Jonny (renders vs. spec) · Tim y John (handoff) · rutinas `/optimize-app`, `/architecture-audit`, `/app-store-ready`, `/clean-folder-project`, `/global-audit` · `setup.sh` y `/update-team` (export con sello).

No se creó un agente nuevo — es tooling transversal que cada agente existente adopta en su propio rol.

---

**Recolectado**: 2026-09-14; integración en el equipo 2026-09-15 (v1.11.0). Secciones 1–4 verificadas por probing directo contra `xcrun mcpbridge` (Xcode 27.0, build 27A266a) en esta máquina; §5 verificada exportando las skills con el comando indicado.
