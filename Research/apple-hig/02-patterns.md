# Patterns — Flujos de Interacción Comunes

**Fuente**: https://developer.apple.com/design/human-interface-guidelines/patterns  
**En una frase**: Patrones de interacción probados que enseñan cuándo usar qué estructura de navegación y entrada de datos.

---

## 1. Data Entry (Entering Data)

### Propósito
Guiar cómo pedir información a usuarios de forma clara, accesible y con mínimo fricción.

### Core Components

#### Text Fields
```swift
TextField("Username@company.com", text: $username)
    .textInputAutocapitalization(.never)
    .keyboardType(.emailAddress)
    .textContentType(.emailAddress)  // Enables autofill
    .accessibilityLabel("Email address")
```

**Keyboard types importantes:**
- `.emailAddress` — teclado con @
- `.number` — pad de números
- `.phonePad` — pad de teléfono
- `.default` — qwerty normal
- `.URL` — con .com y /

#### Validation

**Real-time validation** (mejor UX):
```swift
@State var email = ""
@State var isValidEmail = false

var body: some View {
    TextField("Email", text: $email)
        .onChange(of: email) { _, newValue in
            isValidEmail = isValidFormat(newValue)
        }
    
    if !email.isEmpty && !isValidEmail {
        Text("Invalid email format")
            .foregroundColor(.red)
            .font(.caption)
    }
}
```

**Avoid submission-time validation** si es posible — feedback temprano > sorpresas.

#### Password Security

**Best Practices:**
```swift
SecureField("Password", text: $password)
    .textContentType(.password)
    .accessibilityLabel("Password")

// Mostrar/ocultar toggle
@State var showPassword = false
Group {
    if showPassword {
        TextField("Password", text: $password)
    } else {
        SecureField("Password", text: $password)
    }
}

// NUNCA prepopular passwords
// SIEMPRE soportar biometric auth (Face ID, Touch ID)
```

#### Autofill

```swift
TextField("Email", text: $email)
    .textContentType(.emailAddress)  // iOS 11+

TextField("Name", text: $name)
    .textContentType(.givenName)

SecureField("Password", text: $password)
    .textContentType(.password)
```

**Text Content Types disponibles:**
- `.emailAddress`, `.URL`, `.password`
- `.givenName`, `.familyName`, `.fullName`
- `.telephoneNumber`, `.postalCode`

### Form Accessibility

**Regla de oro**: Label + Input deben estar asociados.

```swift
VStack(alignment: .leading, spacing: 8) {
    Label("Email", systemImage: "envelope")  // Label visible
    TextField("", text: $email)
        .textContentType(.emailAddress)
        .accessibilityLabel("Email address")  // Para VoiceOver
    
    if !isValid {
        Text("Invalid email")
            .font(.caption)
            .foregroundColor(.red)
            .accessibilityLiveRegion(.polite)  // Announce error
    }
}
```

### Best Practices

1. **Minimizar campos requeridos** — solo lo esencial
2. **Progressive disclosure** — mostrar campos adicionales solo cuando sea necesario
3. **Contextual keyboards** — match input type a keyboard
4. **Consistent styling** — visual hierarchy clara
5. **Error prevention** — validación temprana

### Puntos críticos
- Supported input methods: teclado, voice, autofill — NO depender de uno solo
- Fetch data del sistema cuando posible (contacts, location, etc.)
- Touch targets 44x44pt mínimo
- Accesibilidad VoiceOver + keyboard navigation

---

## 2. Split Views

### Cuándo usar

**Split Views** son el patrón de navegación master-detail. Diferencian por plataforma:

| Plataforma | Patrón | Ejemplo |
|-----------|--------|---------|
| **iPhone** | Full-screen master, luego detail | Contactos: lista → tap → detalle |
| **iPad** | Side-by-side (master + detail) | Mail: carpetas + inbox side-by-side |
| **macOS** | Sidebar + content + inspector (3-col) | Finder: sidebar + content + preview |

### Estrutura en SwiftUI

#### 2-column (iPad/Mac typical)

```swift
NavigationSplitView {
    // Sidebar / Master
    List(items, id: \.id) { item in
        NavigationLink(value: item) {
            Text(item.name)
        }
    }
    .navigationDestination(for: Item.self) { _ in }
} detail: {
    // Detail / Content
    if let selected {
        DetailView(item: selected)
    } else {
        Text("Select an item")
    }
}
```

