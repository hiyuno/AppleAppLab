# PRD — Fintrol

> Última actualización: 2026-09-15. Versión: 1.1
> Todo lo que no está aquí no está definido.

---

## Resumen

**One-liner:** Fintrol es tu presupuesto quincenal — sabes exactamente cuánto entra, cuánto sale y cuánto te sobra, quincena tras quincena, proyectado a años.

**El problema:** El usuario lleva su presupuesto desde 2022 en una hoja de cálculo (`Mis Finanzas 2.0.xlsx`) que replica su ciclo de pago quincenal: dos cortes al mes, sobrante que se arrastra de una quincena a la siguiente, conversión MXN↔USD porque parte de sus gastos son en pesos, y varios ingresos/egresos recurrentes con fecha de fin (un préstamo a 4 años, dinero que le presta a su hermana). Mantener esto a mano en Excel es tedioso: hay que copiar fórmulas, arrastrar el sobrante manualmente, sumar suscripciones por fecha de pago, y no hay forma fácil de proyectar "¿cómo se ve mi presupuesto en 10 años si tengo este préstamo a 5?".

**Usuario objetivo:** El propio usuario — un profesional que recibe sueldo quincenal, tiene ingresos variables, envía dinero a México regularmente, paga un préstamo personal a plazo fijo, y quiere ver su presupuesto proyectado hacia el futuro sin tocar una hoja de cálculo. V1 es de un solo usuario, sin cuentas ni compartir — sync solo vía iCloud privado del propio usuario.

---

## Plataforma y distribución

- **Plataforma:** iOS y macOS (app nativa, UI compartida donde tenga sentido, adaptada a cada idioma de plataforma)
- **Versión mínima:** iOS 26 / macOS 26 — Liquid Glass nativo
- **Distribución:** personal por ahora — TestFlight o instalación directa, sin App Store público (Tier 2 de seguridad — datos financieros personales + llamada a API externa de tipo de cambio, sin autenticación de terceros). Sin Phil ni Kate en v1. Abrir a App Store público queda como posible fase futura, no decidida.
- **Sync:** iCloud privado (CloudKit, solo el usuario, sin compartir ni cuentas multiusuario)
- **Monetización:** Ninguna en v1 — app personal, sin distribución comercial planeada. No aplica StoreKit.

---

## Stack preferido

- **Framework:** SwiftUI (decisión de Avie en fase de arquitectura — no la resuelve este documento)
- **Bundle ID base:** por definir con el usuario
- **Team ID Apple Developer:** por definir con el usuario

---

## Modelo de datos y reglas de negocio (fuente de verdad de comportamiento)

Esta sección traduce el comportamiento de la hoja de cálculo actual a reglas explícitas. Es lo que Avie debe respetar en el modelo de datos y lo que Jonny debe respetar en cada pantalla.

### Quincenas

- Una **quincena** es la unidad atómica de la app. Hay dos por mes calendario:
  - **Quincena del 15**: cubre pagos/cargos ocurridos del día 1 al 15.
  - **Quincena de fin de mes**: cubre pagos/cargos del 16 al último día del mes (28/29/30/31 según el mes).
- Las fechas de corte se generan automáticamente sin intervención del usuario (equivalente a la lógica `EOMONTH` + 15 días de la hoja actual). El usuario nunca captura fechas de quincena a mano.
- Cada quincena es **una sola pantalla completa** (requisito explícito del usuario, replicando el layout de los screenshots de referencia).
- **Límite de navegación hacia atrás:** configurable en Ajustes → Preferencias ("Historial visible"), en **meses** hacia atrás desde la quincena actual, default **1 mes**, rango 1–24. El chevron "atrás" se deshabilita al llegar al límite. **Piso adicional, no configurable:** nunca se puede navegar antes de la primera quincena que exista en la app (la primera materializada) — el setting nunca permite ver más atrás de ese piso, aunque el número de meses configurado sea mayor.

### Líneas de INCOME y EXPENSES

