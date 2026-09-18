import SwiftUI

/// Centralized fix (coordinator, 2026-09-17): every numeric field bound directly to a
/// `Decimal` (`TextField(_, value: $decimal, format:)`) showed "0"/"0.00" as real, selectable
/// text — not a placeholder — forcing the user to manually delete it before typing a real
/// value. This binds to an internal `String` instead; when the underlying value is exactly 0
/// (the "never entered anything" case — a brand-new form field), the displayed text starts
/// empty and `placeholder` shows through normally, so the user can just start typing.
///
/// Scope note: this only clears the STARTING zero, not "select all on focus" for a field
/// that's being edited with a real existing value (e.g. editing a loan's principal) — that
/// would need a `UIViewRepresentable`/`NSViewRepresentable` per platform to select-all
/// reliably, out of scope for this pass; the reported bug was specifically about the default-
/// zero placeholder trap.
///
/// Coordinator (2026-09-17, same pass): `isCurrency` (default `true`) adds thousands grouping
/// while typing for money fields ("2000" → "2,000", "2000.5" → "2,000.5") — NOT for
/// percentage fields like APR, which pass `isCurrency: false`. Grouping is applied by
/// reformatting the digits-only content on every keystroke; this resets the cursor to the end
/// on each reformat (a known limitation of a pure `@State` `String` binding without a
/// `UIViewRepresentable`/`NSViewRepresentable` — acceptable for a trailing-edit-only field
/// like these, out of scope to fix cursor-in-the-middle editing here). No "$" prefix — every
/// call site already shows the currency code ("USD") as a separate trailing label, so adding
/// "$" here would duplicate that.
struct LabDecimalField: View {
    let placeholder: String
    @Binding var value: Decimal
    var isCurrency: Bool = true

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private static let locale = Locale(identifier: "en_US_POSIX")

    var body: some View {
        TextField(placeholder, text: $text)
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .focused($isFocused)
            .onAppear {
                syncFromValue()
            }
            .onChange(of: text) { _, newText in
                let digitsOnly = newText.filter { $0.isNumber || $0 == "." }
                value = Decimal(string: digitsOnly, locale: Self.locale) ?? 0
                if isCurrency {
                    let grouped = Self.groupedText(forDigitsOnly: digitsOnly)
                    if grouped != newText { text = grouped }
                }
            }
            .onChange(of: value) { _, newValue in
                // Keep in sync if the binding changes from outside (e.g. switching the item
                // being edited) without fighting the user's own typing.
                guard !isFocused else { return }
                syncFromValue(newValue)
            }
    }

    private func syncFromValue(_ newValue: Decimal? = nil) {
        let resolved = newValue ?? value
        guard resolved != 0 else { text = ""; return }
        text = isCurrency ? Self.groupedText(forDigitsOnly: "\(resolved)") : "\(resolved)"
    }

    /// Groups the integer part of `digitsOnly` (which may already contain a "." fraction and
    /// no commas — the raw parsed content) with thousands commas, leaving the fraction as
    /// typed so far untouched. Not `private` — `LineCaptureSheet`'s "Monto" field (a String-
    /// bound field already, not a `LabDecimalField`) reuses this exact grouping logic instead
    /// of a second implementation.
    static func groupedText(forDigitsOnly digitsOnly: String) -> String {
        guard !digitsOnly.isEmpty else { return "" }
        let hasTrailingDot = digitsOnly.hasSuffix(".")
        let parts = digitsOnly.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let integerPart = String(parts.first ?? "")
        let fractionPart = parts.count > 1 ? String(parts[1]) : ""
        let groupedInteger = groupThousands(integerPart)
        if hasTrailingDot { return groupedInteger + "." }
        if parts.count > 1 { return groupedInteger + "." + fractionPart }
        return groupedInteger
    }

    private static func groupThousands(_ digits: String) -> String {
        guard !digits.isEmpty else { return digits }
        let reversed = Array(digits.reversed())
        var grouped: [Character] = []
        for (index, character) in reversed.enumerated() {
            if index > 0, index % 3 == 0 { grouped.append(",") }
            grouped.append(character)
        }
        return String(grouped.reversed())
    }
}
