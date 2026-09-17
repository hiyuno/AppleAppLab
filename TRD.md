# TRD — Fintrol

> Última actualización: 2026-09-15. Basado en PRD v1.1.
> Decisiones técnicas vinculantes. Cambiar algo aquí requiere actualizar este documento.

---

## Stack técnico

Swift nativo — HIG, Liquid Glass, CloudKit privado y performance nativa son requisitos explícitos del PRD; no hay ninguna razón (código previo, multiplataforma no-Apple) que justifique Electron/Tauri.

| Área | Decisión | Justificación |
|------|----------|----------------|
| UI Framework | SwiftUI, un solo target multiplataforma (iOS 26 + macOS 26) | Liquid Glass nativo requiere SwiftUI; un target comparte 100% del dominio y la mayoría de la UI vía `AppleAppLabUI` |
| Estado | `@Observable` (Observation framework) | Swift 6 nativo, sin boilerplate de Combine; encaja con MV + engines de dominio (ver Arquitectura) |
| Persistencia | SwiftData | Única fuente de verdad local; integra sync CloudKit sin código de red propio |
| Sync | SwiftData + CloudKit (`.automatic`), contenedor privado | App de un solo usuario, sin colaboración — no se justifica `CKContainer` manual (ver CloudKit) |
| Red | `URLSession` + `async/await`, una sola llamada GET con header `Bmx-Token` (tipo de cambio, Banxico SIE) | No hay necesidad de nada más pesado que `URLSession.data(from:)`; el token se agrega como header, no cambia el cliente |
| Concurrencia | Swift Concurrency (`async/await`), Swift 6 strict concurrency mode | Target iOS/macOS 26 soporta Swift 6 completo desde día 1 |
| Dependencias de terceros | Cero. Solo `AppleAppLabUI` (paquete local del equipo) | El SDK de Apple resuelve todo lo que este proyecto necesita |

```yaml
# project.yml — sección packages
packages:
  AppleAppLabUI:
    path: ../../Packages/AppleAppLabUI

targets:
  Fintrol:
    dependencies:
      - package: AppleAppLabUI
        product: AppleAppLabUI
```

---

## Arquitectura

**Patrón:** MV (Model-View, el patrón nativo que Apple recomienda para SwiftUI + SwiftData) **+ capa de Engines de dominio**, no MVVM clásico.

**Justificación:** Las Views leen SwiftData directo con `@Query`/`@Environment(\.modelContext)` — no hay valor en ViewModels que solo reenvían `@Query`. Pero la lógica real de este proyecto (encadenado de sobrante, proyección de recurrentes a años, regla "la edición manual gana", conversión de moneda) es lógica de negocio pura, no lógica de presentación, y **debe ser testable sin UI y sin SwiftData montado**. Por eso vive en `Core/Engine/` como structs Swift puros (`Sendable`, sin `@Model`), que reciben/devuelven datos planos y que las Views (o un thin coordinator) invocan contra el `ModelContext`. Esto evita el boilerplate de un ViewModel por pantalla sin sacrificar testabilidad en la parte que sí importa: el cálculo financiero.

**Estructura de carpetas** (feature-first, `Core/` compartido — nivel B del proyecto por la complejidad de la proyección):

```
Fintrol/
├── App/
│   └── FintrolApp.swift            # ModelContainer, entry point
├── Features/
│   ├── Period/                     # Pantalla Quincena
│   │   ├── PeriodView.swift
│   │   └── PeriodDetailComponents/ # subviews específicas (LineItemRow, SobranteBadge…)
│   ├── Subscriptions/
│   ├── Recurring/
│   ├── Overview/
│   └── Settings/
├── Core/
│   ├── Models/                     # @Model — Period, LineItem, RecurringItem, Subscription
│   ├── Engine/                     # Lógica pura, testable, sin SwiftData/UI
│   │   ├── PeriodDateEngine.swift       # generación determinista de fechas de quincena
│   │   ├── ProjectionEngine.swift       # expande RecurringItem/Subscription → líneas
│   │   ├── CarryOverEngine.swift        # encadenado de sobrante hacia adelante
│   │   ├── CurrencyConversion.swift     # Decimal, MXN↔USD
│   │   └── LoanEngine.swift             # amortización de Loan, determinista
│   ├── Migration/                  # VersionedSchema + SchemaMigrationPlan
│   └── Extensions/
├── Services/
│   └── ExchangeRateService.swift   # actor: fetch + cache + fallback
├── UI/                              # solo lo que NO está en AppleAppLabUI
└── Resources/
```

---

## Modelo de datos (SwiftData + CloudKit)

### Entidades

**`Period`** (quincena)
- `id: UUID`
- `startDate: Date`, `endDate: Date` — límites reales de esa quincena (informativos; el cálculo de a qué `Period` pertenece una fecha se hace con `PeriodDateEngine`, no comparando estas fechas)
- `year: Int`, `month: Int`, `half: PeriodHalf` (`.first` = 1–15, `.second` = 16–fin) — clave natural para lookup/materialización, indexado
- `manualExchangeRateOverride: Decimal?` — override del tipo de cambio para **esta quincena completa**; si está presente, todas las conversiones MXN→USD de sus líneas lo usan en vez del rate cacheado del día
- `lineItems: [LineItem]?` — relación opcional (requisito CloudKit, ver Limitaciones)
- `isMaterialized: Bool` — ver "Materialización perezosa"

**`LineItem`** (línea de INCOME o EXPENSES)
- `id: UUID`
- `kind: LineKind` (`.income` / `.expense`)
- `title: String`
- `amount: Decimal`
- `currency: Currency` (`.usd` / `.mxn`)
- `isPaid: Bool` — switch visual, **no participa en ningún cálculo**
- `sortOrder: Int`
- `origin: LineOrigin` (`.manual`, `.carryOver`, `.recurring`, `.subscription`, `.loan`, `.investment`)
- `sourceRecurringID: UUID?` — enlace lógico al `RecurringItem`/`Subscription` que la generó (no relación SwiftData para no forzar acoplamiento; se resuelve por `id` al regenerar)
- `sourceLoanID: UUID?` — mismo mecanismo que `sourceRecurringID` pero para `Loan`; una línea `.loan` nunca tiene ambos campos poblados
- `isManuallyEdited: Bool` — **bandera central de la regla "la edición manual gana"**: se pone en `true` en cualquier edición del usuario sobre una línea con `origin != .manual`; el motor de regeneración nunca toca una línea con esta bandera en `true`
- `exchangeRateSnapshot: Decimal?` — tipo de cambio efectivo usado al calcular esta línea (para que "Mandar" y el histórico no cambien retroactivamente si el rate cacheado cambia después)
- `isHomeService: Bool` — solo relevante cuando `origin == .subscription`; distingue la línea combinada "Servicios" (hogar) de "Payments" (suscripciones); ambas comparten `origin == .subscription`, no hay un origin `.service` separado
- `paidAt: CivilDate?` — **decisión del usuario:** se setea al momento en que el usuario marca `isPaid = true` (swipe en `PeriodView`), se limpia a `nil` si se desmarca. No es la fecha programada del pago (esa ya vive en la fecha de la quincena/`Period`) — es la fecha real en que el usuario confirmó el pago. Sigue la convención `CivilDate` (ver "Decisiones de Swift" — política de fechas), no `Date` crudo.
- `period: Period?` (inverso, opcional)

**`RecurringItem`**
- `id: UUID`, `kind: LineKind`, `title: String`, `amount: Decimal`, `currency: Currency`
- `frequency: RecurringFrequency` (`.biweekly`, `.monthlyOnDay(Int)`, `.once(Date)`)
- `startDate: Date`, `endDate: Date?`
- `isActive: Bool`
- `category: RecurringCategory` (`.general` default | `.investment`) — **feature "Inversiones", decisión del usuario: se modela reutilizando `RecurringItem`, no una entidad aparte.** Una aportación recurrente es, estructuralmente, idéntica a cualquier otro recurrente (monto, moneda, frecuencia `.biweekly`/`.monthlyOnDay(día)` ya cubre "cada quincena / mensual día X", inicio, fin opcional, activo) — crear un `Investment` aparte solo duplicaría `reprojectRecurring`, materialización y el motor de vigencia sin ganar nada. `kind` en una aportación es siempre `.expense`.
- `accountName: String?` — solo poblado cuando `category == .investment`; nombre de la cuenta destino que muestra la pantalla "Inversiones"

