# AppleAppLab — Equipo de Agentes

Este proyecto usa un equipo de agentes especializados para construir apps de iOS y macOS. Cada agente tiene sus instrucciones completas en `.claude/skills/[nombre]/SKILL.md`.

**Siempre empieza con Steve.** Él orquesta — nunca escribe código ni diseña.

## El equipo

| Agente | Skill file | Rol | Documento de salida |
|--------|-----------|-----|---------------------|
| **Steve** | `.claude/skills/steve/SKILL.md` | Orquestador — entry point | — |
| Scott | `.claude/skills/scott/SKILL.md` | PM — idea → roadmap | `PRD.md` |
| Avie | `.claude/skills/avie/SKILL.md` | Arquitecto — stack y estructura | `TRD.md` |
| Ivan | `.claude/skills/ivan/SKILL.md` | Security Architect & Independent Reviewer — threat model, auditoría y release gate | `SECURITY.md` + `SECURITY_AUDIT.md` |
| Jonny | `.claude/skills/jonny/SKILL.md` | Diseño UI/UX — HIG, pantallas, motion design | `DESIGN_LIQUID.md` + `DESIGN_FROST.md` |
| Woz | `.claude/skills/woz/SKILL.md` | SwiftUI/Swift — código idiomático Apple, optimización | código, `.xcodeproj` |
| Larry | `.claude/skills/larry/SKILL.md` | HIG Reviewer — auditoría contra Apple guidelines | notas de auditoría |
| Bertrand | `.claude/skills/bertrand/SKILL.md` | QA — testing, TestFlight, profiling de performance | `TEST_PLAN.md` |
| Sarah | `.claude/skills/sarah/SKILL.md` | Accesibilidad — VoiceOver, Dynamic Type, Switch Control | notas de auditoría |
| Chris | `.claude/skills/chris/SKILL.md` | Compatibility Auditor — dispositivos reales, OS, red, permisos, configuraciones no estándar | `COMPAT_AUDIT.md` |
| Phil | `.claude/skills/phil/SKILL.md` | App Store — metadata, screenshots, submission | `APPSTORE.md` |
| Craig | `.claude/skills/craig/SKILL.md` | CI/CD — Xcode Cloud, GitHub Actions, fastlane | pipeline config |
| Kara | `.claude/skills/kara/SKILL.md` | Monetización — StoreKit 2, IAP, suscripciones | código StoreKit 2 |
| Eve | `.claude/skills/eve/SKILL.md` | Widgets, Live Activities, App Intents, Shortcuts | código WidgetKit |
| Kate | `.claude/skills/kate/SKILL.md` | Legal & Compliance — Privacy Policy, GDPR/CCPA/COPPA, licencias, Export Compliance | `LEGAL_AUDIT.md` + `PRIVACY_POLICY.md` |
| Kim | `.claude/skills/kim/SKILL.md` | Localización & i18n — .xcstrings, plurales, RTL, formatos por región | `L10N_AUDIT.md` |
| Tim | `.claude/skills/tim/SKILL.md` | Analytics — qué medir, TelemetryDeck/PostHog, privacidad (solo si la app lo necesita) | `ANALYTICS.md` |
| John | `.claude/skills/john/SKILL.md` | Core ML & AI — on-device vs API, Core ML, LLMs, fallbacks (solo si hay features de IA) | `AI_SPEC.md` |
| Frederick | `.claude/skills/frederick/SKILL.md` | Growth Advisor — validación de nicho, pricing, Apple Search Ads, análisis de mercado y competidores | `GROWTH.md` |
| Sam | `.claude/skills/sam/SKILL.md` | Asesor de Finanzas Personales & Score Crediticio — umbrales, fórmulas de deuda/interés y estrategias con fuentes reales (CFPB, myFICO, Experian, NerdWallet) | `FINANCE_ADVISOR.md` |
| Ed | `.claude/skills/ed/SKILL.md` | Director técnico de 3D con Blender — assets de marca (ícono, screenshots del App Store, héroe web) con look Apple; brief 3D aprobado por Yuno en rondas con sus referencias antes de modelar; MCP oficial de Blender Lab, previews Eevee, final Cycles solo a pedido; PNG/WebP, MP4, STL, glTF | `Docs/Design/3D/<asset>/BRIEF_3D.md` |
| `/optimize-app` (rutina) | `.claude/skills/optimize-app/SKILL.md` | Auditoría de performance — Bertrand mide con Instruments, Avie revisa el código (loops, redundancia, duplicación), Steve entrega plan por etapas; `go <n>` aplica cada etapa | `PERFORMANCE_AUDIT.md` |
| `/architecture-audit` (rutina) | `.claude/skills/architecture-audit/SKILL.md` | Auditoría de arquitectura — Avie mapea estructura real vs TRD y roadmap, 6 criterios de salud, veredicto MANTENER/AJUSTAR/CAMBIAR, plan de migración strangler por etapas; `go <n>` aplica cada etapa y actualiza TRD.md | `ARCHITECTURE_AUDIT.md` |
| `/app-store-ready` (rutina) | `.claude/skills/app-store-ready/SKILL.md` | Preparación para App Store — Phil lidera; cuenta y contratos, build y validación, Info.plist, Privacy Manifest, entitlements/sandbox, guidelines de rechazo, App Store Connect; gates de Ivan, Kate, Bertrand, Chris, Sarah, Kara, Larry; veredicto LISTA / LISTA CON FIXES / NO LISTA / NO VIABLE, plan por etapas y opciones de distribución alternativas; `go <n>` aplica cada etapa; el submit requiere confirmación explícita | `APP_STORE_READINESS.md` |
| `/clean-folder-project` (rutina) | `.claude/skills/clean-folder-project/SKILL.md` | Limpieza y organización del proyecto — Avie lidera: inventario (basura y rastreados indebidos, nombres, capa equivocada, huérfanos en assets/strings, .gitignore, project.yml), estructura objetivo feature-first adaptada al nivel del TRD, tabla archivo → destino, plan por etapas con `git mv` que compila y pasa tests en cada una; Woz mueve, Bertrand confirma, Ivan para secretos/entitlements, Kim para strings; `go <n>` aplica cada etapa; deja la convención "dónde va cada cosa" | `PROJECT_STRUCTURE.md` |
| `/app-web-intake` (rutina) | `.claude/skills/app-web-intake/SKILL.md` | Intake para el sitio web en web-lab — solo cuando el usuario la pide. Crea `app-web-intake.md` en la raíz desde el template verbatim (inglés), deriva todo lo que ya existe en PRD, TRD, STYLE_BRIEF, GROWTH, PRIVACY_POLICY, APPSTORE; pregunta en un mensaje solo dominio, soporte y confirmación de pilares; Phil pregunta lo del foro en pre-lanzamiento; URLs, rating y proof solo con datos reales; nunca inventa, `TBD`. Cada agente escribe su campo al producir su documento. `status`, `update`, `prelaunch` | `app-web-intake.md` |
| `/link-todocky <code>` (comando) | `.claude/skills/link-todocky/SKILL.md` | Enlace inverso repo ↔ proyecto de Todocky: con el código de "Copy project number" (un solo uso) llama `link_repo_to_project` con la ruta absoluta del repo y el `external_key` consciente de worktrees de Steve §0.5, guarda el `projectId` en `.claude/todocky-link.json` (ignorado por git) y habilita "Implement with Claude" desde Todocky. Requiere el MCP de Todocky; no crea proyectos ni tasks | `.claude/todocky-link.json` (cache local) |
| `/global-fix` (rutina) | `.claude/skills/global-fix/SKILL.md` | Bugs que no caen con una revisión pequeña: Bertrand reproduce y escribe el test que falla; Avie mapea el flujo completo (entrada → estado → fronteras → salida) y enumera todas las causas con un catálogo Apple (estado, concurrencia, datos, ciclo de vida, fronteras externas, entorno, el fix anterior), rankeadas y falsadas con evidencia; Woz corrige la raíz, un commit por causa, sin fixes prohibidos (`try?`, `asyncAfter`, skip); Bertrand verifica con la reproducción ×N, test verde, suite, dispositivo mínimo; después Avie/Woz simplifican en commit aparte dejando solo lo necesario; entrada en `PROJECT_LEARNINGS.md`. Dos checkpoints; `auto` sin parar; salida explícita cuando nada confirma (bisect, repro aislada, evidencia del usuario) | entrada en `PROJECT_LEARNINGS.md` |
| `/add-developer-tools [tema\|check]` (rutina) | `.claude/skills/add-developer-tools/SKILL.md` | Instala Dev Tools y tema central en un proyecto: Steve sonda y elige tema, Woz empaqueta `Themes/<tema>.json`, cablea `LabThemeStore` + `.labTheme` + `.labDevTools` y sustituye `PatternConfig(...)` por `labTheme.config(for: XPattern.self)` con script de referencia; Bertrand compila iOS/macOS y abre el panel; Ivan verifica `nm | grep LabDevTools` = 0 en Release; Larry reporta literales visuales restantes. Idempotente; `check` solo audita | `TRD.md` + `STYLE_BRIEF.md` actualizados |
| `/app-brand-package [check\|screens\|status]` (rutina) | `.claude/skills/app-brand-package/SKILL.md` | Paquete de marca para web-lab (contrato v1, web-lab `docs/app-brand-package.md`): Jonny lidera; el generador `lab-brand-package` (AppleAppLabUI) produce manifest y tokens DTCG desde el tema, los assets y el código; Yuno contesta cada diferencia entre tema, `DESIGN_*.md` y código (no se publica con diferencias abiertas); Woz captura 3–6 pantallas clave con `-LabSeedData` en cada modo de la app; el generador calcula el semver y Jonny lo confirma; Ivan revisa privacidad; Steve escribe `CHANGELOG.md`, el campo *Brand package* del intake y hace el commit. `check` solo diagnostica |
| `/global-audit` (rutina paraguas) | `.claude/skills/global-audit/SKILL.md` | Steve hace triage por etapa del proyecto (nuevo/scaffold, en construcción, pre-lanzamiento, publicada, heredada) y omite o posterga con razón las rutinas que no hacen falta — un proyecto nuevo no recibe arquitectura, limpieza ni performance; corre las necesarias en modo diagnóstico silencioso (solo las desactualizadas respecto al commit) compartiendo inventarios (find, imports, Periphery, SwiftLint, git una sola vez), Avie reconcilia hallazgos cruzados (🏗 → arquitectura, 🧹 → limpieza, 2.1 → performance; puede cambiar veredictos) y colisiones entre etapas, Steve entrega un tablero con los cuatro veredictos y una secuencia global de `go` en rondas fijas arquitectura → limpieza → performance → App Store, con re-sincronización al cerrar cada ronda (TRD, re-baseline, status); `go <n>` delega a la rutina dueña; `status` refresca sin re-auditar. No añade hallazgos propios | `GLOBAL_AUDIT.md` |
| `/update-ui <pantalla o screenshot>` (rutina) | `.claude/skills/update-ui/SKILL.md` | Paridad UI↔diseño (Figma o Pen) — Steve compara una pantalla completa (por nombre) o un fragmento (por screenshot) contra su frame en Figma o en el archivo `.pen` de Pen (`get_design_context`, `get_variable_defs`, `get_metadata`): colores, padding, alineación, tipografía, radios, iconografía; Woz aplica directo (sin plan por etapas, es de bajo riesgo) salvo que el fix sea estructural, Steve verifica con build + screenshot en simulador | sin documento — reporta lo corregido por categoría en el chat |
| `/harvest-learnings` (rutina, solo repo fuente) | `.claude/skills/harvest-learnings/SKILL.md` | App Master cosecha los `PROJECT_LEARNINGS.md` de todas las apps en `GitSync/`, separa incidentes de preferencias, agrupa lo repetido entre apps, decide solo lo técnico con criterios fijos, pregunta al usuario solo preferencias y cambios de código, y sube lo aprobado por la escalera doc → skill → code | `KNOWN_ISSUES.md`, `PREFERENCES.md`, `LEARNINGS_LEDGER.md` |

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
- **Finanzas personales / score crediticio** → Sam (define regla/umbral con fuentes) → Avie (modelo) → Jonny (indicador) → Woz
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
- **Finanzas personales / score crediticio** → Sam → Avie/Jonny → Woz
- **Asset 3D (ícono, screenshots, héroe web)** → Ed (brief en rondas con referencias de Yuno → Yuno aprueba) → Ed (escena, previews Eevee) → Jonny (revisa identidad) → Ed (final Cycles a pedido, exports) → Phil / `/app-brand-package`
- **Legal** → Kate → Steve presenta hallazgos al usuario → usuario aprueba → agentes implementan
- **Paquete de marca para web-lab** → Jonny (pantallas clave, logo, mapa de íconos) → Woz (`-LabSeedData`, capturas) → `lab-brand-package check` → Yuno (cada diferencia) → Jonny/Woz (corrigen el origen) → Jonny (confirma versión) → Ivan (privacidad) → Steve (`write`, CHANGELOG, intake, commit)

