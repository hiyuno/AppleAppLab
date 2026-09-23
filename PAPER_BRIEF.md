# PAPER_BRIEF — Home + Quincena (recreación de prueba en Paper)

> Brief de traspaso para reconstruir las pantallas **Home** y **Quincena** de Fintrol en
> Paper (paper.design) vía su MCP local. Figma sigue siendo la fuente de verdad del design
> system; esto es una prueba paralela. Valores extraídos el 2026-09-22 de
> `figma.com/design/tSUzh4zfCpDPYT5A88otst` — no re-medir.
>
> **Antes de empezar en la nueva sesión:** abrir un archivo en la app Paper Desktop (eso
> levanta el MCP en `http://127.0.0.1:29979/mcp`, ya registrado con `claude mcp add paper`).
> Verificar con `claude mcp list` que `paper` aparezca `✔ Connected`.

---

## 0. Canvas

| | |
|---|---|
| Ancho de frame | **393 pt** (iPhone) |
| Alto Home | 999 pt (Figma) — el card negro cubre desde y≈485 hasta abajo |
| Alto Quincena | 1073 pt (scrollea; lo fijo es el header) |
| Fuente | **Inter** (en el app real es SF Pro; Inter es el proxy de Figma — usar Inter en Paper) |
| Esquinas | todas *continuous* (squircle) |

---

## 1. Tokens (página "Tokens", frame `1:5`)

### Color

| Token | Hex | Uso |
|---|---|---|
| `AppBackground` | `#000000` | fondo raíz de Quincena y del card negro de Home |
| `AppBackground.secondary` | `#2A2A2A` | cajas INCOME/EXPENSES del quick-balance (Home) |
| `AppBackground.tertiary` | `#3C3C3C` | filas normales (`row.normal`), fondo del TabBar (al 85%) |
| `PeriodSectionCardBackground` | `#161617` | contenedores "INCOME card" / "EXPENSES card" en Quincena |
| `accent-500` FintrolOrange | `#F04200` | acento (cifras resaltadas en el mensaje de Home, tab activo) |
| `accent-600` | `#FF6B33` | hover/pressed del acento |
| `accent-300` | `#A32D00` | |
| `accent-100 dark` | `#4D1500` | |
| `accent-800 dark` | `#FFBCA3` | |
| `success-green` (fill) | `#006338` | filas hechas (`row.done`), SOBRANTE, Next Month |
| `success-green-light` | `#01F98E` | texto sobre `#006338`, borde+texto de la píldora "1 – 15" |
| `success-green-dark` | `#14332B` | texto de filas hechas (tachado) |
| `success` (.green iOS) | `#34C759` | color de acción "palomita" en swipe |
| `warning` | `#FFCC00` | |
| `danger` | `#FF3B30` | (swipe eliminar en Figma usa `#FF5053`) |
| `text.primary` | `#FFFFFF` | |
| `text.secondary` | `#EBEBF5` al 60% (Figma lo pinta como `#A8A8A8`) | títulos de sección INCOME/EXPENSES |
| `HomeHeaderBackground` | `#FFFFFF` | mitad superior de Home |
| `HomeHeaderText.primary` | `#000000` | |
| `HomeHeaderText.secondary` | `#3C3C43` al 60% | "SEPTEMBER" / "2026" a la derecha |

### Tipografía (Inter, line-height 100%)

| Estilo | Tamaño / peso | Dónde |
|---|---|---|
| `h1` | 34 / Bold | "Friday 17" (Home), cifra de SOBRANTE |
| `h2` | 22 / Semibold | mensaje dinámico de Home; **"September" es 22 / Bold** |
| `h3` | 20 / Semibold | — |
| `h4` | 17 / Semibold | "Sobrante" |
| `p big` | 17 / Regular | filas (nombre + monto), "Next Month", "$2,750.00" en quick-balance |
| `p normal` | 15 / Regular | — |
| `p small` | 12 / Regular | "2026" (Semibold), píldora "1 – 15" (Semibold) |
| `h5` fijo | 14 / Semibold | "TOTAL INCOME / TOTAL EXPENSES" (**Bold** en Figma) |
| sección | **18 / Bold, tracking 0.6** | "INCOME" / "EXPENSES" en Quincena (el quick-balance de Home usa 14 / Bold, tracking 0.6) |

