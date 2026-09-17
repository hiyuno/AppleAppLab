---
name: app-web-intake
description: "Rutina de intake para el sitio web de la app. Solo cuando el usuario la pide: Steve crea app-web-intake.md en la raíz desde el template (verbatim en inglés, valores en inglés), lo rellena con lo que ya existe en PRD, TRD, STYLE_BRIEF, GROWTH, PRIVACY_POLICY y APPSTORE, pregunta al usuario solo lo que ningún documento sabe (dominio, soporte, pilares confirmados) y deja lo demás en TBD sin inventar. Desde entonces cada agente escribe su campo al producir su documento; Phil pregunta lo del foro en pre-lanzamiento; URLs, rating y proof solo cuando son reales. 'status' muestra qué falta y quién lo llena; 'update' re-deriva de los documentos. web-lab /app-web lo lee al construir el sitio. Úsalo cuando la app vaya a tener sitio web."
---

# /app-web-intake — El intake del sitio web se llena mientras construimos la app

Rutina del equipo, no un agente. Existe para un solo propósito: cuando esta app vaya a tener un sitio de marketing en **web-lab**, el skill `/app-web` de ese repo lee `app-web-intake.md` y solo pregunta lo que siga vacío o `TBD`. Todo lo que el equipo de la app ya sabe — plataformas, pilares, pricing, sign-in, qué datos recoge, color de marca, descripción de App Store — se escribe aquí **a medida que aparece**, en inglés, sin inventar nada.

**Solo arranca cuando el usuario lo pide.** Steve no crea este archivo por su cuenta. Una vez existe, los agentes lo mantienen.

---

## Reglas que no se negocian

