---
name: app-store-ready
description: "Rutina de preparación para App Store. Phil lidera; Kate, Ivan, Bertrand, Chris, Sarah, Kara y Larry revisan. Verifica cuenta, build, Info.plist, Privacy Manifest, entitlements, guidelines de rechazo y App Store Connect. Veredicto LISTA / LISTA CON FIXES / NO LISTA / NO VIABLE, plan por etapas y, si no es viable, opciones de distribución alternativas (Developer ID + Sparkle, TestFlight, Unlisted, Business Manager). 'go <n>' aplica cada etapa. Úsalo cuando quieras subir una app, te hayan rechazado o dudes si se puede distribuir."
---

# /app-store-ready — ¿Puede esta app entrar al App Store? Y si no, ¿qué hacemos?

Rutina del equipo, no un agente. Cuando se lanza, Steve orquesta a Phil (líder), Kate, Ivan, Bertrand, Chris, Sarah, Kara y Larry para responder una pregunta con dos partes: **¿esta app pasaría App Review hoy?** y, si no, **¿qué falta — o qué camino de distribución conviene en su lugar?** Entrega `APP_STORE_READINESS.md` con un veredicto — LISTA / LISTA CON FIXES / NO LISTA / NO VIABLE — un **plan por etapas** para llegar a LISTA, y cuando el App Store no es el camino, un **menú de alternativas** con pros, contras y quién las ejecuta.

**El skill termina en el veredicto y el plan.** No envía nada a App Review ni implementa fixes hasta que el usuario apruebe cada etapa explícitamente.

---

## Frontera con el resto del equipo

| | Quién lo hace ya | Qué hace esta rutina con eso |
|--|--|--|
| Metadata, screenshots, `APPSTORE.md` | Phil | Verifica que exista y sea coherente con el build; si falta, Phil lo produce como etapa |
| Gate de seguridad, entitlements, `SECURITY_AUDIT.md` | Ivan | **Lee** el gate. Si está `BLOCKED`, el veredicto es NO LISTA hasta que Ivan lo cierre. No re-audita |
| Privacy Policy, GDPR/COPPA, export compliance, `LEGAL_AUDIT.md` | Kate | Lee el estado y verifica que lo legal esté **publicado y enlazado**, no solo redactado |
| Performance, crashes | `/optimize-app`, Bertrand | Si hay hang o crash 🔴 (guideline 2.1), deriva a `/optimize-app` y lo marca como prerrequisito |
| Distribución directa macOS | `/update-feature` | Es una de las opciones de la Fase 7 |
| Pricing y monetización | Kara, Frederick | Solo verifica que lo implementado cumpla 3.1.x. No decide precios |

