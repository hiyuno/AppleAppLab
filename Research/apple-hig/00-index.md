# Apple Human Interface Guidelines — Resumen Ejecutivo

**Fuente principal**: https://developer.apple.com/design/human-interface-guidelines/

**Fecha de última recolección**: 2026-08-24 (Pasada 3 completada)

**Scope**: Foundations completas + Patterns esenciales (~90%) + Components core (~85%) + Diferencias iOS/macOS.

---

## Tabla de Contenidos

### Pasada 1 (Foundations + Patterns/Components Base)

1. **01-foundations.md** — Foundations (Accesibilidad, Color, Tipografía, Layout, Inclusion, Branding)
2. **02-patterns.md** — Patterns base (Data Entry, Split Views, Onboarding)
3. **03-components.md** — Components core (Buttons, Text Fields, Tab Bars, Alerts, Sheets)

### Pasada 2 (Patterns + Components + Plataforma)

4. **05-patterns-search.md** — Searching & Navigation Patterns (Search bars, search fields, search behavior, iOS 26 updates)
5. **06-patterns-auth.md** — Authorization & Sign-In Patterns (Sign in with Apple, biometric, OAuth, account recovery)
6. **07-patterns-sharing.md** — Sharing & Collaboration Patterns (Share sheet, AirDrop, direct sharing, real-time collaboration)
7. **08-components-input.md** — Input Components (Toggle, Picker, DatePicker, Stepper, Slider)
8. **09-components-menus.md** — Menu & Navigation Components (Menu, Context Menu, Toolbar, Navigation Bar, Sidebar, Tab Bar, Segmented Control)
9. **10-platform-differences.md** — iOS vs macOS Differences (Navigation, menus, text input, multitasking, keyboard, window management, accessibility)

### Pasada 3 (Patterns Avanzados + Components Especializados) — ✓ COMPLETADA

10. **11-patterns-dragdrop.md** — Drag and Drop (Multi-item, undo, accessibility, iOS vs macOS)
11. **12-patterns-tasks.md** — Managing Tasks (Undo/redo, notifications, task completion, sync patterns)
12. **13-patterns-permissions.md** — System Permissions (Camera, location, contacts, photos, microphone, iOS 14+ limited access)
13. **14-patterns-confirmations.md** — Confirming User Actions (Destructive, costly actions, undo patterns, forgiveness)
14. **15-patterns-choices.md** — Offering Choices (Radio buttons, checkboxes, toggles, selection controls)
15. **16-patterns-disclosure.md** — Progressive Disclosure (Expandable, tabs, help buttons, conditional fields)
16. **17-components-progress-list.md** — ProgressView & List/Table (Determinate/indeterminate progress, list styles, sorting, selection)

---

## Resumen Ejecutivo

Las Apple HIG son un documento vivo que cubre design principles y technical guidance para todas las plataformas Apple (iOS, iPadOS, macOS, watchOS, tvOS, visionOS).

### Por qué importa para SwiftUI developers:

- **Foundations** establecen principios que trascienden plataformas: accesibilidad no es optional, dark mode es obligatorio, Dynamic Type es crítico.
- **Patterns** enseñan cuándo usar cada estructura de navegación (tabs vs sidebars, sheets vs full-screen) y flujos comunes (sign-in, search, sharing, permisos).
- **Components** documentan el comportamiento esperado de UI elements — no solo cómo verlos, sino cómo se comportan, qué estados tienen, cuándo deshabilitados.
- **Plataforma** — iOS y macOS tienen paradigmas diferentes que requieren adaptación de diseño, no simple porting.

### Estructura clave de AppleAppLab:

Este conocimiento se reparte entre agentes especializados:
- **Jonny** (diseño): Foundations + Patterns + Components → decisiones de diseño UI/UX.
- **Woz** (código): Components + plataforma-specific → implementación en SwiftUI.
- **Larry** (HIG reviewer): Guardián de compliance con Apple HIG, revisa contra este documento.
- **Sarah** (accesibilidad): Foundations + Accessibility en cada componente.
- **Chris** (compatibilidad): Plataforma-specific differences para asegurar iOS/macOS funcionan bien.
- **Kate** (legal & compliance): Privacy Policy implications de permisos y datos sensibles.

---

## Cobertura Completada (Pasadas 1-3)

### ✓ Foundations (Pasada 1 — 100%)

