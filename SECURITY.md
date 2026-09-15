# SECURITY.md — Fintrol

> Fase: PLAN (pre-código para el cambio descrito abajo). Autor: Ivan (Security Architect). Basado en PRD v1.1 y TRD (ambos fechados 2026-09-15).
> Fecha de esta entrada: 2026-09-15. Ninguna fuente externa cambia con frecuencia suficiente para requerir reverificación diaria; las que sí se citan con fecha de consulta explícita más abajo.
> Este documento fija los controles que Woz debe implementar. La verificación de que se implementaron correctamente vive en `SECURITY_AUDIT.md` (Pase 2, después de que exista código y un archive).
>
> **Actualización 2026-09-15 (mismo día, cambio de alcance ordenado por Steve):** el tipo de cambio deja de venir de Frankfurter (sin auth) y pasa a **Banxico SIE** (`www.banxico.org.mx`), que exige un token personal (`Bmx-Token`) pegado por el usuario en Ajustes. Esto introduce la **primera credencial de la app** — invalida la afirmación anterior de "no existe ningún secreto que custodiar" en §3 y §6.1. Solo se tocan las secciones afectadas: §1 (fuente), §2 (diagrama), §3 (activos), §4 (integración), §5 (entitlements — Keychain ahora permitido), §6.1 (secretos, deja de ser N/A), §6.4 (nuevo control **C-12**), §7.4 (abuse cases nuevos), §9 y el resumen para Woz. Frankfurter queda retirado de todo el documento; el resto de §1-§9 no cambia.

---

## 1. Scope, versión y fecha de fuentes

- **Apps cubiertas:** Fintrol (iOS 26 + macOS 26, target único SwiftUI). `Apps/PatternLibrary` es un proyecto distinto del mismo repo y no está en scope de este documento.
- **Tier de seguridad:** Tier 2 — datos financieros personales, sin auth, sin backend propio, una integración externa sin credenciales, distribución no pública (TestFlight / instalación directa, sin App Store en v1).
- **Estado del código:** no existe todavía. `find Apps/` confirma que solo `PatternLibrary` está creado; Fintrol arranca desde cero según el Setup inicial del TRD. Este documento es el gate de Pase 1 antes de que Woz cree el proyecto.
- **Fuentes primarias consultadas hoy (2026-09-15):**
  - Apple, *App Sandbox*, *Preventing Insecure Network Connections (ATS)*, *Keychain Services*, *Privacy manifest files* — usadas como baseline de plataforma, no releídas línea por línea hoy porque no cambian por versión menor sin anuncio; si Woz encuentra comportamiento distinto al aquí descrito durante implementación, revalidar contra `developer.apple.com` antes de asumir que este documento tiene razón.
  - ~~`api.frankfurter.app`~~ — retirado 2026-09-15, ver actualización arriba.
  - **Banxico, Sistema de Información Económica (SIE) API** (`https://www.banxico.org.mx/SieAPIRest/service/v1/`) — API oficial del banco central de México. Requiere un **token personal** que el usuario solicita gratis en el sitio de Banxico y pega en la app; se envía como header HTTP `Bmx-Token`. No consultada línea por línea hoy contra `banxico.org.mx` con fecha explícita porque el cambio de alcance llegó por instrucción directa de Steve con el contrato del header ya especificado (`Bmx-Token`); **Woz debe confirmar contra la documentación oficial de Banxico SIE antes de implementar** el endpoint exacto (serie USD/MXN — habitualmente `SF43718` o equivalente vigente), el shape de la respuesta JSON, y los códigos de error documentados (401/403 por token inválido, formato de "N/E" para "No disponible"/dato faltante) — si algo no coincide con lo asumido aquí, Woz vuelve a Ivan antes de continuar, no improvisa el contrato.
  - OWASP MASVS (baseline móvil, sin baseline oficial de Apple equivalente para "cliente con un solo secreto de usuario, sin login" — se extrapola con cautela, declarado aquí). Guía de Keychain: Apple, *Keychain Services* / `kSecAttrAccessible*` — usada como baseline de plataforma, no releída línea por línea hoy por el mismo criterio de §1 original.

---

## 2. Diagrama / tabla de data flow y trust boundaries

```
┌─────────────────────────────┐
│  Usuario (dueño del dispositivo) │
└──────────────┬───────────────┘
               │ interactúa directo, sin login
               ▼
┌─────────────────────────────────────────┐
│  Fintrol (iOS / macOS, un solo target)   │
│                                           │
│  Core/Engine (puro, sin red, sin I/O)    │
│  Core/Models (@Model SwiftData)          │
│  Services/ExchangeRateService (actor)    │
│  Keychain (Bmx-Token del usuario)        │
└───┬───────────────────┬──────────────┬───┘
    │ HTTPS GET          │ SwiftData ⇄  │ Keychain API
    │ header Bmx-Token    │ CloudKit    │ (local, sin red)
    ▼                     ▼              ▼
┌────────────────────┐ ┌──────────────────┐ ┌───────────────┐
│ www.banxico.org.mx  │ │ iCloud privado    │ │ Keychain local │
│ SIE API (tercero,   │ │ del usuario       │ │ (no sincroniza │
│ no confiable como   │ │ (Apple, mismo     │ │ vía iCloud —   │
│ fuente de verdad —  │ │ Apple ID; frontera│ │ atado a este   │
│ solo informativo;   │ │ = cuenta iCloud)  │ │ dispositivo)   │
│ requiere Bmx-Token)  │ │                   │ │                │
└────────────────────┘ └──────────────────┘ └───────────────┘
```

**Fronteras de confianza:**

