# Menus, Actions & Navigation Components

**Fuentes**:
- https://developer.apple.com/design/human-interface-guidelines/menus-and-actions
- Apple HIG Components
- SwiftUI Menu documentation

**En una frase**: Componentes para ejecutar acciones, organizar múltiples opciones, y navegar dentro de la interfaz.

---

## Menu (Dropdown/Popup)

**What**: A list of actions/options that appears when user taps a button.

### Types

#### 1. Menu Button (iOS 14+)

- Single button revealing list of actions.
- Typically three-dot icon (⋯) or similar.
- Options are not mutually exclusive.

```swift
Menu {
    Button(action: { editAction() }) {
        Label("Edit", systemImage: "pencil")
    }
    Button(action: { deleteAction() }) {
        Label("Delete", systemImage: "trash")
        .foregroundStyle(.red)
    }
    Button(action: { shareAction() }) {
        Label("Share", systemImage: "square.and.arrow.up")
    }
} label: {
    Image(systemName: "ellipsis.circle")
}
```

#### 2. Context Menu (Long-Press)

- Menu appears on long-press or right-click.
- More discoverable than top menu (visual feedback with preview).
- iOS 13+.

```swift
Text("Item")
    .contextMenu {
        Button("Copy", action: { copyItem() })
        Button("Delete", action: { deleteItem() })
        Button("Share", action: { shareItem() })
    }
```

**With Preview** (iOS 16+):

```swift
Text("Item")
    .contextMenu {
        Button("Copy", action: { copyItem() })
    } preview: {
        ItemPreview()  // Shows while menu open
    }
```

### Menu Best Practices

- **Order**: Most common action first, destructive (delete) last.
- **Icons**: Use consistent, recognizable SF Symbols.
- **Labels**: Clear, short text (1-3 words).
- **Grouping**: Use Section if many options (iOS 16+).

```swift
Menu {
    Section("Edit") {
        Button("Rename", action: { renameItem() })
        Button("Duplicate", action: { duplicateItem() })
    }
    Section("Danger Zone") {
        Button("Delete", action: { deleteItem() })
            .foregroundStyle(.red)
    }
} label: {
    Label("Menu", systemImage: "ellipsis.circle")
}
```

### When to Use Menu

- **Multiple actions** on single item (3+).
- **Non-destructive by default** — primary action is obvious elsewhere.
- **Quick access** — No sub-navigation needed.

### When NOT to Use Menu

- **Single action** → Use button instead.
- **Primary flow** → Make it visible (not hidden in menu).
- **Hierarchical options** → Use picker or navigation.

---

## Context Menu

Already described above, but key points:

- **Trigger**: Long-press (iOS), right-click (macOS).
- **Preview**: Optional preview while menu open.
- **Actions**: Usually destructive or secondary actions.
- **Discovery**: Less discoverable than menu button (no visual indicator).

### Discoverability Tip

Add a small hint icon or swipe indicator to suggest context menu exists.

---

## Toolbar & ToolbarItem

**What**: Horizontal or vertical bar with buttons/controls for common actions.

### iOS Toolbar (Top)

- Navigation bar area → back button, title, action buttons.
- Right side of nav bar: typically 1-2 buttons.

```swift
NavigationStack {
    List {
        Text("Item 1")
    }
    .navigationTitle("Items")
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { addItem() }) {
                Image(systemImage: "plus")
            }
        }
    }
}
```

### Placements

- `.topBarLeading` — Left side of nav bar (back button default).
- `.topBarTrailing` — Right side (most common for actions).
- `.bottomBar` — Bottom of screen (iOS 16+, less common).
- `.keyboard` — Above keyboard (if editing text).

### macOS Toolbar

- Much richer — can have multiple buttons, menus, search, etc.
- Top of window.
- Customizable by user (right-click to show/hide items).

```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        HStack {
            Button("Add") { addItem() }
            Button("Remove") { removeItem() }
        }
    }
}
```

---

## Navigation Bars & Title Bars

### iOS Navigation Bar

- **Top of screen** (below status bar).
- Contains: Back button (auto), Title (center), Right actions (trailing).
- **Large title** (iOS 11+): Larger title that shrinks on scroll.

```swift
NavigationStack {
    List {
        Text("Item")
    }
    .navigationTitle("My Items")
    .navigationBarTitleDisplayMode(.large)  // Large title
}
```

### macOS Title Bar

- Contains window controls (close, minimize, maximize) + title + toolbar area.
- More formal than iOS.
- Customizable (add accessory views, search).

