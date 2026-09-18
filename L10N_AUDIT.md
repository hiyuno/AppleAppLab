# L10N_AUDIT — Fintrol

> Auditoría de localización. Fecha: 2026-09-17.
> Alcance de esta fase: **inventario y mapeo**, no ejecución. Ningún código ni catálogo fue tocado.
> Decisión del usuario: la app queda **solo en inglés** por ahora, pero se construye la infraestructura real de i18n (`Localizable.xcstrings`, `sourceLanguage: "en"`, claves semánticas) para que agregar español u otros idiomas después sea trivial.

---

## Estado

| Idioma | i18n lista | Traducción | App Store |
|--------|-----------|-----------|----------|
| Inglés (sourceLanguage) | ❌ (todo hardcodeado hoy) | ⏳ (esta auditoría define el texto fuente) | ⏳ |
| Español | ❌ | N/D — explícitamente fuera de alcance por ahora | ⏳ |

Ningún idioma tiene i18n lista todavía: **cero** strings usan `String(localized:)`, no existe `Localizable.xcstrings` ni `InfoPlist.xcstrings` en el proyecto.

---

## Hallazgos de i18n

### 🔴 [L-001] Cero infraestructura de i18n — toda la UI está hardcodeada
**Reproducción:** cambiar el idioma del sistema a cualquier otro — nada cambia, la app siempre muestra la mezcla actual de español/inglés literal.
**Fix:** crear `Localizable.xcstrings` con `sourceLanguage: "en"`, envolver cada `Text`/`Label`/`Button`/`.navigationTitle`/`.accessibilityLabel`/`.accessibilityHint`/placeholder con `String(localized:)` y una clave semántica. Ver tabla completa abajo (~340 strings).
**Responsable:** Woz

### 🔴 [L-002] `HomeServiceCategory` y (parcialmente) `SubscriptionCategory` usan su `rawValue` en español como texto de UI Y como valor persistido a la vez
**Archivo:** `Core/Models/FintrolEnums.swift:80-108`
**Reproducción:** `ServicesView.swift:76` y `SubscriptionsView.swift:76` hacen `Text($0.rawValue)` / interpolan `category.rawValue` directo en un `Picker`/caption — es el `rawValue` **persistido** en SwiftData/CloudKit (`case rent = "Renta"`, `case electricity = "Luz"`, etc.), no solo texto de display.
**Por qué es bloqueante:** no se puede envolver `rawValue` en `String(localized:)` sin either (a) mostrar la clave cruda en vez de una traducción, o (b) cambiar el `rawValue` mismo, lo que rompe datos ya persistidos/sincronizados vía CloudKit. `SubscriptionCategory` ya está en inglés (`case tools = "Tools"`, etc. — inconsistente con `HomeServiceCategory`, que está en español) pero tiene el mismo problema estructural: el `rawValue` sirve dos propósitos a la vez.
**Fix:** separar persistencia de presentación — mantener el `rawValue` actual tal cual (no tocarlo, evita migración), agregar una `var displayName: String` computada por caso que devuelva `String(localized:)` con una clave propia (`home_service_category_rent`, etc.), y cambiar cada `Text($0.rawValue)`/interpolación a `Text($0.displayName)`.
**Responsable:** Woz (requiere a Avie confirmar que no hay otro lugar que dependa del `rawValue` como texto — ya revisé `ServicesView`/`SubscriptionsView`, no vi más apariciones en `Features/`/`UI/`).

### 🟡 [L-003] `CreditCardPaymentDateRuleView` está comentado como "el único texto en inglés de toda la app, por decisión explícita del usuario" — ese comentario queda obsoleto
**Archivo:** `Features/Settings/CreditCardPaymentDateRuleView.swift:5-6`
**Detalle:** con la decisión de mover TODA la app a inglés, ese comentario y la premisa que describe ("el resto de Fintrol es español") ya no aplican. No bloquea nada — la pantalla ya está en inglés y no necesita cambios de texto — pero el comentario debería actualizarse cuando Woz toque el archivo para no confundir al siguiente desarrollador.
**Fix:** actualizar/quitar el comentario. Sin impacto funcional.
**Responsable:** Woz (cosmético, bajo el mismo PR que envuelve el resto del archivo en claves).

### 🟡 [L-004] Mezcla de idioma ya existente hoy — confirma que normalizar a inglés no es solo traducir, es unificar tono
**Detalle:** la app ya mezcla literales en inglés (`"INCOME"`, `"EXPENSES"`, `"Next Month"`, `"Credit Cards"`, `"Credit Cards Payments"`, `AppAppearance`/`FintrolSection` en algunos casos) con español (`"Sobrante"`, `"Mandar"`, `"Préstamos"`, etc.) en la MISMA pantalla (`PeriodView`/`SummaryPanel`). Confirmado en el código, no solo en el enunciado de la tarea.
**Fix:** la tabla de abajo asigna un valor en inglés de producto a cada string, sin importar si el original ya estaba en inglés o español — todo pasa por una clave nueva.
**Responsable:** Woz + Kim (revisión de tono)

### ✅ [L-005] "Quincena" (periodo de pago quincenal, concepto muy mexicano) — resuelto
**Detalle:** el código ya usa "Period"/"period" en inglés en varios lugares internos (`PeriodView`, `PeriodCoordinator`, comentarios), pero el texto visible en español decía "quincena" en ~15 lugares distintos (`"Quincena anterior"`, `"Cada quincena"`, `"Ir a quincena"`, etc.).
**Decisión (Steve, aprobada):** **"quincena" → "period"** en todo el texto de producto (ej. "Quincena anterior" → "Previous period", "Cada quincena" → "Every period"), consistente con el nombre interno que el código ya usa (`PeriodView`, `PeriodCoordinate`). Aplicado en toda la tabla.
**Responsable:** Woz implementa contra la tabla tal cual.

### 🔵 [L-006] Plurales reales necesarios (hoy resueltos con ternarios `count == 1 ? … : …`, que no escalan a otros idiomas)
- `RecurringHubView.row(...)`: `count == 1 ? "1 elemento" : "\(count) elementos"` → clave `hub_item_count` con variantes `one`/`other`.
- `SettingsView`: `historyMonthsBack == 1 ? "mes" : "meses"` → clave `settings_history_months` con variantes `one`/`other`.
- `CreditCardPaymentDateRuleView`: `days == 1 ? "day" : "days"` → clave `cc_date_rule_days_before` con variantes `one`/`other`.
- `LoanEditSheet.overrideRecalculatedTermText`: siempre usa la forma plural de "quincenas"/"meses" sin importar si `n == 1` — hoy es un bug menor de gramática en español que se replicaría en inglés ("pays off in 1 months"). Al mover a `String(localized:)` con variantes, se corrige gratis.
**Responsable:** Woz (usa `String(localized:)` con `Argument`/plural variants al implementar cada clave marcada 🔢 en la tabla).