## Hallazgos de Kate — requieren aprobación

Cuando Kate encuentra un problema legal, **no se implementa automáticamente**. Steve presenta el hallazgo al usuario con la solución propuesta y espera confirmación explícita antes de lanzar los agentes que lo resuelven.

## Jerarquía — quién decide qué

Una escalera: nadie se salta niveles.

| Nivel | Quién | Qué hace | Qué no hace |
|---|---|---|---|
| 1 | **Yuno** | Decide | — |
| 2 | **Yubot** (segundo cerebro, en `~/Yubot`) | Piensa con Yuno, guarda las decisiones y manda mensajes en su nombre ("De: Yuno (vía Yubot)") | No modifica proyectos ni equipos |
| 3 | **App Master** (Master Orquestador, solo en el repo AppleAppLab) | Mejora a Steve y al equipo: skills, reglas y procesos; cosecha learnings; decide con Yuno qué se vuelve regla | Nunca entra a un proyecto: no toca su código, sus docs ni sus decisiones |
| 4 | **Steve** (en cada app) | Orquesta su proyecto y anota lo aprendido en `PROJECT_LEARNINGS.md` | No se modifica a sí mismo ni a otros skills: propone y App Master decide |
| 5 | **Especialistas** (Scott, Avie, Jonny, Woz…) | Hacen el trabajo | Tampoco editan skills: lo que mejorarían lo anotan como propuesta |

