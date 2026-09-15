---
name: global-fix
description: "Rutina para bugs que no caen con una revisión pequeña. Reproduce primero y escribe un test que falle; Avie mapea el flujo completo de la función (entrada → estado → efectos → salida) y enumera TODAS las causas posibles, rankeadas y falsadas con evidencia, no adivinadas; Woz corrige la raíz de cada causa confirmada en un commit por causa; Bertrand verifica con la reproducción y regresión en el dispositivo mínimo; después una pasada aparte que re-lee el flujo, lo simplifica y elimina código basura dejando solo lo necesario; queda documentado en PROJECT_LEARNINGS.md. 'auto' corre todo sin parar; sin él, dos checkpoints. Úsalo cuando un error vuelve, tiene varias causas, o 'ya lo arreglé tres veces'."
---

# /global-fix — Para el bug que no cae con una revisión pequeña

Rutina del equipo, no un agente. Existe para el error que ya "se arregló" y volvió, el que tiene más de una causa, el que solo pasa a veces, o el que nadie entiende del todo. En vez de mirar la línea que falla, **se mira toda la función como debería funcionar**, se encuentran todas las causas posibles, se falsan con evidencia, se corrige la raíz de cada una, se verifica con la reproducción, y solo entonces se re-lee el flujo para dejarlo limpio y con lo mínimo necesario.

El prompt original del usuario, que es el corazón de la rutina:

> *Revisa globalmente cómo tendría que funcionar esta función. Tu objetivo es encontrar todas las posibles causas que puedan estar ocasionando este error y solucionarlas. Una vez arregladas, vuelve a analizar el flujo y optimízalo, elimina código basura. Solo deja lo necesario para que funcione sin problemas.*

Lo que esta rutina le añade es lo que hace que el fix **aguante**: reproducir antes de tocar, un test que falle y luego pase, hipótesis falsadas y no adivinadas, un commit por causa, simplificación en commit aparte, y una salida cuando nada confirma.

---

## Cuándo se usa — y cuándo no

| Sí | No |
|----|----|
| El bug volvió después de un fix | Un typo, un nil evidente, un error de compilación — flujo normal C: Avie → Woz → Bertrand |
| Solo pasa a veces, o solo en ciertos dispositivos | Un crash con stack trace claro y una sola causa |
| Hay más de una causa plausible | La app está lenta en general — `/optimize-app` |
| "Ya lo arreglé tres veces" | La estructura está mal en toda la app — `/architecture-audit` |
| Nadie sabe exactamente cómo debería funcionar la función | |

