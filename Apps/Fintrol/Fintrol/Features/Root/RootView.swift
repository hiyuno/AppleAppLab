import SwiftUI

/// macOS sidebar — 7 flat items (no hub; the tab-bar limit that forces a hub on iPhone
/// doesn't exist on Mac, DESIGN_LIQUID.md). Ajustes is NOT a sidebar destination on Mac —
/// it lives in the native `Settings` scene (⌘,), per "Ajustes generales › macOS" in
/// DESIGN_LIQUID.md, standard macOS convention for app preferences.
enum FintrolSection: String, CaseIterable, Identifiable {
    case period
    case recurringIncome
    case recurringExpense
    case services
    case subscriptions
    case loans
    case investments
    case overview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .period: "Quincena"
        case .recurringIncome: "Ingresos recurrentes"
        case .recurringExpense: "Gastos recurrentes"
        case .services: "Servicios"
        case .subscriptions: "Suscripciones"
        case .loans: "Préstamos"
        case .investments: "Inversiones"
        case .overview: "Overview"
        }
    }

    var systemImage: String {
        switch self {
        case .period: "calendar"
        case .recurringIncome: "arrow.down.circle"
        case .recurringExpense: "arrow.up.circle"
        case .services: "house.fill"
        case .subscriptions: "repeat"
        case .loans: "banknote"
        case .investments: "chart.line.uptrend.xyaxis"
        case .overview: "chart.bar.fill"
        }
    }
}

/// iPhone tab bar — 4 tabs, icon-only (decisión del usuario). "Recurrentes y pagos" is a
/// hub covering the 4 entries that live as flat sidebar items on Mac.
enum FintrolTab: String, CaseIterable, Identifiable {
    case period
    case recurringHub
    case overview
    case settings

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .period: "Quincena"
        case .recurringHub: "Recurrentes y pagos"
        case .overview: "Overview"
        case .settings: "Ajustes"
        }
    }

    var systemImage: String {
        switch self {
        case .period: "calendar"
        case .recurringHub: "arrow.triangle.2.circlepath"
        case .overview: "chart.bar.fill"
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
        }
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
    @State private var selection: FintrolTab = .period

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
    }

    @ViewBuilder
    private func destination(for tab: FintrolTab) -> some View {
        switch tab {
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
    @State private var selection: FintrolSection? = .period

    var body: some View {
        NavigationSplitView {
            List(FintrolSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Fintrol")
            .frame(minWidth: 220)
        } detail: {
            destination(for: selection ?? .period)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private func destination(for section: FintrolSection) -> some View {
        switch section {
        case .period: PeriodView()
        case .recurringIncome: RecurringListView(kind: .income)
        case .recurringExpense: RecurringListView(kind: .expense)
        case .services: ServicesView()
        case .subscriptions: SubscriptionsView()
        case .loans: LoansView()
        case .investments: InvestmentsView()
        case .overview: OverviewView()
        }
    }
}
#endif
