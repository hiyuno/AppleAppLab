# SECURITY_AUDIT.md — Fintrol

> Fase: AUDITORÍA (Pase 2). Autor: Ivan (Security Architect, revisor independiente).
> Fecha de esta entrada: 2026-09-15.
> Revisado contra: `SECURITY.md` (controles C-01…C-11, fecha 2026-09-15) y el reporte de implementación de Woz.
> **Commit base del repo:** `9ef1d46df232b80789b3b34bd0c0356ee87657c2` (HEAD de `Fintrol` en el momento de esta auditoría).
> **Estado de control de versiones de `Apps/Fintrol`:** `git status` reporta el directorio completo como `??` (untracked) — el código de Woz aún no está commiteado. Esta auditoría revisó el árbol de trabajo tal como está en disco, no un commit específico dentro de `Apps/Fintrol`. **Acción para Woz/Bertrand:** commitear antes de que Ivan haga el recheck, para que el próximo pase tenga un commit exacto que citar.
> **Build/artefacto revisado:** no existe archive Release. Se inspeccionó (a) el árbol fuente completo, (b) build settings vía `xcodebuild -showBuildSettings` y `mcp__xcode__GetTargetBuildSettings` para destinos `platform=macOS` y `generic/platform=iOS`, configuraciones Debug y Release, (c) un build Debug macOS preexistente en DerivedData (`Fintrol-efxiwqxmopgmpjeeatyjfwwkfjio`, firmado ad-hoc, sin Team ID — **no representativo** de un archive Release firmado), y (d) ejecución real de la suite de tests (`xcodebuild test`, destino macOS) — 49 tests, 8 suites, **TEST SUCCEEDED**, sin warnings de concurrencia en la salida.
> **Limitación de evidencia explícita:** C-08 y C-09 no pueden cerrarse al 100% sin un archive Release firmado real (`codesign -d --entitlements :- <archive>`). Lo verificado aquí es el *source of truth* (`project.yml`, `.entitlements`, build settings evaluados) que alimentará ese archive — es evidencia fuerte pero no sustituye la inspección del binario final que exige el gate de `/app-store-ready`.

---

## Tabla de controles

| Control-ID | Pass/Fail/NA | Severity | Evidence | Risk | Remediation | Source |
|---|---|---|---|---|---|---|
| **C-01** ATS sin excepciones | **Pass** | — | `grep -rn "NSAppTransportSecurity\|NSExceptionDomains\|NSAllowsArbitraryLoads"` sobre `project.yml` y todo `Fintrol/` → 0 matches. `GENERATE_INFOPLIST_FILE=YES`, ningún `INFOPLIST_KEY_NSAppTransportSecurity*` en `project.yml`. No hay `Info.plist` estático que pudiera traer excepciones. | Ninguno detectado | N/A | SECURITY.md C-01 |
| **C-02** sin bypass de `serverTrust` | **Pass** | — | `grep -rn "didReceive challenge\|serverTrust\|NSURLAuthenticationMethodServerTrust\|URLSessionDelegate" Fintrol/` → 0 matches. `ExchangeRateService.swift:29-34` usa `URLSession.shared` sin delegate custom, `session.data(from:)` plano. | Ninguno | N/A | SECURITY.md C-02 |
| **C-03** solo `https://` | **Pass** | — | `Fintrol/Services/ExchangeRateService.swift:27` — endpoint hardcodeado `https://api.frankfurter.app/...`. `grep -rn "http://" Fintrol/Services Fintrol/Core Fintrol/Features Fintrol/App` → 0 matches. | Ninguno | N/A | SECURITY.md C-03 |
| **C-04** parseo defensivo fail-closed | **Pass** | — | `Fintrol/Services/ExchangeRateParser.swift`: usa `JSONSerialization` + cast tipado, extrae el literal numérico de `MXN` con regex sobre el texto crudo (nunca via `Double`), construye `Decimal` directo, valida `plausibleRange = 1...100`, lanza `ParseError` en cada caso adverso — cero `try!`. `ExchangeRateService.refreshRate` envuelve todo en `do/catch` y cae a `fallback(persistedCache:)` en cualquier error o status≠200. `FintrolTests/ExchangeRateParserTests.swift` — **9 tests** (`validPayload`, `truncatedJSON`, `missingField`, `wrongType`, `zeroRateRejected`, `hugeRateRejected`, `nonJSONPayload`, `emptyPayload`, `edgeOfRangeAccepted`), los 9 pasan en `xcodebuild test` de hoy. `FintrolTests/ExchangeRateServiceTests.swift` cubre además la cascada de fallback a nivel actor (5 tests, todos pasan). | Ninguno en el camino de red de Frankfurter | N/A — ver hallazgo **M-01** para un gap relacionado pero distinto (override manual, no viene de Frankfurter) | SECURITY.md C-04 |
| **C-05** cero logging de montos | **Pass** | — | `grep -rn "print(\|os_log(\|Logger(" Fintrol/Core Fintrol/Services Fintrol/Features Fintrol/App Fintrol/UI` → 0 matches en todo el árbol de producto. | Ninguno | N/A | SECURITY.md C-05 |
| **C-06** overlay de privacidad en background (recomendado) | **Pass** (implementado, no solo recomendado) | — | `Fintrol/Features/Root/RootView.swift:53-56` — `if scenePhase != .active { PrivacySnapshotOverlay() }`, cubre el caso por defecto (lock apagado) que `LockView` solo no alcanza. `PrivacySnapshotOverlay` (líneas 63-73) no renderiza ningún monto, solo un ícono genérico. | Bajo — riesgo residual documentado en SECURITY.md §7.4 queda cerrado, no solo aceptado | N/A | SECURITY.md C-06 |
| **C-07** `Decimal` de extremo a extremo | **Pass** | — | `grep -rn "Double" Fintrol/Core/Engine Fintrol/Core/Models` → único match es un comentario (`CurrencyConversion.swift:3`), cero uso real. `LineItem.amount`, `RecurringItem.amount`, `Subscription.price`, `ExchangeRateCache.rate` — todos `Decimal`. `ExchangeRateParser` evita el round-trip por `Double` extrayendo el literal del JSON crudo. | Ninguno | N/A | SECURITY.md C-07 |
| **C-08** entitlements = §5 exactos | **Pass (fuente) / No verificable al 100% (artefacto)** | — (ver limitación) | `Fintrol/Fintrol-iOS.entitlements` y `Fintrol/Fintrol-macOS.entitlements` comparados línea por línea contra SECURITY.md §5 — **coinciden exactamente**, sin ninguna key fuera de lista, sin `keychain-access-groups`, sin App Groups, sin `files.user-selected.read-write`. `CODE_SIGN_ENTITLEMENTS` / `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` en `project.yml` apuntan a los archivos correctos. **No hay archive Release** para correr `codesign -d --entitlements :- <archive>` y confirmar ausencia de `get-task-allow` en el binario firmado real — el build Debug inspeccionado en DerivedData está firmado ad-hoc sin entitlements embebidos (no representativo). | Bajo hoy (fuente correcta); el riesgo real es no detectar drift entre fuente y artefacto firmado | Repetir C-08 sobre el primer archive Release real antes de Phil/Craig, por mandato propio del gate de Ivan (SKILL.md Pase 2, punto 5) | SECURITY.md C-08 |
| **C-09** Hardened Runtime + Sandbox macOS | **Pass (build settings) / No verificable al 100% (artefacto)** | — (ver limitación) | `xcodebuild -showBuildSettings -configuration Release -destination 'platform=macOS'` → `ENABLE_HARDENED_RUNTIME=YES`, `CODE_SIGN_ENTITLEMENTS=Fintrol/Fintrol-macOS.entitlements`. El mismo resultado se repite en Debug macOS (no depende de configuración, solo de `[sdk=macosx*]`). `Fintrol-macOS.entitlements` declara `com.apple.security.app-sandbox=true`. Ver hallazgo **L-01** sobre una discrepancia cosmética (`ENABLE_APP_SANDBOX` build setting). Sin archive Release, no se corrió `codesign -d --entitlements :- <archive>` sobre el binario final. | Bajo | Repetir sobre el archive Release real | SECURITY.md C-09 |
| **C-10** Swift 6 strict concurrency completo | **Pass** | — | `project.yml` → `SWIFT_STRICT_CONCURRENCY: complete` a nivel base. `GetTargetBuildSettings` confirma `SWIFT_STRICT_CONCURRENCY=complete`, `SWIFT_VERSION=6.0`, `EFFECTIVE_SWIFT_VERSION=6`. Se ejecutó `xcodebuild test -destination 'platform=macOS'` hoy: **49 tests, 8 suites, TEST SUCCEEDED**, compiló sin errores de concurrencia (con `complete` cualquier violación de Sendable rompe el build, no solo advierte) y sin warnings suprimidos visibles en la salida. | Ninguno | N/A | SECURITY.md C-10 |
| **C-11** bloqueo biométrico opcional | **Pass**, con una observación no bloqueante | Low (ver **L-02**) | `Fintrol/Features/Lock/BiometricLockStore.swift`: usa `.deviceOwnerAuthentication` (línea 63, 70) — nunca `.deviceOwnerAuthenticationWithBiometrics` a solas; `LockView.swift:12` usa el mismo policy solo para elegir el ícono. `isAuthenticated` es `private(set)` en memoria de un `@MainActor @Observable`, nunca escrito a `UserDefaults` ni Keychain (`grep -rn "Keychain" Fintrol/` → solo comentarios explicando que no se usa). Solo `isLockEnabled` (el switch, no el resultado de auth) persiste vía `UserDefaults` (`BiometricLockStore.swift:22,31`) — consistente con el diseño pedido. Reset a `false` en cada cold start (el valor por defecto de la propiedad ya es `false`; `resetForColdStart()` además limpia `backgroundedAt`) y tras ≥60s en background/inactive (`handleScenePhaseChange`, líneas 38-50). `project.yml` → `INFOPLIST_KEY_NSFaceIDUsageDescription: "Fintrol usa Face ID para proteger el acceso a tu presupuesto."` — específico, no genérico. `FintrolApp.swift:32-34` conecta `scenePhase` al store. `RootView.swift:39` no monta ninguna vista de contenido financiero mientras `shouldPresentLockScreen` es true. | Bajo | Confirmar con Jonny/producto que 60s (no ≤30s, el default "corto" que SECURITY.md sugería) es la decisión final, y dejarlo escrito en SECURITY.md §9 como decisión, no como omisión | SECURITY.md C-11 |

