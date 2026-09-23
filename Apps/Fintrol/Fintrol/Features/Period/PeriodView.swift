import SwiftUI
import SwiftData
import AppleAppLabUI

struct PeriodView: View {
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore

    /// Woz (2026-09-20, `revealProgress` unification — replaces the old `PeriodPreviewCard` +
    /// `HomeView.staticPeriodLayer` two-view architecture entirely): `1` by default (fully
    /// revealed — the normal standalone `PeriodView()` call site in `RootView.swift` is
    /// completely unaffected). `HomeView` drives this LIVE with `dragProgress` (0...1) during
    /// the Home→Quincena drag — NOT a separate morph/tracking mechanism, just a continuous
    /// parameter this view reacts to directly, the same way the rest of the drag reads
    /// `dragTranslation` 1:1. Controls the crossfade+reflow between the compact "quick-balance"
    /// summary (INCOME/EXPENSES side-by-side boxes, visible at low `revealProgress`, see
    /// `quickBalanceLayer`) and the detailed income/expenses cards (individual line items,
    /// visible at high `revealProgress`, see `detailedCardsLayer`) — confirmed against the
    /// user's Figma file (node `57:80` "Content" inside "01 · Quincena", node `8:2`): a
    /// `quick-balance` child sits `hidden="true"` at the exact same origin as the detailed
    /// `income card`/`expenses card` siblings that follow it, i.e. the design file itself
    /// already models this as "swap one representation for another, let the rest of the layout
    /// close the gap."
    var revealProgress: CGFloat = 1

    /// Woz (2026-09-20): replaces `PeriodPreviewCard.onTap`. `nil` by default (the normal
    /// standalone `PeriodView()` call site — tapping the title/handle opens `JumpSheet`, same
    /// as always). `HomeView` passes its own `navigateToPeriod` here when embedding this view —
    /// see `handleOrTitleTapped()` for how the two behaviors are selected, and this file's top
    /// doc comment for why only the drag handle + title region (not the whole screen) triggers
    /// it now that the embedded view is genuinely interactive.
    var onTap: (() -> Void)?

    /// True RGB interpolation between `PeriodSectionCardBackground` (#161617, `revealProgress ==
    /// 0`) and `AppBackground` (#000000, `revealProgress == 1`) — see the `.background(...)`
    /// call site's doc comment for why this replaced a naive stacked-opacity crossfade (produced
    /// a visible gray wash instead of a clean solid color). Both endpoints are dark neutral grays
    /// this close together, so a flat per-channel lerp reads as a clean fade with no visible hue
    /// shift.
    private var embeddedBackgroundColor: Color {
        let t = Double(min(max(revealProgress, 0), 1))
        let component = Double(0x16) / 255.0 * (1 - t)
        let blueComponent = Double(0x17) / 255.0 * (1 - t)
        return Color(red: component, green: component, blue: blueComponent)
    }

    /// Settings → Preferencias → "Mostrar próximo mes". `true` by default (the normal standalone
    /// `PeriodView()` call site always shows `NextMonthCard`, unaffected). `HomeView` threads its
    /// own `@AppStorage` read through here when embedding this view — see
    /// `SummaryPanel.showNextMonth`'s doc comment.
    var showNextMonth: Bool = true

    /// Drives the previous/next period chevron buttons' slide-in reveal — `1` by default (fully
    /// in place, no offset) so the normal `PeriodView()` call site in `RootView.swift` is
    /// unaffected. `HomeView` sets this to a value that ramps from `0` to `1` only in the FINAL
    /// portion of the Home→Quincena drag (see `HomeView.chevronsRevealProgress`), so the chevrons
    /// slide in from off-screen only as the transition is nearly complete, instead of sitting
    /// static for the whole drag. Deliberately UNTOUCHED by the `revealProgress` unification
    /// (2026-09-20, explicit user instruction) — left exactly as it was.
    var chevronsRevealProgress: CGFloat = 1

    /// Natural (unconstrained) height of `quickBalanceBlock`, measured via
    /// `QuickBalanceHeightKey` — see `quickBalanceLayer` for how this drives the collapse-to-zero
    /// animation as `revealProgress` rises.
    @State private var quickBalanceNaturalHeight: CGFloat = 0
    /// Natural (unconstrained) height of `detailedCardsLayer`'s content (`blocks`), measured via
    /// `DetailedCardsHeightKey` — mirror of `quickBalanceNaturalHeight`, see `detailedCardsLayer`.
    @State private var detailedCardsNaturalHeight: CGFloat = 0

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
    @State private var isPresentingEssentialsSheet = false
    @State private var isPresentingPaymentsSheet = false
    @State private var isPresentingServiciosSheet = false
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

