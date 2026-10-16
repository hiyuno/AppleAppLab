# Figma — guía de trabajo para el design system de una app Apple

Verificado en help.figma.com, developers.figma.com y developer.apple.com el 2026-10-16. Lo marcado ⚠ no se pudo confirmar: compruébalo en la app antes de enseñarlo como hecho.

Cuando Claude edita por MCP, **siempre** carga antes las skills oficiales del MCP de Figma con `get_figma_skill`:

| Skill del MCP | Para qué |
|---|---|
| `skill://figma/figma-use/SKILL.md` | Obligatoria antes de cada `use_figma`: sintaxis del Plugin API y trampas |
| `skill://figma/figma-generate-library/SKILL.md` | Qué construir y en qué orden para un design system; scripts de ayuda; ledger de estado |
| `skill://figma/figma-swiftui/SKILL.md` | Traducción Figma ↔ SwiftUI: colores semánticos como tokens, SF Symbols por nombre |
| `skill://figma/figma-create-new-file/SKILL.md` | Antes de `create_new_file` |

Esta guía no las reemplaza: dice **qué decide el equipo** y **cómo lo haría el usuario a mano**.

---

## Qué existe (responde sin adivinar)

| Pregunta | Respuesta | Dónde |
|---|---|---|
| ¿Variables? | **Sí**: Color, Number, String, Boolean, **Timing** (ms) y **Easing** (curva o spring) | Sin nada seleccionado → panel derecho **Local variables → Open variables** (en algunas cuentas, barra izquierda **Variables**) |
| ¿Modos? | **Sí**, por colección. Starter 1 · Professional hasta 10 · Organization hasta 20 · Enterprise ilimitados | Botón **New variable mode** a la derecha de las columnas |
| ¿Estilos? | **Sí**, siguen vigentes: color, texto, efecto y *layout guide* (antes "layout grid", renombrado en mayo 2025) | Panel derecho sin selección |
| ¿Variantes? | **Sí**: component sets con propiedades `Propiedad=Valor` | Seleccionar componentes → **Combine as variants** |
| ¿Propiedades de componente? | **Variant, Boolean, Instance swap, Text, Slot** | Componente → **Properties → +** |
| ¿Slots? | **Sí, GA desde junio 2026**, todos los planes | Frame anidado → **Convert to slot** (⇧⌘S) |
| ¿Efecto de vidrio? | **Sí**, efecto **Glass** nativo (Refraction, Depth, Dispersion, Frost, luz). No se ve sobre rellenos al 100% de opacidad; beta en el Plugin API; sin CSS en Dev Mode | **Effects → Glass** |
| ¿Librerías? | **Sí**, plan pagado y asiento Full; el archivo no puede estar en Drafts | Assets (⌥2) → **Libraries → Publish** |
| ¿Branching? | Organization y Enterprise | Menú junto al nombre del archivo → **Create branch…** |
| ¿Code Connect con SwiftUI? | **Sí**. Recomendado: **template files**; el parser SwiftUI quedó como legado. Professional: una librería y un framework | developers.figma.com/docs/code-connect |
| ¿El agente puede escribir en el canvas? | **Sí**, `use_figma` (servidor remoto, beta, según plan) | MCP de Figma |

---

## Variables y modos — cómo se arma

**Arquitectura que usa el equipo** (la de `figma-generate-library`, adaptada a Apple):

```
Primitives     modos: Value          (ocultas: scope vacío; prefijo "_" si no se publican)
Color          modos: Light · Dark   (semánticas, alias a Primitives)
Spacing        modos: Value
Radius         modos: Value
Material       modos: Light · Dark   (opacidades y tintes de los materiales)
Type           modos: Value          (Number/String que alimentan los text styles)
Motion         modos: Value          (Timing y Easing)
```

Si hay que sumar **Increased Contrast**, va como modos extra de `Color` (Light, Dark, Light HC, Dark HC): caben en Professional. iOS y macOS: si los valores cambian por plataforma (tamaños de texto, controles), una colección `Platform` con modos `iOS · macOS`.