**Origen de línea:** `ProjectionEngine.generateRecurringLines` decide `LineItem.origin` a partir de `category`: `.investment` si `category == .investment`, `.recurring` en cualquier otro caso — sigue poblando `sourceRecurringID` (no se agrega un `sourceInvestmentID` nuevo; es el mismo campo, ya genérico). `PeriodCoordinator.reprojectRecurring` y la baja de un `RecurringItem` (`deleteRecurring`) no cambian: operan igual sobre cualquier `category`.

**Pantalla "Inversiones":** lista cada `RecurringItem` con `category == .investment` mostrando `accountName` y "aportado a la fecha" = suma de `amount` de sus `LineItem` materializadas (`origin == .investment && sourceRecurringID == item.id`) — no filtra por `isPaid` (esa marca nunca afecta cálculos, regla general del PRD). Desactivar el `RecurringItem` (`isActive = false`) dispara `reprojectRecurring`, que retira sus líneas futuras no editadas manualmente — el acumulado baja porque las líneas materializadas correspondientes desaparecen, no porque haya un flag adicional que filtrar.
**Fuera de v1** (ya decidido en el PRD, sin cambios): rendimientos, valor actual de la cuenta, portafolios — "Inversiones" en v1 es solo registro de aportaciones, el hueco de etapa 2 (control de inversiones real) queda intacto.

**`Subscription`** — **actualizado a como lo implementó Woz, distinto de lo documentado originalmente aquí:**
- `id: UUID`, `name: String`, `price: Decimal`, `currency: Currency`
- `paymentDay: Int` (1–31), `startDate: Date`, `endDate: Date?`
- `card: String`
- `kind: SubscriptionKind` (`.subscription` / `.service`) — **una sola entidad cubre tanto "Suscripciones" (Tools/Entertainment/Apartment/Work/Personal/Hobby/Investment) como "Servicios del hogar"** (renta, luz, internet, agua, gas, seguro); Woz reutilizó el modelo en vez de crear uno nuevo para mantener CloudKit simple (sin entidad ni relación adicional)
- `category: String` — interpretado contra `SubscriptionCategory` cuando `kind == .subscription`, o contra `HomeServiceCategory` cuando `kind == .service`: un solo campo, dos catálogos de categorías según `kind`
- **Contradicción con el PRD que Avie señala, no acomoda:** el PRD (Suscripciones/Services List) no describe "Servicios del hogar" como concepto separado del feature de suscripciones — esta bifurcación (`kind`, `HomeServiceCategory`, línea combinada "Servicios 1–15/16–30" en paralelo a "Payments 1–15/16–30") es una decisión de implementación (Woz, según `DESIGN_LIQUID.md`) no registrada previamente en este documento ni en el PRD. Queda documentada aquí como lo que el código realmente hace; si no era la intención de producto, es una conversación para Scott, no un ajuste silencioso del TRD.

**`Loan`**
- `id: UUID`, `name: String`
- `direction: LoanDirection` (`.borrowed` → sus pagos generan `LineItem.expense`; `.lent` → sus pagos generan `LineItem.income`)
- `mode: LoanMode` (`.fixedTerm` | `.revolving`) — decisión del usuario: **`.revolving`** ("Hasta liquidar") modela deuda tipo tarjeta sin plazo fijo, donde el interés se acumula sobre saldo y el usuario paga un monto esperado por período hasta liquidar
- `principal: Decimal`, `currency: Currency` (USD/MXN)
- `apr: Decimal` — tasa anual
- `startDate: Date`
- `termMonths: Int?`, `endDate: Date?` — **obligatorios (uno deriva del otro) en `.fixedTerm`; ambos opcionales en `.revolving`**, donde el fin lo determina el saldo, no un plazo capturado
- `expectedPayment: Decimal?` — **solo relevante en `.revolving`**: el pago que el usuario planea hacer cada período mientras no haya un pago real registrado; en `.fixedTerm` el pago fijo lo calcula `LoanEngine.schedule` como hasta ahora, este campo no aplica
- `frequency: LoanFrequency` (`.monthly(day: Int)` default, `.biweekly`)
- `paymentOverride: Decimal?` — **solo `.fixedTerm`**: si el usuario fija un pago distinto al calculado, `LoanEngine` recalcula `n` (número de pagos) a partir de este monto en vez de derivar el pago desde `termMonths`
- `isActive: Bool`
- `lineItems: [LineItem]?` (inverso vía `sourceLoanID`, opcional — no es relación `@Relationship` directa, se resuelve igual que recurrentes/suscripciones)

**`ExchangeRateCache`** (una fila viva, no historial completo)
- `date: Date` — fecha del último fetch exitoso
- `rate: Decimal` — USD→MXN
- `fetchedFromAPI: Bool` — `false` si esta fila quedó de un fallback

### Qué se persiste vs. qué se calcula

| Dato | Persiste | Se calcula |
|------|----------|------------|
| Fechas de corte de cada quincena | No | `PeriodDateEngine` (pura función de año/mes/half) |
| Líneas generadas por recurrentes/suscripciones/préstamos vigentes en una quincena aún no visitada | No | `ProjectionEngine` + `LoanEngine`, bajo demanda |
| Tabla de amortización, desglose interés/capital, saldo restante de un `Loan` | No — siempre derivado | `LoanEngine.schedule(for: loan)`, determinista a partir de `principal`/`apr`/`frequency`/`paymentOverride` |
| "Pagado hasta hoy" de un `Loan` | No — se lee de las `LineItem` ya materializadas | `isPaid == true` sobre las líneas `origin == .loan` de ese `Loan` |
| Líneas de una quincena ya visitada/editada | Sí (`LineItem`) | — |
| TOTAL INCOME / TOTAL EXPENSES / Sobrante / "Mandar" | No — siempre derivado | Calculado en cada render desde `lineItems` de esa `Period` |
| Tipo de cambio del día | Sí (`ExchangeRateCache`, 1 fila) | Refrescado al abrir/pull-to-refresh |
| Override de tipo de cambio por quincena | Sí (`Period.manualExchangeRateOverride`) | — |

### Materialización perezosa (sin crear 240 registros de golpe)

El riesgo del PRD ("proyección infinita") se resuelve así: **una `Period` y sus `LineItem` solo se crean en SwiftData cuando el usuario navega a esa quincena o algo la fuerza a materializarse.**

1. `PeriodDateEngine` calcula el rango de fechas de cualquier `(year, month, half)` sin tocar el store — es una función pura. La navegación "quincena anterior/siguiente" avanza sobre estas coordenadas, no sobre registros.
   - **Límite histórico — ahora dos topes, gana el más restrictivo (cambio de comportamiento, decisión del usuario):**
     - **Piso (ya existía, sin cambios):** nunca antes de la primera `Period` materializada — no hay quincenas "hacia atrás" de donde el usuario empezó a usar la app.
     - **Techo (nuevo, configurable):** "meses hacia atrás visibles desde la quincena actual", `Int`, default `1`, guardado en `UserDefaults`/`@AppStorage` (misma convención que apariencia/re-bloqueo — no es un dato financiero, no va en SwiftData). Semántica exacta: dado el `PeriodCoordinate` de "hoy" y `N` meses, el techo es **resta de mes civil, no de días** — `(year, month) − N meses`, mitad `.first` de ese mes resultante. Como `.first` es la mitad más antigua del mes, **ambas mitades de ese mes-techo quedan navegables** (la `.second` es cronológicamente posterior al `.first`, dentro del mismo límite).
     - **Combinación:** el límite efectivo de navegación hacia atrás = `max(pisoMaterializado, techoPorMeses)` (el coordinate más tardío/restrictivo de los dos gana). Si el techo por meses cae antes de la primera quincena materializada, el piso gana — nunca se ofrece navegar a una quincena que no existe. Si no hay ninguna `Period` materializada todavía, solo aplica el techo.
     - **Dónde vive:** el cálculo puro "N meses atrás desde hoy, mitad `.first`" es una función determinista de `CivilDate` (mismo tipo/aritmética de meses que ya usa `LoanEngine` para plazos) → vive en `PeriodDateEngine` (p. ej. `monthsAgoCoordinate(from:months:)`), sin tocar SwiftData ni `UserDefaults`. La combinación con el piso materializado (que sí necesita `ModelContext`) vive en `PeriodCoordinator` (p. ej. `navigableLowerBound(context:monthsBack:)`, recibe `monthsBack` como parámetro — no lee `@AppStorage` directamente, esa lectura queda en la View/Ajustes, igual que el resto de `Core/` no toca UI ni almacenamiento de preferencias). El chevron "atrás" de `PeriodView`/`JumpSheet` se deshabilita cuando el coordinate actual `== navigableLowerBound`.
     - **Tests obligatorios (Bertrand):** `N=1` desde Sep 1–15 → límite Ago 1–15, ambas mitades navegables; cambiar el setting a `N=3` amplía el rango de navegación sin re-materializar ni perder datos ya existentes (es solo un límite de navegación, no afecta qué está persistido); si `N` implica una fecha anterior a la primera quincena materializada, el piso gana (se navega solo hasta la primera materializada, no hasta donde `N` alcanzaría).