1. **Usuario ↔ App:** sin autenticación de app por defecto — cualquiera con el dispositivo desbloqueado tiene acceso completo. Esta frontera la protege el sistema operativo (passcode/Face ID/Touch ID del dispositivo) y, opcionalmente, C-11. El `Bmx-Token` que el usuario pega en Ajustes es la **primera credencial real** de la app (ver §6.1, C-12) — se trata con la misma disciplina que cualquier secreto, aunque el resto de la app siga sin auth de usuario.
2. **App ↔ Banxico SIE:** frontera de red pública, **con credencial saliente** (`Bmx-Token` en header). La respuesta es dato **no confiable** — se trata como input externo, nunca como fuente de verdad si no matchea el shape esperado (C-04/C-12). El token en sí nunca debe salir de este canal hacia ningún otro destino.
3. **App ↔ Keychain local:** frontera nueva. El `Bmx-Token` vive solo aquí, nunca en SwiftData/CloudKit/`UserDefaults`/logs. Ver C-12.
4. **App ↔ CloudKit privado:** frontera gestionada por Apple. El dato en tránsito y en reposo en el servidor de CloudKit está bajo el modelo de responsabilidad compartida de Apple (ver §7); la app no añade cifrado de campo adicional en v1 (decisión TRD, Ivan concurre — ver §7.3). **El token nunca cruza esta frontera** — no es un `@Model`, no sincroniza entre dispositivos vía CloudKit (ver decisión de Keychain sin iCloud sync en §5/§6.1).
5. **App ↔ Almacenamiento local (SwiftData store en disco):** frontera física — protegida por Data Protection (iOS) y por FileVault (macOS, fuera del control de la app).
6. **App ↔ Otros procesos del mismo dispositivo:** pasteboard, App Switcher snapshot, logs de sistema, crash reports — superficies de fuga incidental, no de intrusión activa. El campo del token en Ajustes es `SecureField` precisamente para reducir exposición en snapshots (ver C-12).

No hay frontera de "otro usuario" ni de "otro tenant": es explícitamente una app de un solo usuario, sin cuentas, sin compartir (PRD, decisión registrada 2026-09-15).

---

## 3. Activos, actores y superficie de ataque

### Activos (por sensibilidad)

| Activo | Sensibilidad | Dónde vive |
|---|---|---|
| Montos de `LineItem` (ingresos/egresos individuales) | Alta — dato financiero personal identificable al dueño | SwiftData local + CloudKit privado |
| `RecurringItem` (sueldo WALO, renta, préstamos Upstart, "Ada") | Alta — revela ingresos fijos, deudas activas y a quién le presta dinero el usuario | SwiftData local + CloudKit privado |
| `Subscription` (servicios, tarjeta de pago asociada como texto libre) | Media-Alta — el campo `card` es texto libre; si el usuario escribe ahí los últimos 4 dígitos de una tarjeta real, eleva la sensibilidad del campo sin que el modelo lo distinga | SwiftData local + CloudKit privado |
| `ExchangeRateCache.rate` | Baja — dato público de mercado, no identifica al usuario | SwiftData local + CloudKit privado |
| Sobrante calculado / "Mandar" | Alta — es el resumen financiero más legible de toda la app | Derivado en memoria, nunca persistido aparte |
| Identidad Apple ID / cuenta iCloud | Alta pero **fuera del control de la app** — la gestiona el sistema | Sistema operativo |
| **`Bmx-Token` (credencial personal de Banxico SIE)** | **Alta** — es una credencial de acceso a una API de un tercero a nombre del usuario; su robo no expone datos financieros de Fintrol directamente, pero sí permite a un atacante consumir la cuota del usuario en Banxico y potencialmente correlacionar su uso; se trata con la disciplina de "cualquier secreto", no con la de "cualquier dato del usuario" | **Keychain únicamente** (ver C-12) — nunca SwiftData, nunca CloudKit, nunca `UserDefaults`, nunca logs |

**Actualización 2026-09-15:** ya no aplica "no existe ningún secreto que custodiar" — el `Bmx-Token` es la primera credencial de la app. Ver §6.1 y control **C-12** en §6.4 para su ciclo de vida completo.

### Actores

- **Usuario dueño** — único actor legítimo, sin roles ni permisos diferenciados.
- **Atacante con acceso físico al dispositivo desbloqueado o con biométrico engañado** — fuera del control de la app; mitigación vive en el OS.
- **Atacante con acceso a un backup no cifrado o a un dispositivo con Data Protection/FileVault deshabilitado** — riesgo residual documentado en §7.
- **Atacante en la red (rogue Wi-Fi / MITM)** — puede intentar interceptar o falsificar la respuesta de Frankfurter. No puede leer CloudKit (TLS de Apple) ni inyectarse en la sesión CloudKit del usuario sin comprometer la cuenta Apple ID misma (fuera de scope de la app).
- **Frankfurter comprometido o con contrato cambiado** — riesgo de integridad de un solo campo numérico (`rate`), no de ejecución de código ni de persistencia de payload malicioso si el parseo es defensivo (ver §6.4 y control C-04).
- **Apple (CloudKit, responsabilidad compartida)** — no es un actor hostil, pero es un actor con acceso técnico potencial a datos en su infraestructura bajo su propio modelo de cifrado; se documenta como riesgo aceptado en §7.3, no como amenaza a mitigar con ingeniería del cliente.

### Superficie de ataque (enumeración explícita pedida por Avie)

| Superficie | ¿En scope v1? | Notas |
|---|---|---|
| Red saliente (Frankfurter) | Sí | Única llamada de red de toda la app. GET sin parámetros de usuario. |
| CloudKit privado | Sí | Sync automático, sin `CKContainer` manual. |
| Almacenamiento local (SwiftData store) | Sí | Data Protection por defecto — ver §7.1. |
| Backups (iCloud device backup, Time Machine en Mac) | Sí, informativo | Mismo nivel de protección que el store; no hay mitigación adicional de la app. |
| Mac sin Data Protection equivalente a iOS | Sí | FileVault es responsabilidad del usuario, no de la app — ver §7.2. |
| Logs / `os_log` / consola de Xcode | Sí | Control C-05: nunca loguear montos ni contenido de `LineItem`/`RecurringItem` en claro. |
| Crash reports / MetricKit | Sí, preventivo | No hay integración de crash reporting de terceros en v1 (TRD no la menciona); si se añade en el futuro, revisar antes de shippearla. |
| Capturas de pantalla / App Switcher snapshot | Sí | Control C-06 (recomendado, no bloqueante v1) — ver §7.4. |
| Clipboard / pasteboard | Marginal | PRD no define ninguna acción de "copiar" explícita en v1. N/A por ahora — si Jonny/Woz añaden copiar-monto, revisar entonces. |
| Widgets | No en v1 | PRD no lo incluye ni en MVP ni en fases futuras explícitas. Nota forward-looking en §9. |
| Deep links / URL schemes / universal links | No en v1 | PRD no define ninguno. N/A. |
| Extensiones, App Groups, helpers, XPC | No en v1 | TRD confirma que no hay ninguno en este diseño. |

