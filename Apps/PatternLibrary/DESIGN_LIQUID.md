# DESIGN_LIQUID — Pattern Library

> Estilo para iOS 26+ / macOS 26+ (Tahoe, Liquid Glass).
> Fuente de verdad de diseño. Última actualización: 2026-08-24.
> Todo lo que no está aquí no está decidido.

---

## Plataforma y versión target

- **Plataforma:** macOS
- **Versión mínima:** macOS 14.0 (Liquid Glass es progressive enhancement en macOS 26+, ver DESIGN_FROST.md para el fallback real de hoy)
- **Sistema de diseño:** Liquid Glass (macOS 26+) con fallback SwiftUI Material (macOS 14–25)
- **Modos soportados:** Light + Dark (automático con semánticos Apple)

---

## Identidad visual

**Sensación general:** técnica, silenciosa, precisa — es una herramienta de taller, no un producto de consumo. El chrome debe desaparecer para que el pattern en preview sea lo único que llame la atención.
**Inspiración:** Xcode Previews + Figma inspector panel — utilitaria, sin decoración.

---

## Color

### Paleta semántica (usar siempre estos, nunca hex hardcoded)

| Rol | Token SwiftUI | Hex Light | Hex Dark |
|-----|--------------|-----------|----------|
| Fondo principal | `Color(.windowBackgroundColor)` | sistema | sistema |
| Fondo secundario (sidebar) | `Color(.controlBackgroundColor)` | sistema | sistema |
| Superficie / panel inspector | `Color(.underPageBackgroundColor)` | sistema | sistema |
| Texto primario | `.primary` | sistema | sistema |
| Texto secundario | `.secondary` | sistema | sistema |
| Separadores | `Color(.separatorColor)` | sistema | sistema |

### Color de acento

- **Nombre:** LabIndigo
- **Hex:** `#5E5CE6` (systemIndigo de Apple — no custom)
- **Definido en:** Assets.xcassets > AccentColor
- **Uso:** selección activa en sidebar, botón CTA del pattern en preview, foco de inputs del inspector

### Sistema de paleta desde accent — LabIndigo `#5E5CE6`

HSL base: H 244° / S 76% / L 68%

| Token | Light (hex aprox.) | Dark (hex aprox.) | Uso |
|-------|------------------|------------------|-----|
| `accent-50` | `#F0F0FE` | `#0E0D2E` | Fondos tintados sutiles |
| `accent-100` | `#DEDCFC` | `#161452` | Fondo de item seleccionado en sidebar |
| `accent-300` | `#A8A4F5` | `#3B37A8` | Bordes de foco |
| **`accent-500`** | **`#5E5CE6`** | **`#5E5CE6`** | Accent base — CTA, selección |
| `accent-700` | `#3634A0` | `#A8A4F5` | Texto sobre superficies accent claras |
| `accent-900` | `#1C1B50` | `#F0F0FE` | Texto sobre accent-subtle |

Texto sobre `accent-500` (L 68% → claro): usar blanco (L original de indigo es suficientemente oscuro perceptualmente — verificar con Contrast.app antes de Fase 1; si falla, usar `accent-900`).

### Colores adicionales — estados semánticos

| Estado | Color SwiftUI | Cuándo |
|--------|--------------|--------|
| Éxito | `.green` | Valor de inspector aplicado sin error |
| Error | `.red` | Config inválida (ej. rango fuera de límite) |
| Deshabilitado | `.secondary.opacity(0.4)` | Propiedad no aplicable al pattern activo |

---

## Tipografía

**Sistema:** SF Pro (Dynamic Type)
**Nunca:** tamaños hardcoded, fuentes custom

| Elemento | Style | Peso | Uso |
|----------|-------|------|-----|
| Nombre del pattern (detail header) | `.title2` | Semibold | Encabezado del área central |
| Item de sidebar | `.body` | Regular | Nombre de cada uno de los 10 patterns |
| Label de control en inspector | `.subheadline` | Regular | "Spacing", "Corner Radius", etc. |
| Valor numérico del control | `.caption` monospaced (`.monospacedDigit()`) | Regular | Feedback numérico en vivo del slider |

---

## Espaciado

**Base:** 8pt.

| Contexto | Valor |
|----------|-------|
| Padding de sidebar items | 12pt vertical, 16pt horizontal |
| Padding de preview area | 32pt (da aire al pattern en exhibición) |
| Padding de inspector panel | 16pt |
| Espacio entre controles del inspector | 16pt |
| Ancho del inspector panel | 280pt fijo |
| Ancho del sidebar | 220pt (rango 180–260, resizable) |

