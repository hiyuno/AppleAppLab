import Testing
import Foundation
@testable import Fintrol

@Suite("CarryOverEngine")
struct CarryOverEngineTests {
    @Test("Sobrante is INCOME minus EXPENSES regardless of isPaid (there's no isPaid on the snapshot — it never enters the calc)")
    func sobranteIgnoresNothingButKind() {
        let lines: [LineSnapshot] = [
            LineSnapshot(kind: .income, amount: 1000, currency: .usd, origin: .manual),
            LineSnapshot(kind: .expense, amount: 400, currency: .usd, origin: .manual),
        ]
        #expect(CarryOverEngine.sobrante(for: lines, exchangeRate: 18) == 600)
    }

    @Test("Sobrante threshold colors: green >= 100, yellow 0..<100, red < 0")
    func sobranteThresholds() {
        #expect(SobranteStatus(sobrante: 100) == .positive)
        #expect(SobranteStatus(sobrante: 99.99) == .adjusted)
        #expect(SobranteStatus(sobrante: 0) == .adjusted)
        #expect(SobranteStatus(sobrante: -0.01) == .negative)
    }

    @Test("Mandar sums only MXN expenses and divides by the exchange rate")
    func mandarCalculation() {
        let rate = Decimal(string: "18.00")!
        let lines: [LineSnapshot] = [
            LineSnapshot(kind: .expense, amount: 900, currency: .mxn, origin: .manual),
            LineSnapshot(kind: .expense, amount: 100, currency: .usd, origin: .manual),
            LineSnapshot(kind: .income, amount: 1000, currency: .mxn, origin: .manual),
        ]
        #expect(CarryOverEngine.mandar(for: lines, exchangeRate: rate) == 900 / rate)
    }

    // MARK: - Incremental forward propagation with fixed point

    @Test("An edit propagates forward through materialized periods until sobrante stops changing")
    func propagatesUntilFixedPoint() {
        let coordinateN1 = PeriodCoordinate(year: 2026, month: 6, half: .second)
        let coordinateN2 = PeriodCoordinate(year: 2026, month: 7, half: .first)
        let coordinateN3 = PeriodCoordinate(year: 2026, month: 7, half: .second)

        // N+1 previously received a carry-over of 500; after the edit to N, the new sobrante is 800.
        // N+1's own other lines are +200 income / -100 expense, so its new sobrante is 800+200-100=900,
        // which differs from what N+2 previously received (500) -> propagate again.
        let chain: [CarryOverEngine.ChainEntry] = [
            CarryOverEngine.ChainEntry(
                coordinate: coordinateN1,
                nonCarryOverLines: [
                    LineSnapshot(kind: .income, amount: 200, currency: .usd, origin: .manual),
                    LineSnapshot(kind: .expense, amount: 100, currency: .usd, origin: .manual),
                ],
                previousCarryOverReceived: 500
            ),
            CarryOverEngine.ChainEntry(
                coordinate: coordinateN2,
                nonCarryOverLines: [
                    LineSnapshot(kind: .income, amount: 0, currency: .usd, origin: .manual),
                    LineSnapshot(kind: .expense, amount: 0, currency: .usd, origin: .manual),
                ],
                previousCarryOverReceived: 900 // already matches what N+1 will produce -> should stop here
            ),
            CarryOverEngine.ChainEntry(
                coordinate: coordinateN3,
                nonCarryOverLines: [],
                previousCarryOverReceived: 12345 // must never be touched: propagation stops before this
            ),
        ]

        let updates = CarryOverEngine.recomputeForward(materializedChain: chain, startingSobrante: 800, exchangeRate: 18)

        #expect(updates[coordinateN1] == 800)
        #expect(updates[coordinateN2] == nil, "fixed point reached at N+2: its carry-over didn't actually change")
        #expect(updates[coordinateN3] == nil, "propagation must stop and never touch periods after the fixed point")
    }

    @Test("No materialized periods after the edited one means nothing to update")
    func emptyChainProducesNoUpdates() {
        let updates = CarryOverEngine.recomputeForward(materializedChain: [], startingSobrante: 500, exchangeRate: 18)
        #expect(updates.isEmpty)
    }

    // MARK: - Next Month (unified formula)

    @Test("previewNextMonth is exactly the sobrante formula applied to the supplied lines")
    func previewNextMonthMatchesSobrante() {
        let lines: [LineSnapshot] = [
            LineSnapshot(kind: .income, amount: 3000, currency: .usd, origin: .carryOver),
            LineSnapshot(kind: .income, amount: 2750, currency: .usd, origin: .recurring),
            LineSnapshot(kind: .expense, amount: 1900, currency: .usd, origin: .recurring),
        ]
        #expect(CarryOverEngine.previewNextMonth(lines: lines, exchangeRate: 18) == CarryOverEngine.sobrante(for: lines, exchangeRate: 18))
        #expect(CarryOverEngine.previewNextMonth(lines: lines, exchangeRate: 18) == 3850)
    }
}
