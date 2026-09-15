import Testing
import Foundation
import SwiftData
@testable import Fintrol

/// Bertrand — edge cases del PRD/TRD no cubiertos por las suites existentes:
/// cruce de año, mes bisiesto combinado con recurrentes, recurrente mensual día 31 en
/// meses cortos, fecha fin a mitad de quincena, sobrante negativo encadenado,
/// "Next Month" real vs. proyectado, y el límite histórico (incluye un caso documentado
/// como bug conocido — ver FIN-2026-xxx pendiente para Woz).
@MainActor
@Suite("Edge cases — cobertura adicional de Bertrand")
struct EdgeCaseEngineTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> CivilDate {
        CivilDate(year: year, month: month, day: day)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    // MARK: - 31 dic -> 15 ene (cruce de año)

    @Test("El rango de la segunda quincena de diciembre termina el 31 y la primera de enero empieza el 1, sin hueco ni traslape")
    func decemberToJanuaryDateRangesAreContiguous() {
        let december = PeriodDateEngine.dateRange(for: PeriodCoordinate(year: 2026, month: 12, half: .second))
        let january = PeriodDateEngine.dateRange(for: PeriodCoordinate(year: 2027, month: 1, half: .first))

        #expect(december.end == CivilDate(year: 2026, month: 12, day: 31))
        #expect(january.start == CivilDate(year: 2027, month: 1, day: 1))
        #expect(december.end.addingDays(1) == january.start)
    }