---

## 4. Integraciones, scopes, credenciales y endpoints

| Integración | Endpoint | Auth | Datos que salen | Datos que entran | Confiable como fuente de verdad? |
|---|---|---|---|---|---|
| ~~Frankfurter~~ | ~~`GET https://api.frankfurter.app/latest?from=USD&to=MXN`~~ | — | — | — | **Retirado 2026-09-15** — reemplazado por Banxico SIE. Ningún código nuevo debe referenciar `frankfurter.app`. |
| **Banxico SIE** | `GET https://www.banxico.org.mx/SieAPIRest/service/v1/series/<serie>/datos/oportuno` (Woz confirma la serie exacta contra la doc oficial antes de codificar — ver §1) | **Header `Bmx-Token: <token del usuario>`** — token personal, gratuito, propio de cada usuario, no un secreto de la app | El token en el header de cada request; nada más identificable al usuario (sin PII adicional, sin cookies) | JSON con la serie de tipo de cambio; Banxico documenta `"N/E"` (No Existe/No disponible) como valor de dato faltante en vez de un número — debe tratarse como ausencia de dato, no como `0` | **No** — tratado como input no confiable igual que Frankfurter; ver control **C-12** (reemplaza y extiende C-04 para esta integración) |

No hay OAuth, OIDC, Sign in with Apple, App Attest, DeviceCheck, APNs, WeatherKit ni Toggl en este proyecto. Las secciones correspondientes de mi checklist estándar (Google/OAuth, Toggl, APIs Apple con `.p8`) son **N/A explícito** — no hay ninguna de esas integraciones en el TRD. Banxico SIE tampoco es ninguna de ellas: es autenticación por token estático en header, sin flujo OAuth, sin expiración documentada por defecto — pero **sigue siendo una credencial de usuario** y se custodia como tal (C-12), no como un API key hardcodeado de la app (que sí estaría prohibido por mis reglas estándar — este no lo está porque es el usuario quien lo provee y lo posee, no un secreto de backend distribuido en el binario).

---

## 5. Entitlements, TCC, App Groups, helpers y distribución

### Entitlements exactos permitidos (Woz no debe agregar ninguno fuera de esta lista sin volver a Ivan)

**Actualización 2026-09-15 — decisión de almacenamiento del `Bmx-Token`:** Keychain **sí queda permitido** a partir de ahora, exclusivamente para este token. Decisión:

- API: `Security` framework (`SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate`/`SecItemDelete`), clase `kSecClassGenericPassword`, `kSecAttrService` propio de la app (ej. `"mx.fintrol.banxico-token"`), sin `kSecAttrAccessGroup` explícito (usa el access group default de la app — no hay que compartir el token con ninguna extensión ni helper, no hay ninguno en este proyecto).
- **Accesibilidad: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.** No `WhenUnlocked` (el refresh de tipo de cambio puede correr en background/tras reinicio antes de que el usuario abra la app, igual que hoy con Frankfurter) y no `...ThisDeviceOnly` omitido — **explícitamente sin sync a iCloud Keychain**: el token es una credencial personal ligada a un dispositivo por decisión de este documento, no un dato que deba propagarse solo porque el usuario tiene el mismo Apple ID en otro dispositivo. Si el usuario instala Fintrol en un segundo dispositivo, vuelve a pegar el token ahí — fricción mínima y aceptable, y evita que un vector de sync de iCloud Keychain (fuera del control directo de la app) se convierta en una superficie nueva para este secreto. **Si Jonny/Steve prefieren sync entre dispositivos del propio usuario**, la alternativa es `kSecAttrSynchronizable = true` con `kSecAttrAccessibleAfterFirstUnlock` (sin `ThisDeviceOnly`, que es incompatible con sync) — Ivan no bloquea esa opción si el producto la pide explícitamente, pero el default de este documento es **sin sync**, por ser la superficie más chica.
- **Entitlements que esto implica — ninguno nuevo en macOS App Sandbox.** El acceso a Keychain para los propios items de la app (no compartidos con otro proceso/extensión) **no requiere `keychain-access-groups`** bajo App Sandbox — ese entitlement solo es necesario para compartir un access group entre distintos bundle IDs (app + extensión, app + helper). Fintrol no tiene ninguno de esos. `com.apple.security.app-sandbox = true` (ya presente) es suficiente; Keychain Services funciona dentro del sandbox por defecto para el propio proceso de la app.
- iOS no requiere ningún entitlement adicional para Keychain del propio proceso tampoco (no hay App Groups en este proyecto).

**iOS (`Fintrol.entitlements`):**
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

**macOS (mismo target, App Sandbox obligatorio para distribución fuera de Xcode-run-directo):**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

**Explícitamente prohibidos** (cualquiera de estos en el archive Release es hallazgo Critical en Pase 2):
- `get-task-allow` (debe estar ausente en builds Release/Archive)
- `com.apple.security.network.server`
- `com.apple.security.cs.disable-library-validation`
- `com.apple.security.cs.allow-jit`
- `com.apple.security.cs.allow-unsigned-executable-memory`
- `com.apple.security.cs.allow-dyld-environment-variables`
- `com.apple.security.files.user-selected.read-write` (no hay flujo de import/export de archivos en v1 — PRD lo confirma al excluir importación de histórico)
- `keychain-access-groups` (Keychain del propio proceso para el `Bmx-Token` no lo requiere — ver decisión arriba; este entitlement solo sería necesario si el token se compartiera con una extensión/helper, y no hay ninguno en este proyecto)
- Cualquier App Group (`com.apple.security.application-groups`) — no hay widgets, extensiones ni helpers en v1