### 🔵 [L-007] Expansión de texto / layout — riesgo bajo, un patrón a vigilar
Revisé cada `.frame(width:)` fijo en las pantallas auditadas:
- Los únicos anchos fijos sobre texto son los `Picker` segmentados de moneda (`.frame(width: 140)` en Loans/CreditCards/Investments/Recurring/Services/Subscriptions edit sheets, `.frame(width: 130)` en `LineCaptureSheet`) — contienen únicamente `"USD"`/`"MXN"`, códigos de moneda que **no se traducen nunca** (ISO 4217). Sin riesgo.
- El chip de dirección "Debo"/"Me deben" que el propio código menciona en comentarios (`DESIGN_LIQUID.md`) **ya no se renderiza visualmente** — `LoanRow` lo removió a favor de encabezados de sección ("ME DEBEN"/"DEBO"), que no tienen ancho fijo. El texto solo sobrevive dentro de `accessibilityLabel` (no visual, sin riesgo de corte). Confirmar con Jonny/Larry que esto sigue siendo intencional al traducir a "I owe"/"Owed to me" (más largo que el español).
- `OverviewView.row(label:totals:)`: `.frame(width: 60, alignment: .leading)` sobre `"1–15"`/`"16–fin"` → al traducir "fin" → "end" el string pasa de 6 a 6 caracteres (`16–fin` vs `16–end`), sin riesgo.
- No encontré ningún `Button`/chip de texto corto con ancho fijo que se rompa con la expansión inglés→futuro-alemán. Sin bloqueantes de layout hoy.
**Responsable:** Jonny (confirmar visualmente con pseudo-localización una vez el catálogo exista — Bounded/Double-Length Pseudolanguage).

### ✅ [L-008] `InvestmentEditSheet` usaba marcas mexicanas como placeholder de ejemplo — resuelto
**Archivo:** `Features/Investments/InvestmentsView.swift:269` — `"Cuenta (GBM, Cetesdirecto…)"`.
**Detalle:** GBM y Cetesdirecto son brokers/plataformas de inversión mexicanas — tenían sentido para un usuario mexicano pero no para el mercado angloparlante ahora que el idioma fuente es inglés.
**Decisión (Steve, aprobada):** generalizar el placeholder a nombres angloparlantes — `"Account (Fidelity, Vanguard, Robinhood…)"`. Aplicado en la tabla.
**Responsable:** Woz implementa contra la tabla tal cual.

---

## Strings pendientes — inventario completo

Convenciones: 🔢 = necesita variantes de plural en el catálogo, no una sola clave. `%@`/`%d` = placeholder de interpolación (formato real a confirmar con Woz al envolver cada string — algunos hoy son interpolación de `Text`, no format strings). Claves marcadas **[compartida]** se reutilizan literal en más de un archivo — una sola entrada en el catálogo, referenciada desde varios `String(localized:)`.

### 1 — Quincena (PeriodView, LineItemRow, SummaryPanel, SobranteBadge)

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `period_income_header` | "INCOME" (ya en inglés) | "INCOME" |
| `period_expenses_header` | "EXPENSES" (ya en inglés) | "EXPENSES" |
| `period_total_income` | "TOTAL INCOME" (ya en inglés) | "TOTAL INCOME" |
| `period_total_expenses` | "TOTAL EXPENSES" (ya en inglés) | "TOTAL EXPENSES" |
| `period_swipe_hint_message` | "Desliza una línea: hacia la derecha para activar/desactivar, hacia la izquierda para marcarla pagada (y de nuevo para eliminar/editar)." | "Swipe a line: right to activate or deactivate, left to mark it as paid (swipe again to delete or edit)." |
| `period_swipe_hint_dismiss_a11y` | "Cerrar aviso" | "Dismiss hint" |
| `period_previous_a11y` | "Quincena anterior" | "Previous period" |
| `period_next_a11y` | "Quincena siguiente" | "Next period" |
| `period_date_a11y_current_suffix` | ", quincena actual" | ", current period" |
| `period_date_a11y_hint` | "Toca para saltar a otra quincena" | "Tap to jump to another period" |
| `period_two_column_income_a11y` (macOS) | "Columna de ingresos y gastos" | "Income and expenses column" |
| `period_two_column_summary_a11y` (macOS) | "Columna de resumen" | "Summary column" |
| `period_two_column_layout_a11y` (macOS) | "Diseño de dos columnas" | "Two-column layout" |
| `period_add_income_a11y` | "Agregar ingreso" | "Add income" |
| `period_add_expense_a11y` | "Agregar gasto" | "Add expense" |
| `period_credit_cards_row_title` | "Credit Cards Payments" (ya en inglés) | "Credit Cards Payments" |
| `period_credit_cards_row_a11y` | "Pagos de tarjetas de crédito, %@" | "Credit card payments, %@" |
| `period_credit_cards_row_a11y_hint` | "Toca dos veces para ver el desglose por tarjeta" | "Double-tap to see the breakdown by card" |
| `period_income_a11y` | "Ingresos" | "Income" |
| `period_expenses_a11y` | "Gastos" | "Expenses" |
| `period_loading_a11y` | "Cargando quincena" | "Loading period" |
| `line_origin_manually_edited` | "editado manualmente" | "manually edited" |
| `line_origin_recurring` | "recurrente" | "recurring" |
| `line_origin_home_service` | "servicio del hogar" | "home service" |
| `line_origin_subscription` | "suscripción" | "subscription" |
| `line_origin_loan` | "préstamo" | "loan" |
| `line_origin_investment` | "inversión" | "investment" |
| `line_origin_carry_over` | "arrastrado del mes anterior" | "carried over from last period" |
| `line_origin_credit_card` | "tarjeta de crédito" | "credit card" |
| `line_converted_caption` | "≈ %@ USD · TC %@" | "≈ %@ USD · Rate %@" |
| `line_a11y_action_mark_unpaid` **[compartida]** | "Desmarcar pagado" | "Mark as unpaid" |
| `line_a11y_action_mark_paid` **[compartida]** | "Marcar pagado" | "Mark as paid" |
| `line_a11y_action_edit` **[compartida]** | "Editar" | "Edit" |
| `line_a11y_action_activate` **[compartida]** | "Activar" | "Activate" |
| `line_a11y_action_deactivate` **[compartida]** | "Desactivar" | "Deactivate" |
| `line_a11y_action_delete` **[compartida]** | "Eliminar" | "Delete" |
| `line_context_menu_switch_to_mxn` | "Cambiar a MXN" | "Switch to MXN" |
| `line_context_menu_switch_to_usd` | "Cambiar a USD" | "Switch to USD" |
| `line_currency_changed_announcement` | "Moneda cambiada a %@" | "Currency changed to %@" |
| `line_a11y_state_inactive` | "inactiva" | "inactive" |
| `line_a11y_state_paid` | "pagada" | "paid" |
| `summary_next_month_label` | "Next Month" (ya en inglés) | "Next Month" |
| `summary_send_label` | "Mandar" | "To Send" *(ver duda de tono abajo)* |
| `summary_panel_a11y` | "Panel de resumen" | "Summary panel" |
| `sobrante_label` | "Sobrante" | "Surplus" *(ver duda de tono abajo)* |
| `sobrante_status_positive_a11y` | "positivo, verde" | "positive, green" |
| `sobrante_status_adjusted_a11y` | "ajustado, amarillo" | "adjusted, yellow" |
| `sobrante_status_negative_a11y` | "negativo, rojo" | "negative, red" |

