# Known Issues — Soluciones probadas en producción
> Problemas reales encontrados en **New PROject** (macOS launcher).  
> Referencia rápida para no volver a perder tiempo en los mismos errores.

---

## 1. Dos íconos en la barra de menú (menu bar)

**Síntoma:** Aparecen dos íconos de folder en la menu bar — uno grande a la izquierda y uno pequeño a la derecha.

**Causa:** `MenuBarExtra` en `App.swift` Y `NSStatusItem` manual en `AppDelegate` creando dos íconos simultáneamente.

**Solución:** Elegir uno solo. Si necesitas diferenciación de clic izquierdo/derecho (funcionalidad que `MenuBarExtra` no soporta), usar `NSStatusItem` manual y eliminar el bloque `MenuBarExtra` del `App.swift`:
```swift
// App.swift — eliminar esto:
// MenuBarExtra("App", systemImage: "folder") { ... }

// Dejar solo:
var body: some Scene {
    Settings { EmptyView() }
}
```

**Tiempo perdido:** ~1 hora buscando el origen del segundo ícono.

---

## 2. Ícono de menu bar no aparece en macOS 26

**Síntoma:** El ícono existe en código pero no se ve en la barra en macOS 26. En macOS 15 sí aparece.

**Causa:** `setupStatusItem()` se llama en `applicationDidFinishLaunching`, pero en macOS 26 el subsistema del status bar aún no está listo en ese momento. `statusItem?.button` retorna `nil` silenciosamente y el ícono nunca se configura.

**Solución:** Diferir la configuración al siguiente ciclo del run loop:
```swift
private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    DispatchQueue.main.async { [weak self] in
        guard let self, let button = self.statusItem?.button else { return }
        // configurar button aquí
    }
}
```

**Tiempo perdido:** ~2 horas.

---

## 3. Ícono de menu bar negro / sin color

**Síntoma:** El ícono aparece pero completamente negro, sin el tinte esperado.

**Causa:** Usar `image.isTemplate = true` + `button.contentTintColor` juntos. Con imágenes template, AppKit maneja el color internamente e ignora `contentTintColor`.

**Solución:** Con `isTemplate = true` no usar `contentTintColor`. El sistema aplica el color correcto automáticamente (oscuro en light mode, claro en dark mode). Si necesitas color custom, usar `isTemplate = false` y pintar la imagen manualmente.

```swift
image.isTemplate = true   // ✅ el sistema maneja el color
// button.contentTintColor = .orange  // ❌ ignorado con isTemplate=true
```

---

## 4. Liquid Glass muestra fondo marrón/sólido en vez de glass

**Síntoma:** La ventana muestra un fondo marrón opaco en lugar del efecto glass translúcido.

**Causa:** El branch `darkFallback` tenía prioridad sobre el branch `#available(macOS 26, *)`. El orden de los `if` importa.

**Solución:** Siempre verificar `#available` PRIMERO, antes de cualquier otro branch:
```swift
// ✅ Correcto — macOS 26 primero
if #available(macOS 26, *) {
    // liquid glass
} else if darkFallback {
    // fallback oscuro
} else {
    // fallback claro
}

// ❌ Incorrecto — darkFallback puede ganar antes
if darkFallback {
    // esto toma prioridad aunque estemos en macOS 26
} else if #available(macOS 26, *) { ... }
```

---

## 5. Liquid Glass recoge el color del wallpaper

**Síntoma:** La ventana glass se ve verde si el wallpaper es verde, naranja si es naranja — inconsistente con el diseño oscuro.

**Causa:** El glass puro sin tinte adapta el color del entorno. Es el comportamiento esperado del glass, pero no deseable si la UI es dark-first.

**Solución:** Agregar una capa de `Color.black.opacity(0.4)` encima del glass. Esta capa neutraliza el color del wallpaper y mantiene la apariencia oscura consistente:
```swift
ZStack {
    RoundedRectangle(cornerRadius: r, style: .continuous)
        .glassEffect(LiquidGlassStyle.clear.glass(...), in: ...)
    RoundedRectangle(cornerRadius: r, style: .continuous)
        .fill(Color.black.opacity(0.4))   // ← esta capa es obligatoria
    RoundedRectangle(cornerRadius: r, style: .continuous)
        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
}
```

**Tiempo perdido:** ~3 horas ajustando tint, opacidades y estilos de glass.

---

## 6. List dentro de ScrollView colapsa a altura cero

**Síntoma:** Una vista con `List` dentro de `ScrollView` no muestra contenido aunque haya datos. La vista aparece en blanco.