- Cada quincena tiene dos listas independientes: **INCOME** (ingresos) y **EXPENSES** (egresos).
- Cada línea tiene: descripción (texto libre), monto, moneda (USD por defecto, MXN opcional) y dos estados que se controlan con un **swipe** (no switches separados), persistidos por línea y sincronizados por iCloud:
  - **Swipe izquierda→derecha — "cuenta / no cuenta"** (equivalente al IF de la hoja): alterna entre activa e inactiva. Inactiva se muestra semitransparente y **no** suma en TOTAL INCOME/EXPENSES, sobrante ni en el encadenado a la siguiente quincena. La línea no se borra — sigue visible y se puede reactivar en cualquier momento.
  - **Swipe derecha→izquierda — "pagado/recibido"**: marca/desmarca una palomita discreta. Es puramente visual y **no afecta ningún cálculo** — cuenta siempre en los totales igual, esté marcada o no.

### Totales y sobrante

- **TOTAL INCOME** = suma de montos (convertidos a USD) de todas las líneas de INCOME con estado "cuenta" activo.
- **TOTAL EXPENSES** = suma de montos (convertidos a USD) de todas las líneas de EXPENSES con estado "cuenta" activo.
- **Sobrante** = TOTAL INCOME − TOTAL EXPENSES. Se muestra en tamaño grande con código de color, umbral fijo en v1:
  - Verde: sobrante ≥ $100.
  - Amarillo: sobrante entre $0 y $99.99.
  - Rojo: sobrante < $0.
- *Criterios de aceptación:* desactivar (swipe) la línea WALO en la quincena del 1–15 de septiembre reduce TOTAL INCOME de esa quincena y reduce el "Latest Month" encadenado en la quincena del 16–30 en el mismo monto; reactivarla restaura ambos valores exactamente. Marcar/desmarcar "pagado" en cualquier línea no cambia TOTAL INCOME, TOTAL EXPENSES, sobrante ni ningún encadenado.

### Encadenado quincena a quincena

- El sobrante de la quincena N se inserta automáticamente como la **primera línea de INCOME** ("Latest Month") de la quincena N+1.
- Este encadenado es automático y continuo hacia adelante en toda la proyección — no solo a la siguiente quincena, sino a todas las quincenas futuras generadas.
- Cada quincena también muestra, informativamente, **"Next Month"**: el sobrante previsto de la quincena siguiente dado el estado actual (útil para ver el impacto de un cambio antes de que ocurra).
- Si el usuario edita una línea en una quincena pasada o presente, el encadenado debe recalcular hacia adelante todas las quincenas futuras que dependen de ese sobrante.

### Moneda y conversión MXN↔USD

- Moneda base de la app: **USD**.
- Cualquier línea (INCOME o EXPENSES) puede capturarse en MXN.
- El tipo de cambio del día se obtiene automáticamente de una API externa (sin autenticación) al abrir/refrescar la app, y es **editable a mano** por el usuario (override manual que persiste para esa quincena/línea).
- Conversión: monto_MXN ÷ tipo_de_cambio = monto_USD equivalente, usado en los totales.
- **"Mandar"**: cada quincena muestra "Mandar: $X USD" = suma de las líneas de EXPENSES en MXN ÷ tipo de cambio del día — el monto que el usuario debe enviar a México para cubrir esos gastos.

### Recurrencia y proyección multi-año

- Requisito clave del usuario: poder ver el presupuesto proyectado años hacia adelante, incluyendo el efecto de préstamos/ingresos con fecha de fin conocida.
- Cada **ítem recurrente** (ingreso o egreso) define:
  - Tipo: ingreso o egreso
  - Monto
  - Moneda (USD o MXN)
  - Frecuencia: cada quincena / mensual en día X / una sola vez
  - Fecha de inicio
  - Fecha de fin (opcional — si no se define, se proyecta indefinidamente)
