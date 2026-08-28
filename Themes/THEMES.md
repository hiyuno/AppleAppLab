# Temas de AppleAppLab

Temas predefinidos del sistema de diseño. Cuando el usuario dice "usa el tema X", Jonny y Woz aplican estos tokens exactos.

Cada tema define: accent color, fondo, material de ventana, corner style, densidad, elevación, tipografía y wallpaper de referencia.

---

## Fintrol

**Estilo:** app financiera. Oscuro, denso, naranja energético sobre fondo neutro. Serio pero con carácter.

| Token | Valor |
|-------|-------|
| Accent | `#F04200` — naranja intenso |
| Fondo | `#323232` — gris oscuro neutro |
| Material | Frost (translúcido con blur) |
| Corner style | Squircle (continuous corners) |
| Blur intensity | 0.5 |
| Transparency | 0.5 |
| Density | Regular |
| Elevation | Flat |
| Font design | Standard (SF Pro) |
| Font weight | Regular |
| Wallpaper ref | wallpaper-07 |

**Uso típico:** apps de finanzas, presupuesto, control de gastos, inversiones, crypto.

---

## Todocky

**Estilo:** productividad limpia. Negro profundo, verde lima vibrante, Liquid Glass. Moderno y enfocado.

| Token | Valor |
|-------|-------|
| Accent | `#ACDD01` — verde lima |
| Fondo | `#0A0A0A` — negro profundo |
| Material | Liquid Glass |
| Corner style | Squircle |
| Blur intensity | 0.5 |
| Transparency | 0.2 |
| Density | Compact |
| Elevation | Flat |
| Font design | Standard (SF Pro) |
| Font weight | Regular |
| Wallpaper ref | wallpaper-07 |

**Uso típico:** apps de tareas, GTD, productividad, habit trackers, listas.

---

## ToDo Project

**Estilo:** colaboración y proyectos. Gris medio, azul eléctrico, sólido y directo. Para trabajo en equipo.

| Token | Valor |
|-------|-------|
| Accent | `#305DCC` — azul eléctrico |
| Fondo | `#313131` — gris medio |
| Material | Solid (sin transparencia) |
| Corner style | Squircle |
| Blur intensity | 0.5 |
| Transparency | 0.5 |
| Density | Regular |
| Elevation | Subtle |
| Font design | Standard (SF Pro) |
| Font weight | Medium |
| Wallpaper ref | wallpaper-07 |

**Uso típico:** apps de proyectos, gestión de equipos, planificación, notas colaborativas.

---

## Test

**Estilo:** prototipo. Azul cyan sobre negro, Frost. Para explorar y testear — no para producción.

| Token | Valor |
|-------|-------|
| Accent | `#0092FF` — cyan azul |
| Fondo | `#0E0E0E` — negro |
| Material | Frost |
| Corner style | Squircle |
| Blur intensity | 0 |
| Transparency | 0.5 |
| Density | Regular |
| Elevation | Subtle |
| Font design | Standard (SF Pro) |
| Font weight | Regular |
| Wallpaper ref | wallpaper-30 |

**Uso típico:** prototipos rápidos, exploración de UI, demos internas.

---

## Cómo usarlos

Cuando el usuario diga "usa el tema Fintrol" o "base visual Todocky", Jonny:

1. Lee los tokens de este archivo
2. Los aplica en `DESIGN_LIQUID.md` y `DESIGN_FROST.md` como sistema de color base
3. Genera la paleta completa desde el accent con el método HSL (ver jonny.md)

Woz:
1. Importa `AppleAppLabUI` como dependencia del proyecto (en `project.yml`)
2. Usa los componentes del paquete: `LabButton`, `LabCard`, `LabTextField`, `LabList`, etc.
3. Aplica los tokens de color del tema como accent en `Assets.xcassets/AccentColor`

---

## Agregar un tema nuevo

1. Diseñar en PatternLibrary, guardar con nombre
2. Exportar: `python3 -c "import subprocess, json, plistlib; ..."` (ver setup de repo)
3. Agregar la entrada a este archivo con descripción, tokens y uso típico
4. Commit al repo
