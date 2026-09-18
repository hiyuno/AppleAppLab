# DESIGN_LIQUID — Fintrol

> Estilo para iOS 26+ / macOS 26+ (Tahoe, Liquid Glass).
> Fuente de verdad de diseño. Última actualización: 2026-09-17.
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
| Fondo secundario | `Color(.secondarySystemBackground)` | #F2F2F7 | #000000 |
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

### Origen de línea (`LineOrigin`) — sin icono en la fila, decisión del usuario

La fila de Quincena no muestra ningún icono de origen — ni `arrow.triangle.2.circlepath`, ni `repeat`, ni `house.fill`, ni `banknote`, ni `chart.line.uptrend.xyaxis`, ni `pencil` para las editadas a mano. La fila es solo **descripción + monto** (+ palomita de pagado si aplica, ver "Fila de línea"). El origen (`.manual`/`.recurring`/`.subscription`/`.loan`/`.investment`/`.carryOver`) y si fue editado manualmente (`isManuallyEdited`) siguen siendo datos reales del modelo — solo dejan de tener representación visual permanente en reposo:

| Dónde vive el origen ahora | Cómo se expone |
|---|---|
| Accesibilidad | `accessibilityLabel`/`accessibilityValue` de la fila lo incluye en texto — ver "Accesibilidad obligatoria" más abajo, se actualiza para anunciar el origen igual que ya anuncia "inactiva"/"pagada" |
| Edición (inline o formulario de detalle) | Al entrar en modo edición, la fila puede mostrar de dónde vino el valor (ej. "Generado por: Upstart #1" como texto `.caption` `.secondary` sobre los campos editables) — es información de contexto en el momento de editar, no una marca permanente en reposo |
| Detalle de Préstamos/Inversiones | Las tablas de amortización/historial de esas pantallas conservan su propia distinción visual "Proyectado" vs. real — eso no cambia, es una pantalla distinta de la fila de Quincena |

Razón del cambio: cinco (ahora seis, contando `pencil`) símbolos posibles por fila competían visualmente con la lectura rápida de descripción+monto que es el modelo mental central de la app (hoja de cálculo). El origen sigue siendo real y consultable, solo deja de imprimirse en cada fila.

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
| Header de sección (INCOME / EXPENSES) | `.caption` | Semibold | +0.5 | `ALL CAPS` vía `.textCase(.uppercase)`, nunca string en mayúsculas; **decisión del usuario: vive fuera de la card**, como encabezado de sección iOS grouped encima del bloque — no como primera fila dentro de él (ver "Bloques INCOME / EXPENSES") |
| Título de línea (descripción) | `.body` | Regular | 0 | |
| Monto de línea | `.body` | Semibold | 0 | `.monospacedDigit()`, alineado `.trailing` |
| Monto convertido / TC (caption bajo línea MXN) | `.caption` | Regular | 0 | `.secondary`, `.monospacedDigit()` |
| Total INCOME / Total EXPENSES | `.title3` | Semibold | 0 | `.monospacedDigit()`, `.trailing` |
| Metadata (día de pago, frecuencia, categoría) | `.subheadline` | Regular | 0 | `.secondary` |
| Badge de categoría / origen | `.caption2` | Regular | +1.2 | `ALL CAPS` |
| Label de botón | `.headline` | Semibold | 0 | |

### Text Styles de Figma (librería reutilizable — página "Tokens", `tSUzh4zfCpDPYT5A88otst`)

Se formalizaron como **Text Styles reales de Figma** (no cajas de muestra sueltas) para que cualquier frame nuevo los aplique por nombre — nomenclatura pedida por el usuario (`h1`/`h2`/`h3`/`p normal`/`p big`/`p small`), verificada contra el código real de `Apps/Fintrol/Fintrol/` (`grep -rn ".font(" `) antes de mapear, no inventada:

| Nombre en Figma | Dynamic Type de Apple (HIG) | Tamaño/Peso | Uso real confirmado en código |
|---|---|---|---|
| `h1` | `largeTitle` | 34pt Bold | `SobranteBadge`, montos hero de `LoanDetailView`/`InvestmentsView` (`.largeTitle.weight(.bold)`, 4 ocurrencias) |
| `h2` | `title2` | 22pt Semibold | Título de pantalla, ej. header de Quincena (`.title2.weight(.semibold)`, 2 ocurrencias) |
| `h3` | `title3` | 20pt Semibold | `LoanDetailView` (`.title3.weight(.semibold)`, 1 ocurrencia) |
| `h4` | `headline` | 17pt Semibold | Encabezados de card/label de botón (`.headline`, 3 ocurrencias) |
| `p big` | `body` | 17pt Regular | Texto de línea/fila principal — INCOME/EXPENSES, "Mandar", etc. (`.body`, 5 + 11 con peso Semibold) — el párrafo más grande realmente usado hoy |
| `p normal` | `subheadline` | 15pt Regular | Texto secundario/metadata — frecuencia, día de pago (`.subheadline`, 6 ocurrencias) |
| `p small` | `caption` (caption1) | 12pt Regular | El texto pequeño más usado en la app — labels, captions (`.caption`, 31 + 5 con peso Semibold). **Nuevo uso confirmado:** también reemplaza al `.system(size: 14, weight: .bold)` de los encabezados de sección INCOME/EXPENSES — ver nota de migración abajo |
| `p tiny` | `caption2` | 11pt Regular | Badges de categoría/origen (`.caption2`, 5 ocurrencias) |
| `h5` | ⚠️ **ninguno — no es Dynamic Type** | 14pt Semibold, **tamaño fijo** | `.system(size: 14, weight: .semibold)` — decisión explícita del usuario. No escala con Ajustes de Texto/Dynamic Type, a diferencia de los 8 estilos anteriores. Misma naturaleza de excepción que el `.system(size: 14, weight: .bold)` que migró a `p small` (ver nota 3 más abajo) — aquí el usuario decidió lo contrario: mantenerlo como tamaño fijo en vez de migrarlo a un Dynamic Type style |

**Decisiones cerradas por el usuario (ya no son preguntas abiertas):**
1. "p big" se queda en `body` 17pt, sin cambio — no se reserva un tamaño nuevo.
2. `h4`/`p big` comparten tamaño (17pt) a propósito, distinguidos solo por peso (`headline` Semibold vs `body` Regular) — confirmado, es el comportamiento esperado (igual que `headline`/`body` en HIG). Antes era el par `h3`/`p big`; con la corrección de jerarquía de abajo, el par pasó a ser `h4`/`p big`.
3. **El `.system(size: 14, weight: .bold)` de los encabezados de sección migra a `p small` (`.caption.weight(.bold)`, 12pt) — pendiente de coordinar con Woz el cambio de código en `PeriodView.swift` (filas INCOME/EXPENSES)** para que deje de ser un tamaño fijo sin `relativeTo:` y pase a escalar con Dynamic Type como el resto de la librería.
4. Se agregaron `h3` (`title3`, 20pt Semibold) y `p tiny` (`caption2`, 11pt Regular) — librería final de **8 Text Styles**, ya construidos en Figma (página Tokens, frame `1:49`) igual que los anteriores.
5. **Corrección de jerarquía (bug detectado por el usuario):** los nombres `h3`/`h4` estaban invertidos — `h4` (20pt) era más grande que `h3` (17pt), al revés de `h1 > h2 > h3 > h4`. Se intercambiaron los **nombres** (no los tamaños) en Figma y en esta tabla: `title3` (20pt) ahora es `h3`, `headline` (17pt) ahora es `h4`. Verificar que ningún frame ya construido en Figma referenciaba el nombre viejo antes del swap.

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

> **Nota de consistencia (parcialmente superada por el rediseño de card-por-línea, ver "Bloques INCOME / EXPENSES"):** las filas de línea dentro de un bloque de 20pt con padding de 16pt matemáticamente dan r_inner=4pt. Pero una fila de 44–52pt de alto con r=4pt se ve casi rectangular, lo cual es correcto para una fila de "tabla" (no se quiere que cada fila lea como mini-card). El valor de 12pt de la tabla de arriba ya no aplica a ningún estado de la fila: editar ya no es un estado in-place con fondo propio elevado — abre el "Sheet de captura/edición de línea" (ver esa sección), así que la fila en reposo nunca cambia de radio ni de fondo por edición. El radio de 20pt de cada card-por-línea (ver "Bloques INCOME / EXPENSES") es el que aplica siempre.

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
| Sheet (jump quincena, formularios de Recurrentes/Suscripciones/Servicios/Préstamos/Inversiones) | Sistema — Liquid Glass `regular` (no `.clear`, ver nota de Variante abajo) |
| Sheet de captura/edición de línea (INCOME/EXPENSES) | **Excepción documentada:** fondo Frost del tema, no Liquid Glass — ver "Sheet de captura/edición de línea" más abajo, decisión explícita del usuario sobre esta pantalla en particular |
| Pantalla de bloqueo Face ID | Fondo `AppBackground` sólido, sin glass — es una superficie de seguridad, no de navegación; ver sección Face ID |
| Botón de atrás (pantallas de lista del hub) | Nativo de `NavigationStack` — Liquid Glass automático del sistema en iOS 26, igual que el "+"; **decisión del usuario, revierte el `NavCircleButton` que se había formalizado aquí:** no hace falta un componente custom, el back button nativo ya recibe el cristal correcto sin intervención |

**Variante:** Regular en toda la navegación. No hay caso de uso para Clear en Fintrol — no hay media-rich content detrás de las barras (es una app de texto y números), así que Clear no aporta y arriesgaría legibilidad de los montos.

### Superficies macOS 26+

