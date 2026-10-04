---
name: harvest-learnings
description: "Cosecha de learnings de todos los proyectos del usuario. App Master lee los PROJECT_LEARNINGS.md de cada app en GitSync/, separa incidentes de preferencias, agrupa lo repetido entre apps, descarta lo ya decidido según LEARNINGS_LEDGER.md, y hace triage en el chat en tandas de 4: quedarse, descartar o editar. Lo aprobado sube por la escalera: KNOWN_ISSUES.md o PREFERENCES.md, regla en el skill del agente, y si se puede, default en el código. Solo corre en el repo AppleAppLab. Úsalo con 'cosecha learnings', 'revisa lo aprendido', 'qué se repite en mis apps'."
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
        kind = field(body, "Tipo") or ("preferencia" if re.search(r"\bpreferencia\b", body, re.I) else "incidente")
        state = re.search(r"`(hypothesis|conditional|verified|deprecated|observed)`", field(body, "Owner / status") + field(body, "Estado"))
        rows.append((proj, eid, fp, kind, state.group(1) if state else "?", field(body, "Categoría")[:24], field(body, "Fingerprint")[:40], title[:90], symptom[:140]))
print(f"{total} entradas en {len(set(files))} proyectos · {len(rows)} nuevas o cambiadas")
for r in rows: print(" | ".join(r))
PY
```

Lee también `KNOWN_ISSUES.md`, `PREFERENCES.md` y el ledger: lo que ya está cubierto no se vuelve a preguntar.

## Fase 2 — Separar y agrupar

1. **Tipo.** Cada entrada es un **incidente** (algo falló, tiene causa y fix) o una **preferencia** (cómo le gusta al usuario: un material, una opacidad, un orden, un estilo de texto, un flujo). Si la entrada no lo dice, lo decides por el contenido.
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

## Fase 4 — Triage contigo

Con `AskUserQuestion`, en tandas de hasta 4 grupos, empezando por los de más apps. Cada pregunta muestra la regla, en cuántas apps se vio y el escalón propuesto. Opciones:

- **Quedarse** — con el escalón propuesto
- **Quedarse solo como doc** — sin regla de skill ni código
- **Descartar** — fue algo de esa app, no se repite
- *Otro* — el usuario edita la regla o el alcance con sus palabras

Lo que el usuario edita se reescribe así antes de promover. No se promueve nada sin respuesta.

## Fase 5 — Aplicar la escalera

Por cada grupo aprobado, en este orden:

1. **doc** — entrada nueva o actualizada en `KNOWN_ISSUES.md` (`AAL-*`, formato existente) o `PREFERENCES.md` (`PREF-*`, formato del archivo) + fila en su índice.
2. **skill** — la regla en una o dos líneas en el skill del agente que la aplica, citando el ID. Sin duplicar el detalle: el skill apunta al documento.
3. **code** — cambio en `Packages/AppleAppLabUI`, `Themes/` o el scaffold. Antes de tocar código, App Master lo muestra y pide confirmación; después `swift build` y `swift test` del paquete en verde y, si afecta a una app del repo, su build. Si el cambio es grande, queda anotado como pendiente con dueño en lugar de hacerse a medias.

Después:

- Una fila por entrada de origen en `LEARNINGS_LEDGER.md` con decisión y destino.
- En el `PROJECT_LEARNINGS.md` de cada proyecto de origen **no** se escribe: el ledger lleva la cuenta desde aquí.
- `VERSION` sube un patch; commit; push. Los proyectos lo reciben con `/update-team`.

## Cierre

> "Cosecha: 83 entradas en 11 apps, 31 nuevas. 9 grupos: aprobaste 6, descartaste 2, 1 quedó como doc. Escalera: 3 a code (foco en `LabTextField`, tema por defecto en Frost, …), 2 a skill, 1 doc. Ledger al día. Commit `abc1234`, v1.19.1 — corre `/update-team` en tus apps para recibirlo."

## Lo que NO hace

- No escribe en los repos de los proyectos
- No promueve sin tu respuesta en el triage
- No convierte una `hypothesis` en código
- No borra historia: lo superado se marca `deprecated` y se enlaza