- **Las mejoras al equipo suben, no se aplican en la app.** Los skills (`.claude/skills/`), `.appleapplab/`, `AGENTS.md`, `GEMINI.md` y `.cursor/rules/apple-team.mdc` de una app son copia de AppleAppLab y `/update-team` los sobreescribe. Un agente que ve algo mejorable en un skill, una regla o un proceso lo anota en `PROJECT_LEARNINGS.md` con **Tipo:** `propuesta` y sigue trabajando. App Master la recoge con `/harvest-learnings` y la decide con Yuno.
- **Si Yuno pide en una app cambiar un skill**, el agente anota la propuesta y avisa en una línea que el cambio se hace desde AppleAppLab; editarlo ahí se perdería con la siguiente actualización.
- **Mensajes de Yubot.** Un mensaje firmado "De: Yuno (vía Yubot)" vale como decisión de Yuno. Yubot no toca proyectos ni equipos: si su mensaje pide un cambio al equipo, lo aplica App Master; si pide algo de una app, lo ejecuta el Steve de esa app.
- **Dos equipos, dos Masters.** web-lab tiene su propio Master Orquestador. Lo que comparten los dos equipos —`app-web-intake.md` y el paquete de marca (`brand-package/`, contrato v1 en web-lab `docs/app-brand-package.md`, lo produce `/app-brand-package`)— lo acuerdan los dos Masters con Yuno. Ninguno edita el repo del otro.

