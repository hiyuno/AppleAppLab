# Components — UI Elements Fundamentales

**Fuente**: https://developer.apple.com/design/human-interface-guidelines/  
**En una frase**: Especificaciones de componentes core que toda app iOS/macOS toca: botones, text fields, tab bars, alerts, sheets.

---

## 1. Buttons

### Tipos y Estilos

#### Primary Button (Filled)
- **Uso**: main call-to-action
- **Color**: brand accent color
- **Estado**: enabled, pressed, disabled

```swift
Button("Save") {
    // Action
}
.buttonStyle(.borderedProminent)  // Filled style
```

#### Secondary Button (Outlined)
- **Uso**: alternative actions
- **Color**: system blue (default) o custom
- **Border**: 1pt stroke

```swift
Button("Cancel") {
    // Action
}
.buttonStyle(.bordered)  // Outlined style
```

#### Tertiary Button (Plain)
- **Uso**: less prominent, inline
- **Color**: system blue (text only)
- **No background**

```swift
Button("Skip") {
    // Action
}
.buttonStyle(.plain)
```

#### Destructive Button
- **Uso**: delete, logout, irreversible actions
- **Color**: system red
- **Warning**: use sparingly

```swift
Button("Delete", role: .destructive) {
    // Action
}
.buttonStyle(.borderedProminent)
```

### Button States

| Estado | Visual | Cuándo |
|--------|--------|--------|
| **Enabled** | Full color, tap responds | Default |
| **Pressed** | Darker, scaled (iOS 15+) | User is tapping |
| **Disabled** | Dimmed, no tap response | Validation fails, async pending |
| **Loading** | Show progress indicator | Action in progress |

```swift
@State var isSaving = false

var body: some View {
    Button(action: { 
        isSaving = true
        // async work, then isSaving = false
    }) {
        if isSaving {
            ProgressView()
                .tint(.white)
        } else {
            Text("Save")
        }
    }
    .buttonStyle(.borderedProminent)
    .disabled(isSaving)
}
```

### Button Sizing & Layout

**Minimum touch target: 44x44pt**

```swift
Button("Action") { }
    .buttonStyle(.borderedProminent)
    .frame(height: 44)  // Ensure min height
    .frame(maxWidth: .infinity)  // Full width on small screens
```

**iOS: prefer full-width buttons on form screens**  
**macOS: OK with smaller buttons, ~80-120pt width**

### Best Practices

- ✓ Primary action = strongest visual (filled)
- ✓ Secondary actions = weaker (outlined/plain)
- ✓ Never use destructive as primary (too risky)
- ✓ Disabled state must be visually obvious
- ✓ Label must be action-oriented ("Save", "Delete", not "OK")

### Puntos críticos
- NO más de 2 primary buttons por screen
- Destructive buttons SIEMPRE requieren confirmation
- Touch targets 44x44pt mínimo
- Labels: verb + noun o clear action

---

## 2. Text Fields

### Anatomy

```
+-------------------------------------+
| Label (above or inside)             |
+-------------------------------------+
| [Input text]        [Icon/Button]   |
+-------------------------------------+
| Helper text / Error message         |
+-------------------------------------+
```

### Implementation

```swift
VStack(alignment: .leading, spacing: 8) {
    // Label
    Label("Email Address", systemImage: "envelope")
        .font(.caption)
        .foregroundColor(.secondary)
    
    // Input
    TextField("user@example.com", text: $email)
        .textInputAutocapitalization(.never)
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .padding(12)
        .border(Color.gray.opacity(0.3), width: 1)
        .cornerRadius(8)
    
    // Validation message
    if !isValidEmail && !email.isEmpty {
        Label("Invalid email format", systemImage: "exclamationmark.circle")
            .font(.caption)
            .foregroundColor(.red)
    }
}
```

### Focus & Keyboard

```swift
@FocusState var emailFocused: Bool

TextField("Email", text: $email)
    .focused($emailFocused)
    .onSubmit {
        // Handle return key
        emailFocused = false
    }
```

### Placeholder vs Label

| Elemento | Uso |
|----------|-----|
| **Label** | Always visible, describes field |
| **Placeholder** | Fades with input, hints at format |

**NO usar placeholder como label** — eso es accessibility violation.

```swift
// GOOD:
Label("Email", systemImage: "envelope")
TextField("user@example.com", text: $email)

// BAD:
TextField("Email", text: $email)  // Email as label in placeholder
```

