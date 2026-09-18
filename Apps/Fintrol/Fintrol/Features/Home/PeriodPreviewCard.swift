import SwiftUI

/// Read-only preview of the current quincena, embedded in `HomeView` (DESIGN_LIQUID.md §
/// "Card de Quincena embebida"). Not the full `PeriodView` and not a text link — reuses
/// `SobranteBadge` and `NextMonthCard` (extracted from `SummaryPanel`) verbatim; "Mandar"/"To
/// Send" is deliberately excluded, it's an operational action, not a summary datum.
///
/// Purely presentational/"dumb" — it renders its own content and reports taps via `onTap`.
/// It has no dependency on `HomeView`'s drag gesture at all; the drag lives entirely in
/// `HomeView` and this card stays visually static regardless of it.
struct PeriodPreviewCard: View {
    let coordinate: PeriodCoordinate
    let isTodayCoordinate: Bool
    let income: Decimal
    let expense: Decimal
    let sobrante: Decimal
    let nextMonth: Decimal
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                header
                totalsBlock
                SobranteBadge(sobrante: sobrante)
                NextMonthCard(nextMonth: nextMonth)
                // Pushes the fixed-size content to the top and lets the `VStack` itself claim
                // any extra height `HomeView` hands this card (edge-to-edge, down to the tab
                // bar) — without it, `maxHeight: .infinity` below would just center an
                // unchanged-size card inside a taller transparent frame instead of actually
                // stretching the visible background.
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color("AppBackgroundSecondary"))
            // Top corners only, 55pt (matches the iPhone 17 Pro's screen curve, confirmed with
            // the user) — bottom corners stay square since the card runs edge-to-edge to the
            // screen's physical bottom (`HomeView`'s `.ignoresSafeArea(edges: .bottom)`).
            // `HomeView` re-applies its own (drag-animated) version of this same shape from the
            // outside, so this static clip is what the card looks like at rest/in isolation.
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 55,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 55,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "home_preview_card_a11y",
            defaultValue: "Current period, \(coordinate.accessibleTitle), surplus \(sobrante.currencyString()), tap to see detail"
        ))
    }

    // Same visual pattern as `PeriodView`'s own header (title + range pill) minus the
    // chevrons/jump-sheet trigger — the whole card is one tap target, no sub-interactions.
    // Figma mockup (2026-09-18): both centered horizontally, matching `PeriodView`'s own
    // `VStack(spacing: 2)` header block — not left-aligned like the rest of the card's content.
    private var header: some View {
        VStack(spacing: 6) {
            // Figma header redesign (2026-09-18, node 128:66): year sits above the month,
            // same treatment as `PeriodView`'s header. Coordinator (2026-09-18): pill
            // container removed per user request — plain text, same size/weight/color.
            Text(coordinate.yearTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            Text(coordinate.monthTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            // Coordinator (2026-09-18, user request): same treatment as `PeriodView`'s header —
            // no solid `.fill` behind the range pill, just the `Capsule` stroke; text goes
            // green instead of white when it's today's period.
            Text(coordinate.dayRangeTitle)
                .font(.subheadline.weight(isTodayCoordinate ? .bold : .regular))
                .foregroundStyle(isTodayCoordinate ? Color.green : .secondary)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .overlay(Capsule().strokeBorder(isTodayCoordinate ? Color.green.opacity(0.5) : Color.secondary.opacity(0.3)))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 38)
        .padding(.bottom, 16)
    }

    // Figma mockup (2026-09-18): INCOME/EXPENSES are two side-by-side "boxes", not a text row —
    // label above, amount inside a nested card below. Same `.ultraThinMaterial.opacity(0.5)`
    // nested-card fill used by `LoanDetailView`/`InvestmentsView` for their internal stat cards,
    // reused here instead of inventing a new box style.
    private var totalsBlock: some View {
        HStack(spacing: 12) {
            totalColumn(title: String(localized: "period_income_header", defaultValue: "INCOME"), amount: income)
            totalColumn(title: String(localized: "period_expenses_header", defaultValue: "EXPENSES"), amount: expense)
        }
    }

    private func totalColumn(title: String, amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(amount.currencyString())
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Matches `NextMonthCard`'s internal padding, not `SobranteBadge`'s — the goal
                // is equal box HEIGHT, not just an equal padding number. `SobranteBadge`'s
                // amount is `.largeTitle` (much taller line height), while `NextMonthCard`'s
                // amount is `.body.weight(.semibold)` — same font/line-height as this box's
                // amount text — so matching `NextMonthCard`'s `.padding(16)` is what actually
                // produces a visually equal row height. `SobranteBadge` stays taller by design
                // (it's the hero number); it was never a realistic height target.
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.5))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PeriodPreviewCard(
        coordinate: PeriodDateEngine.coordinate(containing: CivilDate.today()),
        isTodayCoordinate: true,
        income: 5200,
        expense: 3100,
        sobrante: 2100,
        nextMonth: 1800,
        onTap: {}
    )
    .padding()
}
