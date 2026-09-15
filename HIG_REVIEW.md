# Auditoría HIG — Fintrol v1

**Auditor:** Larry Tesler, HIG Reviewer del equipo AppleAppLab  
**Fecha:** 2026-09-15  
**Plataforma:** iOS 26+ / macOS 26+ (SwiftUI, Liquid Glass)  
**Entregable:** Auditoría contra Human Interface Guidelines de Apple + Liquid Glass (iOS 26/macOS Tahoe)

---

## Resumen Ejecutivo

**Hallazgos totales:** 4  
- 🔴 **Bloqueantes:** 1
- 🟡 **Altos:** 1  
- 🔵 **Medios:** 2

**Estado general:** La arquitectura de navegación y materiales es correcta. Las violaciones halladas son específicas de componentes (Dynamic Type, swipe actions) y corregibles con cambios de una línea.

---

## Hallazgos por Severidad

### 🔴 BLOQUEANTE

#### 1. Swipe-to-delete en líneas recurrentes/suscripción viola expectativa HIG

**Archivo:** `/Users/yuno/Documents/GitSync/Fintrol/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:75-81`

**Problema:**  
Según DESIGN_LIQUID.md (línea 325), cuando un usuario hace swipe-left en una línea de origen recurrente/suscripción/carryOver, **debe abrir el modo edición inline** (no eliminar, porque la línea se regenerará). Actualmente, el código **no define swipeActions para líneas no-manual**, lo que significa que swiping hace nada — viola la expectativa de que toda fila responde a swipe.

```swift
// ACTUAL (líneas 75-81):
.swipeActions(edge: .trailing) {
    if line.origin == .manual, let onDelete {  // ← Solo manual
        Button(role: .destructive, action: onDelete) {
            Label("Eliminar", systemImage: "trash")
        }
    }
}
```

**Por qué importa:**  
El usuario espera que swipe-left en cualquier fila haga algo. El silencio (ninguna acción) rompe el modelo mental de "el swipe funciona para todas las filas". Aunque internamente sea correcto (no queremos eliminar filas auto-generadas), la ausencia de feedback es confusa.

**Corrección:**  
Agregar swipe action para líneas no-manual que abra edit inline:

```swift
.swipeActions(edge: .trailing) {
    if line.origin == .manual, let onDelete {
        Button(role: .destructive, action: onDelete) {
            Label("Eliminar", systemImage: "trash")
        }
    } else {
        Button(action: onStartEditing) {
            Label("Editar", systemImage: "pencil")
        }
        .tint(.blue)
    }
}
```

---

### 🟡 ALTO

#### 2. SobranteBadge: tamaño de 44pt sin `relativeTo:` rompe Dynamic Type

**Archivo:** `/Users/yuno/Documents/GitSync/Fintrol/Apps/Fintrol/Fintrol/UI/SobranteBadge.swift:31`

**Problema:**  
El badge del sobrante usa `.font(.system(size: 44, weight: .bold, design: .default))` pero **omite el modificador `relativeTo: .largeTitle`** especificado en DESIGN_LIQUID.md (línea 119). Sin `relativeTo:`, el sistema no escala el texto con Dynamic Type — usuarios con tamaños de fuente grande (accesibilidad) verán un badge en 44pt fijo, que se verá desproporcionadamente pequeño comparado al texto circundante.

```swift
// ACTUAL (línea 31):
Text(sobrante.currencyString())
    .font(.system(size: 44, weight: .bold, design: .default))
    // Falta: .font(...).relativeTo(.largeTitle)
```

**Por qué importa:**  
La especificación HIG (y DESIGN_LIQUID.md) exige Dynamic Type sin excepciones. El badge es el elemento **más importante de la pantalla** (per DESIGN_LIQUID.md) — un usuario con vision deficiente que necesita fuentes grandes tiene aún más razón para verlo escalado correctamente.

**Verificación:**  
Simular con `Environment(\.sizeCategory, .accessibilityExtraLarge)` — actualmente el badge no crece.

