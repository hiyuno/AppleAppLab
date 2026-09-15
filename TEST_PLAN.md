# TEST_PLAN — Fintrol

> Última actualización: 2026-09-15 (sesión 2, tras los pases de Woz: tab bar, hub Recurrentes y pagos, Ajustes Preferencias/Seguridad, header "Mes Año / 1–15", re-proyección sobre quincenas materializadas, fix del límite histórico, cliente Banxico SIE, `LoanEngine`).
> Basado en PRD v1.1 / TRD 2026-09-15.
> Autor: Bertrand (QA & Testing).
> Gate previo: SECURITY_AUDIT.md — **APPROVED WITH CONDITIONS** (0 Critical/High). No bloquea QA.
> **Build:** el bloqueador de compilación en `PeriodCoordinate+Title.swift` (visto a las 04:22, mientras Woz estaba a mitad del fix) **ya está cerrado**. HEAD compila en macOS e iOS Simulator con **113/113 tests** (confirmado de nuevo a las 04:25 de esta sesión). El header de quincena muestra correctamente `"September 2026 · 1 – 15 · Hoy"` el 15-sep-2026 — bug de zona horaria resuelto, confirmado por Steve y verificado en el label de accesibilidad del smoke test (`"Fecha: September 2026, 1 – 15"`).

---

## 🔴 Re-verificación final (sesión 4, build 127/127, política CivilDate + blindaje APR de Woz)

Regresión confirmada: **127/127 en macOS e iOS Simulator**. Re-test de las 4 reproducciones exactas pedidas, sobre iPhone Simulator (limpieza de datos residuales antes de empezar):

| # | Reproducción | Resultado |
|---|---|---|
| 1 | WALO ($2,750/quincena, inicio 1-sep) aparece en Sep 1–15 y NO duplicado en Sep 16–30, incluso tras reiniciar la app | 🔴 **SIGUE FALLANDO — REABIERTO** con evidencia peor: Sep 1–15 tiene 1 línea (correcto), pero Sep 16–30 tiene **3 líneas duplicadas** ($15,882.85 de total inflado). Persiste tras matar y reabrir la app — no es un problema de refetch en memoria |
| 2 | Luz ($82, día 12) aparece en la quincena 1–15 | 🔴 **SIGUE FALLANDO — REABIERTO** — se guarda en Servicios pero nunca se proyecta a ninguna quincena, total de gastos no cambia |
| 3 | Préstamo $10,000/12%/24m/día 20 → "Próximo pago" día 20, pago $470.73, línea en 16–30 | ✅ **CERRADO** — los tres sub-criterios pasan, confirmado con evidencia (detalle "Próximo pago: $470.73 · Sep 20", interés mes 1 = $100.00 exacto) |
| 4 | APR 9,999% no crashea y Guardar queda deshabilitado | ✅ **CERRADO** — sin crash; jerarquía de accesibilidad confirma `Button 'Guardar', Disabled` |

**Hallazgo adicional no solicitado:** la quincena 16–30 sigue mostrando líneas fantasma de EXPENSES de dos préstamos que ya fueron **borrados** del hub de Préstamos (0 elementos confirmados) — "Préstamo Auto" $488.86 y "Test Loan 24m" $470.73 — y esto sobrevive al reinicio completo. Sugiere que borrar un préstamo no purga sus líneas ya proyectadas en quincenas materializadas. Reportar a Woz junto con #1/#2 — los tres apuntan a la misma zona: el ciclo de vida de re-proyección/purga sobre `PeriodView` y las quincenas ya materializadas no está completo, aunque los tests unitarios de idempotencia (`reprojectRecurringIsIdempotent`, `reprojectLoanIsIdempotent`, etc.) pasen en aislamiento — el gap está en la integración real con la UI, no en el motor puro.

**Conclusión: 2 de 4 bugs originales del smoke test siguen abiertos** (duplicación de recurrentes/no aparición de servicios en su quincena). No recomendar TestFlight interno hasta que Woz cierre esto — afecta directamente la integridad de los totales, el criterio más sensible del PRD.

---

## Historial de rondas anteriores (para trazabilidad)

### Sesión 3 (build 118/118) — Bugs 1 y 2 SIGUEN ABIERTOS, Bug 3 parcialmente reabierto, 1 crítico nuevo (ya cerrado en sesión 4)

Woz reportó cerrados los 3 bugs de abajo (`.onAppear` refetch, stepper con Binding computada, día de pago sin bug real). Re-verificado en simulador (iPhone 18 Pro, fallback — "iPhone 17 Pro" no es un destino arrancable en esta máquina) tras confirmar 118/118 en macOS e iOS Simulator. Resultado: **2 de 3 siguen fallando**, con evidencia nueva.

### 🔴 Bug 1 — REABIERTO: WALO no aparece en la quincena actual (ni tras reiniciar)
Creado "WALO" $2,750/quincena en Ingresos recurrentes. Cambiar de tab y volver a Quincena (Overview→Quincena, Ajustes→Quincena): TOTAL INCOME se queda en $5,000 (solo Salario), WALO ausente. **Persiste incluso después de matar y reabrir la app por completo** — esto ya no es solo un problema de refetch de `.onAppear`, sugiere que el periodo 1–15 actual nunca re-materializa la línea del recurrente en absoluto. **Hallazgo nuevo:** WALO sí aparece en la quincena 16–30, pero **duplicado** (dos líneas de $2,750 en vez de una).

### 🔴 Bug 2 — REABIERTO: Luz (Servicio) no aparece en la quincena que le corresponde
Mismo patrón exacto: creado "Luz" $82, día 12, nunca aparece en EXPENSES de la quincena 1–15 (TOTAL EXPENSES se queda en $117.15, solo Renta), ni cambiando de tab ni reiniciando la app.

