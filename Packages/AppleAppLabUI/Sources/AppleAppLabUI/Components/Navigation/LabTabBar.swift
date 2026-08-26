import SwiftUI

public struct LabTabItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let symbolName: String

    public init(title: String, symbolName: String) {
        self.title = title
        self.symbolName = symbolName
    }
}

public struct LabTabBar: View {
    let items: [LabTabItem]
    @Binding var selection: Int
    let config: PatternConfig

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(items: [LabTabItem], selection: Binding<Int>, config: PatternConfig) {
        self.items = items
        self._selection = selection
        self.config = config
    }

    public var body: some View {
        HStack(spacing: config.spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    withAnimation(reduceMotion ? .none : .spring(response: config.duration, dampingFraction: 0.8)) {
                        selection = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbolName)
                        Text(item.title).font(.caption2)
                    }
                    .foregroundStyle(selection == index ? config.accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 8)
        .background(
            LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                .fill(.regularMaterial)
        )
    }
}

#Preview {
    LabTabBar(
        items: [
            LabTabItem(title: "Home", symbolName: "house"),
            LabTabItem(title: "Search", symbolName: "magnifyingglass"),
            LabTabItem(title: "Profile", symbolName: "person")
        ],
        selection: .constant(0),
        config: PatternConfig()
    )
    .padding()
}
