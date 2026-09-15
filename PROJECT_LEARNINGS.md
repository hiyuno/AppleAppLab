# PROJECT_LEARNINGS — Fintrol

Bitácora local y acumulativa del proyecto. Registra incidentes sin frenar el trabajo normal; el agente propietario actualiza la entrada después de reproducir y verificar. Steve asegura el flujo y coordina retrospectivas, pero no redacta soluciones técnicas.

> Estados permitidos: `hypothesis`, `conditional`, `verified`, `deprecated`. No borres entradas: marca las reemplazadas y enlaza su sucesora.

## Índice

| ID | Estado | Categoría | Resumen | Owner | Last verified |
|---|---|---|---|---|---|
| FIN-2026-001 | verified | dependencias / AppleAppLabUI | `AppleAppLabUI` no compilaba en iOS (solo declaraba `.macOS(.v14)`; usaba `NSColor`/`.checkbox`/`.radioGroup` sin guardas) | Woz | 2026-09-15 |
| FIN-2026-002 | verified | XcodeGen / multiplatform | `TEST_HOST` autogenerado por XcodeGen para un target `supportedDestinations: [iOS, macOS]` usa la ruta de bundle de iOS incluso al compilar para macOS | Woz | 2026-09-15 |
| FIN-2026-003 | conditional | diseño / AppleAppLabUI | `LabNestedCard` no tiene un slot de contenido arbitrario (`@ViewBuilder`); no sirve para "bloque de tabla financiera con totales al pie" que DESIGN_LIQUID.md sugiere construir sobre él | Woz | 2026-09-15 |
| FIN-2026-004 | hypothesis | build system / Xcode 27 Enhanced Security | `ENABLE_ENHANCED_SECURITY: YES` a nivel proyecto rompe el link del target app contra el paquete local `AppleAppLabUI` (arm64e vs arm64) | Woz | 2026-09-15 |
| FIN-2026-005 | verified | integraciones / Banxico SIE | Banxico SIE responde **HTTP 400** (no 401/403 como asumía SECURITY.md/TRD) para token faltante/inválido, con body `{"error":{"mensaje":"Token inválido",...}}` | Woz | 2026-09-15 |
| FIN-2026-006 | verified | testing / Keychain en iOS Simulator | Los tests de `KeychainStore` fallan con `errSecMissingEntitlement` (-34018) en iOS Simulator cuando el test bundle corre sin firma (`CODE_SIGNING_ALLOWED=NO`); en macOS no firmado sí funciona | Woz | 2026-09-15 |
| FIN-2026-007 | verified | Core/Engine / LoanEngine | `termMonths(from:to:)` tenía off-by-one: la instalación N cae `N-1` meses después de `startDate` (primer pago el mismo mes), así que el inverso de `endDate(...)` necesita `+1`, no solo la diferencia de meses en calendario | Woz | 2026-09-15 |
| FIN-2026-008 | verified | Core/Engine / fechas | `PeriodDateEngine`/`LoanEngine` mezclaban `Date` a medianoche UTC (`Calendar.gregorianUTC`) con `Date` a medianoche LOCAL (proveniente de `DatePicker`) en la misma comparación — en cualquier zona UTC−N la clasificación se corría un día, causando WALO ausente/duplicado, Luz ausente y "próximo pago" de préstamo mostrando el día 19 en vez del 20 | Woz | 2026-09-15 |
| FIN-2026-009 | verified | Core/Engine / CivilDate | `CivilDate.daysInMonth` construía la fecha neutral con el propio `day` (potencialmente fuera de rango, p.ej. 31 en febrero) antes de preguntarle a `Calendar` el rango del mes — `Calendar.date(from:)` desbordaba el 31 hacia marzo en silencio, así que `clampedToValidDay` nunca clampeaba nada | Woz | 2026-09-15 |

## FIN-2026-001 — AppleAppLabUI no soportaba destino iOS

