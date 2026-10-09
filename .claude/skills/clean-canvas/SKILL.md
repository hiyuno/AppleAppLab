---
name: clean-canvas
description: "Rutina para ordenar el canvas de diseño (Pen / pen.dev, archivos .pen vía MCP 'pencil'). Jonny es el dueño. Arriba guidelines y patterns (Design System, Components, estados); abajo el flujo de pantallas actuales de izquierda a derecha con pasos numerados; debajo de cada pantalla sus exploraciones y versiones; y borra lo que ya no se usa (archivos viejos, opciones descartadas, nodos sueltos), siempre con un commit de respaldo antes. Úsalo cuando el usuario diga 'ordena el canvas', 'organiza los boards', 'limpia Pen', 'clean canvas' o el canvas tenga pantallas, opciones y archivos mezclados."
---

# /clean-canvas — Ordenar el canvas de diseño por flujo

Rutina del equipo, no un agente. **Jonny es el dueño del canvas**; Steve la corre cuando el `.pen` acumula pantallas, opciones y pruebas mezcladas. Deja el archivo legible para cualquiera: qué reglas sigue la app, cuál es el flujo real y qué se está explorando.

Aplica la regla **"El diseño vive en git"** (Jonny, §"Pen (pen.dev) como fuente de diseño"): el `.pen` está en `Docs/Design/<App>.pen`, en git, y se guarda con ⌘S antes de cada commit.

## Layout objetivo

```
1 · Guidelines & patterns                       (fila de arriba, y = 0)
[Design System] [Components] [Estados / Loader States] …

2 · Screens flow  (left → right, explorations below each screen)
1. Pantalla A →   2. Pantalla B →   3. Pantalla C →   …
[Pantalla A]      [Pantalla B]      [Pantalla C]
                                    Explorations
                                    [C · v2 … (shipped)]
                                    [C · v3 … (exploring)]
```

- **Fila 1 · Guidelines & patterns:** Design System (tokens, tipografía, botones), Components (reutilizables) y boards de estados o patrones (loaders, toasts, vacíos). Lado a lado, en y = 0.
- **Fila 2 · Flujo:** solo las pantallas que existen hoy en la app, en el orden en que el usuario las recorre. Encima de cada una, una etiqueta de paso: `1. Set →`, `2. Generating →`…
- **Debajo de cada pantalla:** sus exploraciones, con la etiqueta `Explorations` y nombres con versión y estado: `<Pantalla> · v2 <qué cambia> (shipped)` o `(exploring)`.
- **Separaciones:** 200 pt entre columnas, 400 pt entre filas y 120 pt entre exploraciones. Las etiquetas de sección van en texto de 48 pt y las de paso en 28 pt, en `$text-secondary`.

## Pasos

1. **Ubicar el archivo.** El `.pen` del proyecto en `Docs/Design/` (en proyectos sin migrar, `design/` o `Design/`: se usa ahí y Steve propone `/clean-folder-project docs` una vez), o el que tenga abierto Pen según `get_app_state`. Si no está abierto en el editor, pide al usuario que lo abra: el MCP solo trabaja sobre el archivo activo. Nunca uses `Read`/`cat` sobre un `.pen`.
2. **Respaldo en git, antes de tocar nada.**
   - Pide al usuario que guarde en Pen con ⌘S y confirma con `ls -l Docs/Design/*.pen` que la fecha del archivo cambió. Pen solo escribe en disco al guardar: sin ⌘S, el archivo puede tener días de atraso aunque el canvas se vea al día.
   - Si el `.pen` ya está en git: commit de ese estado, `design: snapshot before clean-canvas`.
   - Si no está en git: se mete ahora (`git add Docs/Design/<App>.pen`, más `.backup/` y `.DS_Store` en `.gitignore` si faltan) y commit `design: track <App>.pen in git`. No se hacen copias sueltas: git guarda la historia.
3. **Inventario.** Lista los frames de primer nivel con id, nombre y tamaño (`Get((n,c)=>c.depth===0 && Print(n.id,n.name,c.bounds.width,c.bounds.height))`) y clasifica cada uno:
   - **Guideline o pattern:** design system, componentes, estados.
   - **Pantalla del flujo:** coincide con una pantalla real de la app (compárala con las vistas del código si hay duda).
   - **Exploración:** una versión o alternativa de una pantalla del flujo. Va debajo de ella.
   - **Sin uso:** marcados como `Archive`, opciones descartadas, versiones reemplazadas, nodos sueltos (textos o formas sin frame), duplicados.
4. **Confirmar lo que se borra.** Muestra la lista de "sin uso" con su motivo. Bórralos solo si el usuario ya pidió eliminar lo que no se usa o lo confirma. El commit del paso 2 es la forma de recuperarlos.
5. **Ordenar.** Mueve cada frame a su lugar con `Update(id,{x,y})` según el layout objetivo. Calcula las posiciones con los tamaños reales: las filas no se enciman aunque un board sea muy alto, como un Design System de 4000 pt. Crea o actualiza las etiquetas de sección, de paso y de `Explorations` como nodos de texto en la raíz, con `name` descriptivo (`Section · Flow`, `Step · Set`), y quita las etiquetas viejas que queden sueltas.
6. **Nombrar.** Renombra para que el nombre diga dónde va:
   - Pantallas: `<Modo> · <Pantalla>`, por ejemplo `Set · Fill Drawer · Build`.
   - Exploraciones: `<Pantalla> · vN <cambio> (shipped|exploring)`.
   - No toques los nombres de capas internas que el código o `/update-ui` usan como referencia.
7. **Verificar.** `TakeScreenshot(["document"])`: nada encimado, cada exploración bajo su pantalla, etiquetas legibles. Revisa `problems` solo en los frames que tocaste.
8. **Guardar, commit y reportar.** Pide ⌘S, confirma con `ls -l` que cambió la fecha, y commit `design: clean canvas`. Push solo si el usuario lo pide. Reporta el nuevo orden (filas y pasos), qué se movió bajo qué pantalla y qué se borró con su motivo, con los dos commits (respaldo y resultado).

## Lo que esta rutina NO hace

- No rediseña ni edita el contenido de las pantallas: solo las mueve, las nombra y borra lo que no se usa.
- No borra exploraciones vivas, aunque no estén implementadas: las pone bajo su pantalla con `(exploring)`.
- No borra componentes reutilizables (`reusable: true`) que tengan instancias en algún frame.
- No borra nada sin el commit de respaldo del paso 2.
- No cambia el código de la app.
