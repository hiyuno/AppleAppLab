import SwiftUI
import SwiftData

/// First tab (iPhone) / first sidebar item (Mac) — DESIGN_LIQUID.md § Home. Answers "¿cómo
/// estoy hoy?" faster than the full Quincena: today's date, a dynamic motivational message
/// (`HomeInsightEngine`), and a read-only preview of the current quincena
/// (`PeriodPreviewCard`) that navigates to the Quincena tab/sidebar-item on tap — and, on
/// iPhone, on an upward drag past a threshold (plan `glimmering-swinging-bumblebee.md` §5).
struct HomeView: View {
    #if os(iOS)
    @Binding var selectedTab: FintrolTab
    #else
    @Binding var selectedSection: FintrolSection?
    #endif

    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    @Query(sort: \RecurringItem.title) private var recurringItems: [RecurringItem]
    @Query(sort: \Subscription.name) private var subscriptions: [Subscription]
    @Query(sort: \Loan.name) private var loans: [Loan]
    @Query(sort: \CreditCard.name) private var creditCards: [CreditCard]

    @State private var coordinate = PeriodDateEngine.coordinate(containing: CivilDate.today())
    @State private var period: Period?
    @State private var isLoading = true
    /// Computed once per `loadPeriod()`, not on every `body` evaluation — the drag gesture
    /// mutates `dragTranslation` every frame, which would otherwise re-run
    /// `PeriodCoordinator.homeInsightContext` (several SwiftData fetches) on every frame too.
    @State private var insightMessage: HomeInsightMessage = .fallback

    // Same pattern as `LineItemRow`'s swipe gesture — plain `@State`, not `@GestureState`.
    @State private var dragTranslation: CGFloat = 0
    /// Full container height (header + card/Quincena rect together) — measured on the outer
    /// container via `GeometryReader`. Only `PeriodPreviewCard` ever moves through this range
    /// (0 → `-availableHeight`), so it can travel far enough to fully exit above the screen,
    /// past even the fixed header.
    @State private var availableHeight: CGFloat = 1
    /// Measured height of the fixed white header (date + message) via `HeaderHeightKey` —
    /// both the real Quincena (`PeriodView`, static) and `PeriodPreviewCard` (draggable) are
    /// inset by this amount so they occupy exactly the same rectangle below the header, down
    /// to the bottom of the screen. The header itself never uses this value on itself.
    @State private var headerHeight: CGFloat = 0
    /// True for the duration of the post-release settle animation (commit OR cancel) — keeps
    /// `periodPage` mounted through that window so it doesn't pop away mid-slide. Cleared once
    /// the animation's own duration has elapsed (`settleAnimationDuration`).
    @State private var isSettling = false
    /// Set once a commit's settle animation has actually landed (offset == `-availableHeight`)
    /// and the real tab has already been flipped. Cleared, along with `dragTranslation`, the next
    /// time `HomeView` reappears — see `body`'s `.onAppear`. See `commitPush()` for why
    /// `dragTranslation` itself is deliberately NOT reset synchronously right after navigating.
    ///
    /// Bug fix 2026-09-18 (user-reported with a 5-frame HUD capture, `since commit` ~239ms): the
    /// ORIGINAL version of this fix (3-frame QuickTime capture) unmounted `staticPeriodLayer`/
    /// `cardLayer` the INSTANT `didCommit` flipped true, on the assumption that "`HomeView` itself
    /// is off-screen behind the now-frontmost Quincena tab" by that point — i.e. that setting
    /// `selectedTab`/`selectedSection` and the tab bar's own cut-over to the new tab are
    /// effectively synchronous. They are NOT: a `TabView`/`NavigationSplitView` selection change
    /// is itself an animated transition with its own frame(s) of latency, so there's a real
    /// window, AFTER `didCommit` flips true but BEFORE the real Quincena tab has actually painted
    /// over `HomeView`, during which `HomeView` (now sitting on the old, still-frontmost-for-a-
    /// beat tab) is what's rendered — and by then this property alone had already unmounted both
    /// moving layers, leaving only `headerLayer` (the Welcome Card) visible with nothing behind
    /// it. That's the fully-exposed Welcome Card the user captured. Fix: stop tying the unmount to
    /// `didCommit` directly — see `isHomeContentVisible`/`isPeriodPageMounted` below, which instead
    /// tie it to `HomeView` ACTUALLY disappearing (`.onDisappear`), the one signal that's
    /// guaranteed to fire only once nothing of `HomeView` is on screen any more, with no assumption
    /// about tab-switch timing.
    @State private var didCommit = false
    /// True whenever `HomeView`'s content is mounted and could conceivably be on screen; flipped
    /// false only in `.onDisappear` — the actual, non-racy signal that the `TabView`/
    /// `NavigationSplitView` has cut over away from `HomeView` and nothing here can be visible any
    /// more. See `didCommit`'s bug-fix note: unmounting `staticPeriodLayer`/`cardLayer` on
    /// `didCommit` alone raced the tab switch's own animation; gating on this flag too means the
    /// unmount can only ever happen once `HomeView` is provably off screen, closing that gap
    /// completely instead of narrowing it. Reset back to `true` in `.onAppear`, alongside
    /// `dragTranslation`/`didCommit`, the next time `HomeView` reappears.
    @State private var isHomeContentVisible = true
    /// Bug fix 2026-09-18 (user-reported: the Preview Card jumped ~100px upward "de golpe" the
    /// instant the drag started, THEN tracked the finger normally) — root cause confirmed with
    /// timestamped instrumentation around `PeriodView.body`: mounting the real `PeriodView()`
    /// for the very first time is not free (three `@Query` fetches + its own
    /// `GeometryReader`/`safeAreaInset` layout negotiation), and `isPeriodPageMounted` used to
    /// flip true for the first time on the EXACT SAME SwiftUI update transaction as the drag's
    /// first `onChanged` (`dragTranslation < 0` becomes true together with that first pixel of
    /// movement). Measured: that first mount forces 3–4 extra `PeriodView.body` evaluations
    /// (~12ms in Simulator on trivial fixture data; a real device with a real dataset can cost
    /// meaningfully more) landing on the very frame the card is supposed to start tracking the
    /// finger 1:1 — any dropped/delayed frame there reads as a sudden jump once the pending
    /// touch deltas catch up. Every subsequent `onChanged` after that first mount costs exactly
    /// one normal `body` evaluation (confirmed with the same instrumentation), so this is a
    /// one-time mount cost, not an ongoing per-frame one. Fix: pay it once, off the interactive
    /// gesture path, right after `HomeView`'s own load finishes — see the `.task` in `body` and
    /// `isPeriodPageMounted` below.
    @State private var hasPrewarmedPeriodPage = false

