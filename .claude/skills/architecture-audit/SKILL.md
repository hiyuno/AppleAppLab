---
name: architecture-audit
description: "Rutina de arquitectura. Avie mapea la estructura real vs TRD y roadmap, verifica 6 criterios de salud, da veredicto MANTENER / AJUSTAR / CAMBIAR y entrega ARCHITECTURE_AUDIT.md con plan de migración por etapas. 'go <n>' aplica cada etapa. Úsalo cuando cada feature cueste, quieras refactorizar o vayas a meter sync o un widget."
---

# /architecture-audit — Auditoría de arquitectura y plan de migración

Rutina del equipo, no un agente. Cuando se lanza, Steve orquesta a Avie (líder), Ivan, Bertrand y Woz para responder una sola pregunta: **¿la arquitectura que tiene la app es la correcta para lo que la app hace hoy y para lo que viene en el roadmap?** Entrega `ARCHITECTURE_AUDIT.md` con un veredicto — MANTENER / AJUSTAR / CAMBIAR — y, si aplica, un **plan de migración por etapas** que nunca rompe la app.

**El skill termina en el veredicto y el plan.** No implementa nada hasta que el usuario apruebe cada etapa explícitamente.

---

## Frontera con `/optimize-app`

| | `/optimize-app` | `/architecture-audit` |
|--|--|--|
| Pregunta | ¿Qué está lento y por qué? | ¿La estructura aguanta lo que la app necesita? |
| Método | Mide con Instruments, revisa código de los flujos lentos | Mapea la estructura real, la compara con el TRD y el roadmap |
| Fix | Local, en su sitio | Estructural: capas, fuentes de verdad, dependencias, DI |
| Entrada cruzada | Marca hallazgos `🏗 arquitectura` → entrada para esta rutina | Lee `PERFORMANCE_AUDIT.md` como señal. **No re-mide** |
| Documento | `PERFORMANCE_AUDIT.md` | `ARCHITECTURE_AUDIT.md` |