- **Fingerprint:** `dependencias/AppleAppLabUI/ios-build-nscolor-not-in-scope`
- **Categoría:** dependencias / SwiftUI multiplataforma
- **Plataformas / versiones:** iOS 26 (Simulator) + macOS 26, Xcode 27 (27A266a), SDK iOS/macOS 27
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15; last verified 2026-09-15
- **Owner / status:** Woz / `verified`
- **Síntoma:** Al compilar el target multiplataforma `Fintrol` (`supportedDestinations: [iOS, macOS]`) para `generic/platform=iOS Simulator`, la compilación fallaba con `cannot find 'NSColor' in scope`, `extraneous argument label 'nsColor:'`, `'checkbox' is unavailable in iOS`, `'radioGroup' is unavailable in iOS` y `'Previewable()' is only available in iOS 17.0 or newer`, todos originados dentro del paquete `Packages/AppleAppLabUI`, no en código de Fintrol.
- **Reproducción/evidencia:** `xcodebuild -project Fintrol.xcodeproj -scheme Fintrol -destination 'generic/platform=iOS Simulator' build` sobre el proyecto generado por XcodeGen, antes del fix. Log completo con los 6 errores capturado en la sesión (no conservado aquí por ser transcripción de build, no dato sensible).
- **Hipótesis/causa raíz (confirmada por lectura del código):** `Packages/AppleAppLabUI/Package.swift` declaraba `platforms: [.macOS(.v14)]` únicamente. `ColorTokens.swift` y `AccentPalette.swift` usaban `NSColor` sin `#if canImport(AppKit)`; `LabWindowFrame.swift` usaba `Color(nsColor:)` sin condicional; `LabCheckboxGroup.swift`/`LabRadioGroup.swift` usaban `.toggleStyle(.checkbox)`/`.pickerStyle(.radioGroup)`, ambos exclusivos de macOS; el mínimo de iOS implícito (sin declarar) quedaba por debajo de 17, rompiendo `@Previewable`.
- **Garantía de plataforma/fuente:** Ninguna — es un gap de cobertura del paquete interno del equipo, no un límite de la SDK de Apple. `NSColor`/`UIColor`, `.checkbox`/`.radioGroup` son APIs documentadas de AppKit sin equivalente literal en UIKit; la solución estándar es ramificar con `#if canImport(UIKit)`.
- **Workaround:** ninguno aplicado — se corrigió el paquete directamente en vez de evitar sus componentes, porque el TRD exige reutilizar `AppleAppLabUI` en el único target multiplataforma.
- **Solución durable:** `Package.swift` ahora declara `platforms: [.macOS(.v14), .iOS(.v17)]`. `ColorTokens.init(light:dark:)` y `AccentPalette.rgbComponents` ramifican con `#if canImport(UIKit) ... #elseif canImport(AppKit)`. `LabWindowFrame` reemplaza el `Color(nsColor: .separatorColor)` de producción por un `separatorColor` calculado (`#if os(macOS)` / `#else Color(uiColor: .separator)`) y su `#Preview` usa la misma técnica para `.windowBackgroundColor`/`.systemBackground`. `LabCheckboxGroup` usa `.toggleStyle(.checkbox)` en macOS y `.toggleStyle(.switch)` en iOS; `LabRadioGroup` usa `.pickerStyle(.radioGroup)` en macOS y `.pickerStyle(.inline)` en iOS. El comportamiento visual en macOS no cambió (misma rama de código); iOS obtiene un equivalente funcional razonable.
- **Verificación:** `xcodebuild -destination 'generic/platform=iOS Simulator' build` → `BUILD SUCCEEDED`; `xcodebuild -destination 'platform=macOS' build` → `BUILD SUCCEEDED` (sin regresión). Repetido tras el fix en la misma sesión.
- **Prevención:** si `AppleAppLabUI` gana un consumidor iOS nuevo, correr un build iOS del paquete como smoke test antes de asumir que un componente "ya probado en macOS" es multiplataforma.
- **Relacionadas:** FIN-2026-002
- **Promoción global:** Candidata — el fix vive en el paquete compartido `Packages/AppleAppLabUI`, no en Fintrol; cualquier app futura del equipo que use este paquete en iOS se beneficia automáticamente. No requiere acción adicional de promoción, ya está en el paquete global.

## FIN-2026-002 — XcodeGen genera `TEST_HOST` incorrecto para targets `supportedDestinations`

- **Fingerprint:** `xcodegen/multiplatform-target/test-host-wrong-bundle-path`
- **Categoría:** release / build system
- **Plataformas / versiones:** macOS 26, XcodeGen 2.45.4, target con `platform: auto` + `supportedDestinations: [iOS, macOS]`
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15; last verified 2026-09-15
- **Owner / status:** Woz / `verified`
- **Síntoma:** `xcodebuild test -destination 'platform=macOS'` fallaba con `Could not find test host for FintrolTests: TEST_HOST evaluates to ".../Fintrol.app/Fintrol"` — esa ruta no existe en un bundle macOS (el ejecutable real vive en `Fintrol.app/Contents/MacOS/Fintrol`).
- **Reproducción/evidencia:** proyecto generado por XcodeGen a partir de un target `Fintrol` con `supportedDestinations: [iOS, macOS]` y un target `bundle.unit-test` `FintrolTests` con `dependencies: [{target: Fintrol}]`, sin overrides de `TEST_HOST`/`BUNDLE_LOADER`. `grep TEST_HOST` en el `.pbxproj` generado mostraba `$(BUILT_PRODUCTS_DIR)/Fintrol.app/Fintrol` (convención de iOS) para ambas configuraciones.
- **Hipótesis/causa raíz:** XcodeGen deriva el `TEST_HOST` por defecto para un target hosted con la convención de bundle de iOS (`AppName.app/AppName`), sin condicionar por SDK cuando el target de la app es multiplataforma (`platform: auto` / `supportedDestinations`). No se confirmó en el código fuente de XcodeGen (fuera de alcance); queda como hipótesis basada en el comportamiento observado.
- **Garantía de plataforma/fuente:** Ninguna — comportamiento de la herramienta XcodeGen, no de Xcode/Apple.
- **Workaround:** ninguno — se corrigió con overrides explícitos.
- **Solución durable:** en `project.yml`, target `FintrolTests`, se fijó manualmente:
  ```yaml
  TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Fintrol.app/Fintrol"
  "TEST_HOST[sdk=macosx*]": "$(BUILT_PRODUCTS_DIR)/Fintrol.app/Contents/MacOS/Fintrol"
  BUNDLE_LOADER: "$(TEST_HOST)"
  ```
  usando la sintaxis de build setting condicional por SDK que Xcode ya soporta nativamente (no es una feature de XcodeGen).
