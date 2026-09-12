---
name: link-todocky
description: "Cierra el enlace inverso entre este repo y su proyecto en Todocky. El usuario copia el código de 'Copy project number' en el menú del proyecto en Todocky y lo pega: /link-todocky <code>. Llama link_repo_to_project con la ruta absoluta del repo y el external_key consciente de worktrees, guarda el projectId en .claude/todocky-link.json y con eso 'Implement with Claude' funciona desde Todocky. El código es de un solo uso. Requiere el MCP de Todocky conectado. Úsalo cuando el usuario pegue un código de Todocky o diga 'enlaza este repo a Todocky'."
---

# /link-todocky `<code>` — que Todocky sepa dónde vive este repo

Comando corto, no una rutina. Cierra la **dirección inversa** del enlace con Todocky:

| Dirección | Quién la hace | Qué logra |
|-----------|---------------|-----------|
| Repo → Todocky | Steve, solo, al arrancar (`steve/SKILL.md` §0.5) | El repo tiene un proyecto real en el tablero y las etapas de cada plan aprobado aparecen como tasks |
| **Todocky → repo** | **este comando**, con un código que el usuario copia desde la app | Todocky conoce la ruta local del repo — es lo que hace funcionar su botón **"Implement with Claude"** |

Sin este comando, Steve puede escribir en el tablero pero Todocky no puede abrir Claude Code en la carpeta correcta.

---

## Uso

```
/link-todocky ABC123
```

El usuario obtiene el código en Todocky: menú del proyecto → **Copy project number**. Es un código corto y **de un solo uso**.

Si el usuario escribe `/link-todocky` sin código, pídeselo en una línea: *"Copia el código desde 'Copy project number' en el menú del proyecto en Todocky y pégamelo: `/link-todocky <code>`."*

---

## Pasos

1. **Comprueba el MCP.** Busca con ToolSearch `mcp__todocky__*`. Si no aparece, el usuario no tiene Todocky conectado en esta sesión: dilo una vez — *"Todocky no está conectado en esta sesión. Conéctalo (claude.ai → conectores, o `claude mcp` en una terminal interactiva) y vuelve a pegar el código — necesitarás uno fresco."* — y termina. No inventes un enlace.
2. **Ruta del repo.** `git rev-parse --show-toplevel`; si no es un repo git, el cwd. Siempre absoluta.
3. **`external_key`.** Exactamente la derivación consciente de worktrees de `steve/SKILL.md` §0.5: `--git-common-dir` si es worktree → `git:` + remoto normalizado (sin protocolo ni credenciales, sin `.git`, host en minúsculas) → si no hay remoto, `root-commit:` + commit raíz → si no es git, el `localKey` cacheado en `.claude/todocky-link.json` o un UUID nuevo. Si el cache ya trae `externalKey`, úsalo.
4. **Llama** `link_repo_to_project(link_code: <code>, repo_path: <ruta absoluta>, external_key: <el calculado>)`.
5. **Guarda.** Escribe o actualiza `.claude/todocky-link.json` con el `projectId` (y `projectName`, `workspaceId`, `workspaceName` si vienen), `externalKey`, `cachedAt`. Si `.claude/todocky-link.json` no está en `.gitignore`, añádelo — el ID es de esta instalación, no viaja con el repo.
6. **Confirma** en una línea: *"Enlazado: este repo ↔ proyecto **[nombre]** en Todocky. 'Implement with Claude' ya funciona desde el tablero."*

---

## Errores que sí pasan

| Respuesta | Qué significa | Qué haces |
|-----------|---------------|-----------|
| `No project found for that code.` | El código ya se usó o caducó — es de un solo uso | Pide uno fresco desde Todocky. **No reintentes con el mismo código** |
| Falta de permiso | Todocky pide confirmar el acceso la primera vez desde una identidad nueva | Dilo una vez: *"Todocky pidió confirmar el acceso — apruébalo en la app y vuelve a pegar un código fresco."* |
| Rate limit | ~20 escrituras/minuto por identidad | Espera; no reintentes en loop |
| El `projectId` devuelto no coincide con el cacheado | El cache era de otro proyecto o estaba desactualizado | Sobreescribe el cache con el nuevo — no es un error. Si el cache trae `"_note"` de enlace manual (proyecto anterior a este feature), respétalo: menciona la discrepancia al usuario y no lo pises sin su OK |

---

## Lo que este comando NO hace

- No crea proyectos ni tasks — eso es `find_or_create_project` / `upsert_task` desde Steve
- No toca tasks que el usuario escribió a mano
- No reutiliza códigos ni intenta adivinarlos
- No enlaza sin el MCP conectado