**Tono (aprobado por Steve):** "Sobrante" → **"Surplus"**, "Mandar" → **"To Send"**. Cerrado, sin más ajustes pendientes.

### 2 — Hub (RecurringHubView) — ✅ migrado (2026-09-17, Woz)

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `hub_title` | "Recurrentes y pagos" | "Recurring & Payments" |
| `hub_section_income` | "INCOME" (ya en inglés) | "INCOME" |
| `hub_section_expenses` | "EXPENSES" (ya en inglés) | "EXPENSES" |
| `hub_section_others` | "OTHERS" (ya en inglés) | "OTHERS" |
| `hub_row_recurring_income` | "Ingresos recurrentes" | "Recurring income" |
| `hub_row_recurring_expense` | "Gastos recurrentes" | "Recurring expenses" |
| `hub_row_services` | "Servicios" | "Services" |
| `hub_row_subscriptions` | "Suscripciones" | "Subscriptions" |
| `hub_row_loans` | "Préstamos" | "Loans" |
| `hub_row_credit_cards` | "Credit Cards" (ya en inglés) | "Credit Cards" |
| `hub_row_investments` | "Inversiones" | "Investments" |
| `hub_item_count` 🔢 | "1 elemento" / "%d elementos" | one: "1 item" / other: "%d items" |

**Nuevas (2026-09-17) — descripción de una línea por fila, pedida por el usuario tras ver el Hub:**

| Clave | Inglés (fuente) |
|---|---|
| `hub_row_recurring_income_desc` | "Income that repeats every period, like your salary" |
| `hub_row_recurring_expense_desc` | "Expenses that repeat automatically each period" |
| `hub_row_services_desc` | "Fixed monthly bills — rent, utilities, internet" |
| `hub_row_subscriptions_desc` | "Recurring subscriptions — streaming, apps, memberships" |
| `hub_row_loans_desc` | "Loans you're paying off or that are being paid to you" |
| `hub_row_credit_cards_desc` | "Manage balances, APR, and payment dates" |
| `hub_row_investments_desc` | "Recurring contributions to your investments" |

`hub_item_count` ya tiene sus variantes `one`/`other` escritas a mano en `Localizable.xcstrings` (Xcode no las auto-genera hasta abrir el catálogo). El resto de las claves de esta sección se sincronizan al catálogo por extracción automática al compilar, igual que en Quincena.

### 3 — Préstamos (LoansView, LoanDetailView)

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `loans_title` | "Préstamos" | "Loans" |
| `loans_empty_title` | "Sin préstamos todavía" | "No loans yet" |
| `loans_empty_message` | "Registra un préstamo para ver su saldo y calendario de pagos automáticamente" | "Add a loan to automatically see its balance and payment schedule" |
| `loans_add_a11y` | "Agregar préstamo" | "Add loan" |
| `loans_section_owed_to_me` | "ME DEBEN" | "OWED TO ME" |
| `loans_section_i_owe` | "DEBO" | "I OWE" |
| `loans_section_paid_off` | "LIQUIDADOS" | "PAID OFF" |
| `swipe_action_delete` **[compartida]** | "Eliminar" | "Delete" |
| `swipe_action_edit` **[compartida]** | "Editar" | "Edit" |
| `loan_direction_i_owe_a11y` | "Debo" | "I owe" |
| `loan_direction_owed_to_me_a11y` | "Me deben" | "Owed to me" |
| `loan_paid_a11y` | "Pagado" | "Paid" |
| `loan_paid_off_text` | "Liquidado —" | "Paid off —" |
| `loan_last_payment` | "Último Pago  %@ · %@" | "Last payment  %@ · %@" |
| `loan_next_payment` | "Próximo pago  " | "Next payment  " |
| `loan_remaining` | "Restante  " | "Remaining  " |
| `loan_no_fixed_term` | "Sin plazo" | "No fixed term" |
| `loan_no_fixed_term_never_pays_off` | "Sin plazo · no liquida con el pago esperado" | "No fixed term · never pays off at this payment" |
| `loan_no_fixed_term_ends_approx` | "Sin plazo · termina aprox. %@" | "No fixed term · ends approx. %@" |
| `loan_no_fixed_term_by_payment` | "Sin plazo · según pago esperado" | "No fixed term · based on expected payment" |
| `loan_progress_a11y` 🔢 | "%d por ciento pagado" | "%d percent paid" |
| `loan_frequency_monthly_option` | "Mensual, día X" | "Monthly, day X" |
| `loan_frequency_biweekly_option` | "Cada quincena" | "Every period" |
| `loan_field_name` **[compartida]** | "Nombre" | "Name" |
| `loan_field_direction` | "Dirección" | "Direction" |
| `loan_direction_borrowed_option` | "Me lo prestaron" | "Borrowed" |
| `loan_direction_lent_option` | "Lo presté" | "Lent" |
| `loan_field_original_amount` | "Monto original" | "Original amount" |
| `loan_field_currency` **[compartida]** | "Moneda" | "Currency" |
| `loan_field_apr` **[compartida]** | "APR" | "APR" |
| `loan_field_start_date` **[compartida]** | "Fecha de inicio" | "Start date" |
| `loan_field_frequency` **[compartida]** | "Frecuencia" | "Frequency" |
| `loan_field_day_of_month` | "Día del mes: %d" | "Day of month: %d" |
| `loan_field_revolving_toggle` | "Hasta liquidar (revolving)" | "Until paid off (revolving)" |
| `loan_field_term_months` | "Plazo (meses): %d" | "Term (months): %d" |
| `loan_field_end_date` **[compartida]** | "Fecha fin" | "End date" |
| `loan_footer_fixed_term` | "Editar el plazo o la fecha fin recalcula el otro en vivo." | "Editing the term or end date recalculates the other one live." |
| `loan_footer_revolving` | "Sin plazo fijo: interés mensual sobre el saldo, como una tarjeta de crédito. Puedes cambiar el pago real en cada quincena." | "No fixed term: monthly interest on the balance, like a credit card. You can change the actual payment each period." |
| `loan_field_expected_payment` **[compartida]** | "Pago esperado" | "Expected payment" |
| `loan_warning_insufficient_payment` | "Este pago no cubre el interés mensual estimado — el saldo nunca bajará con este monto." | "This payment doesn't cover the estimated monthly interest — the balance will never go down at this amount." |
| `loan_warning_insufficient_payment_a11y` | "Advertencia: pago insuficiente para cubrir interés mensual" | "Warning: payment insufficient to cover monthly interest" |
| `loan_footer_revolving_short` | "Puedes cambiar el pago real en cada quincena." | "You can change the actual payment each period." |
| `loan_calculated_payment` | "Pago calculado" | "Calculated payment" |
| `loan_per_period_suffix` | "quincena" | "period" |
| `loan_per_month_suffix` | "mes" | "month" |
| `loan_override_payment_button` | "Sobreescribir monto de pago" | "Override payment amount" |
| `loan_override_field` | "Monto de pago" | "Payment amount" |
| `loan_override_recalculated_term` 🔢 | "Con este pago, el préstamo se liquida en %d %@ (%@)." | "With this payment, the loan pays off in %d %@ (%@)." |
| `loan_periods_unit` 🔢 | "quincenas" | one: "period" / other: "periods" |
| `loan_months_unit` 🔢 | "meses" | one: "month" / other: "months" |
| `loan_revert_to_auto_button` | "Volver al cálculo automático" | "Revert to automatic calculation" |
| `loan_active_toggle` **[compartida]** | "Activo" | "Active" |
| `loan_new_title` | "Nuevo préstamo" | "New loan" |
| `loan_edit_title` | "Editar préstamo" | "Edit loan" |
| `action_cancel` **[compartida, app-wide]** | "Cancelar" | "Cancel" |
| `action_save` **[compartida, app-wide]** | "Guardar" | "Save" |
| `loan_direction_change_confirm_title` | "¿Cambiar la dirección del préstamo?" | "Change the loan's direction?" |
| `loan_direction_change_confirm_destructive` | "Cambiar de todos modos" | "Change anyway" |
| `loan_direction_change_confirm_message` | "Ya existen pagos generados para este préstamo. Cambiar la dirección afecta cómo se calculan en quincenas futuras." | "Payments have already been generated for this loan. Changing the direction affects how they're calculated in future periods." |
| `loan_detail_edit_button` **[compartida]** | "Editar" | "Edit" |
| `loan_current_balance_header` | "SALDO ACTUAL" | "CURRENT BALANCE" |
| `loan_remaining_balance_header` | "SALDO RESTANTE" | "REMAINING BALANCE" |
| `loan_accrued_interest_to_date` **[compartida]** | "Interés acumulado a la fecha" | "Interest accrued to date" |
| `loan_last_payment_date` **[compartida]** | "Fecha del último pago" | "Last payment date" |
| `loan_next_expected_payment` | "Próximo pago esperado" | "Next expected payment" |
| `loan_estimated_end` | "Fin estimado" | "Estimated end" |
| `loan_revolving_no_payoff` | "No liquida con este pago" | "Doesn't pay off with this payment" |
| `table_column_date` **[compartida]** | "Fecha" | "Date" |
| `table_column_payment` **[compartida]** | "Pago" | "Payment" |
| `table_row_projected` **[compartida]** | "Proyectado" | "Projected" |
| `table_column_interest` **[compartida]** | "Interés" | "Interest" |
| `table_column_balance` **[compartida]** | "Saldo" | "Balance" |
| `table_column_principal` | "Capital" | "Principal" |
| `loan_paid_to_date` | "Pagado a la fecha" | "Paid to date" |
| `loan_total_interest` | "Interés total" | "Total interest" |
| `loan_next_payment_row` | "Próximo pago" | "Next payment" |
| `loan_end_date_row` | "Fecha de fin" | "End date" |
| `loan_row_a11y_payment` | "%@, pago %@%@" | "%@, payment %@%@" |
| `loan_row_a11y_projected_suffix` | ", proyectado" | ", projected" |
| `loan_row_interest_capital` | "Interés %@ · Capital %@" | "Interest %@ · Principal %@" |
| `loan_row_balance_caption` | "Saldo %@" | "Balance %@" |

