import SwiftUI
import SwiftData

/// macOS sidebar — 7 flat items (no hub; the tab-bar limit that forces a hub on iPhone
/// doesn't exist on Mac, DESIGN_LIQUID.md). Ajustes is NOT a sidebar destination on Mac —
/// it lives in the native `Settings` scene (⌘,), per "Ajustes generales › macOS" in
/// DESIGN_LIQUID.md, standard macOS convention for app preferences.
enum FintrolSection: String, CaseIterable, Identifiable {
    case home
    case period
    case recurringIncome
    case recurringExpense
    case services
    case subscriptions
    case loans
    case creditCards
    case investments
    case overview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .period: "Quincena"
        case .recurringIncome: "Ingresos recurrentes"
        case .recurringExpense: "Gastos recurrentes"
        case .services: "Servicios"
        case .subscriptions: "Suscripciones"
        case .loans: "Préstamos"
        case .creditCards: "Credit Cards"
        case .investments: "Inversiones"
        case .overview: "Overview"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .period: "calendar"
        case .recurringIncome: "arrow.down.circle"
        case .recurringExpense: "arrow.up.circle"
        // Plan (glimmering-swinging-bumblebee.md §3): reassigned from `house.fill` to free
        // that icon for `.home` — both appear in this SAME flat Mac sidebar list, unlike the
        // iPhone hub row equivalent (a different screen, no real collision there).
        case .services: "bolt.fill"
        case .subscriptions: "repeat"
        case .loans: "banknote"
        case .creditCards: "creditcard.fill"
        case .investments: "chart.line.uptrend.xyaxis"
        case .overview: "chart.bar.fill"
        }
    }
}

/// iPhone tab bar — 3 tabs, icon-only (decisión del usuario). Coordinator (2026-09-21): the
/// "Recurrentes y pagos" hub tab (`RecurringHubView`, deleted) was pulled from the dock — its
/// rows now live inside Ajustes (`SettingsView`'s "Recurrentes"/"Credit Cards" sections),
/// reachable from `HomeView`'s gear button.
enum FintrolTab: String, CaseIterable, Identifiable {
    case home
    case period
    case overview

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .home: "Home"
        case .period: "Quincena"
        case .overview: "Overview"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .period: "calendar"
        // Coordinator (2026-09-16): tab 3 (Overview) icon change, "menucard" SF Symbol.
        case .overview: "menucard"
        }
    }
}

struct RootView: View {
    @Environment(BiometricLockStore.self) private var lockStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @State private var hasPurgedOrphanLines = false
    @State private var hasReprojectedLoanKindFix = false
    @State private var hasSeededSubscriptionCategories = false

    #if DEBUG
    /// Owns the single `HomeDragDebugState` instance for the whole app lifetime — injected into
    /// the environment below so `HomeView` (however deep it's mounted, iOS tab or Mac sidebar
    /// item) can find and update it, and read directly here to render `GestureDebugHUD` as a
    /// fixed overlay on TOP of `MacRootView`/`iOSRootView`. User ask (2026-09-18): the HUD used
    /// to live inside `HomeView` itself and vanished the moment the drag transition landed on
    /// the real Quincena tab — moving both the state and the HUD's render site up to this
    /// shared root is what keeps it on screen across every tab/section, showing the last values
    /// `HomeView` wrote instead of disappearing.
    @State private var homeDragDebugState = HomeDragDebugState()
    /// Coordinator (2026-09-21, user's request — the HUD kept covering real content it was
    /// meant to help debug): Ajustes → Developer Tools → "HUD Panel" toggle. `false` by
    /// default, so a fresh DEBUG build stays clean until the user explicitly turns it on —
    /// same `@AppStorage` key that toggle reads/writes, so they can never disagree.
    @AppStorage("fintrol.debugHUDVisible") private var isDebugHUDVisible = false
    #endif

