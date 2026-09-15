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
- **Hallazgo no documentado en los blogs consultados:** Xcode 27 tiene su **propio sistema de skills** que algunos de sus MCP tools exigen como precondición. No se investigó más a fondo qué otras skills existen ni dónde se declaran — pendiente si el equipo decide automatizar localización vía MCP.

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

## Recomendaciones de implementación para AppleAppLab — ya aplicadas

1. **Avie** — cuándo esta capacidad es transversal-tooling vs. cuándo se vuelve superficie de producto que necesita threat model. Ver `.claude/skills/avie/SKILL.md`.
2. **Woz** — usarlo en el loop de desarrollo interactivo (`BuildProject`, `RunAllTests`, `RenderPreview`, `DeviceInteraction*`) en vez de `xcodebuild` a ciegas; mantener `xcodebuild`/Makefile para CI y export. Ver `.claude/skills/woz/SKILL.md`.
3. **Bertrand** — `GetTestList`/`RunAllTests`/`RunSomeTests` para testing en vivo con resultados estructurados; `RenderPreview` como evidencia de un fix visual. Ver `.claude/skills/bertrand/SKILL.md`.
4. **Ivan** — gate nuevo en `Gates obligatorios` + checklist "Agentes externos con acceso a Xcode (MCP)", incluyendo el hallazgo concreto de que `GetTopCrashIssues`/`GetFieldPerformanceIssueLogs` exponen telemetría real de producción vía la sesión de Xcode. Ver `.claude/skills/ivan/SKILL.md`.

No se creó un agente/skill nuevo — es tooling transversal que cada agente existente adopta en su propio rol.

---

**Recolectado**: 2026-09-14. Sección 1–4 verificadas por probing directo contra `xcrun mcpbridge` (Xcode 27.0, build 27A266a) en esta máquina — no son un resumen de terceros.
