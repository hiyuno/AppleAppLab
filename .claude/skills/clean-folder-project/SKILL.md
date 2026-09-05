---
name: clean-folder-project
description: "Rutina de limpieza y organización del proyecto. Avie inventaría carpetas, archivos, nombres, basura, assets y .gitignore; define la estructura objetivo según el estándar de facto para apps SwiftUI (feature-first, Core, Resources, tests que reflejan el código) adaptada al TRD; entrega PROJECT_STRUCTURE.md con la tabla archivo → destino y un plan por etapas que nunca rompe el build. Woz mueve con git mv, Bertrand confirma build y tests. 'go <n>' aplica cada etapa. Úsalo cuando el proyecto esté desordenado, no sepas dónde va un archivo, haya basura en git o quieras dejarlo como un proyecto profesional."
---

# /clean-folder-project — Limpiar y organizar el proyecto como un proyecto profesional

Rutina del equipo, no un agente. Cuando se lanza, Steve orquesta a Avie (líder), Woz y Bertrand para dejar el proyecto **físicamente** ordenado: carpetas que reflejan la arquitectura decidida, archivos con nombre y lugar predecibles, sin basura en el repo, con `.gitignore` correcto, assets y strings sin huérfanos, y tests que reflejan el código. Entrega `PROJECT_STRUCTURE.md` — que además queda como **la convención viva del proyecto** ("dónde va cada cosa") — con la tabla *archivo → destino* y un **plan por etapas** que compila y pasa tests al final de cada una.

**El skill termina en el plan.** No mueve, renombra ni borra nada hasta que el usuario apruebe cada etapa explícitamente.

---

## Frontera con el resto del equipo

| | Quién | Qué hace esta rutina |
|--|--|--|
| **Qué capas existen** (MVVM, Repository, módulos) | `/architecture-audit` — Avie | **No lo decide.** Lee el `TRD.md` y hace que el sistema de archivos lo refleje. Si al inventariar descubre que la arquitectura misma está mal, lo marca `🏗` y lo pasa a `/architecture-audit`. Si ese audit tiene etapas abiertas que mueven código, esta rutina **espera** o se limita a zonas que no toca |
| Código muerto *dentro* de archivos, duplicación de lógica | `/optimize-app` | Aquí solo **archivos** muertos completos, assets y strings sin uso. Lo de dentro de los archivos no se toca |
| Mover archivos | Woz | Avie decide destino; Woz ejecuta con `git mv` y regenera el proyecto |
| Entitlements, `PrivacyInfo.xcprivacy`, configs con secretos | Ivan | **No se mueven ni borran sin Ivan.** Si aparece un secreto rastreado en git, es 🔴 y va a Ivan — `.gitignore` no lo arregla, ya está en el historial |
| `Localizable.xcstrings` — claves sin uso | Kim | Se reportan; solo se borran con confirmación de Kim si la app es multi-idioma |
| Assets de diseño, nombres de componentes | Jonny | Nombres de assets y carpeta de diseño se consensúan con Jonny |
| Documentos del equipo (`PRD.md`, `TRD.md`, `*_AUDIT.md`) | Steve | **Se quedan en la raíz.** Los agentes los leen ahí. No se mueven a `docs/` |