    // Debug-only: reads the SAME `HomeDragDebugState` instance `HomeView`/`RootView`'s
    // `GestureDebugHUD` already share (defined in `RootView.swift`, injected app-wide via
    // `.environment` from `RootView` — visible here with no import since it's the same module),
    // so `PeriodView` can draw its own `.debugOutline(...)` layers when "outlines: ON" is
    // toggled from the HUD, whether this instance is mounted standalone (tab/sidebar root) or
    // embedded inside `HomeView.cardLayer` during the drag transition. See
    // `HomeDragDebugState.outlinesEnabled`'s doc comment.
    #if DEBUG
    @Environment(HomeDragDebugState.self) private var debugState
    #endif

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
            SubscriptionSnapshot(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency, paymentDay: $0.paymentDay, startDate: $0.civilStartDate, endDate: $0.civilEndDate, kind: $0.kind, isActive: $0.isActive, isBiweekly: $0.isBiweekly)
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
        // brand-new `PeriodView()` instance in `iOSRootView` (distinct from the drag's own
        // embedded instance inside `HomeView.cardLayer`), which starts `isLoading = true` again
        // and, without this, showed `loadingSkeleton` with no background of its own for that one
        // frame.
        //
        // Woz (2026-09-20, corner-radius-invisible-on-black fix): was a flat `Color("AppBackground")`
        // fill — correct for the standalone tab (real nav-bar/system chrome around it provides
        // contrast) but WRONG when embedded in `HomeView.cardLayer`: that ZStack's base layer is
        // ALSO plain `AppBackground` (pure black) painted directly behind the embedded card with
        // nothing in between, so the clipped `UnevenRoundedRectangle` corners (see
        // `HomeView.cardLayer`) were genuinely there and genuinely clipped — just invisible, zero
        // contrast between "inside the clip" and "outside the clip". Same class of bug already
        // fixed once on the old, now-deleted `PeriodPreviewCard` (`PeriodSectionCardBackground`,
        // #161617, specifically to stand out against the plain black behind it) — lost when that
        // view got folded into this one and reverted to plain `AppBackground`.
        //
        // Fix interpolates the ACTUAL RGB channels between the two colors, driven by
        // `revealProgress`, instead of stacking two independently-translucent `Color.opacity(...)`
        // fills — that first attempt (2026-09-20) looked washed-out/gray on-device: overlaying two
        // partially-transparent flat fills doesn't blend to the same result as a true color lerp,
        // it visibly greys out everything underneath (a user-reported screenshot showed exactly
        // this — a persistent gray wash over the whole card, not a clean solid background).
        // `embeddedBackgroundColor` below produces ONE fully-opaque interpolated color instead, so
        // there's no stacked-translucency artifact. Reuses the SAME progress signal
        // `HomeView.cardLayer` already threads in as `revealProgress: dragProgress` — no extra
        // plumbing needed: standalone (`onTap == nil`) always has `revealProgress == 1` (its
        // default), so it's 100% `AppBackground`, unchanged from before. Embedded, it starts at
        // `revealProgress == 0` (100% `PeriodSectionCardBackground`, contrast against the black
        // behind it) and interpolates to 100% `AppBackground` by `revealProgress == 1` (full
        // commit), exactly matching the destination standalone tab at the hand-off instant — same
        // convergence-to-zero-difference invariant `cardCornerRadius`/`embeddedTopInset` rely on.
        // User correction (2026-09-20): the interpolated `embeddedBackgroundColor` used to sit
        // HERE, at the whole view's root — covering the scrollable content area too, which read
        // as an unwanted gray patch behind INCOME/EXPENSES (a user screenshot flagged exactly
        // this). The rounded-corner contrast problem only ever concerns the very TOP edge, where
        // `stickyHeader` sits against the white header above — so the interpolated color moved
        // THERE (see `stickyHeader`'s own `.background`), and this root fill goes back to a flat
        // `AppBackground`, matching `HomeView.content`'s own base layer exactly — no visible seam,
        // no extra background box, transparent-reading scroll content exactly as intended.
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
        .sheet(isPresented: $isPresentingEssentialsSheet) {
            SubscriptionBreakdownSheet(
                title: String(localized: "period_essentials_row_title", defaultValue: "Essentials"),
                lines: (period?.lineItems ?? []).filter { $0.origin == .essential }.sorted { $0.sortOrder < $1.sortOrder },
                exchangeRate: effectiveRate,
                onStartEditing: { captureTarget = CaptureTarget(line: $0, kind: .expense) },
                onQuickCommit: { commitQuickEdit() },
                onToggleActive: { toggleActive($0) },
                onTogglePaid: { togglePaid($0) }
            )
        }
        .sheet(isPresented: $isPresentingPaymentsSheet) {
            SubscriptionBreakdownSheet(
                title: String(localized: "period_payments_row_title", defaultValue: "Payments"),
                lines: (period?.lineItems ?? []).filter { $0.origin == .subscription && !$0.isHomeService }.sorted { $0.sortOrder < $1.sortOrder },
                exchangeRate: effectiveRate,
                onStartEditing: { captureTarget = CaptureTarget(line: $0, kind: .expense) },
                onQuickCommit: { commitQuickEdit() },
                onToggleActive: { toggleActive($0) },
                onTogglePaid: { togglePaid($0) }
            )
        }
        .sheet(isPresented: $isPresentingServiciosSheet) {
            SubscriptionBreakdownSheet(
                title: String(localized: "period_servicios_row_title", defaultValue: "Servicios"),
                lines: (period?.lineItems ?? []).filter { $0.origin == .subscription && $0.isHomeService }.sorted { $0.sortOrder < $1.sortOrder },
                exchangeRate: effectiveRate,
                onStartEditing: { captureTarget = CaptureTarget(line: $0, kind: .expense) },
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
                        periodContentBlocks
                        // Coordinator (2026-09-21, /update-ui): Sobrante→Next Month is its own
                        // tighter 8pt gap in Figma (`balance` frame: SOBRANTE height 81, Resumen
                        // starts at y=89 → 8pt), not the outer 24pt block spacing.
                        VStack(spacing: 8) {
                            SobranteBadge(sobrante: sobrante)
                                #if DEBUG
                                .debugOutline("sobrante", color: .pink, enabled: debugState.outlinesEnabled)
                                #endif
                            summaryPanel
                                #if DEBUG
                                .debugOutline("summaryPanel", color: .mint, enabled: debugState.outlinesEnabled)
                                #endif
                        }
                    }
                } else {
                    #if os(macOS)
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 24) {
                            periodContentBlocks
                            SobranteBadge(sobrante: sobrante)
                                #if DEBUG
                                .debugOutline("sobrante", color: .pink, enabled: debugState.outlinesEnabled)
                                #endif
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(String(localized: "period_two_column_income_a11y", defaultValue: "Income and expenses column"))

                        summaryPanel
                            .frame(width: 280)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel(String(localized: "period_two_column_summary_a11y", defaultValue: "Summary column"))
                            #if DEBUG
                            .debugOutline("summaryPanel", color: .mint, enabled: debugState.outlinesEnabled)
                            #endif
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "period_two_column_layout_a11y", defaultValue: "Two-column layout"))
                    #else
                    periodContentBlocks
                    // Coordinator (2026-09-21, /update-ui): Sobrante→Next Month is its own
                    // tighter 8pt gap in Figma (`balance` frame: SOBRANTE height 81, Resumen
                    // starts at y=89 → 8pt), not the outer 24pt block spacing — applies to both
                    // the embedded Home preview and the standalone Quincena tab, same view.
                    VStack(spacing: 8) {
                        SobranteBadge(sobrante: sobrante)
                            #if DEBUG
                            .debugOutline("sobrante", color: .pink, enabled: debugState.outlinesEnabled)
                            #endif
                        summaryPanel
                            #if DEBUG
                            .debugOutline("summaryPanel", color: .mint, enabled: debugState.outlinesEnabled)
                            #endif
                    }
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
            #if DEBUG
            .debugOutline("content", color: .indigo, enabled: debugState.outlinesEnabled, padding: "h:10 top:12 bottom:16")
            #endif
        }
        // Coordinator (2026-09-17): the Quincena header (title/chevrons/range pill) is now
        // fixed above the scroll content instead of scrolling away with it — `.safeAreaInset`
        // both pins it AND automatically reserves exactly its own height as extra top inset
        // for the ScrollView's content, so nothing needs a hand-tuned padding-top to avoid
        // starting hidden underneath it (the manual-overlay/ZStack alternative would need
        // that arithmetic redone by hand any time the header's height changes).
        .safeAreaInset(edge: .top, spacing: 0) {
            stickyHeader
                #if DEBUG
                .debugOutline("stickyHeader", color: .orange, enabled: debugState.outlinesEnabled, padding: "h:10 top:4 bottom:8")
                #endif
        }
        // `ScrollView` paints its own system content background (a system material, close to
        // but NOT exactly any of our own colors) OVER whatever sits behind it unless told
        // otherwise — confirmed by direct experiment (2026-09-20): swapping this view's own
        // root `.background(...)` all the way to `Color.blue` had ZERO visible effect on the
        // area behind this `ScrollView`'s content, while the same swap DID affect areas
        // outside it (nothing to compare there, but the total absence of blue anywhere in the
        // scroll region was the tell). `.scrollContentBackground(.hidden)` turns that system
        // fill off so our own explicit backgrounds (root `AppBackground`, `stickyHeader`'s
        // `embeddedBackgroundColor`, each card's own fill) are what's actually visible,
        // instead of the system material showing through every gap between them.
        .scrollContentBackground(.hidden)
        // Woz (2026-09-20, `revealProgress` unification): measures `quickBalanceBlock`'s and
        // `detailedCardsLayer`'s own NATURAL (unconstrained) heights — same `GeometryReader` +
        // `PreferenceKey` technique `HomeView.HeaderHeightKey` already uses — so
        // `quickBalanceLayer`/`detailedCardsLayer` can collapse/grow between `0` and that real
        // measured height as `revealProgress` changes, instead of a guessed constant.
        .onPreferenceChange(QuickBalanceHeightKey.self) { quickBalanceNaturalHeight = $0 }
        .onPreferenceChange(DetailedCardsHeightKey.self) { detailedCardsNaturalHeight = $0 }
    }

    /// Groups `quickBalanceLayer` and `detailedCardsLayer` with NO spacing between them — per
    /// the user's Figma file, both occupy the exact same origin (the compact quick-balance sits
    /// `hidden="true"` at the same position the detailed income/expenses cards start at), and
    /// since they're driven by complementary `(1 - revealProgress)`/`revealProgress` heights off
    /// the SAME parameter, only one of the two ever has non-zero height at the extremes — an
    /// outer `spacing` here would just reintroduce a gap between them during the crossfade.
    private var periodContentBlocks: some View {
        VStack(spacing: 0) {
            quickBalanceLayer
                #if DEBUG
                .debugOutline("quickBalance", color: .purple, enabled: debugState.outlinesEnabled)
                #endif
            detailedCardsLayer
        }
    }

    /// Compact INCOME/EXPENSES summary — visible (full height, full opacity) at
    /// `revealProgress == 0`, collapses to zero height AND zero opacity by `revealProgress == 1`
    /// so it's completely out of the layout once fully revealed (matches the Figma file's own
    /// `hidden="true"` modeling of this element — see `revealProgress`'s doc comment). Measured
    /// via `.background(GeometryReader ...)` placed BEFORE `.frame(height:)` in the modifier
    /// chain — the background reports `quickBalanceBlock`'s own natural size (an `HStack` of
    /// fixed-size `Text`/card elements that doesn't compress under a smaller proposed height),
    /// independent of the `.frame(height:)` constraint applied afterward, which is what lets this
    /// converge to the same natural height on every layout pass regardless of `revealProgress`.
    /// Guards on `quickBalanceNaturalHeight > 0` (not yet measured) so the very first render
    /// doesn't flash collapsed before the first measurement lands.
    private var quickBalanceLayer: some View {
        quickBalanceBlock
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: QuickBalanceHeightKey.self, value: geo.size.height)
                }
            )
            .frame(height: quickBalanceNaturalHeight > 0 ? quickBalanceNaturalHeight * (1 - revealProgress) : nil, alignment: .top)
            .clipped()
            .opacity(1 - revealProgress)
            .allowsHitTesting(revealProgress < 1)
    }

    /// The detailed INCOME/EXPENSES cards (`blocks` — individual line items, "+" buttons, swipe
    /// actions, all genuinely interactive, user's explicit decision) — mirror image of
    /// `quickBalanceLayer`: zero height/opacity at `revealProgress == 0`, grows to `blocks`' own
    /// natural full height/opacity by `revealProgress == 1` (the normal standalone `PeriodView()`
    /// appearance, completely unaffected since `revealProgress` defaults to `1` there). Same
    /// measurement technique as `quickBalanceLayer` — see that doc comment.
    ///
    /// `.allowsHitTesting(revealProgress > 0)`: below a certain `revealProgress` this is
    /// zero-height and `.clipped()`, so nothing here is actually paintable — this just makes
    /// that explicit rather than relying on zero-size alone to keep it out of hit-testing.
    private var detailedCardsLayer: some View {
        blocks
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: DetailedCardsHeightKey.self, value: geo.size.height)
                }
            )
            .frame(height: detailedCardsNaturalHeight > 0 ? detailedCardsNaturalHeight * revealProgress : nil, alignment: .top)
            .clipped()
            .opacity(revealProgress)
            .allowsHitTesting(revealProgress > 0)
    }

    /// Figma mockup (2026-09-18): INCOME/EXPENSES are two side-by-side "boxes" — label above,
    /// amount inside a nested card below. Relocated verbatim from the now-deleted
    /// `PeriodPreviewCard.totalsBlock`/`totalColumn` (2026-09-20, `revealProgress` unification) —
    /// same `.ultraThinMaterial.opacity(0.5)` nested-card fill used by `LoanDetailView`/
    /// `InvestmentsView` for their internal stat cards.
    private var quickBalanceBlock: some View {
        HStack(spacing: 16) {
            quickBalanceColumn(title: String(localized: "period_income_header", defaultValue: "INCOME"), amount: income)
            quickBalanceColumn(title: String(localized: "period_expenses_header", defaultValue: "EXPENSES"), amount: expense)
        }
    }

    private func quickBalanceColumn(title: String, amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                // Coordinator (2026-09-21, /update-ui): Figma's "title" node is 14px Bold with
                // 0.6px tracking, not `.caption` (12px) — and it's centered within the column's
                // full width (a wrapper with `justify-center`), not left-aligned.
                .font(.system(size: 14, weight: .bold))
                .tracking(0.6)
                // Coordinator (2026-09-21, tokens update): system `.secondary` → the Figma
                // token's `Text/Secondary` (#A8A8A8, solid) — same pass across every dark-mode
                // caption on this screen.
                .foregroundStyle(Color("TextSecondary"))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(amount.currencyString())
                // Coordinator (2026-09-21, /update-ui): Figma's amount is Regular weight, not
                // Semibold.
                .font(.system(size: 17, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(.primary)
                // Coordinator (2026-09-21): centered, not leading — Figma's row is symmetric
                // (29.25pt on both sides of the amount within the 140.5pt row).
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(16)
                .background(
                    // Coordinator (2026-09-21, /update-ui): 20pt, not 16 — matches Figma's
                    // `rounded-[20px]` on this box (the app's own "internos" token is 12pt and
                    // "cards" is 20pt; Figma puts this specific box on the card radius, not the
                    // internal-element one).
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        // Solid #2a2a2a per Figma (was `.ultraThinMaterial.opacity(0.5)`,
                        // inherited from `PeriodPreviewCard.totalColumn` — that material read
                        // fine on the old card's own contrasting background, but blurs/lightens
                        // whatever's behind it, which reads as an unwanted gray wash now that
                        // this box sits directly on Home's black background (user-reported
                        // screenshot, 2026-09-20).
                        .fill(Color(red: 0x2a / 255.0, green: 0x2a / 255.0, blue: 0x2a / 255.0))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(spacing: 16) {
            dragHandle
                #if DEBUG
                .debugOutline("dragHandle", color: .blue.opacity(0.6), enabled: debugState.outlinesEnabled)
                #endif
            header
        }
            // Coordinator (2026-09-17): matches `content`'s 10pt horizontal margin.
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .background(alignment: .bottom) {
                // User request (2026-09-22): liquid-glass sticky header — scrolled content
                // should show through, blurred, instead of the flat `AppBackground` fill this
                // used before. `.ultraThinMaterial` gives the frost/blur; a thin `AppBackground`
                // tint on top keeps the date/title legible against whatever scrolls underneath
                // without going back to fully opaque. Only for the real, standalone Quincena
                // screen (`onTap == nil`) — the follow-up user correction (2026-09-22) explicitly
                // scoped this OUT of the embedded `HomeView` preview card, which keeps its
                // original flat fill via `embeddedBackgroundColor` below.
                Group {
                    if onTap == nil {
                        // Bug fix (2026-09-22, user report — screenshot showed a visible seam,
                        // "como si hubiera dos layers"): the material's own frame has a hard
                        // rectangular edge, and unblurred list content sits directly below it, so
                        // a flat-opacity fade over a fixed 14pt strip still cut off abruptly.
                        // Masking the WHOLE fill (material + tint) with a gradient — not just a
                        // layer stacked on top of it — fades the blur itself out over a taller
                        // stretch, so the glass dissolves into the scrolled content instead of
                        // ending in a visible edge.
                        ZStack(alignment: .bottom) {
                            Rectangle().fill(.ultraThinMaterial)
                            Color("AppBackground").opacity(0.35)
                        }
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.82),
                                    .init(color: .black.opacity(0), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
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
                // Bug fix (2026-09-21, user report): `.safeAreaInset` places this view's own
                // frame right at the safe area boundary, not behind the status bar/Dynamic
                // Island above it — so THIS fill (everything else in `stickyHeader` stays put)
                // never covered that strip, and scrolled content became visible poking through
                // it. Extending only the background (not the content, which must stay inset
                // below the status bar) up into the top safe area closes that gap.
                .ignoresSafeArea(edges: .top)
            }
            // User request (2026-09-22): horizontal swipe as a second way to change period,
            // originally scoped to just `header` (the date/chevrons row) — user follow-up
            // ("extiendelo a que sea a cualquier parte de la parte de arriba") widened it to the
            // WHOLE sticky header (drag handle capsule included), matching the red-boxed area in
            // their screenshot. `.contentShape(Rectangle())` first: an `HStack`/`VStack` with
            // `Spacer()`s is only hit-testable where its children actually draw pixels by
            // default, so without this, a touch starting in a `Spacer()` gap wouldn't reach the
            // gesture at all — likely why the swipe felt inconsistent by direction/position
            // before this widened it to the full frame. Explicit mapping from the user, not the
            // usual "swipe left reveals what's next" paging convention: left-to-right (positive
            // translation) → next period, right-to-left (negative translation) → previous.
            // `minimumDistance: 24` keeps this from fighting the title's own tap-to-jump.
            // Mirrors the chevrons exactly — same `coordinate.next`/`.previous`, same
            // `loadPeriod()`, same haptic, same historical-limit guard as the disabled
            // `chevron.backward`.
            //
            // Bug fix (2026-09-22, verified in simulator): plain `.gesture` lost the arena to
            // the title's own `Button` every time — SwiftUI prefers a descendant's gesture, so
            // even a real swipe across the title got read as a tap and opened `JumpSheet`
            // instead. `.highPriorityGesture` claims the touch stream first, but only once the
            // drag actually clears `minimumDistance` — a true tap-with-no-movement still never
            // "starts", so it falls through to the title's `onTapGesture` exactly as before.
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width > 0 {
                            coordinate = coordinate.next
                            loadPeriod()
                            HapticFeedback.lightImpact(reduceMotion: reduceMotion)
                        } else if coordinate > earliestCoordinate {
                            coordinate = coordinate.previous
                            loadPeriod()
                            HapticFeedback.lightImpact(reduceMotion: reduceMotion)
                        }
                    }
            )
    }

    /// Woz (2026-09-20, `revealProgress` unification): relocated verbatim from the now-deleted
    /// `PeriodPreviewCard.dragHandle` — figma mockup 100×4pt capsule, `#252525`, centered. Common
    /// to both states now (always present at its natural layout position, per `revealProgress`'s
    /// doc comment), not just the old preview-only card. Tappable, same action as the title (see
    /// `handleOrTitleTapped()`) — part of the "non-interactive top region" that navigates to the
    /// real Quincena tab when embedded (user's explicit decision, §4 of the reveal-unification
    /// plan: the whole card is no longer one big `Button` now that its lower content is genuinely
    /// interactive, so only this handle + the title below it still act as a single tap target).
    private var dragHandle: some View {
        Button(action: handleOrTitleTapped) {
            Capsule()
                .fill(Color(red: 0x25 / 255.0, green: 0x25 / 255.0, blue: 0x25 / 255.0)) // #252525
                .frame(width: 100, height: 4)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    /// Shared action for `dragHandle` and the title button inside `header` — the "non-interactive
    /// top region" (drag handle + title/header block, everything in `header` EXCEPT the
    /// chevrons, which keep their own previous/next-period actions untouched). When `onTap` is
    /// set (this instance is embedded inside `HomeView`), tapping either one navigates to the
    /// real Quincena tab/section, exactly like the whole old `PeriodPreviewCard` used to on any
    /// tap. When `onTap` is `nil` (the normal standalone `PeriodView()` call site), tapping opens
    /// `JumpSheet` — the screen's own original behavior, completely unaffected.
    private func handleOrTitleTapped() {
        if let onTap {
            onTap()
        } else {
            showJumpSheet = true
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
        #if DEBUG
        .debugOutline("blocks", color: .teal, enabled: debugState.outlinesEnabled)
        #endif
    }

    private var swipeDiscoverabilityHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .foregroundStyle(Color.accentColor)
            Text(String(localized: "period_swipe_hint_message", defaultValue: "Swipe a line: right to activate or deactivate, left to mark it as paid (swipe again to delete or edit)."))
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
            Spacer(minLength: 0)
            Button {
                hasSeenSwipeHint = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color("TextSecondary"))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "period_swipe_hint_dismiss_a11y", defaultValue: "Dismiss hint"))
        }
        .padding(12)
        // Larry (2026-09-17): a dismissible inline tip banner (12pt padding), not a card in
        // its own right — the 12pt internal-element token, not the 20pt card radius.
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.1)))
        .accessibilityElement(children: .combine)
        #if DEBUG
        .debugOutline("swipeHint", color: .brown, enabled: debugState.outlinesEnabled, padding: "12")
        #endif
    }

    /// Year + month + range pill — extracted out of `header` so the chevrons on either side stay
    /// out of it. Uses the shared `PeriodTitleBlock` content, common to both revealed states now
    /// (see `revealProgress`'s doc comment) — no longer paired with a separately-tracked floating
    /// copy; this IS the only copy, always.
    private var titleBlock: some View {
        PeriodTitleBlock(coordinate: coordinate, isTodayCoordinate: isTodayCoordinate)
            #if DEBUG
            .debugOutline("titleBlock", color: .purple, enabled: debugState.outlinesEnabled)
            #endif
    }

    // User request (2026-09-22): hide the chevron buttons "por el momento" now that the header
    // swipe does the same next/previous navigation — kept as a single flag (not deleted) so
    // it's a one-line revert if they come back. The buttons themselves, `earliestCoordinate`
    // disabling, and their accessibility labels are all left intact below, just not shown.
    private var showsChevronButtons: Bool { false }

    private var header: some View {
        HStack {
            if showsChevronButtons {
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
                // Slides in from off-screen left, only in the final portion of the Home→Quincena
                // drag — see `chevronsRevealProgress` doc comment.
                .offset(x: (chevronsRevealProgress - 1) * 80)
                .opacity(chevronsRevealProgress)
            }

            Spacer()

            VStack(spacing: 4) {
                // Bug fix (2026-09-22, user report — swipe "a veces funciono y a veces no" on
                // real device, right-to-left "no funciona nada"): this used to be a `Button`,
                // which on real hardware races unpredictably against the header's own
                // `.highPriorityGesture` swipe below — Button's UIKit-bridged press recognizer
                // can win the arena even when a real drag is in progress, far more often than in
                // the simulator's cleaner synthetic touches. Plain `.onTapGesture` composes
                // deterministically with an ancestor's `.highPriorityGesture(DragGesture(...))`:
                // once the touch clears `minimumDistance`, the drag claims the stream and the tap
                // never fires; below that, the drag never "starts" and the tap fires normally.
                // `.accessibilityAddTraits(.isButton)` replaces the trait `Button` used to give
                // for free — VoiceOver still announces this as tappable.
                titleBlock
                    .contentShape(Rectangle())
                    .onTapGesture(perform: handleOrTitleTapped)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Fecha: \(coordinate.accessibleTitle)\(isTodayCoordinate ? String(localized: "period_date_a11y_current_suffix", defaultValue: ", current period") : "")")
                    .accessibilityHint(String(localized: "period_date_a11y_hint", defaultValue: "Tap to jump to another period"))
            }

            Spacer()

            if showsChevronButtons {
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
                // Slides in from off-screen right, only in the final portion of the Home→Quincena
                // drag — see `chevronsRevealProgress` doc comment.
                .offset(x: (1 - chevronsRevealProgress) * 80)
                .opacity(chevronsRevealProgress)
            }
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
        // "Cuando le de clic ahi, quiero que salga una ventana con todo el desglose" (2026-09-21):
        // same aggregation pattern as Credit Cards/Investments — Essentials (`origin ==
        // .essential`) and the combined Payments/Servicios line (`origin == .subscription`,
        // disambiguated by `isHomeService`) each collapse into their own navigation row instead
        // of rendering as a single editable `LineItemRow`.
        let essentialLines = kind == .expense ? lines.filter { $0.origin == .essential } : []
        let paymentsLines = kind == .expense ? lines.filter { $0.origin == .subscription && !$0.isHomeService } : []
        let serviciosLines = kind == .expense ? lines.filter { $0.origin == .subscription && $0.isHomeService } : []
        let regularLines = kind == .expense ? lines.filter { $0.origin != .creditCard && $0.origin != .investment && $0.origin != .essential && $0.origin != .subscription } : lines
        // Bug fix (2026-09-21, user report — deactivating "Tech"/"Fun" correctly dropped the
        // breakdown sheet's own Total to $400, but this row kept showing $500): unlike
        // `CarryOverEngine.total`/`CreditCardPaymentsSheet`/`SubscriptionBreakdownSheet`, these
        // five totals summed EVERY line regardless of `isActive` — the one aggregate total in
        // the app that didn't exclude deactivated lines from its sum.
        //
        // Bug fix (2026-09-21, user report — "Alpaca" $100 USD + "Novotech" MX$7,950 summed to
        // $8,050 instead of ~$565.67): a line can be in MXN (its own currency, shown as-is on
        // its own row) — these totals are presented in plain USD, so each line must convert
        // through `CurrencyConversion.toUSD` first instead of raw-summing `.amount`.
        func usdTotal(_ lines: [LineItem]) -> Decimal {
            lines.filter(\.isActive).reduce(Decimal(0)) { partial, line in
                partial + CurrencyConversion.toUSD(amount: line.amount, currency: line.currency, rate: effectiveRate)
            }
        }
        let creditCardTotal = usdTotal(creditCardLines)
        let investmentTotal = usdTotal(investmentLines)
        let essentialTotal = usdTotal(essentialLines)
        let paymentsTotal = usdTotal(paymentsLines)
        let serviciosTotal = usdTotal(serviciosLines)

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
                    // Coordinator (2026-09-21, user's explicit request): bumped from 14px to
                    // 18px — supersedes the earlier /update-ui pass on node 12:7 (that one
                    // matched Figma exactly at 14px; the user asked for it larger regardless).
                    .font(.system(size: 18, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color("TextSecondary"))
                    .accessibilityHidden(true)

                Spacer()

                Button {
                    captureTarget = CaptureTarget(line: nil, kind: kind)
                } label: {
                    // Coordinator (2026-09-21, user's Figma review): the "+" now matches
                    // `header`'s chevron buttons exactly — Figma represents both as a static
                    // `plus.circle.fill`/`chevron.*.circle.fill` proxy since it can't render
                    // live Liquid Glass, but the real button is plain `plus` sized to a 29×29
                    // frame with `.buttonStyle(.glass)` painting the circle, same as the
                    // chevrons — no manual circle/tint here either.
                    Image(systemName: "plus")
                        .frame(width: 29, height: 29)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(kind == .income ? String(localized: "period_add_income_a11y", defaultValue: "Add income") : String(localized: "period_add_expense_a11y", defaultValue: "Add expense"))
            }
            #if DEBUG
            .debugOutline("card:titleRow", color: .gray, enabled: debugState.outlinesEnabled)
            #endif

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

                // "Essencial, Suscriptions, Services. en ese orden" (2026-09-21) — same relative
                // order as `PeriodCoordinator.reorderAggregateSubscriptionLines`. Coordinator
                // (2026-09-21, per-item refactor — user's request that editing/deleting "Food"
                // only ever touches this one quincena): each `Subscription` now generates its
                // OWN real `LineItem`, so a group can hold several lines with independently
                // different `isPaid` states — back to the same collapsed-navigation-row pattern
                // as Credit Cards/Investments (no single `isPaid` to show on the row itself; that
                // state lives per-item inside the breakdown sheet).
                if !essentialLines.isEmpty {
                    aggregateRow(
                        title: String(localized: "period_essentials_row_title", defaultValue: "Essentials"),
                        total: essentialTotal,
                        a11yHint: String(localized: "period_essentials_row_a11y_hint", defaultValue: "Double-tap to see the breakdown"),
                        action: { isPresentingEssentialsSheet = true }
                    )
                }

                if !paymentsLines.isEmpty {
                    aggregateRow(
                        title: String(localized: "period_payments_row_title", defaultValue: "Payments"),
                        total: paymentsTotal,
                        a11yHint: String(localized: "period_payments_row_a11y_hint", defaultValue: "Double-tap to see the breakdown"),
                        action: { isPresentingPaymentsSheet = true }
                    )
                }

                if !serviciosLines.isEmpty {
                    aggregateRow(
                        title: String(localized: "period_servicios_row_title", defaultValue: "Servicios"),
                        total: serviciosTotal,
                        a11yHint: String(localized: "period_servicios_row_a11y_hint", defaultValue: "Double-tap to see the breakdown"),
                        action: { isPresentingServiciosSheet = true }
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
                                // Coordinator (2026-09-21, /update-ui): matches the regular
                                // `LineItemRow` text weight — Figma's row text is Regular, not
                                // Semibold.
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        // Coordinator (2026-09-21, /update-ui): same fix as `LineItemRow` — was
                        // `AppBackgroundSecondary` (#000000, indistinguishable from the card
                        // behind it), Figma's row background is `AppBackgroundTertiary` (#3C3C3C).
                        .background(Color("AppBackgroundTertiary"))
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
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        .background(Color("AppBackgroundTertiary"))
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
            #if DEBUG
            .debugOutline("card:rows", color: .red.opacity(0.5), enabled: debugState.outlinesEnabled, padding: "spacing:8")
            #endif

            HStack {
                // Coordinator (2026-09-21, /update-ui): 14px Bold per Figma's "total" node, not
                // `.caption` (12pt).
                Text(kind == .income ? String(localized: "period_total_income", defaultValue: "TOTAL INCOME") : String(localized: "period_total_expenses", defaultValue: "TOTAL EXPENSES"))
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(total(for: kind).currencyString())
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
            }
            #if DEBUG
            .debugOutline("card:total", color: .blue.opacity(0.5), enabled: debugState.outlinesEnabled)
            #endif
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
        #if DEBUG
        .debugOutline("card:\(title)", color: .cyan, enabled: debugState.outlinesEnabled, padding: "16")
        #endif
    }

    /// Shared style for a collapsed aggregate row (Essentials/Payments/Servicios) — same visual
    /// pattern as the Credit Cards Payments/Investments rows above.
    @ViewBuilder
    private func aggregateRow(title: String, total: Decimal, a11yHint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(total.currencyString())
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding(16)
            .background(Color("AppBackgroundTertiary"))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(total.currencyString())")
        .accessibilityHint(a11yHint)
    }

    // Coordinator (2026-09-15, Figma tSUzh4zfCpDPYT5A88otst node 8:2): the "Tipo de cambio"
    // row + "Editar" button are removed from the Quincena's Resumen entirely — the manual
    // override stays reachable from Ajustes → Preferencias → Tipo de cambio
    // (`ExchangeRateSettingsView`), which already has it. The per-quincena-only override this
    // sheet used to write (`period.manualExchangeRateOverride`) has no UI trigger left as a
    // result — accepted by the coordinator's instruction, not an oversight.
    private var summaryPanel: some View {
        // `mandarOpacity: revealProgress` (2026-09-20): "Mandar" doesn't appear at all in the
        // compact preview state — user's explicit decision, see `SummaryPanel.mandarOpacity`'s
        // doc comment. `NextMonthCard` inside `SummaryPanel` is unaffected.
        SummaryPanel(mandar: mandar, nextMonth: nextMonth, mandarOpacity: revealProgress, showNextMonth: showNextMonth)
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

    /// Feeds `quickBalanceBlock` — same `total(for:)` the detailed cards' own "TOTAL
    /// INCOME"/"TOTAL EXPENSES" rows already use, so the compact and detailed representations
    /// never disagree.
    private var income: Decimal { total(for: .income) }
    private var expense: Decimal { total(for: .expense) }

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

// MARK: - Height PreferenceKeys

/// Publishes `quickBalanceBlock`'s own natural (unconstrained) height — see `quickBalanceLayer`'s
/// doc comment for how this drives its collapse-to-zero animation as `revealProgress` rises. Same
/// `max`-reducing pattern as `HomeView.HeaderHeightKey`.
private struct QuickBalanceHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Same as `QuickBalanceHeightKey`, for `detailedCardsLayer`'s content (`blocks`).
private struct DetailedCardsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
