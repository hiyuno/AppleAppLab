# STYLE_BRIEF — Fintrol

> Brief visual preparado por Steve a partir de referencias del usuario.
> Fecha: 2026-09-15
> Tema elegido: **Fintrol** (`Themes/fintrol.json`, `Themes/THEMES.md`)

## Tono general

Serio pero con carácter. App financiera personal: oscura, densa, un solo acento naranja que se usa para lo que importa (sobrante, acciones primarias). Debe sentirse como una herramienta que se abre dos veces al mes y se entiende en un vistazo, no como un dashboard bancario.

## Referencias

| Referencia | Qué tomar de ella |
|-----------|-------------------|
| Hoja `Mis Finanzas 2.0.xlsx` (screenshots del usuario) | Una quincena = una pantalla completa. Bloques INCOME / EXPENSES apilados, totales al pie de cada bloque, sobrante grande y coloreado, panel lateral de resumen (Overview, USD/Peso, Mandar, Next Month). Filas con marca "pagado". |
| iOS 26 / macOS 26 nativo | Liquid Glass en barras, toolbars y sheets. Listas y formularios del sistema. Nada custom donde el sistema ya lo resuelve. |

## Paleta

- **Accent:** `#F04200` naranja intenso — solo para acción primaria, selección y énfasis.
- **Fondo:** `#323232` gris oscuro neutro. Modo oscuro por defecto; el modo claro debe existir pero no es la referencia.
- **Materiales:** Frost (translúcido con blur 0.5, transparencia 0.5) sobre Liquid Glass nativo.
- **Semántica del sobrante (fija en PRD):** verde ≥ $100 · amarillo $0–$99.99 · rojo < $0. Estos tres colores son sistema (`.green`, `.yellow`, `.red`), no parte del acento.

## Tipografía

SF Pro, peso Regular. Montos con cifras tabulares (`monospacedDigit`). El sobrante es el texto más grande de la pantalla.

## Densidad visual

Regular. Densa como una hoja de cálculo bien hecha, pero con el espaciado del sistema: muchas filas visibles sin scroll en Mac, cómodas al tacto en iPhone.

## Corner style y elevación

Squircle (continuous corners). Elevación flat: la jerarquía se da por material y agrupación, no por sombras.

## Motion

Sutil. Transiciones del sistema. El cambio de color del sobrante puede animarse; nada más llama la atención.

## Restricciones del usuario

- Solo "pagado" por línea; no existe el switch "cuenta / no cuenta" en v1.
- Cada quincena es una pantalla; no dividir ingresos y gastos en tabs distintas.
- USD por defecto; MXN es una opción por línea, no un modo global.
- Sin tarjetas de crédito, sin metas por categoría en v1.