    #if DEBUG
    /// Shared debug state (`HomeDragDebugState`, `Features/Root/RootView.swift`) — the HUD
    /// itself now lives in `RootView` (as a fixed overlay above every tab/section, so it stays
    /// visible after navigating away from Home) instead of `HomeView`. `HomeView` still owns and
    /// UPDATES every value; `RootView`/`GestureDebugHUD` only READ it. Injected unconditionally
    /// from `RootView` (`#if DEBUG`), so `HomeView` — always mounted somewhere inside `RootView`'s
    /// tree, on both iOS and Mac — can rely on it always being present in the environment.
    @Environment(HomeDragDebugState.self) private var debugState
    #endif

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let commitProgressThreshold: CGFloat = 0.35
    private let velocityCommitThreshold: CGFloat = 0.5

    private var todayCoordinate: PeriodCoordinate { PeriodDateEngine.coordinate(containing: CivilDate.today()) }
    private var isTodayCoordinate: Bool { coordinate == todayCoordinate }
    private var effectiveRate: Decimal { period?.manualExchangeRateOverride ?? rateStore.currentRate ?? 0 }

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

    private var dragProgress: CGFloat {
        guard availableHeight > 0 else { return 0 }
        return min(max(-dragTranslation / availableHeight, 0), 1)
    }

    /// Reduce Motion: the drag-follow itself is direct manipulation (finger-tracked, not an
    /// automatic transition) so it stays 1:1 regardless — only the post-release SETTLE
    /// animation (commit snapping to the end, or cancel snapping back) collapses to instant
    /// with Reduce Motion on. Same end state either way, per plan §5/§6.
    private var settleAnimation: Animation? { reduceMotion ? nil : .easeOut(duration: settleAnimationDuration) }
    private let settleAnimationDuration: TimeInterval = 0.2

