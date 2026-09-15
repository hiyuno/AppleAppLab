import Foundation

/// Parses and validates the JSON subscription/service import format (Ajustes → Preferencias
/// → "Importar suscripciones y servicios…"). Pure, `Sendable`, no SwiftData — mirrors the
/// `Core/Engine` pattern (`ProjectionEngine`, `LoanEngine`): the coordinator layer
/// (`PeriodCoordinator.importSubscriptions`) turns validated items into `Subscription` rows.
///
/// Format:
/// ```json
/// {"version":1,"items":[{"name":"Netflix","kind":"subscription","amount":15,"currency":"USD",
///   "payDay":5,"startDate":"2026-01-01","endDate":null,"isActive":true,
///   "paymentMethod":"Apple Card","category":"entertainment"}]}
/// ```
///
/// Defensive by construction: `ImportItemRaw.init(from:)` never throws — every field decodes
/// via `try?`, so one item with a malformed field (wrong type, unparseable date) can never
/// abort the whole `items` array decode. Validation then runs per item and reports which
/// ones failed and why, without ever needing to re-derive amounts from anything but `Decimal`
/// and dates from anything but `CivilDate` (TRD "Decisiones de Swift").
public enum SubscriptionImportService {
    // MARK: - Wire format (defensive: every field optional, decode never throws per item)

    struct ImportFile: Decodable {
        let version: Int?
        let items: [ImportItemRaw]
    }

    struct ImportItemRaw: Decodable {
        let name: String?
        let kindRaw: String?
        let amount: Decimal?
        let currencyRaw: String?
        let payDay: Int?
        let startDateRaw: String?
        let endDateRaw: String?
        let isActive: Bool?
        let paymentMethod: String?
        let categoryRaw: String?

        private enum CodingKeys: String, CodingKey {
            case name, kind, amount, currency, payDay, startDate, endDate, isActive, paymentMethod, category
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try? container.decodeIfPresent(String.self, forKey: .name)
            kindRaw = try? container.decodeIfPresent(String.self, forKey: .kind)
            amount = try? container.decodeIfPresent(Decimal.self, forKey: .amount)
            currencyRaw = try? container.decodeIfPresent(String.self, forKey: .currency)
            payDay = try? container.decodeIfPresent(Int.self, forKey: .payDay)
            startDateRaw = try? container.decodeIfPresent(String.self, forKey: .startDate)
            endDateRaw = try? container.decodeIfPresent(String.self, forKey: .endDate)
            isActive = try? container.decodeIfPresent(Bool.self, forKey: .isActive)
            paymentMethod = try? container.decodeIfPresent(String.self, forKey: .paymentMethod)
            categoryRaw = try? container.decodeIfPresent(String.self, forKey: .category)
        }
    }

    // MARK: - Validated output

    public struct ValidatedItem: Sendable, Hashable {
        public let name: String
        public let kind: SubscriptionKind
        public let amount: Decimal
        public let currency: Currency
        public let payDay: Int
        public let startDate: CivilDate
        public let endDate: CivilDate?
        public let isActive: Bool
        public let paymentMethod: String
        public let subscriptionCategory: SubscriptionCategory
        public let homeServiceCategory: HomeServiceCategory
    }

    /// One item that failed validation — `index` is its position in the JSON `items` array
    /// (0-based), for a precise, non-sensitive error message (SECURITY C-05: never logs the
    /// amount, only the reason and, when present, the item's own `name`).
    public struct Issue: Sendable, Hashable {
        public let index: Int
        public let name: String?
        public let reason: String
    }

    public struct ParseResult: Sendable {
        public let valid: [ValidatedItem]
        public let issues: [Issue]
    }

    // MARK: - Entry point

    public static func parse(data: Data) -> ParseResult {
        guard let file = try? JSONDecoder().decode(ImportFile.self, from: data) else {
            return ParseResult(valid: [], issues: [Issue(index: -1, name: nil, reason: "El archivo no tiene el formato JSON esperado.")])
        }

        var valid: [ValidatedItem] = []
        var issues: [Issue] = []
        for (index, raw) in file.items.enumerated() {
            switch validate(raw) {
            case .success(let item):
                valid.append(item)
            case .failure(let reason):
                issues.append(Issue(index: index, name: raw.name, reason: reason))
            }
        }
        return ParseResult(valid: valid, issues: issues)
    }

