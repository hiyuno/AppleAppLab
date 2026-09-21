import SwiftUI

/// Shared title content (year + month + day-range pill) rendered by `PeriodView.titleBlock` —
/// the only remaining call site since the `revealProgress` unification (2026-09-20) removed the
/// old separately-tracked `PeriodPreviewCard`/floating-title-overlay copies entirely. Kept as its
/// own small view (rather than inlined back into `titleBlock`) since it's still a clean,
/// self-contained unit and a natural extension point if another call site ever needs the same
/// content again.
struct PeriodTitleBlock: View {
    let coordinate: PeriodCoordinate
    let isTodayCoordinate: Bool

    private static let successGreenLight = Color(red: 0x01 / 255.0, green: 0xF9 / 255.0, blue: 0x8E / 255.0) // #01F98E

    var body: some View {
        VStack(spacing: 6) {
            Text(coordinate.yearTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            Text(coordinate.monthTitle)
                // Coordinator (2026-09-21, /update-ui): Figma is Bold, not Semibold.
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text(coordinate.dayRangeTitle)
                // Coordinator (2026-09-21, /update-ui): Figma's pill is 12px Semibold (was
                // `.subheadline`, 15pt) with 12/4pt padding (was 10/3), and the "today" color is
                // the tokens update's `Semantic/Success Green-Light` (#01F98E), not system
                // `.green`.
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isTodayCoordinate ? Self.successGreenLight : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .overlay(
                    Capsule().strokeBorder(isTodayCoordinate ? Self.successGreenLight : Color.secondary.opacity(0.3))
                )
        }
    }
}