**Causa:** `List` en SwiftUI/macOS tiene su propio scroll interno. Cuando se anida dentro de un `ScrollView` externo, el `List` colapsa a altura cero porque no sabe cuánto espacio ocupar.

**Solución:** Reemplazar `List` con `LazyVStack`:
```swift
// ❌ No funciona dentro de ScrollView
List(items) { item in
    ItemRow(item: item)
}

// ✅ Funciona dentro de ScrollView
LazyVStack(spacing: 4) {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}
```

---

## 7. Fatal crash: "No Observable object of type X found"

**Síntoma:** La app crashea al abrir una ventana secundaria (Settings) con el error "No Observable object of type RecentProjectsStore found in the view hierarchy".

**Causa:** El `@Environment` de un `@Observable` store no se propaga automáticamente a ventanas nuevas creadas con `NSHostingView`. Cada `NSHostingView` es un árbol SwiftUI independiente.

**Solución:** Pasar el store explícitamente en el `WindowController` que crea la ventana:
```swift
// En el WindowController:
func open(appState: AppState, myStore: MyStore) {
    let content = SettingsView()
        .environment(appState)
        .environment(myStore)   // ← pasar todos los stores necesarios
    NSHostingView(rootView: content)
}
```

---

## 8. NSWorkspace abre la carpeta padre en vez de la carpeta misma

**Síntoma:** Al abrir una carpeta desde la app, Finder muestra el directorio padre con la carpeta seleccionada — no el contenido de la carpeta.

**Causa:** `NSWorkspace.shared.activateFileViewerSelecting([url])` selecciona el item en su directorio padre.

**Solución:** Usar `NSWorkspace.shared.open(url)` para abrir el contenido de la carpeta directamente:
```swift
// ❌ Abre el padre y selecciona la carpeta
NSWorkspace.shared.activateFileViewerSelecting([url])

// ✅ Abre el contenido de la carpeta
NSWorkspace.shared.open(url)
```

---

## 9. Glow shadow clippeado — no se ve fuera de la ventana

**Síntoma:** Se agrega `shadowColor` + `shadowRadius` al `contentView.layer` para crear un glow, pero no aparece nada fuera de los límites de la ventana.

**Causa:** El `hostingView` tiene `layer.masksToBounds = true` (necesario para el `cornerRadius`). Esto clipea todo, incluyendo el shadow, dentro de los límites del layer.

**Solución:** Crear un `NSPanel` hijo independiente posicionado detrás (o encima) de la ventana principal, con un `CAShapeLayer` usando `shadowPath`:
```swift
// El glow vive en su propia ventana transparente
let glowPanel = NSPanel(contentRect: window.frame.insetBy(dx: -80, dy: -80), ...)
glowPanel.isOpaque = false
glowPanel.backgroundColor = .clear

let glowLayer = CAShapeLayer()
glowLayer.shadowPath = CGPath(roundedRect: launcherRect, cornerWidth: r, cornerHeight: r, transform: nil)
glowLayer.fillColor = NSColor.clear.cgColor
glowLayer.shadowColor = NSColor.orange.cgColor
glowLayer.shadowOffset = .zero
glowLayer.shadowRadius = 40
glowLayer.shadowOpacity = 1.0

window.addChildWindow(glowPanel, ordered: .above)
```

**Tiempo perdido:** ~1.5 horas.

---

## 10. Flash de panel vacío al primer render

**Síntoma:** Al primera vez que aparece la ventana, se ve un flash de un cuadro vacío por algunos milisegundos antes de la animación.

**Causa:** El `NSPanel` del glow se crea y se adjunta como `childWindow` antes de `makeKeyAndOrderFront`. Aunque `alphaValue = 0`, hay un frame donde el sistema lo renderiza antes de aplicar el alpha.

**Solución:** Crear el panel DENTRO del bloque `asyncAfter`, no antes. Así no existe en memoria ni en pantalla hasta el momento exacto de la animación:
```swift
// ❌ Panel creado antes — puede flashear
let glowPanel = makeGlowPanel()
window.addChildWindow(glowPanel, ordered: .above)
window.makeKeyAndOrderFront(nil)

DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    // animar...
}

// ✅ Panel creado justo cuando se necesita
window.makeKeyAndOrderFront(nil)

DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak window] in
    let glowPanel = makeGlowPanel()   // ← aquí
    window?.addChildWindow(glowPanel, ordered: .above)
    // animar...
}
```

---

## 11. CALayer scale desde la esquina en vez del centro