## Dónde vive cada documento

La raíz del proyecto (o de la carpeta de la app dentro de un monorepo) queda limpia: solo lo que las herramientas exigen ahí y lo que compila. Cada documento del equipo tiene una carpeta fija; un agente que crea un documento lo crea ahí, y crea la carpeta si no existe.

| Carpeta | Qué vive ahí |
|---------|--------------|
| raíz | `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` (las herramientas los buscan ahí), `README.md`, `project.yml`, `Makefile`, `.gitignore`, `app-web-intake.md` y `brand-package/` (contratos con web-lab) y el código de la app |
| `Docs/Product/` | `PRD.md`, `GROWTH.md`, `FINANCE_ADVISOR.md`, monetización, ideas y roadmaps |
| `Docs/Tech/` | `TRD.md`, `SECURITY.md`, `PROJECT_STRUCTURE.md`, `TEST_PLAN.md`, `AI_SPEC.md`, `ANALYTICS.md`, planes de versión |
| `Docs/Design/` | `STYLE_BRIEF.md`, `DESIGN_LIQUID.md`, `DESIGN_FROST.md`, `key-screens.json`, `3d-assets.json`, archivos `.pen`, `3D/<asset>/` (brief, referencias, `.blend`, renders) |
| `Docs/Audits/` | `PERFORMANCE_AUDIT.md`, `ARCHITECTURE_AUDIT.md`, `SECURITY_AUDIT.md`, `COMPAT_AUDIT.md`, `L10N_AUDIT.md`, `LEGAL_AUDIT.md`, `APP_STORE_READINESS.md`, `GLOBAL_AUDIT.md` |
| `Docs/Release/` | `APPSTORE.md`, `PRIVACY_POLICY.md`, metadata por idioma, icono master |
| `Docs/` | `PROJECT_LEARNINGS.md` |
| `.appleapplab/` | Lo que instala el equipo: `PATTERNS.md`, `Themes/`, `Research/`, `KNOWN_ISSUES.md`, `PREFERENCES.md`, `VERSION`, templates |
| `.claude/` · `.cursor/` | Skills y reglas del equipo |

**Rutas en los skills.** Cuando un skill cita `PATTERNS.md`, `Themes/…` o `Research/…`, en un proyecto instalado se leen en `.appleapplab/` (`.appleapplab/PATTERNS.md`, `.appleapplab/Research/apple-hig/…`). En el repo AppleAppLab son la fuente que se distribuye y se quedan en su raíz.