### 🟡 Bug 3 — PARCIAL: stepper y pago OK, pero "Próximo pago" sigue con off-by-one de fecha
Confirmado PASA: stepper de plazo ya no oscila (12→24 monotónico), pago $470.73 exacto, campo "Día de pago" reabierto muestra 20 correctamente, línea en EXPENSES de 16–30. Pero el resumen/primera fila de amortización muestra **"Próximo pago: Sep 19"** pese a que el día guardado es 20 — desfase de -1 día que Woz no cerró del todo (contradice su diagnóstico de que era solo efecto del storm de re-renders del stepper).

### 🔴 Bug nuevo (Crítico) — Crash por overflow de `Decimal` con APR mal ingresado
Al tocar rápido cerca de donde debía estar el stepper "Día del mes" mientras el teclado numérico de APR seguía visible, los taps se colaron como dígitos en el campo APR, inflando su valor; el cálculo de cuota `(1+r)^n` del `LoanEngine` desbordó sin manejo de excepción → **`NSDecimalNumberOverflowException`, crash**. Es un bug de validación de entrada (falta clamp/validación de rango de APR antes de usarlo en el motor), no relacionado a los 3 fixes de esta ronda. Reproducible: capturar un APR fuera de rango razonable (ej. varios miles de %) y confirmar que el cálculo de pago no crashea.

**Nota de contaminación de datos:** al iniciar esta verificación ya existían un "WALO" y un "Luz" residuales de la corrida anterior — se borraron y recrearon desde cero antes de medir, para no contaminar el resultado.

---

## Bugs encontrados en el smoke test completo (sesión 2, iPhone Simulator, build 113/113) — historial

Corrido con la skill `device-interaction` sobre iPhone 18 Pro (iPhone 17 Pro no está disponible como simulador en esta máquina — sustituido, mismo iOS 27.0). macOS no se probó en esta ronda (Secure Input de 1Password bloquea automatización de teclado en este equipo — saltado, ver nota del coordinador).

### 🔴 Bug 1 (Alto) — Recurrentes y servicios nuevos NO aparecen en la quincena actual sin reiniciar
**Reproducción:** Hub "Recurrentes y pagos" → Ingresos recurrentes → crear "WALO", $2,750 USD, cada quincena, fecha inicio hoy. Guardar. Navegar a la pestaña Quincena (Hoy). **Resultado:** TOTAL INCOME se queda en $5,000 (solo Salario), "WALO" no aparece en INCOME de Hoy. Sí aparece correctamente en la quincena siguiente (16-30, TOTAL $7,632.85) — la proyección hacia adelante funciona, pero la quincena YA materializada y visible en pantalla no se re-proyecta en vivo. Mismo patrón exacto con el **Flujo 3 (Servicio "Luz", $82, día 12)**: se crea bien, pero no aparece en la quincena 1–15 (si esa quincena ya estaba materializada/en pantalla) sin reiniciar la app.
**Nota para Woz:** esto contradice directamente `PeriodCoordinatorTests.reprojectRecurringCreatesLineOnExistingPeriod`/`reprojectSubscriptionCreatesLineOnExistingPeriod` (ambos pasan en la suite unitaria) — el motor SÍ re-proyecta correctamente sobre `ModelContext`; sospecho que el gap está en que la `View` de Quincena no observa/refresca su `@Query`/estado tras el guardado del nuevo recurrente (falta invalidar o releer). Revisar el binding entre `RecurringHubView`/`ServicesView` y `PeriodView`.

### 🔴 Bug 2 (Alto) — Stepper de "Plazo (meses)" en Nuevo Préstamo se atasca oscilando entre dos valores
**Reproducción:** Hub → Préstamos → Nuevo préstamo → tocar repetidamente el stepper de "Plazo (meses)" intentando llegar a 24. **Resultado:** el valor oscila entre pares (ej. 22↔23, 8↔9) y no avanza más allá — no se pudo configurar exactamente 24 meses en este smoke test. Con n=23 el pago mostrado fue $488.86 (consistente con la fórmula de amortización para n=23; `LoanEngineTests.prdExamplePayment` ya confirma $470.73 exacto para n=24 a nivel de motor, así que el cálculo es correcto — el bug es del control de UI del stepper, no del `LoanEngine`).

### 🟡 Bug 3 (Medium) — Día de pago del préstamo tiene off-by-one
**Reproducción:** mismo formulario de préstamo, día de pago configurado en 20. **Resultado:** el préstamo calculó/guardó el pago en el día **19**, no 20. Revisar el binding del `Stepper`/`Picker` de día de pago en el formulario de préstamo contra `LoanEngine` (los tests unitarios de `LoanEngine` usan el día correctamente, así que el desfase parece estar en la capa de formulario, no en el motor).

### ✅ Flujo 2(b)(c) Préstamo — quincena y detalle: PASA
La línea del préstamo sí aparece en la quincena 16-fin (EXPENSES), y `LoanDetailView` muestra la tabla de amortización completa (fecha/interés/capital/saldo por cuota).

### ✅ Flujo 4 Ajustes — PASA
Secciones "Preferencias" y "Seguridad" visibles. Con token Banxico inválido ("test123") + "Probar token": no crashea, muestra "Token inválido — verifica que lo copiaste completo.", y el tipo de cambio se mantiene en su último valor conocido (17.07, con indicador de advertencia) — los 3 criterios pedidos por Steve se cumplen.

---

## Regresión — números antes/después