    @Test("Un recurrente biweekly vigente sin fecha fin sigue generando línea al cruzar de diciembre 2026 a enero 2027")
    func recurringCrossesYearBoundary() {
        let item = RecurringItemSnapshot(
            id: UUID(), kind: .income, title: "WALO", amount: 2750, currency: .usd,
            frequency: .biweekly, startDate: date(2020, 1, 1), endDate: nil, isActive: true
        )
        let decemberSecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 12, half: .second), recurringItems: [item])
        let januaryFirst = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2027, month: 1, half: .first), recurringItems: [item])
        #expect(decemberSecond.count == 1)
        #expect(januaryFirst.count == 1)
    }

    // MARK: - Recurrente mensual día 31 en meses cortos

    @Test("monthlyOnDay(31) se clampea al último día en abril (30 días) y sigue cayendo en la segunda quincena")
    func monthlyOnDay31ClampsInShortMonth() {
        let item = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Renta fin de mes", amount: 1900, currency: .usd,
            frequency: .monthlyOnDay(31), startDate: date(2026, 1, 1), endDate: nil, isActive: true
        )
        let aprilSecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 4, half: .second), recurringItems: [item])
        let aprilFirst = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 4, half: .first), recurringItems: [item])
        #expect(aprilSecond.count == 1, "día 31 clampeado a 30 en abril sigue en la segunda quincena (16-30)")
        #expect(aprilFirst.isEmpty)
    }

    @Test("monthlyOnDay(31) también clampea correctamente en febrero no bisiesto (día 28) y bisiesto (día 29)")
    func monthlyOnDay31ClampsInFebruary() {
        let item = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Suscripción anual prorrateada", amount: 10, currency: .usd,
            frequency: .monthlyOnDay(31), startDate: date(2020, 1, 1), endDate: nil, isActive: true
        )
        let nonLeapFeb = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 2, half: .second), recurringItems: [item])
        let leapFeb = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2028, month: 2, half: .second), recurringItems: [item])
        #expect(nonLeapFeb.count == 1)
        #expect(leapFeb.count == 1)
    }

    // MARK: - Recurrente con fecha fin a mitad de quincena

    @Test("Un recurrente monthlyOnDay cuya fecha fin cae ANTES de la ocurrencia del mes deja de generar esa quincena")
    func monthlyOnDayEndDateMidPeriodExcludesOccurrence() {
        // Ocurrencia real: día 20. Fecha fin: día 10 del mismo mes (a mitad de la misma quincena,
        // antes de que el recurrente realmente "ocurra" ese mes).
        let loan = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Upstart", amount: 629, currency: .usd,
            frequency: .monthlyOnDay(20), startDate: date(2026, 1, 1), endDate: date(2026, 6, 10), isActive: true
        )
        let juneSecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 6, half: .second), recurringItems: [loan])
        #expect(juneSecond.isEmpty, "la fecha fin (día 10) es anterior a la ocurrencia real (día 20) de esa misma quincena, no debe generar línea")
    }

    @Test("Un recurrente monthlyOnDay cuya fecha fin cae justo DESPUÉS de la ocurrencia del mes sigue generando esa quincena")
    func monthlyOnDayEndDateAfterOccurrenceIncludesIt() {
        let loan = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Upstart", amount: 629, currency: .usd,
            frequency: .monthlyOnDay(20), startDate: date(2026, 1, 1), endDate: date(2026, 6, 21), isActive: true
        )
        let juneSecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 6, half: .second), recurringItems: [loan])
        #expect(juneSecond.count == 1, "la fecha fin (día 21) es posterior a la ocurrencia (día 20) de esa misma quincena, debe generar línea")
    }

    @Test("Un recurrente biweekly con fecha fin a mitad de la quincena (dentro del rango) sigue vigente ese corte")
    func biweeklyEndDateMidRangeStillVigente() {
        // startDate/endDate no coinciden con los bordes de la quincena (1-15 de julio); endDate cae el 8.
        let item = RecurringItemSnapshot(
            id: UUID(), kind: .income, title: "Ada", amount: 300, currency: .usd,
            frequency: .biweekly, startDate: date(2026, 1, 1), endDate: date(2026, 7, 8), isActive: true
        )
        let julyFirst = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 7, half: .first), recurringItems: [item])
        let julySecond = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 7, half: .second), recurringItems: [item])
        #expect(julyFirst.count == 1, "endDate cae dentro del rango (1-15 jul), la quincena completa sigue vigente")
        #expect(julySecond.isEmpty, "la quincena siguiente ya no es vigente porque empieza después de endDate")
    }

    // MARK: - Suscripción / recurrente día 15 vs 16 (recurrente, paralelo al caso ya cubierto de Subscription)

    @Test("Recurrente monthlyOnDay(15) cae en la primera quincena, monthlyOnDay(16) en la segunda")
    func recurringMonthlyOnDay15Vs16Boundary() {
        let payday15 = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Pago día 15", amount: 50, currency: .usd,
            frequency: .monthlyOnDay(15), startDate: date(2026, 1, 1), endDate: nil, isActive: true
        )
        let payday16 = RecurringItemSnapshot(
            id: UUID(), kind: .expense, title: "Pago día 16", amount: 50, currency: .usd,
            frequency: .monthlyOnDay(16), startDate: date(2026, 1, 1), endDate: nil, isActive: true
        )
        let first = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 6, half: .first), recurringItems: [payday15, payday16])
        let second = ProjectionEngine.generateRecurringLines(for: PeriodCoordinate(year: 2026, month: 6, half: .second), recurringItems: [payday15, payday16])
        #expect(first.map(\.title) == ["Pago día 15"])
        #expect(second.map(\.title) == ["Pago día 16"])
    }

    // MARK: - Encadenado con sobrante negativo

    @Test("Un sobrante negativo se encadena igual que uno positivo como línea de INCOME negativa")
    func negativeCarryOverChainsAsNegativeIncomeLine() throws {
        let context = try makeContext()
        let coordinateN = PeriodCoordinate(year: 2026, month: 8, half: .first)

        let periodN = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        let expense = LineItem(kind: .expense, title: "Gasto grande", amount: 5000, currency: .usd, sortOrder: 0, origin: .manual, period: periodN)
        context.insert(expense)
        periodN.lineItems?.append(expense)
        try context.save()

        #expect(CarryOverEngine.sobrante(for: PeriodCoordinator.snapshots(of: periodN), exchangeRate: 18) == -5000)

        let periodN1 = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN.next, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        let carryLine = (periodN1.lineItems ?? []).first { $0.origin == .carryOver }

        #expect(carryLine?.kind == .income, "el sobrante negativo sigue siendo origin .carryOver / kind .income — el signo vive en el monto, no en el tipo de línea")
        #expect(carryLine?.amount == -5000)

        // Y colorea rojo (< $0) según el criterio del PRD.
        #expect(SobranteStatus(sobrante: carryLine!.amount) == .negative)
    }

    @Test("recomputeForward propaga correctamente cuando el sobrante recalculado es negativo")
    func recomputeForwardPropagatesNegativeSobrante() {
        let coordinateN1 = PeriodCoordinate(year: 2026, month: 9, half: .first)
        let chain: [CarryOverEngine.ChainEntry] = [
            CarryOverEngine.ChainEntry(
                coordinate: coordinateN1,
                nonCarryOverLines: [
                    LineSnapshot(kind: .expense, amount: 100, currency: .usd, origin: .manual),
                ],
                previousCarryOverReceived: 1000
            ),
        ]
        // Sobrante recalculado de la quincena editada ahora es -200 (antes era positivo).
        let updates = CarryOverEngine.recomputeForward(materializedChain: chain, startingSobrante: -200, exchangeRate: 18)
        #expect(updates[coordinateN1] == -200)
    }

    // MARK: - "Next Month" real (materializada) vs. proyectado (no materializada)

    @Test("previewNextMonth devuelve el valor REAL de la quincena N+1 cuando ya está materializada y editada a mano, no el valor teórico")
    func previewNextMonthReturnsRealValueWhenMaterialized() throws {
        let context = try makeContext()
        let coordinateN = PeriodCoordinate(year: 2026, month: 10, half: .first)
        let recurring = RecurringItemSnapshot(
            id: UUID(), kind: .income, title: "WALO", amount: 2750, currency: .usd,
            frequency: .biweekly, startDate: date(2020, 1, 1), endDate: nil, isActive: true
        )

        let periodN = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN, context: context, recurringItems: [recurring], subscriptions: [], exchangeRate: 18)
        // Materializa N+1 también (con el recurrente proyectado normalmente).
        let periodN1 = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN.next, context: context, recurringItems: [recurring], subscriptions: [], exchangeRate: 18)

        // El usuario edita a mano una línea de N+1 después de materializarla, divergiendo del valor teórico.
        let editedLine = LineItem(kind: .income, title: "Bono inesperado", amount: 999, currency: .usd, sortOrder: 99, origin: .manual, period: periodN1)
        context.insert(editedLine)
        periodN1.lineItems?.append(editedLine)
        try context.save()

        let real = PeriodCoordinator.previewNextMonth(after: periodN, context: context, recurringItems: [recurring], subscriptions: [], exchangeRate: 18)
        let expectedReal = CarryOverEngine.sobrante(for: PeriodCoordinator.snapshots(of: periodN1), exchangeRate: 18)

        #expect(real == expectedReal, "debe leer las líneas reales persistidas de N+1 (incluyendo el bono editado a mano), no recalcular en memoria")
    }

    @Test("previewNextMonth proyecta en memoria (sin persistir) cuando N+1 NO está materializada todavía")
    func previewNextMonthProjectsInMemoryWhenNotMaterialized() throws {
        let context = try makeContext()
        let coordinateN = PeriodCoordinate(year: 2026, month: 11, half: .first)
        let recurring = RecurringItemSnapshot(
            id: UUID(), kind: .income, title: "WALO", amount: 2750, currency: .usd,
            frequency: .biweekly, startDate: date(2020, 1, 1), endDate: nil, isActive: true
        )

        let periodN = PeriodCoordinator.materializeIfNeeded(coordinate: coordinateN, context: context, recurringItems: [recurring], subscriptions: [], exchangeRate: 18)
        // N+1 nunca se materializa explícitamente.

        let preview = PeriodCoordinator.previewNextMonth(after: periodN, context: context, recurringItems: [recurring], subscriptions: [], exchangeRate: 18)
        let expected = CarryOverEngine.sobrante(for: PeriodCoordinator.snapshots(of: periodN), exchangeRate: 18) + 2750

        #expect(preview == expected, "sin materializar, previewNextMonth debe ser sobrante(N) + recurrente proyectado de N+1")
        #expect(PeriodCoordinator.fetchPeriod(coordinate: coordinateN.next, context: context) == nil, "previewNextMonth NUNCA debe materializar N+1 como side effect (TRD)")
    }

    // MARK: - Límite histórico

    @Test("earliestMaterializedCoordinate devuelve la quincena más antigua realmente materializada, no una fecha fija")
    func earliestMaterializedCoordinateTracksActualAnchor() throws {
        let context = try makeContext()
        #expect(PeriodCoordinator.earliestMaterializedCoordinate(context: context) == nil, "un store vacío no tiene límite histórico todavía")

        let anchor = PeriodCoordinate(year: 2026, month: 6, half: .first)
        _ = PeriodCoordinator.materializeIfNeeded(coordinate: anchor, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)
        _ = PeriodCoordinator.materializeIfNeeded(coordinate: PeriodCoordinate(year: 2027, month: 1, half: .first), context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        #expect(PeriodCoordinator.earliestMaterializedCoordinate(context: context) == anchor)
    }

    /// FIN-2026-BERTRAND-01 — FIXED (see PROJECT_LEARNINGS.md): `materializeIfNeeded` now
    /// clamps to the existing anchor instead of materializing a coordinate before it, so the
    /// TRD's "no existen quincenas anteriores a la primera materializada" holds at the engine
    /// level, not just via the disabled "anterior" chevron in `PeriodView`.
    @Test("materializeIfNeeded clamps to the anchor instead of materializing before it")
    func materializeIfNeededEnforcesHistoricalLimit() throws {
        let context = try makeContext()
        let anchor = PeriodCoordinate(year: 2026, month: 6, half: .first)
        _ = PeriodCoordinator.materializeIfNeeded(coordinate: anchor, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        let beforeAnchor = PeriodCoordinate(year: 2026, month: 1, half: .first)
        let result = PeriodCoordinator.materializeIfNeeded(coordinate: beforeAnchor, context: context, recurringItems: [], subscriptions: [], exchangeRate: 18)

        #expect(PeriodCoordinator.fetchPeriod(coordinate: beforeAnchor, context: context) == nil)
        #expect(PeriodCoordinator.earliestMaterializedCoordinate(context: context) == anchor)
        #expect(result.coordinate == anchor, "clamped call should return the anchor's own period")
    }
}
