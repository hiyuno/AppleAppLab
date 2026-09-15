import SwiftUI

/// Salto de año/quincena arbitraria (DESIGN_LIQUID.md). Presented as `.sheet` on iPhone,
/// `.popover` on Mac by the caller.
struct JumpSheet: View {
    let earliest: PeriodCoordinate
    let onJump: (PeriodCoordinate) -> Void
    let onToday: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var year: Int
    @State private var month: Int
    @State private var half: PeriodHalf

    init(current: PeriodCoordinate, earliest: PeriodCoordinate, onJump: @escaping (PeriodCoordinate) -> Void, onToday: @escaping () -> Void) {
        self.earliest = earliest
        self.onJump = onJump
        self.onToday = onToday
        _year = State(initialValue: current.year)
        _month = State(initialValue: current.month)
        _half = State(initialValue: current.half)
    }

    private var years: [Int] {
        let currentYear = Calendar.gregorianUTC.component(.year, from: Date())
        return Array(min(earliest.year, currentYear)...(currentYear + 10))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Año", selection: $year) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }
                .accessibilityHint("Elige el año de la quincena")
                Picker("Mes", selection: $month) {
                    ForEach(1...12, id: \.self) { month in
                        Text(localizedMonthName(month)).tag(month)
                    }
                }
                .accessibilityHint("Elige el mes de la quincena")
                Picker("Quincena", selection: $half) {
                    Text("1–15").tag(PeriodHalf.first)
                    Text("16–fin").tag(PeriodHalf.second)
                }
                .pickerStyle(.segmented)
                .accessibilityHint("Elige la primera o segunda quincena del mes")

                Button("Hoy") {
                    onToday()
                    dismiss()
                }
                .accessibilityLabel("Ir a hoy")
            }
            .navigationTitle("Ir a quincena")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ir") {
                        onJump(PeriodCoordinate(year: year, month: month, half: half))
                        dismiss()
                    }
                    .accessibilityLabel("Ir a \(localizedMonthName(month)) \(year), quincena \(half == .first ? "1" : "2")")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 320, minHeight: 280)
        #endif
    }
}