    /// Mount `periodPage` while it's actually needed — while the finger is dragging it into
    /// view, or during the settle animation right after release (commit lands on it, cancel
    /// slides it back out) — plus once `hasPrewarmedPeriodPage` flips true, shortly after Home's
    /// own load finishes (see bug fix note on that property). It never mounts purely because
    /// Home merely sits on screen with nothing loaded yet, but it IS intentionally mounted (off
    /// screen — the offset formula already parks it fully below the visible area at
    /// `dragTranslation == 0`) for the rest of a loaded Home visit, trading a small amount of
    /// live `@Query` overhead for a drag that never has to pay a first-mount cost mid-gesture.
    ///
    /// `&& (!didCommit || isHomeContentVisible)`: stays mounted through `didCommit` for as long as
    /// `HomeView` could still be on screen (`isHomeContentVisible`) — only actually unmounts once
    /// `.onDisappear` has fired. See `isHomeContentVisible`'s doc comment for the bug this closes.
    private var isPeriodPageMounted: Bool {
        (dragTranslation < 0 || isSettling || hasPrewarmedPeriodPage) && (!didCommit || isHomeContentVisible)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .task {
            await rateStore.refresh(context: context)
            loadPeriod()
            isLoading = false
            // See `hasPrewarmedPeriodPage`'s bug fix note. `Task.yield()` lets THIS update (the
            // `isLoading = false` switch to `content`) actually commit and render on its own
            // first, instead of bundling `PeriodView()`'s first-mount cost into that same
            // transaction — the whole point is to move that cost off any transaction the user is
            // actively watching, gesture or not.
            await Task.yield()
            hasPrewarmedPeriodPage = true
            #if DEBUG
            debugState.hasPrewarmedPeriodPage = true
            #endif
        }
        .onAppear {
            // Bug fix 2026-09-18 (user-reported, 3-frame QuickTime capture of the glitch): reset
            // the push-transition state HERE, on the NEXT appearance of `HomeView`, rather than
            // synchronously inside `commitPush()` right after navigating. Resetting it there was
            // the actual root cause — the reset raced the `TabView`'s own tab-switch rendering,
            // so on some frames `HomeView` (with `dragTranslation` already snapped back to `0`,
            // i.e. full rest — Welcome Card + Preview Card complete) was still what got painted,
            // producing a visible "everything jumps back to Home" flash before the real Quincena
            // tab cut over. Resetting here instead is invisible by construction: by the time the
            // user is looking at `HomeView` again, the transition is long over. See
            // `commitPush()`/`didCommit` for the other half of this fix.
            dragTranslation = 0
            didCommit = false
            // See `isHomeContentVisible`'s doc comment — `HomeView` being back on screen again is
            // exactly what this flag means, so it resets to `true` here alongside the rest of the
            // transition state.
            isHomeContentVisible = true
            #if DEBUG
            debugState.dragTranslation = 0
            debugState.didCommit = false
            debugState.isHomeContentVisible = true
            debugState.gestureStartedAt = nil
            debugState.commitCalledAt = nil
            debugState.settleCompletedAt = nil
            debugState.navigateCalledAt = nil
            #endif
            // Same reasoning as `PeriodView`'s `.onAppear`: editing a line elsewhere doesn't
            // refire `.task`, but tab reselection does refire `.onAppear` — cheap to reload.
            guard !isLoading else { return }
            loadPeriod()
        }
        .onDisappear {
            // The actual, non-racy signal that `HomeView` is off screen — see
            // `isHomeContentVisible`'s doc comment. This is what finally lets
            // `isPeriodPageMounted` unmount `staticPeriodLayer`/`cardLayer` after a commit,
            // instead of assuming the tab switch already completed the instant `didCommit` flips.
            isHomeContentVisible = false
            #if DEBUG
            debugState.isHomeContentVisible = false
            #endif
        }
    }

    // Four stacked layers, NOT one pushed unit (user-confirmed mechanic change): the header
    // never moves; the real `PeriodView()` occupies the same rectangle the card occupies (below
    // the header, down to the tab bar) but is jalada desde abajo in sync with the drag — its own
    // `.offset(y: availableHeight + dragTranslation)` starts fully off-screen below and lands
    // exactly in place as `cardLayer` finishes exiting above, as if the card were dragging it up
    // with it; `PeriodPreviewCard` is the only layer with `.offset(y: dragTranslation)`, drawn
    // topmost, sliding out past the top of the screen. `GeometryReader` measures the TOTAL space
    // Home gets from the `TabView`/`NavigationStack` above it — that's `availableHeight`, the
    // full distance both layers travel (card up-and-out, Quincena up-and-in).
    private var content: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // DESIGN_LIQUID.md § Home "Fondo del header — excepción blanca": fixed white
                // surface (no Dark variant on purpose) behind everything else in this ZStack —
                // header AND the card/Quincena rect below it — so `PeriodPreviewCard`'s rounded
                // top corners never cut away to reveal the screen's default dark background as
                // a black sliver. Extends under the top safe area too. Straight rectangle, no
                // corner rounding here — the 55pt squircle belongs to the card's own top
                // corners (confirmed with the user: "el roundness va ahí, no donde lo pusiste").
                Color("HomeHeaderBackground")
                    .ignoresSafeArea(edges: .top)