### States

```swift
// Focused
.border(Color.blue, width: 2)

// Error
.border(Color.red, width: 1)

// Success
.border(Color.green, width: 1)

// Disabled
.disabled(true)
.opacity(0.6)
```

### Best Practices

- ✓ Always pair with visible label
- ✓ Use appropriate `keyboardType`
- ✓ Support autofill with `textContentType`
- ✓ Validate in real-time when possible
- ✓ 44x44pt minimum height
- ✓ Clearly show focus (border, highlight)

### Puntos críticos
- Placeholder ≠ Label
- Focus state must be obvious
- Error messages clear y actionable
- Auto-capitalize/auto-correct según context

---

## 3. Tab Bars

### Overview

Tab bar presenta 2-5 tabs peer-level navigation a top of app (iOS) o bottom (sometimes macOS).

### Maximum Tab Count

| Platform | Max Tabs | Behavior |
|----------|----------|----------|
| **iPhone** | 5 | More = horizontal scroll (UX issue, avoid) |
| **iPad** | 5+ OK | Mais espacio, considerar sidebar si > 5 |
| **macOS** | N/A | Usar window tabs ou sidebar, NO tab bars como iOS |

```swift
TabView(selection: $selectedTab) {
    Tab1View()
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
        .tag(Tab.home)
    
    Tab2View()
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }
        .tag(Tab.search)
    
    // Max 5 tabs
}
```

### Tab Item Requirements

**Each tab must have:**
1. Distinctive icon (recognizable at small size)
2. Short label (1-2 words max)
3. Selected + unselected states

```swift
.tabItem {
    Image(systemName: "star")
        .environment(\.symbolVariants, .none)
    Text("Favorites")
}
```

### Badges

Use badges sparingly to indicate new content:

```swift
.tabItem {
    Label("Messages", systemImage: "message.fill")
        .badge(unreadCount > 0 ? unreadCount : nil)
}
```

**Badges** = red badge con número o dot. **Rules:**
- Only for counters (new messages, notifications)
- NO para status generic (use icon change instead)
- Keep count brief (e.g., "99+" for large numbers)

### Custom Graphics

```swift
.tabItem {
    VStack {
        Image("customIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
        Text("Tab")
    }
}
```

**Reglas:**
- Testea a pequeño tamaño (iOS tab bars son pequeñas)
- Mantén consistencia visual
- Proporciona selected vs unselected variants si custom

### Best Practices

- ✓ Limit to 5 tabs max on iPhone
- ✓ Equal visual weight per tab
- ✓ Clear icons (system icons preferred)
- ✓ Short labels (1-2 words)
- ✓ Current tab obviously highlighted
- ✓ Avoid > 5 tabs (use sidebar instead on iPad)

### Puntos críticos
- NO horizontal scrolling tabs en iPhone
- Consistency: icons + labels OR icons only (not mixed)
- Current tab MUST be visually distinct
- iPad con 5+ sections = sidebar, not tab bar

---

## 4. Alerts

### Propósito

**Alerts** son interruptions. Use only for:
- Critical information requiring immediate attention
- Confirmation needed before destructive action
- System errors that block progress

### Tipos

```swift
// Simple alert
Alert(
    title: Text("Confirm Delete"),
    message: Text("This action cannot be undone"),
    dismissButton: .cancel()
)

// Alert with buttons
Alert(
    title: Text("Delete Item?"),
    message: Text("Are you sure?"),
    primaryButton: .destructive(Text("Delete")) {
        // Delete action
    },
    secondaryButton: .cancel()
)
```

### Estructura recomendada

```
+-----------------------------+
| Title (required)            |
| Message (optional)          |
|                             |
| [Cancel]  [Destructive]     |
+-----------------------------+
```

**Rules:**
- **Title**: clear, concise (one sentence)
- **Message**: explain consequences (optional, only if needed)
- **Buttons**: 1-2 max, destructive on right/bottom

### Button Guidance

| Rol | Style | Ejemplo |
|-----|-------|---------|
| **Confirm/Safe** | Default or `.default` | "Delete", "Save" |
| **Destructive** | `.destructive` | "Delete", "Remove" |
| **Cancel** | `.cancel()` | "Cancel", "Don't Delete" |

```swift
.alert("Delete?", isPresented: $showAlert) {
    Button("Cancel", role: .cancel) { }
    Button("Delete", role: .destructive) {
        deleteItem()
    }
}
```

