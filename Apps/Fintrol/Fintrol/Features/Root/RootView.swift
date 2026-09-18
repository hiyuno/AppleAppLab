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

/// iPhone tab bar — 5 tabs, icon-only (decisión del usuario). "Recurrentes y pagos" is a
/// hub covering the 4 entries that live as flat sidebar items on Mac.
enum FintrolTab: String, CaseIterable, Identifiable {
    case home
    case period
    case recurringHub
    case overview
    case settings

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .home: "Home"
        case .period: "Quincena"
        case .recurringHub: "Recurrentes y pagos"
        case .overview: "Overview"
        case .settings: "Ajustes"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .period: "calendar"
        case .recurringHub: "arrow.triangle.2.circlepath"
        // Coordinator (2026-09-16): tab 3 (Overview) icon change, "menucard" SF Symbol.
        case .overview: "menucard"
        case .settings: "gearshape.fill"
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
            // navigating away from Home. `.allowsHitTesting(false)` (same as before the move)
            // keeps it purely visual: it never intercepts the drag gesture or any tap. Entire
            // branch is `#if DEBUG` — doesn't exist as a symbol in a Release build, and neither
            // does `HomeDragDebugState`/`GestureDebugHUD` themselves (see below).
            GestureDebugHUD(state: homeDragDebugState)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(false)
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
        case .recurringHub: RecurringHubView()
        case .overview: OverviewView()
        case .settings: SettingsView()
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
        VStack(alignment: .trailing, spacing: 2) {
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
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.top, 8)
        .padding(.trailing, 8)
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
