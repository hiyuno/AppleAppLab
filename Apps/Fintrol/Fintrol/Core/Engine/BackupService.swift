import Foundation
import SwiftData

/// Full-store JSON backup/restore (Ajustes → Preferencias). Coordinator's rule: the
/// simulator's captured data must survive future builds, so this is both a manual safety net
/// for the user and the fixture mechanism for tests/DEBUG-store-recovery (`FintrolApp`'s
/// delete-and-retry path calls into `BackupService.backupStoreFiles` before ever deleting
/// anything). Every persisted field round-trips except the Banxico token, which lives only in
/// the Keychain and is never written to disk in plaintext (SECURITY.md C-12).
public enum BackupService {
    public struct Backup: Codable {
        public var version: Int = 1
        public var exportedAt: Date
        public var periods: [PeriodDTO]
        public var recurringItems: [RecurringItemDTO]
        public var subscriptions: [SubscriptionDTO]
        public var loans: [LoanDTO]
        public var exchangeRateCache: [ExchangeRateCacheDTO]
    }

    public struct PeriodDTO: Codable {
        public var id: UUID
        public var startDate: Date
        public var endDate: Date
        public var year: Int
        public var month: Int
        public var halfRaw: String
        public var manualExchangeRateOverride: Decimal?
        public var isMaterialized: Bool
        public var lineItems: [LineItemDTO]
    }

    public struct LineItemDTO: Codable {
        public var id: UUID
        public var kindRaw: String
        public var title: String
        public var amount: Decimal
        public var currencyRaw: String
        public var isPaid: Bool
        public var isActive: Bool
        public var sortOrder: Int
        public var originRaw: String
        public var sourceRecurringID: UUID?
        public var sourceLoanID: UUID?
        public var isManuallyEdited: Bool
        public var exchangeRateSnapshot: Decimal?
        public var isHomeService: Bool
    }

    public struct RecurringItemDTO: Codable {
        public var id: UUID
        public var kindRaw: String
        public var title: String
        public var amount: Decimal
        public var currencyRaw: String
        public var frequencyKindRaw: String
        public var frequencyDay: Int?
        public var frequencyOnceDate: Date?
        public var startDate: Date
        public var endDate: Date?
        public var isActive: Bool
    }

    public struct SubscriptionDTO: Codable {
        public var id: UUID
        public var name: String
        public var price: Decimal
        public var currencyRaw: String
        public var paymentDay: Int
        public var startDate: Date
        public var endDate: Date?
        public var card: String
        public var kindRaw: String
        public var categoryRaw: String
        public var isActive: Bool
        public var isBiweekly: Bool = false
    }

    public struct LoanDTO: Codable {
        public var id: UUID
        public var name: String
        public var directionRaw: String
        public var principal: Decimal
        public var currencyRaw: String
        public var apr: Decimal
        public var startDate: Date
        public var termMonths: Int
        public var frequencyKindRaw: String
        public var frequencyDay: Int?
        public var paymentOverride: Decimal?
        public var isActive: Bool
        public var modeRaw: String
        public var expectedPayment: Decimal?
    }

    public struct ExchangeRateCacheDTO: Codable {
        public var id: UUID
        public var date: Date
        public var rate: Decimal
        public var fetchedFromAPI: Bool
    }

    // MARK: - Export

    /// Builds a `Backup` from everything currently in `context`. Never touches the Keychain —
    /// the Banxico token is intentionally excluded (SECURITY.md C-12).
    public static func exportBackup(context: ModelContext) -> Backup {
        let periods = (try? context.fetch(FetchDescriptor<Period>())) ?? []
        let recurringItems = (try? context.fetch(FetchDescriptor<RecurringItem>())) ?? []
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        let loans = (try? context.fetch(FetchDescriptor<Loan>())) ?? []
        let rateCache = (try? context.fetch(FetchDescriptor<ExchangeRateCache>())) ?? []

        let periodDTOs = periods.map { period in
            PeriodDTO(
                id: period.id, startDate: period.startDate, endDate: period.endDate,
                year: period.year, month: period.month, halfRaw: period.halfRaw,
                manualExchangeRateOverride: period.manualExchangeRateOverride,
                isMaterialized: period.isMaterialized,
                lineItems: (period.lineItems ?? []).map { line in
                    LineItemDTO(
                        id: line.id, kindRaw: line.kindRaw, title: line.title, amount: line.amount,
                        currencyRaw: line.currencyRaw, isPaid: line.isPaid, isActive: line.isActive,
                        sortOrder: line.sortOrder, originRaw: line.originRaw,
                        sourceRecurringID: line.sourceRecurringID, sourceLoanID: line.sourceLoanID,
                        isManuallyEdited: line.isManuallyEdited, exchangeRateSnapshot: line.exchangeRateSnapshot,
                        isHomeService: line.isHomeService
                    )
                }
            )
        }

        let recurringDTOs = recurringItems.map {
            RecurringItemDTO(
                id: $0.id, kindRaw: $0.kindRaw, title: $0.title, amount: $0.amount, currencyRaw: $0.currencyRaw,
                frequencyKindRaw: $0.frequencyKindRaw, frequencyDay: $0.frequencyDay, frequencyOnceDate: $0.frequencyOnceDate,
                startDate: $0.startDate, endDate: $0.endDate, isActive: $0.isActive
            )
        }

        let subscriptionDTOs = subscriptions.map {
            SubscriptionDTO(
                id: $0.id, name: $0.name, price: $0.price, currencyRaw: $0.currencyRaw, paymentDay: $0.paymentDay,
                startDate: $0.startDate, endDate: $0.endDate, card: $0.card, kindRaw: $0.kindRaw,
                categoryRaw: $0.categoryRaw, isActive: $0.isActive, isBiweekly: $0.isBiweekly
            )
        }

        let loanDTOs = loans.map {
            LoanDTO(
                id: $0.id, name: $0.name, directionRaw: $0.directionRaw, principal: $0.principal, currencyRaw: $0.currencyRaw,
                apr: $0.apr, startDate: $0.startDate, termMonths: $0.termMonths, frequencyKindRaw: $0.frequencyKindRaw,
                frequencyDay: $0.frequencyDay, paymentOverride: $0.paymentOverride, isActive: $0.isActive,
                modeRaw: $0.modeRaw, expectedPayment: $0.expectedPayment
            )
        }

        let rateDTOs = rateCache.map {
            ExchangeRateCacheDTO(id: $0.id, date: $0.date, rate: $0.rate, fetchedFromAPI: $0.fetchedFromAPI)
        }

        return Backup(
            exportedAt: Date(), periods: periodDTOs, recurringItems: recurringDTOs,
            subscriptions: subscriptionDTOs, loans: loanDTOs, exchangeRateCache: rateDTOs
        )
    }