    // MARK: - Per-item validation

    private enum ValidationOutcome {
        case success(ValidatedItem)
        case failure(String)
    }

    private static func validate(_ raw: ImportItemRaw) -> ValidationOutcome {
        guard let name = raw.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return .failure("Falta \"name\".")
        }
        guard let kindRaw = raw.kindRaw, let kind = SubscriptionKind(rawValue: kindRaw) else {
            return .failure("\"kind\" inválido o faltante (debe ser \"subscription\" o \"service\").")
        }
        guard let amount = raw.amount, ValidationRange.amount.contains(amount) else {
            return .failure("\"amount\" inválido o fuera de rango.")
        }
        guard let currencyRaw = raw.currencyRaw, let currency = Currency(rawValue: currencyRaw.lowercased()) else {
            return .failure("\"currency\" inválida (debe ser \"USD\" o \"MXN\").")
        }
        guard let payDay = raw.payDay, ValidationRange.dayOfMonth.contains(payDay) else {
            return .failure("\"payDay\" fuera de rango (1-31).")
        }
        guard let startDateRaw = raw.startDateRaw, let startDate = civilDate(fromISO: startDateRaw) else {
            return .failure("\"startDate\" inválida (formato esperado YYYY-MM-DD).")
        }

        let endDate: CivilDate?
        if let endDateRaw = raw.endDateRaw {
            guard let parsed = civilDate(fromISO: endDateRaw) else {
                return .failure("\"endDate\" inválida (formato esperado YYYY-MM-DD).")
            }
            endDate = parsed
        } else {
            endDate = nil
        }

        let categoryRaw = raw.categoryRaw ?? ""
        return .success(ValidatedItem(
            name: name,
            kind: kind,
            amount: amount,
            currency: currency,
            payDay: payDay,
            startDate: startDate,
            endDate: endDate,
            isActive: raw.isActive ?? true,
            paymentMethod: raw.paymentMethod ?? "",
            subscriptionCategory: mapSubscriptionCategory(categoryRaw),
            homeServiceCategory: mapHomeServiceCategory(categoryRaw)
        ))
    }

    /// Strict `YYYY-MM-DD` parse straight into `CivilDate` — never through `Date`/`Calendar`
    /// (TRD "Decisiones de Swift"), and rejects a calendar-impossible day (e.g. Feb 30) rather
    /// than silently clamping it, since an import file's date should already be a real date.
    private static func civilDate(fromISO string: String) -> CivilDate? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        let candidate = CivilDate(year: year, month: month, day: day)
        guard candidate.day <= candidate.daysInMonth else { return nil }
        return candidate
    }

    /// The import format shares one `category` field across both kinds; `SubscriptionCategory`
    /// (entertainment/tools subscriptions) has no "home" case, so a subscription-kind item
    /// tagged "home" maps to its nearest neighbor, `.personal`.
    private static func mapSubscriptionCategory(_ raw: String) -> SubscriptionCategory {
        switch raw {
        case "tools": .tools
        case "entertainment": .entertainment
        case "work": .work
        case "personal": .personal
        case "hobby": .hobby
        case "investment": .investment
        case "home": .personal
        default: .tools
        }
    }

    /// `HomeServiceCategory` has no generic "home" case (only specific utilities); the import
    /// format's only service-side category value in practice is "home", which maps to `.rent`
    /// — the closest generic "home payment" bucket. A future format revision that sends a
    /// specific utility name (e.g. "electricity") should extend this switch.
    private static func mapHomeServiceCategory(_ raw: String) -> HomeServiceCategory {
        switch raw {
        case "electricity": .electricity
        case "internet": .internet
        case "water": .water
        case "gas": .gas
        case "insurance": .insurance
        case "rent", "home": .rent
        default: .rent
        }
    }
}
