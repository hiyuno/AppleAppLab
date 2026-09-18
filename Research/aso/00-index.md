# ASO — metodología destilada

> Fuente: https://github.com/appeeky/aso-skills (MIT, 40 skills para agentes; Appeeky API opcional, no requerida). Destilado septiembre 2026.
> Decisión del equipo: **no se instalan los 40 skills** (solapan con Frederick, Kara, Kim, Tim y `/app-store-ready rejected` y llenarían el autocompletado). Se toma la metodología y vive aquí; Phil y Frederick la aplican.

---

## 1. Keyword research (Phil)

**Opportunity Score = Volumen × 0.4 + (100 − Dificultad) × 0.3 + Relevancia × 0.3** (cada uno 0–100).

| Tier | Cuántas | Dónde van |
|------|---------|-----------|
| Primary | 3–5 | Título / subtítulo. Mayor opportunity |
| Secondary | 5–10 | Subtítulo / campo de keywords |
| Long-tail | 10–20 | Campo de keywords, lo que quepa |
| Aspirational | 3–5 | Objetivo a 6+ meses; no se meten hoy |

Fuentes de volumen y dificultad sin herramienta de pago: sugerencias del App Store (autocompletar por letra), Apple Search Ads popularity index (gratis con cuenta), `asc metadata keywords audit`, y los títulos/subtítulos de los 5 competidores (`competitor-analysis`: gap de keywords que ellos rankean y tú no).

## 2. Metadata (Phil) — límites y reglas

| Campo | Límite | Regla |
|-------|--------|-------|
| Título | 30 | `[Marca] - [Keyword primaria]` o `[Marca]: [Beneficio]`. Llenar los 30 |
| Subtítulo | 30 | Keywords secundarias como beneficio; sin repetir el título; llenar los 30 |
| Keywords | 100 | Comas **sin espacio**, singular, sin nombre de app, sin categoría ("Apple ya sabe tu categoría"), sin competidores, sin "free", sin repetir lo que ya está en título/subtítulo |
| Descripción | 4 000 | Las **3 primeras líneas** son lo único que se ve sin "más": hook, no "Bienvenido a…". Luego prueba social, 4–6 bullets de beneficio, 3 pasos, testimonio, CTA |
| Promo text | 170 | Cambia sin review: ofertas, lanzamientos, premios |
| What's New | — | Lo que el usuario gana, no el changelog técnico |

**Entrega**: 3 variantes por campo (Recomendada / A / B) con conteo de caracteres, keywords cubiertas y razón; matriz de cobertura keyword → campo; tabla antes/después. Todo pasa por `asc validate` (sin `TODO`/`TBD`) y `asc metadata apply --dry-run`.

## 3. Screenshots — brief de 10 slots (Phil + Jonny)

"Las 3 primeras (visibles sin scroll) deciden el 80 % de la conversión."

| Slot | Qué | Nunca |
|------|-----|-------|
| 1 — Hook | Qué resuelve y por qué importa: titular de beneficio, antes/después, o el problema | Login, splash, "Bienvenido" |
| 2–3 — Valor | Las dos capacidades más fuertes con caption de beneficio | Features secundarias |
| 4–7 — Features | `[Titular de beneficio] + [UI real] + [detalle]` | Feature names sin beneficio |
| 8–9 — Confianza | Rating, premio, comparación, premium | Datos inventados (regla de App Review) |
| 10 — CTA | Recap + trial/descarga | — |

Titulares: **4–6 palabras**, ≥ 60 px, contraste alto, estilo consistente, UI real (no placeholders), dark mode además de light, vertical salvo juegos/video. Localizar overlays por mercado (Kim), RTL, moneda. Entrega: plan de 10 slots (titular, caption, pantalla, layout, elemento clave) + brief para diseño + tabla de screenshots de competidores. Se sube con `asc screenshots plan/apply`.

## 4. Audit ASO — 10 dimensiones (Phil; `/app-store-ready` lo usa como pulido 🔵)

