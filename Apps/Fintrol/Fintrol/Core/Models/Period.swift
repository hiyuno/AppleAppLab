import Foundation
import SwiftData

@Model
public final class Period {
    public var id: UUID = UUID()
    public var startDate: Date = Date()
    public var endDate: Date = Date()
    public var year: Int = 0
    public var month: Int = 0
    public var halfRaw: String = PeriodHalf.first.rawValue
    public var manualExchangeRateOverride: Decimal?
    public var isMaterialized: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \LineItem.period)
    public var lineItems: [LineItem]?

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        year: Int,
        month: Int,
        half: PeriodHalf,
        manualExchangeRateOverride: Decimal? = nil,
        isMaterialized: Bool = false,
        lineItems: [LineItem]? = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.year = year
        self.month = month
        self.halfRaw = half.rawValue
        self.manualExchangeRateOverride = manualExchangeRateOverride
        self.isMaterialized = isMaterialized
        self.lineItems = lineItems
    }

    public var half: PeriodHalf {
        get { PeriodHalf(rawValue: halfRaw) ?? .first }
        set { halfRaw = newValue.rawValue }
    }

    /// Natural key used for materialized-period lookup.
    public var coordinate: PeriodCoordinate {
        PeriodCoordinate(year: year, month: month, half: half)
    }
}

/// Pure, hashable, `Sendable` identity of a period independent of SwiftData.
public struct PeriodCoordinate: Hashable, Sendable, Comparable {
    public let year: Int
    public let month: Int
    public let half: PeriodHalf

    public init(year: Int, month: Int, half: PeriodHalf) {
        self.year = year
        self.month = month
        self.half = half
    }

    public static func < (lhs: PeriodCoordinate, rhs: PeriodCoordinate) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.half == .first && rhs.half == .second
    }

    public var next: PeriodCoordinate {
        if half == .first {
            return PeriodCoordinate(year: year, month: month, half: .second)
        }
        if month == 12 {
            return PeriodCoordinate(year: year + 1, month: 1, half: .first)
        }
        return PeriodCoordinate(year: year, month: month + 1, half: .first)
    }

    public var previous: PeriodCoordinate {
        if half == .second {
            return PeriodCoordinate(year: year, month: month, half: .first)
        }
        if month == 1 {
            return PeriodCoordinate(year: year - 1, month: 12, half: .second)
        }
        return PeriodCoordinate(year: year, month: month - 1, half: .second)
    }
}