| Corrida | Plataforma | Tests | Resultado |
|---|---|---|---|
| SECURITY_AUDIT.md, recheck M-01 (antes de sesión 1) | macOS | 49 → 53 | TEST SUCCEEDED |
| Sesión 1 — regresión inicial | macOS + iOS Simulator | 53/53 | ✅ TEST SUCCEEDED |
| Sesión 1 — con tests nuevos de Bertrand (`EdgeCaseEngineTests`) | macOS + iOS Simulator | 67 (66 passed, 1 expected failure documentando un bug, 0 failed) | ✅ TEST SUCCEEDED |
| Sesión 2 — tras los pases de Woz (tab bar, hub, Ajustes, re-proyección, límite histórico, Banxico, `LoanEngine`) | macOS (My Mac) | **106/106** | ✅ TEST SUCCEEDED — 04:20:02 |
| Sesión 2 — mismo commit | iOS Simulator (iPhone 17 Pro) | **106/106** | ✅ TEST SUCCEEDED — 04:20:15 |
| Sesión 2 — ~2 min después (Woz a mitad del fix de header/zona horaria) | macOS | N/A — BUILD FAILED transitorio | 🔴 04:22:50 — cerrado por Woz minutos después |
| Sesión 2 — fix cerrado, regresión de confirmación | macOS + iOS Simulator | **113/113** | ✅ TEST SUCCEEDED — 04:24:45 / 04:24:55 |

**Nota sobre el bug que documentaba `EdgeCaseEngineTests.materializeIfNeededDoesNotEnforceHistoricalLimit` (FIN-2026-BERTRAND-01, límite histórico):** Woz ya lo corrigió. El test fue renombrado/reescrito a `materializeIfNeededEnforcesHistoricalLimit()` y ahora **pasa en verde** (no como `withKnownIssue`) en ambas plataformas al 106/106 de la sesión 2 — confirmado, cierro este hallazgo como **resuelto**.

El único "expected failure" es un test deliberado con `withKnownIssue` que documenta el bug **FIN-2026-BERTRAND-01** (ver sección Bugs) — no es una regresión, es evidencia reproducible para Woz que no rompe el build en verde.

**Comando usado (además del MCP xcode):** `xcodegen generate` fue necesario antes de que Xcode recogiera el archivo de tests nuevo (`FintrolTests/` usa `sources: [path: FintrolTests]` con auto-detección de carpeta en `project.yml`, pero el `.xcodeproj` generado no se refresca solo).

---

## Cobertura vs. criterios de aceptación del PRD

| # | Feature (PRD) | Criterio de aceptación | Test(s) | Estado |
|---|---|---|---|---|
| 1 | Pantalla Quincena | Ve líneas INCOME/EXPENSES, switch "pagado" visual sin afectar cálculo, sobrante correcto y coloreado en tiempo real | `CarryOverEngineTests.sobranteIgnoresNothingButKind`, `sobranteThresholds`; smoke test UI (switch DONE no mueve el sobrante) | ✅ Cubierto (engine) + smoke UI |
| 2 | Conversión MXN→USD + override manual | Línea MXN convertida en total; rate de API al abrir; override persiste por quincena | `CurrencyConversionTests` (4 tests), `ExchangeRateParserTests` (9), `ExchangeRateServiceTests` (5), `ExchangeRateStoreTests` (4, cubre M-01) | ✅ Cubierto |
| 3 | "Mandar" | = suma EXPENSES en MXN ÷ tipo de cambio vigente | `CarryOverEngineTests.mandarCalculation` | ✅ Cubierto |
| 4 | Encadenado de sobrante | Sobrante N → "Latest Month" de N+1; edición pasada recalcula hacia adelante | `CarryOverEngineTests.propagatesUntilFixedPoint`, `emptyChainProducesNoUpdates`; `PeriodCoordinatorTests.carryOverChains`, `recomputeForwardStopsAtFixedPoint`; **nuevo:** `EdgeCaseEngineTests.negativeCarryOverChainsAsNegativeIncomeLine`, `recomputeForwardPropagatesNegativeSobrante` (sobrante negativo, gap cerrado) | ✅ Cubierto, incluido caso negativo |
| 5 | Recurrentes multi-año + fecha fin | Recurrente con fin genera solo en vigencia; sin fin se proyecta indefinido; edición manual gana | `ProjectionEngineTests` (9 tests: biweekly, monthlyOnDay, manual-edit-wins, etc.); `PeriodCoordinatorTests.regenerationRespectsManualEdits`; **nuevo:** `EdgeCaseEngineTests.monthlyOnDay31ClampsInShortMonth`, `monthlyOnDay31ClampsInFebruary`, `monthlyOnDayEndDateMidPeriodExcludesOccurrence`, `monthlyOnDayEndDateAfterOccurrenceIncludesIt`, `biweeklyEndDateMidRangeStillVigente`, `recurringMonthlyOnDay15Vs16Boundary`, `recurringCrossesYearBoundary` | ✅ Cubierto, gaps de día 31 / fin a mitad de quincena / cruce de año cerrados |
| 6 | Suscripciones por día de pago | Suma automática en "Payments 1–15"/"16–30" sin captura manual | `ProjectionEngineTests.subscriptionFirstHalf`, `subscriptionSecondHalf`, `subscriptionMixedCurrencyCombines`, `subscriptionEndsAfterExpiry`, `noSubscriptionsReturnsNil` | ✅ Cubierto (incluye boundary día 15 vs 16) |
| 7 | Overview mensual/anual | Income/Outcome/Total por quincena + resumen anual, solo lectura, sin materializar | Cubierto indirectamente vía `PeriodCoordinator.projectedTotals` (usa `CarryOverEngine.total`/`sobrante`, ya testeados) + smoke UI de `OverviewView` | ⚠️ Sin test directo de `PeriodCoordinator.projectedTotals` en memoria (gap, ver abajo) |
| 8 | Sync iCloud privado | Cambio en iOS visible en macOS sin acción manual | No testeable con Swift Testing/XCUITest de forma determinista (depende de CloudKit real, cuenta y red) | ❌ Fuera del alcance automatizado — ver "Qué NO testear" |
| 9 | Ajustes (rate manual, moneda default, recurrentes/suscripciones) | CRUD completo desde un solo lugar | `ExchangeRateStoreTests` cubre el rate; CRUD de `RecurringItem`/`Subscription` no tiene test de integración dedicado (usan `@Model`/`@Query` directos, comportamiento estándar de SwiftData) | ⚠️ Gap menor — ver abajo |
| 10 | Bloqueo biométrico | Switch off por defecto; pide auth al abrir/volver de background tras 60s; no muestra montos hasta autenticar | `BiometricLockStore` no tiene suite de Swift Testing propia (depende de `LAContext`, difícil de mockear sin wrapper de protocolo); validado por Ivan en SECURITY_AUDIT.md C-11 (Pass) | ⚠️ Gap — smoke test pendiente, ver bloqueador |