**Reglas:**
- Los semánticos **siempre** son alias de primitivos: clic derecho en el valor → **Create alias**. Nunca un hex repetido.
- **Scope en cada variable** (clic derecho → **Edit variable → Scope**): fondos `Frame fill, Shape fill`; texto `Text fill`; bordes `Stroke`; espaciado `Gap and padding`; radios `Corner radius`; primitivos sin scope (no aparecen en los pickers). Los booleanos no tienen scope.
- **Code syntax iOS en cada variable** (Edit variable → **Code syntax → iOS**): el nombre que usa la app. En AppleAppLab, el campo del tema (`accentColor`, `backgroundColor`) o el color semántico del sistema (`Color(.secondaryLabel)`). Dev Mode lo muestra en su snippet SwiftUI.
- Aplicar un modo: seleccionar el frame → **Appearance → Apply variable mode** → colección → modo. Los hijos heredan.

**Tipografía con variables.** Number para tamaño, peso numérico, line height (px) y tracking; String para familia y estilo ("Semibold", escrito exacto). Se enlazan **dentro del text style** (Apply variable). ⚠ line height en porcentaje puede no enlazarse: usa px.

---

## Componentes, variantes y propiedades — la mejor forma

**Regla de decisión** (igual que en Pen, con las herramientas de Figma):

| Cambia… | Usa |
|---|---|
| Estado o estilo con el mismo esqueleto (Default, Pressed, Disabled, Focused) | **Variant** |
| Mostrar u ocultar una parte (ícono, badge, subtítulo) | **Boolean** — no dupliques variantes por eso |
| Qué ícono o qué subcomponente va | **Instance swap** con *preferred instances* — nunca una variante por ícono |
| El texto | **Text property** |
| Contenido libre por instancia (filas de una lista, acciones de una tarjeta) | **Slot** |
| La estructura completa | Otro componente (`Card`, `Card / Compact`) |

**Límite:** si Size × Style × State pasa de ~30 combinaciones, divide en subcomponentes.

**Crear un componente con estados (app):**
1. Diseña el estado base con auto layout y variables (nada suelto).
2. **⌥⌘K** crea el componente. Duplica (**⌘D**) por cada estado y ajusta.
3. Selecciónalos todos → **Combine as variants**. La variante de **arriba a la izquierda es la default**.
4. Renombra propiedades con doble clic: `State`, `Size`, `Style`. Valores: `Default`, `Pressed`, `Disabled`, `Focused`, `Hover` (macOS).
5. **Properties → +**: Boolean para partes opcionales (enlázalo con **Apply variable/property** en la capa), Text para el label, Instance swap para el ícono con sus preferred instances.
6. Instancias anidadas: **Properties → Expose properties from → Nested instances**.
7. Reordena la cuadrícula de variantes (Figma las apila) y deja una descripción en el componente.

**Slots (app):** dentro del componente, selecciona un frame anidado → **Convert to slot** (⇧⌘S), o **Wrap in new slot** para otras capas. Ajustes: preferred instances, **Only allow preferred instances**, mínimo y máximo de capas (avisan en naranja, no bloquean). Un slot no puede estar en la capa raíz del componente. ⚠ Quitar una propiedad slot borra el contenido de todas las instancias: pruébalo en una rama. ⚠ El MCP aún no maneja slots ("coming soon"); créalos a mano o con el Plugin API si `figma-use` lo documenta.

**Nombres:** componentes como el `Lab*` del código (`LabButton`, `LabTextField`) o, si la app no usa AppleAppLabUI, como la vista SwiftUI. Jerarquía con `/` (`Icon/Close`). Componentes de construcción con prefijo `.` para no publicarlos.

---

## Auto layout

| Acción | Atajo |
|---|---|
| Agregar / quitar / sugerir | ⇧A / ⌥⇧A / ⌃⇧A |
| Hug | doble clic en el borde |
| Fill | ⌥ + doble clic en el borde |
| Editar todos los paddings | ⌘ + clic en el campo |
| Alinear por baseline | B en la caja de alineación |
| Gap "Between" | X |

- Gap numérico o **Auto** (Between/Around/Evenly). Min/max width aceptan variables.
- **Wrap** horizontal y vertical; **Grid** con filas, columnas y spans.
- Lo absoluto ahora se llama **Ignore auto layout** (⌃ al arrastrar).
- Gap, padding, radio y tamaños se enlazan a variables Number: **nunca** escribas un número suelto.

---

## Kits oficiales de Apple

