---
name: harvest-learnings
description: "Cosecha de learnings de todos los proyectos del usuario. App Master lee los PROJECT_LEARNINGS.md de cada app en GitSync/, separa incidentes de preferencias, agrupa lo repetido entre apps, descarta lo ya decidido según LEARNINGS_LEDGER.md, y decide solo lo técnico con criterios fijos y solo te pregunta preferencias y cambios de código, en lenguaje simple. Lo aprobado sube por la escalera: KNOWN_ISSUES.md o PREFERENCES.md, regla en el skill del agente, y si se puede, default en el código. Solo corre en el repo AppleAppLab. Úsalo con 'cosecha learnings', 'revisa lo aprendido', 'qué se repite en mis apps'."
---

# /harvest-learnings — Lo que una app aprende, lo saben todas

Rutina de App Master. Cierra el ciclo de memoria del equipo:

```
captura automática en cada app → /harvest-learnings → triage contigo → escalera (doc → skill → código) → /update-team → la siguiente app ya lo sabe
```

**Solo en el repo AppleAppLab.** Es el único lugar desde donde se escribe la memoria global. No se instala en los proyectos.

---

## Modos

| Comando | Qué hace |
|---------|----------|
| `/harvest-learnings` | Cosecha completa: todo lo nuevo o cambiado desde la última vez |
| `/harvest-learnings <proyecto>` | Solo ese proyecto |
| `/harvest-learnings prefs` | Solo preferencias |
| `/harvest-learnings status` | Cuánto hay pendiente por proyecto, sin triage |
| `/harvest-learnings ask-all` | Te pregunta todo, incluido lo técnico |
| `/harvest-learnings undo <ID>` | Revierte una decisión |

---

## Fase 1 — Recolectar (sin tocar nada)

```bash
python3 - <<'PY'
import pathlib, re, hashlib
root = pathlib.Path.home() / "Documents/GitSync"
ledger = pathlib.Path("LEARNINGS_LEDGER.md").read_text() if pathlib.Path("LEARNINGS_LEDGER.md").exists() else ""
seen = {(m.group(1).strip(), m.group(2).strip(), m.group(3).strip())
        for m in re.finditer(r"^\| ([^|]+) \| ([^|]+) \| ([^|]+) \|", ledger, re.M)}
files = [f for f in root.glob("*/Docs/PROJECT_LEARNINGS.md")] + [f for f in root.glob("*/PROJECT_LEARNINGS.md")]
head = re.compile(r"^## ([A-Z][A-Z0-9]*-[A-Z0-9-]*\d) — (.+)$", re.M)
field = lambda body, name: (re.search(rf"^- \*\*{name}:\*\* *(.+)$", body, re.M) or [None, ""])[1].strip()
rows, total = [], 0
for f in sorted(set(files)):
    proj = f.parent.name if f.parent.name != "Docs" else f.parent.parent.name
    text = f.read_text(errors="ignore")
    parts = head.split(text)
    for i in range(1, len(parts), 3):
        eid, title, body = parts[i], parts[i+1].strip(), parts[i+2]
        if "AAAA" in eid: continue
        total += 1
        symptom = field(body, "Síntoma")
        fp = hashlib.sha1((title + symptom).encode()).hexdigest()[:8]
        if (proj, eid, fp) in seen: continue
        kind = field(body, "Tipo") or ("preferencia" if re.search(r"\bpreferencia\b", body, re.I) else "propuesta" if re.search(r"\bpropuesta\b", body, re.I) else "incidente")
        state = re.search(r"`(hypothesis|conditional|verified|deprecated|observed)`", field(body, "Owner / status") + field(body, "Estado"))
        rows.append((proj, eid, fp, kind, state.group(1) if state else "?", field(body, "Categoría")[:24], field(body, "Fingerprint")[:40], title[:90], symptom[:140]))
print(f"{total} entradas en {len(set(files))} proyectos · {len(rows)} nuevas o cambiadas")
for r in rows: print(" | ".join(r))
PY
```

