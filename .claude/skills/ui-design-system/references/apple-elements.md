# Elementos de un design system para apps de iOS y macOS

Investigado el 2026-10-16 en las páginas vivas de la HIG (developer.apple.com/design/human-interface-guidelines/<página>), Apple Design Resources y las sesiones WWDC25 219, 310 y 356. La versión vigente es **iOS/iPadOS 27 y macOS 27** (WWDC26, 8 jun 2026). La HIG no lleva versión: describe el sistema actual.

**Regla de oro:** lo que Apple **no publica como número** (⚠ abajo) se toma del kit oficial 27 o se mide en Xcode. Nunca se escribe de memoria.

**Mínimos del equipo:** las apps soportan iOS 17 / macOS 14. Liquid Glass existe desde iOS 26 / macOS 26. El sistema de diseño dibuja el aspecto con glass y anota el **fallback** (material estándar) para versiones anteriores, que Woz implementa con `if #available`.

---

## 1. Color

**Reglas de la HIG:**
- Nunca fijar los valores de los colores del sistema: cambian entre versiones. En el archivo de diseño son **variables semánticas** con el nombre del sistema.
- Cada color propio tiene variante **clara, oscura y de alto contraste** para cada una.
- No cambiar el significado de un semántico (el separador no es color de texto).
- Ancho de color: Display P3, 16 bits por canal, exportar PNG.

**Colores del sistema iOS** (RGB; claro / oscuro / alto contraste claro / alto contraste oscuro):

| Color | Claro | Oscuro | AC claro | AC oscuro |
|---|---|---|---|---|
| Red | 255,56,60 | 255,66,69 | 233,21,45 | 255,97,101 |
| Orange | 255,141,40 | 255,146,48 | 197,83,0 | 255,160,86 |
| Yellow | 255,204,0 | 255,214,0 | 161,106,0 | 254,223,67 |
| Green | 52,199,89 | 48,209,88 | 0,137,50 | 74,217,104 |
| Mint | 0,200,179 | 0,218,195 | 0,133,117 | 84,223,203 |
| Teal | 0,195,208 | 0,210,224 | 0,129,152 | 59,221,236 |
| Cyan | 0,192,232 | 60,211,254 | 0,126,174 | 109,217,255 |
| Blue | 0,136,255 | 0,145,255 | 30,110,244 | 92,184,255 |
| Indigo | 97,85,245 | 109,124,255 | 86,74,222 | 167,170,255 |
| Purple | 203,48,224 | 219,52,242 | 176,47,194 | 234,141,255 |
| Pink | 255,45,85 | 255,55,95 | 231,18,77 | 255,138,196 |
| Brown | 172,127,94 | 183,138,102 | 149,109,81 | 219,166,121 |

**Grises iOS** (claro / oscuro / AC claro / AC oscuro): Gray 142,142,147 / 142,142,147 / 108,108,112 / 174,174,178 · Gray2 174,174,178 / 99,99,102 / 142,142,147 / 124,124,128 · Gray3 199,199,204 / 72,72,74 / 174,174,178 / 84,84,86 · Gray4 209,209,214 / 58,58,60 / 188,188,192 / 68,68,70 · Gray5 229,229,234 / 44,44,46 / 216,216,220 / 54,54,56 · Gray6 242,242,247 / 28,28,30 / 235,235,240 / 36,36,38.

**Semánticos iOS** (nombres y roles; ⚠ los valores RGBA **no** están en la HIG: léelos de las variables del kit 27):
- Primer plano: `label`, `secondaryLabel`, `tertiaryLabel`, `quaternaryLabel`, `placeholderText`, `separator`, `opaqueSeparator`, `link`.
- Fondos: `systemBackground` / `secondarySystemBackground` / `tertiarySystemBackground` y la serie *Grouped* (`systemGroupedBackground`…). Primario = vista, secundario = grupos dentro, terciario = grupos dentro del secundario.
- Modo oscuro: fondos **base** (más oscuros) y **elevated** (más claros); sheets y popovers pasan a elevated solos.

