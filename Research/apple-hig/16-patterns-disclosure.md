# Progressive Disclosure Pattern

**Fuentes**:
- https://www.uxpin.com/studio/blog/what-is-progressive-disclosure/
- https://ixdf.org/literature/topics/progressive-disclosure
- https://uxuiprinciples.com/en/principles/progressive-disclosure
- https://developer.apple.com/design/human-interface-guidelines/ (core principles)

**En una frase**: Mostrar solo lo necesario inicialmente, revelar opciones avanzadas bajo demanda, para reducir complejidad sin sacrificar poder.

**Fuente: Secundaria** — No tiene página dedicada en HIG; consolida guidance de UX general aplicada a Apple platforms.

**Fecha de recolección**: 2026-08-24 (Pasada 3)

---

## Filosofía

**Progressive Disclosure = Training Wheels para interfaces complejas**

La idea: Los usuarios principiantes ven solo controles básicos. Los usuarios avanzados pueden explorar y encontrar opciones más poderosas.

Beneficios:
- ✓ Interfaz menos intimidante para nuevos usuarios
- ✓ Usuarios avanzados no sienten limitaciones
- ✓ Menos clutter visual (menos visuosidad = menos cognitive load)
- ✓ Reduce tasa de abandono de nuevas features

---

## Patrones de Disclosure

### Patrón 1: Expandible (Acordeón)

Mostrar un header clickeable que expande contenido oculto.

**Cuándo usar**:
- Formarios largos (expandir sección por sección)
- Configuración avanzada ("Show Advanced Options")
- Listas con detalles adicionales por item
- Documentación o help (contraer/expandir respuestas)

**Implementación**:

```swift
// Acordeón simple
VStack(spacing: 0) {
    Button(action: { isExpanded.toggle() }) {
        HStack {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .foregroundColor(.blue)
            Text("Advanced Settings")
                .font(.headline)
            Spacer()
        }
        .padding()
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    
    if isExpanded {
        Divider()
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Debugging", isOn: $debugEnabled)
            Picker("Log Level", selection: $logLevel) {
                Text("Info").tag(LogLevel.info)
                Text("Debug").tag(LogLevel.debug)
                Text("Verbose").tag(LogLevel.verbose)
            }
            .pickerStyle(.menu)
        }
        .padding()
    }
}
```

**UX Tips**:
- Usar chevron/arrow para indicar estado (→ vs ↓)
- Animar altura del contenido al expandir/contraer
- Retener estado de expansión (si usuario expandió, mantenerlo al navegar y regresar)
- Mostrar preview del contenido oculto si es posible (ej. "2 more options")

### Patrón 2: Tabbed Interface

Separar básico vs avanzado en tabs.

**Cuándo usar**:
- Configuración de app (General, Advanced, About)
- Herramientas de edición (Basic, Advanced, Effects)
- Perfil de usuario (Overview, Details, Preferences)

**Implementación**:

```swift
struct SettingsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("Settings", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Advanced").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            TabView(selection: $selectedTab) {
                GeneralSettingsView()
                    .tag(0)
                
                AdvancedSettingsView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}
```

**UX Tips**:
- Mantener el tab "General" visible por defecto
- Usar números mínimos de tabs (2-3 máximo)
- Alternativamente: Picker/Menu en lugar de tabs

### Patrón 3: Help/Details Button

Mostrar información adicional bajo demanda sin ocupar espacio.

**Cuándo usar**:
- Campos complejos que necesitan explicación (ej. "API Key")
- Tooltips o definiciones
- Legal/compliance text que no quieres mostrar por defecto

**Implementación**:

```swift
VStack(alignment: .leading, spacing: 8) {
    HStack {
        Text("API Key")
            .font(.headline)
        
        Button(action: { showAPIHelp.toggle() }) {
            Image(systemName: "questionmark.circle")
                .foregroundColor(.gray)
        }
        .buttonStyle(.plain)
        
        Spacer()
    }
    
    SecureField("Enter API Key", text: $apiKey)
    
    if showAPIHelp {
        VStack(alignment: .leading, spacing: 4) {
            Text("Where to find your API Key:")
                .font(.caption).bold()
            Text("1. Go to Settings → API")
            Text("2. Click 'Generate Key'")
            Text("3. Copy and paste here")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
}
```

**UX Tips**:
- Usar icono consistente (?, ⓘ, help icon)
- Help debe ser sucinto (no párrafos largos)
- Hacer el texto copyable si son instrucciones técnicas
- Posicionar help debajo del field, no en tooltip (accesibilidad)

### Patrón 4: Show More / Expand

Para listas o contenido truncado, mostrar "Show More" como botón/link.

**Cuándo usar**:
- Listas que pueden ser muy largas (primeros 3 items visibles, resto ocultos)
- Descripciones largas (mostrar primeras 2-3 líneas, "Read More" link)
- Comentarios o respuestas (inicialmente colapsos, expandir al tomar)

**Implementación**:

```swift
VStack(alignment: .leading, spacing: 8) {
    // Primeros N items
    ForEach(Array(comments.prefix(3)), id: \.id) { comment in
        CommentRow(comment: comment)
    }
    
    // Si hay más, mostrar botón "Show More"
    if comments.count > 3 {
        Button(action: { showAllComments.toggle() }) {
            HStack {
                Text("Show \(comments.count - 3) more comments")
                Image(systemName: showAllComments ? "chevron.up" : "chevron.down")
            }
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
    }
    
    // Mostrar resto si expandido
    if showAllComments {
        ForEach(Array(comments.dropFirst(3)), id: \.id) { comment in
            CommentRow(comment: comment)
        }
    }
}
```

**UX Tips**:
- Mostrar count exacto ("Show 5 more") para claridad
- Animar la expansión
- Opcionalmente: "Show Less" al contraer
- Considerar lazy loading si hay muchos items

### Patrón 5: Context Menu (macOS Right-Click, iOS Long-Press)

Opciones avanzadas reveladas solo en contexto menu, no en UI principal.

**Cuándo usar**:
- Acciones secundarias o destructivas
- Opciones específicas de contexto ("Open in New Tab", "Duplicate")
- Power-user workflows

**Implementación**:

```swift
Text("Document Title")
    .contextMenu {
        Button(action: { duplicate() }) {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        
        Button(action: { openInNewWindow() }) {
            Label("Open in New Window", systemImage: "macwindow")
        }
        
        Divider()
        
        Button(action: { delete() }, role: .destructive) {
            Label("Delete", systemImage: "trash")
        }
    }
```

**UX Tips**:
- Máximo 5-7 items en context menu (si más, submenu)
- Separar acciones destructivas con divider
- No replicar actions que ya están en toolbar/menu principal

---

## Evitar Anti-Patterns

### ❌ Hidden by Default (Confusión)

```swift
// MALO: Usuario no sabe que hay opciones
if userKnowsAboutAdvanced {
    advancedSettings()
}
```

Mejor: Mostrar explícitamente que hay más ("3 advanced options available").

### ❌ Demasiados Niveles de Nesting

```swift
// MALO: 4 niveles de expandible
VStack {
    ExpandableSection("Settings") {
        ExpandableSection("Network") {
            ExpandableSection("Advanced") {
                ExpandableSection("Debugging") {
                    // ...
                }
            }
        }
    }
}
```

Mejor: Máximo 2 niveles, después usar tabs.

### ❌ Disclosure sin Educación

Si révelas opciones avanzadas, también proporciona help/contexto:

```swift
// MALO
if showAdvanced { TextField("Regex", text: $regex) }

// BIEN
if showAdvanced {
    VStack {
        TextField("Regex Pattern", text: $regex)
        Text("Example: ^[a-z]+$").font(.caption).foregroundColor(.gray)
    }
}
```

---

## Disclosure en Formularios

### Patrón: Condicional Progresivo

Revelar más campos según selecciones anteriores:

```swift
Form {
    Section("Account Type") {
        Picker("Type", selection: $accountType) {
            Text("Personal").tag(AccountType.personal)
            Text("Business").tag(AccountType.business)
        }
    }
    
    // Condicionalmente revelado
    if accountType == .business {
        Section("Business Details") {
            TextField("Company Name", text: $companyName)
            TextField("Tax ID", text: $taxID)
        }
    }
    
    if accountType == .business && showAdvanced {
        Section("Advanced") {
            Toggle("Multi-user Access", isOn: $multiUser)
        }
    }
}
```

**UX Tips**:
- Cambio de campos debe ser smooth (animation)
- No resetear valores si usuario atrás/adelante
- Guardar estado de expansión en UserDefaults si es persistente

---

## Accesibilidad de Progressive Disclosure

1. **VoiceOver**:
   - Anunciar claramente state ("Expanded", "Collapsed")
   - Botón debe ser anunciado: "Show Details, button, double-tap to activate"

2. **Keyboard**:
   - Enter/Space debe toggle expandible
   - Tab entre secciones
   - Arrow keys dentro de secciones (si hay muchas)

3. **Motor Accessibility**:
   - Target clickeable >= 44x44 pt
   - No requiere drag (solo click/tap)

```swift
Button(action: { isExpanded.toggle() }) {
    HStack {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
        Text("Show Details")
        Spacer()
    }
}
.accessibilityLabel("Advanced options")
.accessibilityHint(isExpanded ? "Expanded" : "Collapsed")
```

---

## Checklist de Implementación

- [ ] Contenido básico visible inicialmente
- [ ] Opciones avanzadas claramente indicadas ("3 more options available")
- [ ] Botón/control con chevron o visual clara para expandir/contraer
- [ ] Animación suave al revelar/ocultar
- [ ] Estado de expansión retenido durante sesión
- [ ] Help/context proporcionado cuando apropiado
- [ ] VoiceOver y keyboard navigation funcional
- [ ] Máximo 2 niveles de nesting (después usar tabs)
- [ ] No esconder features críticas (solo opciones verdaderamente avanzadas)
- [ ] Considerar onboarding para destacar opciones avanzadas

---

## Referencias Relacionadas

- **Patterns: Offering Choices** (15) — revelar opciones condicionalmente
- **Patterns: Data Entry** (02) — formas con secciones expandibles
- **Components: Picker** (08) — alternativa a tabbed interface
- **Accessibility** (01 foundations) — navegación con keyboard