Steve la lanza cuando el flujo C fracasa una vez, o cuando el usuario lo pide.

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/global-fix <descripción del error>` | Rutina completa con dos checkpoints: después de confirmar causas (antes de tocar código) y después de verificar el fix (antes de simplificar) |
| `/global-fix <archivo o función>` | Igual, con el alcance ya acotado |
| `/global-fix auto <descripción>` | Sin checkpoints: diagnostica, corrige, verifica, simplifica y documenta de un tirón. Es el prompt original. Cada paso sigue siendo un commit propio, así que todo es reversible |
| `/global-fix status` | Dónde va: causas confirmadas / descartadas / pendientes, fixes aplicados, qué falta verificar |

---

## Quién hace qué

| Fase | Agente | Rol |
|------|--------|-----|
| 0 · Reproducir | Bertrand + usuario | Pasos exactos, entrada, esperado vs observado, frecuencia. Test que falla |
| 1 · Mapa del flujo | **Avie** | Cómo *debería* funcionar la función, de entrada a salida, con cada frontera |
| 2 · Causas | Avie | Todas las hipótesis, rankeadas, y **falsadas** una por una con evidencia |
| 3 · Fix | Woz | Raíz de cada causa confirmada, un commit por causa, sin tocar lo demás |
| 4 · Verificación | Bertrand (+ Chris si es de dispositivo, Ivan si toca seguridad) | La reproducción pasa, el test rojo está verde, regresión, dispositivo mínimo |
| 5 · Simplificar | Avie decide, Woz ejecuta | Re-leer el flujo arreglado, quitar lo que solo existía para tapar el bug, dejar lo mínimo |
| 6 · Documentar | Agente propietario, Steve coordina | Entrada en `PROJECT_LEARNINGS.md`: repro, causa, fix, verificación |

Avie diagnostica y no Woz: quien escribió el código es quien más fácil se cree su propia explicación.

---

## Antes de empezar

Lee si existen:
- **`PROJECT_LEARNINGS.md`** y **`.appleapplab/KNOWN_ISSUES.md`** — este bug o uno parecido puede estar documentado con causa verificada. Es lo primero que se mira.
- **`TRD.md`** — la arquitectura decidida dice dónde *debería* vivir cada cosa; el bug suele estar donde el código no coincide con eso.
- **`TEST_PLAN.md`** — qué ya está cubierto y qué no.
- **`PERFORMANCE_AUDIT.md`**, **`ARCHITECTURE_AUDIT.md`** — hallazgos `🏗` o loops en esa zona son sospechosos directos.
- `git log -p -- <archivos del flujo>` — los últimos cambios en la zona: un bug que "apareció" casi siempre tiene un commit que lo trajo.

---

## Fase 0 — Reproducir antes de tocar (Bertrand + usuario)

**Sin reproducción no hay fix, hay suerte.**

1. **Pasos exactos.** Qué hace el usuario, con qué datos, en qué estado (primera instalación / upgrade / cuenta con datos), en qué dispositivo y OS. Esperado vs observado. Frecuencia: siempre / a veces / solo en X.
2. **Si no se reproduce**, no se toca código: se instrumenta primero. `os_signpost` o `Logger` en cada frontera del flujo, y se vuelve a intentar con los logs. Si sigue sin aparecer, se pide al usuario evidencia concreta: video, log de Console.app, `.xcresult`, dispositivo.
3. **Test que falla.** Bertrand escribe el test más pequeño que captura el bug — unit si es lógica, UI si es flujo — y confirma que está **rojo**. Ese test es el criterio de éxito de toda la rutina: el fix termina cuando está verde y se queda para siempre como regresión.
4. **Estado limpio.** `rm -rf DerivedData`, borrar la app del simulador o dispositivo, reinstalar. Un porcentaje real de "bugs imposibles" son caché.

---

## Fase 1 — Mapa del flujo: cómo debería funcionar (Avie)

Antes de buscar el error, se escribe cómo funciona la función **cuando funciona**. Sin esto, cada hipótesis es una adivinanza.

```
Entrada → [validación] → [estado que lee] → [transformación] → [efectos: persistencia / red / notificación] → [estado que escribe] → [UI que reacciona] → Salida esperada
```

Por cada tramo, Avie anota:
- **Qué entra y qué sale** (tipos, opcionales, valores límite)
- **Qué estado lee y quién más lo escribe** — dos escritores del mismo estado es sospechoso automático
- **Qué frontera cruza**: `async`, actor, `@MainActor`, `Task`, red, `ModelContext`, `NotificationCenter`, `onChange`, `onAppear`
- **Qué invariante debe cumplirse** ("el id nunca es nil aquí", "esto corre en main")

Salida: el diagrama del flujo con cada frontera marcada. Los bugs viven en las fronteras.

---

## Fase 2 — Todas las causas, rankeadas y falsadas (Avie)

### 2.1 Enumerar sin filtrar

Se listan **todas** las causas plausibles antes de evaluar ninguna — incluida la posibilidad de que haya **dos a la vez**, que es la razón número uno de "lo arreglé y volvió". Catálogo para no olvidar ninguna familia:

| Familia | Causas típicas en apps Apple |
|---------|------------------------------|
| **Estado** | Dos fuentes de verdad; estado leído antes de escribirse; `@Observable` mutado en `body`; `onChange` que dispara el flujo dos veces; estado que sobrevive entre pantallas (`@State` vs `@StateObject`); UserDefaults con clave vieja |
| **Concurrencia** | Race entre dos `Task`; trabajo fuera de `@MainActor` tocando UI; `Task` no cancelada que escribe tarde; actor reentrante; `await` en medio de una secuencia que asume atomicidad |
| **Datos** | Optional forzado; `Int` vs `Double`; índice fuera de rango; `Date` sin zona horaria; `Decimal` vs `Double`; migración de SwiftData incompleta; `ModelContext` usado desde otro hilo; fetch que devuelve objetos stale |
| **Ciclo de vida** | `onAppear` corre más veces de lo que crees; vista recreada y estado perdido; `init` de ViewModel llamado por render; app vuelve de background con estado a medias; primera instalación vs upgrade |
| **Fronteras externas** | Respuesta de red con forma distinta; timeout; permiso denegado o revocado en caliente; Keychain con datos de una instalación anterior; iCloud desactivado; App Group mal configurado |
| **Entorno** | `DerivedData` stale; simulador con datos viejos; entitlements o Info.plist distintos entre Debug y Release; `#if DEBUG` que cambia el flujo; versión de OS con comportamiento distinto; Dynamic Type / RTL / región |
| **El fix anterior** | El "arreglo" previo tapó el síntoma y creó otro camino; `try?` que traga el error; `DispatchQueue.asyncAfter` puesto para "que dé tiempo"; un `if` defensivo que esconde el estado inválido |