**Un solo plan activo por zona.** Steve cruza etapas abiertas de `/optimize-app`, `/architecture-audit` y `/app-store-ready` antes de cada `go`. Mover archivos que otro plan está editando es la forma más fácil de romper las dos cosas.

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/clean-folder-project` | Auditoría completa: inventario, estructura objetivo, tabla de destinos, plan por etapas |
| `/clean-folder-project quick` | Solo basura, `.gitignore`, archivos rastreados que no deberían y violaciones de nombre. Reporte, sin plan de movimientos. Útil antes de un PR |
| `/clean-folder-project <carpeta>` | Solo esa zona (ej: `Features/Tasks`, `Resources`) |
| `/clean-folder-project go <n>` | Aprueba e implementa la etapa `n` del plan existente |

---

## Quién hace qué

| Fase | Agente | Rol |
|------|--------|-----|
| 0 · Contra qué se ordena | Steve | Lee TRD (la arquitectura decidida es el esqueleto), audits previos, detecta XcodeGen vs `.xcodeproj` manual |
| 1 · Inventario | **Avie** | Árbol real, basura, rastreados indebidos, nombres, archivos multi-tipo, huérfanos, assets y strings sin uso, `.gitignore` |
| 2 · Estructura objetivo | Avie | El estándar de facto adaptado al nivel de arquitectura del TRD. Árbol antes / después |
| 3 · Tabla archivo → destino | Avie | Cada archivo: se queda / se mueve a / se renombra / se borra, con razón |
| 4 · Plan por etapas | Avie + Steve | Etapas que compilan solas; `git mv`; una clase de movimiento por etapa |
| 5 · Implementación | Woz → Bertrand → Avie | **Solo con `go <n>`.** Woz mueve y regenera; Bertrand: build + tests + previews; Avie: el árbol coincide con el objetivo; Steve cierra y actualiza `TRD.md` y `PROJECT_STRUCTURE.md` |

Avie lidera y no Woz: quien escribió los archivos no es quien mejor ve dónde deberían estar.

---

## Antes de empezar

Lee si existen:
- **`TRD.md`** — nivel de arquitectura (A–D), capas, targets, paquetes. **Las carpetas reflejan esto.** Si el TRD no describe la estructura, la Fase 2 la propone y el cierre la escribe ahí.
- **`ARCHITECTURE_AUDIT.md`** — si tiene veredicto CAMBIAR o AJUSTAR con etapas abiertas, coordina: no se ordenan carpetas que se van a reestructurar.
- **`PERFORMANCE_AUDIT.md`**, **`APP_STORE_READINESS.md`** — zonas con etapas abiertas.
- **`PROJECT_STRUCTURE.md`** — si ya existe, es re-audit: la convención ya está; mide desvíos y no repitas lo cerrado.
- **`project.yml`** (XcodeGen), **`Package.swift`**, **`Makefile`**, **`.gitignore`**, **`.swiftlint.yml`** — cómo está cableado el proyecto.
- **`PROJECT_LEARNINGS.md`** — incidentes por "no encontré el archivo" o "lo dupliqué sin saber que existía".

---

## Fase 0 — Contra qué se ordena (Steve)

1. **El esqueleto lo da el TRD.** Nivel A (local simple) tolera organización por capa; nivel B en adelante (MVVM con lógica real) se organiza **por feature**; nivel D son paquetes. No se inventa una estructura más ambiciosa que la arquitectura.
2. **Cómo está generado el proyecto:**

```bash
ls project.yml Package.swift *.xcodeproj *.xcworkspace 2>/dev/null
which xcodegen swiftlint periphery
```

| Situación | Consecuencia |
|-----------|--------------|
| **XcodeGen** (`project.yml`) — el estándar del equipo | Mover carpetas es `git mv` + `xcodegen generate`. Las carpetas *son* los grupos. Ideal |
| `.xcodeproj` manual, sin XcodeGen | Mover archivos en disco rompe referencias. Etapa 0 del plan: **adoptar XcodeGen** (Woz), o mover desde Xcode arrastrando. Avie lo propone, el usuario decide |
| SPM puro (`Package.swift`) | `Sources/<Target>/` y `Tests/<Target>Tests/` son obligatorios; el resto se ordena dentro |

3. **Rama limpia.** Mover archivos genera conflictos con cualquier rama abierta. Steve pregunta si hay trabajo en curso y recomienda: `main` limpio, una etapa por PR, avisar al equipo.
4. **Zonas bloqueadas** por otros planes activos → se anuncian antes de inventariar.

---

## Fase 1 — Inventario (Avie, con evidencia del repo)

### 1.1 Árbol real y densidad

```bash
find . -type d -not -path "*/.git*" -not -path "*/.build/*" -not -path "*/DerivedData/*" -not -name "*.xcassets" -not -path "*.xcassets/*" | sed 's|^\./||' | sort
find . -name "*.swift" -not -path "*/.build/*" | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -15   # archivos Swift por carpeta
find . -type d -empty -not -path "*/.git*"                                                                  # carpetas vacías
```

Carpetas con > 15 archivos Swift sin subcarpetas, carpetas de un solo archivo, profundidad > 5, carpetas que mezclan vistas con servicios: todo se anota.

### 1.2 Basura y rastreados indebidos — lo primero que se ve

```bash
git ls-files | grep -E "\.DS_Store|xcuserdata|\.xcuserstate|DerivedData|/build/|\.orig$|\.rej$|~$|\.swp$|\.bak$|Thumbs\.db|\.ipa$|\.dSYM|\.xcarchive|Pods/|fastlane/report\.xml|\.env$|\.p8$|\.p12$|\.mobileprovision$|GoogleService-Info\.plist"
git ls-files -z | xargs -0 du -k 2>/dev/null | sort -rn | head -15                                          # archivos más pesados rastreados
find . -name ".DS_Store" -not -path "*/.git/*" | wc -l
find . -iname "*copy*" -o -iname "*old*" -o -iname "*backup*" -o -iname "*final*" -o -iname "*untitled*" -o -iname "*new group*" -o -iname "*test123*" 2>/dev/null | grep -v "/.git/"
```

| Hallazgo | Severidad |
|----------|-----------|
| **Secretos** rastreados (`.env`, `.p8`, `.p12`, `GoogleService-Info.plist` con claves, API keys en código) | 🔴 → **Ivan**. Rotar la clave; `.gitignore` no borra el historial |
| `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `build/`, `.DS_Store` rastreados | 🔴 ruido en cada commit y conflictos gratuitos |
| Binarios > 5 MB rastreados sin LFS | 🟡 |
| `*.orig`, `*.bak`, "copy", "old", "final2", "Untitled" | 🟡 |
| Carpetas vacías | 🔵 |