### Radios

| Elemento | Radio |
|---|---|
| Cards contenedoras (INCOME card / EXPENSES card) | **24** |
| Filas, SOBRANTE, Next Month, cajas quick-balance | **20** |
| Elementos internos | 12 |
| Píldoras "2026" / "1 – 15", CTA/chips, TabBar | 999 (cápsula) |
| Card negro de Home (solo esquinas superiores) | **35** |

---

## 2. HOME — frame `81:2` (393 × 999)

Layout raíz: columna, `justify-end`, **gap 131** entre el bloque blanco y el card negro, `padding-top 45`.

### 2a. Bloque blanco `intr` (`87:3`) — fondo `#FFFFFF`, padding 16, gap 40, columna

1. **`top`** (`172:89`): fila alineada a la derecha → ícono `gearshape.fill` 25.77 × 25.77, negro.
2. **`date`** (`90:45`): fila `space-between`, centrada vertical.
   - Izq: **"Friday 17"** — 34 / Bold, negro.
   - Der: columna alineada a la derecha, 17 pt, negro: **"SEPTEMBER"** (Regular) sobre **"2026"** (Semibold).
3. **`resume`** (`90:49`): `padding-y 25`, gap 10.
   - Texto del mensaje: **22 / Semibold**, negro, ancho completo, multilínea.
     Copy de muestra: *"This biweekly, you have 3 pending payments. You need to pay 2 credit cards, and you loans are 30% paid, and credit cards are 30% full."*
   - **En el app real** las cifras dentro del mensaje van en naranja `#F04200` (p. ej. el "4" en "just **4** more payments") — Figma no lo pinta, el código sí.

### 2b. Card negro `preview-screen` (`87:2`)

Fondo `#000000`, borde 1 pt `#000000`, **radio 35 solo arriba**, `padding-top 20`, `padding-x 16`, gap 16, ancho completo, columna centrada.

1. **Drag handle**: línea/cápsula **100 × 4**, color `#252525`, centrada.
2. **`Header`** (`161:97`): columna centrada, gap 8.
   - Píldora "**2026**": 12 / Semibold, blanco, `padding-x 12`, radio 50, sin fondo.
   - `TitleRow` alto 34: "**September**" 22 / Bold, blanco, centrado (sin chevrones en Home).
   - Píldora "**1 – 15**": 12 / Semibold, texto y borde 1 pt `#01F98E`, `padding 4 × 12`, radio 50, sin fondo.
3. **`Content`** (`161:223`): columna, gap 24, ancho completo.
   - **`quick-balance`** (`161:224`): fila, gap 16, dos columnas iguales (`flex 1`), cada una gap 8:
     - título "INCOME" / "EXPENSES": 14 / Bold, tracking 0.6, `#A8A8A8`, centrado, `padding-x 8`.
     - caja `row`: fondo `#2A2A2A`, radio 20, padding 16, monto **17 / Regular** blanco (`$2,750.00`), INCOME alineado a la derecha, EXPENSES centrado.
   - **`balance`** (`161:297`): columna, gap 8:
     - **SOBRANTE**: fondo `#006338`, radio 20, **padding 20**, fila `space-between`: "Sobrante" 17 / Semibold + "**$2,828.80**" 34 / Bold, ambos `#01F98E`.
     - **Next Month**: fondo `#006338`, radio 20, padding 16, fila `space-between`: "Next Month" / "$6,078.80", 17 / Regular, `#01F98E`.
   - **`TabBar`** (`161:308`): cápsula radio 999, fondo `rgba(60,60,60,0.85)`, `padding 12 × 24`, gap 30, tres íconos SF blancos: `calendar` 25.05 × 22.23 · `arrow.trianglehead.2.clockwise.rotate.90` 30.68 × 25.09 · `menucard` 20.6 × 28.47.
     - **App real** (difiere de Figma): tres tabs `house.fill` (activo, naranja `#F04200` con cápsula de fondo `#3C3C3C`) · `calendar` · `menucard`; el TabBar es Liquid Glass flotante.