### Features nuevas de la sesión 2 (pases de Woz) — cobertura

| Feature nueva | Test(s) | Estado |
|---|---|---|
| **`LoanEngine`** (amortización: principal, APR, plazo, frecuencia, `paymentOverride`) | `LoanEngineTests` (10 tests): pago exacto contra ejemplo del PRD (`$10,000`/12%/24m → `$470.73`, con desglose de interés/principal/saldo de la primera cuota), caso "Upstart-like" (`$20,000`/12%/48m), APR=0 (división exacta), frecuencia quincenal (`apr/24`, `termMonths*2` cuotas), saldo final exactamente 0 (no residual de centavo), `paymentOverride` round-trip, `termMonths`⇄`endDate` round-trip, clamp de día 31 en mes corto, `direction` (borrowed→expense, lent→income), `generateLoanLines` proyecta a la quincena correcta | ✅ Cubierto a fondo (unit) — **falta la verificación end-to-end en UI** (detalle/tabla de amortización, `LoanDetailView`), bloqueada hoy por el build roto |
| **Cliente Banxico SIE** (reemplaza Frankfurter) + token en Keychain | `ExchangeRateParserTests` (payload real de Banxico, `"N/E"` día no hábil tratado como no-disponible nunca como 0, 400/401/403 con cuerpo de Banxico → `invalidToken` distinto de fallo genérico, 500 NO se trata como invalidToken); `ExchangeRateServiceTests` (sin token → cae a cache sin hacer request, throttle de 1 fetch/24h, "Probar token" bypassea el throttle, token inválido nunca se devuelve en claro); `KeychainStoreTests` (4 tests: round-trip, replace, delete idempotente, nil si no existe) | ✅ Cubierto a fondo (unit) |
| **Re-proyección de recurrentes/suscripciones sobre quincenas YA materializadas** (crear/editar/desactivar un recurrente o suscripción después de que la quincena ya existe) | `PeriodCoordinatorTests`: `reprojectRecurringCreatesLineOnExistingPeriod`, `reprojectRecurringRespectsManualEdit`, `reprojectRecurringRemovesWhenDeactivated`, `reprojectRecurringUpdatesCarryOverChain`, y los 4 equivalentes para `Subscription` | ✅ Cubierto — incluye el flujo exacto que pide Steve (crear WALO y que aparezca sin reiniciar) a nivel de motor/integración SwiftData; **falta confirmarlo en UI real**, bloqueado hoy por el build roto |
| **Header "Mes Año / día–día"** (`PeriodCoordinate+Title.swift`) | `PeriodCoordinateTitleTests` (4 tests): `dayRangeTitle` usa el último día real del mes, primera mitad siempre "1 – 15", `monthYearTitle`/`localizedMonthName` nunca caen a placeholders genéricos tipo "M09" | ⚠️ Los 4 tests pasan, pero **el archivo bajo prueba no compila ahora mismo** en el working tree (ver bloqueador) — es decir, los tests validan una versión que ya no es la que está en disco; hay que re-ejecutarlos en cuanto compile |
| **Validación de línea manual** (descripción + monto positivo) | `PeriodCoordinatorTests.manualLineValidation` | ✅ Cubierto |
| **Ajustes con secciones Preferencias/Seguridad** | Sin test automatizado (es organización de `Form`/`Section` en SwiftUI) | ⚠️ Solo smoke test — bloqueado hoy, ver bloqueador |
| **Tab bar de 4 iconos / hub "Recurrentes y pagos"** | Sin test automatizado (navegación de UI) | ⚠️ Solo smoke test — bloqueado hoy, ver bloqueador |

### Edge cases pedidos explícitamente — mapeo 1:1

