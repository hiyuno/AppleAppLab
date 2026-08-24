# Offering Choices Pattern

**Fuentes**:
- Medium: "Checkbox & Radio Button Design Best Practices (2026)"
- https://blog.prototypr.io/how-to-choose-and-design-selection-controls-in-ux/
- https://www.shaheermalik.com/blog/checkbox-radio-design-best-practices
- Setproduct Blog: "Radio button UI design"

**En una frase**: Cómo presentar opciones de selección (radio buttons, checkboxes, toggles) para que usuarios comprendan rápidamente si pueden elegir una o múltiples opciones.

**Fuente: Secundaria** — No tiene página dedicada en HIG actual; este documento consolida mejores prácticas de UX para controls de selección desde fuentes confiables.

**Fecha de recolección**: 2026-08-24 (Pasada 3)

---

## Cuándo Ofrecer Opciones

✓ **Usar cuando**:
- Formularios con preguntas de opción única (pago, envío)
- Multi-select lists (filtros, permisos, preferencias)
- Configuración de app (tema, idioma)
- Encuestas o cuestionarios

✗ **Evitar si**:
- Hay demasiadas opciones (>7) → usar Picker o Search
- Las opciones son complejas → usar descripción detallada o Help
- El usuario necesita cambiar frecuentemente → usar Toggle o Segmented Control

---

## Control Type Decision Tree

```
Decisión: ¿Cuántas opciones puede elegir el usuario?

├─ UNA opción (mutually exclusive)
│  ├─ Pocas opciones (2-4) → Radio Button
│  ├─ Muchas opciones (5+) → Picker / Menu
│  └─ Cambio rápido/toggle → Toggle o Segmented Control
│
├─ MÚLTIPLES opciones (zero to many)
│  ├─ Pocas (2-4) → Checkbox
│  ├─ Muchas (5+) → List con checkbox o custom scroll
│  └─ Filtros con preview → Filter buttons o tags
│
└─ DOS estados binarios
   └─ Toggle (no necesita label "Option A / Option B")
```

---

## Radio Buttons (Selección Única)

### Cuándo Usar
- Seleccionar un método de pago entre opciones (Credit card, PayPal, Apple Pay)
- Elegir frecuencia de notificación (Nunca, Diario, Semanal)
- Elegir tamaño de fuente (Pequeño, Normal, Grande)

### Diseño en iOS/iPadOS

**En SwiftUI 5+**, usar `Picker` con estilo `.segmented` o `.menu`:

```swift
// Opción 1: Menu Picker (compact, recomendado para muchas opciones)
Picker("Frequency", selection: $frequency) {
    Text("Never").tag(Frequency.never)
    Text("Daily").tag(Frequency.daily)
    Text("Weekly").tag(Frequency.weekly)
    Text("Monthly").tag(Frequency.monthly)
}
.pickerStyle(.menu)

// Opción 2: Segmented Control (mejor para 2-3 opciones)
Picker("Size", selection: $fontSize) {
    Text("Small").tag(FontSize.small)
    Text("Normal").tag(FontSize.normal)
    Text("Large").tag(FontSize.large)
}
.pickerStyle(.segmented)

// Opción 3: Inline radios (para formas verticales)
VStack(alignment: .leading, spacing: 12) {
    Text("Select Payment Method").font(.headline)
    
    ForEach(paymentMethods, id: \.id) { method in
        Button(action: { selectedMethod = method }) {
            HStack {
                Circle()
                    .fill(selectedMethod == method ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 20)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8)
                            .opacity(selectedMethod == method ? 1 : 0)
                    )
                
                Text(method.name)
                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

### Mejores Prácticas de Radio

1. **Keyboard Navigation** (macOS, iPad con keyboard):
   - Tab → ir al grupo
   - Arrow keys → mover entre opciones
   - Space → seleccionar

2. **Target Size** (iOS):
   - Mínimo 44x44 pt (Apple standard)
   - Mejor 48x48 pt si hay espacio

3. **Labels Claros**:
   - "Every Day" es mejor que "1d"
   - "Credit Card" es mejor que "CC"

4. **Agrupación Visual**:
   - Agrupar radios relacionadas con spacing y color
   - Opcional: usar sección header

---

## Checkboxes (Selección Múltiple)

### Cuándo Usar
- Permitir seleccionar múltiples filtros (Categorías, Etiquetas)
- Permisos o preferencias variadas (Email, SMS, Push)
- Aceptar múltiples términos (I agree to Terms, I want newsletter)

### Diseño en iOS/iPadOS

```swift
// Opción 1: List con toggles
List {
    Section(header: Text("Notifications")) {
        Toggle("Email", isOn: $emailEnabled)
        Toggle("SMS", isOn: $smsEnabled)
        Toggle("Push", isOn: $pushEnabled)
    }
}

