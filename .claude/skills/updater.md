# Updater — Sparkle para macOS (distribución fuera del App Store)

Runbook reutilizable para implementar actualizaciones automáticas vía Sparkle en apps macOS con Developer ID, sin depender del Mac App Store.

**Invócalo desde Phil** (estrategia y pipeline) o **desde Woz** (integración de código).

---

## Preguntas obligatorias antes de empezar

Antes de tocar código o crear repos, obtén estas respuestas:

1. **¿Nombre del repo público de updates?**
   Sugerencia: `<usuario>/<NombreApp>-updates`
   → Contendrá solo `appcast.xml` y los `.dmg` como GitHub Releases. El código fuente queda en el repo privado.

2. **¿La app usa App Sandbox?**
   → Cambia los entitlements requeridos. Si no lo sabe, busca en el `.entitlements` o en el `project.yml`.

3. **¿Existe ya un certificado Developer ID Application en este Mac?**
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

4. **¿Existe perfil de notarización en Keychain?**
   ```bash
   xcrun notarytool history --keychain-profile PROFILE_NAME 2>&1 | head -5
   ```
   Si no existe, hay que crearlo una sola vez:
   ```bash
   xcrun notarytool store-credentials NOTARY_PROFILE \
     --apple-id tu@email.com \
     --team-id XXXXXXXXXX \
     --password xxxx-xxxx-xxxx-xxxx   # App-specific password de appleid.apple.com
   ```

---

## Arquitectura de repos

```
repo privado/        ← código fuente de la app (puede ser privado)
  └── scripts/
      ├── release.sh         ← orquesta todo el pipeline
      └── publish_update.sh  ← firma, notariza, publica

repo público/        ← solo para distribución (DEBE ser público — Sparkle lo lee sin auth)
  NombreApp-updates/
  ├── appcast.xml            ← feed de updates
  └── README.md
```

GitHub Releases del repo público contiene los `.dmg` de cada versión.

---

## 1. Crear el repo público de updates

```bash
gh repo create <usuario>/NombreApp-updates --public \
  --description "NombreApp macOS — releases y actualizaciones automáticas"
```

`appcast.xml` inicial:
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>NombreApp Updates</title>
    <link>https://github.com/usuario/NombreApp-updates</link>
    <description>Actualizaciones de NombreApp para macOS</description>
    <language>es</language>
    <!-- Los items de release se insertan aquí -->
  </channel>
</rss>
```

URL del feed (va en `Info.plist`):
```
https://raw.githubusercontent.com/usuario/NombreApp-updates/main/appcast.xml
```

---

## 2. Integrar Sparkle en el proyecto

### SPM — agregar dependencia en `project.yml`

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: 2.6.0

targets:
  NombreApp:
    dependencies:
      - package: Sparkle
        product: Sparkle
```

Luego regenerar: `xcodegen generate`

### Generar claves EdDSA (una sola vez por app, no perder la privada)

```bash
# Tras compilar una vez en Xcode, el binario aparece en DerivedData
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -name "generate_keys" 2>/dev/null | head -1)
$SPARKLE_BIN
```

Output:
```
Private key saved to the Keychain.
Public key (SUPublicEDKey): <BASE64_STRING>
```

**Guarda la clave pública** — va en `Info.plist`.
**La privada queda en el Keychain** — sin ella no puedes firmar releases futuros. Haz backup del Keychain o del item `ed25519` de la app.

### Info.plist — keys de Sparkle

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/usuario/NombreApp-updates/main/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>AQUI_LA_CLAVE_PUBLICA_BASE64</string>

<key>SUEnableInstallerLauncherService</key>
<true/>
```

> `SUEnableInstallerLauncherService` es **obligatorio si la app está sandboxeada**. Sin él el updater falla silenciosamente.

### Entitlements — excepciones para sandbox

Si la app usa App Sandbox, agrega en `NombreApp.entitlements`:

```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>
```

Sin estas dos excepciones el helper XPC de Sparkle no puede comunicarse y el updater nunca arranca.

### Punto de entrada — `NombreAppApp.swift`

```swift
import SwiftUI
import Sparkle

