# PROJECT_LEARNINGS — [Nombre de la app]

Bitácora local y acumulativa del proyecto. Registra incidentes sin frenar el trabajo normal; el agente propietario actualiza la entrada después de reproducir y verificar. Steve asegura el flujo y coordina retrospectivas, pero no redacta soluciones técnicas.

> Estados permitidos: `hypothesis`, `conditional`, `verified`, `deprecated` para incidentes; `observed` para preferencias. No borres entradas: marca las reemplazadas y enlaza su sucesora.
>
> **Se escribe solo.** Los agentes anotan sin que se lo pidan cuando un fix necesitó más de un intento, corriges dos veces el mismo valor visual, dices "otra vez" o "siempre", rechazas un default, o se cierra un `/global-fix`. App Master cosecha estas entradas desde AppleAppLab con `/harvest-learnings`.

## Índice

| ID | Estado | Categoría | Resumen | Owner | Last verified |
|---|---|---|---|---|---|
| APP-AAAA-001 | hypothesis | [área] | [síntoma breve] | [agente] | YYYY-MM-DD |

## APP-AAAA-001 — [Título accionable]

- **Tipo:** `incidente`
- **Fingerprint:** `[área]/[componente]/[fallo-normalizado]`
- **Categoría:** [arquitectura / AppKit / SwiftUI / seguridad / diseño / QA / release / otra]
- **Plataformas / versiones:** [iOS/macOS/etc.], OS [versiones], Xcode [versión], SDK [versión]
- **Proyecto fuente / fechas:** [app]; first seen YYYY-MM-DD; last verified YYYY-MM-DD
- **Owner / status:** [Avie/Woz/Jonny/Ivan/Bertrand/etc.] / `hypothesis|conditional|verified|deprecated`
- **Síntoma:** [qué observa el usuario o el sistema; sin explicar todavía la causa]
- **Reproducción/evidencia:** [pasos mínimos, logs no sensibles, test o artefacto]
- **Hipótesis/causa raíz:** [separa explícitamente hipótesis de causa demostrada]
- **Garantía de plataforma/fuente:** [qué promete realmente Apple/API + enlace primario; “ninguna identificada” si aplica]
- **Workaround:** [mitigación temporal y sus límites]
- **Solución durable:** [fix implementado o propuesto; quién lo verificó]
- **Verificación:** [build/test/matriz/regresión exacta y resultado]
- **Prevención:** [test, checklist, arquitectura, observabilidad o documentación]
- **Relacionadas:** [IDs locales o AAL-*; `—` si ninguna]
- **Promoción global:** [no candidata / candidata; justificación y alcance generalizable]

## APP-AAAA-002 — [Preferencia en una frase]

- **Tipo:** `preferencia`
- **Fingerprint:** `pref/[área]/[tema]` (ej. `pref/window/material`, `pref/text/tone`)
- **Estado:** `observed`
- **Qué hizo o dijo el usuario:** [la corrección, el valor que eligió, o la frase; cita corta]
- **Valor elegido:** [el valor concreto: `.frost`, opacidad 0.35, radio 14…]
- **Contexto:** [pantalla o componente; si aplica a toda la app]
- **Veces en este proyecto:** [n]

## Retrospectiva — [milestone/release] — YYYY-MM-DD

- **Nuevos incidentes:** [IDs o ninguno]
- **Fixes confirmados:** [IDs + evidencia]
- **Hipótesis abiertas:** [IDs + siguiente experimento/owner]
- **Entradas globales aplicadas:** [AAL-* + resultado]
- **Entradas globales a revalidar:** [AAL-* + cambio de OS/Xcode/SDK/API]
- **Candidatas a promoción:** [IDs locales que cumplen los criterios]

## Reglas de calidad

- Primero observación reproducida; después hipótesis; solo entonces causa confirmada.
- No conviertas coincidencia temporal en garantía de plataforma.
- Nunca incluyas tokens, secretos, datos personales ni logs sensibles.
- Una solución es `verified` solo con una prueba/regresión explícita.
- Si una entrada queda obsoleta, usa `deprecated` y enlaza el reemplazo.
- Un valor visual calibrado una vez pertenece a esta app. Si lo repites en varias apps o dices "siempre", se anota como `preferencia` y puede volverse default de todas.
