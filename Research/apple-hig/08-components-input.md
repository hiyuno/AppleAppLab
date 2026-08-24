# Input Components: Toggle, Picker, Stepper, Slider

**Fuentes**:
- https://developer.apple.com/design/human-interface-guidelines/toggles
- https://developer.apple.com/design/human-interface-guidelines/pickers/
- https://developer.apple.com/design/human-interface-guidelines/steppers
- https://developer.apple.com/design/human-interface-guidelines/components/selection-and-input/sliders
- Apple HIG Components

**En una frase**: Componentes reutilizables para entrada de datos, selección de valores y control de estado binario.

---

## Toggle

**What**: A control that lets users choose between two opposing states (On/Off, Enabled/Disabled).

### Visual Design

- **Switch-style**: iOS standard, appears as oval capsule.
- **States**:
  - **Off** (default): Gray background, circle on left, no fill.
  - **On**: Blue background (or tint color), circle on right, filled.
  - **Disabled** (off): Gray, reduced opacity.
  - **Disabled (on)**: Blue, reduced opacity.

### When to Use Toggle

- **Simple binary choice** — Notifications on/off, dark mode, Wi-Fi enabled.
- **Immediate effect** — No confirmation button needed.
- **Visible state** — User needs to see current state at a glance.

### When NOT to Use Toggle

- **Complex choice** — Use radio buttons or picker.
- **Consequences unknown** — Explain consequences first, then offer toggle.
- **Multiple options** — Use segmented control or picker.

### Sizing & Labels

- **Min touch target**: 44pt height (includes label).
- **Label placement**: Left of toggle (iOS) or above (iPadOS/macOS).
- **Secondary label**: Small text explaining what each state means (optional, uncommon).

### SwiftUI Implementation

```swift
@State private var isEnabled = false

Toggle("Enable Notifications", isOn: $isEnabled)
    .tint(.blue)

// With custom label
Toggle(isOn: $isEnabled) {
    VStack(alignment: .leading) {
        Text("Dark Mode")
        Text("Easier on the eyes").font(.caption).foregroundStyle(.secondary)
    }
}
```

### Accessibility

- **Label required**: Toggle must have text label (not just icon).
- **VoiceOver**: "Dark Mode, toggle button, on" or "off".
- **Dynamic Type**: Label scales appropriately.
- **Focus**: 44pt touch target for keyboard navigation.

---

## Picker

**What**: A control that displays one or more scrollable lists for users to select values.

### Types of Pickers

#### 1. Wheel Picker (iOS Default)

- Vertical scrollable "wheel" with values.
- User scrolls to select.
- Typically used in modals or sheets.

```swift
@State private var selectedFruit = "Apple"

Picker("Fruit", selection: $selectedFruit) {
    ForEach(["Apple", "Orange", "Banana"], id: \.self) { fruit in
        Text(fruit).tag(fruit)
    }
}
.pickerStyle(.wheel)
```

#### 2. Menu Picker (iOS 15+)

- Appears as button showing selected value.
- Taps opens menu with options.
- Space-efficient, preferred for most iOS screens.

```swift
Picker("Fruit", selection: $selectedFruit) {
    ForEach(["Apple", "Orange", "Banana"], id: \.self) { fruit in
        Text(fruit).tag(fruit)
    }
}
.pickerStyle(.menu)
```

#### 3. Segmented Picker

- Horizontal buttons, one selectable at a time.
- Best for 2-4 options (more → picker menu).

```swift
Picker("Fruit", selection: $selectedFruit) {
    Text("Apple").tag("Apple")
    Text("Orange").tag("Orange")
    Text("Banana").tag("Banana")
}
.pickerStyle(.segmented)
```

#### 4. DatePicker

**Special variant for dates** — choose date, time, or both.

```swift
@State private var birthDate = Date()

DatePicker("Birth Date", selection: $birthDate, displayedComponents: [.date])
    .datePickerStyle(.compact)  // Inline, wheels, or compact
```

### Picker Best Practices

- **Limit options**: < 10 → Use menu picker; > 10 → wheel or search.
- **Group options**: Use Section for grouped picker values (e.g., "Fruits", "Vegetables").
- **Default selection**: Always pre-select sensible default value.
- **Labels**: Clearly label what's being selected.

### DatePicker Variants

- **Wheel style** (default): Large, modal-like interface.
- **Compact style** (iOS 14+): Compact date button with popover.
- **Inline style** (iOS 14+): Calendar grid picker.
- **Graphical style** (macOS): Full calendar.