- **Verificación:** `xcodebuild test -destination 'platform=macOS'` → `Test run with 49 tests in 8 suites passed`, `TEST SUCCEEDED`; `xcodebuild test -destination 'id=<iPhone simulator>'` → mismo resultado, 49/49.
- **Prevención:** en cualquier target XcodeGen con `supportedDestinations: [iOS, macOS]` que tenga un test target hosted, fijar `TEST_HOST`/`BUNDLE_LOADER` explícitos con el sufijo `[sdk=macosx*]` desde el `project.yml` inicial en vez de confiar en el default.
- **Relacionadas:** FIN-2026-001
- **Promoción global:** Candidata — cualquier app del equipo que adopte un target único `supportedDestinations: [iOS, macOS]` con XcodeGen (patrón que el TRD de Fintrol fija como estándar) va a golpear el mismo bug. Vale la pena documentarlo en el template de `project.yml` de Woz (`.claude/skills/woz/SKILL.md`) para apps multiplataforma futuras.

## FIN-2026-003 — `LabNestedCard` no encaja como contenedor de bloque INCOME/EXPENSES

- **Fingerprint:** `diseño/AppleAppLabUI/LabNestedCard-no-viewbuilder-slot`
- **Categoría:** diseño / catálogo de componentes
- **Plataformas / versiones:** iOS 26 + macOS 26, `AppleAppLabUI` (paquete local)
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15; last verified 2026-09-15
- **Owner / status:** Woz / `conditional` (no bloquea v1, pero el componente sugerido por diseño no es el que se terminó usando)
- **Síntoma:** `DESIGN_LIQUID.md` (sección "Bloques INCOME / EXPENSES") indica construir el bloque "sobre `LabNestedCard` (da el nested radius automático)". Al leer la implementación real de `Packages/AppleAppLabUI/Sources/AppleAppLabUI/Components/Cards/LabNestedCard.swift`, el componente no expone ningún parámetro `@ViewBuilder content: () -> Content` — su `body` es fijo: imagen opcional + `title`/`subtitle` de texto en tres capas anidadas. No hay forma de insertar una lista dinámica de `LineItemRow` + fila de total dentro de él.
- **Reproducción/evidencia:** lectura directa del archivo fuente (no requiere build para confirmarlo); su único inicializador acepta `title: String, subtitle: String, ...`, sin closure de contenido.
- **Hipótesis/causa raíz:** `LabNestedCard` fue diseñado como preview de tarjeta (imagen + texto), no como contenedor genérico de layout — un caso de uso distinto al que DESIGN_LIQUID.md asumía al escribir la sugerencia.
- **Garantía de plataforma/fuente:** N/A — es una decisión de diseño del paquete interno, no de Apple.
- **Workaround:** el bloque INCOME/EXPENSES de `PeriodView.swift` (`lineBlock(title:kind:)`) y el `SummaryPanel.swift` se construyeron como `VStack` custom con `RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial.opacity(0.5))`, replicando manualmente el material Frost del tema (blur 0.5/transparencia 0.5) y el radio de card (20pt) en vez de usar `LabNestedCard`.
- **Solución durable:** ninguna aplicada todavía — requeriría añadir a `LabNestedCard` (o a un nuevo componente `LabListCard`) un slot `@ViewBuilder content` para listas con total al pie, generalizando `LineItemRow`/`SobranteBadge`/`SummaryPanel` de Fintrol al catálogo compartido.
- **Verificación:** N/A (no es un bug que falle build/test — es una discrepancia entre documentación de diseño y API real).
- **Prevención:** antes de que Jonny escriba "construir sobre `Lab___`" en un `DESIGN_*.md`, verificar contra la firma real del componente en `Packages/AppleAppLabUI/Sources`, no solo contra `PATTERNS.md` (que en este caso tampoco documenta la firma exacta de `LabNestedCard`).
- **Relacionadas:** —
- **Promoción global:** Candidata — un componente "lista con total al pie" (`LineItemRow` + bloque contenedor) es genérico y reaparecería en cualquier app de presupuesto/finanzas del equipo. Generalizar a `AppleAppLabUI` en una iteración futura, no en v1.

## FIN-2026-004 — `ENABLE_ENHANCED_SECURITY: YES` rompe el link contra el paquete local `AppleAppLabUI`