                headerLayer
                staticPeriodLayer
                cardLayer
            }
            .onPreferenceChange(HeaderHeightKey.self) { headerHeight = $0 }
            .onAppear {
                availableHeight = max(proxy.size.height, 1)
                #if DEBUG
                debugState.availableHeight = availableHeight
                #endif
            }
            .onChange(of: proxy.size.height) { _, newValue in
                availableHeight = max(newValue, 1)
                #if DEBUG
                debugState.availableHeight = availableHeight
                #endif
            }
        }
    }

    /// The real Quincena screen (user-confirmed: full `PeriodView()`, not a
    /// simplified/presentational stand-in) — jalada desde abajo en sincronía 1:1 con el mismo
    /// `dragTranslation` que saca a `cardLayer` por arriba, como si el card la arrastrara consigo
    /// (user-confirmed: "vamos subiendo el card de preview y abajo viene jalando a la pantalla de
    /// quincena" — ya NO está estática esperando a destaparse). Offset = `availableHeight +
    /// dragTranslation`: en reposo (`dragTranslation == 0`) da `availableHeight`, completamente
    /// fuera de pantalla por debajo; cuando el card ha salido del todo (`dragTranslation ==
    /// -availableHeight`) da `0`, exactamente en su lugar — mismo rango, dirección opuesta al
    /// offset del card.
    ///
    /// Hueco negro (bug fix 2026-09-18, user-reported con screenshot): este layer SÍ necesita el
    /// mismo `.padding(.top, headerHeight)` que `cardLayer` — antes no lo tenía, así que su
    /// rectángulo medía `availableHeight` completo mientras el de `cardLayer` medía
    /// `availableHeight - headerHeight` (más corto, por su propio inset). Como ambas capas
    /// comparten la misma fórmula de offset basada en `availableHeight`/`dragTranslation` pero
    /// recorrían distancias distintas, el card (más corto) terminaba de salir de pantalla ANTES
    /// de que esta capa (más larga) hubiera llegado a su posición final — dejando un hueco negro
    /// vacío entre ambas capas durante el tramo intermedio del drag. Con el mismo padding, ambos
    /// rectángulos miden exactamente lo mismo y recorren la misma distancia en sincronía.
    ///
    /// El padding va ANTES de `.frame`/`.background` (mismo orden que `cardLayer`: padding inset
    /// del contenido, luego `.frame` expande al tamaño completo, luego `.background` pinta TODO
    /// ese frame ya expandido — incluida el área del padding). Si el orden fuera
    /// `.frame`→`.background`→`.padding`, el padding agregaría espacio fuera del área ya pintada
    /// por `.background`, reintroduciendo la franja transparente/blanca que un fix anterior ya
    /// resolvió (ver `PROJECT_LEARNINGS.md`) — por eso el orden importa y no es intercambiable.
    ///
    /// Z-order (bug fix 2026-09-18, user-reported con screenshot): este layer se dibuja DESPUÉS de
    /// `headerLayer` en el `ZStack` (ver `content`) — es decir, por delante del Welcome Card, no
    /// detrás. Antes `headerLayer` estaba entre `staticPeriodLayer` y `cardLayer`, así que durante
    /// el drag había un instante en que NINGUNA de las dos capas móviles cubría al Welcome Card
    /// (una ya había salido, la otra no había llegado) y su fondo blanco se asomaba flotando en
    /// medio de la pantalla. Ahora `headerLayer` está al fondo del `ZStack` (antes de esta capa Y
    /// de `cardLayer`), así que en cualquier punto del drag, la que sea de las dos capas móviles
    /// que esté ocupando esa región en ese instante lo tapa por completo. Only
    /// mounted while `isPeriodPageMounted` — see that property for why. `PeriodView` has no
    /// `TabView`/tab bar of its own (that lives in `iOSRootView`, outside `HomeView` entirely),
    /// so placing it in here doesn't duplicate one.
    @ViewBuilder
    private var staticPeriodLayer: some View {
        if isPeriodPageMounted {
            PeriodView()
                .padding(.top, headerHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color("AppBackground"))
                .ignoresSafeArea(edges: .bottom)
                .offset(y: availableHeight + dragTranslation)
        }
    }

    /// Fixed header — date + dynamic message — NEVER offset, not even during the drag. Publishes
    /// its own rendered height via `HeaderHeightKey` so `staticPeriodLayer`/`cardLayer` below can
    /// inset by exactly that amount, regardless of Dynamic Type or message length.
    ///
    /// Bug fix (2026-09-18, user-reported with screenshot): near the end of the drag, this
    /// layer's dynamic message text rendered as a ghosted/double-exposed overlap with
    /// `staticPeriodLayer`'s incoming title (e.g. "September 2026") once `cardLayer` had
    /// scrolled far enough off-screen to reveal what's underneath. Root cause: this layer only
    /// had `Color.clear` as its own `.background` — it relied entirely on the ZStack's shared
    /// `Color("HomeHeaderBackground")`, which sits at the very BOTTOM of the ZStack, BELOW
    /// `staticPeriodLayer`, not between the two. So `headerLayer` had no actual opaque backing
    /// of its own: everywhere outside the glyphs themselves it was fully transparent, letting
    /// `staticPeriodLayer` show/blend straight through during the animated `.offset` frames
    /// (same `.compositingGroup()`-before-`.clipShape()` gotcha as `LineItemRow`'s card
    /// background — a transformed sibling layer isn't guaranteed to composite as a clean opaque
    /// stack unless each layer that must fully occlude is flattened with a real opaque
    /// background baked in). Fix: give this layer its own opaque
    /// `Color("HomeHeaderBackground")` fill sized to its own bounds, then flatten with
    /// `.compositingGroup()` so it always paints as one solid, fully-opaque texture over
    /// whatever `staticPeriodLayer` is doing underneath — the user's ask ("el texto de home se
    /// queda atrás, porque ahora se enfrenta") is satisfied by making the occlusion real instead
    /// of relying on z-order alone.
    private var headerLayer: some View {
        VStack(alignment: .leading, spacing: 32) {
            dateHeader

            messageText
                .font(.body.weight(.semibold))
                .lineSpacing(4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                // Base text color only — the accent-orange highlights already override this
                // explicitly inside `attributedText`/`highlighted`, per DESIGN_LIQUID.md § Home.
                .foregroundStyle(Color("HomeHeaderTextPrimary"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        // The bottom padding IS the 48pt header→card gap.
        .padding(.bottom, headerToCardSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Real opaque backing for THIS layer — not just the shared background at the
                // bottom of the outer ZStack (see doc comment above for why that alone isn't
                // enough during the drag animation).
                Color("HomeHeaderBackground")
                GeometryReader { geo in
                    Color.clear.preference(key: HeaderHeightKey.self, value: geo.size.height)
                }
            }
        )
        // Flattens content + opaque background into a single composited layer so it always
        // paints as one solid texture over `staticPeriodLayer`, instead of SwiftUI/Core Animation
        // potentially compositing them as separate semi-independent layers mid-animation.
        .compositingGroup()
    }

    /// The only layer with `.offset(y: dragTranslation)` — a literal lid over `staticPeriodLayer`,
    /// same rectangle, drawn on top. Range is `0` (resting, fully covering the real Quincena) to
    /// `-availableHeight` (fully off-screen past the top, per the user's confirmed mechanic — not
    /// just past the header, but the full container height, since the card starts already inset
    /// by `headerHeight`).
    @ViewBuilder
    private var cardLayer: some View {
        if let period {
            PeriodPreviewCard(
                coordinate: coordinate,
                isTodayCoordinate: isTodayCoordinate,
                income: income(for: period),
                expense: expense(for: period),
                sobrante: sobrante(for: period),
                nextMonth: nextMonth(for: period),
                onTap: navigateToPeriod
            )
            .compositingGroup()
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cardCornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: cardCornerRadius,
                    style: .continuous
                )
            )
            .padding(.top, headerHeight)
            // Full width, full remaining height down to the tab bar — same rectangle as
            // `staticPeriodLayer`.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The `NavigationStack`/`TabView` reserves its own bottom safe-area inset for the
            // floating (Liquid Glass) tab bar, so without this the card's background stopped
            // short of the physical bottom edge, leaving a plain black strip below it (visible
            // behind the translucent tab bar). Only `.bottom` is ignored — horizontal edges
            // already have zero safe-area inset in portrait, and ignoring `.top` would slide the
            // card under the navigation bar/status bar, which isn't wanted here.
            .ignoresSafeArea(edges: .bottom)
            .offset(y: dragTranslation)
            #if os(iOS)
            // `.highPriorityGesture`, not `.gesture` — `PeriodPreviewCard` is a `Button`, whose
            // own tap gesture otherwise wins the recognition race and the drag never even starts
            // (confirmed on-device: a plain `.gesture` here silently ate every drag). A short tap
            // (under `minimumDistance`) still falls through to the button's own action.
            .highPriorityGesture(dragGesture)
            #endif
        }
    }

    /// Top corners only (bottom stays square — the card runs edge-to-edge to the screen's
    /// physical bottom). 55pt matches the iPhone 17 Pro's screen curve (confirmed with the
    /// user).
    private var cardCornerRadius: CGFloat { 55 }

    /// DESIGN_LIQUID.md § Home "Densidad visual — ajustes puntuales" (revisión 2026-09-18):
    /// 32pt → 48pt, the gap between the dynamic message and `PeriodPreviewCard`.
    private let headerToCardSpacing: CGFloat = 48

    #if os(iOS)
    private func hapticImpact() {
        HapticFeedback.lightImpact(reduceMotion: reduceMotion)
    }

    /// Attached only to `PeriodPreviewCard`, not the whole screen — so it never fights the
    /// `ScrollView`'s own vertical drag outside the card (plan §5/verificación #1).
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard value.translation.height < 0 else { return }
                #if DEBUG
                if debugState.gestureStartedAt == nil { debugState.gestureStartedAt = Date() }
                #endif
                dragTranslation = value.translation.height
                #if DEBUG
                debugState.dragTranslation = dragTranslation
                #endif
            }
            .onEnded { value in
                defer {
                    #if DEBUG
                    debugState.gestureStartedAt = nil
                    #endif
                }
                let translation = value.translation.height
                guard translation < 0, availableHeight > 0 else {
                    cancelPush()
                    return
                }
                let predictedProgress = min(max(-value.predictedEndTranslation.height / availableHeight, 0), 1)
                let shouldCommit = dragProgress >= commitProgressThreshold || predictedProgress >= velocityCommitThreshold

                if shouldCommit {
                    commitPush()
                } else {
                    cancelPush()
                }
            }
    }

    /// Finishes the push all the way to the end (offset = `-availableHeight` exactly, Quincena
    /// fully on screen) INSIDE the settle animation, then — once that animation has actually
    /// finished, not before — flips the real tab. Doing the real `selectedTab` change only
    /// after the visual slide has already landed on the same full-screen `PeriodView` is what
    /// keeps the handoff to the real tab invisible: by the time `TabView` cuts over, both sides
    /// already show the identical resting frame.
    ///
    /// Bug fix (2026-09-18, user-reported with a 3-frame QuickTime capture): this used to reset
    /// `dragTranslation` back to `0` SYNCHRONOUSLY, right here, immediately after
    /// `navigateToPeriod()`. That reset is what actually caused the glitch — a `TabView` tab
    /// switch isn't guaranteed to land on the very next rendered frame, so there was a real
    /// window where `HomeView` was still what got painted with `dragTranslation` already back at
    /// `0` (full rest: Welcome Card + Preview Card complete), i.e. a visible flash of "everything
    /// jumps back to Home" right before the real Quincena tab cut over on top of it. Fix: leave
    /// `dragTranslation` frozen at `-availableHeight` (the landed, fully-pushed position) and
    /// instead mark `didCommit = true`, which unmounts `staticPeriodLayer`/`cardLayer` right away
    /// (safe — `HomeView` is already off-screen behind the now-frontmost Quincena tab, so nothing
    /// visible changes) without ever touching `dragTranslation` while `HomeView` could still be
    /// on screen. `dragTranslation` itself only gets reset later, invisibly, the next time
    /// `HomeView` reappears — see `body`'s `.onAppear`.
    private func commitPush() {
        hapticImpact()
        #if DEBUG
        debugState.commitCalledAt = Date()
        debugState.settleCompletedAt = nil
        debugState.navigateCalledAt = nil
        #endif
        guard let animation = settleAnimation else {
            // Reduce Motion: same end state, no visible travel — jump straight there.
            navigateToPeriod()
            #if DEBUG
            debugState.settleCompletedAt = Date()
            debugState.navigateCalledAt = Date()
            #endif
            didCommit = true
            #if DEBUG
            debugState.didCommit = true
            #endif
            return
        }
        isSettling = true
        #if DEBUG
        debugState.isSettling = true
        #endif
        withAnimation(animation) {
            dragTranslation = -availableHeight
        }
        #if DEBUG
        debugState.dragTranslation = -availableHeight
        #endif
        Task {
            try? await Task.sleep(nanoseconds: UInt64(settleAnimationDuration * 1_000_000_000))
            #if DEBUG
            debugState.settleCompletedAt = Date()
            #endif
            navigateToPeriod()
            #if DEBUG
            debugState.navigateCalledAt = Date()
            #endif
            isSettling = false
            didCommit = true
            #if DEBUG
            debugState.isSettling = false
            debugState.didCommit = true
            #endif
        }
    }

    /// Slides the push container back to rest (offset 0) — `periodPage` stays mounted
    /// (`isSettling`) for the length of that return animation so it doesn't pop away mid-slide.
    private func cancelPush() {
        guard let animation = settleAnimation else {
            dragTranslation = 0
            #if DEBUG
            debugState.dragTranslation = 0
            #endif
            return
        }
        isSettling = true
        #if DEBUG
        debugState.isSettling = true
        #endif
        withAnimation(animation) {
            dragTranslation = 0
        }
        #if DEBUG
        debugState.dragTranslation = 0
        #endif
        Task {
            try? await Task.sleep(nanoseconds: UInt64(settleAnimationDuration * 1_000_000_000))
            isSettling = false
            #if DEBUG
            debugState.isSettling = false
            #endif
        }
    }
    #endif

    private func navigateToPeriod() {
        #if os(iOS)
        selectedTab = .period
        #else
        selectedSection = .period
        #endif
    }

    // MARK: - Data

    private func loadPeriod() {
        let loadedPeriod = PeriodCoordinator.materializeIfNeeded(
            coordinate: coordinate,
            context: context,
            recurringItems: recurringSnapshots,
            subscriptions: subscriptionSnapshots,
            loans: loanSnapshots,
            exchangeRate: rateStore.currentRate ?? 0
        )
        try? context.save()
        period = loadedPeriod

        let insightContext = PeriodCoordinator.homeInsightContext(
            for: loadedPeriod, loans: loans, creditCards: creditCards, context: context, exchangeRate: effectiveRate
        )
        insightMessage = HomeInsightEngine.message(for: insightContext)
    }

    private func snapshots(of period: Period) -> [LineSnapshot] { PeriodCoordinator.snapshots(of: period) }

    private func income(for period: Period) -> Decimal {
        CarryOverEngine.total(for: snapshots(of: period), kind: .income, exchangeRate: effectiveRate)
    }

    private func expense(for period: Period) -> Decimal {
        CarryOverEngine.total(for: snapshots(of: period), kind: .expense, exchangeRate: effectiveRate)
    }

    private func sobrante(for period: Period) -> Decimal {
        CarryOverEngine.sobrante(for: snapshots(of: period), exchangeRate: effectiveRate)
    }

    private func nextMonth(for period: Period) -> Decimal {
        PeriodCoordinator.previewNextMonth(
            after: period,
            context: context,
            recurringItems: recurringSnapshots,
            subscriptions: subscriptionSnapshots,
            loans: loanSnapshots,
            exchangeRate: effectiveRate
        )
    }

    /// DESIGN_LIQUID.md § Home "Header de fecha" — day-of-week hero (`h1`, leading) + a
    /// trailing two-line secondary date block ("17 de septiembre" / "2026"), `HStack(alignment:
    /// .firstTextBaseline)` so the hero's baseline lines up with the top line of the secondary
    /// block. No accent dot (discarded explicitly — "el naranja nunca decora").
    private var dateHeader: some View {
        HStack(alignment: .center) {
            Text(todayWeekdayTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color("HomeHeaderTextPrimary"))

            Spacer()

            // ALL CAPS with tracking — same token already used for "INCOME"/"EXPENSES"
            // (`PeriodView.swift`) and "APORTADO A LA FECHA" (`InvestmentsView.swift`), reused
            // verbatim rather than inventing a new one (DESIGN_LIQUID.md § Home, restaurado
            // 2026-09-18).
            VStack(alignment: .trailing, spacing: 2) {
                Text(todayDateTitle)
                Text(todayYearTitle)
            }
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(Color("HomeHeaderTextSecondary"))
        }
    }

    /// "Jueves" — full localized weekday, capitalized (`Locale.current`, `.weekday(.wide)`).
    private var todayWeekdayTitle: String {
        let date = CivilDate.today().date(calendar: .current)
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: .current)
            .weekday(.wide)
        let formatted = date.formatted(style)
        guard let first = formatted.first else { return formatted }
        return String(first).uppercased() + formatted.dropFirst()
    }

    /// "17 de septiembre" (es) / "September 17" (en) — day + wide month, `Locale.current`.
    private var todayDateTitle: String {
        let date = CivilDate.today().date(calendar: .current)
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: .current)
            .day().month(.wide)
        let formatted = date.formatted(style)
        guard let first = formatted.first else { return formatted }
        return String(first).uppercased() + formatted.dropFirst()
    }

    /// "2026" — year only, `Locale.current`.
    private var todayYearTitle: String {
        let date = CivilDate.today().date(calendar: .current)
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: .current).year()
        return date.formatted(style)
    }

    // MARK: - Message

    private var messageText: Text { insightMessage.attributedText }
}