| Edge case | Test | Resultado |
|---|---|---|
| 31 dic → 15 ene | `EdgeCaseEngineTests.decemberToJanuaryDateRangesAreContiguous`, `recurringCrossesYearBoundary` | ✅ |
| Febrero bisiesto | `PeriodDateEngineTests.februaryLeapYear`, `februaryNonLeapYear`, `centuryNonLeapYear`; `EdgeCaseEngineTests.monthlyOnDay31ClampsInFebruary` | ✅ |
| Recurrente mensual día 31 en meses cortos | `EdgeCaseEngineTests.monthlyOnDay31ClampsInShortMonth`, `monthlyOnDay31ClampsInFebruary` | ✅ (nuevo) |
| Recurrente con fecha fin a mitad de quincena | `EdgeCaseEngineTests.monthlyOnDayEndDateMidPeriodExcludesOccurrence`, `monthlyOnDayEndDateAfterOccurrenceIncludesIt`, `biweeklyEndDateMidRangeStillVigente` | ✅ (nuevo) |
| Suscripción día 15 vs 16 | `ProjectionEngineTests.subscriptionFirstHalf`/`subscriptionSecondHalf` (ya existía); `EdgeCaseEngineTests.recurringMonthlyOnDay15Vs16Boundary` (paralelo para `RecurringItem`, nuevo) | ✅ |
| Edición manual + cambio de recurrente | `ProjectionEngineTests.manualEditWinsRule`; `PeriodCoordinatorTests.regenerationRespectsManualEdits` (end-to-end) | ✅ (ya existía) |
| Encadenado con sobrante negativo | `EdgeCaseEngineTests.negativeCarryOverChainsAsNegativeIncomeLine`, `recomputeForwardPropagatesNegativeSobrante` | ✅ (nuevo) |
| Override de tipo de cambio fuera de rango | `ExchangeRateStoreTests` (4 tests, M-01) | ✅ (ya existía) |
| Next Month real vs. proyectado | `EdgeCaseEngineTests.previewNextMonthReturnsRealValueWhenMaterialized`, `previewNextMonthProjectsInMemoryWhenNotMaterialized` | ✅ (nuevo — gap cerrado, antes solo se testeaba la fórmula pura de `CarryOverEngine.previewNextMonth`, no el wrapper `PeriodCoordinator.previewNextMonth` que decide real-vs-proyectado) |
| Límite histórico | `EdgeCaseEngineTests.earliestMaterializedCoordinateTracksActualAnchor`; `materializeIfNeededEnforcesHistoricalLimit` | ✅ **RESUELTO por Woz** — ver Bugs |

---

## Bugs encontrados

### ✅ FIN-2026-BERTRAND-01 — El límite histórico no se aplicaba a nivel de motor, solo de UI (Medium) — **RESUELTO**

**Estado: cerrado.** En la sesión 2, `EdgeCaseEngineTests.materializeIfNeededDoesNotEnforceHistoricalLimit` (el test con `withKnownIssue` que documentaba el bug) aparece reescrito como `materializeIfNeededEnforcesHistoricalLimit()` y **pasa en verde**, sin `withKnownIssue`, en el run de 106/106 de macOS e iOS Simulator de esta sesión. Woz cerró el hallazgo en `PeriodCoordinator.materializeIfNeeded` (clamp al ancla en vez de materializar hacia atrás). No se necesita acción adicional; queda como regresión cubierta permanentemente por ese test.

**Descripción original (para referencia):** Severidad Medium — no crasheaba, no corrompía datos financieros directamente, pero violaba un invariante explícito del TRD y podía confundir la cadena de encadenado.

**Dónde:**
- `Apps/Fintrol/Fintrol/Core/PeriodCoordinator.swift`, función `materializeIfNeeded` (líneas 38–76).
- `Apps/Fintrol/Fintrol/UI/JumpSheet.swift`, propiedad `years` (línea 24–27).

**Descripción:** El TRD dice explícitamente: *"No hay quincenas 'hacia atrás' — la navegación a 'anterior' se detiene ahí; no es una proyección simétrica hacia el pasado"* y *"`PeriodDateEngine` no genera ni permite navegar a coordenadas anteriores a la primera `Period` materializada"*. En la práctica, ese límite **solo está implementado en la UI**:
- `PeriodView.swift:137` deshabilita el botón "Quincena anterior" con `.disabled(coordinate <= earliestCoordinate)` — correcto, pero es la única defensa.
- `JumpSheet.swift:24-27` (`years`) solo acota el **año** mínimo seleccionable a `min(earliest.year, currentYear)`. Dentro de ese año, el picker de **mes** (1–12) y de **quincena** (1–15 / 16–fin) no tiene ningún clamp — si la quincena más antigua materializada es, por ejemplo, junio 2026, el usuario puede abrir el Jump Sheet, dejar el año en 2026 y elegir "Enero" + "1–15", que es anterior a la quincena más antigua.
- `PeriodCoordinator.materializeIfNeeded` (el código que efectivamente crea el `Period`) no valida en ningún punto que la coordenada solicitada sea `>= earliestMaterializedCoordinate(...)`. Si se le pide una coordenada anterior al ancla existente, cae en la rama `else { toCreate = [coordinate] }` (línea 59-63) y la materializa igual, **sin ninguna línea de carry-over** (porque no hay período previo) y **corriendo el límite histórico hacia atrás** — la próxima llamada a `earliestMaterializedCoordinate` devolverá esta nueva quincena más antigua, no la original.

**Reproducción exacta:**
1. Usar la app por primera vez, materializar la quincena actual (ej. primera quincena de junio 2026) capturando cualquier línea.
2. Abrir el Jump Sheet (botón de fecha en el header de Quincena).
3. Sin cambiar el año (queda en 2026), cambiar el mes a "Enero" y la quincena a "1–15".
4. Tocar "Ir".
5. **Resultado observado (código):** la app materializa enero 2026 1–15 como una quincena nueva, sin carry-over, y el botón "Quincena anterior" ahora se habilita hacia atrás de enero también (porque el ancla se movió), rompiendo el invariante "no hay quincenas antes de la primera visitada" que el PRD/TRD fijan como regla de proyección.

