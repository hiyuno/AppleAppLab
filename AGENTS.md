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
| Jonny | `.claude/skills/jonny.md` | Diseño UI/UX — HIG, pantallas, motion design | `DESIGN_LIQUID.md` + `DESIGN_FROST.md` |
| Woz | `.claude/skills/woz.md` | SwiftUI/Swift — código idiomático Apple, optimización | código, `.xcodeproj` |
| Larry | `.claude/skills/larry.md` | HIG Reviewer — auditoría contra Apple guidelines | notas de auditoría |
| Bertrand | `.claude/skills/bertrand.md` | QA — testing, TestFlight, profiling de performance | `TEST_PLAN.md` |
| Sarah | `.claude/skills/sarah.md` | Accesibilidad — VoiceOver, Dynamic Type, Switch Control | notas de auditoría |
| Chris | `.claude/skills/chris.md` | Compatibility Auditor — dispositivos reales, OS, red, permisos, configuraciones no estándar | `COMPAT_AUDIT.md` |
| Phil | `.claude/skills/phil.md` | App Store — metadata, screenshots, submission | `APPSTORE.md` |
| Craig | `.claude/skills/craig.md` | CI/CD — Xcode Cloud, GitHub Actions, fastlane | pipeline config |
| Kara | `.claude/skills/kara.md` | Monetización — StoreKit 2, IAP, suscripciones | código StoreKit 2 |
| Eve | `.claude/skills/eve.md` | Widgets, Live Activities, App Intents, Shortcuts | código WidgetKit |
| Kate | `.claude/skills/kate.md` | Legal & Compliance — Privacy Policy, GDPR/CCPA/COPPA, licencias, Export Compliance | `LEGAL_AUDIT.md` + `PRIVACY_POLICY.md` |
| Kim | `.claude/skills/kim.md` | Localización & i18n — .xcstrings, plurales, RTL, formatos por región | `L10N_AUDIT.md` |
| Tim | `.claude/skills/tim.md` | Analytics — qué medir, TelemetryDeck/PostHog, privacidad (solo si la app lo necesita) | `ANALYTICS.md` |
| John | `.claude/skills/john.md` | Core ML & AI — on-device vs API, Core ML, LLMs, fallbacks (solo si hay features de IA) | `AI_SPEC.md` |

## Flujo estándar

```
Steve → Scott (PRD) → Avie (TRD) → Ivan (plan si aplica) → Jonny (DESIGN) → Woz (código) → Ivan (auditoría) → Larry (HIG) → Bertrand (QA) → Sarah (a11y) → Chris (compat) → Ivan (archive recheck) → Kate (legal) → Phil (App Store)
```

Agregar según necesidad:
- **CI/CD** → Ivan hace archive recheck antes de Craig
- **Monetización** → Kara (después de Woz) → Ivan (auditoría)
- **Widgets / extensiones** → Eve (después de Woz) → Ivan (auditoría)
- **Analytics** → Tim (cuando el usuario lo pide o antes del primer lanzamiento)
- **Features de IA** → John (solo cuando hay inteligencia real) → Ivan (si hay API externa)
- **Multi-idioma** → Kim (cuando la app soporta más de un idioma) → Woz (fixes) → Phil (App Store l10n)
- **Seguridad sensible** → Ivan planifica después de Avie, audita después de Woz y revisa el archive antes de Phil/Craig

## Fast Track — tiers de complejidad

Steve clasifica cada app en un tier antes de elegir el flujo:

| Tier | Perfil | Flujo |
|------|--------|-------|
| **1 — Fast Track** | 1–4 pantallas, sin auth, sin APIs externas, datos locales | Scott → Avie → Jonny → Woz → Bertrand |
| **2 — Estándar** | Auth O APIs externas O 5+ pantallas O monetización | Scott → Avie → Ivan → Jonny → Woz → Ivan → Larry → Bertrand → Sarah |
| **3 — Completo** | Auth + datos sensibles, múltiples integraciones, distribución pública inminente | Flujo completo — todos los agentes |

Steve nunca baja de tier. Si aparece una señal que sube el tier (login, datos sensibles, lanzamiento inminente), escala inmediatamente.

## Flujos por contexto

- **Idea nueva** → Scott → Avie → Ivan (plan si aplica) → Jonny → Woz → Ivan → Larry → Bertrand → Sarah → Chris → Ivan (archive recheck) → Kate → Phil
- **Feature nueva en app existente** → flujo mínimo + gates de Ivan según riesgo
- **Bug** → Avie (diagnóstico) → Woz (fix) → Bertrand (regresión)
- **Bug de seguridad** → Ivan (diagnóstico) → Woz (fix) → Ivan (recheck) → Bertrand (regresión)
- **Revisión antes de lanzar** → Ivan (auditoría/archive) → Larry → Sarah → Chris → Kate → Phil
- **Solo código** → Woz → Ivan (auditoría proporcional) → Bertrand
- **Solo diseño** → Jonny → Larry
- **Analytics** → Tim → Woz (implementación)
- **Features de IA** → John → Ivan (si API externa) → Woz
- **Localización** → Kim → Woz (fixes) → Kim (re-verifica) → Phil
- **Legal** → Kate → Steve presenta hallazgos al usuario → usuario aprueba → agentes implementan

## Hallazgos de Kate — requieren aprobación

Cuando Kate encuentra un problema legal, **no se implementa automáticamente**. Steve presenta el hallazgo al usuario con la solución propuesta y espera confirmación explícita antes de lanzar los agentes que lo resuelven.

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
| `COMPAT_AUDIT.md` | Chris | Ivan (archive recheck), Phil |
| `LEGAL_AUDIT.md` | Kate | Steve → usuario → agentes |
| `PRIVACY_POLICY.md` | Kate | Phil |
| `ANALYTICS.md` | Tim | Woz |
| `AI_SPEC.md` | John | Ivan, Woz |
| `L10N_AUDIT.md` | Kim | Woz, Phil |
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
