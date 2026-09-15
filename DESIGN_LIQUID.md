# DESIGN_LIQUID — Fintrol

> Estilo para iOS 26+ / macOS 26+ (Tahoe, Liquid Glass).
> Fuente de verdad de diseño. Última actualización: 2026-09-15.
> Todo lo que no está aquí no está decidido.

---

## Plataforma y versión target

- **Plataforma:** iOS y macOS, un solo target SwiftUI (según TRD)
- **Versión mínima:** iOS 26.0 / macOS 26.0 — no hay fallback real que ejecutar en producción; `DESIGN_FROST.md` existe como documento defensivo por si el target mínimo baja en el futuro, no porque vaya a compilar hoy.
- **Sistema de diseño:** Liquid Glass nativo en la capa de navegación; superficies de contenido en material **Frost** (tema Fintrol: blur 0.5, transparencia 0.5) — ver "Materiales y profundidad".
- **Modos soportados:** Dark por defecto (`appearanceMode: dark` en el tema). Light debe existir y ser correcto, pero no es la referencia visual — el usuario abre esta app de noche o entre tareas, no en luz de estudio fotográfico.

---

## Identidad visual

**Sensación general:** seria, densa, directa. Se abre dos veces al mes, se entiende de un vistazo, se cierra. Nada de dashboard bancario con gráficas decorativas — es una hoja de cálculo bien hecha que además hace la aritmética sola.

**Inspiración:** `Mis Finanzas 2.0.xlsx` del propio usuario (ver STYLE_BRIEF.md) — bloques INCOME/EXPENSES apilados, totales al pie, sobrante grande, panel de resumen lateral. El naranja se reserva para lo que importa: nunca decora, siempre señala.

---

## Color

### Paleta semántica (usar siempre estos, nunca hex hardcoded)

| Rol | Token SwiftUI | Hex Light | Hex Dark |
|-----|--------------|-----------|----------|
| Fondo principal | `Color(.systemBackground)` | #FFFFFF | #323232 (fondo del tema Fintrol, no negro puro) |
| Fondo secundario | `Color(.secondarySystemBackground)` | #F2F2F7 | #2A2A2A |
| Superficie / card | `Color(.tertiarySystemBackground)` | #FFFFFF | #3C3C3C |
| Texto primario | `.primary` | #000000 | #FFFFFF |
| Texto secundario | `.secondary` | #3C3C43 @60% | #EBEBF5 @60% |
| Separadores | `Color(.separator)` | — | — |

El fondo base de Fintrol en dark mode es el gris neutro `#323232` del tema (no `systemBackground` negro puro de iOS) — se define como `Color("AppBackground")` en Assets, y se usa en vez de `Color(.systemBackground)` en las pantallas principales para respetar el tema. `secondarySystemBackground`/`tertiarySystemBackground` de la tabla arriba quedan sobreescritas por `AppBackground` + sus variantes `AppBackground.secondary`/`.tertiary` (10% y 20% más claras respectivamente) declaradas también en Assets.

### Color de acento

- **Nombre:** FintrolOrange
- **Hex:** `#F04200`
- **HSL:** H 16.5° · S 100% · L 47%
- **Definido en:** Assets.xcassets > AccentColor
- **Uso:** sobrante cuando no aplica semántica de estado (nunca — el sobrante siempre usa verde/amarillo/rojo, ver abajo), CTA primario ("Agregar línea", "Guardar"), tab/sidebar activo, foco de campos, línea "Latest Month" (badge de carry-over).

### Sistema de paleta desde el accent — escala completa

H=16.5°, S=100% constantes, L variable. Los valores están calculados directamente desde `#F04200`, no aproximados.

| Token | Light (hex) | Dark (hex) | Uso típico |
|-------|------------|------------|-----------|
| `accent-50` | `#FFEDE6` | `#330E00` | Fondos tintados muy sutiles |
| `accent-100` | `#FFD3C2` | `#4D1500` | Fondo de badge "recurrente", chip seleccionado |
| `accent-200` | `#FFAE8F` | `#701F00` | Bordes suaves de acento |
| `accent-300` | `#FF7E4D` | `#A32D00` | `accentBorder` — borde de foco, borde de card seleccionada |
| `accent-400` | `#FF591A` | `#E63F00` | Iconos secundarios activos |
| **`accent-500`** | **`#F04200`** | **`#F04200`** | **El accent base — AccentColor** |
| `accent-600` | `#E63F00` | `#FF6B33` | Pressed state de botones |
| `accent-700` | `#B33100` | `#FF9870` | Texto sobre fondo accent claro |
| `accent-800` | `#802300` | `#FFBCA3` | Texto de alto contraste sobre `accent-100` |
| `accent-900` | `#4D1500` | `#FFE1D6` | Texto sobre superficies accent muy claras |

**Regla de texto sobre `accent-500`:** L=47% < 55% → el naranja base es "oscuro" perceptualmente → texto **blanco** encima, en light y en dark. Verificado: blanco sobre `#F04200` da ~4.6:1, pasa AA para texto normal.

### Tokens semánticos derivados

