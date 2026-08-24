# Pendientes — Estado Actual y Próximas Pasadas

**Última actualización**: 2026-08-24 (Pasada 3 Completada)

---

## Estado Actual

### ✓ Pasada 1 Completada
- Foundations (100%)
- Patterns iniciales: Data Entry, Split Views, Onboarding
- Components core: Buttons, TextFields, TabBars, Alerts, Sheets

### ✓ Pasada 2 Completada (08-24)
- ✓ Patterns: Searching, Authorization & Sign-In, Sharing & Collaboration
- ✓ Components: Toggle, Picker, DatePicker, Stepper, Slider, Menu, ContextMenu, Toolbar, Sidebar, SegmentedControl
- ✓ Platform Differences: iOS vs macOS (navigation, menus, keyboard, windows)

### ✓ Pasada 3 Completada (08-24)
- ✓ **Patterns**: Drag & Drop, Managing Tasks, System Permissions, Confirming User Actions, Offering Choices, Progressive Disclosure
- ✓ **Components**: ProgressView (determinate & indeterminate), List & Table (styles, selection, sorting, swipe actions)

---

## Archivos de Pasada 3 (Nuevos)

1. **11-patterns-dragdrop.md** — Drag & Drop (multi-item, undo, accessibility, iOS vs macOS)
2. **12-patterns-tasks.md** — Managing Tasks (undo/redo, notifications, task completion, sync, offline)
3. **13-patterns-permissions.md** — System Permissions (camera, location, contacts, photos, microphone, HealthKit, iOS 14+ limited access, just-in-time requests)
4. **14-patterns-confirmations.md** — Confirming User Actions (destructive actions, batch operations, undo toast, forgiveness philosophy, recovery paths)
5. **15-patterns-choices.md** — Offering Choices (radio buttons, checkboxes, toggles, multi-select, selection controls, keyboard navigation)
6. **16-patterns-disclosure.md** — Progressive Disclosure (accordion, tabs, help buttons, conditional fields, show more/less patterns)
7. **17-components-progress-list.md** — ProgressView & List/Table (determinate/indeterminate, list styles, selection, sorting, swipe actions, lazy loading)

**Nota sobre fuentes**: Pasada 3 usa mix de HIG oficial + fuentes secundarias confiables (Medium, Smashing Magazine, NN/G, WWDC) para patrones donde HIG no tiene página dedicada. Cada archivo marca claramente: "Fuente: primaria (HIG oficial)" vs "Fuente: secundaria — pattern no tiene página dedicada en HIG actual".

---

## Cobertura por Porcentaje (Actualizado Post-Pasada 3)

| Categoría | Pasada 1 | Pasada 2 | Pasada 3 | Total Cubierto |
|-----------|----------|----------|----------|-----------------|
| Foundations | 100% | — | — | **100%** ✓ |
| Patterns | 30% | +30% | +30% | **~90%** ✓ |
| Components | 25% | +40% | +20% | **~85%** ✓ |
| Platform-Specific (iOS/macOS) | — | 100% | — | **100%** ✓ |
| iOS-Specific Tech | 0% | 0% | 0% | **0% (Pasada 4+)** |
| macOS-Specific Tech | 0% | 0% | 0% | **0% (Pasada 4+)** |
| Emerging Platforms | 0% | 0% | 0% | **0% (Pasada 5+)** |

---

## Qué Falta (Pasada 4+ — Bajo Prioridad, Lazy-Load)

### Pasada 4 — Platform-Specific Technologies

**Acción**: Solo hacer cuando app scope incluya estas features. No es urgente para la mayoría de apps.

#### iOS-Specific Features (Bajo Prioridad)

1. **Widgets** — Home screen widgets, lock screen widgets, smart stack
   - When: Apps needing home screen presence
   - Estimated: 1 file
   - URL: https://developer.apple.com/design/human-interface-guidelines/widgets

2. **Live Activities** — Live data on lock screen, Dynamic Island
   - When: Sports, fitness, delivery tracking, timers
   - Estimated: 0.5 file
   - URL: https://developer.apple.com/design/human-interface-guidelines/live-activities

3. **App Clips** — Lightweight experiences, NFC/URL activation
   - When: Commerce, ticketing, quick experiences
   - Estimated: 0.5 file

4. **Shortcuts** — Siri Shortcuts integration, custom intents
   - When: Automation-focused apps
   - Estimated: 0.3 file

5. **Background Modes** — Background fetch, processing, downloads
   - When: Sync, notifications, audio
   - Estimated: 0.5 file

#### macOS-Specific Features (Bajo Prioridad)

1. **Menu Bar** — Menu bar apps, status items
   - When: Utility apps, system tools
   - Estimated: 0.3 file

2. **Window Management** — Tabs, resizing, Stage Manager
   - When: Desktop apps
   - Estimated: 0.3 file (partially in 10-platform-differences.md already)

3. **Dock Integration** — Dock icon, context menu
   - When: Desktop apps with Dock presence
   - Estimated: 0.2 file

#### Cross-Platform Advanced Features (Bajo Prioridad)

1. **SharePlay** — Collaborative experiences, shared playback
   - When: Multiplayer, collaborative editing
   - Estimated: 0.4 file

2. **Handoff** — Continuity between devices, resume on Mac
   - When: Cloud-enabled, multi-device apps
   - Estimated: 0.3 file

3. **Focus Modes** — Do Not Disturb, Sleep, Work, Custom
   - When: Notifications, availability-aware apps
   - Estimated: 0.2 file

4. **Siri Integration** — Voice commands beyond Shortcuts
   - When: Voice-first features
   - Estimated: 0.2 file