- Accesibilidad (VoiceOver, Dynamic Type, focus, color contrast, motor accessibility)
- Color (paletas, dark mode, semantic colors)
- Tipografía (system fonts, sizes, weights, legibilidad)
- Layout (safe area, spacing, adaptive layouts)
- Inclusion & Internationalization
- Branding & Language

### ✓ Patterns (Pasadas 1-3 — ~90%)

- **Pasada 1**: Data Entry, Split Views, Onboarding
- **Pasada 2**: Searching & Navigation, Authorization & Sign-In, Sharing & Collaboration
- **Pasada 3**: ✓ Drag and Drop, ✓ Managing Tasks, ✓ System Permissions, ✓ Confirming Actions, ✓ Offering Choices, ✓ Progressive Disclosure
- **Pendiente Pasada 4+**: Widgets, Live Activities, SharePlay, Handoff, Focus Modes, etc. (platform-specific technologies)

### ✓ Components (Pasadas 1-3 — ~85%)

- **Pasada 1**: Buttons, Text Fields, Tab Bars, Alerts, Sheets
- **Pasada 2**: 
  - Input: Toggle, Picker, DatePicker, Stepper, Slider
  - Navigation: Menu, Context Menu, Toolbar, Navigation Bar, Sidebar, Tab Bar, Segmented Control
- **Pasada 3**: ✓ ProgressView (determinate & indeterminate), ✓ List & Table (styles, selection, sorting)
- **Pendiente Pasada 4**: ColorPicker, Media pickers, AppKit-specific components

### ✓ Plataforma-Specific (Pasada 2 — iOS vs macOS — 100%)

- Navigation patterns (tab bar vs sidebar)
- Menus (bottom sheet vs menu bar)
- Text input & keyboard
- Multitasking & windows
- UI density & layout
- Accessibility emphasis differences
- Keyboard support
- Checklists per plataforma

---

## Cobertura por Archivo (Quick Reference)

| Archivo | Tema | Estado | Agentes clave |
|---------|------|--------|---------------|
| 01-foundations.md | Accessibility, Color, Type, Layout, Inclusion | ✓ Completo | Jonny, Sarah, Woz |
| 02-patterns.md | Data Entry, Split Views, Onboarding | ✓ Pasada 1 | Jonny |
| 03-components.md | Buttons, TextFields, TabBar, Alerts, Sheets | ✓ Pasada 1 | Jonny, Woz |
| 05-patterns-search.md | Searching, Navigation, Search Bars | ✓ Pasada 2 | Jonny, Woz |
| 06-patterns-auth.md | Sign-in, Authorization, Biometric | ✓ Pasada 2 | Jonny, Ivan (security) |
| 07-patterns-sharing.md | Sharing, AirDrop, Collaboration | ✓ Pasada 2 | Jonny, Woz |
| 08-components-input.md | Toggle, Picker, DatePicker, Stepper, Slider | ✓ Pasada 2 | Jonny, Woz |
| 09-components-menus.md | Menu, Context Menu, Toolbar, Sidebar, TabBar | ✓ Pasada 2 | Jonny, Woz, Chris |
| 10-platform-differences.md | iOS vs macOS: Navigation, Menus, Keyboard, Windows | ✓ Pasada 2 | Jonny, Woz, Chris |
| **11-patterns-dragdrop.md** | **Drag & Drop, undo, accessibility** | **✓ Pasada 3** | **Jonny, Woz, Sarah** |
| **12-patterns-tasks.md** | **Tasks, undo/redo, notifications, sync** | **✓ Pasada 3** | **Jonny, Woz, Tim** |
| **13-patterns-permissions.md** | **System permissions, camera, location, privacy** | **✓ Pasada 3** | **Jonny, Ivan, Kate** |
| **14-patterns-confirmations.md** | **Destructive actions, undo, forgiveness** | **✓ Pasada 3** | **Jonny, Woz** |
| **15-patterns-choices.md** | **Radio, checkbox, toggle, selection controls** | **✓ Pasada 3** | **Jonny, Woz** |
| **16-patterns-disclosure.md** | **Progressive disclosure, accordion, tabs** | **✓ Pasada 3** | **Jonny, Woz** |
| **17-components-progress-list.md** | **ProgressView, List, Table, sorting** | **✓ Pasada 3** | **Jonny, Woz** |

