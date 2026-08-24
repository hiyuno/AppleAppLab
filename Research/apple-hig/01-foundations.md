# Foundations — Principios Fundamentales de Apple HIG

**Fuente**: https://developer.apple.com/design/human-interface-guidelines/foundations  
**En una frase**: Principios universales de diseño que trascienden plataformas — accesibilidad, color, tipografía, layout, inclusión y branding.

---

## 1. Accesibilidad

### Definición
Diseñar y desarrollar apps que sean usables por todo el mundo, incluidas personas con discapacidades.

### Principios clave (WCAG)
- **Perceivable**: contenido debe ser perceptible por todos
- **Operable**: apps navegables y controlables
- **Understandable**: información y operaciones claras
- **Robust**: compatible con tecnologías asistenciales

### Qué deben hacer los devs de iOS/macOS

1. **VoiceOver Support**
   - Implementar `.accessibilityLabel()` y `.accessibilityHint()` en SwiftUI
   - Testear con VoiceOver habilitado regularmente

2. **Dynamic Type**
   - Permitir ajustes de tamaño de texto
   - Usar estilos de font escalables (`.headline`, `.body`, `.caption` en lugar de tamaños fijos)
   - Implementar `@Environment(\.sizeCategory)` para responder a cambios

3. **Contraste de color**
   - Mantener ratios WCAG AA mínimo (4.5:1 para texto pequeño, 3:1 para large text)
   - Verificar readability para usuarios daltónicos

4. **Navegación por teclado**
   - Asegurar que todas las features sean accesibles vía keyboard
   - Soportar gestos de VoiceOver

5. **Herramientas de testing**
   - Usar Xcode Accessibility Inspector regularmente
   - Testear con tecnologías asistenciales reales

### Puntos críticos
- `accessibilityHeading(.h1)` para estructurar contenido
- `accessibilityElement(children: .combine)` para agrupar lógicamente
- Nunca confíes solo en color para comunicar información

---

## 2. Color

### Principios clave

**Uso propositivo de color**
- Color debe comunicar información y guiar interacción
- NO es el único medio para conveyar información
- Sufficient contrast obligatorio

**Dark Mode es obligatorio**
- Diseñar colores que funcionen en light AND dark mode
- Usar semantic colors que adaptan automáticamente (recomendado)
- Testear ambos modos siempre

### Semantic Colors en SwiftUI

```swift
// Estos adaptan automáticamente a light/dark mode
Color.primary          // Texto principal
Color.secondary        // Texto secundario
Color.accentColor      // Accent de la app
Color.red, .green, .blue  // System colors con soporte dark mode

// Custom semantic colors
@Environment(\.colorScheme) var colorScheme
// Definir en Asset Catalog con Light/Dark variants
let customColor = Color("CustomBrandColor")
```

### Contrastes WCAG
- Texto pequeño: mínimo 4.5:1
- Texto grande (18pt+): mínimo 3:1
- UI components: mínimo 3:1

### Puntos críticos
- Testear en multiple devices y lighting conditions
- Considerar significados culturales de colores (rojo = alerta en Occidente)
- NO uses color como único indicador (agrega iconos, patrones, texto)

---

## 3. Tipografía

### Estilos de texto predefinidos

Usar estos en lugar de tamaños arbitrarios:

```swift
Text("Headline")
    .font(.headline)  // ~17pt, bold

Text("Body")
    .font(.body)      // ~17pt, regular

Text("Caption")
    .font(.caption)   // ~12pt

Text("Large Title")
    .font(.largeTitle) // ~34pt

Text("Subheadline")
    .font(.subheadline) // ~15pt
```

### Dynamic Type (CRITICO)

**Qué es**: El usuario puede ajustar el tamaño de texto global en Settings > Display & Brightness > Text Size.

**Cómo implementarlo en SwiftUI**:
```swift
@Environment(\.sizeCategory) var sizeCategory

var body: some View {
    Text("Hello")
        .font(.body)  // Adapta automáticamente con Dynamic Type
        
    // Si necesitas custom size:
    Text("Flexible size")
        .font(.system(size: 16, weight: .regular))
        .lineLimit(2)
}
```

### Tipografía del sistema
- **SF Pro** (iOS/macOS) — sistema primario, optimizado para pantallas
- **SF Compact** — versión condensada para espacios limitados
- **SF Mono** — monoespaciada, para código/data

### Puntos críticos
- NO fijes tamaños en puntos: usa estilos nombrados o `.dynamicTypeSize`
- Jerarquía visual: weight diferente (regular, semibold, bold) + tamaño
- Testea con text size al mínimo y máximo para layout breakage

---

## 4. Layout