---

## Hallazgos adicionales (fuera de la tabla de controles C-01…C-11)

### M-01 — El override manual del tipo de cambio no valida rango superior (Medium)

**Evidencia:**
- `Fintrol/Features/Settings/SettingsView.swift:37` — única validación: `Decimal(string: manualRateText, ...) != nil && value > 0`. No hay cota superior.
- `Fintrol/Core/ExchangeRateStore.swift:49-56` (`applyManualOverride`) — recibe el `Decimal` ya "validado" por la UI y lo persiste directo como fila de `ExchangeRateCache` (`persist(result, context:)`, línea 63-72), **sin pasar por `ExchangeRateParser.plausibleRange` (1...100)** ni ningún otro chequeo de plausibilidad.
- Contraste: `ExchangeRateParser.parseUSDToMXNRate` (la ruta de red) sí aplica `plausibleRange` y rechaza valores absurdos (C-04). La ruta manual del usuario, que alimenta exactamente el mismo modelo (`ExchangeRateCache`) y exactamente el mismo fallback usado cuando Frankfurter no responde, no tiene ese control.

**Riesgo:** No es un vector de ataque externo — es el propio usuario tecleando en su Ajustes, en su dispositivo. Pero el dato persistido se convierte en el **fallback futuro** (`ExchangeRateStore.refresh` lee `latestCache` y lo usa cuando la API falla), y alimenta directamente el cálculo de "Sobrante" — el dato financiero más sensible de toda la app según SECURITY.md §3. Un error de dedo (`16200` en vez de `16.20`, o pegar un número con un cero de más) se aplica de inmediato a `currentRate` y persiste silenciosamente como la tasa de respaldo, sin ningún mensaje de advertencia ni tope. Esto no es exclusivamente un problema de seguridad — es sobre todo un defecto de integridad de datos — pero cae directamente dentro del criterio que SECURITY.md exige verificar ("que el override manual valide rango"), y el propio diseño de C-04 ya estableció cuál es el rango razonable (`1...100`) que aquí simplemente no se reutiliza.

**Remediation para Woz:** Reutilizar `ExchangeRateParser.plausibleRange` (o extraerlo a una constante compartida, p. ej. `ExchangeRateParser.plausibleRange` ya es `static let` accesible) en `SettingsView` o en `ExchangeRateStore.applyManualOverride`, y mostrar un mensaje de error en la UI en vez de aceptar silenciosamente el valor fuera de rango o simplemente no aplicar el override. Sugerido: mover el guard a `applyManualOverride` (defensa en profundidad — no solo en la vista) para que cualquier futuro caller quede protegido igual.

**Criterio de verificación para el recheck:** `ExchangeRateStore.applyManualOverride` rechaza (o clamp explícito, a decidir con Woz/Jonny) un valor fuera de `1...100`; test unitario nuevo que alimente `applyManualOverride` con `0.5`, `999999` y confirme que `ExchangeRateCache` no queda con esos valores.

---

### M-02 — Enhanced Security (Xcode 27) no está habilitado a nivel de proyecto (Medium)

Ejecuté el diagnóstico de la skill oficial `audit-xcode-security-settings` en modo solo-lectura (sin `Plan & Approve`, sin `UpdateTargetBuildSetting`/`AddEntitlement`) contra el target `Fintrol`, vía `mcp__xcode__GetTargetBuildSettings`.