    public static func encode(_ backup: Backup) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    // MARK: - Import

    public struct ImportSummary {
        public var periods = 0
        public var lineItems = 0
        public var recurringItems = 0
        public var subscriptions = 0
        public var loans = 0
        public var rateEntries = 0
    }

    public static func decode(_ data: Data) -> Backup? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Backup.self, from: data)
    }

    /// Replaces everything in `context` with `backup`'s contents. Dedupe is by `id`: an
    /// existing record with a matching id is updated in place, a new id is inserted, and any
    /// record NOT present in the backup is deleted — this is a full replace, per the
    /// coordinator's spec ("reemplaza todo tras confirmación, dedupe por id"). Callers must
    /// confirm with the user before calling this — it is destructive.
    @discardableResult
    public static func importBackup(_ backup: Backup, context: ModelContext) -> ImportSummary {
        var summary = ImportSummary()

        let existingPeriods = (try? context.fetch(FetchDescriptor<Period>())) ?? []
        var periodsByID = Dictionary(uniqueKeysWithValues: existingPeriods.map { ($0.id, $0) })
        var keepPeriodIDs = Set<UUID>()

        for dto in backup.periods {
            keepPeriodIDs.insert(dto.id)
            let period: Period
            if let existing = periodsByID[dto.id] {
                period = existing
            } else {
                period = Period(id: dto.id, startDate: dto.startDate, endDate: dto.endDate, year: dto.year, month: dto.month, half: PeriodHalf(rawValue: dto.halfRaw) ?? .first)
                context.insert(period)
                periodsByID[dto.id] = period
            }
            period.startDate = dto.startDate
            period.endDate = dto.endDate
            period.year = dto.year
            period.month = dto.month
            period.halfRaw = dto.halfRaw
            period.manualExchangeRateOverride = dto.manualExchangeRateOverride
            period.isMaterialized = dto.isMaterialized

            var existingLines = Dictionary(uniqueKeysWithValues: (period.lineItems ?? []).map { ($0.id, $0) })
            var newLineItems: [LineItem] = []
            for lineDTO in dto.lineItems {
                let line: LineItem
                if let existing = existingLines[lineDTO.id] {
                    line = existing
                    existingLines.removeValue(forKey: lineDTO.id)
                } else {
                    line = LineItem(id: lineDTO.id, kind: LineKind(rawValue: lineDTO.kindRaw) ?? .income, title: lineDTO.title, amount: lineDTO.amount, currency: Currency(rawValue: lineDTO.currencyRaw) ?? .usd)
                    context.insert(line)
                }
                line.kindRaw = lineDTO.kindRaw
                line.title = lineDTO.title
                line.amount = lineDTO.amount
                line.currencyRaw = lineDTO.currencyRaw
                line.isPaid = lineDTO.isPaid
                line.isActive = lineDTO.isActive
                line.sortOrder = lineDTO.sortOrder
                line.originRaw = lineDTO.originRaw
                line.sourceRecurringID = lineDTO.sourceRecurringID
                line.sourceLoanID = lineDTO.sourceLoanID
                line.isManuallyEdited = lineDTO.isManuallyEdited
                line.exchangeRateSnapshot = lineDTO.exchangeRateSnapshot
                line.isHomeService = lineDTO.isHomeService
                line.period = period
                newLineItems.append(line)
                summary.lineItems += 1
            }
            // Anything left in `existingLines` was not in the backup — delete it (full replace).
            for orphan in existingLines.values { context.delete(orphan) }
            period.lineItems = newLineItems
            summary.periods += 1
        }
        for (id, period) in periodsByID where !keepPeriodIDs.contains(id) {
            context.delete(period)
        }

        replace(RecurringItem.self, with: backup.recurringItems, context: context, count: &summary.recurringItems) { dto, existing in
            let item = existing ?? {
                let created = RecurringItem(id: dto.id, kind: .income, title: dto.title, amount: dto.amount, currency: .usd, frequency: .biweekly, startDate: dto.startDate)
                context.insert(created)
                return created
            }()
            item.kindRaw = dto.kindRaw
            item.title = dto.title
            item.amount = dto.amount
            item.currencyRaw = dto.currencyRaw
            item.frequencyKindRaw = dto.frequencyKindRaw
            item.frequencyDay = dto.frequencyDay
            item.frequencyOnceDate = dto.frequencyOnceDate
            item.startDate = dto.startDate
            item.endDate = dto.endDate
            item.isActive = dto.isActive
        }

        replace(Subscription.self, with: backup.subscriptions, context: context, count: &summary.subscriptions) { dto, existing in
            let item = existing ?? {
                let created = Subscription(id: dto.id, name: dto.name, price: dto.price, currency: .usd, paymentDay: dto.paymentDay, startDate: dto.startDate, category: .tools)
                context.insert(created)
                return created
            }()
            item.name = dto.name
            item.price = dto.price
            item.currencyRaw = dto.currencyRaw
            item.paymentDay = dto.paymentDay
            item.startDate = dto.startDate
            item.endDate = dto.endDate
            item.card = dto.card
            item.kindRaw = dto.kindRaw
            item.categoryRaw = dto.categoryRaw
            item.isActive = dto.isActive
            item.isBiweekly = dto.isBiweekly
        }

        replace(Loan.self, with: backup.loans, context: context, count: &summary.loans) { dto, existing in
            let item = existing ?? {
                let created = Loan(id: dto.id, name: dto.name, direction: .borrowed, principal: dto.principal, currency: .usd, apr: dto.apr, startDate: dto.startDate, termMonths: dto.termMonths, frequency: .monthly(day: 1))
                context.insert(created)
                return created
            }()
            item.name = dto.name
            item.directionRaw = dto.directionRaw
            item.principal = dto.principal
            item.currencyRaw = dto.currencyRaw
            item.apr = dto.apr
            item.startDate = dto.startDate
            item.termMonths = dto.termMonths
            item.frequencyKindRaw = dto.frequencyKindRaw
            item.frequencyDay = dto.frequencyDay
            item.paymentOverride = dto.paymentOverride
            item.isActive = dto.isActive
            item.modeRaw = dto.modeRaw
            item.expectedPayment = dto.expectedPayment
        }

        replace(ExchangeRateCache.self, with: backup.exchangeRateCache, context: context, count: &summary.rateEntries) { dto, existing in
            let item = existing ?? {
                let created = ExchangeRateCache(id: dto.id, date: dto.date, rate: dto.rate, fetchedFromAPI: dto.fetchedFromAPI)
                context.insert(created)
                return created
            }()
            item.date = dto.date
            item.rate = dto.rate
            item.fetchedFromAPI = dto.fetchedFromAPI
        }

        try? context.save()
        return summary
    }

    /// Shared dedupe-by-id replace pattern for the four flat (non-`Period`) model types.
    private static func replace<Model: PersistentModel, DTO>(
        _ type: Model.Type, with dtos: [DTO], context: ModelContext, count: inout Int,
        apply: (DTO, Model?) -> Void
    ) where DTO: HasBackupID {
        let existing = (try? context.fetch(FetchDescriptor<Model>())) ?? []
        var byID = Dictionary(uniqueKeysWithValues: existing.compactMap { model -> (UUID, Model)? in
            guard let id = (model as? any HasModelID)?.backupID else { return nil }
            return (id, model)
        })
        var keep = Set<UUID>()
        for dto in dtos {
            keep.insert(dto.backupID)
            apply(dto, byID[dto.backupID])
            byID.removeValue(forKey: dto.backupID)
            count += 1
        }
        for orphan in byID.values { context.delete(orphan) }
    }
}

/// Lets the generic `replace` helper above read an `id: UUID` off both the DTO and the
/// `@Model` types without repeating per-type boilerplate.
protocol HasBackupID { var backupID: UUID { get } }
protocol HasModelID { var backupID: UUID { get } }

extension BackupService.RecurringItemDTO: HasBackupID { var backupID: UUID { id } }
extension BackupService.SubscriptionDTO: HasBackupID { var backupID: UUID { id } }
extension BackupService.LoanDTO: HasBackupID { var backupID: UUID { id } }
extension BackupService.ExchangeRateCacheDTO: HasBackupID { var backupID: UUID { id } }

extension RecurringItem: HasModelID { var backupID: UUID { id } }
extension Subscription: HasModelID { var backupID: UUID { id } }
extension Loan: HasModelID { var backupID: UUID { id } }
extension ExchangeRateCache: HasModelID { var backupID: UUID { id } }
