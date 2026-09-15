import Foundation
import SwiftData

/// Single-row cache of the last known USD→MXN rate. SwiftData/CloudKit keeps
/// exactly one materialized row of this type (looked up by fetching all and
/// taking the most recent `date`), never a full history.
@Model
public final class ExchangeRateCache {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var rate: Decimal = 0
    public var fetchedFromAPI: Bool = false

    public init(id: UUID = UUID(), date: Date, rate: Decimal, fetchedFromAPI: Bool) {
        self.id = id
        self.date = date
        self.rate = rate
        self.fetchedFromAPI = fetchedFromAPI
    }
}