### TCC / permisos del sistema

Ninguno. La app no pide cámara, contactos, ubicación, micrófono, fotos, ni Local Network. Si Jonny/Woz descubren que necesitan alguno durante implementación, es una desviación del TRD que debe volver a Ivan antes de agregarse — no se justifica por nada descrito en el PRD actual.

### App Groups, helpers, XPC, extensiones

N/A — no hay ninguno en este diseño (TRD lo confirma explícitamente).

### Distribución

- v1: TestFlight o instalación directa, sin App Store público (PRD). **Pendiente de decisión operativa que Ivan no puede tomar solo:** ¿"instalación directa" significa correr desde Xcode en los propios dispositivos del usuario (dev-signed, sin notarización necesaria), o significa construir un `.app`/`.pkg` de macOS firmado con Developer ID para copiar fuera de Xcode? Esto cambia si Notarización + `notarytool` + stapling entran al scope de Craig antes de la primera build usable. Ver §9 "Decisiones pendientes del usuario".
- Sea cual sea la respuesta, Hardened Runtime en macOS y ausencia de `get-task-allow` en Release aplican igual — no dependen de esa decisión.
- Si en el futuro se abre a App Store (fase no decidida, PRD lo deja explícito), este documento debe revisarse completo: entra `PrivacyInfo.xcprivacy` obligatorio, revisión de purpose strings si se agregan permisos, y el gate completo de `/app-store-ready`.

---

## 6. Lifecycle de datos y secretos

### 6.1 Secretos y credenciales

**Actualización 2026-09-15 — ya no está vacía.** El `Bmx-Token` de Banxico SIE es la primera credencial real de la app.

- **Creación:** el usuario obtiene el token gratis en el sitio de Banxico (fuera de la app) y lo pega en Ajustes → Preferencias.
- **Almacenamiento:** exclusivamente Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, ver §5 para la decisión completa). **Prohibido explícitamente:** `UserDefaults`, cualquier `@Model` de SwiftData (y por tanto CloudKit), archivos en disco propios, logs, analytics o crash reports.
- **Uso:** solo como header `Bmx-Token` en la request HTTPS a `www.banxico.org.mx`. Nunca en query string, nunca en URL, nunca en el cuerpo de un log de red.
- **Expiración/rotación:** Banxico no documenta expiración automática estándar para tokens SIE (Woz confirma contra la doc oficial antes de implementar, ver §1); el usuario puede regenerarlo desde el sitio de Banxico en cualquier momento, lo que invalida el anterior — la app debe manejar el 401/403 resultante como "token inválido", no como crash.
- **Revocación/reemplazo:** el usuario pega un token nuevo en Ajustes, que sobrescribe el item de Keychain existente (`SecItemUpdate`, no acumular items duplicados).
- **Recuperación por incidente:** si el usuario sospecha que su token fue expuesto, la mitigación vive en Banxico (regenerarlo en su sitio), no en Fintrol — la app no tiene forma de revocarlo remotamente porque no es su emisor.
- **Redacción:** cualquier mensaje de error mostrado en Ajustes (ej. "token inválido") **nunca debe interpolar el valor del token**, ni siquiera parcialmente (ni los últimos 4 caracteres) — no hay necesidad de mostrar nada del valor para que el mensaje sea útil.

### 6.2 Datos financieros — minimización y retención

- La app no recolecta nada que el usuario no capture explícitamente. No hay analytics, no hay telemetría, no hay tracking de terceros (PRD no lo menciona, TRD no lo incluye).
- Retención: indefinida mientras el usuario use la app — es presupuesto histórico y proyectado, borrarlo rompería el producto. No hay requisito de purga automática (no aplica LFPDPPP/GDPR de terceros porque es dato del propio dueño sobre sí mismo, no de un tercero — este es un matiz importante: la app no es un producto con usuarios ajenos, es una herramienta personal).
- Eliminación: si el usuario desinstala la app y elimina los datos de iCloud (Ajustes del sistema → iCloud → Fintrol → Eliminar datos), CloudKit privado los borra según el mecanismo estándar de Apple. La app no implementa un "borrar todo" propio en v1 — no está en el PRD. **Nota, no bloqueante:** recomendar a Jonny/Steve evaluar en Fase 2 un botón de exportar/borrar dentro de Ajustes, dado que son datos financieros sensibles y hoy la única vía de borrado es a través de Ajustes del sistema, no descubrible dentro de la app.

### 6.3 Tipo de cambio — ciclo de vida

Ver TRD "Integraciones externas y seguridad" — ya está bien definido: fetch → cache → override manual, en cascada, fail-closed. Ivan no encuentra nada que ajustar en ese diseño; lo convierte en controles verificables en §6.4.

### 6.4 Controles obligatorios que Woz debe implementar

Cada control tiene un ID para referenciar en `SECURITY_AUDIT.md`.