**Síntoma:** La animación de scale hace que la ventana crezca desde la esquina inferior izquierda, no desde el centro.

**Causa:** En AppKit, el `anchorPoint` por defecto de un `CALayer` es `(0, 0)` — la esquina inferior izquierda. En iOS es `(0.5, 0.5)` — el centro. Al aplicar `CATransform3DMakeScale`, el origen de la transformación es ese punto.

**Solución:** Ajustar `anchorPoint` Y `position` juntos (cambiar solo `anchorPoint` mueve el layer):
```swift
if let layer = window.contentView?.layer {
    let bounds = layer.bounds
    layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    layer.position = CGPoint(x: bounds.midX, y: bounds.midY)  // ← obligatorio
    layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
}
```

---

## 12. Warnings de @MainActor en NSAnimationContext

**Síntoma:** Xcode muestra warnings de Swift 6: "Call to main actor-isolated instance method 'orderOut' in a synchronous nonisolated context".

**Causa:** El `completionHandler` de `NSAnimationContext.runAnimationGroup` no está marcado como `@MainActor` en el SDK, aunque corre en el main thread. Swift 6 strict concurrency lo detecta como problema potencial.

**Solución:** Envolver el código del completion handler en `MainActor.assumeIsolated`:
```swift
NSAnimationContext.runAnimationGroup({ ctx in
    // animación...
}, completionHandler: {
    MainActor.assumeIsolated {
        window?.removeChildWindow(panel)
        panel.orderOut(nil)
    }
})
```

---

## 13. @Bindable en @Environment crea copia local

**Síntoma:** Cambios al store desde la vista no se propagan — cada modificación parece perderse.

**Causa:** Usar `@Bindable var store = store` dentro del `body` crea una copia local del store en esa línea, no un binding al store del environment.

**Solución:** Con `@Observable`, usar el store directamente desde `@Environment` sin crear una variable intermedia:
```swift
// ❌ Crea copia local
@Environment(MyStore.self) private var store
var body: some View {
    @Bindable var store = store  // ← copia, no binding al original
}

// ✅ Usar @Bindable directamente en la propiedad
@Environment(MyStore.self) private var store
// Y en el body usar $store.property directamente
```

---

## 14. editMode no disponible en macOS

**Síntoma:** Error de compilación: `'editMode' is unavailable in macOS`.

**Causa:** `.environment(\.editMode, .constant(.active))` es una API de iOS/iPadOS solamente.

**Solución:** En macOS usar `LazyVStack` con botones manuales para delete/reorder en lugar de `List` con `editMode`.

---

## Resumen rápido

| # | Problema | Causa raíz | Fix en una línea |
|---|----------|-----------|-----------------|
| 1 | Dos íconos menu bar | MenuBarExtra + NSStatusItem simultáneos | Eliminar MenuBarExtra de App.swift |
| 2 | Ícono no aparece macOS 26 | Status bar no listo en didFinishLaunching | Defer con DispatchQueue.main.async |
| 3 | Ícono negro sin tinte | isTemplate + contentTintColor incompatibles | Quitar contentTintColor |
| 4 | Glass muestra marrón sólido | darkFallback evalúa antes que #available | Poner #available siempre primero |
| 5 | Glass recoge color wallpaper | Glass puro sin tinte adapta el entorno | Agregar Color.black.opacity(0.4) encima |
| 6 | List colapsa en ScrollView | List tiene scroll interno, no puede anidarse | Reemplazar con LazyVStack |
| 7 | Crash "No Observable found" | @Environment no se propaga a NSHostingView nuevos | Pasar stores explícitamente en el WindowController |
| 8 | Finder abre carpeta padre | activateFileViewerSelecting selecciona, no abre | Usar NSWorkspace.shared.open(url) |
| 9 | Glow shadow no visible | masksToBounds clippea la sombra del layer | Usar NSPanel hijo con CAShapeLayer + shadowPath |
| 10 | Flash de panel vacío | Panel creado antes del makeKeyAndOrderFront | Crear el panel dentro del asyncAfter |
| 11 | Scale desde esquina | anchorPoint default (0,0) en AppKit | Ajustar anchorPoint + position juntos |
| 12 | Warnings @MainActor en NSAnimationContext | completionHandler no marcado como @MainActor en SDK | MainActor.assumeIsolated { } en el completion |
| 13 | @Bindable crea copia | var local en body copia el store | Usar @Environment directamente, sin var intermedio |
| 14 | editMode no compila | API solo de iOS | Usar LazyVStack + botones manuales en macOS |