### 4 — Tarjetas de crédito (CreditCardsView, CreditCardDetailView)

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `cc_title` | "Credit Cards" (ya en inglés) | "Credit Cards" |
| `cc_empty_title` | "Sin tarjetas todavía" | "No cards yet" |
| `cc_empty_message` | "Registra una tarjeta para ver su saldo, utilización y pago mínimo sugerido automáticamente" | "Add a card to automatically see its balance, utilization and suggested minimum payment" |
| `cc_add_a11y` | "Agregar tarjeta" | "Add card" |
| `cc_balance_row` | "Saldo %@" | "Balance %@" |
| `cc_utilization_summary` 🔢 | "Utilización %d%% · Mínimo sugerido %@" | "Utilization %d%% · Suggested minimum %@" |
| `cc_row_a11y` | "%@, saldo %@, utilización %d por ciento" | "%@, balance %@, utilization %d percent" |
| `cc_field_name` **[compartida]** | "Nombre" | "Name" |
| `cc_field_current_balance` | "Saldo actual" | "Current balance" |
| `cc_field_apr` **[compartida]** | "APR" | "APR" |
| `cc_field_credit_limit` **[compartida]** | "Límite de crédito" | "Credit limit" |
| `cc_field_cutoff_day` | "Día de corte: %d" | "Cutoff day: %d" |
| `cc_field_payment_day` | "Día de pago: %d" | "Payment day: %d" |
| `cc_field_expected_payment` **[compartida]** | "Pago esperado" | "Expected payment" |
| `cc_footer_expected_payment` | "Vacío usa el mínimo sugerido recalculado cada quincena: MAX($25, saldo × 1% + interés del mes)." | "Leave empty to use the suggested minimum, recalculated every period: MAX($25, balance × 1% + this month's interest)." |
| `cc_active_toggle` **[compartida]** | "Activa" | "Active" |
| `cc_new_title` | "Nueva tarjeta" | "New card" |
| `cc_edit_title` | "Editar tarjeta" | "Edit card" |
| `cc_detail_utilization_label` | "Utilización" | "Utilization" |
| `cc_detail_high_utilization_suffix` | " · Alta utilización" | " · High utilization" |
| `cc_detail_utilization_a11y` 🔢 | "Utilización %d por ciento%@" | "Utilization %d percent%@" |
| `cc_detail_high_utilization_a11y_suffix` | ", alta utilización" | ", high utilization" |

*(`cc_detail_*` reutiliza `loan_accrued_interest_to_date`, `loan_last_payment_date`, `loan_next_payment_row`, `table_column_*` y `loan_current_balance_header` — mismas claves compartidas de la sección 3, sin duplicar.)*

