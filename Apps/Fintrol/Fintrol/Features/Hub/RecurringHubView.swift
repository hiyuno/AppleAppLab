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
        List {
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
            NavigationLink {
                InvestmentsView()
            } label: {
                row(title: "Inversiones", systemImage: "chart.line.uptrend.xyaxis", count: investmentCount)
            }
        }
        .navigationTitle("Recurrentes y pagos")
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
