# ProgressView & List/Table Components

**Fuentes**:
- https://www.swiftyn.com/articles/mastering-progressview-in-swiftui
- https://developer.apple.com/tutorials/data/documentation/swiftui/tables.md
- https://www.oreilly.com/library/view/swiftui-cookbook/9781803234458/B17962_02_Final_VK_ePub.xhtml
- https://sharpskill.dev/en/blog/ios/swiftui-building-modern-interfaces

**En una frase**: Componentes para mostrar progreso de operaciones (ProgressView) y colecciones de datos (List & Table) con patrones de selección, sorting y scroll.

**Fuente: Secundaria** — Profundidad técnica de SwiftUI; estructura de patterns de HIG.

**Fecha de recolección**: 2026-08-24 (Pasada 3)

---

## ProgressView — Indicadores de Progreso

### Cuándo Usar

✓ **Usar cuando**:
- Operación toma >1 segundo (descarga, sync, procesamiento)
- Usuario debe saber que algo está pasando (no está congelado)
- Quieres mostrar progreso específico (75% completado) o indeterminado (spinny circle)

✗ **No usar**:
- Animaciones decorativas (spinners innecesarios)
- Cambios instantáneos (< 100ms)

### Tipos de ProgressView

#### 1. Indeterminado (Spinner)

Cuando **no sabes cuánto toma** (duración desconocida).

```swift
// Simple spinner
ProgressView()

// Con label
ProgressView("Loading...")

// Estilo circular (compact)
ProgressView()
    .progressViewStyle(.circular)

// Sobre fondo oscuro (iOS dark content)
ProgressView()
    .tint(.white)
```

**Cuándo usar**:
- Carga de página
- Sync inicial
- Operaciones sin duración conocida (API call)

#### 2. Determinado (Barra de Progreso)

Cuando **sabes el porcentaje de completitud**.

```swift
// Progreso 0.0 a 1.0 (0% a 100%)
ProgressView(value: 0.75) // 75% completo

// Con label
ProgressView(value: downloadProgress, total: 100) {
    Text("Downloading...")
}

// Estilo barra lineal (default)
ProgressView(value: 0.5)
    .progressViewStyle(.linear)

// Custom color
ProgressView(value: 0.8)
    .tint(.green)
```

**Cuándo usar**:
- Descargas/uploads con duración estimada
- Instalaciones de app
- Procesamientos por batch (5 de 20 items)

### Casos de Uso Comunes

#### Descarga/Upload

```swift
@State private var downloadProgress = 0.0
@State private var isDownloading = false

VStack(spacing: 12) {
    if isDownloading {
        ProgressView(value: downloadProgress)
        
        HStack {
            Text("\(Int(downloadProgress * 100))%")
            Spacer()
            Text("~\(estimatedTimeRemaining)s")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    Button(isDownloading ? "Cancel" : "Download") {
        isDownloading.toggle()
        if isDownloading { startDownload() }
    }
}

private func startDownload() {
    let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        downloadProgress += 0.01
        if downloadProgress >= 1.0 {
            isDownloading = false
        }
    }
}
```

#### Sincronización

```swift
@StateObject private var syncManager = SyncManager()

VStack {
    if syncManager.isSyncing {
        ProgressView("Syncing...", value: syncManager.syncProgress)
            .padding()
    } else if let error = syncManager.lastError {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text("Sync failed: \(error)")
            Spacer()
            Button("Retry") { syncManager.sync() }
        }
        .padding()
    } else {
        Text("Synced: \(syncManager.lastSyncTime ?? "Never")")
    }
}
```

#### Operación Larga Múltiple Items

```swift
@State private var processedCount = 0
@State private var totalCount = 100
@State private var isProcessing = false

VStack {
    if isProcessing {
        ProgressView(value: Double(processedCount) / Double(totalCount)) {
            HStack {
                Text("Processing...")
                Spacer()
                Text("\(processedCount)/\(totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private func processBatch() {
    isProcessing = true
    for (index, item) in items.enumerated() {
        // Procesar item
        processedCount = index + 1
        if processedCount >= totalCount {
            isProcessing = false
        }
    }
}
```

