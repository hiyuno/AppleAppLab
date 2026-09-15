# A11Y_AUDIT — Fintrol v1
> Auditoría de accesibilidad integral. Fecha: 2026-09-15  
> Auditor: Sarah, especialista en accesibilidad del equipo AppleAppLab  
> Destinatario: Woz (implementación de fixes)

---

## Resumen ejecutivo

**Total de hallazgos:** 29 (v1: 23 + v2: 6 nuevos)  
**Bloqueantes:** 5  
**Altos:** 10 (+4 en v2: Loans, Investments, Settings)  
**Medios:** 9 (+1 en v2)  
**Bajos:** 5 (+1 en v2)

**v1 (Initial audit):** Deficiencias críticas en componentes custom (SobranteBadge, LineItemRow, SummaryPanel, LockView) — falta de labels, values, Reduce Motion, Reduce Transparency. Naranja sobre Frost cae por debajo de WCAG AA. Dynamic Type no probado en AX5+.

**v2 (Post-DragGesture):** LineItemRow ahora implementa swipe leading/trailing con accesibilidad completa (`.accessibilityActions`, `.accessibilityValue`, `originLabel`). Nuevas pantallas (Loans "Hasta liquidar", Investments, Settings Exportar/Importar) descubren 6 hallazgos de a11y en avisos naranja, botones, y confirmaciones destructivas sin labels accesibles.

---

## Hallazgos por severidad

### 🔴 BLOQUEANTES (debe fixear antes de release)

#### 1. SobranteBadge — Sin `.accessibilityValue()` para comunicar estado
**Archivo:** `/Apps/Fintrol/Fintrol/UI/SobranteBadge.swift:44-46`  
**Problema:** El label dice "Sobrante: $XXX" pero NO comunica el estado (positivo/ajustado/negativo) ni el riesgo financiero. VoiceOver no anuncia que -$320 está en rojo y es negativo — solo lee el número.

**Impacto:** Usuarios con discapacidad visual no saben si están en verde ($100+), amarillo ($0-$99.99) o rojo (<$0) sin una pista visual de color.

**Fix exacto:**
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Sobrante")
.accessibilityValue("""
\(sobrante.currencyString()), \(statusText)
""")

private var statusText: String {
    switch status {
    case .positive: return "positivo, verde"
    case .adjusted: return "ajustado, amarillo"
    case .negative: return "negativo, rojo"
    }
}
```

---

#### 2. SobranteBadge — Animación NO respeta Reduce Motion
**Archivo:** `/Apps/Fintrol/Fintrol/UI/SobranteBadge.swift:43`  
**Problema:** `.animation(.smooth(duration: 0.3), value: sobrante)` se ejecuta siempre, incluso si el usuario tiene `Reduce Motion` activado (Configuración > Accesibilidad > Movimiento).

**Impacto:** Usuarios con problemas vestibulares, migrañas o fotosensibilidad ven animaciones que pueden causarles mareo o malestar.

**Fix exacto:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

private var animation: Animation? {
    reduceMotion ? .none : .smooth(duration: 0.3)
}

var body: some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("SOBRANTE")
            .font(.caption2)
            .tracking(1.2)
            .foregroundStyle(.secondary)

        Text(sobrante.currencyString())
            .font(.system(size: 44, weight: .bold, design: .default))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .contentTransition(.numericText(value: Double(truncating: sobrante as NSDecimalNumber)))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(color.opacity(0.12))
    )
    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    .animation(animation, value: sobrante)  // <-- cambiado aquí
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Sobrante")
    .accessibilityValue("\(sobrante.currencyString()), \(statusText)")
}
```

---

#### 3. LineItemRow — Icono de origen SIN label accesible
**Archivo:** `/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:49-52`  
**Problema:** El icono `Image(systemName: originIcon)` (repeat, pencil, arrow) es el ÚNICO indicador visual de que una línea es recurrente, suscripción o carry-over. VoiceOver lo omite o solo dice "icono".

**Impacto:** Usuarios con discapacidad visual no saben si una línea es manual, recurrente, o arrastrada del mes anterior — deben depender puramente del color del icono (que es `.secondary`).

**Fix exacto:**
```swift
private var originLabel: String? {
    switch line.origin {
    case .manual: return nil
    case .recurring: return line.isManuallyEdited ? "editado manualmente" : "recurrente"
    case .subscription: return "suscripción"
    case .carryOver: return "arrastrado del mes anterior"
    }
}

if let originIcon {
    Image(systemName: originIcon)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .accessibilityLabel(originLabel)  // <-- agregar
        .accessibilityHidden(originLabel == nil)  // <-- ocultar si no hay label
}
```

---