### Safe Area y Screen Regions

**Safe Area** es la región segura para contenido (excluye notches, home indicator, status bar).

En SwiftUI, se respeta automáticamente con `.safeAreaInset()` o `.ignoresSafeArea()`.

### Spacing y Grid

Apple recomienda spacing consistente:
- 8pt: smallest gaps
- 16pt: standard spacing
- 20pt, 24pt: larger gaps
- Usar multiples de 4 para consistency

### Adaptive Layout

**Size Classes** para adaptabilidad:

```swift
@Environment(\.horizontalSizeClass) var hSizeClass
@Environment(\.verticalSizeClass) var vSizeClass

var body: some View {
    if hSizeClass == .compact {
        // iPhone portrait
        VStack { /* contenido */ }
    } else {
        // iPad / iPhone landscape
        HStack { /* contenido */ }
    }
}
```

**o usar `NavigationSplitView`** (iOS 16+):
```swift
NavigationSplitView {
    SidebarView()
} detail: {
    DetailView()
}
// Adapta automáticamente: single column en iPhone, split en iPad
```

### Responsive Design

- Testea en múltiples devices: iPhone SE, iPhone Pro Max, iPad, Mac
- Cuidado con Split View, Slide Over, Stage Manager en iPad
- Orientations: portrait, landscape, y cambios en tiempo real

### Puntos críticos
- Respectar Safe Area (NO uses `.ignoresSafeArea()` a menos que sea necesario)
- Flexible layouts > fixed widths
- Testea en landscape y portrait

---

## 5. Inclusión (Inclusive Design)

### Qué es
Diseñar para todo tipo de usuario: capacidades físicas, cognitivas, edades, contextos.

### Consideraciones de diversidad

1. **Visual**
   - Color contrast sufficient
   - NO confíes solo en color
   - Iconos claros y reconocibles
   - Support para VoiceOver

2. **Auditiva**
   - NO uses audio como único indicador
   - Proporciona transcripciones, captions
   - Visual feedback para alerts

3. **Motor**
   - Touch targets de 44x44pt mínimo
   - NO confíes en gestos complejos
   - Soporta switch control, voice control

4. **Cognitiva**
   - Claridad en language
   - Consistencia en patrones
   - Progresiva disclosure (no overwhelm)

### Respeto de Preferencias del Usuario

```swift
@Environment(\.reduceMotion) var reduceMotion

var body: some View {
    VStack {
        Text("Content")
            .transition(
                reduceMotion.active 
                ? .opacity 
                : .move(edge: .leading)
            )
    }
}
```

### Puntos críticos
- Inclusión NO es feature: es baseline
- Testea con usuarios reales con diferentes capacidades
- `reduceMotion`, `reduceTransparency`, `contrastedColors` son environment values

---

## 6. Branding

### Principios

**Balance**:
- Marca debe reforzar, no reemplazar, la interfaz del sistema
- La funcionalidad siempre gana; branding nunca compromete usability

**Consistencia**:
- Colores, tipografía, iconos reconocibles
- Aplicar en toda la app coherentemente

**Accesibilidad**:
- Branding colors deben mantener contraste
- NO uses marca como única indicación de estado

### Implementación en SwiftUI

```swift
// Define brand colors en Asset Catalog
let brandPrimary = Color("BrandPrimary")  // Light: #0066FF, Dark: #66B3FF
let brandSecondary = Color("BrandSecondary")

// Usa en buttons, navigation
Button(action: {}) {
    Text("Action")
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(brandPrimary)
        .cornerRadius(8)
}

// App-wide accent color
.accentColor(brandPrimary)
```

### Areas de aplicación

1. **Launch Screen** — refuerza brand identity
2. **Tab Bar / Navigation** — color accent, iconografía
3. **Buttons & CTAs** — brand primary color
4. **Progress indicators** — brand colors
5. **Navigation bar** — considerada (no siempre necesita cambio)

### Puntos críticos
- Testea brand colors en dark mode
- Verificar contraste: brand color + white/black text
- Apps con branding sutil > con branding loudly

---

## Resumen de Implementación

**Para cualquier app SwiftUI, estas Foundations son obligatorias:**

- ✓ Accesibilidad: `accessibilityLabel`, `accessibilityHint`, `accessibilityHeading`
- ✓ Color: semantic colors + dark mode testeo
- ✓ Tipografía: estilos predefinidos + Dynamic Type
- ✓ Layout: Safe Area + adaptive layouts + responsive testing
- ✓ Inclusión: reduce motion, contrast, keyboard nav
- ✓ Branding: balance con system design, consistency

Sin estas, la app NO cumple Apple HIG y será rechazada en App Store.