Lee también `KNOWN_ISSUES.md`, `PREFERENCES.md` y el ledger: lo que ya está cubierto no se vuelve a preguntar.

**Recetas 3D de Ed.** Además de las entradas, lista las recetas locales de cada app y su estado; las propuestas `team/recipes3d/<id>` de los learnings apuntan a ellas:

```bash
for f in ~/Documents/GitSync/*/Docs/Design/3D/recipes/*.md; do
  [ -e "$f" ] || continue
  app=$(echo "$f" | sed -E 's#.*/GitSync/([^/]+)/Docs/.*#\1#')
  echo "$app | $(basename "$f" .md) | $(grep -m1 -oE '\*\*Estado:\*\* *[a-z]+' "$f" | awk '{print $2}') | $(grep -c '^| .* | .* | [0-9-]\{10\} |' "$f") aprobaciones"
done
```

Solo lectura: App Master nunca escribe en las recetas de una app.

## Fase 2 — Separar y agrupar

1. **Tipo.** Cada entrada es un **incidente** (algo falló, tiene causa y fix), una **preferencia** (cómo le gusta al usuario: un material, una opacidad, un orden, un estilo de texto, un flujo) o una **propuesta** (Steve o un especialista propone cambiar un skill, una regla o un proceso del equipo; los agentes de una app no editan skills, ver "Jerarquía" en `CLAUDE.md`). Si la entrada no lo dice, lo decides por el contenido.
2. **Grupos.** Junta las entradas que describen lo mismo aunque cada proyecto le haya puesto otro nombre: primero por fingerprint, después por síntoma y causa. "TextField no responde", "campo bloqueado al abrir el sheet" y "no puedo escribir en el buscador" son un grupo si la causa es el foco.
3. **Ranking.** Ordena por número de apps donde aparece × impacto. Lo visto en 3 apps va antes que lo visto en 1.
4. **Contra lo existente.** Por grupo: ¿ya existe un `AAL-*` o `PREF-*` que lo cubre? ¿Lo contradice? ¿Lo amplía a otra versión de OS?

## Fase 3 — Propuesta por grupo

Para cada grupo, una propuesta con tres partes:

- **Regla en una frase**, accionable: "Al presentar un sheet o ventana con campos, el primer campo recibe foco con `@FocusState` en `.onAppear`" — no "cuidado con el foco".
- **Evidencia:** proyectos e IDs de origen, y si está `verified` en alguno.
- **Escalera propuesta**, el escalón más alto que aguanta:

| Escalón | Cuándo | Ejemplo |
|---------|--------|---------|
| `doc` | Siempre. Incidentes a `KNOWN_ISSUES.md`, preferencias a `PREFERENCES.md` | `AAL-MAC-016`, `PREF-UI-001` |
| `skill` | Hay un agente que lo puede aplicar en cada app | Checklist de Woz, test de Bertrand, regla de Jonny |
| `code` | Se puede resolver de una vez en AppleAppLabUI, el tema por defecto o el scaffold | Foco automático dentro de `LabTextField`; tema por defecto en Frost |

Reglas de calidad que App Master sigue igual que antes: un incidente solo sube a `verified` con verificación explícita en algún proyecto; una `hypothesis` puede quedar como `doc` marcada así, nunca como `code`. Una **calibración visual vista en una sola app sigue siendo local**; se vuelve preferencia global cuando aparece en dos o más apps o el usuario la declara como "siempre".

## Fase 4 — App Master decide, tú solo ves lo tuyo

El usuario no tiene por qué entender un incidente de XcodeGen o de Keychain. **App Master decide solo todo lo técnico** con los criterios de abajo y pregunta únicamente lo que es gusto del usuario o lo que cambia sus apps de forma visible.

### Lo que App Master decide sin preguntar