#### 4. LineItemRow — Toggle "Pagado" sin `.accessibilityValue()`
**Archivo:** `/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:45-47`  
**Problema:** `LabToggleRow(title: "Pagado", ...)` con `.labelsHidden()` hace que VoiceOver no anuncie si la línea está pagada o no. El toggle es accesible (es del sistema), pero el estado no se comunica.

**Impacto:** VoiceOver solo anuncia "toggle" sin indicar si está ON u OFF.

**Fix exacto:**
```swift
LabToggleRow(title: "Pagado", isOn: $line.isPaid, config: PatternConfig(accentColor: .accentColor))
    .labelsHidden()
    .frame(width: 22)
    .accessibilityLabel("Pagado")
    .accessibilityValue(line.isPaid ? "activado" : "desactivado")
```

---

#### 5. LockView — Sin foco inicial para Voice Control / Switch Control en macOS
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Lock/LockView.swift:46-55`  
**Problema:** El botón "Desbloquear"/"Reintentar" no tiene `.focused()` declarado. En macOS con Voice Control o Switch Control, el usuario no sabe dónde está el foco inicial — debe navegar con Tab hasta encontrar el botón.

**Impacto:** En Switch Control (que solo puede navegar elementos enfocables), no está claro cuál es el primer elemento enfocable. Se requiere `.focused(_:equals:)` + `@FocusState`.

**Fix exacto:**
```swift
@FocusState private var iButtonFocused: Bool