#### 3-column (macOS common)

```swift
NavigationSplitView {
    Sidebar()
} content: {
    ContentView()
} detail: {
    InspectorView()
}
```

### Responsive Behavior

**NavigationSplitView adapts automáticamente:**
- **iPhone**: collapsed a single column, navegable con back button
- **iPad**: side-by-side si hay espacio
- **macOS**: full 3-column si width permite

### Tips de UX

1. **Mantén estado de selección** — cuando user vuelve a master, remember el item seleccionado
2. **Predictable navigation** — tap en item debe mostrar detalle, no hacer otra cosa
3. **Search en sidebar** — si la lista es larga, agrega search
4. **Fallback content** — mostrar placeholder si nada está seleccionado

### Alternativa: Tab-based + Navigation

En iPhone donde 5+ tabs sería crowded:
```swift
TabView {
    NavigationStack {
        ListDetail1()
    }
    .tabItem {
        Label("First", systemImage: "1.circle")
    }
    
    NavigationStack {
        ListDetail2()
    }
    .tabItem {
        Label("Second", systemImage: "2.circle")
    }
}
```

### Puntos críticos
- NO uses split view en iPhone portrait (confunde a usuarios)
- iPad está diseñado para split view
- macOS espera multi-pane navigation

---

## 3. Onboarding

### Propósito
Primera experiencia del usuario debe ser suave, rápida, y mostrar el valor core de la app.

### Componentes de Onboarding

#### Getting Started
```
Screen 1: "Welcome to App"
   - Brand logo
   - 1-2 sentence description de value
   - "Get Started" button

Screen 2: "Feature 1"
   - Screenshot o icon
   - Explain core feature
   - Can skip

Screen 3: "Permissions"
   - Request camera, location, etc.
   - Clear why it's needed
```

#### Tutorial Pattern

```swift
// Usar Overlay o focus ring para highlight first-time user experience
@State var showTutorial = false

var body: some View {
    ZStack {
        MainContent()
        
        if showTutorial {
            TutorialOverlay()
                .transition(.opacity)
        }
    }
}
```

**Best practice**: Tutorial debería ser skipeable, pero clearly mark "Skip" no como primary CTA.

#### Progressive Disclosure

**NO mostres todo de una vez.** Deja que el usuario explore a su propio ritmo.

```swift
// Bad: 
// - 5-screen required onboarding

// Good:
// - 1-2 screens de value
// - Luego acción: "Start" o "Login"
// - In-app hints cuando llega a feature nueva
```

### Onboarding Checklist

- [ ] Brief: máximo 2-3 pantallas
- [ ] Skippable: usuario puede ir directo a app
- [ ] Repeatable: guardar en Settings > Help para re-ver
- [ ] Value-first: mostrar qué hace la app antes de permisos
- [ ] Permissions late: pedir camera/location DESPUÉS de intro, no antes
- [ ] Accessible: texto claro, imágenes con alt text, VoiceOver support

### Timing

```swift
@AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false

var body: some View {
    Group {
        if !hasSeenOnboarding {
            OnboardingView()
                .onDisappear {
                    hasSeenOnboarding = true
                }
        } else {
            MainApp()
        }
    }
}
```

### Puntos críticos
- Onboarding es vista UNA SOLA VEZ — hacerla valedera
- NO pedir permisos en screen 1
- Demostrar features, NO explicar
- Incluir way to re-trigger desde Settings/Help

---

## Patrones Pendientes (Próxima Pasada)

Estos patrones quedan documentados fuera de este resumen por falta de espacio:

- **Searching** — search bars, filters, results
- **Sharing** — social sharing, AirDrop, send to others
- **Authorization Requests** — login, sign-up flows
- **Managing Tasks** — to-do lists, notifications, task completion
- **Offering Choices** — radio buttons, checkboxes, choice lists
- **Confirming User Actions** — warnings, undo, destructive actions
- **Asking for Permission** — privacy permissions, system access

Estos irán en **Pasada 2** cuando se necesite profundizar.

---

## Resumen

**Data Entry**: minimize fields, validate early, support autofill  
**Split Views**: adapt to device, remember selection, responsive  
**Onboarding**: brief (2-3 screens), skippable, value-first, repeatable