---

## Forma — Continuous Corners

**Regla absoluta:** `RoundedRectangle(cornerRadius: x, style: .continuous)` en todo. Nunca `.circular`.

| Elemento | Radio |
|----------|-------|
| Item seleccionado en sidebar | 8pt |
| Panel de preview (marco del pattern) | 16pt |
| Controles del inspector (sliders, swatches) | 8pt |

---

## Materiales y profundidad

### Superficies macOS 26+

| Superficie | Variante | Razón |
|---|---|---|
| Sidebar | `regular` glass | Navegación — capa permitida para glass |
| Inspector panel | `regular` glass | Navegación/control, no contenido |
| Área de preview del pattern | Sin glass — fondo sólido `windowBackgroundColor` | Es "contenido": el pattern debe verse sin interferencia de material translúcido detrás |

### Sombras (fallback sin glass, macOS 14–25)

```swift
.shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 1) // separación sidebar/inspector del área central
```

---

## Navegación

- **Patrón principal:** `NavigationSplitView` de 3 columnas (sidebar → detail → inspector no es columna nativa, va como panel fijo a la derecha del detail)
- **Sidebar:** lista simple de 10 items, sin agrupación en Fase 1 (agrupar por categoría se evalúa si la lista crece)
- **Transiciones:** ninguna transición de navegación custom — el cambio de pattern seleccionado es instantáneo (es una herramienta de inspección, no un flujo narrativo)

---

## Componentes del sistema

### Botones (chrome de la app catálogo, no el pattern "Botones" en sí)

- Controles del inspector usan `.buttonStyle(.bordered)` — utilitario, sin protagonismo

### Listas y cards

- Sidebar: `.listStyle(.sidebar)` nativo de macOS
- Sin swipe actions — no aplica en macOS

### Iconografía

- SF Symbols para cada item del sidebar (uno representativo por pattern: `button.programmable` para Botones, `sidebar.left` para Navegación, etc.)
- Peso: `.regular`, mismo peso que el texto del item

---

## Animaciones

### Principios

- El **chrome de la app** (sidebar, inspector) no debe animar de forma llamativa — es una herramienta de trabajo, la atención va al pattern en preview.
- El **pattern en preview** sí anima con la curva/duración que define su propio `PatternConfig` — eso es literalmente lo que el usuario está ajustando en vivo.
- Reduce Motion: el chrome de la app ya es estático por diseño; solo el pattern en preview necesita respetar `@Environment(\.accessibilityReduceMotion)`, y cada pattern define su propia alternativa.

### Especificación de motion aprobada — chrome de la app

| Evento | Estado inicial → final | Curva | Duración | Reduce Motion | Razón |
|---|---|---|---|---|---|
| Cambio de selección en sidebar | Highlight de fondo fade | `easeOut` | 0.15s | Sin cambio (ya es sutil) | Feedback inmediato sin distraer |
| Cambio de valor en inspector → preview | El pattern reacciona con SU PROPIA curva configurada | (definida por `PatternConfig.curve`) | (definida por `PatternConfig.duration`) | El pattern respeta su propia alternativa | Es el objeto de estudio, no chrome |

---

## Punto de partida — Pattern 1: Botones y controles

Valores default iniciales en `PatternConfig` para el primer pattern (se pulen en vivo dentro del catálogo, esto es solo el punto de arranque):

| Propiedad | Valor inicial |
|-----------|---------------|
| `spacing` | 12pt (entre botones en fila) |
| `cornerRadius` | 999pt (pill, siguiendo HIG) |
| `accentColor` | LabIndigo `#5E5CE6` |
| `duration` | 0.2s (feedback de press) |
| `curve` | `.spring(response: 0.3, dampingFraction: 0.7)` — sensación táctil al presionar |

Estilo base: CTA principal pill con fill de accent, texto blanco (o `accent-900` si falla contraste), altura 44pt (tap target mínimo aunque sea macOS — consistencia con hermanas iOS).

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-08-24 | Accent LabIndigo (`#5E5CE6`, systemIndigo) | Diferencia visualmente la herramienta interna de las apps de producto que construirá |
| 2026-08-24 | Sin glass en el área de preview | El pattern debe verse limpio, sin material translúcido compitiendo visualmente |
| 2026-08-24 | Chrome de la app estático, sin animaciones propias | La atención debe ir 100% al pattern que se está puliendo |

---

## Sin definir aún

- [ ] Si el sidebar agrupa patterns por categoría cuando la lista crezca más allá de 10
- [ ] Si se necesita un modo "comparar 2 patterns lado a lado" en el futuro