var body: some View {
    ZStack {
        Color("AppBackground").ignoresSafeArea()

        VStack(spacing: 20) {
            Image(systemName: biometryIcon)
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityLabel(biometryLabel)  // +1 fix menor abajo

            Text("Fintrol está bloqueado")
                .font(.title2.weight(.semibold))

            Text("Autentica para ver tus montos")
                .font(.body)
                .foregroundStyle(.secondary)

            if store.lastAuthenticationFailed {
                Text("No se pudo verificar tu identidad")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: No se pudo verificar tu identidad")  // +2 fix menor
            }

            Button {
                Task { await store.authenticate() }
            } label: {
                Text(store.lastAuthenticationFailed ? "Reintentar" : "Desbloquear")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .focused($iButtonFocused)  // <-- agregar aquí
            .onAppear {
                iButtonFocused = true  // <-- establecer foco inicial
            }
        }
        .padding()
    }
    .task {
        await store.authenticate()
    }
}

private var biometryLabel: String {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    switch context.biometryType {
    case .faceID: return "Face ID"
    case .touchID: return "Touch ID"
    default: return "Bloqueo de seguridad"
    }
}
```

---

### 🟡 ALTOS (debe fixear en este ciclo)

#### 6. SummaryPanel — Contraste desconocido sobre Frost translúcido
**Archivo:** `/Apps/Fintrol/Fintrol/UI/SummaryPanel.swift:40-43`  
**Problema:** `.ultraThinMaterial.opacity(0.5)` es Frost translúcido. El ratio de contraste del texto sobre este material depende de qué hay detrás (pared, contenido, etc.). Según DESIGN_LIQUID.md, **el naranja `#F04200` sobre gris `#323232` da ~3.4:1**, que pasa AA solo para UI grandes (≥17pt). Pero sobre el material translúcido, el contraste real es incierto y probablemente FALLA.

**Impacto:** Textos como "Tipo de cambio" (caption/subheadline) sobre Frost pueden caer por debajo de 3:1 en contraste, fallando WCAG AA.

**Fix exacto:** Verifica el contraste real con una herramienta (Accessibility Inspector en Xcode con RenderPreview override de `.regularMaterial`). Si falla:
```swift
// Fallback a fondo sólido cuando el usuario activa "Aumentar contraste"
@Environment(\.legibilityWeight) var legibilityWeight

var body: some View {
    VStack(alignment: .leading, spacing: 14) {
        row(title: "Mandar", value: mandar.currencyString() + " USD")
        // ... resto

    }
    .padding(16)
    .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(legibilityWeight == .bold ? Color("AppBackgroundSecondary") : .ultraThinMaterial.opacity(0.5))
    )
}
```

---

#### 7. PeriodView header — Botones de navegación SIN `.accessibilityLabel()`
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Period/PeriodView.swift:109-150`  
**Problema:** `Button { ... } label: { Image(systemName: "chevron.left") }` sin `.accessibilityLabel()`. VoiceOver solo dice "botón" sin indicar que es "anterior" o "siguiente".

**Impacto:** Usuarios de VoiceOver no saben si están navegando hacia atrás o adelante en las quincenas.

**Fix exacto:**
```swift
HStack {
    Button {
        coordinate = coordinate.previous
        loadPeriod()
    } label: {
        Image(systemName: "chevron.left")
    }
    .accessibilityLabel("Quincena anterior")  // <-- agregar
    .disabled(coordinate <= earliestCoordinate)

    Spacer()

    VStack(spacing: 2) {
        Button {
            showJumpSheet = true
        } label: {
            Text(titleText)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fecha: \(titleText)")  // <-- agregar hint
        .accessibilityHint("Toca para saltar a otra quincena")  // <-- agregar

        if coordinate == todayCoordinate {
            Text("Hoy")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                .accessibilityHidden(true)  // <-- es decorativo, ocultar
        } else if coordinate > todayCoordinate {
            Text("Proyección")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(.secondary.opacity(0.15)))
                .accessibilityHidden(true)  // <-- es decorativo, ocultar
        }
    }

    Spacer()

    Button {
        coordinate = coordinate.next
        loadPeriod()
    } label: {
        Image(systemName: "chevron.right")
    }
    .accessibilityLabel("Quincena siguiente")  // <-- agregar
}
```

---

#### 8. PeriodView — Botón "Agregar ingreso/gasto" SIN `.accessibilityLabel()`
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Period/PeriodView.swift:216-229`  
**Problema:** `Image(systemName: "plus.circle")` en el botón de captura no tiene label. El texto "Agregar ingreso" está ahí pero VoiceOver puede no combinarlo correctamente.

**Fix exacto:**
```swift
private func captureRow(kind: LineKind) -> some View {
    Button {
        addLine(kind: kind)
    } label: {
        HStack {
            Image(systemName: "plus.circle")
            Text(kind == .income ? "Agregar ingreso" : "Agregar gasto")
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(kind == .income ? "Agregar ingreso" : "Agregar gasto")  // <-- agregar
}
```

---

#### 9. LineItemRow — Acción de tap SIN `.accessibilityAction()`
**Archivo:** `/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:73-74`  
**Problema:** `.onTapGesture { onStartEditing() }` es accesible (el elemento es interactivo), pero no hay `.accessibilityAction()` que lo declare como una acción "Editar" específica para Switch Control / Voice Control.

**Fix exacto:**
```swift
.contentShape(Rectangle())
.onTapGesture { onStartEditing() }
.accessibilityAction(named: "Editar") { onStartEditing() }  // <-- agregar
.swipeActions(edge: .trailing) {
    if line.origin == .manual, let onDelete {
        Button(role: .destructive, action: onDelete) {
            Label("Eliminar", systemImage: "trash")
        }
    }
}
```

---

#### 10. SummaryPanel — Botón "Editar" probablemente < 44×44pt
**Archivo:** `/Apps/Fintrol/Fintrol/UI/SummaryPanel.swift:30`  
**Problema:** `Button("Editar", action: onEditRate)` con `.buttonStyle(.borderless)` y `.font(.caption)` probablemente no alcanza 44×44pt, fallando el tap target mínimo motor.

**Impacto:** Usuarios con discapacidad motora pueden no poder presionar el botón con precisión.

**Fix exacto:**
```swift
HStack {
    VStack(alignment: .leading, spacing: 2) {
        Text("Tipo de cambio")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        Text(exchangeRate.map { $0.twoDecimalString } ?? "—")
            .font(.body.weight(.semibold))
            .monospacedDigit()
        if isRateStale {
            Text("Usando el último conocido")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    Spacer()
    Button("Editar", action: onEditRate)
        .font(.body)  // <-- cambiar de .caption a .body
        .padding(.vertical, 8)  // <-- asegurar ≥44pt de alto
        .padding(.horizontal, 12)  // <-- asegurar ≥44pt de ancho
        .accessibilityLabel("Editar tipo de cambio")  // <-- agregar label
}
```

---

### 🔵 MEDIOS (debe fixear en próximo sprint)

#### 11. PeriodView — Sin verificación de Dynamic Type AX5+
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Period/PeriodView.swift`  
**Problema:** La pantalla no se ha probado con Dynamic Type en tamaños Accessibility Large (AX4) o más grandes. Con AX5 (XXL), es probable que:
- El badge de sobrante (44pt) se expanda y salga de la pantalla
- Las filas de líneas se vuelvan muy altas y requieran scroll vertical innecesario
- El layout de macOS (HStack al lado del panel) se colapse

**Impacto:** Usuarios con baja visión que necesitan texto muy grande ven la app rota o deben scrollear más de lo esperado.

**Fix:** Prueba con Xcode Simulator + Configuración > Accesibilidad > Pantalla y tamaño de texto = AX5 (Accessibility Extra Large). Luego:
- Reduce el tamaño base del sobrante a 32pt o hazlo escalar con `@ScaledMetric`
- Usa `VStack` condicional en iOS cuando el DynamicTypeSize es muy grande
- En macOS, cambia a `VStack` en lugar de `HStack` cuando AX5+

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var isLargeAccessibilitySize: Bool {
    dynamicTypeSize >= .accessibility1  // AX4, AX5, AX6, AX7
}

// En PeriodView content:
if isLargeAccessibilitySize {
    VStack(spacing: 24) {
        blocks
        SobranteBadge(sobrante: sobrante)
        summaryPanel
    }
} else {
    #if os(macOS)
    HStack(alignment: .top, spacing: 20) {
        VStack(spacing: 24) {
            blocks
            SobranteBadge(sobrante: sobrante)
        }
        summaryPanel
            .frame(width: 280)
    }
    #else
    VStack(spacing: 24) {
        blocks
        SobranteBadge(sobrante: sobrante)
        summaryPanel
    }
    #endif
}
```

---

#### 12. SobranteBadge — Sin respeto a Reduce Transparency
**Archivo:** `/Apps/Fintrol/Fintrol/UI/SobranteBadge.swift:38-41`  
**Problema:** `.shadow(...)` y el fondo con `.opacity(0.12)` se aplican siempre. Si el usuario activa "Reducir transparencia" (Configuración > Accesibilidad > Pantalla), el componente debe usar fondo sólido en lugar de translúcido.

**Impacto:** Usuarios que necesitan reducir transparencia (p. ej., con fotosensibilidad) ven efectos visuales que no necesitan.

**Fix exacto:**
```swift
@Environment(\.accessibilityShowButtonShapes) var showButtonShapes
@Environment(\.reduce Motion) var reduceTransparency  // Nota: este es @Environment(\.reduceTransparency) en iOS 17+, pero puede variar en 26

var body: some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("SOBRANTE")
            .font(.caption2)
            .tracking(1.2)
            .foregroundStyle(.secondary)

        Text(sobrante.currencyString())
            .font(.system(size: 44, weight: .bold, design: .default))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .contentTransition(.numericText(value: Double(truncating: sobrante as NSDecimalNumber)))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(color.opacity(0.12))
    )
    .shadow(color: .black.opacity(showButtonShapes ? 0.12 : 0.08), radius: 8, x: 0, y: 2)  // aumentar opacidad si se pide contraste alto
    .animation(animation, value: sobrante)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Sobrante")
    .accessibilityValue("\(sobrante.currencyString()), \(statusText)")
}
```

---

#### 13. LineItemRow — Stripe deshabilitado en modo edición SIN feedback accesible
**Archivo:** `/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:112, 120`  
**Problema:** `.disabled(line.origin == .carryOver)` en los campos de monto y moneda en modo edición. VoiceOver anunciará "deshabilitado" pero sin contexto de POR QUÉ. El usuario no entiende por qué no puede editar una línea arrastrada.

**Fix exacto:**
```swift
TextField("Monto", value: $line.amount, format: .number.precision(.fractionLength(2)))
    #if os(iOS)
    .keyboardType(.decimalPad)
    #endif
    .textFieldStyle(.roundedBorder)
    .disabled(line.origin == .carryOver)
    .accessibilityHint(line.origin == .carryOver ? "No se puede editar porque es arrastrado del mes anterior" : nil)  // <-- agregar

Picker("Moneda", selection: $line.currency)
    // ...
    .disabled(line.origin == .carryOver)
    .accessibilityHint(line.origin == .carryOver ? "No se puede cambiar porque es arrastrado del mes anterior" : nil)  // <-- agregar
```

---

#### 14. PeriodView — Bloques INCOME/EXPENSES SIN `.accessibilityElement(children: .combine)`
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Period/PeriodView.swift:166-214`  
**Problema:** El bloque de líneas (VStack de ForEach(lines)) no está agrupado como un elemento accesible lógico. VoiceOver navega cada línea por separado, lo que es correcto, pero falta un label de sección que diga "INCOME" o "EXPENSES".

**Fix exacto:**
```swift
private func lineBlock(title: String, kind: LineKind) -> some View {
    let lines = (period?.lineItems ?? [])
        .filter { $0.kind == kind }
        .sorted { $0.sortOrder < $1.sortOrder }

    return VStack(alignment: .leading, spacing: 4) {
        HStack {
            Text(title)
                .font(.headline)
                .tracking(0.5)
                .textCase(.uppercase)
            Spacer()
        }
        .accessibilityHidden(true)  // <-- el VStack exterior lo comunica, esto es decorativo

        VStack(spacing: 0) {
            ForEach(lines) { line in
                LineItemRow(
                    line: line,
                    exchangeRate: effectiveRate,
                    isEditing: editingLineID == line.id,
                    onStartEditing: { editingLineID = line.id },
                    onCommit: { commitEdit() },
                    onDelete: line.origin == .manual ? { deleteLine(line) } : nil
                )
                if line.id != lines.last?.id {
                    Divider()
                }
            }

            captureRow(kind: kind)
        }

        Divider().frame(height: 2).overlay(Color.secondary)

        HStack {
            Text(kind == .income ? "TOTAL INCOME" : "TOTAL EXPENSES")
                .font(.title3.weight(.semibold))
            Spacer()
            Text(total(for: kind).currencyString())
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }
    .padding(16)
    .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.5))
    )
    .accessibilityElement(children: .contain)  // <-- agrupar el bloque completo
    .accessibilityLabel(kind == .income ? "Ingresos" : "Gastos")  // <-- label de sección
}
```

---

#### 15. JumpSheet — Pickers SIN `.accessibilityHint()`
**Archivo:** `/Apps/Fintrol/Fintrol/UI/JumpSheet.swift:32-44`  
**Problema:** Los Pickers para Año, Mes, Quincena no tienen hints que expliquen su propósito. VoiceOver solo dice "Picker, Año" sin contexto.

**Fix exacto:**
```swift
Picker("Año", selection: $year) {
    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
}
.accessibilityHint("Elige el año de la quincena")  // <-- agregar