**Un solo plan activo por zona.** Steve no abre etapas de esta rutina en archivos con etapas abiertas de `/optimize-app`, ni al revés. Ambos documentos llevan sección *Etapas activas* y Steve la cruza antes de cada `go`. Al cerrar una etapa de arquitectura, Bertrand vuelve a tomar baseline de performance de los flujos afectados.

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/architecture-audit` | Auditoría completa contra PRD + roadmap |
| `/architecture-audit <feature>` | "¿La arquitectura aguanta meter X?" — ej: `/architecture-audit sync`, `/architecture-audit widget`. Solo las fases que X afecta |
| `/architecture-audit quick` | Solo criterios de salud y señales, sin roadmap. Útil antes de una feature grande |
| `/architecture-audit go <n>` | Aprueba e implementa la etapa `n` del plan existente |

---

## Quién hace qué

| Fase | Agente | Rol |
|------|--------|-----|
| 0 · Contra qué se audita | Steve | PRD, roadmap, TRD, auditorías previas. Define el *target* |
| 1 · Mapa de lo que existe | **Avie** | Estructura, grafo de dependencias, inventario de estado, datos, navegación, concurrencia, DI, tests — con evidencia del repo |
| 2 · Las 6 preguntas | Avie | TRD asumió · la app hace · el roadmap necesita. Nivel actual vs necesario |
| 3 · Los 6 criterios de salud | Avie | PASS/FAIL con `archivo:línea` |
| 4 · Señales de que duele | Avie | Churn, archivos gordos, features recientes, bugs repetidos, loops, lo que viene |
| 5 · Revisión cruzada | Ivan, Bertrand, Eve/Chris | Fronteras de seguridad, testabilidad, multi-target |
| 6 · Veredicto | Avie + Steve | MANTENER / AJUSTAR / CAMBIAR + qué NO tocar |
| 7 · Arquitectura objetivo | Avie | Solo si AJUSTAR o CAMBIAR. Justificada contra el roadmap |
| 8 · Plan de migración | Avie + Steve | Etapas strangler, tests antes de mover, sin reescritura |
| 9 · Implementación | Woz → Bertrand → Avie | **Solo con `go <n>`.** Woz migra, Bertrand confirma tests, Avie verifica el criterio, Steve cierra y actualiza `TRD.md` |

Avie lidera y no Woz: nadie audita su propio código.

---

## Antes de empezar

Lee si existen:
- **`PRD.md`** — qué hace la app y qué features vienen. Es el *target*.
- **`TRD.md`** — lo que Avie decidió al inicio y *por qué no subió de nivel*. La auditoría compara lo decidido, lo construido y lo necesario.
- **`PERFORMANCE_AUDIT.md`** — hallazgos `🏗 arquitectura` son entrada directa. Los loops y redraws en cascada son síntomas de estructura.
- **`PROJECT_LEARNINGS.md`** y **`.appleapplab/KNOWN_ISSUES.md`** — bugs repetidos = lógica que debería vivir en un solo sitio.
- **`ARCHITECTURE_AUDIT.md`** — si ya existe, es re-audit: compara y no repitas lo cerrado.
- **`SECURITY_AUDIT.md`** — dónde Ivan ubicó secretos, red y auth.

---

## Fase 0 — Contra qué se audita (Steve)

> **¿Hace falta?** Antes de lanzar esta rutina — suelta o dentro de `/global-audit` — Steve hace el triage de `.claude/skills/global-audit/SKILL.md` Fase 0 (sonda de 7 comandos → etapa del proyecto). En un proyecto **nuevo o recién generado por Woz desde el TRD** esta rutina no aplica: la estructura *es* el TRD que Avie escribió hace días — no hay nada que comparar. Steve lo dice en una línea en vez de correrla; si el usuario insiste, se corre. En construcción, solo por señal y en modo `quick`.

Una arquitectura no es buena o mala sola — es buena o mala **para lo que la app necesita**.

1. **Target.** Del PRD y el roadmap: qué hace la app hoy y qué entra en los próximos 2 releases. Si en 3 meses entra sync o un widget, la arquitectura se juzga contra eso.
2. **Lo decidido.** Del TRD: nivel elegido, capas, fuente de verdad, y la justificación de no haber subido de nivel.
3. **Síntomas ya documentados.** De PERFORMANCE_AUDIT, PROJECT_LEARNINGS, KNOWN_ISSUES.
4. **Alcance.** Toda la app, o una feature concreta (`<feature>`).

Steve anuncia el target antes de que Avie empiece: *"Se audita contra: [features hoy] + [lo que viene: sync en v1.2, widget en v1.3]"*.

---

## Fase 1 — Mapa de lo que realmente existe (Avie)

Lo que está construido, no lo que dice el TRD. Con evidencia del repo, no de memoria.

### 1.1 Estructura

```bash
find . -name "*.swift" -not -path "*/.build/*" | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -20   # archivos por carpeta
find . -name "Package.swift" -not -path "*/.build/*"                                                        # paquetes SPM
grep -n "targets:" -A 30 project.yml 2>/dev/null                                                            # targets
```

¿Por capa (`Views/`, `ViewModels/`) o por feature (`Tasks/`, `Settings/`)? ¿Cuántos archivos por carpeta? Las carpetas de 40 archivos son la primera señal.

### 1.2 Grafo de dependencias

```bash
grep -rn "^import " --include="*.swift" . | grep -v "/.build/" | sort | uniq -c | sort -rn   # qué importa cada capa
grep -rln "import SwiftUI" --include="*.swift" . | grep -i "model\|service\|repository"      # modelos/servicios que importan UI → flecha hacia atrás
```

Quién conoce a quién: qué vista conoce qué servicio, qué ViewModel conoce a otro ViewModel. Se dibuja. **Las flechas hacia atrás** (servicio que conoce a la vista, modelo que importa SwiftUI, ViewModel que instancia otra vista) son hallazgos directos.

### 1.3 Inventario de estado — el más importante

```bash
grep -rn "@Observable\|ObservableObject\|@StateObject\|@EnvironmentObject\|\.shared\b\|@AppStorage\|UserDefaults" --include="*.swift" . | grep -v "/.build/"
grep -rn "@Environment(\\\\." --include="*.swift" . | grep -v "/.build/"   # environment custom
```

Para **cada dato de negocio** (tareas, usuario, settings, sesión): dónde vive, quién lo escribe, quién lo lee. Tabla:

| Dato | Vive en | Escriben | Leen | ¿Única fuente? |
|------|---------|----------|------|----------------|
| Lista de tareas | `TaskStore` + `HomeViewModel.tasks` | ambos | 6 vistas | ❌ |

Si el mismo dato vive en dos sitios, se anota — ahí nacen los loops y las desincronizaciones.

### 1.4 Persistencia y datos

```bash
grep -rn "@Query\|FetchDescriptor\|modelContext\|ModelContainer" --include="*.swift" . | grep -v "/.build/"
grep -rn "URLSession\|URLRequest\|\.data(from:\|\.data(for:" --include="*.swift" . | grep -v "/.build/"
```

Cuántos `@Query` y `FetchDescriptor` hay y **dónde** — si están en vistas, la capa de datos no existe. Cómo se accede a la red, si hay cache, cómo se manejan y propagan errores.

### 1.5 Navegación

`NavigationStack` con rutas tipadas (`enum Route`) o `NavigationLink` suelto por todas partes. Sheets y modales: quién decide que se abren — la vista, el ViewModel, o un coordinador.

### 1.6 Concurrencia

```bash
grep -rn "@MainActor\|actor \|Task {\|Task.detached\|DispatchQueue\|\.sink\b\|Combine" --include="*.swift" . | grep -v "/.build/" | wc -l
```

`@MainActor` dónde, actors, `Task` sueltas sin cancelación, Combine y async/await mezclados. Swift 6 strict concurrency: ¿compila limpio, o hay `@unchecked Sendable` y `nonisolated(unsafe)` tapando warnings?

### 1.7 Inyección de dependencias

Cómo llega un servicio a un ViewModel: por `init`, por `Environment`, por singleton `.shared`, o instanciado dentro. **Esto decide si algo es testeable.** `Service.shared` llamado desde una vista = no hay DI.

### 1.8 Tests

Qué está cubierto y qué *no puede* cubrirse. Un ViewModel sin tests "porque necesita la UI" o "porque llama a `.shared`" es un hallazgo de arquitectura, no de QA.

Salida de la fase: el mapa — estructura, grafo dibujado, tabla de estado, tabla de datos, resumen de navegación/concurrencia/DI/tests.

---

## Fase 2 — Las 6 preguntas, con evidencia (Avie)

Para cada una, tres columnas:

| Pregunta | El TRD asumió | La app hace | El roadmap necesita |
|----------|---------------|-------------|---------------------|
| 1. ¿Cuánto estado comparten las pantallas? | | | |
| 2. ¿De dónde vienen los datos y cuántas fuentes hay? | | | |
| 3. ¿Qué lógica hay que probar? | | | |
| 4. ¿Qué va a cambiar? (backend, modelo, UI) | | | |
| 5. ¿Cuántas personas y cuánto tiempo? | | | |
| 6. ¿Qué da la plataforma gratis que estamos replicando? | | | |

**Nivel actual vs nivel necesario:**

| Nivel | Cuándo |
|-------|--------|
| **A** Local simple | Vistas + `@State`/`@Observable` directo con SwiftData. Sin ViewModels obligatorios |
| **B** MVVM `@Observable` | Lógica real, red, algo que testear. Vista → ViewModel → Servicios con protocolos. *Default del repo* |
| **C** MVVM + Repository | Varias fuentes (local + red + sync), offline-first, resolución de conflictos |
| **D** Modular por feature | Equipo grande, muchas features, SPM packages, fronteras explícitas, DI formal |

Si el nivel actual es **más alto** que el necesario, también es hallazgo: capas que nadie usa cuestan lo mismo que capas que faltan.

---

## Fase 3 — Los 6 criterios de salud, PASS/FAIL con evidencia (Avie)

| # | Criterio | Cómo se verifica | Evidencia |
|---|----------|------------------|-----------|
| C1 | **Una sola fuente de verdad por dato** | Tabla de estado (1.3): ninguna fila con ❌ | `archivo:línea` de cada duplicado |
| C2 | **Dependencias en una sola dirección** | Grafo (1.2): cero flechas hacia atrás | Cada flecha invertida |
| C3 | **La vista no decide, muestra** | Leer `body`: cálculos, reglas de negocio, `if` que no sean de presentación | `archivo:línea` de cada decisión en vista |
| C4 | **Cambiar el backend sin tocar una vista** | ¿Hay protocolo entre ViewModel y red/persistencia? Cuántas vistas llaman directo a `URLSession` / `modelContext` | Lista de llamadas directas |
| C5 | **La lógica se testea sin UI** | Tests (1.8) + DI (1.7): ¿qué ViewModels no se pueden instanciar sin UI o sin `.shared`? | Lista |
| C6 | **Un dev nuevo sabe dónde va una feature en 5 minutos** | Avie lo prueba literalmente: toma una feature del roadmap y anota qué archivos tocaría. > 5 archivos o "habría que preguntar" = FAIL | La lista de archivos |

---

## Fase 4 — Señales de que duele (Avie, con datos del repo)

```bash
git log --since="3 months ago" --name-only --pretty=format: | grep "\.swift$" | sort | uniq -c | sort -rn | head -15   # churn: archivos tocados en casi todos los commits
find . -name "*.swift" -not -path "*/.build/*" -exec wc -l {} + | sort -rn | head -10                                  # archivos gordos
git log --oneline -20                                                                                                  # features recientes
```

| Señal | Qué está diciendo | Evidencia |
|-------|-------------------|-----------|
| **Churn** — mismos archivos en casi todos los commits | Cuellos de botella: todo pasa por ahí | Top 5 del churn |
| **Archivos gordos** — > 400 líneas | `HomeView` de 800 líneas, `AppState` que lo sabe todo | Top 5 por tamaño |
| **Features recientes tocaron muchos archivos** | Fronteras mal puestas | Últimas 3 features: archivos por cada una |
| **Bugs repetidos** — de PROJECT_LEARNINGS | Lógica que debería estar en un solo sitio | IDs de los learnings |
| **Loops y desincronización** — de PERFORMANCE_AUDIT `🏗` | Dos fuentes de verdad, observación de más | IDs PERF-xxx |
| **Lo que viene** — del roadmap | Sync, widget, watch, Mac, multi-usuario, IA: cada uno cambia una pregunta de la Fase 2 | Qué pregunta cambia y si la arquitectura lo absorbe |

---

## Fase 5 — Revisión cruzada (solo los que tienen algo que decir)

- **Ivan** — fronteras de seguridad: dónde viven secretos, red, auth, Keychain. Si están dispersos por vistas o ViewModels, es hallazgo de arquitectura con severidad de seguridad. Ivan no diseña la arquitectura; dice qué frontera es obligatoria.
- **Bertrand** — testabilidad: confirma C5 y estima qué cobertura se desbloquea con cada cambio propuesto.
- **Eve / Chris** — solo si hay o viene multi-target: qué código tiene que ser compartible entre app, widget, Mac (y no lo es porque importa SwiftUI/UIKit o depende de `.shared`).

Cada uno devuelve hallazgos en el mismo formato; Avie los integra.

---

## Severidades

**🔴 CRÍTICO** — la arquitectura ya está causando bugs o bloqueando el roadmap:
- Dos fuentes de verdad del mismo dato (C1 FAIL) con loop o desincronización reproducible
- El roadmap inmediato (próximo release) exige algo que la estructura actual no aguanta sin hack
- Secretos, auth o red sin frontera (Ivan)
- Lógica de negocio core sin poder testearse

**🟡 IMPORTANTE** — cuesta cada feature y va a costar más:
- Flechas hacia atrás en el grafo (C2)
- Lógica de negocio en vistas (C3) en más de 3 pantallas
- Sin protocolo entre ViewModel y datos (C4)
- Archivo gordo o cuello de churn

**🔵 MENOR** — deuda que no duele todavía:
- Organización por capa cuando por feature comunicaría mejor (o al revés)
- Nivel más alto del necesario en una zona
- Navegación sin rutas tipadas
- Nomenclatura inconsistente entre capas

---

## Fase 6 — Veredicto (Avie + Steve)

Uno de tres, con justificación explícita:

| Veredicto | Cuándo | Qué sigue |
|-----------|--------|-----------|
| **MANTENER** | Nivel correcto para hoy y para el roadmap · criterios en PASS o FAIL solo 🔵 · señales ausentes o menores | Se documenta. No se toca nada. Se actualiza el TRD con lo aprendido |
| **AJUSTAR** | Nivel correcto, pero 1–3 criterios fallan en **zonas concretas** (lógica en 4 vistas, un dato duplicado, un archivo gordo) | Fase 7 describe solo la zona. Plan corto, riesgo bajo–medio |
| **CAMBIAR** | El nivel es incorrecto para lo que viene (roadmap exige sync/multi-target y no hay capa que lo aguante) · o ≥2 criterios fallan **en toda la app** · o el nivel es más alto de lo necesario y estorba | Fase 7 completa. Plan largo, migración strangler |

**Qué NO cambiar.** Tan importante como el veredicto: lo que funciona se nombra explícitamente — capas, decisiones, archivos — para que nadie lo "mejore" de paso durante la migración.

---

## Fase 7 — Arquitectura objetivo (solo si AJUSTAR o CAMBIAR)

Descrita en los mismos términos del mapa, para poder comparar:

- **Nivel** objetivo (A–D) y por qué ese y no el siguiente
- **Capas** y qué vive en cada una
- **Fuente de verdad por dato** — la tabla de 1.3 con la columna "vivirá en"
- **Dirección de dependencias** — grafo objetivo
- **Cómo llega un servicio a un ViewModel** — el mecanismo de DI elegido
- **Diagrama antes / después**

**Justificada contra el roadmap, no contra la moda.** "Repository porque entra CloudKit en v1.2", no "Repository porque es lo correcto". Cada capa nueva tiene que nombrar la feature o el criterio que la exige.

---

## Fase 8 — Plan de migración por etapas (Avie + Steve)

Aquí está el valor de la rutina. Mismas reglas que `/optimize-app`, más las propias de arquitectura:

### Reglas

1. **Nunca reescritura.** Patrón *strangler*: lo nuevo convive con lo viejo; se migra una pantalla o un dato a la vez; lo viejo se borra cuando ya nada lo usa. La app funciona entre cada etapa.
2. **Tests antes de mover.** Si una pieza no tiene tests, la primera etapa es ponérselos *en su estado actual* — así la migración demuestra que no cambió el comportamiento.
3. **Orden:** primero lo que **desbloquea** (extraer el protocolo del servicio, definir la fuente de verdad), luego lo que **duele más** (el dato duplicado, el archivo gordo, el cuello de churn). Lo **cosmético** (renombrar archivos, mover carpetas, reorganizar por feature) **no forma etapas aquí**: cuando la última etapa de código se cierra, Steve lo pasa a `/clean-folder-project`, que lo hace con `git mv` y su propio plan.
4. **Una etapa = un tipo de cambio.** "Extraer `TaskRepository` con protocolo" es una etapa. "Migrar HomeView a usarlo" es otra. Si algo sale mal, se sabe qué fue.
5. **Cada etapa es shippable sola.** Compila, tests pasan, comportamiento idéntico. Nunca una etapa deja dos mecanismos a medias sin que uno sea claramente el activo.
6. **Nada de dos etapas tocando el mismo archivo a la vez.** Y nada de etapas en zonas con etapas abiertas de `/optimize-app`.
7. **Una etapa no rompe una feature en curso.** Si Woz está a medias con algo en esa zona, la etapa espera.
8. **Cada etapa dice cómo se verifica y cómo se revierte.**

### Formato de cada etapa

```markdown
### Etapa N — [nombre corto]

