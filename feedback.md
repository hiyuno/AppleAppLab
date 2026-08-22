# AppleAppLab — Feedback de implementación real
> Basado en el desarrollo de **New PROject** (macOS launcher, v0.1–v0.10).  
> Este documento es para mejorar los skills del equipo de agentes.

---

## 1. Steve — Orquestador

### Problema
Steve está diseñado para el flujo "nueva app desde cero", pero el 90% del trabajo real es **iteración sobre algo existente**. No hay protocolo para cuando el usuario llega con una feature concreta, un bug, o un ajuste visual.

### Mejora: agregar modo iteración
```
## Modo iteración (app existente)

Si el usuario llega con una tarea concreta (feature, bug, ajuste):
1. Leer DESIGN.md + CLAUDE.md antes de hacer nada
2. Decidir el flujo mínimo necesario:
   - Ajuste visual sin diseño nuevo → Woz directo
   - Feature con UI nueva → Jonny → Woz
   - Bug técnico → Woz → Bertrand
   - Cambio de arquitectura → Avie → Woz
3. No arrancar el flujo completo (Scott → Avie → Jonny → ...) 
   si no hace falta. La mayoría de las tareas de mantenimiento 
   son Jonny + Woz a lo mucho.
```

---

## 2. Jonny — Diseño UI/UX

### Problema
Varias decisiones visuales importantes se tomaron sin pasar por Jonny — directamente en código — resultando en mucha iteración ("más rápido", "más suave", "alrededor no atrás"). Un diseño previo hubiera cortado esas rondas a la mitad.

Decisiones que se tomaron sin diseño formal:
- Animación de entrada del launcher (escala + easing)
- Glow naranja: timing, intensidad, color, forma
- Color naranja en botones de onboarding
- Posicionamiento del glow (above vs below)

### Mejora 1: Agregar sección Motion Design en DESIGN.md

```markdown
## Motion design

### Principios
- Spring antes que easing para interacciones físicas
- easeOut para elementos que entran a pantalla
- easeIn para elementos que salen
- easeInOutBack para elementos que necesitan energía/personalidad

### Animaciones de ventana (macOS)
| Evento | Curva | Duración | Escala inicial |
|--------|-------|----------|---------------|
| Primera aparición | easeInOutBack | 0.33s | 0.5 → 1.0 |
| Aparición normal | easeOut | 0.2s | 0.9 → 1.0 |
| Desaparición | easeIn | 0.15s | 1.0 → 0.95 |

### Efectos de luz / glow
- Usar glow solo en momentos de "primera vez" o logro
- Color del glow = color de acento de la app
- Implementación: NSPanel child window con CAShapeLayer + shadowPath
  (NO layer shadow en contentView — está clippeado por masksToBounds)
- Timing: fade in con el elemento → hold 0.2s → fade out 0.3s

### Curvas recomendadas
| Efecto | CAMediaTimingFunction |
|--------|-----------------------|
| Entrada natural | `.easeOut` |
| Entrada con energía | `controlPoints: 0.68, -0.6, 0.32, 1.6` (easeInOutBack) |
| Salida suave | `.easeIn` |
| Rebote leve | `.spring(duration: 0.4, bounce: 0.15)` |
```

### Mejora 2: Liquid Glass — patrón aprobado para macOS

Este es el stack de UI de referencia aprobado y probado en producción. Usarlo como base para nuevos proyectos macOS.

```swift
// MARK: — Ventana principal (launcher / panel flotante)
// macOS 26+
if #available(macOS 26, *) {
    ZStack {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .glassEffect(
                LiquidGlassStyle.clear.glass(
                    tintEnabled: false,
                    interactive: false,
                    defaultTint: Color.black.opacity(1.0)
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.4))          // capa de oscuridad
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)  // borde sutil
    }
}

// macOS 14–25 (fallback)
ZStack {
    VisualEffectBlur(material: .sidebar)
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color.black.opacity(0.28))
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(Color.black.opacity(0.95), lineWidth: 1)
}
.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
```

```swift
// MARK: — Cards (Settings / paneles secundarios)
// macOS 26+
RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    .glassEffect(
        LiquidGlassStyle.regular.glass(tintEnabled: false, interactive: false),
        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    )

// macOS 14–25 (fallback)
RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    .fill(Color.black.opacity(0.16))
    .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
```

```swift
// MARK: — Campos de texto con foco naranja
// macOS 26+
RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    .fill(Color.black.opacity(0.6))
    .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                isFocused ? accentOrange.opacity(0.9) : Color.white.opacity(0.18),
                lineWidth: isFocused ? 1.5 : 0.75
            )
    }

// macOS 14–25 (fallback)
RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    .fill(Color.black)
    .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(isFocused ? accentOrange : .black, lineWidth: 1)
    }
```

### Regla de uso: cuándo usar clear vs regular

| Variante | Cuándo |
|----------|--------|
| `LiquidGlassStyle.clear` | Ventana principal / launcher — sobre wallpaper |
| `LiquidGlassStyle.regular` | Cards internas, paneles, settings |
| **Nunca mezclar** clear y regular en la misma superficie | |

### La capa negra es obligatoria en macOS 26

Sin `Color.black.opacity(0.4)` sobre el glass, la ventana recoge el color del wallpaper (verde, azul, lo que sea) y la UI se ve inconsistente. Esta capa da la apariencia oscura estable independiente del wallpaper.