---

## 3. QUINCENA — frame `8:2` (393 × 1073)

Layout raíz: fondo `#000000`, columna centrada, `padding 59 top / 16 x / 24 bottom`, **gap 48** entre Header y Content.

### 3a. `Header` (`128:66`) — columna centrada, gap 8, ancho completo

- Píldora "**2026**": 12 / Semibold, blanco, `padding-x 12`, radio 50.
- `TitleRow` alto 34, fila `space-between`:
  - `chevron.backward.circle.fill` 24.94 × 24.60 (izq) · "**September**" 22 / Bold blanco (centro) · `chevron.right.circle.fill` 24.94 × 24.60 (der).
  - **App real (2026-09-22):** los chevrones están **ocultos** (`showsChevronButtons = false`); la navegación es por **swipe horizontal sobre todo el header** (izq→der = siguiente quincena, der→izq = anterior). Tap en el título abre "Ir a quincena". Además hay un **drag handle 100 × 4 `#252525`** arriba del "2026" (Figma no lo tiene en esta pantalla).
- Píldora "**1 – 15**": borde 1 pt `#01F98E`, texto 12 / Semibold `#34C759`, `padding 4 × 12`, radio 50.
- **App real:** este header es *sticky* con fondo **Liquid Glass** (`.ultraThinMaterial` + tinte negro 35 %, máscara de degradado que se disuelve en el 18 % inferior) para que el contenido se vea borroso detrás al scrollear. En Figma es negro plano. En Paper: material/blur si lo soporta; si no, negro `#000000`.

### 3b. `Content` (`57:80`) — columna centrada, gap 24, ancho completo

#### INCOME card (`12:7`) — fondo `#161617`, radio **24**, padding 16, gap 24
- **`title`** fila `space-between`, `padding-x 8`: "**INCOME**" 18 / Bold, tracking 0.6, `#A8A8A8` · `plus.circle.fill` 24.58 × 24.59.
  - **App real:** el "+" es un botón `.glass` circular con `plus` plano (no `.circle.fill`).
- **`rows`** columna, gap 8. Cuatro estados de fila (todas radio 20, padding 16, texto 17 / Regular, fila `space-between` nombre / monto):
  1. `row.done` — fondo `#006338`, texto `#14332B`, monto **tachado**. ("WALO" / "$2,750.00")
  2. `row` + swipe **check** revelado — contenedor fondo `#34C759`; la fila (`#3C3C3C`, blanco) queda a 259 pt de ancho y a la derecha aparece `checkmark` 21.31 × 21.82 blanco centrado.
  3. `row.done` + swipe **X** revelado — contenedor fondo `#FF5053`; la fila hecha (`#006338`, `#14332B` tachado) a 259 pt y `xmark` 19.76 × 19.78 blanco a la derecha.
  4. `row.normal` — fondo `#3C3C3C`, texto blanco. ("WALO" / "$2,750.00")
- **`total`** fila `space-between`, `padding-x 8`: "**TOTAL INCOME**" / "**$2,828.80**", 14 / Bold, blanco.

#### EXPENSES card (`11:69`) — idéntico al de INCOME
- "**EXPENSES**" 18 / Bold `#A8A8A8` + `plus.circle.fill`.
- Dos `row.normal` (`#3C3C3C`): "Example" / "$1,000.00" y "Example" / "$250.00".
- "**TOTAL EXPENSES**" / "**$1,250.00**", 14 / Bold.
- **App real:** aquí también viven las filas agregadas de navegación "Essentials", "Payments", "Servicios", "Credit Cards Payments", "Investments" (mismo estilo `row.normal`, tap abre un sheet de desglose; sin swipe).

#### `balance` (`87:24`) — columna, gap 8
- **SOBRANTE** (`107:27`): igual que en Home — `#006338`, radio 20, padding 20, "Sobrante" 17 / Semibold + "$2,828.80" 34 / Bold, `#01F98E`.
- **Next Month** (`8:38`): `#006338`, radio 20, padding 16, "Next Month" / "$6,078.80" 17 / Regular `#01F98E`.

