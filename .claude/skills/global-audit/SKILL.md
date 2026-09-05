---
name: global-audit
description: "Rutina paraguas. Steve corre las cuatro auditorías del equipo — /architecture-audit, /clean-folder-project, /optimize-app, /app-store-ready — en modo diagnóstico, Avie reconcilia los hallazgos que una rutina le pasa a otra, y sale GLOBAL_AUDIT.md: un tablero con los cuatro veredictos y una sola secuencia de 'go' en rondas (arquitectura → limpieza → performance → App Store) que respeta 'un solo plan activo por zona'. 'go <n>' aplica el paso n delegando a la rutina dueña. Úsalo cuando quieras saber cómo está el proyecto entero, antes de un lanzamiento, o cuando heredes una app."
---

# /global-audit — Estado completo del proyecto y un solo camino para arreglarlo

Rutina paraguas del equipo. Cuando se lanza, Steve ejecuta las cuatro auditorías — `/architecture-audit`, `/clean-folder-project`, `/optimize-app`, `/app-store-ready` — **primero todas en diagnóstico**, después Avie reconcilia lo que una le pasa a otra, y Steve entrega `GLOBAL_AUDIT.md`: un tablero con los cuatro veredictos, los totales por severidad, y **una sola secuencia de `go` en rondas** que ya viene ordenada para que ningún plan pise a otro.

Cada rutina sigue produciendo su documento y sus etapas. `/global-audit` no añade hallazgos ni severidades propias: **consolida y ordena**. Y como todas las demás, **termina en el plan** — nada se aplica sin `go <n>`.

---

## Por qué existe

Las cuatro rutinas por separado te dan cuatro planes con cuatro `go 1`. Sin esta capa tendrías que decidir tú en qué orden aplicarlos y vigilar que no toquen los mismos archivos. Aquí eso ya está resuelto:

| Problema con cuatro planes sueltos | Cómo lo resuelve |
|-----------------------------------|------------------|
| ¿Cuál va primero? | Rondas fijas: **arquitectura → limpieza → performance → App Store**. No se ordenan carpetas que se van a reestructurar; no se optimiza código que se va a mover; el App Store se audita sobre el build final |
| `/optimize-app` encuentra un `🏗` que es de arquitectura, pero arquitectura ya dio veredicto | Fase de **reconciliación**: Avie incorpora los `🏗` y `🧹` cruzados antes de cerrar veredictos |
| Cuatro resúmenes, cuatro paradas | Las rutinas corren en modo *silencioso* dentro de esta y Steve hace **un** cierre |
| ¿Qué `go` sigue? | Secuencia global G1…Gn; cada paso dice a qué rutina y etapa corresponde |
| Un audit está fresco, otro es de hace un mes | Solo se re-ejecuta lo que está **desactualizado** respecto al commit actual |
| Un proyecto nuevo no necesita cuatro auditorías | **Triage**: Steve sonda el estado del proyecto y omite, con razón en una línea, las que no hacen falta |
| Arquitectura y limpieza corren el mismo `find`; optimize y limpieza corren Periphery por separado | **Trabajo compartido**: cada comando se ejecuta una vez y su salida se pasa a todas |

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/global-audit` | Las cuatro rutinas en modo completo (con dispositivo e Instruments si hay; con App Store Connect si aplica) |
| `/global-audit quick` | Las cuatro en su modo `quick`: sin dispositivo, sin ASC, sin roadmap. Chequeo de salud en minutos. Útil antes de un PR grande o al heredar un proyecto |
| `/global-audit <rutinas>` | Solo las indicadas, ej: `/global-audit optimize clean` · nombres válidos: `architecture`, `clean`, `optimize`, `appstore` |
| `/global-audit status` | No re-audita: relee los cuatro documentos y refresca el tablero y la secuencia. Para saber dónde estás |
| `/global-audit all` | Fuerza las cuatro aunque el triage diga que alguna no hace falta |
| `/global-audit go <n>` | Aplica el paso `n` de la secuencia global delegando a la rutina dueña (`/architecture-audit go 2`, etc.) |

---

## Quién hace qué

| Fase | Agente | Rol |
|------|--------|-----|
| 0 · Alcance y frescura | **Steve** | Qué rutinas aplican a esta app, cuáles ya están frescas, en qué orden se diagnostica |
| 1 · Diagnóstico | Cada rutina con su líder (Avie ×2, Bertrand + Avie, Phil) | Corren en modo silencioso: producen su documento y su plan, **sin cierre propio** |
| 2 · Reconciliación | **Avie** (+ Phil para lo de App Store) | Incorpora hallazgos cruzados, re-evalúa veredictos afectados, detecta etapas que colisionan |
| 3 · Secuencia global | Steve + Avie | Rondas y pasos G1…Gn; qué se salta; qué queda bloqueado por Ivan/Kim/usuario |
| 4 · Tablero | Steve | `GLOBAL_AUDIT.md` y **un** cierre |
| 5 · `go <n>` | La rutina dueña del paso | Steve delega, la rutina aplica con sus propios gates, Steve actualiza el tablero y re-sincroniza al cambiar de ronda |

---

## Antes de empezar

Lee si existen:
- **`PRD.md`**, **`TRD.md`** — para saber qué rutinas aplican (¿va al App Store? ¿qué nivel de arquitectura?).
- **`ARCHITECTURE_AUDIT.md`**, **`PROJECT_STRUCTURE.md`**, **`PERFORMANCE_AUDIT.md`**, **`APP_STORE_READINESS.md`** — y el commit/build que cada uno declara en su cabecera.
- **`GLOBAL_AUDIT.md`** — si existe, es re-audit: conserva el historial de rondas cerradas.
- **`SECURITY_AUDIT.md`**, **`LEGAL_AUDIT.md`** — gates que `/app-store-ready` exige; si están `BLOCKED`, se anuncia desde el principio.
- **`PROJECT_LEARNINGS.md`**, **`.appleapplab/KNOWN_ISSUES.md`**.

---

## Fase 0 — Alcance y frescura (Steve)

### Triage — qué rutinas hacen falta, no solo cuáles aplican

Una auditoría que no hace falta es ruido y coste. Un proyecto que Woz acaba de generar desde el TRD no tiene nada que auditar en arquitectura (la estructura *es* el TRD), ni carpetas que ordenar (el scaffold del equipo ya viene ordenado), ni flujos que medir. Steve lo comprueba con una **sonda barata** antes de lanzar nada:

```bash
git rev-list --count HEAD                                                         # edad: commits
find . -name "*.swift" -not -path "*/.build/*" | wc -l                             # tamaño: archivos Swift
ls -d */Features/*/ 2>/dev/null | wc -l                                            # features reales
ls PRD.md TRD.md TEST_PLAN.md APPSTORE.md PERFORMANCE_AUDIT.md ARCHITECTURE_AUDIT.md PROJECT_STRUCTURE.md APP_STORE_READINESS.md 2>/dev/null
git ls-files | grep -cE "xcuserdata|\.DS_Store|DerivedData|/build/"               # basura rastreada
ls ExportOptions.plist fastlane 2>/dev/null; grep -l "TestFlight" APPSTORE.md 2>/dev/null   # señales de lanzamiento
git log -1 --format=%cr -- TRD.md                                                 # cuándo se decidió la arquitectura
```

Con eso ubica el proyecto en una **etapa de vida** y decide rutina por rutina:

| Etapa | Señales | Arquitectura | Limpieza | Performance | App Store |
|-------|---------|--------------|----------|-------------|-----------|
| **Nuevo / scaffold** — Woz acaba de generar desde el TRD | < ~15 archivos Swift, < ~20 commits, TRD de hace días, 0–1 features | ❌ la estructura *es* el TRD; nada que comparar | ❌ el scaffold ya viene ordenado; `quick` solo si la sonda ve basura rastreada | ❌ no hay flujos que medir ni código que revisar | ⏸ **se posterga**: "cuando exista build Release candidato" |
| **En construcción** — features entrando, sin release | 15–80 archivos, 2+ features, sin build Release | solo **por señal**: `🏗` abiertos, bugs repetidos en `PROJECT_LEARNINGS.md`, roadmap que mete sync / multi-target → `quick` | `quick`; completo solo si el quick da 🔴 o 🟡 | solo **por señal**: el usuario reporta lentitud, `TEST_PLAN.md` con métrica fuera de umbral → `quick` | ⏸ postergado; `quick` técnico si Phil ya está cerca |
| **Pre-lanzamiento** — Tier 2/3, Phil próximo, TestFlight | build Release, `APPSTORE.md` o TestFlight, "quiero subirla" | ✅ completo — última oportunidad barata de mover cosas | ✅ completo | ✅ completo, con dispositivo | ✅ completo |
| **Publicada / mantenimiento** | usuarios reales, Organizer con datos | por señal | por señal | ✅ con Organizer / MetricKit como Fase 1 | `rejected` o re-submit según el caso |
| **Heredada** — código que el equipo no escribió | sin TRD o TRD desactualizado, historia larga | ✅ completo | ✅ completo | ✅ completo | ✅ si va al App Store |

Además, `/app-store-ready` se **omite** (no se posterga) si el PRD dice uso personal / interno o ya se eligió distribución directa (`/update-feature`).

**Reglas del triage:**
- **Omitir se dice, no se calla.** Cada rutina omitida o postergada aparece en el tablero con la razón en una línea.
- **Postergar ≠ omitir.** Lo postergado lleva su condición ("cuando exista build Release candidato") y Steve lo vuelve a evaluar cuando se cumpla.
- **El usuario manda.** Si pide una rutina que el triage omitió, Steve se lo dice en una frase ("no hay flujos que medir todavía") y la corre igual si insiste. `/global-audit all` fuerza las cuatro.
- **Fresco reemplaza a necesario.** Si una rutina hace falta pero su documento está fresco (siguiente sección), se reutiliza.
- **La misma sonda vale para las rutinas sueltas.** Steve la corre también antes de lanzar `/optimize-app`, `/clean-folder-project`, `/architecture-audit` o `/app-store-ready` por separado.

### Qué está fresco

```bash
git rev-parse --short HEAD
grep -m1 -h "Build:" ARCHITECTURE_AUDIT.md PROJECT_STRUCTURE.md PERFORMANCE_AUDIT.md APP_STORE_READINESS.md 2>/dev/null
git diff --stat <commit-del-audit>..HEAD -- '*.swift' project.yml | tail -1
```

| Estado | Regla |
|--------|-------|
| **Fresco** — mismo commit, o solo cambiaron archivos fuera de su alcance | Se **reutiliza** el documento tal cual. No se re-audita |
| **Desactualizado** — hubo commits que tocan su alcance | Se re-ejecuta en modo `status` de esa rutina si existe, o completo |
| **Inexistente** | Se ejecuta completo (o `quick` según el modo global) |

Steve anuncia el alcance antes de empezar:

> "Global audit sobre `a1b2c3d`. Proyecto **en construcción**: 42 archivos Swift, 3 features, 61 commits, sin build Release.
> Corren: **limpieza `quick`** (hay 3 `.DS_Store` rastreados) y **arquitectura `quick`** (2 hallazgos `🏗` abiertos en PERFORMANCE_AUDIT.md).
> Se omiten: **performance** — sin señal de lentitud ni métrica fuera de umbral. **App Store** — postergado hasta que exista build Release candidato.
> `SECURITY_AUDIT.md` en PASS. Si quieres que corra alguna de las omitidas, dímelo. Empiezo."

En un proyecto **nuevo** el anuncio es una línea: *"Proyecto recién generado desde el TRD (9 archivos, 4 commits). No hay nada que auditar todavía; el flujo normal Scott → Avie → Jonny → Woz ya lo cubre. Vuelve a llamarme cuando haya features o build candidato."* — y `/global-audit` termina ahí, sin documento.

### Orden de diagnóstico

No es el orden de ejecución de etapas — es el orden en que se **recoge información** para que la reconciliación tenga todo:

1. `/architecture-audit` — el mapa de la estructura sirve a las otras tres
2. `/optimize-app` — produce los `🏗` (para arquitectura) y `🧹` (para limpieza)
3. `/clean-folder-project` — ya sabe qué zonas va a reestructurar arquitectura y qué archivos huérfanos marcó performance
4. `/app-store-ready` — al final, porque su veredicto depende de que los otros tres no tengan 🔴 abiertos que sean rechazo 2.1

---

## Fase 1 — Diagnóstico (las cuatro rutinas, modo silencioso)

Cada rutina corre **igual que sola** — mismas fases, mismos líderes, mismos gates — con dos diferencias:

- **No muestra su cierre.** Produce su documento y su plan y devuelve el control a Steve. El usuario ve un solo resumen al final.
- **No se detiene a preguntar** salvo por lo que solo el usuario puede responder (perfil de App Store en Fase 0 de `/app-store-ready`, si adoptar XcodeGen en `/clean-folder-project`). Steve agrupa esas preguntas y las hace **juntas al principio**, no una por una.

### Trabajo compartido — cada comando se ejecuta una vez

Varias rutinas le piden lo mismo al repo. Dentro de `/global-audit`, Steve lo ejecuta **una vez** y pasa la salida; las rutinas no lo repiten, y así no salen dos inventarios distintos del mismo repo:

| Salida | La produce | La reutilizan |
|--------|------------|---------------|
| Árbol de carpetas y archivos Swift por carpeta | `/architecture-audit` 1.1 | `/clean-folder-project` 1.1 — no vuelve a correr `find` |
| Grafo de `import` | `/architecture-audit` 1.2 | `/clean-folder-project` 1.4 (capa equivocada) |
| **Periphery** (declaraciones sin referencias) | una corrida | `/optimize-app` 3.5 toma símbolos *dentro* de archivos · `/clean-folder-project` 1.5 toma archivos completos |
| **SwiftLint** | una corrida | `/optimize-app` 3.5 (complejidad) · `/clean-folder-project` 1.3 (nombres) |
| `git ls-files` y churn (`git log --stat`) | una corrida | arquitectura 4 (churn) · limpieza 1.2 (rastreados indebidos) |
| Archive Release + tests en verde | Bertrand, una vez | `/app-store-ready` 2.1 · gate de arquitectura y limpieza |
| Gates de Ivan y Kate | se leen una vez | `/app-store-ready` 5 · arquitectura 5 |

Sueltas, cada rutina corre lo suyo. Juntas, no se duplica trabajo.

Si una rutina no puede completar una fase (sin dispositivo, sin acceso a ASC), lo deja marcado como pendiente igual que haría sola. `/global-audit` lo recoge en el tablero como *"medición pendiente — requiere X"*.

---

## Fase 2 — Reconciliación (Avie, con Phil para App Store)

Aquí está el valor que las rutinas sueltas no tienen. Avie cruza los cuatro documentos:

### 2.1 Hallazgos que cambian de dueño

| De | Tag | A | Qué hace Avie |
|----|-----|---|---------------|
| `/optimize-app` | `🏗 arquitectura` | `/architecture-audit` | Los añade como hallazgos ARCH-xxx. Si alguno es 🔴, **re-evalúa el veredicto**: un MANTENER puede pasar a AJUSTAR |
| `/optimize-app` | `🧹 estructura` | `/clean-folder-project` | Los añade a la tabla archivo → destino (borrar huérfanos) |
| `/clean-folder-project` | `🏗 arquitectura` | `/architecture-audit` | Igual que arriba |
| `/app-store-ready` | 2.1 crash / hang / 4.0 HIG 🔴 | `/optimize-app` o Larry | Se marcan como **prerrequisito** del veredicto de App Store — no se resuelven en su plan |
| `/architecture-audit` | etapas cosméticas (renombrar, mover) | `/clean-folder-project` | Se retiran del plan de arquitectura y aparecen en el de limpieza |

Cada traslado se anota en **ambos** documentos: "movido a X como ID-nnn".

### 2.2 Colisiones entre etapas

Avie lista cada archivo que aparece en etapas de **dos o más** planes:

| Archivo | Plan A · etapa | Plan B · etapa | Resolución |
|---------|----------------|----------------|------------|
| `Features/Tasks/TaskListView.swift` | arquitectura · 2 (extraer ViewModel) | performance · 1 (formatter en body) | Performance espera a que cierre arquitectura 2; **re-baseline** después |
| `Views/Settings.swift` | limpieza · 4 (mover a Features/Settings) | App Store · 2 (eliminación de cuenta) | Limpieza primero (es solo `git mv`); App Store 2 se aplica sobre la ruta nueva |

La regla de resolución es la de las rondas: **arquitectura → limpieza → performance → App Store**. La etapa del plan posterior queda marcada *"espera a G<n>"*.

### 2.3 Bloqueos externos

Lo que ningún `go` puede resolver y hay que decir de frente:

- `SECURITY_AUDIT.md` en `BLOCKED` → Ivan → Woz → Ivan, antes de cualquier ronda de App Store
- Secretos rastreados en git → Ivan (rotar) — no se espera a la ronda de limpieza
- Strings huérfanos en app multi-idioma → Kim confirma
- Veredicto **NO VIABLE** de App Store → **decisión del usuario** entre las opciones de Phil; hasta entonces la ronda 4 no existe
- Veredicto **CAMBIAR** de arquitectura con nivel D (modularización) → el usuario aprueba el alcance antes de que exista la ronda 1

### 2.4 Veredictos finales

Tras la reconciliación, cada rutina confirma o corrige su veredicto en su propio documento. Solo entonces se arma la secuencia.

---

## Fase 3 — Secuencia global (Steve + Avie)

### Rondas

| Ronda | Rutina | Por qué en este lugar | Al cerrar la ronda |
|-------|--------|-----------------------|--------------------|
| **R1** | `/architecture-audit` | Decide qué capas existen. Todo lo demás se acomoda a eso | Avie actualiza `TRD.md` · `/clean-folder-project status` refresca su tabla (las rutas pueden haber cambiado) |
| **R2** | `/clean-folder-project` | Solo `git mv`: barato y sin riesgo de lógica. Deja el árbol donde los fixes van a vivir | Bertrand **re-toma baseline** de performance — los archivos cambiaron de sitio, los traces viejos no sirven |
| **R3** | `/optimize-app` | Fixes locales sobre el código ya en su lugar definitivo | `/app-store-ready status` — los 2.1 que eran prerrequisito ya deberían estar cerrados |
| **R4** | `/app-store-ready` | Se audita y corrige el build que de verdad se va a enviar | Veredicto LISTA → Phil pide confirmación explícita para *Submit for Review* |

Una ronda **vacía** (MANTENER, nada que limpiar, 0 hallazgos) se salta y se dice.

### Pasos

Cada paso global es una etapa de una rutina:

```
G1  → /architecture-audit go 1   Tests de HomeViewModel en su estado actual          riesgo bajo
G2  → /architecture-audit go 2   TaskRepository con protocolo; TaskStore única fuente  riesgo medio
G3  → /architecture-audit go 3   HomeView deja de leer modelContext                   riesgo medio
     ── cierre R1: TRD.md actualizado · clean-folder status ──
G4  → /clean-folder-project go 1 Basura y .gitignore                                 riesgo cero
G5  → /clean-folder-project go 2 Resources/                                          riesgo bajo
G6  → /clean-folder-project go 3 Core/                                               riesgo bajo
G7  → /clean-folder-project go 4 Feature Tasks + tests                               riesgo bajo
     ── cierre R2: re-baseline de performance ──
G8  → /optimize-app go 1         Loops de redraw en HomeView                         riesgo bajo
G9  → /optimize-app go 2         Formatters fuera de body                            riesgo bajo
     ── cierre R3: app-store-ready status ──
G10 → /app-store-ready go 1      Purpose strings + PrivacyInfo.xcprivacy             riesgo bajo
G11 → /app-store-ready go 2      Eliminación de cuenta (5.1.1 v)                     riesgo medio
G12 → /app-store-ready go 3      Metadata, screenshots del build final, cuenta demo  riesgo bajo
     ── LISTA → Phil: submit con confirmación ──
```

Cada paso hereda el formato, la verificación y el rollback de su rutina. `/global-audit` solo añade el número global y la ronda.

### Lo que no entra en la secuencia

- Bloqueos externos (2.3) — se listan aparte con su dueño
- Mediciones pendientes por falta de dispositivo o ASC — se listan con los pasos exactos para el usuario
- Lo que **no se toca** — la unión de los "qué no cambiar" de las cuatro rutinas

---

## Fase 4 — Tablero y cierre (Steve)

Steve escribe `GLOBAL_AUDIT.md` y hace **un solo cierre**:

> "Global audit de **Tasq** sobre `a1b2c3d` — completo.
>
> | Rutina | Veredicto | 🔴 | 🟡 | 🔵 | Etapas |
> |---|---|---|---|---|---|
> | Arquitectura | **AJUSTAR** — nivel B correcto; C1 y C4 fallan | 1 | 2 | 1 | 3 |
> | Limpieza | 17 archivos se quedan; 4 features a ordenar | 2 | 6 | 3 | 5 |
> | Performance | 2 loops, 1 leak (medición `quick`, sin dispositivo) | 2 | 3 | 2 | 2 |
> | App Store | **NO LISTA** — corregible | 3 | 2 | 1 | 3 |
>
> Reconciliación: 2 hallazgos `🏗` de performance pasaron a arquitectura (ARCH-005, ARCH-006) y **subieron el veredicto de MANTENER a AJUSTAR**. 1 colisión resuelta: performance 1 espera a arquitectura 2.
>
> Bloqueos externos: ninguno. `SECURITY_AUDIT.md` en PASS.
> Pendiente de medición: Instruments en dispositivo real (pasos en PERFORMANCE_AUDIT.md).
>
> **Secuencia: 13 pasos en 4 rondas.** Primero arquitectura (3), luego limpieza (5), performance (2), App Store (3).
>
> Para empezar: `/global-audit go 1` (= `/architecture-audit go 1` — tests de HomeViewModel en su estado actual, riesgo bajo)."

**No aplica nada sin ese `go`.**

---

## Fase 5 — `/global-audit go <n>`

```
Steve (lee el paso Gn; comprueba que Gn-1 está cerrado o que el usuario quiere saltar a sabiendas)
→ delega: /<rutina> go <etapa>   — la rutina aplica con sus propios agentes, gates y rollback
→ Steve (GLOBAL_AUDIT.md: Gn ✅ con antes/después heredado del documento de la rutina)
→ si Gn cerraba una ronda:
     R1 → Avie actualiza TRD.md · /clean-folder-project status (refresca rutas)
     R2 → Bertrand re-toma baseline · /optimize-app status
     R3 → /app-store-ready status (2.1 prerrequisitos)
     R4 → veredicto LISTA → Phil: checklist de submit con confirmación explícita del usuario
→ Steve pregunta: "Gn cerrado. ¿Aplico Gn+1 (= /<rutina> go <e> — [qué], riesgo [x])?"
```

Si un paso falla, la rutina dueña revierte según sus reglas y Steve marca Gn ⚠️. **No se avanza a Gn+1 con Gn revertido.** Si el fallo cambia un veredicto (por ejemplo, un `go` de arquitectura destapa un problema mayor), Steve corre `/global-audit status` y re-secuencia desde ahí.

El usuario puede seguir usando el `go` de cada rutina directamente. `/global-audit status` lo detecta y actualiza el tablero.

---

## GLOBAL_AUDIT.md — documento que produce la rutina

Es un **tablero**, no una copia. Los hallazgos viven en el documento de cada rutina; aquí solo referencias, veredictos y la secuencia.

```markdown
# GLOBAL_AUDIT — [Nombre de la app] v[X.Y]

> Estado completo del proyecto. Build: [commit]. Fecha: [fecha]. Modo: completo / quick / [rutinas].
> Rutinas ejecutadas: arquitectura (nuevo) · limpieza (nuevo) · performance (quick, sin dispositivo) · App Store (nuevo)
> Rutinas omitidas: [ninguna / App Store — PRD indica uso personal]

---

## Tablero

| Rutina | Documento | Veredicto | 🔴 | 🟡 | 🔵 | Etapas | Fresco en |
|--------|-----------|-----------|----|----|----|--------|-----------|
| Arquitectura | `ARCHITECTURE_AUDIT.md` | AJUSTAR | 1 | 2 | 1 | 3 | a1b2c3d |
| Limpieza | `PROJECT_STRUCTURE.md` | 5 etapas | 2 | 6 | 3 | 5 | a1b2c3d |
| Performance | `PERFORMANCE_AUDIT.md` | 2 loops, 1 leak | 2 | 3 | 2 | 2 | a1b2c3d |
| App Store | `APP_STORE_READINESS.md` | NO LISTA (corregible) | 3 | 2 | 1 | 3 | a1b2c3d |
| **Total** | | | **8** | **13** | **7** | **13** | |

**Gates:** Ivan `SECURITY_AUDIT.md` PASS · Kate `LEGAL_AUDIT.md` PASS · Kim N.A. (mono-idioma)

---

## Reconciliación

| Hallazgo | De | A | Efecto |
|----------|----|---|--------|
| PERF-004 (dos fuentes de verdad) | performance | arquitectura → ARCH-005 | veredicto MANTENER → AJUSTAR |
| PERF-009 (assets sin uso) | performance | limpieza → STR-012 | — |
| ARCH etapa 4 (mover carpetas) | arquitectura | limpieza → etapas 3–4 | plan de arquitectura: 4 → 3 etapas |

### Colisiones resueltas
| Archivo | Planes | Resolución |
|---------|--------|------------|
| `Features/Tasks/TaskListView.swift` | arq 2 · perf 1 | perf 1 espera a G2; re-baseline en cierre R2 |

### Bloqueos externos
- [ninguno / lista con dueño]

### Mediciones pendientes
- Instruments en dispositivo real → `PERFORMANCE_AUDIT.md` §Fase 2 · pasos para el usuario

---

## Lo que no se toca
[unión de los "qué no cambiar" de las cuatro rutinas]

---

## Secuencia global

> Aprobar con `/global-audit go <n>`. Cada paso delega a su rutina con sus gates y rollback.

### Ronda 1 — Arquitectura
| G | Rutina · etapa | Qué | Riesgo | Estado |
|---|----------------|-----|--------|--------|
| G1 | `/architecture-audit go 1` | Tests de HomeViewModel en su estado actual | bajo | ⏳ |
| G2 | `/architecture-audit go 2` | TaskRepository con protocolo | medio | ⏳ |
| G3 | `/architecture-audit go 3` | HomeView sin modelContext | medio | ⏳ |
**Cierre R1:** TRD.md · `/clean-folder-project status`

### Ronda 2 — Limpieza
…
**Cierre R2:** re-baseline (Bertrand)

### Ronda 3 — Performance
…
**Cierre R3:** `/app-store-ready status`

### Ronda 4 — App Store
…
**Cierre R4:** LISTA → Phil · submit con confirmación explícita

---

## Historial

| G | Fecha | Rutina · etapa | Resultado | Commit | Estado |
|---|-------|----------------|-----------|--------|--------|
```

---

## Cuándo Steve lanza esta rutina sin que se la pidan

- El usuario dice "¿cómo está el proyecto?", "audítalo todo", "revísalo completo", "¿qué le falta?", "heredé esta app", "quiero dejarla bien antes de lanzar"
- Tier 3 antes del lanzamiento — Steve la propone como puerta previa en lugar de correr las cuatro sueltas
- Dos o más rutinas ya tienen documento y el usuario pregunta cuál `go` sigue — `/global-audit status`
- Frederick, en su momento 2, pide el estado de salud del proyecto

## Lo que esta rutina NO hace

- No añade hallazgos ni severidades propias — consolida los de las cuatro rutinas
- No re-audita lo que está fresco
- No corre rutinas que el estado del proyecto no necesita — las omite o posterga con razón; `all` las fuerza
- No corre dos veces el mismo comando de inventario — la salida se comparte
- No aplica nada sin `go <n>`, y cada `go` lo ejecuta la rutina dueña con sus gates
- No resuelve bloqueos externos (Ivan, Kim, decisiones del usuario) — los lista con dueño
- No sustituye a las rutinas: cada una sigue funcionando sola

---

## Tono

- Un tablero, no un ensayo. Los detalles viven en cada documento; aquí veredictos, totales y el siguiente paso.
- Las reconciliaciones se dicen explícitas: "esto subió el veredicto de X a Y".
- Rondas vacías se celebran, no se rellenan.
- Español o inglés: el del usuario.