### 1.3 Nombres

Convención Swift/Apple que sí es estándar de facto:

| Regla | Cómo se verifica |
|-------|------------------|
| El archivo se llama como el tipo principal que contiene: `TaskListView.swift` → `struct TaskListView` | script: primer `struct/class/enum/actor/protocol` público del archivo vs nombre |
| **Un tipo principal por archivo.** Tipos auxiliares pequeños (un `enum` de estado, un `PreviewProvider`) pueden convivir | contar declaraciones top-level por archivo |
| Extensiones: `Date+Formatting.swift`, `View+Shimmer.swift` | `grep -l "^extension" ` con nombre sin `+` |
| Sufijos consistentes: `View`, `ViewModel`, `Service`, `Repository`, `Store`, `Model`, `Tests` | archivos con sufijo que no corresponde al tipo (`FooManager` que es un `View`) |
| UpperCamelCase para tipos, archivos y carpetas; sin espacios, guiones ni acentos en nombres de archivo | `find . -name "* *" -o -name "*-*.swift"` |
| Tests reflejan el archivo que prueban: `TaskListViewModelTests.swift` | tests sin archivo fuente correspondiente y viceversa |

```bash
for f in $(find . -name "*.swift" -not -path "*/.build/*"); do
  base=$(basename "$f" .swift | sed 's/+.*//')
  grep -qE "^(public |internal |private |fileprivate |final |@MainActor |@Observable )*(struct|class|enum|actor|protocol) $base\b" "$f" || echo "NOMBRE ≠ TIPO: $f"
done 2>/dev/null | head -30
```

### 1.4 Ubicación — archivos en la capa equivocada

Con el TRD como referencia:

- `View` fuera de `Features/` o `UI/` · `Service`/`Repository` dentro de una carpeta de feature cuando lo usan varias · modelos de dominio dentro de una vista · `extension` sueltas en la raíz · utilidades en `App/`
- Archivos en la **raíz del target** que no sean `App`, `Info.plist`, entitlements, `PrivacyInfo.xcprivacy`
- Recursos (`.json`, `.plist`, fuentes, imágenes) fuera de `Resources/`
- Tests que no reflejan la estructura de `Sources`

### 1.5 Huérfanos — archivos y recursos sin uso