Apple publica en developer.apple.com/design/resources los kits de la versión vigente. Hoy son **27**:

| Kit | Enlace |
|---|---|
| iOS y iPadOS 27 (Figma) | https://www.figma.com/community/file/1651309003795292092/ios-and-ipados-27 |
| macOS 27 (Figma) | https://www.figma.com/community/file/1651309434229735362/macos-27 |
| Plantilla de ícono iOS/iPadOS/watchOS 27 (Figma) | https://www.figma.com/community/file/1645923469870515372/ |
| SF Pro, SF Symbols 27, Icon Composer | https://developer.apple.com/design/resources/ |

**Cómo se usan:**
- Duplica el kit a tu cuenta y agrégalo como **librería** del archivo de la app. Los controles del sistema (barras, tab bar, sheets, alerts, menús, teclados) **se instancian del kit, no se redibujan**.
- Tus componentes propios **envuelven** instancias del kit cuando se parecen a un control del sistema ("wrap if visual match but API incompatible", de `figma-generate-library`).
- ⚠ No se pudo abrir el kit 27 para confirmar si usa variables y efecto Glass nativo; ábrelo y revisa sus colecciones antes de decidir si aliasear a sus variables o copiar valores.
- **Licencia de SF Pro:** solo para maquetas de software de plataformas Apple; no para otras plataformas, ni para incrustar o redistribuir (tampoco en web). Lee la licencia del instalador.

---

## Estructura del archivo (convención, no regla de Figma)

```
Cover
Foundations      (frames: Color, Typography, Spacing, Radius, Materials, Icons, Motion)
---
Components       (o una página por familia: Buttons, Inputs, Lists, Navigation…)
Patterns         (combinaciones: formularios, estados vacíos, onboarding)
---
Screens          (una sección por flujo; frames con el nombre de la vista SwiftUI)
Playground
```

En una librería publicada, **los nombres de página son los encabezados** del panel Assets y los frames, subencabezados plegables: nómbralos para quien los busca.

---

## Dev Mode y entrega a Woz

- Marca pantallas y componentes **Ready for dev** cuando estén listos (todos los planes con Dev Mode). **Completed** es solo Organization/Enterprise.
- Woz lee con `get_design_context` (`clientLanguages:"swift"`, `clientFrameworks:"swiftui"`) siguiendo `figma-swiftui`, y `/update-ui` compara con `get_variable_defs`. El React/Tailwind que devuelve es referencia estructural, no código a copiar.
- Code Connect es opcional: vale la pena cuando la app tiene muchos componentes `Lab*` y el plan lo permite.

---

## Atajos que conviene enseñar

| Acción | Atajo |
|---|---|
| Crear componente | ⌥⌘K |
| Desligar instancia | ⌥⌘B |
| Ir al componente principal | ⌃⌥⌘K |
| Convertir en slot | ⇧⌘S |
| Duplicar variante o instancia | ⌘D |
| Pestaña Assets | ⌥2 |
| Quick insert | ⇧I |
| Acciones rápidas (buscar cualquier comando, p. ej. "Combine as variants") | ⌘K o ⌘/ |
| Panel de atajos | ⌃⇧? |

⚠ "Combine as variants" no tiene atajo confirmado: botón del panel derecho o acciones rápidas.

---

## Límites que hay que decir antes de empezar

- Modos por colección según plan (Starter no tiene modos extra: light/dark exige Professional o usar dos colecciones).
- Publicar librerías y Dev Mode requieren plan pagado.
- Extended collections, solo Enterprise. Para más de una marca en otros planes: capas de alias.
- Glass en beta en el API y sin salida de código: el material real lo implementa Woz con `.glassEffect` / materiales de SwiftUI.
- Aceptar actualizaciones de una librería borra los modos aplicados por los diseñadores: hay que volver a aplicarlos.

Fuentes: help.figma.com (variables 14506821864087, 15145852043927, 15343816063383, 360040328273; styles 15871097384471; effects 360041488473; component properties 5579474826519; variants 360056440594; slots 38231200344599; auto layout 360040451373; libraries 360025508373, 360039238193; branching 360063144053; Dev Mode 15023124644247; shortcuts 360038665754), developers.figma.com (MCP tools, Code Connect, Plugin API updates 2026-06-10), developer.apple.com/design/resources.
