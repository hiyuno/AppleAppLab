import SwiftUI
import SwiftData

/// Push detail for a single card — DESIGN_LIQUID.md § "Detalle de tarjeta individual": same
/// pattern as `LoanDetailView`'s revolving header + real-vs-projected table, plus a
/// utilization field that's new to cards (no `Loan` equivalent).
struct CreditCardDetailView: View {
    let card: CreditCard
    @Environment(\.modelContext) private var context
    @State private var isPresentingEdit = false

    @AppStorage("fintrol.creditCardPaymentDateRuleKind") private var dateRuleKind = 2
    @AppStorage("fintrol.creditCardPaymentDateRuleDays") private var dateRuleDays = 5
    private var dateRule: CreditCardPaymentDateRule { .resolve(kindRaw: dateRuleKind, days: dateRuleDays) }

    private var today: CivilDate { CivilDate.today() }

    /// "Chase •••• 4242" — same rule as `CreditCardRow`.
    private var nameWithLastFour: String {
        guard let lastFour = card.lastFourDigits, !lastFour.isEmpty else { return card.name }
        return "\(card.name) •••• \(lastFour)"
    }

    private var paidToDate: Decimal { PeriodCoordinator.creditCardPaidToDate(creditCardID: card.id, context: context) }
    private var lastPaymentDateText: String {
        PeriodCoordinator.creditCardLastPaymentDate(creditCardID: card.id, context: context)
            .map { $0.date(calendar: .current).formatted(date: .abbreviated, time: .omitted) } ?? "—"
    }

    /// Next payment date, computed the same way `reprojectCreditCard` does — reused, not a
    /// second date formula.
    private var nextDueDate: CivilDate {
        CreditCardEngine.paymentDate(cutoffDay: card.cutoffDay, paymentDay: card.paymentDay, year: today.year, month: today.month, rule: dateRule)
    }

    /// Display-only multi-row projection (unlike `reprojectCreditCard`'s single anchored row
    /// per materialization pass) — anchored at the next upcoming due date, `card.balance` as
    /// the live starting principal, reusing `LoanEngine.revolvingSchedule` for the real-vs-
    /// projected mixing exactly like `Loan.revolving`'s own detail table.
    private var scheduleAnchor: CivilDate {
        nextDueDate >= today ? nextDueDate : nextDueDate.addingMonths(1)
    }

    private var expected: Decimal {
        card.expectedPayment ?? CreditCardEngine.suggestedMinimumPayment(balance: card.balance, apr: card.apr)
    }

    private var result: LoanEngine.RevolvingResult {
        LoanEngine.revolvingSchedule(
            principal: card.balance, apr: card.apr, expectedPayment: expected,
            frequency: .monthly(day: scheduleAnchor.day), start: scheduleAnchor, actualPayments: [:]
        )
    }

    private var interestToDate: Decimal {
        LoanEngine.accumulatedInterest(revolvingRows: result.rows, through: today)
    }

    private var currentBalance: Decimal {
        card.balance + interestToDate - paidToDate
    }

    private var utilization: Double {
        guard card.creditLimit > 0 else { return 0 }
        let fraction = card.balance / card.creditLimit
        return max(0, min(1, Double(truncating: fraction as NSDecimalNumber)))
    }

    private var utilizationLevel: CreditCardEngine.UtilizationLevel {
        CreditCardEngine.utilizationLevel(balance: card.balance, creditLimit: card.creditLimit)
    }

    private var utilizationColor: Color {
        switch utilizationLevel {
        case .low: .green
        case .medium: .yellow
        case .high: .red
        }
    }

    private var utilizationLevelText: String {
        switch utilizationLevel {
        case .low: "Utilización baja"
        case .medium: "Utilización media"
        case .high: "Utilización alta"
        }
    }

    private var nextRow: LoanEngine.RevolvingRow? { result.rows.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                table
            }
            .padding(16)
        }
        .navigationTitle(nameWithLastFour)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { isPresentingEdit = true }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            CreditCardEditSheet(card: card)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SALDO ACTUAL")
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(currentBalance.currencyString(currency: .usd))
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()

            Divider().padding(.vertical, 4)

            detailRow("Límite de crédito", card.creditLimit.currencyString(currency: .usd))
            // Coordinator (2026-09-17): replaced the single-threshold "≥30% naranja" rule
            // with a real 3-tier semaphore (green <10%, yellow 10–29.99%, red ≥30%) —
            // researched against myFICO/Experian/CFPB/NerdWallet. Still its own scale, not
            // the sobrante semaphore's thresholds — never color alone, the level name is
            // always spelled out in text too.
            HStack {
                Text("Utilización")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((utilization * 100).rounded()))% · \(utilizationLevelText)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(utilizationColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(utilizationLevelText), \(Int((utilization * 100).rounded())) por ciento")
            UtilizationProgressBar(value: utilization, level: utilizationLevel)

            detailRow("Interés acumulado a la fecha", interestToDate.currencyString(currency: .usd))
            detailRow("Fecha del último pago", lastPaymentDateText)
            if let nextRow {
                detailRow("Próximo pago", "\(nextRow.payment.currencyString(currency: .usd)) · \(nextRow.date.date(calendar: .current).formatted(.dateTime.day().month(.abbreviated)))")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saldo actual \(currentBalance.currencyString(currency: .usd))")
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var table: some View {
        let rows = result.rows
        #if os(macOS)
        Table(rows) {
            TableColumn("Fecha") { row in
                Text(row.date.date(calendar: .current).formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(row.date <= today ? Color.secondary : .primary)
            }
            TableColumn("Pago") { row in
                HStack(spacing: 4) {
                    Text(row.payment.currencyString(currency: .usd)).monospacedDigit()
                    if row.isProjected { Text("Proyectado").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            TableColumn("Interés") { row in Text(row.interest.currencyString(currency: .usd)).monospacedDigit() }
            TableColumn("Saldo") { row in Text(row.remainingBalance.currencyString(currency: .usd)).monospacedDigit() }
        }
        .frame(minHeight: 320)
        #else
        LazyVStack(spacing: 0) {
            ForEach(rows, id: \.index) { row in
                tableRow(row)
                if row.index != rows.count { Divider() }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        #endif
    }

    private func tableRow(_ row: LoanEngine.RevolvingRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(row.date.date(calendar: .current).formatted(date: .abbreviated, time: .omitted))
                if row.isProjected {
                    Text("Proyectado")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(row.payment.currencyString(currency: .usd)).monospacedDigit()
            }
            .font(.body)
            HStack {
                Text("Interés \(row.interest.currencyString(currency: .usd))")
                Spacer()
                Text("Saldo \(row.remainingBalance.currencyString(currency: .usd))")
            }
            .font(.caption)
            .monospacedDigit()
        }
        .foregroundStyle(row.date <= today ? Color.secondary : .primary)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