#### `TabBar` (`8:48`) — igual que en Home (cápsula `rgba(60,60,60,0.85)`, padding 12 × 24, gap 30, mismos tres íconos).

---

## 4. Assets SVG (SF Symbols)

Todos son SF Symbols — en Paper usar el glyph nativo si está disponible; los tamaños arriba son el bounding box exacto de Figma.

`gearshape.fill` · `calendar` · `arrow.trianglehead.2.clockwise.rotate.90` · `menucard` · `chevron.backward.circle.fill` · `chevron.right.circle.fill` · `plus.circle.fill` · `checkmark` · `xmark` · (app real) `house.fill`, `chevron.backward`, `chevron.forward`, `plus`.

---

## 5. Diferencias Figma ↔ app real a decidir al recrear

| Elemento | Figma | App hoy (2026-09-22) | Sugerencia para Paper |
|---|---|---|---|
| Header Quincena | negro plano, chevrones visibles | Liquid Glass, chevrones ocultos, swipe, drag handle | **App** (es lo vigente) |
| TabBar | `calendar / arrows / menucard` | `house.fill / calendar / menucard`, glass, activo naranja | **App** |
| "+" de sección | `plus.circle.fill` | botón `.glass` con `plus` | **App** |
| Cifras del mensaje Home | negro | naranja `#F04200` | **App** |
| Títulos INCOME/EXPENSES | 18 / Bold | 18 / Bold (se igualó hoy) | igual |

---

## 6. Estado en Paper (recreado 2026-09-22)

Archivo Paper **"Fintrol"** — `01M35T6JJZRV2XETKY8C7K74TA`
→ https://app.paper.design/file/01M35T6JJZRV2XETKY8C7K74TA

| Artboard | Node | Notas |
|---|---|---|
| `Home` | `1-0` | 393 × 999 fijo. Status bar oficial (negro) reemplaza el `padding-top 45`. Card negro `18-0` con `margin-top 66px` + `flex-grow 1` (queda a ~y 497, alto ≈ 500 como Figma). Mensaje `4E-0` es un `flex-wrap` de palabras — Paper no soporta runs de color dentro de un párrafo, así que cada palabra es un Text y las cifras van en `--color-accent`. |
| `01 · Quincena` | `2-0` | 393 × `fit-content` (el 1073 fijo recortaba el TabBar). Status bar oficial (blanco). Header `10-0` con drag handle (versión app, sin chevrones). |

Tokens creados en el archivo (usar `var(--…)`): `--color-app-background`, `--color-app-background-secondary/tertiary`, `--color-section-card`, `--color-text-primary/secondary`, `--color-home-header-bg/text/text-secondary`, `--color-drag-handle`, `--color-accent(-hover)`, `--color-success(-light/-dark/-ios)`, `--color-warning`, `--color-danger(-swipe)`, `--color-tab-bar`, `--radius-inner/row/card/home-card/pill`, `--text-p-small…--text-h1`, `--font-weight-*`, `--font-sans`, `--tracking-caps`.

Limitaciones encontradas: sin blur/material para el header glass (se dejó negro plano, como Figma); iconos SF vienen de los assets SVG de Figma (URLs de 7 días) salvo `house.fill`, que es un SVG inline.

## 7. Referencias

- Screenshots descargados en la sesión anterior: `scratchpad/figma_home.png`, `scratchpad/figma_quincena.png` (temporales — volver a pedir con `get_screenshot` si hacen falta).
- Código fuente que hoy manda: `Apps/Fintrol/Fintrol/Features/Home/HomeView.swift`, `Apps/Fintrol/Fintrol/Features/Period/PeriodView.swift` (`stickyHeader`, `header`, `card(...)`, `aggregateRow(...)`), `Apps/Fintrol/Fintrol/UI/LineItemRow.swift`, `SummaryPanel.swift`, `SobranteBadge.swift`.
- Design system: `DESIGN_LIQUID.md`, `STYLE_BRIEF.md`.
