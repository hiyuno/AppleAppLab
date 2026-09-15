# DESIGN_FROST — Fintrol

> Estilo para iOS 17–25 / macOS 14–15 (materiales SwiftUI / NSVisualEffectView).
> Última actualización: 2026-09-15.
> Tipografía, colores semánticos, espaciado, radios y decisiones de contenido: ver `DESIGN_LIQUID.md` — idénticos en ambas versiones.

> **Nota de vigencia:** el TRD fija el target mínimo de Fintrol en iOS 26 / macOS 26 ("no hay razón para bajar el target y perder Liquid Glass"). Este documento **no se va a compilar en producción hoy** — existe como especificación defensiva, siguiendo el gate de la skill de Jonny, para el caso de que el target mínimo se relaje en el futuro. Si el target nunca baja de 26, Woz no necesita implementar nada de este archivo. No es fuente de verdad activa mientras el TRD diga lo que dice hoy.

---

## Materiales — iOS 17–25

| Componente | Material SwiftUI | Nota |
|---|---|---|
| Tab bar | `.background(.ultraThinMaterial, in: Capsule())` | Pill flotante, mismo layout que Liquid |
| Tab activo | `Capsule().fill(Color.accentColor.opacity(0.15))` | Inner bubble tintado con `AccentColor` (#F04200), no blanco genérico — mantiene identidad de marca sin Liquid Glass |
| Navbar / toolbar | `.toolbarBackground(.ultraThinMaterial, for: .navigationBar)` | |
| Botón CTA (Agregar línea, Guardar) | `.buttonStyle(.borderedProminent)` con `.tint(.accentColor)` | Fill sólido naranja, pill vía `.buttonBorderShape(.capsule)` |
| Botón secundario (Cancelar) | `.background(.thinMaterial, in: Capsule())` | |
| Sheet (editar línea, jump quincena, formularios de Suscripciones/Recurrentes) | `.background(.regularMaterial)` | Sistema |
| Cards de bloque (INCOME/EXPENSES, panel resumen, Suscripciones/Recurrentes) | `Color("AppBackground").opacity(0.85)` + `.background(.ultraThinMaterial)` superpuesto al 50% | Aproxima el material Frost del tema (blur 0.5 / transparencia 0.5) sin `glassEffect()`: es la misma intención visual que en Liquid, lograda con Material de SwiftUI en vez de la API de Tahoe |
| Fila de línea en modo edición | `Color("AppBackground").opacity(0.6)` fill, sin blur adicional | El blur de `.ultraThinMaterial` sobre filas pequeñas genera ruido visual; se resuelve con opacidad sólida |

## Materiales — macOS 14–15

| Componente | NSVisualEffectView material | Nota |
|---|---|---|
| Sidebar | `.sidebar` | `blendingMode: .behindWindow` |
| Toolbar | `.headerView` | |
| Window background (zona central del detail) | `.windowBackground`, pero tintado — ver nota abajo | `blendingMode: .behindWindow` |
| Cards internas (bloques, panel resumen) | `.sidebar` reutilizado como aproximación de Frost, opacidad reducida vía `NSVisualEffectView.alphaValue = 0.85` | No hay material de sistema que replique Frost 1:1; se documenta esta aproximación en vez de inventar una API |
| Campo de texto (monto, descripción, TC manual) | Fill opaco `Color("AppBackground").secondary`, sin NSVisualEffectView | Los campos de captura de dinero deben ser 100% legibles, sin blur detrás del texto que se está escribiendo |

**Nota — ventana central en macOS 14–15:** a diferencia de Liquid (donde el contenido central es `AppBackground` sólido sin ningún material, ver `DESIGN_LIQUID.md`), aquí tampoco se usa `.windowBackground` translúcido para el área de bloques — se mantiene sólido por la misma razón que en Liquid: legibilidad de números sobre legibilidad atmosférica. `.windowBackground` con `blendingMode: .behindWindow` solo aplicaría, si acaso, detrás de la sidebar, nunca detrás de las cifras.

## Sombras (cuando no hay material translúcido)

```swift
.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)   // badge de sobrante
```

Mismo valor que en Liquid — la elevación **Flat** del tema Fintrol no cambia entre versiones; el badge de sobrante es la única superficie que se eleva visualmente en ambas.

## Colores — sin cambios

`AccentColor` (#F04200), la escala `accent-50…900`, y los tres colores de estado del sobrante (`.green`/`.yellow`/`.red`) son colores de sistema y de Assets catalog — funcionan igual en iOS 17+/macOS 14+ sin ningún ajuste. No hay tabla de fallback de color porque no hay nada que hacer fallback.

## Forma — sin cambios

Continuous Corners y `r_inner = r_outer − padding` no dependen de Liquid Glass — `RoundedRectangle(cornerRadius:, style: .continuous)` existe desde iOS 13. Todos los radios de `DESIGN_LIQUID.md` aplican igual aquí.

## Navegación — sin cambios de estructura

`TabView` (iPhone) y `NavigationSplitView` (Mac) con las mismas 5 secciones, el mismo esquema de chevrons + jump sheet + botón "Hoy" para navegar entre quincenas. Nada de esto depende de Liquid Glass — es estructura de SwiftUI estándar disponible desde iOS 16+.

## Motion fallback

| Evento | Diferencia respecto a Liquid | Curva / duración | Reduce Motion |
|---|---|---|---|
| Cambio de color del sobrante | Ninguna — `withAnimation` funciona igual sin Liquid | `.easeInOut(duration: 0.3)` (equivalente a `.smooth` de iOS 17+, disponible desde iOS 15) | Igual: solo cross-fade de color |
| Confirmar captura rápida | Ninguna | `.spring(response: 0.3, dampingFraction: 0.85)` (API pre-`.spring(duration:bounce:)` de iOS 17) | Solo fade |
| Swipe to delete | Ninguna | `.easeIn(duration: 0.2)` | Fade sin colapso animado |
| Entrar en modo edición inline | Ninguna | `.easeOut(duration: 0.2)` | Igual, ya es corto |
| Navegar entre quincenas | Ninguna | `.easeOut(duration: 0.25)` | Cross-fade simple |
| Toggle "pagado" | Sin `.symbolEffect(.bounce)` (iOS 17+ only) — usar `.scaleEffect` manual 1.0→1.15→1.0 vía `withAnimation` | `.spring(response: 0.25, dampingFraction: 0.6)` | Sin scale, solo el cambio de símbolo instantáneo |

Sin glows en ninguna versión — decisión ya fijada en `DESIGN_LIQUID.md`, no depende del sistema de materiales.

## Préstamos (Loans) — sin cambios

Toda la especificación de `DESIGN_LIQUID.md` (lista, formulario, detalle con tabla de amortización, chips de dirección, accesibilidad) aplica igual aquí — `Table` (Mac), `ProgressView`, `DatePicker` y `Form` están disponibles desde macOS 12/iOS 15, no dependen de Liquid Glass. Las cards de la lista y la cabecera del detalle usan la misma aproximación de Frost con `.ultraThinMaterial` ya descrita arriba, en vez de `glassEffect()`.

## Bloqueo biométrico — sin cambios

La pantalla de bloqueo (LAContext, fondo sólido sin ningún material, sin datos montados detrás) es idéntica en ambas versiones — no usa Liquid Glass ni Frost, es intencionalmente una superficie plana de seguridad. Ver `DESIGN_LIQUID.md` para la especificación completa.

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-09-15 | Este documento es defensivo, no activo — el TRD fija target 26+ | Evita que Woz implemente compatibilidad que el TRD no requiere hoy |
| 2026-09-15 | Frost del tema se aproxima con `.ultraThinMaterial` + opacidad manual en vez de intentar replicar `glassEffect()` | No existe una API de fallback 1:1 para Liquid Glass; se prioriza legibilidad de cifras sobre fidelidad visual exacta |
| 2026-09-15 | macOS 14–15: sin material translúcido en el área central de bloques, igual que en Liquid | Consistencia con la decisión ya tomada en `DESIGN_LIQUID.md` de priorizar legibilidad de números sobre efecto atmosférico |