| ID | Control | Criterio de verificación |
|---|---|---|
| **C-01** | ATS activo sin excepciones — sin `NSAllowsArbitraryLoads`, sin `NSExceptionDomains` para `frankfurter.app` ni ningún otro host, en `Info.plist` | Pase 2: `plutil -p Info.plist` del archive no debe contener ninguna clave `NSAppTransportSecurity` con excepciones. Ausencia total de la clave es el estado esperado (ATS default de iOS/macOS 26 ya exige TLS 1.2+). |
| **C-02** | Ningún `URLSessionDelegate` personalizado que evalúe o haga bypass de `serverTrust` / `URLAuthenticationChallenge` | Pase 2: `grep -rn "didReceive challenge\|serverTrust\|NSURLAuthenticationMethodServerTrust" Fintrol/` debe devolver vacío, o si existe, debe delegar al comportamiento default del sistema, nunca `.useCredential` incondicional. |
| **C-03** | Todas las llamadas de red usan `https://` explícito, nunca `http://` | Pase 2: `grep -rn "http://" Fintrol/Services` debe devolver vacío. |
| **C-04** | ~~Parseo de la respuesta de Frankfurter...~~ **Retirado 2026-09-15 — Frankfurter ya no es la fuente.** El principio (parseo defensivo, fail-closed a `ExchangeRateCache`, rango plausible 1–100, nunca `try!`) se conserva íntegro pero migra a Banxico SIE bajo **C-12**, que lo reemplaza y le añade el manejo específico de `"N/E"` y de 401/403 por token inválido. No dejar código muerto referenciando Frankfurter. | N/A — ver C-12 |
| **C-05** | Ningún log (`print`, `os_log`, `Logger`) interpola montos, `rate`, `title` de `LineItem`/`RecurringItem`/`Subscription` en claro fuera de builds Debug. Si un log de diagnóstico necesita referenciar una línea, usa el `id` (`UUID`), nunca el valor. | Pase 2: `grep -rn "print(\|os_log(\|Logger(" Fintrol/Core Fintrol/Services Fintrol/Features` — revisar cada resultado; ninguno debe interpolar `amount`, `rate`, `title`, `.card`. |
| **C-06** (recomendado, no bloqueante v1) | Ocultar/blurrear contenido financiero en el snapshot del App Switcher al pasar a `.background`/`.inactive` | Pase 2: inspección manual — backgrounding la app y revisar el snapshot en el multitasking switcher no debe mostrar montos legibles. Severidad Medium si no está implementado; no bloquea release v1 dado que es dispositivo personal de un solo usuario, pero se registra como riesgo aceptado con owner si se omite. |
| **C-07** | `Decimal` de extremo a extremo para dinero — ya es requisito del TRD; Ivan lo hereda como control de integridad de datos, no solo de precisión: un `Double` en la cadena de conversión de moneda es también un vector de discrepancia silenciosa entre lo que el usuario cree que tiene y lo que la app calculó. | Pase 2: `grep -rn "Double" Fintrol/Core/Engine Fintrol/Core/Models` no debe aparecer en ningún campo de monto/tasa. |
| **C-08** | Entitlements del archive Release coinciden exactamente con §5, sin ninguno fuera de la lista permitida, y sin `get-task-allow` | Pase 2: `codesign -d --entitlements :- <archive Release>` comparado línea por línea contra §5. |
| **C-09** | Hardened Runtime activo en el target macOS, App Sandbox activo en el target macOS | Pase 2: `codesign -d --entitlements :- <archive>` debe mostrar `com.apple.security.app-sandbox = true`; verificar Hardened Runtime en `GetTargetBuildSettings` / build settings del target (`ENABLE_HARDENED_RUNTIME = YES` o el toggle equivalente en Signing & Capabilities). |
| **C-10** | Swift 6 strict concurrency completo (`SWIFT_STRICT_CONCURRENCY = complete`), ya requerido por TRD — Ivan lo trata también como control de seguridad: código de dominio financiero con carreras de datos no detectadas es una fuente de corrupción de estado silenciosa (ej. `CarryOverEngine.recomputeForward` corriendo dos veces concurrentemente sobre la misma `Period`) | Pase 2: `GetTargetBuildSettings` confirma el flag; `RunAllTests` sin warnings de concurrencia suprimidos. |
| **C-11** | Bloqueo biométrico opcional (v1, apagado por defecto, activable en Ajustes). `LAContext.evaluatePolicy(.deviceOwnerAuthentication, ...)` — nunca `.deviceOwnerAuthenticationWithBiometrics` solo, porque debe caer a passcode del dispositivo si Face ID/Touch ID no está disponible o falla. `NSFaceIDUsageDescription` en `Info.plist` con purpose string específico (no genérico). Montos e importes ocultos (placeholder/blur) hasta que `evaluatePolicy` devuelva éxito. Re-bloqueo automático al volver de background/inactive tras N segundos configurables (60s, decisión confirmada de Steve — ver §9 ítem 7). El resultado de la autenticación **no se persiste**: vive solo en memoria del proceso actual (ej. un `@Observable` en `MainActor`, nunca en disco), se resetea a "no autenticado" en cada `scenePhase` a `.background` y en cada cold start. | Pase 2: `grep -rn "LAContext\|LAPolicy" Fintrol/` confirma `.deviceOwnerAuthentication` (no solo biometría); `Info.plist` contiene `NSFaceIDUsageDescription` con texto específico al propósito ("para proteger el acceso a tu presupuesto"), no genérico; inspección manual — backgrounding la app con el lock activado y volviendo tras N segundos exige reautenticación y no muestra montos hasta pasar; `grep -rn "UserDefaults" Fintrol/` no debe contener ninguna clave de tipo `isAuthenticated`/`unlocked`; `grep -rn "Keychain" Fintrol/Features/Settings` no debe usarse para guardar el estado de esta sesión de autenticación (el estado de auth sigue prohibido en Keychain; el `Bmx-Token` de C-12 es el único uso permitido de Keychain en este proyecto). |
| **C-12** *(nuevo, 2026-09-15)* | **Banxico SIE — token, red y parseo defensivo, extremo a extremo.** (a) `Bmx-Token` guardado y leído **solo** vía Keychain con `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (§5/§6.1) — nunca en `UserDefaults`, nunca en un `@Model`/CloudKit, nunca en logs. (b) Toda request a Banxico usa `https://www.banxico.org.mx/...` explícito, sin excepciones de ATS (mismo criterio que C-01/C-03, extendido al nuevo host). (c) Parseo fail-closed igual que el C-04 original: `Decodable`/`JSONSerialization` tipado, cualquier HTTP status ≠ 200 → fallback a `ExchangeRateCache`; el valor `"N/E"` que Banxico documenta para dato faltante se trata como ausencia de dato (fallback a cache), **nunca** como `0` ni se fuerza a `Decimal`; tasa fuera de `ExchangeRateParser.plausibleRange` (1...100, ya definido) sigue rechazándose igual que antes. (d) **401/403 (y también 400 — comprobado contra el servicio real por Woz el 2026-09-15: Banxico responde 400, no solo 401/403, para un `Bmx-Token` inválido) se manejan como caso propio, distinto de "red caída"**: mensaje en Ajustes tipo "Tu token de Banxico no es válido o expiró — revísalo en Ajustes" **sin revelar el token** (ni completo ni parcial) en el mensaje, y sin loguearlo. (e) UI del campo del token en Ajustes → Preferencias: `SecureField` con un control explícito para mostrar/ocultar el valor en texto plano (el usuario controla cuándo se revela, la app no lo expone por defecto), y un botón **"Probar token"** que hace una llamada de verificación contra Banxico y reporta éxito/401/403/error de red sin nunca mostrar el token de vuelta. (f) Ningún rastro de Frankfurter queda en el código (`grep -rn "frankfurter" Fintrol/` debe devolver vacío). | Pase 2: `grep -rn "Keychain\|SecItemAdd\|kSecAttrAccessible" Fintrol/` confirma que el token se guarda con `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` y que ningún `@Model`/`UserDefaults` lo persiste (`grep -rn "Bmx-Token\|bmxToken\|banxicoToken" Fintrol/Core/Models Fintrol/App` debe devolver vacío); `grep -rn "http://" Fintrol/Services` vacío; tests de Bertrand alimentando `"N/E"`, JSON malformado, 401, 403 y rate fuera de rango deben resultar en fallback a cache o mensaje de error sin crash ni fuga del token; inspección manual del campo en Ajustes confirma `SecureField` + toggle mostrar/ocultar + botón "Probar token" funcional; `grep -rin "frankfurter" Fintrol/` vacío. |

