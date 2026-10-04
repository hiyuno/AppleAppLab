---
name: add-developer-tools
description: "Instala el panel de Dev Tools y el tema central (LabThemeStore) en un proyecto existente o nuevo: detecta el paquete AppleAppLabUI, elige o pregunta el tema de Themes/*.json, lo empaqueta como recurso, cablea .labTheme + .labDevTools en la raíz, sustituye todos los PatternConfig(...) hardcodeados por labTheme.config(for:), compila en iOS y macOS, verifica que Release no contiene DevTools y deja a Larry el reporte de literales visuales. Idempotente. 'check' solo audita sin tocar. Úsalo con 'agrega dev tools', 'quiero controlar la UI en vivo', o al crear una app nueva."
---

# /add-developer-tools — Dev Tools y tema central en cualquier proyecto

Rutina ejecutable, no auditoría. Woz hace el cableado, Bertrand compila, Larry reporta lo que quedó hardcodeado, Ivan confirma que Release va limpio. Al terminar, la app abre el panel con shake / ⌥⌘D / botón flotante y toda su UI lee del tema. Referencia de la API: `PATTERNS.md` §"Tema y Dev Tools".

**Es idempotente.** Correrla sobre un proyecto que ya lo tiene no duplica nada: cada paso comprueba antes de escribir.

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/add-developer-tools` | Instala completo: tema, store, panel, sustitución de configs, build, verificación |
| `/add-developer-tools <tema>` | Igual, con el tema fijado (`fintrol`, `todocky`, `todo-project`, `test`, o la ruta a un JSON exportado) |
| `/add-developer-tools check` | Solo audita: ¿está cableado? ¿qué `PatternConfig(` siguen hardcodeados? ¿qué literales visuales hay? No toca nada |

---

## Quién hace qué

| Paso | Agente |
|------|--------|
| 0 · Sonda y tema | Steve |
| 1–4 · Cableado y sustitución | **Woz** |
| 5 · Build iOS + macOS | Bertrand |
| 6 · Release sin DevTools | Ivan |
| 7 · Literales visuales restantes | Larry |
| 8 · Documentar | Steve (TRD, STYLE_BRIEF, PROJECT_LEARNINGS si hubo sorpresa) |

---

## Paso 0 — Sonda (Steve)

```bash
grep -n "AppleAppLabUI" project.yml Package.swift 2>/dev/null          # ¿depende del paquete? ¿path local o URL?
grep -rn "labDevTools\|LabThemeStore" --include="*.swift" . | head     # ¿ya cableado?
grep -rn "PatternConfig(" --include="*.swift" . | grep -v "Packages/" | wc -l   # configs hardcodeados
ls Themes/*.json 2>/dev/null; grep -n "Themes/" STYLE_BRIEF.md 2>/dev/null       # tema disponible / elegido
grep -rn "^@main" --include="*.swift" -l .                              # App.swift
cat .appleapplab/VERSION 2>/dev/null                                    # ≥ 1.16.0 para tener LabThemeStore
```

**Decisiones:**
- **Sin el paquete** → esto no aplica: Avie lo añade primero (es dependencia estándar del TRD). Steve lo dice y para.
- **Paquete por path local** desactualizado (sin `Theme/LabThemeStore.swift`) → `/update-team` o `git pull` en AppleAppLab antes de seguir.
- **Tema:** el que diga `STYLE_BRIEF.md`; si no hay, el argumento; si tampoco, Steve pregunta **una vez** mostrando los de `Themes/THEMES.md`. Si el usuario no quiere ninguno, se usa `.default` y no se empaqueta JSON.
- **Ya cableado** → salta a los pasos 4–7 (sustitución y verificación), que es lo que suele faltar.

---

## Paso 1 — Empaquetar el tema (Woz)

En `project.yml`, dentro de `sources:` del target principal (no del de tests):

```yaml
sources:
  - path: <App>
  - path: ../../Themes/<tema>.json      # ruta relativa a Themes/ del repo instalado
    buildPhase: resources
```

Si el proyecto no usa XcodeGen, el JSON se añade al target como recurso desde Xcode (Copy Bundle Resources). `xcodegen generate` después.

## Paso 2 — Store en `App.swift` (Woz)

```swift
import AppleAppLabUI

@State private var themeStore: LabThemeStore = {
    let bundled = LabThemeStore.bundledThemes()
    return LabThemeStore(bundledThemes: bundled, initial: bundled.first { $0.name == "<Nombre del tema>" } ?? .default)
}()
```

`"<Nombre del tema>"` es el campo `name` del JSON (`Fintrol`, `Todocky`…), no el nombre del archivo.

## Paso 3 — Modificadores en la raíz (Woz)

En **cada** escena (`WindowGroup`, `Settings` en macOS, `MenuBarExtra`):

```swift
RootView()
    .labTheme(themeStore)       // siempre
    .labDevTools(themeStore)    // solo en la escena principal; es no-op en Release
```

Si la app ya aplica `.preferredColorScheme` propio, se deja: `.labTheme` solo lo fuerza cuando el tema no es `.system`. Si la app ya aplica `.tint(...)` propio, se quita — el tema manda.

## Paso 4 — Sustituir configs hardcodeados (Woz)

Cada `PatternConfig(...)` construido a mano en la app se cambia por `labTheme.config(for: <Pattern>.self)` según el componente que lo recibe, y el struct contenedor gana `@Environment(\.labTheme) private var labTheme`:

| Componente | Pattern |
|---|---|
| `LabButton` | `ButtonsPattern` |
| `LabCard` · `LabNestedCard` · `LabDashboardCards` | `CardsPattern` |
| `LabList` | `ListsPattern` |
| `LabTodoList` | `TodoListPattern` |
| `LabTextField` | `FormsPattern` |
| `LabTabBar` | `NavigationPattern` |
| `LabToggleRow` | `TogglesPattern` |
| `LabCheckboxGroup` · `LabRadioGroup` | `CheckboxRadioPattern` |
| `LabProgressIndicator` | `LoadingPattern` |
| `LabEmptyState` | `EmptyStatesPattern` |
| `LabOnboardingStep` | `OnboardingPattern` |
| `LabBadge` | `BadgePattern` |

Script de referencia (el que se usó en Fintrol; el componente se busca hasta 30 líneas arriba del `config:` porque los `Binding` multilínea lo alejan):

```bash
python3 - <<'PY'
import pathlib, re, subprocess
needle = re.compile(r"PatternConfig\((accentColor: \.accentColor)?\)")
pattern_for = {"LabEmptyState":"EmptyStatesPattern","LabTextField":"FormsPattern","LabToggleRow":"TogglesPattern","LabButton":"ButtonsPattern","LabCard":"CardsPattern","LabNestedCard":"CardsPattern","LabDashboardCards":"CardsPattern","LabList":"ListsPattern","LabBadge":"BadgePattern","LabTabBar":"NavigationPattern","LabProgressIndicator":"LoadingPattern","LabTodoList":"TodoListPattern","LabCheckboxGroup":"CheckboxRadioPattern","LabRadioGroup":"CheckboxRadioPattern","LabOnboardingStep":"OnboardingPattern"}
files = subprocess.run(["grep","-rl","PatternConfig(","--include=*.swift","."],capture_output=True,text=True).stdout.split()
files = [f for f in files if "/Packages/" not in f and "/.build/" not in f]
for f in files:
    p = pathlib.Path(f); lines = p.read_text().split("\n"); structs=set(); n=0
    for i,line in enumerate(lines):
        if not needle.search(line): continue
        comp = next((m.group(1) for j in range(i,max(-1,i-30),-1) for m in [re.search(r"\b(Lab[A-Z]\w*)\(",lines[j])] if m), None)
        if comp not in pattern_for: print(f"REVISAR A MANO {f}:{i+1} ({comp})"); continue
        lines[i] = needle.sub(f"labTheme.config(for: {pattern_for[comp]}.self)", line); n+=1
        for j in range(i,-1,-1):
            if re.match(r"^\s*(private |fileprivate |public )?struct \w+\s*:\s*View\s*\{", lines[j]): structs.add(j); break
    for j in sorted(structs, reverse=True):
        if "@Environment(\\.labTheme)" not in "\n".join(lines[j+1:j+40]):
            lines.insert(j+1, re.match(r"^(\s*)",lines[j]).group(1)+"    @Environment(\\.labTheme) private var labTheme")
    s="\n".join(lines)
    if "import AppleAppLabUI" not in s: s=s.replace("import SwiftUI\n","import SwiftUI\nimport AppleAppLabUI\n",1)
    p.write_text(s); print(f"{f}: {n}")
PY
```

Los `PatternConfig(...)` con **otros argumentos** (un `cornerRadius:` o `spacing:` explícito) se imprimen como *REVISAR A MANO*: Woz decide si ese valor pasa a ser un override del tema (lo normal) o una variante legítima del componente.

## Paso 5 — Build (Bertrand)

```bash
xcodegen generate
xcodebuild -scheme <App> -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"
xcodebuild -scheme <App> -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"   # si hay target Mac
```

Y una comprobación visual: lanzar en el simulador, abrir el panel (botón flotante), confirmar que la pestaña Tema muestra el accent del JSON y que Componentes lista los `Lab*`. Si hay dispositivo, shake.

## Paso 6 — Release sin DevTools (Ivan)

```bash
xcodebuild -scheme <App> -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/rel build 2>&1 | grep -E "error:|BUILD"
nm -gU $(find /tmp/rel -name "<App>" -path "*Release-iphonesimulator/<App>.app/*" | head -1) | grep -c LabDevTools   # debe ser 0
```

Si no es 0, alguien referenció el panel fuera de `#if DEBUG`: se corrige antes de cerrar.

## Paso 7 — Literales visuales restantes (Larry)

```bash
grep -rnE "PatternConfig\(|\.opacity\(0\.[0-9]|cornerRadius: [0-9]|Color\(red:|Color\(hex|\.shadow\(radius: [0-9]|\.spring\(response: [0-9]" --include="*.swift" . | grep -v "Packages/\|/.build/\|Preview"
```

Cada línea es un hallazgo 🟡 (🔴 si es el accent o un fondo de pantalla). No se arreglan en esta rutina: Larry los reporta y Woz los lleva a tokens o a un `InspectablePattern` propio en una pasada aparte, o entran como etapa de `/optimize-app`.

## Paso 8 — Documentar (Steve)

- `TRD.md`: "Tema: `Themes/<tema>.json` vía `LabThemeStore`; Dev Tools en Debug".
- `STYLE_BRIEF.md`: el archivo del tema si no estaba.
- Si algo del proyecto exigió una excepción (widget sin paquete, target sin SwiftUI), queda en `PROJECT_LEARNINGS.md`.

## Cierre

> "Dev Tools instalado: tema **Fintrol** empaquetado y activo, `.labTheme` + `.labDevTools` en 2 escenas, 19 configs sustituidos en 10 archivos, 0 para revisar a mano. Build iOS ✅ macOS ✅. Release sin DevTools ✅. Larry encontró 7 literales visuales en 4 vistas — los dejo listados para una pasada aparte. Abre la app y agita (o ⌥⌘D) para ver el panel."

---

## Lo que esta rutina NO hace

- No crea temas nuevos — eso es la fase visual de Steve + Jonny y el panel mismo (Exportar JSON)
- No arregla los literales visuales que encuentra Larry — los reporta
- No cambia los inits de los componentes `Lab*`
- No toca widgets ni extensiones: no pueden importar el paquete (ver Eve); sus tokens se pasan a mano
- No se salta la verificación de Release aunque el usuario tenga prisa

## Tono

- Dice qué cambió por paso, con conteos. Si algo quedó "REVISAR A MANO", lo lista con archivo:línea.
- Español o inglés: el del usuario.