    var body: some View {
        ZStack {
            if lockStore.shouldPresentLockScreen {
                LockView(store: lockStore)
                    .transition(.opacity)
            } else {
                #if os(macOS)
                MacRootView()
                #else
                iOSRootView()
                #endif
            }

            // C-06 (SECURITY.md, recommended): the App Switcher/Mission Control snapshot must
            // never show real amounts, regardless of whether the biometric lock is enabled —
            // this covers the default (lock off) case that LockView alone doesn't reach.
            if scenePhase != .active {
                PrivacySnapshotOverlay()
                    .transition(.opacity)
            }

            #if DEBUG
            // Fixed overlay above EVERYTHING — every tab (iOS) / sidebar section (Mac),
            // including the lock screen and the privacy snapshot — so it never disappears when
            // navigating away from Home. Coordinator (2026-09-21): reverted a same-day change
            // that put `.allowsHitTesting(false)` on this outer frame and `.allowsHitTesting
            // (true)` back on the HUD's own content (`GestureDebugHUD.hud(now:)`) — that split
            // does NOT work the way its own comment assumed: `allowsHitTesting(false)` on an
            // ancestor disables hit-testing for the WHOLE subtree in SwiftUI, and a descendant
            // re-enabling it on itself cannot override that. Confirmed empirically: with the
            // split in place, none of the HUD's own buttons/drag gesture ever received a touch —
            // the earlier investigation that motivated the split had actually misdiagnosed a tab-
            // bar tap failure that was really just wrong tap coordinates in testing, not this
            // frame. Back to no explicit `.allowsHitTesting` here at all — SwiftUI already skips
            // hit-testing the empty (background-less) parts of this expanded, `.topTrailing`-
            // aligned frame by default, which is what actually keeps the rest of the screen
            // untouched. Entire branch is `#if DEBUG` — doesn't exist as a symbol in a Release
            // build, and neither does `HomeDragDebugState`/`GestureDebugHUD` themselves (below).
            if isDebugHUDVisible {
                GestureDebugHUD(state: homeDragDebugState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            #endif
        }
        #if DEBUG
        .environment(homeDragDebugState)
        #endif
        .animation(.easeOut(duration: 0.25), value: lockStore.shouldPresentLockScreen)
        .animation(.easeOut(duration: 0.15), value: scenePhase)
        .onAppear {
            // Avie's fix: sweep once per cold start for LineItems whose generating
            // RecurringItem/Loan no longer exists — garbage accumulated before
            // `deleteRecurring`/`deleteLoan` existed (or any future bypass of them).
            guard !hasPurgedOrphanLines else { return }
            hasPurgedOrphanLines = true
            PeriodCoordinator.purgeOrphanLines(context: context, exchangeRate: rateStore.currentRate ?? 0)
        }
        .onAppear {
            // Coordinator (2026-09-17): one-time cold-start fix for the `reprojectLoan` bug
            // (existing materialized lines never had `kind` corrected when a loan's
            // `direction` was edited after creation — only NEW future lines picked it up).
            // The code fix alone only prevents new drift; this forces every already-persisted
            // loan through a fresh reproject once so any lines still stuck on the wrong
            // Income/Expense `kind` self-heal on next launch, without a dedicated data
            // migration. Cheap — loan counts are small, `reprojectLoan` is already idempotent
            // (skips manually-edited lines).
            guard !hasReprojectedLoanKindFix else { return }
            hasReprojectedLoanKindFix = true
            let allLoans = (try? context.fetch(FetchDescriptor<Loan>())) ?? []
            for loan in allLoans {
                PeriodCoordinator.reprojectLoan(item: loan, context: context, exchangeRate: rateStore.currentRate ?? 0)
            }
        }
        .onAppear {
            // Coordinator (2026-09-17): one-time seed for `SubscriptionCategoryItem` — user
            // feedback made subscription categories editable (Ajustes → "Categorías de
            // suscripciones"). Seeds the 7 original `SubscriptionCategory` cases (same
            // `rawValue`/icon) exactly once, so existing `Subscription.categoryRaw` data keeps
            // matching a real row in the new user-editable list from the very first launch
            // after this feature ships.
            guard !hasSeededSubscriptionCategories else { return }
            hasSeededSubscriptionCategories = true
            let existingCount = (try? context.fetchCount(FetchDescriptor<SubscriptionCategoryItem>())) ?? 0
            guard existingCount == 0 else { return }
            for (index, category) in SubscriptionCategory.allCases.enumerated() {
                context.insert(SubscriptionCategoryItem(name: category.rawValue, iconName: category.seedIconName, sortOrder: index))
            }
            try? context.save()
        }
    }
}

private struct PrivacySnapshotOverlay: View {
    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
    }
}

#if os(iOS)
private struct iOSRootView: View {
    @State private var selection: FintrolTab = .home
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TabView(selection: $selection) {
            ForEach(FintrolTab.allCases) { tab in
                NavigationStack {
                    destination(for: tab)
                }
                .tabItem {
                    // Decisión de producto: tab bar de iPhone solo con iconos, sin texto.
                    // El accessibilityLabel se conserva para VoiceOver (A11Y_AUDIT.md).
                    Image(systemName: tab.systemImage)
                        .accessibilityLabel(tab.accessibilityLabel)
                }
                .tag(tab)
            }
        }
        // Coordinator (2026-09-17): light haptic on every tab switch — shared helper with
        // `LineItemRow.hapticImpact()` (`HapticFeedback`), same Reduce Motion gate.
        .onChange(of: selection) {
            HapticFeedback.lightImpact(reduceMotion: reduceMotion)
        }
    }

