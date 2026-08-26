# TRD — AppleAppLabUI + Pattern Library

> Última actualización: 2026-08-24. Basado en PRD v0.1.
> Decisiones técnicas vinculantes. Cambiar algo aquí requiere actualizar este documento.

---

## Stack técnico

| Área | Decisión | Justificación |
|------|----------|---------------|
| UI Framework | SwiftUI puro | NavigationSplitView cubre sidebar+detail nativo, sin AppKit bridging |
| Estado | `@Observable` | Convención del repo |
| Persistencia | Ninguna (Fase 1–2) | Herramienta de desarrollo; se evalúa "guardar sesión" en Fase 3 |
| Sync | N/A | No aplica |
| Concurrencia | Swift Concurrency, `@MainActor` implícito | Sin trabajo async real (sin red/disco) |

---

## Arquitectura

**Patrón:** MVVM con `@Observable`
**Justificación:** El catálogo es composición de vistas + estado de inspector, no lógica de negocio. MVVM ligero es suficiente; TCA sería over-engineering para una herramienta interna.

**Dos módulos, un workspace:**

```
AppleAppLab/
├── Packages/AppleAppLabUI/              # SPM package — design system real
│   ├── Package.swift
│   └── Sources/AppleAppLabUI/
│       ├── Tokens/
│       │   ├── ColorTokens.swift
│       │   ├── TypographyTokens.swift
│       │   ├── SpacingTokens.swift
│       │   └── MotionTokens.swift
│       ├── Components/
│       │   ├── Buttons/
│       │   ├── Navigation/
│       │   ├── Lists/
│       │   ├── Cards/
│       │   ├── Forms/
│       │   ├── Sheets/
│       │   ├── Onboarding/
│       │   ├── EmptyStates/
│       │   ├── Loading/
│       │   └── Toggles/
│       └── AppleAppLabUI.swift          # exports públicos
│
└── Apps/PatternLibrary/                 # app catálogo — consume el package
    └── PatternLibrary/
        ├── App/PatternLibraryApp.swift
        ├── Catalog/
        │   ├── CatalogViewModel.swift    # @Observable, selección de pattern
        │   ├── PatternCatalog.swift      # registro de los 10 patterns
        │   └── ContentView.swift         # NavigationSplitView
        ├── Inspector/
        │   ├── InspectorViewModel.swift  # @Observable, valores en vivo
        │   ├── InspectorView.swift       # panel de controles genérico
        │   └── InspectableProperty.swift # contrato de propiedades ajustables
        └── PatternDetail/
            └── PatternDetailView.swift   # preview + inspector lado a lado
```

**Por qué separado en dos targets:** el package es lo que se importa en apps reales — debe compilar solo, sin dependencias de la app catálogo (que es solo herramienta de desarrollo, nunca se distribuye).

---

## Modelo de datos

No hay persistencia. El estado vive en memoria durante la sesión del catálogo:

- `CatalogViewModel` — qué pattern está seleccionado
- `InspectorViewModel` — valores actuales de `PatternConfig` para el pattern activo (spacing, radius, color, duración, curva)

**Contrato central — cómo se registra y se inspecciona un pattern:**

```swift
// En AppleAppLabUI
public protocol InspectablePattern {
    static var patternName: String { get }
    associatedtype PreviewView: View
    static func preview(config: PatternConfig) -> PreviewView
    static var inspectableProperties: [InspectableProperty] { get }
}

// PatternConfig: struct simple con valores actuales + escape hatch
public struct PatternConfig {
    public var spacing: CGFloat
    public var cornerRadius: CGFloat
    public var accentColor: Color
    public var duration: Double
    public var curve: Animation
    public var custom: [String: AnyHashable] = [:]
}

// En PatternLibrary — un solo tipo de propiedad ajustable, reusado por todos
enum InspectableProperty {
    case spacing(label: String, keyPath: WritableKeyPath<PatternConfig, CGFloat>, range: ClosedRange<CGFloat>)
    case cornerRadius(label: String, keyPath: WritableKeyPath<PatternConfig, CGFloat>, range: ClosedRange<CGFloat>)
    case color(label: String, keyPath: WritableKeyPath<PatternConfig, Color>)
    case duration(label: String, keyPath: WritableKeyPath<PatternConfig, Double>, range: ClosedRange<Double>)
    case animationCurve(label: String, keyPath: WritableKeyPath<PatternConfig, Animation>)
}
```

`InspectorView` genérico itera `inspectableProperties` y renderiza el control correcto (slider, color picker, picker de curva) — un solo inspector para los 10 patterns, no uno custom por patrón.

---

## Decisiones de Swift

- **Target mínimo:** macOS 14 (Sonoma) — habilita `@Observable`, `NavigationSplitView` maduro, `.animation(value:)` moderno
- **Swift Concurrency:** `@MainActor` implícito en vistas; sin actors dedicados (no hay trabajo async real)
- **Swift 6:** strict concurrency desde día 1 en el package — es una librería que van a importar apps futuras, debe nacer Sendable-clean

---

## Integraciones externas y seguridad

No aplica — sin APIs externas, sin auth, sin datos sensibles, sin entitlements especiales, sin distribución fuera de este repo. No requiere gate de Ivan.

---

## Riesgos técnicos

- `PatternConfig` con propiedades fijas puede quedarse corto si un pattern necesita algo fuera de spacing/radius/color/duración/curva (ej. número de items en una lista) — mitigación: el campo `custom: [String: AnyHashable]` es el escape hatch, no rompe el contrato genérico
- NavigationSplitView se comporta distinto en iPadOS vs macOS — no es riesgo ahora (macOS-only), revisar si en Fase 3 se decide soporte iPad

---

## Qué NO hacer

- No usar TCA — over-engineering para herramienta interna sin lógica de negocio real
- No persistir valores del inspector en Fase 1–2 — se evalúa en Fase 3 si hace falta "guardar sesión"
- No crear target de tests separado todavía — Bertrand decide alcance cuando haya componentes reales que probar

---

## Setup inicial

1. Crear `Packages/AppleAppLabUI/Package.swift` (macOS 14, un target de librería)
2. Crear los 4 archivos de tokens vacíos (`ColorTokens`, `TypographyTokens`, `SpacingTokens`, `MotionTokens`)
3. Crear proyecto Xcode `Apps/PatternLibrary` (macOS App), agregar `AppleAppLabUI` como local package dependency
4. Implementar `ContentView` con `NavigationSplitView` + `PatternCatalog` (10 nombres, vistas placeholder)
5. Implementar `InspectableProperty` + `InspectorView` genérico antes del primer pattern real

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-08-24 | MVVM ligero, no TCA | Sin lógica de negocio compleja; TCA sería over-engineering |
| 2026-08-24 | Dos targets separados (package + app catálogo) | El package debe compilar y distribuirse solo, sin arrastrar código de la herramienta de desarrollo |
| 2026-08-24 | Inspector genérico basado en `InspectableProperty` | Evita 10 paneles de inspector custom — un solo motor reusado |
| 2026-08-24 | Sin persistencia en Fase 1–2 | No hay necesidad real todavía; se evalúa en Fase 3 |
| 2026-08-24 | Swift 6 strict concurrency desde día 1 en el package | Es una librería de consumo futuro, mejor que nazca Sendable-clean |
