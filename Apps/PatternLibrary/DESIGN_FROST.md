# DESIGN_FROST — Pattern Library

> Estilo para macOS 14–25 (materiales SwiftUI / NSVisualEffectView). Este es el fallback REAL para el mínimo target del proyecto (macOS 14).
> Última actualización: 2026-08-24.
> Tipografía, colores semánticos, espaciado y radios: ver DESIGN_LIQUID.md — idénticos en ambas versiones.

---

## Materiales — macOS 14–15

| Componente | Material SwiftUI | Nota |
|---|---|---|
| Sidebar | Nativo `.listStyle(.sidebar)` (ya trae su propio material del sistema) | No requiere material manual |
| Inspector panel | `.background(.regularMaterial)` | Separación visual del área de preview |
| Área de preview | `.background(Color(.windowBackgroundColor))` — sólido, sin material | El pattern debe verse sin translucidez detrás |

---

## Sombras (cuando no hay glass)

```swift
.shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 1) // separación inspector/preview
```

---

## Motion fallback

Idéntico a DESIGN_LIQUID.md — no hay diferencia de motion entre Frost y Liquid en este proyecto, porque el chrome de la app ya es estático en ambas versiones. Solo el material visual cambia.

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-08-24 | Preview area sin material en ambas versiones | Consistencia — el pattern nunca debe verse afectado por transparencia del chrome |