**Evidencia:**
- `ENABLE_ENHANCED_SECURITY = NO` (default, no forzado explícitamente — no hay entrada en `project.yml`, así que no es "deliberadamente desactivado" con una razón documentada, simplemente nunca se activó).
- En cascada, esto deja apagado: `ENABLE_POINTER_AUTHENTICATION=NO` (`$(ENABLE_ENHANCED_SECURITY)`), `CLANG_ENABLE_STACK_ZERO_INIT=NO`, `ENABLE_SECURITY_COMPILER_WARNINGS=NO`, `GCC_WARN_SHADOW=NO`.
- Sin entitlements `com.apple.security.hardened-process.*` en ninguno de los dos `.entitlements` (`grep -rn "hardened-process" Fintrol/*.entitlements` → 0 matches).
- El proyecto es **Swift puro** (41 archivos `.swift`, 0 `.c`/`.cpp`/`.m`/`.mm`) — así que el grupo "Warnings" de la skill (compiler/analyzer/clang-tidy, orientado a C/ObjC/C++) no aplica de forma significativa aquí; no lo cuento como hallazgo aparte.
- `ENABLE_HARDENED_RUNTIME` y App Sandbox (C-09) son **independientes** de Enhanced Security y ya están correctos — este hallazgo es sobre una capa de hardening adicional y más nueva, no sobre lo que C-08/C-09 cubren.

**Riesgo:** Sin exploit conocido en este código — es hardening en profundidad (pointer authentication en `arm64e`, zero-init de stack, memoria endurecida), no un control que hoy esté mitigando una vulnerabilidad identificada en Fintrol. Para una app Tier 2 con datos financieros personales en Xcode 27/iOS 26+, es la postura por defecto que Apple está empujando para proyectos nuevos.

**Remediation para Woz:** Agregar `ENABLE_ENHANCED_SECURITY: YES` a nivel de proyecto en `project.yml` (`settings.base`), regenerar con XcodeGen, y **probar en hardware real** (no simulador) antes de shippear — pointer authentication y stack zero-init pueden exponer bugs latentes que hoy pasan desapercibidos. No lo marco bloqueante porque (a) es defensa en profundidad, no mitigación de un hallazgo explotable, y (b) activarlo sin probar en dispositivo real es en sí mismo un riesgo de estabilidad que no quiero introducir a ciegas en un recheck exprés. Sí debe entrar al roadmap con owner y fecha si se pospone más allá del primer archive Release.

**Criterio de verificación para el recheck:** `GetTargetBuildSettings` (o `xcodebuild -showBuildSettings`) confirma `ENABLE_ENHANCED_SECURITY=YES` a nivel proyecto; `RunAllTests`/`xcodebuild test` pasa igual tras el cambio; Woz confirma explícitamente que hizo al menos una prueba manual en un dispositivo físico (arm64e) sin crashes nuevos.

---

### L-01 — `ENABLE_APP_SANDBOX` (build setting) muestra `NO` pese a que el entitlement real está en `true` (Low / informativo)

**Evidencia:** `GetTargetBuildSettings` reporta `ENABLE_APP_SANDBOX=NO`, mientras que `Fintrol-macOS.entitlements` declara `com.apple.security.app-sandbox=true` y `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=YES`. Esto es esperado cuando XcodeGen gestiona el `.entitlements` directamente en vez de usar el editor de Signing & Capabilities de Xcode (que es quien sincroniza `ENABLE_APP_SANDBOX`) — el archivo de entitlements sigue siendo la fuente autoritativa que `codesign` firma, así que **no es un fallo funcional hoy**.

**Riesgo:** Si alguien en el futuro abre el proyecto en Xcode y toca "Signing & Capabilities" pensando que el sandbox está apagado (porque el toggle de la UI lo muestra así), podría desactivarlo por error creyendo que lo está activando por primera vez, o Xcode podría reescribir el `.entitlements` a partir de ese estado inconsistente.

**Remediation:** No bloqueante. Recomendado (no urgente): documentar en un comentario junto a `CODE_SIGN_ENTITLEMENTS` en `project.yml`, o en `PROJECT_LEARNINGS.md`, que el sandbox se gestiona por archivo de entitlements directo y que el toggle de Xcode no debe usarse para esto. Confirmar con `codesign -d --entitlements :- <archive>` en el primer archive real que `com.apple.security.app-sandbox=true` sobrevive intacto.

---

### L-02 — Umbral de re-bloqueo de 60s vs. el default "corto" sugerido en SECURITY.md (Low)

Ya cubierto en la fila C-11 de la tabla. SECURITY.md C-11 sugería "default corto, ej. inmediato o ≤30s — Jonny define el valor exacto." Woz implementó 60s (`BiometricLockStore.reauthenticationThreshold`). No es un defecto — SECURITY.md explícitamente delegaba el valor exacto a Jonny — pero no encontré evidencia de que Jonny haya confirmado 60s específicamente. Pido que quede registrado como decisión explícita, no como default implícito de Woz.

---

### Info — Código de Fintrol no commiteado

`git status` muestra todo `Apps/Fintrol/` como `??` (untracked) sobre el commit `9ef1d46d`. No es un hallazgo de seguridad, pero afecta la trazabilidad exigida por este mismo documento ("identifica exactamente commit... revisado"). Pido a Woz/Bertrand commitear antes del próximo recheck de Ivan.

---

## RECHECK — 2026-09-15 (mismo día, segundo pase tras el fix de Woz)

> Revisado contra el árbol de trabajo actual (sigue `??` sin commitear, ver Info abajo). Evidencia recolectada leyendo código, `grep`, `xcodebuild -showBuildSettings` y `xcodebuild test -scheme Fintrol -destination 'platform=macOS'` ejecutado en esta sesión.

### M-01 — CERRADO

- `Fintrol/Core/ExchangeRateStore.swift:60-74` (`applyManualOverride`) ahora hace `guard ExchangeRateParser.plausibleRange.contains(rate) else { lastManualOverrideError = .outOfRange; return false }` antes de persistir — el guard vive en el Store (defensa en profundidad), no solo en la vista, tal como pedí.
- `SettingsView.swift:44-48` consume el `Bool` de retorno y muestra `"El tipo de cambio debe estar entre \(...lowerBound) y \(...upperBound)."` en vez de fallar silenciosamente.
- Mismo patrón replicado en el override por quincena: `Features/Period/PeriodView.swift:304-306` valida `ExchangeRateParser.plausibleRange.contains(value)` con el mismo mensaje de error antes de aplicar el override — cierra el gap que mi hallazgo original no mencionó explícitamente (el override de `PeriodView` es una segunda ruta hacia el mismo problema) pero que Woz corrigió igual, correctamente.
- `FintrolTests/ExchangeRateStoreTests.swift:23-68` — 4 tests nuevos confirmados por lectura: `0.5` rechazado (`accepted == false`, `lastManualOverrideError == .outOfRange`), `999999` rechazado igual, `18.50` aceptado, y una prueba explícita de que `16200` no sobrescribe un valor previamente válido (`20.00` se mantiene). Cubre exactamente el criterio de verificación que pedí (`0.5`, `999999`, confirmar que `ExchangeRateCache` no queda contaminado).
- `xcodebuild test -scheme Fintrol -destination 'platform=macOS'` ejecutado hoy en esta sesión → **53 tests, 9 suites, TEST SUCCEEDED** (antes: 49/8 — la suite nueva `ExchangeRateStoreTests` aporta los 4 tests). Sin fallos, sin warnings de concurrencia en la salida.