- **Fingerprint:** `build-system/enhanced-security/arm64e-arm64-link-mismatch-local-spm-package`
- **Categoría:** build system / seguridad (SECURITY_AUDIT.md M-02)
- **Plataformas / versiones:** macOS 26 (host de desarrollo), Xcode 27 (27A266a), SDK macOS 27.0, XcodeGen 2.45.4
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15; last verified 2026-09-15
- **Owner / status:** Woz / `hypothesis` (causa raíz consistente con la evidencia del log, no confirmada línea por línea contra el código fuente de Xcode/SPM — herramienta cerrada, no inspeccionable)
- **Síntoma:** Con `ENABLE_ENHANCED_SECURITY: YES` en `settings.base` de `project.yml` (y por tanto `ARCHS = arm64e` cascadeado al target `Fintrol`), `xcodebuild build` para `platform=macOS` falla: `warning: Module file '.../AppleAppLabUI.swiftmodule/arm64-apple-macos.swiftmodule' is incompatible with this Swift compiler: built for incompatible target`, seguido de `error: Unable to resolve module dependency: 'AppleAppLabUI'` en cada archivo que hace `import AppleAppLabUI`.
- **Reproducción/evidencia:** `rm -rf DerivedData` (para descartar caché estancada) → `xcodegen generate` con `ENABLE_ENHANCED_SECURITY: YES` → `xcodebuild -destination 'platform=macOS' build`. El log de compilación muestra el target `AppleAppLabUI` (paquete local) compilando explícitamente con `-target arm64-apple-macos14.0`, mientras el target `Fintrol` compila con `-target arm64e-apple-macos26.0` en la misma invocación — arquitecturas de ABI de punteros incompatibles (firmados vs. no firmados) no pueden enlazarse entre sí.
- **Hipótesis/causa raíz:** `ENABLE_ENHANCED_SECURITY`/`ARCHS=arm64e` se aplican a los targets nativos del `.xcodeproj` generado (vía `project.yml`), pero **no cascadean** al grafo de build de un Swift Package local resuelto por Xcode (`Packages/AppleAppLabUI`), que sigue resolviendo su arquitectura por su propio `Package.swift`/defaults de SPM (`$(ARCHS_STANDARD)`, que no incluye `arm64e`). No se confirmó esto leyendo el código fuente de Xcode/SPM (herramienta cerrada); es la explicación que mejor encaja con el log de build observado.
- **Garantía de plataforma/fuente:** Ninguna verificada hoy contra `developer.apple.com` — Enhanced Security es una feature nueva de Xcode 27 (WWDC 2025); no se confirmó documentación oficial sobre su interacción con paquetes SPM locales en esta sesión.
- **Workaround:** ninguno probado (p. ej. forzar `ARCHS`/settings equivalentes directamente sobre el target del paquete no es controlable desde `project.yml` de forma directa para un paquete SPM local; requeriría modificar `Package.swift` con flags no estándar o esperar una vía soportada por XcodeGen/Xcode).
- **Solución durable:** ninguna aplicada — se revirtió `ENABLE_ENHANCED_SECURITY` a comentado/apagado en `project.yml` para no dejar el build roto. Ver SECURITY.md §9 ítem 8 para el riesgo aceptado temporal.
- **Verificación:** con el setting revertido, `xcodebuild build` (macOS e iOS Simulator) → `BUILD SUCCEEDED` en ambos; `xcodebuild test` (macOS e iOS Simulator) → 53/53 tests, `TEST SUCCEEDED` en ambos. Con el setting activo, el build falla reproduciblemente (2/2 intentos, incluyendo uno tras limpiar DerivedData por completo).
- **Prevención:** antes de reactivar `ENABLE_ENHANCED_SECURITY`, investigar si Xcode 27 expone alguna forma soportada de forzar `arm64e` en el grafo de build de un paquete SPM local (o si Apple documenta que Enhanced Security simplemente no es compatible con dependencias de paquete hasta que el propio Xcode/SPM lo resuelva). Si Craig/Ivan encuentran la vía correcta, promover esta entrada a `verified` con la solución aplicada.
- **Relacionadas:** —
- **Promoción global:** No candidata todavía — es una hipótesis específica de esta combinación de versiones (Xcode 27A266a); revalidar si cambia la versión de Xcode antes de proponerla como regla general del equipo.

## FIN-2026-005 — Banxico SIE responde HTTP 400 (no 401/403) para token inválido/faltante

- **Fingerprint:** `integraciones/banxico-sie/token-error-status-400-not-401-403`
- **Categoría:** integraciones / seguridad (SECURITY.md C-12)
- **Plataformas / versiones:** N/A (API externa) — confirmado vía `curl` directo el 2026-09-15
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15; last verified 2026-09-15
- **Owner / status:** Woz / `verified`
- **Síntoma:** SECURITY.md/TRD asumían (basado en el resumen de la doc de Banxico SIE) que un `Bmx-Token` faltante o inválido resulta en HTTP 401 o 403. Probando en vivo contra `www.banxico.org.mx` con y sin header `Bmx-Token` (y con un token basura), el servicio responde consistentemente **HTTP 400**.
- **Reproducción/evidencia:**
  ```
  curl -s "https://www.banxico.org.mx/SieAPIRest/service/v1/series/SF43718/datos/oportuno" -H "Accept: application/json" -w "HTTP_STATUS:%{http_code}\n"
  → HTTP_STATUS:400
  → {"error":{"url":"https://www.banxico.org.mx/SieAPIRest/service/v1/token","mensaje":"Token inválido","detalle":"El token enviado no es válido, favor de verificar. Para obtener un token consultar la url adjunta."}}
  ```
  Repetido con `-H "Bmx-Token: garbage12345"` → mismo resultado (400, mismo body).