**Semánticos macOS** (AppKit): `labelColor` y sus niveles, `controlColor`, `controlBackgroundColor`, `controlTextColor`, `disabledControlTextColor`, `controlAccentColor`, `selectedContentBackgroundColor`, `unemphasizedSelectedContentBackgroundColor`, `selectedTextBackgroundColor`, `keyboardFocusIndicatorColor`, `separatorColor`, `gridColor`, `headerTextColor`, `windowBackgroundColor`, `underPageBackgroundColor`, `textColor`, `textBackgroundColor`, `alternatingContentBackgroundColors`, `findHighlightColor`, `linkColor`, `placeholderTextColor`, `shadowColor`.

**Acento:**
- iOS: el acento de la app.
- macOS: el acento de la app **solo** se ve si el usuario eligió acento **multicolor**; cualquier otro lo reemplaza. Grafito activa el tintado del escritorio en los fondos de ventana. El archivo muestra el acento propio y anota esta regla.
- Liquid Glass no tiene color propio. Se tinta **con moderación**, solo la acción principal, y el tinte va en el **fondo** del control, no en su etiqueta. En apps con contenido colorido, barras monocromas.

## 2. Tipografía

- Familias: **SF Pro** (y SF Pro Rounded) en iOS y macOS; **New York** serif (en macOS solo vía Catalyst); SF Mono. Variables con tamaños ópticos, pesos Ultralight→Black y anchos Condensed→Expanded. Evitar Ultralight, Thin y Light en tamaños chicos.
- Tamaño por defecto y mínimo: iOS 17 / 11 pt · macOS 13 / 10 pt.

**Estilos iOS** (tamaño Large por defecto; peso / tamaño / interlineado / peso enfatizado):

| Estilo | Peso | Tamaño | Interlineado | Enfatizado |
|---|---|---|---|---|
| Large Title | Regular | 34 | 41 | Bold |
| Title 1 | Regular | 28 | 34 | Bold |
| Title 2 | Regular | 22 | 28 | Bold |
| Title 3 | Regular | 20 | 25 | Semibold |
| Headline | Semibold | 17 | 22 | Semibold |
| Body | Regular | 17 | 22 | Semibold |
| Callout | Regular | 16 | 21 | Semibold |
| Subhead | Regular | 15 | 20 | Semibold |
| Footnote | Regular | 13 | 18 | Semibold |
| Caption 1 | Regular | 12 | 16 | Semibold |
| Caption 2 | Regular | 11 | 13 | Semibold |

**Estilos macOS** (sin Dynamic Type):

| Estilo | Peso | Tamaño | Interlineado | Enfatizado |
|---|---|---|---|---|
| Large Title | Regular | 26 | 32 | Bold |
| Title 1 | Regular | 22 | 26 | Bold |
| Title 2 | Regular | 17 | 22 | Bold |
| Title 3 | Regular | 15 | 20 | Semibold |
| Headline | **Bold** | 13 | 16 | Heavy |
| Body | Regular | 13 | 16 | Semibold |
| Callout | Regular | 12 | 15 | Semibold |
| Subheadline | Regular | 11 | 14 | Semibold |
| Footnote | Regular | 10 | 13 | Semibold |
| Caption 1 | Regular | 10 | 13 | Medium |
| Caption 2 | Medium | 10 | 13 | Semibold |

**Dynamic Type (iOS):** xSmall, Small, Medium, **Large** (default), xLarge, xxLarge, xxxLarge y de accesibilidad AX1–AX5. Body: 14/15/16/**17**/19/21/23 y AX 28/33/40/47/53 pt; Large Title llega a ~60–70 en AX5. El archivo documenta al menos **Large** y **AX3** de las pantallas clave. Soportar ampliación de al menos 200%.

**Tracking — hay que ponerlo a mano.** El sistema ajusta el tracking por tamaño; Figma y Pen no. SF Pro (1/1000 em → pt): 11 pt +6 → +0.06 · 12 pt 0 · 13 pt −6 → −0.08 · 15 pt −16 → −0.23 · 17 pt −26 → −0.43 · 20 pt −23 → −0.45 · 22 pt −12 → −0.26 · 28 pt +14 → +0.38 · 34 pt +12 → +0.40. SF Pro Rounded y New York tienen tablas propias en la HIG /typography.