### 5 — Inversiones (InvestmentsView)

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `inv_title` | "Inversiones" | "Investments" |
| `inv_empty_title` | "Sin inversiones todavía" | "No investments yet" |
| `inv_empty_message` | "Registra una cuenta para llevar tus aportaciones recurrentes" | "Add an account to track your recurring contributions" |
| `inv_contributed_to_date` **[compartida]** | "Aportado a la fecha" | "Contributed to date" |
| `inv_add_a11y` | "Agregar cuenta de inversiones" | "Add investment account" |
| `inv_row_contributed_suffix` | "aportado" | "contributed" |
| `inv_row_a11y` | "%@, aportado a la fecha %@" | "%@, contributed to date %@" |
| `inv_frequency_biweekly` | "Cada quincena" | "Every period" |
| `inv_frequency_monthly_day` | "Día %d" | "Day %d" |
| `inv_frequency_once` | "Una vez, %@" | "Once, %@" |
| `inv_detail_header` | "APORTADO A LA FECHA" | "CONTRIBUTED TO DATE" |
| `inv_period_half_second` | "16–fin" | "16–end" |
| `inv_state_deactivated` | "Desactivada" | "Deactivated" |
| `inv_state_edited` | "Editada" | "Edited" |
| `inv_state_projected` | "Proyectada" | "Projected" |
| `inv_a11y_deactivated` | "desactivada" | "deactivated" |
| `inv_a11y_edited` | "editada" | "edited" |
| `inv_a11y_projected` | "proyectada" | "projected" |
| `inv_field_account_placeholder` | "Cuenta (GBM, Cetesdirecto…)" | "Account (Fidelity, Vanguard, Robinhood…)" |
| `inv_field_contribution` | "Aportación" | "Contribution" |
| `inv_section_frequency` **[compartida]** | "Frecuencia" | "Frequency" |
| `inv_field_start` | "Inicio" | "Start" |
| `inv_field_has_end_date` **[compartida]** | "Tiene fecha de fin" | "Has an end date" |
| `inv_field_end` **[compartida]** | "Fin" | "End" |
| `inv_field_active` **[compartida]** | "Activa" | "Active" |
| `inv_new_title` | "Nueva cuenta" | "New account" |
| `inv_edit_title` | "Editar cuenta" | "Edit account" |
| `inv_frequency_kind_biweekly` | "Cada quincena" | "Every period" |
| `inv_frequency_kind_monthly` | "Mensual" | "Monthly" |

### 6 — Recurrentes / Servicios / Suscripciones

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `recurring_income_title` **[= hub_row_recurring_income]** | "Ingresos recurrentes" | "Recurring income" |
| `recurring_expense_title` **[= hub_row_recurring_expense]** | "Gastos recurrentes" | "Recurring expenses" |
| `recurring_empty_income_title` | "Sin ingresos recurrentes todavía" | "No recurring income yet" |
| `recurring_empty_expense_title` | "Sin gastos recurrentes todavía" | "No recurring expenses yet" |
| `recurring_empty_income_message` | "Agrega tu sueldo u otro ingreso fijo para proyectarlo automáticamente" | "Add your salary or another fixed income to project it automatically" |
| `recurring_empty_expense_message` | "Agrega renta, un préstamo u otro gasto fijo para proyectarlo automáticamente" | "Add rent, a loan or another fixed expense to project it automatically" |
| `recurring_frequency_biweekly` **[= loan_frequency_biweekly_option]** | "Cada quincena" | "Every period" |
| `recurring_frequency_day` | "Día %d" | "Day %d" |
| `recurring_frequency_once` | "Una vez, %@" | "Once, %@" |
| `recurring_frequency_until_suffix` | "%@ · hasta %@" | "%@ · until %@" |
| `frequency_kind_biweekly_option` **[compartida]** | "Cada quincena" | "Every period" |
| `frequency_kind_monthly_option` **[compartida]** | "Mensual" | "Monthly" |
| `frequency_kind_once_option` | "Una sola vez" | "One time" |
| `field_description` **[compartida]** | "Descripción" | "Description" |
| `field_amount` **[compartida]** | "Monto" | "Amount" |
| `recurring_new_title` | "Nuevo" | "New" |
| `recurring_edit_title` **[compartida con action_edit_title]** | "Editar" | "Edit" |
| `field_currency` **[= loan_field_currency]** | "Moneda" | "Currency" |
| `field_start` **[= inv_field_start]** | "Inicio" | "Start" |
| `field_has_end_date` **[compartida]** | "Tiene fecha de fin" | "Has an end date" |
| `field_end` **[compartida]** | "Fin" | "End" |
| `field_active_masc` | "Activo" | "Active" |
| `services_title` | "Servicios" | "Services" |
| `services_empty_title` | "Sin servicios todavía" | "No services yet" |
| `services_empty_message` | "Agrega renta, luz u otro pago del hogar para que se calcule solo en cada quincena" | "Add rent, electricity or another home payment to have it calculated automatically every period" |
| `services_row_day_category` | "Día %d · %@" | "Day %d · %@" |
| `services_field_name_placeholder` **[= field_name, bare TextField hoy]** | "Nombre" | "Name" |
| `services_field_price_placeholder` | "Precio" | "Price" |
| `services_field_payment_day` | "Día de pago: %d" | "Payment day: %d" |
| `services_field_category` **[compartida]** | "Categoría" | "Category" |
| `services_new_title` | "Nuevo servicio" | "New service" |
| `services_edit_title` | "Editar servicio" | "Edit service" |
| `home_service_category_rent` (rawValue "Renta") | "Renta" | "Rent" |
| `home_service_category_electricity` (rawValue "Luz") | "Luz" | "Electricity" |
| `home_service_category_internet` (rawValue "Internet") | "Internet" | "Internet" |
| `home_service_category_water` (rawValue "Agua") | "Agua" | "Water" |
| `home_service_category_gas` (rawValue "Gas") | "Gas" | "Gas" |
| `home_service_category_insurance` (rawValue "Seguro") | "Seguro" | "Insurance" |
| `subscriptions_title` | "Suscripciones" | "Subscriptions" |
| `subscriptions_empty_title` | "Sin suscripciones todavía" | "No subscriptions yet" |
| `subscriptions_empty_message` | "Agrega tu primera suscripción para que se calcule sola en cada quincena" | "Add your first subscription to have it calculated automatically every period" |
| `subscriptions_row_day_category` | "Día %d · %@" | "Day %d · %@" |
| `subscriptions_field_card` | "Tarjeta" | "Card" |
| `subscriptions_new_title` | "Nueva suscripción" | "New subscription" |
| `subscriptions_edit_title` | "Editar suscripción" | "Edit subscription" |
| `subscription_category_tools` (rawValue "Tools", ya en inglés) | "Tools" | "Tools" |
| `subscription_category_entertainment` (rawValue "Entertainment", ya en inglés) | "Entertainment" | "Entertainment" |
| `subscription_category_apartment` (rawValue "Apartment", ya en inglés) | "Apartment" | "Apartment" |
| `subscription_category_work` (rawValue "Work", ya en inglés) | "Work" | "Work" |
| `subscription_category_personal` (rawValue "Personal", ya en inglés) | "Personal" | "Personal" |
| `subscription_category_hobby` (rawValue "Hobby", ya en inglés) | "Hobby" | "Hobby" |
| `subscription_category_investment` (rawValue "Investment", ya en inglés) | "Investment" | "Investment" |

*(`SubscriptionCategory` ya está en inglés — igual necesita pasar por `displayName`/clave, ver hallazgo L-002, para no quedar como el único enum sin ruta de traducción futura.)*