### SwiftUI DatePicker Code

```swift
@State private var selectedDate = Date()

// Date only
DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])

// Time only
DatePicker("Select Time", selection: $selectedDate, displayedComponents: [.hourAndMinutes])

// Date range (iOS 16+)
DatePicker("Start", selection: $startDate, in: Date()...)
DatePicker("End", selection: $endDate, in: startDate...)
```

---

## Stepper

**What**: A two-button control for increasing/decreasing a numeric value incrementally.

### Visual Design

- **Buttons**: - button (left) and + button (right).
- **Center**: Displays current value or empty space.
- **Sizes**: Regular (standard) or compact (smaller).

### When to Use Stepper

- **Incremental changes** — Adjust quantity, volume, brightness.
- **Small ranges** — 1-100 items (not 1-10000).
- **Fine-grained control** — User adjusts step-by-step.

### When NOT to Use Stepper

- **Continuous range** — Use slider instead.
- **Unknown range** — Use text field.
- **Many options** — Use picker.

### Bounds & Steps

- **Min/Max**: Define clear limits (e.g., 0-10).
- **Step size**: Default 1, but can be custom (0.5, 5, etc.).
- **Disabled state**: Buttons gray out if at boundary.

### SwiftUI Implementation

```swift
@State private var quantity = 1

Stepper("Quantity: \(quantity)", value: $quantity, in: 1...10, step: 1)

// Compact style
Stepper(value: $quantity, in: 1...10) {
    Text("Quantity: \(quantity)")
}

// Custom step
Stepper(value: $volume, in: 0...100, step: 5)
```

### Accessibility

- **Label required**: "Quantity, stepper" — must speak value.
- **Keyboard**: Plus/Minus keys navigate.
- **Touch target**: 44pt minimum.

---

## Slider

**What**: A horizontal track with a thumb control for selecting a continuous value within a range.

### Visual Design

- **Track**: Horizontal line showing range.
- **Thumb**: Circle or capsule that user drags.
- **Min/Max markers** (optional): Labels at ends.
- **Color**: Filled portion left of thumb (tinted).

### When to Use Slider

- **Continuous value** — Volume, brightness, opacity.
- **Visual feedback** — User sees change in real-time.
- **Large range** — 0-100, 0-360°, etc.

### When NOT to Use Slider

- **Discrete values** — Use stepper or picker.
- **Precise input needed** — Use text field.
- **Binary choice** — Use toggle.

### Variants

#### 1. Standard Slider

```swift
@State private var volume: Double = 50

Slider(value: $volume, in: 0...100)
    .tint(.blue)
```

#### 2. Slider with Labels

```swift
Slider(value: $volume, in: 0...100,
       label: { Text("Volume") },
       minimumValueLabel: { Text("0") },
       maximumValueLabel: { Text("100") })
```

#### 3. Range Slider (iOS 16+)

Two thumbs for selecting a range (e.g., price 10-50).

```swift
@State private var range: ClosedRange<Double> = 10...50

Slider(range: $range, in: 0...100)
```

### Step & Precision

- **Step size**: Can snap to discrete values (0, 5, 10, etc.).
- **onEditingChanged**: Callback when user starts/stops dragging.

```swift
Slider(value: $brightness, in: 0...100)
    .onChange(of: brightness) { _, newValue in
        // Update brightness in real-time
    }
```

### Accessibility

- **Label required**: "Volume, slider".
- **Value announced**: "50 percent" or value label.
- **Keyboard**: Arrow keys to adjust.
- **Touch target**: 44pt minimum height.

---

## Component Placement in Forms

**Typical form layout** (top-to-bottom):

```
Section("Settings") {
    Toggle("Notifications", isOn: $notif)          // Binary
    Picker("Notification Type", ...) { ... }       // Multiple choice
    Stepper("Quiet Hours", value: $hours, ...)     // Incremental
    Slider(value: $volume, ...)                    // Continuous
    DatePicker("Expires", selection: $date)        // Date/time
}
```

---

## Platform-Specific Notes

| Component | iOS | macOS | iPadOS |
|-----------|-----|-------|--------|
| **Toggle** | Switch style | Checkbox (and toggle) | Switch style |
| **Picker** | Wheel (modal) | Dropdown menu (default) | Menu or wheel |
| **Stepper** | Two-button | Spinner control | Two-button |
| **Slider** | Vertical or horizontal | Horizontal line | Vertical or horizontal |

---

## Fecha de recolección

2026-08-24
