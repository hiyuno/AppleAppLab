# Catálogo de Patterns — AppleAppLabUI

Componentes ya construidos y refinados en `Packages/AppleAppLabUI/`.

**Regla del equipo:** antes de diseñar o codificar cualquier elemento de UI, revisar este catálogo. Si el componente existe, se usa — no se recrea.

Todos los componentes reciben un `PatternConfig` que contiene los tokens del tema activo (accent, cornerRadius, spacing, elevation, etc.). El tema se aplica una vez a nivel de app (`.labTheme(store)`) y cada vista lo resuelve por componente con `labTheme.config(for: XPattern.self)` — ver "Tema y Dev Tools" más abajo. Nunca se construye un `PatternConfig` a mano en la app.

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

## Tema y Dev Tools — `LabTheme` · `LabThemeStore` · `.labDevTools()`

La regla del equipo: **ningún valor visual hardcodeado en la app**. Colores, radios, opacidades, sombras, duraciones y springs salen del tema activo, y cada componente recibe su `PatternConfig` resuelto desde ahí. Eso es lo que hace que el panel de Dev Tools pueda mover toda la interfaz en vivo y que lo afinado se exporte al repo en vez de perderse.

### Cableado en la app (una vez, en `App.swift`)

```swift
import AppleAppLabUI

@main
struct MiApp: App {
    @State private var themeStore: LabThemeStore = {
        let bundled = LabThemeStore.bundledThemes()          // lee Themes/*.json del bundle
        return LabThemeStore(bundledThemes: bundled,
                             initial: bundled.first { $0.name == "Fintrol" } ?? .default)
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .labTheme(themeStore)      // inyecta \.labTheme + tint, fuente, símbolos, apariencia
                .labDevTools(themeStore)   // solo #if DEBUG; en Release es no-op
        }
    }
}
```

En `project.yml`, el JSON del tema se empaqueta como recurso:

```yaml
sources:
  - path: MiApp
  - path: ../../Themes/fintrol.json
    buildPhase: resources
```

### En cada vista — config resuelto por componente

```swift
struct LoansView: View {
    @Environment(\.labTheme) private var labTheme

    var body: some View {
        LabEmptyState(icon: "banknote", title: "…", message: "…",
                      config: labTheme.config(for: EmptyStatesPattern.self))
        LabTextField(placeholder: "Nombre", text: $name,
                     config: labTheme.config(for: FormsPattern.self))
    }
}
```

`config(for:)` devuelve los defaults del componente + los tokens globales del tema (accent, corner style, elevación, spacing escalado por densidad, duración escalada por velocidad de animación) + el override que el usuario haya guardado para ese componente. Nunca `PatternConfig(accentColor: .accentColor)` suelto: eso desconecta la vista del panel.

| Componente | Pattern para `config(for:)` |
|---|---|
| `LabButton` | `ButtonsPattern` |
| `LabCard` · `LabNestedCard` · `LabDashboardCards` | `CardsPattern` |
| `LabList` | `ListsPattern` |
| `LabTodoList` | `TodoListPattern` |
| `LabTextField` | `FormsPattern` |
| `LabTabBar` | `NavigationPattern` |
| `LabToggleRow` | `TogglesPattern` |
| `LabCheckboxGroup` · `LabRadioGroup` | `CheckboxRadioPattern` |
| `LabProgressIndicator` | `LoadingPattern` |
| `LabEmptyState` | `EmptyStatesPattern` |
| `LabOnboardingStep` | `OnboardingPattern` |
| `LabBadge` | `BadgePattern` |

### Valores visuales propios de la app

Lo que no es un `Lab*` también lee del tema: `labTheme.accentColor.color`, `labTheme.cornerStyle`, `labTheme.elevation` (`.labShadow(labTheme.elevation)`), `labTheme.density.scale`, `labTheme.motionSpeedMultiplier`. Si una vista necesita un control propio en el panel, adopta `InspectablePattern` y se registra una vez: `LabPatternRegistry.register(MiPantallaPattern.self)` — aparece en la pestaña **Componentes** junto a los `Lab*`.

### El panel (Debug)

Se abre con **shake** en iOS, **⌥⌘D** en Mac, o el botón flotante. Tres pestañas:

- **Tema** — color (accent, fondo, modo), forma y elevación, tipografía e iconos, densidad y motion, material de ventana, blur y transparencia.
- **Componentes** — un inspector por `Lab*` registrado; cada cambio queda como override del tema activo.
- **Temas** — guardar, actualizar, renombrar, borrar, **Exportar JSON** (se copia al portapapeles y en iOS se puede compartir), importar del portapapeles, reset.

**Ciclo:** afinas en la app → Exportar JSON → lo pegas en `Themes/<nombre>.json` → Jonny lo adopta en `STYLE_BRIEF.md` → PatternLibrary y el resto de apps lo ven con `/update-team`. El panel y todo `DevTools/` están bajo `#if DEBUG`: no existen en el archive de Release, e Ivan lo verifica en `/app-store-ready`.

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
