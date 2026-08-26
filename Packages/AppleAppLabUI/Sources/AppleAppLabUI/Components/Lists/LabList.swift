import SwiftUI

public struct LabListRow: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let symbolName: String

    public init(title: String, subtitle: String, symbolName: String) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
    }
}

public struct LabList: View {
    let rows: [LabListRow]
    let config: PatternConfig

    public init(rows: [LabListRow], config: PatternConfig) {
        self.rows = rows
        self.config = config
    }

    public var body: some View {
        VStack(spacing: config.spacing) {
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    Image(systemName: row.symbolName)
                        .foregroundStyle(config.accentColor)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.body)
                        Text(row.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    LabShape(radius: config.cornerRadius, style: config.cornerStyle)
                        .fill(.quaternary.opacity(0.3 * config.surfaceOpacityMultiplier))
                )
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    LabList(
        rows: [
            LabListRow(title: "Downloads", subtitle: "128 items", symbolName: "arrow.down.circle"),
            LabListRow(title: "Documents", subtitle: "56 items", symbolName: "doc"),
            LabListRow(title: "Photos", subtitle: "1,204 items", symbolName: "photo")
        ],
        config: PatternConfig()
    )
    .padding()
    .frame(width: 320)
}