**Test que lo documenta (no rompe la suite):** `Apps/Fintrol/FintrolTests/EdgeCaseEngineTests.swift`, test `materializeIfNeededDoesNotEnforceHistoricalLimit()` — usa `withKnownIssue` para dejar evidencia reproducible sin marcar la regresión en rojo. Al corregir, quitar el `withKnownIssue` y el test debe pasar en verde (confirmando el fix), no se debe borrar.

**Sugerencia para Woz:** dos capas de defensa, no solo una:
1. `JumpSheet.years`/month/half: clampear el picker de mes+quincena cuando `year == earliest.year` para no ofrecer coordenadas `< earliest`.
2. Defensa en profundidad (igual que M-01 con el rate): `PeriodCoordinator.materializeIfNeeded` debería rechazar o clampear una `coordinate < earliestMaterializedCoordinate` en vez de materializarla — el motor no debe confiar en que la UI sea la única barrera para un invariante de datos.

---

### 🟢 Observación — `earliestCoordinate` en `PeriodView` usa `coordinate` (no `todayCoordinate`) como fallback cuando no hay nada materializado (Info, no bloqueante)

`PeriodView.swift:33`: `PeriodCoordinator.earliestMaterializedCoordinate(context: context) ?? coordinate`. En el primer arranque (`isMaterialized` store vacío), `earliestCoordinate` es el `@State coordinate` actual, que solo se actualiza después de `loadPeriod()`. Es un fallback razonable en la práctica (la primera navegación hacia atrás queda bloqueada porque `coordinate == earliestCoordinate`), pero no se verificó con un test de UI automatizado — solo con smoke test manual. No se reporta como bug, queda como nota para Woz/Bertrand si en el futuro se automatizan UI tests con XCUITest.

---

## Gaps de cobertura que quedan (no bloqueantes para TestFlight interno)

0. **BLOQUEANTE — Smoke test de los 4 flujos pedidos por Steve** (WALO recurrente, préstamo $10,000/12%/24m día 20, Servicio Luz $82 día 12, Ajustes Preferencias/Seguridad) y confirmación del bug de header "August 1–15". Ninguno se pudo correr porque el HEAD no compila ahora mismo (ver "Bloqueador activo"). Repetir en cuanto Avie corrija `PeriodCoordinate+Title.swift`. Prioridad: **Alta, primero que nada**.
1. **`PeriodCoordinator.projectedTotals` (Overview en memoria)** — no tiene test directo de `PeriodCoordinator`, solo se apoya en que `CarryOverEngine.total`/`sobrante` ya están probados. Recomendado: un test de integración con `ModelContext` en memoria que materialice 2-3 quincenas, deje años intermedios sin materializar, y verifique que `projectedTotals` para una quincena lejana futura da el mismo resultado que materializarla manualmente paso a paso. Prioridad: Media.
2. **CRUD de `RecurringItem`/`Subscription` desde `SettingsView`/`RecurringView`/`SubscriptionsView`** — sin test de integración (alta/edición/baja). Es SwiftData estándar (`@Query` + `context.insert/delete`), bajo riesgo, pero no está cubierto explícitamente. Prioridad: Baja (el riesgo real vive en `ProjectionEngine`/`PeriodCoordinator`, ya cubiertos).
3. **`BiometricLockStore`** — sin suite de Swift Testing. Requiere abstraer `LAContext` detrás de un protocolo inyectable para poder testear `attemptEnableLock()`/`handleScenePhaseChange` sin biometría real. Hoy solo está validado por: (a) lectura de código en SECURITY_AUDIT.md C-11 (Pass), (b) smoke test manual. Prioridad: Media — es Tier 2 de seguridad (datos financieros), vale la pena el esfuerzo de abstracción en una iteración futura.
4. **Sync CloudKit real** — no automatizable de forma determinista sin dos dispositivos/cuentas reales. Se deja fuera de la suite automatizada por diseño (ver "Qué NO testear").
5. **`ExchangeRateService` contra la red real** — los tests actuales usan payloads simulados (`URLProtocol` mock, según el patrón ya usado en `ExchangeRateServiceTests`); no hay un test (ni debería haberlo en CI) que golpee `api.frankfurter.app` de verdad. Aceptado — sería un test no determinista.

---

## Qué testear — priorizado por riesgo

| # | Área | Tipo de test | Prioridad | Estado |
|---|---|---|---|---|
| 1 | `PeriodDateEngine` (fechas de quincena, cruce de año/mes, bisiestos) | Unit | Alta | [x] |
| 2 | `CurrencyConversion` (Decimal, MXN↔USD) | Unit | Alta | [x] |
| 3 | `CarryOverEngine` (sobrante, mandar, encadenado, fixed-point, sobrante negativo) | Unit | Alta | [x] |
| 4 | `ProjectionEngine` (recurrentes, suscripciones, manual-edit-wins, edge cases de fecha) | Unit | Alta | [x] |
| 5 | `ExchangeRateParser` / `ExchangeRateService` (parseo defensivo, fallback en cascada) | Unit | Alta | [x] |
| 6 | `ExchangeRateStore.applyManualOverride` (M-01, rango 1-100) | Unit | Alta | [x] |
| 7 | `PeriodCoordinator` (materialización perezosa, recompute forward, Next Month real vs. proyectado, límite histórico) | Integration (SwiftData en memoria) | Alta | [x] (con 1 bug documentado) |
| 8 | `SchemaV1` / `ModelContainer` abre limpio | Integration | Media | [x] |
| 9 | Flujo Quincena end-to-end en simulador/macOS (agregar línea, marcar pagado, navegar) | UI / Smoke manual | Alta | [x] ver sección Smoke test |
| 10 | Bloqueo biométrico end-to-end (switch, re-lock tras 60s, no exponer montos) | UI / Smoke manual | Alta | [x] ver sección Smoke test |
| 11 | `PeriodCoordinator.projectedTotals` (Overview) | Integration | Media | [ ] Gap — ver arriba |
| 12 | CRUD Recurrentes/Suscripciones | Integration | Baja | [ ] Gap — ver arriba |
| 13 | `BiometricLockStore` unit-testeable | Unit | Media | [ ] Gap — requiere abstracción de `LAContext` |
| 14 | Sync CloudKit real | — | — | No aplica a esta suite (ver "Qué NO testear") |

