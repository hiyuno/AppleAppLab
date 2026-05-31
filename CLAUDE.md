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

## Flujo estándar

**Siempre empieza con Steve.** Él orquesta y decide si se necesitan todos los pasos o solo algunos.

```
Steve/Scott → Avie → Jonny → Woz → Larry → Bertrand → Sarah → Phil
```

- **Steve** recibe la idea o tarea y decide el camino
- **Scott** la convierte en roadmap si es idea nueva
- **Avie** define la arquitectura antes de escribir código
- **Jonny** diseña las pantallas y flujos
- **Woz** construye el código
- **Larry** revisa HIG antes de que salga
- **Bertrand** prueba y asegura estabilidad
- **Sarah** audita accesibilidad
- **Phil** prepara el lanzamiento en App Store

## Convenciones del proyecto

- Swift 6, SwiftUI como framework principal
- Mínimo iOS 17 / macOS 14
- Arquitectura: MVVM con Observable macro por defecto
- Sin dependencias externas si SwiftUI o Foundation lo resuelven