**Un solo plan activo por zona.** Igual que `/optimize-app` y `/architecture-audit`: Steve cruza etapas abiertas antes de cada `go`.

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/app-store-ready` | Auditoría completa: cuenta, build, proyecto, guidelines, App Store Connect, revisión cruzada, veredicto, plan, opciones |
| `/app-store-ready quick` | Solo Fase 2 — checks técnicos automatizables sobre el proyecto (Info.plist, Privacy Manifest, entitlements, iconos, archive). Sin App Store Connect ni cuenta. Útil antes de cada TestFlight |
| `/app-store-ready rejected` | Toma el mensaje de App Review pegado por el usuario como entrada, mapea cada punto a la guideline y a un hallazgo, y arma el plan para el resubmit |
| `/app-store-ready go <n>` | Aprueba e implementa la etapa `n` del plan existente |

Plataforma (iOS / macOS / ambas) se detecta del `project.yml` o del `TRD.md`. Mac App Store tiene requisitos propios (sandbox obligatorio) que se activan solos.

---

## Quién hace qué

| Fase | Agente | Rol |
|------|--------|-----|
| 0 · Contra qué se audita | Steve | Plataformas, tipo de distribución deseada, monetización, cuentas, UGC, kids, regiones |
| 1 · Cuenta y contratos | **Phil** | Developer Program, Agreements, tax/banking, DSA trader status, roles ASC — checklist para el usuario |
| 2 · Proyecto y build | Woz + Craig | Archive Release, validación, versiones, iconos, Info.plist, Privacy Manifest, entitlements, sandbox — automatizable |
| 3 · Guidelines de rechazo | **Phil** + Larry + Kara | Las 15 causas de rechazo más frecuentes contra la app real |
| 4 · App Store Connect | **Phil** | App record, metadata, screenshots, age rating, Privacy Labels, IAP, review notes, demo account |
| 5 · Revisión cruzada | Ivan, Kate, Bertrand, Chris, Sarah | Cada uno confirma su gate sobre el build candidato |
| 6 · Veredicto | Phil + Steve | LISTA / LISTA CON FIXES / NO LISTA / NO VIABLE |
| 7 · Opciones | Phil + Steve (+ Kara, Avie, Scott según opción) | Solo si NO VIABLE, o si el usuario pide alternativas |
| 8 · Plan por etapas | Phil + Steve | Orden: bloqueantes técnicos → privacidad/legal → guidelines → metadata → pulido |
| 9 · Implementación | Woz / Phil / Kate → Bertrand → Ivan | **Solo con `go <n>`.** Cuando quedan 0 🔴 y 0 🟡, Phil ejecuta el submit con confirmación explícita del usuario |

Phil lidera porque es quien conoce App Review; los gates de Ivan y Kate son independientes y él no los puede saltar.

---

## Antes de empezar

Lee si existen:
- **`PRD.md`** — qué hace la app, si tiene cuentas, UGC, pagos, público infantil. Cada uno activa guidelines distintas.
- **`TRD.md`** — plataformas, entitlements, servicios externos, SDKs de terceros (Privacy Manifest).
- **`SECURITY_AUDIT.md`** — el gate de Ivan. `BLOCKED` = NO LISTA automático.
- **`LEGAL_AUDIT.md`** y **`PRIVACY_POLICY.md`** — lo que Kate ya cubrió. Aquí se verifica que esté publicado y enlazado.
- **`COMPAT_AUDIT.md`**, **`TEST_PLAN.md`** — hallazgos 🔴 abiertos son rechazo por 2.1.
- **`APPSTORE.md`** — metadata de Phil si ya existe.
- **`PERFORMANCE_AUDIT.md`** — hangs y crashes abiertos.
- **`project.yml`**, **`Info.plist`**, **`*.entitlements`**, **`PrivacyInfo.xcprivacy`**, **`Assets.xcassets/AppIcon.appiconset`** — la evidencia técnica de la Fase 2.
- **`APP_STORE_READINESS.md`** — si ya existe, es re-audit: compara y no repitas lo cerrado.

---

## Fase 0 — Contra qué se audita (Steve)

Los requisitos cambian según lo que la app **es**. Steve fija esto antes de que nadie revise:

| Pregunta | Activa |
|----------|--------|
| ¿iOS, macOS o ambas? | Mac App Store exige App Sandbox y hardened runtime |
| ¿App Store, Mac App Store, o el usuario está abierto a distribución directa? | Define si la Fase 7 es plan B o plan A |
| ¿Cobra? ¿Bienes digitales, suscripción, físico, servicios? | 3.1.1 IAP obligatorio para digital; 3.1.2 suscripciones; 3.1.3 excepciones |
| ¿Tiene cuentas de usuario? ¿Login con terceros? | 4.8 Sign in with Apple; 5.1.1(v) eliminación de cuenta en la app |
| ¿Contenido generado por usuarios? | 1.2: reportar, bloquear, filtrar, contacto |
| ¿Público infantil o categoría Kids? | 1.3 + COPPA (Kate) + sin tracking ni links externos |
| ¿Recoge datos, usa SDKs de terceros, hace tracking? | Privacy Manifest, Privacy Labels, ATT 5.1.2 |
| ¿Se vende en la UE? | DSA: trader status obligatorio en ASC |
| ¿Salud, finanzas, legal, apuestas, cannabis, armas? | Categorías reguladas — guidelines 1.4, 3.2.2, 5.3, 5.1.3 y licencias (Kate) |

Steve anuncia el perfil antes de empezar: *"App iOS, suscripción, cuentas con Google Sign-In, sin UGC, venta en UE. Se activan: 3.1.2, 4.8, 5.1.1(v), DSA, Privacy Manifest."*

---

## Fase 1 — Cuenta y contratos (Phil, manual)

Nada de esto se automatiza — Phil entrega el checklist y el usuario confirma cada punto:

- [ ] Apple Developer Program **activo** (individual u organización). Organización requiere D-U-N-S y autoridad legal
- [ ] App Store Connect → Agreements: **Paid Apps Agreement** firmado si hay IAP o precio; **tax forms** y **banking** completos — sin esto los productos IAP no se pueden enviar
- [ ] **DSA trader status** declarado en ASC si la app se distribuye en la UE (obligatorio desde febrero 2025; sin él, la app se retira de la UE)
- [ ] Roles ASC: quién es Account Holder, quién puede subir builds, quién responde a App Review
- [ ] Certificado **Apple Distribution** y perfil de provisioning App Store vigentes (o firma automática configurada)
- [ ] Identificadores registrados en el portal: bundle ID, App Groups, iCloud containers, push keys, Sign in with Apple — según entitlements

Un `[ ]` aquí es 🔴: el build no se puede ni subir.

---

## Fase 2 — Proyecto y build (Woz + Craig, automatizable)

Todo lo que el repo permite verificar sin tocar App Store Connect. Cada check es un hallazgo con `archivo:línea` si falla.

### 2.1 Compila y valida

```bash
# Archive Release — si esto falla, nada más importa
xcodebuild -project <App>.xcodeproj -scheme <App> -configuration Release \
  -destination 'generic/platform=iOS' archive -archivePath build/<App>.xcarchive

# Export para App Store (ExportOptions.plist con method: app-store-connect)
xcodebuild -exportArchive -archivePath build/<App>.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export

