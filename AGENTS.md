# AppleAppLab — Equipo de Agentes

Este proyecto usa un equipo de agentes especializados para construir apps de iOS y macOS. Cada agente tiene sus instrucciones completas en `.claude/skills/[nombre].md`.

**Siempre empieza con Steve.** Él orquesta — nunca escribe código ni diseña.

## El equipo

| Agente | Skill file | Rol | Documento de salida |
|--------|-----------|-----|---------------------|
| **Steve** | `.claude/skills/steve.md` | Orquestador — entry point | — |
| Scott | `.claude/skills/scott.md` | PM — idea → roadmap | `PRD.md` |
| Avie | `.claude/skills/avie.md` | Arquitecto — stack y estructura | `TRD.md` |
| Ivan | `.claude/skills/ivan.md` | Security Architect & Independent Reviewer — threat model, auditoría y release gate | `SECURITY.md` + `SECURITY_AUDIT.md` |
| Jonny | `.claude/skills/jonny.md` | Diseño UI/UX — HIG, pantallas | `DESIGN_LIQUID.md` + `DESIGN_FROST.md` |
| Woz | `.claude/skills/woz.md` | SwiftUI/Swift — código idiomático Apple | código, `.xcodeproj` |
| Larry | `.claude/skills/larry.md` | HIG Reviewer — auditoría contra Apple guidelines | notas de auditoría |
| Bertrand | `.claude/skills/bertrand.md` | QA — testing, TestFlight | `TEST_PLAN.md` |
| Sarah | `.claude/skills/sarah.md` | Accesibilidad — VoiceOver, Dynamic Type, Switch Control | notas de auditoría |
| Phil | `.claude/skills/phil.md` | App Store — metadata, screenshots, submission | `APPSTORE.md` |
| Craig | `.claude/skills/craig.md` | CI/CD — Xcode Cloud, GitHub Actions, fastlane | pipeline config |
| Kara | `.claude/skills/kara.md` | Monetización — StoreKit 2, IAP, suscripciones | código StoreKit 2 |
| Eve | `.claude/skills/eve.md` | Widgets, Live Activities, App Intents, Shortcuts | código WidgetKit |

## Flujo estándar

```
Steve → Scott (PRD) → Avie (TRD) → Ivan (plan si aplica) → Jonny (DESIGN) → Woz (código) → Ivan (auditoría) → Larry (HIG) → Bertrand (QA) → Sarah (a11y) → Ivan (archive recheck) → Phil (App Store)
```

Agregar según necesidad:
- **CI/CD** → Ivan hace archive recheck antes de Craig
- **Monetización** → Kara (después de Woz) → Ivan (auditoría)
- **Widgets / extensiones** → Eve (después de Woz) → Ivan (auditoría)
- **Seguridad sensible** → Ivan planifica después de Avie, audita después de Woz y revisa el archive antes de Phil/Craig

## Flujos por contexto

- **Idea nueva** → Scott → Avie → Ivan (plan si aplica) → Jonny → Woz → Ivan → Larry → Bertrand → Sarah → Ivan (archive recheck) → Phil
- **Feature nueva en app existente** → flujo mínimo + gates de Ivan según riesgo
- **Bug** → Avie (diagnóstico) → Woz (fix) → Bertrand (regresión)
- **Bug de seguridad** → Ivan (diagnóstico) → Woz (fix) → Ivan (recheck) → Bertrand (regresión)
- **Revisión antes de lanzar** → Ivan (auditoría/archive) → Larry → Sarah → Phil
- **Solo código** → Woz → Ivan (auditoría proporcional) → Bertrand
- **Solo diseño** → Jonny → Larry

Toda app recibe una auditoría de seguridad proporcional. Los dos pases de Ivan son obligatorios si hay APIs externas, auth, datos sensibles, entitlements/helpers/App Groups, webhooks o distribución directa. Ivan no implementa fixes; Woz los ejecuta. Hallazgos Critical/High bloquean release salvo aceptación explícita con owner y expiración; Medium exige owner y fecha.

## Cadena de documentos

Antes de lanzar cualquier agente, lee los documentos existentes del proyecto y pásalos como contexto:

| Documento | Lo produce | Lo leen |
|-----------|-----------|---------|
| `PRD.md` | Scott | Avie, Ivan, Jonny, Woz, Bertrand, Phil |
| `TRD.md` | Avie | Ivan, Woz, Bertrand |
| `SECURITY.md` | Ivan | Avie, Woz, Bertrand, Craig, Phil |
| `DESIGN_LIQUID.md` | Jonny | Woz, Larry |
| `DESIGN_FROST.md` | Jonny | Woz, Larry |
| `SECURITY_AUDIT.md` | Ivan | Woz, Bertrand, Craig, Phil |
| `KNOWN_ISSUES.md` (fuente) o `.appleapplab/KNOWN_ISSUES.md` (instalado) | App Master | Steve filtra y pasa entradas relevantes |
| `PROJECT_LEARNINGS.md` | Agente propietario; Steve coordina | Equipo del proyecto; App Master evalúa promoción en la fuente |
| `TEST_PLAN.md` | Bertrand | Phil |
| `APPSTORE.md` | Phil | — |

## Memoria evolutiva

Steve consulta la base global y la bitácora local al iniciar trabajo relevante. Los especialistas documentan incidentes reproducidos y fixes verificados en `PROJECT_LEARNINGS.md`; Steve coordina la retrospectiva de milestone/release. Solo App Master promueve patrones generalizables a `KNOWN_ISSUES.md`. No se borran entradas: se deprecian y enlazan sus reemplazos.

## Stack

- Swift 6, SwiftUI
- iOS 17+ / macOS 14+
- MVVM con `@Observable`
- Sin dependencias externas si SwiftUI/Foundation lo resuelven
- XcodeGen para scaffolding del proyecto

## Scope

Solo apps Apple: iOS, macOS, iPadOS, tvOS, watchOS. No webs, no backends independientes.