### Inline Title (iOS 16+)

- Title inline with content (not separate nav bar).
- More modern, saves space.

```swift
.navigationTitle("Items")
.navigationBarTitleDisplayMode(.inline)
```

---

## Sidebar (iPad/macOS)

**What**: Hierarchical navigation on left side (iPad split view, macOS always).

### Visual Structure

```
┌─────────────────────┐
│ ☰ Sidebar  |  Content│
├─────────────────────┤
│ • Home              │
│ • Library           │
│ • Settings          │
└─────────────────────┘
```

### SwiftUI Implementation

```swift
NavigationSplitView {
    List(items, id: \.id, selection: $selectedItem) { item in
        NavigationLink(value: item) {
            Label(item.name, systemImage: item.icon)
        }
    }
    .navigationTitle("Menu")
} detail: {
    if let selected = selectedItem {
        ItemDetail(item: selected)
    } else {
        Text("Select an item")
    }
}
```

### Sidebar Best Practices

- **Hierarchy**: Folders/categories first, then items.
- **Icons**: Use consistent SF Symbols.
- **Selection**: Highlight current item clearly.
- **Collapse**: Allow collapse/expand of folders on iPad.
- **Reorder** (optional): Allow drag-reorder if applicable.

### Platform Notes

- **iOS**: Hidden by side-swipe or hamburger menu (doesn't always show).
- **iPad**: Always visible (split view) or can collapse.
- **macOS**: Always visible, resizable.

---

## Segmented Control

**What**: Multiple buttons in a row, one selectable at a time.

### Usage

- **2-4 options**: Segmented control.
- **5+ options**: Use picker or tab bar.

```swift
@State private var selection = 0

Picker("View", selection: $selection) {
    Text("List").tag(0)
    Text("Grid").tag(1)
    Text("Table").tag(2)
}
.pickerStyle(.segmented)
```

### Alternatives in SwiftUI

- Modern SwiftUI prefers `Picker(...).pickerStyle(.segmented)` over custom SegmentedControl.
- `PickerStyle` automatically adapts to platform.

---

## Tab Bar (iOS)

**What**: Bottom navigation with 4-5 tabs, one active at a time.

### Visual Structure

```
┌──────────────────────────┐
│  List          Grid  Etc │ (content)
├──────────────────────────┤
│ 🏠 Home | 🔍 Search | ⋯ │ (tab bar)
└──────────────────────────┘
```

### SwiftUI TabView

```swift
@State private var selectedTab = 0

TabView(selection: $selectedTab) {
    HomeView()
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
        .tag(0)
    
    SearchView()
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }
        .tag(1)
    
    SettingsView()
        .tabItem {
            Label("Settings", systemImage: "gear")
        }
        .tag(2)
}
```

### Best Practices

- **Limit tabs**: 3-5 maximum (4 is sweet spot).
- **Labels**: Combine icon + text (not icon-only unless necessary).
- **Order**: Most important tabs first (left to right).
- **Consistency**: Don't change tab order or icons.
- **Isolation**: Each tab is independent screen (don't mix with navigation stacks).

### Tab Bar vs Sidebar

| Aspect | Tab Bar | Sidebar |
|--------|---------|---------|
| **Screen space** | Takes bottom 44pt | Takes side ~250-350pt |
| **Platforms** | iOS primary | iPad/macOS primary |
| **Tabs** | 3-5 | Unlimited (scroll) |
| **Discovery** | Visible always | Collapsible |

---

## Accessibility

### Menus & Buttons

- **Labels required**: "Add, button" or "Menu, button".
- **VoiceOver**: Actions clearly spoken.
- **Keyboard**: Tab/Space to activate.

### Navigation

- **Breadcrumb trails** (optional): Show navigation hierarchy.
- **Back button**: Always accessible, clear label.
- **Focus**: Clear focus indicator on interactive items.

### Tab Bar

- **Icons + labels**: Both required for accessibility.
- **Order announced**: "Tab 1 of 5" when navigating.

---

## Platform Differences

| Component | iOS | macOS | iPadOS |
|-----------|-----|-------|--------|
| **Menu** | Tap (popover) | Click (dropdown) | Tap or click |
| **Context Menu** | Long-press | Right-click | Long-press or right-click |
| **Toolbar** | Top nav bar | Top window (rich) | Top + optional bottom |
| **Sidebar** | Hidden/menu | Always visible | Visible in split |
| **Tab Bar** | Bottom | Tabs in toolbar | Bottom or sidebar |

---

## Fecha de recolección

2026-08-24