# Validación contra App Store Connect — detecta iconos, entitlements, versiones, Info.plist inválidos
xcrun altool --validate-app -f build/export/<App>.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
# Alternativa GUI: Xcode → Organizer → Archives → Validate App
```

Sin API key de ASC, Woz da los pasos del Organizer y el usuario pega el resultado.

### 2.2 Versiones e identidad

```bash
grep -n "CFBundleShortVersionString\|CFBundleVersion\|MARKETING_VERSION\|CURRENT_PROJECT_VERSION" project.yml Info.plist 2>/dev/null
```

- `CFBundleShortVersionString` (x.y.z) y `CFBundleVersion` (build) — el build tiene que ser **mayor** que cualquier build ya subido para esa versión
- Bundle ID coincide con el registrado en ASC
- Deployment target coherente con el PRD y con `UIRequiredDeviceCapabilities`

### 2.3 Iconos y pantallas de lanzamiento

```bash
ls Assets.xcassets/AppIcon.appiconset/ && cat Assets.xcassets/AppIcon.appiconset/Contents.json | grep -c '"filename"'
```

- Icono **1024×1024 sin alpha ni esquinas redondeadas** (App Store Marketing) — el rechazo más tonto y más común
- Todos los tamaños del catálogo con archivo asignado (o icono único con Xcode 14+)
- Launch screen configurado (storyboard o `UILaunchScreen` en Info.plist); sin texto que necesite localización
- iPad: si el target lo incluye, soporta todas las orientaciones y multitasking, o declara `UIRequiresFullScreen`

### 2.4 Info.plist — purpose strings vs. APIs usadas

Falta una = **crash en el dispositivo del reviewer** = rechazo 2.1. Cruce automático:

| Si el código usa… | Info.plist necesita… |
|-------------------|----------------------|
| `AVCaptureDevice`, `UIImagePickerController` (cámara) | `NSCameraUsageDescription` |
| `AVAudioSession` grabando, `AVAudioRecorder` | `NSMicrophoneUsageDescription` |
| `PHPhotoLibrary`, `PhotosPicker` con acceso completo | `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription` |
| `CLLocationManager` | `NSLocationWhenInUseUsageDescription` (+ `AlwaysAndWhenInUse` si background) |
| `CNContactStore` | `NSContactsUsageDescription` |
| `EKEventStore` | `NSCalendarsFullAccessUsageDescription` / `NSRemindersFullAccessUsageDescription` |
| `LAContext` con biometría | `NSFaceIDUsageDescription` |
| `HKHealthStore` | `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` |
| `CMMotionManager`, `CMPedometer` | `NSMotionUsageDescription` |
| `SFSpeechRecognizer` | `NSSpeechRecognitionUsageDescription` |
| `CBCentralManager` | `NSBluetoothAlwaysUsageDescription` |
| `NWBrowser`, Bonjour, multicast | `NSLocalNetworkUsageDescription` (+ `NSBonjourServices`) |
| `ATTrackingManager` | `NSUserTrackingUsageDescription` |
| `INPreferences`, Siri | `NSSiriUsageDescription` |

```bash
for api in AVCaptureDevice AVAudioRecorder PHPhotoLibrary CLLocationManager CNContactStore EKEventStore LAContext HKHealthStore CMMotionManager SFSpeechRecognizer CBCentralManager NWBrowser ATTrackingManager; do
  if grep -rq "$api" --include="*.swift" . ; then echo "USA $api"; fi