2. Al entrar a una quincena:
   - Si ya existe un `Period` materializado para esa `(year, month, half)` → se lee tal cual.
   - Si no existe → se materializa: se crea el `Period`, se llama a `ProjectionEngine` para generar sus `LineItem` (recurrentes vigentes + suscripciones vigentes + la línea de carry-over "Latest Month" tomada del `Period` anterior, materializándolo primero si hace falta — recursión acotada por la fecha destino) y se marca `isMaterialized = true`.
3. Overview y cualquier vista de "consulta rápida a futuro" (ej. "¿cómo se ve en 10 años?") **no materializan**: corren `ProjectionEngine` en memoria sobre los `RecurringItem`/`Subscription` activos y devuelven totales calculados, sin escribir en SwiftData. Materializar es una acción explícita (navegar/editar), no un side-effect de ver un resumen.

Esto mantiene el store acotado al historial realmente usado, nunca a "24 quincenas × N años" de una proyección teórica.

### Calendario y zona horaria — regla que faltaba documentar aquí

Fix real de un bug de producción, no estaba en la versión anterior de este TRD: `PeriodDateEngine` usa **dos calendarios distintos a propósito**, y confundirlos fue la causa raíz de que la app abriera en el mes equivocado.
- `Calendar.gregorianUTC` — para todo cálculo de fecha *puro* que no depende de "ahora" (`dateRange(for:)`, `date(forDayOfMonth:in:)`): determinista sin importar la zona horaria del dispositivo.
- `Calendar.current` (local del dispositivo) — exclusivamente en `coordinate(containing: Date())`, porque "qué día es hoy" es un concepto de la zona horaria del usuario, no UTC; usar UTC ahí podía clasificar mal el día cerca de medianoche.
- Los formatters de título (`monthYearTitle`, `localizedMonthName` en `Core/Extensions/PeriodCoordinate+Title.swift`) construyen el `Date` con `gregorianUTC` y **deben** formatearlo con `Date.FormatStyle(timeZone: .init(identifier: "UTC")!)` — no basta encadenar `.timeZone(_:)` sobre `.dateTime` (eso solo cambia el símbolo de zona mostrado, no en qué zona se calculan los componentes). Sin este pin, cualquier dispositivo en UTC−N renderiza el mes anterior.

### Encadenado de sobrante — estrategia de recálculo

- El sobrante de `Period` N vive como el **monto calculado** de N (INCOME − EXPENSES, siempre derivado, nunca persistido como campo separado).
- Al materializar `Period` N+1, `CarryOverEngine` toma el sobrante ya calculado de N y crea la línea `LineItem(origin: .carryOver, title: "Latest Month", ...)` en el INCOME de N+1.
- **Edición retroactiva:** si el usuario edita una línea en una `Period` ya materializada, se dispara `CarryOverEngine.recomputeForward(from: period)`:
  1. Recalcula el sobrante de `period`.
  2. Si existe `Period` N+1 **materializada**, actualiza su línea `.carryOver` con el nuevo monto.
  3. Compara el sobrante resultante de N+1 con el que tenía antes de este recálculo. Si no cambió → **se detiene** (fixed point, no hay nada que propagar más adelante). Si cambió → repite el paso 2 sobre N+2, y así sucesivamente.
  4. Periods **no materializadas** no se tocan — cuando el usuario navegue a ellas, se materializan ya con el carry-over correcto porque parten del sobrante ya actualizado de la última materializada.
- Esto es recálculo **incremental, no completo**: el costo es proporcional a cuántas quincenas materializadas hay después de la editada y se corta en cuanto el cambio deja de propagarse (típicamente 0–2 quincenas en uso normal, nunca "todas las quincenas futuras" salvo que el usuario tenga cientos ya visitadas).
- `CarryOverEngine.recomputeForward` corre síncrono en `MainActor` tras cada edición confirmada (no en cada keystroke) — volumen de datos de un presupuesto personal (decenas de quincenas materializadas, no miles) hace innecesario moverlo a background.
- **"Next Month" (preview informativo, no materializa):** `CarryOverEngine` expone una función unificada, `previewNextMonth(after: Period)`, que es la única fuente para ese dato en toda la app:
  - Si la quincena N+1 **ya está materializada** → devuelve su sobrante real ya calculado a partir de sus `LineItem` persistidas, incluyendo cualquier edición manual que tenga (no un valor teórico).
  - Si N+1 **no existe todavía** → devuelve el sobrante que tendría si se materializara ahora mismo, corriendo `ProjectionEngine` en memoria (recurrentes/suscripciones vigentes + carry-over de N) sin escribir nada en SwiftData — mismo mecanismo de cálculo-sin-persistir que usa Overview.
  - Ninguna vista debe reimplementar esta lógica por separado; toda lectura de "Next Month" pasa por `previewNextMonth`.

### Regla "la edición manual gana" — mecanismo

- Toda línea generada por `ProjectionEngine` (recurrente o suscripción) nace con `origin` correspondiente y `isManuallyEdited = false`.
- Cuando el usuario edita monto/moneda/título de esa línea, la UI marca `isManuallyEdited = true` antes de guardar.
- **Implementado como `PeriodCoordinator.reprojectRecurring/reprojectSubscription/reprojectLoan`** (`Core/PeriodCoordinator.swift`) — corrige lo que este documento decía antes (`ProjectionEngine.regenerate` solo actualizaba líneas ya existentes; nunca creaba una línea nueva en una `Period` que aún no tenía una para ese recurrente, que fue un bug real encontrado en diagnóstico). El comportamiento real, sobre **todas** las `Period` materializadas (no solo ≥ hoy):
  - `reprojectRecurring(item:)`: por cada `Period`, busca la línea con `sourceRecurringID == item.id`. Si existe y `isManuallyEdited == true` → no se toca. Si existe y `isManuallyEdited == false` → se actualiza, o se borra si el recurrente ya no genera línea ahí (inactivo/fuera de rango). Si no existe y el recurrente sí genera línea ahí → se **crea**.
  - `reprojectSubscription(kind:)`: mismo mecanismo pero para la línea combinada "Payments"/"Servicios", identificada por `origin == .subscription && isHomeService == (kind == .service)` — no hay `sourceRecurringID` porque la línea suma *todas* las suscripciones de ese `kind`, no una sola.
  - `reprojectLoan(item:)`: mismo mecanismo, keyed por `sourceLoanID`; además refresca `exchangeRateSnapshot` de la línea si el préstamo es en MXN.
  - Las tres terminan llamando `recomputeForward` desde el primer período tocado, y las tres se disparan al guardar (crear/editar) el `RecurringItem`/`Subscription`/`Loan` correspondiente.
- Periods futuras no materializadas nunca necesitan este paso: se generan directo con el valor vigente del recurrente en el momento de materializarse.

### Préstamos (Loans) — `LoanEngine`

