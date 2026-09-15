import SwiftUI

struct LoanDetailView: View {
    let loan: Loan

    private var snapshot: LoanSnapshot {
        LoanSnapshot(id: loan.id, name: loan.name, direction: loan.direction, principal: loan.principal, currency: loan.currency, apr: loan.apr, startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency, paymentOverride: loan.paymentOverride, isActive: loan.isActive)
    }

    private var schedule: [LoanInstallment] { LoanEngine.schedule(for: snapshot) }
    private var today: CivilDate { CivilDate.today() }
    private var lastPast: LoanInstallment? { schedule.last { $0.date <= today } }
    private var currentInstallment: LoanInstallment? { schedule.first { $0.date > today } }
    private var currentBalance: Decimal { lastPast?.remainingBalance ?? loan.principal }
    private var paidToDate: Decimal { loan.principal - currentBalance }
    private var totalInterest: Decimal { schedule.reduce(Decimal(0)) { $0 + $1.interest } }

    private var isDebo: Bool { loan.direction == .borrowed }
    private var tintColor: Color { isDebo ? .orange : .blue }

    private var endDateText: String {
        LoanEngine.endDate(startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency)
            .date(calendar: .current)
            .formatted(.dateTime.month(.abbreviated).year())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                amortizationTable
            }
            .padding(16)
        }
        .navigationTitle(loan.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SALDO RESTANTE")
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(currentBalance.currencyString(currency: loan.currency))
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tintColor)

            Divider().padding(.vertical, 4)

            detailRow("Pagado a la fecha", paidToDate.currencyString(currency: loan.currency))
            detailRow("Interés total", totalInterest.currencyString(currency: loan.currency))
            if let currentInstallment {
                detailRow("Próximo pago", "\(currentInstallment.payment.currencyString(currency: loan.currency)) · \(currentInstallment.date.date(calendar: .current).formatted(.dateTime.day().month(.abbreviated)))")
            }
            detailRow("Fecha de fin", endDateText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saldo restante \(currentBalance.currencyString(currency: loan.currency))")
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
    private var amortizationTable: some View {
        #if os(macOS)
        Table(schedule) {
            TableColumn("Fecha") { installment in
                Text(installment.date.date(calendar: .current).formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(rowColor(for: installment))
            }
            TableColumn("Pago") { installment in
                Text(installment.payment.currencyString(currency: loan.currency)).monospacedDigit()
                    .foregroundStyle(rowColor(for: installment))
            }
            TableColumn("Interés") { installment in
                Text(installment.interest.currencyString(currency: loan.currency)).monospacedDigit()
                    .foregroundStyle(rowColor(for: installment))
            }
            TableColumn("Capital") { installment in
                Text(installment.principal.currencyString(currency: loan.currency)).monospacedDigit()
                    .foregroundStyle(rowColor(for: installment))
            }
            TableColumn("Saldo") { installment in
                Text(installment.remainingBalance.currencyString(currency: loan.currency)).monospacedDigit()
                    .foregroundStyle(rowColor(for: installment))
            }
        }
        .frame(minHeight: 320)
        #else
        LazyVStack(spacing: 0) {
            ForEach(schedule, id: \.number) { installment in
                amortizationRow(installment)
                if installment.number != schedule.count {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        #endif
    }

    private func amortizationRow(_ installment: LoanInstallment) -> some View {
        let isCurrent = currentInstallment?.number == installment.number
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(installment.date.date(calendar: .current).formatted(date: .abbreviated, time: .omitted))
                Spacer()
                Text(installment.payment.currencyString(currency: loan.currency))
                    .monospacedDigit()
            }
            .font(.body)
            HStack {
                Text("Interés \(installment.interest.currencyString(currency: loan.currency)) · Capital \(installment.principal.currencyString(currency: loan.currency))")
                Spacer()
                Text("Saldo \(installment.remainingBalance.currencyString(currency: loan.currency))")
            }
            .font(.caption)
            .monospacedDigit()
        }
        .foregroundStyle(rowColor(for: installment))
        .padding(.vertical, 8)
        .padding(.horizontal, isCurrent ? 8 : 0)
        .background(
            isCurrent
                ? RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.12))
                : nil
        )
        .accessibilityElement(children: .combine)
    }

    private func rowColor(for installment: LoanInstallment) -> Color {
        // Fila ya pagada o futura: .secondary; fila actual: .primary (único color de acento).
        installment.date <= today || currentInstallment?.number != installment.number ? .secondary : .primary
    }
}