done
grep -n "UsageDescription" Info.plist project.yml 2>/dev/null
```

Cada string tiene que decir **para qué** la app lo usa, en el idioma del usuario. "Necesitamos acceso a la cámara" es rechazo por 5.1.1; "Para escanear el código QR de tu ticket" pasa.

### 2.5 Privacy Manifest — `PrivacyInfo.xcprivacy`

Obligatorio desde mayo 2024. Su ausencia o incoherencia es rechazo automático (ITMS-91053).

```bash
find . -name "PrivacyInfo.xcprivacy" -not -path "*/.build/*"
grep -rn "UserDefaults\|\.timeIntervalSince1970\|systemUptime\|ProcessInfo.processInfo.systemUptime\|volumeAvailableCapacity\|activeInputModes\|fileModificationDate\|creationDate" --include="*.swift" . | grep -v "/.build/" | head
```

- Existe en el target principal **y** en cada extensión (widget, share)
- `NSPrivacyAccessedAPITypes` declara cada *required-reason API* que el código usa: UserDefaults (`CA92.1`…), file timestamps, system boot time, disk space, active keyboard
- `NSPrivacyCollectedDataTypes` coincide con lo que dirán las Privacy Nutrition Labels en ASC
- `NSPrivacyTracking` = `true` solo si hay tracking real (y entonces ATT es obligatorio)
- **SDKs de terceros** de la lista de Apple (Firebase, Alamofire, Kingfisher, RevenueCat…) traen su propio manifest **y firma** — verificar versión que lo incluya

### 2.6 Cifrado y transporte

- `ITSAppUsesNonExemptEncryption` declarado en Info.plist (`false` si solo usa HTTPS/cifrado del sistema — evita la pregunta en cada build). Kate confirma la clasificación
- `NSAppTransportSecurity`: cualquier `NSAllowsArbitraryLoads` o excepción por dominio necesita justificación en las review notes, o es 🟡

### 2.7 Entitlements y sandbox

```bash
cat *.entitlements 2>/dev/null; grep -n "entitlements\|capabilities" project.yml
codesign -d --entitlements :- build/<App>.xcarchive/Products/Applications/<App>.app 2>/dev/null
```

- Solo los entitlements que la app **usa**. Uno sin uso es pregunta de App Review
- **macOS → Mac App Store:** `com.apple.security.app-sandbox = true` es **obligatorio**. Sin sandbox no entra — punto. Hardened runtime activo. Cada excepción de sandbox (`files.user-selected`, `network.client`, `temporary-exception.*`) justificada; las `temporary-exception` son 🟡 y suelen ser rechazadas
- iOS: push, iCloud, App Groups, Sign in with Apple, Associated Domains — cada uno configurado también en el portal de identificadores (Fase 1)
- `UIBackgroundModes` solo los que se usan de verdad — 2.5.4

### 2.8 Lo que App Review encuentra aunque tú no

```bash
# Símbolos privados — Xcode Validate los detecta; esto es una primera pasada
xcrun nm -u build/<App>.xcarchive/Products/Applications/<App>.app/<App> 2>/dev/null | grep -i "_UI.*Private\|_\$s.*Private" | head
grep -rn "#if DEBUG" --include="*.swift" . | wc -l           # OK si compila fuera; 🔴 si hay flags de debug activos en Release
grep -rni "lorem ipsum\|TODO\|placeholder\|test123\|coming soon" --include="*.swift" --include="*.xcstrings" . | grep -v "/.build/" | head
```

- Sin APIs privadas (2.5.1)
- Sin contenido placeholder, "próximamente", features que no funcionan (2.1 — *incomplete*)
- Sin menciones a otras plataformas ("también en Android") en la app o en metadata (2.3.10)
- dSYMs incluidos en el archive (para crash reports)

Salida de la fase: tabla *check → estado → evidencia*.

---

## Fase 3 — Guidelines de rechazo (Phil + Larry + Kara)

Las causas reales de rechazo, contra la app real. Cada una es PASS / FAIL / N.A. con evidencia.

| # | Guideline | Qué revisa Phil | Quién más |
|---|-----------|-----------------|-----------|
| 2.1 | **Performance — completitud** | Sin crashes en los flujos que un reviewer va a tocar; sin placeholders; **cuenta demo** en review notes si hay login; todo lo que se ve funciona | Bertrand, Chris |
| 2.3 | **Metadata exacta** | Screenshots del build real, no mockups con features que no existen; descripción sin promesas falsas; sin precios en screenshots | — |
| 2.5.1 | **APIs privadas** | Fase 2.8 | Woz |
| 2.5.4 | **Background** | Solo modos usados; audio/location/VoIP justificados | Woz |
| 3.1.1 | **IAP para bienes digitales** | Todo lo digital (features, contenido, suscripciones) se compra con StoreKit; sin links a compra externa salvo excepciones regionales vigentes; sin "descuento fuera de la app" | **Kara** |
| 3.1.2 | **Suscripciones** | Precio y periodo claros **antes** de comprar; términos y privacy policy enlazados en el paywall; botón **Restaurar compras**; sin trials engañosos; funciona en todos los dispositivos del usuario | Kara |
| 3.1.3 / 3.1.5 | **Excepciones** | Bienes físicos, servicios fuera de la app, reader apps, multiplataforma — si aplica, documentado en review notes | Kara |
| 4.0 | **Diseño** | Sin auditoría de Larry con 🔴 abiertos; parece una app nativa, no una web | **Larry** |
| 4.2 | **Funcionalidad mínima** | No es un web wrapper ni una app de una sola pantalla sin valor; no es un clon | Scott |
| 4.8 | **Sign in with Apple** | Si hay login con Google/Facebook/etc. y **no** solo login propio, SIWA es obligatorio (salvo educación/enterprise/gobierno) | Woz |
| 5.1.1 | **Privacidad — recolección** | Privacy Policy **enlazada en ASC y accesible dentro de la app**; solo pide datos que necesita; permisos just-in-time con propósito; **(v) si se puede crear cuenta, se puede borrar cuenta desde la app** | **Kate** |
| 5.1.2 | **Privacidad — uso** | Tracking solo con ATT; sin compartir datos con terceros sin consentimiento; Privacy Labels coherentes con la realidad | Kate, Tim |
| 1.2 | **Contenido de usuarios** | Si hay UGC: filtrar, **reportar**, **bloquear** usuarios, y un contacto publicado. Los cuatro | Scott, Woz |
| 1.3 / 5.1.4 | **Kids** | Si es Kids o para menores: sin tracking, sin links externos sin gate parental, COPPA | Kate |
| 5.2 | **Propiedad intelectual** | Sin marcas, iconos ni nombres de terceros sin permiso; sin "para iPhone" en el nombre | Kate |
| 1.4 / 5.1.3 / 5.3 | **Regulados** | Salud (sin diagnósticos sin base), finanzas, apuestas, cannabis — licencias y disclaimers | Kate |
| 2.3.10 | **Menciones a otras plataformas** | Ni en la app ni en metadata | — |

**Mac App Store añade:** sandbox obligatorio (2.4.5), sin kexts ni helpers privilegiados fuera del sandbox, sin acceso a otras apps vía AppleScript sin entitlement `automation`, sin auto-actualización propia (Sparkle **no** en la versión App Store).

Salida de la fase: tabla por guideline con estado y evidencia.

---

## Fase 4 — App Store Connect (Phil)

Lo que tiene que existir en ASC para poder enviar. Phil verifica lo que hay y produce lo que falta (`APPSTORE.md`):

### App record y versión
- [ ] App creada con el bundle ID exacto, plataforma(s), SKU, idioma primario
- [ ] Versión creada con el número del build

### Metadata (por idioma)
- [ ] Nombre ≤ 30 · Subtítulo ≤ 30 · Keywords ≤ 100 (sin repetir el nombre ni categorías) · Descripción · Texto promocional · Novedades
- [ ] Sin menciones a precios, otras plataformas, ni "beta"
- [ ] URL de **soporte** (funciona) · URL de **Privacy Policy** (funciona, pública, mismo contenido que la app) · URL de marketing (opcional)
- [ ] Copyright · EULA (estándar de Apple o custom)

### Screenshots y preview
- [ ] iPhone: los tamaños que ASC exija para la versión actual (6.9" y 6.5"/6.7" a la fecha) — **del build real**
- [ ] iPad 13" si el target incluye iPad
- [ ] Mac: 2880×1800 / 2560×1600 / 1440×900 / 1280×800
- [ ] Sin frames de dispositivo con features inexistentes; primera captura = la propuesta de valor
- [ ] App Preview opcional, ≤ 30 s, solo footage de la app

### Cuestionarios
- [ ] **Age rating** — el cuestionario nuevo (2025) completo y honesto; Kids solo si cumple 1.3
- [ ] **Privacy Nutrition Labels** — coherentes con `PrivacyInfo.xcprivacy` y con la Privacy Policy. Incoherencia = rechazo o retiro
- [ ] **Export compliance** — respondido (coherente con `ITSAppUsesNonExemptEncryption`)
- [ ] **Content rights** — si hay contenido de terceros, se declara
- [ ] **Accessibility Nutrition Labels** (iOS 26 / 2025) — opcional pero visible en la ficha; Sarah confirma qué se puede declarar con verdad

### Monetización
- [ ] Productos IAP / suscripciones creados, con metadata, **screenshot de review** y en estado *Ready to Submit*; **adjuntos a la versión** (los primeros productos se revisan con la app)
- [ ] Grupos de suscripción con niveles correctos; ofertas introductorias configuradas
- [ ] Precio y disponibilidad por país

### Review
- [ ] **Review notes**: qué hace la app en 3 líneas, cómo probar cada feature con permisos, justificación de entitlements/ATS/background
- [ ] **Cuenta demo** con datos ya cargados si hay login — sin esto, rechazo garantizado por 2.1
- [ ] Contacto de review con teléfono que suene
- [ ] Adjuntos: video de demo si la feature necesita hardware o contexto (ej: Bluetooth, ubicación real)

### Distribución
- [ ] Release: manual / automático / programado
- [ ] **Phased release** (7 días) activado para v1.x — recomendación de Phil
- [ ] TestFlight externo con **Beta App Review pasado** — no obligatorio, pero es la mejor señal previa

---

## Fase 5 — Revisión cruzada (los gates)

Cada uno confirma sobre **el build candidato exacto**, no sobre uno anterior:

- **Ivan** — `SECURITY_AUDIT.md` en `PASS` o `PASS WITH ACCEPTED RISK` sobre el archive Release. `BLOCKED` = NO LISTA. Entitlements del archive coinciden con los auditados
- **Kate** — Privacy Policy **publicada** en URL estable y enlazada en ASC y en la app; términos si hay suscripción; export compliance clasificado; DSA trader status; COPPA si aplica; licencias de fuentes/assets/SDKs
- **Bertrand** — `TEST_PLAN.md` sin 🔴; crash-free en TestFlight; los flujos que el reviewer va a tocar probados en el dispositivo mínimo
- **Chris** — `COMPAT_AUDIT.md` sin 🔴; probado en la versión mínima de OS del target
- **Sarah** — sin bloqueantes de accesibilidad en flujos core; qué Accessibility Labels se pueden declarar
- **Kara** (si cobra) — StoreKit probado en sandbox y TestFlight; restore funciona; paywall cumple 3.1.2
- **Larry** — sin 🔴 de HIG abiertos (4.0)

Cada uno devuelve PASS / FAIL con evidencia; Phil integra.

---

## Severidades

**🔴 BLOQUEANTE** — no se puede enviar, o el rechazo es seguro:
- Archive no compila o `validate-app` falla
- Falta un purpose string de una API usada
- Sin `PrivacyInfo.xcprivacy` o incoherente con las Labels
- Mac: sandbox desactivado
- `SECURITY_AUDIT.md` BLOCKED
- Bienes digitales sin IAP (3.1.1)
- Login de terceros sin Sign in with Apple (4.8)
- Cuentas sin eliminación de cuenta en la app (5.1.1 v)
- UGC sin reportar/bloquear (1.2)
- Sin Privacy Policy URL, o la URL no carga
- Sin cuenta demo habiendo login
- Agreements/tax/banking sin firmar habiendo IAP
- Icono 1024 con alpha

**🟡 RIESGO ALTO** — probablemente rechazo, o retiro posterior:
- Screenshots que no corresponden al build
- ATS con `AllowsArbitraryLoads` sin justificar
- Entitlements o background modes sin uso
- Paywall sin precio/periodo claros o sin Restaurar
- Hallazgos 🟡 de Larry o Chris abiertos
- Purpose strings genéricos
- `temporary-exception` en sandbox macOS
- Age rating dudoso

**🔵 PULIDO** — mejora la ficha o la probabilidad, no bloquea:
- Accessibility Labels sin declarar
- Sin App Preview
- Keywords con espacio desaprovechado
- Sin phased release
- Sin TestFlight externo previo

---

## Fase 6 — Veredicto (Phil + Steve)

| Veredicto | Cuándo | Qué sigue |
|-----------|--------|-----------|
| **LISTA** | 0 🔴 · 0 🟡 | Phil ejecuta el checklist de submit (`APPSTORE.md`) **con confirmación explícita del usuario** antes de pulsar *Submit for Review* |
| **LISTA CON FIXES** | 0 🔴 · algunos 🟡 | Plan corto de 1–3 etapas; se puede enviar aceptando riesgo si el usuario lo decide, documentado |
| **NO LISTA** | Hay 🔴, pero **todos tienen fix dentro del App Store** | Plan por etapas de la Fase 8. Al cerrar todos los 🔴 y 🟡 → LISTA |
| **NO VIABLE (hoy)** | Al menos un 🔴 es **estructural**: la funcionalidad core viola una guideline o requiere lo que el App Store prohíbe | Fase 7 — opciones. El usuario elige el camino |

Qué cuenta como **estructural**: la app *es* un web wrapper (4.2); el negocio *es* vender digital fuera de IAP; en Mac, la feature core *necesita* salir del sandbox (kext, acceso total a disco, controlar otras apps, driver, auto-update propio); la app compite con una función del sistema de forma que Apple no permite; contenido regulado sin licencia posible; clon de otra app.

**Qué NO tocar.** Igual que las otras rutinas: lo que ya cumple se nombra para que nadie lo "mejore" de paso y rompa un gate.

---

## Fase 7 — Opciones cuando el App Store no es el camino (o no lo es todavía)

Solo si el veredicto es NO VIABLE, o si el usuario pide alternativas. Phil presenta el menú completo con pros, contras, costo y quién lo ejecuta; **el usuario elige**, Steve no decide.

| Opción | Cuándo conviene | Pros | Contras | Quién |
|--------|-----------------|------|---------|-------|
| **A · Quitar o rediseñar la feature bloqueante** | La feature no es el corazón del producto | Entra al App Store completo; descubrimiento, pagos, confianza | Pierdes la feature; puede cambiar el PRD | Scott (impacto), Avie, Woz |
| **B · Dos ediciones (Mac)** — App Store (sandbox, sin X) + Directa (Developer ID, completa) | Mac; la feature bloqueante es valiosa pero no para todos | Presencia en la tienda + versión completa; patrón muy común (BBEdit, Transmit…) | Dos builds, dos pipelines, dos flujos de pago; sin sync de licencias entre ambas sin trabajo | Woz (build configs), Craig, Kara (licencias) |
| **C · Developer ID + notarización + Sparkle (Mac)** → `/update-feature` | Mac; la app necesita salir del sandbox; quieres 100 % del ingreso y sin review | Sin restricciones de sandbox, sin comisión, sin review, updates cuando quieras | Sin descubrimiento del App Store; pagos con Paddle/Lemon Squeezy/Stripe (merchant of record para impuestos); confianza inicial menor; tú gestionas licencias y soporte | Phil (estrategia), Woz, Craig, Kara |
| **D · TestFlight** (iOS y Mac) | Beta, comunidad cerrada, validación antes de decidir | Hasta 10 000 testers externos, Beta App Review más laxa, sin ASC metadata completa | Builds expiran a los 90 días; no se puede cobrar; no es distribución final | Bertrand, Phil |
| **E · Unlisted App Distribution** | Audiencia específica (empleados, clientes, evento) pero pública por link | En el App Store sin aparecer en búsqueda; mismas herramientas (IAP, TestFlight) | **Mismas guidelines** — no salta 3.1.1 ni sandbox; requiere solicitud a Apple con justificación | Phil |
| **F · Custom Apps — Apple Business Manager / School Manager** | Una o pocas organizaciones concretas | Distribución privada a organizaciones; puede cobrarse | Guidelines casi iguales; la organización necesita ABM/ASM | Phil, Kate |
| **G · Apple Developer Enterprise Program** | Solo empleados de tu propia empresa (≥100), uso interno | Sin App Store, sin review | Muy difícil de obtener hoy; prohibido para público o clientes; revocación si se abusa | Phil, Kate |
| **H · Distribución alternativa en la UE** (iOS 17.4+): marketplaces alternativos o Web Distribution | Solo mercado UE y volumen alto | Fuera del App Store en iOS | Solo UE; requisitos altos (notarización de Apple, umbrales de instalaciones para web distribution, términos comerciales alternativos y sus comisiones); cambia con frecuencia — Kate verifica el estado actual | Phil, Kate, Frederick |
| **I · Reformular el producto** — Safari Web Extension, App Clip, widget, PWA | Cuando la funcionalidad cabe en otro formato que sí entra | Puede entrar al App Store o no necesitarlo | Es otro producto; vuelve a Scott | Scott, Avie |
| **J · Apelar / aclarar con App Review** | El rechazo es interpretativo, no estructural | A veces se gana; puedes pedir llamada con App Review | Lento; hay que tener argumentos con guidelines en mano | Phil (redacta), Kate |

Phil cierra con una **recomendación** y su razón, pero presenta todas las viables. Si el usuario elige una, esa decisión vuelve al PRD (Scott) y al TRD (Avie) como etapa 1 del plan.

---

## Fase 8 — Plan por etapas (Phil + Steve)

Mismas reglas que las otras rutinas — cada etapa shippable sola, un tipo de cambio por etapa, riesgo bajo primero, sin dos etapas en el mismo archivo, verificación y rollback explícitos — y el orden propio de App Store:

1. **Bloqueantes técnicos** — que compile, valide y tenga iconos. Sin esto nada se puede probar
2. **Privacidad y legal** — purpose strings, Privacy Manifest, Privacy Policy publicada, eliminación de cuenta, export compliance. Son los 🔴 más frecuentes y los más baratos
3. **Guidelines de negocio** — IAP, Sign in with Apple, UGC. Tocan código y a veces el PRD
4. **App Store Connect** — metadata, screenshots del build final, labels, IAP adjuntos, review notes, cuenta demo
5. **Pulido** — Accessibility Labels, preview, keywords, phased release

### Formato de cada etapa

```markdown
### Etapa N — [nombre corto]