---

## 7. Abuse cases, controles, impacto y riesgo residual

### 7.1 Data Protection en iOS — ¿basta el default?

**Pregunta que Avie/TRD delega explícitamente a Ivan.** Respuesta: **sí, basta para v1**, con matiz.

- SwiftData con CloudKit usa por default `NSFileProtectionCompleteUntilFirstUserAuthentication` (clase de protección estándar de cualquier store en un dispositivo con passcode — es la misma clase que usa Mail y la mayoría de apps del sistema). El archivo del store es ilegible sin desbloquear el dispositivo al menos una vez tras reinicio.
- No se requiere `NSFileProtectionComplete` (protección total, ilegible incluso con dispositivo desbloqueado en background) porque el producto necesita leer/escribir en background para refrescar tipo de cambio y responder a sync de CloudKit sin fricción — subir a `.complete` es una fricción real (la app no podría operar en background) por un beneficio marginal dado que el threat model es "dispositivo perdido/robado bloqueado", que `UntilFirstUserAuthentication` ya cubre razonablemente.
- **Riesgo residual aceptado:** un atacante con el dispositivo desbloqueado (por biométrico engañado, coacción, o robo mientras está desbloqueado) lee todo sin fricción adicional de la app — porque no hay auth de app. Esto es consistente con la decisión de producto "sin auth" del PRD; Ivan no puede revertir esa decisión de producto, pero la documenta como riesgo aceptado explícito (ver §9) y recomienda, no bloquea, evaluar un lock biométrico opcional a nivel app en Fase 2.

### 7.2 Mac sin Data Protection equivalente

- macOS no tiene un equivalente exacto a las clases de Data Protection de iOS. La protección real en reposo depende de **FileVault**, que es una decisión y configuración del usuario a nivel de sistema, no algo que la app pueda forzar programáticamente sin MDM.
- **Control:** ninguno a nivel de código — esto es una limitación de plataforma, no un defecto de diseño de Fintrol.
- **Riesgo residual aceptado, con mitigación documental:** recomendar al usuario (fuera del código, en README o onboarding si Jonny lo decide) que tenga FileVault activo en el Mac donde corra Fintrol. No es bloqueante porque es exactamente la misma postura que cualquier app nativa de Apple (Notas, Mail) en macOS — no hay una barra más alta razonable que exigirle a esta app específicamente.

### 7.3 CloudKit privado — ¿requiere cifrado de campo adicional?

- **No para v1.** CloudKit cifra en tránsito (TLS) y en reposo en la infraestructura de Apple bajo su propio modelo; el contenedor es privado (solo la cuenta iCloud del usuario tiene acceso), sin compartir, sin `CKShare`.
- **Riesgo residual aceptado y explícito:** Apple, bajo su propio modelo de custodia de claves de CloudKit y bajo proceso legal (ej. una solicitud de autoridad), tiene una vía técnica potencial de acceso a datos en reposo en el contenedor privado del usuario, dependiendo de si el usuario tiene Advanced Data Protection para iCloud activado a nivel de cuenta (una configuración del propio usuario en su Apple ID, fuera del control de la app). Fintrol no implementa cifrado de campo con CryptoKit encima de CloudKit para v1 — sería trabajo real (gestión de clave derivada del passcode/biométrico, UX de recuperación si se pierde la clave) desproporcionado para Tier 2 personal, y el propio TRD ya tomó esta decisión; Ivan concurre explícitamente.
- **Recomendación no bloqueante:** documentar en README o en Ajustes de la app una nota sugiriendo al usuario activar Advanced Data Protection en su cuenta de iCloud si quiere el nivel más alto de cifrado end-to-end que Apple ofrece — es gratis, es una decisión de cuenta, no de código, y sube el piso de este riesgo aceptado sin que Woz escriba una línea.

### 7.4 Abuse cases — tabla completa