```bash
periphery scan --format json 2>/dev/null | jq -r '.[] | select(.kind=="class" or .kind=="struct" or .kind=="enum") | .location' | sort -u | head   # tipos sin referencias → archivo candidato
# Assets sin referencia en código
for img in $(find . -path "*.xcassets/*.imageset" -not -path "*/.build/*" | xargs -n1 basename | sed 's/\.imageset//'); do
  grep -rq "\"$img\"\|\.$img\b\|Image(\"$img\")\|ImageResource\.$img" --include="*.swift" . || echo "ASSET SIN USO: $img"
done
# Colores sin referencia
for c in $(find . -path "*.xcassets/*.colorset" -not -path "*/.build/*" | xargs -n1 basename | sed 's/\.colorset//'); do
  grep -rq "\"$c\"\|\.$c\b" --include="*.swift" . || echo "COLOR SIN USO: $c"
done
# Claves de xcstrings sin uso (reporte para Kim)
python3 -c "import json,sys,subprocess,glob
for f in glob.glob('**/*.xcstrings', recursive=True):
    keys=json.load(open(f))['strings'].keys()
    src=subprocess.run(['grep','-rho','--include=*.swift','\"[^\"]*\"','.'],capture_output=True,text=True).stdout
    print(f, [k for k in keys if f'\"{k}\"' not in src][:20])"
```

Un archivo cuyo único tipo no tiene referencias es candidato a borrar — **siempre confirmado a mano** por Avie (reflection, `@main`, storyboards, Intents y tests dan falsos positivos).

### 1.6 `.gitignore` y cableado

```bash
cat .gitignore 2>/dev/null || echo "SIN .gitignore"
git check-ignore -q xcuserdata DerivedData .DS_Store build && echo "ignora lo básico" || echo "FALTAN reglas básicas"
grep -n "sources:\|path:\|excludes:" project.yml 2>/dev/null
```