**Qué:** [1–2 líneas]
**Hallazgos que cierra:** ASR-003, ASR-007 · **Guidelines:** 5.1.1(v), 4.8
**Archivos / lugar:** `Info.plist`, `Views/Settings/AccountView.swift` · App Store Connect → App Privacy
**Riesgo:** Bajo / Medio / Alto — [por qué]
**Cómo se verifica:** [`validate-app` pasa · check de Fase 2 en PASS · Kate confirma URL · Bertrand prueba el flujo]
**Rollback:** [commit atómico / revertir en ASC]
**Owner:** Woz / Phil / Kate
**Estado:** ⏳ Pendiente de aprobación
```

### Cierre de la rutina

Steve muestra el resumen y **se detiene**:

> "Auditoría App Store lista en `APP_STORE_READINESS.md`.
>
> **Veredicto: NO LISTA (corregible).** 4 🔴 · 3 🟡 · 2 🔵. Todo tiene fix dentro del App Store.
>
> Etapa 1 — Purpose strings de cámara y fotos + `PrivacyInfo.xcprivacy` con UserDefaults. Riesgo bajo. Cierra ASR-001, ASR-002.
> Etapa 2 — Eliminación de cuenta en Ajustes (5.1.1 v). Riesgo medio. Cierra ASR-004.
> Etapa 3 — Sign in with Apple junto al login de Google (4.8). Riesgo medio. Cierra ASR-003.
> Etapa 4 — Metadata, screenshots del build final, cuenta demo en review notes. Riesgo bajo.
>
> Para aplicar la primera: `/app-store-ready go 1`."

Si el veredicto es **NO VIABLE**, el resumen es el menú de la Fase 7 con la recomendación de Phil, y la etapa 1 del plan es *"decisión del usuario → actualizar PRD/TRD"*.

**No implementa ni envía nada sin ese `go`.**

---

## Fase 9 — Implementación por etapa (`/app-store-ready go <n>`)

```
Steve (lee la etapa n; cruza con otros planes activos)
→ Woz / Phil / Kate (implementa solo lo que dice la etapa; un commit si es código)
→ Bertrand (archive + validate pasan; tests pasan; el flujo tocado probado en dispositivo)
→ Ivan (solo si la etapa toca entitlements, red, auth, sandbox o Privacy Manifest)
→ Phil (re-verifica el check o guideline que la etapa cerraba → PASS)
→ Steve (actualiza APP_STORE_READINESS.md: hallazgos ✅, etapa ✅; recalcula el veredicto)
→ Steve pregunta: "Etapa n cerrada. Quedan X 🔴, Y 🟡. ¿Aplico la etapa n+1?"
```

Cuando el veredicto llega a **LISTA**:

```
Phil (checklist de submit de APPSTORE.md, punto por punto, con el usuario)
→ Usuario confirma explícitamente "envíalo"
→ Phil: Submit for Review · phased release · anota fecha y build en el historial
→ Mientras está en review: Phil monitorea; si llega un rechazo → `/app-store-ready rejected` con el mensaje pegado
```

Si algo se rompe o un gate vuelve a FAIL: revertir, marcar la etapa ⚠️ Revertida con la razón, replantear. Nunca se envía con un gate en FAIL "porque probablemente pasa".

---

## APP_STORE_READINESS.md — documento que produce la rutina

```markdown
# APP_STORE_READINESS — [Nombre de la app] v[X.Y] (build [N])

