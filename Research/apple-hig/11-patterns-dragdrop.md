# Drag and Drop Pattern

**Fuentes**:
- https://developers.apple.com/design/human-interface-guidelines/patterns/drag-and-drop/
- https://developer.apple.com/tutorials/app-dev-training/supporting-drag-and-drop
- https://developers.apple.com/design/human-interface-guidelines/macos/user-interaction/drag-and-drop/

**En una frase**: Drag and drop es un patrón intuitivo para mover o copiar contenido entre apps o dentro de la misma, disponible en iOS, iPadOS y macOS con soporte multi-item.

**Fecha de recolección**: 2026-08-24 (Pasada 3)

---

## Cuándo Usar Drag and Drop

✓ **Usar cuando**:
- El usuario necesita mover o copiar contenido entre destinos
- La operación es más intuitiva visualmente que mediante botones (ej. reorganizar listas, asignar ítems a categorías)
- Quieres permitir que usuarios experimenten sin ansiedad (undo es posible)
- El contexto hace evidente qué se puede arrastrar (ej. cartas en un juego, archivos en el Finder)

✗ **Evitar si**:
- La operación es crítica/destructiva y requiere confirmación explícita
- El target de drop no es visualmente evidente
- Usuarios con limitaciones motoras dependen de alternativas (accesibilidad crítica)

---

## Diseño en iOS/iPadOS

### Soporte Multi-Item
- Permitir arrastrar múltiples ítems seleccionados juntos, no uno a uno
- En iPadOS, usuarios pueden empezar a arrastrar y agregar más ítems sin soltar
- Proporciona feedback visual que agrupa ítems durante el drag

### Feedback Visual
- **Drag initiation**: Animar la escala/opacidad del ítem siendo arrastrado
- **Over drop target**: Cambiar el fondo del target, border o highlight para indicar que el drop es válido
- **Drop completion**: Animar el desaparecimiento del original (si es mover) o la inserción del nuevo ítem

### Gesture Recognizers
```swift
// Hacer un View arrastrable (SwiftUI 5+)
Image("photo")
    .draggable(NSItemProvider(contentsOf: imageURL))

// Destino que acepta drops
ZStack {
    RoundedRectangle(cornerRadius: 12)
        .dropDestination(for: URL.self) { urls, _ in
            handleDroppedImages(urls)
            return true
        }
}
```

---

## Diseño en macOS

### Características Expandidas
- Soporte más flexible para tipos de datos (archivos, strings, imágenes, URLs)
- Drag entre aplicaciones es más robusto
- Personalizaciones profundas de comportamiento de drop

### Operaciones de Copia vs Movimiento
- Usar `.move` cuando el ítem desaparece del origen
- Usar `.copy` cuando se duplica contenido
- Si ambas son válidas, dejar que el usuario elija (Command/Option keys determinan la operación)

---

## Consideraciones de Accesibilidad

⚠️ **Crítico**: Drag-and-drop NO debe ser la única forma de realizar una acción.

- **Alternativa de keyboard**: Ofrecer Ctrl+X (cortar), Ctrl+V (pegar) o click+menu
- **VoiceOver**: Proporcionar menu alternativo que describa la acción ("Move to Folder", "Assign to Category")
- **Motor accessibility**: Usuarios con limitaciones motoras pueden no poder sostener un drag

Recomendación: Complementar siempre con opciones en toolbar, menu o sheet.

---

## Patrones Específicos de Drag-Drop

### Reordenamiento de Listas (iOS/macOS)
```swift
List(items, id: \.self, editActions: .move) { item in
    Text(item.name)
}
.onMove { indices, newOffset in
    items.move(fromOffsets: indices, toOffset: newOffset)
}
```

### Cross-App Drag (macOS principalmente)
- Proporcionar múltiples representaciones del ítem (imagen, rich text, plain text) para que apps receptoras elijan qué usar
- Usar `NSDraggingSource` protocol en AppKit o `draggable()` modifier en SwiftUI

### Drag Between Sections
- Validar que el drop destino existe y es válido antes de ejecutar
- Proporcionar visual feedback si el drop es inválido (no resaltar el target, ej. "grayed out")

---

## Mejores Prácticas

1. **Undo es esencial**: Ofrecer siempre la opción de deshacer un drag-drop erróneo. Usuarios aprecian la confianza.
2. **Feedback claro**: El usuario debe saber siempre qué está pasando — el ítem se mueve, se copia, o la acción está inválida.
3. **Multi-item de verdad**: No solo permitir multi-select teórico; si permites drag de múltiples, asegúrate que funciona sin errores.
4. **Documentación visual**: En onboarding o primer uso, mostrar ejemplos de qué se puede arrastrar (ej. "Drag and drop photos here").
5. **Testear en ambas plataformas**: iOS y macOS tienen diferentes capacidades; lo que funciona perfecto en Mac puede ser incómodo en Touch.

---

## Errores Comunes

❌ Drag-drop como único camino → Siempre ofrecer alternativa (botones, menús)  
❌ Drop target no evidente → Usar colores, bordes, o help text  
❌ Sin undo → Crítica frustración si usuario se equivoca  
❌ Ignorar accesibilidad → Keyboard-only users quedan bloqueados  

---

## Referencias Relacionadas

- **Undo & Redo** (01 patterns) — cómo implementar reversibilidad
- **Accessibility** (01 foundations) — alternativas de interacción
- **List & Table** (17 components) — mejor lugar para reordenamiento en iOS