// MARK: - HeaderHeightKey

/// Publishes the fixed header's rendered height up to `HomeView`, so the static Quincena layer
/// and the draggable `PeriodPreviewCard` can both inset by exactly that amount — no magic
/// constant, tracks Dynamic Type and message length automatically.
private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    // Bug fix 2026-09-18 (regression found while fixing the drag-start jump, see
    // `hasPrewarmedPeriodPage`): was `value = nextValue()` — last sibling to report ALWAYS wins,
    // even a sibling that never touches this key at all and so only ever contributes the
    // untouched `defaultValue` (`0`). `headerLayer` is the only view that actually publishes a
    // real measurement here; `staticPeriodLayer`/`cardLayer` don't. As long as `staticPeriodLayer`
    // only mounted well after everything had already settled (the old, gesture-start-only
    // mount timing), its silent `0` contribution never got a chance to land after `headerLayer`'s
    // real value. Mounting it EARLIER (right after load, off the drag path) exposed the latent
    // bug: its first, still-settling layout pass reduces `0` right after `headerLayer`'s real
    // 278pt-ish value, permanently collapsing `headerHeight` to `0` — the fixed header's real
    // rectangle stays intact, but `cardLayer`/`staticPeriodLayer`'s own `.padding(.top,
    // headerHeight)` no longer clears it, so the card renders starting at the very top and
    // visually buries the date/message header underneath it. `max` makes the reduction resilient
    // to any sibling — present now or added later — that doesn't genuinely publish this key: once
    // the real header height has been measured, nothing smaller can ever knock it back down.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - HomeInsightMessage → AttributedString

