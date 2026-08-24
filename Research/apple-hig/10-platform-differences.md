# iOS vs macOS: Platform-Specific Design Differences

**Fuentes**:
- Apple HIG Platform-Specific Guidance (iOS, macOS)
- https://frankrausch.com/ios-navigation/ — iOS navigation patterns
- Apple Design Resources

**En una frase**: Cómo diseñar y adaptar apps considerando diferencias fundamentales entre iOS (touch, portable, full-screen) y macOS (keyboard/pointer, desktop, windowed).

---

## Design Philosophy Differences

### iOS

- **Touch-first**: All interactions assume finger input.
- **Full-screen immersion**: Apps take entire screen.
- **Single-window**: One view at a time (modal focus).
- **Portable context**: Used on the go, interrupted often.
- **Tactile feedback**: Haptics, animations matter.
- **Direct manipulation**: Direct contact with content.

### macOS

- **Pointer + keyboard primary**: Touch not expected.
- **Window-based**: Multiple windows, resizable, windowed multitasking.
- **Dense information**: More can fit on screen.
- **Stationary context**: Longer sessions at desk.
- **Menu bar**: Global menu structure (File, Edit, View, etc.).
- **Keyboard shortcuts**: Command+Z, Command+A, etc. are native.

---

## Navigation Patterns

### iOS: Tab Bar + Stack Navigation

```
┌──────────────────┐
│  Home    Search ⋯ │ (tabs at bottom)
├──────────────────┤
│                  │
│  HomeView        │
│  (main content)  │
│                  │
└──────────────────┘
  ↓ (tap Home item)
┌──────────────────┐
│ ← Detail View    │ (push to stack)
├──────────────────┤
│                  │
│  ItemDetail      │
│                  │
└──────────────────┘
```

**Pattern**: TabView → NavigationStack → Detail.

### macOS: Sidebar + Split View

```
┌──────────────────────────────────────┐
│ ☰ Sidebar | List          | Detail  │
├──────────────────────────────────────┤
│ • Home                               │
│ • Library     | Item 1               │
│ • Settings    | Item 2      [Content]│
│               | Item 3       [here] │
└──────────────────────────────────────┘
```

**Pattern**: NavigationSplitView (3-column), resizable.

### Key Difference

| iOS | macOS |
|-----|-------|
| Tab bar (bottom) | Sidebar (left) |
| Stack (push → detail) | Split view (select → show) |
| Full screen per tab | Multiple columns visible |
| Swipe back gesture | Click back arrow or click sidebar |

---

## Menus & Actions

### iOS: Bottom Sheet, Top Menu, Long-Press

```
Action options typically from:
1. Top right corner → Menu button (⋯) → popover
2. Long-press item → Context menu (preview + actions)
3. Swipe left/right → Quick actions
```

Example:
```swift
Button(action: { /* main action */ }) {
    Image(systemImage: "plus")  // Top right
}

// OR

List(items) { item in
    ItemRow(item)
        .contextMenu {  // Long-press
            Button("Edit") { editItem() }
            Button("Delete") { deleteItem() }
        }
}
```

### macOS: Menu Bar, Right-Click, Toolbar Buttons

```
Global menu bar at top:
File | Edit | View | ...

Individual window also has:
- Right-click context menu
- Top toolbar with buttons
- Command+letter shortcuts
```

Example:
```swift
.menu {
    Button("Copy") { copyItem() }
        .keyboardShortcut("c", modifiers: .command)  // Cmd+C
}
// appears in File or Edit menu

OR

.contextMenu {  // Right-click
    Button("Copy") { copyItem() }
}
```

---

## Text Input & Keyboard

### iOS

- **On-screen keyboard** — virtual keyboard appears over content.
- **Keyboard toolbar** (optional) — small bar above keyboard with Done/Next.
- **Predictive text** — suggestions and auto-correct.
- **Gestures**: Swipe on keyboard for cursor movement (sometimes).

### macOS

- **Physical keyboard** — always available.
- **No on-screen keyboard** — but text field behavior same.
- **Command shortcuts** — Cmd+A (select all), Cmd+C (copy), Cmd+V (paste) standard.
- **Tab navigation** — Tab moves between fields (no Return to submit unless custom).

---

## Multitasking & Window Management

### iOS

- **Single app full-screen** (default).
- **Split View** (iPad): Two apps side-by-side (1/2 + 1/2, or 1/3 + 2/3).
- **Slide Over** (iPad): Third app slides over in panel.
- **Picture-in-Picture** (iPad/macOS): Floating video window.

### macOS

- **Windows standard**: Open multiple windows of same app.
- **Tabs in window**: One window with multiple tabs (like Safari).
- **Full-screen mode**: Cmd+Control+F → full-screen, separate space.
- **Mission Control**: Swipe up (trackpad) → see all windows/spaces.
- **Stage Manager** (macOS 13+): Organize windows visually.

### SwiftUI Implication

```swift
// iOS: NavigationStack + TabView
TabView {
    NavigationStack { ... }  // Each tab has its own stack
}

// macOS: NavigationSplitView (can open separate windows)
NavigationSplitView {
    Sidebar()
} detail: {
    ContentDetail()
}
// + File menu → "New Window" → Opens new window
```

---

## Interaction Models

### iOS

| Interaction | Gesture | Behavior |
|-------------|---------|----------|
| Select item | Tap | Highlight + action |
| Menu | Long-press | Context menu appears |
| Navigate back | Swipe from left edge | Pop stack |
| Dismiss | Swipe down (sheet) | Sheet closes |
| Scroll | Swipe/flick | Momentum scroll |