- La app **genera automáticamente** la línea correspondiente en cada quincena futura mientras el ítem recurrente esté vigente (fecha de inicio ≤ quincena ≤ fecha de fin). El usuario edita lo variable o agrega líneas puntuales encima de lo generado.
- Nota: los préstamos (Upstart #1 y #2, modo estándar; "Ada", modo "Hasta liquidar") **ya no se modelan como recurrentes genéricos** — ver "Préstamos (Loans)" abajo.
- Ejemplos de recurrentes sin fecha de fin: sueldo fijo WALO ($2,750/quincena), Rent ($1,900, quincena de fin de mes), T-Mobile, GYM, Abuelos ($2,750 MXN), Mustang Insurance, Novotech (MXN).
- **La edición manual gana:** editar un ítem recurrente (monto, frecuencia, fecha fin) regenera/actualiza la línea correspondiente solo en las quincenas futuras cuya línea generada por ese recurrente **no** haya sido editada manualmente por el usuario. Las quincenas donde el usuario ya editó esa línea a mano quedan intactas — el cambio del recurrente no las sobrescribe.
  - *Criterio de aceptación:* si el usuario cambia el monto de un recurrente, todas las quincenas futuras sin edición manual en esa línea reflejan el nuevo monto; una quincena donde el usuario ya había modificado esa línea a mano conserva su valor editado sin cambios.

### Préstamos (Loans)

- Un préstamo tiene: nombre, **dirección** (me lo prestaron → sus pagos son EGRESOS; yo lo presté → sus pagos son INGRESOS), monto original (principal), moneda (USD/MXN), APR anual, fecha de inicio, plazo en meses **o** fecha de fin (uno deriva el otro), frecuencia de pago (mensual en día fijo — default — o cada quincena), y estado activo.
- **Amortización estándar (pago fijo):** `pago = P · r / (1 − (1 + r)^−n)`, donde `P` = principal, `r` = tasa por período (APR/12 para mensual, APR/24 para quincenal), `n` = número total de períodos (meses o quincenas según frecuencia).
- La app calcula automáticamente, para cada pago del calendario de amortización: desglose interés/capital de ese pago y saldo restante después de aplicarlo.
- **Sobrescritura del pago:** si el usuario cambia manualmente el monto de un pago, la app recalcula el plazo restante y el saldo con ese nuevo monto hacia adelante (no solo esa línea aislada).
- Cada pago programado cae en la quincena que le corresponde según su día (1–15 / 16–fin de mes) como línea generada con origen `"préstamo"`, sujeta a la misma regla "edición manual gana" y al mismo encadenado de sobrante que cualquier otra línea.
- Ejemplos reales: Upstart 1 (día 20, pago ~$629, egreso), Upstart 2 (día 4, pago ~$534, egreso). Estas líneas dejan de capturarse como recurrentes sueltos y pasan a ser préstamos con amortización.
- *Criterio de aceptación (ejemplo verificable, modo estándar):* préstamo de $10,000 USD, APR 12%, mensual, 24 meses → `r = 0.01`, `n = 24` → pago mensual = `10000 · 0.01 / (1 − 1.01^−24) ≈ $470.73/mes`. Primer pago: interés = `10000 × 0.01 = $100.00`, capital = `470.73 − 100.00 = $370.73`, saldo tras el pago = `10000 − 370.73 = $9,629.27`. La app debe reproducir estos tres valores exactos (±$0.01) para el primer período, y el saldo debe llegar a $0.00 (±$0.01) en el pago #24.

**Modo "Hasta liquidar" (revolving):**

- Switch "Hasta liquidar" en el formulario del préstamo: al activarlo, oculta plazo/fecha fin y en su lugar pide **"Pago esperado"** por período. Aplica a ambas direcciones (me lo prestaron / yo lo presté).
- **Interés mensual** (como tarjeta de crédito) = saldo × APR/12, calculado al cierre de cada mes sobre el saldo vigente en ese momento.
- Cada período genera una línea con el pago esperado, que el usuario edita libremente con el pago real recibido/hecho; **la edición manual gana** — el pago real sobrescribe el esperado para ese período.
- **Saldo** = principal + intereses acumulados − suma de pagos reales de las líneas activas (con estado "cuenta" activo).
- El préstamo **termina** en el primer período en que el saldo llega a ≤ 0; el último pago se ajusta automáticamente al saldo restante exacto (no se sobrepaga).
- Si el pago esperado configurado es ≤ el interés mensual, la app **avisa que el préstamo nunca se liquida** con ese pago y proyecta un máximo de 10 años como techo de la tabla de amortización.
- Ejemplo real: "Ada" — $824 prestados a su hermana, APR 26.2%, pago esperado $200 por quincena (ingreso).
- *Criterio de aceptación (ejemplo verificable, modo revolving):* préstamo de $824, APR 26.2%, pago esperado $200/quincena → interés del primer mes = `824 × (0.262/12) ≈ $17.99`. La app debe calcular este valor (±$0.01), mostrar una fecha estimada de fin y la tabla proyectada período a período; si el usuario edita un pago real a $150 en vez de $200, el saldo y la fecha estimada de fin se recalculan hacia adelante a partir de ese período.

### Inversiones (aportaciones recurrentes)

- Una inversión tiene: cuenta destino (ej. GBM, Webull, crypto…), monto de aportación, moneda, frecuencia (cada quincena / mensual en día X), fecha de inicio, fecha de fin opcional, estado activo.
- Cada aportación se proyecta como **EGRESO** en la quincena correspondiente, como línea generada con origen `"inversión"`, sujeta a la misma regla "edición manual gana" y al mismo encadenado de sobrante que cualquier otra línea.
- La pantalla lista las cuentas con **"aportado a la fecha"** = suma de las líneas activas ya materializadas (quincenas que ya ocurrieron o fueron generadas), y un **total general** sumando todas las cuentas activas.
- **Fuera de v1 explícitamente:** rendimientos, precios de mercado o valor actual de la inversión — v1 solo registra cuánto se ha aportado, no cuánto vale hoy. Etapa 2 añade "valor actual manual" (captura a mano) y más adelante control completo (precios, rendimiento).
- *Criterio de aceptación:* inversión GBM de $300 cada quincena desde el 1 de septiembre genera una línea de $300 en la quincena 1–15 de septiembre y otra de $300 en la quincena 16–30; tras materializarse la primera quincena, "aportado a la fecha" para GBM muestra $300.

### Suscripciones (Services List)

- Lista separada de servicios/suscripciones: nombre, precio, moneda, día de pago (1–31), fecha de inicio, fecha de fin (opcional), tarjeta de pago, categoría (Tools, Entertainment, Apartment, Work, Personal, Hobby, Investment).
- Ejemplos: 1Password ($4, día 23), ChatGPT ($20, día 1), Claude ($21, día 30), Cursor ($20, día 21), iCloud ($9.99, día 15), Netflix, Spotify MX, YouTube, Luz Reliant ($82, día 12).
- **Servicios del hogar:** para el usuario es una lista distinta (ej. luz, agua, gas, internet del hogar), pero de producto no hay diferencia de reglas frente a Suscripciones — se implementa como el mismo modelo con un `kind` (`.subscription` / `.service`), misma mecánica de día de pago, misma pantalla base, icono `house.fill` y categorías propias de hogar. Decisión de implementación aprobada por Steve, no es una feature ni una regla de cálculo distinta.
- **Cálculo automático por día de pago:** la app determina sola si el día de pago de cada suscripción activa cae en el rango 1–15 o 16–fin de mes, y sma esos montos en la línea **"Payments from 1–15 / 15–30"** de la quincena correspondiente — sin que el usuario tenga que capturar nada manualmente por quincena.
- Una suscripción con fecha de fin deja de sumarse a partir de la quincena posterior a su vencimiento.

### Overview

- Vista resumen por mes: quincena del 15 vs. quincena de fin de mes, con Income / Outcome / Total de cada una.
- Vista resumen anual (agregando los 24 cortes del año).
- Entra en v1, sin edición — es solo lectura/consulta.

---

## Features — MVP (v1)

En orden de prioridad. Todas para 1.0 — review (no hay features que requieran diferirse a 1.1 por complejidad de revisión, ya que no hay IAP, permisos sensibles ni mecánicas de monetización).

| # | Feature | Por qué en MVP | Criterio de aceptación |
|---|---------|---------------|----------------------|
| 1 | Pantalla Quincena (INCOME + EXPENSES + totales + sobrante) | Es el core loop completo de la app — sin esto no hay producto | El usuario abre una quincena, ve sus líneas de ingreso y gasto; swipe izq→der alterna "cuenta/no cuenta" (inactiva = semitransparente, excluida de totales/sobrante/encadenado); swipe der→izq marca/desmarca "pagado" (puramente visual, sin efecto en cálculos); desactivar WALO en la quincena 1–15 de septiembre baja TOTAL INCOME y el "Latest Month" de la quincena 16–30, reactivarla lo restaura; el sobrante colorea correctamente (verde ≥ $100, amarillo $0–$99.99, rojo < $0) en tiempo real |
| 2 | Conversión MXN → USD con tipo de cambio automático + override manual | Gasto real del usuario está en dos monedas; sin esto los totales están mal | Una línea en MXN se refleja convertida en el total USD; el tipo de cambio se obtiene de la API al abrir la app; el usuario puede editarlo y el cambio persiste para esa quincena |
| 3 | "Mandar" (monto a enviar a México) | Es una decisión operativa que el usuario toma cada quincena | La cifra "Mandar: $X USD" es igual a la suma de líneas EXPENSES en MXN dividida entre el tipo de cambio vigente |
| 4 | Encadenado de sobrante entre quincenas | Es el mecanismo central de la proyección — sin esto cada quincena vive aislada | El sobrante de la quincena N aparece automáticamente como primera línea de INCOME ("Latest Month") en la quincena N+1; editar una línea pasada recalcula el encadenado hacia adelante |
| 5 | Ítems recurrentes con proyección multi-año (con fecha fin opcional) | Es el requisito explícito del usuario: ver 10 años adelante, préstamos a plazo | Un recurrente con fecha fin genera líneas automáticamente en cada quincena dentro de su vigencia y deja de generarlas después; uno sin fecha fin se proyecta indefinidamente hacia adelante en cualquier quincena futura que el usuario navegue |
| 6 | Suscripciones (Services List) con cálculo automático por día de pago | Reemplaza el cálculo manual que hoy hace en la hoja | Cada suscripción activa se refleja automáticamente en "Payments 1–15" o "Payments 15–30" de la quincena que corresponda según su día de pago, sin captura manual por quincena |
| 7 | Overview (mensual y anual) | Da visión de conjunto que hoy la hoja no da de forma clara | El usuario ve Income/Outcome/Total por cada quincena del mes y un resumen anual agregando los 24 cortes |
| 8 | Sync iCloud privado | Requisito de continuidad entre iPhone y Mac del mismo usuario | Un cambio hecho en iOS aparece en macOS (y viceversa) sin acción manual del usuario, sin login ni cuentas |
| 9 | Ajustes (tipo de cambio manual, moneda por defecto, historial visible, gestión de recurrentes/suscripciones) | Punto único para administrar lo que no vive en una quincena específica | El usuario puede crear/editar/eliminar recurrentes y suscripciones, fijar el tipo de cambio manual, y configurar "Historial visible" (1–24 meses, default 1) desde un solo lugar; el chevron "atrás" de la pantalla Quincena se deshabilita al llegar al límite configurado o a la primera quincena existente, lo que ocurra primero |
| 10 | Bloqueo biométrico opcional (Face ID / Touch ID) | Datos financieros personales — el usuario quiere poder proteger el acceso sin que sea obligatorio | Switch "Bloquear con Face ID / Touch ID" en Ajustes, apagado por defecto. Al activarlo, la app pide autenticación local (Face ID / Touch ID / contraseña del dispositivo) al abrir y al volver de background tras N segundos de inactividad (N sugerido: 60 s, valor final a decisión de Jonny/Woz). Con el switch activo, la app no muestra montos hasta autenticar exitosamente; si la autenticación falla, se muestra una pantalla de bloqueo con botón "Reintentar" |
| 11 | Préstamos (Loans): amortización estándar + modo "Hasta liquidar" (revolving) | Reemplaza el cálculo manual de Upstart 1/2 (estándar) y de "Ada" (revolving) en la hoja, y da visibilidad real de saldo/interés restante | Estándar: préstamo de $10,000 USD, APR 12%, mensual, 24 meses calcula pago mensual ≈ $470.73, primer pago con interés $100.00 / capital $370.73 / saldo $9,629.27 (±$0.01), saldo $0.00 en el pago #24. Revolving: préstamo de $824, APR 26.2%, pago esperado $200/quincena calcula interés del primer mes ≈ $17.99 (±$0.01), termina en el primer período con saldo ≤ 0 (último pago ajustado), avisa si el pago esperado ≤ interés mensual y proyecta máx. 10 años. Ambos modos: cada pago genera su línea en la quincena correcta según día de pago, respeta "edición manual gana", y el detalle muestra saldo restante, pagado a la fecha, interés total, fecha de fin y próximo pago |
| 12 | Inversiones (aportaciones recurrentes) | Reemplaza el cálculo manual de aportaciones a GBM/Webull/crypto en la hoja; solo aportaciones, sin rendimientos ni valor de mercado en v1 | Aportación GBM de $300 cada quincena desde el 1 de sep. genera una línea de EGRESO de $300 (origen `"inversión"`) en la quincena 1–15 y otra en 16–30, respetando "edición manual gana" y el encadenado; la pantalla muestra "aportado a la fecha" = $300 tras materializarse la primera quincena, y el total general sumando todas las cuentas activas |

---

## Features — Fuera del MVP

Explícitamente descartadas para V1 (etapa 2, roadmap futuro — no se diseñan ni desarrollan ahora):

- **Tarjetas de crédito** (saldos, APR, intereses, cálculo de Deuda Total) — espera a etapa 2; añade complejidad de cálculo de intereses compuestos que no es necesaria para el core loop quincenal.
- **Goals / presupuesto por categoría** — espera a que el core de quincenas + recurrentes esté validado en uso real antes de añadir una capa de metas.
- **Control de inversiones completo** (rendimientos, precios de mercado, portafolios) — v1 solo registra aportaciones recurrentes (feature #12); "valor actual manual" llega en etapa 2, control completo más adelante.
- **Importación del histórico 2022–2025 desde la hoja de cálculo** — el usuario decidió arrancar desde cero en 2026; importar el histórico es trabajo adicional de parsing/mapeo que no bloquea el valor core.
- **Multiusuario / compartir presupuesto** — la app es de un solo usuario por diseño; no hay modelo de cuentas ni permisos.
- **Monetización (IAP, suscripción de la app)** — no aplica, uso personal.

---

## Pantallas — alto nivel (sin diseño, referencia para Jonny)

- **Quincena** — pantalla principal, una por corte (15 / fin de mes). Lista INCOME, lista EXPENSES, totales, sobrante grande con color, "Mandar", navegación a quincena anterior/siguiente (incluye quincenas futuras generadas por recurrencia, hacia años adelante).
- **Suscripciones (Services List)** — lista de servicios con precio, día de pago, categoría, tarjeta, vigencia. Alta/edición/baja.
- **Recurrentes y pagos** (hub) — tres secciones: **Recurrentes** (ingresos/egresos simples, con monto/frecuencia/fecha inicio-fin, alta/edición/baja), **Préstamos** (lista de préstamos activos, incluye Upstart 1/2 en modo estándar y "Ada" en modo "Hasta liquidar"; detalle por préstamo con resumen — saldo restante, pagado a la fecha, interés total, fecha de fin, próximo pago — y tabla de amortización período a período; los pagos marcados "pagado" en su quincena se reflejan en el avance del préstamo), e **Inversiones** (lista de cuentas con aportación recurrente — GBM, Webull, crypto…; muestra "aportado a la fecha" por cuenta y total general, sin rendimientos ni valor actual en v1).
- **Overview** — resumen mensual (dos quincenas) y anual, solo lectura.
- **Ajustes** — tipo de cambio (automático + override manual), moneda por defecto, switch de bloqueo biométrico (Face ID / Touch ID), Preferencias → "Historial visible" (stepper/picker de meses hacia atrás, 1–24, default 1), y accesos a Recurrentes/Suscripciones si no viven como tabs independientes.

La navegación entre estas pantallas (tabs vs. sidebar, iOS vs. macOS) es decisión de Jonny en fase de diseño, no de este documento.

---

## Fases de desarrollo

**Fase 1 — MVP**
- Meta: reproducir completo el modelo mental de la hoja de cálculo actual en una app nativa con Liquid Glass, con proyección automática.
- Entregables: features 1–12 de la tabla MVP.
- Estado final: el usuario puede abandonar la hoja de cálculo por completo — captura su quincena, ve su sobrante encadenado, administra suscripciones y recurrentes, y consulta el overview, todo sincronizado entre iPhone y Mac.

**Fase 2 — Experiencia completa**
- Meta: cerrar los huecos que hoy sigue cubriendo manualmente fuera de la app (tarjetas de crédito, metas).
- Entregables: Tarjetas de crédito (saldos, APR, Deuda Total), Goals/presupuesto por categoría.
- Estado final: el usuario tiene una vista financiera completa, no solo de flujo de quincena sino de deuda y metas.

**Fase 3 — Polish y lanzamiento**
- Meta: pulir para uso de largo plazo y evaluar si vale la pena abrir a otros usuarios.
- Entregables: control de inversiones, importación de histórico si se decide retroactivamente, evaluación de si Fintrol pasa de app personal a distribución más amplia (lo cual reabriría monetización, multiusuario, etc. — no se asume aquí).
- Estado final: app madura de uso diario, con decisión explícita tomada sobre su alcance futuro.

---

## Riesgos

- **La API de tipo de cambio sin autenticación puede caerse o cambiar de contrato** — mitigación: el override manual (ya en el MVP) es el fallback; cachear el último tipo de cambio obtenido para no bloquear la app si la API falla.
- **La lógica de recalculo en cascada (encadenado + recurrentes proyectados a años) puede volverse costosa si el usuario edita una quincena pasada** — mitigación: Avie debe definir si el recalculo es completo o incremental; la regla de que la edición manual siempre gana sobre el recurrente ya está fijada (ver "Recurrencia y proyección multi-año"), así que el modelo de datos debe marcar por línea si fue editada manualmente para respetarla.
- **Proyección "infinita" hacia adelante para recurrentes sin fecha fin** — generar quincenas bajo demanda (lazy) en vez de precalcular años completos, para no comprometer rendimiento ni almacenamiento en iCloud.
- **Bloqueo biométrico mal implementado deja montos visibles en background/app switcher** — mitigación: usar el snapshot/privacy overlay del sistema al entrar a background cuando el switch está activo, y exigir autenticación antes de renderizar cualquier monto al volver a foreground.

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-09-15 | App arranca desde cero en 2026, sin importar histórico 2022–2025 | Decisión explícita del usuario |
| 2026-09-15 | Tarjetas de crédito, Goals, control de inversiones e importación de histórico van a etapa 2 | Reducir alcance del MVP al core de quincena + recurrencia |
| 2026-09-15 | Suscripciones se calculan automáticamente por día de pago, sin captura manual por quincena | Decisión explícita del usuario |
| 2026-09-15 | Tipo de cambio automático vía API con override manual editable | Decisión explícita del usuario |
| 2026-09-15 | Préstamos (Upstart) e "Ada" se modelan como ingresos/egresos recurrentes genéricos con fecha de fin, no como entidades especiales | Decisión explícita del usuario — simplifica el modelo de datos |
| 2026-09-15 | Sobrante se encadena automáticamente quincena a quincena, hacia adelante en toda la proyección | Decisión explícita del usuario, es el corazón del modelo mental de la hoja actual |
| 2026-09-15 | Vuelve a v1 el estado "cuenta/no cuenta" — ya no como switches separados sino como dos gestos de swipe por línea: izq→der alterna "cuenta/no cuenta" (excluye de totales/sobrante/encadenado), der→izq marca "pagado" (puramente visual). Ambos persisten por línea y sincronizan por iCloud | Decisión explícita del usuario |
| 2026-09-15 | "Mandar" se mantiene como cálculo visible por quincena | Decisión explícita del usuario |
| 2026-09-15 | Solo Overview entra en v1; Goals se pospone | Decisión explícita del usuario |
| 2026-09-15 | Un solo usuario, sync solo vía iCloud privado, sin cuentas ni compartir | Decisión explícita del usuario |
| 2026-09-15 | Sin monetización en v1 — app de uso personal | Consecuencia de ser app de un solo usuario sin distribución comercial planeada |
| 2026-09-15 | Distribución v1: personal (TestFlight / instalación directa), sin App Store público, sin Phil/Kate; abrir al App Store queda como posible fase futura no decidida | Decisión explícita del usuario |
| 2026-09-15 | Color del sobrante con umbral fijo: verde ≥ $100, amarillo $0–$99.99, rojo < $0 | Decisión explícita del usuario |
| 2026-09-15 | En conflicto entre recurrente y edición manual, gana la edición manual de esa quincena específica | Decisión explícita del usuario |
| 2026-09-15 | Bloqueo biométrico opcional (Face ID / Touch ID) entra en v1, apagado por defecto, en Ajustes | Decisión explícita del usuario — protección de datos financieros personales sin fricción obligatoria |
| 2026-09-15 | "Préstamos" es feature propia con amortización estándar (no recurrentes genéricos); Upstart 1 y 2 pasan a modelarse como préstamos | Decisión explícita del usuario |
| 2026-09-15 | Préstamos añade modo "Hasta liquidar" (revolving, interés mensual sobre saldo tipo tarjeta de crédito, sin plazo fijo); "Ada" pasa de recurrente simple a préstamo revolving ($824, APR 26.2%, pago esperado $200/quincena) | Decisión explícita del usuario |
| 2026-09-15 | "Inversiones" (aportaciones recurrentes) entra en v1 como sexta sección del hub "Recurrentes y pagos"; solo registra aportaciones (egresos), sin rendimientos ni valor actual — eso queda para etapa 2 | Decisión explícita del usuario |
| 2026-09-16 | El límite histórico de navegación hacia atrás pasa de tope duro fijo ("no hay quincenas antes de la primera materializada") a configurable en meses (Ajustes → Preferencias → "Historial visible", 1–24, default 1); la regla de la primera quincena materializada se conserva como piso adicional no configurable | Decisión explícita del usuario |
| 2026-09-15 | "Servicios del hogar" se implementa como `kind` (.subscription / .service) del mismo modelo que Suscripciones — misma mecánica de día de pago, pantalla, icono `house.fill` y categorías propias; dos listas para el usuario, sin diferencia de reglas de producto | Autorizado por Steve — decisión de implementación, no contradicción |

---

## Decisiones técnicas delegadas

- **Proveedor de API de tipo de cambio** (servicio específico, límites de uso, costo si aplica) — no es decisión de producto; la toma Avie como parte del TRD (Technical Requirements Document) de arquitectura.