/// UI-layer presentation of the engine's pure output (plan §2: the engine returns a key +
/// params, never an assembled `String`). Numeric values (`{n}`, `{loanPct}%`, `{cardsDue}`)
/// are highlighted inline — semibold + accent orange — instead of an icon/chip, per
/// DESIGN_LIQUID.md § Home "Mensaje dinámico".
private extension HomeInsightMessage {
    var attributedText: Text {
        switch self {
        case .noDebtCaughtUp:
            return Text(String(localized: "home_message_no_debt_caught_up", defaultValue: "No debt, nothing pending — you're in full control this biweekly. Your surplus is healthy and every account is settled, so this is a great moment to put extra money toward your goals. Keep this streak going."))

        case .noDebtPending(let count):
            return Text(String(localized: "home_message_no_debt_pending_prefix", defaultValue: "You're debt-free! Just "))
                + highlighted("\(count)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_no_debt_pending_suffix_one", defaultValue: " payment left to wrap up this biweekly — clear that and every account will be settled with money to spare. You've got this.")),
                    other: Text(String(localized: "home_message_no_debt_pending_suffix_other", defaultValue: " payments left to wrap up this biweekly — clear those and every account will be settled with money to spare. You've got this.")),
                    count: count
                )

        case .loanJustPaidOff(let name):
            return Text(String(localized: "home_message_loan_just_paid_off", defaultValue: "You just paid off \(name)! One less thing weighing you down — that's real progress, and it means more of your income stays yours starting this period."))