- **Hipótesis/causa raíz:** Confirmado por observación directa, no es hipótesis — es el comportamiento real y reproducible del servicio hoy.
- **Garantía de plataforma/fuente:** Ninguna — comportamiento de un servicio de terceros (Banxico), puede cambiar sin aviso; la doc pública resumida por Ivan sugería 401/403, pero el comportamiento observado en producción es 400.
- **Workaround:** N/A — no es un bug a evitar, es el contrato real.
- **Solución durable:** `ExchangeRateParser.isInvalidTokenError(status:data:)` acepta **400, 401 y 403** como candidatos a "token inválido", y solo los clasifica como tales si el body además trae la forma `{"error": {"mensaje": ...}}` que Banxico realmente devuelve — así cualquiera de los tres códigos con ese body se trata como C-12(d) (token inválido, mensaje claro sin revelar el token), y cualquier otro código (ej. 500 genérico) cae al fallback normal de red.
- **Verificación:** `ExchangeRateParserTests.detectsRealBanxicoInvalidTokenBody` usa el body exacto capturado por `curl` arriba; `ExchangeRateServiceTests.invalidTokenIsDistinctFromGenericFailure` cubre el flujo completo vía `StubURLProtocol`. Ambos pasan en macOS e iOS Simulator (96/96 tests totales).
- **Prevención:** si Ivan/Craig necesitan el contrato exacto de éxito (200 con token válido), no se pudo probar en esta sesión por no tener un token real — el shape de éxito (`bmx.series[0].datos[0].{fecha,dato}`) se implementó según la documentación pública estándar de Banxico SIE, ampliamente conocida y consistente entre series, pero **no fue confirmada en vivo con un token real en esta sesión**. Recomendado: la primera vez que el usuario pegue un token real en Ajustes y pruebe "Probar token"/actualización automática, verificar que el shape de éxito coincide; si no, hay un hallazgo nuevo que reportar.
- **Relacionadas:** —
- **Promoción global:** Candidata — cualquier futura integración del equipo con Banxico SIE debe asumir 400 para token inválido, no 401/403.

## FIN-2026-006 — Tests de Keychain fallan en iOS Simulator sin firma de código

- **Fingerprint:** `testing/keychain/ios-simulator-errSecMissingEntitlement-unsigned`
- **Categoría:** testing / build system
- **Plataformas / versiones:** iOS 26 Simulator, Xcode 27 (27A266a)
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15; last verified 2026-09-15
- **Owner / status:** Woz / `verified`
- **Síntoma:** `KeychainStoreTests` (save/read/delete del `Bmx-Token`) fallan en iOS Simulator con `KeychainError.unexpectedStatus(-34018)` (`errSecMissingEntitlement`) cuando el test bundle se compila y corre con `CODE_SIGNING_ALLOWED=NO` (el flag usado en toda la sesión para builds de verificación sin Team ID). En macOS, el mismo test sin firma **sí pasa**.
- **Reproducción/evidencia:** `xcodebuild test -destination 'id=<iPhone Simulator>' CODE_SIGNING_ALLOWED=NO` → 3 fallos en `KeychainStoreTests`. `xcodebuild test -destination 'id=<iPhone Simulator>' -allowProvisioningUpdates` (firmado con el Team ID real detectado, `449S639443`) → 96/96 tests pasan, incluidos los 4 de `KeychainStoreTests`.
- **Hipótesis/causa raíz:** El Keychain de iOS (a diferencia de macOS) exige que el proceso que llama a `SecItemAdd`/`SecItemUpdate`/`SecItemCopyMatching` esté codesigned con una identidad que otorgue el entitlement de acceso a Keychain; un binario de test sin firmar en el simulador de iOS no lo tiene, de ahí `errSecMissingEntitlement`. macOS parece más permisivo para binarios ad-hoc/sin firmar en este contexto de desarrollo local.
- **Garantía de plataforma/fuente:** Comportamiento de Security.framework en iOS — no se releyó `developer.apple.com` hoy con fecha explícita, pero es consistente con el código de error documentado (`errSecMissingEntitlement`).
- **Workaround:** ninguno — no es deseable "arreglar" esto sin firma, ya que Keychain sin firma real no es representativo de producción de todos modos.
- **Solución durable:** para cualquier test suite futura que toque `KeychainStore` en iOS Simulator, correr con firma real (`-allowProvisioningUpdates`, Team ID configurado) en vez de `CODE_SIGNING_ALLOWED=NO`. En macOS, ambos modos funcionan.
- **Verificación:** 96/96 tests pasan en iOS Simulator firmado; los mismos 4 tests de Keychain fallan reproduciblemente sin firma (3/3 intentos).
- **Prevención:** documentar en el Makefile/skill de Woz que los tests que tocan Keychain necesitan un target firmado, no `CODE_SIGNING_ALLOWED=NO`.
- **Relacionadas:** —
- **Promoción global:** Candidata — aplica a cualquier app del equipo que adopte Keychain y corra tests en iOS Simulator.