> Auditoría de preparación para App Store. Build: [commit / archivo .xcarchive]. Fecha: [fecha].
> Modo: completo / quick / rejected
> Perfil: [iOS + macOS · suscripción · cuentas con Google · sin UGC · venta en UE]
> Guidelines activadas: [3.1.2, 4.8, 5.1.1(v), DSA, Privacy Manifest, sandbox macOS]

---

## Veredicto

**LISTA / LISTA CON FIXES / NO LISTA / NO VIABLE** — [justificación en 3 líneas]

**Qué ya cumple y no se toca:** [gates en PASS, decisiones que funcionan]

| Severidad | Abiertos | Cerrados |
|-----------|----------|----------|
| 🔴 Bloqueante | X | Y |
| 🟡 Riesgo alto | X | Y |
| 🔵 Pulido | X | Y |

**Etapas activas:** [n] · **Zonas bloqueadas por otros planes:** [archivos o "ninguna"]

---

## Gates cruzados

| Gate | Estado | Evidencia |
|------|--------|-----------|
| Ivan — SECURITY_AUDIT | PASS / BLOCKED | [fecha, archive] |
| Kate — legal publicado | ✅ / ❌ | [URL policy, DSA, export] |
| Bertrand — estabilidad | ✅ / ❌ | [TestFlight build, crash-free %] |
| Chris — compat | ✅ / ❌ | [COMPAT_AUDIT 🔴 abiertos] |
| Sarah — a11y | ✅ / ⚠️ | [bloqueantes] |
| Kara — StoreKit | ✅ / ❌ / N.A. | [restore, paywall] |
| Larry — HIG | ✅ / ❌ | [🔴 abiertos] |

