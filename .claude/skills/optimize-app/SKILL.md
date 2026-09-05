---
name: optimize-app
description: "Rutina de performance. Bertrand mide con Instruments, Avie revisa el código (loops, trabajo redundante, main thread, leaks, duplicación) y Steve entrega PERFORMANCE_AUDIT.md con un plan por etapas. 'go <n>' aplica cada etapa. Úsalo cuando la app esté lenta, se trabe, se loopee o haya código repetido."
---

# /optimize-app — Auditoría de performance y plan de optimización

Rutina del equipo, no un agente. Cuando se lanza, Steve orquesta a Bertrand, Avie y Woz para auditar la app completa — medición en dispositivo **y** revisión del código — y entrega `PERFORMANCE_AUDIT.md` con un **plan por etapas** para arreglarlo sin romper la app.

**El skill termina en el plan.** No implementa nada hasta que el usuario apruebe cada etapa explícitamente.

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/optimize-app` | Auditoría completa: flujos críticos, medición dinámica, revisión estática, plan |
| `/optimize-app <pantalla o flujo>` | Solo ese flujo (ej: `/optimize-app HomeView`, `/optimize-app onboarding`) |
| `/optimize-app quick` | Solo revisión estática del código — sin dispositivo, sin Instruments. Útil antes de un commit grande |
| `/optimize-app go <n>` | Aprueba e implementa la etapa `n` del plan existente |

---

## Quién hace qué

| Fase | Agente | Rol |
|------|--------|-----|
| 0 · Preparación | Steve | Lee PRD.md, elige flujos críticos, fija dispositivo de medición, guarda baseline |
| 1 · Producción | Bertrand | Lee Xcode Organizer / MetricKit si la app ya está en usuarios |
| 2 · Medición dinámica | Bertrand | Instruments por área: launch, hangs, hitches, SwiftUI, memoria, disco, energía, tamaño |
| 3 · Revisión estática | **Avie** | Lee el código buscando loops, trabajo redundante, duplicación, main thread, retain cycles. Avie y no Woz: nadie revisa su propio código |
| 4 · Plan por etapas | Steve + Avie | Ordena hallazgos en etapas aplicables sin romper la app |
| 5 · Implementación | Woz → Bertrand | **Solo con `go <n>`.** Woz implementa la etapa, Bertrand re-mide contra baseline, Steve marca la etapa cerrada y pide aprobación de la siguiente |

---

## Antes de empezar

Lee si existen:
- **`PRD.md`** — qué flujos son core. Los flujos críticos salen de aquí, no de suposiciones.
- **`TRD.md`** — stack, persistencia, sync. Define dónde buscar (SwiftData, CloudKit, red).
- **`TEST_PLAN.md`** — la sección Performance de Bertrand si ya existe: es el baseline previo.
- **`PERFORMANCE_AUDIT.md`** — si ya existe, este es un re-audit: compara contra él y no repitas hallazgos cerrados.
- **`PROJECT_LEARNINGS.md`** y **`.appleapplab/KNOWN_ISSUES.md`** — patrones de performance ya documentados.

---

## Fase 0 — Preparación (Steve)

1. **Flujos críticos.** Del PRD, elige 3–5: siempre incluye launch y la pantalla principal; añade la lista más larga, el flujo de guardar, y cualquier flujo con red o sync.
2. **Dispositivo de medición.** El mínimo del target (iPhone SE 3ª gen en iOS 17+; el Mac más viejo soportado en macOS). Nunca el simulador para números finales. Build `Release` con símbolos.
3. **Detectar qué hay disponible** y anunciarlo antes de medir:

```bash
xcrun xctrace list devices          # ¿hay dispositivo o simulador?
which swiftlint periphery            # ¿herramientas estáticas?
ls *.xcresult 2>/dev/null            # ¿resultados previos?
```

| Disponible | Qué se hace |
|------------|-------------|
| Dispositivo real conectado | Fase 2 completa con `xctrace` |
| Solo simulador | Fase 2 con `xctrace` en simulador — números marcados como *orientativos* |
| Nada | Fase 2 se documenta como pendiente con pasos exactos para el usuario; Fase 3 completa |

4. **Baseline.** Antes de tocar nada, un trace por flujo crítico. Sin baseline no hay forma de demostrar mejora.

---

## Fase 1 — Producción (Bertrand, solo si la app ya está en manos de usuarios)

Xcode Organizer es GUI — no se automatiza. Bertrand pide al usuario:

> "Abre Xcode → Window → Organizer → [app] → Metrics. Exporta o pega: Launch Time, Hang Rate, Scroll Hitch Rate, Memory, Disk Writes, Terminations. Y en Reports → Hangs, los stack traces de los 3 hangs más frecuentes."

Con eso, Bertrand sabe **dónde duele en usuarios reales** y prioriza la Fase 2 ahí. Si MetricKit está integrado (`MXMetricManager`), lee los payloads directamente.

---

## Fase 2 — Medición dinámica (Bertrand)

Por área, con umbral y herramienta. Cada medición se hace en el flujo crítico correspondiente.

| Área | Template de Instruments | Umbral | Qué buscar |
|------|------------------------|--------|-----------|
| **Launch** | App Launch | < 400 ms primer frame (ideal), < 2 s (aceptable) | Red, disco, Keychain, inicializadores pesados antes del primer frame |
| **Hangs** | Time Profiler + Hangs | 0 bloqueos > 250 ms | CPU alto → código lento. CPU idle → esperando I/O o lock (System Trace) |
| **Hitches** | Animation Hitches | 0 frames perdidos en scroll | > 16.7 ms (60 Hz) / > 8.3 ms (ProMotion) por frame |
| **SwiftUI** | SwiftUI (Instruments 26) | Sin long body updates, sin updates innecesarios | Cause & Effect Graph: un tap que dispara N redraws en cascada. **Aquí aparecen los loops.** |
| **Memoria** | Allocations + Leaks | Sin leaks; footprint < 150 MB en SE; memoria vuelve al baseline tras salir de pantalla | Entrar/salir 5 veces marcando generaciones — si no vuelve, hay leak |
| **Disco** | File Activity | Sin escrituras repetidas | SwiftData guardando por keystroke, logs, cache sin límite |
| **Energía** | Energy Log | "Low" en 5 min de uso típico | Timers, location, red en background |
| **Tamaño** | Archive → App Thinning Size Report | Proporcional a la app | Assets sin comprimir, fuentes no usadas, dependencias pesadas |

### Comandos automatizables

```bash
# Time Profiler sobre el launch (sustituye el bundle id y el destino)
xcrun xctrace record --template 'Time Profiler' \
  --device '<UDID o nombre>' \
  --launch -- <bundle.id> \
  --time-limit 15s \
  --output baseline-launch.trace