- `.gitignore` con el estándar Xcode/Swift: `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `build/`, `.DS_Store`, `*.ipa`, `*.dSYM.zip`, `.build/`, `*.xcresult`, `fastlane/report.xml`, `fastlane/screenshots/**/*.png`, `.env*`, `*.p8`, `*.p12`, `*.mobileprovision`
- `project.yml`: `sources` apunta a carpetas reales; `excludes` no oculta archivos que deberían borrarse; sin rutas a archivos individuales cuando una carpeta basta
- `.xcodeproj` rastreado con XcodeGen: decisión explícita (el equipo suele **no** rastrearlo y generarlo con `make gen`); si se rastrea, que sea a propósito y documentado

Salida de la fase: inventario con conteos y cada hallazgo con ruta y severidad.

---

## Fase 2 — Estructura objetivo (Avie)

No hay un estándar oficial de Apple para organizar un proyecto. Lo que sí hay es un **consenso de facto** para apps SwiftUI modernas — feature-first, `Core` compartido, `Resources` separados, tests que reflejan el código, un tipo por archivo, compatible con XcodeGen y SPM — y es lo que Avie aplica, **adaptado al nivel del TRD**:

### Nivel B (MVVM `@Observable`) — el default del equipo

```
<App>/
├── project.yml                 # XcodeGen — las carpetas son los grupos
├── Makefile                    # gen / build / test / archive
├── README.md
├── .gitignore
├── .swiftlint.yml
├── PRD.md  TRD.md  PROJECT_STRUCTURE.md  …   # documentos del equipo — en la raíz, los agentes los leen aquí
├── Packages/                   # paquetes SPM locales (AppleAppLabUI, módulos propios)
├── Scripts/                    # release.sh, ci_post_clone.sh, herramientas
├── .github/workflows/  |  ci_scripts/
│
├── <App>/                      # target principal
│   ├── App/                    # <App>App.swift, AppDelegate si hay, Environment/DI raíz, Info.plist, *.entitlements, PrivacyInfo.xcprivacy
│   ├── Features/               # una carpeta por feature — vertical: todo lo que solo esa feature usa
│   │   ├── Tasks/
│   │   │   ├── TaskListView.swift
│   │   │   ├── TaskListViewModel.swift
│   │   │   ├── TaskRowView.swift
│   │   │   └── TaskDetail/     # sub-feature si crece
│   │   ├── Settings/
│   │   └── Onboarding/
│   ├── Core/                   # lo que usan dos o más features
│   │   ├── Models/             # entidades de dominio, @Model de SwiftData
│   │   ├── Services/           # protocolos + implementaciones: red, auth, notificaciones
│   │   ├── Persistence/        # ModelContainer, migraciones, repositorios
│   │   ├── Navigation/         # Route, Router/Coordinator si existe
│   │   └── Extensions/         # Date+…, View+…, String+…
│   ├── UI/                     # componentes y estilos propios de esta app que NO están en AppleAppLabUI
│   │   ├── Components/
│   │   └── Theme/
│   ├── Resources/              # Assets.xcassets, Localizable.xcstrings, fuentes, JSON semilla, sonidos
│   └── Preview Content/        # solo para previews; excluido del build de release
│
├── <App>Tests/                 # refleja <App>/: Features/Tasks/TaskListViewModelTests.swift, Core/Persistence/…
│   ├── Features/
│   ├── Core/
│   ├── Fixtures/               # datos y mocks compartidos
│   └── TestPlan.xctestplan
├── <App>UITests/
│   └── Flows/                  # OnboardingUITests.swift, …
│
├── <App>Widget/                # cada extensión es un target hermano con su propio Info.plist y PrivacyInfo.xcprivacy
└── <App>ShareExtension/
```

**Reglas que hacen que funcione:**
- Una feature es una **carpeta**, no una capa. Si algo lo usan dos features, sube a `Core/`. Si lo usa una, se queda en la feature
- `Core/` no importa `Features/` — nunca. `Features/` no se importan entre sí: pasan por `Core/`
- `UI/` es solo lo que no está en `AppleAppLabUI` (`PATTERNS.md`). Antes de crear un componente en `UI/`, se comprueba que no exista ya en el paquete
- Tests **reflejan** la ruta del archivo que prueban
- `Preview Content/` va en `project.yml` como `developmentAssets` — no se embarca

### Nivel A (app local simple, ≤ 6 pantallas)

`App/`, `Views/`, `Models/`, `Resources/`, `Preview Content/`. Por capa es correcto aquí; feature-first sería ceremonia. Migra a B cuando dos vistas comparten un ViewModel o un servicio.

### Nivel C (Repository, sync, offline)

Nivel B + `Core/Data/` con `Repositories/`, `Local/`, `Remote/`, `Sync/`. El resto igual.

### Nivel D (modular)

Cada feature o dominio es un **paquete SPM local** en `Packages/` con su propio `Sources/` y `Tests/`; la app es una cáscara que los compone. Se llega aquí por `/architecture-audit`, no por esta rutina.

### Salida de la fase

Árbol **antes** (real) y **después** (objetivo) lado a lado, y una lista de **lo que no cambia** — carpetas que ya están bien se nombran para que nadie las toque.

---

## Fase 3 — Tabla archivo → destino (Avie)

Cada archivo del inventario aparece **una vez**. Nada se mueve todavía.

| Archivo actual | Acción | Destino / nuevo nombre | Razón | Requiere cambio de código |
|----------------|--------|------------------------|-------|---------------------------|
| `Views/TaskList.swift` | mover + renombrar | `Features/Tasks/TaskListView.swift` | contiene `struct TaskListView`; feature Tasks | no |
| `Helpers/Utils.swift` | dividir | `Core/Extensions/Date+Formatting.swift`, `Core/Extensions/String+Trimming.swift` | dos extensiones sin relación en un archivo | no |
| `Services/API.swift` | mover | `Core/Services/APIClient.swift` | tipo `APIClient` | no |
| `Assets.xcassets/old_logo.imageset` | borrar | — | sin referencias (1.5) | no |
| `Resources/seed.json` | mover | `<App>/Resources/Seed/seed.json` | recurso | **sí**: `Bundle.main.url(forResource:)` sin cambio; verificar `project.yml` |
| `.DS_Store` ×14 | borrar + ignorar | — | basura | no |
| `Config/Secrets.plist` | **🔴 → Ivan** | — | secreto rastreado | Ivan decide |
| `Views/Components/LabButtonCopy.swift` | borrar | — | duplica `LabButton` de AppleAppLabUI | sustituir 3 usos → **sí**, etapa propia |

La columna **"Requiere cambio de código"** es la que separa etapas seguras de etapas con riesgo: mover un `.swift` no cambia nada (Swift no tiene imports por ruta), pero mover recursos, cambiar nombres de tipos, o eliminar un archivo que se usa, sí.

---

## Severidades

**🔴 CRÍTICO** — rompe algo hoy o expone algo:
- Secretos rastreados en git
- Artefactos de build o `xcuserdata` rastreados (conflictos y ruido en cada commit)
- Dos recursos con el mismo nombre en assets distintos (el runtime carga el equivocado)
- Archivo referenciado en `project.yml` que no existe, o al revés

**🟡 IMPORTANTE** — cuesta cada día:
- Archivos en la capa equivocada según el TRD
- Varios tipos principales por archivo; nombre de archivo ≠ tipo
- Mezcla de organización por feature y por capa en el mismo target
- Tests que no reflejan el código
- Assets, colores o strings sin uso (peso + confusión)
- Sin `.gitignore` o incompleto

**🔵 MENOR** — cosmético:
- `.DS_Store`, carpetas vacías, orden alfabético roto en `project.yml`
- Nombres válidos pero inconsistentes (`Utils` vs `Utilities`)

---

## Fase 4 — Plan por etapas (Avie + Steve)

Las reglas comunes a todas las rutinas — cada etapa compila sola, un tipo de cambio por etapa, riesgo bajo primero, verificación y rollback explícitos, sin tocar zonas de otros planes — más las propias de mover archivos:

1. **`git mv` siempre.** Nunca borrar y crear. El historial de cada archivo se conserva y `git blame` sigue funcionando.
2. **Mover ≠ editar.** Una etapa que mueve archivos no cambia una sola línea dentro de ellos. Si un movimiento exige cambiar código (ruta de recurso, `@testable import`, `Bundle`), va en su **propia etapa**, marcada, con el cambio mínimo.
3. **Una clase de movimiento por etapa.** Orden recomendado:
   1. Basura y `.gitignore` (borrar rastreados indebidos, `.DS_Store`, añadir reglas) — riesgo cero
   2. Secretos → Ivan (fuera de esta rutina; se espera su cierre)
   3. Adoptar XcodeGen si no está (Woz) — solo si el usuario acepta
   4. `Resources/` — mover recursos y verificar carga en runtime
   5. `Core/` — modelos, servicios, extensiones compartidas
   6. `Features/` — **una feature por etapa**, con sus tests reflejados en la misma etapa
   7. `UI/` — componentes propios; sustituir duplicados de AppleAppLabUI en etapa aparte
   8. Renombrar archivos para que coincidan con su tipo
   9. Dividir archivos multi-tipo
   10. Borrar huérfanos confirmados (archivos, assets, strings con OK de Kim)
   11. `project.yml`, `Makefile`, CI, scripts, docs: rutas actualizadas — aunque normalmente cada etapa ya lo hace
4. **Cada etapa regenera y compila.** `xcodegen generate && xcodebuild build` + tests + previews. Si XcodeGen no está y el usuario no quiso adoptarlo, la etapa incluye la instrucción de arrastre en Xcode y el commit del `.xcodeproj`.
5. **Una etapa por PR**, sobre `main` limpio. Mover 40 archivos en un commit es imposible de revisar; mover una feature sí.
6. **Nada de "ya que estoy".** Si al mover un archivo Woz ve código malo, lo anota para `/optimize-app`. No lo arregla en esa etapa.

### Formato de cada etapa

```markdown
### Etapa N — [nombre corto]