### 7 — Overview

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `overview_title` | "Overview" (ya en inglés) | "Overview" |
| `overview_empty_title` | "Sin quincenas todavía" | "No periods yet" |
| `overview_empty_message` | "Captura tu primera quincena para ver el resumen aquí" | "Log your first period to see the summary here" |
| `overview_year_picker_label` | "Año" | "Year" |
| `overview_monthly_section` | "Mensual" | "Monthly" |
| `overview_annual_section` | "Anual %d" | "Annual %d" |
| `overview_row_half_first` | "1–15" | "1–15" |
| `overview_row_half_second` | "16–fin" | "16–end" |
| `overview_row_income_prefix` | "In: %@" | "In: %@" |
| `overview_row_expense_prefix` | "Out: %@" | "Out: %@" |
| `overview_row_total_prefix` | "Total: %@" | "Total: %@" |
| `overview_income_total` | "Income total" (ya en inglés) | "Income total" |
| `overview_outcome_total` | "Outcome total" (ya en inglés — nota: "Outcome" no es el término correcto en inglés financiero, debería ser "Expense total"/"Total expenses", flag de tono) | "Expense total" |
| `overview_total` | "Total" (ya en inglés) | "Total" |

**Nota de tono (Kim):** `"Outcome total"` es un falso amigo — en inglés financiero de producto lo correcto es **"Expense total"** (o "Total expenses", igual que en el resto de la app: `"TOTAL EXPENSES"`). Lo marco como corrección, no solo traducción; el string original YA estaba en inglés pero es incorrecto.