- **Dirección determina el signo:** `.borrowed` (el usuario debe) genera `LineItem(kind: .expense, origin: .loan)`; `.lent` (el usuario prestó) genera `LineItem(kind: .income, origin: .loan)`. Es la única diferencia de cómo `ProjectionEngine`/coordinator interpretan un `Loan` frente a un `RecurringItem`.
- **Cálculo del pago fijo (amortización estándar, francesa):** `r` = tasa periódica (`apr/12` si `frequency == .monthly`, `apr/24` si `.biweekly`); `n` = número de pagos (derivado de `termMonths`/`endDate`, o de `paymentOverride` si el usuario lo fija). Pago = `P·r / (1 − (1+r)^−n)`; si `apr == 0` → pago = `P/n` (caso degenerado, sin división por cero de `r`).
- **`paymentOverride` recalcula `n`, no al revés:** si el usuario fija un pago distinto al calculado por `termMonths`, `LoanEngine` resuelve `n` numéricamente a partir de ese pago (no se le pide al usuario capturar `n` directamente) y `termMonths`/`endDate` se recalculan como derivados de ese `n`.
- **Desglose interés/capital y saldo:** `LoanEngine.schedule(for: loan)` es una función pura que devuelve el arreglo completo `[LoanInstallment]` (número de pago, interés, capital, saldo restante) de forma determinista a partir de `principal`, `apr`, `frequency`, `startDate` y `n` — nunca se persiste esta tabla, se recalcula cada vez que se necesita (misma filosofía que "qué se persiste vs. se calcula" del resto del modelo).
- **Redondeo:** cada pago se redondea a 2 decimales (`Decimal`, `.rounded(scale: 2, .plain)` o equivalente). El **último pago absorbe el ajuste de redondeo acumulado** para que el saldo cierre exactamente en `0` — nunca queda un remanente de centavos sin explicar.
- **Proyección a `LineItem`:** cada cuota vigente en una quincena se proyecta igual que un recurrente — por `frequency`, cayendo en la mitad 1–15 o 16–fin según el día — con `origin: .loan`, `sourceLoanID`, y respetando `isManuallyEdited` como cualquier otra línea generada.
- **Moneda:** si `Loan.currency == .mxn`, cada cuota generada usa el `exchangeRateSnapshot` de **esa quincena** (mismo mecanismo que cualquier otra línea en MXN) para su equivalente en USD en los totales — no hay un tipo de cambio fijo capturado al crear el préstamo; cada pago convierte al rate vigente (cache/override) de la quincena donde cae, igual que "Mandar".
- **Pre-release:** esta feature entra directo en `SchemaV1` — el proyecto no ha salido a producción, así que no aplica ninguna estrategia de migración (`VersionedSchema`/`SchemaMigrationPlan` se actualiza sin necesidad de `SchemaV2`).
- **Tests obligatorios (Bertrand), todos sobre `LoanEngine` puro sin SwiftData:**
  1. Caso Upstart-like: `principal = 20000`, `apr = 0.12`, `termMonths = 48`, mensual → pago calculado `526.68`.
  2. `apr = 0` → pago exacto `principal / n`, sin restos.
  3. Frecuencia `.biweekly` → usa `r = apr/24` y genera `n` cuotas quincenales, no mensuales.
  4. El último pago del schedule deja saldo `0` exacto (verifica el ajuste de redondeo, no solo que sea "cercano a 0").
  5. `paymentOverride` fijado → `LoanEngine` recalcula `n` consistente con ese pago (round-trip: recalcular el pago desde el `n` derivado debe reproducir el override, dentro de la tolerancia del redondeo a 2 decimales).

### Modo `.revolving` ("Hasta liquidar") — `LoanEngine.revolvingSchedule`

- **Firma:** `LoanEngine.revolvingSchedule(principal:apr:expectedPayment:frequency:start:actualPayments:[CivilDate: Decimal]) -> [RevolvingRow]`, tan pura y determinista como `schedule` (fecha en `CivilDate`, ver política de fechas de "Decisiones de Swift").
- **Interés:** mensual, sobre saldo, acumulado al cierre de cada **mes civil** (mecánica de tarjeta de crédito) — `interés = saldo × apr/12`, independiente de si la frecuencia de pago es mensual o quincenal.
- **Pago por período:** usa el pago **real** ya registrado (líneas `origin == .loan` con `sourceLoanID`, materializadas, `isActive`, editadas o no) cuando existe para ese período; si el período es futuro y no tiene línea real, usa `expectedPayment` como proyección. Un período mezclado (parte de la tabla con pagos reales, parte proyectada) es el caso normal, no una excepción.
- **Saldo:** `saldo_nuevo = saldo_anterior + interés_del_mes − pago_del_período`. Fin = **primer período con saldo ≤ 0**; ese último pago se ajusta hacia abajo para no dejar saldo negativo (mismo principio de ajuste que en `.fixedTerm`).
- **`neverEnds`:** si `expectedPayment ≤` el interés mensual del saldo inicial (el pago ni siquiera cubre el interés, el saldo nunca baja) → la función marca `neverEnds = true` y acota la proyección a **10 años** en vez de iterar indefinidamente (mismo principio de materialización acotada del resto del TRD — nunca proyección infinita).
- **`PeriodCoordinator.reprojectLoan` en modo revolving:** genera/actualiza la línea `.loan` de cada período con `expectedPayment` (no con la tabla `.fixedTerm`), respetando `isManuallyEdited`/`isActive` igual que siempre; a diferencia de `.fixedTerm`, **cualquier pago real registrado en cualquier quincena** (edición manual de esa línea) dispara un recálculo completo de `revolvingSchedule` hacia adelante — el saldo de todos los períodos posteriores depende del pago real más reciente, no solo de la línea que cambió.
- **Pantalla de detalle (`LoanDetailView`):** para `.revolving` muestra saldo actual, interés acumulado a la fecha, fecha de fin estimada (o "No liquida con este pago" si `neverEnds`), y tabla real vs. proyectado (qué períodos ya tienen pago real vs. cuáles siguen usando `expectedPayment`).
- **Tests obligatorios (Bertrand), sobre `LoanEngine.revolvingSchedule` puro:**
  1. Caso Ada: `principal = 824`, `apr = 0.262`, `expectedPayment = 200` quincenal → interés mes 1 ≈ `17.99`; verificar saldo tras 2 pagos y la fecha de fin proyectada.
  2. Registrar un pago real de `150` (en vez del esperado `200`) en una quincena ya materializada → `revolvingSchedule` recalcula el saldo de esa quincena en adelante con el pago real, no con `expectedPayment`.
  3. `expectedPayment` ≤ interés mensual del saldo inicial → `neverEnds == true`, proyección acotada a 10 años, no iteración infinita.
  4. Liquidación anticipada: un pago real mayor al saldo restante de ese período → el pago se ajusta al saldo exacto (nunca queda saldo negativo ni un pago "de más" sin explicar).

### Progreso de pago — decisión del usuario: solo avanza por confirmación manual, no por fecha programada

Cambio de comportamiento sobre el diseño anterior: `LoanDetailView.swift:24` calculaba `paidToDate = loan.principal − currentBalance`, con `currentBalance` derivado del schedule **por tiempo transcurrido** — avanzaba solo, sin que el usuario confirmara nada. Se reemplaza por:

- **`paidToDate`** = suma de `amount` de todas las `LineItem` con `sourceLoanID == loan.id && isPaid == true` (materializadas, cualquier quincena, pasada o futura si el usuario la marcó adelantada). Ya no se deriva del schedule por fecha.
- **`currentBalance`** (para mostrar) = `principal + interésAcumulado − paidToDate`, donde `interésAcumulado` sigue viniendo del schedule del modo correspondiente (`LoanEngine.schedule` en `.fixedTerm`, `LoanEngine.revolvingSchedule` en `.revolving`, evaluado hasta hoy) — lo único que cambia es qué resta: el pago **real confirmado**, no el pago que "debería" haberse hecho a la fecha.
- **"Fecha del último pago"** = `paidAt` de la `LineItem` con `isPaid == true` de mayor `paidAt` entre las de `sourceLoanID == loan.id`; `"—"` si no hay ninguna marcada.
- **Barra de progreso (`LoansView`, fila de la lista):** usa el mismo `paidToDate` real, no un valor derivado del schedule — misma fuente que el detalle, sin una segunda fórmula paralela.
- **Dónde se setea `paidAt`:** en el toggle de "pagado" que ya existe en `PeriodView.swift` para el swipe de la línea (marcar `isPaid = true` en cualquier `LineItem`, no solo las de préstamo) — al pasar a `true` se asigna `paidAt = CivilDate.today(calendar: .current)`; al pasar a `false` se limpia a `nil`. No es un mecanismo nuevo, es un campo adicional en el mismo toggle.
- **Consistencia con "Inversiones" — señalado, no aplicado:** "aportado a la fecha" en la pantalla de Inversiones tiene exactamente el mismo problema de fondo si se derivara del schedule proyectado en vez de líneas confirmadas; hoy ya está definido como "suma de `LineItem` materializadas" (no por fecha), así que estructuralmente ya sigue el mismo principio — la pregunta abierta es si también debería exigir `isPaid == true` (en vez de contar cualquier línea materializada, editada o no) para ser 100% consistente con esta decisión. **No se aplica ahora** — queda anotado para que el usuario decida si "aportado" debe requerir confirmación manual igual que "pagado" en préstamos, o si para inversiones basta con que la línea exista.
- **Tests obligatorios (Bertrand):**
  1. Marcar `isPaid = true` en la línea de un préstamo → la barra avanza y `paidAt` queda registrado con la fecha de hoy.
  2. Desmarcarla → la barra retrocede y `paidAt` vuelve a `nil`.
  3. Una línea futura de ese préstamo, aunque su quincena ya haya pasado, **no cuenta** en `paidToDate` mientras no se marque manualmente — el progreso no avanza solo por fecha programada.

