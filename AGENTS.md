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
| Frederick | `.claude/skills/frederick.md` | Growth Advisor — validación de nicho, pricing, Apple Search Ads, análisis de mercado y competidores | `GROWTH.md` |

## Flujo estándar

```
Steve → Scott (PRD) → Avie (TRD) → Ivan (plan si aplica) → [Steve: brief visual → STYLE_BRIEF.md] → Jonny (DESIGN) → Woz (código) → Ivan (auditoría) → Larry (HIG) → Bertrand (QA) → Sarah (a11y) → Chris (compat) → Ivan (archive recheck) → Kate (legal) → Phil (App Store)
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
| `PATTERNS.md` | AppleAppLabUI team (repo fuente) | Jonny, Woz |
| `STYLE_BRIEF.md` | Steve (síntesis de referencias del usuario) | Jonny |
| `LEGAL_AUDIT.md` | Kate | Steve → usuario → agentes |
| `PRIVACY_POLICY.md` | Kate | Phil |
| `ANALYTICS.md` | Tim | Woz |
| `AI_SPEC.md` | John | Ivan, Woz |
| `L10N_AUDIT.md` | Kim | Woz, Phil |
| `GROWTH.md` | Frederick | Phil, Kara |
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

## Contrato operativo para Codex

Esta sección es la guía de entrada de Codex para este repositorio. No sustituye las skills especializadas: decide cuándo usarlas y qué contexto pasarles.

### Clasificación de la petición

Antes de actuar, clasifica la petición en una categoría:

| Categoría | Cadena mínima | Resultado esperado |
|---|---|---|
| Análisis/revisión | Steve → especialista proporcional | Hallazgos con evidencia; no cambios salvo petición explícita |
| Idea nueva | Steve → Scott → Avie → Jonny → Woz → verificación | Producto definido, diseñado, implementado y verificado |
| Feature existente | Steve → Avie/Jonny según riesgo → Woz → verificación | Cambio local con regresión controlada |
| Bug técnico | Steve → Avie → Woz → Bertrand | Causa reproducida, fix y prueba de regresión |
| Bug de seguridad | Steve → Ivan → Woz → Ivan → Bertrand | Hallazgo corregido y re-auditado |
| Cambio de arquitectura | Steve → Avie → Woz → Bertrand | Decisión registrada y compilación/pruebas |
| Solo diseño | Steve → Jonny → Larry | Diseño entregado y revisado contra HIG |
| Solo código | Steve → Woz → Ivan proporcional → Bertrand | Código funcional y verificado |
| Lanzamiento | Steve → Ivan → Larry → Sarah → Chris → Kate → Phil/Craig | Gates de release resueltos |
| Mejora de skill | Steve → skill-creator → validación | Skill más clara, enfocada y validada |

Si la petición ya contiene una decisión clara, no relances un agente para repetirla. Si falta una decisión que cambia materialmente el resultado, formula una sola pregunta concreta.

### Contrato de handoff

Cada agente recibe la petición original, la clasificación, la evidencia relevante, los documentos existentes, restricciones de alcance y su salida esperada. Cada agente debe devolver:

1. resumen de lo decidido o encontrado;
2. archivos creados/modificados;
3. verificaciones ejecutadas y su resultado;
4. riesgos, decisiones pendientes o bloqueos;
5. criterio para que Steve pueda cerrar ese paso.

Un agente no implementa el trabajo propiedad de otro: Steve coordina, Avie decide arquitectura, Jonny diseña, Woz implementa, e Ivan/Larry/Bertrand/Sarah/Chris verifican según su especialidad.

### Prioridad de skills

Usa primero skills de proceso cuando apliquen y después skills de dominio:

- trabajo creativo o comportamiento nuevo: `superpowers:brainstorming`;
- requisitos de varios pasos: `superpowers:writing-plans`;
- bug o comportamiento inesperado: `superpowers:systematic-debugging`;
- implementación de feature o fix: `superpowers:test-driven-development` cuando sea viable;
- antes de declarar completado: `superpowers:verification-before-completion`;
- creación o modificación de una skill: `skill-creator` y, si aplica, `superpowers:writing-skills`.

Después activa solo el dominio necesario: `macos`/`macos-design` para apps Mac, `interface-design` para interfaces, `documents` para Word, `pdf` para PDF, `spreadsheets` para hojas, y las skills de Vercel/web únicamente si la petición realmente es web. No actives monetización, analytics, IA, localización, widgets, legal o CI/CD si no hay una señal de alcance que lo requiera.

### Límites de autoridad

- Una petición de análisis es de solo lectura hasta que el usuario pida cambios.
- No modificar `.claude/**`, `.cursor/**`, `CLAUDE.md` ni `GEMINI.md` desde el flujo Codex.
- No crear entregables de especialistas que no correspondan al alcance.
- No desplegar, publicar, enviar mensajes ni modificar servicios externos sin petición explícita.
- Preservar cambios previos del usuario y verificar el worktree antes de editar.
- Un `Critical` o `High` de Ivan bloquea release salvo aceptación explícita con owner y expiración.

### Documentos de proyecto

Antes de delegar, leer solo los documentos que existan y sean relevantes. No bloquear el trabajo por documentos ausentes: registrar el hueco en el handoff y pedir al agente propietario que lo cree únicamente si el flujo lo necesita.

### Estado visible del flujo

Mantén una línea de estado al cambiar de agente, por ejemplo:

`[✅ Steve] [✅ Avie] [🔄 Woz] [⏳ Bertrand]`

No mantengas agentes abiertos después de recibir su salida. Si un gate bloquea, marca el estado como `❌` y detén las acciones dependientes.