    @ViewBuilder
    private func destination(for tab: FintrolTab) -> some View {
        switch tab {
        case .home: HomeView(selectedTab: $selection)
        case .period: PeriodView()
        case .overview: OverviewView()
        }
    }
}
#endif

#if os(macOS)
private struct MacRootView: View {
    @State private var selection: FintrolSection? = .home

    var body: some View {
        NavigationSplitView {
            List(FintrolSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Fintrol")
            .frame(minWidth: 220)
        } detail: {
            destination(for: selection ?? .home)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private func destination(for section: FintrolSection) -> some View {
        switch section {
        case .home: HomeView(selectedSection: $selection)
        case .period: PeriodView()
        case .recurringIncome: RecurringListView(kind: .income)
        case .recurringExpense: RecurringListView(kind: .expense)
        case .services: ServicesView()
        case .subscriptions: SubscriptionsView()
        case .loans: LoansView()
        case .creditCards: CreditCardsView()
        case .investments: InvestmentsView()
        case .overview: OverviewView()
        }
    }
}
#endif

// MARK: - HomeDragDebugState / GestureDebugHUD

#if DEBUG
/// Debug-only shared state for `HomeView`'s Home→Quincena drag transition — added 2026-09-18 at
/// the user's request to diagnose an intermittent flash of opacity toward the Welcome Card right
/// after a drag commits, before Quincena appears; moved out of `HomeView` the same day so the
/// HUD reading it (`GestureDebugHUD`, below) survives navigating away from Home. `HomeView` is
/// the only writer (mirrors its own `@State` into this object at every mutation site); `RootView`
/// owns the single instance, injects it via `.environment`, and is the only reader. `@Observable`
/// so `GestureDebugHUD` re-renders live while `HomeView` — mounted anywhere else in the tree —
/// keeps writing to it, and keeps showing the last values written once `HomeView` stops (e.g.
/// after the tab switch lands on Quincena) instead of resetting or disappearing. Entire type is
/// behind `#if DEBUG`, so it isn't compiled at all — not even as dead code — in a Release build.
@Observable
final class HomeDragDebugState {
    var dragTranslation: CGFloat = 0
    var availableHeight: CGFloat = 1
    var isSettling = false
    var didCommit = false
    var hasPrewarmedPeriodPage = false
    /// Mirrors `HomeView.isHomeContentVisible` — bug fix 2026-09-18 (5-frame HUD capture): the
    /// unmount used to be gated on `didCommit` alone, which raced the `TabView`/
    /// `NavigationSplitView`'s own tab-switch animation and could expose the bare Welcome Card
    /// for a frame or more. See `HomeView.isHomeContentVisible`'s doc comment.
    var isHomeContentVisible = true
    var gestureStartedAt: Date?
    var commitCalledAt: Date?
    var settleCompletedAt: Date?
    var navigateCalledAt: Date?

    /// Debug-only kill switch for `HomeView.settleAnimation` — added 2026-09-19 at the user's
    /// request to isolate a suspected "desfase" (mismatch) between the elements that ride the
    /// settle `withAnimation` transaction (title lerp, content inset, opacity fades, all driven
    /// off `dragTranslation`) during `commitPush()`/`cancelPush()`'s 0.2s easeOut. Toggled from
    /// `GestureDebugHUD` below; when `true`, `HomeView.settleAnimation` returns `nil` (same as
    /// `reduceMotion` already does) so the settle snaps instantly and the raw, un-eased value
    /// curves can be inspected before layering timing/curves back on top. Defaults to `false` so
    /// normal easing plays unless explicitly toggled.
    var easingDisabled = true

    /// Debug-only kill switch that draws a colored border + label around each of the major
    /// stacked layers/containers involved in the Home→Quincena drag transition (see
    /// `View.debugOutline(_:color:enabled:)`) — added 2026-09-19 alongside `easingDisabled` so
    /// the user can visually inspect each layer's actual on-screen bounds while debugging a
    /// padding-interpolation timing mismatch between `HomeView`'s floating title overlay and
    /// `PeriodView`'s content, instead of guessing from screenshots. Toggled from
    /// `GestureDebugHUD` below. Defaults to `false` so outlines stay hidden unless explicitly
    /// turned on.
    var outlinesEnabled = false

    /// Debug-only slow-motion multiplier for `HomeView`'s settle animation — added 2026-09-19
    /// alongside `easingDisabled`/`outlinesEnabled` so the drag-to-transition's settle phase
    /// (title tracking, chevron slide-in, padding interpolation) can be watched frame-by-frame
    /// instead of over the snappy default 0.2s. Cycled through presets from `GestureDebugHUD`
    /// below; `HomeView.effectiveSettleDuration` multiplies its base duration by this value in
    /// Debug builds. Named so the direction is unambiguous: this MULTIPLIES the duration (i.e.
    /// DIVIDES the speed) — `1.0` is normal speed, `15.0` is 15x slower, never the reverse.
    /// Interacts with `easingDisabled`: while that's `true`, `settleAnimation` already returns
    /// `nil` (instant), so this multiplier has no visible effect regardless of its value — the
    /// two aren't mutually exclusive, just non-additive in that combination. Defaults to `1.0`
    /// so normal speed plays unless explicitly slowed down.
    var settleSpeedMultiplier: Double = 1.0

    /// Whether `GestureDebugHUD` is showing its larger, easier-to-tap layout — added 2026-09-19
    /// at the user's request after the compact HUD's toggle rows proved fiddly to hit precisely.
    /// Toggled by `GestureDebugHUD.expandToggleRow`, a dedicated chevron control kept separate
    /// from `easingToggleRow`/`outlinesToggleRow`/`speedCycleRow` so expanding/collapsing the
    /// panel never fights with those rows' own tap targets. Defaults to `false` so the HUD keeps
    /// its familiar compact footprint unless explicitly expanded.
    var isExpanded = false

    /// The HUD's committed drag offset from its default top-trailing corner — added 2026-09-21 at
    /// the user's request after the panel kept covering content it was meant to help debug (the
    /// Overview year picker, Home's new settings gear). Lives here rather than as local `@State`
    /// inside `GestureDebugHUD` so the position survives that view being torn down and rebuilt
    /// (e.g. by the `TimelineView` above it, or a tab switch) instead of snapping back to the
    /// corner. `GestureDebugHUD` adds its own live in-flight drag delta on top of this while
    /// dragging, then folds it in here once the finger lifts.
    var hudOffset: CGSize = .zero

    /// Mirrors `HomeView.dragProgress` — recomputed here instead of also being mirrored, since
    /// it's a pure function of two values already mirrored above.
    var dragProgress: CGFloat {
        guard availableHeight > 0 else { return 0 }
        return min(max(-dragTranslation / availableHeight, 0), 1)
    }

    /// Mirrors `HomeView.isPeriodPageMounted`'s formula — same reasoning as `dragProgress`.
    var isPeriodPageMounted: Bool {
        (dragTranslation < 0 || isSettling || hasPrewarmedPeriodPage) && (!didCommit || isHomeContentVisible)
    }
}

/// Purely diagnostic: the user reads live numbers off this HUD ("el glitch pasa en el frame X /
/// a los Y ms") instead of screenshots, and Woz correlates that against the code. Rendered by
/// `RootView` as a fixed top-level overlay (see `RootView.body`) — no longer by `HomeView` — so
/// it stays on screen across every tab/section instead of disappearing when the drag transition
/// it's diagnosing actually lands on the real Quincena tab.
///
/// FPS was deliberately left out: a trustworthy per-frame counter needs `CADisplayLink`
/// (iOS-only — this app also builds for macOS, which would need a separate `CVDisplayLink` path)
/// wired into the actual render loop, not just a `TimelineView` tick, and the risk of that extra
/// machinery perturbing the very gesture performance being diagnosed outweighed the value here —
/// the stopwatches plus the state flags below already pinpoint the timing precisely enough to
/// correlate against a frame-numbered screen recording.
private struct GestureDebugHUD: View {
    let state: HomeDragDebugState

    /// Live in-flight drag delta, on top of `state.hudOffset` — see that property's doc comment.
    /// Plain `@State`, not `@GestureState`: `hud(now:)` is rebuilt 20x/second by the
    /// `TimelineView` above, and `@GestureState` proved unreliable across that rebuild rate in
    /// testing (drags were never recognized) — `@State` isn't tied to gesture-recognizer
    /// lifecycle the same way, so it survives.
    @State private var liveDragTranslation: CGSize = .zero

    var body: some View {
        // `.periodic` ticks on a fixed wall-clock schedule (20 Hz) independent of any of
        // `HomeDragDebugState`'s own changes — this is what keeps the stopwatches below visibly
        // advancing even while the finger holds still mid-drag, which relying on the state
        // object's own change events alone would not do.
        TimelineView(.periodic(from: .now, by: 0.05)) { timeline in
            hud(now: timeline.date)
        }
    }

    private func hud(now: Date) -> some View {
        VStack(alignment: .trailing, spacing: rowSpacing) {
            expandToggleRow
            easingToggleRow
            outlinesToggleRow
            speedCycleRow
            row("drag", String(format: "%.1f", state.dragTranslation))
            row("progress", String(format: "%.2f", state.dragProgress))
            row("avail h", String(format: "%.1f", state.availableHeight))
            row("settling", state.isSettling ? "true" : "false")
            row("committed", state.didCommit ? "true" : "false")
            row("periodMounted", state.isPeriodPageMounted ? "true" : "false")
            row("prewarmed", state.hasPrewarmedPeriodPage ? "true" : "false")
            row("visible", state.isHomeContentVisible ? "true" : "false")
            row("gesture", elapsedText(from: state.gestureStartedAt, to: now))
            row("settle", deltaText(from: state.commitCalledAt, to: state.settleCompletedAt))
            row("since commit", elapsedText(from: state.commitCalledAt, to: state.navigateCalledAt ?? now))
        }
        .font(rowFont)
        .foregroundStyle(.white)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.top, 8)
        .padding(.trailing, 8)
        // Without this, only the actual row `Text`/`Button` glyphs are hit-testable — the
        // panel's own padding and inter-row gaps (most of its visible rounded-rect background)
        // fall through to whatever sits underneath (e.g. `HomeView`'s settings gear button, which
        // visually overlaps this panel). Needed both so the panel reads as one solid draggable
        // surface and so the drag gesture below can start from anywhere inside it, not just
        // exactly on a row's text.
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .offset(
            x: state.hudOffset.width + liveDragTranslation.width,
            y: state.hudOffset.height + liveDragTranslation.height
        )
        // Draggable — see `HomeDragDebugState.hudOffset`'s doc comment. `minimumDistance: 4`
        // (above the default 10) so it still starts moving readily, while staying comfortably
        // above the near-zero movement of an actual tap on `easingToggleRow`/etc., so dragging
        // and tapping those rows keep working side by side.
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    liveDragTranslation = value.translation
                }
                .onEnded { value in
                    state.hudOffset.width += value.translation.width
                    state.hudOffset.height += value.translation.height
                    liveDragTranslation = .zero
                }
        )
    }

