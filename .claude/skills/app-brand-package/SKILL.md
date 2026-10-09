---
name: app-brand-package
description: "Rutina que produce el paquete de marca de la app para web-lab (contrato v1: web-lab docs/app-brand-package.md). Jonny lidera. Corre el generador lab-brand-package (AppleAppLabUI) sobre el tema, los assets y el código; le muestra a Yuno cada diferencia entre tema, DESIGN_*.md y código, una pregunta por diferencia, y no publica con diferencias abiertas; Jonny elige las 3–6 pantallas clave y confirma la versión (semver calculado por el generador); Woz captura con -LabSeedData en cada modo de la app; Phil suma screenshots en pre-lanzamiento; Ivan revisa que no haya secretos ni datos reales; Steve escribe el CHANGELOG, actualiza 'Brand package' en el intake y hace el commit en el repo de la app. 'check' solo diagnostica. Úsalo cuando la app vaya a tener sitio, antes de entregar a web-lab, y cada vez que cambien colores, tipografía, esquinas o pantallas clave."
---

# /app-brand-package — La app le pasa su marca a la web

El sitio de una app nace de la app: colores, tipografía, esquinas, materiales, motion, ícono y pantallas reales, no de un style lab en blanco. Esta rutina produce `brand-package/` en la raíz del repo de la app, junto a `app-web-intake.md`, con la forma exacta que firmaron los dos Masters (web-lab `docs/app-brand-package.md`, v1, 2026-10-08).

**Principio del contrato:** el paquete dice cómo es la app tal como sale; nunca trae una decisión de web. Si un valor no se ve bien en web (contraste, modo que falta, blur), eso lo resuelve Frost en web-lab y lo registra allá. Aquí no se "mejora" nada para la web.

```
brand-package/
├── brand-package.json     # manifest — generador
├── tokens.tokens.json     # DTCG — generador
├── icons.map.json         # SF Symbol → Lucide/Phosphor — Jonny, si las pantallas muestran SF Symbols
├── CHANGELOG.md           # una entrada por versión — Steve
└── assets/
    ├── logo/              # logo.svg (+ logo-on-dark.svg) — Jonny; si no hay, same_as_icon
    ├── icon/              # app-icon-ios-1024.png, app-icon-macos-1024.png — generador (o a mano si es Icon Composer)
    ├── screens/           # <id>-<estado>-<modo>@<n>x.png — Woz
    ├── 3d/<id>/           # opcional, contrato v1.1: renders por modo, póster, mp4, glb — Ed
    └── screenshots/       # App Store, desde pre-lanzamiento — Phil
```

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/app-brand-package` | Rutina completa: insumos que falten → check → diferencias a Yuno → versión → write → CHANGELOG → intake → commit |
| `/app-brand-package check` | Solo diagnóstico: versión que saldría, diferencias, faltantes. No escribe nada |
| `/app-brand-package screens` | Solo recaptura las pantallas clave (Woz). Después corre `check` |
| `/app-brand-package status` | Versión publicada, si el diseño cambió desde entonces y qué falta |

## Quién hace qué

| Paso | Agente |
|------|--------|
| 0 · Sonda | Steve |
| 1 · Pantallas clave, plataforma principal, logo, mapa de íconos | **Jonny** |
| 2 · Datos de prueba (`-LabSeedData`) y capturas | **Woz** |
| 3 · Check y diferencias → Yuno | Steve corre, Jonny traduce, **Yuno decide** |
| 4 · Corrección en el origen | Jonny (tema, `DESIGN_*.md`) · Woz (assets, código) |
| 5 · Versión | generador calcula, **Jonny confirma** |
| 6 · Revisión de privacidad | Ivan |
| 7 · Write, CHANGELOG, intake, commit | Steve |
| Pre-lanzamiento · screenshots de App Store | Phil |
| Cuando hay assets 3D para la web · `3d-assets.json` y `assets/3d/<id>/` | Ed |

---

## Paso 0 — Sonda (Steve)

```bash
grep -n "AppleAppLabUI" -A2 project.yml                     # ruta del paquete (path local)
grep -n "Themes/.*\.json" project.yml                       # tema empaquetado
ls brand-package/brand-package.json Docs/Design/key-screens.json 2>/dev/null
git status --short | grep -v " brand-package/"              # debe estar limpio
```

- El generador vive en `AppleAppLabUI`. Se corre con la ruta del paquete de `project.yml`:
  `swift run --package-path <ruta AppleAppLabUI> lab-brand-package check --primary <ios|macos>`
  Si la app no depende del paquete por ruta local, usa el clon de AppleAppLab (`~/Documents/GitSync/AppleAppLab/Packages/AppleAppLabUI`).
- **Sin tema** (`LabThemeStore` + `Themes/<app>.json`) no hay paquete: primero `/add-developer-tools`. El tema es la fuente principal.
- **Repo sucio** fuera de `brand-package/`: `write` se niega. El paquete sale de un commit limpio (`source.commit`).
- **Sin remoto `origin`**: `source.repo` es obligatorio. Steve se lo dice a Yuno; no inventa una URL.

## Paso 1 — Insumos de diseño (Jonny)

1. **Plataforma principal** (`--primary`): la que llena `text`, `radius` y `spacing`. En una app iOS + macOS, la que el usuario usa más; Jonny decide y lo anota en `STYLE_BRIEF.md` para no volver a preguntarlo.
2. **Pantallas clave, de 3 a 6**, en `Docs/Design/key-screens.json` (commit en el repo). Las que mejor cuentan la app: la principal, el flujo central, un detalle, un estado vacío si es parte de la identidad. Siempre, aunque web-lab todavía no sepa si el sitio será `mirror` o `adapted`.
   ```json
   {"screens": [
     {"id": "home", "platform": "macos", "view": "HomeView", "states": ["default", "empty"]},
     {"id": "transaction-detail", "platform": "macos", "view": "TransactionDetailView"},
     {"id": "settings", "platform": "macos", "view": "SettingsView"}
   ]}
   ```
   `id` en kebab-case; `states` es opcional (por defecto `default`).
3. **Logo** (opcional): `brand-package/assets/logo/logo.svg`, vectorial, con `currentColor` o con `logo-on-dark.svg` aparte. Sin logo, el manifest dice `same_as_icon`.
4. **`icons.map.json`** si las pantallas clave muestran SF Symbols: `{"star.fill": "lucide:star", "gearshape": "lucide:settings"}`. SF Symbols nunca se usan como íconos sueltos en la web.
5. **Ícono de macOS desde Icon Composer** (`.icon`): el generador no lo puede exportar. Jonny lo exporta a mano a `brand-package/assets/icon/app-icon-macos-1024.png` (1024 × 1024, con forma y sombra). Es opcional: si falta, el paquete se publica igual. El de iOS (1024, sin alfa, sin máscara) sí es obligatorio; el generador lo toma de `AppIcon.appiconset`, o del mismo folder si se exportó a mano.

## Paso 2 — Datos de prueba y capturas (Woz)

**Convención `-LabSeedData`** (`AppleAppLabUI/Support/LabSeedData.swift`, detalle en `PATTERNS.md` §"Datos de prueba"): con ese argumento la app arranca con un set de datos ficticio en un store en memoria y nunca toca los datos reales; con `-LabScreen <id>` abre la pantalla clave de ese id. Todo dentro de `#if DEBUG`. Si la app aún no lo tiene, Woz lo implementa primero: nombres, montos y fechas inventados y verosímiles, nada copiado de datos reales.