# Allocations sobre un flujo
xcrun xctrace record --template 'Allocations' \
  --device '<UDID>' --attach <bundle.id> \
  --time-limit 60s --output baseline-memory.trace

# Exportar a XML para leer desde terminal
xcrun xctrace export --input baseline-launch.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' \
  --output launch.xml
```

Las plantillas **SwiftUI**, **Animation Hitches** y el **Cause & Effect Graph** solo se leen en la GUI. Bertrand da los pasos exactos y el usuario reporta lo que ve.

### Tests de performance como baseline reproducible

```swift
func testLaunchPerformance() {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
        XCUIApplication().launch()
    }
}

func testHomeListScroll() {
    let app = XCUIApplication(); app.launch()
    measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric, XCTMemoryMetric()]) {
        app.collectionViews.firstMatch.swipeUp(velocity: .fast)
    }
}
```

Salida de la fase: tabla *flujo → métrica → medido → umbral → estado*.

---

## Fase 3 — Revisión estática del código (Avie)

Guiada por la Fase 2: primero el código de los flujos que fallaron, después el resto. Si no hubo Fase 2 (`quick`), toda la app.

### Frontera con `/architecture-audit` — regla del tag 🏗

`/optimize-app` = **síntoma medible + fix local**. `/architecture-audit` = **estructura**.

Si el fix de un hallazgo exige cambiar estructura — mover una fuente de verdad, crear una capa, cambiar cómo se inyecta un servicio, migrar el modelo de observación de toda la app, reorganizar carpetas — Avie **no lo planifica aquí**. Lo reporta con el tag `🏗 arquitectura`, con causa y evidencia, y queda como entrada para `/architecture-audit`. Aquí se planifica solo lo que se arregla en su sitio.

| Hallazgo | Dónde va |
|----------|----------|
| `onChange` que se escribe a sí mismo | optimize |
| Loop porque dos objetos tienen la misma lista (dos fuentes de verdad) | 🏗 arquitectura |
| Extraer un formatter duplicado a un helper | optimize |
| La misma regla de negocio copiada en varias features → falta una capa | 🏗 arquitectura |
| Un `@Observable` por fila *en esta lista* | optimize |
| Migrar toda la app de `ObservableObject` a `@Observable` | 🏗 arquitectura |
| `try!` o I/O síncrono en una vista | optimize |
| Vistas que llaman directo a `URLSession` / `modelContext` en toda la app | 🏗 arquitectura |

### 3.1 Loops y trabajo que se repite — lo más valioso

Patrones que Avie busca uno por uno. Cada uno es un hallazgo con `archivo:línea`:

| Patrón | Cómo se detecta | Por qué es un loop |
|--------|----------------|-------------------|
| `onChange(of: x) { x = ... }` | `grep -n "onChange"` y leer el cuerpo | Escribe la variable que observa → ciclo |
| Mutar `@State` / `@Observable` dentro de `body` | Leer cada `body` con asignaciones | Cada render dispara otro render |
| `.task(id:)` con id que cambia cada render | `grep -n "\.task(id:"` | Cancela y relanza en cada update |
| `.onAppear { fetch() }` / `.task { fetch() }` sin guard | `grep -n "onAppear\|\.task {"` | Se dispara cada vez que la vista reaparece (tabs, navegación atrás) |
| `Timer` sin `invalidate`, `Task` sin `cancel` | `grep -n "Timer\.\|Task {"` y buscar el cierre | Siguen corriendo con la vista destruida |
| Dos `@Observable` que se actualizan mutuamente | Leer los `didSet` y observaciones cruzadas | Ping-pong infinito. Si la causa es que ambos son fuente de verdad del mismo dato → `🏗 arquitectura` |
| `NotificationCenter` que publica en respuesta a la misma notificación | `grep -n "post(name"` | Ciclo por eventos |
| Vista que depende de un array completo para mostrar un ítem | `ForEach(items)` con `items` como `@Observable` de toda la lista | Un cambio en un ítem redibuja todos |

### 3.2 Trabajo redundante

| Patrón | Detección |
|--------|-----------|
| `DateFormatter()` / `NumberFormatter()` / `JSONDecoder()` dentro de `body` o computed property | `grep -n "Formatter()\|JSONDecoder()"` — deben ser `static let` o cacheados |
| Computed property cara leída en cada redraw | Leer `var x: T {` con loops o `filter`/`sorted` sin cache |
| Fetch N+1 en listas | `@Query` o `fetch` dentro de una fila de `ForEach` |
| Misma `@Query` / `FetchDescriptor` en varias vistas | `grep -n "@Query\|FetchDescriptor"` y comparar predicados |
| Imagen decodificada en cada render | `UIImage(named:)` / `Image(uiImage:)` con datos crudos en `body` |
| `.sorted()` / `.filter` sobre colección grande en `body` | Leer `body` |

### 3.3 Main thread

- Activar en el scheme **Main Thread Checker** y **Thread Sanitizer** y correr los flujos críticos.
- `grep -n "try!\|Data(contentsOf\|String(contentsOf\|FileManager.*contents"` — I/O síncrono en vistas o ViewModels.
- `JSONDecoder().decode` fuera de `Task.detached` o actor.
- `@MainActor` en clases que hacen trabajo pesado.

### 3.4 Retain cycles

- `grep -n "self\." dentro de closures sin `[weak self]` en clases (no structs).
- Delegates declarados `var delegate: X` sin `weak`.
- Combine `.sink` sin `.store(in: &cancellables)`.
- `NotificationCenter.addObserver` sin `removeObserver` (ni en `deinit`).

### 3.5 Duplicación y código muerto

```bash
swiftlint lint --reporter json 2>/dev/null | jq '[.[] | select(.rule_id | test("cyclomatic|function_body_length|file_length|type_body_length"))]'
periphery scan --format json 2>/dev/null
```

Si no están instalados, Avie lo hace por lectura: bloques de > 15 líneas que aparecen en 2+ archivos → hallazgo. **Lo duplicado se extrae antes de optimizarlo** — si el patrón malo está copiado 6 veces, se arregla una vez en un solo lugar.

Aquí se queda la duplicación *mecánica* (un helper, un formatter, un modifier). Si lo duplicado es **lógica de negocio** repetida entre features, eso es una capa que falta → `🏗 arquitectura`.

Código muerto *dentro* de un archivo (funciones, propiedades, ramas) se queda aquí. **Archivos completos** sin referencias, assets y strings sin uso, y basura en git son de `/clean-folder-project` — se reportan con el tag `🧹 estructura` y no se planifican aquí.

### 3.6 Granularidad de observación

- Un `@Observable` por ítem en listas, no toda la lista dependiendo del array. *Fix local por lista → optimize.*
- Nada volátil (geometría, timers, scroll offset) en `Environment` — cascadea a todas las vistas dependientes. *Fix local → optimize.*
- `ObservableObject` + `@Published` → `@Observable` evita redraws innecesarios por diseño. *Si es una clase aislada → optimize. Si es el modelo de observación de toda la app → `🏗 arquitectura`.*

Salida de la fase: hallazgos con `archivo:línea`, causa, fix sugerido, severidad.

---

## Severidades

**🔴 CRÍTICO** — hace la app visiblemente lenta o inestable hoy:
- Loop de redraw o de fetch
- Hang > 250 ms en flujo crítico
- Leak que crece con el uso
- I/O síncrono en main thread en launch o scroll

**🟡 IMPORTANTE** — degrada la experiencia o va a doler pronto:
- Hitches en scroll
- Trabajo redundante en `body` (formatters, sorts)
- Fetch N+1
- Launch entre 400 ms y 2 s

**🔵 MENOR** — no se nota aún pero es deuda:
- Duplicación de código
- Código muerto
- Tamaño de app por assets sin comprimir
- `ObservableObject` que podría ser `@Observable`

---

## Fase 4 — Plan por etapas (Steve + Avie)

Aquí está el valor del skill. Los hallazgos no se entregan como lista plana — se agrupan en **etapas aplicables de forma independiente, sin romper la app**.

### Reglas para diseñar las etapas

1. **Cada etapa es shippable sola.** Al terminarla, la app compila, los tests pasan, y funciona igual o mejor. Nunca una etapa deja la app a medias.
2. **Orden: riesgo bajo + impacto alto primero.** Los loops de redraw suelen ser etapa 1 — máximo impacto, cambio localizado. Refactors de arquitectura (migrar a `@Observable`, extraer duplicados grandes) van al final aunque sean importantes.
3. **Una etapa = un tipo de cambio.** No mezclar "arreglar loop en HomeView" con "extraer formatters a un helper". Si algo sale mal, se sabe qué fue.
4. **Nada de dos etapas tocando el mismo archivo a la vez.** Si dos hallazgos viven en el mismo archivo, van en la misma etapa o en etapas consecutivas.
5. **Cada etapa dice cómo se verifica y cómo se revierte.**
6. **Los hallazgos `🏗 arquitectura` no forman etapas aquí.** Se listan en una sección aparte del documento como entrada para `/architecture-audit`.
7. **Un solo plan activo por zona.** Si existe `ARCHITECTURE_AUDIT.md` con etapas abiertas, Steve no crea etapas de optimización en los archivos que esas etapas van a reestructurar — no tiene sentido optimizar código que se va a mover. Esas zonas quedan marcadas *"pendiente de arquitectura"*.

### Formato de cada etapa

```markdown
### Etapa N — [nombre corto]

**Qué:** [1–2 líneas]
**Hallazgos que cierra:** PERF-003, PERF-007
**Archivos:** `Views/HomeView.swift`, `ViewModels/HomeViewModel.swift`
**Riesgo:** Bajo / Medio / Alto — [por qué]
**Ganancia esperada:** [métrica concreta: "hang de 380 ms → 0", "redraws por tap 40 → 1"]
**Cómo se verifica:** [qué mide Bertrand, qué test corre]
**Rollback:** [un commit atómico — `git revert` limpio]
**Owner:** Woz
**Estado:** ⏳ Pendiente de aprobación
```

### Cierre del skill

Al terminar la Fase 4, Steve muestra el resumen y **se detiene**:

> "Auditoría lista en `PERFORMANCE_AUDIT.md`. X hallazgos (🔴 a · 🟡 b · 🔵 c) organizados en N etapas. Cada etapa se aplica sola sin romper la app.
>
> Etapa 1 — [nombre]: [ganancia]. Riesgo bajo.
> Etapa 2 — …
>
> Para aplicar la primera: `/optimize-app go 1`."

Si hay hallazgos `🏗 arquitectura` de severidad 🔴, Steve añade:

> "Hay N hallazgos críticos que son de estructura, no de código local — están listados como entrada para `/architecture-audit`. Recomiendo correrla antes de aplicar las etapas que tocan esa zona. Las etapas [x, y] no la tocan y se pueden aplicar ya."

**No implementa nada sin ese `go`.**

---

## Fase 5 — Implementación por etapa (`/optimize-app go <n>`)

Solo se ejecuta cuando el usuario aprueba la etapa `n`. Si pide `go 3` y la 1 o 2 no están cerradas, Steve avisa y pregunta si de verdad quiere saltarse el orden.

```
Steve (lee la etapa n del plan)
→ Woz (implementa solo lo que dice la etapa, un commit por etapa)
→ Bertrand (re-mide el flujo afectado contra el baseline; corre los tests de performance)
→ Steve (actualiza PERFORMANCE_AUDIT.md: hallazgos → ✅, etapa → ✅ Cerrada con medición antes/después)
→ Steve pregunta: "Etapa n cerrada: [antes] → [después]. ¿Aplico la etapa n+1?"
```

Si la re-medición **no mejora** o algo se rompe: Woz revierte el commit, Steve marca la etapa como ⚠️ Revertida con la razón, y se replantea antes de continuar. Nunca se sigue a la siguiente etapa con una anterior rota.

**Antes de cada `go`**, Steve cruza con `ARCHITECTURE_AUDIT.md` si existe: si la etapa toca archivos con una etapa de arquitectura abierta, avisa y no la aplica. Y si una etapa de arquitectura se cerró después del baseline, Bertrand **vuelve a tomar baseline** de los flujos afectados — el viejo ya no corresponde al código.

Re-medición con comparación directa:

```bash
# Instruments 26 — baseline vs. nuevo en un mismo documento, delta en rojo/verde
open -a Instruments baseline-launch.trace after-launch.trace
```

---

## PERFORMANCE_AUDIT.md — documento que produce la rutina

```markdown
# PERFORMANCE_AUDIT — [Nombre de la app] v[X.Y]

> Auditoría de performance. Build: [commit]. Dispositivo: [modelo, OS]. Fecha: [fecha].
> Modo: completo / quick / [flujo]

---

## Resumen

| Severidad | Abiertos | Cerrados |
|-----------|----------|----------|
| 🔴 Crítico | X | Y |
| 🟡 Importante | X | Y |
| 🔵 Menor | X | Y |

**Estado:** Plan pendiente de aprobación / Etapa N en curso / Completo

---

## Flujos críticos auditados

1. Launch → HomeView
2. [flujo]
3. [flujo]

---

## Métricas — baseline

| Flujo | Métrica | Medido | Umbral | Estado |
|-------|---------|--------|--------|--------|
| Launch | Primer frame | 1.4 s | < 400 ms | ❌ |
| HomeView | Hang máx. | 380 ms | < 250 ms | ❌ |
| HomeView scroll | Hitches | 12 / 60 frames | 0 | ❌ |
| HomeView | Redraws por tap favorito | 40 | 1 | ❌ |
| App | Memoria tras 5 ciclos | +38 MB | ±0 | ❌ |
| App | Leaks | 3 | 0 | ❌ |

*Mediciones pendientes (sin dispositivo):* [lista con pasos para el usuario]

---

## Hallazgos

### 🔴 [PERF-001] Loop de redraw en HomeView al marcar favorito

**Archivo:** `Views/HomeView.swift:42`
**Causa:** `ForEach(store.items)` — toda la lista depende del array completo; un cambio en un ítem redibuja los 40.
**Evidencia:** SwiftUI instrument — Cause & Effect: 1 tap → 40 body updates.
**Fix sugerido:** `@Observable` por ítem; la fila observa solo su ítem.
**Etapa:** 1
**Estado:** ⏳

### 🟡 [PERF-002] DateFormatter creado en cada render de TaskRow

**Archivo:** `Views/TaskRow.swift:18`
…

---

## 🏗 Entrada para /architecture-audit

> Hallazgos cuyo fix exige cambiar estructura. No se planifican aquí.

| ID | Hallazgo | Evidencia | Por qué es estructura |
|----|----------|-----------|----------------------|
| PERF-004 | `TaskStore` y `HomeViewModel` tienen ambos la lista de tareas | Loop al editar: 2 fuentes de verdad se sincronizan mutuamente | Hay que decidir una sola fuente de verdad |

---

## Plan de optimización — por etapas

> Cada etapa se aplica sola. La app compila y funciona al terminar cada una.
> Aprobar con `/optimize-app go <n>`.
> Zonas pendientes de arquitectura: [archivos con etapas abiertas en ARCHITECTURE_AUDIT.md, o "ninguna"]

### Etapa 1 — Cortar loops de redraw en HomeView
[formato de etapa]

### Etapa 2 — Sacar trabajo redundante de los body
[formato de etapa]

### Etapa 3 — Launch: diferir todo lo que no genera el primer frame
[formato de etapa]

### Etapa 4 — Leaks y ciclos de retención
[formato de etapa]

### Etapa 5 — Extraer duplicados y borrar código muerto
[formato de etapa]

---

## Historial de etapas

| Etapa | Fecha | Antes | Después | Commit | Estado |
|-------|-------|-------|---------|--------|--------|
| 1 | — | 40 redraws | — | — | ⏳ |

---

## Tests de regresión añadidos

- `PerformanceTests/LaunchTests.swift` — `XCTApplicationLaunchMetric`, baseline 380 ms
- …
```

---

## Cuándo Steve lanza esta rutina sin que se la pidan

- El usuario dice "la app está lenta", "se traba", "tarda en abrir", "consume mucha batería", "se loopea", "hay código repetido"
- Bertrand encuentra en TEST_PLAN.md una métrica de performance fuera de umbral y el fix no es trivial
- Chris reporta en COMPAT_AUDIT.md lentitud o hang en el dispositivo mínimo
- Antes de un lanzamiento público si nunca se ha corrido — Steve lo propone, no lo impone

## Lo que esta rutina NO hace

- No implementa sin `go <n>`
- No toca estructura — lo estructural se marca `🏗 arquitectura` y es entrada para `/architecture-audit`, que tiene su propio plan por etapas
- No cambia el diseño visual — si un hallazgo pide cambiar UI, entra Jonny en esa etapa
- No sustituye a Ivan: si un fix toca seguridad, entitlements o red, Ivan revisa esa etapa antes de cerrarla

---

## Tono

- Números o no existe. Cada hallazgo tiene medición o `archivo:línea`.
- Sin especulación: "probablemente es lento" no es un hallazgo.
- El plan se explica para que el usuario decida, no para impresionar.
- Español o inglés: el del usuario.
