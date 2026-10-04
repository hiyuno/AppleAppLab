---
name: update-team
description: "Sincroniza este proyecto con la última versión de AppleAppLab. Descarga skills, PATTERNS.md, temas y KNOWN_ISSUES. Solo descarga, no hace commit ni push. Úsalo cuando AppleAppLab reciba cambios."
---

# update-team — Sincronizar equipo con AppleAppLab

Actualiza todos los skills del equipo, temas y catálogo de patterns a la versión más reciente de AppleAppLab.

---

## Qué hace este skill

Ejecuta en bash:

```bash
curl -s https://raw.githubusercontent.com/hiyuno/AppleAppLab/main/setup.sh | bash /dev/stdin --update
```

Eso es todo. `setup.sh` sobreescribe los skills, `AGENTS.md` y todo lo de `.appleapplab/` (PATTERNS.md, Themes/, Research/, KNOWN_ISSUES.md) con la versión más reciente de GitHub. Los documentos del proyecto en `Docs/` (PRD, TRD, auditorías, PROJECT_LEARNINGS…) y `CLAUDE.md` con contenido propio no se tocan. Si detecta copias viejas de PATTERNS.md, Themes/ o Research/ en la raíz, avisa para correr `/clean-folder-project docs`.

Si hay Xcode ≥ 27, también refresca las skills oficiales de Apple en `~/.claude/xcode-skills/` — solo cuando el build de Xcode cambió respecto al sello `.xcode-build` — y las enlaza en `~/.claude/skills/`. Si el MCP `xcode` no está registrado en Claude Code, imprime el comando; no lo registra por ti.

**IMPORTANTE:** Este skill solo descarga archivos. No hace commit, no hace push, no sube nada a ningún repositorio. Cuando termine, confirma al usuario qué versión se instaló y detente. No preguntes sobre git.

---

## Cuándo usar este skill

- Después de que AppleAppLab recibe actualizaciones (nuevos agentes, nuevas reglas, nuevos temas)
- Si un agente del equipo se comporta de forma inesperada y sospechas que tiene una versión vieja
- Antes de un ciclo importante de trabajo en un proyecto antiguo

---

## Qué se actualiza

| Qué | Dónde queda |
|-----|------------|
| Skills del equipo (steve, woz, jonny…) | `.claude/skills/*/SKILL.md` |
| Catálogo de componentes | `.appleapplab/PATTERNS.md` |
| Temas predefinidos | `.appleapplab/Themes/*.json` + `THEMES.md` |
| Snapshot de issues globales | `.appleapplab/KNOWN_ISSUES.md` |
| Documentación de referencia (HIG, Xcode 27 MCP, asc, ASO…) | `.appleapplab/Research/` |
| Skills oficiales de Apple (Xcode ≥ 27) | `~/.claude/skills/<name>` → `~/.claude/xcode-skills/` — re-export solo si cambió el build de Xcode |
| AGENTS.md (Codex) | `AGENTS.md` |
| Versión instalada | `.appleapplab/VERSION` |

## Qué NO se toca

- `Docs/PROJECT_LEARNINGS.md` (o en la raíz si el proyecto no se migró) — preservado siempre
- `~/.claude/xcode-skills/` si Xcode < 27 o el build no cambió — no re-exporta ni borra
- `CLAUDE.md` — si ya tiene el bloque de Steve, no se modifica
- Cualquier archivo del proyecto (`PRD.md`, `TRD.md`, código Swift, etc.)