Capturas: **cada estado × cada modo que la app tiene** (`appearance.app_modes`: si la app es solo oscura, solo `dark`), sin marco de dispositivo:

| Plataforma | Escalas | Cómo |
|------------|---------|------|
| macOS | `@1x` y `@2x` | Abrir el build Debug: `open -n <App>.app --args -LabSeedData -LabScreen <id> -AppleInterfaceStyle Dark` (o `Light`). Luego `lab-brand-package capture-mac --app "<App>" --out brand-package/assets/screens/<id>-<estado>-dark@2x.png`, que guarda la ventana sin sombra y genera el `@1x`. La terminal necesita permiso de Grabación de pantalla; si no lo tiene, Woz se lo dice a Yuno y para |
| iOS / iPadOS | `@3x` | `xcrun simctl ui <udid> appearance dark` · `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4` · `xcrun simctl launch --terminate-running-process <udid> <bundle> -LabSeedData -LabScreen <id>` · `xcrun simctl io <udid> screenshot brand-package/assets/screens/<id>-<estado>-dark@3x.png` |

Nombre exacto: `<id>-<estado>-<modo>@<n>x.png`. El generador lista lo que falta.

## Paso 2b — Assets 3D (Ed, opcional)

Si la web debe heredar un asset 3D (héroe, ícono en volumen), Ed lo anota en `Docs/Design/3d-assets.json` y copia los finales a `brand-package/assets/3d/<id>/`: un render `<id>-<modo>.png` por cada modo de la app (`.webp` opcional), y si hay `<id>.mp4` o `<id>.glb`, un póster `<id>-poster-<modo>.webp` por modo, obligatorio. El generador los lista en `assets.three_d` y bloquea si falta un render o un póster. Nunca el `.blend` ni las referencias. Detalle en `.claude/skills/ed/SKILL.md`.

## Paso 3 — Check y diferencias (Steve → Yuno)

```bash
swift run --package-path <AppleAppLabUI> lab-brand-package check --primary macos --json
```

Salida: `ready`, `version`, `bump`, `reasons`, `differences`, `blocking`, `warnings`. Códigos: `0` listo · `2` hay diferencias o faltantes · `3` nada cambió (no hay versión nueva).