### `isPaid == true` bloquea la línea — decisión del usuario

Cuando una `LineItem` tiene `isPaid == true` queda bloqueada: no se puede editar (monto/descripción), no se puede eliminar (manuales), no se puede desactivar (`isActive`, si aplica). La única acción disponible es desmarcar "pagado", que la desbloquea.

- **No es solo regla de UI — el guard vive en un solo punto reusable, no repetido por vista.** Ocultar/deshabilitar el botón es necesario para la experiencia, pero no es suficiente: las mutaciones (`deleteLine`, `toggleActive`, edición de monto/descripción) hoy viven como funciones privadas de `PeriodView.swift`, no en `PeriodCoordinator` — así que el guard no puede colgarse del coordinator por sí solo. Se agrega `PeriodCoordinator.canModify(line:) -> Bool` (`return !line.isPaid`), función pura sin `ModelContext`, y cada mutación (`deleteLine`, `toggleActive`, el commit de edición de monto/título en `PeriodView`) empieza con `guard PeriodCoordinator.canModify(line: line) else { return }` — la misma función alimenta también el `.disabled()`/ocultamiento de los botones. Un solo punto de verdad, nunca un `if isPaid` distinto por sitio.
- **`togglePaid` (el que marca/desmarca) es la única acción exenta del guard** — si no, nunca se podría desbloquear.
- **No afecta `reprojectRecurring/Subscription/Loan`:** confirmado contra el código actual (`Features/Period/PeriodView.swift:434-439`) — `togglePaid` ya marca `isManuallyEdited = true` en cualquier línea de origen generado (`origin != .manual`) al pasar `isPaid` a `true`, y `reproject*` ya salta toda línea con `isManuallyEdited == true` (`Core/PeriodCoordinator.swift:332/383/520`). Una línea manual pagada tampoco necesita nada nuevo: `reproject*` nunca toca `origin == .manual`. El bloqueo por `isPaid` es una regla adicional de "quién puede editar", no cambia a quién alcanza el reproject.
- **Tests obligatorios (Bertrand):** editar/eliminar/desactivar una línea con `isPaid == true` no tiene efecto (el estado no cambia); desmarcar `isPaid` la desbloquea y esas mismas acciones vuelven a funcionar normalmente.

---

## Decisiones de Swift

- **Target mínimo:** iOS 26 / macOS 26 — fijado por el PRD (Liquid Glass nativo); no hay razón para bajar el target y perder Liquid Glass o partes de Observation/SwiftData más recientes.
- **Swift Concurrency:** `ExchangeRateService` es un `actor` (única fuente mutable de estado de red + cache en memoria). El resto de la app opera en `MainActor` — SwiftData en este proyecto no necesita un `ModelActor` en background: el volumen de datos de un presupuesto personal (miles de filas en el peor caso a 10 años) es trivial para el `ModelContext` principal. Introducir un `ModelActor` de background sería over-engineering para este volumen (ver "Qué NO hacer").
- **Swift 6 strict concurrency:** activado desde día 1. `Core/Engine/*` son `Sendable` por diseño (structs sin estado mutable compartido). `@Model` de SwiftData no son `Sendable` — no cruzan fronteras de actor; todo acceso a `ModelContext` queda en `MainActor`.
- **`@Observable` vs `ObservableObject`:** `@Observable` en cualquier estado de UI que no sea `@Model` (p. ej. estado de "quincena actualmente visible" o selección de tab) — es el default de Swift 6/Observation y no requiere `ObservableObject`/`@Published`.
- **Moneda: `Decimal`, nunca `Double`.** Todos los montos (`amount`, `price`, `rate`, resultados de conversión y de `CarryOverEngine`) son `Decimal` de extremo a extremo, incluida la respuesta de la API de tipo de cambio (parseada a `Decimal` desde el string/number del JSON, nunca vía `Double`). Ningún cálculo financiero pasa por `Double` en ningún punto de la cadena.
- **Fechas: `CivilDate`, nunca `Date` crudo, en todo `Core/Engine`.** Bug de producción real encontrado (WALO no aparecía en Sep 1–15 y salía duplicado en Sep 16–30; servicio día 12 ausente; "próximo pago" de un préstamo día 20 mostraba día 19) — causa: `PeriodDateEngine.dateRange`/`date(forDayOfMonth:)` y `LoanEngine` (`schedule`, `installmentDate`, `termMonths`, `endDate`) construyen límites a medianoche **UTC** (`Calendar.gregorianUTC`), mientras que `RecurringItem`/`Subscription`/`Loan.startDate`/`endDate` llegan de un `DatePicker` como medianoche **local** sin normalizar; `ProjectionEngine.isVigente` (`Core/Engine/ProjectionEngine.swift:121-130`) compara esos `Date` crudos directamente. En cualquier zona UTC−N el desfase corre la clasificación un día y, cerca de un borde de quincena, hace que un recurrente/préstamo se evalúe vigente en dos quincenas (el duplicado) o en ninguna. Superaba la sección "Calendario y zona horaria" de arriba, que documentaba el mix `gregorianUTC`/`Calendar.current` como solución — esa solución resultó insuficiente porque el mix persistía dentro de `ProjectionEngine`/`LoanEngine`.
  - **Política única del proyecto:** se introduce `struct CivilDate` (`Codable`, `Comparable`, `Hashable`; año/mes/día, sin hora ni zona) en `Core/Engine/CivilDate.swift`. Todo cálculo de calendario dentro de `Core/Engine` (límites de quincena, vigencia de recurrentes/suscripciones/préstamos, tabla de amortización, día de pago) opera en `CivilDate`, nunca en `Date`. `Date` solo existe en la frontera de UI: un `DatePicker` se normaliza a `CivilDate` vía `Calendar.current.dateComponents([.year,.month,.day], from:)` en el momento de guardar, y se reconstruye a `Date` (medianoche local, `Calendar.current`) solo para alimentar el propio `DatePicker` o un formatter de despliegue. Nunca se compara un `Date` crudo contra otro en lógica de negocio.
  - **Sitios exactos a cambiar (Woz):** `Core/Engine/PeriodDateEngine.swift` (`dateRange`, `coordinate(containing:)`, `date(forDayOfMonth:)` → entrada/salida `CivilDate`); `Core/Engine/EngineTypes.swift` (`RecurringItemSnapshot`/`SubscriptionSnapshot`/`LoanSnapshot`: `startDate`/`endDate` de `Date` a `CivilDate`); `Core/Engine/ProjectionEngine.swift` (`isVigente`, ambas variantes); `Core/Engine/LoanEngine.swift` (`schedule`, `installmentDate`, `termMonths`, `endDate` — aritmética de meses/quincenas sobre `CivilDate`, no `Calendar.current`/`gregorianUTC` sobre `Date`); `Core/Models/RecurringItem.swift`, `Subscription.swift`, `Loan.swift` (mantienen `startDate`/`endDate: Date` como columna SwiftData — no soporta `CivilDate` nativo — pero exponen un accessor `civilStartDate`/`civilEndDate` que normaliza en el getter/setter); cada `DatePicker(selection:)` en `Features/Recurring/RecurringView.swift`, `Features/Subscriptions/SubscriptionsView.swift`, `Features/Loans/LoansView.swift` (o sus sheets de edición) — normalizar el `Date` recibido antes de asignarlo al modelo; `LoanDetailView` "próximo pago" — leer la fecha vía el `LoanEngine` ya migrado a `CivilDate`, formatear con `Calendar.current` solo al mostrar.
  - **Tests obligatorios (Bertrand), con `TimeZone` fijada a `America/Mexico_City` y repetidos con `UTC`:** WALO (`.biweekly`, inicio civil 1 sep) aparece exactamente una vez en Sep 1–15, no en Ago 16–30 ni duplicado en Sep 16–30; servicio Luz día 12 aparece en Sep 1–15; préstamo día 20 mensual → "próximo pago" = 20 de septiembre, no 19; **idempotencia de `reproject*`** — llamarlo dos veces seguidas sobre el mismo `RecurringItem`/`Subscription`/`Loan` no duplica `LineItem` (el conteo de líneas con ese `sourceRecurringID`/`sourceLoanID` en cada `Period` es 1 antes y después de la segunda llamada); los cuatro casos deben dar el mismo resultado bajo ambas zonas horarias (prueba de que el resultado ya no depende de la zona del dispositivo).