Picker("Mes", selection: $month) {
    ForEach(1...12, id: \.self) { month in
        Text(Calendar.gregorianUTC.monthSymbols[month - 1].capitalized).tag(month)
    }
}
.accessibilityHint("Elige el mes de la quincena")  // <-- agregar

Picker("Quincena", selection: $half) {
    Text("1–15").tag(PeriodHalf.first)
    Text("16–fin").tag(PeriodHalf.second)
}
.pickerStyle(.segmented)
.accessibilityHint("Elige la primera o segunda quincena del mes")  // <-- agregar
```

---

#### 16. LineItemRow — Swipe-to-delete SIN alternativa de teclado en macOS
**Archivo:** `/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:75-81`  
**Problema:** `.swipeActions()` solo funciona en iOS. En macOS, no hay alternativa de teclado (Suprimir) o menú contextual para borrar la línea. El usuario debe usar el contextMenu, que no es accesible vía teclado sin Voice Control.

**Impacto:** En macOS, Switch Control no puede acceder a la acción de eliminar sin Voice Control.

**Fix exacto:**
```swift
private var displayRow: some View {
    HStack(spacing: 10) {
        // ... componentes ...
    }
    .contentShape(Rectangle())
    .onTapGesture { onStartEditing() }
    .accessibilityAction(named: "Editar") { onStartEditing() }
    #if os(iOS)
    .swipeActions(edge: .trailing) {
        if line.origin == .manual, let onDelete {
            Button(role: .destructive, action: onDelete) {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
    #endif
    .contextMenu {
        Button("Editar", systemImage: "pencil", action: onStartEditing)
        Button(line.currency == .usd ? "Cambiar a MXN" : "Cambiar a USD") {
            line.currency = line.currency == .usd ? .mxn : .usd
            line.isManuallyEdited = line.origin != .manual ? true : line.isManuallyEdited
            onCommit()
        }
        if line.origin == .manual, let onDelete {
            Button("Eliminar", systemImage: "trash", role: .destructive) {
                // En macOS, agregar atajos de teclado para accesibilidad
                #if os(macOS)
                NSApp.keyWindow?.makeFirstResponder(nil)
                #endif
                onDelete()
            }
        }
    }
    #if os(macOS)
    .keyboardShortcut(.delete, modifiers: [.command, .shift])  // Cmd+Shift+Delete para eliminar, si es contexto correcto
    #endif
}
```

---

### 🟢 BAJOS (considerar para mejora continua)

#### 17. PeriodView — Mensaje de carga sin `.accessibilityLabel()`
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Period/PeriodView.swift:44-48`  
**Problema:** El `loadingSkeleton` usa `.redacted(reason: .placeholder)` que es accesible, pero sin etiqueta de contexto. VoiceOver solo dice "rectángulo redondeado".

**Fix:** Agregar label al VStack:
```swift
private var loadingSkeleton: some View {
    VStack(spacing: 24) {
        ForEach(0..<2, id: \.self) { _ in
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8).fill(.quaternary).frame(height: 44)
                }
            }
            .padding()
            .redacted(reason: .placeholder)
        }
    }
    .padding(16)
    .accessibilityLabel("Cargando quincena")  // <-- agregar
}
```

---

#### 18. SummaryPanel — "Usando el último conocido" SIN contexto accesible
**Archivo:** `/Apps/Fintrol/Fintrol/UI/SummaryPanel.swift:23-27`  
**Problema:** El texto rojo "Usando el último conocido" solo aparece si `isRateStale` es true, pero sin `.accessibilityLabel()` que lo comunique como advertencia.

**Fix:**
```swift
if isRateStale {
    Text("Usando el último conocido")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Advertencia: usando tipo de cambio anterior")  // <-- agregar
}
```

---

#### 19. LineItemRow — "Cambiar a MXN/USD" SIN feedback de cambio
**Archivo:** `/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:84-88`  
**Problema:** Al pulsar la opción de context menu, la moneda cambia pero no hay `.accessibilityAnnouncement()` que confirme el cambio a VoiceOver.

**Fix:**
```swift
Button(line.currency == .usd ? "Cambiar a MXN" : "Cambiar a USD") {
    line.currency = line.currency == .usd ? .mxn : .usd
    line.isManuallyEdited = line.origin != .manual ? true : line.isManuallyEdited
    onCommit()
    // Anunciar el cambio a VoiceOver
    #if os(iOS)
    UIAccessibility.post(notification: .announcement, argument: "Moneda cambiada a \(line.currency == .usd ? "USD" : "MXN")")
    #endif
}
```

---

#### 20. LockView — Icono biométrico SIN `.accessibilityHidden()` correcto
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Lock/LockView.swift:25-28`  
**Problema:** El icono se anuncia como "imagen, faceid" o "imagen, touchid", pero sin label descriptivo. Es decorativo + informativo, así que debería ser oculto (ya que el texto siguiente lo explica).

**Fix:** El icono debe estar `.accessibilityHidden(true)` porque los textos abajo ("Fintrol está bloqueado", "Autentica...") ya lo comunican.

```swift
Image(systemName: biometryIcon)
    .font(.system(size: 80))
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(.secondary)
    .accessibilityHidden(true)  // <-- agregar (es decorativo)
```

---

#### 21. JumpSheet — Botón "Ir" / "Hoy" SIN confirmar acción
**Archivo:** `/Apps/Fintrol/Fintrol/UI/JumpSheet.swift:46-64`  
**Problema:** Los botones son accesibles (del sistema), pero sin `.accessibilityLabel()` que confirme la acción.

**Fix:**
```swift
Button("Hoy") {
    onToday()
    dismiss()
}
.accessibilityLabel("Ir a hoy")  // <-- agregar

// ToolbarItem confirmationAction
Button("Ir") {
    onJump(PeriodCoordinate(year: year, month: month, half: half))
    dismiss()
}
.accessibilityLabel("Ir a \(monthName) \(year), quincena \(half == .first ? "1" : "2")")  // <-- agregar contexto dinámico
```

---

#### 22. SummaryPanel — Panel sin `.accessibilityElement(children: .contain)`
**Archivo:** `/Apps/Fintrol/Fintrol/UI/SummaryPanel.swift:11-44`  
**Problema:** El panel es un VStack de filas, pero sin agrupar como un elemento accesible lógico de "Resumen". VoiceOver navega fila por fila sin contexto.

**Fix:**
```swift
var body: some View {
    VStack(alignment: .leading, spacing: 14) {
        row(title: "Mandar", value: mandar.currencyString() + " USD")
        // ... resto ...
    }
    .padding(16)
    .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.5))
    )
    .accessibilityElement(children: .contain)  // <-- agrupar
    .accessibilityLabel("Panel de resumen")  // <-- label
}
```

---

#### 23. PeriodView — Forma condicional de layout SIN `.accessibilityLabel()`
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Period/PeriodView.swift:81-94`  
**Problema:** En macOS, el layout es `HStack` (lado a lado), pero en iOS es `VStack` (apilado). Sin `.accessibilityLabel()`, VoiceOver no sabe si está mirando un "layout de dos columnas" o "una columna".