### 2.2 Rankear

Por **probabilidad × facilidad de comprobar**. Se comprueban primero las baratas aunque sean menos probables (caché, estado limpio, el commit que lo trajo).

```bash
git log --oneline -15 -- <archivos del flujo>        # ¿qué cambió antes de que apareciera?
git bisect start && git bisect bad && git bisect good <commit-bueno>   # si hay un commit bueno conocido
```

### 2.3 Falsar, no adivinar

Cada hipótesis se **confirma o descarta con evidencia**, nunca por intuición: un log en la frontera, un breakpoint con el valor, un test que la aísla, un `git bisect`. Tabla:

| # | Hipótesis | Familia | Cómo se comprobó | Resultado |
|---|-----------|---------|------------------|-----------|
| H1 | `tasks` se escribe desde `TaskStore` y `HomeViewModel` | estado | log en ambos `didSet` | ✅ confirmada — dos escritores |
| H2 | `ModelContext` usado desde `Task.detached` | concurrencia | breakpoint `Thread.isMainThread` | ✅ confirmada |
| H3 | migración V1→V2 deja `dueDate` nil | datos | fetch tras migrar | ❌ descartada |
| H4 | `DerivedData` stale | entorno | build limpio | ❌ descartada |

**No se pasa a la Fase 3 con hipótesis "probablemente".** Confirmada o descartada. Si tras recorrer el catálogo nada confirma, ver "Cuando nada confirma".

---

## Checkpoint 1 (salvo `auto`)

> "Reproducido: [pasos], test rojo `TaskSyncTests.testEditKeepsOrder`. Flujo mapeado: 6 tramos, 3 fronteras. Causas confirmadas: **H1** dos escritores de `tasks` (`TaskStore.swift:12`, `HomeViewModel.swift:8`) y **H2** `ModelContext` fuera de main (`TaskRepository.swift:44`). Descartadas con evidencia: H3, H4, H5. Fix: dos commits, uno por causa. ¿Sigo?"

---

## Fase 3 — Corregir la raíz, una causa por commit (Woz)

- **La raíz, no el síntoma.** Si la causa es "dos escritores", el fix es un solo escritor — no un `if` que evita la colisión.
- **Un commit por causa confirmada**, con la hipótesis en el mensaje (`fix(H1): TaskStore es la única fuente de tasks`). Así, si algo regresa, `git bisect` lo encuentra en minutos.
- **Solo el flujo afectado.** Nada de "ya que estoy". Lo que se vea de paso se anota para `/optimize-app` o la Fase 5.
- **Prohibido como fix:** `try?` que traga, `asyncAfter` "para dar tiempo", `!` cambiado por `?? default` sin entender por qué era nil, desactivar o marcar `skip` un test, `@unchecked Sendable` para callar un warning, `DispatchQueue.main.async` sin saber por qué no estaba en main.
- Si el fix exige cambiar estructura (mover una fuente de verdad a otra capa, crear un repositorio), es un fix legítimo aquí **si es local al flujo**; si toca toda la app, `🏗` → `/architecture-audit` y el bug se mitiga mínimamente mientras tanto, dicho de frente.

---

## Fase 4 — Verificar de verdad (Bertrand)

1. **La reproducción de la Fase 0 ya no reproduce.** Mismos pasos, mismos datos, mismo estado.
2. **El test rojo está verde** y se queda en el target de tests.
3. **Toda la suite pasa**; ningún test se borró ni se marcó `skip`.
4. **Regresión en los flujos vecinos** — los que comparten estado o fronteras con el arreglado.
5. **Dispositivo mínimo y OS mínimo** del target, no solo simulador (Chris si el bug era de dispositivo o configuración).
6. Si el bug era intermitente: la reproducción se corre **N veces** (10–20) o con `--repeat` en el test plan; una pasada verde no prueba nada en un race.
7. Ivan revisa si el fix tocó red, auth, Keychain, entitlements o persistencia de datos sensibles.