| Dimensión | Peso iOS | Qué mira |
|-----------|----------|----------|
| Título | 20 % | keyword primaria, uso de caracteres, balance marca |
| Subtítulo | 15 % | keywords secundarias, propuesta de valor, sin repetición |
| Campo keywords | 15 % | únicas, formato, relevancia |
| Descripción | 5 % | hook, beneficios, densidad, CTA |
| Screenshots | 15 % | cobertura, orden, localización, overlays |
| Preview video | 5 % | existe, hook en 3 s, duración, subtítulos |
| Ratings & reviews | 15 % | estrellas, volumen, tendencia, tasa de respuesta |
| Icono | 5 % | distintivo, simple, legible en pequeño |
| Rankings de keywords | 10 % | top 10, amplitud, tendencia |
| Señales de conversión | 5 % | promo text, what's new, in-app events |

Cada una 0–10 → score ponderado 0–100. Salida: scorecard + quick wins / alto impacto / estratégico + benchmark contra competidores.

## 5. Rating prompt — gating (Phil → Woz)

- **Solo en momentos de éxito** (tarea completada, compra, logro). Nunca tras error, crash, cancelación, ni en cold open, ni primera sesión, ni dos veces por sesión.
- **Gating**: sesiones ≥ 3 · ≥ 3 días desde instalación · evento de activación completado · sin crash en la última sesión · sin señal negativa en esta · no ha valorado esta versión.
- **Pre-prompt** de una pregunta: "¿Te está gustando [App]?" → Sí → `SKStoreReviewRequest` · No → formulario de feedback. Filtra 1–2 ★; +0.3–0.8 ★ en promedio.
- Apple muestra el prompt **máximo 3 veces por 365 días** por usuario, decida lo que decida el código. No se personaliza la UI nativa.
- **Version gating**: resetear ratings en ASC solo tras un release que arregla lo que causaba las malas; nunca tras un cambio controvertido.

## 6. Timeline de lanzamiento (Frederick, momento 2)

| Cuándo | Qué |
|--------|-----|
| **T-8 semanas** | Keyword research, competidores, metadata, screenshots/icono/video, press kit, 20–30 contactos de prensa, mapa de comunidades (`launch-channels/reddit.md`, `directories.md`) |
| **T-4** | TestFlight con 50–200 testers, blog de lanzamiento, 10+ posts sociales, listing de Product Hunt preparado, analytics + crash + rating prompt configurados, pitches de prensa personalizados |
| **T-1** | Submit a App Review (`/app-store-ready`), embargo de prensa, campaña de Apple Search Ads lista pero pausada, avisar a beta testers |
| **Día D** | Mañana: release, emails de prensa, Product Hunt + comunidades + lista de correo · Durante: métricas, responder reviews, crashes, hitos · Noche: agradecer, stats del día 1, plan del día 2 |
| **Semana 1** | Engagement diario, rankings de keywords, ajustar pujas de ASA, seguimiento a prensa, solicitar featuring editorial, análisis de métricas |

Canales gratis: Product Hunt, Show HN, Reddit, X, YouTube, sitios de reviews. Pago: Apple Search Ads primero; Meta/TikTok/UAC después con datos.

## 7. Rechazos — corrección a lo que ya teníamos

- Respuesta en Resolution Center: reconocer la guideline **sin discutir**, describir cambios concretos, credenciales demo, número del nuevo build. Nunca reenviar el mismo binario con solo un cambio de metadata salvo que el problema fuera la metadata.
- Apelar solo cuando la guideline se aplicó mal; el App Review Board tarda 5–10 días hábiles, así que casi siempre es más rápido arreglar y reenviar.
- **Expedited review: solo bug crítico, seguridad o lanzamiento con fecha real. Por "marketing" Apple lo niega y puede marcar la cuenta.** Esto corrige la nota anterior de `/app-store-ready` que lo listaba como razón válida.

## 8. Custom Product Pages, In-App Events, featuring — solo cuando aplique

- **Custom Product Pages**: hasta 35 páginas con screenshots y promo text distintos por campaña de ASA o link; la métrica es conversión por página. Frederick las pide cuando hay ≥ 2 audiencias claras.
- **In-App Events**: aparecen en la ficha y en búsqueda; para lanzamientos de features, retos, temporadas. Phil los programa con la 1.1.
- **Featuring editorial**: se solicita en App Store Connect → Promote; funciona con historia + calidad + accesibilidad + uso de tecnologías nuevas de Apple. Phil lo pide en la semana 1.