**Fix:** No es crítico, pero se puede mejorar indicando la estructura:
```swift
#if os(macOS)
HStack(alignment: .top, spacing: 20) {
    VStack(spacing: 24) {
        blocks
        SobranteBadge(sobrante: sobrante)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Columna de ingresos y gastos")
    
    summaryPanel
        .frame(width: 280)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Columna de resumen")
}
.accessibilityElement(children: .contain)
.accessibilityLabel("Diseño de dos columnas")
```

---

## Matriz de severidad vs. área

| Área | Bloqueante | Alto | Medio | Bajo |
|------|-----------|------|-------|------|
| SobranteBadge | 2 | 1 | 1 | 0 |
| LineItemRow | 2 | 2 | 2 | 1 |
| SummaryPanel | 0 | 2 | 0 | 1 |
| PeriodView | 0 | 2 | 2 | 1 |
| LockView | 1 | 0 | 0 | 1 |
| JumpSheet | 0 | 0 | 1 | 1 |

---

## Checklist de prueba — antes de merge

### VoiceOver (obligatorio)
- [ ] Habilitar VoiceOver en Simulator: `Cmd+F5` (iOS) o Configuración > Accesibilidad > VoiceOver
- [ ] Navegar cada pantalla con swipes: líneas de ingreso/gasto, sobrante, panel de resumen, botones
- [ ] Verificar que cada acción anuncie claramente (ej: "Pagado, activado" cuando es true)
- [ ] Verificar que sobrante diga "Sobrante: $XXX, positivo, verde" (o ajustado/negativo)
- [ ] Verificar botones de navegación: "Quincena anterior", "Ir a", "Quincena siguiente"