### macOS

| Interaction | Gesture | Behavior |
|-------------|---------|----------|
| Select item | Click | Highlight + single-select |
| Menu | Right-click | Context menu appears |
| Navigate back | Click back button | Pop navigation |
| Dismiss | Click X or Cmd+W | Window closes |
| Scroll | Mouse wheel / trackpad | Precise control |

---

## UI Layout & Density

### iOS

- **Generous spacing** — Large hit targets (44pt minimum).
- **Vertical scrolling** — Lists scroll vertically (full-width).
- **Top-aligned**: Most content aligned to top (full screen).
- **Portrait first**: Design for portrait, adapt to landscape.

### macOS

- **Compact spacing** — More information per screen.
- **Horizontal scrolling**: Lists may scroll horizontally if many columns.
- **Flexible layout**: Content can float anywhere in window.
- **Landscape first**: Most content designed for landscape.

### Example: List Layout

**iOS:**
```
┌──────────────────┐
│ Home             │ (top)
├──────────────────┤
│ ▼ Items          │
│ • Item 1         │ (generous)
│ • Item 2         │ (vertical)
│ • Item 3         │
│                  │ (scroll)
│ • Item 4         │
│ • Item 5         │
└──────────────────┘
```

**macOS:**
```
┌─────────────────────────────────┐
│ Home                      [Sort] │ (compact)
├─────────────────────────────────┤
│ Item  │ Category │ Date         │ (table)
│ Item1 │ Work     │ 2024-08-24   │ (dense)
│ Item2 │ Personal │ 2024-08-23   │
│ Item3 │ Work     │ 2024-08-22   │
└─────────────────────────────────┘
```

---

## Defaults & Settings

### iOS

- **In-app settings screen** — Access Settings → Your App → toggle options.
- **No system preferences** — Settings inside the app.

### macOS

- **App Preferences** — Cmd+, (comma) → window.
- **System Preferences**: Some settings in System Settings (trackpad, language, etc.).
- **Menu → Preferences** standard.

### SwiftUI

```swift
// iOS: Settings view inside app
NavigationLink("Settings", destination: SettingsView())

// macOS: Preferences window (separate)
.preferenceWindow(id: "preferences") {
    PreferencesView()
}
.keyboardShortcut(",", modifiers: .command)
```

---

## Keyboard Support

### iOS

- **Tab navigation** — Sometimes, but swipe/tap primary.
- **Keyboard shortcuts** — Limited, secondary.
- **Physical keyboard** (iPad): Supported but not primary.

### macOS

- **Tab/Shift+Tab** — Navigate between fields (expected).
- **Arrow keys** — Navigate lists, sidebars.
- **Command shortcuts** — Cmd+S (save), Cmd+N (new), Cmd+Q (quit).
- **Full keyboard navigation** — Every action reachable via keyboard.

### Best Practice

Always make keyboard navigation full on macOS:

```swift
// Button with keyboard shortcut
Button("Save") { save() }
    .keyboardShortcut("s", modifiers: .command)

// Or in menu
.menu {
    Button("Save") { save() }
        .keyboardShortcut("s", modifiers: .command)
}
```

---

## Accessibility Differences

### iOS

- **VoiceOver** — Primary accessibility tech (touch-based).
- **Haptics** — Tactile feedback for actions (critical).
- **Dynamic Type** — Text size scaling (major).
- **Reduced Motion** — Important for animations.

### macOS

- **VoiceOver** — Available but less critical (keyboard nav compensates).
- **Keyboard navigation** — Primary for accessibility (not secondary).
- **Contrast** — Important on larger screens.
- **Pointer size** — Cursor should be visible/resizable.

---

## Adaptive Design Strategy

### Single Codebase (SwiftUI)

```swift
@Environment(\.horizontalSizeClass) var sizeClass

ZStack {
    if sizeClass == .compact {
        // iOS: TabView + Stack
        iOSLayout()
    } else {
        // iPad/macOS: Split View
        macOSLayout()
    }
}
```

Or use `@Environment` to detect platform:

```swift
#if os(iOS)
    // iOS-specific code
#elseif os(macOS)
    // macOS-specific code
#endif
```

### When to Diverge

- **Navigation**: iOS tab bar ≠ macOS sidebar → use conditional.
- **Menus**: iOS menu button ≠ macOS menu bar → use conditional.
- **Windows**: iOS modal ≠ macOS resizable window → conditional.
- **Keyboard**: macOS requires full keyboard nav → handle in macOS path.

---

## Platform-Specific Checklists

### iOS Checklist

- [ ] Tab bar or navigation stack (not sidebar).
- [ ] Touch targets ≥ 44pt.
- [ ] Gestures (swipe back, long-press context menu).
- [ ] VoiceOver compatible.
- [ ] Haptics for important actions.
- [ ] Keyboard dismiss for text input.
- [ ] Safe area respected (notch, home indicator).
- [ ] Portrait + landscape both work.

### macOS Checklist

- [ ] Menu bar (File, Edit, View, ...).
- [ ] Full keyboard navigation.
- [ ] Right-click context menu.
- [ ] Command shortcuts for common actions (Cmd+S, Cmd+N, Cmd+Q).
- [ ] Resizable windows.
- [ ] Sidebar navigation (NavigationSplitView preferred).
- [ ] Support for multiple windows.
- [ ] Menu bar items accessible (not hidden).

---

## Fecha de recolección

2026-08-24