**Veredicto M-01: Closed.**

### L-01 — CERRADO

- `project.yml:73` ahora declara `"ENABLE_APP_SANDBOX[sdk=macosx*]": YES`.
- Confirmado en build settings evaluados, no solo en fuente: `xcodebuild -showBuildSettings -configuration Release -destination 'platform=macOS' -scheme Fintrol` → `ENABLE_APP_SANDBOX = YES` (antes `NO`). El drift cosmético entre el toggle de Xcode y el entitlement real queda resuelto.

**Veredicto L-01: Closed.**

### L-02 — CERRADO

- `SECURITY.md` §9, ítem 7: *"Decisión confirmada (Steve): el umbral de re-bloqueo biométrico queda en 60s..."*, marcado `Cerrado — no riesgo aceptado abierto, es el valor final.` Es exactamente el registro explícito que pedí — ya no es un default implícito de Woz, es una decisión de producto con owner (Steve) documentada.

**Veredicto L-02: Closed (Accepted — 60s es el valor final, no un placeholder).**

### M-02 — SIGUE ABIERTO, pero con diagnóstico confirmado y una mitigación concreta que Woz no probó

**Lo que Woz hizo es razonable y está bien evidenciado, no solo "revertido a ciegas":**

- Confirmé en código: `project.yml:22-27` tiene el setting comentado con una nota que cita `SECURITY.md §9` y `PROJECT_LEARNINGS.md FIN-2026-004`, explicando la causa exacta (arm64e vs arm64 en el paquete local).
- Confirmé en build settings evaluados: `ENABLE_ENHANCED_SECURITY = NO`, `ARCHS = arm64 x86_64` (sin `arm64e`) hoy.
- `PROJECT_LEARNINGS.md` FIN-2026-004 documenta el síntoma exacto (`Unable to resolve module dependency: 'AppleAppLabUI'`, log mostrando `AppleAppLabUI` compilando `-target arm64-apple-macos14.0` mientras `Fintrol` compila `-target arm64e-apple-macos26.0` en la misma invocación) y lo marca `hypothesis` con honestidad — no pretende certeza que no tiene.
- La causa raíz es **plausible y, de hecho, es un comportamiento documentado**, no una hipótesis sin respaldo: la propia referencia local de la skill oficial `audit-xcode-security-settings` (`~/.claude/skills/audit-xcode-security-settings/references/pointer-authentication.md`, sección "Swift Package Manager Support") dice textualmente: *"Swift Package dependencies are not automatically built for arm64e when the main project enables pointer authentication."* Esto confirma la hipótesis de Woz al 100% — no es una interacción rara ni un bug, es el comportamiento esperado y documentado de Xcode 27 con paquetes SPM locales.

**La corrección: existe una vía soportada que Woz no probó.**

La misma referencia da el fix exacto — **flags a nivel de workspace**, no en `Package.swift` ni en `project.yml`:

```bash
plutil -create xml1 Fintrol.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
plutil -insert macOSPackagesShouldBuildARM64e -bool YES Fintrol.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
plutil -insert iOSPackagesShouldBuildARM64e -bool YES Fintrol.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
```

Esto le dice a Xcode que resuelva los paquetes SPM locales (incluyendo `Packages/AppleAppLabUI`) también en `arm64e`, en vez de dejarlos en el default de `ARCHS_STANDARD` sin `arm64e`. Es la vía que Apple documenta específicamente para este caso — no `unsafeFlags`/`cSettings`/`swiftSettings` en `Package.swift` (que no tienen forma estándar de forzar una arquitectura adicional en un target SPM resuelto por Xcode), y no un truco por xcconfig del target de la app (que es exactamente lo que ya está fallando).

**Nota operativa:** `WorkspaceSettings.xcsettings` vive dentro del `.xcodeproj` generado por XcodeGen (`Fintrol.xcodeproj/project.xcworkspace/...`), así que XcodeGen probablemente lo regenera o lo ignora en cada `xcodegen generate` — Woz/Craig deben confirmar si sobrevive una regeneración o si hay que aplicarlo post-generate (script en el pipeline de Craig, o un `postGenCommand` en `project.yml` si XcodeGen lo soporta). No lo verifiqué en esta sesión porque no debo tocar el proyecto ni ejecutar `xcodegen generate` con el setting activo — eso le toca a Woz probar.

**Alternativa parcial, sin arm64e, disponible hoy sin este riesgo:** de la subcascada de `ENABLE_ENHANCED_SECURITY`, solo `ENABLE_POINTER_AUTHENTICATION` fuerza `arm64e` (confirmado por la doc de la skill: *"the build system appends arm64e to ARCHS_STANDARD whenever arm64 is already present"* — específico de pointer authentication, no de la cascada completa). `GCC_WARN_SHADOW`, `ENABLE_SECURITY_COMPILER_WARNINGS`, `CLANG_CXX_STANDARD_LIBRARY_HARDENING`, `CLANG_ENABLE_C_TYPED_ALLOCATOR_SUPPORT`/`CLANG_ENABLE_CPLUSPLUS_TYPED_ALLOCATOR_SUPPORT` no dependen de `arm64e` y no deberían romper el link contra el paquete local. Como Fintrol es 100% Swift (sin C/C++/ObjC), el valor real de estos sub-settings es bajo — pero si Woz quiere ganar algo de terreno sin tocar `ARCHS`, puede habilitarlos individualmente en vez de vía `ENABLE_ENHANCED_SECURITY = YES` completo, mientras se resuelve la vía de workspace para pointer authentication.

**Discrepancia de documentación que Woz/Bertrand deben corregir antes del siguiente recheck:** `SECURITY.md` §9, ítem 8, dice hoy *"`ENABLE_ENHANCED_SECURITY: YES`... está activado a nivel de `project.yml`... y confirmado en build settings"* — esto es **falso** contra el estado real (`ENABLE_ENHANCED_SECURITY = NO`, setting comentado). El texto de ese ítem describe el estado que Woz *intentó* dejar, no el que dejó tras revertir. Esto no es un hallazgo de seguridad nuevo, pero si queda así en el documento de riesgos aceptados, cualquiera que lo lea (incluido Phil en `/app-store-ready`) creerá que el control ya está activo cuando no lo está. Corregir el texto del ítem 8 para que diga lo que `PROJECT_LEARNINGS.md` FIN-2026-004 ya dice correctamente: revertido, riesgo aceptado temporal, pendiente la vía de `WorkspaceSettings.xcsettings`.