Cada grupo pasa por estas preguntas en orden. La primera que aplica decide.

| # | Pregunta | Si la respuesta es sí |
|---|----------|-----------------------|
| 1 | ¿Ya lo cubre un `AAL-*` o `PREF-*`? | **Fusionar**: se añade el proyecto como evidencia a la entrada existente |
| 2 | ¿Es lógica de negocio de esa app? (cálculos, reglas de su dominio, una API que solo ella usa, nombres de sus modelos) | **Descartar**: se queda en el proyecto |
| 3 | ¿Está `deprecated`, o es `hypothesis` vista en una sola app? | **Diferir**: queda en el ledger y vuelve si aparece en otra app o pasa a `verified` |
| 4 | ¿Es `verified` o `conditional` y trata de algo que toda app Apple puede tocar? (SwiftUI, AppKit, SwiftData, CloudKit, Keychain, concurrencia, XcodeGen, firma, tests, Xcode, App Store, seguridad de procesos) | **Quedarse** como `doc` en `KNOWN_ISSUES.md`, y como `skill` en el agente que lo previene (Woz, Bertrand, Avie, Ivan, Craig) |
| 5 | ¿Apareció en dos o más apps, aunque sea `hypothesis`? | **Quedarse** como `doc` marcado `hypothesis`, con todas las apps como evidencia |
| 6 | Ninguna de las anteriores | **Diferir** |

Ejemplos con entradas reales:

- "Banxico responde 400 con token inválido" → regla 2, se descarta: solo Fintrol usa Banxico.
- "`LoanEngine` off-by-one en plazo" → regla 2, se descarta: es el cálculo de esa app.
- "XcodeGen genera `TEST_HOST` incorrecto en targets multiplataforma" → regla 4, se queda: le pasa a cualquier app con iOS y macOS.
- "Tests de Keychain fallan en el simulador sin firma" → regla 4, se queda, con una regla para Bertrand.
- "Hardened runtime bloquea Python de yt-dlp", `hypothesis` en una app → regla 3, se difiere.

### Recetas 3D (Ed)

Una receta local sube a `Recipes3D/` (global) cuando está `verified` en **dos o más assets**, de una app o de varias, o cuando Yuno la marcó con "siempre" (⭐ en `RECIPE.md`). Si dos apps tienen recetas que hacen lo mismo, se fusionan en una con los parámetros que más veces se aprobaron, y el rango probado queda en la tabla.

- **Técnica** (`export`, `render`, `shape` de topología: presets de glTF/STL, settings de Cycles, bevel squircle): la decide App Master con la tabla de arriba, como un incidente verificado.
- **De gusto** (`light`, `material`, `camera`, `scene`): se le pregunta a Yuno, con el render final del asset donde se aprobó y en lenguaje simple: *"En NewProject y Fintrol te gustó la luz de estudio suave con la principal grande arriba a la izquierda. ¿La dejo como la luz de partida para todos los renders?"*
- Una preferencia `pref/3d/<tema>` vista en dos apps va a `PREFERENCES.md` como cualquier otra preferencia, y si encaja con una receta, se aplica también a la receta.

### Lo único que se le pregunta al usuario

1. **Preferencias.** Material de ventana, opacidad, tono de textos, orden de pantallas, cualquier gusto. Solo el usuario sabe si es "siempre" o fue cosa de esa app.
2. **Cambios de código en AppleAppLabUI o en el tema por defecto.** Cambian cómo se ven o se comportan todas sus apps.
3. **Contradicciones.** Una entrada nueva choca con una regla que el usuario ya aprobó.
4. **Propuestas que cambian cómo trabaja el equipo.** El rol de un agente, el orden del flujo, qué se pregunta y qué no. Una propuesta que solo añade una línea técnica a un checklist (Woz, Bertrand, Ivan) la decide App Master con la tabla de arriba, como un incidente.

Las preguntas van **en lenguaje de usuario, sin jerga**: qué notaría en sus apps, no cómo se implementa.