---

## Fase 1 — Cuenta y contratos
[checklist con estado]

## Fase 2 — Proyecto y build
| Check | Estado | Evidencia |
|-------|--------|-----------|
| Archive Release | ✅ | build/App.xcarchive |
| validate-app | ❌ | ITMS-91053: PrivacyInfo missing |
| Purpose strings | ❌ | usa AVCaptureDevice, falta NSCameraUsageDescription |
| … | | |

## Fase 3 — Guidelines
| Guideline | Estado | Evidencia |
|-----------|--------|-----------|
| 2.1 completitud | ✅ | |
| 3.1.2 suscripciones | 🟡 | paywall sin "Restaurar" — PaywallView.swift:88 |
| 4.8 Sign in with Apple | ❌ | GoogleSignIn presente, sin SIWA |
| 5.1.1(v) eliminación de cuenta | ❌ | no existe en la app |
| … | | |

## Fase 4 — App Store Connect
[checklist con estado]

---

## Hallazgos

### 🔴 [ASR-001] Falta NSCameraUsageDescription

**Fase / Guideline:** 2.4 · 5.1.1
**Evidencia:** `Features/Scan/ScanView.swift:31` usa `AVCaptureDevice`; `Info.plist` sin la clave
**Consecuencia:** crash al abrir el escáner en el dispositivo del reviewer → rechazo 2.1
**Fix:** añadir la clave con propósito específico: "Para escanear el código QR de tu ticket"
**Etapa:** 1 · **Owner:** Woz · **Estado:** ⏳