---

## Qué NO testear

- **Sync CloudKit real entre dos dispositivos** — no determinista, depende de red/cuenta/latencia de Apple; se valida manualmente por el usuario en uso real (TestFlight), no en CI.
- **Internals de componentes `Lab*` de `AppleAppLabUI`** (`LabToggleRow`, `LabTextField`, `LabEmptyState`, etc.) — ya tienen accesibilidad y comportamiento correcto por diseño (paquete compartido); Bertrand testea los flujos de Fintrol que los usan, no los componentes en sí.
- **La respuesta real de `api.frankfurter.app`** — se testea con payloads simulados; un test contra la red real sería no determinista y no debe vivir en CI.
- **StoreKit / monetización** — no aplica, fuera del alcance de v1 (PRD).
- **Tarjetas de crédito / Goals / control de inversiones** — explícitamente fuera del MVP (PRD "Features — Fuera del MVP").

---

## Estructura de tests

```
FintrolTests/
├── CarryOverEngineTests.swift          # sobrante, mandar, encadenado, fixed-point
├── CurrencyConversionTests.swift       # Decimal MXN↔USD
├── EdgeCaseEngineTests.swift           # (Bertrand) — cruce de año, día 31, fin a mitad de
│                                       #   quincena, sobrante negativo, Next Month real vs.
│                                       #   proyectado, límite histórico (bug ya resuelto por Woz)
├── ExchangeRateParserTests.swift       # parseo defensivo Banxico SIE
├── ExchangeRateServiceTests.swift      # fallback en cascada, throttle 24h, token inválido (actor)
├── ExchangeRateStoreTests.swift        # M-01: override manual con rango
├── KeychainStoreTests.swift            # token de Banxico en Keychain: round-trip, replace, delete
├── LoanEngineTests.swift               # amortización: pago, tabla, paymentOverride, clamps
├── PeriodCoordinateTitleTests.swift    # header "Mes Año / 1–15" — sin placeholders genéricos
├── PeriodCoordinatorTests.swift        # integración SwiftData en memoria + re-proyección
├── PeriodDateEngineTests.swift         # fechas de quincena, bisiestos
├── ProjectionEngineTests.swift         # recurrentes, suscripciones, manual-edit-wins
└── SchemaV1Tests.swift                 # ModelContainer abre limpio
```

**106 tests en total, 10 suites** (última corrida verde antes del bloqueador: macOS 106/106 a las 04:20:02, iOS Simulator 106/106 a las 04:20:15, sesión 2).

Todas las suites usan **Swift Testing** (`@Test`/`#expect`/`@Suite`), no XCTest — consistente con el TRD ("target de tests `FintrolTests` (Swift Testing, no XCTest)"). No hay UI tests automatizados con XCUITest en este repo todavía; el smoke test de esta sesión fue manual, dirigido por el subagente `device-interaction`. Si en el futuro se decide invertir en XCUITest, seguir el patrón de `PATTERNS.md` (referenciar por `accessibilityLabel`, no coordenadas).

---

## Cómo correr

**Vía MCP xcode (preferido, usado en esta sesión):**
```
XcodeSwitchRunDestination → "My Mac" o "iPhone 17 Pro" (o el simulador que esté booteado)
RunAllTests(workspaceIdentifier: "workspace-X7USGiffHg")
```

