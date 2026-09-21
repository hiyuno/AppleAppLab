import SwiftUI
import SwiftData

/// First tab (iPhone) / first sidebar item (Mac) — DESIGN_LIQUID.md § Home. Answers "¿cómo
/// estoy hoy?" faster than the full Quincena: today's date, a dynamic motivational message
/// (`HomeInsightEngine`), and an embedded preview of the current quincena that navigates to the
/// Quincena tab/sidebar-item on tap of its drag handle/title — and, on iPhone, on an upward drag
/// past a threshold (plan `glimmering-swinging-bumblebee.md` §5).
///
/// Woz (2026-09-20, `revealProgress` unification): the preview used to be a separate, read-only
/// `PeriodPreviewCard` view kept in sync with a separately-mounted `PeriodView`
/// (`staticPeriodLayer`) via a floating title overlay and a pile of frame-tracking machinery
/// (`sourceRestFrame`/`destRestFrame`, named coordinate spaces, `PeriodViewInternalTitleInsetKey`,
/// etc.) — all of that is gone. `cardLayer` now mounts exactly ONE real `PeriodView`, driven live
/// by `dragProgress` via its own `revealProgress` parameter: the compact "quick-balance" summary
/// and the detailed income/expenses cards are two ends of the SAME view's continuous spectrum,
/// crossfading and reflowing entirely inside `PeriodView` itself (see that file). `HomeView`'s own
/// job shrinks to what it always should have been: measuring `availableHeight`/`headerHeight`,
/// owning the drag gesture, and deciding when to commit/cancel/navigate.
struct HomeView: View {
    #if os(iOS)
    @Binding var selectedTab: FintrolTab
    #else
    @Binding var selectedSection: FintrolSection?
    #endif

    @Environment(\.modelContext) private var context
    @Environment(ExchangeRateStore.self) private var rateStore
    // Settings → Preferencias → "Mostrar próximo mes" — threaded into the embedded `PeriodView`
    // as `showNextMonth` (see `PeriodView.showNextMonth`/`SummaryPanel.showNextMonth`), same
    // effect on the preview it always had, now expressed as a param on the single unified view
    // instead of a param on the old, separate `PeriodPreviewCard`.
    @AppStorage("fintrol.showNextMonthOnPreviewCard") private var showNextMonthOnPreviewCard = true
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
    /// Full container height (header + embedded Quincena rect together) — measured on the
    /// outer container via `GeometryReader`. `dragProgress` (and everything derived from it —
    /// `revealProgress`, `embeddedTopInset`, the corner-radius convergence) is normalized
    /// against this.
    @State private var availableHeight: CGFloat = 1
    /// Measured height of the fixed white header (date + message) via `HeaderHeightKey`. No
    /// longer drives `embeddedTopInset` directly (see that property's doc comment) — kept for any
    /// other Dynamic-Type-aware layout that needs Home's own header height.
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
    /// ORIGINAL version of this fix (3-frame QuickTime capture) unmounted `cardLayer` the
    /// INSTANT `didCommit` flipped true, on the assumption that "`HomeView` itself
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
    /// more. See `didCommit`'s bug-fix note: unmounting `cardLayer` on `didCommit` alone raced
    /// the tab switch's own animation; gating on this flag too means the
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
            SubscriptionSnapshot(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency, paymentDay: $0.paymentDay, startDate: $0.civilStartDate, endDate: $0.civilEndDate, kind: $0.kind, isActive: $0.isActive, isBiweekly: $0.isBiweekly)
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

    /// Chevrons only start sliding in during the FINAL ~30% of the drag (per user request:
    /// "casi al final de la transition") — `0` for the first 70% of `dragProgress`, then ramps
    /// linearly from `0` to `1` over the remaining 30%, reaching `1` exactly at full commit.
    /// Threshold is tunable — flag to the user if they want the reveal to start earlier/later
    /// once they see it on-device. Derives from `dragProgress` (itself from `dragTranslation`),
    /// so it animates smoothly along with `dragTranslation`'s own settle animation automatically.
    /// Deliberately UNTOUCHED by the `revealProgress` unification (2026-09-20, explicit user
    /// instruction) — `PeriodView.chevronsRevealProgress` still reads this directly.
    private var chevronsRevealProgress: CGFloat {
        let start: CGFloat = 0.7
        guard dragProgress > start else { return 0 }
        return min((dragProgress - start) / (1 - start), 1)
    }

