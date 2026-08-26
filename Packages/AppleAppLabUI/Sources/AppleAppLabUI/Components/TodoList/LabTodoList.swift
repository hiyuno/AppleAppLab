import SwiftUI
import UniformTypeIdentifiers

public struct LabTodoItem: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var isDone: Bool

    public init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

public struct LabTodoList: View {
    @Binding var items: [LabTodoItem]
    let config: PatternConfig

    @State private var draggingID: String?
    @State private var targetID: String?
    @State private var dragToken: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(items: Binding<[LabTodoItem]>, config: PatternConfig) {
        self._items = items
        self.config = config
    }

    public var body: some View {
        VStack(spacing: config.spacing) {
            ForEach(items) { item in
                VStack(spacing: 4) {
                    if isInsertionPoint(item) {
                        ghostSlot(for: item)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                // No fade on removal: the ghost must be gone the instant the
                                // real row starts animating in, or the two visibly overlap.
                                removal: .identity
                            ))
                    }

                    if draggingID != item.id.uuidString {
                        row(for: item)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 1.2).combined(with: .opacity),
                                removal: .opacity.combined(with: .scale(scale: 0.96))
                            ))
                    }
                }
                .animation(reduceMotion ? .none : .easeOut(duration: 0.12), value: targetID)
                .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: draggingID)
                // `dragPayload(for:)` is the actual payload autoclosure the system
                // evaluates the instant it commits to starting the drag — a single,
                // synchronous hook, unlike the preview's onAppear below (which depends
                // on SwiftUI's async view-mounting and was landing late or being skipped
                // for some items, leaving their row stuck visible).
                .draggable(dragPayload(for: item)) {
                    rowContent(for: item)
                        .padding(12)
                        .background(
                            LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                                .fill(.background)
                        )
                        .frame(width: 240)
                        .onAppear { beginDrag(item) }
                        .onDisappear { scheduleEndDrag() }
                }
                .dropDestination(for: String.self) { droppedIDs, _ in
                    move(droppedIDs: droppedIDs, onto: item)
                } isTargeted: { isTargeted in
                    // Only ever advance the target forward — never clear it on `false`.
                    // Showing the ghost slot shifts layout under the cursor, which can
                    // fire a spurious `false` immediately after `true` for the same row
                    // (classic DnD feedback loop). The target only changes when a
                    // *different* row reports `true`, or when the drop completes.
                    guard isTargeted, targetID != item.id.uuidString else { return }
                    targetID = item.id.uuidString
                    announce("Move before \(item.title)")
                }
            }
        }
    }

    private func dragPayload(for item: LabTodoItem) -> String {
        beginDrag(item)
        return item.id.uuidString
    }

    private func beginDrag(_ item: LabTodoItem) {
        // Always claim a fresh token, even if draggingID is already correct, so any
        // pending scheduleEndDrag() clear from a spurious/stale signal gets invalidated
        // as long as at least one of the two start signals keeps firing.
        dragToken += 1
        if draggingID != item.id.uuidString {
            draggingID = item.id.uuidString
            announce("Picked up \(item.title)")
        }
    }

    /// Safety net: if the drag is cancelled (dropped outside any valid target) neither
    /// signal's "end" is guaranteed to mean the drag is truly over on its own, so this
    /// clear is debounced against the token — if a fresh beginDrag() lands before this
    /// fires, the token has already moved on and the clear is skipped.
    private func scheduleEndDrag() {
        let token = dragToken
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            if dragToken == token {
                draggingID = nil
                targetID = nil
            }
        }
    }

    private func isInsertionPoint(_ item: LabTodoItem) -> Bool {
        targetID == item.id.uuidString && draggingID != item.id.uuidString
    }

    /// Uses the real row content, hidden, so the ghost slot matches the exact size
    /// the dragged item will occupy once dropped here — no guessed/fixed height.
    private func ghostSlot(for item: LabTodoItem) -> some View {
        rowContent(for: item)
            .padding(12)
            .opacity(0)
            .accessibilityHidden(true)
            .background(
                LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                    .fill(config.accentColor.opacity(0.08))
            )
            .overlay(
                LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                    .stroke(config.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            )
    }

    private func row(for item: LabTodoItem) -> some View {
        rowContent(for: item)
            .padding(12)
            .background(
                LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                    .fill(.quaternary.opacity(0.3 * config.surfaceOpacityMultiplier))
            )
    }

    private func rowContent(for item: LabTodoItem) -> some View {
        HStack(spacing: 12) {
            Button {
                toggle(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? config.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Marcar como pendiente" : "Marcar como hecho")

            Text(item.title)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)

            Spacer()

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: item.isDone ? "Marcar como pendiente" : "Marcar como hecho") {
            toggle(item)
        }
        .accessibilityAction(named: "Move Up") {
            moveWithoutDrag(item, by: -1)
        }
        .accessibilityAction(named: "Move Down") {
            moveWithoutDrag(item, by: 1)
        }
    }

    private func toggle(_ item: LabTodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isDone.toggle()
    }

    /// Accessible alternative to drag reordering — no pointer/drag gesture required.
    private func moveWithoutDrag(_ item: LabTodoItem, by offset: Int) {
        guard let index = items.firstIndex(of: item) else { return }
        let newIndex = index + offset
        guard items.indices.contains(newIndex) else { return }
        withAnimation(reduceMotion ? .none : .spring(response: config.duration, dampingFraction: 0.8)) {
            items.swapAt(index, newIndex)
        }
        announce("Moved \(item.title) to position \(newIndex + 1) of \(items.count)")
    }

    private func move(droppedIDs: [String], onto target: LabTodoItem) -> Bool {
        guard let droppedID = droppedIDs.first,
              let sourceIndex = items.firstIndex(where: { $0.id.uuidString == droppedID }),
              let targetIndex = items.firstIndex(of: target) else {
            return false
        }
        let movedItem = items[sourceIndex]
        // Low damping (0.7) made the settle visibly bouncy/slow, reading as if the
        // ghost's gap lingered — even though the ghost view itself is already instant.
        // Higher damping here kills the overshoot so the reorder reads as snappy.
        withAnimation(reduceMotion ? .none : .spring(response: min(config.duration, 0.3), dampingFraction: 0.9)) {
            let item = items.remove(at: sourceIndex)
            items.insert(item, at: targetIndex)
            draggingID = nil
            targetID = nil
        }
        announce("Dropped. \(movedItem.title) moved to position \(targetIndex + 1) of \(items.count)")
        return true
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview {
    @Previewable @State var items = [
        LabTodoItem(title: "Diseñar el inspector", isDone: true),
        LabTodoItem(title: "Implementar drag & drop"),
        LabTodoItem(title: "Pulir animación de reorder")
    ]

    LabTodoList(items: $items, config: PatternConfig())
        .padding()
        .frame(width: 320)
}