---

## Opciones de distribución
[solo si NO VIABLE o si el usuario las pidió — tabla de Fase 7 filtrada a las viables, con recomendación de Phil]

---

## Plan — por etapas

> Cada etapa se aplica sola. Aprobar con `/app-store-ready go <n>`.

### Etapa 1 — …
[formato de etapa]

---

## Historial

| Etapa / evento | Fecha | Resultado | Build | Estado |
|----------------|-------|-----------|-------|--------|
| Etapa 1 | — | — | — | ⏳ |
| Submit v1.0 | — | — | — | — |
| App Review | — | Aprobada / Rechazada [guidelines] | — | — |
```

---

## Cuándo Steve lanza esta rutina sin que se la pidan

- El usuario dice "quiero subirla", "¿está lista para el App Store?", "vamos a lanzar", "me rechazaron", "¿esto se puede distribuir?", "¿por qué no me dejan…?"
- Tier 3 antes de Phil — Steve la corre como puerta previa a la submission
- Frederick, en su momento 2 (pre-lanzamiento), la pide como prerrequisito
- Kate o Ivan detectan un requisito de App Store que nadie está cubriendo
- `/update-feature` se está considerando y el usuario no ha descartado el App Store — Steve propone auditar primero

## Lo que esta rutina NO hace

- No pulsa *Submit for Review* sin confirmación explícita del usuario en ese momento
- No re-audita seguridad ni legal — lee los gates de Ivan y Kate y los exige
- No decide monetización ni pricing — Kara y Frederick
- No elige entre las opciones de la Fase 7 — las presenta con recomendación; el usuario decide
- No promete aprobación: reduce el riesgo de rechazo a lo que se puede verificar

---

## Dentro de `/global-audit`

Cuando Steve te ejecuta desde `/global-audit`, corres **igual** — mismas fases, mismos líderes, mismos gates, mismo documento y mismo plan — con dos diferencias: **no muestras tu cierre** (Steve hace uno solo con las cuatro rutinas) y **no te detienes a preguntar** salvo lo que solo el usuario puede responder, que Steve agrupa al principio. Tus hallazgos con tag cruzado (`🏗`, `🧹`, prerrequisitos 2.1) los recoge Avie en la reconciliación y pueden cambiar de documento; tus etapas aparecen en la secuencia global como `G<n> → /app-store-ready go <etapa>` dentro de tu ronda. Si tu ronda es la que cierra, Steve dispara la re-sincronización que corresponde antes de que empiece la siguiente.

## Tono

- Guideline o no existe. Cada hallazgo cita el número (2.1, 3.1.1, 5.1.1 v) y la evidencia.
- Sin dramatizar el rechazo: la mayoría son corregibles en una etapa.
- Sin vender el App Store ni la distribución directa: en la Fase 7 se presentan las opciones con sus costos reales y el usuario elige.
- Español o inglés: el del usuario.