| Superficie | Variante | Capas de contraste | Razón |
|---|---|---|---|
| Ventana principal sobre wallpaper (fondo de `NavigationSplitView`) | Liquid Glass `regular` en sidebar; contenido central en `AppBackground` sólido (#323232), no glass | Sin capa neutral adicional — el fondo sólido del tema ya da el contraste que un `clear` necesitaría simular | Fintrol es una app de trabajo con números todo el tiempo en pantalla; un fondo `clear` que deja ver el wallpaper detrás de columnas de dinero compite con la legibilidad — se prioriza la lectura sobre el efecto atmosférico |
| Cards internas (bloques INCOME/EXPENSES, panel resumen, Suscripciones/Recurrentes) | Frost del tema (no glass) | Fill `AppBackground.tertiary` ~`#3C3C3C`, sin borde adicional — la separación la da el material Frost, no un borde | Frost aporta la textura translúcida de marca sin competir con Liquid Glass de la sidebar |
| Campo de texto (monto, descripción, tipo de cambio manual) | Fill `AppBackground.secondary` (~#000000) opaco | Borde de foco `accentBorder` (#FF7E4D dark), 1.5pt | El foco usa el token de acento de Fintrol, nunca naranja hardcoded fuera del token |

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

### Recurrentes y pagos — hub (iPhone) / ítems directos en sidebar (Mac)

Decisión del usuario, en cuatro pasos: primero "Recurrentes" se dividió en **"Ingresos recurrentes"** y **"Gastos recurrentes"** (cada una lista solo su tipo, botón "+" crea ese tipo directo, sin picker de ingreso/egreso). Después se agregó **"Servicios"** — pagos del hogar (renta, luz, internet, agua, gas, seguro), mismo mecanismo automático por día de pago que Suscripciones (TRD, `Subscription`) pero con su propia pantalla, icono y categorías de hogar, distinta de Suscripciones (Netflix, Claude, Spotify…). Con tres listas ya viviendo fuera de un tab propio, mover también **Suscripciones** al mismo hub fue lo coherente: las cuatro son "cosas que la app genera solas en cada quincena sin captura manual". Luego se agregó **"Préstamos"** (ver "Préstamos (Loans)" más abajo) como quinta fila. Ahora se agrega **"Inversiones"** (feature v1 nueva, ver "Inversiones (Investments)" más abajo) como sexta fila — aportaciones recurrentes a cuentas de inversión (GBM, Webull, crypto…) que también generan su línea sola en cada quincena, misma razón que las otras cinco. **Nota de alcance:** esto es distinto de "Control de inversiones" que el PRD marca fuera de v1 (Fase 3) — esa exclusión es sobre rendimientos/valor de portafolio; "Inversiones" aquí es solo el registro de la aportación periódica, tan simple como un recurrente con cuenta destino. El hueco de rendimientos/valor actual queda anotado en "Sin definir aún" para etapa 2, no se diseña ahora.

Esto también informa el patrón de acceso rápido que ya existía en `SettingsView` (`Apps/Fintrol/Fintrol/Features/Settings/SettingsView.swift:92`, fila `NavigationLink("Recurrentes")`) — esa fila queda obsoleta como camino alterno mixto: Ajustes no debe ofrecer una segunda entrada a estas listas por fuera del hub; si Woz quiere mantener acceso rápido desde Ajustes, debe ser un solo `NavigationLink("Recurrentes y pagos")` que abre el mismo hub, no filas sueltas por tipo.

**Actualización del usuario (mockup exportado, no live file de Figma):** las filas se agrupan en **3 secciones con encabezado** (mismo patrón visual de encabezado de sección que INCOME/EXPENSES en Quincena — `.caption` `ALL CAPS`, `.secondary`, fuera de las cards):
- **"INCOME"** — Ingresos recurrentes
- **"EXPENSES"** — Gastos recurrentes, Servicios, Suscripciones, Préstamos, **Credit Cards** (feature v1 nueva, promovida desde Fase 2 del PRD — ver "Tarjetas de crédito (Credit Cards)" más abajo)
- **"OTHERS"** — Inversiones

**Actualización (2026-09-17, coordinador):** "Gastos recurrentes" se movió de "INCOME" a "EXPENSES" (primera fila de ese grupo, antes de Servicios/Suscripciones/Préstamos) — corrige la agrupación puramente literal documentada arriba, que dejaba un gasto bajo el encabezado "INCOME" sin ninguna razón semántica. "INCOME" ahora contiene solo "Ingresos recurrentes". La nota anterior ("no corregir a criterio propio") queda superada por esta instrucción explícita del coordinador — "EXPENSES" sigue sin ser 100% preciso para Préstamos (que pueden ser "Me deben"), eso no cambió.

- **iPhone:** la tab "Recurrentes y pagos" (icono `arrow.triangle.2.circlepath`) abre un hub — `List` de 7 filas `LabListRow` con chevron, agrupadas en las 3 secciones de arriba. Orden dentro de cada sección:
  1. "Ingresos recurrentes" — `systemImage: "arrow.down.circle"`, subtitle con conteo
  2. "Gastos recurrentes" — `systemImage: "arrow.up.circle"`, subtitle con conteo
  3. "Servicios" — `systemImage: "house.fill"`, subtitle con conteo
  4. "Suscripciones" — `systemImage: "repeat"`, subtitle con conteo
  5. "Préstamos" — `systemImage: "banknote"`, subtitle con conteo — símbolo elegido en su momento en parte para no leer como "tarjeta de crédito" cuando esa feature estaba fuera de v1; ahora que Credit Cards entró a v1 (ver fila 6), `banknote` se mantiene igual — sigue siendo el símbolo correcto para "dinero prestado/prestado a alguien", distinto conceptualmente de una tarjeta
  6. **"Credit Cards"** — `systemImage: "creditcard.fill"`, subtitle con conteo — feature v1 nueva, ver "Tarjetas de crédito (Credit Cards)" más abajo
  7. "Inversiones" — `systemImage: "chart.line.uptrend.xyaxis"`, subtitle con conteo — se acepta la sugerencia del coordinador: es el símbolo estándar de Apple para inversión/crecimiento, distinto de los otros orígenes y sin ambigüedad con "gráficas de Overview" (Overview usa `chart.bar.fill`, una barra, no una línea — no se confunden en la tab bar)
  - Tap en cada fila hace push a su lista filtrada, donde vive el botón "+" que crea ese tipo directo. El hub no tiene botón "+" propio.
- **Mac:** el límite de tabs es exclusivo de iPhone; el sidebar no lo tiene, así que ahí las siete son **ítems directos**, sin hub intermedio — cada uno navega directo a su lista con su propio "+" en el toolbar.

### Mac — `NavigationSplitView`, sidebar + detail (sin columna media)

10 secciones en sidebar (ancho 220pt): Quincena, Ingresos recurrentes, Gastos recurrentes, Servicios, Suscripciones, Préstamos, Credit Cards, Inversiones, Overview, Ajustes. El PRD tiene solo 2 niveles de profundidad reales (lista → detalle de recurrente/suscripción/servicio/préstamo/tarjeta/inversión), así que no se usa columna `content` intermedia — sidebar + detail directo:

```swift
NavigationSplitView {
    SidebarView()   // Quincena, Ingresos recurrentes, Gastos recurrentes, Servicios, Suscripciones, Préstamos, Credit Cards, Inversiones, Overview, Ajustes
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
[ 1 – 15 ]                 ← pill que YA ES el indicador de estado — ver punto 3, no hay
                             badge "Current"/"Proyección" separado
```

**Decisión del usuario, reemplaza el punto 3 anterior:** se elimina el badge "Current"/"Proyección" como elemento aparte. La segunda línea del header — la que ya muestra el rango de días ("1 – 15" / "16 – 30", con el último día REAL del mes vía `PeriodDateEngine`, nunca un "30" genérico) — pasa a ser ella misma la pill de estado, doblando función: texto de rango + indicador visual de "dónde estoy" en una sola pieza, sin segundo elemento debajo.

Ambas líneas viven dentro del mismo botón (todo el bloque es el trigger del jump sheet, no solo la primera línea) y se centran como una unidad en el header.

**1. Navegación adyacente — chevrons en el toolbar/header**

- iPhone: dentro del header de la pantalla Quincena, un `HStack` con dos botones a los lados del bloque de título de dos líneas — símbolo **`chevron.backward`** / **`chevron.forward`**, `.buttonStyle(.glass)` sin tint (vigente, confirmado en código; sustituye la exploración anterior de `arrow.backward`/`arrow.right`, ver nota en "Íconos SF Symbols detectados" abajo). Swipe horizontal en el contenido también navega (gesto acelerador, con alternativa tap siempre presente en los chevrons — regla de gestos).
- Mac: mismos chevrons en el toolbar (`.navigation` placement a la izquierda), más atajos de teclado `⌘←` / `⌘→`.
- El chevron derecho nunca se deshabilita — avanzar siempre materializa la siguiente quincena bajo demanda (ver TRD, materialización perezosa). El chevron izquierdo se deshabilita (estado `.disabled`, opacidad reducida) al llegar al límite hacia atrás — que ahora es el **más cercano a hoy** entre dos topes: la **primera quincena materializada** (no existe "antes" real en los datos, coincide con "arranca desde cero en 2026") y **"Historial visible"** (Ajustes → Preferencias, default 1 mes atrás desde la quincena actual, configurable 1–24 meses — ver "Ajustes generales"). El jump sheet respeta el mismo límite combinado: el `Picker` de año/mes/quincena no ofrece opciones anteriores a ese punto de corte.

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

**3. Indicador de "dónde estoy"** — ya no es un badge de texto aparte ("Current"/"Proyección"); es el propio estilo de la pill de rango de días, con dos estados posibles, sin ninguna etiqueta de texto adicional en ningún caso:
  - **Quincena de HOY:** la pill "1 – 15"/"16 – 30" lleva **fondo verde sólido** (mismo verde del sobrante positivo, `#34C759`) con texto blanco/contrastante **Bold**.
  - **Pasada o proyectada (futura):** la pill es **transparente** (sin relleno, borde sutil opcional `.secondary` a baja opacidad), texto en `.secondary`/atenuado — un solo tratamiento visual para ambos casos (pasada y futura), no se distinguen entre sí; la distinción que antes hacía "Proyección" queda cubierta por el resto del contexto de pantalla (badges de origen de línea, "Generado por…" al editar), no por el header.

---

## Componentes del sistema

### Botones

- **CTA principal** ("Agregar línea", "Guardar recurrente"): `.buttonStyle(.glassProminent)` → tinte `AccentColor`, pill, 54pt en iPhone / 36pt en Mac.
- **Secundario** ("Cancelar"): `.buttonStyle(.glass)`.
- **Destructivo** ("Eliminar recurrente"): `.foregroundStyle(.red)`, siempre detrás de `confirmationDialog` — nunca borrado directo de una línea recurrente o suscripción (sí se permite swipe-to-delete directo en una línea manual suelta de INCOME/EXPENSES, reversible con undo del sistema).

### Bloques INCOME / EXPENSES — componente custom (no está en el catálogo)

**Decisión del usuario (edición directa en Figma, frame "01 · Quincena", `8:2`): cada línea es ahora su propia card/pill independiente, no una fila dentro de una card contenedora única.** Se abandona el patrón "una `LabNestedCard` con filas separadas por `Divider()`" en favor de "una card por línea, apiladas con gap". El total queda fuera de las cards, directamente sobre el fondo de la app.

- **Header de sección fuera de la card** (sigue igual que antes): `ALL CAPS`, `.caption` Bold, tracking +0.6, `.secondary` 60%, con padding propio de 10pt (ya no es solo texto suelto — vive envuelto en un contenedor con padding, ver tabla de medidas).
- **Cada línea (`LineItemRow`) es su propia card**: fondo Frost `AppBackground.secondary` (`#000000`), radio **20pt** (mismo radio que las cards grandes, no el radio interno de 12pt, sin cambio), padding **16pt** en los 4 lados (el usuario probó 24pt en Figma y revirtió al original), contenido en `HStack` (`.spaceBetween`) descripción `.leading` + monto `.trailing`, `.body` (17pt) Regular, blanco. Sin separador `Divider()` entre líneas — el separador visual ahora es el espacio, no una línea.
- **Gap entre cards de línea: 8pt** (`SpacingTokens.itemSpacing`), no los 4pt de densidad de tabla documentados antes — ese valor queda obsoleto para este patrón.
- **Fila de total: fuera de toda card**, sobre el fondo de la app directamente (sin `LabNestedCard` propio). `.body` (17pt) Bold, blanco, padding `10pt` arriba / `10pt` horizontal / ~1pt abajo, `HStack` `.spaceBetween`. Ya no lleva el `Divider()` de 2pt que la separaba del último ítem — el espacio hace esa función.
- **El patrón de card-por-línea con TOTAL fuera aplica por igual a INCOME y a EXPENSES** — no es exclusivo de INCOME, EXPENSES migra al mismo tratamiento (cards individuales + total suelto sobre el fondo). Confirmado en Figma: ambos bloques ya tienen sus líneas como cards independientes.

**Nueva edición manual del usuario en Figma (misma sesión, frame `8:2`) — decisiones ya cerradas por el usuario:**

- **El CTA de agregar es un ícono, no texto: `plus.circle.fill`, en INCOME y en EXPENSES por igual.** Reemplaza definitivamente la fila suelta "⊕ Agregar ingreso / ⊕ Agregar gasto" (ese texto queda obsoleto). La capa detectada en Figma como `plus.capsule.fill 1` no era un símbolo real (sufijo de auto-dedupe + nombre inexistente en el catálogo) — el símbolo correcto y ya confirmado es **`plus.circle.fill`**.
- **Posición del CTA — actualización del usuario (nueva captura de Figma), reemplaza la ubicación anterior:** el botón ya **no** vive en el header de sección junto al título. Se mueve a una posición independiente **debajo de la última card de línea**, antes de la fila de TOTAL — botón circular solo, sin texto, alineado a `.leading` (izquierda), mismo tratamiento en ambos bloques (INCOME y EXPENSES). El header de sección queda solo con el texto (`ALL CAPS`, sin ningún control a la derecha). Orden vertical final de cada bloque: header de sección → cards de línea apiladas → **botón "+" circular, solo, alineado a la izquierda** → fila de TOTAL.
- **Fila de TOTAL: el tamaño de texto bajó de 17pt a 14pt Bold** (blanco) — en ambos bloques (TOTAL INCOME y TOTAL EXPENSES).
- **Iconografía del header de navegación — superada por una decisión posterior confirmada en código:** en esta sesión de Figma los chevrons `‹`/`›` se habían reemplazado por `arrow.backward`/`arrow.right`; el estado vigente hoy es `chevron.backward`/`chevron.forward` con `.buttonStyle(.glass)` sin tint (ver tabla de íconos abajo y "Navegación adyacente" arriba).
- **Pill de estado en verde: excepción deliberada, no corregir — superada en su forma pero no en su color.** En esta sesión de Figma era un badge de texto aparte ("Hoy" → "Current"); una decisión posterior (ver "Header de Quincena — dos líneas + pill de estado") eliminó ese badge y trasladó el mismo tratamiento de color a la propia pill de rango de días. El color se mantiene: verde éxito (`#34C759` texto, `rgba(52,199,89,0.43)` fondo o sólido según el estado — ver spec vigente) en vez de acento naranja. El usuario confirmó que el verde aquí se queda aunque rompa la regla general "el verde se reserva para SOBRANTE / el naranja para lo que importa" — sigue siendo la única excepción documentada a esa regla en toda la app; no generalizar el verde a otros estados sin pedir la misma confirmación explícita.
- **SOBRANTE cambió de layout vertical a horizontal:** antes label arriba / monto abajo (`VStack`, gap 6pt); ahora es una sola fila `HStack` `.spaceBetween` — "SOBRANTE" a la izquierda, monto a la derecha, ambos en verde `#34C759` (antes el label era `.secondary` gris y solo el monto era verde).
- **Espaciado exterior cambió:** gap entre bloques mayores pasó de 19pt a **24pt**, y el padding lateral de 16pt ahora vive en el wrapper raíz (`px-16` sobre todo el contenido) en vez de aplicarse por-card.

#### Íconos SF Symbols detectados (nombre de capa = nombre del símbolo)

| Capa | Símbolo | Ubicación | Tamaño aprox. | Nota |
|---|---|---|---|---|
| `arrow.backward` (`11:112`) | ~~`arrow.backward`~~ **superado** | Header · TitleRow, extremo izquierdo | 23.76×18.92pt | Exploración de Figma en su momento; **vigente hoy: `chevron.backward`**, `.buttonStyle(.glass)` sin tint, confirmado en código |
| `arrow.right` (`11:121`) | ~~`arrow.right`~~ **superado** | Header · TitleRow, extremo derecho | 23.76×18.92pt | Exploración de Figma en su momento; **vigente hoy: `chevron.forward`**, `.buttonStyle(.glass)` sin tint, confirmado en código |
| CTA agregar (INCOME y EXPENSES) | **`plus.circle.fill`** ✅ decisión cerrada | **Actualizado:** ya no en el header de sección — vive solo, alineado a la izquierda, debajo de la última card de línea y antes de TOTAL | ~24×24pt (ajustar en Figma; la capa vista `plus.capsule.fill 1` era un símbolo inválido, no usar de referencia de tamaño) | Reemplaza la fila de texto "⊕ Agregar…" en ambos bloques |

**⚠️ Nueva exploración de Figma (lectura más reciente, frame `8:2`) — diverge de lo "confirmado en código" arriba, NO reemplazarlo sin que el usuario lo confirme:**

| Capa vista en Figma | Símbolo | Ubicación en esta exploración | Tamaño | Nota |
|---|---|---|---|---|
| `chevron.backward.circle.fill` (`38:62`) | ✅ válido | Header · TitleRow, extremo izquierdo | 24.94×24.6pt | Círculo relleno gris translúcido — visualmente el mismo tratamiento que `NavCircleButton` (ver "Componentes de navegación"), pero aquí para navegar quincena anterior/siguiente, no para volver al hub. Contradice el estado "confirmado en código" (`chevron.backward` plano, `.buttonStyle(.glass)`, sin círculo). Pendiente de que el usuario diga cuál es la dirección real: ¿se unifica el prev/next de Quincena con el mismo componente `NavCircleButton`, o son dos cosas distintas que casualmente se ven igual? |
| `chevron.right.circle.fill 1` (`38:73`) | ✅ válido (el símbolo es `chevron.right.circle.fill`; el " 1" es de nuevo el sufijo de auto-dedupe de Figma, no parte del nombre) | Header · TitleRow, extremo derecho | 24.94×24.6pt | Mismo comentario que arriba |
| `plus` (`57:66` en INCOME, `57:75` en EXPENSES) | ✅ válido, delgado, sin fondo de círculo/cápsula | De vuelta en el header de sección (derecha de "INCOME"/"EXPENSES"), ~19.8×19.8pt | Contradice el estado "confirmado en código" (CTA suelto debajo de la última card). Ya no es `plus.circle.fill` con relleno — es el símbolo `plus` desnudo. También el texto del header subió de 13pt a 16pt Bold en esta exploración. Pendiente de confirmación del usuario antes de mover el CTA de vuelta al header. |

**Otros cambios detectados en esta misma lectura, sin resolver:**
- Una de las dos cards "WALO $2,750.00" en INCOME tiene fondo `#023c2f` (verde oscuro) mientras la otra sigue en `#000000` neutral — no hay explicación visible (¿estado "pagada"? ¿resaltado accidental de una copia duplicada?). No asumir semántica; preguntar antes de documentar como estado nuevo.
- Pill de rango de días ("1 – 15"): valores exactos en esta lectura — fondo `rgba(52,199,89,0.5)`, texto `#34C759`, radio `50px` (no `999px`), texto 12pt Semibold. Cercano pero no idéntico a lo ya documentado en "Header de Quincena" — actualizar ahí si el usuario confirma estos como los valores finales.
- Tab bar: los 4 íconos ya son SF Symbols reales y sus nombres de capa coinciden con el símbolo: `calendar`, `arrow.trianglehead.2.clockwise.rotate.90` (reemplaza al glifo `↻`), `menucard` (✅ coincide con lo ya esperado para la tab 3), `gearshape`. Gap entre íconos: 30pt (antes documentado 18pt).

Documentar `LineItemRow` (ahora card individual) y el patrón "stack de cards con total suelto encima del fondo" en `PROJECT_LEARNINGS.md` como candidato a generalizarse a `AppleAppLabUI`.

### Fila de línea (`LineItemRow`) — estados visuales

**Decisión del usuario: se eliminan los toggles visibles de la fila.** Ambos estados de una línea (activa/inactiva y pagada/no pagada) se controlan por swipe, no por un control tap en la fila. Nota de producto: "activar/desactivar una línea" excluyéndola de la suma coincide en efecto con el switch "cuenta/no cuenta" que el PRD v1.1 marca explícitamente fuera de v1 ("Features — Fuera del MVP") — se implementa el diseño tal como lo pidió el usuario tras ver la app en simulador, pero queda señalado aquí para que Steve confirme si esto actualiza el PRD o si "activar/desactivar" es conceptualmente distinto de lo que el PRD excluyó.

| Estado | Apariencia |
|---|---|
| Reposo, cualquier origen (`.manual`/`.recurring`/`.subscription`/`.loan`/`.investment`/`.carryOver`), activa | Descripción `.leading` + monto `.trailing`, sin icono de origen ni controles visibles en la fila — todas las filas se ven igual en reposo independientemente de su origen o de si fueron editadas a mano; ver "Origen de línea" arriba |
| Reposo, origen carry-over ("Latest Month") | Sin marca visual distinta al resto; título no editable, solo el monto es de solo lectura (es el resultado calculado de la quincena anterior — si el usuario necesita cambiarlo debe editar la línea origen en la quincena previa) |
| **Pagada — bloqueada** | **Fondo de la card cambia de Frost gris a verde tenue** (ver token exacto abajo). Palomita discreta (`checkmark.circle.fill`, 14pt, tinte `.blue`, sin cambios) sigue visible a la derecha del monto — el color no es el único vector, la palomita se conserva aunque el fondo ya lo comunique (regla de accesibilidad: nunca solo por color). No afecta números. La línea queda **bloqueada**: la única acción disponible es "Desmarcar pagado" — ver "Swipe actions" y "Menú contextual" abajo para el detalle de qué desaparece |
| **Inactiva** (excluida de la suma) | Opacidad de toda la fila reducida a `0.4`; monto con `.strikethrough()`; el motor de totales la omite del cálculo del bloque |
| **Inactiva y pagada** | Se combinan: fondo verde tenue (igual que "Pagada — bloqueada") + opacidad de toda la fila reducida a `0.4` (el verde también queda atenuado, no se dibuja aparte a opacidad completa), monto tachado, palomita azul presente a la misma opacidad reducida — lee como "esto pasó, pero ahora mismo no cuenta". También bloqueada — solo "Desmarcar pagado" disponible (desmarcar revela de nuevo las acciones normales de una línea inactiva) |

**Token del fondo verde de "Pagada":** `Color.green.opacity(0.16)` superpuesto sobre el fondo Frost de la card (`AppBackground.secondary`, `#000000`) — no reemplaza el material, se mezcla encima. Deliberadamente más sutil que el verde sólido del badge de SOBRANTE (que es 100% opaco con texto contrastante) — aquí es un tinte, nunca relleno neón. Mismo radio 20pt Continuous Corners que cualquier card-por-línea, sin cambio de forma. Es una segunda excepción documentada al uso de verde en la app (la primera es la pill "Hoy" del header de Quincena, ver "Decisiones registradas") — ambas están confirmadas explícitamente por el usuario, no se generaliza verde a ningún otro estado sin la misma confirmación.
| Línea en MXN | Bajo el monto principal (que siempre se muestra en su moneda de captura), una segunda línea `.caption` `.secondary` `.monospacedDigit()`: "≈ $842.30 USD · TC 18.42" |
| Línea en MXN con override manual del tipo de cambio para esa quincena | Igual + badge `.caption2` pill pequeño "manual" en `accentSubtle`/`accentForeground`, junto al TC — señala que ese número no vino de la API |
| Editando | **Ya no es un estado in-place de la fila** — tap en la fila abre el "Sheet de captura/edición de línea" (ver más abajo) precargado con sus valores. La fila en sí no cambia de fondo ni de layout; el sheet es una presentación modal separada. Si el origen no es manual, el sheet puede mostrar contexto "Generado por: [nombre]" — ver "Origen de línea" |

**Fondo en reposo — dark mode:** con editar ahora resuelto por el sheet (ver "Sheet de captura/edición de línea"), la fila nunca cambia de fondo por edición — no hay estado "Editando" in-place que romper. **Nota de conflicto pendiente, no resuelta en esta pasada:** este párrafo originalmente describía filas transparentes sobre una card contenedora única; el rediseño posterior "card-por-línea" (ver "Bloques INCOME / EXPENSES") hace que cada fila SÍ tenga su propio fondo Frost (`AppBackground.secondary`, radio 20pt) siempre, no solo al editar — las dos descripciones son incompatibles y quedan sin reconciliar aquí; Woz/Larry deben tratar "Bloques INCOME / EXPENSES" (más reciente) como la vigente.

### Swipe actions — iPhone

Con los toggles fuera de la fila, tap sigue abriendo edición — ahora vía el "Sheet de captura/edición de línea" (ver más abajo) en vez de inline, **salvo que la línea esté pagada** (ver bloqueo abajo). Los dos ejes de swipe reemplazan lo que antes eran controles visibles:

| Dirección | Acción | Icono / tinte | Full swipe | Notas |
|---|---|---|---|---|
| **Leading** (izquierda→derecha) | Activar / Desactivar (según estado actual) | Inactivo→Activo: `arrow.uturn.backward.circle.fill`, tinte `.blue` · Activo→Inactivo: `minus.circle.fill`, tinte `.gray` (`systemGray`) | Sí, permitido — dispara la acción sin confirmación | Nunca verde/rojo — esos dos colores son exclusivos del semáforo del sobrante en esta app; gris y azul se usan aquí porque no son ninguno de los tres estados reservados. **No disponible si `isPaid == true`** — el swipe leading en una línea pagada no revela nada (`.swipeActions` vacío en ese borde) |
| **Trailing** (derecha→izquierda), 1ª acción | Marcar / Desmarcar pagado | `checkmark.circle.fill` (marcar) / `circle` outline (desmarcar), tinte `.blue` | Sí — full swipe marca/desmarca directo | Mismo azul que "Activar" a propósito: ambas son acciones de estado, no destructivas ni de alerta. **Es la única acción que sigue disponible en una línea pagada** — desmarcarla es también lo que la desbloquea |
| **Trailing, 2ª acción** (revelada al deslizar más) — solo líneas `.manual`, **y solo si `isPaid == false`** | Eliminar | `trash`, `role: .destructive` (rojo de sistema) | No — requiere tap explícito en la acción, nunca full swipe | El rojo aquí es la convención universal de "eliminar" de iOS/macOS, no una señal financiera. **Ausente mientras la línea está pagada** — el swipe trailing en una línea pagada revela solo "Desmarcar pagado", sin segunda acción |
| **Trailing, 2ª acción** — líneas de origen `.recurring`/`.subscription`/`.loan`/`.carryOver`, **y solo si `isPaid == false`** | Editar | `pencil`, tinte `.gray` (`systemGray`) | No | Reemplaza a "Eliminar" en líneas generadas. **Ausente mientras la línea está pagada**, misma razón que arriba |

**Línea bloqueada por `isPaid == true` — comportamiento recomendado, decisión cerrada:** las acciones que no aplican simplemente **no aparecen** — no hay toast, alert ni mensaje explicando "Quita 'pagado' para editar". Es el patrón estándar de iOS: `.swipeActions`/`.contextMenu` condicionales que solo listan las acciones válidas para el estado actual, igual que Mail o Reminders no muestran un swipe action que no aplica y no explican por qué. Tap en una línea pagada tampoco abre el sheet de edición — no pasa nada visible (sin haptic de error, sin mensaje; el usuario ya tiene la señal visual clara del fondo verde + la palomita de que la línea está en un estado distinto).

### Menú contextual (long-press / botón "···", iPhone y Mac)

Mismas acciones que el swipe, para descubribilidad y para Mac (donde el swipe de trackpad puede no ser obvio para todos los usuarios). Igual que el swipe, el menú es condicional al estado:

- **Línea no pagada:** `.contextMenu`: "Activar"/"Desactivar", "Marcar pagado", "Cambiar a MXN/USD", "Editar", "Eliminar" (solo líneas `.manual`).
- **Línea pagada:** `.contextMenu` con **una sola opción**: "Desmarcar pagado". El resto no se lista — mismo criterio que el swipe, sin mensaje explicativo.

Accesible también por tap en "···" al final de la fila.

### macOS — swipe y contexto

- El `List` nativo de SwiftUI ya traduce `.swipeActions` a gestos de trackpad en macOS (deslizar con dos dedos sobre la fila) — mismas acciones, mismos iconos y tintes que iPhone, sin cambios de spec.
- Se añade además el menú contextual (clic derecho) descrito arriba, porque en Mac no todos los usuarios tienen trackpad (mouse) ni descubren el gesto — es la vía primaria de acceso a estas acciones para esos casos, el swipe es el acelerador.

### Accesibilidad obligatoria — el gesto no es descubrible

Ni el swipe leading ni el swipe trailing son detectables por VoiceOver o Switch Control solo con `.swipeActions` — es una decisión de la skill de Jonny, no opcional, exponer las mismas acciones como `accessibilityActions` explícitas en cada fila:

```swift
.accessibilityAction(named: line.isPaid ? Text("Desmarcar pagado") : Text("Marcar pagado")) {
    togglePaid(line)
}
// El resto de acciones solo se expone si la línea NO está pagada — refleja
// exactamente lo que el swipe/contextMenu ya no ofrecen cuando isPaid == true:
if !line.isPaid {
    .accessibilityAction(named: line.isActive ? Text("Desactivar") : Text("Activar")) {
        toggleActive(line)
    }
    .accessibilityAction(named: Text("Editar")) { presentEditSheet(line) }
    // Solo líneas .manual:
    .accessibilityAction(named: Text("Eliminar")) { requestDelete(line) }
}
```

- `accessibilityValue` de la fila concatena los dos estados cuando aplican, siempre en el mismo orden, nunca solo por color/icono: `"inactiva"` / `"pagada"` / `"inactiva, pagada"` / nada si la línea está activa y no pagada. Ejemplo completo de `accessibilityLabel` + `accessibilityValue`: "Renta, 1,900 dólares" + "inactiva, pagada".
- Con los iconos de origen fuera de la fila (ver "Origen de línea"), el origen se anuncia también por voz: el `accessibilityLabel` antepone el origen cuando no es `.manual` — ej. "Recurrente, Gimnasio, 45 dólares" / "Suscripción, Netflix, 15 dólares" / "Servicio, Luz, 82 dólares" / "Préstamo, pago Upstart uno, 629 dólares" / "Inversión, aportación GBM, 200 dólares" / "Traído de la quincena anterior, Latest Month, 1,240 dólares". Es el único lugar donde el origen sigue siendo perceptible sin entrar a editar la línea.
- Esto aplica igual en Mac (VoiceOver de macOS) y es lo que hace que Switch Control pueda operar la fila sin depender del gesto de swipe en absoluto — el menú contextual también sirve a este propósito para usuarios de mouse, pero las `accessibilityActions` son la vía que no depende de ningún gesto ni de un dispositivo señalador funcional.

### Sheet de captura/edición de línea

**Decisión del usuario, reemplaza el patrón anterior de fila inline.** Tocar el CTA `plus.circle.fill` (ver "Bloques INCOME / EXPENSES" arriba — vive solo, alineado a la izquierda, debajo de la última card de línea y antes de TOTAL; ya no existe la fila suelta "Agregar ingreso/gasto" ni el ícono en el header de sección) **ya no transforma nada in-place**: abre un **bottom sheet nativo** (`.sheet` + `.presentationDetents`), esquinas superiores redondeadas, grabber, fondo Frost oscuro con el resto de la pantalla atenuado detrás — mismo patrón estándar de iOS, adaptado al tema oscuro Fintrol en vez del blanco/claro de la referencia visual del usuario. **El mismo componente sirve para crear y para editar**: tocar una línea existente en Quincena abre este sheet precargado con sus valores, en vez del modo "edición inline" documentado antes (ver correcciones abajo).

**Layout del sheet** (de arriba a abajo):

```
━━━                                    ← grabber, .presentationDragIndicator(.visible)

Agregar ingreso / Agregar gasto /       ← .title3, semibold, centrado, padding top 8pt
Editar línea                              tras el grabber ("Editar línea" en modo edición)

Descripción                             ← LabTextField, ancho completo, foco inicial aquí
[________________________]

Monto                    [ USD ▾ ]      ← HStack: LabTextField numérico (.decimalPad) flexible
[________________]                        + selector de moneda USD/MXN compacto, ancho fijo

Escribe una descripción y un monto      ← .caption, .red — SOLO si el usuario intentó
mayor a 0                                 confirmar con datos inválidos; oculto en reposo

                                         ← Spacer — "espacio de sobra" pedido por el usuario,
                                           el sheet no se siente apretado como la fila inline

[     Cancelar     ] [     Listo      ] ← dos botones, ancho completo cada uno (ver Bug)
```

- **`presentationDetents`:** `[.medium, .large]`, default `.medium` — coincide con la referencia visual del usuario ("cubre la mitad inferior"), arrastrable a `.large` si Dynamic Type grande necesita más espacio vertical. No se usa una altura fija en puntos (`.height(...)`) porque el contenido debe poder crecer con Dynamic Type sin recortarse.
- **`presentationCornerRadius`:** 20pt, Continuous Corners (mismo radio que las cards grandes de la app).
- **`presentationDragIndicator`:** `.visible` — el grabber estándar de iOS.
- **Fondo — Frost, no Liquid Glass ni blanco:** `AppBackground.secondary` (`#000000`) con el material Frost del tema (blur 0.5, transparencia 0.5) vía `PatternConfig`, **no** `.regularMaterial`/`glassEffect()` del sistema — es la excepción ya señalada en "Componentes de navegación — Liquid Glass". El resto de la pantalla detrás del sheet se atenúa con el dimming estándar del sistema (`.presentationBackground` no reemplaza el scrim, solo el material del propio sheet).
- **Descripción:** `LabTextField`, ancho completo, `.textInputAutocapitalization(.sentences)`. Recibe el foco automáticamente al aparecer el sheet (`@FocusState`, sin necesidad de que el usuario toque el campo).
- **Monto + selector de moneda:** en la misma fila — `LabTextField` numérico (`.decimalPad`) que toma el espacio flexible, selector USD/MXN compacto (pill, ancho fijo ~70pt) a la derecha. Moneda por defecto USD en captura nueva; en edición, precarga la moneda real de la línea.
- **Texto de ayuda:** `.caption`, `.red`, aparece solo cuando el usuario intenta confirmar con descripción vacía o monto ≤ 0 — "Escribe una descripción y un monto mayor a 0". No se muestra en reposo antes del primer intento de confirmar (no se anticipa el error).
- **Botones de acción — bug corregido:** en la versión anterior "Cancelar" se truncaba a 3 líneas por falta de ancho. En el sheet nuevo, cada botón usa `.frame(maxWidth: .infinity)` — nunca un ancho fijo insuficiente. A tamaños de Dynamic Type estándar/grandes, los dos botones van lado a lado en un `HStack` con `spacing: 12`, cada uno ocupando 50% menos el gap; a tamaños de accesibilidad (`dynamicTypeSize >= .accessibility1`) se apilan verticalmente, cada uno a ancho completo — mismo patrón `ViewThatFits`/chequeo de `dynamicTypeSize` ya usado en otras partes de este documento para adaptar layout, nunca truncan en ningún tamaño.
  - "Cancelar": `.buttonStyle(.glass)`, descarta cambios, cierra el sheet.
  - "Listo": `.buttonStyle(.glassProminent)`, tinte accent, **deshabilitado** (`opacity` reducida + `disabled(true)`) mientras la descripción esté vacía o el monto sea ≤ 0; confirma, crea/actualiza la línea y cierra el sheet.
- **Teclado (iPhone):** toolbar con "Siguiente" entre Descripción → Monto → "Listo" en el teclado numérico confirma igual que tocar el botón "Listo" del sheet.
- **Haptic:** `.success` al confirmar (crear o guardar edición), `.error` si se intenta confirmar con datos inválidos (además del texto de ayuda — nunca solo un haptic sin texto).
- **Accesibilidad:** el sheet se anuncia a VoiceOver al aparecer (`accessibilityAddTraits(.isModal)` / el propio `.sheet` ya lo hace vía UIKit, pero se verifica explícitamente con Sarah en revisión); el foco inicial en "Descripción" es también el primer elemento que VoiceOver enfoca al abrir, sin que el usuario tenga que explorar el sheet para encontrar dónde empezar a escribir.

**Corrección de referencias previas en este documento:** el patrón "modo edición inline" (fila con fondo propio, campos editables in-place) descrito antes para tap-to-edit y para el botón "Editar" del menú contextual/swipe **queda reemplazado por este sheet** en todos los casos — ver "Fila de línea", "Swipe actions" y "Accesibilidad obligatoria" arriba, actualizados en consecuencia.

### Badge de sobrante

Componente custom, no está en el catálogo. Card standalone (r=24pt) debajo de los dos bloques, ancho completo:

```
[ SOBRANTE ]              ← .caption2, ALL CAPS, .secondary
$1,240.50                 ← .monospacedDigit(), bold, relativeTo: .largeTitle, tamaño 44pt
                             color = verde/amarillo/rojo según umbral
+ signo explícito antes del monto cuando es negativo: "−$320.00" en rojo
```

**Actualización del usuario (mockup exportado, no live file de Figma):** el fondo del badge de SOBRANTE pasa de tinte sutil a **color sólido** del estado (verde/amarillo/rojo). Mismo criterio para los tres estados del semáforo — no solo el verde. La card "Next Month" del panel de resumen (ver "Panel de resumen" abajo) recibe el mismo tratamiento: fondo sólido del color de su propio estado de semáforo (no siempre verde — depende del sobrante proyectado de esa quincena). ~~Fondo del badge: tinte muy sutil del color de estado (`.green.opacity(0.12)` / `.yellow.opacity(0.12)` / `.red.opacity(0.12)`)~~ — superado por la decisión anterior. Transición de color animada al recalcular (ver Animaciones).

**Corrección de valores exactos (lectura más reciente de Figma, frame `8:2`) — el texto NO es blanco/negro contrastante, es un par monocromático de verdes:**
- Fondo sólido (estado verde): `#006338` (verde oscuro, no el `#34C759`/success genérico del token de sistema).
- Texto sobre ese fondo: `#01F98E` (verde menta brillante) — **no blanco**, corregir la asunción anterior de "texto contrastante blanco o negro".
- Label: cambia de `ALL CAPS` (`.caption2`/12pt tracking +1.2) a **Title Case "Sobrante"**, 17pt Semibold — ya no es un `.caption` en mayúsculas. Falta confirmar con el usuario si esto aplica también al label de "Next Month" (que ya era Title Case) o si es exclusivo del badge de SOBRANTE.
- Pendiente de definir: los valores exactos de `#006338`/`#01F98E` para los estados amarillo/rojo del semáforo — solo se vio el estado verde en esta sesión de Figma.

### Panel de resumen (USD/Peso, Mandar, Next Month)

**Decisión cerrada del usuario (edición en Figma, frame `8:2`):** la card Resumen se simplifica — pierde la fila "Tipo de cambio"; ese control **vive solo en Ajustes → Preferencias** (ver "Tipo de cambio" en Ajustes más abajo), no se duplica aquí. "Mandar" deja de estar dentro de la card: sale como texto suelto sobre el fondo, entre SOBRANTE y la card Resumen.

- **iPhone:** "Mandar: $X USD" es una fila suelta sobre el fondo de la app (sin card propia, sin fondo, padding vertical ~6pt, `.body` 17pt — label `.secondary`, valor blanco), inmediatamente debajo del badge de sobrante. Debajo de esa fila, una card independiente (`LabNestedCard`, mismo ancho) contiene **solo** "Next Month: $Y". "Next Month" siempre muestra el mismo número que el usuario verá al avanzar con el chevron: si la siguiente quincena ya está materializada (con o sin ediciones manuales), es su sobrante real ya calculado; si no está materializada, es la proyección en memoria de `ProjectionEngine`. No hay distinción visual entre ambos casos — es un solo campo, un solo comportamiento. **Actualización del usuario (mockup exportado):** esta card deja de ser neutral (`#000000`, label `.secondary` / valor blanco Semibold) — pasa a llevar **fondo sólido del color de semáforo** correspondiente al sobrante proyectado de esa quincena (mismo criterio que el badge de SOBRANTE, ver "Badge de sobrante" arriba: fondo `#006338` / texto `#01F98E` en el estado verde, ambos textos del row en ese mismo verde menta, no solo el valor). Es la única card de esta pantalla que lleva color de estado además del badge de SOBRANTE mismo.
- **Mac:** dado que "en Mac la quincena cabe sin scroll y el resumen puede ir a un lado" (requisito del usuario), el panel vive en una tercera zona fija a la derecha del detail (no una columna `NavigationSplitView` adicional — un `HStack` dentro del detail: bloques INCOME/EXPENSES a la izquierda en `ScrollView` si excede alto de ventana, panel de resumen a la derecha en ancho fijo ~280pt, sin scroll propio). Ver "Consideraciones de plataforma".

### Listas (Ingresos recurrentes, Gastos recurrentes, Servicios, Suscripciones)

Las cuatro comparten el mismo patrón — `LabList` con `LabListRow` — pero cada una es una pantalla propia con su propio botón "+" en el toolbar, nunca una lista mixta con filtro:

- **Ingresos recurrentes / Gastos recurrentes:** subtitle muestra frecuencia + fecha fin si existe ("Cada quincena" / "Día 20 · hasta ago 2030"). `systemImage` fijo por pantalla (`arrow.down.circle` / `arrow.up.circle`), no varía por fila.
- **Servicios:** subtitle muestra día de pago + categoría de hogar ("Día 12 · Luz"). `systemImage` por categoría de hogar (Renta `house`, Luz `bolt.fill`, Internet `wifi`, Agua `drop.fill`, Gas `flame.fill`, Seguro `shield.fill`) — a diferencia de Suscripciones, aquí el icono sí varía por fila porque la categoría es la forma en que el usuario reconoce cada servicio de un vistazo.
- **Suscripciones:** subtitle muestra día de pago + categoría (Tools, Entertainment, Apartment, Work, Personal, Hobby, Investment, según TRD). `systemImage` por categoría existente del catálogo.
- Swipe actions: eliminar (con confirmación si el ítem tiene historial de líneas generadas) y editar.
- Alta: botón "+" en toolbar → sheet con `Form` nativo, específico de cada tipo (el formulario de Servicios no pregunta tarjeta de pago si no aplica al servicio; el de Recurrentes no pregunta día de pago sino frecuencia + fecha inicio/fin).

### Iconografía

- Sistema: SF Symbols, rendering mode **Hierarchical** (default) salvo los iconos de las filas de los hubs/listas (`arrow.down.circle`, `arrow.up.circle`, `house.fill`, `repeat`, `banknote`, `chart.line.uptrend.xyaxis`) que van en **Monochrome** `.secondary` — no deben competir visualmente con el semáforo del sobrante. Ninguno de estos aparece en la fila de Quincena (`LineItemRow`) — esa fila no lleva icono de origen, ver "Origen de línea".
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
| Abrir sheet de captura/edición de línea | Sistema (`.sheet` con `.presentationDetents`) | Sistema | Sistema | Sistema ya respeta RM | No custom — mismo criterio que el jump sheet |
| Navegar entre quincenas (chevron / swipe) | Contenido sale lateral + nuevo contenido entra lateral | `.easeOut` | 0.25s | Cross-fade simple, sin movimiento lateral | Transición direccional ligera, refuerza "estoy avanzando/retrocediendo" |
| Jump sheet abre/cierra | Sistema (`.sheet`/`.popover`) | Sistema | Sistema | Sistema ya respeta RM | No custom |
| Marcar/desmarcar pagado (swipe trailing) | Palomita aparece/desaparece con `.symbolEffect(.bounce)` | — | Sistema | Símbolo cambia sin bounce (`.contentTransition(.opacity)`) | Confirmación ligera, no bloqueante |
| Activar/desactivar línea (swipe leading) | Fila cruza a `opacity 0.4` + monto gana `.strikethrough()` | `.easeInOut` | 0.2s | Igual — es un cambio de opacidad/tachado, no espacial, se conserva completo | El cambio debe ser instantáneamente legible como "esto salió de la suma", sin narrativa |

No hay glows ni efectos de luz en Fintrol — el tono "serio pero con carácter" del STYLE_BRIEF se logra con el naranja puntual y el semáforo, no con efectos atmosféricos. Si en el futuro se agrega un momento de celebración (ej. terminar de pagar un préstamo), especificarlo entonces, no antes.

---

## Haptic feedback (iPhone)

| Acción | Haptic |
|---|---|
| Confirmar línea en captura rápida | `.sensoryFeedback(.success, trigger: didAddLine)` |
| Marcar/desmarcar pagado (swipe trailing, full swipe o tap en la acción) | `.sensoryFeedback(.impact(weight: .light))` |
| Activar/desactivar línea (swipe leading, full swipe o tap en la acción) | `.sensoryFeedback(.impact(weight: .medium))` — más peso que "pagado" porque cambia el cálculo del bloque, no es solo visual |
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
| Historial visible | `Stepper` con valor en el label: "Historial visible: 1 mes" (pluraliza a "meses" cuando > 1) | Rango 1–24, default 1. Debajo, texto de ayuda `.caption` `.secondary` fijo: "Cuánto puedes retroceder desde la quincena actual". Define cuántos meses atrás desde la quincena de hoy se puede navegar con el chevron izquierdo/jump sheet — ver "Navegación adyacente" arriba, que se actualiza con este límite |

**Nota de reconciliación con "Navegación adyacente":** el chevron izquierdo/jump sheet ya se deshabilitaban al llegar a la primera quincena materializada (no existe "antes" real en los datos). Este control añade un segundo límite, configurable por el usuario, que puede ser más restrictivo: el punto de corte efectivo es el que esté **más cerca de hoy** entre "primera quincena materializada" y "hoy − N meses" (N = este valor). Con el default de 1 mes, un usuario con años de historial materializado solo puede retroceder un mes salvo que suba el valor.

### Grupo "Seguridad"

| Fila | Control | Comportamiento |
|---|---|---|
| Bloquear con Face ID / Touch ID | `LabToggleRow` | Apagado por defecto. Al activarlo, dispara autenticación de prueba (LAContext) — si falla o no hay biometría configurada, el switch vuelve a apagado + texto inline (`.caption`, `.red`) explicando por qué. Nunca queda "on" sin biometría real funcionando |
| Tiempo de re-bloqueo | `Picker` `.pickerStyle(.menu)`, opciones "Inmediato" / "1 minuto" / "5 minutos" | Default "1 minuto" (60s, ya fijado en el PRD). Fila solo visible/habilitada cuando el bloqueo está activo — con el switch apagado aparece deshabilitada (`.opacity(0.4)`, sin interacción), no oculta, para que el usuario entienda que depende del toggle de arriba |
| Ocultar montos en el app switcher | Texto informativo, sin control | Siempre activo, no configurable — fila puramente informativa (`.caption`, `.secondary`) que explica que esta protección corre siempre, independiente del switch de Face ID, usando el snapshot/privacy overlay del sistema (mitigación ya fijada en el PRD) |

### Pie de pantalla

Fuera de ambos `Section`, como `Section` final sin header: "Fintrol — versión 1.0 (build X)", `.caption`, `.secondary`, centrado.

### Import/export — no usa el patrón de captura corta (revisado)

`SettingsView.swift` ya implementa "Importar suscripciones y servicios…", "Exportar respaldo completo (JSON)" e "Importar respaldo completo…" con `.fileImporter`/`.fileExporter`/`.alert`/`.confirmationDialog` nativos — flujos de selección de archivo del sistema, no el campo corto de texto+monto que motivó el cambio a sheet. El bug de "Cancelar" truncado y el rediseño a bottom sheet **no aplican aquí**; no requieren cambio.

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

Feature v1 nueva. Modela lo que hoy son "recurrentes especiales con fecha fin" en el PRD (Upstart #1, Upstart #2, "Ada") pero con datos propios de amortización — saldo restante, interés, plazo — que un `RecurringItem` genérico no captura. Vive en el hub "Recurrentes y pagos" (fila 5) y como ítem directo en el sidebar de Mac. **Actualización:** "tarjetas de crédito" ya no está fuera de v1 — se promovió desde Fase 2 del PRD (ver "Tarjetas de crédito (Credit Cards)" más abajo) — pero Préstamos y Credit Cards siguen siendo modelos y pantallas distintos, no se fusionan: un préstamo tiene plazo fijo y amortización determinística (o "Hasta liquidar" con pago esperado pero aun así una sola dirección de deuda conocida), una tarjeta tiene saldo revolvente sin plazo y su propio motor de interés mensual (`CreditCardEngine`, ver TRD).

Dos modos conviven en la misma entidad `Loan`: **Plazo fijo** (Upstart — monto, APR, plazo/fecha fin conocidos, pago fijo calculado) y **Hasta liquidar** (caso "Ada" — $824 al 26.2%, la hermana del usuario paga montos variables ~$200 por quincena, sin plazo definido de antemano; se liquida cuando el saldo llega a $0, lo que dependerá de cuánto pague realmente cada quincena). El modo es un switch en el formulario, no una entidad distinta — ambos comparten lista, detalle y origen de línea en Quincena.

### 0. "Hasta liquidar" — diferencias sobre el modo Plazo fijo

En vez de plazo/fecha fin conocidos, el préstamo define un **"Pago esperado"** por periodo y proyecta cuándo se liquidaría *si* los pagos reales coinciden con ese esperado — una estimación que se ajusta sola cada vez que el pago real de una quincena difiere del esperado (exactamente como el saldo restante ya se recalcula con cada pago real en el modo Plazo fijo, solo que aquí también recalcula la fecha de fin estimada, no solo el saldo).

### 1. Lista de préstamos

**Cambio estructural del usuario (lectura de Figma, frame "03 · Prestamos lista" `5:67`, no escrito por mí — solo lectura, comparado contra `LoansView.swift` que hoy es lista plana con chip por card):** la lista deja de ser plana con un chip de dirección por card — ahora se **agrupa en dos secciones con encabezado**, una por dirección, y el chip de dirección desaparece de la card (el agrupamiento por sección lo reemplaza). El chip "Pagado" de LIQUIDADOS **sí se mantiene** por card en esa tercera sección.

```
ME DEBEN                                        ← encabezado de sección, .caption Bold, tracking +0.6, .secondary 60%
┌──────────────────────────────────────────┐
│ Ada                                       │  ← nombre, .body Semibold 17pt blanco (ya no lleva chip de dirección)
│ Ultimo Pago   $200.00 · Sep 15, 2026      │  ← nueva línea: Regular 14pt, .secondary (#C7C7CC)
│ Próximo pago  $400.00 · Oct 15, 2026      │  ← nueva línea: label Regular / valor Semibold, 14pt, blanco
│                                            │
│ Restante      $4,320.00                   │  ← label Regular .secondary / valor Semibold blanco, 14pt
│ [████████░░░░░░░░░░░░░░░░░░░]             │  ← barra de progreso
└──────────────────────────────────────────┘

DEBO                                            ← misma estructura, sección separada, sin chip por card
┌──────────────────────────────────────────┐
│ Debo · Restante · Último/Próximo pago ...  │
└──────────────────────────────────────────┘

LIQUIDADOS                                      ← sin cambio: chip "Pagado" se mantiene por card
┌──────────────────────────────────────────┐
│ Laptop — Ada                    [Pagado]  │
│ Restante      $0.00                        │
│ Liquidado     —                            │
└──────────────────────────────────────────┘
```

- **Agrupamiento por sección reemplaza al chip de dirección:** ya no hay chip "Debo"/"Me deben" dentro de la card de un préstamo activo — la sección "ME DEBEN" agrupa los que antes llevaban chip azul, la sección "DEBO" los que llevaban chip naranja. El nombre del préstamo ya no comparte fila con ningún chip.
- **Dos líneas de pago en vez de una:** "Último Pago $X · fecha" (Regular, `.secondary`) y "Próximo pago $Y · fecha" (label Regular / valor Semibold, blanco) — antes solo existía "Próximo pago". Gap vertical entre ambas líneas: 8pt.
- **"Restante $Z" y la barra de progreso se mantienen sin cambio de comportamiento** — solo bajó su tamaño tipográfico (ver medidas exactas abajo).
- **El chip "Pagado" de la sección LIQUIDADOS no cambia**: sigue por card, ahí sí se mantiene (a diferencia de ME DEBEN/DEBO, que ya no llevan chip).
- **Préstamo en modo "Hasta liquidar"** — sigue documentado como antes: badge "Sin plazo" + estimado en vez de fecha fin; el progreso se calcula igual. Pendiente confirmar cómo se integra visualmente con las dos líneas nuevas de Último/Próximo pago (no visible en esta captura).
- Tap/click → push a Detalle. Swipe/botón "+" en toolbar → Formulario de alta.

#### Medidas y colores exactos (lectura de Figma `5:67`, para Woz — los 3 tipos de card)

| Elemento | Card activa (ME DEBEN / DEBO) | Card LIQUIDADOS |
|---|---|---|
| Fondo de card | `#3C3C3C` | `#3C3C3C` (igual) |
| Radio de card | 18pt | 18pt |
| Padding interno | 16pt | 16pt |
| Gap interno entre bloques | 18pt (nombre → líneas de pago → restante → barra) | 8pt (nombre+chip → restante → liquidado) |
| Nombre | `.body` Semibold, 17pt, blanco | `.body` Semibold, 17pt, blanco |
| Chip de dirección | **ninguno** (removido) | — |
| Chip "Pagado" | — | borde blanco 1pt, sin relleno, radio 999pt (pill), texto 8pt Regular blanco, padding 10pt horizontal / 6pt vertical |
| "Ultimo Pago" / "Próximo pago" / "Restante" / "Liquidado" — label | 14pt Regular, `#C7C7CC` | 14pt Regular, `#C7C7CC` |
| "Próximo pago" / "Restante" — valor | 14pt Semibold, blanco | 14pt Semibold, blanco |
| "Ultimo Pago" — valor | 14pt Regular, `#C7C7CC` (mismo peso que el label, a diferencia de "Próximo pago" que sí resalta en Semibold) | — |
| Barra de progreso — track | `#023C2F` (verde muy oscuro), radio 5pt, alto 4pt | — |
| Barra de progreso — fill | `#00FFC5` (verde menta brillante/neón) | — |
| Encabezado de sección ("ME DEBEN"/"DEBO") | 13pt Bold, `rgba(235,235,245,0.6)`, tracking +0.6pt, padding 10pt | "LIQUIDADOS": 12pt Bold, tracking +1pt (ligeramente distinto del resto — verificar si es intencional o inconsistencia) |
| Gap entre secciones | ~24–26pt (sección → título → card) | igual |

**Pregunta abierta para el usuario (no resuelta a criterio propio):** el track/fill de la barra de progreso ya no usa el tinte naranja/azul de dirección documentado antes ("color = tinte de la dirección del préstamo") — ahora ambas secciones (ME DEBEN y DEBO) muestran la misma barra verde (`#023C2F`/`#00FFC5`) en la captura leída. ¿Es intencional que el progreso ya no distinga visualmente dirección (porque la sección ya lo hace), o falta aplicar el tinte naranja a la sección "DEBO"?

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
| **Hasta liquidar** | `LabToggleRow`, debajo de Frecuencia | Apagado por defecto (modo Plazo fijo). Al activarlo, oculta "Plazo (meses)" y "Fecha fin" (con animación de colapso — ver "Motion fallback"/Animaciones) y revela el campo "Pago esperado" descrito abajo |
| *(modo Plazo fijo, oculto si "Hasta liquidar" está activo)* Plazo en meses ↔ Fecha de fin | Dos campos enlazados en la misma fila: `Stepper`/`LabTextField` de "Plazo (meses)" + `DatePicker` de "Fecha fin" | Editar uno recalcula el otro en vivo a partir de fecha de inicio + frecuencia (ej. 48 meses desde ago 2026 → fecha fin jul 2030; mover la fecha fin recalcula el plazo en meses). Un solo campo es la fuente de verdad en cada edición — el que el usuario tocó último — nunca hay estado inconsistente entre ambos |
| *(modo Plazo fijo)* Pago calculado | Texto informativo (`.body`, `.monospacedDigit()`, `.secondary`) bajo el bloque de plazo: "Pago calculado: $629.00/mes" — fórmula de amortización estándar (monto, APR, plazo) | Recalcula en vivo al cambiar monto/APR/plazo/frecuencia |
| *(modo Plazo fijo)* Override del pago | Botón de texto "Sobreescribir monto de pago" bajo el pago calculado | Al activarlo, el pago calculado se vuelve editable (`LabTextField`); al escribir un valor distinto, aparece debajo un texto informativo `.caption` `.secondary`: "Con este pago, el préstamo se liquida en 52 meses (ago 2030 → dic 2030)" — recalculando el plazo real a partir del pago fijo, en vez de al revés. Volver al cálculo automático restaura el plazo original |
| *(modo Hasta liquidar)* Pago esperado | `LabTextField` numérico + toggle USD/MXN junto al campo (mismo patrón que Monto original) | Reemplaza a "Plazo/Fecha fin/Pago calculado" — es el único monto que el usuario define en este modo. Debajo, nota fija `.caption` `.secondary`: "Puedes cambiar el pago real en cada quincena" — deja claro que este número es solo la expectativa, no un compromiso fijo, y que la línea generada en Quincena sigue siendo editable línea por línea como cualquier otra |
| *(modo Hasta liquidar)* Aviso de pago insuficiente | Texto inline `.caption`, tinte `.orange` (semántica de advertencia, no el semáforo del sobrante), aparece debajo de "Pago esperado" solo si aplica | Se calcula en vivo: interés mensual = saldo actual × APR/12; si Pago esperado < interés mensual, el saldo nunca bajaría a ese ritmo — texto: "Con este pago, el saldo no bajaría — el interés mensual es de $18.00" |
| Activo | `LabToggleRow` | Un préstamo inactivo deja de generar línea en quincenas futuras no materializadas, pero conserva su historial y su Detalle es accesible desde la sección "Liquidados" de la lista |

### 3. Detalle — cabecera + tabla de amortización

**Cabecera, modo Plazo fijo** (card `LabNestedCard`, mismo patrón visual que el badge de sobrante pero sin semáforo — un préstamo no tiene "bueno/malo", tiene estado factual):

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

**Cabecera, modo Hasta liquidar** — mismas cuatro filas de metadata, dos cambian de nombre/naturaleza para reflejar que son estimaciones, no hechos fijos:

```
Saldo actual                          ← .caption2, ALL CAPS, .secondary
$824.00                               ← igual tratamiento tipográfico que arriba

Interés acumulado a la fecha: $46.10  ← .subheadline, .secondary — "acumulado" en vez de "total",
                                         porque sigue creciendo mientras no se liquide
Próximo pago esperado: $200.00 · —    ← .subheadline, .secondary — sin fecha fija si la
                                         frecuencia no la determina (ver Formulario)
Fin estimado: mar 2029                ← .subheadline, .secondary — "estimado" explícito en el
                                         label, nunca "Fecha de fin" a secas, para no leer
                                         como un compromiso
```

**Tabla de amortización** — periodo a periodo (fecha, pago, interés, capital, saldo):

- **iPhone:** `List` de filas custom (no `Table`, no soportado en compacto) — cada fila en `.monospacedDigit()`: fecha `.leading`, pago/interés/capital/saldo en `.trailing` apilados en dos líneas por espacio (fecha+pago en línea 1, interés/capital/saldo en línea 2 más pequeña `.caption`).
- **Mac:** `Table` nativo con columnas Fecha / Pago / Interés / Capital / Saldo, todas `.monospacedDigit()`, `.trailing` salvo Fecha. Ordenable por columna no es necesario (el orden cronológico es el único que tiene sentido) — se deshabilita el sort de header. Igual en ambos modos — la diferencia entre modos vive en el contenido de las filas, no en el tipo de control.
- **Fila ya pagada, pago real** (existe un `LineItem` materializado/editado en Quincena para ese periodo): `.secondary` en todo el texto, sin énfasis — es historial confirmado.
- **Fila actual** (el próximo pago pendiente): fondo resaltado sutil (`accentSubtle` al 50% adicional de opacidad), texto `.primary`, único punto de la tabla con color de acento — es la única fila que representa una decisión próxima del usuario.
- **Filas futuras proyectadas** (después de la actual, sin `LineItem` materializado todavía — todo el modo Plazo fijo más allá de "actual", y prácticamente toda la tabla en modo Hasta liquidar salvo pagos ya reales): `.secondary`, **más** una etiqueta `.caption2` "Proyectado" al final de la fila (Mac: columna adicional "Estado"; iPhone: texto inline después del saldo) — no basta con la opacidad reducida que ya comparten con las pagadas, porque en modo Hasta liquidar la diferencia entre "esto ya pasó" y "esto es una proyección que puede cambiar con el siguiente pago real" es información que el usuario necesita poder leer sin ambigüedad, así que se refuerza con texto, no solo opacidad.
- **Interés cargado por mes**: cada fila de la columna "Interés" en modo Hasta liquidar se recalcula sobre el saldo real vigente al momento de ese periodo (saldo × APR/12), por lo que las filas proyectadas después de un pago real distinto al esperado muestran un interés distinto al que tenían antes de ese pago — es visible en la tabla como números que cambian, no oculto; no hace falta un indicador adicional, el propio recálculo es la comunicación.

### Accesibilidad

- Cada fila de la lista de préstamos expone un solo `accessibilityElement(children: .combine)` cuyo `accessibilityLabel` concatena dirección + nombre + saldo en una frase, no solo el nombre — ej. "Debo, Upstart uno, saldo restante 18,420 dólares" — para que VoiceOver comunique la dirección y el saldo sin que el usuario tenga que navegar campo por campo dentro de la fila.
- El chip de dirección nunca depende solo del color naranja/azul — el texto "Debo"/"Me deben" es parte del `accessibilityLabel` y está siempre visible tipográficamente, no oculto en un tooltip.
- La barra de progreso expone `accessibilityValue` con el porcentaje en texto ("34 por ciento pagado"), no solo el `value` numérico del `ProgressView`.
- El badge "Sin plazo" y su estimado ("termina aprox. mar 2029") se incluyen en el `accessibilityLabel` combinado de la fila — ej. "Me deben, Ada, saldo actual 824 dólares, sin plazo, termina aprox. marzo 2029" — nunca queda como un badge visual sin equivalente leído.
- En la tabla de amortización, la etiqueta "Proyectado" se lee explícitamente en VoiceOver (`accessibilityLabel` de la fila incluye la palabra, no solo la opacidad reducida) — es información funcional, no decorativa, tanto en `List` (iPhone) como en `Table` (Mac, vía `accessibilityLabel` de la fila del `TableRow`).

### Estado vacío

`LabEmptyState(systemImage: "banknote", title: "Sin préstamos todavía", subtitle: "Registra un préstamo para ver su saldo y calendario de pagos automáticamente")` con CTA — mismo patrón que las otras cuatro listas del hub.

### Origen de línea en Quincena — regla de edición manual

Igual que Recurrentes/Suscripciones/Servicios: la línea que un préstamo genera en una quincena nace con `origin: .loan`, `isManuallyEdited: false`; si el usuario la edita a mano, el modelo marca `isManuallyEdited = true` y esa quincena específica queda protegida de la regeneración automática si el préstamo se edita después — misma regla "la edición manual gana" del TRD, sin caso especial para préstamos. Sin icono de origen en la fila (decisión del usuario, ver "Origen de línea"), el origen `.loan` se lee igual que cualquier otro en reposo — solo se distingue en accesibilidad y en el contexto de edición ("Generado por: Upstart #1"). Esto aplica idéntico en ambos modos: la línea generada por un préstamo "Hasta liquidar" se ve exactamente igual que la de un préstamo a plazo fijo — el modo es una diferencia de cómo se calcula la proyección, no de cómo se presenta la línea ya materializada en Quincena. Es precisamente porque el usuario puede sobreescribir el pago real de cualquier quincena (nota del Formulario: "Puedes cambiar el pago real en cada quincena") que el modo Hasta liquidar no necesita tratamiento especial aquí — cada pago real es, de nuevo, solo una línea editada a mano como cualquier otra.

### Motion — colapso de campos en el Formulario

| Evento | Estado inicial → final | Curva | Duración | Reduce Motion |
|---|---|---|---|---|
| Activar/desactivar "Hasta liquidar" | "Plazo/Fecha fin/Pago calculado" colapsan (`opacity 1→0` + `height→0`) mientras "Pago esperado" aparece (`opacity 0→1`) | `.easeInOut` | 0.25s | Sin colapso animado — los campos cambian instantáneamente, es un `Form` de configuración, no necesita narrativa |

---

## Tarjetas de crédito (Credit Cards)

Feature v1 nueva, promovida desde Fase 2 del PRD (plan `glimmering-swinging-bumblebee.md`). Modela deuda revolvente — sin plazo fijo, interés mensual sobre saldo, pago mínimo sugerido con fórmula estándar de emisores. Vive en el hub "Recurrentes y pagos", sección "EXPENSES" (fila 6, icono `creditcard.fill`) y como ítem directo en el sidebar de Mac. Reutiliza el motor de `Loan.revolving`/`LoanEngine` a nivel de datos (ver TRD) pero es un modelo y una pantalla distintos — una tarjeta nunca es "Me deben" (siempre `.expense`), un préstamo sí puede serlo.

**Pieza de diseño específica de esta feature — la fila agregada:** cada tarjeta genera su propia `LineItem` real (como un préstamo), pero en Quincena las líneas `origin == .creditCard` de una misma quincena se muestran como **una sola fila colapsada** "Credit Cards Payments" (suma de montos) en vez de una fila por tarjeta — a diferencia de Préstamos e Inversiones, que sí muestran una fila por ítem. Es la única fila de Quincena que representa más de una línea de datos.

### 1. Formulario "Nueva tarjeta"

`Form` nativo, mismo patrón que Préstamos:

| Campo | Control | Comportamiento |
|---|---|---|
| Nombre | `LabTextField` | Texto libre |
| Saldo actual | `LabTextField` numérico, `.decimalPad` | Sin selector de moneda — asumido USD como el resto de deuda financiera de la app (el PRD no pide MXN para tarjetas; si se necesita, es una extensión, no v1) |
| APR (%) | `LabTextField` numérico, `.decimalPad`, sufijo "%" | Mismo patrón que Préstamos |
| Límite de crédito | `LabTextField` numérico, `.decimalPad` | Nuevo campo, no existe en Préstamos — es la base del % de utilización en el Detalle |
| Día de corte | `Stepper` 1–31 o `LabTextField` numérico acotado | "Cutoff day" — fecha en que el emisor congela el saldo del período |
| Día de pago | `Stepper` 1–31 o `LabTextField` numérico acotado | "Due date" — fecha límite legal de pago sin intereses (grace period) |
| Pago esperado (opcional) | `LabTextField` numérico, `.decimalPad`, **placeholder dinámico** | Vacío por defecto. El placeholder muestra en vivo el mínimo sugerido calculado — `MAX($25, saldo × 1% + interés del mes)` — como texto gris de ejemplo (`.placeholder`, no un valor real hasta que el usuario escribe algo). Si el usuario nunca lo fija, cada quincena usa el mínimo sugerido recalculado ese período, igual patrón que "Pago esperado" de Préstamos "Hasta liquidar" pero aquí el cálculo es automático en vez de un número fijo que el usuario decide una vez |
| Activa | `LabToggleRow` | Mismo patrón que el resto del hub |

**Nota de fórmula (para que Woz y Larry no la reinventen):** `suggestedMinimumPayment = max($25, balance × 0.01 + interésDelMes)`, donde `interésDelMes = balance × APR / 12` — fórmula típica de emisores grandes (Chase), investigada y citada en el plan de Avie.

### 2. Fila "Credit Cards Payments" — Hub y Quincena

**En el hub:** fila estándar del catálogo, igual tratamiento que las otras seis (`LabListRow`, chevron, subtitle con conteo de tarjetas activas), `systemImage: "creditcard.fill"`. Tap/click → push a la lista de tarjetas (una fila por tarjeta, no agregada — la agregación solo ocurre en Quincena).

**En Quincena (EXPENSES), solo si hay ≥1 tarjeta con pago en ese período:**

```
[ ]  Credit Cards Payments          $958.00     ← misma card-por-línea que cualquier
                                                    otra fila de EXPENSES: fondo Frost,
                                                    radio 20pt, .body 17pt, monto .trailing
```

- Visualmente **idéntica** a cualquier card de línea (mismo fondo Frost, radio, tipografía, `.monospacedDigit()`) — no se inventa un tratamiento especial para no romper el ritmo visual de la lista.
- **Sin swipe ni menú contextual de pagado/editar/eliminar/activar-desactivar.** Es una fila de navegación, no una línea editable — tocarla (tap/click, toda la fila) abre el "Sheet de detalle — Credit Cards Payments" descrito abajo. No hay palomita de pagado en esta fila (el estado pagado vive por tarjeta, dentro del sheet) ni icono de origen (consistente con "Origen de línea" — ninguna fila de Quincena lleva icono).
- Si ninguna tarjeta tiene pago en esa quincena, la fila simplemente no aparece — no hay un estado "Credit Cards Payments: $0.00" vacío ocupando espacio.

### 3. Sheet de detalle — "Credit Cards Payments"

Mismo patrón de presentación que el "Sheet de captura/edición de línea" (`.presentationDetents([.medium, .large])`, fondo Frost, grabber, radio 20pt) — se abre al tocar la fila agregada:

```
━━━
Credit Cards Payments              ← .title3, semibold, centrado

Chase Sapphire                     ← nombre, .body, semibold
Sugerido: $58.00 · A pagar: [___]  ← monto sugerido de solo lectura junto al campo editable
Saldo restante tras el pago: $1,942.00
Corte: 15 · Pago: 5 del próximo mes

Amex Gold
Sugerido: $312.00 · A pagar: [___]
...
```

- **Cada fila de tarjeta dentro del sheet SÍ es una `LineItemRow` completa** (no la versión de solo navegación de la fila agregada) — reutiliza el patrón ya documentado: monto editable, palomita de pagado, y el **bloqueo al marcar pagado ya especificado para `LineItemRow`** (fondo verde tenue `Color.green.opacity(0.16)`, solo queda disponible "Desmarcar pagado", sin swipe de eliminar/editar mientras está pagada — ver "Fila de línea" arriba, mismo token, mismo comportamiento, cero reinvención).
- Monto sugerido vs. a pagar: el sugerido se muestra como referencia (`.caption`, `.secondary`) junto al campo editable — igual que "Pago esperado" en el Formulario, el usuario puede pagar más, menos, o exactamente el sugerido.
- "Saldo restante tras el pago" se recalcula en vivo mientras el usuario edita el monto a pagar de esa tarjeta — feedback inmediato de qué tanto baja la deuda con ese pago específico.
- Fecha de corte/pago de esa tarjeta: texto informativo `.caption`, `.secondary`, no editable desde aquí (se edita en el Detalle de tarjeta o el Formulario).
- Total del sheet (suma de "a pagar" de todas las tarjetas) se muestra al pie, y es ese número el que retroalimenta el monto de la fila agregada "Credit Cards Payments" en Quincena al cerrar el sheet.

### 4. Detalle de tarjeta individual (push)

Mismo patrón que `LoanDetailView` (cabecera + tabla real-vs-proyectado), con un campo nuevo — % de utilización:

```
Saldo actual
$1,942.00

Límite de crédito: $5,000.00
Utilización: 38.8%                 ← saldo ÷ límite, .monospacedDigit(), color de estado
                                       (ver regla de color abajo — no es semáforo del sobrante)
Interés acumulado a la fecha: $186.40
Próximo pago: $58.00 · 5 oct
```

- **Color de "Utilización":** no reutiliza el semáforo verde/amarillo/rojo del sobrante (reglas distintas, umbrales distintos, confundiría el significado). Usa su propia escala de dos estados con umbral único, apoyada en texto no solo color: `.secondary` (texto normal) si utilización < 30% (buena práctica de crédito estándar, citada en la investigación del plan); `.orange` + un texto de apoyo breve "Alta utilización" en `.caption` si ≥ 30% — un solo umbral, no un semáforo de tres colores, para no competir visualmente con el del sobrante.
- **Tabla real-vs-proyectado:** idéntica en estructura y reglas a la de Préstamos "Hasta liquidar" (`List` en iPhone, `Table` en Mac, fila actual resaltada, filas proyectadas con etiqueta "Proyectado" explícita, no solo opacidad) — una tarjeta revolvente sin plazo fijo es, en términos de UI, el mismo patrón que un préstamo "Hasta liquidar"; ver esa sección para la spec completa en vez de repetirla aquí.

### Ajustes → Preferencias — regla de fecha de pago

Nueva fila, junto a las demás de Preferencias (moneda, tipo de cambio, apariencia, Historial visible):

| Fila | Control | Comportamiento |
|---|---|---|
| Regla de pago de tarjetas | `NavigationLink` a subpantalla "Payment Date Rule" | Preferencia **global** (aplica a todas las tarjetas), 3 opciones en `Picker` `.pickerStyle(.inline)` (no `.menu` — cada opción necesita espacio para su explicación, no cabe en un menú compacto) |

Las 3 opciones, cada una con su explicación corta **en inglés** (decisión explícita del usuario, texto exacto para Woz):

```
○ On the payment date
  Only avoids interest. Simplest option, no credit score benefit.

○ On the statement/cutoff date
  Almost as good as paying early, with no buffer if something goes wrong.

● N days before the cutoff date                    ← default, N = 5
  Reduces the balance your card issuer reports to the credit
  bureau — often the best practice for your credit score.
  [Stepper: 5 días] — visible solo cuando esta opción está seleccionada
```

- Default: "N days before the cutoff date", N = 5 — coincide con la regla informal "15/3" investigada en el plan (pagar unos días antes del corte).
- El `Stepper` de N (rango razonable 1–15, no se especifica límite superior estricto en el plan — Woz puede acotar a 1–15 sin pedir confirmación, es un detalle de implementación menor) solo aparece cuando esa opción está seleccionada, mismo patrón de campo condicional que "Tiempo de re-bloqueo" en Seguridad.
- Por qué inglés: decisión explícita del usuario, no es inconsistencia — el resto de la UI de Fintrol es español, esta es la única excepción de idioma en toda la app, documentarla como tal si Larry la señala en revisión.

### Origen de línea en Quincena — regla de edición manual

Cada `LineItem` individual generada por una tarjeta nace con `origin: .creditCard`, `isManuallyEdited: false` — igual regla que el resto del hub. La fila agregada de Quincena no tiene su propio `isManuallyEdited` (es una vista, no un dato); la edición ocurre por tarjeta dentro del sheet, y ahí sí aplica "la edición manual gana" sobre la línea individual de esa tarjeta.

### Accesibilidad

- Fila agregada de Quincena: `accessibilityLabel` = "Pagos de tarjetas de crédito, 958 dólares" + `accessibilityHint` = "Toca dos veces para ver el desglose por tarjeta" — comunica que es navegación, no una línea editable, ya que no tiene las `accessibilityActions` de swipe que sí llevan las demás filas.
- Filas del sheet de detalle: mismas `accessibilityActions`/`accessibilityValue` ya especificadas para `LineItemRow` ("pagada", bloqueo al pagar) — sin reinventar.
- "Utilización" en el Detalle de tarjeta: el `accessibilityLabel` incluye el porcentaje y, si aplica, el texto "alta utilización" — nunca solo el color naranja.

### Estado vacío

`LabEmptyState(systemImage: "creditcard.fill", title: "Sin tarjetas todavía", subtitle: "Agrega una tarjeta para calcular sus pagos automáticamente")` con CTA — mismo patrón que el resto del hub.

---

## Inversiones (Investments)

Feature v1 nueva. Registra **aportaciones periódicas** a cuentas de inversión (GBM, Webull, crypto…) — es, en efecto, un recurrente con cuenta destino, no un portafolio. Vive en el hub "Recurrentes y pagos" (fila 6) y como ítem directo en el sidebar de Mac. **Fuera de alcance explícito en v1:** rendimientos, valor actual del portafolio, precios de mercado — el PRD ya excluye "control de inversiones" (dominio de portafolios/rendimientos) para Fase 3; esta feature es deliberadamente más chica que eso, limitada al registro de cuánto se aporta y cuándo. El hueco queda anotado en "Sin definir aún".

### 1. Lista de cuentas de inversión

Total general arriba, `LabNestedCard` simple, fuera de la lista:

```
Total aportado a la fecha
$14,200.00                    ← .monospacedDigit(), bold, mismo tratamiento que cabeceras de
                                 Préstamos, sin color de dirección (no aplica aquí) — .primary
```

Debajo, `LabList` con una fila por cuenta (`LabListRow` estándar sí alcanza aquí — no hay dirección ni progreso que mostrar, más simple que Préstamos):

```
[chart.line.uptrend.xyaxis] GBM
Aportación: $200.00 · Cada quincena
Aportado a la fecha: $8,400.00
```

- `systemImage` fijo `chart.line.uptrend.xyaxis` en todas las filas (no varía por cuenta — a diferencia de Servicios, aquí no hay categorías de hogar que distinguir, todas las cuentas son la misma clase de cosa).
- Subtitle: aportación + frecuencia en una línea, "Aportado a la fecha" en una segunda línea `.secondary`.
- Tap/click → push a Detalle. Botón "+" en toolbar → Formulario de alta.

### 2. Formulario crear/editar

`Form` nativo, mismo patrón que el resto del hub:

| Campo | Control | Comportamiento |
|---|---|---|
| Cuenta destino | `LabTextField` | Texto libre — "GBM", "Webull", "Crypto (Coinbase)"; no es un picker de opciones fijas porque el usuario define sus propias cuentas |
| Monto | `LabTextField` numérico + toggle USD/MXN junto al campo | Mismo patrón que captura de línea en Quincena |
| Frecuencia | `Picker` `.pickerStyle(.menu)`: "Cada quincena" / "Mensual, día X" | Si "Mensual, día X": `Stepper` adicional 1–31 para el día |
| Fecha de inicio | `DatePicker` `.compact` | |
| Fecha de fin (opcional) | `LabToggleRow` "Tiene fecha de fin" + `DatePicker` condicional | Igual patrón que `RecurringItem` del TRD — sin fecha de fin, la aportación proyecta indefinidamente |
| Activa | `LabToggleRow` | Una cuenta inactiva deja de generar línea en quincenas futuras no materializadas, conserva su historial |

No hay campo de "rendimiento esperado" ni "valor actual" — es la ausencia deliberada que marca el alcance de v1.

### 3. Detalle — simple, sin portafolio

Cabecera (`LabNestedCard`, mismo tratamiento tipográfico que las demás cabeceras del hub, sin color de dirección):

```
Aportado a la fecha
$8,400.00

Próxima aportación: $200.00 · 4 oct
```

**Historial de aportaciones** — lista simple, no tabla de amortización (no hay saldo/interés que calcular, cada aportación es independiente):

- **iPhone:** `List` de filas: fecha `.leading`, monto `.trailing`, `.monospacedDigit()`.
- **Mac:** `Table` con columnas Fecha / Monto — mismo patrón de consistencia que Préstamos, aunque aquí solo dos columnas.
- **Aportación real** (existe `LineItem` materializado/editado en Quincena): `.secondary`, sin etiqueta — es historial confirmado, igual convención que Préstamos.
- **Aportación proyectada** (sin `LineItem` materializado todavía): `.secondary` + etiqueta `.caption2` "Proyectado", misma razón que en Préstamos — no depender solo de opacidad para comunicar la diferencia.

### Accesibilidad

- Cada fila de la lista de cuentas expone `accessibilityElement(children: .combine)` con `accessibilityLabel` que concatena cuenta + aportado a la fecha — ej. "GBM, aportado a la fecha 8,400 dólares".
- Filas del historial marcadas "Proyectado" lo incluyen en el `accessibilityLabel`, igual que en Préstamos.

### Estado vacío

`LabEmptyState(systemImage: "chart.line.uptrend.xyaxis", title: "Sin inversiones todavía", subtitle: "Agrega una cuenta para registrar tus aportaciones periódicas")` con CTA.

### Origen de línea en Quincena — regla de edición manual

Igual que el resto del hub: la línea que una cuenta de inversión genera nace con `origin: .investment`, `isManuallyEdited: false`; editarla a mano marca `isManuallyEdited = true` y protege esa quincena de la regeneración — misma regla "la edición manual gana" del TRD, sin caso especial. Sin icono de origen en la fila (ver "Origen de línea") — se distingue solo en accesibilidad y en el contexto de edición.

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

### Inversiones

| Estado | Diseño |
|---|---|
| Vacío (lista de cuentas) | Estado vacío ya especificado en "Inversiones (Investments)" |
| Loading | `.redacted(.placeholder)` sobre `LabList`/historial |
| Error | No aplica (datos 100% locales, sin red) |

### Overview

| Estado | Diseño |
|---|---|
| Vacío (sin ninguna quincena materializada) | `LabEmptyState` invitando a capturar la primera quincena |
| Normal | Tabla mensual (dos quincenas) + resumen anual, solo lectura, `.monospacedDigit()` en toda cifra |

---

## Consideraciones de plataforma

### iPhone

- Thumb-zone: captura rápida y swipe de "pagado"/"activar-desactivar" dentro del tercio inferior/medio de la pantalla en el uso típico (listas empiezan arriba pero el usuario captura scrolleando).
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

## Home

Pantalla nueva, primer tab de la app — no es un splash ni un landing sin salida: es el resumen "¿cómo estoy hoy?" desde el que se entra a la Quincena completa. Brief original: header pequeño "00 · Home" (interno de Figma, no se lleva a producción), fecha grande bold, bloque de mensaje dinámico (copy ya cerrado por el usuario, ver PRD/plan — Jonny solo diseña el tratamiento visual, no el texto), y debajo una preview de la card oscura de Quincena.

### Decisión de navegación — Home reemplaza a Quincena como tab 1

**Home pasa a ser el primer tab de la app; Quincena se mueve al segundo lugar.** Tab bar de iPhone pasa de 4 a 5 tabs — llena el quinto slot que se había dejado libre a propósito (`Decisiones registradas`, 2026-09-15: "no se rellena el quinto slot solo por simetría"). Esa decisión seguía siendo correcta entonces porque no había una quinta pantalla real; Home sí lo es.

Orden final:

| # | Tab (iPhone) / Sidebar (Mac) | Icono | accessibilityLabel |
|---|---|---|---|
| 1 | **Home** (nuevo) | `house.fill` | "Home" |
| 2 | Quincena | `calendar` | "Quincena" |
| 3 | Recurrentes y pagos | `arrow.triangle.2.circlepath` | "Recurrentes y pagos" |
| 4 | Overview | `menucard` | "Overview" |
| 5 | Ajustes | `gearshape.fill` | "Ajustes" |

**Por qué tab nuevo y no splash/landing:** un splash sin salida (fullScreenCover de un solo uso, tipo onboarding) no encaja con una app que se abre "dos veces al mes" para consultarla repetidamente — el usuario necesita volver a este resumen a media sesión, no solo al arrancar. Un tab es la única presentación que permite eso sin fricción (push/pop innecesario, o forzar `dismiss()` cada vez). HIG: `TabView` es correcto para 2–5 secciones de igual jerarquía de alto nivel en iPhone, y Home cumple el mismo criterio que las otras cuatro — es una sección real, no una interrupción.

**Por qué reemplaza a Quincena como default (no se agrega como quinto tab manteniendo Quincena primero):** la app entera existe para responder "¿cómo estoy ahorita?" en un vistazo (STYLE_BRIEF: "se entiende en un vistazo, no como un dashboard bancario") — Home es exactamente esa respuesta, más rápida de leer que la Quincena completa (que exige escanear bloques INCOME/EXPENSES línea por línea). Precedente de plataforma: Salud (tab "Resumen"), Wallet (tab "Overview") — un resumen glanceable primero, el detalle editable a un tap. La Quincena completa sigue siendo el segundo tab, no queda enterrada — el usuario que abre la app para capturar una línea llega en un tap igual que hoy.

**Icono `house.fill` coincide con el de "Servicios"** (fila del hub "Recurrentes y pagos", no un tab). Nunca son visibles en la misma pantalla — no hay colisión real de reconocimiento, y `house.fill` es el símbolo estándar de Apple para "inicio/resumen" (Salud, muchas apps de terceros). No se cambia por esta coincidencia de bajo riesgo.

**Mac:** Home se agrega como primer ítem de sidebar (antes de Quincena), mismo patrón — 10 secciones en vez de 9. Sin hub (el límite de 5 es exclusivo de iPhone).

### Estructura de la pantalla

```
ScrollView
├─ Header de fecha             ← hero de esta pantalla (equivalente al rol de SOBRANTE en Quincena), fondo blanco (ver "Fondo del header")
├─ 32pt                        ← revisión 2026-09-18, duplicado desde 16pt (ver "Espaciado" abajo)
├─ Bloque de mensaje dinámico  ← prosa, 2–4 oraciones por escenario, sin ícono inline (revertido, ver "Mensaje dinámico"), TODO el párrafo en Semibold, mismo fondo blanco del header
├─ 48pt                        ← sin cambio desde la revisión 2026-09-18, restaura el aire del mockup original (ver "Espaciado" abajo)
└─ Card de Quincena embebida (preview, un solo tap target → navega a tab Quincena) — se queda oscura; su fondo pasa de `#2A2A2A` a `#000000` puro (cambio global de `AppBackgroundSecondary`, ver "Fondo — negro puro" abajo). Sus esquinas superiores llevan el radio de 55pt de la pantalla — no el header blanco, que se queda recto arriba (ver "Fondo del header")
```

Sin header "00 · Home" visible — es una anotación interna del mockup de Figma para organizar el archivo, no una instrucción de UI (confirmado en el brief del usuario). Añadir un eyebrow label ahí no aporta información nueva y va contra "reduce, no añadas". Toda la pantalla vive en un `ScrollView`, igual que Quincena — no se fuerza a caber sin scroll en iPhone.

**Revisión 2026-09-17 (referencia "Loop Lentz"):** el usuario compartió una app de calendario/productividad como referencia explícita ("se debe de ver como el primer screenshot") y pidió adaptar su header (día + dot + fecha secundaria), sus iconos inline en el mensaje, evaluar una fila de stats, y más aire general. Las cuatro subsecciones siguientes documentan qué se adoptó, qué se adaptó y qué se descartó — con razón explícita en cada caso, no en silencio.

### Header de fecha — día de la semana + fecha secundaria

**Adoptado, adaptado.** Reemplaza la fecha única "17 de septiembre" por dos elementos en una fila, `HStack(alignment: .center)` — **revisión 2026-09-18:** cambia desde `.firstTextBaseline`; la fecha secundaria ("SEPTIEMBRE"/"2026") queda centrada verticalmente contra el hero "Jueves" en vez de alinear por la línea base, lectura más equilibrada ahora que la fecha secundaria son dos líneas apiladas en vez de una sola línea de texto.

| Elemento | Contenido | Token | Alineación |
|---|---|---|---|
| Día de la semana (hero, izquierda) | "Jueves" — día completo localizado, capitalizado (`Locale.current`, `.weekday(.wide)`, misma técnica de capitalizar la primera letra que ya usa `todayDateTitle`) | `h1` (`.largeTitle.weight(.bold)`, 34pt), `HomeHeaderTextPrimary` (ver "Fondo del header" abajo — ya no `.primary` dinámico) | `.leading` |
| Spacer | — | — | — |
| Fecha completa (secundaria, derecha) | Dos líneas, **ALL CAPS**: "SEPTIEMBRE" / "2026" | `p small` (`.caption`, 12pt) **Semibold**, tracking **+0.5**, `.textCase(.uppercase)` × 2, `HomeHeaderTextSecondary` | `.trailing`, `VStack(alignment: .trailing, spacing: 2)` |

- **Por qué día de la semana como hero y no la fecha exacta (que era la decisión previa del mismo día):** el usuario pidió explícitamente replicar el patrón de la referencia tras verla junto al Home actual — es una decisión de diseño nueva, no un descuido de la anterior. Sigue siendo información útil para una app de finanzas quincenales ("hoy es viernes, la quincena cierra el lunes"); la fecha exacta no desaparece, baja de jerarquía a la posición secundaria donde antes solo iba a existir la fecha sola.
- **Se recupera el año** (la decisión de 2026-09-17 anterior lo excluía "por no competir con el hero") — ya no aplica esa razón: el año ahora vive en `p small` secundario, no en el hero, así que no compite con nada. Aporta contexto real sin costo visual.
- **El punto rojo de la referencia — descartado, no adoptado.** Dos razones, ambas suficientes por sí solas:
  1. **Rompe la regla de paleta ya fijada** ("el naranja nunca decora, siempre señala", Decisiones registradas 2026-09-17): un punto junto al día no señala ningún dato accionable, sería decoración pura. Usar rojo genérico (como la referencia) introduciría además un segundo color de "alerta" fuera del semáforo verde/amarillo/rojo del sobrante — colisión directa con una regla ya escrita.
  2. **Es redundante en Home específicamente:** el punto en la referencia distingue "hoy" de otros días en un calendario que muestra múltiples fechas. Home de Fintrol siempre muestra HOY — no hay otro día en pantalla del que distinguirse, así que el indicador no aporta información nueva ("reduce, no añadas").
- **Espaciado interno:** `spacing: 2` entre las dos líneas de la fecha secundaria (ya usado en el header de `PeriodPreviewCard` para el mismo patrón título+subtítulo apilado).
- **Formato de fecha — restaurado 2026-09-18 (mockup original "00 · Home", frame `81:2`, ahora DEPRECATED):** el usuario comparó el Home implementado contra ese primerísimo mockup y pidió puntualmente recuperar el tratamiento de la fecha secundaria: mayúsculas con tracking ("SEPTEMBER" / "2026" en el original), perdido en la iteración "Loop Lentz" del 2026-09-17 que la dejó en Title Case ("17 de septiembre"). Se localiza el mes a español ("SEPTIEMBRE") — el resto de la UI de Fintrol es español salvo la excepción ya documentada de fecha de pago de tarjetas — y se **reutiliza el token ya existente de encabezados de sección ALL CAPS** (`p small`/`.caption` Semibold, tracking +0.5, `.textCase(.uppercase)` — mismo tratamiento de "INCOME"/"EXPENSES" en Quincena y del bloque "Aportado a la fecha" en Inversiones) en vez de inventar un token nuevo para esta pantalla. **No se toca el día de la semana como hero** ("Jueves" solo, una línea) — el usuario dejó esa opción fuera explícitamente al responder esta ronda; sigue en `h1`/`.largeTitle.weight(.bold)` tal cual está.

### Fondo del header — excepción blanca (restaurado del mockup original, DEPRECATED)

**Restaurado 2026-09-18.** El mockup original de Figma ("00 · Home", frame `81:2`, marcado DEPRECATED tras las iteraciones posteriores) mostraba el bloque de header — fecha + mensaje dinámico, todo lo que va **arriba** de `PeriodPreviewCard` — sobre fondo **blanco**, no negro. Esa versión se perdió en las iteraciones intermedias, cuando el header pasó a heredar `AppBackground` (#323232) como el resto de la pantalla. El usuario comparó ambas versiones y pidió explícitamente recuperar el fondo blanco del header.

**Esto es una excepción deliberada a "Dark por defecto"** (`Plataforma y versión target` arriba: "Modos soportados: Dark por defecto"). Se documenta explícitamente aquí para que Woz y Larry no la traten como un bug ni la "corrijan" de vuelta a `AppBackground` en una futura pasada:

| Superficie | Color | Token | Nota |
|---|---|---|---|
| Fondo del bloque header (fecha + mensaje dinámico) | `#FFFFFF` sólido | `HomeHeaderBackground` (nuevo, Assets.xcassets, **sin variante Dark** — "Any Appearance" única) | Blanco fijo, no sigue el `colorScheme` del sistema ni el picker de Ajustes ("Sistema"/"Claro"/"Oscuro") — es intencional: el contraste consciente es entre el header y la card, no entre el header y el modo del sistema |
| `PeriodPreviewCard` (debajo del header) | Sin cambio — Frost `AppBackground.secondary` | Sin cambio | **No se toca.** Sigue oscura tal cual está hoy; el cambio es exclusivamente el fondo detrás del bloque de texto de arriba |
| Resto de la pantalla (`ScrollView` background, safe areas) | Sin cambio — `AppBackground` (#323232) | Sin cambio | El blanco es una zona acotada al header, no un cambio de fondo global de Home |

- **Por qué es una excepción y no una regla nueva:** "Dark por defecto" sigue siendo la norma para el resto de la app — Quincena, Recurrentes, Overview, Ajustes no cambian. Esta excepción vive únicamente en el header de Home, y existe porque el usuario pidió puntualmente restaurar ese contraste consciente del mockup original: **header claro arriba, card oscura de Quincena abajo, dos tonos en la misma pantalla** — es la composición que el mockup original comunicaba y que las iteraciones posteriores (fondo uniforme `AppBackground`) diluyeron.
- **Color de texto sobre el header — pasa a oscuro, ya no puede seguir siendo `.primary`/`.secondary` dinámico:** el texto del header hoy es blanco sobre negro (`.primary` resuelve a blanco en dark mode, que es el modo por defecto de la app). Si el fondo pasa a blanco fijo, el texto debe volverse oscuro para seguir siendo legible — y como el fondo **no seguirá** el `colorScheme` del sistema, el texto tampoco puede usar los semánticos dinámicos de Apple (que sí lo siguen): en dark mode, `.primary` seguiría resolviendo a blanco sobre un fondo ahora blanco, ilegible. Se definen dos colores fijos nuevos, reutilizando los valores estándar de Apple para texto sobre superficies claras que ya están documentados en la tabla de "Paleta semántica" de este mismo archivo (columna "Hex Light"), en vez de inventar hex nuevos:

| Rol | Token nuevo | Valor fijo | Reutiliza | Uso |
|---|---|---|---|---|
| Texto primario del header | `HomeHeaderTextPrimary` | `#000000` | Mismo hex que `.primary` en Light mode (tabla "Paleta semántica") | Día de la semana (`h1`), texto base del mensaje dinámico (`p big` `.primary`→este token) |
| Texto secundario del header | `HomeHeaderTextSecondary` | `#3C3C43` @60% | Mismo hex que `.secondary` en Light mode (tabla "Paleta semántica") | Fecha secundaria ALL CAPS ("SEPTIEMBRE"/"2026") |

  El naranja de acento en las cifras resaltadas del mensaje dinámico (`Color.accentColor`, FintrolOrange) **no cambia** — el accent de Fintrol ya está calibrado para pasar contraste tanto en superficies claras como oscuras (ver tabla de verificación WCAG de la sección de paleta); sigue siendo el mismo naranja sobre el nuevo fondo blanco.
- **Implementación para Woz:** `HomeHeaderBackground`, `HomeHeaderTextPrimary` y `HomeHeaderTextSecondary` se definen como `Color Set` en `Assets.xcassets` con una sola variante ("Any Appearance", sin "Dark") — exactamente lo opuesto de cómo se define `AppBackground` (que si tiene variante Dark explícita). Esto asegura que el header se vea igual sin importar si el usuario tiene la app en "Sistema", "Claro" u "Oscuro" — es una superficie de marca fija, no una superficie semántica. Aplican solo dentro del bloque de header de `HomeView`; el resto de la pantalla sigue usando `.primary`/`.secondary`/`AppBackground` normalmente.
- **Contraste:** `#000000` sobre `#FFFFFF` = 21:1 (excede cualquier mínimo WCAG). `#3C3C43 @60%` sobre `#FFFFFF` es el mismo par que Apple usa como `secondaryLabel` en light mode en todo iOS — ya pasa AA por definición del sistema.

### Mensaje dinámico — tratamiento visual

El copy (8 frases de referencia en el prompt del usuario) ya está cerrado — Jonny diseña solo cómo se ve, no el texto. **Nota abierta, no bloqueante:** el copy de referencia está en inglés; toda la UI de Fintrol es español salvo una única excepción ya documentada (regla de fecha de pago de tarjetas, Ajustes). Si este es un segundo caso especial o si Kim/Steve deben traducirlo antes de que Woz lo implemente queda señalado aquí — no cambia el tratamiento tipográfico, que aplica igual en cualquier idioma.

- **Token — revisión 2026-09-18:** todo el párrafo en `p big` **Semibold** (`.body.weight(.semibold)`), no solo las cifras resaltadas — antes solo las cifras llevaban peso Semibold y el resto de la frase era Regular; el usuario pidió más presencia visual al párrafo completo. `HomeHeaderTextPrimary` (ver "Fondo del header" arriba — ya no `.primary`, porque este bloque vive sobre el fondo blanco fijo del header, no sobre `AppBackground`), `.leading`, sin card — texto suelto directamente sobre `HomeHeaderBackground`, mismo patrón ya usado para TOTAL INCOME/EXPENSES y "To Send" (nunca todo lo que aparece en Fintrol necesita un contenedor).
- **Longitud — revisión 2026-09-18:** el copy pasó de una sola oración corta a 2–4 oraciones por escenario (~25–55 palabras), más detallado y explicativo que la versión inicial. La tipografía y el tratamiento visual no cambian por esto — `lineSpacing(4)` y `lineLimit(nil)` ya estaban dimensionados para el caso largo.
- **Interlineado:** `lineSpacing(4)` — aplica la regla ya escrita en "Leading" de este documento (texto ≥3 líneas en el estado largo).
- **Sin límite de líneas:** `lineLimit(nil)` + `.fixedSize(horizontal: false, vertical: true)`. Nunca se trunca información financiera, así que no hay truncamiento ni "leer más" — el `ScrollView` absorbe la altura extra.
- **Énfasis de las cifras accionables:** los valores dinámicos del mensaje —`{n}` pagos pendientes, `{loanPct}%`, `{cardsDue}` tarjetas— se resaltan inline con `Text` concatenado (no `AttributedString` — decisión ya tomada por Woz, ver `HomeInsightMessage.attributedText`): mismo peso Semibold que ya lleva ahora todo el párrafo, pero en `.foregroundStyle(Color.accentColor)` (FintrolOrange) — el color, no el peso, es lo que las distingue del resto del texto tras la revisión de arriba. Coherente con la regla de paleta ("el naranja nunca decora, siempre señala") — señala exactamente el número que el usuario necesita retener.

#### SF Symbol inline antes de cada cifra — **revertido 2026-09-18, vuelve a estar descartado**

**Revertido.** La adopción del 2026-09-17 (ver entrada superseded en "Decisiones registradas") antepuso un SF Symbol (`checklist`/`creditcard.fill`/`banknote`) a cada cifra resaltada vía `Text(Image(systemName:))`. El usuario pidió quitarlos en la revisión del 2026-09-18 — `HomeInsightMessage.attributedText` (`HomeView.swift`) ya no llama a ningún helper `iconedHighlight`, solo `highlighted(_:)` con color naranja, sin símbolo. La razón original que había descartado los iconos el 2026-09-17 (antes de la adopción acotada) vuelve a aplicar: el mensaje se lee mejor como prosa limpia, sin el ruido visual de un glifo repetido antes de cada cifra. Esta subsección queda como registro histórico de la iteración intermedia — no describe el estado actual del código.

#### Fila de stats pequeña — **descartada, no adoptada**

La referencia muestra "🚶 4.7K steps  🌙 7.3 hours" debajo del mensaje. Fintrol no tiene datos de fitness, pero la pregunta real es si vale la pena un análogo financiero (ej. "Sobrante: $X" chico, o "N días para tu próximo pago"). **No se adopta:**

- **Redundancia directa, no análoga:** en la referencia, steps/hours no aparecen en ningún otro lugar de la pantalla — es información nueva. En Home de Fintrol, el dato más cercano (sobrante, próximo mes) ya vive en la `PeriodPreviewCard` inmediatamente debajo, a un scroll de distancia mínima. Una fila de stats repitiendo o anticipando ese mismo dato sería ruido, no señal — exactamente lo que "reduce, no añadas" prohíbe.
- **Identidad de la app, no de la referencia:** Fintrol es una herramienta financiera densa por diseño (STYLE_BRIEF), no un dashboard minimalista de bienestar — llenar el espacio "aireado" de la referencia con una fila decorativa solo por igualar la composición visual iría en contra de esa identidad ya establecida, sin aportar valor real al usuario.
- **Si en el futuro aparece un dato nuevo** que no viva ya en la card de abajo (ej. una racha de quincenas sin deuda), esta fila es el lugar natural para introducirlo — queda anotado en "Sin definir aún", no cerrado para siempre.

### Espaciado — más aire, sin romper densidad regular

**Adoptado parcialmente.** La referencia se siente notablemente menos densa que el Home actual. Se ajustan tres valores puntuales del header hacia el bloque de mensaje y la card, sin adoptar el minimalismo extremo de la referencia (que no aplica a una app financiera densa por diseño):

| Elemento | Valor anterior | Valor nuevo | Razón |
|---|---|---|---|
| Espacio header de fecha → mensaje dinámico | 12pt | 16pt | Un salto perceptible sin llegar a separar visualmente el header del mensaje — siguen leyéndose como el mismo bloque |
| **Espacio header de fecha → mensaje dinámico — revisión 2026-09-18** | 16pt | **32pt** | Duplicado sobre el valor anterior — el usuario pidió más aire también arriba del mensaje, no solo entre el mensaje y la card, para que el header completo (fecha + mensaje) respire igual que el nuevo salto de 48pt de abajo |
| Espacio mensaje → card de Quincena | 24pt | 32pt | El salto más grande de la pantalla — es donde la referencia respira más, y es el punto natural de Fintrol para separar "resumen en prosa" de "card de datos" |
| **Espacio mensaje → card de Quincena — revisión 2026-09-18** | 32pt | **48pt** | El usuario comparó el Home implementado contra el mockup original de Figma ("00 · Home", frame `81:2`, DEPRECATED) y pidió puntualmente más aire aquí — en ese mockup el mensaje termina aproximadamente a la mitad de la pantalla y hay un salto grande de espacio en blanco antes de que arranque la card oscura. 32pt (la iteración anterior) ya no comunicaba ese salto una vez el header pasó a fondo blanco: con dos tonos distintos en pantalla (header claro / card oscura), la transición necesita más aire para leerse como una pausa intencional y no como un espaciado de sección normal. 48pt es el siguiente múltiplo de 8 con salto perceptible (+16pt sobre 32pt, el doble del ajuste anterior 24→32) sin volverse un hueco vacío que rompa la lectura vertical del `ScrollView`. **Sin cambio en esta revisión** — confirmado que sigue en 48pt |
| Padding superior del `ScrollView` | 12pt | 20pt | Da al header su propio espacio antes de tocar la safe area, en vez de sentirse pegado al notch/Dynamic Island |

Se mantiene sin cambio el padding lateral de pantalla (20pt) y el padding interno de la card (16pt) — ya están dentro del sistema de espaciado de la app y no forman parte de este encargo (la card de Quincena embebida no se toca).

- **Estado corto vs. largo:** no hay tratamiento especial por longitud — la tipografía de 17pt Regular con `lineSpacing(4)` funciona igual de bien en una línea de 8 palabras que en cuatro líneas de 25; el espacio de 32pt hacia la card de abajo es fijo, no compensa por la altura del texto (el `ScrollView` ya lo resuelve).

### Card de Quincena embebida — preview de solo lectura, no la vista completa

**No es un link a texto ("Ver Quincena →") ni la `PeriodView` completa incrustada** — es una card nueva y más chica, `PeriodPreviewCard`, que reutiliza piezas ya construidas en modo lectura:

| Bloque (de arriba a abajo) | Reutiliza | Cambios para el modo preview |
|---|---|---|
| Título + pill de rango | Mismo patrón visual del header de Quincena ("Septiembre 2026" `h2`/`.title2` Semibold + pill "1 – 15"/"16 – 30" con el mismo tratamiento verde-si-es-hoy) | No abre el jump sheet al tocarlo — toda la card es un solo tap target, no hay sub-interacciones dentro de ella. **Revisión 2026-09-18 (mockup de Figma):** el bloque completo se centra horizontalmente (antes alineado a la izquierda como el resto del contenido de la card), con `padding(.top, 38)` y `padding(.bottom, 16)` propios — separa visualmente este header del bloque INCOME/EXPENSES de abajo |
| INCOME / EXPENSES | Mismo token que "TOTAL INCOME"/"TOTAL EXPENSES" (`p small`/`.caption.weight(.bold)` tras la migración pendiente, ver Tipografía) | **Rediseñado 2026-09-18 (mockup de Figma):** deja de ser una fila de texto simple — pasa a ser **dos cajas lado a lado** (`HStack(spacing: 12)`), una por INCOME y otra por EXPENSES. Cada caja: label arriba (`.caption.weight(.bold)`, tracking +0.5, `.secondary`) y el monto debajo dentro de un nested-card (`.ultraThinMaterial.opacity(0.5)`, radio 16pt, `padding(16)`) — mismo padding que usa la caja "Next Month", para que ambas filas de cajas midan la misma altura visual. Sin las cards de línea individuales, sin botón "+"; sigue siendo un resumen, no un editor |
| Sobrante | `SobranteBadge` reutilizado tal cual (mismo componente, mismo semáforo verde/amarillo/rojo, `h1` Bold) | Sin cambios — es el dato que más importa de la card |
| Next Month | `SummaryPanel`'s bloque "Next Month" reutilizado tal cual | Sin cambios |

- **"Mandar"/"To Send" queda fuera del preview** — no es parte de lo que el usuario listó en el mockup ("INCOME/EXPENSES, Sobrante grande, Next Month") y es una acción operativa (convertir a MXN para enviar), no un dato de resumen; se ve al entrar a la Quincena completa.
- **Espaciado pill → INCOME/EXPENSES — revisión 2026-09-18:** el salto entre la pill de rango y las cajas INCOME/EXPENSES se duplica (+16pt adicionales sobre el spacing base de la card), para separar con más claridad el header centrado (título + pill) del bloque de totales.
- **Contenedor:** una sola card Frost, `AppBackground.secondary`, radio 20pt en el resto de la app (Home usa 55pt en sus esquinas superiores, ver abajo), padding 16pt. Sin swipe actions, sin menú contextual — toda la superficie es un botón.
- **Esquinas superiores redondeadas — 55pt, solo en la card, no en el header blanco.** El radio de 55pt (curva de pantalla del iPhone 17 Pro, confirmado con el usuario) vive exclusivamente en `PeriodPreviewCard.clipShape` (`UnevenRoundedRectangle`, esquinas superiores únicamente, bottom en 0 porque la card corre edge-to-edge hasta el borde físico inferior). El bloque header blanco (fecha + mensaje) va con esquinas **rectas** arriba — corrección explícita tras un error de ubicación en una iteración previa donde el radio se había aplicado al header por accidente. `HomeView` reaplica su propia versión animada de este mismo `clipShape` durante el drag-to-transition, con el mismo radio en reposo.
- **Fondo — negro puro (cambio global, no solo Home).** `AppBackgroundSecondary` (Assets.xcassets) pasa de gris `#2A2A2A` a **`#000000`** en dark mode — ver `Assets.xcassets/AppBackgroundSecondary.colorset/Contents.json`. Es el fondo Frost de todas las cards oscuras de la app, no solo `PeriodPreviewCard`: Quincena, Préstamos, Tarjetas, Inversiones, etc. heredan el mismo cambio automáticamente al usar el mismo token. Todas las menciones de `#2A2A2A` en este documento se actualizaron a `#000000` para reflejarlo. **Pendiente:** revisar si los frames ya sincronizados en Figma (`02 · Quincena` y sucesivos) necesitan el mismo refresco de color — no se tocaron en esta pasada, solo `01 · Home`.
- **Interacción:** tap en cualquier punto de la card navega al tab/sidebar-item Quincena, mostrando la quincena actual (mismo `coordinate` que ya se estaría mostrando ahí). No hay chevron ni flecha "ver más" dentro de la card — la superficie completa siendo tappable ya es un patrón establecido en la app (filas del hub navegan igual, con tap simple).
- **Accesibilidad:** la card es un solo `accessibilityElement(children: .combine)` con un label compuesto ("Quincena actual, [rango], sobrante [monto], toca para ver detalle") en vez de leer cada sub-bloque por separado — un VoiceOver user no necesita navegar 4 elementos internos en una preview que no tiene acciones propias.

### Ajustes a `RootView.swift` — para Woz

1. **`FintrolTab`** (iPhone): agregar `case home` como **primer** caso (el orden de `CaseIterable.allCases` sigue el orden de declaración, así que debe ir antes de `.period`), con `systemImage: "house.fill"` y `accessibilityLabel: "Home"`. Actualizar `destination(for:)` con `case .home: HomeView()`.
2. **`@State private var selection: FintrolTab = .period`** → cambia el default a `.home`.
3. **`FintrolSection`** (Mac): mismo patrón — `case home` primero, `title: "Home"`, `systemImage: "house.fill"`, y en `MacRootView` el default `@State private var selection: FintrolSection? = .period` → `.home`, más `case .home: HomeView()` en `destination(for:)`.
4. **Navegación programática Home → Quincena:** hoy `selection` vive como `@State` privado dentro de `iOSRootView`/`MacRootView` — `HomeView` no tiene forma de cambiarlo al tocar la card embebida. Woz necesita decidir el mecanismo (opción simple: pasar un `Binding<FintrolTab>`/`Binding<FintrolSection?>` a `HomeView`, en vez de dejar `selection` totalmente privado; alternativa: una notificación/`@Observable` de navegación compartido si el patrón se repite en otro lado). Esto es la única pieza estructural real de este cambio — el resto es una pantalla nueva más un reordenamiento de enum.
5. `HomeView.swift` es un archivo nuevo (`Apps/Fintrol/Fintrol/Features/Home/HomeView.swift`, siguiendo el patrón de carpeta por feature ya establecido).

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-09-15 | Fondo base `AppBackground` (#323232 del tema), no `systemBackground` negro puro | Requisito del tema Fintrol — gris oscuro neutro, no negro OLED |
| 2026-09-15 | Cards de contenido usan material Frost del tema, nunca Liquid Glass | Regla de capas: Liquid Glass solo en navegación; Frost es el material de marca de Fintrol para contenido |
| 2026-09-15 | Sobrante usa `.green`/`.yellow`/`.red` de sistema, no el accent naranja | Semántica fija del PRD — el naranja de marca nunca se confunde con el semáforo financiero |
| 2026-09-15 | Navegación entre quincenas: chevrons (adyacente) + jump sheet por título (año/quincena arbitraria) + botón "Hoy" | Resuelve explícitamente el riesgo de "perderse" en una proyección a 10 años |
| 2026-09-15 | Captura rápida es una fila inline al final de cada bloque, no un botón que abre sheet aparte | Replica el flujo de "llenar una hoja de cálculo" que es el modelo mental del usuario |
| 2026-09-15 | **Superseded (ver entrada del mismo día más abajo, "sin icono de origen en la fila"):** línea de origen recurrente/suscripción/servicio editada manualmente cambiaba su icono base a `pencil` | Comunicaba visualmente la regla "la edición manual gana" del TRD sin texto adicional — reemplazado cuando se quitaron todos los iconos de origen de `LineItemRow` |
| 2026-09-15 | "Recurrentes" se divide en "Ingresos recurrentes" y "Gastos recurrentes"; cada lista solo su tipo, alta directa sin picker | Decisión del usuario — evita preguntar ingreso/egreso cuando el contexto ya lo dice |
| 2026-09-15 | Se agrega "Servicios" (pagos del hogar: renta, luz, internet, agua, gas, seguro), mecánica idéntica a Suscripciones pero pantalla, icono y categorías propias | Decisión del usuario — separa gasto operativo del hogar de suscripciones de entretenimiento/trabajo, aunque el motor de cálculo por día de pago sea el mismo |
| 2026-09-15 | Suscripciones se mueve del tab propio al hub "Recurrentes y pagos", junto con Ingresos/Gastos recurrentes y Servicios | Con tres listas ya viviendo en un hub, dejar Suscripciones como único tab de nivel top por una sola fuente de datos rompía la consistencia; las cuatro responden a la misma pregunta del usuario ("qué se repite solo") |
| 2026-09-15 | Tab bar de iPhone baja de 5 a 4 tabs (Quincena, Recurrentes y pagos, Overview, Ajustes) | Consecuencia directa de mover Suscripciones al hub — no se rellena el quinto slot solo por simetría |
| 2026-09-15 | Nueva feature v1 "Préstamos": quinta fila del hub "Recurrentes y pagos", icono `banknote` (no `creditcard.and.123`) | Decisión del usuario; el ícono evita asociación visual con tarjetas de crédito, explícitamente fuera de v1 en el PRD |
| 2026-09-15 | Dirección del préstamo ("Debo"/"Me deben") en chip icono+texto con tinte `.orange`/`.blue`, no `.green`/`.red` | Evita colisión con la semántica fija del semáforo del sobrante (verde/amarillo/rojo), que es exclusiva de ese cálculo |
| 2026-09-15 | Override del pago de un préstamo recalcula el plazo (nunca al revés) | El usuario fija lo que puede pagar; el plazo es la consecuencia, coincide con cómo se razona un préstamo real |
| 2026-09-15 | Tabla de amortización: `List` de filas custom en iPhone, `Table` nativo en Mac | `Table` no es viable en ancho compacto; ambas muestran las mismas 5 columnas con distinto layout |
| 2026-09-15 | **Superseded:** origen `.subscription` usaba icono distinto según Suscripciones (`repeat`) o Servicios (`house.fill`) en la fila de Quincena; `.recurring` conservaba `arrow.triangle.2.circlepath` ahí | Respondía a si la fila de quincena debía distinguir el origen — reemplazado cuando se quitaron todos los iconos de origen de `LineItemRow` (siguiente entrada) |
| 2026-09-15 | Pantalla de bloqueo Face ID no monta ningún dato real detrás, no es blur sobre contenido | Cierra el riesgo del PRD de montos visibles en app switcher/background |
| 2026-09-15 | Sin `.searchable()` en v1 | Volumen de datos de un presupuesto personal no lo justifica |
| 2026-09-15 | Mac: panel de resumen fijo a la derecha del detail, no columna adicional de `NavigationSplitView` | El PRD pide sidebar + contenido; una tercera columna de sistema competiría con la sidebar de secciones |
| 2026-09-15 | Se eliminan los toggles visibles de `LineItemRow`; activar/desactivar y marcar pagado pasan a swipe leading/trailing + menú contextual + `accessibilityActions` | Decisión del usuario tras ver la app en simulador. **Señalado, no bloqueante:** "activar/desactivar" excluye la línea de la suma, lo cual coincide en efecto con el switch "cuenta/no cuenta" que el PRD v1.1 marca fuera de v1 — Steve debe confirmar si esto actualiza el PRD |
| 2026-09-15 | Swipe/acciones de línea usan `.blue` (pagado, reactivar) y `.gray` (desactivar, editar en líneas generadas), nunca `.green`/`.red` | Verde/amarillo/rojo quedan exclusivos del semáforo del sobrante; `trash` de Eliminar es la única excepción, por ser convención universal de sistema, no señal financiera |
| 2026-09-15 | Préstamos gana un segundo modo "Hasta liquidar" (switch en el Formulario, sin plazo, solo "Pago esperado") junto al modo Plazo fijo existente | Decisión del usuario — caso real "Ada": $824 al 26.2%, pagos variables ~$200/quincena, sin fecha de fin conocida de antemano |
| 2026-09-15 | Tabla de amortización distingue filas de pago real de filas proyectadas con etiqueta explícita "Proyectado", no solo opacidad | En modo Hasta liquidar casi toda la tabla es proyección que se recalcula con cada pago real; la opacidad reducida sola (ya usada para "pagada") no basta para comunicar esa diferencia sin ambigüedad |
| 2026-09-15 | La línea generada por un préstamo "Hasta liquidar" en Quincena es visualmente idéntica a la de un préstamo a plazo fijo | El modo cambia cómo se proyecta, no cómo se presenta ni se edita la línea ya materializada — misma regla de edición manual sin caso especial |
| 2026-09-15 | Se quitan todos los iconos de origen de `LineItemRow` en Quincena (ni `arrow.triangle.2.circlepath`, `repeat`, `house.fill`, `banknote`, `chart.line.uptrend.xyaxis`, ni `pencil`); la fila queda solo descripción + monto + palomita de pagado | Decisión del usuario — seis símbolos posibles por fila competían con la lectura rápida de descripción+monto, el modelo mental central de la app. Origen y `isManuallyEdited` se conservan en el modelo, expuestos solo en accesibilidad y en el contexto de edición |
| 2026-09-15 | La fila en reposo no tiene fondo propio en ningún estado (salvo "Editando") — es transparente, hereda el Frost de la card contenedora, en light y dark | Evita un rectángulo visual redundante encima del material de la card; consistente con la regla de capas ya fijada (Frost solo en la card, no en cada fila) |
| 2026-09-15 | Nueva feature v1 "Inversiones": sexta fila del hub "Recurrentes y pagos", icono `chart.line.uptrend.xyaxis` | Decisión del usuario — registro de aportaciones periódicas a cuentas de inversión, deliberadamente más chico que "control de inversiones" (Fase 3 del PRD): sin rendimientos ni valor de portafolio |
| 2026-09-15 | Inversiones no tiene campo de rendimiento ni valor actual en el Formulario ni en el Detalle | Ausencia deliberada — marca el límite de alcance de v1; ver "Sin definir aún" para el hueco de etapa 2 |
| 2026-09-15 | Captura/edición de línea deja de ser inline; el "+" y el tap en una línea abren un bottom sheet (`.presentationDetents([.medium, .large])`, fondo Frost del tema, no Liquid Glass) con Descripción, Monto+moneda y botones "Cancelar"/"Listo" a ancho completo | Decisión del usuario — corrige de paso el bug de "Cancelar" truncado a 3 líneas por falta de ancho en el patrón anterior |
| 2026-09-15 | El sheet de captura/edición es la única excepción documentada a "los sheets usan Liquid Glass" — usa Frost porque el usuario lo pidió explícitamente para esta pantalla | El resto de sheets (jump quincena, formularios de Recurrentes/Préstamos/Inversiones) sigue Liquid Glass regular, sin cambio |
| 2026-09-15 | Import/export en Ajustes revisado — usa `.fileImporter`/`.fileExporter`/`.alert` nativos, no el patrón de captura corta; no requiere el cambio a sheet | Evita aplicar un rediseño donde no aplica el problema que lo motivó |
| 2026-09-16 | **Revertido el mismo día:** se evaluó formalizar un `NavCircleButton` custom (círculo 29×29pt) para el back de las 6 listas del hub; el usuario decidió no hacerlo — el back nativo de `NavigationStack` ya recibe Liquid Glass correcto en iOS 26 sin componente custom | Ver "Componentes de navegación — Liquid Glass" — es la entrada vigente, no esta |
| 2026-09-16 | El CTA "+" de INCOME/EXPENSES se mueve del header de sección a una posición sola, alineada a la izquierda, debajo de la última card de línea y antes de TOTAL | Decisión del usuario (nueva captura de Figma) — el header de sección queda solo con el texto, sin control a la derecha |
| 2026-09-16 | Badge "Current"/"Proyección" eliminado del header de Quincena; su función pasa a la propia pill de rango de días (verde sólido si es hoy, transparente si no) | Decisión del usuario — un elemento menos, misma información, sin distinguir pasada de proyectada en el header |
| 2026-09-16 | Nueva fila "Historial visible" en Ajustes → Preferencias (`Stepper`, 1–24 meses, default 1) limita cuánto se puede retroceder desde la quincena actual | Decisión del usuario — se combina con el límite existente de "primera quincena materializada": aplica el que esté más cerca de hoy |
| 2026-09-16 | Línea con `isPaid == true` queda bloqueada (solo "Desmarcar pagado" disponible) y su card cambia a fondo verde tenue (`Color.green.opacity(0.16)` sobre Frost) | Decisión del usuario — tercera excepción documentada al uso de verde en la app (junto a SOBRANTE y la pill "Hoy"), siempre más sutil que el verde sólido del semáforo |
| 2026-09-16 | Acciones ausentes/deshabilitadas sin toast ni mensaje cuando la línea está bloqueada por `isPaid` | Recomendación de Jonny adoptada — patrón estándar iOS (Mail, Reminders): las acciones que no aplican simplemente no aparecen en swipe/menú/accessibilityActions |
| 2026-09-17 | Nueva feature v1 "Credit Cards", promovida desde Fase 2 del PRD (plan `glimmering-swinging-bumblebee.md`); séptima fila del hub, sección "EXPENSES", icono `creditcard.fill` | Decisión del usuario tras investigación de Avie sobre fecha de pago óptima y fórmula de pago mínimo |
| 2026-09-17 | En Quincena, las líneas `.creditCard` de una misma quincena se agrupan en una sola fila "Credit Cards Payments" (suma) en vez de una fila por tarjeta — única fila de Quincena que representa más de una línea de datos | Evita saturar EXPENSES con una fila por tarjeta cuando puede haber varias con pago el mismo período; el desglose vive en el sheet de detalle |
| 2026-09-17 | La fila "Credit Cards Payments" no lleva swipe/menú de pagado/editar/eliminar — es navegación pura, tocarla abre el sheet | Es la única card-por-línea de Quincena sin esas acciones; el estado pagado real vive por tarjeta dentro del sheet, no en la fila agregada |
| 2026-09-17 | El sheet de detalle reutiliza `LineItemRow` completo, incluido el bloqueo verde al marcar pagado, sin reinventar el patrón | Consistencia — mismo token `Color.green.opacity(0.16)` y mismo comportamiento ya documentado para toda línea pagada |
| 2026-09-17 | "Utilización" del Detalle de tarjeta usa su propia escala de un umbral (`.secondary`/`.orange` ≥30%), no el semáforo verde/amarillo/rojo del sobrante | Evita confundir dos significados distintos con la misma paleta de tres colores |
| 2026-09-17 | Regla de fecha de pago en Ajustes: 3 opciones con explicación en inglés, default "N días antes del corte" (N=5) | Decisión explícita del usuario — única excepción de idioma en toda la app, basada en investigación citada en el plan (reduce el saldo reportado al buró) |
| 2026-09-17 | Nueva pantalla "Home" reemplaza a Quincena como primer tab (iPhone) / primer ítem de sidebar (Mac); Quincena pasa a segundo lugar. Tab bar de iPhone sube de 4 a 5 | Recomendación de Steve, adoptada por Jonny — Home responde "¿cómo estoy hoy?" más rápido que la Quincena completa, coherente con "se entiende en un vistazo" del STYLE_BRIEF; llena el quinto slot que se había dejado vacío a propósito (2026-09-15) porque hasta ahora no existía una quinta sección real |
| 2026-09-17 | **Superseded (ver revisión "Header de fecha" más abajo, mismo día):** la fecha grande de Home usa `h1`/`.largeTitle.weight(.bold)` como único elemento del header, sin day-of-week ni año | Era correcto antes de que el usuario compartiera la referencia "Loop Lentz" y pidiera replicar su patrón día+fecha secundaria — reemplazado por la entrada de "Header de fecha" de abajo |
| 2026-09-17 | **Superseded (ver "SF Symbol inline antes de cada cifra" en § Home, mismo día):** el mensaje dinámico de Home resalta sus valores (`{n}`, `{loanPct}%`, `{cardsDue}`) con accent naranja inline en vez de un ícono/chip aparte; sin header "00 · Home" visible | La mitad "sin header 00 · Home" sigue vigente sin cambio. La mitad "sin ícono/chip aparte" se reemplaza tras la referencia del usuario — ver la entrada de supersede explícito más abajo, que documenta por qué la razón original (ruido de `LineItemRow`) no aplica igual en un párrafo con máximo 3 cifras |
| 2026-09-17 | La card de Quincena embebida en Home es un componente nuevo de solo lectura (`PeriodPreviewCard`), no la `PeriodView` completa ni un link de texto — reutiliza `SobranteBadge` y el bloque "Next Month" de `SummaryPanel` tal cual | El mockup la muestra como resumen, no como la vista interactiva completa; "Mandar" queda fuera por ser una acción operativa, no un dato de resumen |
| 2026-09-17 | Header de fecha de Home cambia a día de la semana completo (hero, `h1` Bold) + fecha completa con año en dos líneas secundarias (`p small`, `.secondary`, trailing) — sin punto/dot de acento | Referencia explícita del usuario ("Loop Lentz", comparada contra el Home actual). El día de la semana sí aporta a "¿cómo estoy hoy?" en una app quincenal; el año vuelve porque ahora vive en texto secundario que no compite con el hero. El dot se descarta por romper la regla "el naranja nunca decora" y por ser redundante — Home siempre muestra hoy, no hay otro día del que distinguirse |
| 2026-09-17 | El mensaje dinámico de Home antepone un SF Symbol inline (`checklist`/`creditcard.fill`/`banknote` según el tipo de cifra) a cada valor resaltado en naranja, vía `Text(Image(systemName:))` concatenado | Supersede explícito de la entrada "sin ícono/chip aparte" del mismo día — la razón original (ruido de `LineItemRow`, hasta 6 símbolos por fila repetidos N veces) no aplica igual a un párrafo único con máximo 3 cifras; refuerza reconocimiento reutilizando los iconos ya asignados a Tarjetas y Préstamos en el hub |
| 2026-09-17 | Se descarta una fila de stats pequeña bajo el mensaje dinámico (análoga a "steps/hours" de la referencia) | La `PeriodPreviewCard` inmediatamente debajo ya muestra sobrante y próximo mes — una fila adicional sería redundante, no información nueva como sí lo es en la referencia; Fintrol es densa por diseño, no un dashboard minimalista |
| 2026-09-17 | Espaciado del header de Home ajustado: header→mensaje 12pt→16pt, mensaje→card 24pt→32pt, padding superior del `ScrollView` 12pt→20pt | Referencia explícita del usuario pidiendo "más aire"; ajuste puntual, no adopción del minimalismo extremo de la referencia — el resto del sistema de espaciado de la app no cambia |
| 2026-09-18 | **Restaurado del mockup original "00 · Home" (frame `81:2`, DEPRECATED):** el fondo del bloque header de Home (fecha + mensaje dinámico, no la card de Quincena) pasa a blanco sólido fijo (`HomeHeaderBackground`, `#FFFFFF`, sin variante Dark), con texto en `HomeHeaderTextPrimary` (`#000000`) y `HomeHeaderTextSecondary` (`#3C3C43` @60%) en vez de `.primary`/`.secondary` dinámico | Excepción deliberada a "Dark por defecto" — el usuario pidió puntualmente recuperar el contraste consciente del mockup original: header claro arriba, card oscura de Quincena abajo, dos tonos en la misma pantalla. `PeriodPreviewCard` no cambia, se queda oscura |
| 2026-09-18 | Espacio mensaje → card de Quincena en Home sube de 32pt a 48pt | El usuario comparó contra el mockup original y pidió más aire ahí — en el mockup el mensaje termina a media pantalla con un salto grande antes de la card; 32pt ya no comunicaba ese salto con el nuevo header blanco de dos tonos |
| 2026-09-18 | Fecha secundaria del header de Home pasa de Title Case ("17 de septiembre"/"2026") a ALL CAPS con tracking ("SEPTIEMBRE"/"2026"), reutilizando el token de encabezados de sección ya existente (`p small`/`.caption` Semibold, tracking +0.5, `.textCase(.uppercase)` — mismo de "INCOME"/"EXPENSES" y "Aportado a la fecha") | Restaura el formato del mockup original ("SEPTEMBER"/"2026" en el brief en inglés, localizado a español); no se inventa un token nuevo, se reutiliza el ya usado para mayúsculas con tracking en el resto de la app. El día de la semana hero ("Jueves" solo) no se toca — el usuario lo dejó fuera de este pedido explícitamente |
| 2026-09-18 | **Revertido:** el mensaje dinámico de Home vuelve a no llevar SF Symbol inline antes de las cifras — se quita `Text(Image(systemName:))`, solo queda el resaltado naranja | El usuario pidió quitar los iconos adoptados el 2026-09-17; la razón original que los había descartado antes de esa adopción (ruido visual) vuelve a aplicar |
| 2026-09-18 | Todo el párrafo del mensaje dinámico pasa a Semibold (antes solo las cifras resaltadas eran Semibold, el resto Regular); el copy en sí se alarga a 2–4 oraciones por escenario | Más presencia visual y más contexto explicativo por escenario, pedido explícito del usuario |
| 2026-09-18 | Header de fecha (fila "Jueves" + fecha secundaria) cambia de `HStack(alignment: .firstTextBaseline)` a `HStack(alignment: .center)` | La fecha secundaria centrada verticalmente contra el hero se lee mejor ahora que son dos líneas apiladas, en vez de alinear por la línea base |
| 2026-09-18 | Espacio header de fecha → mensaje dinámico se duplica de 16pt a 32pt | Más aire arriba del mensaje, pedido explícito del usuario, para que el header respire igual que el salto de 48pt de abajo |
| 2026-09-18 | Las esquinas superiores redondeadas de 55pt se confirman exclusivas de `PeriodPreviewCard` — el header blanco (fecha + mensaje) va con esquinas rectas arriba | Corrige un error de ubicación de una iteración previa donde el radio se había aplicado al header por accidente; "el roundness va ahí, no donde lo pusiste" (confirmado con el usuario) |
| 2026-09-18 | El header interno de `PeriodPreviewCard` (título del mes + pill de rango) se centra horizontalmente, con `padding(.top, 38)` y `padding(.bottom, 16)` propios | Mockup de Figma exportado por el usuario — separa visualmente el header de la card del bloque INCOME/EXPENSES de abajo |
| 2026-09-18 | INCOME/EXPENSES en `PeriodPreviewCard` dejan de ser una fila de texto simple — pasan a ser dos cajas lado a lado con label arriba y monto dentro de un nested-card, mismo padding que "Next Month" | Mockup de Figma exportado por el usuario — iguala la altura visual entre la fila INCOME/EXPENSES y la card "Next Month" |
| 2026-09-18 | Espacio pill de rango → cajas INCOME/EXPENSES se duplica (+16pt adicionales sobre el spacing base de la card) | Mockup de Figma exportado por el usuario — separa el header centrado del bloque de totales |
| 2026-09-18 | **Cambio global, no solo Home:** `AppBackgroundSecondary` pasa de `#2A2A2A` a `#000000` puro en dark mode — afecta el fondo de toda card oscura de la app (Home, Quincena, Préstamos, Tarjetas, Inversiones) | Decisión de color del usuario aplicada al color set compartido; todas las menciones de `#2A2A2A` en este documento se actualizaron a `#000000`. Pendiente: refrescar los frames ya sincronizados en Figma distintos de `01 · Home` con el mismo negro |

---

## Sin definir aún

- [ ] Icono de la app — no se ha diseñado; queda pendiente de una sesión dedicada con Phil.
- [ ] Inversiones — etapa 2: rendimientos, valor actual del portafolio, precios de mercado en vivo. v1 solo registra la aportación periódica; el diseño de "cuánto vale hoy mi cuenta" no está hecho y necesita decidir fuente de datos (API de precios) antes de poder diseñarse — no es solo una pantalla nueva, tiene las mismas preguntas de integración externa que resolvió el TRD para el tipo de cambio.
- [ ] Home — idioma del mensaje dinámico: el copy de referencia del usuario está en inglés; confirmar con Steve/Kim si se traduce a español (regla general de la app) o si es un segundo caso de excepción de idioma junto con la regla de fecha de pago de tarjetas. No bloquea el tratamiento tipográfico, que es igual en cualquier idioma.
- [ ] Home — accesibilidad de los SF Symbols inline del mensaje dinámico: señalado para Sarah en la sección "SF Symbol inline antes de cada cifra" — confirmar en pruebas reales de VoiceOver si la lectura redundante símbolo+número molesta, y si hace falta un `accessibilityLabel` a nivel de bloque que la sobrescriba.
- [ ] Home — fila de stats pequeña queda descartada para esta revisión, no cerrada para siempre: si aparece un dato financiero nuevo que no viva ya en `PeriodPreviewCard` (ej. racha de quincenas sin deuda), este es el lugar natural para introducirlo.
- [ ] Home — mecanismo de navegación programática Home → Quincena (qué State/Binding/Observable usa Woz para cambiar el tab/sidebar seleccionado desde `HomeView`) queda como decisión de implementación, no de diseño; señalado en "Ajustes a RootView.swift" de § Home.