## FIN-2026-007 — `LoanEngine.termMonths(from:to:)` off-by-one en el round-trip plazo↔fecha fin

- **Fingerprint:** `core-engine/loan-engine/term-months-from-end-date-off-by-one`
- **Categoría:** Core/Engine — cálculo financiero
- **Plataformas / versiones:** N/A (lógica pura, sin dependencia de plataforma)
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15; last verified 2026-09-15
- **Owner / status:** Woz / `verified`
- **Síntoma:** Test `termMonthsEndDateRoundTrip` fallaba: `LoanEngine.endDate(startDate:termMonths: 48,...)` seguido de `LoanEngine.termMonths(from:to:)` sobre esa misma fecha devolvía `47`, no `48`.
- **Reproducción/evidencia:** `xcodebuild test` → `Expectation failed: recomputedTerm == 48 → recomputedTerm → 47`.
- **Hipótesis/causa raíz (confirmada):** `installmentDate(index:...)` coloca la instalación `N` en `N-1` meses después de `startDate` (el primer pago cae el mismo mes de inicio, no un mes después) — es la convención correcta para que `numberOfPayments(termMonths:frequency:) == termMonths` en frecuencia mensual. Pero el inverso original, `termMonths(from:to:)`, calculaba solo la diferencia de meses en calendario entre `startDate` y `endDate` sin compensar ese desfase de 1, rompiendo el round-trip que el formulario de Préstamos depende (plazo↔fecha fin enlazados, DESIGN_LIQUID.md).
- **Garantía de plataforma/fuente:** Ninguna — es una decisión de diseño propia del motor, no un comportamiento de `Calendar`/Foundation.
- **Workaround:** ninguno necesario — se corrigió la fórmula directamente.
- **Solución durable:** `termMonths(from:to:) = calendar.dateComponents([.month], from:to:).month + 1` (antes sin el `+1`), con comentario explicando la convención "instalación N a N-1 meses de distancia".
- **Verificación:** `LoanEngineTests.termMonthsEndDateRoundTrip` pasa; 106/106 tests totales en macOS e iOS Simulator tras el fix.
- **Prevención:** cualquier función futura que derive un conteo de periodos desde una fecha debe declarar explícitamente si cuenta "distancia entre fechas" o "número de eventos" — son off-by-one entre sí por definición cuando el primer evento coincide con el punto de partida.
- **Relacionadas:** —
- **Promoción global:** No candidata — específico de la convención interna de `LoanEngine`.

## FIN-2026-008 — `PeriodDateEngine`/`LoanEngine` mezclaban `Date` UTC y `Date` local en la misma comparación

- **Fingerprint:** `core-engine/dates/utc-vs-local-date-mixed-comparison`
- **Categoría:** Core/Engine — fechas
- **Plataformas / versiones:** N/A (lógica pura); reproducible en cualquier zona horaria con offset negativo respecto a UTC (p.ej. America/Mexico_City, UTC−6)
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15 (diagnóstico de Avie); last verified 2026-09-15
- **Owner / status:** Woz / `verified`
- **Síntoma:** Un recurrente biweekly (WALO) desaparecía de la quincena 1–15 de septiembre y aparecía duplicado en 16–30; un servicio mensual (Luz, día 12) desaparecía de su quincena; el "próximo pago" de un préstamo mensual (día 20) mostraba el día 19.
- **Reproducción/evidencia:** Antes del fix, `PeriodDateEngine.dateRange`/`coordinate(containing:)` y `LoanEngine.installmentDate` construían límites de quincena a medianoche UTC vía `Calendar.gregorianUTC`, mientras `RecurringItem.startDate`/`endDate` (y equivalentes en `Subscription`/`Loan`) llegaban de un `DatePicker` como medianoche LOCAL del dispositivo. `ProjectionEngine.isVigente` comparaba esos `Date` directamente. En UTC−6, la medianoche local del día 16 es aún las 18:00 UTC del día 15 — la comparación clasificaba mal según qué lado del cálculo usó qué zona.
- **Hipótesis/causa raíz (confirmada):** dos fuentes de `Date` con distinta zona de referencia comparadas como si fueran el mismo tipo de dato — el bug no vivía en ningún `Calendar` individual, sino en mezclar dos.
- **Garantía de plataforma/fuente:** Ninguna — `Date` es un instante absoluto (UTC internamente); cualquier comparación de "día civil" que no pase primero por una normalización explícita y consistente es, por construcción, dependiente de qué `Calendar`/zona se usó para construir cada lado.
- **Workaround:** ninguno — no hay forma segura de seguir comparando `Date` crudos para este propósito.
- **Solución durable:** se introdujo `Core/Engine/CivilDate.swift` (año/mes/día puro, sin hora ni zona) como el único tipo de fecha dentro de `Core/Engine`. `PeriodDateEngine`, `EngineTypes` (snapshots + `LoanInstallment`), `ProjectionEngine.isVigente`, y `LoanEngine` (`schedule`, `installmentDate`, `termMonths`, `endDate`) migraron por completo a `CivilDate`. Los modelos (`RecurringItem`/`Subscription`/`Loan`) exponen `civilStartDate`/`civilEndDate` que envuelven la columna `Date` persistida (necesaria para SwiftData/CloudKit) y normalizan vía `Calendar.current` en el límite UI↔modelo. Todo sitio de `DatePicker` (`RecurringListView`, `SubscriptionsView`, `ServicesView`, `LoansView`) guarda a través de esos accesores, nunca asignando `Date` crudo a la columna. `LoanDetailView`/`LoansView` bridgean `CivilDate → Date` solo para mostrar (`.date(calendar: .current)`), nunca para comparar. Se agregó también un cinturón de idempotencia en `reprojectRecurring`/`reprojectSubscription`/`reprojectLoan`: elimina `LineItem`s duplicados que compartan la misma fuente dentro del mismo `Period` antes de decidir crear/actualizar/eliminar.
- **Verificación:** 123/123 tests en macOS e iOS Simulator, incluyendo tests nuevos que repiten el escenario bajo `America/Mexico_City` y `UTC` exigiendo el mismo resultado en ambas zonas (WALO, Luz, préstamo día 20, idempotencia de reproyección).
- **Prevención:** cualquier comparación de "día civil" en `Core/Engine` debe pasar por `CivilDate`; ningún tipo nuevo debe comparar `Date` crudos salvo en el límite UI (formateo/`DatePicker`).
- **Relacionadas:** FIN-2026-009
- **Promoción global:** Candidata — el patrón `CivilDate` (año/mes/día puro, normalización única en el límite UI) es reutilizable en cualquier app del equipo con lógica de "día calendario" independiente de zona horaria.