**Qué:** [1–2 líneas]
**Criterios que cierra:** C1, C4 · **Hallazgos:** ARCH-002, PERF-004
**Archivos:** `Services/TaskRepository.swift` (nuevo), `ViewModels/HomeViewModel.swift`
**Tipo:** desbloquea / duele / cosmético
**Riesgo:** Bajo / Medio / Alto — [por qué]
**Prerrequisito:** [etapa anterior, o "tests de X en su estado actual"]
**Cómo se verifica:** [tests que deben seguir pasando · criterio que pasa a PASS · comportamiento que Bertrand comprueba a mano]
**Rollback:** un commit atómico — `git revert` limpio
**Owner:** Woz
**Estado:** ⏳ Pendiente de aprobación
```

### Cierre de la rutina

Al terminar la Fase 8, Steve muestra el resumen y **se detiene**:

> "Auditoría de arquitectura lista en `ARCHITECTURE_AUDIT.md`.
>
> **Veredicto: AJUSTAR.** Nivel B (MVVM) es correcto para hoy y para el roadmap. Fallan C1 (lista de tareas en dos sitios) y C4 (4 vistas llaman a `modelContext` directo). Lo demás se mantiene tal cual.
>
> N etapas, en este orden:
> Etapa 1 — Tests de HomeViewModel en su estado actual. Riesgo bajo.
> Etapa 2 — `TaskRepository` con protocolo; `TaskStore` pasa a ser la única fuente de verdad. Riesgo medio.
> Etapa 3 — …
>
> Para aplicar la primera: `/architecture-audit go 1`."

Si el veredicto es **MANTENER**, no hay etapas: Steve lo dice, actualiza `TRD.md` con lo aprendido, y termina.

**No implementa nada sin ese `go`.**

---

## Fase 9 — Implementación por etapa (`/architecture-audit go <n>`)

Solo cuando el usuario aprueba la etapa `n`. Si pide `go 3` con la 1 o 2 abiertas, Steve avisa: las etapas de arquitectura tienen prerrequisitos reales, saltarse una suele romper la siguiente.

```
Steve (lee la etapa n; cruza con PERFORMANCE_AUDIT.md — zona libre)
→ Woz (implementa solo lo que dice la etapa; un commit)
→ Bertrand (todos los tests pasan; ninguno se borró ni se marcó skip; comportamiento a mano si la etapa lo pide)
→ Avie (verifica que el criterio que la etapa cerraba ahora está en PASS, con la misma evidencia de la Fase 3)
→ Ivan (solo si la etapa toca red, auth, secretos o entitlements)
→ Steve (actualiza ARCHITECTURE_AUDIT.md: etapa ✅, criterios ✅ · actualiza TRD.md · pide baseline nuevo a Bertrand si hay PERFORMANCE_AUDIT.md en esa zona)
→ Steve pregunta: "Etapa n cerrada: [criterio] pasó a PASS. ¿Aplico la etapa n+1?"
```

**`TRD.md` se actualiza al cerrar cada etapa.** El TRD tiene que reflejar la arquitectura real siempre — si no, la próxima auditoría vuelve a empezar de cero.

Si algo se rompe o un test deja de pasar: Woz revierte el commit, Steve marca la etapa ⚠️ Revertida con la razón, y se replantea antes de continuar. Nunca se avanza con una etapa anterior rota.

---

## ARCHITECTURE_AUDIT.md — documento que produce la rutina

```markdown
# ARCHITECTURE_AUDIT — [Nombre de la app] v[X.Y]

