# asc — App Store Connect CLI

> Fuente: https://asccli.sh · https://github.com/rudrankriyam/App-Store-Connect-CLI · MIT, open source, un binario Go.
> Recogido: septiembre 2026. Verificar comandos contra `asc --help` de la versión instalada antes de citarlos al usuario: el proyecto cambia rápido.

**Qué es:** App Store Connect y Apple Ads desde la terminal. 76 grupos de comandos sobre 1 200+ endpoints. Salida `json` cuando corre en pipe o CI (TTY-aware: `table` en terminal interactiva), `--dry-run` en lo que escribe, `--confirm` obligatorio en lo irreversible, comandos `doctor` de autodiagnóstico. Diseñado para agentes: `asc install-skills` copia 25 skills al directorio global de skills del agente.

**Por qué nos importa:** casi todo lo que en `/app-store-ready` está marcado *"manual — Phil pide al usuario que abra App Store Connect"* deja de serlo si `asc` está instalado y autenticado. Y `asc validate` rechaza `TODO`, `TBD`, `Lorem ipsum` en metadata — la misma regla que ya tenemos en `app-web-intake`, ahora también aplicada a lo que va a App Review.

---

## Instalación y detección

```bash
brew install asc                                   # o: curl -fsSL https://asccli.sh/install | bash
which asc && asc version                           # sonda: ¿está?
asc auth status --validate                         # ¿hay credenciales válidas?
asc doctor                                         # autodiagnóstico general
asc system-status                                  # ¿App Store Connect está caído hoy?
```

Regla del equipo: **si `asc` no está o no está autenticado, el flujo manual de cada rutina sigue siendo el válido.** `asc` acelera, nunca es requisito. La sonda va en la Fase 0 de `/app-store-ready` y en el arranque de Phil.

## Autenticación — territorio de Ivan

```bash
asc auth login --name "MyApp" --key-id ABC123 --issuer-id DEF456 --private-key /path/AuthKey.p8   # keychain (default en macOS)
asc auth login ... --bypass-keychain                                                              # CI / headless: config en disco
asc auth login --key-type individual ...                                                          # API key individual (sin issuer)
asc auth status --validate · asc auth doctor
```

Variables para CI: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (contenido del `.p8`). **El `.p8` nunca entra al repo** — ya está en `.gitignore` del equipo (`*.p8`); en CI vive en el secret store. Apple Ads usa credenciales OAuth aparte (`asc ads auth login`); StoreKit (retention messaging) usa su propia key (`asc storekit auth login`).

## Salida para agentes

```bash
asc <cmd> --output json --pretty        # siempre json cuando lo lee un agente
export ASC_DEFAULT_OUTPUT=json          # preferencia global
```

---

## Mapa comando → quién lo usa en el equipo