@main
struct NombreAppApp: App {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
```

`CheckForUpdatesView` — botón en el menú Help:
```swift
import Sparkle
import SwiftUI

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: checkForUpdatesViewModel.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
```

---

## 3. Versionado

Sparkle determina si hay update usando **`sparkle:version`** (el build number entero), no el semver.

| Key | Valor | Ejemplo |
|-----|-------|---------|
| `CFBundleShortVersionString` | Semver — lo que ve el usuario | `1.2.0` |
| `CFBundleVersion` | Entero, siempre mayor al anterior | `42` |
| `sparkle:version` en appcast | Igual a CFBundleVersion | `42` |
| `sparkle:shortVersionString` | Igual a CFBundleShortVersionString | `1.2.0` |

**Regla:** el build number del próximo release = build del último item en `appcast.xml` + 1. Nunca confiar en un archivo local — leer del appcast publicado.

Archivos de estado en el repo privado:

**`VERSION.md`:**
```markdown
# Versión actual publicada
- Versión: 1.0.0
- Build: 1

# Próximo release sugerido
- Versión: 1.1.0
- Build: 2

## Historial
| Build | Versión | Fecha |
|-------|---------|-------|
| 1 | 1.0.0 | 2025-01-15 |
```

**`CHANGELOG.md`:**
```markdown
# Changelog

## [Unreleased]
- Descripción de cambios que aún no se han publicado

## [1.0.0] — 2025-01-15
- Primera versión pública
```

---

## 4. Pipeline de release — `scripts/release.sh`

**Orden estricto — no saltarse pasos:**

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="NombreApp"
SCHEME="NombreApp"
PROJECT="${APP_NAME}.xcodeproj"
UPDATES_REPO="usuario/NombreApp-updates"
NOTARY_PROFILE="NOTARY_PROFILE"
TEAM_ID="XXXXXXXXXX"
BUNDLE_ID="com.ejemplo.NombreApp"

# ── Leer versión del appcast publicado ───────────────────────────
APPCAST_URL="https://raw.githubusercontent.com/${UPDATES_REPO}/main/appcast.xml"
LAST_BUILD=$(curl -s "$APPCAST_URL" | grep 'sparkle:version' | \
  sed 's/.*sparkle:version="\([0-9]*\)".*/\1/' | sort -n | tail -1)
LAST_BUILD=${LAST_BUILD:-0}

NEW_BUILD=$((LAST_BUILD + 1))
read -p "Versión semver (último publicado: ver appcast): " NEW_VERSION

echo "→ Build: $NEW_BUILD | Versión: $NEW_VERSION"

ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
DMG_PATH="build/${APP_NAME}-${NEW_VERSION}.dmg"

# ── a. Archive ────────────────────────────────────────────────────
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  MARKETING_VERSION="$NEW_VERSION" \
  CURRENT_PROJECT_VERSION="$NEW_BUILD"

# ── b. Export (Developer ID) ──────────────────────────────────────
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions/Direct.plist

# ── c. Verificar firma y entitlements ────────────────────────────
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH"

# ── d. Empaquetar DMG ────────────────────────────────────────────
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

# ── e. Notarizar ─────────────────────────────────────────────────
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

# ── f. Grapar ticket (ANTES de firmar con Sparkle) ───────────────
xcrun stapler staple "$DMG_PATH"

# ── g. Firmar con Sparkle (DESPUÉS de grapar) ────────────────────
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" 2>/dev/null | head -1)
if [ -z "$SIGN_UPDATE" ]; then
  echo "ERROR: sign_update no encontrado. Compila el proyecto en Xcode primero."
  exit 1
fi

ED_SIG=$("$SIGN_UPDATE" "$DMG_PATH" | grep 'sparkle:edSignature' | \
  sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
DMG_SIZE=$(stat -f%z "$DMG_PATH")

# ── h. Actualizar appcast.xml ─────────────────────────────────────
UPDATES_DIR=$(mktemp -d)
git clone --depth=1 "https://github.com/${UPDATES_REPO}.git" "$UPDATES_DIR"

RELEASE_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
NEW_ITEM="    <item>
      <title>${APP_NAME} ${NEW_VERSION}</title>
      <pubDate>${RELEASE_DATE}</pubDate>
      <sparkle:version>${NEW_BUILD}</sparkle:version>
      <sparkle:shortVersionString>${NEW_VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url=\"https://github.com/${UPDATES_REPO}/releases/download/v${NEW_VERSION}/${APP_NAME}-${NEW_VERSION}.dmg\"
        sparkle:edSignature=\"${ED_SIG}\"
        length=\"${DMG_SIZE}\"
        type=\"application/octet-stream\" />
    </item>"

# Insertar antes del cierre </channel>
sed -i '' "s|</channel>|${NEW_ITEM}\n  </channel>|" "${UPDATES_DIR}/appcast.xml"

# ── i. Verificar Gatekeeper ───────────────────────────────────────
spctl -a -vvv --type install "$DMG_PATH"

# ── j. Publicar ──────────────────────────────────────────────────
cd "$UPDATES_DIR"
git add appcast.xml
git commit -m "release: v${NEW_VERSION} (build ${NEW_BUILD})"
git push

gh release create "v${NEW_VERSION}" \
  --repo "$UPDATES_REPO" \
  --title "${APP_NAME} v${NEW_VERSION}" \
  --notes "$(sed -n "/## \[${NEW_VERSION}\]/,/## \[/p" ../CHANGELOG.md | head -n -1)" \
  "${DMG_PATH}#${APP_NAME}-${NEW_VERSION}.dmg"

# ── Verificar que el asset publicado es byte a byte igual ─────────
REMOTE_SIZE=$(gh release view "v${NEW_VERSION}" \
  --repo "$UPDATES_REPO" \
  --json assets --jq '.assets[0].size')
if [ "$REMOTE_SIZE" != "$DMG_SIZE" ]; then
  echo "ERROR: tamaño del asset en GitHub ($REMOTE_SIZE) ≠ DMG firmado ($DMG_SIZE)"
  echo "La validación EdDSA fallará en los clientes. Borra el release y vuelve a subir."
  exit 1
fi

echo "✅ v${NEW_VERSION} (build ${NEW_BUILD}) publicado correctamente."

# Actualizar VERSION.md
cd -
sed -i '' "s/^- Versión:.*/- Versión: ${NEW_VERSION}/" VERSION.md
sed -i '' "s/^- Build:.*/- Build: ${NEW_BUILD}/" VERSION.md
```

---

## 5. Troubleshooting

| Síntoma | Causa | Fix |
|---------|-------|-----|
| "The updater failed to start" | Sandbox sin entitlements de mach-lookup | Agregar `-spks` y `-spki` al `.entitlements` |
| Updater arranca pero nunca ofrece update | `sparkle:version` no incrementó | Verificar que el nuevo build > último en appcast |
| "No such host" / appcast inaccesible | Repo de updates es privado | Hacerlo público en GitHub Settings |
| Firma EdDSA inválida en clientes | Asset subido difiere del firmado | Verificar bytes: `stat -f%z` local == `.size` en release |
| DMG rechazado por Gatekeeper | No notarizado o no grapado | Correr `spctl -a -vvv --type install` antes de publicar |
| Credenciales de notarytool vencidas | App-specific password expiró | Generar nuevo en appleid.apple.com, `store-credentials` de nuevo |
| `sign_update` no encontrado | Sparkle no compilado aún | Compilar el proyecto en Xcode una vez para que genere DerivedData |
| Update se ofrece pero falla al instalar | Helper XPC no firmado | `codesign --verify --deep` en el `.app` exportado |