> Auditoría de arquitectura. Build: [commit]. Fecha: [fecha].
> Modo: completo / quick / [feature]
> Target: [features hoy] + [lo que viene: …]

---

## Veredicto

**MANTENER / AJUSTAR / CAMBIAR** — [justificación en 3 líneas]

**Nivel actual:** B (MVVM @Observable) · **Nivel necesario:** B / C
**Qué NO se toca:** [capas, decisiones, archivos que funcionan]

---

## Resumen

| Severidad | Abiertos | Cerrados |
|-----------|----------|----------|
| 🔴 Crítico | X | Y |
| 🟡 Importante | X | Y |
| 🔵 Menor | X | Y |

| Criterio | Estado | Evidencia |
|----------|--------|-----------|
| C1 Única fuente de verdad | ❌ | ARCH-001 |
| C2 Dependencias en una dirección | ✅ | — |
| C3 La vista no decide | ⚠️ 2 vistas | ARCH-003 |
| C4 Backend intercambiable | ❌ | ARCH-002 |
| C5 Lógica testeable sin UI | ⚠️ | ARCH-004 |
| C6 Feature nueva en < 5 archivos | ✅ | — |

**Estado:** Plan pendiente de aprobación / Etapa N en curso / Completo
**Etapas activas:** [n] · **Zonas bloqueadas por /optimize-app:** [archivos o "ninguna"]