---

## SwiftData — CloudKit

### Opción elegida

**SwiftData + CloudKit (`.automatic`)** — app personal, datos privados de un solo usuario, sin colaboración. No se justifica `CKContainer` manual ni CloudKit compartido (ninguno de los casos de "control granular" o "colaboración entre usuarios" de la tabla de decisión aplica aquí).

```swift
ModelContainer(
    for: Period.self, LineItem.self, RecurringItem.self, Subscription.self, Loan.self, ExchangeRateCache.self,
    configurations: ModelConfiguration(cloudKitDatabase: .automatic)
)
```

Entitlements:
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array><string>iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)</string></array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

### Limitaciones de SwiftData + CloudKit que ya están reflejadas en el modelo de datos

- **Sin `@Attribute(.unique)`** — ninguna entidad lo usa; `id: UUID` es único por convención de la app, no forzado por el store.
- **Todas las relaciones son opcionales** — `Period.lineItems: [LineItem]?` y `LineItem.period: Period?` ya están declaradas opcionales por esta razón, no por elección de diseño.
- **Sin `isStoredInMemoryOnly` con cloud** — no aplica; no hay necesidad de store en memoria en este proyecto (los tests de `Core/Engine` corren sin SwiftData, ver Setup inicial).
- **Conflictos: last-write-wins**, sin merge manual — aceptable para un solo usuario en dos dispositivos propios; no hay edición concurrente real esperada.

### Sync y offline

- Fuente de verdad local: SwiftData (funcional 100% offline, incluida la materialización de nuevas quincenas y el recálculo de encadenado).
- Sync: CloudKit automático cuando hay red — nunca bloqueante, nunca se espera sync para completar una acción del usuario.
- Conflictos: last-write-wins (default SwiftData + CloudKit).
- Estado de sync: no expuesto en UI.
- Tipo de cambio: el fetch de red es independiente del sync de CloudKit — si no hay red, se usa `ExchangeRateCache` (última fila persistida, que sí sincroniza vía CloudKit) o el override manual.

---

## Migración de schema

- Versión actual: `SchemaV1`
- Cambios en esta versión: se agrega `Loan` (y `sourceLoanID`/`.loan` en `LineItem`) directo a `SchemaV1` — el proyecto es **pre-release** (sin datos de usuario en producción), así que no se abre `SchemaV2` ni se escribe migración para este cambio; se edita `SchemaV1` en sitio.
- **Modo `.revolving` de `Loan` (`mode`, `expectedPayment`, `termMonths`/`endDate` ahora opcionales) → `SchemaV2` en sitio:** sigue siendo pre-release, así que no hace falta `MigrationStage` real, pero el cambio se declara como `SchemaV2` (no otro edit silencioso de V1) para dejar el checkpoint correcto antes de que el proyecto salga de pre-release — desde ese punto sí aplicará la regla estándar de migración explícita.
- **Feature "Inversiones" (`RecurringItem.category`, `accountName`) → Lightweight, dentro de `SchemaV2` vigente:** son propiedades nuevas con default (`category = .general`, `accountName = nil`) sobre una entidad existente — cae directo en la fila "Agregar propiedad con default → Lightweight, automática" de la tabla de migración de este documento. No amerita `SchemaV3` ni plan de migración custom.
- Estrategia: se adopta el patrón `VersionedSchema` + `SchemaMigrationPlan` **desde el día 1**, aunque V1 no tenga nada que migrar todavía. Es más barato empezar con el patrón correcto que retrofit-earlo cuando ya haya datos de usuario en producción. Esta regla de "editar V1 en sitio mientras sea pre-release" deja de aplicar en cuanto haya un build de producción con datos reales — desde ese punto, cualquier cambio de schema (incluido uno igual de simple) exige `SchemaV2` + migración real.
- Plan: `Fintrol/Core/Migration/SchemaV1.swift` + `AppMigrationPlan.swift` (stage list vacía por ahora, lista para `MigrationStage.lightweight`/`.custom` en V2).
- Prueba requerida: no aplica todavía (no hay V0). Bertrand deja un test placeholder que verifica que `ModelContainer` abre limpio con `SchemaV1`.

---

## Integraciones externas y seguridad

### Inventario y privilegios

| Integración | Datos que entran/salen | Credencial y almacenamiento | Scopes/capacidades | Endpoints necesarios | Acceso (read/write) | Cuenta/rol mínimo |
|-------------|-------------------------|-----------------------------|--------------------|----------------------|---------------------|---------------------|
| Banxico SIE (serie SF43718, FIX USD/MXN) | Sale: header `Bmx-Token` (token del usuario, ver Handoff). Sin otro parámetro de usuario, sin PII en el request. Entra: `{bmx: {series: [{datos: [{fecha: "dd/MM/yyyy", dato: "<string>"}]}]}}` — `dato` puede venir `"N/E"` en día inhábil | Token de Banxico introducido por el usuario en Ajustes → Preferencias; **nunca en código, `Info.plist` ni repo**. Almacenamiento: decisión pendiente de Ivan (ver Handoff) | N/A (token de consulta pública de SIE, sin scopes) | `GET https://www.banxico.org.mx/SieAPIRest/service/v1/series/SF43718/datos/oportuno` | Read-only | N/A |

**Decisión de proveedor — Banxico SIE (serie `SF43718`, FIX USD/MXN):**
- Reemplaza a Frankfurter — decisión explícita del usuario. Frankfurter se elimina por completo, **no queda como segundo proveedor ni como fallback**.
- Fuente oficial del tipo de cambio FIX que el propio usuario ya usaba como referencia en la hoja de cálculo — más autoritativa que un agregador de terceros.
- Requiere `Bmx-Token` en el header de cada request — es la única integración del proyecto con credencial, y por eso el token vive fuera del repo (input del usuario en Ajustes, nunca hardcodeado ni en `Info.plist`).
- **1 request/día máximo** — el fetch se dispara al abrir la app o en refresh manual, nunca en polling; `ExchangeRateService` descarta un segundo fetch si ya hubo uno exitoso ese mismo día calendario (se compara contra `ExchangeRateCache.date`).
- **Cliente:** `URLSession` GET con header `Bmx-Token: <token>`. Parseo defensivo a `Decimal` desde `bmx.series[0].datos[0].dato` (string) — nunca vía `Double`; igual que con Frankfurter, se valida rango **1–100** (un FIX USD/MXN fuera de ese rango se trata como respuesta inválida, no se acepta).
- **`dato == "N/E"` (día inhábil):** no es un error de red ni de token — es una respuesta válida sin dato del día. Se trata igual que un fetch fallido para efectos de fallback: se conserva el último valor válido de `ExchangeRateCache` (no se sobreescribe con "N/E", no se marca error).
- **Fallback en cascada** (cumple el riesgo del PRD "la API puede caerse o cambiar de contrato"), en este orden:
  1. Token presente y válido, fetch exitoso, `dato` numérico en rango 1–100 → actualiza `ExchangeRateCache` y se usa.
  2. Token ausente, token inválido (401/403), `dato == "N/E"`, error de red, o parseo fuera de rango → se usa la última fila de `ExchangeRateCache` (puede tener días de antigüedad; la UI no lo oculta pero tampoco bloquea nada).
  3. Si el usuario definió `Period.manualExchangeRateOverride` para la quincena activa → ese valor gana sobre cache y sobre API, siempre — este escalón no cambia.
- No se agrega un segundo proveedor como fallback de red: cache + override manual ya cubren el riesgo real según el propio PRD, igual que con la decisión anterior.

### Ciclo de vida y respuesta

