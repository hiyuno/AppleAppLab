# AppleAppLab — Known Issues globales

Base curada de problemas reutilizables en apps Apple. No sustituye la documentación oficial ni el diagnóstico del proyecto: Steve filtra estas entradas por contexto y el agente propietario verifica que apliquen antes de actuar.

> Estados: `hypothesis` = explicación aún no confirmada; `conditional` = solución válida bajo condiciones explícitas; `verified` = reproducida y corregida con verificación; `deprecated` = explicación o práctica retirada, conservada para evitar que reaparezca.

## Índice rápido

| ID | Estado | Área | Resumen |
|---|---|---|---|
| AAL-MAC-001 | verified | Menu bar | `MenuBarExtra` + `NSStatusItem` duplican el ícono |
| AAL-MAC-002 | conditional | Menu bar | El botón de `NSStatusItem` puede no estar disponible al configurarlo |
| AAL-MAC-003 | deprecated | Menu bar | Mito: una imagen template ignora siempre `contentTintColor` |
| AAL-MAC-004 | conditional | Disponibilidad/UI | El orden de ramas debe expresar la política de precedencia |
| AAL-MAC-005 | deprecated | Materials | Mito: una capa negra con opacidad 0.4 es obligatoria |
| AAL-MAC-006 | conditional | SwiftUI layout | Evitar scroll anidado; elegir el contenedor por semántica y layout |
| AAL-MAC-007 | verified | SwiftUI/AppKit | Cada `NSHostingView` inicia un árbol de entorno separado |
| AAL-MAC-008 | verified | Finder | Abrir y revelar son intenciones diferentes en `NSWorkspace` |
| AAL-MAC-009 | conditional | AppKit/Core Animation | Un glow externo necesita una superficie no recortada |
| AAL-MAC-010 | conditional | AppKit rendering | Evitar el primer frame incompleto antes de ordenar una ventana |
| AAL-MAC-011 | deprecated | Core Animation | Mito: `CALayer.anchorPoint` vale `(0, 0)` por defecto en AppKit |
| AAL-MAC-012 | conditional | Swift concurrency | `assumeIsolated` solo con garantía documentada de ejecución en main |
| AAL-MAC-013 | deprecated | Observation | Mito: `@Bindable var model = model` copia una instancia observable |
| AAL-MAC-014 | verified | SwiftUI/macOS | `editMode` no está disponible en macOS |
| AAL-MAC-015 | verified | SwiftUI/AppKit layout | Capa de ventana completa como `.overlay` desborda por el safe area del titlebar |
| AAL-TEST-001 | verified | Testing/codecs | Fixtures válidos y `#require` evitan traps del host de pruebas |
| AAL-TEST-002 | verified | Testing/persistencia | Tests y builds Debug nunca tocan los datos reales |
| AAL-UX-001 | verified | UX/persistencia | La UI no afirma éxito sin el resultado de la operación |
| AAL-DATA-001 | verified | SwiftData/CloudKit | Abrir el store nunca hace `fatalError` |
| AAL-SEC-001 | verified | Seguridad/helpers | `Process` con ruta fija, entorno mínimo y temporales propios |
| AAL-MAC-016 | conditional | AppKit/ciclo de vida | Monitores de eventos con teardown en cada salida y sin trabajo por evento |
| AAL-MAC-017 | verified | SwiftUI/AppKit | Un control que no responde: revisar quién está delante en el hit-test |
| AAL-MAC-018 | verified | Sparkle | `applicationShouldTerminate` no puede bloquear la instalación |
| AAL-BUILD-001 | verified | XcodeGen | Nombre de módulo y `TEST_HOST` explícitos |
| AAL-REL-001 | conditional | Firma/release | Capabilities y firma se verifican en el artifact firmado |
| AAL-SYNC-001 | conditional | Sync | Escribir intenciones y mostrar solo lo confirmado |
| AAL-SWIFT-001 | verified | Swift | Parsers binarios usan `loadUnaligned` |
| AAL-SWIFT-002 | verified | Swift 6 | Protocolo inyectado `async` en `@MainActor` declara `Sendable` |
| AAL-SWIFT-003 | verified | Swift | `case a, b where` solo aplica al último patrón |

## Entradas verificadas

### AAL-MAC-001 — Un solo propietario del ícono de menu bar

- **Fingerprint:** `menubar/duplicate-owner/menubarextra+nsstatusitem`
- **Categoría:** AppKit / SwiftUI / menu bar
- **Plataformas:** macOS; OS observado: macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `verified`
- **Síntoma:** aparecen dos íconos para la misma app en la barra de menú.
- **Reproducción/evidencia:** declarar un `MenuBarExtra` y crear además un `NSStatusItem` manual produce dos propietarios y dos ítems.
- **Hipótesis/causa raíz:** dos mecanismos independientes registran su propio elemento; no es un fallo de render.
- **Garantía de plataforma/fuente:** cada API representa un mecanismo de presentación; verificar contra la documentación del SDK usado.
- **Workaround:** ocultar temporalmente uno de los dos ítems.
- **Solución durable:** elegir un único propietario. Usar `NSStatusItem` cuando se necesite control AppKit no cubierto por `MenuBarExtra`.
- **Verificación:** una sola ruta de creación activa y un único ícono tras relanzar la app.
- **Prevención:** documentar el propietario del menu bar en TRD y probar launch/relaunch.
- **Relacionadas:** —

### AAL-MAC-007 — Inyectar dependencias en cada `NSHostingView`

- **Fingerprint:** `swiftui/environment/separate-nshostingview-tree`
- **Categoría:** SwiftUI / AppKit interoperability
- **Plataformas:** macOS 14+; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `verified`
- **Síntoma:** una ventana secundaria falla al resolver un modelo observable del environment.
- **Reproducción/evidencia:** crear una ventana con un nuevo `NSHostingView(rootView:)` sin volver a inyectar sus stores; el nuevo árbol no hereda el entorno de otro hosting root.
- **Hipótesis/causa raíz:** cada hosting root inicia su propia jerarquía SwiftUI.
- **Garantía de plataforma/fuente:** el environment fluye por una jerarquía de vistas, no entre raíces independientes; [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app).
- **Workaround:** pasar la dependencia como inicializador si solo la usa una vista.
- **Solución durable:** centralizar la composición de cada ventana e inyectar explícitamente todos sus modelos compartidos.
- **Verificación:** abrir cada ventana desde cold launch y confirmar identidad compartida y ausencia del fallo.
- **Prevención:** test de composición por ventana y lista de dependencias por hosting root.
- **Relacionadas:** AAL-MAC-013

### AAL-MAC-008 — Distinguir “abrir” de “revelar en Finder”