    /// Drives the compact/expanded row font — see `HomeDragDebugState.isExpanded`'s doc comment.
    /// Compact value (`size: 10, weight: .medium`) matches the HUD's original, unchanged
    /// appearance exactly; expanded scales up ~1.5x and bumps the weight for legibility at the
    /// larger size.
    private var rowFont: Font {
        state.isExpanded
            ? .system(size: 15, weight: .semibold, design: .monospaced)
            : .system(size: 10, weight: .medium, design: .monospaced)
    }

    /// Drives inter-row spacing alongside `rowFont` — expanded value gives each row, especially
    /// the three tappable toggle rows, a much bigger vertical tap target.
    private var rowSpacing: CGFloat {
        state.isExpanded ? 10 : 2
    }

    private var horizontalPadding: CGFloat {
        state.isExpanded ? 14 : 8
    }

    private var verticalPadding: CGFloat {
        state.isExpanded ? 12 : 6
    }

    /// Dedicated expand/collapse control, kept separate from `easingToggleRow`/
    /// `outlinesToggleRow`/`speedCycleRow` so tapping to resize the panel never intercepts or
    /// gets intercepted by those rows' own `Button` taps — each row (including this one) is its
    /// own `Button` with its own hit target, so SwiftUI routes a tap to whichever one it actually
    /// landed on and nothing else fires. Chevron glyph doubles as the row's own compact label.
    private var expandToggleRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                state.isExpanded.toggle()
            }
        } label: {
            row("hud", state.isExpanded ? "▾ collapse" : "▸ expand")
        }
        .buttonStyle(.plain)
    }

    /// Tappable row that flips `state.easingDisabled` — see that property's doc comment. Kept as
    /// a plain `Button` with the same terse monospace styling as the other rows (rather than a
    /// full `Toggle`) to fit the HUD's compact footprint. Needs the HUD's own `.allowsHitTesting`
    /// re-enabled (see `RootView.body`) since the overlay is otherwise purely visual/passthrough.
    private var easingToggleRow: some View {
        Button {
            state.easingDisabled.toggle()
        } label: {
            row("easing", state.easingDisabled ? "OFF" : "ON")
        }
        .buttonStyle(.plain)
    }

    /// Tappable row that flips `state.outlinesEnabled` — see that property's doc comment. Same
    /// plain-`Button` pattern as `easingToggleRow`.
    private var outlinesToggleRow: some View {
        Button {
            state.outlinesEnabled.toggle()
        } label: {
            row("outlines", state.outlinesEnabled ? "ON" : "OFF")
        }
        .buttonStyle(.plain)
    }

    /// Presets `state.settleSpeedMultiplier` cycles through on each tap, wrapping back to `1.0`
    /// after the last one. Values are the duration multiplier (bigger = slower), matching
    /// `settleSpeedMultiplier`'s doc comment.
    private static let speedPresets: [Double] = [1.0, 3.0, 8.0, 15.0]

    /// Tappable row that cycles `state.settleSpeedMultiplier` through `speedPresets` — same
    /// plain-`Button` pattern as `easingToggleRow`/`outlinesToggleRow`. Label always spells out
    /// the direction ("Nx slower") rather than a bare multiplier so it can't be misread as
    /// speeding the animation up.
    private var speedCycleRow: some View {
        Button {
            let presets = Self.speedPresets
            let currentIndex = presets.firstIndex(of: state.settleSpeedMultiplier) ?? 0
            let nextIndex = (currentIndex + 1) % presets.count
            state.settleSpeedMultiplier = presets[nextIndex]
        } label: {
            row("speed", speedLabel(for: state.settleSpeedMultiplier))
        }
        .buttonStyle(.plain)
    }

    private func speedLabel(for multiplier: Double) -> String {
        multiplier <= 1.0 ? "1x" : "\(Int(multiplier))x slower"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.white.opacity(0.6))
            Text(value)
        }
    }

    private func elapsedText(from start: Date?, to end: Date) -> String {
        guard let start else { return "—" }
        return "\(Int(end.timeIntervalSince(start) * 1000))ms"
    }

    private func deltaText(from start: Date?, to end: Date?) -> String {
        guard let start, let end else { return "—" }
        return "\(Int(end.timeIntervalSince(start) * 1000))ms"
    }
}
#endif
