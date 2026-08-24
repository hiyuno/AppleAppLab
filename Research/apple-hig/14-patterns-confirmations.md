# Confirming User Actions Pattern

**Fuentes**:
- https://developer.apple.com/design/human-interface-guidelines/ (core principles)
- https://www.saasui.design/blog/saas-destructive-actions-confirmation-ux-patterns (2026)
- https://www.smashingmagazine.com/2024/09/how-manage-dangerous-actions-user-interfaces/ (Apple practices)
- WWDC 2026: "Principles of great design" (Apple philosophy on forgiveness)

**En una frase**: Cómo diseñar confirmaciones y undo para acciones destructivas o costosas, balanceando seguridad con fluidez.

**Fuente: Secundaria parcial** — Patrones de destrucción no tienen sección dedicada en HIG actual; consolida guidance de undo/redo + mejores prácticas de confirmación.

**Fecha de recolección**: 2026-08-24 (Pasada 3)

---

## Filosofía: Forgiveness Over Prevention

> **Apple 2026 Design Principle**: "Build in forgiveness through easy undo and confirmation for destructive actions, so users feel confident and free to try things."

Esto significa:
- ✓ Permitir que usuarios experimenten sin ansiedad
- ✓ Deshacer es fácil (1-2 taps, no multi-step)
- ✓ Confirmación es clara pero no molesta
- ✗ Evitar barreras excesivas ("Are you really sure?" x 3)

---

## Tipos de Acciones que Requieren Confirmación

### 1. **Acciones Destructivas** (No se puede recuperar sin server)
- Eliminar nota, evento, contacto, archivo → **Requiere confirmación**
- Eliminar múltiples ítems → **Requiere confirmación + count** ("Delete 25 emails?")
- Vaciar papelera → **Requiere confirmación estricta**

### 2. **Acciones Costosas** (Alto costo pero reversibles)
- Cambiar password → **Requiere confirmación**
- Salir sin guardar cambios → **Requiere confirmación** (o auto-save)
- Cancelar suscripción → **Requiere confirmación + reason prompt**

### 3. **Acciones Irreversibles pero Recuperables** (Local undo es posible)
- Deshacer tarea completada → **Undo sin confirmación (easy)**
- Archivizar email → **No requiere confirmación, pero mostrar undo toast**

### 4. **Acciones que Afectan Datos de Otros** (Colaborativo)
- Eliminar evento compartido → **Confirmar, notificar a participantes**
- Cambiar acceso (público → privado) → **Confirmar, mostrar quiénes pierden acceso**

---

## Patrones de Confirmación

### Patrón 1: Confirmación Explícita (Destructivo Crítico)

Usar cuando: Eliminación irreversible, vaciar papelera, factory reset.

```swift
// iOS — Usar ActionSheet / Confirmation Dialog
.confirmationDialog(
    "Delete Email",
    isPresented: $showDeleteConfirmation,
    actions: {
        Button("Delete", role: .destructive) {
            deleteEmail()
        }
        Button("Cancel", role: .cancel) { }
    },
    message: {
        Text("This email will be permanently deleted. You can't undo this action.")
    }
)

// macOS — Usar NSAlert
NSAlert()
    .messageText = "Delete Email?"
    .informativeText = "This can't be undone."
    .alertStyle = .warning
    .addButton(withTitle: "Delete")
    .addButton(withTitle: "Cancel")
```

**UX**: Botón destructivo (rojo) claramente etiquetado, cancelación siempre disponible.

### Patrón 2: Undo Toast (Destructivo Reversible)

Usar cuando: Acciones que pueden deshacerse localmente (archivizar, mover a papelera).

```swift
// Elemento desaparece con animación
withAnimation {
    emails.removeAll { $0.id == email.id }
}

// Mostrar toast con opción de undo (3-5 segundos)
showUndoToast(
    title: "Email archived",
    action: "Undo",
    onUndo: {
        emails.append(email) // Restaurar
    }
)

// Típicamente en la barra inferior
VStack(spacing: 0) {
    // Contenido principal
    List { /* ... */ }
    
    // Toast bottom-aligned
    if let undoItem = lastDeletedItem {
        HStack {
            Text("\(undoItem.title) deleted")
            Spacer()
            Button("Undo") {
                restore(undoItem)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.9))
    }
}
```

**UX**: Automático disappear después de timeout, pero permitir undo si usuario lo ve a tiempo.

### Patrón 3: Conteo Explícito (Multi-Item)

Usar cuando: Eliminar muchos ítems a la vez.

```swift
// ✗ MALO
Alert(title: "Delete items?", message: "Are you sure?")

// ✓ BUENO
Alert(
    title: "Delete 25 emails?",
    message: "This action can't be undone.",
    primaryButton: .destructive(Text("Delete")) { deleteEmails() },
    secondaryButton: .cancel()
)
```

El conteo exacto hace que el usuario sea consciente de qué está pasando.

### Patrón 4: Contexto Adicional (Implicaciones)

Usar cuando: La acción afecta cosas relacionadas.

```swift
// Cambiar privacidad de documento compartido
Alert(
    title: "Make Private",
    message: "Sarah and 3 others will no longer have access to this document.",
    primaryButton: .destructive(Text("Make Private")) { makePrivate() },
    secondaryButton: .cancel()
)
```