**Diferencias.** El generador compara el tema contra el `AccentColor` del catálogo de assets, los colores con nombre de rol (`AppBackground`, `TextSecondary`…), los hex de acento en `DESIGN_*.md` y los `.tint(Color(…))` del código. Cada diferencia va a Yuno **antes de escribir nada**, una pregunta por diferencia, en lenguaje simple, con `AskUserQuestion` y una opción por fuente con su valor:

> "En Fintrol el fondo oscuro es gris `#323232` en el tema y negro `#000000` en el catálogo de colores. ¿Cuál es el de la app?"

**Un paquete no se publica con diferencias abiertas.** Si Yuno no contesta, no hay versión nueva: web-lab sigue con la anterior o sin paquete. Nada se bloquea.

## Paso 4 — Corrección en el origen

La respuesta de Yuno se corrige en la fuente que perdió, para que la siguiente corrida ya no vea la diferencia:

- **Perdió `DESIGN_*.md`** → Jonny corrige el documento.
- **Perdió un asset o el código** → Woz corrige el colorset o la línea.
- **Perdió el tema** → el tema de la app vive en `.appleapplab/Themes/` y `/update-team` lo sobreescribe: Steve no lo edita. Anota una `propuesta` en `PROJECT_LEARNINGS.md` (fingerprint `team/themes/<app>`, con el valor elegido) para App Master, que corrige `Themes/<app>.json` en AppleAppLab. El paquete espera a ese `/update-team`.

Commit de las correcciones y `check` otra vez hasta que no queden diferencias.

## Paso 5 — Versión (generador → Jonny)

El generador compara con el paquete del último commit (contrato §9):

- **MAJOR** — cambió el matiz del acento, la fuente (`font_design`), el estilo de esquinas, el logo o el ícono; se quitó un modo de apariencia, un token o un asset 3D.
- **MINOR** — cualquier otro cambio de diseño: tokens, material, motion, valores por componente, pantallas, screenshots o assets 3D nuevos o distintos.
- **PATCH** — solo metadata.
- **Nada** — si el diseño no cambió no sale versión (código 3), aunque cambien la fecha o el commit.

Jonny lee las `reasons` y confirma. Si es **MAJOR**, Steve se lo dice a Yuno en una línea antes de publicar ("La marca de Fintrol cambia de versión mayor: nuevo acento. Web-lab te preguntará si la adopta.").

## Paso 6 — Privacidad (Ivan)

Antes del `write`, Ivan abre cada captura y screenshot: sin nombres, correos, montos, cuentas ni notificaciones reales; solo datos de `-LabSeedData`. El generador ya rechaza rutas locales absolutas y tokens (Figma, GitHub, API keys, tokens en URLs) en el manifest y los tokens, y quita credenciales de la URL del remoto. Un dato real en una captura es un hallazgo de datos personales: se recaptura, no se edita la imagen.

## Paso 7 — Publicar (Steve)

1. `lab-brand-package write --primary <plataforma>` — escribe `brand-package.json`, `tokens.tokens.json` y copia los íconos. Se niega si hay diferencias, faltantes o repo sucio.
2. **`CHANGELOG.md`** — entrada nueva arriba, en inglés (lo lee web-lab):
   ```markdown
   ## 1.1.0 — 2026-10-12
   - Window material is more transparent (0.5 → 0.3).
   - New key screen: onboarding.
   Source: <short commit SHA>
   ```
   Una línea por razón del generador, en lenguaje de producto, no de tokens.
3. **Intake** (si existe `app-web-intake.md`): `Brand package` = la versión; `Logo file(s)`, `App icon file(s)` y `Available screenshots` = `in brand package` cuando el paquete los trae; `Last updated` = hoy. `App repo` con la ruta local si falta.
4. Commit en el repo de la app: `brand package <versión>`. Push solo si Yuno lo pide.

Cierre en una línea:

> "Paquete de marca de Fintrol 1.1.0 publicado (minor: material más transparente, pantalla de onboarding). Web-lab lo verá al empezar su siguiente fase."

---

## Cuándo Steve la propone (no la lanza) sin que se la pidan

- Existe `app-web-intake.md` y todavía no hay `brand-package/` → una vez.
- Jonny cierra un cambio de colores, tipografía, esquinas o pantallas clave en una app que ya tiene `brand-package/` → *"Cambió el diseño; ¿saco versión nueva del paquete de marca?"*
- `/app-web-intake` Fase 3 (entrega a web-lab).

## Lo que esta rutina NO hace

- No decide nada de la web: modo `mirror`/`adapted`, escala tipográfica, contraste, el modo que falta. Eso es de Cooper y Frost en web-lab.
- No inventa el modo que la app no tiene: una app solo oscura publica solo oscuro, con `mode_missing: "light"`.
- No publica con diferencias abiertas ni con datos reales en las capturas.
- No edita el tema en `.appleapplab/` ni ningún skill: eso sube como `propuesta` a App Master.
- No copia nada al repo de web-lab. Web-lab lee `brand-package/` en su lugar, solo lectura.

## Tono

Corto y concreto. A Yuno se le pregunta qué color es el de su app, no qué fuente gana un merge.
