# Codex Agent Guidance Improvement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mejorar la comprensión de Codex sobre los roles, skills y flujo de AppleAppLab sin modificar archivos de Claude, Cursor ni Gemini.

**Architecture:** `AGENTS.md` será el punto de entrada obligatorio y describirá el contrato operativo de Codex: clasificación de tareas, selección mínima de roles, entradas/salidas, gates y límites de autoridad. Se añadirá una guía Codex-only en `.codex/` para conservar detalles operativos sin duplicar toda la documentación de `.claude/skills/`.

**Tech Stack:** Markdown, repositorio AppleAppLab, skills locales de Codex.

---

## Alcance protegido

Archivos permitidos:

- `AGENTS.md`
- `.codex/README.md`
- `.codex/roles.md`
- `.codex/skill-routing.md`
- `docs/superpowers/plans/2026-08-25-codex-agent-guidance.md`

Archivos explícitamente fuera de alcance:

- `.claude/**`
- `.cursor/**`
- `CLAUDE.md`
- `GEMINI.md`

No se copiarán skills completos de Claude. Codex usará las skills disponibles en su runtime y las instrucciones Codex-only servirán para enrutar y contextualizar su uso.

## Task 1: Reescribir `AGENTS.md` como contrato de entrada para Codex

**Files:**
- Modify: `AGENTS.md`

- [x] **Step 1: Preservar el inventario de roles existente**

Mantener los roles actuales, pero reformular cada entrada con cuatro campos: responsabilidad, entrega, cuándo activar y qué no debe hacer. El rol Steve seguirá siendo el orquestador y no implementará código, diseño ni auditorías especializadas.

- [x] **Step 2: Añadir clasificación de tareas**

Agregar una tabla explícita para clasificar cada petición como análisis, idea nueva, feature, bug, seguridad, revisión, solo código, solo diseño o lanzamiento. Cada categoría debe apuntar a la cadena mínima de roles correspondiente.

- [x] **Step 3: Añadir contrato de handoff**

Definir que cada agente recibe: petición original, evidencia inspeccionada, documentos relevantes, restricciones, salida esperada y criterio de finalización. Definir también que el agente debe devolver resumen, archivos tocados, verificaciones y bloqueos.

- [x] **Step 4: Añadir reglas de decisión para skills**

Documentar prioridad entre skills de proceso y dominio. Por ejemplo: brainstorming antes de construir, debugging antes de corregir, TDD antes de implementar, y verification-before-completion antes de declarar terminado.

- [x] **Step 5: Añadir límites de autoridad de Codex**

Dejar explícito que una petición de análisis no autoriza cambios; que no se deben tocar integraciones de Claude/Cursor/Gemini; que no se deben inventar archivos de salida; y que los cambios destructivos o externos requieren autorización proporcional.

## Task 2: Crear `.codex/README.md` como mapa de navegación

**Files:**
- Create: `.codex/README.md`

- [x] **Step 1: Documentar el propósito**

Explicar que `.codex/` contiene únicamente orientación adicional para Codex dentro de este repositorio y no es una fuente de verdad para Claude, Cursor o Gemini.

- [x] **Step 2: Documentar el orden de lectura**

Establecer este orden: `AGENTS.md` → instrucciones del task → documentos existentes del proyecto → `.codex/roles.md` → `.codex/skill-routing.md` → skill específica aplicable.

- [x] **Step 3: Documentar la regla de no duplicación**

Indicar que los detalles específicos de un especialista deben permanecer en su skill instalada; estos archivos solo deben contener contexto AppleAppLab, routing y contratos de salida.

## Task 3: Crear `.codex/roles.md` con contratos de roles

**Files:**
- Create: `.codex/roles.md`

- [x] **Step 1: Definir formato uniforme por rol**

Para cada rol incluir: misión, activa cuando, lee, produce, criterios de terminado, dependencias y límites.

- [x] **Step 2: Separar roles de decisión, implementación y verificación**

Agrupar los roles en:

1. Dirección: Steve, Scott.
2. Decisión: Avie, Ivan, Jonny, Kate, Kim, Tim, John, Kara, Eve, Craig.
3. Implementación: Woz.
4. Verificación: Larry, Bertrand, Sarah, Chris, Ivan.

La clasificación debe aclarar que Ivan puede aparecer en varios puntos del flujo con tareas distintas.

- [x] **Step 3: Registrar salidas concretas**

Mapear los documentos esperados (`PRD.md`, `TRD.md`, diseños, auditorías, `TEST_PLAN.md`, etc.) y permitir explícitamente una salida de “no aplica” cuando el alcance no la requiera.

## Task 4: Crear `.codex/skill-routing.md` para seleccionar skills con precisión

**Files:**
- Create: `.codex/skill-routing.md`

- [x] **Step 1: Añadir matriz de activación**

Incluir señales de activación para skills de AppleAppLab y skills generales de Codex: macOS, macOS design, interface design, systematic debugging, TDD, verification, writing plans, documents, spreadsheets, presentations, browser y deployment.

- [x] **Step 2: Definir exclusiones**

Indicar cuándo no activar una skill: no usar diseño para un análisis puramente técnico, no usar despliegue sin petición explícita, no usar monetización/analytics/IA si la app no tiene esas capacidades, y no usar skills web para una app Apple nativa.

- [x] **Step 3: Definir combinaciones válidas**

Documentar combinaciones frecuentes, por ejemplo:

- nueva app: brainstorming → writing-plans → macOS design o interfaz → implementación → verification;
- bug: systematic-debugging → skill de plataforma → verification;
- revisión: auditoría específica → verification;
- cambio de skill: skill-creator → writing-skills → validación.

## Task 5: Verificación y revisión de alcance

**Files:**
- Verify: `AGENTS.md`
- Verify: `.codex/README.md`
- Verify: `.codex/roles.md`
- Verify: `.codex/skill-routing.md`

- [x] **Step 1: Comprobar enlaces y rutas**

Ejecutar:

```bash
rg -n "\.claude|\.cursor|CLAUDE\.md|GEMINI\.md" AGENTS.md .codex
```

Resultado esperado: solo referencias de exclusión o contexto, ninguna instrucción que pida modificar esos archivos.

- [x] **Step 2: Comprobar placeholders**

Ejecutar:

```bash
rg -n "TODO|TBD|FIXME|Similar to Task|write tests for the above" AGENTS.md .codex
```

Resultado esperado: no hay placeholders de implementación.

- [x] **Step 3: Comprobar integridad del worktree**

Ejecutar:

```bash
git diff --name-only
git status --short
```

Resultado esperado: solo aparecen los archivos Codex permitidos y cualquier cambio previo del usuario se conserva.

- [x] **Step 4: Ejecutar una prueba mental de routing**

Validar tres peticiones representativas: “analiza este repo”, “corrige un crash SwiftUI” y “mejora una skill”. Cada una debe seleccionar una cadena clara, no activar roles irrelevantes y producir una salida verificable.

## Criterios de aceptación

- `AGENTS.md` explica cómo Codex decide qué rol y skill usar.
- Cada rol tiene responsabilidad, entrada, salida, límites y criterio de terminado.
- Las skills de proceso tienen prioridad explícita cuando corresponde.
- Las instrucciones no ordenan modificar `.claude/**`, `.cursor/**`, `CLAUDE.md` ni `GEMINI.md`.
- La guía no duplica el contenido completo de las skills instaladas.
- Las verificaciones de alcance y placeholders pasan.