**Veredicto M-02: Open — Accepted Risk (temporal), con acción concreta pendiente.**
- Owner: Woz (probar `WorkspaceSettings.xcsettings` + confirmar que sobrevive `xcodegen generate`; si sobrevive, reactivar `ENABLE_ENHANCED_SECURITY: YES` y correr tests + build en ambas plataformas; probar en hardware físico arm64e antes de marcar verificado).
- Fecha objetivo: antes del primer archive Release — no bloquea a Bertrand hoy.
- Acción adicional: corregir el texto de `SECURITY.md` §9 ítem 8 para que refleje el estado real (Woz o Bertrand, antes del próximo recheck).

### Info (commit) — SIGUE ABIERTO

`git status` sobre `Apps/Fintrol/` sigue reportando el árbol como `??` (untracked), mismo commit base `9ef1d46d`. No bloqueante para este recheck (revisé el árbol de trabajo real), pero repito el pedido: commitear antes del próximo pase para que haya un commit exacto que citar.

---

## RECHECK 2 — 2026-09-15 (mismo día, tercer pase: Banxico SIE + Keychain + `Loan`)

> Cambio de alcance (SECURITY.md, actualización 2026-09-15): Frankfurter sale, entra Banxico SIE con token `Bmx-Token` guardado en Keychain (control **C-12**). Se añade también la superficie `Loan` (préstamos, APR/principal). Evidencia recolectada leyendo `Fintrol/Services/ExchangeRateService.swift`, `Fintrol/Services/ExchangeRateParser.swift`, `Fintrol/Core/ExchangeRateStore.swift`, `Fintrol/Core/KeychainStore.swift`, `Fintrol/Features/Settings/SettingsView.swift`, `Fintrol/Core/Models/Loan.swift`, `Fintrol/Core/Engine/LoanEngine.swift`, `Fintrol/Features/Loans/*.swift`, los `.entitlements` de ambas plataformas, `project.yml`, y ejecutando `grep` + `xcodebuild test -scheme Fintrol -destination 'platform=macOS'` en esta sesión.

### C-12 — Banxico SIE: token, red, parseo — CERRADO

- **Token solo en Keychain, con la accesibilidad correcta.** `Fintrol/Core/KeychainStore.swift:33` — `kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` en el `SecItemAdd`. `grep -rn "kSecAttrSynchronizable"` en todo `Apps/Fintrol/` → única coincidencia es un comentario explicando por qué **no** se usa (línea 6 del mismo archivo) — no hay ningún `kSecAttrSynchronizable = true` real en el código. Confirma la decisión de SECURITY.md §5/§6.1: sin sync a iCloud Keychain.
- **Nunca en UserDefaults/`@Model`/CloudKit/logs/`description`.** `grep -rn "UserDefaults" Fintrol/` con filtro `token` → único hit es un comentario en `ExchangeRateStore.swift:6` diciendo explícitamente que el token nunca va ahí. `grep -rn "print(\|os_log(\|Logger("` sobre `Fintrol/Core Fintrol/Services Fintrol/Features` → **0 matches** en todo el árbol de producto (no solo en el código del token — confirma C-05 sigue intacto). `grep -rn "var description\|CustomStringConvertible\|CustomDebugStringConvertible"` sobre `Core`/`Services` → 0 matches, no hay ningún override que pudiera filtrar el token vía interpolación accidental (`"\(token)"` en un `Loan`/`RecurringItem` u otro tipo). `Loan` (`Core/Models/Loan.swift`) es un `@Model` sin ningún campo relacionado al token — confirmado por lectura completa del archivo.
- **`SecureField` + revelar + "Probar token" sin filtrar el valor.** `SettingsView.swift:202-204` alterna `TextField`/`SecureField` según un toggle explícito (`revealToken`, línea 218 con `accessibilityLabel` correcto). El botón "Probar token" (línea 222) llama `testToken()` (línea 305) que solo produce tres mensajes fijos (`"Token válido."`, `"Token inválido — verifica que lo copiaste completo."`, `"No se pudo verificar — revisa tu conexión e intenta de nuevo."`) — ninguno interpola `tokenText` ni ningún valor derivado del token. Mismo patrón en el mensaje de error persistente de token inválido tras un fetch automático (línea 241: `"Tu token de Banxico no es válido o expiró — revísalo arriba."`, sin el valor). `ExchangeRateService.testToken` (líneas 88-98) y `KeychainStore` no tienen ningún `return`/log que exponga el valor crudo salvo `KeychainStore.read()` en sí, que es la lectura legítima para rellenar el campo al abrir Ajustes (línea 281 de `SettingsView.swift`) — comportamiento esperado, no una fuga.
- **ATS sin excepciones para `banxico.org.mx`.** `grep -rn "NSAppTransportSecurity\|NSExceptionDomains\|NSAllowsArbitraryLoads" project.yml Fintrol/` → 0 matches. El endpoint está hardcodeado como literal `https://` (`ExchangeRateService.swift:39`), y `grep -rn "http://" Fintrol/Services` → 0 matches (mismo criterio que C-03 original).
- **Parseo fail-closed con `"N/E"` como ausencia, no `0`.** `ExchangeRateParser.swift:38-40` — `guard dato.dato != "N/E" else { throw ParseError.dataUnavailable }` ocurre **antes** de cualquier intento de `Decimal(string:)`, así que `"N/E"` nunca llega a convertirse en número. `ExchangeRateService.swift` propaga cualquier `ParseError` (incluido `.dataUnavailable`) al `catch` genérico de `refreshRate`, que cae a `fallback(persistedCache:)` — mismo comportamiento que cualquier otro fallo de parseo. Confirmado también por el test `ExchangeRateServiceTests.swift:89` (`"\"N/E\" (non-business day) falls back to cache instead of treating the day as 0"`).
- **401/403 (y el 400 real observado) a caché, no a crash ni a "red caída" genérica.** `ExchangeRateParser.isInvalidTokenError` (líneas 54-59) reconoce **400/401/403** con el shape `{"error":{"mensaje":...}}` de Banxico — el comentario en el archivo documenta que Woz probó contra el servicio real el 2026-09-15 y encontró **400**, no 401/403 como asumía SECURITY.md/TRD originalmente; esto es una corrección de mi propio documento basada en evidencia real, no un defecto de Woz — lo acepto y lo reflejo abajo. `ExchangeRateService.refreshRate` (líneas 69-74) distingue explícitamente `.invalidToken` de un fallback genérico. `ExchangeRateStore.refresh` (líneas 81-93) maneja `.invalidToken` como su propio caso: usa caché si existe, marca `isTokenInvalid = true`, nunca crashea. Cubierto por tests (`ExchangeRateServiceTests.swift:64`, `ExchangeRateParserTests.swift:93,101,108,114` — incluye un test negativo explícito de que un 500 con el mismo shape **no** cuenta como invalid-token, evitando falsos positivos).
- **Entitlements sin cambios.** `Fintrol-macOS.entitlements` y `Fintrol-iOS.entitlements` comparados contra la versión ya auditada en el pase anterior — idénticos, sin `keychain-access-groups`, sin ningún entitlement nuevo. Consistente con la decisión de SECURITY.md §5: Keychain del propio proceso bajo App Sandbox no requiere entitlement adicional.
- **1 request/día.** `ExchangeRateService.swift:40` — `throttleInterval: TimeInterval = 86_400`, aplicado en `refreshRate` (líneas 58-60) antes de cualquier fetch automático; `testToken` (la acción explícita "Probar token") bypassa el throttle a propósito, documentado en el comentario de la línea 86-87 — comportamiento correcto: un fetch manual disparado por el usuario no debe estar sujeto al límite pensado para el refresh automático.
- **Sin rastro de Frankfurter.** `grep -rin "frankfurter" --include="*.swift" --include="*.yml" .` sobre todo `Apps/Fintrol/` → **0 matches**.
- **Corrección propia a mi documento:** SECURITY.md/TRD originalmente asumían 401/403 para token inválido; el comportamiento real de Banxico es 400. Pido que quede una nota de una línea en SECURITY.md C-12 (ya debería decir esto tras la próxima edición) para que quien lea el control no asuma 401/403 exclusivamente — Woz ya lo documentó correctamente en el código, falta reflejarlo en SECURITY.md mismo. No lo considero un hallazgo nuevo porque el código y los tests ya están alineados con la realidad; es housekeeping documental.