## FIN-2026-009 — `CivilDate.daysInMonth` desbordaba el mes con un `day` fuera de rango antes de clampear

- **Fingerprint:** `core-engine/civildate/days-in-month-overflow-before-clamp`
- **Categoría:** Core/Engine — CivilDate
- **Plataformas / versiones:** N/A (lógica pura)
- **Proyecto fuente / fechas:** Fintrol (`Apps/Fintrol`); first seen 2026-09-15 (durante la migración a CivilDate); last verified 2026-09-15
- **Owner / status:** Woz / `verified`
- **Síntoma:** `PeriodDateEngine.date(forDayOfMonth: 31, in: .february)` devolvía el día 31 sin clampear (en vez de 28/29); un recurrente `monthlyOnDay(31)` con instalación de préstamo día 31 en un mes de 30 días no se clampeaba al último día real.
- **Reproducción/evidencia:** `PeriodDateEngineTests.clampsInvalidDay`, `LoanEngineTests.installmentDateClampsToLastValidDay`, `EdgeCaseEngineTests.monthlyOnDay31Clamps*` fallaban tras la migración inicial a `CivilDate`.
- **Hipótesis/causa raíz (confirmada):** `daysInMonth` construía `asNeutralDate` con el `day` original (p.ej. 31) vía `Calendar.date(from: DateComponents(year:month:day: 31))` para febrero — `Calendar` no lanza error ante un día fuera de rango, lo desborda en silencio hacia el mes siguiente (31 feb → ~3 mar), así que `range(of: .day, in: .month, for:)` devolvía el conteo de días de MARZO (31), y `min(day, daysInMonth)` no clampeaba nada.
- **Garantía de plataforma/fuente:** Ninguna — es un comportamiento documentado pero fácil de pasar por alto de `Calendar.date(from:)`: normaliza componentes fuera de rango en vez de fallar.
- **Workaround:** ninguno.
- **Solución durable:** `daysInMonth` ahora ancla siempre al día 1 del mes (`DateComponents(year:month:day: 1)`) antes de pedirle a `Calendar` el rango del mes, nunca al `day` potencialmente inválido de `self`.
- **Verificación:** los 4 tests mencionados pasan; 123/123 tests totales en macOS e iOS Simulator.
- **Prevención:** cualquier cálculo de "rango del mes" debe anclarse a un día conocido-válido (día 1), nunca al día que se está intentando validar/clampear.
- **Relacionadas:** FIN-2026-008
- **Promoción global:** No candidata — específico de la implementación interna de `CivilDate` en Fintrol.

## Retrospectiva — Fintrol v1: CivilDate refactor (fechas end-to-end) — 2026-09-15

