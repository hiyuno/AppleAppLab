# Routing de skills para Codex

## Proceso primero

| Señal | Skill de proceso |
|---|---|
| crear comportamiento, producto o UI ambiguos | `superpowers:brainstorming` |
| requisitos con varios pasos | `superpowers:writing-plans` |
| bug, crash o resultado inesperado | `superpowers:systematic-debugging` |
| feature o fix con código | `superpowers:test-driven-development` cuando sea viable |
| revisión final o afirmación de “completo” | `superpowers:verification-before-completion` |
| crear/editar una skill | `skill-creator` y `superpowers:writing-skills` |

## Dominio

- App macOS nativa: `macos`; interfaz macOS, sidebar, ventanas o HIG: `macos-design`.
- Dashboard o interfaz de producto: `interface-design`.
- Documento Word, PDF, spreadsheet o presentación: skill específica del formato.
- Sitios web, Next.js o Vercel: skill web/Vercel correspondiente, nunca para una app nativa Apple.
- Despliegue: `deploy-to-vercel` o skill de deployment solo con petición explícita.

## Combinaciones frecuentes

### Nueva app Apple

`brainstorming → writing-plans → macos/macos-design → implementación → verification-before-completion`

### Bug SwiftUI

`systematic-debugging → macos o skill de dominio → TDD → verification-before-completion`

### Revisión antes de release

Skill de auditoría pertinente → `verification-before-completion`; añadir Ivan, Larry, Sarah, Chris, Kate o Phil según el alcance.

### Mejora de una skill

`skill-creator → superpowers:writing-skills → quick_validate.py` de la skill modificada.

## Exclusiones

No activar una skill solo porque el repositorio la contiene. No usar diseño para análisis puramente técnico, deployment sin autorización, monetización/analytics/IA sin feature correspondiente, ni skills web para una app Apple. No duplicar en `.codex/` el contenido completo de una skill instalada.