### Reduce Motion (obligatorio)
- [ ] Habilitar en Configuración > Accesibilidad > Movimiento > Reducir movimiento
- [ ] Cambiar el sobrante y verificar que NO se anima (solo cross-fade instantáneo)

### Reduce Transparency (obligatorio)
- [ ] Habilitar en Configuración > Accesibilidad > Pantalla > Aumentar contraste
- [ ] Verificar que Frost se vuelve sólido o que el contraste mejora

### Dynamic Type (obligatorio)
- [ ] Configurar a Accessibility Large (AX5, tamaño XXL)
- [ ] Verificar que la pantalla de quincena sigue siendo navegable sin texto truncado
- [ ] Verificar que el sobrante no se sale de la pantalla

### Contraste (verificar con Accessibility Inspector)
- [ ] Naranja sobre gris: debe ser ≥3:1 (está en ~3.4:1, OK para UI grande)
- [ ] Naranja sobre Frost: debe ser ≥3:1 (verificar con RenderPreview)
- [ ] Textos sobre Frost: deben ser ≥4.5:1

### Motor / Keyboard en macOS
- [ ] Habilitar Voice Control o Switch Control
- [ ] Navegar menús y filas con Tab
- [ ] Eliminar línea manual debe ser accesible vía teclado o Voice Control