**Proyectos sin migrar.** Si los documentos todavía están en la raíz, se leen ahí y no se crea un duplicado en `Docs/`. Steve propone `/clean-folder-project docs` una vez.

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
| `PREFERENCES.md` (fuente) o `.appleapplab/PREFERENCES.md` (instalado) | App Master con `/harvest-learnings`, tras triage con el usuario | Steve, Jonny, Woz, Avie al empezar trabajo nuevo |
| `PROJECT_LEARNINGS.md` | Agente propietario; Steve coordina | Equipo del proyecto; App Master evalúa promoción en la fuente |
| `TEST_PLAN.md` | Bertrand | Phil |
| `COMPAT_AUDIT.md` | Chris | Ivan (archive recheck), Phil |
| `PATTERNS.md` | AppleAppLabUI team (repo fuente) | Jonny, Woz |
| `STYLE_BRIEF.md` | Steve (síntesis de referencias del usuario) | Jonny |
| `Docs/Design/3D/<asset>/BRIEF_3D.md` | Ed, en rondas con Yuno y sus referencias; Yuno lo aprueba | Ed (no modela sin él), Jonny (revisa el final), Phil, `/app-brand-package` |
| `LEGAL_AUDIT.md` | Kate | Steve → usuario → agentes |
| `PRIVACY_POLICY.md` | Kate | Phil |
| `ANALYTICS.md` | Tim | Woz |
| `AI_SPEC.md` | John | Ivan, Woz |
| `L10N_AUDIT.md` | Kim | Woz, Phil |
| `GROWTH.md` | Frederick | Phil, Kara |
| `FINANCE_ADVISOR.md` | Sam | Avie, Jonny, Woz |
| `PERFORMANCE_AUDIT.md` | Steve (rutina `/optimize-app`: Bertrand + Avie) | Woz, Bertrand, `/architecture-audit` (hallazgos 🏗) |
| `ARCHITECTURE_AUDIT.md` | Steve (rutina `/architecture-audit`: Avie lidera) | Woz, Bertrand, Avie (actualiza TRD.md al cerrar etapas) |
| `APP_STORE_READINESS.md` | Steve (rutina `/app-store-ready`: Phil lidera) | Woz, Kate, Ivan, Bertrand, Phil (submit) |
| `PROJECT_STRUCTURE.md` | Steve (rutina `/clean-folder-project`: Avie lidera) | Woz y Steve al crear archivos nuevos (convención "dónde va cada cosa"), Bertrand, Avie (C6 de `/architecture-audit`) |
| `GLOBAL_AUDIT.md` | Steve (rutina `/global-audit`; Avie reconcilia) | Steve para cada `go`; el usuario como tablero; las cuatro rutinas para saber qué ronda está activa |
| `app-web-intake.md` | Steve (rutina `/app-web-intake`, solo a petición del usuario); cada agente escribe sus campos al producir su documento | web-lab `/app-web` al construir el sitio; Steve (`status`) |
| `brand-package/` (manifest, tokens DTCG, íconos, pantallas clave, `CHANGELOG.md`) | Jonny con `/app-brand-package` (generador `lab-brand-package`; Woz capturas, Phil screenshots, Steve CHANGELOG y commit) | web-lab: Cooper lo verifica, Frost y Osmani lo usan; Steve (`status`) |
| `APPSTORE.md` | Phil | — |

## Memoria evolutiva

**Captura automática.** Cualquier agente anota en `PROJECT_LEARNINGS.md` sin que se lo pidan, y lo dice en una línea en el chat ("Anotado en learnings: …"), cuando:

- un fix necesitó más de un intento, o el usuario dijo "sigue igual" o "no funcionó";
- el usuario corrige el mismo valor visual dos veces (material, opacidad, color, radio, spacing, animación), o exporta un tema desde Dev Tools;
- el usuario dice "otra vez", "siempre", "como siempre", "en todas las apps" o "de nuevo";
- el usuario rechaza un default del equipo y elige otro;
- se cierra un `/global-fix`.

Cada entrada lleva **Tipo:** `incidente` (algo falló: causa y fix), `preferencia` (cómo le gusta al usuario) o `propuesta` (un cambio a un skill, regla o proceso del equipo, para App Master). Un incidente recién capturado es `hypothesis`; una preferencia es `observed`; una propuesta es `proposed`. No se anotan typos ni cosas de una sola vez. Al empezar trabajo nuevo, los agentes leen también `PREFERENCES.md` (`.appleapplab/PREFERENCES.md` en proyectos instalados) y aplican lo que corresponda sin volver a preguntar.

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