**Qué:** [1–2 líneas]
**Tipo:** basura / gitignore / recursos / core / feature <X> / ui / renombrar / dividir / borrar huérfanos / cableado
**Archivos:** [n archivos — lista o referencia a la tabla de la Fase 3]
**Cambia código:** no / sí — [qué y por qué, mínimo]
**Riesgo:** Bajo / Medio / Alto — [por qué]
**Cómo se verifica:** `xcodegen generate && make build && make test` en verde · previews compilan · [recurso X carga en runtime] · Avie: el árbol de esta zona coincide con el objetivo
**Rollback:** un commit — `git revert` limpio (los `git mv` se revierten solos)
**Owner:** Woz
**Estado:** ⏳ Pendiente de aprobación
```

### Cierre de la rutina

Steve muestra el resumen y **se detiene**:

> "Estructura del proyecto lista en `PROJECT_STRUCTURE.md`.
>
> Inventario: 84 archivos Swift en 6 carpetas, 3 🔴 (`xcuserdata` rastreado, `Secrets.plist` rastreado → Ivan, `logo` duplicado en dos assets), 11 🟡, 6 🔵. Estructura objetivo: nivel B feature-first, 4 features. 17 archivos se quedan donde están.
>
> Etapa 1 — Basura y `.gitignore`. 16 archivos. Riesgo cero.
> Etapa 2 — `Resources/`. 9 archivos, verifica carga de `seed.json`. Riesgo bajo.
> Etapa 3 — `Core/` (modelos, servicios, extensiones). 12 archivos. Riesgo bajo.
> Etapa 4 — Feature Tasks + sus tests. 14 archivos. Riesgo bajo.
> …
>
> `Secrets.plist` está con Ivan; ninguna etapa lo toca.
> Para aplicar la primera: `/clean-folder-project go 1`."

**No mueve, renombra ni borra nada sin ese `go`.**

---

## Fase 5 — Implementación por etapa (`/clean-folder-project go <n>`)

```
Steve (lee la etapa n; cruza zonas con otros planes activos; confirma main limpio)
→ Woz (git mv / git rm según la tabla; xcodegen generate; un commit con mensaje "chore(structure): etapa n — …")
→ Bertrand (make build en verde · todos los tests pasan, ninguno borrado ni skip · previews compilan · si la etapa movió recursos, la app los carga en el dispositivo o simulador)
→ Avie (el árbol de la zona coincide con el objetivo; nombres = tipos; sin huérfanos nuevos)
→ Ivan (solo si la etapa tocó entitlements, PrivacyInfo, Info.plist o configs)
→ Steve (PROJECT_STRUCTURE.md: etapa ✅, tabla actualizada · TRD.md: sección "Estructura" refleja la realidad · CLAUDE.md del proyecto si menciona rutas)
→ Steve pregunta: "Etapa n cerrada, build y tests en verde. ¿Aplico la etapa n+1?"
```

Si el build o un test falla: Woz revierte el commit, Steve marca ⚠️ Revertida con la razón, se replantea. Nunca se avanza con una etapa rota. Nunca se "arregla rápido" el test para que pase.

**`PROJECT_STRUCTURE.md` queda como convención viva.** Cuando Woz o Steve creen archivos nuevos en el futuro, la sección "Dónde va cada cosa" es la referencia. Es lo que hace que el criterio C6 de `/architecture-audit` ("un dev nuevo sabe dónde va una feature en 5 minutos") se mantenga en PASS.

---

## PROJECT_STRUCTURE.md — documento que produce la rutina

```markdown
# PROJECT_STRUCTURE — [Nombre de la app]

