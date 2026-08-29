# update-team — Sincronizar equipo con AppleAppLab

Actualiza todos los skills del equipo, temas y catálogo de patterns a la versión más reciente de AppleAppLab.

---

## Qué hace este skill

Ejecuta en bash:

```bash
curl -s https://raw.githubusercontent.com/hiyuno/AppleAppLab/main/setup.sh | bash -s --update
```

Eso es todo. `setup.sh` sobreescribe los skills, PATTERNS.md, Themes/, AGENTS.md y KNOWN_ISSUES.md con la versión más reciente de GitHub. Los archivos del proyecto (PRD.md, TRD.md, CLAUDE.md con contenido propio, PROJECT_LEARNINGS.md) no se tocan.

---

## Cuándo usar este skill

- Después de que AppleAppLab recibe actualizaciones (nuevos agentes, nuevas reglas, nuevos temas)
- Si un agente del equipo se comporta de forma inesperada y sospechas que tiene una versión vieja
- Antes de un ciclo importante de trabajo en un proyecto antiguo

---

## Qué se actualiza

| Qué | Dónde queda |
|-----|------------|
| Skills del equipo (steve, woz, jonny…) | `.claude/skills/*.md` |
| Catálogo de componentes | `PATTERNS.md` |
| Temas predefinidos | `Themes/*.json` + `Themes/THEMES.md` |
| Snapshot de issues globales | `.appleapplab/KNOWN_ISSUES.md` |
| AGENTS.md (Codex) | `AGENTS.md` |
| Versión instalada | `.appleapplab/VERSION` |

## Qué NO se toca

- `PROJECT_LEARNINGS.md` — preservado siempre
- `CLAUDE.md` — si ya tiene el bloque de Steve, no se modifica
- Cualquier archivo del proyecto (`PRD.md`, `TRD.md`, código Swift, etc.)