---

## Qué Quedó Pendiente (Pasada 4+)

### Components Especializados (Pasada 4 — Baja Urgencia)

- **ColorPicker** — Color selection UI
- **Media pickers** — Image/video pickers, galleries, media players
- **AppKit-specific** — NSView, NSViewController integration (macOS only)

### Platform-Specific Technologies (Pasada 4+ — Solo si necesario)

**iOS-Specific** (no urgente hasta que feature lo requiera):
- Widgets — Home screen, lock screen widgets
- App Clips — Lightweight app experiences
- Shortcuts — Siri Shortcuts integration
- Live Activities — Live data on lock screen / Dynamic Island
- Background Modes — Background fetch, processing, downloads

**macOS-Specific** (no urgente):
- Menu Bar — Menu bar apps, status items
- Window Management — Tabs, resizing, full-screen, Stage Manager
- Keyboard Shortcuts — Command key patterns
- Dock Integration — Dock icon, context menu

**Cross-Platform Advanced** (no urgente):
- SharePlay — Collaborative experiences, shared playback
- Handoff — Continuity between devices, resume on Mac
- Universal Clipboard — Copy/paste across devices
- Siri Integration — Voice commands, custom intents
- Focus Modes — Do Not Disturb, Sleep, Work, Custom

**Emerging Platforms** (Very Low Priority — solo si app lo requiere):
- watchOS — Complications, glances, watch-specific patterns
- tvOS — Remote control, focus engine, tvOS-specific layouts
- visionOS — Spatial computing, hand gestures, volumetric apps

---

## Notas sobre Fuentes

- **Pasada 1-2**: HIG oficial + WWDC videos + fuentes Apple Developer confiables
- **Pasada 3**: HIG oficial para Drag & Drop; secundarias confiables (Medium, NN/G, Smashing Magazine) para patrones donde HIG no tiene página dedicada actual (tasks, permissions, confirmations, choices, disclosure, progress)
  - Cada archivo marca claramente: "Fuente: primaria (HIG)" vs "Fuente: secundaria — pattern no tiene página dedicada en HIG actual"

---

## Recomendaciones Finales — Qué Agente Usa Esto

### Jonny (Diseño)

**Por qué**: Necesita Foundations + Patterns + Components para diseñar interfaces HIG-compliant.

**Archivos clave**:
- 01-foundations.md — Principios base (color, tipo, layout, accesibilidad).
- 02, 05-16-patterns-*.md — Cuándo usar cada patrón.
- 03, 08, 09, 17-components-*.md — Comportamiento esperado de componentes.
- 10-platform-differences.md — Adaptar diseños entre iOS/macOS.

**Acción**: Consulta cuando diseñar pantallas nuevas. Verificar "¿es el patrón correcto?" y "¿el componente cumple con HIG?" antes de mockups.

---

### Woz (Código)

**Por qué**: Necesita entender comportamiento de componentes + plataforma-specific para implementar en SwiftUI.

**Archivos clave**:
- 03, 08, 09, 17-components-*.md — Comportamiento, estados, accesibilidad.
- 11-16-patterns-*.md § Code Examples — Patrones implementables en SwiftUI.
- 10-platform-differences.md — Cómo SwiftUI varía entre iOS/macOS (conditionals, adapting layouts).
- 01-foundations.md § Accesibilidad — VoiceOver, Dynamic Type, color contrast en código.

**Acción**: Consultar cuando implementar componentes/patrones nuevos. Asegurar SwiftUI code sigue estados y comportamientos documentados.

---

### Larry (HIG Reviewer)

**Por qué**: Es guardián de HIG compliance. Necesita acceso a todo para revisar apps contra el estándar.

**Archivos clave**: Todos. 00-index.md es punto de entrada para auditoría.

**Acción**: Antes de release, Larry revisa app against estos docs. "¿Usa Search patterns correctamente?" "¿El Toggle es accesible?" "¿ProgressView tiene cancel?" "¿Permisos son just-in-time?" etc.

---

### Sarah (Accesibilidad)

**Por qué**: Necesita Foundations accesibilidad + detalles en cada componente.

**Archivos clave**:
- 01-foundations.md § Accesibilidad — VoiceOver, Dynamic Type, motor accessibility, color contrast.
- Cada archivo de pattern/componente tiene sección "Accessibility" (11-17).