5. **Universal Clipboard** — Copy/paste across devices
   - When: Cloud-enabled apps
   - Estimated: 0.2 file

**Estimated total for Pasada 4**: ~2-3 files, **only if needed**.

---

### Pasada 5+ — Emerging Platforms (Very Low Priority)

#### watchOS (Optional, Only if app targets watchOS)
- Complications, glances, limited UI paradigm
- Estimated: 1-2 files
- Very low priority: <3% of typical app market

#### tvOS (Optional, Only if app targets tvOS)
- Remote control navigation, focus engine
- Estimated: 0.5-1 file
- Very low priority: <2% of typical app market

#### visionOS (Optional, Only if app targets visionOS)
- Spatial computing, hand gestures, volumetric apps
- Estimated: 1-2 files
- Very low priority: Early stage, only if app explicitly targets Vision Pro

---

## Componentes Que Faltan (Pasada 4 — Bajo Prioridad)

1. **ColorPicker** — Color selection, palettes
   - When: Art/design apps
   - Estimated: 0.3 file

2. **Media Pickers** — Photo/video picker, gallery, media player
   - When: Photo/video apps
   - Estimated: 0.5 file

3. **AppKit-Specific** — NSView, NSViewController (macOS only)
   - When: macOS apps requiring AppKit integration
   - Estimated: 0.3 file

---

## Recomendaciones para Próximas Pasadas

### Pasada 3 Ya Completada ✓

**Qué cubrir**:
- ✓ Task management, undo/redo, notifications
- ✓ System permissions (camera, location, contacts, photos)
- ✓ Drag & drop patterns
- ✓ Confirming destructive actions
- ✓ Offering choices (radio, checkbox, toggle)
- ✓ Progressive disclosure (accordion, tabs)
- ✓ ProgressView & List components

**Costo**: ~3 horas, 7 archivos nuevos (11-17-patterns/components)

---

### Cuándo Hacer Pasada 4

**Trigger**: Cuando app scope incluya:
- Home screen widgets → Pasada 4-iOS-1
- Live data on lock screen → Pasada 4-iOS-2
- macOS menu bar app → Pasada 4-macOS-1
- Multi-device continuity (Handoff) → Pasada 4-Cross-1

**Costo**: ~2-3 horas, 2-3 archivos nuevos (lazy-loaded, solo si necesario)

---

### Cuándo Hacer Pasada 5

**Trigger**: Cuando app soporta:
- watchOS complications → 5-watchOS
- tvOS remote control UI → 5-tvOS
- visionOS spatial computing → 5-visionOS

**Costo**: ~3-5 horas, 1-3 archivos (very low priority)

---

## URLs para Próximas Pasadas (Pasada 4+)

```
Documentación Completa:
https://developer.apple.com/design/human-interface-guidelines/

iOS-Specific (Pasada 4):
https://developer.apple.com/design/human-interface-guidelines/widgets
https://developer.apple.com/design/human-interface-guidelines/live-activities
https://developer.apple.com/design/human-interface-guidelines/app-clips
https://developer.apple.com/design/human-interface-guidelines/shortcuts

Cross-Platform Advanced (Pasada 4):
https://developer.apple.com/design/human-interface-guidelines/shareplay
https://developer.apple.com/design/human-interface-guidelines/handoff
https://developer.apple.com/design/human-interface-guidelines/focus

Componentes Especializados (Pasada 4):
https://developer.apple.com/design/human-interface-guidelines/components/selection/color-picker
https://developer.apple.com/design/human-interface-guidelines/components/selection/photo-picker

Plataformas Emergentes (Pasada 5+):
https://developer.apple.com/design/human-interface-guidelines/watchos
https://developer.apple.com/design/human-interface-guidelines/tvos
https://developer.apple.com/design/human-interface-guidelines/visionos
```

---

## Próxima Acción

1. **Pasada 3 completa** — Toda guidance de patrones/componentes esenciales está documentada.
2. **Pasada 4 abierta** — Solo hacer cuando feature lo requiera (lazy-load).
3. **Verificar cobertura** — Si necesitas feature que no está en 01-17, abre sesión Skim con URL específica.

Ejemplos de uso:
- "Necesito drag-reordenable list" → Consulta 11-patterns-dragdrop.md + 17-components-progress-list.md (✓ Pasada 3)
- "Necesito solicitar permiso de cámara" → Consulta 13-patterns-permissions.md (✓ Pasada 3)
- "Necesito confirmación antes de delete" → Consulta 14-patterns-confirmations.md (✓ Pasada 3)
- "Necesito home screen widget" → Abre Pasada 4-iOS-1 (no urgente)
- "Necesito watchOS complication" → Abre Pasada 5-watchOS (muy bajo prioridad)

---

## Notas de Investigación

- **Documentación escaneada**: ~50+ URLs principales de developer.apple.com/design/human-interface-guidelines/
- **Fuentes secundarias** (Pasada 3): Medium, NN/G, Smashing Magazine, WWDC transcripts (confiables)
- **Scope**: Enfocado en iOS/macOS como primary platforms, iPad considered
- **Estrategia**: Lazy-load de tecnologías platform-specific (solo cuando feature requiera)
- **Próxima mejora**: Si HIG oficial añade nuevas secciones en 2026, actualizar 04-pendientes.md

---

## Historial de Cambios

- **Pasada 3 completa (08-24)**: Añadidos 7 archivos (11-17), patterns 30% → 90%, components 75% → 85%
- **Pasada 2 completa**: Añadidos 5 archivos (05-10), patterns 30% → 60%, components 25% → 75%
- **Pasada 1 completa**: Foundations 100%, base patterns/components

---