> Convención de estructura del proyecto y estado de la limpieza. Build: [commit]. Fecha: [fecha].
> Nivel de arquitectura (TRD): B — MVVM @Observable, feature-first.
> Generación: XcodeGen (`project.yml`) — las carpetas son los grupos. `make gen` tras mover.

---

## Dónde va cada cosa — la convención

| Quiero añadir… | Va en… | Nombre |
|----------------|--------|--------|
| Una pantalla nueva de una feature existente | `Features/<Feature>/` | `<Algo>View.swift` + `<Algo>ViewModel.swift` |
| Una feature nueva | `Features/<Nueva>/` (carpeta nueva) | igual; sub-carpetas solo si > 8 archivos |
| Un modelo que usan dos features | `Core/Models/` | `<Entidad>.swift` |
| Un servicio (red, auth, notificaciones) | `Core/Services/` | `<Nombre>Service.swift` + protocolo en el mismo archivo o `<Nombre>Servicing.swift` |
| Persistencia, repositorios, migraciones | `Core/Persistence/` | `<Entidad>Repository.swift`, `SchemaV2.swift` |
| Una extensión | `Core/Extensions/` | `<Tipo>+<Qué>.swift` |
| Un componente visual propio | primero `PATTERNS.md`; si no existe en AppleAppLabUI → `UI/Components/` | `<Nombre>View.swift` |
| Un asset, color, fuente, string | `Resources/` (`Assets.xcassets`, `Localizable.xcstrings`) | lowerCamelCase para assets; claves de strings en inglés descriptivo |
| Datos de ejemplo para previews | `Preview Content/` | — |
| Un test | espejo del archivo: `<App>Tests/<misma ruta>/<Archivo>Tests.swift` | — |
| Un mock o fixture compartido | `<App>Tests/Fixtures/` | `Mock<Servicio>.swift`, `<Entidad>+Fixture.swift` |
| Un script | `Scripts/` | kebab-case, `.sh` ejecutable |
| Un documento del equipo | **raíz** | `MAYÚSCULAS.md` |

