import SwiftUI
import SwiftData
import AppleAppLabUI

struct OverviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query private var periods: [Period]
    @Query(sort: \RecurringItem.title) private var recurringItems: [RecurringItem]
    @Query(sort: \Subscription.name) private var subscriptions: [Subscription]
    @Query(sort: \Loan.name) private var loans: [Loan]

    @State private var selectedYear: Int = Calendar.gregorianUTC.component(.year, from: .now)

    private var recurringSnapshots: [RecurringItemSnapshot] {
        recurringItems.map {
            RecurringItemSnapshot(id: $0.id, kind: $0.kind, title: $0.title, amount: $0.amount, currency: $0.currency, frequency: $0.frequency, startDate: $0.civilStartDate, endDate: $0.civilEndDate, isActive: $0.isActive, category: $0.category)
        }
    }

    private var subscriptionSnapshots: [SubscriptionSnapshot] {
        subscriptions.map {
            SubscriptionSnapshot(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency, paymentDay: $0.paymentDay, startDate: $0.civilStartDate, endDate: $0.civilEndDate, kind: $0.kind, isActive: $0.isActive, isBiweekly: $0.isBiweekly)
        }
    }

    private var loanSnapshots: [LoanSnapshot] {
        loans.map {
            LoanSnapshot(id: $0.id, name: $0.name, direction: $0.direction, principal: $0.principal, currency: $0.currency, apr: $0.apr, startDate: $0.civilStartDate, termMonths: $0.termMonths, frequency: $0.frequency, paymentOverride: $0.paymentOverride, isActive: $0.isActive)
        }
    }

    private var rate: Decimal { rateStore.currentRate ?? 0 }

    var body: some View {
        Group {
            if periods.isEmpty {
                LabEmptyState(
                    icon: "chart.bar",
                    title: "Sin quincenas todavía",
                    message: "Captura tu primera quincena para ver el resumen aquí",
                    config: PatternConfig(accentColor: .accentColor)
                )
            } else {
                List {
                    Section("Mensual") {
                        ForEach(1...12, id: \.self) { month in
                            monthSection(month: month)
                        }
                    }

                    Section("Anual \(selectedYear)") {
                        annualSummary
                    }
                }
            }
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Coordinator (2026-09-21): the default toolbar `Picker` (no `.pickerStyle`) gets
                // wrapped in a full-width glass capsule by the system's Liquid Glass toolbar
                // rendering — `.fixedSize()` forces it back to hugging its own label ("2026"),
                // matching the user's ask, instead of stretching across the toolbar.
                Picker("Año", selection: $selectedYear) {
                    ForEach(availableYears, id: \.self) { Text(String($0)).tag($0) }
                }
                .fixedSize()
            }
        }
    }

    private var availableYears: [Int] {
        let years = Set(periods.map(\.year))
        let current = Calendar.gregorianUTC.component(.year, from: .now)
        return Array(years.union([current])).sorted()
    }

    private func monthSection(month: Int) -> some View {
        let firstHalf = totals(for: PeriodCoordinate(year: selectedYear, month: month, half: .first))
        let secondHalf = totals(for: PeriodCoordinate(year: selectedYear, month: month, half: .second))
        let monthName = localizedMonthName(month, year: selectedYear)

        return DisclosureGroup(monthName) {
            row(label: "1–15", totals: firstHalf)
            row(label: "16–fin", totals: secondHalf)
        }
    }

    private func row(label: String, totals: (income: Decimal, expense: Decimal, sobrante: Decimal)) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("In: \(totals.income.currencyString())").font(.caption).foregroundStyle(.green)
                Text("Out: \(totals.expense.currencyString())").font(.caption).foregroundStyle(.red)
                Text("Total: \(totals.sobrante.currencyString())").font(.caption.weight(.semibold)).monospacedDigit()
            }
        }
    }

    private var annualSummary: some View {
        var incomeTotal: Decimal = 0
        var expenseTotal: Decimal = 0
        for month in 1...12 {
            for half in [PeriodHalf.first, .second] {
                let t = totals(for: PeriodCoordinate(year: selectedYear, month: month, half: half))
                incomeTotal += t.income
                expenseTotal += t.expense
            }
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Income total")
                Spacer()
                Text(incomeTotal.currencyString()).monospacedDigit().foregroundStyle(.green)
            }
            HStack {
                Text("Outcome total")
                Spacer()
                Text(expenseTotal.currencyString()).monospacedDigit().foregroundStyle(.red)
            }
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text((incomeTotal - expenseTotal).currencyString()).font(.headline).monospacedDigit()
            }
        }
    }

    private func totals(for coordinate: PeriodCoordinate) -> (income: Decimal, expense: Decimal, sobrante: Decimal) {
        PeriodCoordinator.projectedTotals(
            for: coordinate,
            context: context,
            recurringItems: recurringSnapshots,
            subscriptions: subscriptionSnapshots,
            loans: loanSnapshots,
            exchangeRate: rate
        )
    }
}