- **Alta/autorización:** el usuario obtiene su propio token de Banxico SIE y lo captura en Ajustes → Preferencias; la app no lo solicita ni lo transmite a ningún destino salvo el header `Bmx-Token` de este único endpoint.
- **Rotación/expiración:** si Banxico invalida el token (401/403), cae al fallback (cache/override) y Ajustes debe mostrar que el token dejó de funcionar para que el usuario lo reemplace a mano — no hay refresh automático.
- **Desconexión:** el usuario puede borrar el token desde Ajustes en cualquier momento; al borrarlo la app vuelve a cache/override sin degradar el resto de la app.
- **Kill switch:** si el endpoint deja de responder de forma permanente, la app sigue funcionando indefinidamente con cache + override manual (no es una dependencia dura del core loop).
- **Logs y datos sensibles:** no loguear montos, `rate`, el token, ni contenido de `LineItem`/`RecurringItem` en claro fuera de debug builds. El token nunca se imprime, ni siquiera enmascarado, en logs de producción.

### Handoff de seguridad

- **Superficie sensible:** sí — datos financieros personales (Tier 2 del PRD) persistidos en CloudKit privado, más una llamada de red **con credencial** (el token de Banxico) — esto es nuevo respecto a la versión anterior de este documento, que no tenía ninguna credencial en el proyecto.
- **Decisión pendiente que Ivan debe resolver — almacenamiento del token de Banxico:** `SECURITY.md` §6.1 declara Keychain como N/A/prohibido para este proyecto porque hasta ahora no había ningún secreto que justificarlo. El token de Banxico rompe esa premisa: es la primera credencial real del proyecto. Ivan debe decidir explícitamente dónde vive (Keychain reabierto solo para este caso vs. otra alternativa) y actualizar `SECURITY.md` en consecuencia — Avie no toma esta decisión por él. Hasta que Ivan resuelva esto, Woz **no** implementa la persistencia del token, solo el campo de captura en Ajustes con el valor en memoria.
- **Decisiones adicionales que Ivan debe modelar en `SECURITY.md`:**
  - Confirmar postura de ATS (HTTPS-only, sin excepciones) para `www.banxico.org.mx`.
  - Validar que la app no expone estado de sync/errores de red, ni el token, con detalle que revele datos financieros o la credencial en logs de sistema o crash reports.
  - Revisar entitlements de iCloud (contenedor privado, sin App Groups ni helpers — no hay ninguno en este diseño).
  - Confirmar que Data Protection por defecto de iOS/macOS es suficiente para los `@Model` (no se requiere encriptación adicional a nivel de campo para v1 — es un juicio de Ivan, no de Avie).
  - Threat model mínimo de la superficie de red: respuesta JSON inesperada/maliciosa del endpoint, `dato` fuera de rango o `"N/E"`, y manejo de un token inválido/expirado — el parser debe fallar cerrado (fallback a cache) ante cualquiera de estos casos, nunca crashear ni loguear el payload crudo ni el token.
- **`SECURITY.md`:** existe en el repo; Ivan debe actualizarlo con la decisión de almacenamiento del token antes de que Woz la implemente.
- **Restricciones vinculantes para Woz:** conversión de moneda siempre en `Decimal`; parseo de la respuesta de Banxico debe ser defensivo (fallback a cache ante error de decode, token inválido, o `"N/E"`, nunca `try!`); el token nunca se hardcodea ni va en `Info.plist`/repo — captura en Ajustes → Preferencias; no implementar persistencia del token hasta que Ivan defina el mecanismo.

---

## Riesgos técnicos

- **API de tipo de cambio (Banxico SIE) puede caerse, cambiar de contrato, devolver `"N/E"` en día inhábil, o el token puede faltar/expirar** — mitigado por cache persistente + override manual (ver Integraciones); todos estos casos colapsan al mismo fallback. El parser de la respuesta debe fallar cerrado, no crashear.
- **El token de Banxico es la primera credencial real del proyecto y `SECURITY.md` prohibía Keychain** — Ivan debe decidir el mecanismo de almacenamiento antes de implementar la persistencia (ver Handoff de seguridad); Woz no la construye hasta esa decisión.
- **Recálculo en cascada del encadenado puede volverse costoso** — mitigado con recálculo incremental con fixed-point (`CarryOverEngine.recomputeForward`, ver Modelo de datos), acotado a quincenas ya materializadas, no a la proyección completa.
- **Proyección infinita hacia adelante para recurrentes sin fecha fin** — mitigado con materialización perezosa: nunca se persisten quincenas no visitadas; Overview calcula en memoria sin escribir en el store.
- **Regla "edición manual gana" mal implementada pierde ediciones del usuario silenciosamente** — mitigado con la bandera explícita `isManuallyEdited` por línea (no una heurística de diff) y un test de Bertrand que cubre exactamente el criterio de aceptación del PRD (cambiar el recurrente no debe tocar una línea ya editada a mano).
- **CloudKit last-write-wins puede pisar una edición si el usuario edita casi simultáneamente en iPhone y Mac** — riesgo aceptado explícitamente: es un solo usuario, la ventana de conflicto real es mínima, y añadir merge manual sería over-engineering para este caso de uso (ver PRD, sin este riesgo marcado como bloqueante).

---

## Qué NO hacer

- No usar `Double` para ningún monto o tipo de cambio — errores de redondeo en dinero son inaceptables; `Decimal` en toda la cadena.
- No crear un `ModelActor` en background para SwiftData — el volumen de datos de un presupuesto personal no lo justifica; añade complejidad de concurrencia sin beneficio medible.
- No materializar quincenas futuras "por si acaso" (ni al abrir la app, ni en background) — rompe el requisito de almacenamiento acotado; Overview y proyecciones a años se calculan en memoria, nunca se persisten hasta que el usuario navega ahí.
- No modelar los préstamos (Upstart) ni "Ada" como entidades especiales — son `RecurringItem` genéricos con fecha de fin, ya decidido en el PRD.
- No agregar un segundo proveedor de tipo de cambio como fallback de red — cache + override manual ya resuelve el riesgo real; una segunda integración es superficie extra sin beneficio proporcional. Frankfurter queda eliminado, no se conserva como respaldo.
- No hardcodear el token de Banxico en código, `Info.plist`, `project.yml` ni ningún archivo del repo — es input del usuario en Ajustes → Preferencias.
- No implementar la persistencia del token antes de que Ivan defina el mecanismo de almacenamiento en `SECURITY.md`.
- No usar TCA ni un ViewModel por pantalla — la complejidad real del proyecto está en el dominio (`Core/Engine`), no en la presentación; MV + engines la cubre sin boilerplate.
- No implementar el switch "cuenta/no cuenta" ni tarjetas de crédito/Goals — explícitamente fuera del MVP por el PRD.

---

## Setup inicial