**Fuente en el archivo:** SF Pro instalada en la Mac (developer.apple.com/design/resources). Licencia: solo maquetas de software para plataformas Apple; no web ni otras plataformas. Si no está disponible (Pen sin fuente custom cargada), Inter con los **mismos tamaños, interlineados y tracking** de las tablas, anotado en la portada.

## 3. Layout y espaciado

- Diseñar por **size classes** (compact / regular), no por dispositivo. Respetar safe areas, márgenes y la guía de ancho legible.
- Separar controles del contenido con **glass + scroll edge effect**, no con un fondo sólido detrás. Los fondos a sangre corren bajo sidebar, toolbar y tab bar.
- **Tamaño de controles:** iOS/iPadOS 44×44 pt por defecto, mínimo 28×28 · macOS 28×28 por defecto, mínimo 20×20.
- **Separación entre controles:** ~12 pt alrededor de elementos con borde; ~24 pt alrededor de los que no tienen.
- macOS: controles e información clave lejos del borde inferior; nada detrás de la cámara; ventanas con toolbar tienen radio mayor que las de solo título.
- ⚠ No publicados: márgenes estándar de iOS (16 o 20), ancho legible, escala de espaciado. Mídelos en el kit 27. **Escala del equipo** mientras tanto: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48.

## 4. Forma y concentricidad (WWDC25 356)

- Tres tipos: **fijo** (radio constante), **cápsula** (radio = mitad de la altura), **concéntrico** (radio del padre − padding).
- iPhone: cápsula con margen extra cerca del borde de pantalla. iPad y Mac: concéntrico alineado a la esquina de la ventana.
- "Concéntrico con radio de respaldo" para componentes que aparecen anidados y sueltos. Código: `ConcentricRectangle`, `.containerShape()`, `concentric(minimum:)`.
- Esquinas **continuas** (squircle), nunca circulares.
- ⚠ Apple no publica radios. Sheets y secciones de lista tienen radios "mayores": mídelos en el kit.

## 5. Materiales

**Dos familias:**
- **Liquid Glass** — capa funcional que flota sobre el contenido: tab bar, toolbars, barras de navegación, sidebars, sheets, popovers, menús, alerts, controles destacados. **Nunca en la capa de contenido.** Evitar glass sobre glass.
- **Materiales estándar** — capa de contenido. iOS: ultraThin, thin, **regular** (default), thick. Vibrancy: etiquetas label → quaternary (evitar quaternary sobre thin y ultraThin), rellenos fill/secondaryFill/tertiaryFill, separador. macOS: `NSVisualEffectView` con mezcla behind-window o within-window.

**Variantes de glass:** **Regular** (default, adaptable; siempre que haya texto) · **Clear** (muy translúcido, solo sobre media rica, contenido encima brillante y en negrita; capa oscura de **35%** si el fondo es claro) · tinte e interactivo como modificadores.

**Agrupar:** los ítems agrupados comparten un vidrio (`GlassEffectContainer`, `ToolbarSpacer` entre grupos). No mezclar texto e íconos en un grupo. La acción principal (Done) aparte, tintada, al final. Títulos de toolbar de menos de 15 caracteres.

**Scroll edge effect:** `soft` (típico iOS) o `hard` (macOS: texto, encabezados fijos de tabla, controles sin fondo). Uno por vista, solo bajo UI flotante.

**Accesibilidad automática del glass:** Reduce Transparency → más esmerilado y opaco; Increase Contrast → casi negro o blanco con borde; Reduce Motion → menos efecto, sin elasticidad.

⚠ Apple **no publica** blur ni opacidad del glass, y en iOS 27 el usuario puede ajustar su aspecto en Ajustes (la prensa reporta un control de "ultra claro" a "tintado"; la HIG solo dice que puede elegir el aspecto). En el archivo el glass es **un componente con propiedades**, no una opacidad fija: variante regular/clear, apariencia clara/oscura según el fondo, tinte ninguno/acento, estado reposo/presionado, y versiones Reduce Transparency e Increase Contrast. Siempre se muestra **sobre contenido de ejemplo**.

**Preferencia del usuario:** el material de ventana del tema (`windowMaterial`: Frost o Liquid) y su transparencia mandan en las apps de AppleAppLab (ver `PREFERENCES.md`).