> ❌ "¿Promover INSP-UI-001 (`NSImageView` swallows drop) a `KNOWN_ISSUES` con escalón skill?"
> ✅ "En Inspoflow, arrastrar fotos desde Finder no hacía nada si soltabas encima de una tarjeta. ¿Quieres que todas tus apps Mac acepten soltar archivos en cualquier parte de la tarjeta?"

Con `AskUserQuestion`, en tandas de hasta 4, empezando por lo visto en más apps. Opciones: **Sí, en todas mis apps** · **Solo en ese tipo de app** · **No, fue cosa de esa app** · *Otro* para que lo diga con sus palabras.

### Reporte de lo decidido

Antes de aplicar, App Master muestra **una tabla corta** de lo que decidió solo: cuántos se quedaron, se fusionaron, se descartaron y se difirieron, y una línea en lenguaje simple por cada "se queda". No pide aprobación de esa tabla. Si el usuario dice "regresa X" o "ese no", se revierte en ese momento o con `/harvest-learnings undo <ID>`.

### Modos

- `/harvest-learnings` — App Master decide lo técnico, tú lo tuyo (por defecto)
- `/harvest-learnings ask-all` — te pregunta todo, como antes
- `/harvest-learnings undo <ID>` — revierte una decisión: quita la entrada promovida y marca el ledger `reverted`

## Fase 5 — Aplicar la escalera

Por cada grupo aprobado, en este orden:

1. **doc** — entrada nueva o actualizada en `KNOWN_ISSUES.md` (`AAL-*`, formato existente) o `PREFERENCES.md` (`PREF-*`, formato del archivo) + fila en su índice.
2. **skill** — la regla en una o dos líneas en el skill del agente que la aplica, citando el ID. Sin duplicar el detalle: el skill apunta al documento.
3. **code** — cambio en `Packages/AppleAppLabUI`, `Themes/` o el scaffold. Antes de tocar código, App Master lo muestra y pide confirmación; después `swift build` y `swift test` del paquete en verde y, si afecta a una app del repo, su build. Si el cambio es grande, queda anotado como pendiente con dueño en lugar de hacerse a medias.
4. **Receta 3D** — `Recipes3D/<id>.md` (+ `<id>.py` copiado de la app de origen, sin colores de marca fijos) con estado `verified`, *Probada en* con todas las apps de origen y el *Por qué quedó así* de sus `RECIPE.md`; fila nueva en la tabla de `Recipes3D/README.md` y sus archivos en `Recipes3D/INDEX` (lo que `setup.sh` descarga). Si reemplaza a otra, la vieja queda `deprecated` con enlace. Ed la lee desde `.appleapplab/Recipes3D/` tras `/update-team`.

Después:

- Una fila por entrada de origen en `LEARNINGS_LEDGER.md` con decisión y destino.
- En el `PROJECT_LEARNINGS.md` de cada proyecto de origen **no** se escribe: el ledger lleva la cuenta desde aquí.
- `VERSION` sube un patch; commit; push. Los proyectos lo reciben con `/update-team`.

## Cierre

> "Cosecha: 77 entradas en 11 apps. Decidí solo: 14 se quedan, 6 se fusionan, 41 se descartan por ser de una sola app, 9 diferidas. Te pregunté 4 preferencias: aprobaste 3. Escalera: 3 a code (foco en `LabTextField`, tema por defecto en Frost, …), 2 a skill, 1 doc. Ledger al día. Commit `abc1234`, v1.19.1 — corre `/update-team` en tus apps para recibirlo."

## Lo que NO hace

- No escribe en los repos de los proyectos: App Master nunca entra a una app
- No te pregunta lo técnico: lo decide con criterios fijos y te lo reporta
- No cambia código ni preferencias sin tu respuesta
- No convierte una `hypothesis` en código
- No borra historia: lo superado se marca `deprecated` y se enlaza