**Vía terminal (fallback):**
```bash
cd Apps/Fintrol
xcodegen generate   # solo si se agregaron/movieron archivos de test — el .xcodeproj generado no se auto-refresca
xcodebuild test -project Fintrol.xcodeproj -scheme Fintrol -destination 'platform=macOS'
xcodebuild test -project Fintrol.xcodeproj -scheme Fintrol -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**Nota importante para cualquiera que agregue tests nuevos:** `FintrolTests` usa `sources: [path: FintrolTests]` en `project.yml` (auto-detección de carpeta por XcodeGen), pero eso solo toma efecto en el **próximo** `xcodegen generate` — un archivo `.swift` nuevo en la carpeta no aparece en el test run hasta regenerar el proyecto. Esta sesión lo confirmó: los tests nuevos no corrieron (seguía en 53) hasta correr `xcodegen generate` manualmente.

---

## Plan de TestFlight interno (uso personal)

Dado que el PRD fija v1 como **distribución personal** (TestFlight interno o instalación directa, sin App Store público, sin Phil/Kate):

- **Beta testers:** el propio usuario (`hi@9866.mx`), en su iPhone y su Mac — es una app de un solo usuario por diseño (PRD). No hay grupo externo de testers en v1.
- **Duración:** uso continuo desde el primer build de TestFlight interno — no hay ventana fija de "beta"; la app reemplaza directamente la hoja de cálculo (`Mis Finanzas 2.0.xlsx`) en cuanto el usuario confía en los números, así que el criterio de salida es "los totales de la app coinciden con la hoja durante al menos una quincena completa corrida en paralelo".
- **Flujos a probar en el primer build real (dispositivo físico, no solo simulador):**
  1. Capturar la primera quincena real con los montos reales del usuario (WALO, Rent, Upstart #1/#2, Ada, Abuelos, etc.) y comparar el sobrante contra la hoja de cálculo actual línea por línea.
  2. Confirmar que el override manual del tipo de cambio funciona y persiste tras cerrar/reabrir la app.
  3. Confirmar sync iCloud real: capturar una línea en iPhone, abrir en Mac (o viceversa) y confirmar que aparece sin acción manual — este es el único flujo de esta lista que **no** se puede validar en CI/simulador, requiere dos dispositivos reales con la misma cuenta de iCloud.
  4. Activar el bloqueo biométrico en un dispositivo físico con Face ID/Touch ID real (el simulador no siempre tiene biometría enrolada de forma confiable — ver sección Smoke test) y confirmar que backgroundear >60s pide autenticación real.
  5. Navegar varios años adelante (proyección de préstamos a plazo, ej. Upstart a 4 años) y confirmar que las cifras coinciden con lo esperado manualmente para al menos 2-3 quincenas de muestra.
- **Cómo reportar bugs:** dado que es un solo usuario/tester, no se necesita un canal formal (TestFlight feedback / Slack) — el propio usuario reporta directo en la conversación con el equipo (Steve → Bertrand/Woz), citando quincena exacta, monto esperado vs. observado, y si es posible captura de pantalla. Para hallazgos encontrados por Bertrand/QA automatizada, el formato ya usado en este documento (reproducción exacta + archivo:línea) es el estándar.
- **Build:** Debug/Release firmado con el Team ID del usuario, sin necesidad de External Testing de App Store Connect (Internal Testing basta para hasta 100 personas con el mismo Apple ID del desarrollador — sobra para 1 usuario).

---

## Performance

| Métrica | Target | Medido | Estado |
|---|---|---|---|
| Apertura de la app (cold start, primer frame útil) | < 1 s (target explícito de la tarea; PRD/checklist general de Bertrand pide < 400ms en dispositivo real como ideal) | No medido con Instruments en esta sesión — requiere dispositivo físico + Time Profiler / App Launch template | ⚠️ Pendiente — ver nota |
| Cambio de quincena (navegación anterior/siguiente) | Instantáneo (sin spinner perceptible) — el store es SwiftData local, materialización perezosa acotada | Observado en smoke test: ver hallazgos de la corrida en simulador/macOS | Ver sección Smoke test |
| Memoria (footprint típico, presupuesto de años) | < 150MB (checklist estándar de Bertrand para el dispositivo mínimo del target) | No medido con Instruments (Allocations) en esta sesión | ⚠️ Pendiente |
| Recálculo de encadenado tras editar una quincena pasada | Acotado por el fixed-point del TRD — costo proporcional a quincenas materializadas después de la editada, no a toda la proyección | Validado algorítmicamente por `CarryOverEngineTests.propagatesUntilFixedPoint`/`emptyChainProducesNoUpdates` — el test confirma que el recálculo **se detiene** en el primer punto fijo en vez de recorrer todas las quincenas | ✅ Validado por diseño/test, no por profiling de reloj |

**Nota:** esta sesión no corrió Instruments (Time Profiler / App Launch / Allocations) porque el foco fue regresión funcional + cobertura de edge cases + smoke UI. Antes del primer archive de TestFlight real, correr:
```
Instruments → App Launch (dispositivo físico, no simulador) → confirmar < 1s hasta primer frame con datos
Instruments → Allocations → primer snapshot en frío, y snapshot tras navegar ~5 años de proyección
```
Esto queda como pendiente explícito en el checklist de abajo, no como "✅" falso.

---

## Checklist antes de TestFlight interno

- [x] `SECURITY_AUDIT.md` no está `BLOCKED` (APPROVED WITH CONDITIONS, 0 Critical/High)
- [x] Tests unitarios pasan en macOS (106/106, última corrida verde de la sesión 2)
- [x] Tests unitarios pasan en iOS Simulator (106/106, última corrida verde de la sesión 2)
- [ ] **BLOQUEADO:** el HEAD actual no compila (`PeriodCoordinate+Title.swift:15,24`) — no se puede confirmar "sin crashes en flujos principales" hasta que compile y se repita el smoke test de los 4 flujos nuevos
- [ ] Dark Mode — revisado manualmente (pendiente de confirmación explícita en el smoke test de esta sesión)
- [x] Bloqueo biométrico — validado por código (SECURITY_AUDIT C-11) + intento de smoke test (ver limitaciones del simulador abajo)
- [ ] Sin memory leaks obvios en Instruments (Leaks template) — pendiente, requiere sesión de Instruments dedicada
- [ ] Launch time < 1s en dispositivo real — pendiente, requiere dispositivo físico
- [x] App funciona sin conexión (fallback de tipo de cambio a cache/override — validado por `ExchangeRateServiceTests`)
- [x] Restauración de estado — SwiftData es la fuente de verdad local, no hay estado efímero crítico fuera del store

## Checklist antes de App Store (no aplica a v1 — referencia para etapa futura)

v1 es distribución personal sin App Store público (PRD, decisión registrada). Esta sección se deja como referencia si el usuario decide abrir la app más adelante (PRD, Fase 3):
- [ ] Beta testers externos han reportado bugs
- [ ] Flujos de error probados (sin red, storage lleno, permisos denegados)
- [ ] Prueba en el dispositivo más antiguo del target (iOS 26 mínimo)
- [ ] Privacy Nutrition Label es precisa
