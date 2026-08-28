# Catálogo de Patterns — AppleAppLabUI

Componentes ya construidos y refinados en `Packages/AppleAppLabUI/`.

**Regla del equipo:** antes de diseñar o codificar cualquier elemento de UI, revisar este catálogo. Si el componente existe, se usa — no se recrea.

Todos los componentes reciben un `PatternConfig` que contiene los tokens del tema activo (accent, cornerRadius, spacing, elevation, etc.). El tema se aplica una vez a nivel de app y fluye automáticamente a cada componente.

---

## Integración en un proyecto nuevo

### 1. Agregar el paquete en `project.yml`

```yaml
packages:
  AppleAppLabUI:
    path: ../../Packages/AppleAppLabUI   # si está en el mismo repo
    # o si es externo:
    # url: https://github.com/hiyuno/AppleAppLab
    # from: 1.0.0

targets:
  NombreApp:
    dependencies:
      - package: AppleAppLabUI
        product: AppleAppLabUI
```

### 2. Import en cualquier vista

```swift
import AppleAppLabUI
```

---

## Componentes disponibles

### Botones — `LabButton`

```swift
LabButton(title: "Continuar", style: .primary, config: config) { }
LabButton(title: "Cancelar", style: .secondary, config: config) { }
```

Estilos: `.primary` (fondo accent, texto blanco) · `.secondary` (borde accent, sin fondo)
Incluye: press animation con spring, accessibility reduceMotion, shadow por elevation.

---

### Cards — `LabCard` · `LabNestedCard` · `LabDashboardCards`

```swift
LabCard(title: "Golden Gate", subtitle: "San Francisco", config: config)

LabNestedCard(config: config) {
    // contenido interno con r_inner = r_outer - padding
}

LabDashboardCards(config: config)
```

`LabNestedCard` aplica automáticamente el nested corner radius correcto.

---

### Listas — `LabList`

```swift
let rows = [
    LabListRow(id: UUID(), title: "Item 1", subtitle: "Detalle", systemImage: "star"),
]
LabList(rows: rows, config: config)
```

---

### Todo list con drag & drop — `LabTodoList`

```swift
@State var items = [LabTodoItem(id: UUID(), title: "Tarea", isDone: false)]
LabTodoList(items: $items, config: config)
```

Incluye: checkbox, reorder drag & drop, tachado animado al completar.

---

### Formularios — `LabTextField`

```swift
LabTextField(placeholder: "Email", text: $email, config: config)
```

Incluye: focus border animado con accent, corner radius correcto, accesibilidad.

---

### Navegación — `LabTabBar`

```swift
let tabs = [
    LabTabItem(id: UUID(), title: "Inicio", systemImage: "house"),
    LabTabItem(id: UUID(), title: "Perfil", systemImage: "person"),
]
LabTabBar(tabs: tabs, selectedIndex: $selectedTab, config: config)
```

---

### Toggles — `LabToggleRow`

```swift
LabToggleRow(title: "Notificaciones", isOn: $enabled, config: config)
```

---

### Checkbox & Radio — `LabCheckboxGroup` · `LabRadioGroup`

```swift
LabCheckboxGroup(options: $options, config: config)
LabRadioGroup(options: options, selected: $selected, config: config)
```

---

### Loading — `LabProgressIndicator`

```swift
LabProgressIndicator(config: config)
```

---

### Empty states — `LabEmptyState`

```swift
LabEmptyState(
    systemImage: "tray",
    title: "Nada por aquí",
    subtitle: "Agrega tu primer elemento para empezar",
    config: config
)
```

---

### Onboarding — `LabOnboardingStep`

```swift
LabOnboardingStep(
    systemImage: "sparkles",
    title: "Bienvenido",
    subtitle: "Tu descripción aquí",
    config: config
)
```

---

### Badges — `LabBadge`

```swift
LabBadge(text: "Nuevo", config: config)
```

---

## Tokens del sistema

```swift
// Tipografía
TypographyTokens.screenTitle      // .largeTitle
TypographyTokens.sectionTitle     // .title2.weight(.semibold)
TypographyTokens.body             // .body
TypographyTokens.secondaryLabel   // .subheadline
TypographyTokens.caption          // .caption
TypographyTokens.buttonLabel      // .headline.weight(.semibold)

// Espaciado
SpacingTokens.screenMargin        // 16pt
SpacingTokens.cardPadding         // 16pt
SpacingTokens.sectionSpacing      // 24pt
SpacingTokens.itemSpacing         // 8pt
SpacingTokens.minTapTarget        // 44pt

// Radios
RadiusTokens.card                 // 20pt
RadiusTokens.nestedInCard         // 4pt (card - padding)
RadiusTokens.input                // 12pt
RadiusTokens.pill                 // 999pt
```

---

## Qué NO está en la librería — hay que construirlo

Si un elemento de UI no aparece en esta lista, Woz lo construye desde cero respetando los mismos tokens (`PatternConfig`, `SpacingTokens`, `RadiusTokens`, `TypographyTokens`).

Elementos que típicamente faltan por ser específicos de cada app:
- Charts y gráficas de datos
- Mapas con overlays custom
- Animaciones de hero transition específicas
- Componentes de dominio (ej: tarjeta de transacción financiera con lógica propia)

Cuando Woz construye algo nuevo que podría generalizarse, lo documenta en `PROJECT_LEARNINGS.md` para que sea candidato a entrar al paquete en el futuro.