**Corrección:**  
Cambiar línea 31 a:

```swift
Text(sobrante.currencyString())
    .font(.system(size: 44, weight: .bold, design: .default).relativeTo(.largeTitle))
    .monospacedDigit()
```

O alternativamente (más idiomático):

```swift
Text(sobrante.currencyString())
    .font(.largeTitle.weight(.bold))
    .monospacedDigit()
```

---

### 🔵 MEDIOS

#### 3. Ícono de origen de línea: 12pt hardcodeado sin escalado Dynamic Type

**Archivo:** `/Users/yuno/Documents/GitSync/Fintrol/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:51`

**Problema:**  
Los íconos de origen (`arrow.triangle.2.circlepath`, `pencil`, `arrow.turn.down.right`) se renderizan con tamaño hardcodeado:

```swift
if let originIcon {
    Image(systemName: originIcon)
        .font(.system(size: 12))  // ← Fijo
        .foregroundStyle(.secondary)
}
```

Un tamaño hardcodeado 12pt significa que en Dynamic Type `accessibilityExtraLarge`, el ícono sigue siendo 12pt mientras el texto de al lado crece a ~24pt — desbalance visual y posible confusión de la jerarquía.

**Severidad:** Media, no bloqueante, porque:
- El ícono es un **indicador** (no contenido primario).
- Su tamaño pequeño es intencional por DESIGN_LIQUID.md línea 322 ("tamaño 12pt").
- Pero los usuarios que necesitan fuentes grandes merecen un ícono escalado.

**Corrección:**  
Usar un font relativo:

```swift
Image(systemName: originIcon)
    .font(.caption.weight(.regular))  // o .font(.system(.caption))
    .foregroundStyle(.secondary)
```

O si se quiere mantener 12pt como baseline pero permitir escala:

```swift
Image(systemName: originIcon)
    .font(.system(size: 12).relativeTo(.body))
    .foregroundStyle(.secondary)
```

---

#### 4. Falta accesibilidad de color en indicador de origen recurrente

**Archivo:** `/Users/yuno/Documents/GitSync/Fintrol/Apps/Fintrol/Fintrol/UI/LineItemRow.swift:14-20`

**Problema:**  
El ícono de origen recurrente es el **único indicador visual** de que una línea es auto-generada. Per WCAG 2.2 AA, no se debe comunicar información **solo** por color o ícono pequeño sin texto de soporte. Actualmente:

- Si el usuario desactiva iconos SF (modo accesibilidad extrema) o usa un lector de pantalla, la línea sin ícono parece una línea normal.
- El contexto se pierde.

**Por qué importa:**  
Es especialmente crítico en una app financiera: el usuario necesita saber que una línea NO fue capturada manualmente (es recurrente/carry-over), porque esto afecta a su entendimiento de "¿qué me está pasando con mis números?".

**Nota:** Woz ya tiene `accessibilityLabel` global en algunos componentes, pero LineItemRow no tiene label específico que señale el origen.

**Corrección:**  
Agregar `accessibilityLabel` o `accessibilityValue` en el bloque donde se renderiza originIcon:

```swift
if let originIcon {
    Image(systemName: originIcon)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .accessibilityLabel(
            line.origin == .recurring ? "Automático — recurrente" :
            line.origin == .subscription ? "Automático — suscripción" :
            line.origin == .carryOver ? "Arrastrado de la quincena anterior" :
            ""
        )
}
```

---

## Respuestas a Preguntas de Jonny

### (a) Jump Sheet — ¿DatePicker nativo vs Picker custom?

**Conclusión:** El Picker custom es la decisión correcta.

**Razonamiento:**
- Fintrol usa `PeriodHalf` (1–15 / 16–fin), un concepto que **no existe en DatePicker estándar** (que maneja solo día del mes, que no alinea con quincenas).
- DatePicker + validación posterior sería más complejo que el current approach (año → mes → half segmentado).
- El control segmentado para half es intuitivo y visualmente claro — el usuario ve las dos opciones lado a lado.