| Abuse case | Probabilidad | Impacto | Mitigación | Riesgo residual |
|---|---|---|---|---|
| MITM en red pública inyecta JSON malformado/malicioso en la respuesta de Banxico SIE | Media (redes públicas son comunes) | Bajo — un solo campo numérico (`rate`) mal calculado si el parseo no fuera defensivo; C-12 lo reduce a "usa cache" | ATS (C-01) + parseo defensivo fail-closed (C-12) | Bajo — el peor caso con controles aplicados es una tasa desactualizada, no corrupción de datos ni crash |
| Banxico cambia de contrato de API sin aviso (nuevo shape de JSON, nueva serie) | Media a largo plazo (dependencia de un tercero) | Bajo | C-12 (fallback a cache ante `Decodable` fallido) | Bajo — degradación elegante, mismo patrón que el diseño original con Frankfurter |
| **`Bmx-Token` filtrado vía log, crash report, screenshot del campo de Ajustes, o backup no cifrado** | Baja si C-12/C-05 se cumplen; media si algún log de red se activa sin redactar headers | Medio — el atacante puede consumir la cuota de Banxico del usuario y correlacionar su uso; no expone directamente los datos financieros de Fintrol (esos siguen en SwiftData/CloudKit, no en el token) | Keychain-only (C-12), `SecureField` con reveal opt-in, C-05 extendido a nunca loguear headers de request, sin token en `@Model`/`UserDefaults` | Bajo si todos los controles se cumplen; el usuario puede regenerar el token en Banxico si sospecha exposición (mitigación fuera del control de la app) |
| Usuario pega un `Bmx-Token` inválido/expirado o de otra API por error | Media (typo, copiar mal, token vencido) | Bajo — falla de UX, no de seguridad | C-12(d): manejo explícito de 401/403 con mensaje claro sin revelar el token; botón "Probar token" permite verificar antes de guardar | Bajo — degrada a "sin tipo de cambio nuevo", igual que cualquier otro fallo de red ya cubierto por el diseño de cache |
| Atacante con dispositivo desbloqueado lee/edita datos financieros | Baja en uso normal (dispositivo personal), pero impacto alto si ocurre | Alto — expone sueldo, deudas, a quién le presta dinero el usuario | C-11 (bloqueo biométrico opcional, apagado por defecto) si el usuario lo activa en Ajustes; si permanece apagado, mitigación sigue siendo 100% del OS (passcode/biométrico del dispositivo) | Bajo si el usuario activa C-11; aceptado (sin control adicional) si lo deja apagado — es su elección explícita en Ajustes, no un default inseguro silencioso |
| Backup no cifrado o dispositivo con FileVault apagado expone el store en reposo | Baja (requiere configuración insegura del usuario) | Alto | Data Protection default (iOS) / recomendación de FileVault (macOS) | Aceptado — límite de plataforma, no de la app |
| App Switcher snapshot muestra montos en claro a quien mire por encima del hombro | Media (uso cotidiano en público) | Medio | C-06 (recomendado, no implementado en v1 a menos que Woz lo priorice) | Medio, aceptado si C-06 no se implementa — requiere owner y fecha si se pospone (ver gate de release) |
| Crash report o log de sistema expone un monto o el nombre de un `RecurringItem` ("préstamo Upstart $629") | Baja | Medio | C-05 | Bajo si C-05 se cumple |
| Confused deputy / SSRF | N/A | N/A | No aplica — no hay backend propio que reciba URLs de terceros ni haga fetch en nombre de otro sistema | N/A |
| Replay de request a Frankfurter | N/A | N/A | GET idempotente sin estado ni side-effects en el servidor; no hay nada que "repetir" con efecto malicioso | N/A |

---

## 8. Logging, monitoring e incident response

- **No hay analytics ni crash reporting de terceros en v1** (ni TRD ni PRD lo mencionan). Si se agrega en el futuro (ej. Xcode Organizer / MetricKit para crash reports propios de Apple), antes de activarlo Woz debe confirmar que no captura contenido de `LineItem`/`RecurringItem` — MetricKit y crash reports de Apple no acceden a datos de la app por diseño, pero cualquier log custom que la app emita sí podría filtrarse ahí si C-05 no se respeta.
- **Monitoring:** no aplica — no hay backend propio que monitorear. La única "disponibilidad" externa es Frankfurter, cuya caída ya está mitigada por diseño (cache + override).
- **Incident response:** si el usuario sospecha que su Apple ID fue comprometido, el incidente relevante es a nivel de cuenta Apple (fuera del scope de Fintrol) — recomendar los pasos estándar de Apple (cambiar contraseña de Apple ID, revisar dispositivos confiables, activar Advanced Data Protection). Fintrol no tiene su propio canal de "reportar incidente" porque no hay backend ni soporte multiusuario que lo justifique.
- **Rotación:** no aplica — no hay secretos que rotar.

---

## 9. Riesgos aceptados con owner y expiración / Decisiones pendientes del usuario