### 8 — Ajustes (SettingsView, DeveloperTools)

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `settings_title` | "Ajustes" | "Settings" |
| `settings_section_preferences` | "Preferencias" | "Preferences" |
| `settings_base_currency` | "Moneda base" | "Base currency" |
| `settings_exchange_rate_row` | "Tipo de cambio" | "Exchange rate" |
| `settings_appearance` | "Apariencia" | "Appearance" |
| `appearance_system` | "Sistema" | "System" |
| `appearance_light` | "Claro" | "Light" |
| `appearance_dark` | "Oscuro" | "Dark" |
| `settings_history_visible` 🔢 | "Historial visible: %d mes/meses" | "Visible history: %d month" / "%d months" |
| `settings_history_visible_footer` | "Cuánto puedes retroceder desde la quincena actual." | "How far back you can go from the current period." |
| `settings_cc_payment_rule_row` | "Regla de pago de tarjetas" | "Card payment rule" |
| `settings_icloud_syncing` | "Sincronizando…" | "Syncing…" |
| `settings_icloud_synced` | "Sincronizado" | "Synced" |
| `settings_icloud_offline` | "Sin conexión" | "Offline" |
| `settings_import_subscriptions_button` | "Importar suscripciones y servicios…" | "Import subscriptions and services…" |
| `settings_export_backup_button` | "Exportar respaldo completo (JSON)" | "Export full backup (JSON)" |
| `settings_import_backup_button` | "Importar respaldo completo…" | "Import full backup…" |
| `settings_section_security` | "Seguridad" | "Security" |
| `settings_biometric_lock_toggle` | "Bloquear con Face ID / Touch ID" | "Lock with Face ID / Touch ID" |
| `settings_biometric_lock_error` | "No se pudo activar: verifica que tu dispositivo tenga Face ID, Touch ID o código configurado." | "Couldn't turn it on — check that your device has Face ID, Touch ID or a passcode set up." |
| `settings_reauth_interval` | "Tiempo de re-bloqueo" | "Re-lock time" |
| `reauth_interval_immediate` | "Inmediato" | "Immediate" |
| `reauth_interval_one_minute` | "1 minuto" | "1 minute" |
| `reauth_interval_five_minutes` | "5 minutos" | "5 minutes" |
| `settings_reauth_disabled_hint_a11y` | "Disponible cuando Face ID/Touch ID esté habilitado" | "Available once Face ID/Touch ID is enabled" |
| `settings_privacy_snapshot_note` | "Ocultar montos en el app switcher siempre está activo, independiente de Face ID / Touch ID." | "Hiding amounts in the app switcher is always on, independent of Face ID / Touch ID." |
| `settings_version_text` | "Fintrol — versión %@ (build %@)" | "Fintrol — version %@ (build %@)" |
| `settings_dev_tools_section` | "Developer Tools" (ya en inglés, DEBUG-only) | "Developer Tools" |
| `settings_dev_vibrations_row` | "Vibrations" (ya en inglés, DEBUG-only) | "Vibrations" |
| `settings_dev_cards_row` | "Cards" (ya en inglés, DEBUG-only) | "Cards" |
| `settings_import_alert_title` | "Importación" | "Import" |
| `settings_import_ok_button` **[compartida]** | "OK" | "OK" |
| `settings_import_open_error` | "No se pudo abrir el archivo seleccionado." | "Couldn't open the selected file." |
| `settings_backup_export_success` | "Respaldo exportado correctamente." | "Backup exported successfully." |
| `settings_backup_export_failure` | "No se pudo guardar el respaldo." | "Couldn't save the backup." |
| `settings_backup_import_confirm_title` | "Esto reemplaza TODOS los datos actuales con los del respaldo. ¿Continuar?" | "This replaces ALL current data with the backup's data. Continue?" |
| `settings_backup_import_confirm_destructive` | "Reemplazar todo" | "Replace everything" |
| `settings_backup_import_confirm_cancel` **[= action_cancel]** | "Cancelar" | "Cancel" |
| `settings_backup_alert_title` | "Respaldo" | "Backup" |
| `settings_backup_invalid_file` | "El archivo no es un respaldo válido de Fintrol." | "This file isn't a valid Fintrol backup." |
| `settings_backup_restored_summary` | "Restaurado: %d quincenas, %d líneas, %d recurrentes, %d suscripciones/servicios, %d préstamos." | "Restored: %d periods, %d lines, %d recurring items, %d subscriptions/services, %d loans." |
| `settings_subscription_import_read_error` | "No se pudo leer el archivo seleccionado." | "Couldn't read the selected file." |
| `settings_subscription_import_summary` | "%d importados, %d actualizados, %d omitidos." | "%d imported, %d updated, %d skipped." |
| `settings_exchange_rate_elapsed_minutes` | "hace %d min" | "%d min ago" |
| `settings_exchange_rate_elapsed_hours` | "hace %d h" | "%d h ago" |
| `settings_exchange_rate_elapsed_days` | "hace %d d" | "%d d ago" |
| `exrate_title` | "Tipo de cambio" | "Exchange rate" |
| `exrate_token_placeholder` | "Bmx-Token" | "Bmx-Token" |
| `exrate_show_token_a11y` | "Mostrar token" | "Show token" |
| `exrate_hide_token_a11y` | "Ocultar token" | "Hide token" |
| `exrate_test_token_button` | "Probar token" | "Test token" |
| `exrate_save_token_button` | "Guardar token" | "Save token" |
| `exrate_token_invalid_warning` | "Tu token de Banxico no es válido o expiró — revísalo arriba." | "Your Banxico token is invalid or expired — check it above." |
| `exrate_token_section_header` | "Token de Banxico SIE" | "Banxico SIE token" |
| `exrate_token_section_footer` | "Obtén tu token gratis en el sitio de Banxico. Se guarda solo en este dispositivo, nunca en iCloud." | "Get your free token from the Banxico website. It's stored only on this device, never in iCloud." |
| `exrate_token_valid_message` | "Token válido." | "Valid token." |
| `exrate_token_invalid_message` | "Token inválido — verifica que lo copiaste completo." | "Invalid token — check that you copied it in full." |
| `exrate_token_network_error` | "No se pudo verificar — revisa tu conexión e intenta de nuevo." | "Couldn't verify — check your connection and try again." |
| `exrate_token_test_success_a11y_prefix` | "Éxito: " | "Success: " |
| `exrate_token_test_error_a11y_prefix` | "Error: " | "Error: " |
| `exrate_automatic_toggle` | "Automático" | "Automatic" |
| `exrate_manual_placeholder` | "Tipo de cambio (1–100)" | "Exchange rate (1–100)" |
| `exrate_manual_save_button` **[= action_save]** | "Guardar" | "Save" |
| `exrate_automatic_footer` | "Se consulta automáticamente al abrir la app (máximo una vez al día)." | "Checked automatically when you open the app (at most once a day)." |
| `exrate_manual_footer` | "Rango válido: 1–100 (USD → MXN)." | "Valid range: 1–100 (USD → MXN)." |
| `exrate_manual_invalid_number` | "Escribe un número válido." | "Enter a valid number." |
| `exrate_manual_out_of_range` | "El tipo de cambio debe estar entre %@ y %@." | "The exchange rate must be between %@ and %@." |
| `cc_date_rule_title` | "Payment Date Rule" (ya en inglés) | "Payment Date Rule" |
| `cc_date_rule_option_payment_date` | "On the payment date" (ya en inglés) | "On the payment date" |
| `cc_date_rule_option_payment_date_detail` | "Only avoids interest. Simplest option, no credit score benefit." (ya en inglés) | "Only avoids interest. Simplest option, no credit score benefit." |
| `cc_date_rule_option_cutoff_date` | "On the statement/cutoff date" (ya en inglés) | "On the statement/cutoff date" |
| `cc_date_rule_option_cutoff_date_detail` | "Almost as good as paying early, with no buffer if something goes wrong." (ya en inglés) | "Almost as good as paying early, with no buffer if something goes wrong." |
| `cc_date_rule_option_days_before` | "N days before the cutoff date" (ya en inglés) | "N days before the cutoff date" |
| `cc_date_rule_option_days_before_detail` | "Reduces the balance your card issuer reports to the credit bureau — often the best practice for your credit score." (ya en inglés) | (igual) |
| `cc_date_rule_days_before_stepper` 🔢 | "%d day/days before cutoff" (ya en inglés, ternario) | one: "%d day before cutoff" / other: "%d days before cutoff" |
| `settings_cc_rule_summary_payment_date` | "On the payment date" (ya en inglés) | "On the payment date" |
| `settings_cc_rule_summary_cutoff_date` | "On the cutoff date" (ya en inglés) | "On the cutoff date" |
| `settings_cc_rule_summary_days_before` 🔢 | "%d days before cutoff" (ya en inglés) | one: "%d day before cutoff" / other: "%d days before cutoff" |
| `dev_radius_chip_small` (DEBUG-only) | "Chico (chips/botones)" | "Small (chips/buttons)" |
| `dev_radius_apple_sheet` (DEBUG-only) | "Sheet estándar de Apple" | "Apple's standard sheet" |
| `dev_radius_current` (DEBUG-only) | "Actual de la app" | "Current in the app" |
| `dev_radius_large_card` (DEBUG-only) | "Card grande (actual en tarjetas principales)" | "Large card (current on main cards)" |
| `dev_radius_widget` (DEBUG-only) | "Contenedor de widget iOS 26 (oficial)" | "iOS 26 widget container (official)" |
| `dev_density_compact` (DEBUG-only) | "Compacto" | "Compact" |
| `dev_density_regular` (DEBUG-only) | "Regular (actual)" | "Regular (current)" |
| `dev_density_large` (DEBUG-only) | "Grande" | "Large" |
| `dev_cards_radius_section` (DEBUG-only) | "Radio" | "Radius" |
| `dev_cards_density_section` (DEBUG-only) | "Tamaño/densidad" | "Size/density" |
| `dev_cards_large_radius_section` (DEBUG-only) | "Radio grande (padding 24pt)" | "Large radius (24pt padding)" |
| `dev_cards_title` (DEBUG-only) | "Cards" (ya en inglés) | "Cards" |
| `dev_vibrations_impact_section` (DEBUG-only) | "Impact" (ya en inglés) | "Impact" |
| `dev_vibrations_notification_section` (DEBUG-only) | "Notification" (ya en inglés) | "Notification" |
| `dev_vibrations_selection_section` (DEBUG-only) | "Selection" (ya en inglés) | "Selection" |
| `dev_vibrations_selection_row` (DEBUG-only) | "Selection Changed" (ya en inglés) | "Selection Changed" |
| `dev_vibrations_test_button` (DEBUG-only) | "Probar" | "Test" |
| `dev_vibrations_title` (DEBUG-only) | "Vibrations" (ya en inglés) | "Vibrations" |

*(Las claves `dev_*` son DEBUG-only — no salen en Release/TestFlight/App Store, pero igual conviene envolverlas: son la única superficie donde Woz/QA prueban con VoiceOver en otro idioma sin recompilar.)*