- **Fingerprint:** `nsworkspace/open-vs-activatefileviewerselecting`
- **Categoría:** AppKit / Finder integration
- **Plataformas:** macOS 14+; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `verified`
- **Síntoma:** Finder muestra la carpeta padre y selecciona la carpeta cuando se esperaba ver su contenido.
- **Reproducción/evidencia:** `activateFileViewerSelecting([url])` revela el ítem; `open(url)` pide abrirlo con la aplicación apropiada.
- **Hipótesis/causa raíz:** se eligió una API cuya intención era revelar, no abrir.
- **Garantía de plataforma/fuente:** ambas operaciones son contratos distintos de [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace).
- **Workaround:** ninguno necesario; corregir la intención.
- **Solución durable:** definir el copy y comportamiento como “Abrir” o “Mostrar en Finder”, y usar la API correspondiente.
- **Verificación:** prueba funcional de ambas acciones con archivo y directorio.
- **Prevención:** criterios de aceptación nombran la intención exacta.
- **Relacionadas:** —

### AAL-MAC-014 — Diseñar edición de listas específicamente para macOS

- **Fingerprint:** `swiftui/macos/editmode-unavailable`
- **Categoría:** SwiftUI / desktop interaction
- **Plataformas:** macOS 14+; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Jonny + Woz / `verified`
- **Síntoma:** el proyecto no compila al usar `EnvironmentValues.editMode` en macOS.
- **Reproducción/evidencia:** compilar una vista macOS que accede a `editMode` produce unavailable.
- **Hipótesis/causa raíz:** se trasladó a macOS un patrón de edición de plataformas touch.
- **Garantía de plataforma/fuente:** la disponibilidad se define en el SDK; [List](https://developer.apple.com/documentation/swiftui/list) conserva semánticas propias, pero no hace portable `editMode`.
- **Workaround:** controles explícitos de borrar/reordenar adecuados al escritorio.
- **Solución durable:** Jonny define el modelo de interacción macOS; Woz elige `List`, `Table`, `ForEach` o `LazyVStack` según selección, accesibilidad, navegación y layout, no como sustitución automática.
- **Verificación:** build macOS y pruebas de teclado, VoiceOver, selección, borrado y reordenamiento.
- **Prevención:** revisar disponibilidad y HIG por plataforma antes de compartir vistas.
- **Relacionadas:** AAL-MAC-006

### AAL-TEST-001 — Mantener fixtures válidos y fallar con diagnósticos

- **Fingerprint:** `testing/strict-codec/complete-fixture-no-force-unwrap`
- **Categoría:** testing / payloads versionados
- **Plataformas:** Apple platforms; observado en macOS 14+; Xcode 26.3, SDK macOS 26.2
- **Proyecto fuente / fechas:** ToDoPro; first seen 2026-08-20; last verified 2026-08-20
- **Owner / status:** Woz + Bertrand / `verified`
- **Síntoma:** una suite cierra su host al probar un payload después de endurecer su validación.
- **Reproducción/evidencia:** en ToDoPro, un fixture conservó revisiones parciales del contrato anterior; el codec lo rechazó y un force unwrap posterior produjo `SIGTRAP`. El test focalizado y la suite completa pasaron tras corregir ambos puntos, sin nuevos crash reports.
- **Hipótesis/causa raíz:** confirmada en el proyecto fuente: el fixture ya no representaba un envelope válido y el harness trataba como infalible un resultado derivado de validación.
- **Garantía de plataforma/fuente:** ninguna; es un contrato interno del codec y del harness.
- **Workaround:** reemplazar el force unwrap por una guarda temporal permite diagnosticar el fixture, pero no corrige sus datos.
- **Solución durable:** construir fixtures desde un payload válido y completo, modificar solo los campos objetivo y usar `try #require(...)` para prerrequisitos críticos del test.
- **Verificación:** test focalizado, suite macOS completa, build iOS Simulator y ausencia de nuevos `.ips` tras la corrección.
- **Prevención:** cada cambio estricto de codec actualiza en la misma entrega el corpus válido, los casos inválidos explícitos y sus expectativas; no usar `!` sobre resultados de parseo, validación o fetch.
- **Ampliación (cosecha 2026-10-05, Todocky `APP-TODOPRO-011`/`-020`, NewProject `APP-NPR-001`):** tests deterministas — (1) todo test de expiración, skew o retry inyecta un reloj fijo y pasa la misma fecha al validador; nunca dos lecturas de `Date.now` cerca de un límite; (2) los fixtures salen del productor real (el repositorio tras la operación), no escritos a mano; (3) una constante de producto en una aserción cita su fuente (PRD, roadmap) junto a la aserción; si test y código discrepan falta una decisión, no un número.
- **Relacionadas:** AAL-TEST-002

### AAL-MAC-015 — Capas de ventana completa dentro del contenedor que ignora el safe area

- **Fingerprint:** `swiftui/fullsizecontentview/overlay-after-ignoresSafeArea-overflow`
- **Categoría:** SwiftUI / AppKit / layout de ventana
- **Plataformas:** macOS; observado en macOS 15; Xcode 26, Swift 6
- **Proyecto fuente / fechas:** New PROject (`APP-NPR-005`); first seen 2026-09-27; last verified 2026-09-27
- **Owner / status:** Woz + Steve / `verified`
- **Síntoma:** en una ventana con titlebar transparente, una vista que reemplaza toda la pantalla (un editor mostrado encima de Settings) queda con su pie pegado o cortado contra el borde inferior, mientras las demás pantallas de la misma ventana se ven bien.
- **Reproducción/evidencia:** ventana `.fullSizeContentView` + `titlebarAppearsTransparent`; raíz SwiftUI con `.frame(minHeight: alto de ventana).ignoresSafeArea()`; la vista de pantalla completa agregada como `.overlay { … }` después. Medido: el pie sobresale ~13–16 pt (≈ la altura del titlebar a repartir).
- **Hipótesis/causa raíz:** confirmada — el `.overlay` recibe la propuesta de tamaño del view al que se encadena, calculada contra el safe area reducido por el titlebar; su contenido pide el alto completo y se desborda. El `ZStack` de la raíz sí ignora el safe area, por eso sus hijos se ven bien.
- **Garantía de plataforma/fuente:** comportamiento de layout de SwiftUI con safe areas; no es un bug del sistema.
- **Workaround:** ninguno fiable; quitar el `minHeight` de la vista superpuesta **no** lo corrige.
- **Solución durable:** poner la capa de pantalla completa como un hijo más del mismo `ZStack` que ya ignora el safe area (`if let request { EditorView(…) }`), sin tamaño mínimo propio. Recibe el mismo frame borde a borde que el resto.
- **Verificación:** chequeo de los cuatro bordes con frames reales (accesibilidad) contra el diseño; captura con margen fuera de la ventana; UI test de margen inferior (ver `/bertrand`).
- **Prevención:** cambiar la forma de presentación (sheet ↔ overlay ↔ inline) es un cambio de layout: re-verificar bordes de la vista y de su ventana (`/woz`, `/update-ui` Fase 6). Agrandar el titlebar (p. ej. reposicionar traffic lights) agranda el safe area y hace el problema más visible.
- **Relacionadas:** AAL-MAC-007 (cada `NSHostingView` es un árbol separado), AAL-MAC-010.

### AAL-TEST-002 — Tests y builds Debug nunca tocan los datos reales

- **Fingerprint:** `testing/hosted-tests-share-real-store+debug-shares-bundle-id`
- **Categoría:** testing / persistencia / entorno
- **Plataformas:** macOS 14+ e iOS 17+; Core Data, SwiftData, archivos en contenedor; Xcode 17C519 / 26.3
- **Proyecto fuente / fechas:** Inspoflow (`INSP-QA-002`, 2026-09-18), NewProject (`APP-NPR-006`, `APP-NPR-007`), ToDoPro (`APP-TODOPRO-009`, 2026-08-20); cosechado 2026-10-05
- **Owner / status:** Bertrand + Woz / `verified`
- **Síntoma:** un test espera 2 ítems y recibe el board real (~36); tests alojados borran archivos semilla del usuario; una migración "de prueba" en Debug corre sobre los datos reales; un test de estado inicializa el container real de CloudKit y cierra el host.
- **Reproducción/evidencia:** los tests alojados en la app comparten su contenedor sandbox, su store por defecto y CloudKit; un build Debug con el mismo bundle id que Release lee y escribe el mismo contenedor.
- **Hipótesis/causa raíz:** confirmada en las tres apps: la ubicación del store no era inyectable y el Debug no tenía identidad propia.
- **Garantía de plataforma/fuente:** el contenedor sandbox y el contenedor de CloudKit siguen al bundle id / App ID; un test bundle alojado corre dentro del proceso de la app.
- **Workaround:** copiar los datos a mano antes de probar (no sirve si el Debug sigue apuntando al contenedor real).
- **Solución durable:** (1) la URL del store se inyecta; cada test usa un store in-memory o un sqlite en un directorio temporal propio, con CloudKit apagado; (2) los tests de políticas de sync dependen de valores puros o protocolos, nunca construyen `CKContainer`; (3) el Debug lleva `PRODUCT_BUNDLE_IDENTIFIER` con sufijo `.debug` y su propio contenedor; probar una migración = copiar datos al contenedor `.debug`.
- **Verificación:** Inspoflow: tests de migración en verde con sqlite en temp; ToDoPro: 47/47 sin `CKContainer` en el test; NewProject: migración probada en la copia `.debug`.
- **Prevención:** Bertrand rechaza un test que lea el store por defecto; el scaffold de Woz nace con sufijo `.debug`.
- **Relacionadas:** AAL-TEST-001, AAL-DATA-001

### AAL-UX-001 — La UI no afirma éxito sin el resultado de la operación

- **Fingerprint:** `ux/false-success/unchecked-save+fake-synced+raw-error-code`
- **Categoría:** UX / persistencia / sync
- **Plataformas:** iOS 17+, macOS 14+; SwiftData, CloudKit
- **Proyecto fuente / fechas:** Fintrol (`FINTROL-2026-001`, 2026-08-28), ToDoPro (`CK-NET-001`, `TIMER-EXCLUSIVE-001`, `TIMER-STAGE-001`), Todocky (`APP-TODOPRO-016`); cosechado 2026-10-05
- **Owner / status:** Woz + Larry + Bertrand / `verified`
- **Síntoma:** el sheet anima el check y se cierra aunque `save()` falló (dato perdido); Settings dice "Synced" sin recibo; Play no hace nada sin alerta; el usuario ve `CKErrorDomain error 4`.
- **Reproducción/evidencia:** Fintrol: forzar un store no escribible → éxito animado y dato perdido; ToDoPro: errores del ledger tragados con `try?` y copy genérico.
- **Hipótesis/causa raíz:** confirmada: la vista no lee el resultado de la operación, o el resultado se pierde en un `try?`.
- **Garantía de plataforma/fuente:** ninguna; es contrato de la app.
- **Workaround:** —
- **Solución durable:** la acción devuelve resultado (`Bool`/`throws`) y la vista anima éxito solo con éxito; con fallo se queda abierta y conserva lo escrito; nada de `try?` en escrituras del usuario; "Synced" exige outbox vacío y recibo durable; los errores se traducen a copy humano accionable (nunca un código de dominio crudo).
- **Verificación:** Fintrol `RegresionBugsCriticosTests` 5/5; ToDoPro `DatabaseSyncServiceTests` 45/45 (sin `CKErrorDomain error N` en UI).
- **Prevención:** Bertrand escribe un test de guardado fallido por cada flujo de captura; Larry marca cualquier feedback de éxito no condicionado al resultado.
- **Relacionadas:** AAL-DATA-001, AAL-SYNC-001

### AAL-DATA-001 — Abrir el store nunca hace `fatalError`

- **Fingerprint:** `persistence/swiftdata/fatalerror-on-open`
- **Categoría:** persistencia / SwiftData / CloudKit
- **Plataformas:** iOS 17+, macOS 14+; Xcode 26.3
- **Proyecto fuente / fechas:** Fintrol (`FINTROL-2026-003`, 2026-08-28), ToDoPro (`APP-TODOPRO-001` 2026-08-11, `APP-TODOPRO-005` 2026-08-12); cosechado 2026-10-05
- **Owner / status:** Avie + Woz + Bertrand / `verified`
- **Síntoma:** la app cierra al arrancar (SIGTRAP) en el primer run firmado contra un Team real, o tras añadir atributos a un modelo con datos.
- **Reproducción/evidencia:** Fintrol: `ModelContainer(cloudKitDatabase: .automatic)` falla por aprovisionamiento y `makeContainer()` hace `fatalError`; ToDoPro: atributos nuevos obligatorios sin valor en filas existentes impiden la migración ligera.
- **Hipótesis/causa raíz:** confirmada: cualquier error de apertura se trataba como imposible.
- **Garantía de plataforma/fuente:** `ModelContainer.init` lanza; la migración ligera de SwiftData necesita valor para atributos no opcionales.
- **Workaround:** borrar el store (pierde datos del usuario).
- **Solución durable:** ruta de store explícita en Application Support; si falla la capa CloudKit, reintentar local-only sobre el mismo `storeURL` y marcar el estado de sync; si falla la apertura local, mover store y sidecars a `Recovery/` e informar; atributos nuevos opcionales o con default (o `VersionedSchema` + plan de migración).
- **Verificación:** Fintrol `PersistenceControllerFallbackTests` 2/2; ToDoPro: arranque contra el store existente y la app firmada tras reinicio limpio sin crash report.
- **Prevención:** test de arranque contra un store de la versión anterior antes de cada cambio de modelo.
- **Relacionadas:** AAL-TEST-002, AAL-UX-001

### AAL-SEC-001 — `Process` con ruta fija, entorno mínimo y temporales propios

- **Fingerprint:** `security/process/path-env-args-tempfiles`
- **Categoría:** seguridad / helpers externos
- **Plataformas:** macOS 13+ sin sandbox; Swift 6.2
- **Proyecto fuente / fechas:** Bingen (`BINGEN-2026-001`, `BINGEN-2026-006`, 2026-09-06), Inspoflow (`INSP-SEC-002`, 2026-09-19); cosechado 2026-10-05
- **Owner / status:** Ivan + Woz / `verified`
- **Síntoma:** el helper hereda el entorno completo del usuario (variables que cambian su comportamiento), puede tomarse de `PATH`, lee configuración del usuario, recibe strings sin escapar y deja temporales sueltos.
- **Reproducción/evidencia:** auditorías de Ivan en ambas apps (S-001/S-003/S-004/S-009 en Bingen; SEC-PROC-001/002 en Inspoflow).
- **Hipótesis/causa raíz:** confirmada: los defaults de `Process` heredan entorno y la app no tenía allowlist ni namespace temporal.
- **Garantía de plataforma/fuente:** `Process.environment` hereda el del padre si no se fija.
- **Workaround:** —
- **Solución durable:** ejecutable por ruta absoluta dentro del bundle (fallback a `PATH` solo en DEBUG); `environment` explícito en allowlist; desactivar config de usuario del helper (p. ej. `--ignore-config`); todo string libre interpolado en argumentos pasa por una función de escape única que también filtra caracteres de control; temporales en un subdirectorio propio de `temporaryDirectory`, con `defer` si se consumen en la misma función o barrido por edad si los consume otra app; listeners locales (OAuth loopback) solo en `127.0.0.1`.
- **Verificación:** Bingen 53/53 + 4/4; Inspoflow 35 tests (args, loopback, env).
- **Prevención:** Ivan incluye `Process` en el threat model; Woz no crea un `Process` sin estos cinco puntos.
- **Relacionadas:** AAL-REL-001

### AAL-MAC-017 — Un control que no responde: revisar quién está delante en el hit-test

- **Fingerprint:** `ui/hit-testing/front-view-steals-click-or-drop`
- **Categoría:** SwiftUI / AppKit / interacción
- **Plataformas:** macOS 14+; Xcode 17C519, macOS 15.8
- **Proyecto fuente / fechas:** Inspoflow (`INSP-UI-001`, 2026-10-02), Todocky (`APP-TODOPRO-024`, 2026-09-28); cosechado 2026-10-05
- **Owner / status:** Woz / `verified`
- **Síntoma:** soltar archivos de Finder sobre tarjetas no hace nada (solo en los huecos); el checkbox de completar no responde, solo en filas con nombre largo.
- **Reproducción/evidencia:** Inspoflow: `.onDrop` de SwiftUI vive en una vista AppKit detrás del contenido y el `NSImageView` de la miniatura, delante, registra tipos y rechaza; Todocky: un botón con `.fixedSize()` + `.offset()` (marquee) crece fuera de su slot y gana el hit-test al hermano declarado antes.
- **Hipótesis/causa raíz:** confirmada en ambas con test rojo / reproducción en vivo.
- **Garantía de plataforma/fuente:** AppKit entrega el drag a la vista de delante con tipos coincidentes; en SwiftUI, a igual `zIndex` el orden de declaración decide.
- **Workaround:** —
- **Solución durable:** un `NSViewRepresentable` delante de un `.onDrop` no registra dragged types (subclase que los anula) o acepta él el drop; cualquier vista con `.fixedSize()`+`.offset()` junto a controles interactivos les da `zIndex` explícito.
- **Verificación:** Inspoflow test rojo→verde; Todocky dos tasks reales completan al primer click, 243/243.
- **Prevención:** ante "no responde al click/drop" la primera hipótesis a falsar es la vista de delante, antes que estado o lógica.
- **Relacionadas:** AAL-MAC-007

### AAL-BUILD-001 — XcodeGen: nombre de módulo y `TEST_HOST` explícitos

- **Fingerprint:** `xcodegen/module-name-case+multiplatform-test-host`
- **Categoría:** build system / testing
- **Plataformas:** macOS 26, XcodeGen 2.45.4, Xcode 17C519 / 27
- **Proyecto fuente / fechas:** Fintrol (`FIN-2026-001`, `FIN-2026-002`, 2026-09-15), Inspoflow (`INSP-QA-001`, 2026-09-18); cosechado 2026-10-05
- **Owner / status:** Woz / `verified`
- **Síntoma:** `no such module 'Inspoflow'` en tests aunque la app compila; `Could not find test host … Fintrol.app/Fintrol` al testear en macOS un target multiplataforma; AppleAppLabUI no compilaba para iOS.
- **Reproducción/evidencia:** Inspoflow: `PRODUCT_NAME` `InspoFlow` vs `@testable import Inspoflow` (scanner case-sensitive); Fintrol: XcodeGen deriva `TEST_HOST` con layout de bundle iOS para `supportedDestinations: [iOS, macOS]`.
- **Hipótesis/causa raíz:** módulo: confirmada. `TEST_HOST`: comportamiento observado de XcodeGen, no confirmado en su código fuente.
- **Garantía de plataforma/fuente:** el bundle macOS lleva el ejecutable en `Contents/MacOS/`.
- **Workaround:** —
- **Solución durable:** `PRODUCT_MODULE_NAME` explícito igual al `@testable import`; en el test target de un app multiplataforma, `TEST_HOST[sdk=macosx*]: $(BUILT_PRODUCTS_DIR)/App.app/Contents/MacOS/App` y `BUNDLE_LOADER[sdk=macosx*]: $(TEST_HOST)`; AppleAppLabUI se compila para iOS además de macOS antes de publicar cambios (`make ui-check`).
- **Verificación:** Fintrol 49/49 en macOS y en iPhone Simulator; Inspoflow `TEST SUCCEEDED`, 18 tests.
- **Prevención:** el template de `project.yml` de Woz ya trae ambos ajustes.
- **Relacionadas:** —

### AAL-SWIFT-001 — Parsers binarios usan `loadUnaligned`

- **Fingerprint:** `swift/unsafe-raw/load-unaligned-offset-trap`
- **Categoría:** Swift / parsing binario
- **Plataformas:** Swift 5.7+ (macOS 13+, iOS 16+); observado con Swift 6.2.4
- **Proyecto fuente / fechas:** Bingen (`BINGEN-2026-008`, 2026-09-06); cosechado 2026-10-05
- **Owner / status:** Woz / `verified`
- **Síntoma:** el proceso aborta (signal 5, no catcheable) al leer un STL binario con 2+ triángulos.
- **Reproducción/evidencia:** cada triángulo STL mide 50 bytes; desde el segundo, los `Float`/`UInt32` quedan en offsets no alineados.
- **Hipótesis/causa raíz:** confirmada: `load(fromByteOffset:as:)` exige alineación del tipo y trapea si no la hay.
- **Garantía de plataforma/fuente:** documentación de `UnsafeRawPointer.load(fromByteOffset:as:)` y `loadUnaligned` (SE-0349).
- **Workaround:** —
- **Solución durable:** `loadUnaligned(fromByteOffset:as:)` por defecto en cualquier formato de terceros; no envolver el parser primario en `try?` que caiga a un fallback y oculte "archivo corrupto".
- **Verificación:** 123 XCTest, incluidos 2, 4 y 1000 triángulos y STL truncado.
- **Prevención:** revisar `load(fromByteOffset:` en code review salvo offset alineado demostrable.
- **Relacionadas:** AAL-UX-001

### AAL-SWIFT-002 — Protocolo inyectado con métodos `async` en un tipo `@MainActor` declara `Sendable`

- **Fingerprint:** `swift/concurrency/existential-async-mainactor-sendable`
- **Categoría:** Swift 6 / concurrencia / testabilidad
- **Plataformas:** Swift 6.0–6.2 modo estricto
- **Proyecto fuente / fechas:** Bingen (`BINGEN-2026-007`, 2026-09-06); cosechado 2026-10-05
- **Owner / status:** Woz / `verified`
- **Síntoma:** al cambiar `let service: OpenSCADService` por `let service: any RenderEngine` en un ViewModel `@MainActor`, ~15 llamadas `await` fallan con `sending 'self.service' risks causing data races`.
- **Reproducción/evidencia:** con el tipo concreto el compilador infiere `Sendable`; con el existencial no puede.
- **Hipótesis/causa raíz:** confirmada: el existencial no aporta la garantía de `Sendable`.
- **Garantía de plataforma/fuente:** reglas de region-based isolation de Swift 6.
- **Workaround:** —
- **Solución durable:** `protocol RenderEngine: Sendable` desde el inicio, y la conformidad declarada en la declaración del tipo concreto (no en una extensión de otro archivo).
- **Verificación:** `swift build` sin warnings; 67 XCTest + 4 Swift Testing.
- **Prevención:** todo seam de protocolo para tests sobre un ViewModel `@MainActor` nace `Sendable` si sus requisitos son `async`.
- **Relacionadas:** AAL-MAC-012

### AAL-SWIFT-003 — `case a, b where cond:` solo aplica el `where` al último patrón

- **Fingerprint:** `swift/pattern-matching/where-clause-scoped-to-last-pattern`
- **Categoría:** Swift / corrección
- **Plataformas:** Swift 6
- **Proyecto fuente / fechas:** Todocky (`APP-TODOPRO-023`, 2026-09-28); cosechado 2026-10-05
- **Owner / status:** Woz / `verified`
- **Síntoma:** un atajo de teclado se dispara sin la condición para uno de los patrones; el compilador avisa "'where' only applies to the second pattern match in this 'case'".
- **Reproducción/evidencia:** `case "]", "}" where canvasFocused:` ejecuta con `"]"` aunque `canvasFocused` sea `false`.
- **Hipótesis/causa raíz:** confirmada: semántica del lenguaje.
- **Garantía de plataforma/fuente:** The Swift Programming Language, Patterns.
- **Workaround:** —
- **Solución durable:** repetir el `where` en cada patrón o separar los `case`.
- **Verificación:** build sin el warning; 243/243.
- **Prevención:** ese warning se trata como error en revisión.
- **Relacionadas:** —

### AAL-MAC-018 — Sparkle: `applicationShouldTerminate` no puede bloquear la instalación

- **Fingerprint:** `updater/sparkle/terminateLater-timeout-blocks-install`
- **Categoría:** updater / ciclo de vida
- **Plataformas:** macOS 14+, Sparkle 2
- **Proyecto fuente / fechas:** ToDoPro (`SPARKLE-QUIT-001`, 2026-09-16); cosechado 2026-10-05
- **Owner / status:** Woz / `verified`
- **Síntoma:** al pulsar Cerrar para instalar una actualización, la app no termina y Sparkle se queda esperando.
- **Reproducción/evidencia:** un gate de persistencia devolvía `.terminateLater` y, ante timeout de flush, `reply(false)`; un segundo `terminate` con reply pendiente devolvía `.terminateLater` otra vez sin responder.
- **Hipótesis/causa raíz:** confirmada: Sparkle necesita que el proceso muera para instalar.
- **Garantía de plataforma/fuente:** contrato de `NSApplicationDelegate.applicationShouldTerminate(_:)` / `reply(toApplicationShouldTerminate:)`.
- **Workaround:** forzar salida desde Activity Monitor.
- **Solución durable:** política "instalar actualización" que siempre sale; timeout de flush responde `true`; drenar el guardado en `updater(_:shouldPostponeRelaunchForUpdate:untilInvokingBlock:)`; nunca devolver `.terminateLater` dos veces sin un reply; sin trabajo pendiente, `.terminateNow`.
- **Verificación:** `AppStateSaveQueueTests` 8/8.
- **Prevención:** `/update-feature` lo revisa en toda app con `applicationShouldTerminate`.
- **Relacionadas:** —

## Entradas condicionales

### AAL-MAC-002 — Configuración defensiva de `NSStatusItem.button`

- **Fingerprint:** `nsstatusitem/button-nil-at-launch`
- **Categoría:** AppKit / lifecycle
- **Plataformas:** macOS; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `conditional`
- **Síntoma:** el status item se crea, pero el ícono no aparece.
- **Reproducción/evidencia:** en New PROject, `statusItem.button` fue `nil` durante configuración inicial; diferir permitió configurarlo. Falta reproducción matriz y la causa del timing no está garantizada.
- **Hipótesis/causa raíz:** timing de inicialización del status bar; hipótesis, no contrato de macOS 26.
- **Garantía de plataforma/fuente:** `button` es opcional en [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem/button); Apple no garantiza aquí que “el subsistema aún no esté listo”.
- **Workaround:** conservar fuertemente el item y reintentar de forma acotada en main solo después de comprobar `button == nil`.
- **Solución durable:** ciclo de vida `@MainActor`, referencia fuerte, configuración idempotente, telemetría no sensible y fallo visible si se agotan los reintentos.
- **Verificación:** prueba repetida de cold launch/relaunch en las versiones soportadas; confirmar que no se crean duplicados.
- **Prevención:** no introducir delays fijos ni atribuir la causa a una versión sin evidencia.
- **Relacionadas:** AAL-MAC-001

### AAL-MAC-004 — La precedencia de ramas es política, no receta

- **Fingerprint:** `swiftui/availability-branch-precedence`
- **Categoría:** SwiftUI / availability / accessibility
- **Plataformas:** Apple platforms; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Avie + Jonny / `conditional`
- **Síntoma:** una variante fallback cubre una implementación nueva o una necesidad de accesibilidad.
- **Reproducción/evidencia:** el primer branch verdadero gana; en New PROject el orden seleccionó el fallback oscuro antes del estilo disponible.
- **Hipótesis/causa raíz:** la precedencia visual no estaba documentada.
- **Garantía de plataforma/fuente:** `#available` comprueba disponibilidad, pero no decide la política de producto.
- **Workaround:** reordenar el branch para reflejar la intención comprobada.
- **Solución durable:** documentar precedencia entre disponibilidad, Reduce Transparency/Contrast, configuración y fallback; probar cada combinación material.
- **Verificación:** matriz de ramas y captura/inspección de cada caso alcanzable.
- **Prevención:** evitar la regla falsa “`#available` siempre primero”.
- **Relacionadas:** AAL-MAC-005

### AAL-MAC-006 — No anidar superficies con scroll independiente

- **Fingerprint:** `swiftui/nested-scroll/list-inside-scrollview`
- **Categoría:** SwiftUI / layout / accessibility
- **Plataformas:** Apple platforms; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Jonny + Woz / `conditional`
- **Síntoma:** contenido ausente, altura inesperada o interacción de scroll conflictiva al anidar `List` en `ScrollView`.
- **Reproducción/evidencia:** New PROject observó colapso; la conducta exacta depende de propuestas de tamaño y composición.
- **Hipótesis/causa raíz:** dos contenedores desplazables compiten por layout e interacción; “`List` siempre colapsa a cero” no está garantizado.
- **Garantía de plataforma/fuente:** [List](https://developer.apple.com/documentation/swiftui/list) aporta semánticas de selección, filas y plataforma que un stack no replica automáticamente.
- **Workaround:** eliminar uno de los contenedores de scroll o dar una restricción explícita si el diseño realmente requiere composición.
- **Solución durable:** un único propietario del scroll; escoger `List`, `Table`, `LazyVStack` o layout custom según semántica, teclado y accesibilidad.
- **Verificación:** datos vacíos/largos, redimensionamiento, teclado, VoiceOver y plataformas objetivo.
- **Prevención:** revisión de jerarquía de scroll en diseño y tests.
- **Relacionadas:** AAL-MAC-014

### AAL-MAC-009 — Glow externo en una superficie no recortada

- **Fingerprint:** `appkit/external-glow/clipped-layer`
- **Categoría:** AppKit / Core Animation / effects
- **Plataformas:** macOS; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Jonny + Woz / `conditional`
- **Síntoma:** la sombra/glow no se ve fuera de la geometría de la ventana o vista.
- **Reproducción/evidencia:** el efecto se recorta cuando algún ancestro o la superficie de ventana limita el render exterior.
- **Hipótesis/causa raíz:** clipping o límites de composición, no necesariamente solo `masksToBounds` del hosting view.
- **Garantía de plataforma/fuente:** Core Animation recorta según su jerarquía y geometría; no hay garantía de render fuera de la superficie de ventana.
- **Workaround:** reducir el efecto al interior cuando el diseño lo permita.
- **Solución durable:** inspeccionar toda la cadena de clipping. Un `NSPanel` transparente hijo con `CAShapeLayer`/`shadowPath` es válido si necesita exceder la ventana; gestionar foco, input, Spaces y ciclo de vida.
- **Verificación:** bordes completos, múltiples pantallas/escala, movimiento y cierre sin paneles huérfanos.
- **Prevención:** Jonny especifica bounds/timing; los valores de New PROject son calibración, nunca defaults globales.
- **Relacionadas:** AAL-MAC-010, AAL-MAC-011

### AAL-MAC-010 — Configurar antes de presentar; cancelar trabajo diferido

- **Fingerprint:** `appkit/window/first-frame-flash`
- **Categoría:** AppKit / rendering / lifecycle
- **Plataformas:** macOS; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `conditional`
- **Síntoma:** flash de una superficie vacía o incompleta en la primera presentación.
- **Reproducción/evidencia:** New PROject observó un frame transitorio al adjuntar/presentar el panel antes de completar su estado visual.
- **Hipótesis/causa raíz:** orden de configuración/presentación; no está probado que crear el panel “dentro de `asyncAfter`” sea universal.
- **Garantía de plataforma/fuente:** AppKit renderiza ventanas ordenadas; un delay arbitrario no constituye sincronización garantizada.
- **Workaround:** diferir de forma cancelable cuando exista una transición intencional.
- **Solución durable:** configurar contenido, alpha y layers antes de `order`; si hay trabajo diferido, usar una tarea cancelable que valide la ventana/estado vigente.
- **Verificación:** grabación frame a frame de primer uso y usos posteriores; abrir/cerrar rápidamente para buscar efectos tardíos.
- **Prevención:** no usar `asyncAfter` fijo como receta ni crear efectos huérfanos.
- **Relacionadas:** AAL-MAC-009

### AAL-MAC-012 — `MainActor.assumeIsolated` exige garantía de plataforma

- **Fingerprint:** `swift6/nsanimationcontext/completion-mainactor`
- **Categoría:** Swift concurrency / AppKit
- **Plataformas:** macOS con Swift 6; observado en macOS 26; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `conditional`
- **Síntoma:** diagnóstico de aislamiento al mutar AppKit dentro del completion de `NSAnimationContext`.
- **Reproducción/evidencia:** strict concurrency no expresa el aislamiento en el tipo del callback; Apple documenta que el completion se invoca en el main thread.
- **Hipótesis/causa raíz:** diferencia entre una garantía documental y las anotaciones de concurrencia importadas.
- **Garantía de plataforma/fuente:** [NSAnimationContext.completionHandler](https://developer.apple.com/documentation/appkit/nsanimationcontext/completionhandler) documenta ejecución en main.
- **Workaround:** saltar con `Task { @MainActor in ... }` cuando no haya una garantía equivalente.
- **Solución durable:** usar `MainActor.assumeIsolated` solo en este boundary documentado y mantener propietarios AppKit en `@MainActor`; no generalizar a otros callbacks.
- **Verificación:** build con strict concurrency y tests de cancelación/ciclo de vida de la animación.
- **Prevención:** enlazar la garantía primaria en comentarios del boundary y revalidarla al cambiar SDK.
- **Relacionadas:** AAL-MAC-010

### AAL-REL-001 — Capabilities y firma se verifican en el artifact firmado

- **Fingerprint:** `release/effective-entitlements-vs-source`
- **Categoría:** firma / release / CloudKit
- **Plataformas:** iOS 17+, macOS 14+; Xcode 26.3 / 27
- **Proyecto fuente / fechas:** ToDoPro/Todocky (`APP-TODOPRO-012`, `-013`, `-015`, `-019`, 2026-08-21 → 2026-09-23), Fintrol (`FIN-2026-006`, `FINTROL-2026-003`), Inspoflow (`INSP-SEC-004`, hypothesis); cosechado 2026-10-05
- **Owner / status:** Ivan + Craig + Phil / `conditional`
- **Síntoma:** el proyecto declara Push/iCloud pero el binario no tiene APS; `fileExporter` trapea en `AppKitBreakInDebugger`; tras un rebrand todo sync da `permissionFailure`; un build Production dice `Sync failed`; Keychain falla en tests de iOS Simulator sin firma; un helper con hardened runtime no carga su framework.
- **Reproducción/evidencia:** en cada caso el `.entitlements`/`.pbxproj` fuente era correcto y el artifact firmado no (perfil sin la capability, contenedor de otro App ID, schema no desplegado en Production, binario sin firmar).
- **Hipótesis/causa raíz:** confirmada en ToDoPro/Todocky y Fintrol; Inspoflow pendiente de verificación con Developer ID.
- **Garantía de plataforma/fuente:** los entitlements efectivos salen del perfil de aprovisionamiento al firmar; el contenedor de CloudKit sigue al App ID; Production solo conoce el schema desplegado.
- **Workaround:** —
- **Solución durable:** tras cada cambio de capability, bundle id o firma: `codesign -d --entitlements - <App.app>` (y de cada helper anidado) sobre el artifact; sandbox macOS con `fileImporter`/`fileExporter`/paneles declara `com.apple.security.files.user-selected.read-write` en todas las configuraciones; un rebrand de bundle id es una migración de contenedor; el gate de archive compara el schema exportado contra Production; tests de Keychain en iOS Simulator corren firmados, no con `CODE_SIGNING_ALLOWED=NO`; helpers de terceros re-firmados con hardened runtime llevan su propio `.entitlements`.
- **Verificación:** ToDoPro: artifact con el entitlement, export App Store Connect build 8, Push y Production convergiendo en dos equipos; Todocky 242/242 + migración de contenedor en vivo; Fintrol 96/96 firmado.
- **Prevención:** Ivan (archive recheck), Craig (paso de CI) y Phil (pre-submission) leen entitlements del artifact, no del fuente.
- **Relacionadas:** AAL-DATA-001, AAL-SEC-001

### AAL-SYNC-001 — Sync local-first: escribir intenciones y mostrar solo lo confirmado

- **Fingerprint:** `sync/write-intent-not-disk-state+honest-status`
- **Categoría:** sincronización / persistencia / UI de estado
- **Plataformas:** macOS 14+, iOS 17+; iCloud Drive y CKSyncEngine
- **Proyecto fuente / fechas:** NewProject (`APP-NPR-008`, `APP-NPR-010`), ToDoPro/Todocky (`APP-TODOPRO-004` 2026-08-12, `APP-TODOPRO-016` implemented-unverified); cosechado 2026-10-05
- **Owner / status:** Avie + Woz / `conditional`
- **Síntoma:** guardar en una Mac pisa lo que otra Mac acababa de cambiar; una edición local pendiente deja de enviarse tras recibir un cambio remoto; un ítem editado en otra Mac desaparece de la lista y vuelve; "Synced" aparece sin que la otra Mac reciba todo.
- **Reproducción/evidencia:** NewProject guardaba "todo lo que difiere del disco"; ToDoPro marcaba la entidad como sincronizada tras un merge por campo; un archivo en descarga se trataba como inexistente.
- **Hipótesis/causa raíz:** confirmada para las escrituras (ambas apps); el estado "Synced" falso confirmado en código, divergencia física pendiente.
- **Garantía de plataforma/fuente:** ninguna; es contrato de la app sobre datos que cambian fuera del proceso.
- **Workaround:** —
- **Solución durable:** (1) una escritura describe qué cambió el usuario (delta por campo con revisión), no cómo debe quedar el disco; un merge remoto conserva y reencola los campos locales pendientes que ganan; (2) "no lo puedo leer ahora" no es "no existe": mostrar lo último conocido marcado como pendiente; "Synced" exige outbox vacío y recibo durable.
- **Verificación:** NewProject en dos Macs; ToDoPro `remoteMergeRetainsNewerPendingFieldAndPropagatesBothEdits`.
- **Prevención:** Avie revisa estos dos puntos al diseñar cualquier sync; Bertrand prueba ediciones concurrentes en campos distintos.
- **Relacionadas:** AAL-UX-001

### AAL-MAC-016 — Monitores de eventos con teardown en cada salida y sin trabajo por evento

- **Fingerprint:** `appkit/nsevent-monitor/lifecycle-and-throttle`
- **Categoría:** AppKit / ciclo de vida / rendimiento
- **Plataformas:** macOS 14+
- **Proyecto fuente / fechas:** NewProject (`APP-NPR-003`, 2026-09-02), Todocky (`APP-TODOPRO-018`, 2026-08-28, implemented-unverified); cosechado 2026-10-05
- **Owner / status:** Woz + Bertrand / `conditional`
- **Síntoma:** la grabación de un shortcut sigue capturando teclas al cambiar de pane; 101% de CPU y Energy Impact "Very High" al arrastrar una tarjeta.
- **Reproducción/evidencia:** el monitor solo se retiraba en `deinit` y cambiar de pane no desmonta el modelo; un monitor y `dropUpdated` mutaban cursor/layout en cada evento sin comparar con el estado actual.
- **Hipótesis/causa raíz:** teardown confirmado; throttle con prueba de CPU en vivo (pico 24%, media 2%), falta drag físico del propietario.
- **Garantía de plataforma/fuente:** `NSEvent.addLocalMonitorForEvents` devuelve un token que hay que pasar a `removeMonitor(_:)`.
- **Workaround:** —
- **Solución durable:** todo `NSEvent` monitor u observer de C API se retira en cada salida del modo que lo instala (cancel, save, cambio de vista o pane, cierre de ventana); `deinit` es solo red de seguridad; en gestos continuos comparar estado deseado vs actual antes de mutar y throttlear por distancia o tiempo el trabajo caro.
- **Verificación:** NewProject: regresión de cambio de pane; Todocky: muestreo de CPU durante drag simulado.
- **Prevención:** Bertrand mide CPU durante drag/resize en apps macOS.
- **Relacionadas:** AAL-MAC-017

## Mitos corregidos

### AAL-MAC-003 — `contentTintColor` y template images

- **Fingerprint:** `nsbutton/contenttintcolor-template-image-myth`
- **Categoría:** AppKit / menu bar appearance
- **Plataformas:** macOS; observado en New PROject; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `deprecated`
- **Síntoma:** un ícono muestra un tinte distinto al esperado.
- **Reproducción/evidencia:** la explicación retirada decía que AppKit ignora `contentTintColor` en imágenes template.
- **Hipótesis/causa raíz:** **falsa**; [NSButton.contentTintColor](https://developer.apple.com/documentation/appkit/nsbutton/contenttintcolor) sí puede teñir contenido template. El resultado también depende del estado y contexto del botón.
- **Garantía de plataforma/fuente:** usar `nil` conserva el tinte del sistema; un tinte custom debe validarse en estados y apariencias soportados.
- **Workaround:** volver a `nil` para comportamiento del sistema.
- **Solución durable:** decidir template/system tint versus color de marca y probar normal, selected, disabled, Light/Dark y accesibilidad.
- **Verificación:** matriz visual sobre el `NSButton` real del status item.
- **Prevención:** no rasterizar manualmente ni cambiar `isTemplate` basándose en el mito.
- **Relacionadas:** AAL-MAC-001, AAL-MAC-002

### AAL-MAC-005 — La opacidad 0.4 no es un requisito de Liquid Glass

- **Fingerprint:** `materials/black-overlay-0.4-myth`
- **Categoría:** Visual design / materials / accessibility
- **Plataformas:** macOS 26 observado; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Jonny / `deprecated`
- **Síntoma:** el material toma demasiado color del fondo o pierde legibilidad.
- **Reproducción/evidencia:** `Color.black.opacity(0.4)` funcionó como calibración en New PROject; no demuestra que sea obligatorio ni universal.
- **Hipótesis/causa raíz:** **falsa** como regla global; material, tint, contenido, wallpaper y ajustes de accesibilidad cambian el resultado.
- **Garantía de plataforma/fuente:** diseñar materiales según [Apple HIG — Materials](https://developer.apple.com/design/human-interface-guidelines/materials).
- **Workaround:** overlay/tint local medido si el contraste lo exige.
- **Solución durable:** Jonny define tokens por superficie y Woz implementa ramas para Reduce Transparency/Increase Contrast cuando aplique.
- **Verificación:** wallpapers claros/oscuros/coloridos, Light/Dark, accesibilidad y contraste del contenido.
- **Prevención:** conservar números visuales como calibración del proyecto, no defaults globales.
- **Relacionadas:** AAL-MAC-004

### AAL-MAC-011 — El `anchorPoint` predeterminado es `(0.5, 0.5)`

- **Fingerprint:** `calayer/anchorpoint-default-myth`
- **Categoría:** Core Animation / geometry
- **Plataformas:** Apple platforms; observado en macOS; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `deprecated`
- **Síntoma:** una escala parece originarse en una esquina o desplaza el layer.
- **Reproducción/evidencia:** la explicación retirada atribuía a AppKit un default `(0, 0)`.
- **Hipótesis/causa raíz:** **falsa**; el default documentado es `(0.5, 0.5)`. La geometría observada puede venir de `geometryFlipped`, bounds, position, transform o cambios previos.
- **Garantía de plataforma/fuente:** [CALayer.anchorPoint](https://developer.apple.com/documentation/quartzcore/calayer/anchorpoint).
- **Workaround:** inspeccionar `anchorPoint`, `position`, `bounds`, `frame`, transform y superlayer reales antes de modificar.
- **Solución durable:** si se cambia `anchorPoint`, preservar el frame compensando `position`; configurar model layer y animación de forma coherente.
- **Verificación:** snapshots de geometría antes/después y animación desde la posición esperada.
- **Prevención:** no reasignar el anchor point por rutina.
- **Relacionadas:** AAL-MAC-009

### AAL-MAC-013 — `@Bindable` local no copia una clase `@Observable`

- **Fingerprint:** `observation/bindable-local-copy-myth`
- **Categoría:** SwiftUI / Observation
- **Plataformas:** Apple platforms con Observation; observado en macOS; Xcode/SDK: no registrado
- **Proyecto fuente / fechas:** New PROject; first seen 2026-08-04; last verified 2026-08-04
- **Owner / status:** Woz / `deprecated`
- **Síntoma:** cambios parecen no propagarse desde una vista que obtiene un modelo del environment.
- **Reproducción/evidencia:** la explicación retirada afirmaba que `@Bindable var store = store` dentro de `body` copia el store.
- **Hipótesis/causa raíz:** **falsa** para una clase observable: es el patrón oficial para obtener bindings; no crea otra identidad de referencia.
- **Garantía de plataforma/fuente:** [Bindable](https://developer.apple.com/documentation/swiftui/bindable) y [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app).
- **Workaround:** comprobar identidad, reinicialización del hosting root, shadowing e inyección del environment.
- **Solución durable:** conservar el patrón `@Bindable` cuando se necesiten proyecciones `$`; corregir la propiedad/inyección que realmente duplica o reemplaza el modelo.
- **Verificación:** registrar identidad no sensible en tests y confirmar edición bidireccional desde ventanas independientes.
- **Prevención:** revisar composición de raíces antes de culpar al property wrapper.
- **Relacionadas:** AAL-MAC-007

## Gobernanza de esta base

- App Master promueve desde `PROJECT_LEARNINGS.md`, feedback o evidencia aportada solo si existe reproducción/evidencia, fix verificado, alcance/versiones, generalización razonable, owner, fecha y fuente primaria cuando se afirma conducta de Apple o una API.
- No se promueve `hypothesis`. Una entrada puede ser `conditional` si distingue claramente evidencia, condiciones y límites.
- Dedupe por ID estable y fingerprint. Un hallazgo existente se actualiza; no se crea un duplicado por proyecto.
- Nunca se borra historia. Una práctica reemplazada pasa a `deprecated` e indica la entrada sucesora o corrección.
- Los números de color, timing, opacidad y geometría de una app son calibración local salvo evidencia de que son un requisito de plataforma.
- Revalidar entradas cuando cambien plataforma, OS, Xcode, SDK o contrato de una API.