    /// Reduce Motion: the drag-follow itself is direct manipulation (finger-tracked, not an
    /// automatic transition) so it stays 1:1 regardless — only the post-release SETTLE
    /// animation (commit snapping to the end, or cancel snapping back) collapses to instant
    /// with Reduce Motion on. Same end state either way, per plan §5/§6.
    ///
    /// `debugState.easingDisabled` (added 2026-09-19) is a second, debug-only kill switch, toggled
    /// from `GestureDebugHUD` — flipping it in the HUD short-circuits this to `nil` exactly like
    /// `reduceMotion` already does, so `commitPush()`/`cancelPush()` snap instantly and the raw,
    /// un-eased value curves (title lerp, content inset, opacity) can be inspected without any
    /// curve smoothing. `#if DEBUG`-guarded since `debugState` itself only exists in Debug builds
    /// (see the `#if DEBUG` around its `@Environment` above) — Release behaves exactly as before,
    /// gated on `reduceMotion` alone.
    private var settleAnimation: Animation? {
        #if DEBUG
        guard !reduceMotion, !debugState.easingDisabled else { return nil }
        return .easeOut(duration: effectiveSettleDuration)
        #else
        reduceMotion ? nil : .easeOut(duration: effectiveSettleDuration)
        #endif
    }
    private let settleAnimationDuration: TimeInterval = 0.2

    /// The settle duration actually used everywhere it matters — both by `settleAnimation`'s
    /// `withAnimation` transaction AND by the `Task.sleep` calls in `commitPush()`/`cancelPush()`
    /// that wait out that same animation before flipping `isSettling`/`didCommit`. Added
    /// 2026-09-19 alongside `HomeDragDebugState.settleSpeedMultiplier` (the HUD's slow-motion
    /// control): previously `settleAnimationDuration` was a plain constant referenced separately
    /// by the animation and the sleep, which was safe only because they were always equal. Once
    /// the HUD can stretch the animation's duration in Debug builds, the sleep MUST stretch by
    /// the same factor or `isSettling`/`didCommit` flip while the (now much longer) animation is
    /// still visibly running — reopening exactly the race `isPeriodPageMounted`'s bug-fix notes
    /// above were written to close. Routing both through this single computed property keeps them
    /// from ever drifting apart again. `#if DEBUG`-guarded since `debugState` only exists in Debug
    /// builds; Release always uses the plain constant.
    private var effectiveSettleDuration: TimeInterval {
        #if DEBUG
        settleAnimationDuration * debugState.settleSpeedMultiplier
        #else
        settleAnimationDuration
        #endif
    }

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

    /// Woz (2026-09-20, `revealProgress` unification — replaces `contentTopInset`'s old dual-
    /// endpoint interpolation, `headerHeight` ↔ `periodInternalTitleInset`, which its own doc
    /// comment history already flagged as broken under `cardLayer`'s `alignment: .bottom` — see
    /// git history for the "⚠️ KNOWN RISK" note this closes): the top padding applied to the
    /// SINGLE embedded `PeriodView` in `cardLayer`. At rest (`dragProgress == 0`) it's large —
    /// `embeddedRestInset` — pushing the (still mostly-collapsed, `revealProgress ≈ 0`) preview
    /// down toward the bottom of the screen, leaving Home's own header (date + message) visible
    /// above it, same as the old hugged `PeriodPreviewCard` used to. It shrinks continuously to
    /// exactly `0` by full commit (`dragProgress == 1`) — at THAT point this view's own top edge
    /// exactly matches the real standalone `PeriodView` tab's top edge (no padding, no rounded
    /// corners, see `cardLayer`'s `clipShape`), which is what keeps the hand-off seamless: the
    /// same invariant `commitPush()`'s doc comments have always relied on ("by the time `TabView`
    /// cuts over, both sides already show the identical resting frame"), now expressed as a
    /// single continuous formula instead of two views kept in sync.
    ///
    /// Deviates from the brief's suggestion of a `dragTranslation`-based `.offset()` for this
    /// layer (kept as a single `.padding(.top:)` interpolation instead, no `.offset()` at all):
    /// an `.offset()` big enough to slide this view fully off-screen at commit (matching the old
    /// `cardLayer`'s exit) would make the embedded view invisible right when the user needs to
    /// see it land — the real hand-off only stays invisible if the outgoing view's RESTING frame
    /// already matches the destination's frame at that instant, which a padding-only formula
    /// guarantees and a full off-screen `.offset()` does not.
    private var embeddedTopInset: CGFloat {
        embeddedRestInset * (1 - dragProgress)
    }