---

## Acciones Múltiples (Batch Operations)

Si usuario tiene múltiples ítems seleccionados y quiere deletear/mover/etc:

```swift
// Interface
HStack {
    Text("\(selectedCount) items selected")
    Spacer()
    Button("Delete", action: confirmBatchDelete)
        .tint(.red)
}

// Confirmación
func confirmBatchDelete() {
    showAlert(
        title: "Delete \(selectedCount) items?",
        message: "This can't be undone.",
        destructiveButton: "Delete",
        onDestructive: { deleteBatch() }
    )
}
```

**Importante**: Si hay selecciones largas, permitir:
- "Select All" en una pantalla
- Mostrar count explícitamente
- Permitir deselecionar antes de confirmar

---

## Confirmaciones Contextuales (Sin Dialog)

A veces, un simple dialog es excesivo. Usa confirmación contextual:

### Ejemplo: Cambiar Estatus (Tareas)

```swift
// En lugar de alert, usar un menu o simple toggle
ForEach(tasks) { task in
    HStack {
        Text(task.title)
        Spacer()
        
        // Toggle sin confirmación — es reversible
        Toggle(isOn: .constant(task.completed)) {
            toggleCompletion(task)
        }
    }
}
```

Esto funciona porque:
- La acción es fácilmente reversible (tap again = undo)
- No es destructiva (los datos se guardan)
- El usuario entiende instantáneamente qué ocurrió

### Ejemplo: Cambiar Opción en Menu

```swift
Menu {
    Button("Mark as Read") { markRead() }
    Button("Mark as Junk") { markJunk() }
    Button("Archive", action: archive) // No confirmación, reversible
    Button("Delete", role: .destructive) { showDeleteAlert() } // Confirmación
}
```

---

## Acciones que NO Requieren Confirmación

- Marcar email como leído
- Archivizar (si es recuperable)
- Cambiar filtro o view
- Expandir/contraer secciones
- Cambiar orden de columnas en una tabla
- Mover a carpeta (si es recuperable/movible)

✓ **Compensación**: Undo disponible para todas estas.

---

## Undo/Redo en Acción

### Implementación Básica

```swift
// Usar NSUndoManager en UIKit
@Environment(\.undoManager) var undoManager

func deleteTask(_ task: Task) {
    undoManager?.registerUndo(withTarget: self) { _ in
        self.tasks.append(task)
    }
    tasks.removeAll { $0.id == task.id }
}

// En macOS, también automático en Edit menu
```

### Undo Stack Duración

| App | Undo Retention |
|-----|----------------|
| Notes | Sesión completa (todo el launch) |
| Mail | Últimas 5 acciones típicamente |
| Reminders | 3-5 segundos (toast) |
| Safari | Sesión completa |

**Recomendación para productividad apps**: Mantener stack de undo durante la sesión de trabajo del usuario (no borrar hasta que close app).

---

## Validación Pre-Confirmación

A veces, necesitas validar antes de confirmar:

```swift
// Cambiar password requiere password actual
.sheet(isPresented: $showPasswordChange) {
    PasswordChangeSheet { newPassword, currentPassword in
        if validatePassword(current: currentPassword) {
            updatePassword(newPassword)
        } else {
            showError("Incorrect current password")
        }
    }
}
```

---

## Cancellación Post-Confirmación (Recovery)

Si el usuario confirma pero se arrepiente instantáneamente:

```swift
// Mostrar toast con "Undo" por 5 segundos
showUndoToast(
    message: "Email deleted",
    action: { undoDelete() },
    dismissAfter: 5.0 // segundos
)

// Después de 5s, borrar del servidor si aún no se sincronizó
// Si usuario toca "Undo", restaurar antes de enviar a server
```

---

## Errores Comunes

❌ Confirmación innecesaria ("Are you sure?" para actions reversibles)  
❌ Conteo oculto ("Delete items?" sin mostrar cuántos)  
❌ Sin contexto de implicaciones ("Delete document?")  
❌ Undo no disponible después de destrucción  
❌ Toast de undo sin timeout (forever → polluta screen)  
❌ Confirmación modal que paraliza ("Next" deshabilitado hasta confirmar)  

---

## Checklist de Implementación

- [ ] Identificadas todas las acciones destructivas/costosas
- [ ] Confirmación explícita para irreversibles (delete, vaciar papelera)
- [ ] Undo toast para reversibles (archive, move, soft-delete)
- [ ] Conteo explícito si hay multi-select
- [ ] Contexto mostrado (quiénes serán afectados, implicaciones)
- [ ] Undo/redo funcional durante sesión
- [ ] Acciones reversibles NO tienen confirmación
- [ ] Toast de undo tiene timeout (3-5 segundos)
- [ ] Link a Settings si requiere cambios globales
- [ ] Testear en escenarios de baja conectividad (server sync puede fallar)

---

## Referencias Relacionadas

- **Undo & Redo** (HIG) — profundidad en mecanismo
- **Patterns: Drag and Drop** (11) — undo es crítico aquí también
- **Patterns: Managing Tasks** (12) — tareas eliminadas requieren undo
- **Components: Sheets & Dialogs** (03) — presentation de confirmación
- **Accessibility** (01 foundations) — alertas deben ser anunciadas por VoiceOver