### Use Sparingly

**DON'T use alerts for:**
- ✗ Success messages (use toast/HUD)
- ✗ Non-critical confirmations (use form validation)
- ✗ Tutorials (use onboarding screens)
- ✗ Errors that can be inline (use Text below input)

**DO use alerts for:**
- ✓ Destructive actions (delete, logout)
- ✓ Critical system errors
- ✓ Security confirmations
- ✓ Require immediate decision

### Alternativas

| Caso | Alternativa |
|------|-------------|
| Success message | Inline success state, toast notif |
| Form error | Red error text below input |
| Non-critical info | Inline text, expandable section |
| Choices | Sheet or picker view, not alert |

### Puntos críticos
- Alerts interrupt, so use rarely
- Title must be clear
- Destructive action = explicit confirmation
- Max 2 buttons
- Never default to destructive action

---

## 5. Sheets

### Propósito

**Sheets** presentan modal content over main interface, pero no takeover fullscreen.

### cuando usar Sheet vs Full Screen

| Contexto | Usa |
|----------|-----|
| Focused task (edit item, simple form) | Sheet |
| Complex workflow (multi-step) | Full screen |
| Secondary action | Sheet |
| Primary navigation | Full screen |

```swift
@State var showSheet = false

Button("Edit") { showSheet = true }
    .sheet(isPresented: $showSheet) {
        EditView()
    }

// vs Full screen:
.fullScreenCover(isPresented: $showSheet) {
    ComplexWorkflow()
}
```

### Sheet Sizing (Detents)

**iOS 16+** puede tener multiple sheet sizes:

```swift
@State var detent: PresentationDetent = .medium

.sheet(isPresented: $showSheet, content: {
    SheetContent()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
})
```

**Detent sizes:**
- `.fraction(0.25)` — 25% of screen
- `.medium` — ~50% (common)
- `.large` — full or near-full
- `.height(300)` — fixed height

### Dismissal

Sheet se cierra con:
1. Swipe down gesture (automatic)
2. Cancel/Done button (explicit)
3. Programmatic: `.dismiss` environment

```swift
@Environment(\.dismiss) var dismiss

Button("Done") {
    saveChanges()
    dismiss()
}
```

### Handling Unsaved Changes

```swift
.sheet(isPresented: $showSheet) {
    NavigationStack {
        EditForm()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAlert = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        showSheet = false
                    }
                }
            }
    }
    .alert("Discard Changes?", isPresented: $showAlert) {
        Button("Keep", role: .cancel) { }
        Button("Discard", role: .destructive) {
            showSheet = false
        }
    }
}
```

### Best Practices

- ✓ Sheet content focused on one task
- ✓ Provide clear Done/Cancel buttons
- ✓ Handle unsaved data (confirm discard)
- ✓ Use appropriate detent size
- ✓ Test swipe-to-dismiss on devices
- ✓ Avoid nested sheets (too complex)

### Puntos críticos
- Sheet para focused tasks
- Full screen para complex workflows
- Swipe-to-dismiss DEBE funcionar
- Siempre ask before discarding user input
- Detent sizing en iOS 16+

---

## Componentes Pendientes

Estos componentes core quedan para **Pasada 2**:

- **Toggle** — on/off switch
- **Picker / DatePicker** — selection
- **Stepper** — increment/decrement
- **Slider** — range selection
- **Menu / ContextMenu** — actions menu
- **Sidebar** — hierarchical navigation
- **Toolbar** — command buttons
- **Search** — search interface

---

## Resumen de Implementación

```swift
// Button: .borderedProminent (primary), .bordered (secondary), .plain (tertiary)
Button("Action") { }
    .buttonStyle(.borderedProminent)

// TextField: Label + Input + Error message
TextField("Email", text: $email)
    .textContentType(.emailAddress)

// TabView: max 5 tabs, distinctive icons, short labels
TabView(selection: $tab) {
    // Tab 1-5
}

// Alert: rare, destructive actions only
.alert("Confirm?", isPresented: $showAlert) {
    Button("Delete", role: .destructive) { }
}

// Sheet: focused tasks, proper dismissal
.sheet(isPresented: $show) {
    SheetContent()
        .presentationDetents([.medium, .large])
}
```

Estas 5 componentes cubrirán ~80% del desarrollo de una app típica iOS/macOS.
