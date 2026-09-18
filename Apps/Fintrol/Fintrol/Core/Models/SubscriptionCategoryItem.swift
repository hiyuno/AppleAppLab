import Foundation
import SwiftData

/// User-editable category for "Suscripciones" (feedback del usuario: "en settings agrega que
/// podamos agregar las categorías que queramos"). Replaces the fixed `SubscriptionCategory`
/// enum as the source the picker in `SubscriptionsView` reads from — `Subscription.categoryRaw`
/// stays the persisted string (unchanged), it just now matches against a live, user-editable
/// list instead of a compiled `CaseIterable` set.
///
/// Seeded once, on first launch (`RootView`'s one-time seed step), with the 7 original
/// `SubscriptionCategory` cases — same `name` (== the old `rawValue`, so existing
/// `Subscription.categoryRaw` data keeps matching) and same icon (`seedIconName`).
@Model
public final class SubscriptionCategoryItem {
    public var id: UUID = UUID()
    public var name: String = ""
    public var iconName: String = "tag"
    public var sortOrder: Int = 0

    public init(id: UUID = UUID(), name: String, iconName: String, sortOrder: Int) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.sortOrder = sortOrder
    }
}
