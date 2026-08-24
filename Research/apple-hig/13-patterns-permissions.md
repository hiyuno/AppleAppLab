# Asking for Permission — System Permissions Pattern

**Fuentes**:
- https://developer.apple.com/design/human-interface-guidelines/asking-for-permission
- https://support.apple.com/en-us/102515 (About privacy and Location Services)
- https://developer.apple.com/forums/thread/675818 (Permission request discussions)
- Medium: "Complete Guide to iOS Permissions in 2026"

**En una frase**: Cómo solicitar permisos a usuarios para acceder a cámara, ubicación, contactos, fotos y otros datos sensibles, manteniendo confianza y cumplimiento legal.

**Fecha de recolección**: 2026-08-24 (Pasada 3)

---

## Permisos Principales en iOS/iPadOS (2026)

Estos son los permisos que requieren diálogo de sistema y pueden bloquearse en Settings:

| Permiso | Caso de Uso | Acceso Negado → | Acceso Parcial |
|---------|-----------|-----------------|----------------|
| **Camera** | Video call, foto in-app | Cámara no funciona | Cámara frontal / trasera (iOS 15+) |
| **Microphone** | Audio recording, voice chat | Silencio del audio | Micrófono particular |
| **Photos** | Upload/edit photos | Acceso denegado | "Limited" (iOS 14+): usuario elige qué fotos compartir |
| **Contacts** | Share contact info, invite | Acceso denegado | N/A |
| **Calendar** | Invite to events, check availability | Acceso denegado | N/A |
| **Location** | Maps, local search, geo-fencing | Acceso denegado | "While Using App" vs "Always" |
| **Media Library** | Music, podcasts | Acceso denegado | N/A |
| **Health** (HealthKit) | Fitness apps | Acceso denegado | Por tipo de dato (steps, heart rate, etc.) |
| **Bluetooth** | Wearables, headphones | Acceso denegado | N/A |
| **Clipboard** | Paste from clipboard (iOS 16+) | Lectura bloqueada | Toast notifica acceso |
| **Local Network** (iOS 14+) | mDNS discovery | Acceso denegado | N/A |
| **Apple Intelligence** (2026+) | On-device AI features | Deshabilitado | Puede estar en Private Cloud Compute |

---

## Principios de Solicitud (HIG Oficial)

### 1. Pedir en el Momento Justo (Just-in-Time)

**✗ MAL**: Pedir permiso en launch o onboarding
```swift
// NO hagas esto
if !hasRequestedCameraPermission {
    requestCameraPermissionAtLaunch()
}
```

**✓ BIEN**: Pedir cuando usuario intenta usar la feature
```swift
// En su lugar, cuando usuario toque "Take Photo"
Button("Take Photo") {
    if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted { openCamera() }
        }
    } else {
        openCamera()
    }
}
```

**Beneficios**:
- Tasas de aprobación más altas (~70% vs ~30% si pides en launch)
- Usuarios entienden por qué necesitas el permiso
- Menos abandono ("Qué app rara que quiere mi cámara en launch")

### 2. Proporciona Propósito Claro (Purpose String)

En `Info.plist`, proporciona un mensaje amigable explicando por qué necesitas el acceso:

```xml
<!-- Info.plist -->
<key>NSCameraUsageDescription</key>
<string>We need camera access to let you take photos for your profile.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location to find nearby restaurants and show them on the map.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Select photos from your library to share them with friends.</string>
```

**Mejores prácticas**:
- Escribe en primera persona ("We need" es mejor que "This app requires")
- Sé específico: "Take profile photos" es mejor que "Access camera"
- Evita lenguaje amenazante ("We'll collect your data")
- Usa sentence case (primera letra mayúscula, el resto minúscula)

### 3. Nunca Duplices el Alert del Sistema

Apple proporciona alertas estándar. **No agregues un alert custom que copie el sistema**.

```swift
// ✗ MAL: Alert custom que parece del sistema
Alert(title: "Camera Access", message: "Can we access your camera?")

// ✓ BIEN: Usa el sistema nativo, personaliza solo el propósito (Info.plist)
AVCaptureDevice.requestAccess(for: .video)
```

---

## Flujos de Permiso Específicos

### Camera / Microphone

```swift
import AVFoundation

// Revisar estado actual
let status = AVCaptureDevice.authorizationStatus(for: .video)

switch status {
case .authorized:
    // ✓ Usar cámara
    openCameraView()
    
case .denied:
    // Usuario previamente rechazó
    // Ir a Settings para cambiar
    showSettingsAlert()
    
case .restricted:
    // Control Parental o MDM — no hay mucho que hacer
    showRestrictionAlert()
    
case .notDetermined:
    // Primera vez — pedir permiso
    AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
            if granted { openCameraView() }
            else { showPermissionDeniedAlert() }
        }
    }
    
@unknown default:
    break
}
```

### Fotos (PhotosUI - iOS 14+)

iOS 14+ introduce "Limited Photo Library" — el usuario elige qué fotos compartir:

```swift
import PhotosUI

// Usar PHPickerViewController en lugar de deprecated UIImagePickerController
var config = PHPickerConfiguration()
config.selectionLimit = 0 // 0 = unlimited
config.preferredAssetRepresentationMode = .current

let picker = PHPickerViewController(configuration: config)
picker.delegate = self

present(picker, animated: true)

// Delegate
extension MyViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        results.forEach { result in
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                // Procesar imagen
            }
        }
    }
}
```

**Nota**: Con `PHPickerViewController`, **no necesitas permiso de Photos** — el framework maneja la limitación automáticamente.

### Ubicación (Location)

Dos niveles de permiso:
- **"While Using App"** (temporario) — acceso solo mientras app está en foreground
- **"Always"** (permanente) — acceso incluso cuando app está en background

```swift
import CoreLocation

let locationManager = CLLocationManager()
locationManager.delegate = self

// Pedir "While Using"
locationManager.requestWhenInUseAuthorization()

// O pedir "Always" (requiere justificación adicional)
locationManager.requestAlwaysAndWhenInUseAuthorization()

// Revisar estado
switch CLLocationManager.authorizationStatus() {
case .authorizedWhenInUse:
    // Actualizar ubicación solo en foreground
    locationManager.startUpdatingLocation()
case .authorizedAlways:
    // Usar en foreground y background
    locationManager.startUpdatingLocation()
    locationManager.allowsBackgroundLocationUpdates = true
case .denied, .restricted:
    // Handled
    break
default:
    break
}
```

**Importante (Privacidad 2026+)**:
- Usar `.requestWhenInUseAuthorization()` por defecto
- Solo pedir `.requestAlwaysAndWhenInUseAuthorization()` si realmente necesitas background location (ej. delivery app)

### Contactos / Calendario

```swift
import Contacts
import EventKit

// Contactos
let store = CNContactStore()
store.requestAccess(for: .contacts) { granted, error in
    if granted {
        let keysToFetch: [CNKeyDescriptor] = [CNContactNameKey, CNContactPhoneNumbersKey]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        // Fetch...
    }
}

// Calendario
let eventStore = EKEventStore()
eventStore.requestFullAccessToEvents { granted, error in
    if granted {
        // Acceder a eventos
    }
}
```

---

## Apple Intelligence & Privacidad (2026+)

Con la expansión de IA en iOS 26, Apple introduce **Private Cloud Compute**:

- Ciertos permisos ahora ofrecen opción: "Process on-device" vs "Use server processing"
- Si servidor: Apple promete no guardar datos
- Si local: Verificar que el dispositivo puede procesar (requiere suficiente RAM/almacenamiento)

**Para desarrolladores**: Si tu app integra IA, respetar esta preferencia del usuario:

```swift
// Pseudo-código
if userPrefers(.onDeviceProcessing) {
    processLocally()
} else if hasServerConnection {
    processOnServerPrivately()
}
```

---

## Manejo de Rechazo de Permiso

Cuando usuario rechaza ("Don't Allow" en el dialog):

1. **Primera rechazo**: Permitir que reintente luego
2. **Rechazo permanente** (después de rechazar 2+ veces): Mostrar alert con link a Settings

```swift
func showPermissionDeniedAlert() {
    let alert = UIAlertController(
        title: "Camera Access Required",
        message: "Enable camera access in Settings to take photos.",
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    })
    
    present(alert, animated: true)
}
```

---

## Accesibilidad & Inclusión

- **VoiceOver**: Los alertas de permiso son anunciados automáticamente
- **Motor accessibility**: Los diálogos de permiso son accesibles via teclado
- **No agregar requisitos de permiso** que bloqueen la app por completo
  - Ej. Photo app requiere fotos, pero un editor de notas no

---

## Errores Comunes

❌ Pedir permiso en launch → Pedir just-in-time  
❌ Propósito genérico ("Camera access") → Explícito ("Take profile photos")  
❌ Alert custom que copia el sistema → Usar diálogos del sistema  
❌ Pedir "Always" por defecto → Empezar con "While Using"  
❌ Ignorar "Limited Photos" en iOS 14+ → Usar PHPickerViewController  
❌ Preguntar de nuevo después de rechazar → Mantén UI completa sin permiso  

---

## Checklist de Implementación

- [ ] Permisos solicitados just-in-time (cuando feature es usada, no en launch)
- [ ] `Info.plist` tiene purpose strings claros y específicos
- [ ] Manejo de tres estados: authorized, denied, notDetermined
- [ ] Link a Settings cuando permiso fue rechazado permanentemente
- [ ] Alternativa funcional si permiso se niega (no crashear)
- [ ] Soporte para Limited Photo Library (iOS 14+)
- [ ] Respeto a Location Services preferences ("While Using" por defecto)
- [ ] Testear en dispositivos reales (simulator puede tener comportamiento diferente)
- [ ] Cumplimiento con privacy policy (ser honesto sobre qué haces con los datos)

---

## Referencias Relacionadas

- **Privacy & Compliance** (Kate) — Privacy Policy legal
- **Accessibility** (01 foundations) — alternativas para usuarios con limitaciones
- **Patterns: Confirming User Actions** (14) — si permiso tiene implicaciones
- **Patterns: Managing Tasks** (12) — si quieres notificaciones (también requieren permiso)