        case .cardsHandledOthersPending(let count):
            return Text(String(localized: "home_message_cards_handled_prefix", defaultValue: "Your credit cards are handled for this biweekly — just "))
                + highlighted("\(count)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_cards_handled_suffix_one", defaultValue: " more payment to close out. Staying ahead on cards like this is exactly what keeps your utilization low and your score healthy.")),
                    other: Text(String(localized: "home_message_cards_handled_suffix_other", defaultValue: " more payments to close out. Staying ahead on cards like this is exactly what keeps your utilization low and your score healthy.")),
                    count: count
                )

        case .almostThereExceptCards(let cardsDue):
            return Text(String(localized: "home_message_almost_there_prefix", defaultValue: "Almost there — everything's paid except "))
                + highlighted("\(cardsDue)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_almost_there_suffix_one", defaultValue: " credit card. Clear that before the cutoff and you'll close out this biweekly fully caught up, with your utilization back where it should be.")),
                    other: Text(String(localized: "home_message_almost_there_suffix_other", defaultValue: " credit cards. Clear those before the cutoff and you'll close out this biweekly fully caught up, with your utilization back where it should be.")),
                    count: cardsDue
                )

        case .onlyCardsLeft(let cardsDue):
            return Text(String(localized: "home_message_only_cards_left_prefix", defaultValue: "Just "))
                + highlighted("\(cardsDue)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_only_cards_left_suffix_one", defaultValue: " credit card payment left this period. Finish that and you're all caught up — no other pending payments standing between you and a clean slate.")),
                    other: Text(String(localized: "home_message_only_cards_left_suffix_other", defaultValue: " credit card payments left this period. Finish those and you're all caught up — no other pending payments standing between you and a clean slate.")),
                    count: cardsDue
                )

        case .caughtUpGoodProgress(let loanPct):
            return Text(String(localized: "home_message_caught_up_good_progress_prefix", defaultValue: "Everything's paid up, and you're "))
                + highlighted("\(loanPct)%")
                + Text(String(localized: "home_message_caught_up_good_progress_suffix", defaultValue: " through your loans. You're closer than you think — at this pace, being debt-free is well within reach, and every on-time payment keeps building that progress."))

        case .caughtUpEarlyProgress(let loanPct):
            return Text(String(localized: "home_message_caught_up_early_progress_prefix", defaultValue: "All caught up this biweekly. Every payment is moving you "))
                + highlighted("\(loanPct)%")
                + Text(String(localized: "home_message_caught_up_early_progress_suffix", defaultValue: " closer to being debt-free — it might feel slow now, but consistency here is what compounds over time."))

        case .pendingHealthyUtilization(let count, let cardsDue, let loanPct):
            return highlighted("\(count)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_pending_healthy_mid1_one", defaultValue: " payment to go this biweekly, including ")),
                    other: Text(String(localized: "home_message_pending_healthy_mid1_other", defaultValue: " payments to go this biweekly, including ")),
                    count: count
                )
                + highlighted("\(cardsDue)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_pending_healthy_mid2_one", defaultValue: " credit card. Small steps — you're already ")),
                    other: Text(String(localized: "home_message_pending_healthy_mid2_other", defaultValue: " credit cards. Small steps — you're already ")),
                    count: cardsDue
                )
                + highlighted("\(loanPct)%")
                + Text(String(localized: "home_message_pending_healthy_suffix", defaultValue: " through your loans, and your credit utilization is in great shape, which is exactly where you want it."))

        case .pendingHighUtilization(let count, let cardsDue):
            return highlighted("\(count)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_pending_high_mid_one", defaultValue: " payment pending, ")),
                    other: Text(String(localized: "home_message_pending_high_mid_other", defaultValue: " payments pending, ")),
                    count: count
                )
                + highlighted("\(cardsDue)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_pending_high_suffix_one", defaultValue: " of them a credit card. Paying that down first is the fastest way to get ahead — it'll lower your utilization and free up more of your surplus for what matters.")),
                    other: Text(String(localized: "home_message_pending_high_suffix_other", defaultValue: " of them credit cards. Paying those down first is the fastest way to get ahead — it'll lower your utilization and free up more of your surplus for what matters.")),
                    count: cardsDue
                )

        case .tightPeriod(let count):
            return Text(String(localized: "home_message_tight_period_prefix", defaultValue: "This period's tight, but clearing "))
                + highlighted("\(count)")
                + pluralSuffix(
                    one: Text(String(localized: "home_message_tight_period_suffix_one", defaultValue: " payment gets you back on track. A negative surplus now doesn't define the whole picture — staying on top of what's due is the first step back to steady ground.")),
                    other: Text(String(localized: "home_message_tight_period_suffix_other", defaultValue: " payments get you back on track. A negative surplus now doesn't define the whole picture — staying on top of what's due is the first step back to steady ground.")),
                    count: count
                )

        case .fallback:
            return Text(String(localized: "home_message_fallback", defaultValue: "Here's your biweekly at a glance — income, expenses, and everything in between, right where you can see it."))
        }
    }

    private func highlighted(_ value: String) -> Text {
        Text(value)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.accentColor)
    }

    /// Picks between the "_one"/"_other" manual String Catalog entries by `count`, per
    /// English plural rules (count == 1 → singular). Xcode's plural `variations` require the
    /// number to appear in the string (build error otherwise), but these suffixes never show
    /// the digit — it's already rendered separately via `highlighted(_:)` — so each pair is
    /// two flat, non-plural catalog entries instead, matching the `_one`/`_other` convention
    /// Xcode itself suggests for that case. `String(localized:)`'s `key:` must be a
    /// `StaticString`, so both branches are spelled out rather than built from a dynamic key.
    private func pluralSuffix(one oneText: Text, other otherText: Text, count: Int) -> Text {
        count == 1 ? oneText : otherText
    }
}