Si algo falla, se vuelve a la Fase 2 con la nueva evidencia — **no se apila otro fix encima**.

---

## Checkpoint 2 (salvo `auto`)

> "Arreglado y verificado: reproducción ×15 sin fallo, test verde, suite completa en verde, probado en iPhone SE / iOS 17.0. Dos commits. Ahora la pasada de simplificación: toca `TaskStore.swift`, `HomeViewModel.swift`, `TaskRepository.swift` — quita el `asyncAfter` del fix anterior, el `if` defensivo de línea 61 y la copia local de `tasks`. ¿Sigo?"

---

## Fase 5 — Re-leer el flujo y dejar solo lo necesario (Avie decide, Woz ejecuta)

Con el bug muerto, se vuelve al mapa de la Fase 1 y se lee el código **como si se escribiera hoy**:

- **Quitar lo que existía para tapar el bug**: `asyncAfter`, `if` defensivos, reintentos, copias de estado, `try?`, comentarios "no sé por qué pero sin esto falla".
- **Quitar lo muerto** en ese flujo: ramas inalcanzables, parámetros sin uso, propiedades que ya nadie lee.
- **Un solo camino** por operación: si había dos formas de llegar al mismo resultado, se deja una.
- **Fronteras explícitas**: `@MainActor` donde toca UI, un solo escritor por estado, cancelación de `Task` en `onDisappear`, invariantes como `precondition` donde el mapa decía "esto nunca es nil".
- **No rediseñar.** Simplificar es quitar, no reescribir. Si "limpio" significa cambiar la arquitectura del flujo, es otra rutina.

**En commit aparte** (`refactor(flow): simplificar X tras fix`), y se vuelve a correr la Fase 4 completa. Si la simplificación rompe algo, se revierte sola sin tocar el fix.

---

## Fase 6 — Documentar (agente propietario, Steve coordina)

Entrada en `PROJECT_LEARNINGS.md`, con el formato del equipo:

```markdown
### [fecha] — [síntoma en una línea]

**Reproducción:** [pasos, datos, estado, dispositivo/OS, frecuencia]
**Causas confirmadas:** H1 [qué, dónde, evidencia] · H2 [...]
**Descartadas:** H3 [por qué], H4 [por qué]
**Fix:** [commits] — [qué cambió en una línea cada uno]
**Verificación:** test `X` (rojo → verde), reproducción ×N, dispositivo mínimo, suite completa
**Simplificación:** [commit] — [qué se quitó]
**Estado:** verified
**Lección:** [la regla que evita que vuelva — una línea]
```

Steve avisa si la lección parece global (patrón que se repetirá en otras apps): App Master decide si sube a `KNOWN_ISSUES.md`.

---

## Cuando nada confirma

Si tras el catálogo completo ninguna hipótesis se confirma, **no se inventa un fix**. Salidas en orden:

1. **`git bisect`** hasta el commit que introdujo el bug — el diff dice la causa.
2. **Reproducción mínima aislada**: el flujo en un playground o un target vacío con los mismos datos. Si ahí no falla, la causa está fuera del flujo (entorno, estado global, otra feature).
3. **Instrumentación más fina**: `os_signpost` en cada tramo con timestamps; Instruments si hay concurrencia.
4. **Fronteras externas**: ¿es un bug de OS o SDK? Buscar en release notes, radar, foros de Apple Developer con la versión exacta.
5. **Pedir evidencia al usuario**: video, `.xcresult`, log de Console.app, dispositivo físico prestado.
6. **Decirlo**: "No tengo causa confirmada. Esto es lo que descarté y con qué. Opciones: X, Y." Un "arreglé no sé qué" cuesta más que un "todavía no sé".

---

## Lo que esta rutina NO hace

- No toca código sin reproducción y test rojo
- No aplica un fix a una hipótesis no confirmada
- No apila fixes: si la verificación falla, vuelve a diagnosticar
- No simplifica en el mismo commit que arregla
- No reescribe la arquitectura del flujo — `🏗` → `/architecture-audit`
- No da por cerrado un bug intermitente con una sola pasada verde

---

## Tono

- Evidencia o no existe: cada causa dice cómo se comprobó.
- "Todavía no sé" es una respuesta válida; "probablemente es esto" no es un fix.
- Un commit por causa, la hipótesis en el mensaje.
- Español o inglés: el del usuario.
