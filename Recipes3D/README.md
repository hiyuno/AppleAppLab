# Recipes3D — recetas de Ed que ya funcionaron

Librería **global** de recetas 3D para todas las apps. La mantiene App Master y la sube a cada proyecto `/update-team` en `.appleapplab/Recipes3D/` (solo lectura allá). Ed la consulta **antes** de armar cualquier escena: propone desde estas recetas primero, después desde las locales de la app, y solo al final algo nuevo.

## Dos niveles

| Nivel | Dónde | Quién escribe | Estado |
|-------|-------|---------------|--------|
| Local (una app) | `Docs/Design/3D/recipes/<id>.md` (+ `<id>.py`) en el repo de la app | Ed, al cerrar un asset | `draft` → `verified` cuando Yuno aprobó un final hecho con ella |
| Global (todas) | `Recipes3D/<id>.md` (+ `<id>.py`) en AppleAppLab → `.appleapplab/Recipes3D/` | Solo App Master, con `/harvest-learnings` | `verified` |

Una receta local sube a global cuando quedó `verified` en **dos o más assets** (de la misma app o de varias), o cuando Yuno dice "siempre así". Si es cuestión de gusto (luz, material, encuadre), App Master se lo pregunta a Yuno con el render; si es técnica (export, topología, settings de render), la decide App Master. Ver `.claude/skills/harvest-learnings/SKILL.md`.

## Tipos

`light` (rig de luz y HDRI) · `material` (Principled BSDF) · `shape` (modificadores: bevel squircle, solidify…) · `camera` · `render` (motor y settings) · `export` (presets PNG/WebP/MP4/STL/glTF) · `scene` (combinación de varias).

## Formato

Una receta = `<id>.md` con el formato de `_TEMPLATE.md` y, si tiene código, `<id>.py` con una función `apply(...)` idempotente que la aplica a la escena abierta. `id` en kebab-case; los cambios incompatibles suben la versión (`v2`) y la vieja queda `deprecated` con enlace a la nueva.

Las recetas no copian colores de marca: los parámetros de color se leen del tema de la app al aplicarla.

## Recetas

| id | Tipo | Estado | Resumen | Probada en |
|----|------|--------|---------|------------|
| — | | | Todavía ninguna: las primeras salen del estreno de Ed en NewProject | |