---

## Mapa actual

### Estructura
[carpetas, targets, paquetes, archivos por carpeta]

### Grafo de dependencias
[diagrama; flechas hacia atrás marcadas]

### Inventario de estado
| Dato | Vive en | Escriben | Leen | ¿Única fuente? |
|------|---------|----------|------|----------------|

### Datos, navegación, concurrencia, DI, tests
[resumen de 1.4–1.8]

---

## Las 6 preguntas

| Pregunta | El TRD asumió | La app hace | El roadmap necesita |
|----------|---------------|-------------|---------------------|

---

## Señales

| Señal | Evidencia | Qué dice |
|-------|-----------|----------|

---

## Hallazgos

### 🔴 [ARCH-001] Lista de tareas vive en TaskStore y en HomeViewModel

**Criterio:** C1
**Evidencia:** `Stores/TaskStore.swift:12`, `ViewModels/HomeViewModel.swift:8` — ambos `var tasks: [Task]`; `HomeViewModel` observa `TaskStore` y copia; `TaskStore` escucha cambios de `HomeViewModel`. Origen del loop PERF-004.
**Por qué es estructura:** hay que decidir una sola fuente de verdad y que las vistas la observen directamente.
**Fix propuesto:** `TaskStore` única fuente; `HomeViewModel` deja de tener `tasks` y expone solo lógica de presentación.
**Etapa:** 2
**Estado:** ⏳

