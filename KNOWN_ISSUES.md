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
| AAL-TEST-001 | verified | Testing/codecs | Fixtures válidos y `#require` evitan traps del host de pruebas |

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