**Veredicto:** Mantener actual. No cambiar.

---

### (b) Nested radius 4pt vs 12pt — ¿excepción justificada?

**Conclusión:** Sí, es la excepción correcta documentada.

**Análisis:**
Per DESIGN_LIQUID.md (línea 173–175): el radio anidado matemático es `20 − 16 = 4pt` para filas en **reposo** (sin fondo). Pero cuando la fila entra en **edit inline**, gana un fondo elevado (`AppBackgroundSecondary`) y se convierte en un campo propio — en ese contexto, 12pt es el radio correcto para una "mini-card" editable.

Código actual (LineItemRow:131) usa 12pt para edit mode — **correcto**.

**Veredicto:** Sin cambios. Diseño es coherente con la documentación.

---

### (c) Swipe-to-delete deshabilitado en líneas recurrentes — ¿viola expectativa?

**Conclusión:** Sí, viola la expectativa — reportado arriba como issue 🔴 BLOQUEANTE.

**Análisis:**
- El user esperan que swipe-left en cualquier fila haga algo.
- Actualmente, swiping en líneas recurrentes/suscripción/carryOver hace nada.
- La solución per DESIGN_LIQUID.md es abrir edit inline, no silencio.

**Acción:** Corrección en LineItemRow (ver arriba).

---

## Auditoría Completada — Checklist Resumen

✅ **Navegación** — TabView (iOS) + NavigationSplitView (macOS), patrones correctos  
✅ **Tipografía** — Dynamic Type usado en estilos de texto, excepto 2 overrides documentadas  
✅ **Tap targets** — 44pt+ en filas, botones, toggles  
✅ **Colores semánticos** — Sin hex hardcodeado, uso correcto de Color() y `.systemGreen`/`.systemRed`/`.systemYellow`  
✅ **Dark Mode** — Funcional, fondos `AppBackground` theme-aware  
✅ **Liquid Glass** — Correcto: solo en navegación (tab bar, toolbar, sheets, botones Glass*), nunca en content layer  
✅ **Frost material** — Correcto: cards de contenido (INCOME/EXPENSES/SummaryPanel) usan `.ultraThinMaterial.opacity(0.5)`  
✅ **Continuous corners** — Todos los borderRadius usan `.continuous`, ningún `.circular`  
✅ **Feedback haptic** — Presente (success, impact, selection según DESIGN_LIQUID.md)  
✅ **Animaciones** — Respetan `reduceMotion`, spring/easeOut correctas  
✅ **Permisos biométricos** — LockView correcta, sin datos reales detrás, Face ID/Touch ID detectado dinamicamente  
⚠️ **Dynamic Type** — 2 issues: SobranteBadge sin `relativeTo:`, ícono 12pt hardcodeado  
⚠️ **Accesibilidad de color** — Falta label descriptivo para origen de línea  
⚠️ **Swipe actions** — Falta acción para líneas no-manual  

---

## Resumen de Bloqueantes + Altos

1. **LineItemRow swipe-to-delete:** Agregar swipeAction para origen no-manual que abre edit  
2. **SobranteBadge Dynamic Type:** Agregar `relativeTo: .largeTitle` al font de 44pt  

Ambos son cambios de una línea. Una vez aplicados, la app cumple HIG sin excepciones.

---

## Notas para Woz

- **PROJECT_LEARNINGS.md:** Documentar LineItemRow y SobranteBadge como candidatos a generalizar en AppleAppLabUI (patrón de "large status badge" + "list row with inline edit").
- **DESIGN_LIQUID.md:** Considerar agregar nota explícita sobre `relativeTo:` en texto styles que usen tamaños fijos.
- **Accesibilidad:** Revisar todas las LineItemRow en el proyecto para asegurar que origen no-manual siempre tiene label descriptivo o alt-text.

---

**Auditoría completada:** 2026-09-15 · No se encontraron violaciones de Liquid Glass · Navegación conforme · Materiales conformes · 4 hallazgos totales (1 bloqueante, 1 alto, 2 medios) — todos corregibles.