**Veredicto C-12: Closed.**

### Superficie nueva — `Loan` (APR/principal) — Pass

- `Core/Models/Loan.swift` — `principal: Decimal` (línea 15), `apr: Decimal` (línea 17), `paymentOverride: Decimal?` (línea 22) — mismo patrón `Decimal` de extremo a extremo que el resto del modelo financiero (C-07), sin ningún `Double`.
- `grep -rn "print(\|os_log(\|Logger("` sobre `Core/Engine/LoanEngine.swift` y `Features/Loans/*.swift` → 0 matches — sin logging de montos/APR, consistente con C-05.
- No introduce entitlements, red ni Keychain — es SwiftData/CloudKit puro, mismo trust boundary ya cubierto en §7.3 de SECURITY.md (sin cifrado de campo adicional, decisión ya aceptada). No amerita un control nuevo propio; queda cubierto por C-05/C-07 existentes. Sugiero a Woz que si `Loan` gana un campo de texto libre similar a `Subscription.card` en el futuro, se revise igual que ese caso (§3 de SECURITY.md ya lo señala como matiz).

**Veredicto `Loan`: Pass, sin hallazgos nuevos.**

### Regresión — CERRADO

`xcodebuild test -scheme Fintrol -destination 'platform=macOS'` ejecutado en esta sesión → **113 tests, 13 suites, TEST SUCCEEDED** (antes 53/9 — las suites nuevas `KeychainStoreTests`, `ExchangeRateServiceTests` ampliada, `ExchangeRateParserTests` ampliada y `LoanEngineTests` aportan el resto). Sin fallos.

### SECURITY.md §9 ítem 8 (Enhanced Security) — verificado, ya corregido

Releí SECURITY.md §9 ítem 8 en esta sesión: ya dice correctamente que `ENABLE_ENHANCED_SECURITY` está **comentado/apagado**, no activo — la corrección que pedí en el RECHECK anterior ya está aplicada (queda de mi propia edición previa de SECURITY.md, no de Woz). Confirmado de nuevo contra `project.yml:27` (`# ENABLE_ENHANCED_SECURITY: YES`, comentado). No hay discrepancia documental pendiente en este ítem.

---

## RECHECK 3 — 2026-09-15 (mismo día, cuarto pase: `BackupService`, revolving, Inversiones, swipes)

> Recheck incremental, sin cambios de código de mi parte, sin commit. Evidencia: lectura completa de `Fintrol/Core/Engine/BackupService.swift`, `Fintrol/App/FintrolApp.swift`, `Fintrol/Features/Settings/SettingsView.swift` (bloque de export/import), `Fintrol/Core/Models/Loan.swift`, `Fintrol/Core/Models/FintrolEnums.swift`, `Fintrol/Core/Engine/LoanEngine.swift`, `Fintrol/Features/Investments/InvestmentsView.swift`, `Fintrol/Core/Migration/SchemaV2.swift` y `AppMigrationPlan.swift`, `Fintrol/UI/LineItemRow.swift`, más `grep` dirigidos y `xcodebuild test -scheme Fintrol -destination 'platform=macOS'` ejecutado en esta sesión.

### `BackupService` (export/import completo) — Pass, con una recomendación Low no bloqueante

- **El token nunca se exporta.** `BackupService.Backup`/`exportBackup` (líneas 11-19, 106-165) no tiene ningún campo ni lectura relacionada a Keychain/token — confirmado por lectura completa de la struct y la función. El propio comentario del archivo (líneas 8-9) lo declara explícito: *"Every persisted field round-trips except the Banxico token, which lives only in the Keychain and is never written to disk in plaintext."* `grep -rn "Keychain\|Bmx-Token\|token" Fintrol/Core/Engine/BackupService.swift` → 0 matches de código real (solo el comentario que lo excluye).
- **Sin copias temporales propias sin Data Protection.** El export usa `FileDocument`/`fileWrapper(configuration:)` (`SettingsView.swift:469-474`) que construye los bytes en memoria (`BackupService.encode`) y los entrega a SwiftUI/`fileExporter`, que escribe directo al destino elegido por el usuario — la app no escribe manualmente a `Caches/`/`tmp/` en ningún punto de este flujo (`grep -rn "NSTemporaryDirectory\|/tmp/\|FileManager.default.url.*caches" Fintrol/Core/Engine/BackupService.swift Fintrol/Features/Settings/SettingsView.swift` → 0 matches). El propio mecanismo de `fileExporter` de SwiftUI puede usar un `tmp/` interno del sistema antes de mover el archivo al destino final elegido por el usuario — eso es responsabilidad de SwiftUI/UIDocumentPickerViewController, no de la app, y está fuera de lo que Ivan puede auditar en código de producto.
- **Importación fail-closed + confirmación.** `BackupService.decode` (líneas 185-189) usa `JSONDecoder` tipado con `try?` — cualquier JSON malformado devuelve `nil`, y `importFullBackup` (`SettingsView.swift:195-207`) lo trata como error explícito (`"El archivo no es un respaldo válido de Fintrol."`) sin tocar `context` en absoluto — no hay importación parcial en el camino de fallo. El `confirmationDialog` destructivo (`SettingsView.swift:175-184`, texto *"Esto reemplaza TODOS los datos actuales..."*) se dispara **antes** de que `importFullBackup` pueda ejecutarse — el botón "Reemplazar todo" es la única vía al import real, con "Cancelar" como alternativa explícita. Confirmado también por `security-scoped resource` correcto (`url.startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()` con `defer`, líneas 196-197).
- **El backup automático de `Documents/Backups/` no corre en Release, y no filtra montos.** `FintrolApp.swift:38-51` — la llamada a `Self.deleteStoreFiles` (que internamente invoca `backupStoreFiles`) está dentro de un `#if DEBUG ... #else ... #endif`: en Release, la rama que se compila es la del `#else` (línea 48-50), que va directo a `emergencyInMemoryContainer` sin pasar nunca por `deleteStoreFiles`/`backupStoreFiles`. Confirmado por lectura línea por línea, no solo por el nombre de la función. El único `print(...)` de todo este mecanismo (línea 86) no interpola ningún monto/título — solo el nombre de archivo con timestamp (`"Backed up unreadable store to Documents/Backups/store-<fecha>.sqlite..."`), consistente con C-05.
  - **Recomendación Low, no bloqueante:** `deleteStoreFiles`/`backupStoreFiles` están definidas fuera del `#if DEBUG` (solo su *llamada* está adentro) — funcionalmente nunca se ejecutan en Release porque el call site no existe en esa rama del preprocesador, y `DEAD_CODE_STRIPPING: YES` (ya confirmado en `project.yml`) debería eliminarlas del binario enlazado al no tener ningún referenciador vivo. Aun así, para que quede blindado por el propio compilador y no dependa de que el linker las stripee correctamente, sugiero a Woz envolver las dos funciones (no solo la llamada) en `#if DEBUG ... #endif` — higiene de código, no una vulnerabilidad activa hoy.