- **Nuevos incidentes:** FIN-2026-008, FIN-2026-009
- **Fixes confirmados:** `CivilDate` como único tipo de fecha en `Core/Engine` (`PeriodDateEngine`, `EngineTypes`, `ProjectionEngine`, `LoanEngine`); accesores `civilStartDate`/`civilEndDate` en `RecurringItem`/`Subscription`/`Loan`; todo sitio de `DatePicker` normaliza al guardar; cinturón de idempotencia por-fuente-por-`Period` en `reprojectRecurring`/`reprojectSubscription`/`reprojectLoan`; tests nuevos repetidos bajo `America/Mexico_City` y `UTC` (WALO, Luz, préstamo día 20, idempotencia)
- **Hipótesis abiertas:** ninguna nueva de este pase (FIN-2026-004 de Enhanced Security sigue abierta, sin cambios)
- **Entradas globales aplicadas:** ninguna
- **Entradas globales a revalidar:** N/A
- **Candidatas a promoción:** FIN-2026-008 (patrón `CivilDate` reutilizable en cualquier app del equipo)

## Retrospectiva — Fintrol v1: feature Préstamos (Loans) — 2026-09-15

- **Nuevos incidentes:** FIN-2026-007 (encontrado y corregido en la misma sesión)
- **Fixes confirmados:** amortización francesa (`LoanEngine`, `Decimal` extremo a extremo vía `NSDecimalNumber.raising(toPower:)` para evitar `Double`), `reprojectLoan` simétrico a `reprojectRecurring`/`reprojectSubscription`, 5 tests obligatorios del TRD + 5 adicionales (round-trip plazo↔fecha fin, clamp de día 31, dirección→kind, proyección a quincena)
- **Hipótesis abiertas:** ninguna nueva de este pase
- **Entradas globales aplicadas:** ninguna
- **Entradas globales a revalidar:** N/A
- **Candidatas a promoción:** `LoanRow` (chip de dirección + barra de progreso) documentado en DESIGN_LIQUID.md como candidato a generalizar en `AppleAppLabUI`, igual que `LineItemRow`/`SobranteBadge`

## Retrospectiva — Fintrol v1: navegación/Servicios/reproyección/Banxico SIE — 2026-09-15

- **Nuevos incidentes:** FIN-2026-005, FIN-2026-006
- **Fixes confirmados:** bug del límite histórico en `materializeIfNeeded` (ahora clampea al ancla, test convertido de `withKnownIssue` a assertion real); bug de reproyección de recurrentes/suscripciones sobre quincenas ya materializadas (`reprojectRecurring`/`reprojectSubscription`, 8 tests nuevos); Frankfurter reemplazado por Banxico SIE end-to-end (parser, servicio, Keychain, UI) con 0 referencias residuales a Frankfurter
- **Hipótesis abiertas:** ninguna nueva de este pase (FIN-2026-004 de Enhanced Security sigue abierta, sin cambios)
- **Entradas globales aplicadas:** ninguna
- **Entradas globales a revalidar:** N/A
- **Candidatas a promoción:** FIN-2026-005 (contrato de error de Banxico SIE), FIN-2026-006 (requisito de firma para tests de Keychain en iOS Simulator)

## Retrospectiva — Fintrol v1 recheck de auditorías (Ivan/Larry/Sarah) — 2026-09-15

- **Nuevos incidentes:** FIN-2026-004 (Enhanced Security vs. paquete SPM local)
- **Fixes confirmados:** SECURITY_AUDIT.md M-01 (override manual validado + 4 tests nuevos), L-01 (`ENABLE_APP_SANDBOX[sdk=macosx*]` alineado), HIG_REVIEW.md hallazgos 1–4 (swipe, Dynamic Type ×2, accesibilidad de color), A11Y_AUDIT.md 23/23 hallazgos aplicados
- **Hipótesis abiertas:** FIN-2026-004 (M-02 revertido, pendiente de vía soportada para Enhanced Security + SPM local)
- **Entradas globales aplicadas:** ninguna
- **Entradas globales a revalidar:** N/A
- **Candidatas a promoción:** FIN-2026-001 (ya vive en el paquete compartido), FIN-2026-002 (documentar patrón en skill de Woz), FIN-2026-003 (generalizar componente "lista con total al pie" a futuro)

## Retrospectiva — Fintrol v1 MVP — 2026-09-15

- **Nuevos incidentes:** FIN-2026-001, FIN-2026-002, FIN-2026-003
- **Fixes confirmados:** FIN-2026-001 (build iOS + macOS verde), FIN-2026-002 (tests verdes en ambas plataformas, 49/49)
- **Hipótesis abiertas:** ninguna
- **Entradas globales aplicadas:** ninguna (proyecto nuevo)
- **Entradas globales a revalidar:** N/A
- **Candidatas a promoción:** FIN-2026-001 (ya vive en el paquete compartido), FIN-2026-002 (documentar patrón en skill de Woz), FIN-2026-003 (generalizar componente "lista con total al pie" a futuro)

## Reglas de calidad

- Primero observación reproducida; después hipótesis; solo entonces causa confirmada.
- No conviertas coincidencia temporal en garantía de plataforma.
- Nunca incluyas tokens, secretos, datos personales ni logs sensibles.
- Una solución es `verified` solo con una prueba/regresión explícita.
- Si una entrada queda obsoleta, usa `deprecated` y enlaza el reemplazo.
- Los valores visuales calibrados pertenecen a esta app, no son defaults globales.