### Pantalla de bloqueo
- [ ] Verificar que el botón "Desbloquear" tiene foco inicial
- [ ] En Voice Control, debe poder decir "Tap Desbloquear" sin navegar primero

---

---

## Revisión incremental — Post-DragGesture (v2, 2026-09-15)

**LineItemRow.swift (cambios implementados):**
✅ Línea 31: `@Environment(\.accessibilityReduceMotion)` cargado  
✅ Línea 62-74: `originLabel` con etiquetas ("recurrente", "suscripción", "préstamo", "inversión")  
✅ Línea 121: Settle animation respeta `reduceMotion`  
✅ Línea 164-172: `.accessibilityElement(children: .combine)`, `.accessibilityValue()`, `.accessibilityActions()` ("Activar/Desactivar", "Marcar/Desmarcar pagado")  
✅ Línea 223: `.strikethrough(!line.isActive)` previene opacidad como único indicador  
✅ Línea 236-237: Opacidad 0.4 + animación que respeta Reduce Motion  
✅ Línea 248-253: `accessibilityStateValue` anuncia "inactiva" y "pagada" por separado  
⚠️ **Línea 115-116:** DragGesture valida vertical drags, pero dos dedos de VoiceOver (swipe de exploración) pueden conflictuar — verificar en dispositivo real

**Nuevos hallazgos (pantallas nuevas):**

#### 24. LoansView — Aviso naranja SIN `.accessibilityLabel()`
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Loans/LoansView.swift:413-416`  
**Problema:** Préstamo "Hasta liquidar" con pago menor que interés mensual — solo visual naranja ("Este pago no cubre el interés..."). Sin `.accessibilityLabel()`, VoiceOver no anuncia advertencia.  
**Fix:** `.accessibilityLabel("Advertencia: pago insuficiente para cubrir interés mensual")`  
**Severidad:** 🟡 ALTO (es financiero e importante)

#### 25. LoansView — Botón "plus" SIN `.accessibilityLabel()`
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Loans/LoansView.swift:76`  
**Problema:** `Button { ... } label: { Image(systemName: "plus") }` sin label.  
**Fix:** `.accessibilityLabel("Agregar préstamo")`  
**Severidad:** 🟡 ALTO

#### 26. InvestmentsView — Botón "plus" y icono chart SIN labels
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Investments/InvestmentsView.swift:81, 94-96`  
**Problema:** Botón "plus" sin label, icono chart.line sin `.accessibilityLabel()` ni `.accessibilityHidden()`.  
**Fix:** Botón: `.accessibilityLabel("Agregar cuenta de inversiones")` — Icono: `.accessibilityHidden(true)` (es decorativo, el nombre la describe)  
**Severidad:** 🟡 ALTO

#### 27. InvestmentsView — Fila de inversión SIN `.accessibilityValue()`
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Investments/InvestmentsView.swift:186`  
**Problema:** `.accessibilityElement(children: .combine)` en línea 168-188, pero sin `.accessibilityValue()` que anuncie estado (desactivada/editada/proyectada).  
**Fix:** `.accessibilityValue(entry.line.isActive ? (entry.line.isManuallyEdited ? "editada" : "proyectada") : "desactivada")`  
**Severidad:** 🟡 ALTO