## 6. Profundidad y sombras

La elevación sale de las capas de glass y de los fondos base/elevated, no de una escala de sombras. ⚠ Apple no publica escala de elevación; el glass dibuja su propia sombra. El tema del equipo tiene `elevation` (flat…): respétalo y no inventes sombras para dar jerarquía.

## 7. Movimiento

- Con propósito, breve, cancelable y opcional.
- Tokens como **duración + rebote** (springs), no curvas bezier. Default SwiftUI `spring(duration: 0.5, bounce: 0)`; presets `.smooth` (sin rebote), `.snappy` (poco), `.bouncy` (más).
- Reduce Motion: springs más firmes, desplazamientos cambiados por fundidos, sin animar blur ni profundidad.
- En el archivo se **anotan**, no se dibujan. Figma tiene variables Timing y Easing para guardarlos.

## 8. Íconos — SF Symbols

- Nueve pesos (igual que SF) y tres escalas (small, **medium**, large) relativas a la altura de mayúscula. El símbolo toma el peso del texto que acompaña.
- Modos de render: monochrome, **hierarchical**, palette, multicolor y gradiente.
- Variable color para valores de 0 a 100%, no para profundidad.
- Animaciones: Appear, Disappear, Bounce, Scale, Pulse, Variable Color, Replace, Magic Replace, Wiggle, Breathe, Rotate, **Draw On/Off**, Variable Draw.
- Más de 7,000 símbolos. App SF Symbols para buscar nombres (⚠ el nombre de versión aparece como "8" y como "27").
- En el archivo, siempre el **nombre** del símbolo (Figma lo inserta por nombre; en Pen se usa el equivalente lucide/phosphor y se anota el SF Symbol).

## 9. Ícono de la app

Capas (fondo + primer plano) hechas en **Icon Composer 2**. El sistema agrega brillos, refracción, sombra y desenfoque: **no se hornean**. Capas vectoriales (SVG/PDF) o PNG para degradados, cuadradas y sin máscara. **1024×1024 px** para iOS, iPadOS y macOS, con apariencias **Default, Dark, Clear light, Clear dark, Tinted light, Tinted dark**. Plantilla oficial en Figma (ver figma-guide.md). Si el ícono es 3D, lo hace Ed.

## 10. Accesibilidad como parte del sistema

- Contraste mínimo 4.5:1 para texto hasta 17 pt; 3:1 para 18 pt o más, o negrita; ideal 7:1 para texto chico en colores propios. Revisar en claro y oscuro; si no se alcanza, modo de alto contraste.
- Objetivos táctiles de la sección 3.
- Bold Text, Reduce Transparency, Reduce Motion e Increase Contrast tienen su versión en el archivo cuando cambian el aspecto de un componente.
- Sarah revisa el sistema antes de las pantallas.

## 11. Componentes que el sistema debe cubrir

Instanciar del kit lo que es del sistema; construir como componente propio lo que la app personaliza (los `Lab*`). Cada uno con sus **estados**: normal, presionado, deshabilitado, seleccionado, foco; en macOS además **hover** y **anillo de foco de teclado** (`keyboardFocusIndicatorColor`; anillo en campos, resaltado en filas; fila con foco = fondo acento y texto blanco). Los de glass, además, apariencia clara/oscura y estado enfatizado (tintado).

