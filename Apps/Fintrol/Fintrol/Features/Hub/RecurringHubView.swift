import SwiftUI
import SwiftData
import AppleAppLabUI

/// "Recurrentes y pagos" — hub of 4 entries (iPhone only; macOS sidebar lists these as
/// direct items instead, DESIGN_LIQUID.md). No "+" of its own: each row pushes to its own
/// list, where the "+" lives.
struct RecurringHubView: View {
    @Query private var recurringItems: [RecurringItem]
    @Query private var subscriptions: [Subscription]
    @Query private var loans: [Loan]

    private var incomeCount: Int { recurringItems.filter { $0.kind == .income && $0.category != .investment }.count }
    private var expenseCount: Int { recurringItems.filter { $0.kind == .expense && $0.category != .investment }.count }
    private var serviceCount: Int { subscriptions.filter { $0.kind == .service }.count }
    private var subscriptionCount: Int { subscriptions.filter { $0.kind == .subscription }.count }
    private var loanCount: Int { loans.count }
    private var investmentCount: Int { recurringItems.filter { $0.category == .investment }.count }

    var body: some View {
        // Coordinator (2026-09-15, mockup round 4): grouped into 3 sections whose headers
        // are the literal strings the user chose — "INCOME"/"EXPENSES"/"OTHERS" — NOT a
        // semantic recategorization of the 6 rows (explicitly: Servicios/Suscripciones/
        // Préstamos live under "EXPENSES" even though none of them are income vs. expense
        // classifications on their own; do not "fix" this grouping to be more logical).
        List {
            Section {
                NavigationLink {
                    RecurringListView(kind: .income)
                } label: {
                    row(title: "Ingresos recurrentes", systemImage: "arrow.down.circle", count: incomeCount)
                }
                NavigationLink {
                    RecurringListView(kind: .expense)
                } label: {
                    row(title: "Gastos recurrentes", systemImage: "arrow.up.circle", count: expenseCount)
                }
            } header: {
                sectionHeader("INCOME")
            }

            Section {
                NavigationLink {
                    ServicesView()
                } label: {
                    row(title: "Servicios", systemImage: "house.fill", count: serviceCount)
                }
                NavigationLink {
                    SubscriptionsView()
                } label: {
                    row(title: "Suscripciones", systemImage: "repeat", count: subscriptionCount)
                }
                NavigationLink {
                    LoansView()
                } label: {
                    row(title: "Préstamos", systemImage: "banknote", count: loanCount)
                }
            } header: {
                sectionHeader("EXPENSES")
            }

            Section {
                NavigationLink {
                    InvestmentsView()
                } label: {
                    row(title: "Inversiones", systemImage: "chart.line.uptrend.xyaxis", count: investmentCount)
                }
            } header: {
                sectionHeader("OTHERS")
            }
        }
        .navigationTitle("Recurrentes y pagos")
    }

    // Same header style already used in Ajustes (SettingsView): caption, uppercase, secondary.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
    }

    private func row(title: String, systemImage: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(count == 1 ? "1 elemento" : "\(count) elementos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