---

## 3. Woz — Coder

### Problema crítico
El skill de Woz está enfocado en iOS/SwiftUI. Esta app es macOS con AppKit, y hubo múltiples problemas no cubiertos.

### Mejora: Agregar sección AppKit/macOS

```markdown
## AppKit — patrones macOS que conoces

### Ventanas flotantes (launchers, paneles)
- Usa `NSPanel` con `.borderless + .nonactivatingPanel` para overlays
- Usa `NSStatusItem` para menu bar icons
- `button.sendAction(on: [.leftMouseUp, .rightMouseUp])` para diferenciar clicks
- `window.addChildWindow(panel, ordered: .above)` para efectos visuales

### Glow externo a una ventana
```swift
// El contentView.layer shadow está clippeado — NO funciona para glow externo
// Solución: NSPanel child window con CAShapeLayer + shadowPath
let glowLayer = CAShapeLayer()
glowLayer.shadowPath = CGPath(roundedRect: launcherRect, 
                               cornerWidth: radius, cornerHeight: radius, transform: nil)
glowLayer.fillColor = NSColor.clear.cgColor
glowLayer.shadowColor = NSColor(red: 1.0, green: 0.38, blue: 0.0, alpha: 1.0).cgColor
glowLayer.shadowOffset = .zero
glowLayer.shadowRadius = 40
glowLayer.shadowOpacity = 1.0
```

### Swift 6 + AppKit: trampas comunes
- `NSAnimationContext.completionHandler` no está marcado como `@MainActor`
  → Usar `MainActor.assumeIsolated { }` dentro del completion handler
- `NSWindow.orderOut`, `removeChildWindow` → siempre en `@MainActor`
- Crear glow panels DENTRO del `asyncAfter`, no antes — evita flash en primer render

### CALayer animations (macOS)
- Para escala desde el centro: ajustar `anchorPoint` Y `position` juntos
  ```swift
  layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
  layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
  ```
- `CABasicAnimation` + `fillMode = .forwards` + `isRemovedOnCompletion = false`
- Limpiar con `layer.removeAnimation(forKey:)` + resetear `transform` al terminar

### easeInOutBack en CAMediaTimingFunction
```swift
// No existe como preset — usar controlPoints:
CAMediaTimingFunction(controlPoints: 0.68, -0.6, 0.32, 1.6)
```

### Keychain para tokens de API
- Siempre Keychain, nunca UserDefaults para credenciales
- `KeychainStore.save(_:service:account:)` al guardar
- Migrar tokens legacy si el service key cambia
```

---

## 4. Agente faltante: Tuner / Refinador

### Problema
El patrón más repetido en producción: implementar → ver resultado → ajustar un valor → repetir 4–6 veces. Ningún agente actual cubre este modo.

### Sugerencia
Agregar al skill de Woz un modo explícito:

```markdown
## Modo tuning

Cuando el usuario da feedback visual ("más rápido", "más suave", "muy intenso", "más corto"):
1. Identificar el valor exacto responsable en el código (1 variable)
2. Proponer el nuevo valor con razón breve
3. Editar, compilar, confirmar
4. No preguntar confirmación — ajustar y esperar feedback
5. Una edición por turno — no acumular cambios

Escala de referencia para timings:
- "muy rápido" → ÷ 2
- "un poco más rápido" → × 0.7
- "más lento" → × 1.5
- "muy lento" → × 2
```

---

## 5. Avie — Arquitecto

### Mejora: Agregar análisis de seguridad de integraciones

```markdown
## Seguridad de APIs externas

Checklist antes de integrar cualquier API:
- [ ] ¿El token/key va al Keychain? (nunca UserDefaults ni código)
- [ ] ¿Solo se usan los endpoints necesarios? (principio de mínimo privilegio)
- [ ] ¿Todos los requests son read-only si la app no necesita escribir?
- [ ] ¿Hay un "kill switch" (revocar token) sin necesidad de actualizar la app?
- [ ] ¿La cuenta usada tiene el rol mínimo necesario en el servicio?

Para Toggl (y similares):
- Usar cuenta dedicada con rol Member (no Admin)
- Member no puede modificar proyectos, clientes, ni workspace
- Si el token se compromete → regenerar en el dashboard del servicio
- Dos capas independientes: código (read-only) + servidor (permisos de rol)
```

---

## 6. Lo que funcionó bien — mantener

- **DESIGN.md como fuente de verdad** — cuando existe y está actualizado, Woz implementa sin preguntar
- **Commits semánticos con versión** — `Release v0.X — descripción` hace el historial muy legible
- **Orange como único color de acento** — una sola decisión de color aplicada consistentemente en toda la app (bordes de foco, botón CTA, glow, íconos activos)
- **Continuous Corners en todo** — regla sin excepciones, resultado visual consistente

---

## Resumen de cambios prioritarios

| Prioridad | Agente | Cambio |
|-----------|--------|--------|
| 🔴 Alta | **Woz** | Agregar sección AppKit/macOS con patrones reales |
| 🔴 Alta | **Jonny** | Agregar sección Motion Design + patrones Liquid Glass probados |
| 🟡 Media | **Steve** | Agregar modo iteración para apps existentes |
| 🟡 Media | **Woz** | Agregar modo Tuning (ajustes rápidos sin preguntar) |
| 🟢 Baja | **Avie** | Agregar checklist de seguridad para APIs externas |