**Veredicto `BackupService`: Pass.**

### Modo `.revolving` de préstamos — Pass

- `Loan.modeRaw: String` (default `LoanMode.fixedTerm.rawValue`) y `Loan.expectedPayment: Decimal?` (default `nil`) — ambos campos nuevos con default, sin ningún `Double` (`Core/Models/Loan.swift:27,30`). `LoanEngine.revolvingSchedule` opera enteramente sobre `Decimal` (`Core/Engine/LoanEngine.swift:192-261`, confirmado por lectura — `principal`, `expectedPayment`, intereses, todos `Decimal`).
- `grep -rn "print(\|os_log(\|Logger("` sobre `LoanEngine.swift` y `Features/Loans/*.swift` → 0 matches — sin logging de montos/APR/`expectedPayment`.
- **Migración "ligera con defaults, sin pérdida de datos":** estos campos se agregaron directamente a `SchemaV2` (no una `SchemaV3` nueva), documentado explícitamente en `AppMigrationPlan.swift` con una justificación que revisé y encuentro razonable: el proyecto sigue sin ningún store real de usuario en producción (`Apps/Fintrol/` sigue sin commitear, sin archive, sin TestFlight — ver Info abierto de recheck anterior), así que no hay dato de usuario real que una migración pudiera perder; el propio archivo documenta el incidente previo (`"Duplicate version checksums detected"`) que ocurrió la última vez que se editó un schema ya "enviado" bajo el mismo identificador, y por eso ahora exige explícitamente que la **próxima** vez que cambie la forma del modelo — si ya hay un store real en el campo — se cree una `SchemaV3` distinta con su propio stage de migración real, no otra edición in-place. Estoy de acuerdo con este razonamiento mientras seamos pre-release; lo marco como **nota operativa, no hallazgo**, y pido que quede como recordatorio explícito para Woz/Avie: la primera vez que exista un archive/TestFlight real con datos de un usuario, cualquier cambio de forma de modelo debe volver a Ivan antes de aplicarse igual que ahora — es exactamente el tipo de decisión que este documento existe para gatekeepear.

**Veredicto `.revolving`: Pass. Nota operativa (no bloqueante) sobre el próximo cambio de schema post-release.**

### Inversiones — Pass, sin superficie nueva

- **No hay ningún `@Model` nuevo.** `SchemaV2.models` (`Core/Migration/SchemaV2.swift`) sigue siendo exactamente `[Period, LineItem, RecurringItem, Subscription, Loan, ExchangeRateCache]` — Inversiones (`InvestmentsView.swift:5-6`) reutiliza `RecurringItem` filtrado por `category == .investment` (un caso más de `SubscriptionCategory`, no un tipo nuevo). No hay campos `Decimal` nuevos que auditar — usa `RecurringItem.amount` (ya cubierto por C-07) y `LineItem.amount`/`.isActive` ya existentes.
- Sin logging: `grep -rn "print(\|os_log(\|Logger("` sobre `Features/Investments/*.swift` → 0 matches.
- Sin cambio de schema, por tanto sin pregunta de migración que resolver aquí — el punto (3) del pedido del coordinador queda satisfecho por diseño (reutilización), no por una migración nueva.

**Veredicto Inversiones: Pass.**

### Swipes `isActive`/`isPaid` — Pass, no abren superficie nueva

- `Fintrol/UI/LineItemRow.swift` — el swipe-leading llama `onToggleActive` (togglea `line.isActive`, dispara `recomputeForward` porque afecta totales) y el swipe-trailing llama `onTogglePaid` (togglea `line.isPaid`, "purely visual flag — no recompute", según el propio comentario del archivo, línea 27). Ambos son mutaciones locales de dos `Bool` ya existentes en `LineItem` (ya cubiertos por C-07/modelo financiero) vía un `DragGesture` custom — no navegan a ninguna vista nueva, no disparan red, no tocan Keychain ni Backup. Acciones equivalentes también expuestas vía `.contextMenu` (líneas 168-169) y `accessibilityActions` (líneas 175-176) — mismo control, accesible sin el gesto. El resto de las listas (`SubscriptionsView`, `LoansView`, `InvestmentsView`, `ServicesView`, `RecurringListView`) usan `.swipeActions` nativo estándar de SwiftUI solo para Eliminar/Editar (ya cubierto por el patrón general de la app, sin superficie nueva).

**Veredicto swipes: Pass, ninguna superficie nueva.**

### Regresión — CERRADO

`xcodebuild test -scheme Fintrol -destination 'platform=macOS'` ejecutado en esta sesión → **158 tests, 20 suites, TEST SUCCEEDED** (antes 113/13 — `BackupServiceTests`, `InvestmentsTests` y la ampliación de `LoanEngineTests` para `.revolving` aportan el resto). Sin fallos.

---

## Verificación de fuentes con fecha de consulta

- Apple, *App Sandbox*, *Preventing Insecure Network Connections (ATS)*, *Keychain Services* — no releídas línea por línea hoy (mismo criterio que SECURITY.md §1: no cambian sin anuncio). Comportamiento observado en build settings es consistente con lo documentado.
- `com.apple.security.hardened-process.*` / Enhanced Security — el contenido de la skill `audit-xcode-security-settings` (instalada localmente, no una fuente web) se tomó como fuente para el hallazgo M-02; no se releyó `developer.apple.com` hoy específicamente para esta entrada porque la skill ya encapsula la referencia vigente de Xcode 27 instalada en esta máquina. Si Woz o Craig necesitan el detalle fino de cada sub-opción (pointer auth, stack zero-init, MTE), están en `~/.claude/skills/audit-xcode-security-settings/references/`.
- `api.frankfurter.app` — no se volvió a consultar documentación hoy; el comportamiento del parser se validó contra el propio contrato ya documentado en SECURITY.md §1 (fecha de consulta original 2026-09-15).

