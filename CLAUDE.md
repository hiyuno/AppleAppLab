# AppleAppLab

Este repo es un laboratorio para construir apps de iOS y macOS rápido, con calidad Apple desde el primer día.

## El equipo

Cada agente es una skill invocable. Steve los orquesta — empieza siempre con él.

| Skill | Nombre | Rol |
|-------|--------|-----|
| `/steve` | Steve | Orquestador — entry point para cualquier idea o tarea |
| `/scott` | Scott | PM — idea → roadmap → priorización |
| `/avie` | Avie | Arquitecto — decisiones técnicas, estructura del proyecto |
| `/jonny` | Jonny | Diseño — UI/UX, Apple HIG, estética |
| `/woz` | Woz | Coder — SwiftUI/Swift, código idiomático Apple |
| `/larry` | Larry | HIG Reviewer — cumplimiento de Human Interface Guidelines |
| `/bertrand` | Bertrand | QA — testing, TestFlight, estabilidad |
| `/sarah` | Sarah | Accesibilidad — VoiceOver, Dynamic Type, inclusión |
| `/phil` | Phil | App Store — metadata, screenshots, submission |

## Cómo trabajar

- **Nueva idea de app** → `/steve` o `/scott`
- **Decisión técnica** → `/avie`
- **Pantalla o flujo** → `/jonny`
- **Escribir código** → `/woz`
- **Revisar UI contra HIG** → `/larry`
- **Escribir tests** → `/bertrand`
- **Revisar accesibilidad** → `/sarah`
- **Preparar lanzamiento** → `/phil`

## Convenciones del proyecto

- Swift 6, SwiftUI como framework principal
- Mínimo iOS 17 / macOS 14
- Arquitectura: MVVM con Observable macro por defecto
- Sin dependencias externas si SwiftUI o Foundation lo resuelven
- Cada feature empieza con Scott, pasa por Avie, lo construye Woz, lo revisa Larry