| # | Ítem | Tipo | Owner | Estado |
|---|---|---|---|---|
| 1 | ~~Sin auth/lock biométrico a nivel app~~ — **Resuelto:** el usuario aceptó la recomendación de Ivan. Bloqueo biométrico opcional (Face ID/Touch ID/passcode vía `LocalAuthentication`) entra en v1 como control **C-11** (§6.4), apagado por defecto, activable en Ajustes. Riesgo residual: mientras esté apagado (default), sigue aplicando el mismo riesgo aceptado original — es responsabilidad del usuario activarlo. | Control implementado, no riesgo aceptado abierto | Woz implementa, Ivan verifica en Pase 2 | Ver C-11 |
| 2 | Sin cifrado de campo adicional sobre CloudKit (más allá del cifrado propio de Apple) | Riesgo aceptado, decisión conjunta TRD + Ivan | Avie / Ivan | Aceptado para v1. Sin fecha de expiración — es proporcional al tier mientras siga siendo app de un solo usuario sin distribución comercial. |
| 3 | Data Protection en Mac depende de que el usuario tenga FileVault activo | Límite de plataforma, no de la app | Usuario | Documental, no bloqueante. |
| 4 | C-06 (blur de App Switcher) recomendado pero no obligatorio para v1 | Riesgo aceptado si se omite | Woz, a definir fecha si se pospone | Medium — requiere que Woz confirme en `SECURITY_AUDIT.md` si lo implementó o lo pospuso con fecha. |
| 5 | **Decisión pendiente del usuario, no de Ivan:** ¿"instalación directa" en v1 significa correr desde Xcode en los propios dispositivos (sin notarización), o construir un `.app`/`.pkg` de macOS firmado Developer ID para instalar fuera de Xcode? Esto determina si Craig necesita meter notarización (`notarytool`, stapling) al pipeline antes de la primera build usable fuera de una máquina de desarrollo. | Decisión operativa | Usuario / Craig | **Bloquea la fase de distribución, no la fase de implementación de Woz** — Woz puede construir las pantallas sin esperar esta respuesta. |
| 6 | Nota forward-looking: si en cualquier fase futura se agregan widgets, deep links, extensiones o un segundo dispositivo/cuenta, este documento debe revisarse completo antes de implementarlos — ninguno de esos está cubierto aquí porque ninguno está en el PRD actual. | Nota, no riesgo activo | Ivan (en la siguiente revisión que los introduzca) | N/A hoy |
| 7 | **Decisión confirmada (Steve):** el umbral de re-bloqueo biométrico queda en 60s (`BiometricLockStore.reauthenticationThreshold`), no en el default "corto" (≤30s) que este documento sugería originalmente en C-11. SECURITY_AUDIT.md L-02 pedía que quedara registrado como decisión explícita, no como default implícito de Woz. | Decisión de producto confirmada | Steve | Cerrado — no riesgo aceptado abierto, es el valor final. |
| 8 | `ENABLE_ENHANCED_SECURITY: YES` (SECURITY_AUDIT.md M-02) — **corrección 2026-09-15 (recheck de Ivan):** el setting está actualmente **comentado/apagado** en `project.yml` (`ENABLE_ENHANCED_SECURITY = NO` confirmado en build settings evaluados), no activado como decía una versión anterior de este ítem. Se revirtió porque fuerza `ARCHS=arm64e` y el paquete local `Packages/AppleAppLabUI` no lo hereda, rompiendo el link (`PROJECT_LEARNINGS.md` FIN-2026-004). Mitigación identificada y pendiente de probar: flags `macOSPackagesShouldBuildARM64e`/`iOSPackagesShouldBuildARM64e` en `WorkspaceSettings.xcsettings` (ver `SECURITY_AUDIT.md`, sección RECHECK, M-02). | Riesgo aceptado temporalmente — setting apagado, mitigación de workspace pendiente de probar | Woz | Antes del primer archive Release; no bloquea el desarrollo en Simulator/Mac. |
| 9 | **Nuevo 2026-09-15 — cambio de proveedor de tipo de cambio.** El tipo de cambio pasa de Frankfurter (sin auth) a Banxico SIE (requiere `Bmx-Token` del usuario). Primera credencial de la app; almacenamiento decidido en Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, sin sync a iCloud Keychain) — ver §5, §6.1 y control **C-12**. No es un riesgo aceptado sino una decisión de arquitectura de seguridad tomada en esta misma entrada; Woz implementa, Ivan verifica C-12 en el próximo Pase 2. | Decisión de seguridad, no riesgo aceptado abierto | Ivan (decisión) / Woz (implementación) | Ver C-12 — verificación en el próximo recheck de `SECURITY_AUDIT.md` |

---

## Resumen para Woz (accionable, sin ambigüedad)

1. Entitlements: usar exactamente la lista de §5, en ambas plataformas. Nada más.
2. `Info.plist`: sin ninguna clave `NSAppTransportSecurity`.
3. `ExchangeRateService`: parseo defensivo obligatorio (C-04), `Decimal` de extremo a extremo (C-07), sin `try!`.
4. Cero `print`/`os_log`/`Logger` con montos, tasas o títulos de línea en claro (C-05).
5. macOS: App Sandbox + Hardened Runtime activos desde el primer commit del proyecto (C-08, C-09).
6. Swift 6 strict concurrency completo desde el día 1 (C-10) — ya es requisito del TRD, Ivan lo confirma también como control de seguridad.
7. C-06 (blur de App Switcher) es recomendado; si se pospone, avisar explícitamente para registrarlo con owner/fecha en el gate de release.
8. No agregar App Groups, permisos TCC, deep links ni un tercer proveedor de red sin volver a Ivan primero — ninguno está justificado por el PRD/TRD actuales. **Keychain ya no está prohibido** (ver punto 10) pero solo para el `Bmx-Token` — no lo uses para nada más sin volver a Ivan.
9. Bloqueo biométrico (C-11): `LAContext` con `.deviceOwnerAuthentication` (nunca solo biometría), `NSFaceIDUsageDescription` con purpose string específico, montos ocultos hasta autenticar, re-bloqueo al volver de background tras 60s, resultado de autenticación solo en memoria. **No** guardar flags de "autenticado" en `UserDefaults` ni en Keychain.
10. **Nuevo — C-12, Banxico SIE:** retira todo rastro de Frankfurter del código. `Bmx-Token` se guarda **solo** en Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, sin `keychain-access-groups`, sin sync a iCloud); nunca en `UserDefaults`/`@Model`/logs. Campo en Ajustes → Preferencias: `SecureField` con toggle mostrar/ocultar y botón "Probar token". Parseo fail-closed igual que el C-04 original (fallback a `ExchangeRateCache`), tratando `"N/E"` como dato ausente, no como `0`. 401/403 → mensaje claro en Ajustes sin revelar el token, nunca logueado. Confirma contra la documentación oficial de Banxico SIE el endpoint/serie exacto y el shape de respuesta antes de codificar (§1) — si algo no coincide con lo asumido aquí, vuelve a Ivan.

---

*Ivan no promete seguridad absoluta. Este documento cubre el threat model proporcional a una app financiera personal de un solo usuario sin auth ni backend propio — no está dimensionado para un escenario multiusuario, con auth de terceros, o con distribución pública, porque ninguno de esos existe en el PRD/TRD actuales. Si eso cambia, este documento debe reabrirse completo antes de que Woz continúe.*
