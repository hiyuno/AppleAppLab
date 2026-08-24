# Managing Tasks Pattern

**Fuentes**:
- https://developer.apple.com/design/human-interface-guidelines/undo-and-redo
- https://developer.apple.com/design/human-interface-guidelines/managing-notifications
- https://www.learnui.design/blog/ios-design-guidelines-templates.html
- Medium: "iOS Notifications in 2026: Complete Developer Guide"

**En una frase**: Patrón para diseñar apps con gestión de tareas que soporten undo/redo, notificaciones claras y feedback de progreso sin abrumar al usuario.

**Fuente: Secundaria parcial** — No todos los aspectos tienen página dedicada en HIG; este documento consolida guidance de undo/redo + notifications + mejores prácticas de task management.

**Fecha de recolección**: 2026-08-24 (Pasada 3)

---

## Cuándo Usar Este Patrón

✓ **Usar cuando la app tiene**:
- To-do lists, task workflows, project management
- Operaciones que modifican estado y pueden necesitar reversión
- Background operations que requieren feedback (sync, downloads, procesamiento)
- Notificaciones que informan progreso o cambios

✗ **No siempre necesario si**:
- La app es stateless o los cambios son instantáneos y triviales
- La tarea es read-only

---

## Undo y Redo Fundamentales

### Por Qué Importa Undo/Redo

> "Undo and redo give people easy ways to reverse many types of actions, which can also help people explore and experiment safely as they learn a new interface or task."

Esto es **crítico en apps de productividad**. Los usuarios no sienten ansiedad si saben que pueden deshacer.

### Cuándo Implementar Undo

✓ **Siempre undo en**:
- Eliminar (delete) tareas, eventos, notas
- Cambios de contenido (texto, descripciones, etiquetas)
- Reorganización (reordenar listas, mover entre secciones)
- Cambios de estado (marcar/desmarcar, estatus)

✓ **Considerar undo en**:
- Cambios de settings que son reversibles (tema, idioma, filtros activos)

✗ **No siempre necesario**:
- Navegación (ir a otra pantalla)
- Cambios de preferencias globales que requieren reinicio
- Operaciones de sincronización a servidor (undo localmente es complejo)

### Implementación en iOS 16+

```swift
// Usando NSUndoManager (UIKit) o en SwiftUI via Environment
@Environment(\.undoManager) var undoManager

func deleteTask(_ task: Task) {
    undoManager?.registerUndo(withTarget: self) { _ in
        self.addTask(task) // Reversión
    }
    // Ejecutar eliminación
    tasks.removeAll { $0.id == task.id }
}
```

### UX de Undo

- **Ubicación**: Toolbar o menu (top-left en iOS con back button, en macOS Edit menu)
- **Visual feedback**: Toast o animation que muestra "Undo [acción]" con X para cancelar
- **Timeout**: iOS típicamente permite undo por ~3-5 segundos después de la acción
- **Duración indefinida**: Apps profesionales (Notes, Reminders, Mail) permiten undo durante toda la sesión

---

## Notificaciones en Task Management

### Cuándo Usar Notificaciones

✓ **Notificar cuando**:
- Tarea completada con éxito (ej. sync, upload)
- Alguien edita una tarea compartida (collaboration)
- Recordatorio de tarea vencida o próxima
- Error que requiere acción (ej. "Sync failed — retry?")

✗ **NO notificar por**:
- Acciones que el usuario acaba de hacer (ui feedback visual en la app es suficiente)
- Cambios triviales (ej. cada keystroke)

### Diseño de Notificaciones (iOS)

```swift
import UserNotifications

// Request permission (just-in-time: cuando usuario habilita notificaciones en tu app, no en Settings)
UNUserNotificationCenter.current()
    .requestAuthorization(options: [.alert, .sound, .badge])

// Notificación simple
let content = UNMutableNotificationContent()
content.title = "Task Completed"
content.body = "You finished your morning routine."
content.sound = .default
content.badge = NSNumber(value: 1)

let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
let request = UNNotificationRequest(identifier: "task-complete", content: content, trigger: trigger)
UNUserNotificationCenter.current().add(request)
```

### Notificaciones Inteligentes (iOS 15+)

- **Focus Modes**: Respetar Focus (Do Not Disturb, Work, Sleep, Custom)
  ```swift
  content.interruptionLevel = .timeSensitive // Rompe Focus si es urgente
  ```
- **Notification Summary**: Agrupar notificaciones no urgentes en un resumen diario
  ```swift
  content.interruptionLevel = .passive // Para batches (resúmenes)
  ```
