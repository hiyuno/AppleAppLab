# Searching & Navigation Patterns

**Fuentes**:
- https://developer.apple.com/design/human-interface-guidelines/searching
- https://developer.apple.com/design/human-interface-guidelines/search-fields
- https://developer.apple.com/design/human-interface-guidelines/navigation-and-search
- https://www.swiftyplace.com/blog/swiftui-search-bar-best-practices-and-examples
- https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/

**En una frase**: Cómo diseñar interfaces de búsqueda efectivas y posicionar search bars para que usuarios encuentren contenido rápidamente.

---

## Cuándo usar Search

- **Usar search** cuando el usuario necesita buscar dentro de una colección grande o no familiar.
- **No forzar search** si el contenido cabe en una browse view o es pequeño.
- **Combinar search + browse** para máxima flexibilidad (ej. listar categorías + search bar).

---

## Search Bar Design (iOS)

### Posicionamiento

1. **Navigation Bar** (preferido): Search bar en la top navigation bar
   - Usuarios la buscan instintivamente allí.
   - Más espacio para contenido.
   - Compatible con grandes listas.

2. **Content Area**: Search bar como primer elemento del content
   - Cuando search es interacción principal.
   - Menos común en iOS (mejor para macOS/iPad).

3. **Toolbar** (iOS 26+ con Liquid Glass): Minimizar search en un botón
   - Si search no es el foco principal.
   - Usa `searchToolbarBehavior()` modifier en SwiftUI para esta versión dinámico.
   - Expande a search bar completa cuando usuario lo selecciona.

### Comportamiento

- **Placeholder text**: Describir qué buscar ("Search songs", "Find contacts").
- **Search Scopes** (filtros): Permitir search within categorías si hay muchas opciones.
  - Ej. "Recent", "Contacts", "Messages".
- **Search Results**: Mostrar resultados actualizados mientras escribe (instant search).
  - O esperar a que toque "Search" en keyboard (on-submit search).
  - **Recomendación**: Instant search para mejor UX, especialmente en listas.

### Keyboard & Search Suggestions (iOS 16+)

- **Search Tokens**: Permitir buscar con atributos filtrados (ej. "sender: john date: 2024").
- **Suggestions**: Mostrar búsquedas recientes y populares mientras escribe.
- **Scopes**: Cambiar alcance de búsqueda dinámicamente.

---

## Search Field Component

Un search field es un control reutilizable que encapsula:
- Input text con placeholder.
- Clear button (X) al lado.
- Search icon.
- Optional: cancel button al lado derecho.

### Accesibilidad

- **Label implícito**: Search fields tienen magnifying glass que actúa como label visual.
- **VoiceOver**: Anunciar "Search" claramente.
- **Dynamic Type**: Search text scale apropiadamente.

---

## Navigation & Search Integration

**No son mutuamente excluyentes**:
- Navegación jerárquica (tabs → detail) + search global para saltar directamente.
- Ejemplo: Tab de Music → ver artistas (navegación) O usar search global.

### Best Practices

1. **Global Search** (menos común): Search un único scope global de toda la app.
2. **Scoped Search**: Search solamente dentro del tab/section actual.
3. **Hybrid**: Search global + refinar con filters/scopes después.

---

## iOS 26 / Liquid Glass Updates

**New `searchToolbarBehavior()`**: Controla cómo se comporta la search bar en la navigation toolbar.

```
.searchable(text: $searchText)
.searchToolbarBehavior(.automatic)  // Expande/contrae dinámicamente
```

- **Automatic**: Decide basado en espacio disponible.
- **Compact**: Siempre mostrar como ícono, expandir en tap.
- **Visible**: Siempre mostrar search bar completa.

---

## Common Patterns

| Scenario | Pattern |
|----------|---------|
| Large collection (100s) | Navigation bar search + instant results |
| Medium list (10-50) | In-content search bar, or browse + search |
| Hierarchical (categories) | Browse first, search within section |
| Mobile + Desktop | iOS: nav bar; macOS: sidebar search |

---

## Accesibilidad & VoiceOver

- Search bar siempre announce como "Search, text field".
- Placeholder text must be descriptive.
- Clear button must be reachable via VoiceOver.
- Search results deben ser anunciados (ej. "5 results found").

---

## Code Example: SwiftUI Search

```swift
@State private var searchText = ""

VStack {
    List(filteredItems) { item in
        Text(item.name)
    }
    .searchable(text: $searchText, prompt: "Search items")
    .searchScopes($selectedScope) {
        ForEach(SearchScope.allCases, id: \.self) { scope in
            Text(scope.rawValue).tag(scope)
        }
    }
}
```

---

## Fecha de recolección

2026-08-24