1. **El template es verbatim.** Encabezados, nombres de campo, tablas y notas explicativas se copian tal cual de `.appleapplab/app-web-intake-template.md`. `/app-web` hace match campo por campo; un encabezado traducido o renombrado es un campo que vuelve a preguntar.
2. **Todo en inglés.** También los valores. Es el idioma del intake y del sitio.
3. **Nunca inventar.** Sin números estimados, sin quotes redactados por nosotros, sin fechas supuestas, sin URLs que no existen. Lo que no se sabe es `TBD`. Lo que no aplica es `not applicable`. Lo que aún no pasó es `not published yet` / `none yet`.
4. **Verbatim significa verbatim.** La descripción de App Store se pega tal cual de `APPSTORE.md`; los quotes de proof, tal cual de su fuente y con la fila de permiso.
5. **Cada campo tiene un dueño.** El agente que produce el dato lo escribe cuando produce su documento (tabla abajo). Steve es dueño del archivo y de las fechas (`Date started`, `Last updated`).
6. **Las decisiones del sitio son del usuario.** Dominio, soporte, moderación del foro, comentarios o votos, flagship demo, permiso para citar: se preguntan, no se deducen.

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/app-web-intake` | Crea `app-web-intake.md` desde el template, rellena todo lo derivable de los documentos existentes, y pregunta **en un solo mensaje** lo que ningún documento sabe y ya toca preguntar. Si el archivo ya existe, equivale a `update` |
| `/app-web-intake status` | Tabla campo → estado (`filled` / `TBD` / `deferred to pre-launch` / `post-launch`) → quién lo llena y con qué documento. Para saber qué falta |
| `/app-web-intake update` | Re-deriva los campos automáticos de los documentos (PRD, TRD, STYLE_BRIEF, GROWTH, PRIVACY_POLICY, APPSTORE…). **No pisa** lo que el usuario escribió a mano ni lo que ya está `filled` con dato real; actualiza `Last updated` |
| `/app-web-intake prelaunch` | Hace las preguntas diferidas (foro, flagship demo, permiso de proof). Normalmente las hace Phil dentro de `/app-store-ready` Fase 4; este modo es para apps que no pasan por ahí (distribución directa) |

---

## Quién llena cada campo, con qué, y cuándo

| Campo del template | Lo escribe | Fuente | Cuándo | Tipo |
|--------------------|-----------|--------|--------|------|
| **Round A** | | | | |
| Platforms | Scott | `PRD.md` plataforma target; `TRD.md` targets | cierre de concepto | auto |
| App Store URL · Mac App Store URL | Phil | App Store Connect tras aprobación | post-lanzamiento; antes: `not published yet` o link público de TestFlight si existe | post-launch |
| Current App Store rating and install count | Phil / Frederick | App Store Connect, datos reales | post-lanzamiento; antes: `none yet` | post-launch |
| Current App Store description / tagline (verbatim) | Phil | `APPSTORE.md` §Descripción y subtítulo, pegado tal cual | pre-lanzamiento | auto |
| First two minutes | Scott propone, **usuario confirma** | `PRD.md` core loop + onboarding de Jonny | creación del intake | ask (confirmación) |
| Feature pillars (3–6) | Scott propone, Frederick afina claims, **usuario confirma** | `PRD.md` features P0; `GROWTH.md` posicionamiento | creación del intake | ask (confirmación) |
| Flagship demo? | Frederick recomienda, **usuario decide** | `GROWTH.md` | pre-lanzamiento | ask (deferred) |
| Screenshot/video status | Phil | `/app-store-ready` Fase 4 | pre-lanzamiento; antes: `TBD` | auto |
| **Round B** | | | | |
| Pricing model | Kara / Frederick | `GROWTH.md`, StoreKit config | cuando entra Kara; `free` si no cobra | auto |
| Pricing tiers · Trial length | Kara | StoreKit config, paywall | cuando entra Kara | auto |
| Proof (quote / install count / rating / press) | Frederick | fuentes reales post-lanzamiento | post-lanzamiento | post-launch |
| Permission to quote | **usuario**, por fila | — | cuando exista el proof | ask (deferred) |
| **Round C** | | | | |
| Does the app already have its own sign-in? · Provider | Avie | `TRD.md` auth; `SECURITY.md` | cierre de arquitectura | auto |
| Rough number of existing users | Tim / Phil | `ANALYTICS.md`, App Store Connect | post-lanzamiento; antes: `none yet` | post-launch |
| Who moderates the forum + target response time | **usuario** | — | pre-lanzamiento (Phil en `/app-store-ready` Fase 4) | ask (deferred) |
| Comments allowed, or votes only? | **usuario** | — | pre-lanzamiento (Phil) | ask (deferred) |
| **Round D** | | | | |
| Where do release notes come from today? | Phil / Craig | `APPSTORE.md` (App Store what's-new) o appcast de `/update-feature` | pre-lanzamiento | auto |
| What does the app collect about its users, and where is it stored? | Kate, con Ivan y Tim | `PRIVACY_POLICY.md`, `LEGAL_AUDIT.md`, `SECURITY.md`, `ANALYTICS.md`, `PrivacyInfo.xcprivacy` | cuando Kate produce la policy; se refina en pre-lanzamiento | auto |
| Do docs or a support channel already exist? | **usuario**, Phil lo registra | — (Phil necesita la support URL para App Store Connect de todos modos) | creación del intake | ask |
| **Round E** | | | | |
| Target domain · Already owned? | **usuario** | — (Kate necesita URL pública para la Privacy Policy) | creación del intake | ask |
| Logo file(s) · App icon file(s) | Jonny → Woz | rutas en `Assets.xcassets/AppIcon.appiconset`, carpeta de diseño | construcción | auto |
| Primary/accent brand color (hex) | Steve / Jonny | `STYLE_BRIEF.md` (accent del tema elegido) | fase de estilo visual | auto |
| Available screenshots | Phil | `/app-store-ready` Fase 4, carpeta de screenshots | pre-lanzamiento | auto |
| App Store badge language/localization | Scott / Kim | `PRD.md` mercado; `L10N_AUDIT.md` | cierre de concepto | auto |
| **Open questions / notes** | Frederick, Scott, Avie | `GROWTH.md` competidores; `PRD.md` features del roadmap no construidas; `TRD.md` restricciones | cuando existan | auto |

**auto** = el agente lo escribe sin preguntar · **ask** = Steve lo pregunta al crear el intake · **ask (deferred)** = se pregunta en pre-lanzamiento · **post-launch** = solo con datos reales.

---

## Fase 1 — Creación (`/app-web-intake`)

1. **Copiar el template** de `.appleapplab/app-web-intake-template.md` a `app-web-intake.md` en la raíz. Sustituir `[app name]` por el nombre del PRD. `Date started` = hoy.
2. **Derivar todo lo `auto` que ya exista.** Steve lee los documentos presentes y escribe cada campo en inglés. Lo que su documento fuente aún no existe queda `TBD` — no se adelanta.
3. **Preparar las propuestas que el usuario confirma:** Scott redacta *First two minutes* a partir del core loop del PRD y propone los *Feature pillars* (3–6, una frase cada uno) a partir de las features P0; si hay `GROWTH.md`, Frederick afina los claims al posicionamiento.
4. **Preguntar en un solo mensaje** — solo lo que toca ahora:

> "Creé `app-web-intake.md` con lo que ya sabemos (plataformas, sign-in, color, mercado…). Tres cosas que solo tú sabes:
>
> 1. **Feature pillars y first two minutes** — propuesta de Scott:
>    - *First two minutes:* [texto]
>    - Pilares: 1. [nombre — claim] · 2. … · 3. …
>    ¿Los confirmas o cambias algo?
> 2. **Dominio:** ¿ya tienes uno para la app? ¿Cuál?
> 3. **Soporte y docs:** ¿dónde vas a atender a los usuarios — email, help site, Discord, nada todavía?
>
> Lo del foro del sitio (moderador, comentarios) te lo pregunto en pre-lanzamiento. URLs, rating y quotes se llenan cuando sean reales."

5. Escribir las respuestas, `Last updated` = hoy, y mostrar el `status`.

Si el usuario responde "no sé todavía" a algo: `TBD`. Nunca se rellena por él.

---

## Fase 2 — Mantenimiento continuo (cada agente, sin que se lo pidan)

Una vez que `app-web-intake.md` existe en la raíz, **cada agente escribe sus campos al terminar su documento**, en inglés, y actualiza `Last updated`. Es parte de su entrega, no un paso aparte:

| Al terminar… | Escribe |
|--------------|---------|
| Scott · `PRD.md` | Platforms · propuesta de First two minutes y Feature pillars (marcadas *proposed — confirm*) · badge language por mercado · features del roadmap no construidas en Open questions |
| Avie · `TRD.md` | Sign-in y provider · restricciones técnicas relevantes en Open questions |
| Steve · `STYLE_BRIEF.md` | Primary/accent brand color (hex del tema) |
| Jonny · `DESIGN_*.md` | Logo file(s) · App icon file(s) — rutas reales |
| Kara · StoreKit | Pricing model · Pricing tiers · Trial length |
| Frederick · `GROWTH.md` | Competidores en Open questions · afina claims de los pilares · post-lanzamiento: Proof, rating, installs con fuente |
| Kate · `PRIVACY_POLICY.md` | What the app collects and where it is stored — concreto, con Ivan (`SECURITY.md`) y Tim (`ANALYTICS.md`) |
| Kim · `L10N_AUDIT.md` | App Store badge language/localization |
| Phil · `APPSTORE.md` y `/app-store-ready` | Description/tagline verbatim · Screenshot status y Available screenshots · Release notes source · Docs/support · en Fase 4 **pregunta** moderador + tiempo de respuesta, comments vs votes, flagship demo · post-lanzamiento: App Store URLs |
| Tim · `ANALYTICS.md` | Rough number of existing users, post-lanzamiento |

Los momentos naturales ya existentes del flujo son los que disparan esto — no hay pausas nuevas:
- **Cierre de concepto** (Scott + Avie + fase de estilo visual): Round A y Round C sign-in, color.
- **Pre-lanzamiento** (`/app-store-ready` Fase 4, Kate, Phil): Round D completo, Round A descripción y screenshots, y las preguntas diferidas del foro.
- **Post-lanzamiento** (Phil, Frederick momento 3, Tim): URLs, rating, installs, proof, usuarios.

---

## Fase 3 — Entrega a web-lab

Cuando el usuario diga que va a construir el sitio, Steve corre `/app-web-intake status`, cierra lo que pueda cerrarse ese día, y entrega:

> "`app-web-intake.md` listo para `/app-web`: 19 campos llenos, 4 `TBD` (rating, installs, proof, usuarios — no hay datos reales todavía), 0 pendientes de ti. Cooper solo te preguntará esos cuatro."

El archivo viaja **dentro del repo de la app** en la raíz; web-lab lo lee desde ahí.

---

## Cuándo Steve la propone (no la lanza) sin que se la pidan

- El usuario menciona "sitio", "landing", "página de la app", "web-lab", "app-web", "dominio" → Steve: *"¿Quieres que empiece `app-web-intake.md`? Se va llenando solo mientras construimos."* Una vez. Si dice que no, no insiste.
- Nunca la crea sola: el alcance lo decide el usuario.

## Lo que esta rutina NO hace

- No crea el archivo sin que el usuario lo pida
- No inventa ni estima un solo valor — `TBD` siempre gana
- No traduce el template ni renombra campos
- No pregunta lo que un documento ya responde
- No pregunta lo del foro antes de pre-lanzamiento
- No construye el sitio — eso es web-lab

---

## Con `asc` — campos que se derivan directo de App Store Connect

Si `asc` está autenticado (`Research/asc-cli/00-index.md`), varios campos post-lanzamiento dejan de ser manuales: `asc apps list --output json` da el App Store ID (→ URL), `asc localizations list --app <id> --type app-info` trae la **descripción y el subtítulo verbatim** por idioma, y `asc status --app <id>` el estado de la versión publicada. Rating e install count siguen viniendo de App Store Connect Analytics: se copian **tal cual**, nunca redondeados. `update` los re-deriva.

## Tono

- Inglés en el archivo; el idioma del usuario en la conversación.
- Preguntas agrupadas, una vez, en el momento que toca.
- `TBD` se dice sin disculpas: es información, no un hueco.