#### 28. SettingsView — Botón toggle "eye" (mostrar/ocultar token)
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Settings/SettingsView.swift:350`  
**Problema:** ✅ Ya tiene `.accessibilityLabel()` ("Ocultar token" / "Mostrar token"). No es hallazgo.  
**Severidad:** N/A

#### 29. SettingsView — confirmationDialog destructivo SIN contexto accesible
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Settings/SettingsView.swift:175-184`  
**Problema:** `confirmationDialog("Esto reemplaza TODOS los datos actuales...")` — el diálogo es accesible (del sistema), pero sin `.accessibilityLabel()` adicional que enfatice "DESTRUCTIVO".  
**Fix:** El título ya lo dice. VoiceOver lo anunciará. Sin acción requerida.  
**Severidad:** 🟢 BAJO (el sistema ya lo maneja)

#### 30. SettingsView — Mensajes de error/éxito de token SIN a11y
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Settings/SettingsView.swift:360-364`  
**Problema:** Texto de resultado en rojo o verde (línea 362-363) sin `.accessibilityLabel()`. VoiceOver lee el color, no el contexto.  
**Fix:** `.accessibilityLabel(tokenTestIsError ? "Error: " + tokenTestMessage : "Éxito: " + tokenTestMessage)`  
**Severidad:** 🟡 ALTO (es información crítica)

#### 31. SettingsView — Opacity 0.4 SIN texto alternativo
**Archivo:** `/Apps/Fintrol/Fintrol/Features/Settings/SettingsView.swift:119`  
**Problema:** Picker "Tiempo de re-bloqueo" con `.opacity(lockStore.isLockEnabled ? 1 : 0.4)`. La opacidad es el único indicador de que está deshabilitado.  
**Fix:** `.accessibilityHint(lockStore.isLockEnabled ? "" : "Disponible cuando Face ID/Touch ID esté habilitado")`  
**Severidad:** 🔵 MEDIO

**Resumen v2:**
- 6 nuevos hallazgos (todos en pantallas nuevas: Loans, Investments, Settings)
- 4 altos (avisos/botones/valores financieros sin labels)
- 1 medio (opacity sin hint)
- 1 bajo (confirmationDialog — ya manejado por sistema)
- 1 ya correcto (toggle eye button)

**Total acumulado:** 23 (v1) + 6 (v2) = **29 hallazgos** (5 bloqueantes, 10 altos, 9 medios, 5 bajos)

---

## Notas para Woz

1. **Prioridad 1 (Bloqueantes):** Los 5 problemas de accesibilidad bloqueante deben fijarse ANTES de cualquier release. Son deficiencias críticas que afectan a usuarios con discapacidades visuales, motoras o vestibulares.

2. **Prioridad 2 (Altos):** Los 6 hallazgos altos deben fijarse en este sprint. La mayoría son labels y hints faltantes (cambios de una línea).

3. **Prioridad 3 (Medios):** Los 8 medios pueden posponerse al próximo sprint, pero conviene hacerlos temprano (son mejoras que mejoran la experiencia significativamente para muchos usuarios).

4. **Prioridad 4 (Bajos):** Los 4 bajos son refinamientos. Considera hacerlos cuando haya tiempo de sobra.

5. **Testing obligatorio:** Todos los fixes deben ser probados manualmente con VoiceOver en Simulator (iOS) y en macOS. No hay automatización que valide VoiceOver en SwiftUI completamente.

6. **Contraste real:** El naranja #F04200 sobre gris #323232 está en 3.4:1, que pasa AA solo para UI grandes (≥17pt) o iconos. No usar para texto pequeño de body. Verifica con Accessibility Inspector en Xcode.

7. **Reduce Motion es crítico:** Varios usuarios reportan migrañas/mareos con animaciones. El sobrante anima (contentTransition + withAnimation), lo que es problemático. Hizo falta `@Environment(\.accessibilityReduceMotion)`.

8. **Dynamic Type AX5+:** No sabemos si la pantalla se adapta bien con tamaños de texto muy grandes. Prueba antes de release.

---

## Historial de cambios

| Fecha | Versión | Cambios |
|-------|---------|---------|
| 2026-09-15 | 1.0 | Auditoría completa: 23 hallazgos (5 bloqueantes, 6 altos, 8 medios, 4 bajos) |

---

**Auditor:** Sarah, especialista en accesibilidad, AppleAppLab  
**Fecha de auditoría:** 2026-09-15  
**Destinatario:** Woz (implementación)  
**Estado:** En espera de implementación de fixes