### Mejores Prácticas

1. **Siempre ofrecer cancelación**:
   ```swift
   ProgressView("Uploading...")
   Button("Cancel", role: .destructive) { cancelUpload() }
   ```

2. **Mostrar información contextual**:
   - Qué se está cargando ("Downloading: photo.jpg")
   - Velocidad si es relevante ("2.5 MB/s")
   - Tiempo estimado ("~30 seconds remaining")

3. **No blockear UI**:
   - ProgressView debe ser en foreground task
   - Para background operations, usar badge o notification

4. **Feedback después de completar**:
   ```swift
   if !isDownloading && downloadProgress >= 1.0 {
       HStack {
           Image(systemName: "checkmark.circle.fill")
               .foregroundColor(.green)
           Text("Download complete")
       }
   }
   ```

---

## List — Componente Principal para Colecciones

### Cuándo Usar List

✓ **Usar cuando**:
- Mostrar colección de items (emails, tareas, contactos)
- Items son verticales y scrollables
- Necesitas selección simple o múltiple
- Quieres formatting estándar (separadores, secciones)

✗ **No usar**:
- Grid/layout horizontal (usar LazyVGrid en su lugar)
- Contenido altamente customizado sin estructura (canvas libre)

### Estructura Básica

```swift
// Simple list
List {
    Text("Item 1")
    Text("Item 2")
    Text("Item 3")
}

// Con iteración
List(items, id: \.id) { item in
    Text(item.title)
}

// Con secciones
List {
    Section(header: Text("Inbox")) {
        ForEach(inboxEmails, id: \.id) { email in
            EmailRow(email: email)
        }
    }
    
    Section(header: Text("Archived")) {
        ForEach(archivedEmails, id: \.id) { email in
            EmailRow(email: email)
        }
    }
}
```

### Estilos de List

```swift
// Plain (sin fondo ni separadores por defecto)
List { /* ... */ }
    .listStyle(.plain)

// Grouped (agrupado en background sections)
List { /* ... */ }
    .listStyle(.grouped)

// Inset Grouped (iOS 14+, menos margen horizontal)
List { /* ... */ }
    .listStyle(.insetGrouped)

// Sidebar (macOS principalmente)
List { /* ... */ }
    .listStyle(.sidebar)
```

### Modificadores Comunes

```swift
List(items, id: \.id) { item in
    NavigationLink(destination: ItemDetail(item: item)) {
        Text(item.title)
    }
}
// Remover separadores
.listRowSeparator(.hidden)
// Fondo de row
.listRowBackground(Color.blue.opacity(0.1))
// Insets personalizados
.listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
// Añadir accent al swipe actions
.tint(.red)
```

### Acciones de Swipe (iOS)

```swift
List {
    ForEach(emails, id: \.id) { email in
        EmailRow(email: email)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    delete(email)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                
                Button {
                    archive(email)
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    markAsUnread(email)
                } label: {
                    Label("Unread", systemImage: "envelope.open")
                }
            }
    }
}
```

### Reordenamiento (Edit Mode)

```swift
List {
    ForEach(tasks, id: \.id) { task in
        Text(task.title)
    }
    .onMove { indices, newOffset in
        tasks.move(fromOffsets: indices, toOffset: newOffset)
    }
    .onDelete { indices in
        tasks.remove(atOffsets: indices)
    }
}
.navigationTitle("Tasks")
.toolbar {
    EditButton() // Toggle edit mode
}
```

### Selección Simple y Múltiple

```swift
// Selección simple
@State private var selectedID: UUID?

List(items, id: \.id, selection: $selectedID) { item in
    Text(item.title)
}
.environment(\.editMode, .constant(.active)) // Force selection mode
.navigationTitle("Select Item")

// Selección múltiple
@State private var selectedIDs: Set<UUID> = []

List(items, id: \.id, selection: $selectedIDs) { item in
    Text(item.title)
}
.environment(\.editMode, .constant(.active))

// Usar selecciones después
ForEach(items.filter { selectedIDs.contains($0.id) }) { item in
    Text("Selected: \(item.title)")
}
```