| Componente | Lo que debe tener |
|---|---|
| **Botón** | Roles normal, primario (acento, Return), cancelar, destructivo (rojo, nunca primario). Estilos plain, bordered, borderedProminent, glass, glassProminent. Tamaños mini, small, regular, large, extraLarge. Indicador de actividad dentro (iOS). macOS: push con "…" si abre otra vista, square en vistas, help, tooltip al hover. La preferida se distingue por estilo, no por tamaño |
| **Campo de texto y búsqueda** | Placeholder, botón de borrar, anillo de foco (macOS), error. Búsqueda con scope y tokens; en iOS la búsqueda puede ser pestaña al final del tab bar y sube con el teclado. **Estado de foco obligatorio** (problema repetido en las apps del usuario) |
| **Toggle** | iOS: switch solo en filas de lista (verde por defecto o acento); fuera de listas, botón tipo toggle. macOS: switch para énfasis, mini switch en formularios, checkbox con on/off/mixto, radio para 2–5 opciones; nunca en toolbars |
| **Segmented, picker, slider, stepper** | Segmented: ~5 segmentos en iPhone, 5–7 en anchos; texto o ícono, no ambos; ancho igual. Slider: el knob se vuelve glass al arrastrar; macOS con marcas y circular |
| **Listas, tablas y formularios** | Filas más altas y secciones más redondeadas; encabezados de sección en **Title Case**, no mayúsculas. macOS: filas alternas, selección destacada y selección sin énfasis en ventanas inactivas |
| **Barras y navegación** | iOS: barra de navegación y toolbar en glass con ítems agrupados; **tab bar flotante** en glass que se minimiza al hacer scroll, con accesorio inferior y badges. iPad: `sidebarAdaptable`. Sidebar: panel de glass flotante; macOS con tamaños de fila small/medium/large y íconos en acento. Inspector en glass de borde a borde |
| **Presentación** | Sheets con detents medium/large, grabber si cambia de tamaño, media hoja separada del borde y más opaca al crecer. macOS: sheet como tarjeta que oscurece la ventana; panel si se repite la entrada. Popovers, alerts, menús y context menus en glass; ítems no disponibles atenuados; "…" si piden más datos |
| **Progreso y estados vacíos** | Barra determinada, spinner, actividad en botón. Estado vacío según `ContentUnavailableView` (la HIG no tiene página propia) |

## 12. Diferencias iOS ↔ macOS que el sistema codifica

| Área | iOS / iPadOS | macOS |
|---|---|---|
| Entrada | Toque, 44 pt; en iPad, puntero con highlight y hover | Puntero, 28 pt, tooltips, anillo de foco, acceso total por teclado |
| Texto | Dynamic Type, Body 17 | Sin Dynamic Type, Body 13, Headline Bold 13 |
| Controles | Tendencia a cápsula, tamaños táctiles | mini/small/medium rectángulo redondeado (un poco más altos desde 26); large/extraLarge cápsula. ⚠ alturas no publicadas: mide en el kit |
| Ventana | Tab bar flotante, barra de navegación | Toolbar unificada en glass sobre el contenido, sidebar en glass, radio según toolbar, ventana activa/principal/inactiva (la inactiva pierde materiales) |
| Menús | Context menus; barra de menús en iPad | Barra de menús con App, File, Edit, Format, View, Window, Help; extras de 24 pt |
| Acento | El de la app | El del usuario manda salvo multicolor |
| Scroll edge | Soft | Hard frecuente |

Un archivo que diseña para las dos plataformas lleva modos o colecciones `iOS · macOS` para tamaños de texto y controles, y pantallas separadas por plataforma.

## 13. Recursos oficiales

| Recurso | Dónde |
|---|---|
| Kit iOS y iPadOS 27 (Figma / Sketch) | figma.com/community/file/1651309003795292092 · sketch.com/s/04c24d8b-38fb-4afb-8836-36617e022f02 |
| Kit macOS 27 (Figma / Sketch) | figma.com/community/file/1651309434229735362 · sketch.com/s/57153a31-3379-4737-8ac6-dbfd6525f052 |
| Plantilla de ícono 27 (Figma) | figma.com/community/file/1645923469870515372 |
| Fuentes SF Pro, SF Compact, SF Mono, New York | developer.apple.com/design/resources |
| SF Symbols (requiere macOS Sonoma+) | developer.apple.com/sf-symbols |
| Icon Composer 2 (requiere macOS Sequoia+) | developer.apple.com/icon-composer |
| HIG | developer.apple.com/design/human-interface-guidelines |
| Investigación previa del equipo | `Research/apple-hig/` (01-foundations, 03-components, 10-platform-differences…) |

## Lo que no se pudo verificar

Valores RGBA de label/fondos/separador · radios de esquina · márgenes y escala de espaciado de iOS · alturas de controles en macOS 26+ · blur y opacidad del glass · nombre de versión de SF Symbols · el control de Liquid Glass de iOS 27 (solo prensa) · escala de sombras. Todo eso se mide en el kit 27 o en Xcode y se anota en la portada del archivo con su fuente.