**Acción**: Auditar VoiceOver labels, touch targets (44pt+), color contrast (WCAG AA+), keyboard navigation completa, anunciados de ProgressView.

---

### Chris (Compatibilidad)

**Por qué**: Audita compatibilidad en dispositivos reales, OS versions, y diferencias plataforma-specific.

**Archivos clave**:
- 10-platform-differences.md — Comportamiento diferente iOS vs macOS, iPad considerations.
- Cada archivo (11-17) tiene sección "Platform Differences" en componentes/patrones.

**Acción**: Verificar app en iPhone, iPad, Mac. Asegurar iOS navigation stack ≠ macOS sidebar, keyboard nav completa en Mac, drag-drop en ambas, etc.

---

### Ivan (Seguridad)

**Por qué**: Patterns de auth + permissions + sharing tienen implicaciones de seguridad.

**Archivos clave**:
- 06-patterns-auth.md — Sign in with Apple, biometric, session management, re-auth.
- 07-patterns-sharing.md § Security & Privacy — Deep links, permisos, audit trails.
- **13-patterns-permissions.md § Security Considerations** — Permiso solicitation, privacy architecture, no duplicar system alerts.

**Acción**: Revisar auth flows, storage de tokens, encryption, solicitud de permisos just-in-time, privacy compliance.

---

### Kate (Legal & Compliance)

**Por qué**: Permisos de sistema y datos sensibles tienen implicaciones legales (GDPR, CCPA, COPPA).

**Archivos clave**:
- **13-patterns-permissions.md** — Purpose strings, just-in-time requests, privacy layers (on-device vs server).
- 01-foundations.md § Inclusion — Representación y accesibilidad legal.
- 06-patterns-auth.md — Session management, biometric storage.

**Acción**: Verificar Privacy Policy alineada con permisos solicitados. Asegurar just-in-time requests, propósito claro, cumplimiento GDPR/CCPA si aplica.

---

### Tim (Analytics)

**Por qué**: 12-patterns-tasks.md toca notificaciones y task tracking; puede requerir telemetría.

**Archivos clave**:
- **12-patterns-tasks.md § Notificaciones & Task Tracking** — Cómo medir engagement, sin violar privacidad.

**Acción**: Si app tiene task management, considerar qué métricas rastrear (completado, notificaciones entregadas) sin invasor.

---

## Cómo Usar Este Repo

1. **Inicio de feature/screen nueva**: Consulta el patrón relevante (ej. 13-patterns-permissions.md si necesitas acceso a cámara).
2. **Diseño UI**: Jonny consulta componentes (08, 09, 17) + platform-differences (10) para mockups.
3. **Implementación SwiftUI**: Woz consulta secciones "Code Example" en archivos de componentes/patrones.
4. **HIG Review**: Larry consulta archivo completo como checklist pre-release.
5. **Accesibilidad**: Sarah consulta secciones "Accessibility" en cada archivo.
6. **Compat check**: Chris consulta 10-platform-differences.md + sus secciones en 11-17.
7. **Permisos & Legal**: Kate/Ivan consulta 13-patterns-permissions.md.
8. **Analytics**: Tim consulta 12-patterns-tasks.md § Notificaciones.

---

## Cambios desde Pasada 2

- Añadidos 7 archivos de Pasada 3 (11-17).
- Patterns expandidas de 6 → 12.
- Components expandidas de ~15 → ~17.
- Actualizado este índice con nueva tabla de contenidos y recomendaciones expandidas (Kate, Tim).
- Notas sobre fuentes secundarias añadidas (Pasada 3 usa secundarias para ciertos patrones).
- Pendientes clarificados: Pasada 4+ es low-urgency, lazy-loaded cuando feature lo requiera.

---

## Notas de Investigación

- **Fecha Pasada 1**: 2026-08-24 (Foundations + base Patterns/Components)
- **Fecha Pasada 2**: 2026-08-24 (Patterns search/auth/sharing + Input/Menu components + Platform differences)
- **Fecha Pasada 3**: 2026-08-24 (Patterns avanzadas + componentes especializados) — ✓ COMPLETADA
- **Próxima Pasada 4**: Cuándo app requiera Widgets, LiveActivities, SharePlay, o platform-specific tech
- **Próxima Pasada 5**: watchOS/tvOS/visionOS si app lo soporta (bajo prioridad)

---