1. Crear `project.yml` (XcodeGen) con un solo target multiplataforma `Fintrol` (iOS 26 + macOS 26 deployment target), target de tests `FintrolTests` (Swift Testing, no XCTest) y el paquete local `AppleAppLabUI` como dependencia (ver bloque YAML en Stack técnico).
2. Generar el proyecto con `xcodegen generate`.
3. Crear `Core/Models/` con las 5 entidades `@Model` de este documento, todas con relaciones opcionales (requisito CloudKit).
4. Crear `Core/Migration/SchemaV1.swift` + `AppMigrationPlan.swift` desde el día 1, aunque el plan de migración esté vacío.
5. Configurar `ModelContainer` en `FintrolApp.swift` con `ModelConfiguration(cloudKitDatabase: .automatic)` y agregar los entitlements de iCloud (ver bloque en SwiftData — CloudKit).
6. Implementar `Core/Engine/PeriodDateEngine.swift` primero y con tests — todo lo demás depende de que la generación de fechas de quincena sea determinista y correcta.
7. Implementar `Core/Engine/ProjectionEngine.swift`, `CarryOverEngine.swift`, `CurrencyConversion.swift` como structs `Sendable` puros, sin importar SwiftData — Bertrand los testea sin `ModelContainer`.
8. Implementar `Services/ExchangeRateService.swift` como `actor`, contra Banxico SIE (serie `SF43718`), con el fallback en cascada (token+API → cache → override manual), parseo defensivo a `Decimal` con rango 1–100, manejo de `"N/E"` como no-fetch, y límite de 1 request/día. La captura del token vive en Ajustes → Preferencias; su persistencia queda bloqueada hasta que Ivan defina el mecanismo en `SECURITY.md`.
9. Entregar este `TRD.md` a Ivan para `SECURITY.md` antes de que Woz construya las pantallas que escriben datos financieros.
10. Construir pantallas en `Features/` reutilizando `AppleAppLabUI` (`LabList`, `LabToggleRow` para el switch "pagado", `LabTextField`, `LabCard`) — cualquier componente de dominio (fila de línea con moneda, badge de sobrante con color) que no exista en el catálogo se documenta en `PROJECT_LEARNINGS.md` como candidato a generalizarse.

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-09-15 | Patrón MV + capa de Engines de dominio en `Core/Engine/`, no MVVM ni TCA | La complejidad real es de cálculo financiero, no de presentación; Views leen SwiftData directo, los engines son testables sin UI |
| 2026-09-15 | Proveedor de tipo de cambio: Frankfurter (`api.frankfurter.app`) | *(Superseded — ver siguiente fila)* |
| 2026-09-15 | Proveedor de tipo de cambio cambia de Frankfurter a Banxico SIE (serie `SF43718`, FIX USD/MXN), con `Bmx-Token`; Frankfurter se elimina, no queda como segundo proveedor | Decisión explícita del usuario — fuente oficial que el usuario ya usaba como referencia; token capturado en Ajustes, nunca en código/repo |
| 2026-09-15 | Sin segundo proveedor de fallback de red | Cache persistente + override manual ya cubren el riesgo del PRD sin sumar superficie de integración |
| 2026-09-15 | 1 request/día máximo a Banxico SIE, `"N/E"` (día inhábil) tratado como no-fetch, rango de validación 1–100 igual que con Frankfurter | Evita exceder el uso justo del servicio y mantiene el mismo parseo defensivo ya probado |
| 2026-09-15 | Almacenamiento del token de Banxico queda pendiente de decisión de Ivan (Keychain estaba prohibido en `SECURITY.md` por no haber credenciales hasta ahora) | Es la primera credencial real del proyecto; Avie no decide almacenamiento de secretos por su cuenta |
| 2026-09-15 | Nueva feature v1 "Préstamos" (`Loan`): amortización francesa estándar, `paymentOverride` recalcula `n`, proyección como `LineItem(origin: .loan)` vía `reprojectLoan` simétrico a recurrentes/suscripciones | Decisión explícita del usuario — unifica préstamos (antes modelados como `RecurringItem` genérico) en una entidad con cálculo financiero propio |
| 2026-09-15 | `Loan` entra directo a `SchemaV1` sin migración — proyecto pre-release | No hay datos de usuario en producción; abrir `SchemaV2` para esto sería costo sin beneficio |
| 2026-09-15 | Último pago de `LoanEngine.schedule` absorbe el ajuste de redondeo para que el saldo cierre en `0` exacto | Evita centavos residuales sin explicar al final del plazo |
| 2026-09-15 | Sincronización TRD↔código: `Subscription.kind` (`.subscription`/`.service`) modela también "Servicios del hogar" reutilizando la misma entidad — no estaba documentado y no está en el PRD | Decisión de implementación de Woz (`DESIGN_LIQUID.md`), no de producto; queda señalada como pendiente de confirmar con Scott, no acomodada silenciosamente |
| 2026-09-15 | `reprojectRecurring/Subscription/Loan` reemplaza la descripción previa de `ProjectionEngine.regenerate` — ahora también **crea** líneas faltantes en períodos ya materializados, no solo actualiza las existentes | Corrige un bug real encontrado en diagnóstico: crear un recurrente nuevo no aparecía en quincenas ya visitadas |
| 2026-09-15 | `coordinate(containing:)` usa `Calendar.current` (local) para "hoy"; `dateRange`/`date(forDayOfMonth:)` siguen en `Calendar.gregorianUTC`; los formatters de título fijan `Date.FormatStyle(timeZone: UTC)` | Corrige el bug de producción donde la app abría en el mes anterior en zonas horarias UTC−N |
| 2026-09-15 | `Loan.mode`: se agrega `.revolving` ("Hasta liquidar") junto a `.fixedTerm`, con `expectedPayment` y `termMonths`/`endDate` opcionales; `LoanEngine.revolvingSchedule` calcula interés mensual sobre saldo tipo tarjeta, mezcla pagos reales con `expectedPayment` proyectado, y detecta `neverEnds` acotando a 10 años | Decisión explícita del usuario — cubre deuda sin plazo fijo (ej. "Ada") que `.fixedTerm` no modelaba |
| 2026-09-15 | El cambio de `.revolving` se versiona como `SchemaV2` (en sitio, sin migración real por ser pre-release) en vez de seguir editando `SchemaV1` | Deja un checkpoint de versión correcto antes de que el proyecto salga de pre-release |
| 2026-09-15 | Feature "Inversiones" (aportaciones recurrentes): se reutiliza `RecurringItem` con `category = .investment` + `accountName`, origen de línea `.investment`, sin entidad ni motor de reproyección nuevos | Decisión explícita del usuario — estructuralmente idéntico a un recurrente; una entidad `Investment` aparte solo duplicaría `reprojectRecurring` sin beneficio |
| 2026-09-15 | Campos de "Inversiones" entran como Lightweight dentro de `SchemaV2`, sin `SchemaV3` | Son propiedades nuevas con default sobre una entidad existente — caso trivial de la tabla de migración |
| 2026-09-16 | `LineItem.paidAt: CivilDate?`; progreso de préstamos (`paidToDate`, `currentBalance`, "fecha del último pago") pasa de derivarse del schedule por fecha programada a derivarse de líneas con `isPaid == true` confirmadas por el usuario | Decisión explícita del usuario — el progreso solo debe avanzar por confirmación manual (swipe "pagado"), nunca solo por haber llegado la fecha |
| 2026-09-16 | Consistencia de "aportado a la fecha" (Inversiones) con esta misma regla: señalada como pregunta abierta para el usuario, no aplicada todavía | Evita tocar Inversiones sin decisión explícita, aunque el problema de fondo sea el mismo |
| 2026-09-16 | Límite histórico de navegación deja de ser un piso único; se agrega un techo configurable ("meses hacia atrás visibles", `@AppStorage`, default 1) — gana el más restrictivo entre piso (primera materializada) y techo (N meses civiles atrás desde hoy) | Decisión explícita del usuario — límite de navegación, no de datos: cambiar `N` nunca borra ni rematerializa nada |
| 2026-09-16 | `LineItem.isPaid == true` bloquea edición/borrado/desactivación; guard centralizado en `PeriodCoordinator.canModify(line:)`, no repetido por vista; `togglePaid` es la única acción exenta | Decisión explícita del usuario — ocultar el botón no basta, el guard debe ser robusto a cualquier ruta de mutación |
| 2026-09-15 | Materialización perezosa de quincenas — nunca se generan 240 registros de golpe | Requisito explícito del PRD (riesgo de "proyección infinita"); Overview calcula en memoria |
| 2026-09-15 | Recálculo de encadenado incremental con fixed-point, no recálculo completo | Acota el costo a quincenas materializadas realmente afectadas |
| 2026-09-15 | Regla "edición manual gana" implementada con bandera explícita `isManuallyEdited` por línea | Evita heurísticas de diff frágiles; mapea 1:1 al criterio de aceptación del PRD |
| 2026-09-15 | `Decimal` en toda la cadena de dinero, nunca `Double` | Estándar no negociable del equipo para cualquier cálculo financiero |
| 2026-09-15 | SwiftData + CloudKit `.automatic`, sin `CKContainer` manual | Un solo usuario, sin colaboración — no se justifica complejidad adicional |
| 2026-09-15 | Sin `ModelActor` de background | Volumen de datos de un presupuesto personal es trivial para `MainActor` |
| 2026-09-15 | `VersionedSchema` + `SchemaMigrationPlan` desde V1 aunque no haya nada que migrar todavía | Más barato adoptar el patrón desde el inicio que retrofit-earlo con datos de usuario en producción |
| 2026-09-15 | "Next Month" se resuelve con una función unificada `CarryOverEngine.previewNextMonth` (real si está materializada, proyectada si no) | Decisión explícita del usuario — evita dos implementaciones divergentes del mismo dato |
| 2026-09-15 | No existen quincenas anteriores a la primera materializada; `PeriodDateEngine` no genera períodos hacia atrás | Decisión explícita del usuario — la app arranca desde el punto de uso real, no proyecta pasado |