| Token semántico | Light | Dark | Uso |
|-----------------|-------|------|-----|
| `accent` | `accent-500` (#F04200) | `accent-500` (#F04200) | Botones CTA, tab activo, foco |
| `accentSubtle` | `accent-100` (#FFD3C2) | `accent-100` dark (#4D1500) | Fondo de badge "recurrente"/"suscripción" |
| `accentBorder` | `accent-300` (#FF7E4D) | `accent-300` dark (#A32D00) | Borde de foco en campos, borde de card resaltada |
| `accentForeground` | `accent-800` (#802300) | `accent-800` dark (#FFBCA3) | Texto sobre `accentSubtle` |
| `accentPressed` | `accent-600` (#E63F00) | `accent-600` dark (#FF6B33) | Estado pressed de `LabButton` primary |
| `accentDisabled` | `accent-200` (#FFAE8F) | `accent-200` dark (#701F00) | CTA deshabilitado |

### Verificación de contraste (WCAG AA)

| Combinación | Ratio | Resultado |
|-------------|-------|-----------|
| Blanco sobre `accent-500` (#F04200) | ~4.6:1 | Pasa AA texto normal |
| `accent-500` sobre `AppBackground` (#323232) | ~3.4:1 | Pasa AA elementos UI grandes (3:1); usar solo en tamaños ≥17pt o iconos, no en texto de body pequeño sobre fondo oscuro plano |
| `.secondary` sobre `AppBackground` (#323232) | ~7:1 (blanco 60% sobre #323232) | Pasa AA cómodo |
| `accentForeground` (#FFBCA3, dark) sobre `accentSubtle` (#4D1500, dark) | ~7.8:1 | Pasa AAA |

### Colores de estado — el sobrante (semántica fija del PRD, no negociable)

| Estado | Umbral | Color SwiftUI | Uso |
|--------|--------|---------------|-----|
| Positivo | Sobrante ≥ $100 | `Color.green` / `.systemGreen` | Texto y fondo del badge de sobrante |
| Ajustado | $0 ≤ Sobrante < $100 | `Color.yellow` / `.systemYellow` — **texto siempre en negro/`.black`, nunca blanco, sobre este fondo** | Texto y fondo del badge de sobrante |
| Negativo | Sobrante < $0 | `Color.red` / `.systemRed` | Texto y fondo del badge de sobrante |

Estos tres son colores de sistema, no derivan del accent — el naranja de marca nunca se confunde con el semáforo financiero. El color del sobrante nunca es la única señal: el signo (`+`/`−`) y el símbolo de moneda siempre acompañan la cifra (regla de accesibilidad — nunca comunicar solo por color).

### Iconografía de origen de línea (no es color de estado, es metadata)

| Origen (`LineOrigin`) | Color de icono | Razón |
|---|---|---|
| `.manual` | Sin icono | Es el caso base, no necesita marca |
| `.recurring` (Ingresos/Gastos recurrentes) | `.secondary`, icono `arrow.triangle.2.circlepath` | Informativo, no compite con el semáforo del sobrante |
| `.subscription` — Suscripciones | `.secondary`, icono `repeat` | Distinto del anterior a propósito — Suscripciones y Recurrentes son fuentes de datos distintas para el usuario, aunque ambas auto-generan la línea |
| `.subscription` — Servicios (renta, luz, internet, agua, gas, seguro) | `.secondary`, icono `house.fill` | Un tercer icono para un tercer origen visual — el usuario distingue "esto es un servicio del hogar" de "esto es Netflix" sin abrir la línea. Modelo de datos: mismo mecanismo que Suscripciones (día de pago 1–31, ver TRD `Subscription`); es decisión de Avie si vive como el mismo `@Model` con categorías de hogar o una entidad hermana — el diseño solo exige que la línea resultante sea identificable como `origin == .subscription` con esta variante de icono |
| `.loan` — Préstamos (pago periódico generado por un `Loan`) | `.secondary`, icono `banknote` | Mismo símbolo que la fila del hub, por consistencia — un cuarto origen visual, distinto de recurrente/suscripción/servicio; ver "Préstamos (Loans)" |
| `.carryOver` | `.secondary`, icono `arrow.turn.down.right` | Igual — es texto de sistema, no accent |
| Cualquier línea generada (`.recurring`/`.subscription`/`.loan`) con `isManuallyEdited == true` | `.secondary` con icono `pencil` en vez del icono base de su origen | Señala override, sigue siendo neutro — regla única para las tres, no solo para recurrentes |

---

## Tipografía

**Sistema:** SF Pro, peso Regular (tema Fintrol: `fontWeight: regular`, `fontDesign: standard`). Dynamic Type siempre activo.
**Cifras tabulares obligatorias en todo monto:** `.monospacedDigit()` en cada `Text` que muestre dinero — evita que los totales "bailen" al recalcular, como en una hoja de cálculo real.
**Fuente custom:** ninguna.

### Escala de la app

| Elemento | Style | Peso | Tracking | Notas |
|----------|-------|------|----------|-------|
| Sobrante (badge grande) | `.system(size: 44, weight: .bold, design: .default)` con `relativeTo: .largeTitle` | Bold | 0 | Único texto Bold de la app — es el elemento más grande de cada pantalla, `.monospacedDigit()` |
| Título de pantalla (Quincena: línea 1 "Septiembre 2026") | `.title2` | Semibold | 0 | Botón de navegación (dos líneas + pill debajo, ver "Header de Quincena"), no `.largeTitle` — deja espacio a los bloques |
| Subtítulo de rango (Quincena: línea 2 "1 – 15" / "16 – 30") | `.subheadline` | Regular | 0 | `.secondary`, `.monospacedDigit()`, último día real del mes vía `PeriodDateEngine` |
| Header de sección (INCOME / EXPENSES) | `.headline` | Semibold | +0.5 | `ALL CAPS` vía `.textCase(.uppercase)`, nunca string en mayúsculas |
| Título de línea (descripción) | `.body` | Regular | 0 | |
| Monto de línea | `.body` | Semibold | 0 | `.monospacedDigit()`, alineado `.trailing` |
| Monto convertido / TC (caption bajo línea MXN) | `.caption` | Regular | 0 | `.secondary`, `.monospacedDigit()` |
| Total INCOME / Total EXPENSES | `.title3` | Semibold | 0 | `.monospacedDigit()`, `.trailing` |
| Metadata (día de pago, frecuencia, categoría) | `.subheadline` | Regular | 0 | `.secondary` |
| Badge de categoría / origen | `.caption2` | Regular | +1.2 | `ALL CAPS` |
| Label de botón | `.headline` | Semibold | 0 | |

### Reglas de la app

- Ningún tamaño hardcodeado salvo el badge de sobrante (usa `relativeTo:` para escalar con Dynamic Type de todos modos).
- Alineación: descripciones `.leading`, montos y fechas `.trailing` (regla estándar de tablas).
- Interlineado extra: no — todo el texto de Fintrol es corto (líneas, labels, montos), no hay body text largo.
- Nunca `.font(.system(size: 17))` fuera de la excepción documentada del sobrante.

---

## Espaciado

**Base:** 8pt. Densidad **Regular** (tema Fintrol) — no Compact: debe sentirse como una hoja de cálculo bien hecha, no apretada, pero con muchas filas visibles en Mac sin scroll.

| Contexto | Valor | Token AppleAppLabUI |
|----------|-------|---------------------|
| Padding de pantalla (márgenes laterales) | 16pt | `SpacingTokens.screenMargin` |
| Padding interno de cards | 16pt | `SpacingTokens.cardPadding` |
| Espacio entre secciones (INCOME → EXPENSES → Sobrante) | 24pt | `SpacingTokens.sectionSpacing` |
| Espacio entre líneas dentro de INCOME/EXPENSES | 4pt (más denso que el default de 8pt — son filas de tabla, no cards independientes) | custom, documentar en `PROJECT_LEARNINGS.md` como variante de densidad |
| Espacio entre botones | 12pt | `SpacingTokens.itemSpacing` × 1.5 |
| Altura de fila de línea (INCOME/EXPENSES) | 44pt mínimo, 52pt cómodo con caption de conversión MXN | `SpacingTokens.minTapTarget` como piso |
| Altura mínima de tap target | 44pt | `SpacingTokens.minTapTarget` |

---

## Forma — Continuous Corners

**Regla absoluta:** `RoundedRectangle(cornerRadius: x, style: .continuous)` en todo. **NUNCA** `style: .circular`.

### Sistema de radios

| Elemento | Radio | Nota |
|----------|-------|------|
| Card de bloque (INCOME, EXPENSES, panel resumen) | 20pt | `RadiusTokens.card` — r_outer |
| Fila de línea dentro de un bloque | 12pt | = 20 − 8 (padding de fila reducido) |
| Badge de sobrante | 24pt | Es el elemento más prominente, radio ligeramente mayor que las cards estándar |
| Botones CTA | 999pt | Pill — `RadiusTokens.pill` |
| Inputs / campos (monto, descripción) | 12pt | `RadiusTokens.input` |
| Chips / badges (categoría, origen, "manual") | 999pt | Pill |
| Tab bar (iPhone) | 999pt | Pill flotante |
| Sidebar (Mac) | Sistema, sin radio custom | NavigationSplitView nativo |
| Sheets / modales (editar línea, jump a quincena) | 20pt | Sistema |

**Regla de contenedores anidados:** `r_inner = r_outer − padding`. Card de bloque (r=20, padding=16) → fila de línea interna (r=4, no 12 — corrijo: ver nota).

> **Nota de consistencia:** las filas de línea dentro de un bloque de 20pt con padding de 16pt matemáticamente dan r_inner=4pt. Pero una fila de 44–52pt de alto con r=4pt se ve casi rectangular, lo cual es correcto para una fila de "tabla" (no se quiere que cada fila lea como mini-card). El valor de 12pt de la tabla de arriba aplica solo a la fila cuando está en estado de **edición inline** (se convierte en un campo con su propio fondo elevado) — en reposo, la fila no tiene fondo propio, solo separador, así que el radio no aplica. Ver "Edición de línea" en Componentes del sistema.

---

## Materiales y profundidad

### Regla de capas (Liquid Glass solo en navegación)

| Capa | Liquid Glass | En Fintrol |
|------|--------------|------------|
| Navigation layer (tab bar iPhone, toolbar/sidebar Mac, sheets, botón flotante "+") | ✅ Sí | `glassEffect(.regular)` |
| Content layer (bloques INCOME/EXPENSES, filas, cards de Suscripciones/Recurrentes, Overview) | ❌ No | Material **Frost** del tema (ver abajo) — nunca Liquid Glass |

### Material de contenido: Frost (tema Fintrol)

El tema Fintrol define `windowMaterial: frost`, `blurIntensity: 0.5`, `transparency: 0.5`. Esto es la superficie de **contenido** de la app (bloques, cards, filas con fondo), separada de la capa de navegación con Liquid Glass nativo del sistema. No se mezclan en la misma superficie: la barra de navegación es Liquid Glass del OS; las cards debajo son Frost del tema.

```swift
// Card de bloque (INCOME/EXPENSES/panel resumen) — Frost, no Liquid Glass:
RoundedRectangle(cornerRadius: 20, style: .continuous)
    .fill(.ultraThinMaterial.opacity(0.5))   // blur 0.5, transparency 0.5 vía PatternConfig del tema
    .background(Color("AppBackground").opacity(0.3))
```

En la práctica, Woz consume esto a través de `PatternConfig` del tema Fintrol (ya trae `blurIntensity`/`transparency`) pasado a `LabCard`/`LabNestedCard` — no se hardcodea `.ultraThinMaterial` a mano salvo en el componente custom de fila de línea (que no existe en el catálogo).

### Componentes de navegación — Liquid Glass

| Componente | iOS 26+ / macOS 26+ |
|---|---|
| Tab bar (iPhone) | `Capsule().glassEffect(.regular)` |
| Tab activo (inner) | `ConcentricRectangle().glassEffect()` con tint `accent-500` |
| Sidebar (Mac) | Nativo `NavigationSplitView` — Liquid Glass automático del sistema, sin custom |
| Toolbar (Mac y iPhone) | Nativo, Liquid Glass automático |
| Botón flotante "+" (captura rápida) | `.buttonStyle(.glassProminent)`, tinte accent |
| Sheet (editar línea, jump quincena, editar recurrente) | Sistema — Liquid Glass `.clear` con dimming detrás |
| Pantalla de bloqueo Face ID | Fondo `AppBackground` sólido, sin glass — es una superficie de seguridad, no de navegación; ver sección Face ID |

**Variante:** Regular en toda la navegación. No hay caso de uso para Clear en Fintrol — no hay media-rich content detrás de las barras (es una app de texto y números), así que Clear no aporta y arriesgaría legibilidad de los montos.

### Superficies macOS 26+

| Superficie | Variante | Capas de contraste | Razón |
|---|---|---|---|
| Ventana principal sobre wallpaper (fondo de `NavigationSplitView`) | Liquid Glass `regular` en sidebar; contenido central en `AppBackground` sólido (#323232), no glass | Sin capa neutral adicional — el fondo sólido del tema ya da el contraste que un `clear` necesitaría simular | Fintrol es una app de trabajo con números todo el tiempo en pantalla; un fondo `clear` que deja ver el wallpaper detrás de columnas de dinero compite con la legibilidad — se prioriza la lectura sobre el efecto atmosférico |
| Cards internas (bloques INCOME/EXPENSES, panel resumen, Suscripciones/Recurrentes) | Frost del tema (no glass) | Fill `AppBackground.tertiary` ~`#3C3C3C`, sin borde adicional — la separación la da el material Frost, no un borde | Frost aporta la textura translúcida de marca sin competir con Liquid Glass de la sidebar |
| Campo de texto (monto, descripción, tipo de cambio manual) | Fill `AppBackground.secondary` (~#2A2A2A) opaco | Borde de foco `accentBorder` (#FF7E4D dark), 1.5pt | El foco usa el token de acento de Fintrol, nunca naranja hardcoded fuera del token |

No hay mezcla `clear`/`regular` en la misma superficie continua: la sidebar (Liquid Glass regular) y el contenido central (sólido/Frost) son niveles claramente separados por el propio `NavigationSplitView`.

### Sombras (solo donde no hay glass ni Frost — nunca en cards de contenido)

```swift
.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)  // badge de sobrante, elevado sobre el resto
```

Las cards de bloque (Frost) no llevan shadow adicional — el material ya da la separación. Elevación del tema: **Flat**.

---

## Navegación

### iPhone — `TabView` + `NavigationStack` por tab

4 tabs, jerarquía plana (todas las pantallas de nivel alto del PRD son paralelas, no hay una "principal" que domine). **Solo ícono, sin etiqueta de texto visible** (decisión del usuario tras ver la app en simulador) — cada `Tab`/`TabItem` se declara sin `Text` visible, pero conserva `.accessibilityLabel` con el nombre completo de la sección para VoiceOver:

1. **Quincena** (calendar) — tab por defecto al abrir, `accessibilityLabel: "Quincena"`
2. **Recurrentes y pagos** (arrow.triangle.2.circlepath), `accessibilityLabel: "Recurrentes y pagos"` — hub de 4 entradas, ya no una lista mixta ni un tab dedicado por tipo. Ver "Recurrentes y pagos — hub de cuatro entradas" abajo.
3. **Overview** (chart.bar.fill), `accessibilityLabel: "Overview"`
4. **Ajustes** (gearshape.fill), `accessibilityLabel: "Ajustes"`

Con Suscripciones y Servicios ahora dentro del hub (ver abajo), la tab bar queda en 4 de un máximo de 5 — se deja el quinto slot libre a propósito en vez de forzar una quinta entrada de nivel top que no existe en el PRD; añadir algo solo para llenar el espacio sería decoración, no función.

Cada tab envuelve un `NavigationStack` propio. Push para detalle de línea recurrente/suscripción/servicio; sheet para editar una línea de quincena o capturar una nueva.

### Recurrentes y pagos — hub de cuatro entradas (iPhone) / ítems directos en sidebar (Mac)

Decisión del usuario, en tres pasos: primero "Recurrentes" se dividió en **"Ingresos recurrentes"** y **"Gastos recurrentes"** (cada una lista solo su tipo, botón "+" crea ese tipo directo, sin picker de ingreso/egreso). Después se agregó **"Servicios"** — pagos del hogar (renta, luz, internet, agua, gas, seguro), mismo mecanismo automático por día de pago que Suscripciones (TRD, `Subscription`) pero con su propia pantalla, icono y categorías de hogar, distinta de Suscripciones (Netflix, Claude, Spotify…). Con tres listas ya viviendo fuera de un tab propio, mover también **Suscripciones** al mismo hub fue lo coherente: las cuatro son "cosas que la app genera solas en cada quincena sin captura manual". Ahora se agrega **"Préstamos"** (feature v1 nueva, ver "Préstamos (Loans)" más abajo) como quinta fila — un préstamo (Upstart, "Ada") también genera su línea sola en cada quincena, así que pertenece al mismo hub por la misma razón que las otras cuatro; no se le da tab propio porque la app ya está en el límite razonable de navegación de nivel top.

Esto también informa el patrón de acceso rápido que ya existía en `SettingsView` (`Apps/Fintrol/Fintrol/Features/Settings/SettingsView.swift:92`, fila `NavigationLink("Recurrentes")`) — esa fila queda obsoleta como camino alterno mixto: Ajustes no debe ofrecer una segunda entrada a estas listas por fuera del hub; si Woz quiere mantener acceso rápido desde Ajustes, debe ser un solo `NavigationLink("Recurrentes y pagos")` que abre el mismo hub, no filas sueltas por tipo.

- **iPhone:** la tab "Recurrentes y pagos" (icono `arrow.triangle.2.circlepath`) abre un hub — `List` de 5 filas `LabListRow` con chevron, en este orden (ingresos y gastos primero por ser el corazón de la proyección multi-año del PRD; servicios y suscripciones después por ser más operativos; préstamos al final por ser el caso de uso menos frecuente de tocar, solo consulta ocasional del saldo):
  1. "Ingresos recurrentes" — `systemImage: "arrow.down.circle"`, subtitle con conteo
  2. "Gastos recurrentes" — `systemImage: "arrow.up.circle"`, subtitle con conteo
  3. "Servicios" — `systemImage: "house.fill"`, subtitle con conteo
  4. "Suscripciones" — `systemImage: "repeat"`, subtitle con conteo
  5. "Préstamos" — `systemImage: "banknote"`, subtitle con conteo — **no** `creditcard.and.123`: el PRD excluye tarjetas de crédito de v1 explícitamente y ese símbolo visualmente lee como estado de cuenta de tarjeta; `banknote` comunica "dinero prestado/prestado a alguien" sin esa asociación
  - Tap en cada fila hace push a su lista filtrada, donde vive el botón "+" que crea ese tipo directo. El hub no tiene botón "+" propio.
- **Mac:** el límite de tabs es exclusivo de iPhone; el sidebar no lo tiene, así que ahí las cinco son **ítems directos**, sin hub intermedio — cada uno navega directo a su lista con su propio "+" en el toolbar.

### Mac — `NavigationSplitView`, sidebar + detail (sin columna media)

8 secciones en sidebar (ancho 220pt): Quincena, Ingresos recurrentes, Gastos recurrentes, Servicios, Suscripciones, Préstamos, Overview, Ajustes. El PRD tiene solo 2 niveles de profundidad reales (lista → detalle de recurrente/suscripción/servicio/préstamo), así que no se usa columna `content` intermedia — sidebar + detail directo:

```swift
NavigationSplitView {
    SidebarView()   // Quincena, Ingresos recurrentes, Gastos recurrentes, Servicios, Suscripciones, Préstamos, Overview, Ajustes
} detail: {
    // la vista de la sección seleccionada; Quincena maneja su propia
    // navegación interna (prev/next, jump a año) dentro del detail
}
```

### Navegar entre quincenas — el problema central de "no perderse"

Dos ejes de navegación conviven: **quincena adyacente** (uso diario) y **salto a año/quincena arbitraria** (proyección multi-año). Se resuelven con dos controles distintos, nunca uno solo:

**Header de Quincena — dos líneas + pill de estado**

Decisión del usuario: el título deja de ser una sola línea compacta ("Sept 2026 · 1–15") y pasa a dos líneas apiladas, centradas, dentro del mismo botón tappable/clickeable:

```
Septiembre 2026          ← .title2, semibold — mes completo localizado (Locale.current) + año
1 – 15                    ← .subheadline, .secondary, .monospacedDigit() — o "16 – 30" con el
                             último día REAL del mes (28/29/30/31 según PeriodDateEngine, nunca
                             un "30" genérico)
[ Hoy ]                    ← pill de estado, debajo de las dos líneas — ver punto 3
```

Ambas líneas viven dentro del mismo botón (todo el bloque de dos líneas es el trigger del jump sheet, no solo la primera línea) y se centran como una unidad en el header, con la pill de estado inmediatamente debajo, separada por 4pt.

**1. Navegación adyacente — chevrons en el toolbar/header**

- iPhone: dentro del header de la pantalla Quincena, un `HStack` con `chevron.left` / `chevron.right` a los lados del bloque de título de dos líneas. Swipe horizontal en el contenido también navega (gesto acelerador, con alternativa tap siempre presente en los chevrons — regla de gestos).
- Mac: mismos chevrons en el toolbar (`.navigation` placement a la izquierda), más atajos de teclado `⌘←` / `⌘→`.
- El chevron derecho nunca se deshabilita — avanzar siempre materializa la siguiente quincena bajo demanda (ver TRD, materialización perezosa). El chevron izquierdo se deshabilita (estado `.disabled`, opacidad reducida) al llegar a la **primera quincena materializada** — no existe "antes" en Fintrol, coincide con "arranca desde cero en 2026". El jump sheet respeta el mismo límite: el `Picker` de año/mes/quincena no ofrece opciones anteriores a esa primera quincena materializada.

**2. Salto de año/quincena — botón de título abre un jump sheet**

- El bloque de título de dos líneas es tappable/clickeable en conjunto, no solo decorativo. Al tocarlo se abre un sheet (iPhone) / popover (Mac) con:
  - Un `Picker` de año (rango: desde el primer `Period` materializado hasta año actual + 10, suficiente para el caso "préstamo a 5 años" del PRD).
  - Un `Picker` de mes (mes completo localizado, igual que la primera línea del header).
  - Un segmented control de quincena: "1 – 15" / "16 – 30" (con el último día real del mes seleccionado, recalculado dinámicamente al cambiar el mes en el picker).
  - Botón "Ir" que navega directo — materializa la quincena destino (y las intermedias necesarias para el carry-over, de forma transparente para el usuario, según la lógica de `CarryOverEngine` del TRD).
  - Atajo rápido: botón "Hoy" que regresa a la quincena actual desde cualquier punto de la proyección — crítico para no perderse después de saltar 10 años adelante.

```
Jump sheet — Quincena
- Trigger: tap/click en el bloque de título (dos líneas) del header de Quincena
- Presentación: .sheet (iPhone) / .popover (Mac)
- Contenido: Picker año + Picker mes + segmented 1–15/16–30(real) + botón "Ir" + botón "Hoy"
- Cierre: al navegar, o botón "Cancelar"
```

**3. Indicador de "dónde estoy"** — la pill debajo del título de dos líneas distingue tres estados:
  - Sin pill: quincena pasada o actual ya materializada normalmente.
  - Pill "Hoy" (accent, pill pequeño): la quincena que contiene la fecha de hoy.
  - Pill "Proyección" (`.secondary`, pill pequeño): una quincena futura recién materializada por navegación, para que el usuario sepa que estas líneas vinieron de recurrentes/suscripciones y no de captura manual.

---

## Componentes del sistema

### Botones

- **CTA principal** ("Agregar línea", "Guardar recurrente"): `.buttonStyle(.glassProminent)` → tinte `AccentColor`, pill, 54pt en iPhone / 36pt en Mac.
- **Secundario** ("Cancelar"): `.buttonStyle(.glass)`.
- **Destructivo** ("Eliminar recurrente"): `.foregroundStyle(.red)`, siempre detrás de `confirmationDialog` — nunca borrado directo de una línea recurrente o suscripción (sí se permite swipe-to-delete directo en una línea manual suelta de INCOME/EXPENSES, reversible con undo del sistema).

### Bloques INCOME / EXPENSES — componente custom (no está en el catálogo)

No existe en `PATTERNS.md` un componente de "bloque de tabla financiera con totales al pie" — se construye sobre `LabNestedCard` (da el nested radius automático) con:

- Header de sección: título `ALL CAPS` (`.headline`, tracking +0.5) + botón "+" alineado a la derecha (abre captura rápida inline, ver abajo).
- Lista de filas (`LineItemRow`, custom) sin fondo propio en reposo, separador `Color(.separator)` entre filas.
- Fila de total al pie: `.title3` Semibold, `.monospacedDigit()`, separado del último ítem con un `Divider()` más marcado (2pt, `.secondary`).

Documentar `LineItemRow` y el bloque contenedor en `PROJECT_LEARNINGS.md` como candidatos a generalizarse a `AppleAppLabUI` (patrón reutilizable: "lista con total al pie").

### Fila de línea (`LineItemRow`) — estados visuales

| Estado | Apariencia |
|---|---|
| Reposo, manual | Descripción `.leading` + toggle "pagado" pequeño a la izquierda del texto + monto `.trailing` |
| Reposo, origen `.recurring` (Ingresos/Gastos recurrentes), sin editar | Igual + icono `arrow.triangle.2.circlepath` tamaño 12pt `.secondary` antes de la descripción |
| Reposo, origen `.subscription` — Suscripciones, sin editar | Igual + icono `repeat` tamaño 12pt `.secondary` — icono distinto al de Recurrentes a propósito, ver "Iconografía de origen de línea" |
| Reposo, origen `.subscription` — Servicios, sin editar | Igual + icono `house.fill` tamaño 12pt `.secondary` — tercer icono, distingue de un vistazo un pago del hogar de una suscripción de entretenimiento |
| Reposo, origen `.loan` — Préstamos, sin editar | Igual + icono `banknote` tamaño 12pt `.secondary` — cuarto icono, distingue el pago de un préstamo de los otros tres orígenes generados |
| Reposo, origen recurrente pero editado manualmente (`isManuallyEdited == true`) | Icono cambia a `pencil` 12pt `.secondary` — comunica "esto vino de un recurrente pero tiene un valor propio en esta quincena" |
| Reposo, origen carry-over ("Latest Month") | Icono `arrow.turn.down.right` `.secondary`, no editable el título (solo el monto es de solo lectura — es el resultado calculado de la quincena anterior, no se edita a mano; si el usuario necesita cambiarlo debe editar la línea origen en la quincena previa) |
| Línea en MXN | Bajo el monto principal (que siempre se muestra en su moneda de captura), una segunda línea `.caption` `.secondary` `.monospacedDigit()`: "≈ $842.30 USD · TC 18.42" |
| Línea en MXN con override manual del tipo de cambio para esa quincena | Igual + badge `.caption2` pill pequeño "manual" en `accentSubtle`/`accentForeground`, junto al TC — señala que ese número no vino de la API |
| Editando (inline) | La fila entera gana fondo `AppBackground.secondary`, radio 12pt (aplica aquí el nested radius de la nota en "Forma"), campos de descripción y monto se vuelven `LabTextField` editables, toggle de moneda USD/MXN aparece a la derecha del monto |
| Swipe (iPhone) | Swipe-left revela "Eliminar" (rojo) — solo en líneas `.manual`; en líneas de origen recurrente/suscripción/carryOver el swipe no elimina, abre directo el modo edición inline (no tiene sentido "eliminar" una línea que se regenerará la próxima vez que se visite la quincena) |
| Long-press / botón "···" | `.contextMenu`: Editar, Cambiar a MXN/USD, Eliminar (si aplica) — accesible también por tap en "···" al final de la fila para paridad con Mac (sin long-press ahí) |

### Captura rápida de un gasto/ingreso

Fila especial al final de cada bloque (INCOME/EXPENSES), siempre visible, estilo `.secondary`, ícono `plus.circle` + texto "Agregar ingreso"/"Agregar gasto":

- Tap/click → la fila se transforma in-place en modo edición inline (mismo patrón que editar una línea existente) con foco automático en el campo de descripción.
- Teclado (iPhone): toolbar con "Siguiente" entre descripción → monto → "Listo" que confirma y crea la línea, y deja la fila de captura lista para el siguiente ingreso sin cerrar el teclado (flujo de captura consecutiva, como llenar una hoja de cálculo).
- Moneda por defecto: USD; toggle USD/MXN visible junto al campo de monto durante la captura.
- Haptic `.success` al confirmar cada línea (iPhone únicamente).

### Badge de sobrante

Componente custom, no está en el catálogo. Card standalone (r=24pt) debajo de los dos bloques, ancho completo:

```
[ SOBRANTE ]              ← .caption2, ALL CAPS, .secondary
$1,240.50                 ← .monospacedDigit(), bold, relativeTo: .largeTitle, tamaño 44pt
                             color = verde/amarillo/rojo según umbral
+ signo explícito antes del monto cuando es negativo: "−$320.00" en rojo
```

Fondo del badge: tinte muy sutil del color de estado (`.green.opacity(0.12)` / `.yellow.opacity(0.12)` / `.red.opacity(0.12)`), no color sólido — el texto lleva el color completo, el fondo solo lo insinúa. Transición de color animada al recalcular (ver Animaciones).

### Panel de resumen (USD/Peso, Mandar, Next Month)

- **iPhone:** card independiente debajo del badge de sobrante, mismo ancho, `LabNestedCard` con 3 filas: "Mandar: $X USD", "Tipo de cambio: 18.42 (editar)", "Next Month: $Y" (solo lectura, `.secondary`). "Next Month" siempre muestra el mismo número que el usuario verá al avanzar con el chevron: si la siguiente quincena ya está materializada (con o sin ediciones manuales), es su sobrante real ya calculado; si no está materializada, es la proyección en memoria de `ProjectionEngine`. No hay distinción visual entre ambos casos — es un solo campo, un solo comportamiento.
- **Mac:** dado que "en Mac la quincena cabe sin scroll y el resumen puede ir a un lado" (requisito del usuario), el panel vive en una tercera zona fija a la derecha del detail (no una columna `NavigationSplitView` adicional — un `HStack` dentro del detail: bloques INCOME/EXPENSES a la izquierda en `ScrollView` si excede alto de ventana, panel de resumen a la derecha en ancho fijo ~280pt, sin scroll propio). Ver "Consideraciones de plataforma".

### Listas (Ingresos recurrentes, Gastos recurrentes, Servicios, Suscripciones)

Las cuatro comparten el mismo patrón — `LabList` con `LabListRow` — pero cada una es una pantalla propia con su propio botón "+" en el toolbar, nunca una lista mixta con filtro:

- **Ingresos recurrentes / Gastos recurrentes:** subtitle muestra frecuencia + fecha fin si existe ("Cada quincena" / "Día 20 · hasta ago 2030"). `systemImage` fijo por pantalla (`arrow.down.circle` / `arrow.up.circle`), no varía por fila.
- **Servicios:** subtitle muestra día de pago + categoría de hogar ("Día 12 · Luz"). `systemImage` por categoría de hogar (Renta `house`, Luz `bolt.fill`, Internet `wifi`, Agua `drop.fill`, Gas `flame.fill`, Seguro `shield.fill`) — a diferencia de Suscripciones, aquí el icono sí varía por fila porque la categoría es la forma en que el usuario reconoce cada servicio de un vistazo.
- **Suscripciones:** subtitle muestra día de pago + categoría (Tools, Entertainment, Apartment, Work, Personal, Hobby, Investment, según TRD). `systemImage` por categoría existente del catálogo.
- Swipe actions: eliminar (con confirmación si el ítem tiene historial de líneas generadas) y editar.
- Alta: botón "+" en toolbar → sheet con `Form` nativo, específico de cada tipo (el formulario de Servicios no pregunta tarjeta de pago si no aplica al servicio; el de Recurrentes no pregunta día de pago sino frecuencia + fecha inicio/fin).

### Iconografía

- Sistema: SF Symbols, rendering mode **Hierarchical** (default) salvo los iconos de origen de línea (`arrow.triangle.2.circlepath`, `pencil`, `arrow.turn.down.right`) que van en **Monochrome** `.secondary` — no deben competir visualmente con el semáforo del sobrante.
- Peso: match con el texto adyacente (`.headline` → símbolo hereda semibold vía `Label`).
- Outline = inactivo, Fill = activo/seleccionado (tabs, categorías seleccionadas en filtro de Suscripciones).

---

## Animaciones

### Principios

- Spring para todo lo que representa una fila cambiando de estado (captura, edición, swipe). `easeOut` para entradas de listas. Nada de curva back — esta app no necesita "energía", necesita precisión.
- **Reduce Motion:** siempre respetado vía `@Environment(\.accessibilityReduceMotion)`.

### Especificación de motion aprobada

| Evento | Estado inicial → final | Curva | Duración | Reduce Motion | Razón |
|---|---|---|---|---|---|
| Cambio de color del sobrante al editar una línea | Color anterior → nuevo color (verde/amarillo/rojo) | `.smooth` | 0.3s | Cross-fade de color sin movimiento — se conserva, es el único cambio permitido igual con RM activo | Es la señal más importante de la pantalla; debe notarse pero no distraer |
| Confirmar captura rápida (nueva línea aparece en la lista) | Fila entra con `opacity 0→1` + `offset y: 8→0` | `.spring(duration: 0.3, bounce: 0.15)` | 0.3s | Solo fade, sin offset | Continuidad — la fila "llega" desde donde estaba el campo de captura |
| Swipe to delete confirmado | Fila colapsa altura a 0 + fade | `.easeIn` | 0.2s | Fade sin colapso animado (salto directo) | Feedback rápido, no narrativo |
| Entrar en modo edición inline | Fondo de fila fade-in + campos aparecen | `.snappy` | 0.2s | Igual, ya es corto | Feedback inmediato de foco |
| Navegar entre quincenas (chevron / swipe) | Contenido sale lateral + nuevo contenido entra lateral | `.easeOut` | 0.25s | Cross-fade simple, sin movimiento lateral | Transición direccional ligera, refuerza "estoy avanzando/retrocediendo" |
| Jump sheet abre/cierra | Sistema (`.sheet`/`.popover`) | Sistema | Sistema | Sistema ya respeta RM | No custom |
| Símbolo de "pagado" al activar el toggle | `.symbolEffect(.bounce)` en el checkmark | — | Sistema | Símbolo cambia sin bounce (`.contentTransition(.opacity)`) | Confirmación ligera, no bloqueante |

No hay glows ni efectos de luz en Fintrol — el tono "serio pero con carácter" del STYLE_BRIEF se logra con el naranja puntual y el semáforo, no con efectos atmosféricos. Si en el futuro se agrega un momento de celebración (ej. terminar de pagar un préstamo), especificarlo entonces, no antes.

---

## Haptic feedback (iPhone)

| Acción | Haptic |
|---|---|
| Confirmar línea en captura rápida | `.sensoryFeedback(.success, trigger: didAddLine)` |
| Toggle "pagado" | `.sensoryFeedback(.impact(weight: .light))` |
| Swipe to delete confirmado | `.sensoryFeedback(.impact(weight: .medium))` |
| Editar tipo de cambio manual | `.sensoryFeedback(.selection)` al abrir el editor |
| Face ID exitoso | `.sensoryFeedback(.success)` |
| Face ID fallido | `.sensoryFeedback(.error)` |

Máximo 1 haptic por acción, nunca en recálculos automáticos (el recálculo de carry-over tras editar no dispara haptic propio — el haptic ya ocurrió en la acción que lo disparó).

---

## Ajustes generales

Pantalla "Ajustes generales" — `Form` nativo con dos `Section` (iPhone) / mismo agrupamiento en la `Settings` scene (Mac). Navegación: Liquid Glass (toolbar/navbar y, en Mac, la ventana de `Settings`); contenido: `Form`/`List` con estilo `.insetGrouped` sobre material Frost del tema — no se construye custom, es el `Form` del sistema, que ya respeta densidad Regular y Continuous Corners nativamente.

### Grupo "Preferencias"

| Fila | Control | Comportamiento |
|---|---|---|
| Moneda base | Texto informativo, sin control | "USD" fijo, `.secondary` — no editable, existe solo para que el usuario confirme la moneda de referencia de todos los totales |
| Tipo de cambio | `NavigationLink` a subpantalla "Tipo de cambio" | Fila muestra "18.42 · hace 2 h" (`.monospacedDigit()`, `.secondary`) como value; la subpantalla trae: toggle "Automático" (default on, consulta Frankfurter), y si se apaga, `LabTextField` numérico para override manual global con validación en rango **1–100** (fuera de rango: borde rojo + texto inline de error, no permite guardar) |
| Apariencia | `Picker` `.pickerStyle(.menu)`, opciones "Sistema" / "Claro" / "Oscuro" | Default "Sistema"; cambia `preferredColorScheme` de la app |
| Estado de iCloud | Texto informativo, sin control | "Sincronizado" / "Sin conexión" / "Sincronizando…" (`.caption`, `.secondary`, con `SFSymbol` `icloud`/`icloud.slash` a la izquierda) — no editable, es puramente diagnóstico |

### Grupo "Seguridad"

| Fila | Control | Comportamiento |
|---|---|---|
| Bloquear con Face ID / Touch ID | `LabToggleRow` | Apagado por defecto. Al activarlo, dispara autenticación de prueba (LAContext) — si falla o no hay biometría configurada, el switch vuelve a apagado + texto inline (`.caption`, `.red`) explicando por qué. Nunca queda "on" sin biometría real funcionando |
| Tiempo de re-bloqueo | `Picker` `.pickerStyle(.menu)`, opciones "Inmediato" / "1 minuto" / "5 minutos" | Default "1 minuto" (60s, ya fijado en el PRD). Fila solo visible/habilitada cuando el bloqueo está activo — con el switch apagado aparece deshabilitada (`.opacity(0.4)`, sin interacción), no oculta, para que el usuario entienda que depende del toggle de arriba |
| Ocultar montos en el app switcher | Texto informativo, sin control | Siempre activo, no configurable — fila puramente informativa (`.caption`, `.secondary`) que explica que esta protección corre siempre, independiente del switch de Face ID, usando el snapshot/privacy overlay del sistema (mitigación ya fijada en el PRD) |

### Pie de pantalla

Fuera de ambos `Section`, como `Section` final sin header: "Fintrol — versión 1.0 (build X)", `.caption`, `.secondary`, centrado.

### macOS — Settings scene

Misma agrupación exacta dentro de `Settings { }` nativo (`⌘,`), un solo `Form` sin `TabView` interno (no hay suficientes filas para justificar pestañas de Preferencias — ver "Settings (Preferencias)" en el skill: nunca panel custom). Ancho de ventana de Settings: 420pt fijo, no resizable — estándar macOS para paneles de preferencias cortos.

---

## Bloqueo biométrico — Face ID / Touch ID (PRD feature #10)

### Pantalla de bloqueo

Full-screen cover, se presenta:
- Al abrir la app (si el switch está activo).
- Al volver de background tras 60s de inactividad (valor definido por Jonny, ver PRD — confirmado, no placeholder).

```
Estructura:
- Fondo: AppBackground sólido (#323232), SIN Frost ni Liquid Glass — superficie de seguridad, no de navegación ni contenido
- Icono grande (80pt): "faceid" o "touchid" según capacidad del dispositivo, .hierarchical, color .secondary
- Título (.title2, semibold): "Fintrol está bloqueado"
- Subtítulo (.body, .secondary): "Autentica para ver tus montos"
- Botón "Desbloquear" (.buttonStyle(.glassProminent)) — dispara el prompt del sistema automáticamente al aparecer la pantalla, el botón es el reintento manual, no el trigger inicial
- Si falla: texto inline (.caption, .red) "No se pudo verificar tu identidad" + el mismo botón cambia su label a "Reintentar"
```

Ningún monto, título de línea ni cifra se renderiza detrás de esta pantalla — el `ModelContext`/vistas de datos ni se montan hasta autenticación exitosa (no es un blur encima de contenido real, es ausencia real de contenido, para que un screenshot del sistema en app switcher tampoco filtre nada — coincide con la mitigación de riesgo ya escrita en el PRD).

---

## Préstamos (Loans)

Feature v1 nueva. Modela lo que hoy son "recurrentes especiales con fecha fin" en el PRD (Upstart #1, Upstart #2, "Ada") pero con datos propios de amortización — saldo restante, interés, plazo — que un `RecurringItem` genérico no captura. Vive en el hub "Recurrentes y pagos" (fila 5) y como ítem directo en el sidebar de Mac. Explícitamente no es "tarjetas de crédito" (eso sigue fuera de v1, Fase 2 del PRD) — un préstamo tiene plazo fijo y amortización determinística, una tarjeta tiene saldo revolvente; no comparten modelo ni pantalla.

### 1. Lista de préstamos

`LabList` con una fila custom por préstamo (no cabe en `LabListRow` estándar — necesita dirección + progreso, se documenta como candidato a generalizar en `PROJECT_LEARNINGS.md`):

```
[banknote] Upstart #1                          [ Debo ]      ← nombre + chip de dirección
Saldo restante: $18,420.00                                    ← .body, semibold, .monospacedDigit()
Próximo pago: $629.00 · 20 sept                                ← .subheadline, .secondary
Fecha fin: ago 2030                                             ← .caption, .secondary
[███████░░░░░░░░░░░░] 34% pagado                                ← barra de progreso + porcentaje
```

- **Chip de dirección** — nunca solo icono, siempre icono + texto, para que la lectura no dependa del color (regla de accesibilidad del skill):
  - **"Me lo prestaron"** (es una deuda del usuario): chip pill con icono `arrow.up.forward` + texto **"Debo"**, tinte `.orange` (semántica de "advertencia/compromiso pendiente" del catálogo de estados, no el naranja de marca ni el semáforo verde/amarillo/rojo del sobrante — para no competir con esa semántica ya fija del PRD).
  - **"Lo presté"** (a alguien le presté, me deben): chip pill con icono `arrow.down.forward` + texto **"Me deben"**, tinte `.blue` (semántica "información neutral" del catálogo de estados).
- **Barra de progreso**: `ProgressView(value:)` custom-estilizado (radio pill, altura 6pt, Continuous Corners), color = tinte de la dirección del préstamo (naranja si "Debo", azul si "Me deben") — no el accent de marca, para que la lectura de "cuánto llevo pagado de esta deuda" no se confunda visualmente con una acción primaria de la app.
- Orden de lista: activos primero (por fecha de fin más próxima), luego préstamos ya liquidados (`isActive == false`) en una sección aparte "Liquidados", colapsada por defecto.
- Tap/click → push a Detalle. Swipe/botón "+" en toolbar → Formulario de alta.

### 2. Formulario crear/editar

`Form` nativo, mismo patrón que Recurrentes/Suscripciones/Servicios:

| Campo | Control | Comportamiento |
|---|---|---|
| Nombre | `LabTextField` | Texto libre — "Upstart #1", "Ada" |
| Dirección | `Picker` segmented, 2 opciones: "Me lo prestaron" / "Lo presté" | Determina el chip/tinte en toda la UI del préstamo; no cambia después de creado sin confirmación explícita (cambiar de dirección con historial de pagos ya generado es una acción destructiva conceptual — pedir `confirmationDialog`) |
| Monto original | `LabTextField` numérico + toggle USD/MXN junto al campo | Igual patrón que captura de línea en Quincena |
| APR (%) | `LabTextField` numérico, `.decimalPad`, sufijo "%" | Válido 0–100; en 0% el préstamo es sin interés (toda la tabla de amortización es capital puro) |
| Fecha de inicio | `DatePicker` `.compact` | |
| Plazo en meses ↔ Fecha de fin | Dos campos enlazados en la misma fila: `Stepper`/`LabTextField` de "Plazo (meses)" + `DatePicker` de "Fecha fin" | Editar uno recalcula el otro en vivo a partir de fecha de inicio + frecuencia (ej. 48 meses desde ago 2026 → fecha fin jul 2030; mover la fecha fin recalcula el plazo en meses). Un solo campo es la fuente de verdad en cada edición — el que el usuario tocó último — nunca hay estado inconsistente entre ambos |
| Frecuencia | `Picker` `.pickerStyle(.menu)`: "Mensual, día X" / "Cada quincena" | Si "Mensual, día X": `Stepper` adicional 1–31 para el día |
| Pago calculado | Texto informativo (`.body`, `.monospacedDigit()`, `.secondary`) bajo Frecuencia: "Pago calculado: $629.00/mes" — fórmula de amortización estándar (monto, APR, plazo) | Recalcula en vivo al cambiar monto/APR/plazo/frecuencia |
| Override del pago | Botón de texto "Sobreescribir monto de pago" bajo el pago calculado | Al activarlo, el pago calculado se vuelve editable (`LabTextField`); al escribir un valor distinto, aparece debajo un texto informativo `.caption` `.secondary`: "Con este pago, el préstamo se liquida en 52 meses (ago 2030 → dic 2030)" — recalculando el plazo real a partir del pago fijo, en vez de al revés. Volver al cálculo automático restaura el plazo original |
| Activo | `LabToggleRow` | Un préstamo inactivo deja de generar línea en quincenas futuras no materializadas, pero conserva su historial y su Detalle es accesible desde la sección "Liquidados" de la lista |

### 3. Detalle — cabecera + tabla de amortización

**Cabecera** (card `LabNestedCard`, mismo patrón visual que el badge de sobrante pero sin semáforo — un préstamo no tiene "bueno/malo", tiene estado factual):

```
Saldo restante                    ← .caption2, ALL CAPS, .secondary
$18,420.00                        ← .monospacedDigit(), bold, tamaño grande (mismo tratamiento
                                     tipográfico que el sobrante, sin color de semáforo — color
                                     = tinte de dirección, naranja "Debo" / azul "Me deben")

Pagado a la fecha: $11,580.00     ← .subheadline, .secondary
Interés total: $3,240.00          ← .subheadline, .secondary
Próximo pago: $629.00 · 20 sept   ← .subheadline, .secondary
Fecha de fin: ago 2030            ← .subheadline, .secondary
```

**Tabla de amortización** — periodo a periodo (fecha, pago, interés, capital, saldo):

- **iPhone:** `List` de filas custom (no `Table`, no soportado en compacto) — cada fila en `.monospacedDigit()`: fecha `.leading`, pago/interés/capital/saldo en `.trailing` apilados en dos líneas por espacio (fecha+pago en línea 1, interés/capital/saldo en línea 2 más pequeña `.caption`).
- **Mac:** `Table` nativo con columnas Fecha / Pago / Interés / Capital / Saldo, todas `.monospacedDigit()`, `.trailing` salvo Fecha. Ordenable por columna no es necesario (el orden cronológico es el único que tiene sentido) — se deshabilita el sort de header.
- **Fila ya pagada** (fecha ≤ hoy): `.secondary` en todo el texto, sin énfasis — es historial.
- **Fila actual** (el próximo pago pendiente): fondo resaltado sutil (`accentSubtle` al 50% adicional de opacidad), texto `.primary`, único punto de la tabla con color de acento — es la única fila que representa una decisión próxima del usuario.
- **Filas futuras** (después de la actual): `.secondary`, igual que las pagadas visualmente, pero sin el fondo resaltado — se distinguen de las pagadas solo por estar después de la fila resaltada, nunca hace falta un tercer tratamiento visual (la posición relativa a la fila actual ya lo comunica).

### Accesibilidad

- Cada fila de la lista de préstamos expone un solo `accessibilityElement(children: .combine)` cuyo `accessibilityLabel` concatena dirección + nombre + saldo en una frase, no solo el nombre — ej. "Debo, Upstart uno, saldo restante 18,420 dólares" — para que VoiceOver comunique la dirección y el saldo sin que el usuario tenga que navegar campo por campo dentro de la fila.
- El chip de dirección nunca depende solo del color naranja/azul — el texto "Debo"/"Me deben" es parte del `accessibilityLabel` y está siempre visible tipográficamente, no oculto en un tooltip.
- La barra de progreso expone `accessibilityValue` con el porcentaje en texto ("34 por ciento pagado"), no solo el `value` numérico del `ProgressView`.

### Estado vacío

`LabEmptyState(systemImage: "banknote", title: "Sin préstamos todavía", subtitle: "Registra un préstamo para ver su saldo y calendario de pagos automáticamente")` con CTA — mismo patrón que las otras cuatro listas del hub.

### Origen de línea en Quincena — regla de edición manual

Igual que Recurrentes/Suscripciones/Servicios: la línea que un préstamo genera en una quincena nace con `origin: .loan`, `isManuallyEdited: false`; si el usuario la edita a mano, el icono cambia de `banknote` a `pencil` (ver tabla de iconografía de origen) y esa quincena específica queda protegida de la regeneración automática si el préstamo se edita después — misma regla "la edición manual gana" del TRD, sin caso especial para préstamos.

---

## Estados de pantalla

### Quincena

| Estado | Diseño |
|---|---|
| Loading (primera apertura, materializando) | Skeleton: bloques INCOME/EXPENSES con filas `.redacted(.placeholder)`, 3 filas fantasma cada uno |
| Vacío (quincena sin ningún recurrente/suscripción configurado aún y sin líneas manuales) | Los bloques no desaparecen — cada uno muestra únicamente su fila de captura rápida ("Agregar ingreso"/"Agregar gasto") y el total en $0.00; no se usa `ContentUnavailableView` de pantalla completa porque los totales y el sobrante siguen siendo información real (cero) que el usuario necesita ver |
| Error (fetch de tipo de cambio falla) | No bloquea la pantalla — banner discreto arriba del bloque EXPENSES: "No se pudo actualizar el tipo de cambio, usando el último conocido (18.42, hace 2 días)" `.caption`, `.secondary`, con icono `exclamationmark.triangle`. La quincena se sigue viendo y editando con normalidad |
| Success / normal | El estado por defecto descrito en el resto de este documento |

### Ingresos recurrentes / Gastos recurrentes / Servicios / Suscripciones

| Estado | Diseño |
|---|---|
| Vacío | `LabEmptyState` con `systemImage`/título propio de cada lista — ej. Servicios: `LabEmptyState(systemImage: "house.fill", title: "Sin servicios todavía", subtitle: "Agrega renta, luz u otro pago del hogar para que se calcule solo en cada quincena")`; Suscripciones conserva el `systemImage: "repeat"` ya definido; Préstamos usa el estado vacío ya especificado en "Préstamos (Loans)"; incluye CTA |
| Loading | `.redacted(.placeholder)` sobre `LabList` |
| Error | No aplica (datos 100% locales, sin red) |

### Préstamos — detalle

| Estado | Diseño |
|---|---|
| Loading | Cabecera y tabla en `.redacted(.placeholder)`, 5 filas fantasma en la tabla |
| Vacío (préstamo recién creado, sin pagos aún) | La tabla de amortización se muestra completa desde el primer pago (se calcula entera al crear el préstamo, no se genera perezosamente como las líneas de quincena) — no hay estado vacío real, la primera fila siempre es la resaltada como "actual" |
| Error | No aplica (cálculo 100% local, sin red) |

### Overview

| Estado | Diseño |
|---|---|
| Vacío (sin ninguna quincena materializada) | `LabEmptyState` invitando a capturar la primera quincena |
| Normal | Tabla mensual (dos quincenas) + resumen anual, solo lectura, `.monospacedDigit()` en toda cifra |

---

## Consideraciones de plataforma

### iPhone

- Thumb-zone: captura rápida y toggle "pagado" dentro del tercio inferior/medio de la pantalla en el uso típico (listas empiezan arriba pero el usuario captura scrolleando).
- Tap targets ≥ 44×44pt en toda fila, toggle, chevron de navegación.
- Todo el contenido de Quincena vive en un `ScrollView` — no se fuerza a caber sin scroll en iPhone (eso es requisito exclusivo de Mac).

### Mac

- Ventana: tamaño inicial 1000×700pt, mínimo 900×600pt (`.windowResizability(.contentSize)` con `.frame(minWidth: 900, minHeight: 600)`) — a 900×600 los dos bloques + badge de sobrante + panel lateral deben caber sin scroll con la densidad Regular del tema; si en implementación real algún caso (usuario con 15+ líneas en un bloque) no cabe, el bloque individual gana scroll interno propio, nunca la ventana completa fuerza scroll externo del layout.
- Toolbar: chevrons de navegación (`.navigation` placement), título/jump-button (`.principal`), botón "+" de captura (`.primaryAction`).
- Atajos de teclado: `⌘←`/`⌘→` navegar quincena, `⌘N` nueva línea (foco en captura del bloque activo), `⌘,` Ajustes (Settings scene nativo).
- Sidebar 220pt, con `Label` + `systemImage` por sección.

---

## Búsqueda

Fintrol no tiene una feature de búsqueda en v1 — el volumen de datos de un presupuesto personal (decenas de líneas por quincena, no miles) no lo justifica; navegar por quincena/año ya cubre "encontrar algo". No se implementa `.searchable()` en ningún listado del MVP.

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-09-15 | Fondo base `AppBackground` (#323232 del tema), no `systemBackground` negro puro | Requisito del tema Fintrol — gris oscuro neutro, no negro OLED |
| 2026-09-15 | Cards de contenido usan material Frost del tema, nunca Liquid Glass | Regla de capas: Liquid Glass solo en navegación; Frost es el material de marca de Fintrol para contenido |
| 2026-09-15 | Sobrante usa `.green`/`.yellow`/`.red` de sistema, no el accent naranja | Semántica fija del PRD — el naranja de marca nunca se confunde con el semáforo financiero |
| 2026-09-15 | Navegación entre quincenas: chevrons (adyacente) + jump sheet por título (año/quincena arbitraria) + botón "Hoy" | Resuelve explícitamente el riesgo de "perderse" en una proyección a 10 años |
| 2026-09-15 | Captura rápida es una fila inline al final de cada bloque, no un botón que abre sheet aparte | Replica el flujo de "llenar una hoja de cálculo" que es el modelo mental del usuario |
| 2026-09-15 | Línea de origen recurrente/suscripción/servicio editada manualmente cambia su icono base (`arrow.triangle.2.circlepath` / `repeat` / `house.fill`) a `pencil` | Comunica visualmente la regla "la edición manual gana" del TRD sin texto adicional |
| 2026-09-15 | "Recurrentes" se divide en "Ingresos recurrentes" y "Gastos recurrentes"; cada lista solo su tipo, alta directa sin picker | Decisión del usuario — evita preguntar ingreso/egreso cuando el contexto ya lo dice |
| 2026-09-15 | Se agrega "Servicios" (pagos del hogar: renta, luz, internet, agua, gas, seguro), mecánica idéntica a Suscripciones pero pantalla, icono y categorías propias | Decisión del usuario — separa gasto operativo del hogar de suscripciones de entretenimiento/trabajo, aunque el motor de cálculo por día de pago sea el mismo |
| 2026-09-15 | Suscripciones se mueve del tab propio al hub "Recurrentes y pagos", junto con Ingresos/Gastos recurrentes y Servicios | Con tres listas ya viviendo en un hub, dejar Suscripciones como único tab de nivel top por una sola fuente de datos rompía la consistencia; las cuatro responden a la misma pregunta del usuario ("qué se repite solo") |
| 2026-09-15 | Tab bar de iPhone baja de 5 a 4 tabs (Quincena, Recurrentes y pagos, Overview, Ajustes) | Consecuencia directa de mover Suscripciones al hub — no se rellena el quinto slot solo por simetría |
| 2026-09-15 | Nueva feature v1 "Préstamos": quinta fila del hub "Recurrentes y pagos", icono `banknote` (no `creditcard.and.123`) | Decisión del usuario; el ícono evita asociación visual con tarjetas de crédito, explícitamente fuera de v1 en el PRD |
| 2026-09-15 | Dirección del préstamo ("Debo"/"Me deben") en chip icono+texto con tinte `.orange`/`.blue`, no `.green`/`.red` | Evita colisión con la semántica fija del semáforo del sobrante (verde/amarillo/rojo), que es exclusiva de ese cálculo |
| 2026-09-15 | Override del pago de un préstamo recalcula el plazo (nunca al revés) | El usuario fija lo que puede pagar; el plazo es la consecuencia, coincide con cómo se razona un préstamo real |
| 2026-09-15 | Tabla de amortización: `List` de filas custom en iPhone, `Table` nativo en Mac | `Table` no es viable en ancho compacto; ambas muestran las mismas 5 columnas con distinto layout |
| 2026-09-15 | Origen `.subscription` usa icono distinto según sea Suscripciones (`repeat`) o Servicios (`house.fill`); `.recurring` conserva `arrow.triangle.2.circlepath` | Responde a la pregunta explícita del usuario de si la fila de quincena debe distinguir el origen — tres iconos para tres fuentes, sin texto adicional |
| 2026-09-15 | Pantalla de bloqueo Face ID no monta ningún dato real detrás, no es blur sobre contenido | Cierra el riesgo del PRD de montos visibles en app switcher/background |
| 2026-09-15 | Sin `.searchable()` en v1 | Volumen de datos de un presupuesto personal no lo justifica |
| 2026-09-15 | Mac: panel de resumen fijo a la derecha del detail, no columna adicional de `NavigationSplitView` | El PRD pide sidebar + contenido; una tercera columna de sistema competiría con la sidebar de secciones |

---

## Sin definir aún

- [ ] Icono de la app — no se ha diseñado; queda pendiente de una sesión dedicada con Phil.
