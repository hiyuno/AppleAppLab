import Foundation

/// Fixed color semaphore for the sobrante (PRD, non-negotiable): green ≥ $100,
/// yellow $0–$99.99, red < $0.
public enum SobranteStatus: Sendable {
    case positive
    case adjusted
    case negative

    public init(sobrante: Decimal) {
        if sobrante >= 100 {
            self = .positive
        } else if sobrante >= 0 {
            self = .adjusted
        } else {
            self = .negative
        }
    }
}