**Reglas:** `Core/` nunca importa `Features/`. Features no se importan entre sí. Un tipo principal por archivo, y el archivo se llama como él. Tests reflejan rutas.

---

## Árbol objetivo
[árbol de la Fase 2, adaptado a esta app]

## Lo que no cambia
[carpetas/archivos que ya cumplen]

---

## Estado

| Severidad | Abiertos | Cerrados |
|-----------|----------|----------|
| 🔴 | X | Y |
| 🟡 | X | Y |
| 🔵 | X | Y |

**Etapas activas:** [n] · **Zonas bloqueadas por otros planes:** [ninguna / rutas]
**Con Ivan:** [secretos rastreados, si los hay]

---

## Inventario — hallazgos

### 🔴 [STR-001] `xcuserdata/` rastreado
**Evidencia:** `git ls-files | grep xcuserdata` → 3 archivos, incluido `UserInterfaceState.xcuserstate` que cambia en cada apertura de Xcode
**Fix:** `git rm -r --cached`, regla en `.gitignore`
**Etapa:** 1 · **Estado:** ⏳

### 🟡 [STR-007] `Views/TaskList.swift` — nombre ≠ tipo, capa equivocada
…

---

## Tabla archivo → destino
[tabla completa de la Fase 3]

---

## Plan — por etapas

> Cada etapa compila y pasa tests sola. `git mv` siempre. Aprobar con `/clean-folder-project go <n>`.

### Etapa 1 — …
[formato de etapa]

---

## Historial

| Etapa | Fecha | Archivos | Commit | Build / Tests | Estado |
|-------|-------|----------|--------|---------------|--------|
```

---

## Cuándo Steve lanza esta rutina sin que se la pidan

- El usuario dice "está desordenado", "no encuentro nada", "¿dónde va esto?", "límpialo", "quiero que se vea profesional", "hay archivos por todas partes"
- Woz duplica un archivo porque no encontró el existente (aparece en `PROJECT_LEARNINGS.md`)
- `/architecture-audit` cierra su última etapa de código y quedan solo movimientos cosméticos — Steve los pasa a esta rutina
- Antes de abrir el repo a otra persona o de un `/app-store-ready`
- El `git status` muestra `xcuserstate` o `.DS_Store` modificados en cada sesión

## Lo que esta rutina NO hace

- No mueve, renombra ni borra sin `go <n>`
- No decide arquitectura — refleja el TRD; si el TRD está mal, `🏗` → `/architecture-audit`
- No edita el contenido de los archivos salvo el cambio mínimo que un movimiento exige, en etapa propia
- No toca entitlements, `PrivacyInfo.xcprivacy` ni configs con secretos sin Ivan
- No borra strings sin Kim si la app es multi-idioma
- No mueve los documentos del equipo de la raíz
- No hace "ya que estoy": lo que encuentra dentro de los archivos va a `/optimize-app`

---

## Tono

- Cada hallazgo tiene ruta y comando que lo produjo.
- Sin dogma: "feature-first porque el TRD es nivel B y hay 4 features", no "porque es lo correcto".
- Lo que ya está bien se dice. Un proyecto ordenado en un 70 % no necesita que se le mueva todo.
- Español o inglés: el del usuario.