    /// Tunable rest-state push-down for `embeddedTopInset` — flag to the user/Steve for retuning
    /// once seen on-device (same "tunable, verify on-device" spirit as `commitProgressThreshold`/
    /// `headerToCardSpacing`).
    private let embeddedRestInset: CGFloat = 320

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
            // `isPeriodPageMounted` unmount `cardLayer` after a commit,
            // instead of assuming the tab switch already completed the instant `didCommit` flips.
            isHomeContentVisible = false
            #if DEBUG
            debugState.isHomeContentVisible = false
            #endif
        }
    }

    // ONE mounted layer over Home's fixed header now (user-confirmed mechanic change,
    // 2026-09-20): `headerLayer` (date + message) never moves; `cardLayer` mounts exactly ONE
    // `PeriodView`, driven live by `dragProgress` via its own `revealProgress` — see
    // `PeriodView`'s doc comment. `GeometryReader` measures the TOTAL space Home gets from the
    // `TabView`/`NavigationStack` above it — that's `availableHeight`, what `dragProgress` is
    // normalized against.
    private var content: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // DESIGN_LIQUID.md § Home "Fondo del header — excepción blanca": fixed white
                // surface (no Dark variant on purpose) covering the FULL height of this `ZStack`
                // — so `cardLayer`'s rounded top corners never cut away to reveal a mismatched
                // background right where the card meets the header above it.
                Color("HomeHeaderBackground")
                    .ignoresSafeArea(edges: .top)

                headerLayer
                    #if DEBUG
                    .debugOutline("header", color: .red, enabled: debugState.outlinesEnabled, padding: "h:20 top:0 bottom:\(Int(headerToCardSpacing))")
                    #endif
                cardLayer
                    #if DEBUG
                    .debugOutline("card", color: .green, enabled: debugState.outlinesEnabled, padding: "top:\(Int(embeddedTopInset))")
                    #endif
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

    /// Fixed header — date + dynamic message — NEVER offset, not even during the drag. Publishes
    /// its own rendered height via `HeaderHeightKey` (kept for Dynamic-Type-aware layout
    /// elsewhere, even though `embeddedTopInset` no longer derives from it — see that property's
    /// doc comment).
    ///
    /// Bug fix (2026-09-18, user-reported with screenshot): near the end of the drag, this
    /// layer's dynamic message text used to render as a ghosted/double-exposed overlap with the
    /// embedded Quincena's incoming title once `cardLayer` had grown far enough to reveal what's
    /// underneath. Root cause: this layer only had `Color.clear` as its own `.background` — it
    /// relied entirely on the ZStack's shared `Color("HomeHeaderBackground")`, which sits at the
    /// very BOTTOM of the ZStack, BELOW `cardLayer`, not between the two. So `headerLayer` had no
    /// actual opaque backing of its own: everywhere outside the glyphs themselves it was fully
    /// transparent, letting `cardLayer` show/blend straight through during the animated frames
    /// (same `.compositingGroup()`-before-`.clipShape()` gotcha as `LineItemRow`'s card
    /// background — a transformed sibling layer isn't guaranteed to composite as a clean opaque
    /// stack unless each layer that must fully occlude is flattened with a real opaque
    /// background baked in). Fix: give this layer its own opaque
    /// `Color("HomeHeaderBackground")` fill sized to its own bounds, then flatten with
    /// `.compositingGroup()` so it always paints as one solid, fully-opaque texture over
    /// whatever `cardLayer` is doing underneath — the user's ask ("el texto de home se queda
    /// atrás, porque ahora se enfrenta") is satisfied by making the occlusion real instead of
    /// relying on z-order alone.
    private var headerLayer: some View {
        VStack(alignment: .leading, spacing: 32) {
            settingsButtonRow

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
        .padding(.top, 0)
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
        // paints as one solid texture over `cardLayer`, instead of SwiftUI/Core Animation
        // potentially compositing them as separate semi-independent layers mid-animation.
        .compositingGroup()
    }

    /// The single embedded `PeriodView` — replaces the old `PeriodPreviewCard`/`staticPeriodLayer`
    /// pair entirely (see this file's top doc comment). Driven by TWO live parameters off the
    /// same `dragProgress`: `revealProgress` (this view's own internal crossfade+reflow — see
    /// `PeriodView`) and `embeddedTopInset` (this layer's own top padding — see that property's
    /// doc comment for why it replaces the old two-view offset dance). No `.offset()` at all:
    /// the padding shrinking to `0` by full commit is what lands this view's top edge exactly
    /// where the real standalone `PeriodView` tab's top edge sits, which is what keeps the
    /// hand-off invisible.
    ///
    /// Corner radius mirrors that same convergence — `cardCornerRadius` at rest, shrinking to `0`
    /// by full commit (the standalone destination has no clip at all), so the rounded-top "card"
    /// look smoothly resolves into the destination's square corners instead of popping.
    @ViewBuilder
    private var cardLayer: some View {
        if isPeriodPageMounted {
            PeriodView(
                revealProgress: dragProgress,
                onTap: navigateToPeriod,
                showNextMonth: showNextMonthOnPreviewCard,
                chevronsRevealProgress: chevronsRevealProgress
            )
            // Woz (2026-09-20, corners-invisible-on-black investigation): `.clipShape` used to sit
            // AFTER `.padding(.top:)`/`.frame(maxHeight: .infinity)` below — i.e. it clipped the
            // OUTER frame, whose bounds span the full `GeometryReader` height starting at y=0 (the
            // very top of `content`'s ZStack, underneath `headerLayer`), not the visible top edge
            // of this card (which only starts `embeddedTopInset` points lower, where `PeriodView`'s
            // own opaque background actually begins — everything above that is transparent padding
            // showing `headerLayer`/`HomeHeaderBackground` through). So the rounded corners WERE
            // being clipped — just up at y=0, hidden behind/above the header, nowhere near the
            // black card's actual visible top boundary, which rendered as a perfectly flat,
            // unclipped straight line no matter the radius (confirmed with pixel sampling: the
            // black/white transition sat at the exact same row across the full width, with zero
            // curvature within the radius's pixel range near either edge — a real clip bug, not a
            // color-contrast one; hardcoding the radius to an obviously-large value couldn't have
            // surfaced this, since the curve was always off-canvas either way).
            //
            // Fix: clip `PeriodView` directly, BEFORE the padding/frame that positions it — clipping
            // only affects rendering, not layout, so `PeriodView` still receives the exact same size
            // proposal as before (full available height minus `embeddedTopInset`, from the frame's
            // maxHeight below), but now the rounded-rect's bounds match PeriodView's own actual
            // rendered rect, so the curve lands exactly at the visible top edge instead of off-screen.
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cardCornerRadius * (1 - dragProgress),
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: cardCornerRadius * (1 - dragProgress),
                    style: .continuous
                )
            )
            .padding(.top, embeddedTopInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .bottom)
            #if os(iOS)
                // `.highPriorityGesture`, not `.gesture` — without this, `PeriodView`'s own
                // internal gestures (`ScrollView`'s pan, `LineItemRow`'s swipe actions, every
                // `Button`) win the recognition race and the drag-to-navigate mechanic never even
                // starts, same reasoning the old `PeriodPreviewCard` call site already documented.
                // A short tap (under `minimumDistance`) still falls through to whatever real
                // control is underneath (line rows, "+", the drag handle/title's own navigation
                // button — see `PeriodView.handleOrTitleTapped()`).
                //
                // ⚠️ KNOWN RISK, flagged per explicit instruction rather than silently shipping a
                // maybe-broken interaction (verify on-device, §4 of the reveal-unification plan):
                // now that this view is genuinely interactive (not `PeriodPreviewCard`'s old
                // non-interactive card), a broad-area `DragGesture(minimumDistance: 16)` with no
                // axis filter could, in principle, win against `LineItemRow`'s own
                // leading/trailing swipe gesture for a swipe that happens to travel far enough
                // before SwiftUI resolves which gesture owns it. Kept exactly as the user
                // confirmed ("the DRAG gesture, covering the same broad area as before, remains
                // the primary way to navigate from lower in the card") — needs real on-device
                // testing with actual line rows visible mid-drag (`revealProgress` above ~0) to
                // confirm swipe-to-reveal still works cleanly.
                .highPriorityGesture(dragGesture)
                #endif
        }
    }

    /// Top corners only (bottom stays square — the card runs edge-to-edge to the screen's
    /// physical bottom). Matches the current device's real screen corner curve — see
    /// `DeviceCornerRadius` — instead of a single hardcoded guess.
    private var cardCornerRadius: CGFloat { DeviceCornerRadius.current }

    /// DESIGN_LIQUID.md § Home "Densidad visual — ajustes puntuales" (revisión 2026-09-18):
    /// 32pt → 48pt, the gap between the dynamic message and the embedded `PeriodView` card.
    private let headerToCardSpacing: CGFloat = 48

    #if os(iOS)
    private func hapticImpact() {
        HapticFeedback.lightImpact(reduceMotion: reduceMotion)
    }

    /// Attached only to `cardLayer`, not the whole screen — so it never fights the header's own
    /// layout (plan §5/verificación #1).
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
    /// instead mark `didCommit = true`, which unmounts `cardLayer` right away
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
            try? await Task.sleep(nanoseconds: UInt64(effectiveSettleDuration * 1_000_000_000))
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
            try? await Task.sleep(nanoseconds: UInt64(effectiveSettleDuration * 1_000_000_000))
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

    /// DESIGN_LIQUID.md § Home "Header de fecha" — day-of-week hero (`h1`, leading) + a
    /// trailing two-line secondary date block ("17 de septiembre" / "2026"), `HStack(alignment:
    /// .firstTextBaseline)` so the hero's baseline lines up with the top line of the secondary
    /// block. No accent dot (discarded explicitly — "el naranja nunca decora").
    /// Coordinator (2026-09-21): Ajustes moved out of the iPhone tab bar into this gear button
    /// per the user's updated Figma (`00 · Home`) — top-right, above `dateHeader`, its own row so
    /// it doesn't compete with the weekday hero's baseline alignment. `HomeView` already sits
    /// inside `iOSRootView`'s per-tab `NavigationStack` (see `destination(for:)`), so a plain
    /// `NavigationLink` pushes `SettingsView` naturally — no sheet needed.
    private var settingsButtonRow: some View {
        HStack {
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(Color("HomeHeaderTextPrimary"))
            }
            .accessibilityLabel("Ajustes")
        }
    }

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

/// Publishes the fixed header's rendered height up to `HomeView` — no magic constant, tracks
/// Dynamic Type and message length automatically.
private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    // Bug fix 2026-09-18 (regression found while fixing the drag-start jump, see
    // `hasPrewarmedPeriodPage`): was `value = nextValue()` — last sibling to report ALWAYS wins,
    // even a sibling that never touches this key at all and so only ever contributes the
    // untouched `defaultValue` (`0`). `headerLayer` is the only view that actually publishes a
    // real measurement here; `cardLayer` doesn't. `max` makes the reduction resilient to any
    // sibling — present now or added later — that doesn't genuinely publish this key: once the
    // real header height has been measured, nothing smaller can ever knock it back down.
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