// Opción 2: Custom checkboxes (si quieres visual tradicional)
VStack(alignment: .leading, spacing: 12) {
    Text("Select Interests").font(.headline)
    
    ForEach(interests, id: \.id) { interest in
        Button(action: { toggleInterest(interest) }) {
            HStack {
                Image(systemName: isSelected(interest) ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected(interest) ? .blue : .gray)
                    .frame(width: 20, height: 20)
                
                Text(interest.name)
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Opción 3: Picker con multipleSelectionExample (iOS 16+)
// Nota: SwiftUI no tiene native "multi-select picker",
// así que usar List + Toggle es la norma
```

### Mejores Prácticas de Checkbox

1. **Indicador Visual Claro**:
   - Empty square = unchecked
   - Checkmark-filled square = checked
   - Minus/dash = indeterminate (algunos sub-items checked)

2. **Feedback Inmediato**:
   ```swift
   Button(action: {
       withAnimation(.easeInOut(duration: 0.2)) {
           toggleSelection(item)
       }
   }) { /* visual */ }
   ```

3. **Evitar Cascadas Confusas**:
   - Si hay checkboxes parent/child (ej. Categories > Subcategories), ser explícito sobre behavior:
     - Parent chequeado = todos children chequeados
     - Parent con algunos children = mostrar dash/indeterminate
     - Unchecking parent = unchecks todos children

---

## Toggle (Cambio Binario)

### Cuándo Usar
- Cambio de estado simple (On/Off)
- Cambios que afectan inmediatamente (Dark Mode, Airplane Mode)
- Preferencias de feature (Enable notifications, Share analytics)

### Diseño en iOS

```swift
Form {
    Section(header: Text("Preferences")) {
        Toggle("Dark Mode", isOn: $darkModeEnabled)
            .onChange(of: darkModeEnabled) { _ in
                updateAppearance()
            }
        
        Toggle("Share Analytics", isOn: $analyticsEnabled)
    }
}
```

### Diferencia Toggle vs Radio vs Checkbox

| Control | Selecciones | Cambio | Apariencia |
|---------|------------|--------|-----------|
| **Toggle** | 2 (on/off) | Inmediato | Switch |
| **Radio** | 1 de muchas | Requiere confirm | Círculo |
| **Checkbox** | 0+ de muchas | Inmediato | Cuadrado |

---

## Layouts de Múltiples Opciones

### Patrón: Form Vertical (Recomendado iOS)

```swift
Form {
    Section(header: Text("Shipping Method")) {
        Picker("Method", selection: $shippingMethod) {
            Text("Standard (5-7 days)").tag(ShippingMethod.standard)
            Text("Express (2-3 days)").tag(ShippingMethod.express)
            Text("Overnight").tag(ShippingMethod.overnight)
        }
        .pickerStyle(.inline) // or .wheel
    }
    
    Section(header: Text("Additional Options")) {
        Toggle("Gift Wrap", isOn: $giftWrap)
        Toggle("Insurance", isOn: $insurance)
    }
}
```

### Patrón: Grid (Para visuales, ej. color picker)

```swift
VStack(alignment: .leading, spacing: 16) {
    Text("Select Color").font(.headline)
    
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
        ForEach(colors, id: \.id) { color in
            Button(action: { selectedColor = color }) {
                Circle()
                    .fill(color.value)
                    .frame(height: 60)
                    .overlay(
                        Circle()
                            .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 3)
                    )
            }
        }
    }
}
```

### Patrón: Segmented Control (2-3 opciones)

```swift
Picker("Sort", selection: $sortBy) {
    Text("Recent").tag(SortBy.recent)
    Text("Popular").tag(SortBy.popular)
}
.pickerStyle(.segmented)
```

---

## Progressive Disclosure con Opciones

A veces, seleccionar una opción revela más opciones:

```swift
VStack(spacing: 16) {
    Picker("Payment", selection: $paymentMethod) {
        Text("Credit Card").tag(PaymentMethod.card)
        Text("Apple Pay").tag(PaymentMethod.applePay)
        Text("Crypto").tag(PaymentMethod.crypto)
    }
    .pickerStyle(.menu)
    
    // Revelado condicionalmente
    if paymentMethod == .card {
        CardDetailsForm()
    } else if paymentMethod == .crypto {
        CryptoWalletSelector()
    }
}
```

---

## Accesibilidad de Controles de Selección

### VoiceOver
- Cada opción debe ser anunciada claramente ("Radio button, Credit Card, selected")
- El label debe asociarse al control
- La acción debe ser explícita ("Double-tap to select")

### Keyboard Navigation
- Tab debe mover entre grupos de radios
- Arrow keys dentro del grupo
- Space o Enter para seleccionar
- Shift+Tab para retroceso

### Color + Iconografía
- No solo color para indicar estado (rojo ✗)
- Combinar: color + icon (rojo + X, verde + checkmark)

---

## Errores Comunes

❌ Radio button cuando debería ser checkbox (y viceversa)  
❌ Demasiadas opciones en radio (5+ → usar Picker)  
❌ Sin label visual (solo requiere selección)  
❌ Target size muy pequeño (<44pt)  
❌ Sin feedback visual al seleccionar  
❌ Keyboard navigation roto  
❌ Opciones ambiguas ("Option 1", "Option 2")  

---

## Checklist de Implementación

- [ ] Tipo de control correcto (radio vs checkbox vs toggle)
- [ ] Label claro para cada opción
- [ ] Target size >= 44x44 pt
- [ ] Feedback visual al seleccionar (animación, color)
- [ ] Keyboard navigation funcional (Tab, Arrows, Space)
- [ ] VoiceOver anuncios claros
- [ ] Comportamiento consistente (mismo control = mismo comportamiento siempre)
- [ ] Opción default seleccionada si aplica
- [ ] Validación clara si es formulario (error highlighting)

---

## Referencias Relacionadas

- **Patterns: Offering Choices** → Este documento
- **Components: Picker** (08) — cuando hay muchas opciones
- **Components: Toggle** (08) — control binario
- **Patterns: Confirming Actions** (14) — si selección requiere confirmación
- **Accessibility** (01 foundations) — alternativas de selección
