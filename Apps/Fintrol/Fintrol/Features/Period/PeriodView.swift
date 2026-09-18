import SwiftUI
import SwiftData
import AppleAppLabUI

struct PeriodView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore

    @Query(sort: \RecurringItem.title) private var recurringItems: [RecurringItem]
    @Query(sort: \Subscription.name) private var subscriptions: [Subscription]
    @Query(sort: \Loan.name) private var loans: [Loan]

    @State private var coordinate = PeriodDateEngine.coordinate(containing: CivilDate.today())
    @State private var period: Period?
    /// Coordinator (2026-09-15, DESIGN_LIQUID.md § "Sheet de captura/edición de línea"):
    /// replaces `editingLineID`/`draftLineID` + the inline-editing row entirely. `nil` while
    /// closed; a non-nil `line` means editing that existing `LineItem`; a nil `line` with a
    /// `kind` means creating a new one (no draft `LineItem` exists until "Listo" is tapped —
    /// this removes the old ghost-row problem at the source instead of working around it).
    @State private var captureTarget: CaptureTarget?
    private struct CaptureTarget: Identifiable {
        let id = UUID()
        let line: LineItem?
        let kind: LineKind
    }
    @State private var showJumpSheet = false
    @State private var isPresentingCreditCardSheet = false
    @State private var isPresentingInvestmentSheet = false
    @State private var isLoading = true

    // HIG_REVIEW #5 (Larry): the leading/trailing swipe gestures on a line have no visual
    // hint before the first drag — shown exactly once, ever, then persisted dismissed so it
    // never nags a returning user.
    @AppStorage("fintrol.hasSeenSwipeHint") private var hasSeenSwipeHint = false

    // TRD "Límite de navegación hacia atrás" (2026-09-16): Ajustes → Preferencias → "Historial
    // visible" — the `@AppStorage` read stays here (Core/ never touches it directly, only
    // receives the resolved `Int` as a parameter, same separation as every other
    // preference-driven Core call).
    @AppStorage("fintrol.historyMonthsBack") private var historyMonthsBack = 1

    // A11Y #11: at accessibility Dynamic Type sizes, the badge/panel need to stack instead
    // of sitting side by side (macOS) so nothing gets clipped or squeezed unreadably.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var isLargeAccessibilitySize: Bool { dynamicTypeSize >= .accessibility1 }

    private var todayCoordinate: PeriodCoordinate { PeriodDateEngine.coordinate(containing: CivilDate.today()) }
    private var isTodayCoordinate: Bool { coordinate == todayCoordinate }

    private var effectiveRate: Decimal {
        period?.manualExchangeRateOverride ?? rateStore.currentRate ?? 0
    }

    private var earliestCoordinate: PeriodCoordinate {
        PeriodCoordinator.navigableLowerBound(context: context, monthsBack: historyMonthsBack)
    }

    private var recurringSnapshots: [RecurringItemSnapshot] {
        recurringItems.map {
            RecurringItemSnapshot(id: $0.id, kind: $0.kind, title: $0.title, amount: $0.amount, currency: $0.currency, frequency: $0.frequency, startDate: $0.civilStartDate, endDate: $0.civilEndDate, isActive: $0.isActive, category: $0.category)
        }
    }

    private var subscriptionSnapshots: [SubscriptionSnapshot] {
        subscriptions.map {
            SubscriptionSnapshot(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency, paymentDay: $0.paymentDay, startDate: $0.civilStartDate, endDate: $0.civilEndDate, kind: $0.kind, isActive: $0.isActive)
        }
    }

    private var loanSnapshots: [LoanSnapshot] {
        loans.map {
            LoanSnapshot(id: $0.id, name: $0.name, direction: $0.direction, principal: $0.principal, currency: $0.currency, apr: $0.apr, startDate: $0.civilStartDate, termMonths: $0.termMonths, frequency: $0.frequency, paymentOverride: $0.paymentOverride, isActive: $0.isActive)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                loadingSkeleton
            } else {
                content
            }
        }
        // Coordinator (2026-09-18): applied once here, at the root of `body`, instead of inside
        // `loadingSkeleton`/`content` separately — covers BOTH branches from the very first
        // frame (`isLoading = true`'s default), so there is never a gap where this screen
        // renders with SwiftUI's default white background. Fixes the white-flash "reload
        // glitch" reported when a Home→Quincena drag commits: `selectedTab = .period` mounts a
        // brand-new `PeriodView()` instance in `iOSRootView` (distinct from the drag's
        // `staticPeriodLayer`), which starts `isLoading = true` again and, without this, showed
        // `loadingSkeleton` with no background of its own for that one frame.
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("")
        #if os(iOS)
        // Coordinator (2026-09-17, round 2): the system nav bar (empty title, `.inline` mode)
        // was still reserving its own fixed height above the custom fixed header — a visibly
        // gray strip (system bar material) with too much empty air before "September 2026".
        // `toolbarContent` only ever held an `EmptyView`, so the nav bar itself was pure
        // overhead once the screen grew its own header — hiding it removes both the gray
        // mismatch AND the extra vertical space in one fix. `.safeAreaInset(edge: .top)` still
        // respects the status bar/notch/Dynamic Island on its own, independent of the nav bar,
        // so nothing needs to change there to keep clear of it.
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task {
            await rateStore.refresh(context: context)
            loadPeriod()
            isLoading = false
        }
        .onAppear {
            // Bug (Avie): `period` is a one-shot `@State` snapshot loaded only from `.task`
            // (which runs once per view identity) — editing a RecurringItem/Subscription/Loan
            // from another tab calls `reproject…`, which *does* persist the new lines, but
            // this view never re-fetched them until the app relaunched. `.task` doesn't refire
            // on tab reselection, so `.onAppear` (which does) refetches every time the user
            // comes back to Quincena. Cheap and idempotent — `loadPeriod()` just re-reads the
            // already-materialized `Period` when nothing changed.
            guard !isLoading else { return }
            loadPeriod()
        }
        .sheet(isPresented: $showJumpSheet) {
            JumpSheet(current: coordinate, earliest: earliestCoordinate) { destination in
                coordinate = destination
                loadPeriod()
                HapticFeedback.lightImpact(reduceMotion: reduceMotion)
            } onToday: {
                coordinate = todayCoordinate
                loadPeriod()
                HapticFeedback.lightImpact(reduceMotion: reduceMotion)
            }
        }
        .sheet(item: $captureTarget) { target in
            LineCaptureSheet(editingLine: target.line, kind: target.kind) { title, amount, currency in
                saveLine(target.line, kind: target.kind, title: title, amount: amount, currency: currency)
            }
        }
        .sheet(isPresented: $isPresentingCreditCardSheet) {
            CreditCardPaymentsSheet(
                lines: (period?.lineItems ?? []).filter { $0.origin == .creditCard }.sorted { $0.sortOrder < $1.sortOrder },
                exchangeRate: effectiveRate,
                onDelete: { deleteLine($0) },
                onQuickCommit: { commitQuickEdit() },
                onToggleActive: { toggleActive($0) },
                onTogglePaid: { togglePaid($0) }
            )
        }
        .sheet(isPresented: $isPresentingInvestmentSheet) {
            InvestmentPaymentsSheet(
                lines: (period?.lineItems ?? []).filter { $0.origin == .investment }.sorted { $0.sortOrder < $1.sortOrder },
                exchangeRate: effectiveRate,
                onDelete: { deleteLine($0) },
                onQuickCommit: { commitQuickEdit() },
                onToggleActive: { toggleActive($0) },
                onTogglePaid: { togglePaid($0) }
            )
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLargeAccessibilitySize {
                    VStack(spacing: 24) {
                        blocks
                        SobranteBadge(sobrante: sobrante)
                        summaryPanel
                    }
                } else {
                    #if os(macOS)
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 24) {
                            blocks
                            SobranteBadge(sobrante: sobrante)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(String(localized: "period_two_column_income_a11y", defaultValue: "Income and expenses column"))

                        summaryPanel
                            .frame(width: 280)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel(String(localized: "period_two_column_summary_a11y", defaultValue: "Summary column"))
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "period_two_column_layout_a11y", defaultValue: "Two-column layout"))
                    #else
                    blocks
                    SobranteBadge(sobrante: sobrante)
                    summaryPanel
                    #endif
                }
            }
            // Coordinator (2026-09-17): horizontal margin explicitly 10pt (was 16pt). Matches
            // `stickyHeader`'s own horizontal padding below so the fixed header stays aligned
            // with the scrolling content under it.
            .padding(.horizontal, 10)
            // Coordinator (2026-09-17, round 4): the gap between the fixed header's pill and
            // "INCOME" was way too large — reduced from 16pt (applied uniformly top+bottom via
            // a single `.padding(.vertical, 16)`) to 12pt on top specifically, matching the
            // 12pt gap already standardized elsewhere on this screen (header-to-first-card,
            // last-card-to-TOTAL). Bottom keeps its original 16pt — only the top gap changed.
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        // Coordinator (2026-09-17): the Quincena header (title/chevrons/range pill) is now
        // fixed above the scroll content instead of scrolling away with it — `.safeAreaInset`
        // both pins it AND automatically reserves exactly its own height as extra top inset
        // for the ScrollView's content, so nothing needs a hand-tuned padding-top to avoid
        // starting hidden underneath it (the manual-overlay/ZStack alternative would need
        // that arithmetic redone by hand any time the header's height changes).
        .safeAreaInset(edge: .top, spacing: 0) {
            stickyHeader
        }
    }

    /// `header` + an opaque background so it fully occludes content scrolling underneath.
    ///
    /// Coordinator (2026-09-17, rounds 1-3): tried a gradient "scrim" tail (`.overlay`, offset
    /// below the header) to fade scrolled content out gradually instead of a hard clip. This
    /// was the wrong technique: the tail is STATIC (part of the fixed `.safeAreaInset` layer,
    /// not tied to scroll position), so any tail tall/opaque enough to hide a rubber-band
    /// overscroll glimpse also permanently paints over the top of the actual scroll content —
    /// which is exactly what was hiding "INCOME" and reading as "too much gray space" (a
    /// static 80pt semi-opaque rectangle sitting on top of it). Reverted to a plain solid
    /// background that exactly matches the header's own bounds, nothing extra bleeding past
    /// it. `.safeAreaInset` already keeps normal scroll content from rendering on top of this
    /// region on its own; the only edge case this doesn't cover is a brief rubber-band
    /// overscroll glimpse, which is a much smaller cosmetic issue than hiding "INCOME".
    ///
    /// Coordinator (2026-09-17, round 5): brought the fade back, this time genuinely contained
    /// — it's a layer INSIDE this same `.background`, which `.background` always sizes to
    /// match `header`'s own frame exactly. The gradient occupies only the bottom 14pt of that
    /// fixed frame; it cannot extend past the header's own bounds into the `ScrollView` because
    /// there's no separate `.overlay`/offset placing it outside that frame this time.
    private var stickyHeader: some View {
        header
            // Coordinator (2026-09-17): matches `content`'s 10pt horizontal margin.
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .background(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    Color("AppBackground")
                    LinearGradient(
                        colors: [Color("AppBackground"), Color("AppBackground").opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 14)
                }
            }
    }

    private var blocks: some View {
        VStack(spacing: 24) {
            if !hasSeenSwipeHint {
                swipeDiscoverabilityHint
            }
            lineBlock(title: String(localized: "period_income_header", defaultValue: "INCOME"), kind: .income)
            lineBlock(title: String(localized: "period_expenses_header", defaultValue: "EXPENSES"), kind: .expense)
        }
    }

    private var swipeDiscoverabilityHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .foregroundStyle(Color.accentColor)
            Text(String(localized: "period_swipe_hint_message", defaultValue: "Swipe a line: right to activate or deactivate, left to mark it as paid (swipe again to delete or edit)."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                hasSeenSwipeHint = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "period_swipe_hint_dismiss_a11y", defaultValue: "Dismiss hint"))
        }
        .padding(12)
        // Larry (2026-09-17): a dismissible inline tip banner (12pt padding), not a card in
        // its own right — the 12pt internal-element token, not the 20pt card radius.
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.1)))
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack {
            Button {
                coordinate = coordinate.previous
                loadPeriod()
                // Coordinator (2026-09-17): light haptic on a real period change — this
                // action only runs when the button isn't `.disabled`, so the historical-limit
                // case (no-op tap) never fires it.
                HapticFeedback.lightImpact(reduceMotion: reduceMotion)
            } label: {
                // Coordinator (2026-09-16): system Liquid Glass paints the button now — plain
                // `chevron.backward` (no `.circle.fill`), no manual tint. `.glass` (not
                // `.glassProminent`): this side has no "active" accent state, and the
                // historical-limit disabled look comes from native `.disabled(true)`, not a
                // hand-picked gray.
                Image(systemName: "chevron.backward")
                    .frame(width: 29, height: 29)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(String(localized: "period_previous_a11y", defaultValue: "Previous period"))
            .disabled(coordinate <= earliestCoordinate)

            Spacer()

            VStack(spacing: 4) {
                Button {
                    showJumpSheet = true
                } label: {
                    VStack(spacing: 6) {
                        // Figma header redesign (2026-09-18, node 128:66): the year sits above
                        // the month row as plain text, no longer appended to the month text.
                        // Coordinator (2026-09-18): pill container removed per user request —
                        // same size/weight/color as before, just no background/Capsule.
                        Text(coordinate.yearTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(coordinate.monthTitle)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                        // Coordinator (2026-09-16, DESIGN_LIQUID.md, Jonny): the separate
                        // "Current"/"Proyección" badge is gone — this day-range pill is now
                        // the ONLY indicator. Today's period → bold green text, no fill.
                        // Anything else (past OR future, no distinction) → `.secondary` text,
                        // no extra label.
                        // Coordinator (2026-09-18, user request): removed the solid green
                        // `.fill` — the pill shape stays (padding + `Capsule` stroke), but it's
                        // transparent now; the green moved from the background to the text.
                        Text(coordinate.dayRangeTitle)
                            .font(.subheadline.weight(isTodayCoordinate ? .bold : .regular))
                            .foregroundStyle(isTodayCoordinate ? Color.green : .secondary)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .overlay(
                                Capsule().strokeBorder(isTodayCoordinate ? Color.green.opacity(0.5) : Color.secondary.opacity(0.3))
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fecha: \(coordinate.accessibleTitle)\(isTodayCoordinate ? String(localized: "period_date_a11y_current_suffix", defaultValue: ", current period") : "")")
                .accessibilityHint(String(localized: "period_date_a11y_hint", defaultValue: "Tap to jump to another period"))
            }

            Spacer()

            Button {
                coordinate = coordinate.next
                loadPeriod()
                HapticFeedback.lightImpact(reduceMotion: reduceMotion)
            } label: {
                // Plain `chevron.forward` — system Liquid Glass paints the button.
                // Coordinator (2026-09-16): neutral `.glass` like "atrás" and "+" — the user
                // wants no solid accent fill here, `.glassProminent` was reverted.
                Image(systemName: "chevron.forward")
                    .frame(width: 29, height: 29)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(String(localized: "period_next_a11y", defaultValue: "Next period"))
        }
        .padding(.horizontal, 4)
    }

    private func lineBlock(title: String, kind: LineKind) -> some View {
        let lines = (period?.lineItems ?? [])
            .filter { $0.kind == kind }
            .sorted { $0.sortOrder < $1.sortOrder }

        return card(title: title, kind: kind, lines: lines)
    }

    // Coordinator (2026-09-18, user's Figma review): INCOME and EXPENSES now each get their
    // OWN enclosing container — the "INCOME"/"EXPENSES" label + "+" button, the individual
    // line cards (still `LineItemRow`'s own nested card style, unchanged), and "TOTAL
    // INCOME"/"TOTAL EXPENSES" all live inside the SAME card now, instead of sitting loose
    // directly on the root background. Root `AppBackground` is pure black in dark mode now,
    // so this container needs to visually read as a distinct surface on top of it.
    //
    // Coordinator (2026-09-18, read access restored to the Figma file — exact values pulled
    // from node 12:7 "income card" via `get_design_context`): supersedes the earlier
    // `.ultraThinMaterial.opacity(0.5)` placeholder used while the file was still read-locked.
    // The real design uses a solid `PeriodSectionCardBackground` fill (#161617 dark) — a
    // dedicated color asset, not `AppBackgroundSecondary` (that one is still pure black in
    // dark mode and wouldn't read as distinct from the root). Sobrante/Next Month/Mandar stay
    // loose below, untouched.
    private func card(title: String, kind: LineKind, lines: [LineItem]) -> some View {
        // TRD/DESIGN_LIQUID.md "Credit Cards" (2026-09-17): the ONLY row in Quincena that
        // represents more than one `LineItem` — `origin == .creditCard` lines collapse into a
        // single "Credit Cards Payments" navigation row (EXPENSES only), purely a presentation
        // grouping. Each card still keeps its own real `LineItem`/`isPaid`/`paidAt` — nothing
        // aggregated in `Core/`.
        let creditCardLines = kind == .expense ? lines.filter { $0.origin == .creditCard } : []
        // "Agrupar inversiones" (2026-09-17): same aggregation pattern as Credit Cards — GBM/
        // Webull/etc. (`origin == .investment`) collapse into a single "Investments" navigation
        // row (EXPENSES only). `regularLines` now excludes BOTH aggregated origins.
        let investmentLines = kind == .expense ? lines.filter { $0.origin == .investment } : []
        let regularLines = kind == .expense ? lines.filter { $0.origin != .creditCard && $0.origin != .investment } : lines
        let creditCardTotal = creditCardLines.reduce(Decimal(0)) { $0 + $1.amount }
        let investmentTotal = investmentLines.reduce(Decimal(0)) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 24) {
            // Coordinator (2026-09-16, user's Figma review): "+" reverts to the section
            // header, trailing "INCOME"/"EXPENSES" — the below-the-cards spot from the
            // previous pass is reverted per explicit instruction.
            // Coordinator (2026-09-18): now the top row INSIDE the container instead of a
            // loose title above it — no more +8pt indent needed to line up with the nested
            // row cards' inner text, since both the header and the rows now sit inside the
            // SAME 16pt container padding (an outer-edge-to-outer-edge relationship, not the
            // old loose-title-to-inner-text one).
            HStack {
                Text(title)
                    // Coordinator (2026-09-17): no longer distinct from "TOTAL INCOME"/"TOTAL
                    // EXPENSES" — both are now `p small` (`.caption` Bold, 12pt), the same
                    // token.
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Spacer()

                Button {
                    captureTarget = CaptureTarget(line: nil, kind: kind)
                } label: {
                    // Coordinator (2026-09-16): exact Figma layer name — plain `plus`, no
                    // capsule/circle, ~20pt (Figma: 19.8×19.82pt).
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind == .income ? String(localized: "period_add_income_a11y", defaultValue: "Add income") : String(localized: "period_add_expense_a11y", defaultValue: "Add expense"))
            }

            // DESIGN_LIQUID.md § "Bloques INCOME/EXPENSES" (Figma, updated 2026-09-15 —
            // supersedes the single-card-with-dividers layout): each line is still its own
            // nested card (see `LineItemRow`), stacked with an 8pt gap, no `Divider()` between
            // them — the gap itself is the separator. This whole stack now lives inside the
            // outer INCOME/EXPENSES container (2026-09-18) rather than directly on the root
            // background.
            VStack(alignment: .leading, spacing: 8) {
                ForEach(regularLines) { line in
                    LineItemRow(
                        line: line,
                        exchangeRate: effectiveRate,
                        onStartEditing: { captureTarget = CaptureTarget(line: line, kind: kind) },
                        onDelete: line.origin == .manual ? { deleteLine(line) } : nil,
                        onQuickCommit: { commitQuickEdit() },
                        onToggleActive: { toggleActive(line) },
                        onTogglePaid: { togglePaid(line) }
                    )
                }

                if !creditCardLines.isEmpty {
                    Button {
                        isPresentingCreditCardSheet = true
                    } label: {
                        HStack {
                            Text(String(localized: "period_credit_cards_row_title", defaultValue: "Credit Cards Payments"))
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(creditCardTotal.currencyString())
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        .background(Color("AppBackgroundSecondary"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    // DESIGN_LIQUID.md: pure navigation, no swipe/contextMenu/palomita — the
                    // state lives per-card inside the sheet, not on this row.
                    .accessibilityLabel(String(localized: "period_credit_cards_row_a11y", defaultValue: "Credit card payments, \(creditCardTotal.currencyString())"))
                    .accessibilityHint(String(localized: "period_credit_cards_row_a11y_hint", defaultValue: "Double-tap to see the breakdown by card"))
                }

                if !investmentLines.isEmpty {
                    Button {
                        isPresentingInvestmentSheet = true
                    } label: {
                        HStack {
                            Text(String(localized: "period_investments_row_title", defaultValue: "Investments"))
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(investmentTotal.currencyString())
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        .background(Color("AppBackgroundSecondary"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    // Same pattern as the Credit Cards row: pure navigation, no
                    // swipe/contextMenu/palomita — the state lives per-line inside the sheet,
                    // not on this row.
                    .accessibilityLabel(String(localized: "period_investments_row_a11y", defaultValue: "Investments, \(investmentTotal.currencyString())"))
                    .accessibilityHint(String(localized: "period_investments_row_a11y_hint", defaultValue: "Double-tap to see the breakdown by account"))
                }
            }

            HStack {
                // `p small` (`.caption` Bold, 12pt) — same token as the header above.
                Text(kind == .income ? String(localized: "period_total_income", defaultValue: "TOTAL INCOME") : String(localized: "period_total_expenses", defaultValue: "TOTAL EXPENSES"))
                    .font(.caption.weight(.bold))
                Spacer()
                Text(total(for: kind).currencyString())
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
        }
        // Coordinator (2026-09-18): the container's own padding — 16pt is the standard card
        // padding already used everywhere else in the app (`LoanDetailView`,
        // `InvestmentsView`, `LineItemRow`'s own nested cards) — wraps the header, the line
        // cards and the TOTAL row together as one surface.
        .padding(16)
        // Coordinator (2026-09-18, Figma node 12:7 via `get_design_context`, exact values):
        // solid `PeriodSectionCardBackground` (#161617 dark) instead of `.ultraThinMaterial`,
        // and 24pt corner radius instead of 20pt — supersedes the material/20pt placeholder
        // used before read access to this node was available.
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color("PeriodSectionCardBackground")))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(kind == .income ? String(localized: "period_income_a11y", defaultValue: "Income") : String(localized: "period_expenses_a11y", defaultValue: "Expenses"))
    }

    // Coordinator (2026-09-15, Figma tSUzh4zfCpDPYT5A88otst node 8:2): the "Tipo de cambio"
    // row + "Editar" button are removed from the Quincena's Resumen entirely — the manual
    // override stays reachable from Ajustes → Preferencias → Tipo de cambio
    // (`ExchangeRateSettingsView`), which already has it. The per-quincena-only override this
    // sheet used to write (`period.manualExchangeRateOverride`) has no UI trigger left as a
    // result — accepted by the coordinator's instruction, not an oversight.
    private var summaryPanel: some View {
        SummaryPanel(mandar: mandar, nextMonth: nextMonth)
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 24) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        // Larry (2026-09-17): missing `style:` defaulted to `.circular`, not
                        // the app's squircle — 12pt is the internal-element token.
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary).frame(height: 44)
                    }
                }
                .padding()
                .redacted(reason: .placeholder)
            }
        }
        .padding(16)
        .accessibilityLabel(String(localized: "period_loading_a11y", defaultValue: "Loading period"))
    }

    // MARK: - Actions

    private func loadPeriod() {
        period = PeriodCoordinator.materializeIfNeeded(
            coordinate: coordinate,
            context: context,
            recurringItems: recurringSnapshots,
            subscriptions: subscriptionSnapshots,
            loans: loanSnapshots,
            exchangeRate: rateStore.currentRate ?? 0
        )
        try? context.save()
    }

    /// `LineCaptureSheet`'s `onSave` — `existingLine == nil` creates a brand-new manual
    /// `LineItem` (no draft ever touches the store until this point, which is what actually
    /// eliminates the old ghost-row bug instead of just papering over it with a discard path);
    /// non-nil edits that line in place. Either way, ends with the same persist +
    /// `recomputeForward` sequence as every other edit.
    private func saveLine(_ existingLine: LineItem?, kind: LineKind, title: String, amount: Decimal, currency: Currency) {
        guard let period else { return }
        if let existingLine {
            // "Bloqueo de líneas pagadas" (2026-09-16): a confirmed-paid line is frozen —
            // the sheet shouldn't reach this path for one (UI hides the entry point), but
            // guard here too since `saveLine` is the actual mutation point.
            guard PeriodCoordinator.canModify(line: existingLine) else { return }
            existingLine.title = title
            existingLine.amount = amount
            existingLine.currency = currency
            if existingLine.origin != .manual { existingLine.isManuallyEdited = true }
        } else {
            let nextOrder = ((period.lineItems ?? []).map(\.sortOrder).max() ?? -1) + 1
            let line = LineItem(kind: kind, title: title, amount: amount, currency: currency, sortOrder: nextOrder, origin: .manual, period: period)
            context.insert(line)
            period.lineItems?.append(line)
        }
        try? context.save()
        PeriodCoordinator.recomputeForward(after: period, context: context, exchangeRate: effectiveRate)
        try? context.save()
    }

    private func deleteLine(_ line: LineItem) {
        guard let period else { return }
        guard PeriodCoordinator.canModify(line: line) else { return }
        period.lineItems?.removeAll { $0.id == line.id }
        context.delete(line)
        try? context.save()
        PeriodCoordinator.recomputeForward(after: period, context: context, exchangeRate: effectiveRate)
        try? context.save()
    }

    /// Swipe-leading (DESIGN_LIQUID.md): toggles `isActive`, which affects every total —
    /// needs the same persist-then-`recomputeForward` sequence as any other edit. Counts as a
    /// manual edit on non-manual lines so `reproject*` never silently reactivates it later.
    private func toggleActive(_ line: LineItem) {
        guard PeriodCoordinator.canModify(line: line) else { return }
        line.isActive.toggle()
        if line.origin != .manual { line.isManuallyEdited = true }
        try? context.save()
        if let period {
            PeriodCoordinator.recomputeForward(after: period, context: context, exchangeRate: effectiveRate)
            try? context.save()
        }
    }

    /// Swipe-trailing's first action: purely visual, no recompute — but still counts as a
    /// manual edit so a later `reproject*` doesn't reset it (same reasoning as `toggleActive`).
    private func togglePaid(_ line: LineItem) {
        line.isPaid.toggle()
        // TRD "paidAt/progreso real de préstamos" (2026-09-16): the real confirmation date,
        // set only by this manual toggle — never derived from the period's own date.
        line.paidAt = line.isPaid ? CivilDate.today(calendar: .current) : nil
        if line.origin != .manual { line.isManuallyEdited = true }
        try? context.save()
    }

    /// The one direct in-place row mutation left (`LineItemRow`'s contextMenu "Cambiar a
    /// MXN/USD") — same persist + `recomputeForward` sequence as everything else.
    private func commitQuickEdit() {
        try? context.save()
        if let period {
            PeriodCoordinator.recomputeForward(after: period, context: context, exchangeRate: effectiveRate)
            try? context.save()
        }
    }

    private func total(for kind: LineKind) -> Decimal {
        CarryOverEngine.total(for: currentSnapshots, kind: kind, exchangeRate: effectiveRate)
    }

    private var currentSnapshots: [LineSnapshot] {
        period.map(PeriodCoordinator.snapshots(of:)) ?? []
    }

    private var sobrante: Decimal {
        CarryOverEngine.sobrante(for: currentSnapshots, exchangeRate: effectiveRate)
    }

    private var mandar: Decimal {
        CarryOverEngine.mandar(for: currentSnapshots, exchangeRate: effectiveRate)
    }

    private var nextMonth: Decimal {
        guard let period else { return 0 }
        return PeriodCoordinator.previewNextMonth(
            after: period,
            context: context,
            recurringItems: recurringSnapshots,
            subscriptions: subscriptionSnapshots,
            loans: loanSnapshots,
            exchangeRate: effectiveRate
        )
    }
}
