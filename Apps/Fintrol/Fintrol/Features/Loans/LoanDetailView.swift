import SwiftUI
import SwiftData

struct LoanDetailView: View {
    let loan: Loan
    @Environment(\.modelContext) private var context
    // Coordinator (2026-09-16): "Editar" in the detail toolbar reuses `LoanEditSheet` (same
    // form LoansView uses for "Nuevo préstamo"/its own "Editar" swipe action) instead of a
    // second implementation — same validation, same `reprojectLoan` + `isManuallyEdited`
    // respect on save.
    @State private var isPresentingEdit = false

    private var isRevolving: Bool { loan.mode == .revolving }

    private var snapshot: LoanSnapshot {
        LoanSnapshot(id: loan.id, name: loan.name, direction: loan.direction, principal: loan.principal, currency: loan.currency, apr: loan.apr, startDate: loan.civilStartDate, termMonths: loan.termMonths, frequency: loan.frequency, paymentOverride: loan.paymentOverride, isActive: loan.isActive, mode: loan.mode, expectedPayment: loan.expectedPayment)
    }

    private var schedule: [LoanInstallment] { LoanEngine.schedule(for: snapshot) }
    private var today: CivilDate { CivilDate.today() }
    private var currentInstallment: LoanInstallment? { schedule.first { $0.date > today } }
    // TRD "paidAt/progreso real de préstamos" (2026-09-16): `paidToDate` is the real,
    // user-confirmed sum (`PeriodCoordinator.loanPaidToDate`) — no longer derived from the
    // schedule by elapsed time. `currentBalance` = principal + accumulated interest through
    // today − that real paidToDate.
    private var paidToDate: Decimal { PeriodCoordinator.loanPaidToDate(loanID: loan.id, context: context) }
    private var lastPaymentDateText: String {
        PeriodCoordinator.loanLastPaymentDate(loanID: loan.id, context: context)
            .map { $0.date(calendar: .current).formatted(date: .abbreviated, time: .omitted) } ?? "—"
    }
    private var currentBalance: Decimal {
        loan.principal + LoanEngine.accumulatedInterest(schedule: schedule, through: today) - paidToDate
    }
    private var totalInterest: Decimal { schedule.reduce(Decimal(0)) { $0 + $1.interest } }

    // MARK: - Revolving ("Hasta liquidar")

    /// Real payments (`sourceLoanID` + `isManuallyEdited` lines from every materialized
    /// period), so this detail screen — unlike `LoanRow`'s list-only projection — reflects
    /// any edit the user has already made, per the coordinator's "editar el pago a $150
    /// recalcula" requirement.
    private var revolvingActualPayments: [CivilDate: Decimal] {
        guard isRevolving else { return [:] }
        let allPeriods = ((try? context.fetch(FetchDescriptor<Period>())) ?? []).sorted { $0.coordinate < $1.coordinate }
        var result: [CivilDate: Decimal] = [:]
        var index = 0
        for period in allPeriods {
            guard let line = (period.lineItems ?? []).first(where: { $0.sourceLoanID == loan.id }) else { continue }
            index += 1
            guard line.isManuallyEdited else { continue }
            let date = LoanEngine.revolvingInstallmentDate(index: index, start: loan.civilStartDate, frequency: loan.frequency)
            result[date] = line.amount
        }
        return result
    }

    private var revolvingResult: LoanEngine.RevolvingResult? {
        guard isRevolving, let expected = loan.expectedPayment else { return nil }
        return LoanEngine.revolvingSchedule(principal: loan.principal, apr: loan.apr, expectedPayment: expected, frequency: loan.frequency, start: loan.civilStartDate, actualPayments: revolvingActualPayments)
    }

    private var revolvingNext: LoanEngine.RevolvingRow? { revolvingResult?.rows.first { $0.date > today } }
    private var revolvingInterestToDate: Decimal {
        LoanEngine.accumulatedInterest(revolvingRows: revolvingResult?.rows ?? [], through: today)
    }
    // Same real-paidToDate formula as `.fixedTerm` above — revolving loans use the same
    // `PeriodCoordinator.loanPaidToDate`/`paidAt` mechanism, not a schedule-derived balance.
    private var revolvingBalance: Decimal {
        loan.principal + revolvingInterestToDate - paidToDate
    }
    private var revolvingEndText: String {
        guard let revolvingResult else { return "—" }
        if revolvingResult.neverEnds { return "No liquida con este pago" }
        guard let lastRow = revolvingResult.rows.last else { return "—" }
        return lastRow.date.date(calendar: .current).formatted(.dateTime.month(.abbreviated).year())
    }

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
                if isRevolving {
                    revolvingHeader
                    revolvingTable
                } else {
                    header
                    amortizationTable
                }
            }
            .padding(16)
        }
        .navigationTitle(loan.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { isPresentingEdit = true }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            LoanEditSheet(loan: loan)
        }
    }

    // MARK: - Revolving header/table

    private var revolvingHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SALDO ACTUAL")
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(revolvingBalance.currencyString(currency: loan.currency))
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tintColor)

            Divider().padding(.vertical, 4)

            detailRow("Interés acumulado a la fecha", revolvingInterestToDate.currencyString(currency: loan.currency))
            detailRow("Fecha del último pago", lastPaymentDateText)
            if let revolvingNext {
                detailRow("Próximo pago esperado", "\(revolvingNext.payment.currencyString(currency: loan.currency)) · \(revolvingNext.date.date(calendar: .current).formatted(.dateTime.day().month(.abbreviated)))")
            }
            detailRow("Fin estimado", revolvingEndText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saldo actual \(revolvingBalance.currencyString(currency: loan.currency)), \(revolvingEndText)")
    }

    @ViewBuilder
    private var revolvingTable: some View {
        let rows = revolvingResult?.rows ?? []
        #if os(macOS)
        Table(rows) {
            TableColumn("Fecha") { row in
                Text(row.date.date(calendar: .current).formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(row.date <= today ? Color.secondary : .primary)
            }
            TableColumn("Pago") { row in
                HStack(spacing: 4) {
                    Text(row.payment.currencyString(currency: loan.currency)).monospacedDigit()
                    if row.isProjected { Text("Proyectado").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            TableColumn("Interés") { row in Text(row.interest.currencyString(currency: loan.currency)).monospacedDigit() }
            TableColumn("Saldo") { row in Text(row.remainingBalance.currencyString(currency: loan.currency)).monospacedDigit() }
        }
        .frame(minHeight: 320)
        #else
        LazyVStack(spacing: 0) {
            ForEach(rows, id: \.index) { row in
                revolvingRow(row)
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

    private func revolvingRow(_ row: LoanEngine.RevolvingRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(row.date.date(calendar: .current).formatted(date: .abbreviated, time: .omitted))
                if row.isProjected {
                    Text("Proyectado")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(row.payment.currencyString(currency: loan.currency)).monospacedDigit()
            }
            .font(.body)
            HStack {
                Text("Interés \(row.interest.currencyString(currency: loan.currency))")
                Spacer()
                Text("Saldo \(row.remainingBalance.currencyString(currency: loan.currency))")
            }
            .font(.caption)
            .monospacedDigit()
        }
        .foregroundStyle(row.date <= today ? Color.secondary : .primary)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.date.date(calendar: .current).formatted(date: .abbreviated, time: .omitted)), pago \(row.payment.currencyString(currency: loan.currency))\(row.isProjected ? ", proyectado" : "")")
    }

    // MARK: - Fixed-term header/table (unchanged)

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
            detailRow("Fecha del último pago", lastPaymentDateText)
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