- **Live Activities** (iOS 16+): Mostrar progreso en lock screen
  ```swift
  // Para operaciones de larga duración (uploads, downloads, timers)
  ```

### Mejores Prácticas de Notificaciones

1. **Pide permiso en contexto**: No en launch, sino cuando la feature que necesita notificaciones es usada
   - Ej. usuario crea reminder → "Notify me about this?" 
2. **Sé específico en el contenido**: "Task 'Buy groceries' is due today" > "You have a task"
3. **Agrupa notificaciones**: Si hay múltiples, usa threadIdentifier para agrupar en lock screen
4. **Respeta preferencias**: Usuarios pueden silenciar notificaciones por tipo (reminders, collaboration, errors)
5. **Evita sobrecarga**: Una app que notifica 10x/día => desinstalación garantizada

---

## Patrones de Task Completion

### Visual Feedback Inmediato

Cuando usuario marca una tarea como "completada":

```swift
// ✗ MAL: Simplemente cambiar el estado sin feedback
tasks[index].completed = true

// ✓ BIEN: Animar, mostrar checkmark, después remover o esferizar
withAnimation(.easeInOut(duration: 0.3)) {
    tasks[index].completed = true
}
// Opcional: remover de lista después de 0.5s
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    tasks.remove(at: index)
}
```

### Indicadores de Progreso

Para operaciones que toman tiempo (sync, batch operations):

```swift
// Usar ProgressView si está centralizado
ProgressView(value: 0.75) // 75% completado

// O individualizar por tarea si hay múltiples
ForEach(tasks) { task in
    HStack {
        Text(task.title)
        if task.isSyncing {
            ProgressView() // Spinner
        }
    }
}
```

### Tarea Completada → Dónde Va

- **Opción 1 (Reminders)**: Desaparece inmediatamente con animación
- **Opción 2 (Things)**: Mueve a sección "Completed" con timestamp
- **Opción 3 (Mail - Archive)**: Archiva pero sigue accesible en filter

Recomendación: Permitir que usuarios configuren esto en settings.

---

## Gestión de Errores en Tasks

Cuando una tarea falla (sync, upload, etc.):

1. **Mantén el estado local optimista**: La app refleja el cambio localmente mientras sincroniza
2. **Si falla**: Muestra error con opción de reintentar
   ```swift
   HStack {
       Text("Failed to sync")
       Button("Retry") { retrySync() }
   }
   ```
3. **Nunca elimines silenciosamente datos**: Si sync falla, guarda localmente para retry después
4. **Recuperación automática**: Reintentar sync en background cuando conexión se recupera

---

## Patrones de Notificaciones de Colaboración

Si las tareas se comparten (Reminders, proyecto colaborativo):

- **Notificar cuando alguien edita**: "Sarah marked 'Design review' as done"
- **Comentarios**: Mostrar notificación, permitir responder desde notificación (iOS 15+)
- **Conflictos de edición**: Si dos personas editan simultáneamente, mostrar alert de merge
  - Proporcionar opción para ver ambas versiones y elegir

---

## Errores Comunes

❌ Undo que solo funciona una vez → Mantener stack completo de undo/redo  
❌ Notificaciones sin permiso pedido → Pedirlas contextuales, no en launch  
❌ Task desaparece sin feedback → Animar, mostrar toast "Completed" o mover a sección  
❌ Errores de sync ignorados silenciosamente → Siempre mostrar y permitir retry  
❌ No soportar offline → Guardar cambios localmente, sync cuando hay conexión  

---

## Checklist de Implementación

- [ ] Undo/redo para operaciones destructivas (delete, edit)
- [ ] Toast o animation que confirma cambios
- [ ] Notificaciones pedidas en contexto, no en launch
- [ ] Respetar Focus modes en notificaciones urgentes
- [ ] ProgressView para operaciones de >1 segundo
- [ ] Manejo de errores de sync + retry
- [ ] Soportar offline (cambios locales, sync después)
- [ ] Settings para personalizar notificaciones por tipo
- [ ] Testear en dispositivos con Low Power Mode (animated backgrounds pueden desactivarse)

---

## Referencias Relacionadas

- **Undo & Redo** (HIG oficial) — profundidad en mecanismo
- **Managing Notifications** (HIG oficial) — timing y permiso requests
- **Patterns: Confirming User Actions** (14) — para deletar tareas
- **Components: ProgressView** (17) — indicadores visuales de progreso
- **Accessibility** (01 foundations) — alternativas no-visuales para feedback