| Grupo | Comandos clave | Quién | Dónde en el flujo |
|-------|----------------|-------|-------------------|
| `auth` | `login`, `status --validate`, `doctor` | Ivan (credenciales), Phil (sonda) | `/app-store-ready` Fase 0–1 |
| `apps`, `localizations` | `apps list`, `localizations list --app --type app-info` | Phil, Kim, `/app-web-intake` | descripción verbatim, idiomas |
| `validate` | `validate --app --version [--deep]` | **Phil** | `/app-store-ready` Fase 4 — detecta `TODO`/`TBD`/`Lorem ipsum`; `--deep`: App Privacy publicada, agreements, primera suscripción adjunta, campos de review |
| `metadata` | `init --dir --version --locale`, `apply --dry-run`, `keywords audit --blocked-terms-file` | **Phil** | metadata como archivos en el repo (`./metadata/<locale>/…`), diff antes de aplicar, auditoría de keywords |
| `screenshots` | `plan --review-output-dir`, `apply --confirm`, `upload --device-type --replace`, `matrix --plan` | **Phil** | subir screenshots por tamaño; `matrix` genera la matriz por dispositivo |
| `video-previews` | | Phil | App Preview |
| `review` | `status --app`, `doctor --app` | **Phil** | estado de App Review, qué falta antes de enviar; modo `rejected` |
| `submit` | `status --version-id`, `cancel --confirm` | Phil | ciclo de vida de la submission |
| `publish` | `appstore --app --ipa --version --submit --confirm`, `testflight --group --wait --submit --confirm` | **Phil** (App Store) / **Bertrand** (TestFlight) | `/app-store-ready` Fase 9 — el `--confirm` de `publish appstore --submit` **solo** tras confirmación explícita del usuario |
| `status` | `status --app --watch` | Phil | monitoreo del release en vivo |
| `builds`, `testflight` | `builds upload`, `testflight feedback list --paginate`, `testflight crashes list --sort -createdDate`, `testflight crashes log --submission-id` | **Bertrand** | `/optimize-app` Fase 1 (crashes reales), TestFlight, `/global-fix` Fase 0 (evidencia) |
| `signing`, `bundle-ids` | certificados, perfiles, capabilities | Craig, Ivan | `/app-store-ready` Fase 1 identificadores |
| `xcode` | `inject --manifest .asc/deployment.json --set version= --set build_number=`, `build`, `test`, `archive`, `export` | Craig, Woz | pipeline local reproducible |
| `xcode-cloud` | trigger, rerun, wait | **Craig** | CI |
| `workflow` | `validate`, `run --dry-run <name> VERSION:x.y.z`, `.asc/workflow.json` | **Craig** | pipeline declarativo local Xcode → TestFlight → App Store |
| `storekit` | `auth login`, `auth doctor --environment sandbox --network`, `retention-messaging messages list`, `retention-messaging endpoint view` | **Kara** | ofertas de retención / win-back (van en la 1.1, nunca en la inicial) |
| `ads` | `auth login`, `auth discover`, `campaigns find --file query.json`, `reports apps campaigns --file report.json` | **Frederick** | momento 2 (campañas ASA) y 3 (ROAS por keyword y país) |
| `system-status` | | Steve, Phil | antes de culpar al build |
| `telemetry` | | Ivan | apagar telemetría de la herramienta si la política lo exige |

---

## Patrones de diseño que adoptamos (más allá de la herramienta)

1. **`--dry-run` antes de `--confirm`.** Todo lo que escribe en ASC se muestra primero. Coincide con nuestro contrato `plan → go <n>`.
2. **`doctor` como sonda.** Autodiagnóstico barato antes de trabajar — igual que la sonda de `/global-audit` y la del MCP de Xcode.
3. **Metadata como archivos versionados.** `asc metadata init` deja `./metadata/<locale>/` en el repo; el `APPSTORE.md` de Phil pasa a ser la fuente que se vuelca ahí, y el diff de `apply --dry-run` es la revisión.
4. **`validate` rechaza placeholders.** `TODO`, `TBD`, `FIXME`, `Lorem ipsum` en nombre, subtítulo, descripción, keywords, promo o What's New = bloqueante. Misma regla que `app-web-intake`: `TBD` es correcto en el intake, **nunca** en lo que se envía.
5. **JSON en pipe, tabla en TTY.** Los agentes piden `--output json`; el usuario ve tablas.
6. **Skills del proveedor, no duplicadas.** `asc install-skills` trae 25 skills mantenidas por el proyecto (CLI, Apple Ads, Xcode builds, TestFlight, metadata sync, signing, workflows). El equipo las referencia, no las copia.

## Lo que NO cambia por tener `asc`

- Los gates de Ivan y Kate. `asc validate --deep` comprueba que App Privacy esté *publicada*; no que sea *correcta*.
- La confirmación explícita del usuario para *Submit for Review*. `asc publish appstore --submit --confirm` se ejecuta **solo** después de ese "envíalo".
- La estrategia de 48 h: MVP en la 1.0, review notes humanas, video demo. `asc` sube; no decide qué subir.