### 9 — Bloqueo / Sheets (LockView, BiometricLockStore, LineCaptureSheet, CreditCardPaymentsSheet, JumpSheet)

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `lock_title` | "Fintrol está bloqueado" | "Fintrol is locked" |
| `lock_subtitle` | "Autentica para ver tus montos" | "Authenticate to see your amounts" |
| `lock_auth_failed` | "No se pudo verificar tu identidad" | "We couldn't verify your identity" |
| `lock_auth_failed_a11y` | "Error: No se pudo verificar tu identidad" | "Error: we couldn't verify your identity" |
| `lock_retry_button` | "Reintentar" | "Retry" |
| `lock_unlock_button` | "Desbloquear" | "Unlock" |
| `lock_biometric_prompt_reason` | "Autentica para ver tu presupuesto" | "Authenticate to see your budget" |
| `capture_add_income_title` | "Agregar ingreso" **[= period_add_income_a11y, distinto contexto: título de navegación]** | "Add income" |
| `capture_add_expense_title` | "Agregar gasto" **[= period_add_expense_a11y]** | "Add expense" |
| `capture_carry_over_title` | "Latest Month" (ya en inglés) | "Latest Month" |
| `capture_edit_line_title` | "Editar línea" | "Edit line" |
| `capture_description_label` **[= field_description]** | "Descripción" | "Description" |
| `capture_description_placeholder` **[= field_description]** | "Descripción" | "Description" |
| `capture_carry_over_hint` | "No se puede editar porque es arrastrado del mes anterior" | "Can't be edited because it's carried over from last period" |
| `capture_amount_label` **[= field_amount]** | "Monto" | "Amount" |
| `capture_origin_recurring` | "Generado por: recurrente" | "Generated by: recurring" |
| `capture_origin_service` | "Generado por: servicio del hogar" | "Generated by: home service" |
| `capture_origin_subscription` | "Generado por: suscripción" | "Generated by: subscription" |
| `capture_origin_loan` | "Generado por: préstamo" | "Generated by: loan" |
| `capture_origin_investment` | "Generado por: inversión" | "Generated by: investment" |
| `capture_origin_carry_over` | "Generado por: quincena anterior" | "Generated by: last period" |
| `capture_origin_credit_card` | "Generado por: tarjeta de crédito" | "Generated by: credit card" |
| `capture_validation_error` | "Escribe una descripción y un monto mayor a 0" | "Enter a description and an amount greater than 0" |
| `capture_cancel_button` **[= action_cancel]** | "Cancelar" | "Cancel" |
| `capture_done_button` | "Listo" **[compartida con cc_payments_done_button]** | "Done" |
| `cc_payments_sheet_title` **[= period_credit_cards_row_title]** | "Credit Cards Payments" (ya en inglés) | "Credit Cards Payments" |
| `cc_payments_suggested` | "Sugerido: %@" | "Suggested: %@" |
| `cc_payments_total` | "Total" (ya en inglés) | "Total" |
| `cc_payments_done_button` **[= capture_done_button]** | "Listo" | "Done" |
| `jump_sheet_title` | "Ir a quincena" | "Jump to period" |
| `jump_sheet_year_label` | "Año" **[= overview_year_picker_label]** | "Year" |
| `jump_sheet_year_a11y_hint` | "Elige el año de la quincena" | "Choose the period's year" |
| `jump_sheet_month_label` | "Mes" | "Month" |
| `jump_sheet_month_a11y_hint` | "Elige el mes de la quincena" | "Choose the period's month" |
| `jump_sheet_half_label` | "Quincena" | "Period" |
| `jump_sheet_half_first` **[= overview_row_half_first]** | "1–15" | "1–15" |
| `jump_sheet_half_second` **[= overview_row_half_second/inv_period_half_second]** | "16–fin" | "16–end" |
| `jump_sheet_half_a11y_hint` | "Elige la primera o segunda quincena del mes" | "Choose the first or second half of the month" |
| `jump_sheet_today_button` | "Hoy" | "Today" |
| `jump_sheet_today_a11y` | "Ir a hoy" | "Go to today" |
| `jump_sheet_go_button` | "Ir" | "Go" |
| `jump_sheet_go_a11y` | "Ir a %@ %d, quincena %@" | "Go to %@ %d, period %@" |

### RootView / FintrolSection / FintrolTab (navegación macOS/iOS)

| Clave | Español original | Inglés propuesto |
|---|---|---|
| `nav_period` **[= título ya existe como "" en PeriodView, este es el de sidebar/tab]** | "Quincena" | "Period" |
| `nav_recurring_income` **[= hub_row_recurring_income]** | "Ingresos recurrentes" | "Recurring income" |
| `nav_recurring_expense` **[= hub_row_recurring_expense]** | "Gastos recurrentes" | "Recurring expenses" |
| `nav_services` **[= services_title]** | "Servicios" | "Services" |
| `nav_subscriptions` **[= subscriptions_title]** | "Suscripciones" | "Subscriptions" |
| `nav_loans` **[= loans_title]** | "Préstamos" | "Loans" |
| `nav_credit_cards` **[= cc_title]** | "Credit Cards" | "Credit Cards" |
| `nav_investments` **[= inv_title]** | "Inversiones" | "Investments" |
| `nav_overview` **[= overview_title]** | "Overview" | "Overview" |
| `nav_recurring_hub` **[= hub_title]** | "Recurrentes y pagos" | "Recurring & Payments" |
| `nav_settings` **[= settings_title]** | "Ajustes" | "Settings" |
| `mac_sidebar_app_title` | "Fintrol" (nombre propio) | "Fintrol" |

---

## Conteo

- **~340 strings** hardcodeados en `Features/` y `UI/`, cubriendo las 9 pantallas de prioridad (Quincena, Hub, Préstamos, Tarjetas, Inversiones, Recurrentes/Servicios/Suscripciones, Overview, Ajustes, Bloqueo/Sheets) más navegación (`RootView`).
- De esos, **~60 claves son compartidas** entre 2+ pantallas (Cancelar/Guardar/Editar/Eliminar/Fecha/Pago/Moneda/etc.) — el catálogo final tendrá menos entradas que la tabla porque cada fila "**[compartida]**" es una sola clave reutilizada, no una nueva.
- **4 grupos de plurales** (🔢) necesitan variantes `one`/`other`, no un solo valor.
- **2 enums persistidos** (`HomeServiceCategory`, `SubscriptionCategory`) exponen su `rawValue` directo como texto de UI — requieren una capa `displayName` antes de poder localizarse, sin tocar el `rawValue` almacenado.

---

## Configuración de Xcode

- [ ] Project → Info → Localizations: agregar inglés como `sourceLanguage` (ninguno agregado hoy)
- [ ] `Localizable.xcstrings` creado y en el target
- [ ] `InfoPlist.xcstrings` — revisar si hay `NSFaceIDUsageDescription`/otros usage strings en el Info.plist antes de dar por cerrada esta fase (no estaba en el alcance de `Features/`/`UI/`, pendiente para Woz al implementar)
- [ ] Pseudo-localización ejecutada — 0 strings hardcodeados (pendiente hasta que exista el catálogo)

---

## Loop de fix

```
Kim (L10N_AUDIT.md) ← estamos aquí
→ Woz (crea Localizable.xcstrings vía Xcode 27 MCP, envuelve cada string con String(localized:)
   usando las claves de este documento, resuelve L-002 con `displayName` computado)
→ Kim (re-verifica: 0 strings hardcodeados, StringCatalogContext confirma comment en cada clave)
→ Jonny (si hay ajustes de layout por expansión de texto — bajo riesgo según L-007, pero confirmar
   visualmente con pseudo-localización)
→ Phil (localización de App Store Connect, cuando aplique)
```

---

## Decisiones cerradas (aprobadas por Steve, sin preguntas abiertas)

1. "Sobrante" → "Surplus", "Mandar" → "To Send".
2. "quincena" → "period" en todo el texto de producto.
3. Placeholder de brokers en Inversiones generalizado a nombres angloparlantes ("Fidelity, Vanguard, Robinhood…").

Tabla lista para que Woz implemente tal cual — sin dudas pendientes.