---

## Arquitectura objetivo
[solo si AJUSTAR / CAMBIAR — nivel, capas, tabla de estado "vivirá en", grafo, DI, diagrama antes/después, justificación contra roadmap]

---

## Plan de migración — por etapas

> Cada etapa se aplica sola. La app compila, los tests pasan y el comportamiento es idéntico al terminar cada una.
> Aprobar con `/architecture-audit go <n>`.

### Etapa 1 — …
[formato de etapa]

---

## Historial de etapas

| Etapa | Fecha | Criterios cerrados | Commit | TRD actualizado | Estado |
|-------|-------|--------------------|--------|-----------------|--------|

---

## Revisión cruzada
- **Ivan:** [fronteras de seguridad obligatorias]
- **Bertrand:** [cobertura que se desbloquea]
- **Eve / Chris:** [código compartible, si aplica]
```

---

## Cuándo Steve lanza esta rutina sin que se la pidan

- El usuario dice "esto está mal estructurado", "cada feature me cuesta mucho", "no sé dónde poner esto", "tengo miedo de tocar ese archivo", "quiero refactorizar"
- `/optimize-app` produjo hallazgos `🏗 arquitectura` de severidad 🔴
- El roadmap mete algo que cambia una de las 6 preguntas — sync, segundo target, multi-usuario, IA — Steve la propone **antes** de construir esa feature (`/architecture-audit <feature>`)
- `PROJECT_LEARNINGS.md` acumula el mismo tipo de bug en 3+ pantallas
- Antes de un lanzamiento público si nunca se ha corrido — Steve lo propone, no lo impone

## Lo que esta rutina NO hace

- No implementa sin `go <n>`
- No mide performance — eso es `/optimize-app`; aquí se lee su resultado
- No reescribe la app — migra por etapas o no migra
- No sube de nivel "por si acaso" — cada capa nueva nombra la feature o criterio que la exige
- No cambia el diseño visual — si una etapa toca UI, entra Jonny en esa etapa
- No sustituye a Ivan: si una etapa toca red, auth, secretos o entitlements, Ivan la revisa antes de cerrarla

---

## Dentro de `/global-audit`

Cuando Steve te ejecuta desde `/global-audit`, corres **igual** — mismas fases, mismos líderes, mismos gates, mismo documento y mismo plan — con dos diferencias: **no muestras tu cierre** (Steve hace uno solo con las cuatro rutinas) y **no te detienes a preguntar** salvo lo que solo el usuario puede responder, que Steve agrupa al principio. Tus hallazgos con tag cruzado (`🏗`, `🧹`, prerrequisitos 2.1) los recoge Avie en la reconciliación y pueden cambiar de documento; tus etapas aparecen en la secuencia global como `G<n> → /architecture-audit go <etapa>` dentro de tu ronda. Si tu ronda es la que cierra, Steve dispara la re-sincronización que corresponde antes de que empiece la siguiente.

## Tono

- Evidencia o no existe. Cada hallazgo tiene `archivo:línea`, cada señal tiene un comando que la produjo.
- Sin ideología. "Repository porque entra CloudKit en v1.2", nunca "porque es lo correcto".
- MANTENER es un veredicto válido y frecuente. No inventar trabajo.
- El plan se explica para que el usuario decida etapa por etapa, no para impresionar.
- Español o inglés: el del usuario.