---

## Resumen por severidad (post-RECHECK 3, 2026-09-15)

| Severidad | Cuenta | IDs |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 1 abierto (riesgo aceptado temporal) | M-02 (Enhanced Security — mitigación identificada, pendiente de prueba) |
| Low | 1 nuevo, no bloqueante | `BackupService`: envolver `deleteStoreFiles`/`backupStoreFiles` completas en `#if DEBUG` (hoy solo la llamada lo está; funcionalmente ya no corren en Release) |
| Info | 1 | Código sin commitear |

## Estado de cada pendiente (post-RECHECK 3)

| Nuevo | Estado | Owner | Fecha objetivo |
|---|---|---|---|
| `BackupService` (export/import completo) | **Pass** — token nunca exportado, sin copias temporales propias, import fail-closed con confirmación destructiva, backup automático DEBUG-only sin logs sensibles | Woz | Verificado 2026-09-15 |
| `.revolving` (préstamos) | **Pass** — `Decimal` de extremo a extremo, sin logs, migración in-place justificada mientras el proyecto siga pre-release (nota operativa para el próximo cambio de schema, no hallazgo) | Woz | Verificado 2026-09-15 |
| Inversiones | **Pass** — reutiliza `RecurringItem`, sin `@Model` nuevo, sin campos nuevos, sin logs | Woz | Verificado 2026-09-15 |
| Swipes `isActive`/`isPaid` | **Pass** — mutan booleanos ya existentes, sin superficie nueva, acciones equivalentes accesibles | Woz | Verificado 2026-09-15 |

| ID | Estado | Owner | Fecha objetivo |
|---|---|---|---|
| M-01 | **Closed** — validado en código + 4 tests + `xcodebuild test` verde | Woz | Cerrado 2026-09-15 |
| **C-12** (Banxico SIE + Keychain, nuevo) | **Closed** — token solo en Keychain con accesibilidad correcta, sin sync, sin fugas a UserDefaults/`@Model`/logs/`description`; SecureField + "Probar token" sin revelar el token; ATS sin excepciones; `"N/E"` tratado como ausencia; 400/401/403 a caché sin crash; entitlements sin cambios; 1 req/día; cero rastro de Frankfurter | Woz | Cerrado 2026-09-15 |
| `Loan` (superficie nueva) | **Pass** — `Decimal` de extremo a extremo, sin logging | Woz | Cerrado 2026-09-15 |
| M-02 | **Open — Accepted Risk (temporal)** — diagnóstico de Woz confirmado por fuente oficial; mitigación concreta (`WorkspaceSettings.xcsettings` con `macOSPackagesShouldBuildARM64e`/`iOSPackagesShouldBuildARM64e`) identificada, no probada aún | Woz | Antes del primer archive Release; no bloquea a Bertrand |
| L-01 | **Closed** — `ENABLE_APP_SANDBOX[sdk=macosx*]=YES` en `project.yml`, confirmado en build settings evaluados | Woz | Cerrado 2026-09-15 |
| L-02 | **Closed (Accepted)** — 60s confirmado como decisión final de Steve en SECURITY.md §9 ítem 7 | Steve | Cerrado 2026-09-15 |
| Info (commit) | Abierto | Woz/Bertrand | Antes del siguiente recheck |
| SECURITY.md §9 ítem 8 (Enhanced Security) | **Closed** — verificado en esta sesión, el texto ya refleja el estado real (apagado) | Ivan | Cerrado 2026-09-15 |
| Housekeeping — SECURITY.md C-12 debe anotar que Banxico devuelve **400** (no solo 401/403) para token inválido, según prueba real de Woz | Abierto — documental, no bloqueante | Woz/Bertrand | Antes del siguiente recheck |

---

## Gate de release

**Veredicto (post-RECHECK 3, 2026-09-15): PASS WITH ACCEPTED RISK**

M-01, C-12, `Loan`, `BackupService`, `.revolving`, Inversiones, swipes, L-01 y L-02 cerrados/Pass con evidencia de recheck (código leído, `grep` reproducible, entitlements comparados, build settings evaluados, `xcodebuild test` → **158 tests/20 suites verde**, antes 113/13). No quedan hallazgos Critical ni High. M-02 permanece como **riesgo aceptado temporal, no bloqueante** — sin cambios desde el recheck anterior: Woz debe probar `WorkspaceSettings.xcsettings` antes del primer archive Release. Nuevo hallazgo Low no bloqueante en `BackupService` (envolver las funciones de backup automático completas en `#if DEBUG`, hoy solo la llamada lo está — higiene, no vulnerabilidad activa). C-08 y C-09 mantienen su condición original: **Pass condicionado** a repetirse sobre el primer archive Release real (`codesign -d --entitlements :- <archive>`) — ese artefacto sigue sin existir.

**Pendiente, no bloqueante para Bertrand hoy:** (1) anotar en SECURITY.md C-12 que Banxico devuelve HTTP 400 (no solo 401/403) para token inválido; (2) Low nuevo de `BackupService` (`#if DEBUG` completo); (3) commitear `Apps/Fintrol/` — sigue pendiente desde el primer recheck.

**Qué debe hacer Woz, en orden:**

1. **M-01** — Aplicar `ExchangeRateParser.plausibleRange` (o el rango que se decida) a `ExchangeRateStore.applyManualOverride`, con mensaje de error en `SettingsView` en vez de fallo silencioso. Agregar test unitario.
2. **L-02** — Confirmar con Jonny (o registrar la decisión del usuario) que 60s es el umbral final de re-bloqueo; anotarlo en SECURITY.md §9.
3. **M-02** — Agregar `ENABLE_ENHANCED_SECURITY: YES` en `project.yml`, regenerar con XcodeGen, correr tests, y hacer al menos una prueba manual en dispositivo físico antes de considerar esto cerrado. Si se pospone, registrar owner y fecha en SECURITY.md §9 en vez de dejarlo implícito.
4. **L-01** — Nota documental sobre `ENABLE_APP_SANDBOX` vs. el entitlement real; sin cambio de código requerido.
5. Commitear `Apps/Fintrol/` para que el próximo recheck tenga un commit exacto que citar.
6. Avisar a Ivan para el recheck. Bertrand no debería correr la regresión completa de release hasta que M-01 esté cerrado (afecta directamente la integridad del cálculo de Sobrante); puede seguir trabajando en paralelo sobre todo lo demás.

*Ivan no promete seguridad absoluta. Este documento cubre lo verificable con el código y los build settings disponibles hoy, sin archive Release. C-08/C-09 se repiten obligatoriamente sobre el archive real antes de Phil/Craig, como exige mi propio gate.*
