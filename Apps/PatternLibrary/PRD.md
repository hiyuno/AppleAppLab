# PRD — AppleAppLabUI + Pattern Library

> Última actualización: 2026-08-24. Versión: 0.1
> Todo lo que no está aquí no está definido.

---

## Resumen

**One-liner:** El design system nativo de AppleAppLab — una librería de componentes SwiftUI con su propio catálogo interactivo para pulir cada patrón antes de que se vuelva el default de toda app futura.

**El problema:** Cada app nueva reinventa botones, sheets, cards y animaciones desde cero — tiempo perdido en decisiones ya tomadas, e inconsistencia visual entre apps del laboratorio.

**Usuario objetivo:** Yuno y el equipo de agentes (Woz, Jonny) al arrancar cualquier app nueva de AppleAppLab.

---

## Plataforma y distribución

- **Plataforma:** macOS
- **Versión mínima:** macOS 14
- **Distribución:** Directa, uso interno — no App Store
- **Sync:** No aplica
- **Monetización:** N/A — herramienta interna

---

## Stack preferido

- **Framework:** SwiftUI puro (NavigationSplitView)
- **Arquitectura:** MVVM con `@Observable`
- **Estructura de repo:**
  - `Packages/AppleAppLabUI/` — SPM package: componentes + design tokens
  - `Apps/PatternLibrary/` — app catálogo (Xcode project) que importa el package

---

## Features — MVP

| # | Feature | Por qué en MVP | Criterio de aceptación |
|---|---------|---------------|----------------------|
| 1 | Design tokens (color, tipografía, spacing, motion) | Fundación de todo lo demás | Definidos en `AppleAppLabUI`, usados por al menos un componente |
| 2 | Shell de PatternLibrary (sidebar + detail + inspector) | Valida el pipeline antes de contenido | Sidebar navega entre 10 items, selección muestra área central |
| 3 | Inspector genérico en vivo | Reusado por los 10 patterns, evita 10 inspectores custom | Controles de spacing/radius/color/duración afectan el preview en tiempo real |
| 4 | 10 patterns implementados | Objetivo central del proyecto | Cada uno visible, interactivo y ajustable en el catálogo |
| 5 | Documentación por componente | Para que Woz lo use sin reabrir el catálogo | README por componente en el package |

Patterns (orden de implementación, Botones primero como piloto):
1. Botones y controles
2. Navegación (tabs/sidebar)
3. Listas/tablas
4. Cards
5. Formularios/inputs
6. Sheets/modales/alerts
7. Onboarding
8. Empty states
9. Loading/progress
10. Toggles/segmented controls

---

## Features — Fuera del MVP

- Sync/export de configuraciones del inspector — no aplica, es herramienta local
- Soporte iOS/iPadOS del catálogo — se evalúa después si se necesita

---

## Fases de desarrollo

**Fase 1 — Fundación**
- Meta: Package compilable + tokens base + shell de la app catálogo corriendo
- Estado final: App abre, sidebar con 10 items (placeholders), selección funcional

**Fase 2 — Los 10 patterns**
- Meta: Cada pattern implementado en el package + visible/ajustable con inspector en vivo
- Estado final: Los 10 patterns pulibles visual y funcionalmente sin tocar código

**Fase 3 — Consolidación y adopción**
- Meta: Congelar defaults, documentar, conectar al flujo del equipo
- Estado final: CLAUDE.md y skills de Avie/Woz referencian `AppleAppLabUI` como dependencia por defecto; package taggeado `v0.1`

---

## Riesgos

- Parálisis por pulido infinito — mitigación: congelar cada pattern al cierre de Fase 2
- Inspector en vivo más complejo que los patterns mismos — mitigación: inspector genérico reusado, no uno custom por patrón
- Drift entre el package y apps que ya lo importaron — mitigación: versionar con tags desde el día 1

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-08-24 | macOS nativo (no universal) | Coincide con el uso real: ventana + sidebar, iteración rápida |
| 2026-08-24 | Swift Package local en este repo | Un solo lugar de verdad, fácil de versionar y actualizar |
| 2026-08-24 | Inspector con controles en vivo | Pulido inmediato sin recompilar |
| 2026-08-24 | Estructura `Packages/` + `Apps/` | Escala a futuras apps del laboratorio sin reestructurar |
| 2026-08-24 | Pattern 11 agregado: Todo list (drag & drop) | Pedido explícito del usuario; usa `.draggable`/`.dropDestination` (Transferable) en vez de `List.onMove` para demostrar drag and drop real, reusable en apps con listas reordenables |