---

## Table — Grid Estructurado (Columnas)

### Cuándo Usar Table

✓ **Usar cuando** (principalmente macOS/iPad):
- Datos tabular (filas y columnas)
- Sorting por columna es importante
- Muchos atributos por item

✗ **No usar**:
- Devices pequeños (iPhone) — mejor List
- Contenido no-tabular

### Estructura Básica

```swift
// iOS 16+ / macOS 13+
Table(of: Email.self) {
    TableColumn("From", value: \.from)
    TableColumn("Subject", value: \.subject)
    TableColumn("Date", value: \.date) { email in
        Text(email.date, style: .date)
    }
} rows: {
    ForEach(emails, id: \.id) { email in
        TableRow(email)
    }
}

// Con sorting
@State private var sortOrder = [KeyPathComparator(\Email.date)]

Table(of: Email.self, sortOrder: $sortOrder) {
    TableColumn("From", value: \.from)
    TableColumn("Subject", value: \.subject)
    TableColumn("Date", value: \.date) { email in
        Text(email.date, style: .date)
    }
} rows: {
    ForEach(emails.sorted(using: sortOrder), id: \.id) { email in
        TableRow(email)
    }
}
.onChange(of: sortOrder) {
    emails.sort(using: sortOrder)
}
```

### Selección en Table

```swift
@State private var selectedEmails: Set<Email.ID> = []

Table(of: Email.self, selection: $selectedEmails) {
    TableColumn("From", value: \.from)
    TableColumn("Subject", value: \.subject)
} rows: {
    ForEach(emails, id: \.id) { email in
        TableRow(email)
    }
}
```

---

## Optimización de Listas Grandes

### Lazy Initialization

```swift
// NO — carga todos los items
List(1...10000, id: \.self) { i in
    Text("Item \(i)")
}

// SÍ — carga solo visibles
List {
    ForEach(loadMoreIfNeeded) { /* ... */ }
}

private func loadMoreIfNeeded(item: Item) {
    if item.id == items.last?.id {
        loadNextBatch()
    }
}
```

### Reduce View Complexity

```swift
// LENTO si Item es @Observable con cambios frecuentes
List(items, id: \.id) { item in
    ComplexCustomView(item: item) // Rerender todo si item cambia
}

// RÁPIDO — aislar cambios
List(items, id: \.id) { item in
    ItemCell(item: item) // View pequeña y específica
}

@ObservedReloading var item: Item // Aisla rerender
```

---

## Errores Comunes

❌ List sin .id en ForEach → Views pueden no actualizar  
❌ ProgressView sin información contextual → Usuario no sabe qué se carga  
❌ List con scroll dentro scroll → Conflicto de gestures  
❌ Selección múltiple sin indicador visual → Usuario confundido  
❌ Swipe actions sin confirmar → Accidental deletes  
❌ Table en iPhone → Mejor usar List  

---

## Checklist de Implementación

- [ ] ProgressView para operaciones >1 segundo
- [ ] Cancelación siempre disponible (downloads, syncs)
- [ ] Información contextual (% completado, tiempo estimado)
- [ ] List con .id correcto en ForEach
- [ ] Swipe actions con destructive diferenciados
- [ ] Selección simple/múltiple clara en modo edit
- [ ] Table solo en macOS/iPad (List en iPhone)
- [ ] Sorting en table si relevante
- [ ] Performance: lazy loading para listas >100 items
- [ ] VoiceOver anuncios para ProgressView y selección

---

## Referencias Relacionadas

- **Patterns: Managing Tasks** (12) — ProgressView para operaciones
- **Patterns: Confirming Actions** (14) — confirmación antes de swipe delete
- **Components: Buttons & Menus** (09) — toolbar con Edit button
- **Accessibility** (01 foundations) — anunciar progreso en VoiceOver
